local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNetMax = require(ReplicatedStorage.Game.Modules.ByteNetMax)

return ByteNetMax.defineNamespace("ZombieNetwork", function()
	return {
		packets = {
			ZombieSpawned = ByteNetMax.definePacket({
				value = ByteNetMax.struct({
					Id = ByteNetMax.uint8,
					Model = ByteNetMax.string,
					Position = ByteNetMax.vec3,
					Yaw = ByteNetMax.float32,
				}),
			}),

			ZombieUpdate = ByteNetMax.definePacket({
				reliabilityType = "unreliable",
				value = ByteNetMax.map(ByteNetMax.uint8, ByteNetMax.vec3),
			}),

			ZombieDestroyed = ByteNetMax.definePacket({
				value = ByteNetMax.uint8,
			}),

			ZombieHit = ByteNetMax.definePacket({
				value = ByteNetMax.uint8,
			}),

			ZombieMatchCleared = ByteNetMax.definePacket({
				value = ByteNetMax.uint8,
			}),
		},
	}
end)
