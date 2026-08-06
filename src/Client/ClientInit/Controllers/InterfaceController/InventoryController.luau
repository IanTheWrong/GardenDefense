local Knit = require(game:GetService("ReplicatedStorage").Game.Knit.Knit)
local Players = game:GetService("Players")

local InventoryController = Knit.CreateController {
	Name = "InventoryController",
}

local InventoryFrame
local InventoryPopup

function InventoryController:Open()
	InventoryFrame.Visible = true
end

function InventoryController:Close()
	InventoryFrame.Visible = false
	--InventoryPopup.Visible = false
end

function InventoryController:KnitInit()
	local Interface = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("uiInterface")
	InventoryFrame = Interface:WaitForChild("inventory")
	--InventoryPopup = InventoryFrame:WaitForChild("inventoryPopup")

	InventoryFrame.Visible = false
	--InventoryPopup.Visible = false
end

return InventoryController