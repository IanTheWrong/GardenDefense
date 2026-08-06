--!native
local packetIDs = require(script.Parent.Parent.namespaces.packetIDs)
local queryIDs = require(script.Parent.Parent.namespaces.queryIDs)
local readRefs = require(script.Parent.readRefs)

local packetRef = packetIDs.ref()
local queryRef = queryIDs.ref()
local freeThread: thread?

local function functionPasser(callback, ...)
	local aquiredThread = freeThread
	freeThread = nil
	callback(...)
	freeThread = aquiredThread
end

local function yielder()
	while true do
		functionPasser(coroutine.yield())
	end
end

local function runListener(callback, ...)
	if freeThread == nil then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread :: thread)
	end

	task.spawn(freeThread :: thread, callback, ...)
end

local function runQueryListener(callback, ...)
	local result 
	if freeThread == nil then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread :: thread)
	end

	task.spawn(freeThread :: thread, function(...)
		result = callback(...)
	end, ...)
		
	return result
end

local errorNamespaces = {}

return function(incomingBuffer: buffer, references: { [number]: unknown }?, player: Player?, readType: string?)
	local length = buffer.len(incomingBuffer)
	local readCursor = 0
	readType = readType or "packet"

	readRefs.set(references)

	while readCursor < length do
		local readablePacketOrQuery
		
		if readType == "packet" then
			readablePacketOrQuery = packetRef[buffer.readu8(incomingBuffer, readCursor)]
		elseif readType == "query" then
			readablePacketOrQuery = queryRef[buffer.readu8(incomingBuffer, readCursor)]
		else
			warn("readType not valid. expect for [packets | queries], make sure network description in controller are in these readType.")
			--error("readType not valid.")
			return
		end
		
		--warn("type", readType, buffer.readu8(incomingBuffer, readCursor))
				
		if not readablePacketOrQuery then
			
			local readableEntityID = buffer.readu8(incomingBuffer, readCursor)

			if errorNamespaces[readableEntityID] then
				return
			end

			return pcall(function()
				local bytenetStorage = game.ReplicatedStorage:FindFirstChild("BytenetStorage")
				if bytenetStorage then
					for _, whichNamespace in bytenetStorage:GetChildren() do
						if whichNamespace:IsA("StringValue") then
							local namespace = game.HttpService:JSONDecode(whichNamespace.Value)
							local identifiedNamespace = nil
							for _, id in namespace.packets do
								if readableEntityID == id then
									errorNamespaces[readableEntityID] = whichNamespace
									break
								end
							end
							for _, id in namespace.queries do
								if readableEntityID == id then
									errorNamespaces[readableEntityID] = whichNamespace
									break
								end
							end
						end
					end
				end
				if typeof(errorNamespaces[readableEntityID]) == "Instance" then
					warn(errorNamespaces[readableEntityID], "make sure to require() this namespace that related to the controller in client-side.")
				end
			end)
			--error("No readable entity found for ID: " .. buffer.readu8(incomingBuffer, readCursor) .. " for type: " .. readType)
		else
			local readableEntityID = buffer.readu8(incomingBuffer, readCursor)

			if errorNamespaces[readableEntityID] then
				print(errorNamespaces[readableEntityID], "this namespace is now connected on client-side.")
				errorNamespaces[readableEntityID] = nil
			end
			
			readCursor += 1

			local value, valueLength = readablePacketOrQuery.reader(incomingBuffer, readCursor)

			readCursor += valueLength

			if readType == "packet" then
				for _, listener in readablePacketOrQuery.getListeners() do
					runListener(listener, value, player)
				end
			elseif readType == "query" then
				for _, listener in readablePacketOrQuery.getListeners() do
					local response = runQueryListener(listener, value, player)
					
					--print(response)
					
					return response
				end	
			end
		end
	end
end
