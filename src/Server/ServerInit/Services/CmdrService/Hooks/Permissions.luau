local RS = game:GetService("ReplicatedStorage")

local CmdrConfig = require(RS.Game.Modules.CmdrConfig)

return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		local UserId = context.Executor.UserId
		local IsOwner = table.find(CmdrConfig.Owners, UserId)
		local IsOwnerCmd = context.Group == "Owner"
		
		if IsOwnerCmd and not IsOwner then
			return "You do not have permission to use this command."
		end
		
		if not IsOwner then
			return "You do not have permission to use this command."
		end
	end)
end