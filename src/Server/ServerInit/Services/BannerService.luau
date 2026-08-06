local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(game.ReplicatedStorage.Game.Knit.Knit)

local BannersFolder = ReplicatedStorage.Game.Modules:WaitForChild("Banners")

local RotationDuration = 7200
local ActiveBannerCount = 3
local MaxRollAmount = 10

local Rng = Random.new()

local DataService

local BannerService = Knit.CreateService({
	Name = "BannerService",
	Banners = {},
	Client = {
		ActiveBannersChanged = Knit.CreateSignal()
	}
})

local function WeightedSelect(Pool)
	local Total = 0
	for _, Entry in Pool do
		Total += Entry.Chance
	end

	local Roll = Rng:NextNumber() * Total
	local Cumulative = 0
	for _, Entry in Pool do
		Cumulative += Entry.Chance
		if Roll <= Cumulative then
			return Entry
		end
	end

	return Pool[#Pool]
end

function BannerService:LoadBanners()
	self.Banners = {}
	for _, Module in BannersFolder:GetChildren() do
		if Module:IsA("ModuleScript") then
			self.Banners[Module.Name] = require(Module)
		end
	end
end

function BannerService:GetAllBannerNames()
	local Names = {}
	for Name in self.Banners do
		table.insert(Names, Name)
	end

	table.sort(Names)
	return Names
end

function BannerService:GetActiveBanners()
	local Names = self:GetAllBannerNames()
	local Count = math.min(ActiveBannerCount, #Names)
	local Epoch = math.floor(os.time() / RotationDuration)
	local SeededRng = Random.new(Epoch)
	local Available = table.clone(Names)
	local Selected = {}

	for _ = 1, Count do
		local Index = SeededRng:NextInteger(1, #Available)
		table.insert(Selected, Available[Index])
		table.remove(Available, Index)
	end

	return Selected
end

function BannerService:GetActiveBannerData()
	local Data = {}
	for _, Name in self:GetActiveBanners() do
		local Banner = self.Banners[Name]
		table.insert(Data, {
			Name = Name,
			DisplayName = Banner.DisplayName,
			Brainrots = Banner.Brainrots
		})
	end

	return Data
end

function BannerService:IsBannerActive(BannerName)
	for _, Name in self:GetActiveBanners() do
		if Name == BannerName then
			return true
		end
	end

	return false
end

function BannerService:GetTimeUntilNextRotation()
	return RotationDuration - (os.time() % RotationDuration)
end

function BannerService:Roll(Player, BannerName, Amount)
	if not self:IsBannerActive(BannerName) then
		return {Success = false, Reason = "BannerInactive"}
	end

	local Banner = self.Banners[BannerName]
	if not Banner then
		return {Success = false, Reason = "BannerNotFound"}
	end

	if not DataService:GetProfile(Player) then
		return {Success = false, Reason = "DataNotLoaded"}
	end

	Amount = math.clamp(tonumber(Amount) or 1, 1, MaxRollAmount)
	local Rewards = {}
	for _ = 1, Amount do
		local Entry = WeightedSelect(Banner.Brainrots)
		local IsDuplicate = DataService:OwnsBrainrot(Player, Entry.Name)
		local Uuid
		if not IsDuplicate then
			Uuid = DataService:AddBrainrot(Player, Entry.Name)
		end
		table.insert(Rewards, {
			Uuid = Uuid,
			Name = Entry.Name,
			DisplayName = Entry.DisplayName,
			IsDuplicate = IsDuplicate,
		})
	end

	return {Success = true, Rewards = Rewards}
end

function BannerService:GetBrainrotDisplayNames()
	local DisplayNames = {}
	for _, Banner in self.Banners do
		for _, Entry in Banner.Brainrots do
			DisplayNames[Entry.Name] = Entry.DisplayName
		end
	end

	return DisplayNames
end

function BannerService.Client:GetActiveBanners(Player)
	return self.Server:GetActiveBannerData()
end

function BannerService.Client:GetTimeUntilNextRotation(Player)
	return self.Server:GetTimeUntilNextRotation()
end

function BannerService.Client:GetBrainrotDisplayNames(Player)
	return self.Server:GetBrainrotDisplayNames()
end

function BannerService.Client:Roll(Player, BannerName, Amount)
	return self.Server:Roll(Player, BannerName, Amount)
end

function BannerService:KnitInit()
	self:LoadBanners()
end

function BannerService:KnitStart()
	DataService = Knit.GetService("DataService")

	task.spawn(function()
		while true do
			task.wait(self:GetTimeUntilNextRotation())
			self.Client.ActiveBannersChanged:FireAll(self:GetActiveBannerData())
		end
	end)
end

return BannerService
