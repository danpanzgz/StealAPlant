--!strict
--[[
	MutationConfig.lua
	Define las 5 mutaciones del juego. Una planta puede tener 0 o 1 mutación
	(en esta primera versión; el sistema está preparado para múltiples si se
	necesita en el futuro).
	Las mutaciones son puramente estéticas/de valor: no generan contenido
	violento ni gráfico, solo cambian color/valor.
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

return MutationConfig
