local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local Lanes = require(ReplicatedStorage.Game.Modules.Combat.Lanes)

local PlantModels = ReplicatedStorage.Game.Assets.Models.Plants

local GameService
local DataService
local PlantService

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

function PlacementService:PlacePlant(Player, Uuid, GridPart)
	local Match = GameService:GetActiveMatch()
	if not Match or Match.Player ~= Player then return false end
	if Match.Paused then return false end
	if typeof(GridPart) ~= "Instance" or not GridPart:IsA("BasePart") then return false end
	if GridPart.Parent ~= Match.Area.PlacementGrid then return false end
	if Match.OccupiedCells[GridPart] then return false end
	if not Lanes.Resolve(GridPart) then return false end

	local OwnedPlants = DataService:GetOwnedPlants(Player)
	local Entry = OwnedPlants[Uuid]
	if not Entry then return false end

	local PlacedCount = Match.PlacementCounts[Uuid] or 0
	if PlacedCount >= Match.Config.MaxUnitPlacements then return false end

	local Source = PlantModels:FindFirstChild(Entry.Name)
	if not Source then return false end

	local Model = Source:Clone()
	local FootOffset = GetFootOffset(Model)
	Model:PivotTo(GetSurfaceCFrame(GridPart) * CFrame.new(0, -FootOffset, 0))
	Model.Parent = Match.PlantsFolder

	Match.OccupiedCells[GridPart] = Model
	Match.PlacementCounts[Uuid] = PlacedCount + 1

	PlantService:RegisterPlant(Match, Model, Entry.Name, GridPart)

	return true
end

function PlacementService.Client:PlacePlant(Player, Uuid, GridPart)
	return self.Server:PlacePlant(Player, Uuid, GridPart)
end

function PlacementService:KnitStart()
	GameService = Knit.GetService("GameService")
	DataService = Knit.GetService("DataService")
	PlantService = Knit.GetService("PlantService")
end

return PlacementService