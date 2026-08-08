local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local ZombieNetwork = require(ReplicatedStorage.Game.Modules.ZombieNetwork)
local ZombieTypes = require(ReplicatedStorage.Game.Modules.ZombieTypes)
local Lanes = require(ReplicatedStorage.Game.Modules.Combat.Lanes)
local Currency = require(ReplicatedStorage.Game.Modules.Currency)

local REACHED_DISTANCE = 4
local SERVER_UPDATE_RATE = 20
local SERVER_UPDATE_INTERVAL = 1 / SERVER_UPDATE_RATE
local HURTBOX_COLLISION_GROUP = "ZombieHurtbox"

local HurtboxTemplate = ServerStorage.Game.Assets.Debug:FindFirstChild("ZombieServerVisual")
local HurtboxTemplateRotation = HurtboxTemplate and HurtboxTemplate.CFrame.Rotation
local HurtboxTemplateOffset = HurtboxTemplateRotation and Vector3.new(0, math.abs(HurtboxTemplateRotation:VectorToWorldSpace(HurtboxTemplate.Size).Y) / 2, 0)
local HurtboxFolder

local GameService

local ZombieService = Knit.CreateService {
	Name = "ZombieService",
}

local HealthByModel = {}
local ValueByModel = {}
for _, TypeData in ZombieTypes do
	HealthByModel[TypeData.Model] = TypeData.HP
	ValueByModel[TypeData.Model] = TypeData.Value
end

local function CreateHurtbox(Id, Position, Lane)
	if not HurtboxTemplate then return nil end

	local Hurtbox = HurtboxTemplate:Clone()
	Hurtbox.CollisionGroup = HURTBOX_COLLISION_GROUP
	Hurtbox:SetAttribute("EntityID", Id)
	Hurtbox:SetAttribute("Lane", Lane)
	Hurtbox.CFrame = CFrame.new(Position + HurtboxTemplateOffset) * HurtboxTemplateRotation 
	Hurtbox.Parent = HurtboxFolder

	return Hurtbox
end

function ZombieService:SpawnZombie(Match, WaveState, SpawnPart, Speed, ModelName)
	local Id = Match.NextZombieId
	Match.NextZombieId += 1

	local SpawnPosition = SpawnPart.Position
	local Direction = -Match.AttackForward
	local _, Yaw = CFrame.lookAt(Vector3.zero, Direction):ToOrientation()
	local Lane = Lanes.Resolve(SpawnPart)

	local MaxHealth = HealthByModel[ModelName] or 0
	local Value = ValueByModel[ModelName] or 0

	local Zombie = {
		Position = SpawnPosition,
		Direction = Direction,
		Speed = Speed,
		WaveState = WaveState,
		Lane = Lane,
		Health = MaxHealth,
		MaxHealth = MaxHealth,
		Value = Value,
		HurtboxPart = CreateHurtbox(Id, SpawnPosition, Lane),
		HurtboxOffset = HurtboxTemplateOffset or Vector3.zero,
		Terminated = false,
	}

	function Zombie:TakeDamage(Amount)
		if self.Health <= 0 then return end
		self.Health = math.max(self.Health - Amount, 0)
		ZombieNetwork.packets.ZombieHit.sendTo(Id, Match.Player)
		if self.Health <= 0 then
			ZombieService:DespawnZombie(Match, Id, "Killed")
		end
	end

	Match.Zombies[Id] = Zombie
	Match:RegisterWaveZombie(WaveState)

	ZombieNetwork.packets.ZombieSpawned.sendTo({
		Id = Id,
		Model = ModelName,
		Position = SpawnPosition,
		Yaw = Yaw,
	}, Match.Player)
end

function ZombieService:DespawnZombie(Match, Id, Reason)
	local Zombie = Match.Zombies[Id]
	if not Zombie then return end

	Match.Zombies[Id] = nil
	Zombie.Terminated = true
	Match:UnregisterWaveZombie(Zombie.WaveState)

	if Reason == "Killed" then
		local Income = Currency.ComputeKillIncome(Match.CurrencyConfig, Zombie.Value, Zombie.WaveState.Number)
		Match:AddCurrency(Income)
	end

	if Zombie.HurtboxPart then
		Zombie.HurtboxPart:Destroy()
	end

	ZombieNetwork.packets.ZombieDestroyed.sendTo(Id, Match.Player)
end

function ZombieService:ClearMatch(Match)
	if HurtboxFolder then
		HurtboxFolder:ClearAllChildren()
	end

	table.clear(Match.Zombies)
	ZombieNetwork.packets.ZombieMatchCleared.sendTo(0, Match.Player)
end

function ZombieService:KnitInit()
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, HURTBOX_COLLISION_GROUP)
end

function ZombieService:KnitStart()
	GameService = Knit.GetService("GameService")

	if HurtboxTemplate then
		HurtboxFolder = Instance.new("Folder")
		HurtboxFolder.Name = "ZombieHurtboxes"
		HurtboxFolder.Parent = workspace
	end

	local Accumulated = 0

	RunService.Heartbeat:Connect(function(Dt)
		local Match = GameService:GetActiveMatch()
		if not Match then return end

		Accumulated += Dt
		local ShouldReplicate = Accumulated >= SERVER_UPDATE_INTERVAL
		if ShouldReplicate then
			Accumulated = 0
		end

		if Match.Paused then return end

		local ScaledDt = Dt * Match.SpeedMultiplier
		local Snapshot = nil

		for Id, Zombie in Match.Zombies do
			Zombie.Position += Zombie.Direction * Zombie.Speed * ScaledDt

			if (Zombie.Position - Match.ZombieEnd):Dot(Match.AttackForward) <= REACHED_DISTANCE then
				ZombieService:DespawnZombie(Match, Id, "Leaked")
				continue
			end

			if Zombie.HurtboxPart then
				Zombie.HurtboxPart.CFrame = CFrame.new(Zombie.Position + HurtboxTemplateOffset) * HurtboxTemplateRotation
			end

			if ShouldReplicate then
				Snapshot = Snapshot or {}
				Snapshot[Id] = Zombie.Position
			end
		end

		if Snapshot then
			ZombieNetwork.packets.ZombieUpdate.sendTo(Snapshot, Match.Player)
		end
	end)
end

return ZombieService
