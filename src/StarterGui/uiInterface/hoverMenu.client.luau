
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local gui = script.Parent
local scrollFrame = gui:WaitForChild("cardDisplay")
local menu = gui:WaitForChild("inventoryPopup")

menu.Visible = false

local titleLabel = menu:FindFirstChildWhichIsA("TextLabel")

local function showMenu(button)
	if titleLabel then
		titleLabel.Text = button.Name
	end

	menu.Visible = true
end

local function hideMenu()
	menu.Visible = false
end

RunService.RenderStepped:Connect(function()
	if menu.Visible then
		local mousePos = UserInputService:GetMouseLocation()
		menu.Position = UDim2.new(0, mousePos.X + 15, 0, mousePos.Y + 15)
	end
end)

local function hook(button)
	if not button:IsA("GuiButton") then return end
	
	print("Hooked:", button:GetFullName())

	button.MouseEnter:Connect(function()
		showMenu(button)
		print("Hover script is running")

		
	end)

	button.MouseLeave:Connect(function()
		hideMenu()
	end)
end

for _, obj in pairs(scrollFrame:GetDescendants()) do
	hook(obj)
end

scrollFrame.DescendantAdded:Connect(hook)