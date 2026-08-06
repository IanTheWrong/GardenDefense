local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local Players = game:GetService("Players")

local PlacementController = Knit.CreateController {
	Name = "PlacementController",
}

local PlacementFrame
local UnitTemplate

local DataService
local BannerService
local PlacementGridController

local SelectedButton = nil
local SelectedUuid = nil

local function ClearSelection()
	if SelectedButton then
		SelectedButton.Parent.BorderSizePixel = 0
	end
	SelectedButton = nil
	SelectedUuid = nil

	PlacementGridController:StopSession()
end

local function SelectUnit(Button, Uuid, Name)
	if SelectedButton == Button then
		ClearSelection()
		return
	end

	ClearSelection()

	Button.Parent.BorderSizePixel = 5
	SelectedButton = Button
	SelectedUuid = Uuid

	PlacementGridController:StartSession(Uuid, Name)
end

local function PopulateUnits()
	ClearSelection()

	for _, Child in PlacementFrame:GetChildren() do
		if Child:IsA("Frame") and Child ~= UnitTemplate then
			Child:Destroy()
		end
	end

	local OwnedBrainrots = DataService:GetOwnedBrainrots():expect()
	local DisplayNames = BannerService:GetBrainrotDisplayNames():expect()

	for Uuid, Entry in OwnedBrainrots do
		local UnitFrame = UnitTemplate:Clone()
		UnitFrame.Visible = true
		UnitFrame.BorderSizePixel = 0
		UnitFrame.Parent = PlacementFrame

		local UnitButton = UnitFrame:WaitForChild("UnitButton")
		UnitButton.Text = DisplayNames[Entry.Name] or Entry.Name

		UnitButton.Activated:Connect(function()
			SelectUnit(UnitButton, Uuid, Entry.Name)
		end)
	end
end

function PlacementController:GetSelectedUnit()
	return SelectedUuid
end

function PlacementController:Open()
	PopulateUnits()
	PlacementFrame.Visible = true
end

function PlacementController:Close()
	ClearSelection()
	PlacementFrame.Visible = false
end

function PlacementController:KnitInit()
	local Interface = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("uiInterface")
	local MatchUI = Interface:WaitForChild("MatchUI")
	PlacementFrame = MatchUI:WaitForChild("PlaceholderPlacementUI")
	UnitTemplate = script.PlaceholderUnitTemplate

	UnitTemplate.Visible = false
	PlacementFrame.Visible = false
end

function PlacementController:KnitStart()
	DataService = Knit.GetService("DataService")
	BannerService = Knit.GetService("BannerService")
	PlacementGridController = Knit.GetController("PlacementGridController")

	local GameService = Knit.GetService("GameService")

	GameService.MatchStateChanged:Connect(function(State)
		if State.Phase == "Idle" then
			self:Open()
		elseif State.Phase == "Ended" then
			self:Close()
		end
	end)
end

return PlacementController