local TweenService = game:GetService("TweenService")

local tweenInfo = TweenInfo.new(
	0.2,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local function setupButton(button)
	if not button:IsA("GuiButton") then return end

	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = button
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, tweenInfo, {Scale = 1.1}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, tweenInfo, {Scale = 1}):Play()
	end)
end


for _, obj in ipairs(script.Parent:GetDescendants()) do
	setupButton(obj)
end


script.Parent.DescendantAdded:Connect(setupButton)