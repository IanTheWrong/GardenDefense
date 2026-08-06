local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local Players = game:GetService("Players")

local InterfaceController = Knit.CreateController {
	Name = "InterfaceController",
}

local ButtonsFrame
local TabMap
local TouchMap
local ActiveTab = nil

function InterfaceController:CloseActive()
	if ActiveTab then
		ActiveTab:Close()
		ActiveTab = nil
	end
end

function InterfaceController:OpenTab(TabController)
	if ActiveTab == TabController then
		self:CloseActive()
		return
	end

	self:CloseActive()

	TabController:Open()
	ActiveTab = TabController
end

function InterfaceController:KnitInit()
	local Player = Players.LocalPlayer
	local Interface = Player:WaitForChild("PlayerGui"):WaitForChild("uiInterface")
	ButtonsFrame = Interface:WaitForChild("Buttons")
end

function InterfaceController:KnitStart()
	local GachaController = Knit.GetController("GachaController")
	local InventoryController = Knit.GetController("InventoryController")

	TabMap = {
		InventoryButton = InventoryController,
	}

	TouchMap = {
		[workspace:WaitForChild("Areas").GachaArea] = GachaController,
	}

	for ButtonName, TabController in TabMap do
		local Button = ButtonsFrame:FindFirstChild(ButtonName)
		if Button then
			Button.Activated:Connect(function()
				self:OpenTab(TabController)
			end)
		end
	end

	for Part, TabController in TouchMap do
		local Touching = false

		Part.Touched:Connect(function()
			if Touching then return end
			Touching = true
			
			self:OpenTab(TabController)
		end)

		Part.TouchEnded:Connect(function()
			if not Touching then return end
			Touching = false
			
			if ActiveTab == TabController then
				self:CloseActive()
			end
		end)
	end
end

return InterfaceController