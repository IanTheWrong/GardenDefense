local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage") -- unused
local HttpService = game:GetService("HttpService")

local Knit = require(game.ReplicatedStorage.Game.Knit.Knit)

local ProfileStore = require(script.ProfileStore)
local Template = require(script.DataTemplate)

local DataService = Knit.CreateService {
	Name = "DataService",
	Client = {
		OwnedPlantAdded = Knit.CreateSignal(),
	},
}

DataService.Profiles = {}
local PlayerStore = ProfileStore.New(RunService:IsStudio() and "Test" or "Live", Template) -- creates the ProfileStore "db"

local function OnProfileLoaded(player, profile) --placeholder. Change before final version
end

function DataService:LoadPlayerProfile(player)
	local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, { -- returns profile object
		Cancel = function()
			return player.Parent ~= Players
		end,
	}) 

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function() -- this will fire on a player leaving as well. Not a problem unless we push profiles for people still in game
			self.Profiles[player] = nil
			player:Kick("Data error occurred. Please rejoin.")
		end)

		if player.Parent == Players then
			self.Profiles[player] = profile
			OnProfileLoaded(player, profile) -- called the placeholder function from above
		else
			profile:EndSession()
		end
	else
		player:Kick("Data error occurred. Please rejoin.")
	end
end

function DataService:ReleaseProfile(player)
	local profile = self.Profiles[player]
	if not profile then return end
	profile:EndSession()
	self.Profiles[player] = nil
end

function DataService:GetProfile(player)
	return self.Profiles[player]
end

function DataService:OwnsPlant(Player, PlantName)
	local Profile = self.Profiles[Player]
	if not Profile then return false end

	for _, Entry in Profile.Data.OwnedPlants do
		if Entry.Name == PlantName then
			return true
		end
	end

	return false
end

function DataService:AddPlant(Player, PlantName)
	local Profile = self.Profiles[Player]
	if not Profile then return nil end

	local Uuid = HttpService:GenerateGUID(false)
	local Entry = {
		Name = PlantName,
		Stats = {},
	}
	Profile.Data.OwnedPlants[Uuid] = Entry

	self.Client.OwnedPlantAdded:Fire(Player, Uuid, Entry)

	return Uuid
end

function DataService:GetOwnedPlants(Player)
	local Profile = self.Profiles[Player]
	if not Profile then return {} end

	return Profile.Data.OwnedPlants
end

function DataService.Client:GetOwnedPlants(Player)
	return self.Server:GetOwnedPlants(Player)
end

function DataService:KnitStart()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:LoadPlayerProfile(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayerProfile(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ReleaseProfile(player)
	end)
end

return DataService
