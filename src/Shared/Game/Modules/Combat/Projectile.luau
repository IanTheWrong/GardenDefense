local RunService = game:GetService("RunService")

local Hitbox = require(script.Parent.Hitbox)
local StudioTestParams = require(script.Parent.Parent.StudioTestParams)

local DEFAULT_RADIUS = 2

local Projectile = {}

local ActiveProjectiles = {}
local VisualsFolder
local Started = false

local function StripVisualPhysics(Model)
	for _, Descendant in Model:GetDescendants() do
		if not Descendant:IsA("BasePart") then continue end
		Descendant.Anchored = true
		Descendant.CanCollide = false
		Descendant.CanQuery = false
		Descendant.CanTouch = false
		Descendant.Massless = true
	end
end

local function CreateDebugMarker(Radius)
	local Part = Instance.new("Part")
	Part.Shape = Enum.PartType.Ball
	Part.Size = Vector3.new(Radius, Radius, Radius) * 2
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.Massless = true
	Part.Color = Color3.new(1, 0, 0)
	Part.Transparency = 0.5
	return Part
end

local function DestroyProjectile(Data)
	if Data.Visual then
		Data.Visual:Destroy()
	end
	if Data.DebugMarker then
		Data.DebugMarker:Destroy()
	end
	ActiveProjectiles[Data] = nil
end

local function MatchesLane(Part, Data)
	if Data.LaneMode == "AnyLane" then
		return true
	end
	return Part:GetAttribute("Lane") == Data.SourceLane
end

local function ResolveHits(Data)
	local Parts = Hitbox.QueryRadius(Data.Position, Data.Radius, Data.TargetFolder)

	for _, Part in Parts do
		local EntityID = Part:GetAttribute("EntityID")
		if EntityID == nil or Data.HitEntities[EntityID] then continue end
		if not MatchesLane(Part, Data) then continue end

		if Data.HitMode == "Splash" then
			Data.HitEntities[EntityID] = true

			local SplashParts = Hitbox.QueryRadius(Data.Position, Data.SplashRadius or Data.Radius, Data.TargetFolder)
			for _, SplashPart in SplashParts do
				local SplashEntityID = SplashPart:GetAttribute("EntityID")
				if SplashEntityID == nil or Data.HitEntities[SplashEntityID] then continue end
				if not MatchesLane(SplashPart, Data) then continue end
				Data.HitEntities[SplashEntityID] = true
				if Data.OnHit then
					Data.OnHit(SplashEntityID, Data.Position)
				end
			end

			return true
		end

		Data.HitEntities[EntityID] = true
		if Data.OnHit then
			Data.OnHit(EntityID, Data.Position)
		end

		if Data.HitMode == "Pierce" then
			Data.PierceCount += 1
			if Data.MaxPierce and Data.PierceCount >= Data.MaxPierce then
				return true
			end
			continue
		end

		return true
	end

	return false
end

local function Tick(Dt)
	for Data in ActiveProjectiles do
		Data.Lifetime -= Dt

		if Data.Homing and Data.Homing.Target and not Data.Homing.Target.Terminated then
			local TargetPosition = Data.Homing.Target.Position + (Data.Homing.Offset or Vector3.zero)
			local ToTarget = TargetPosition - Data.Position
			if ToTarget.Magnitude > 0 then
				local DesiredDirection = ToTarget.Unit
				Data.Direction = (Data.Direction + (DesiredDirection - Data.Direction) * Data.Homing.Strength * Dt).Unit
			end
		end

		Data.VerticalVelocity -= Data.Gravity * Dt
		Data.Position += (Data.Direction * Data.Speed * Dt) + Vector3.new(0, Data.VerticalVelocity * Dt, 0)

		if Data.Visual then
			Data.Visual:PivotTo(CFrame.lookAt(Data.Position, Data.Position + Data.Direction))
		end

		if Data.DebugMarker then
			Data.DebugMarker.Position = Data.Position
		end

		local Destroyed = ResolveHits(Data)

		if not Destroyed and Data.Lifetime <= 0 then
			Destroyed = true
			if Data.OnExpire then
				Data.OnExpire()
			end
		end

		if Destroyed then
			DestroyProjectile(Data)
		end
	end
end

local function EnsureStarted()
	if Started then return end
	Started = true

	VisualsFolder = Instance.new("Folder")
	VisualsFolder.Name = "ProjectileVisuals"
	VisualsFolder.Parent = workspace

	RunService.Heartbeat:Connect(Tick)
end

function Projectile.Fire(Config)
	EnsureStarted()

	local Data = {
		Position = Config.Origin,
		Direction = Config.Direction.Unit,
		Speed = Config.Speed,
		Lifetime = Config.Lifetime,
		Gravity = Config.Gravity or 0,
		VerticalVelocity = 0,
		Radius = Config.Radius or DEFAULT_RADIUS,
		HitMode = Config.HitMode or "Single",
		MaxPierce = Config.MaxPierce,
		PierceCount = 0,
		SplashRadius = Config.SplashRadius,
		Homing = Config.Homing,
		TargetFolder = Config.TargetFolder,
		SourceLane = Config.SourceLane,
		LaneMode = Config.LaneMode or "SameLane",
		OnHit = Config.OnHit,
		OnExpire = Config.OnExpire,
		HitEntities = {},
	}

	if Config.Model then
		Data.Visual = Config.Model:Clone()
		StripVisualPhysics(Data.Visual)
		Data.Visual:PivotTo(CFrame.lookAt(Data.Position, Data.Position + Data.Direction))
		Data.Visual.Parent = VisualsFolder
	end

	local Visualize = Config.Visualize
	if Visualize == nil then
		Visualize = StudioTestParams.ShowHitboxes
	end

	if Visualize then
		Data.DebugMarker = CreateDebugMarker(Data.Radius)
		Data.DebugMarker.Position = Data.Position
		Data.DebugMarker.Parent = VisualsFolder
	end

	ActiveProjectiles[Data] = true

	return Data
end

return Projectile
