return {
	DisplayName = "Test Map",
	Area = "TestingGameArea",
	Gamemode = "Standard",
	Modifiers = {},

	MaxUnitPlacements = 3,

	Waves = {
		Count = 5,
		FlagWaves = {3, 5},

		BaseBudget = 1,
		WaveGrowthFactor = 1,
		FlagWaveMultiplier = 3,

		UnlockSchedule = {
			[1] = {"PlaceholderBasicZombie"},
		},

		SpawnIntervalMin = 2,
		SpawnIntervalMax = 5,
		FlagSpawnIntervalMin = 0.2,
		FlagSpawnIntervalMax = 0.5,

		IntermissionDuration = 15,
		ZombieSpeed = 8,
	},
}
