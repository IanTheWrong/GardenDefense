local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local Lanes = require(ReplicatedStorage.Game.Modules.Combat.Lanes)

local BrainrotModels = ReplicatedStorage.Game.Assets.Models.Brainrots

local GameService
local DataService
local BrainrotService

local PlacementService = Knit.CreateService {
	Name = "PlacementService",
	Client = {},
}

local function GetFootOffset(Model)
	local BoundsCFrame, BoundsSize = Model:GetBoundingBox()
	local PivotY = Model:GetPivot().Position.Y
	return (BoundsCFrame.Position.Y - BoundsSize.Y / 2) - PivotY
end

local function GetSurfaceCFrame(GridPart)
	return GridPart.CFrame * CFrame.new(0, GridPart.Size.Y / 2, 0)
end

function PlacementService:PlaceBrainrot(Player, Uuid, GridPart)
	local Match = GameService:GetActiveMatch()
	if not Match or Match.Player ~= Player then return false end
	if Match.Paused then return false end
	if typeof(GridPart) ~= "Instance" or not GridPart:IsA("BasePart") then return false end
	if GridPart.Parent ~= Match.Area.PlacementGrid then return false end
	if Match.OccupiedCells[GridPart] then return false end
	if not Lanes.Resolve(GridPart) then return false end

	local OwnedBrainrots = DataService:GetOwnedBrainrots(Player)
	local Entry = OwnedBrainrots[Uuid]
	if not Entry then return false end

	local PlacedCount = Match.PlacementCounts[Uuid] or 0
	if PlacedCount >= Match.Config.MaxUnitPlacements then return false end

	local Source = BrainrotModels:FindFirstChild(Entry.Name)
	if not Source then return false end

	local Model = Source:Clone()
	local FootOffset = GetFootOffset(Model)
	Model:PivotTo(GetSurfaceCFrame(GridPart) * CFrame.new(0, -FootOffset, 0))
	Model.Parent = Match.BrainrotsFolder

	Match.OccupiedCells[GridPart] = Model
	Match.PlacementCounts[Uuid] = PlacedCount + 1

	BrainrotService:RegisterBrainrot(Match, Model, Entry.Name, GridPart)

	return true
end

function PlacementService.Client:PlaceBrainrot(Player, Uuid, GridPart)
	return self.Server:PlaceBrainrot(Player, Uuid, GridPart)
end

function PlacementService:KnitStart()
	GameService = Knit.GetService("GameService")
	DataService = Knit.GetService("DataService")
	BrainrotService = Knit.GetService("BrainrotService")
end

return PlacementService