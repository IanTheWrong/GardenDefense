local button = script.Parent
local menu = script.Parent.Parent.Parent.Parent.inventory

button.MouseButton1Click:Connect(function()
	menu.Visible = not menu.Visible
end)