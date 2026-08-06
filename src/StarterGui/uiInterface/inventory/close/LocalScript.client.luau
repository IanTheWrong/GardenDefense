local button = script.Parent
local menu = script.parent.parent

button.MouseButton1Click:Connect(function()
	menu.Visible = not menu.Visible
end)