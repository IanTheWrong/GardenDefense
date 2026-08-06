local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local ZombieNetwork = require(ReplicatedStorage.Game.Modules.ZombieNetwork)

local ZombieModels = ReplicatedStorage.Game.Assets.Models.Zombies
local DamageHighlightTemplate = ReplicatedStorage.Game.Assets.Models.Effects:FindFirstChild("ZombieDamageHighlight")

local SERVER_UPDATE_RATE = 20
local SMOOTHING_RATE = 12

local DAMAGE_FLASH_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DAMAGE_RESET_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local ZombieController = Knit.CreateController {
	Name = "ZombieController",
}

local Zombies = {}
local ZombiesFolder

local function GetFootOffset(Model)
	local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
	local PivotY = Model:GetPivot().Position.Y
	return (BoundsCFrame.Position.Y - BoundsSize.Y / 2) - PivotY
end

local function CreateVisual(ModelName, Position, Yaw)
	local Source = ZombieModels:FindFirstChild(ModelName)
	if not Source then return nil end

	local Visual = Source:Clone()

	local TempAnim = Visual:FindFirstChild("TempAnim")
	if TempAnim then
		TempAnim:Destroy()
	end

	local FootOffset = GetFootOffset(Visual)
	Visual:PivotTo(CFrame.new(Position - Vector3.new(0, FootOffset, 0)) * CFrame.Angles(0, Yaw, 0))
	Visual.Parent = ZombiesFolder

	local WalkAnimation = Visual:FindFirstChild("Walk")
	local Animator = Visual.AnimationController:FindFirstChildOfClass("Animator")
	if WalkAnimation and Animator then
		Animator:LoadAnimation(WalkAnimation):Play()
	end

	return Visual, FootOffset
end

local function PlayDamageHighlight(Visual)
	if not DamageHighlightTemplate then return end

	local Highlight = Visual:FindFirstChild("ZombieDamageHighlight")
	if not Highlight then
		Highlight = DamageHighlightTemplate:Clone()
		Highlight.Parent = Visual
	end

	local ResetTween = TweenService:Create(Highlight, DAMAGE_RESET_TWEEN_INFO, { FillTransparency = 1 })
	local FlashTween = TweenService:Create(Highlight, DAMAGE_FLASH_TWEEN_INFO, { FillTransparency = 0.8 })

	Highlight:SetAttribute("DamageTweenId", (Highlight:GetAttribute("DamageTweenId") or 0) + 1)
	local TweenId = Highlight:GetAttribute("DamageTweenId")

	FlashTween.Completed:Connect(function()
		if Highlight:GetAttribute("DamageTweenId") ~= TweenId then return end
		ResetTween:Play()
	end)

	FlashTween:Play()
end

local function StripSelectionBoxes(Folder)
	for _, Descendant in Folder:GetDescendants() do
		if Descendant:IsA("SelectionBox") then
			Descendant:Destroy()
		end
	end

	Folder.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("SelectionBox") then
			Descendant:Destroy()
		end
	end)
end

function ZombieController:KnitInit()
	local ZombieHurtboxes = workspace:FindFirstChild("ZombieHurtboxes")
	if ZombieHurtboxes then
		StripSelectionBoxes(ZombieHurtboxes)
	else
		workspace.ChildAdded:Connect(function(Child)
			if Child.Name == "ZombieHurtboxes" then
				StripSelectionBoxes(Child)
			end
		end)
	end

	ZombieNetwork.packets.ZombieSpawned.listen(function(Data)
		if not ZombiesFolder then return end

		local Visual, FootOffset = CreateVisual(Data.Model, Data.Position, Data.Yaw)
		if not Visual then return end

		Zombies[Data.Id] = {
			Visual = Visual,
			Yaw = Data.Yaw,
			FootOffset = FootOffset,
			CurrentPosition = Data.Position,
			TargetPosition = Data.Position,
			Velocity = Vector3.zero,
		}
	end)

	ZombieNetwork.packets.ZombieUpdate.listen(function(Snapshot)
		for Id, Position in Snapshot do
			local Zombie = Zombies[Id]
			if not Zombie then continue end

			Zombie.Velocity = (Position - Zombie.TargetPosition) * SERVER_UPDATE_RATE
			Zombie.TargetPosition = Position
		end
	end)

	ZombieNetwork.packets.ZombieHit.listen(function(Id)
		local Zombie = Zombies[Id]
		if not Zombie then return end

		PlayDamageHighlight(Zombie.Visual)
	end)

	ZombieNetwork.packets.ZombieDestroyed.listen(function(Id)
		local Zombie = Zombies[Id]
		if not Zombie then return end

		Zombie.Visual:Destroy()
		Zombies[Id] = nil
	end)

	ZombieNetwork.packets.ZombieMatchCleared.listen(function()
		for _, Zombie in Zombies do
			Zombie.Visual:Destroy()
		end
		table.clear(Zombies)
	end)
end

function ZombieController:KnitStart()
	local GameService = Knit.GetService("GameService")

	GameService.MatchStateChanged:Connect(function(State)
		if State.Phase == "Idle" then
			ZombiesFolder = Instance.new("Folder")
			ZombiesFolder.Name = "Zombies"
			ZombiesFolder.Parent = workspace.TestingGameArea
		elseif State.Phase == "Ended" then
			if ZombiesFolder then
				ZombiesFolder:Destroy()
				ZombiesFolder = nil
			end
		end
	end)

	RunService.Heartbeat:Connect(function(Dt)
		for _, Zombie in Zombies do
			local Predicted = Zombie.TargetPosition + Zombie.Velocity * Dt
			Zombie.CurrentPosition = Zombie.CurrentPosition:Lerp(Predicted, math.clamp(Dt * SMOOTHING_RATE, 0, 1))
			Zombie.Visual:PivotTo(CFrame.new(Zombie.CurrentPosition - Vector3.new(0, Zombie.FootOffset, 0)) * CFrame.Angles(0, Zombie.Yaw, 0))
		end
	end)
end

return ZombieController
