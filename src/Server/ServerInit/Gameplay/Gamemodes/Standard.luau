local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)
local ZombieTypes = require(ReplicatedStorage.Game.Modules.ZombieTypes)

local ZombieService = Knit.GetService("ZombieService")

local Standard = {}

Standard.Currency = {
	StartingAmount = 500,

	KillIncome = {
		BaseRate = 1,
		DecayThresholds = {
			{Wave = 1, Multiplier = 1},
			{Wave = 30, Multiplier = 0.75},
			{Wave = 50, Multiplier = 0.5},
		},
	},

	WaveCompleteIncome = {
		BaseAmount = 100,
		Scalar = 1,
	},
}

local function BuildPool(UnlockSchedule, WaveNumber)
	local Pool = {}

	for UnlockWave, Types in UnlockSchedule do
		if UnlockWave <= WaveNumber then
			for _, TypeKey in Types do
				table.insert(Pool, TypeKey)
			end
		end
	end

	return Pool
end

local function ComputeBudget(Waves, WaveNumber, IsFlagWave)
	local Budget = Waves.BaseBudget + Waves.WaveGrowthFactor * (WaveNumber - 1)

	if IsFlagWave then
		Budget *= Waves.FlagWaveMultiplier
	end

	return Budget
end

local function PickWeighted(Pool)
	local TotalWeight = 0
	for _, TypeKey in Pool do
		TotalWeight += ZombieTypes[TypeKey].Weight
	end

	if TotalWeight <= 0 then
		return Pool[1]
	end

	local Roll = math.random() * TotalWeight
	local Cumulative = 0

	for _, TypeKey in Pool do
		Cumulative += ZombieTypes[TypeKey].Weight
		if Roll <= Cumulative then
			return TypeKey
		end
	end

	return Pool[#Pool]
end

local function BuildComposition(Pool, Budget)
	local WeightedPool = {}
	for _, TypeKey in Pool do
		if ZombieTypes[TypeKey].Weight > 0 then
			table.insert(WeightedPool, TypeKey)
		end
	end

	local Composition = {}
	local Remaining = Budget

	while Remaining > 0 and #WeightedPool > 0 do
		local TypeKey = PickWeighted(WeightedPool)
		table.insert(Composition, TypeKey)
		Remaining -= ZombieTypes[TypeKey].Cost
	end

	return Composition
end

local function GenerateSpawnOffsets(Count, Min, Max)
	local Offsets = {}
	local Elapsed = 0

	for Index = 1, Count do
		Elapsed += Min + math.random() * (Max - Min)
		Offsets[Index] = Elapsed
	end

	return Offsets, Elapsed
end

local function ComputeWaveHP(Composition, IsFlagWave)
	local TotalHP = 0

	for _, TypeKey in Composition do
		TotalHP += ZombieTypes[TypeKey].HP
	end

	if IsFlagWave then
		TotalHP += ZombieTypes.PlaceholderFlagZombie.HP
	end

	return TotalHP
end

function Standard.Run(Match)
	local Waves = Match.Config.Waves
	local Spawns = Match.Area.ZombieSpawns:GetChildren()

	local FlagWaveSet = {}
	for _, WaveNumber in Waves.FlagWaves do
		FlagWaveSet[WaveNumber] = true
	end

	Match:NotifyTimeline(Waves.Count, Waves.FlagWaves)

	local LastWaveState = nil

	for WaveNumber = 1, Waves.Count do
		if not Match.Active then break end

		if WaveNumber == 1 then
			Match:SetWaveButtonEligible("Start")
		end

		Match:AwaitWaveStartRequest()
		if not Match.Active then break end

		local IsFlagWave = FlagWaveSet[WaveNumber] == true

		Match.Wave = WaveNumber
		Match.Phase = "Wave"
		Match:NotifyState()

		local Pool = BuildPool(Waves.UnlockSchedule, WaveNumber)
		local Budget = ComputeBudget(Waves, WaveNumber, IsFlagWave)
		local Composition = BuildComposition(Pool, Budget)
		local TotalHP = ComputeWaveHP(Composition, IsFlagWave)
		local WaveState = Match:BeginWave(WaveNumber, TotalHP)
		LastWaveState = WaveState

		local IntervalMin = IsFlagWave and Waves.FlagSpawnIntervalMin or Waves.SpawnIntervalMin
		local IntervalMax = IsFlagWave and Waves.FlagSpawnIntervalMax or Waves.SpawnIntervalMax
		local Offsets, WaveDuration = GenerateSpawnOffsets(#Composition, IntervalMin, IntervalMax)

		Match:NotifySchedule(WaveDuration)

		if IsFlagWave then
			local FlagSpawnPart = Spawns[math.random(1, #Spawns)]
			ZombieService:SpawnZombie(Match, WaveState, FlagSpawnPart, Waves.ZombieSpeed, ZombieTypes.PlaceholderFlagZombie.Model)
		end

		local PreviousOffset = 0
		for Index, TypeKey in Composition do
			if not Match.Active then break end
			Match:Wait(Offsets[Index] - PreviousOffset)
			PreviousOffset = Offsets[Index]

			local SpawnPart = Spawns[math.random(1, #Spawns)]
			local ZombieType = ZombieTypes[TypeKey]
			ZombieService:SpawnZombie(Match, WaveState, SpawnPart, Waves.ZombieSpeed, ZombieType.Model)
		end

		if WaveNumber < Waves.Count then
			Match.Phase = "Intermission"
			Match:NotifyState()
		end
	end

	if LastWaveState then
		Match:AwaitWaveClear(LastWaveState)
	end

	Match:HideWaveButton()
	Match.Phase = "Ended"
	Match:NotifyState()
	Match:Cleanup()
end

return Standard
