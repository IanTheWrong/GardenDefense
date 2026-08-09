local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectileModel = ReplicatedStorage.Game.Assets.Models.Projectiles.PlaceholderProjectile

local LANE_MODE = "SameLane"
local HOMING_STRENGTH = 8

local Placeholder2 = {}

function Placeholder2.Heartbeat(Entity, Dt, Match)
	Entity.Cooldown = math.max((Entity.Cooldown or 0) - Dt, 0)
	if Entity.Cooldown > 0 then return end

	local TargetPart = Entity:GetNearestForwardTarget(Entity.Stats.Range, LANE_MODE)
	if not TargetPart then return end

	local Direction = Entity:GetAttackDirection(TargetPart)
	if not Direction then return end

	local TargetID = TargetPart:GetAttribute("EntityID")
	local Target = TargetID ~= nil and Match.Zombies[TargetID]
	if not Target then return end

	Entity.Cooldown = Entity.Stats.AttackCooldown

	Entity:FireProjectile({
		Direction = Direction,
		Speed = 90,
		Lifetime = 2,
		Radius = 3,
		HitMode = "Single",
		LaneMode = LANE_MODE,
		Homing = { Target = Target, Strength = HOMING_STRENGTH, Offset = Target.HurtboxOffset },
		Model = ProjectileModel,
		OnHit = function(EntityID)
			local Zombie = Match.Zombies[EntityID]
			if Zombie then
				Zombie:TakeDamage(Entity.Stats.Damage)
			end
		end,
	})
end

return Placeholder2
