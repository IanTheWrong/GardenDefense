local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlantModels = ReplicatedStorage.Game.Assets.Models.Plants
local MaxUnitPlacements = require(ReplicatedStorage.Game.Modules.Maps.TestMap).MaxUnitPlacements

local ValidColor = Color3.fromRGB(0, 255, 0)
local InvalidColor = Color3.fromRGB(255, 0, 0)

local PlacementGridController = Knit.CreateController {
	Name = "PlacementGridController",
}

local PlacementGrid
local PlantsFolder

local PlacementService

local SelectedUuid
local SelectedName

local Hologram
local HologramConnection
local CurrentGridPart
local CurrentValid = false

local function GetFootOffset(Model)
	local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
	local PivotY = Model:GetPivot().Position.Y
	return (BoundsCFrame.Position.Y - BoundsSize.Y / 2) - PivotY
end

local function GetSurfaceCFrame(GridPart)
	return GridPart.CFrame * CFrame.new(0, GridPart.Size.Y / 2, 0)
end

local function GetGridPartUnderMouse()
	local Camera = workspace.CurrentCamera
	local MousePosition = UserInputService:GetMouseLocation()
	local Ray = Camera:ViewportPointToRay(MousePosition.X, MousePosition.Y)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {PlacementGrid}

	local Result = workspace:Raycast(Ray.Origin, Ray.Direction * 1000, Params)
	if Result and Result.Instance:IsA("BasePart") then
		return Result.Instance
	end

	return nil
end

local function IsCellOccupied(GridPart)
	if not PlantsFolder then return false end

	for _, Model in PlantsFolder:GetChildren() do
		local Pivot = Model:GetPivot().Position
		if math.abs(Pivot.X - GridPart.Position.X) < 1 and math.abs(Pivot.Z - GridPart.Position.Z) < 1 then
			return true
		end
	end

	return false
end

local function CountPlaced(Name)
	if not PlantsFolder then return 0 end

	local Count = 0
	for _, Model in PlantsFolder:GetChildren() do
		if Model.Name == Name then
			Count += 1
		end
	end

	return Count
end

local function SetHologramColor(Color)
	for _, Descendant in Hologram:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Color = Color
			Descendant.Transparency = 0.5
		elseif Descendant:IsA("Decal") then
			Descendant.Transparency = 1
		end
	end
end

local function HideHologram()
	for _, Descendant in Hologram:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Transparency = 1
		end
	end
end

local function CreateHologram(Name)
	local Source = PlantModels:FindFirstChild(Name)
	if not Source then return nil end

	local NewHologram = Source:Clone()
	NewHologram.Name = "PlacementHologram"

	local HumanoidInHologram = NewHologram:FindFirstChildOfClass("Humanoid")
	if HumanoidInHologram then
		HumanoidInHologram:Destroy()
	end

	for _, Descendant in NewHologram:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
			Descendant.CanCollide = false
			Descendant.CanQuery = false
			Descendant.Transparency = 1
		end
	end

	NewHologram.Parent = workspace
	return NewHologram
end

function PlacementGridController:StopSession()
	if HologramConnection then
		HologramConnection:Disconnect()
		HologramConnection = nil
	end

	if Hologram then
		Hologram:Destroy()
		Hologram = nil
	end

	CurrentGridPart = nil
	CurrentValid = false
	SelectedUuid = nil
	SelectedName = nil
end

function PlacementGridController:StartSession(Uuid, Name)
	self:StopSession()

	Hologram = CreateHologram(Name)
	if not Hologram then return end

	SelectedUuid = Uuid
	SelectedName = Name

	local FootOffset = GetFootOffset(Hologram)

	HologramConnection = RunService.RenderStepped:Connect(function()
		local GridPart = GetGridPartUnderMouse()
		CurrentGridPart = GridPart

		if not GridPart then
			HideHologram()
			CurrentValid = false
			return
		end

		Hologram:PivotTo(GetSurfaceCFrame(GridPart) * CFrame.new(0, -FootOffset, 0))

		local Occupied = IsCellOccupied(GridPart)
		local ReachedLimit = CountPlaced(Name) >= MaxUnitPlacements
		CurrentValid = not Occupied and not ReachedLimit

		SetHologramColor(if CurrentValid then ValidColor else InvalidColor)
	end)
end

function PlacementGridController:KnitInit()
	PlacementGrid = workspace:WaitForChild("TestingGameArea"):WaitForChild("PlacementGrid")
end

function PlacementGridController:KnitStart()
	PlacementService = Knit.GetService("PlacementService")
	local GameService = Knit.GetService("GameService")

	GameService.MatchStateChanged:Connect(function(State)
		if State.Phase == "Idle" then
			PlantsFolder = workspace.TestingGameArea:WaitForChild("Plants")
		elseif State.Phase == "Ended" then
			self:StopSession()
			PlantsFolder = nil
		end
	end)

	UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not Hologram or not CurrentGridPart or not CurrentValid then return end

		PlacementService:PlacePlant(SelectedUuid, CurrentGridPart)
	end)
end

return PlacementGridController