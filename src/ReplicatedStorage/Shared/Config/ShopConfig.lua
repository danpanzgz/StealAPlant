--!strict

local ShopConfig = {}

ShopConfig.RestockSeconds = 300

ShopConfig.Packs = {
	Common = {
		displayName = "Pack de semillas Common",
		description = "3–4 Common, 1–2 Uncommon; bonus: 25% Rare, 5% Legendary, 0,99% Mythic.",
		rarity = "Common",
		price = 250,
		stockWeight = 100,
	},
	Uncommon = {
		displayName = "Pack de semillas Uncommon",
		description = "3–4 Uncommon, 1–2 Rare; bonus: 25% Epic, 5% Legendary, 0,99% Mythic.",
		rarity = "Uncommon",
		price = 1800,
		stockWeight = 65,
	},
	Rare = {
		displayName = "Pack de semillas Rare",
		description = "3–4 Rare, 1–2 Epic; bonus: 25% Legendary, 5% Mythic, 0,99% Celestial.",
		rarity = "Rare",
		price = 9000,
		stockWeight = 32,
	},
	Epic = {
		displayName = "Pack de semillas Epic",
		description = "3–4 Epic, 1–2 Legendary; bonus: 25% Mythic, 5% Celestial.",
		rarity = "Epic",
		price = 35000,
		stockWeight = 14,
	},
	Legendary = {
		displayName = "Pack de semillas Legendary",
		description = "3–4 Legendary, 1–2 Mythic; 5% de una semilla Celestial extra.",
		rarity = "Legendary",
		price = 120000,
		stockWeight = 5,
	},
	Mythic = {
		displayName = "Pack de semillas Mythic",
		description = "3–4 Mythic y 1–2 Celestial.",
		rarity = "Mythic",
		price = 500000,
		stockWeight = 1.4,
	},
	Celestial = {
		displayName = "Pack de semillas Celestial",
		description = "4–5 semillas Celestial.",
		rarity = "Celestial",
		price = 2500000,
		stockWeight = 0.25,
	},
}

ShopConfig.PetEggs = {
	Common = {
		displayName = "Huevo Common",
		description = "Incuba 1 mascota de una colección de 5 diseños Common.",
		rarity = "Common",
		price = 350,
		stockWeight = 100,
	},
	Uncommon = {
		displayName = "Huevo Uncommon",
		description = "Incuba 1 mascota de una colección de 5 diseños Uncommon.",
		rarity = "Uncommon",
		price = 2200,
		stockWeight = 65,
	},
	Rare = {
		displayName = "Huevo Rare",
		description = "Incuba 1 mascota de una colección de 5 diseños Rare.",
		rarity = "Rare",
		price = 11000,
		stockWeight = 32,
	},
	Epic = {
		displayName = "Huevo Epic",
		description = "Incuba 1 mascota de una colección de 5 diseños Epic.",
		rarity = "Epic",
		price = 42000,
		stockWeight = 14,
	},
	Legendary = {
		displayName = "Huevo Legendary",
		description = "Incuba 1 mascota de una colección de 5 diseños Legendary.",
		rarity = "Legendary",
		price = 145000,
		stockWeight = 5,
	},
	Mythic = {
		displayName = "Huevo Mythic",
		description = "Incuba 1 mascota de una colección de 5 diseños Mythic.",
		rarity = "Mythic",
		price = 600000,
		stockWeight = 1.4,
	},
	Celestial = {
		displayName = "Huevo Celestial",
		description = "Incuba 1 mascota de una colección de 5 diseños Celestial.",
		rarity = "Celestial",
		price = 3000000,
		stockWeight = 0.25,
	},
}

ShopConfig.Gear = {
	WaterCan = {
		displayName = "Regadera rápida",
		description = "Acelera 5x un cultivo durante 20 segundos.",
		rarity = "Common",
		price = 30,
		stockWeight = 100,
		kind = "consumable",
	},
	Sprinkler = {
		displayName = "Aspersor",
		description = "Equipado, los nuevos cultivos crecen 1,5x más rápido.",
		rarity = "Uncommon",
		price = 1200,
		stockWeight = 48,
		kind = "passive",
		growthMultiplier = 1.5,
	},
	MutationTotem = {
		displayName = "Tótem de mutación",
		description = "Aumenta la probabilidad de mutación al plantar.",
		rarity = "Rare",
		price = 6500,
		stockWeight = 25,
		kind = "passive",
		mutationLuck = 2,
	},
	SizeTotem = {
		displayName = "Tótem de tamaño",
		description = "Aumenta la probabilidad de plantas grandes y gigantes.",
		rarity = "Epic",
		price = 18000,
		stockWeight = 12,
		kind = "passive",
		sizeLuck = 2,
	},
	NetTrap = {
		displayName = "Trampa de red",
		description = "Colócala en tu jardín: ralentiza a quien la pise. Máx. 3 activas.",
		rarity = "Uncommon",
		price = 900,
		stockWeight = 40,
		kind = "trap",
		color = Color3.fromRGB(95, 190, 255),
		slowSeconds = 5,
		speedFactor = 0.35,
	},
	BubbleTrap = {
		displayName = "Trampa de burbuja",
		description = "Atrapa al intruso en una burbuja unos segundos. Máx. 3 activas.",
		rarity = "Rare",
		price = 4200,
		stockWeight = 22,
		kind = "trap",
		color = Color3.fromRGB(255, 140, 220),
		slowSeconds = 3.5,
		speedFactor = 0,
		bubble = true,
	},
}

-- Trampas colocadas a la vez por jugador.
ShopConfig.MaxActiveTraps = 3
ShopConfig.TrapLifetimeSeconds = 900

return ShopConfig
