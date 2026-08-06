local RS = game:GetService("ReplicatedStorage")

local Knit = require(RS.Game.Knit.Knit)

local CmdrService = Knit.CreateService({
	Name = "CmdrService";
	Client = {}
})

function CmdrService:KnitStart()
	local Cmdr = require(script.Parent.Parent.Libraries.Cmdr)
	
	Cmdr:RegisterDefaultCommands()
	Cmdr:RegisterCommandsIn(script.Commands)
	Cmdr:RegisterTypesIn(script.Types)
	Cmdr:RegisterHooksIn(script.Hooks)
end

return CmdrService