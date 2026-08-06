local RunService = game:GetService("RunService")
local imageLabel = script.Parent

local scrollSpeed = 30
local tileSize = 150

local currentOffset = 0

RunService.RenderStepped:Connect(function(deltaTime)
	currentOffset = currentOffset - (scrollSpeed * deltaTime)

	if currentOffset <= -tileSize then
		currentOffset = currentOffset + tileSize
	end

	imageLabel.Position = UDim2.new(0, currentOffset, 0, currentOffset)
end)
