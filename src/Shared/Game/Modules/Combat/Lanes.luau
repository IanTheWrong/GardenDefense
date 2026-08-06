local CollectionService = game:GetService("CollectionService")

local Lanes = {}

local function ExtractLaneNumber(Text)
	return Text:match("^Lane(%d+)")
end

function Lanes.Resolve(Instance)
	local Current = Instance

	while Current do
		for _, Tag in CollectionService:GetTags(Current) do
			local LaneNumber = ExtractLaneNumber(Tag)
			if LaneNumber then
				return tonumber(LaneNumber)
			end
		end

		local LaneNumber = ExtractLaneNumber(Current.Name)
		if LaneNumber then
			return tonumber(LaneNumber)
		end

		Current = Current.Parent
	end

	return nil
end

return Lanes
