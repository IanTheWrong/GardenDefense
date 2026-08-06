local Currency = {}

local function ResolveDecayMultiplier(DecayThresholds, WaveNumber)
	local Multiplier = 1
	local BestWave = -math.huge

	for _, Threshold in DecayThresholds do
		if Threshold.Wave <= WaveNumber and Threshold.Wave > BestWave then
			BestWave = Threshold.Wave
			Multiplier = Threshold.Multiplier
		end
	end

	return Multiplier
end

function Currency.ComputeKillIncome(CurrencyConfig, ZombieValue, WaveNumber)
	local KillIncome = CurrencyConfig.KillIncome
	local Multiplier = ResolveDecayMultiplier(KillIncome.DecayThresholds, WaveNumber)

	return math.floor(KillIncome.BaseRate * ZombieValue * Multiplier)
end

function Currency.ComputeWaveCompleteIncome(CurrencyConfig, WaveNumber)
	local WaveCompleteIncome = CurrencyConfig.WaveCompleteIncome

	return math.floor(WaveCompleteIncome.BaseAmount + WaveCompleteIncome.Scalar * WaveNumber)
end

return Currency
