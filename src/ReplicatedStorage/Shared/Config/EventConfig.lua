--!strict
--[[
	EventConfig.lua
	Los 2 eventos globales temporales de la v1. Se activan de forma
	periódica y afectan a todo el servidor.
	  - RainShower: crecimiento x1.2 y el efecto Wet (solo posible en lluvia).
	  - GoldRush: multiplica el valor de venta de las cosechas.
]]

export type EventData = {
	id: string,
	displayName: string,
	description: string,
	weatherTag: string?,
	mutationChanceMultiplier: number,
	sellMultiplier: number,
	growthMultiplier: number, -- velocidad de crecimiento mientras dura el evento
}

local EventConfig = {}

EventConfig.Events = {
	RainShower = {
		id = "RainShower",
		displayName = "Rain Shower 🌧️",
		description = "¡Las plantas crecen x1.2 más rápido y pueden mojarse (Wet)!",
		weatherTag = "Rain",
		mutationChanceMultiplier = 1.5,
		sellMultiplier = 1,
		growthMultiplier = 1.2,
	},
	GoldRush = {
		id = "GoldRush",
		displayName = "Gold Rush 💰",
		description = "¡Todas las cosechas valen x1.5!",
		weatherTag = nil,
		mutationChanceMultiplier = 1,
		sellMultiplier = 1.5,
		growthMultiplier = 1,
	},
} :: { [string]: EventData }

EventConfig.Order = { "RainShower", "GoldRush" }

EventConfig.FirstEventDelay = 90 -- segundos tras arrancar el servidor
EventConfig.DurationSeconds = 120 -- duración de cada evento
EventConfig.IntervalSeconds = 300 -- pausa entre eventos

return EventConfig
