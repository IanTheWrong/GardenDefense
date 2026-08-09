local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local EntityBase = require(ReplicatedStorage.Game.Modules.Combat.EntityBase)
local Lanes = require(ReplicatedStorage.Game.Modules.Combat.Lanes)
local PlantTypes = require(ReplicatedStorage.Game.Modules.PlantTypes)

local BehaviorsFolder = ReplicatedStorage.Game.Modules.Plants
local HURTBOX_COLLISION_GROUP = "PlantHurtbox"

local BehaviorCache = {}
local HurtboxFolder

local GameService

local PlantService = Knit.CreateService {
	Name = "PlantService",
}

local function GetBehaviors(TypeKey)
	if BehaviorCache[TypeKey] ~= nil then
		return BehaviorCache[TypeKey] or nil
	end

	local Module = BehaviorsFolder:FindFirstChild(TypeKey)
	local Behaviors = Module and require(Module) or false
	BehaviorCache[TypeKey] = Behaviors

	return Behaviors or nil
end

local function GetHurtboxSize(Model, Stats)
	if Stats.HurtboxSize then
		return Stats.HurtboxSize
	end

	local _, BoundsSize = Model:GetBoundingBox()
	return BoundsSize
end

local function DefaultAttack(Entity, Dt, Match)
	Entity.Cooldown = math.max((Entity.Cooldown or 0) - Dt, 0)
	if Entity.Cooldown > 0 then return end

	local TargetPart = Entity:GetNearestTarget(Entity.Stats.Range)
	if not TargetPart then return end

	Entity.Cooldown = Entity.Stats.AttackCooldown or 1

	local TargetID = TargetPart:GetAttribute("EntityID")
	local Target = TargetID ~= nil and Match.Zombies[TargetID]
	if not Target then return end

	Target:TakeDamage(Entity.Stats.Damage or 0)
end

function PlantService:RegisterPlant(Match, Model, TypeKey, GridPart)
	local Stats = PlantTypes[TypeKey]
	if not Stats then return nil end

	local Id = Match.NextPlantId
	Match.NextPlantId += 1

	local Behaviors = GetBehaviors(TypeKey)
	local Position = Model:GetPivot().Position
	local Lane = GridPart and Lanes.Resolve(GridPart)
	local Entity = EntityBase.New("Plant", Id, Position, Stats, Behaviors, Lane, Match.AttackForward)
	Entity.Model = Model

	Entity:CreateHurtbox(GetHurtboxSize(Model, Stats))
	Entity.HurtboxPart.Parent = HurtboxFolder

	Match.PlacedPlants[Id] = Entity
	Model:SetAttribute("EntityID", Id)

	Entity:RunFunc("OnPlaced", Match)

	return Entity
end

function PlantService:UnregisterPlant(Match, Id)
	local Entity = Match.PlacedPlants[Id]
	if not Entity then return end

	Match.PlacedPlants[Id] = nil
	Entity:RunFunc("OnRemoved", Match)
	Entity:Destroy()
end

function PlantService:ClearMatch(Match)
	if HurtboxFolder then
		HurtboxFolder:ClearAllChildren()
	end

	table.clear(Match.PlacedPlants)
end

function PlantService:KnitInit()
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, HURTBOX_COLLISION_GROUP)
end

function PlantService:KnitStart()
	GameService = Knit.GetService("GameService")

	HurtboxFolder = Instance.new("Folder")
	HurtboxFolder.Name = "PlantHurtboxes"
	HurtboxFolder.Parent = workspace

	RunService.Heartbeat:Connect(function(Dt)
		local Match = GameService:GetActiveMatch()
		if not Match or Match.Paused then return end

		local ScaledDt = Dt * Match.SpeedMultiplier

		for _, Entity in Match.PlacedPlants do
			if Entity.Functions.Heartbeat then
				Entity:RunFunc("Heartbeat", ScaledDt, Match)
			else
				DefaultAttack(Entity, ScaledDt, Match)
			end
		end
	end)
end

return PlantService
