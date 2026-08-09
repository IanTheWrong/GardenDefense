local Placeholder1 = {}

function Placeholder1.OnPlaced(Entity, Match)
	if Entity.AttackForward then
		Entity:SetFacing(Entity.AttackForward)
	end
end

function Placeholder1.Heartbeat(Entity, Dt, Match)
	Entity.Cooldown = math.max((Entity.Cooldown or 0) - Dt, 0)
	if Entity.Cooldown > 0 then return end

	local NearestTarget = Entity:GetNearestForwardTarget(Entity.Stats.Range)
	if not NearestTarget then return end

	Entity.Cooldown = Entity.Stats.AttackCooldown

	local Hits = Entity:SpawnHitbox({
		Size = Vector3.new(6, 6, 6),
		Offset = CFrame.new(0, 0, -3),
	})

	for _, Part in Hits do
		local TargetID = Part:GetAttribute("EntityID")
		local Zombie = TargetID ~= nil and Match.Zombies[TargetID]
		if Zombie then
			Zombie:TakeDamage(Entity.Stats.Damage)
		end
	end
end

return Placeholder1
