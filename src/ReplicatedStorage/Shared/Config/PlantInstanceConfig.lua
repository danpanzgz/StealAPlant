--!strict

local PlantInstanceConfig = {}

PlantInstanceConfig.Sizes = {
	Normal = { displayName = "Normal", multiplier = 1, weight = 84 },
	Large = { displayName = "Large", multiplier = 1.65, weight = 14 },
	Giant = { displayName = "Giant", multiplier = 3, weight = 2 },
}
PlantInstanceConfig.SizeOrder = { "Normal", "Large", "Giant" }
PlantInstanceConfig.MutationOrder = { "Diamond", "Gold" }
PlantInstanceConfig.PlaceCapacityBase = 2
PlantInstanceConfig.PlaceCapacityPerRebirth = 2

return PlantInstanceConfig
