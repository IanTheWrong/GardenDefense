local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewportsFolder = ReplicatedStorage.Game.Assets.Models:WaitForChild("Viewports")

local GachaController = Knit.CreateController {
	Name = "GachaController",
}

local GachaScreen
local CycleLeftButton
local CycleRightButton
local OnePullButton
local SummonedLabel

local Cycling = false

local BannerService

local FrameToBanner = {}

local Slots = {
	Left = nil,
	Selected = nil,
	Right = nil,
}

local SlotProperties = {}

local function CaptureSlot(Frame)
	return {
		Position = Frame.Position,
		Size = Frame.Size,
		BackgroundColor3 = Frame.BackgroundColor3,
		ZIndex = Frame.ZIndex,
	}
end

local CycleTweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function TweenToSlot(Frame, Slot)
	return TweenService:Create(Frame, CycleTweenInfo, {
		Position = SlotProperties[Slot].Position,
		Size = SlotProperties[Slot].Size,
		BackgroundColor3 = SlotProperties[Slot].BackgroundColor3,
	})
end

local function SnapToSlot(Frame, Slot)
	local Props = SlotProperties[Slot]
	Frame.Position = Props.Position
	Frame.Size = Props.Size
	Frame.BackgroundColor3 = Props.BackgroundColor3
	Frame.ZIndex = Props.ZIndex
end

local SlotRing = {"Selected", "Right", "Left"}

local function DoCycle(Step)
	if Cycling then return end
	Cycling = true

	local Current = {}
	for _, Slot in SlotRing do
		Current[Slot] = Slots[Slot]
	end

	local NewSlots = {}
	local Tweens = {}
	for Index, Slot in SlotRing do
		local Target = SlotRing[((Index - 1 + Step) % #SlotRing) + 1]
		local Frame = Current[Slot]
		Frame.ZIndex = SlotProperties[Target].ZIndex
		NewSlots[Target] = Frame
		table.insert(Tweens, TweenToSlot(Frame, Target))
	end

	for _, Tween in Tweens do
		Tween:Play()
	end

	Tweens[1].Completed:Wait()

	for Slot, Frame in NewSlots do
		Slots[Slot] = Frame
	end

	Cycling = false
end

local function DoCycleRight()
	DoCycle(1)
end

local function DoOnePull()
	local Banner = FrameToBanner[Slots.Selected]
	if not Banner then return end

	local Result = BannerService:Roll(Banner.Name, 1):expect()
	if not Result.Success then return end

	local Reward = Result.Rewards[1]
	SummonedLabel.Text = if Reward.IsDuplicate then "Duplicate" else Reward.DisplayName
	SummonedLabel.Visible = true
	task.wait(1)
	SummonedLabel.Visible = false
end

local function DoCycleLeft()
	DoCycle(-1)
end

local function SetupBannerViewport(ViewportFrame, BannerName)
	local WorldModel = ViewportFrame:FindFirstChild("WorldModel")
	if not WorldModel then return end

	WorldModel:ClearAllChildren()

	local OldCamera = ViewportFrame:FindFirstChildOfClass("Camera")
	if OldCamera then
		OldCamera:Destroy()
	end

	local Source = ViewportsFolder:FindFirstChild(BannerName .. "Viewport")
	if not Source then return end

	local Model = Source:Clone()
	Model.Parent = WorldModel

	local Camera = Instance.new("Camera")
	local CameraPart = Model:FindFirstChild("ViewportCameraPart", true)
	if CameraPart then
		Camera.CFrame = CameraPart.CFrame
		CameraPart:Destroy()
	end

	Camera.Parent = ViewportFrame
	ViewportFrame.CurrentCamera = Camera
end

function GachaController:RefreshBanners()
	if not self.ActiveBanners then return end

	local Frames = {Slots.Left, Slots.Selected, Slots.Right}
	for Index, Frame in Frames do
		local Banner = self.ActiveBanners[Index]
		if Banner then
			FrameToBanner[Frame] = Banner
			Frame:SetAttribute("BannerName", Banner.Name)
			Frame:SetAttribute("DisplayName", Banner.DisplayName)
			SetupBannerViewport(Frame, Banner.Name)
		end
	end
end

function GachaController:Open()
	GachaScreen.Visible = true
end

function GachaController:Close()
	GachaScreen.Visible = false
end

function GachaController:KnitInit()
	local Interface = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("uiInterface")
	GachaScreen = Interface:WaitForChild("gachaScreen")
	CycleLeftButton = GachaScreen:WaitForChild("CycleLeft")
	CycleRightButton = GachaScreen:WaitForChild("CycleRight")

	Slots.Left = GachaScreen:WaitForChild("Banner1")
	Slots.Selected = GachaScreen:WaitForChild("SelectedBanner")
	Slots.Right = GachaScreen:WaitForChild("Banner2")

	SlotProperties.Left = CaptureSlot(Slots.Left)
	SlotProperties.Selected = CaptureSlot(Slots.Selected)
	SlotProperties.Right = CaptureSlot(Slots.Right)

	OnePullButton = GachaScreen:WaitForChild("1Pull")
	SummonedLabel = GachaScreen:WaitForChild("SummonedLabel")

	GachaScreen.Visible = false
end

function GachaController:KnitStart()
	BannerService = Knit.GetService("BannerService")

	CycleLeftButton.Activated:Connect(DoCycleLeft)
	CycleRightButton.Activated:Connect(DoCycleRight)
	OnePullButton.Activated:Connect(DoOnePull)

	BannerService:GetActiveBanners():andThen(function(Banners)
		self.ActiveBanners = Banners
		self:RefreshBanners()
	end)

	BannerService.ActiveBannersChanged:Connect(function(Banners)
		self.ActiveBanners = Banners
		self:RefreshBanners()
	end)
end

return GachaController