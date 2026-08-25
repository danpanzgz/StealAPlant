--!strict
--[[
	GardenConfig.lua
	Define los 3 niveles de jardín. Cada jugador tiene un jardín propio
	(ver GardenService) que empieza en el nivel 1 y se puede mejorar
	comprando el siguiente nivel con Cash. Subir de nivel:
	  - añade más plots (parcelas) para plantar
	  - añade más slots de defensa contra robos
]]

export type GardenLevelData = {
	level: number,
	displayName: string,
	plotCount: number,
	defenseSlots: number,
	upgradePrice: number, -- precio para pasar A este nivel desde el anterior
}

local GardenConfig = {}

local Levels: { [number]: GardenLevelData } = {
	[1] = {
		level = 1,
		displayName = "Backyard Plot",
		plotCount = 4,
		defenseSlots = 1,
		upgradePrice = 0, -- nivel inicial, gratis
	},
	[2] = {
		level = 2,
		displayName = "Family Garden",
		plotCount = 8,
		defenseSlots = 2,
		upgradePrice = 2000,
	},
	[3] = {
		level = 3,
		displayName = "Estate Grounds",
		plotCount = 12,
		defenseSlots = 3,
		upgradePrice = 8000,
	},
}

GardenConfig.Levels = Levels
GardenConfig.MaxLevel = 3

-- Layout físico: separación entre parcelas y tamaño del terreno asignado
-- a cada jugador en Workspace. Se usa al generar los jardines en el mapa.
GardenConfig.PlotSpacing = 10 -- studs entre el centro de cada plot
GardenConfig.PlotSize = Vector3.new(8, 1, 8)
GardenConfig.GardenSlotSpacing = 60 -- studs entre el jardín de un jugador y el siguiente

return GardenConfig
