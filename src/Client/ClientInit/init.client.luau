-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)

Knit.AddControllers(script.Controllers)
Knit.AddControllers(script.Controllers.InterfaceController)
Knit:Start():andThen(function()
	warn("[KNIT CLIENT STARTED]")
end)