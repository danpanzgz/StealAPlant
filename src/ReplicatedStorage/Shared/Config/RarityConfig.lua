--!strict
--[[
	RarityConfig.lua
	Define las rarezas de semillas y flores. Un peso relativo menor aparece
	con menos frecuencia en los packs.
]]

export type RarityData = {
	id: string,
	displayName: string,
	order: number,
	color: Color3,
	sellMultiplier: number, -- multiplica el valor base de venta de la planta
	weight: number, -- peso relativo para sorteos ponderados (mayor = más común)
}

local RarityConfig: { [string]: RarityData } = {
	Common = {
		id = "Common",
		displayName = "Common",
		order = 1,
		color = Color3.fromRGB(190, 190, 190),
		sellMultiplier = 1.0,
		weight = 100,
	},
	Uncommon = {
		id = "Uncommon",
		displayName = "Uncommon",
		order = 2,
		color = Color3.fromRGB(94, 214, 108),
		sellMultiplier = 1.6,
		weight = 55,
	},
	Rare = {
		id = "Rare",
		displayName = "Rare",
		order = 3,
		color = Color3.fromRGB(72, 158, 255),
		sellMultiplier = 2.6,
		weight = 25,
	},
	Epic = {
		id = "Epic",
		displayName = "Epic",
		order = 4,
		color = Color3.fromRGB(178, 90, 255),
		sellMultiplier = 4.5,
		weight = 9,
	},
	Legendary = {
		id = "Legendary",
		displayName = "Legendary",
		order = 5,
		color = Color3.fromRGB(255, 191, 61),
		sellMultiplier = 8.0,
		weight = 2,
	},
	Mythic = {
		id = "Mythic",
		displayName = "Mythic",
		order = 6,
		color = Color3.fromRGB(255, 91, 158),
		sellMultiplier = 14,
		weight = 0.45,
	},
	Celestial = {
		id = "Celestial",
		displayName = "Celestial",
		order = 7,
		color = Color3.fromRGB(120, 225, 255),
		sellMultiplier = 25,
		weight = 0.08,
	},
}

-- Orden fijo, útil para la UI (tienda, inventario, filtros)
RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial" } :: any

return RarityConfig
