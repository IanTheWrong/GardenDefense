local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameInterfaceController = Knit.CreateController {
	Name = "GameInterfaceController",
}

local MatchUI
local WaveBar
local WaveBarFill
local IndicatorTemplate
local WaveText
local StartStopButton
local SpeedUpButton
local SpeedModifierText
local WaveButton
local CurrencyLabel

local GameService

local FillTween
local Indicators = {}

local TotalWaves = 1
local CurrentWave = 1
local CurrentPhase = "Idle"

local WaveStartFraction = 0
local WaveEndFraction = 0
local WaveDuration1x = 0
local ElapsedBeforeSegment = 0
local SegmentStartClock = 0

local Paused = false
local Speed = 1

local function ClearIndicators()
	for _, Indicator in Indicators do
		Indicator:Destroy()
	end
	table.clear(Indicators)
end

local function StopFillTween()
	if FillTween then
		FillTween:Cancel()
		FillTween = nil
	end
end

local function SetFillFraction(Fraction)
	WaveBarFill.Size = UDim2.new(Fraction, 0, 1, 0)
end

local function UpdateWaveText()
	WaveText.Text = string.format("Wave %d/%d", CurrentWave, TotalWaves)
end

local function UpdateStartStopText()
	StartStopButton.Text = Paused and "Resume" or "Pause"
end

local function UpdateSpeedText()
	SpeedModifierText.Text = string.format("%.1fx", Speed)
end

local function OnWaveButtonUpdated(Data)
	WaveButton.Visible = Data.Visible
	WaveButton.Text = Data.Mode == "Skip" and "Skip Wave" or "Start Wave"
end

local function OnCurrencyChanged(Data)
	CurrencyLabel.Text = "$" .. Data.Currency
end

local function SegmentElapsed()
	if not FillTween or Paused then return 0 end
	return (os.clock() - SegmentStartClock) * Speed
end

local function FoldElapsedIntoBase()
	ElapsedBeforeSegment = math.min(WaveDuration1x, ElapsedBeforeSegment + SegmentElapsed())
end

local function StartSegmentTween()
	StopFillTween()
	if Paused then return end

	local Remaining1x = WaveDuration1x - ElapsedBeforeSegment
	if Remaining1x <= 0 then
		SetFillFraction(WaveEndFraction)
		return
	end

	SegmentStartClock = os.clock()
	FillTween = TweenService:Create(WaveBarFill, TweenInfo.new(Remaining1x / Speed, Enum.EasingStyle.Linear), {
		Size = UDim2.new(WaveEndFraction, 0, 1, 0),
	})
	FillTween:Play()
end

local function OnTimelineUpdated(Data)
	StopFillTween()
	ClearIndicators()

	TotalWaves = Data.TotalWaves
	SetFillFraction(0)

	for _, FlagWaveNumber in Data.FlagWaves do
		local Fraction = (FlagWaveNumber - 1) / TotalWaves
		local Indicator = IndicatorTemplate:Clone()
		Indicator.Position = UDim2.new(1 - Fraction, 0, IndicatorTemplate.Position.Y.Scale, IndicatorTemplate.Position.Y.Offset)
		Indicator.Visible = true
		Indicator.Parent = WaveBar
		table.insert(Indicators, Indicator)
	end
end

local function OnScheduleUpdated(Data)
	WaveStartFraction = (CurrentWave - 1) / TotalWaves
	WaveEndFraction = CurrentWave / TotalWaves
	WaveDuration1x = Data.WaveDuration
	ElapsedBeforeSegment = 0

	SetFillFraction(WaveStartFraction)
	StartSegmentTween()
end

local function OnMatchStateChanged(State)
	MatchUI.Visible = true
	CurrentWave = State.Wave
	CurrentPhase = State.Phase
	UpdateWaveText()

	if State.Phase == "Wave" then
		WaveBar.Visible = true
	elseif State.Phase == "Intermission" then
		StopFillTween()
		SetFillFraction(State.Wave / TotalWaves)
	elseif State.Phase == "Idle" then
		StopFillTween()
		ClearIndicators()
		WaveBar.Visible = false
	elseif State.Phase == "Ended" then
		StopFillTween()
		SetFillFraction(1)
	end
end

local function OnSpeedChanged(Data)
	if CurrentPhase == "Wave" then
		FoldElapsedIntoBase()
	end

	Paused = Data.Paused
	Speed = Data.SpeedMultiplier

	UpdateStartStopText()
	UpdateSpeedText()

	if CurrentPhase == "Wave" then
		StartSegmentTween()
	end
end

function GameInterfaceController:KnitInit()
	local Interface = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("uiInterface")
	MatchUI = Interface:WaitForChild("MatchUI")
	WaveButton = MatchUI:WaitForChild("WaveButton")
	WaveBar = MatchUI:WaitForChild("WaveBar")
	WaveBarFill = WaveBar:WaitForChild("WaveBarFill")
	IndicatorTemplate = WaveBar:WaitForChild("ZombieSpawnIndicator")
	WaveText = WaveBar:WaitForChild("WaveText")
	StartStopButton = WaveBar:WaitForChild("StartStopButton")
	SpeedUpButton = WaveBar:WaitForChild("SpeedUpButton")
	SpeedModifierText = WaveBar:WaitForChild("SpeedModifierText")
	CurrencyLabel = MatchUI:WaitForChild("CurrencyLabel")

	IndicatorTemplate.Visible = false

	WaveBarFill.AnchorPoint = Vector2.new(1, 0)
	WaveBarFill.Position = UDim2.new(1, 0, 0, 0)
	WaveBarFill.Size = UDim2.new(0, 0, 1, 0)

	WaveBar.Visible = false
	WaveButton.Visible = false
	MatchUI.Visible = false

	UpdateWaveText()
	UpdateStartStopText()
	UpdateSpeedText()
end

function GameInterfaceController:KnitStart()
	GameService = Knit.GetService("GameService")

	GameService.MatchStateChanged:Connect(OnMatchStateChanged)
	GameService.MatchTimelineUpdated:Connect(OnTimelineUpdated)
	GameService.WaveScheduleUpdated:Connect(OnScheduleUpdated)
	GameService.MatchSpeedChanged:Connect(OnSpeedChanged)
	GameService.WaveButtonUpdated:Connect(OnWaveButtonUpdated)
	GameService.MatchCurrencyChanged:Connect(OnCurrencyChanged)

	StartStopButton.MouseButton1Click:Connect(function()
		GameService:TogglePause()
	end)

	SpeedUpButton.MouseButton1Click:Connect(function()
		GameService:CycleSpeed()
	end)

	WaveButton.MouseButton1Click:Connect(function()
		GameService:StartNextWave()
	end)
end

return GameInterfaceController
