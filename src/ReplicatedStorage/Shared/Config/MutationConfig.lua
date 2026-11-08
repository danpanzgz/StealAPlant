--!strict
--[[
	MutationConfig.lua
	Las flores nuevas pueden no tener mutación o tener Gold/Diamond. Las
	entradas antiguas se mantienen para conservar la apariencia de perfiles
	ya guardados.
]]

export type MutationData = {
	id: string,
	displayName: string,
	color: Color3,
	valueMultiplier: number, -- se aplica sobre el valor final de venta
	chance: number, -- probabilidad al cosechar/hacer crecer (0-1)
	weatherTag: string?, -- opcional: evento temporal que puede subir esta probabilidad
}

local MutationConfig: { [string]: MutationData } = {
	Wet = {
		id = "Wet",
		displayName = "Wet",
		color = Color3.fromRGB(84, 172, 255),
		valueMultiplier = 1.3,
		chance = 0.10,
		weatherTag = "Rain",
	},
	Golden = {
		id = "Golden",
		displayName = "Golden",
		color = Color3.fromRGB(255, 213, 74),
		valueMultiplier = 2.0,
		chance = 0.05,
		weatherTag = nil,
	},
	Frozen = {
		id = "Frozen",
		displayName = "Frozen",
		color = Color3.fromRGB(150, 227, 255),
		valueMultiplier = 1.6,
		chance = 0.06,
		weatherTag = "ColdSnap",
	},
	Shiny = {
		id = "Shiny",
		displayName = "Shiny",
		color = Color3.fromRGB(255, 255, 255),
		valueMultiplier = 1.4,
		chance = 0.08,
		weatherTag = nil,
	},
	Rainbow = {
		id = "Rainbow",
		displayName = "Rainbow",
		color = Color3.fromRGB(255, 120, 220),
		valueMultiplier = 3.5,
		chance = 0.015,
		weatherTag = nil,
	},
}

MutationConfig.Order = { "Wet", "Frozen", "Shiny", "Golden", "Rainbow" } :: any

-- New plants use the requested mutation set. Legacy entries above remain
-- readable so already-saved crops keep their appearance after migration.
MutationConfig.Gold = {
	id = "Gold",
	displayName = "Gold",
	color = Color3.fromRGB(255, 213, 74),
	valueMultiplier = 2,
	chance = 0.035,
	weatherTag = nil,
}
MutationConfig.Diamond = {
	id = "Diamond",
	displayName = "Diamond",
	color = Color3.fromRGB(125, 235, 255),
	valueMultiplier = 5,
	chance = 0.005,
	weatherTag = nil,
}
-- TODOS los efectos se tiran por separado: una planta puede conseguir varios
-- a la vez (sin límite) y cada uno multiplica su precio. Wet solo aparece
-- durante la lluvia (weatherTag "Rain").
MutationConfig.Wet.chance = 0.06
MutationConfig.Frozen.chance = 0.04
MutationConfig.Frozen.weatherTag = nil
MutationConfig.Shiny.chance = 0.06
MutationConfig.Rainbow.chance = 0.012
MutationConfig.Gold.chance = 0.035
MutationConfig.Diamond.chance = 0.005
MutationConfig.Order = { "Wet", "Frozen", "Shiny", "Gold", "Rainbow", "Diamond" } :: any

return MutationConfig
