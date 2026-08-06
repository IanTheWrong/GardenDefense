local RunService = game:GetService("RunService")

local container = script.Parent
local rotationSpeed = 120

local gradients = {}

local function registerGradient(object)
	if object:IsA("UIGradient")
		and object.Parent:IsA("UIStroke")
		and object.Parent.Name == "AnimatedStroke" then

		table.insert(gradients, object)
	end
end

-- Find existing gradients
for _, object in ipairs(container:GetDescendants()) do
	registerGradient(object)
end

-- Detect gradients added later
container.DescendantAdded:Connect(registerGradient)

-- Rotate gradients
RunService.RenderStepped:Connect(function(deltaTime)
	for _, gradient in ipairs(gradients) do
		if gradient.Parent then
			gradient.Rotation = (gradient.Rotation + rotationSpeed * deltaTime) % 360
		end
	end
end)