-- SERVICES --
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Game.Knit.Knit)

Knit.AddServices(script.Services)
Knit:Start():andThen(function()
	warn("[KNIT SERVER STARTED]")
end)