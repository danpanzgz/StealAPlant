--!strict
--[[
	ZoneConfig.lua
	Define las 3 zonas de la primera versión. Cada zona agrupa una parte del
	catálogo de semillas y tiene un requisito de desbloqueo simple (Cash
	acumulado o nivel de jardín), pensado para dar progresión clara sin
	sistemas complejos.
]]

export type ZoneData = {
	id: string,
	displayName: string,
	order: number,
	unlockCash: number, -- cash total ganado necesario para desbloquear (0 = disponible desde el inicio)
	description: string,
}

local ZoneConfig: { [string]: ZoneData } = {
	StarterMeadow = {
		id = "StarterMeadow",
		displayName = "Starter Meadow",
		order = 1,
		unlockCash = 0,
		description = "Tu primer huerto. Semillas baratas y rápidas de cultivar.",
	},
	GreenhouseValley = {
		id = "GreenhouseValley",
		displayName = "Greenhouse Valley",
		order = 2,
		unlockCash = 750,
		description = "Semillas de mayor valor y tiempos de crecimiento medios.",
	},
	MysticGrove = {
		id = "MysticGrove",
		displayName = "Mystic Grove",
		order = 3,
		unlockCash = 4000,
		description = "Plantas raras y legendarias para jugadores avanzados.",
	},
}

ZoneConfig.Order = { "StarterMeadow", "GreenhouseValley", "MysticGrove" } :: any

return ZoneConfig
