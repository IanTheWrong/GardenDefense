local Hitbox = {}

function Hitbox.Create(TargetCFrame, Size, CollisionGroup, Attributes, Parent, Visualize)
	local IsSphere = typeof(Size) == "number"

	local Part = Instance.new("Part")
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = true
	Part.CanTouch = false
	Part.Massless = true
	Part.Shape = IsSphere and Enum.PartType.Ball or Enum.PartType.Block
	Part.Size = IsSphere and Vector3.new(Size, Size, Size) or Size
	Part.CFrame = TargetCFrame
	Part.CollisionGroup = CollisionGroup

	if Visualize then
		Part.Transparency = 0.5
		Part.Color = Color3.new(1, 0, 0)
	else
		Part.Transparency = 1
	end

	if Attributes then
		for AttributeName, AttributeValue in Attributes do
			Part:SetAttribute(AttributeName, AttributeValue)
		end
	end

	Part.Parent = Parent or workspace

	return Part
end

function Hitbox.QueryRadius(Position, Radius, SearchFolder)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { SearchFolder }

	return workspace:GetPartBoundsInRadius(Position, Radius, Params)
end

function Hitbox.QueryBox(TargetCFrame, Size, SearchFolder)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { SearchFolder }

	return workspace:GetPartBoundsInBox(TargetCFrame, Size, Params)
end

return Hitbox
