local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(game.ReplicatedStorage.Game.Knit.Knit)

local MapsFolder = ReplicatedStorage.Game.Modules:WaitForChild("Maps")
local GameplayFolder = script.Parent.Parent:WaitForChild("Gameplay")
local GamemodesFolder = GameplayFolder:WaitForChild("Gamemodes")

local Currency = require(ReplicatedStorage.Game.Modules.Currency)

local SpeedSteps = {1, 1.5, 2, 4}

local ZombieService
local BrainrotService

local GameService = Knit.CreateService({
	Name = "GameService",
	ActiveMatch = nil, -- this only allows for one match per server. ActiveMatches = {} would allow for palyer map keying
	Client = {
		MatchStateChanged = Knit.CreateSignal(),
		MatchTimelineUpdated = Knit.CreateSignal(),
		WaveScheduleUpdated = Knit.CreateSignal(),
		MatchSpeedChanged = Knit.CreateSignal(),
		WaveButtonUpdated = Knit.CreateSignal(),
		MatchCurrencyChanged = Knit.CreateSignal(),
	},
})
function GameService:KnitStart()
	ZombieService = Knit.GetService("ZombieService")
	BrainrotService = Knit.GetService("BrainrotService")

	local StartButton = Workspace:WaitForChild("StartButton")
	local ClickDetector = StartButton:FindFirstChildWhichIsA("ClickDetector", true)
	if ClickDetector then
		ClickDetector.MouseClick:Connect(function(Player)
			self:StartMatch(Player, "TestMap")
		end)
	end

	Players.PlayerRemoving:Connect(function(Player)
		if self.ActiveMatch and self.ActiveMatch.Player == Player then
			self:EndMatch()
		end
	end)
end

function GameService:CreateMatch(Player, MapName) --for now, MapName = "TestMap"
	local Service = self -- GameService
	local Config = require(MapsFolder:FindFirstChild(MapName)) --MapsFolder is contained within ReplicatedStorage
	local Area = Workspace:FindFirstChild(Config.Area) -- "TestingGameArea"
	local CurrencyConfig = require(GamemodesFolder:FindFirstChild(Config.Gamemode)).Currency
	
	local BrainrotsFolder = Instance.new("Folder")
	BrainrotsFolder.Name = "Brainrots"
	BrainrotsFolder.Parent = Area

	local PlayerSpawns = Area.PlayerSpawns:GetChildren()
	local ZombieSpawns = Area.ZombieSpawns:GetChildren()
	local ZombieStart = ZombieSpawns[1].Position
	local ZombieEnd = PlayerSpawns[1].Position

	local AttackForward = Vector3.new(0, 0, 1)
	if #ZombieSpawns > 0 then
		AttackForward = ((ZombieStart - ZombieEnd) * Vector3.new(1, 0, 1)).Unit
	end

	local Match = {
		Player = Player,
		PlayerSpawns = PlayerSpawns, --Passes PlayerSpawns children back to startmatch
		Config = Config,
		Area = Area,
		BrainrotsFolder = BrainrotsFolder,
		ZombieStart = ZombieStart,
		ZombieEnd = ZombieEnd,
		AttackForward = AttackForward,
		Wave = 0,
		Phase = "Idle",
		Active = true,
		Paused = false,
		SpeedMultiplier = 1,
		CurrencyConfig = CurrencyConfig,
		Currency = CurrencyConfig.StartingAmount,
		Zombies = {},
		NextZombieId = 0,
		PlacedBrainrots = {},
		NextBrainrotId = 0,
		OccupiedCells = {},
		PlacementCounts = {},
		WaveButtonVisible = false,
		WaveButtonMode = "Start",
		NextWaveRequested = false,
		ActiveWaveState = nil,
	}

	function Match:NotifyState()
		Service.Client.MatchStateChanged:Fire(self.Player, {
			Wave = self.Wave,
			TotalWaves = self.Config.Waves.Count,
			Phase = self.Phase,
		})
	end

	function Match:NotifyTimeline(TotalWaves, FlagWaves)
		Service.Client.MatchTimelineUpdated:Fire(self.Player, {
			TotalWaves = TotalWaves,
			FlagWaves = FlagWaves,
		})
	end

	function Match:NotifySchedule(WaveDuration)
		Service.Client.WaveScheduleUpdated:Fire(self.Player, {
			WaveDuration = WaveDuration,
		})
	end

	function Match:NotifySpeed()
		Service.Client.MatchSpeedChanged:Fire(self.Player, {
			Paused = self.Paused,
			SpeedMultiplier = self.SpeedMultiplier,
		})
	end

	function Match:NotifyWaveButton()
		Service.Client.WaveButtonUpdated:Fire(self.Player, {
			Visible = self.WaveButtonVisible,
			Mode = self.WaveButtonMode,
		})
	end

	function Match:NotifyCurrency()
		Service.Client.MatchCurrencyChanged:Fire(self.Player, {
			Currency = self.Currency,
		})
	end

	function Match:AddCurrency(Amount)
		self.Currency = math.max(self.Currency + Amount, 0)
		self:NotifyCurrency()
	end

	function Match:SetWaveButtonEligible(Mode)
		self.WaveButtonVisible = true
		self.WaveButtonMode = Mode
		self:NotifyWaveButton()
	end

	function Match:HideWaveButton()
		self.WaveButtonVisible = false
		self:NotifyWaveButton()
	end

	function Match:RequestNextWave()
		if not self.WaveButtonVisible then return end
		self.NextWaveRequested = true
	end

	function Match:AwaitWaveStartRequest()
		self.NextWaveRequested = false
		while not self.NextWaveRequested and self.Active do
			task.wait()
		end
		self:HideWaveButton()
	end

	function Match:AwaitWaveClear(WaveState)
		while WaveState.ZombiesAlive > 0 and self.Active do
			task.wait()
		end
	end

	function Match:BeginWave(WaveNumber, TotalHP)
		local WaveState = {
			Number = WaveNumber,
			TotalHP = TotalHP,
			RemainingHP = TotalHP,
			ZombiesAlive = 0,
			Paid = false,
		}
		self.ActiveWaveState = WaveState
		return WaveState
	end

	function Match:RegisterWaveZombie(WaveState)
		WaveState.ZombiesAlive += 1
	end

	function Match:UnregisterWaveZombie(WaveState)
		WaveState.ZombiesAlive -= 1

		if WaveState.ZombiesAlive <= 0 and not WaveState.Paid then
			WaveState.Paid = true
			self:AddCurrency(Currency.ComputeWaveCompleteIncome(self.CurrencyConfig, WaveState.Number))
		end

		self:CheckWaveEligibility(WaveState)
	end

	function Match:CheckWaveEligibility(WaveState)
		if self.ActiveWaveState ~= WaveState then return end
		if self.WaveButtonVisible then return end

		if WaveState.ZombiesAlive <= 0 then
			self:SetWaveButtonEligible("Start")
		elseif WaveState.RemainingHP <= WaveState.TotalHP * 0.25 then
			self:SetWaveButtonEligible("Skip")
		end
	end

	function Match:SetPaused(NewPaused)
		if self.Paused == NewPaused then return end
		self.Paused = NewPaused
		self:NotifySpeed()
	end

	function Match:SetSpeedMultiplier(NewMultiplier)
		if self.SpeedMultiplier == NewMultiplier then return end
		self.SpeedMultiplier = NewMultiplier
		self:NotifySpeed()
	end

	function Match:Wait(Duration)
		local Elapsed = 0
		while Elapsed < Duration and self.Active do
			local Delta = task.wait()
			if not self.Paused then
				Elapsed += Delta * self.SpeedMultiplier
			end
		end
	end

	function Match:Cleanup()
		ZombieService:ClearMatch(self)
		BrainrotService:ClearMatch(self)

		if self.BrainrotsFolder then
			self.BrainrotsFolder:Destroy()
			self.BrainrotsFolder = nil
		end
		table.clear(self.OccupiedCells)
		table.clear(self.PlacementCounts)

		if Service.ActiveMatch == self then
			Service.ActiveMatch = nil
		end
	end

	return Match
end

function GameService:GetActiveMatch()
	return self.ActiveMatch
end

function GameService:StartMatch(Player, MapName)
	if self.ActiveMatch then return end

	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not Root then return end

	local Match = self:CreateMatch(Player, MapName)
	if not Match then return end
	self.ActiveMatch = Match

	Root.CFrame = Match.PlayerSpawns[1].CFrame + Vector3.new(0, 3, 0) --spawns at only the middle square for now


	Match:NotifyState()
	Match:NotifySpeed()
	Match:NotifyCurrency()

	task.spawn(function()
		local Gamemode = require(GamemodesFolder:FindFirstChild(Match.Config.Gamemode))
		Gamemode.Run(Match)
	end)
end

function GameService:EndMatch()
	local Match = self.ActiveMatch
	if not Match then return end

	Match.Active = false
	Match:Cleanup()
end

function GameService:RequestNextWave(Player)
	local Match = self.ActiveMatch
	if Match and Match.Player == Player and Match.Active then
		Match:RequestNextWave()
	end
end

function GameService.Client:StartNextWave(Player)
	self.Server:RequestNextWave(Player)
end

function GameService:RequestTogglePause(Player)
	local Match = self.ActiveMatch
	if Match and Match.Player == Player and Match.Active then
		Match:SetPaused(not Match.Paused)
	end
end

function GameService.Client:TogglePause(Player)
	self.Server:RequestTogglePause(Player)
end

function GameService:RequestCycleSpeed(Player)
	local Match = self.ActiveMatch
	if not (Match and Match.Player == Player and Match.Active) then return end

	local CurrentIndex = table.find(SpeedSteps, Match.SpeedMultiplier) or 1
	local NextIndex = CurrentIndex % #SpeedSteps + 1
	Match:SetSpeedMultiplier(SpeedSteps[NextIndex])
end

function GameService.Client:CycleSpeed(Player)
	self.Server:RequestCycleSpeed(Player)
end

return GameService
