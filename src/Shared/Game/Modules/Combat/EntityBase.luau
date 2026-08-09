local Hitbox = require(script.Parent.Hitbox)
local Projectile = require(script.Parent.Projectile)
local StudioTestParams = require(script.Parent.Parent.StudioTestParams)

local COLLISION_GROUPS = {
	Zombie = { Own = "ZombieHurtbox", Opposing = "PlantHurtbox", OwnFolder = "ZombieHurtboxes", OpposingFolder = "PlantHurtboxes" },
	Plant = { Own = "PlantHurtbox", Opposing = "ZombieHurtbox", OwnFolder = "PlantHurtboxes", OpposingFolder = "ZombieHurtboxes" },
}

local EntityBase = {}
EntityBase.__index = EntityBase

function EntityBase.New(Kind, Id, Position, Stats, Functions, Lane, AttackForward)
	local Groups = COLLISION_GROUPS[Kind]

	local self = setmetatable({}, EntityBase)
	self.Kind = Kind
	self.Id = Id
	self.Position = Position
	self.Facing = Vector3.new(0, 0, 1)
	self.Lane = Lane
	self.AttackForward = AttackForward
	self.Stats = Stats
	self.Functions = Functions or {}
	self.Health = Stats.HP or Stats.Health or 0
	self.MaxHealth = self.Health
	self.OwnCollisionGroup = Groups.Own
	self.OpposingCollisionGroup = Groups.Opposing
	self.OwnFolder = workspace:FindFirstChild(Groups.OwnFolder)
	self.OpposingFolder = workspace:FindFirstChild(Groups.OpposingFolder)
	self.HurtboxPart = nil
	self.Terminated = false

	return self
end

function EntityBase:RunFunc(FuncName, ...)
	if self.Terminated then return end
	local Func = self.Functions[FuncName]
	if not Func then return end
	return Func(self, ...)
end

function EntityBase:SetFacing(Direction)
	if Direction.Magnitude == 0 then return end
	self.Facing = Direction.Unit
end

function EntityBase:GetCFrame()
	return CFrame.lookAt(self.Position, self.Position + self.Facing)
end

function EntityBase:CreateHurtbox(Size, Visualize)
	if Visualize == nil then
		Visualize = StudioTestParams.ShowHurtboxes
	end

	self.HurtboxPart = Hitbox.Create(CFrame.new(self.Position), Size, self.OwnCollisionGroup, { EntityID = self.Id, Lane = self.Lane }, workspace, Visualize)
	return self.HurtboxPart
end

function EntityBase:UpdateHurtboxPosition()
	if not self.HurtboxPart then return end
	self.HurtboxPart.Position = self.Position
end

function EntityBase:FilterByLane(Parts, LaneMode)
	if LaneMode == "AnyLane" then
		return Parts
	end

	local Filtered = {}
	for _, Part in Parts do
		if Part:GetAttribute("Lane") == self.Lane then
			table.insert(Filtered, Part)
		end
	end

	return Filtered
end

function EntityBase:GetTargetsInRange(Range, LaneMode)
	local Targets = Hitbox.QueryRadius(self.Position, Range, self.OpposingFolder)
	return self:FilterByLane(Targets, LaneMode)
end

function EntityBase:GetNearestTarget(Range, LaneMode)
	local Targets = self:GetTargetsInRange(Range, LaneMode)
	local Nearest, NearestDistance = nil, math.huge

	for _, Part in Targets do
		local Distance = (Part.Position - self.Position).Magnitude
		if Distance < NearestDistance then
			Nearest = Part
			NearestDistance = Distance
		end
	end

	return Nearest
end

function EntityBase:GetNearestForwardTarget(Range, LaneMode)
	local Targets = self:GetTargetsInRange(Range, LaneMode)
	local Nearest, NearestDistance = nil, math.huge

	for _, Part in Targets do
		local Delta = (Part.Position - self.Position) * Vector3.new(1, 0, 1)
		if self.AttackForward and Delta:Dot(self.AttackForward) < 0 then continue end

		local Distance = Delta.Magnitude
		if Distance < NearestDistance then
			Nearest = Part
			NearestDistance = Distance
		end
	end

	return Nearest
end

function EntityBase:GetAttackDirection(TargetPart)
	local Delta = (TargetPart.Position - self.Position) * Vector3.new(1, 0, 1)
	if Delta.Magnitude == 0 then return nil end

	local Direction = Delta.Unit
	if self.AttackForward and Direction:Dot(self.AttackForward) < 0 then
		return nil
	end

	return Direction
end

function EntityBase:SpawnHitbox(Config)
	Config = Config or {}

	local Visualize = Config.Visualize
	if Visualize == nil then
		Visualize = StudioTestParams.ShowHitboxes
	end

	local Size = Config.Size or 6
	local Offset = Config.Offset or CFrame.new()
	local WorldCFrame = self:GetCFrame() * Offset

	local Part = Hitbox.Create(WorldCFrame, Size, self.OpposingCollisionGroup, nil, workspace, Visualize)

	local Hits
	if typeof(Size) == "number" then
		Hits = Hitbox.QueryRadius(WorldCFrame.Position, Size / 2, self.OpposingFolder)
	else
		Hits = Hitbox.QueryBox(WorldCFrame, Size, self.OpposingFolder)
	end

	Hits = self:FilterByLane(Hits, Config.LaneMode)

	task.delay(Config.Lifetime or 0.15, function()
		Part:Destroy()
	end)

	return Hits
end

function EntityBase:FireProjectile(Config)
	Config.SourceKind = self.Kind
	Config.SourceLane = self.Lane
	Config.Origin = Config.Origin or self.Position
	Config.TargetFolder = Config.TargetFolder or self.OpposingFolder
	return Projectile.Fire(Config)
end

function EntityBase:TakeDamage(Amount, Source)
	if self.Terminated then return end
	Amount = math.max(0, Amount or 0)

	local OldHealth = self.Health
	self.Health = math.max(OldHealth - Amount, 0)
	if self.Health == OldHealth then return end

	self:RunFunc("OnDamaged", Amount, Source)

	if self.Health <= 0 then
		self:RunFunc("OnDeath", Source)
	end

	return Amount
end

function EntityBase:Heal(Amount)
	if self.Terminated then return end
	Amount = math.max(0, Amount or 0)
	self.Health = math.min(self.Health + Amount, self.MaxHealth)
end

function EntityBase:Destroy()
	if self.HurtboxPart then
		self.HurtboxPart:Destroy()
		self.HurtboxPart = nil
	end
	self.Terminated = true
end

return EntityBase
