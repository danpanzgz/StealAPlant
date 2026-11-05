--!strict
--[[
	EventConfig.lua
	Los 2 eventos globales temporales de la v1. Se activan de forma
	periódica y afectan a todo el servidor.
	  - RainShower: sube la probabilidad de mutaciones con weatherTag "Rain" (Wet).
	  - GoldRush: multiplica el valor de venta de las cosechas.
]]

export type EventData = {
	id: string,
	displayName: string,
	description: string,
	weatherTag: string?,
	mutationChanceMultiplier: number,
	sellMultiplier: number,
}

local EventConfig = {}

EventConfig.Events = {
	RainShower = {
		id = "RainShower",
		displayName = "Rain Shower 🌧️",
		description = "¡Mutación Wet x4 más probable!",
		weatherTag = "Rain",
		mutationChanceMultiplier = 4,
		sellMultiplier = 1,
	},
	GoldRush = {
		id = "GoldRush",
		displayName = "Gold Rush 💰",
		description = "¡Todas las cosechas valen x1.5!",
		weatherTag = nil,
		mutationChanceMultiplier = 1,
		sellMultiplier = 1.5,
	},
} :: { [string]: EventData }

EventConfig.Order = { "RainShower", "GoldRush" }

EventConfig.FirstEventDelay = 90 -- segundos tras arrancar el servidor
EventConfig.DurationSeconds = 120 -- duración de cada evento
EventConfig.IntervalSeconds = 300 -- pausa entre eventos

return EventConfig
