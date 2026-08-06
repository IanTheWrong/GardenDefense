local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Knit = require(RS.Game.Knit.Knit)
local CmdrConfig = require(RS.Game.Modules.CmdrConfig)

local CmdrController = Knit.CreateController({
	Name = "CmdrController"
})

function CmdrController:KnitStart()
	local Player = Players.LocalPlayer
	
	if table.find(CmdrConfig.Owners, Player.UserId) then
		local CmdrClient = require(RS:WaitForChild("CmdrClient"))
		CmdrClient:SetActivationKeys({Enum.KeyCode.F2})
	end
end

return CmdrController