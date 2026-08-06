local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local EntityBase = require(ReplicatedStorage.Game.Modules.Combat.EntityBase)
local Lanes = require(ReplicatedStorage.Game.Modules.Combat.Lanes)
local BrainrotTypes = require(ReplicatedStorage.Game.Modules.BrainrotTypes)

local BehaviorsFolder = ReplicatedStorage.Game.Modules.Brainrots
local HURTBOX_COLLISION_GROUP = "BrainrotHurtbox"

local BehaviorCache = {}
local HurtboxFolder

local GameService

local BrainrotService = Knit.CreateService {
	Name = "BrainrotService",
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

function BrainrotService:RegisterBrainrot(Match, Model, TypeKey, GridPart)
	local Stats = BrainrotTypes[TypeKey]
	if not Stats then return nil end

	local Id = Match.NextBrainrotId
	Match.NextBrainrotId += 1

	local Behaviors = GetBehaviors(TypeKey)
	local Position = Model:GetPivot().Position
	local Lane = GridPart and Lanes.Resolve(GridPart)
	local Entity = EntityBase.New("Brainrot", Id, Position, Stats, Behaviors, Lane, Match.AttackForward)
	Entity.Model = Model

	Entity:CreateHurtbox(GetHurtboxSize(Model, Stats))
	Entity.HurtboxPart.Parent = HurtboxFolder

	Match.PlacedBrainrots[Id] = Entity
	Model:SetAttribute("EntityID", Id)

	Entity:RunFunc("OnPlaced", Match)

	return Entity
end

function BrainrotService:UnregisterBrainrot(Match, Id)
	local Entity = Match.PlacedBrainrots[Id]
	if not Entity then return end

	Match.PlacedBrainrots[Id] = nil
	Entity:RunFunc("OnRemoved", Match)
	Entity:Destroy()
end

function BrainrotService:ClearMatch(Match)
	if HurtboxFolder then
		HurtboxFolder:ClearAllChildren()
	end

	table.clear(Match.PlacedBrainrots)
end

function BrainrotService:KnitInit()
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, HURTBOX_COLLISION_GROUP)
end

function BrainrotService:KnitStart()
	GameService = Knit.GetService("GameService")

	HurtboxFolder = Instance.new("Folder")
	HurtboxFolder.Name = "BrainrotHurtboxes"
	HurtboxFolder.Parent = workspace

	RunService.Heartbeat:Connect(function(Dt)
		local Match = GameService:GetActiveMatch()
		if not Match or Match.Paused then return end

		local ScaledDt = Dt * Match.SpeedMultiplier

		for _, Entity in Match.PlacedBrainrots do
			if Entity.Functions.Heartbeat then
				Entity:RunFunc("Heartbeat", ScaledDt, Match)
			else
				DefaultAttack(Entity, ScaledDt, Match)
			end
		end
	end)
end

return BrainrotService
