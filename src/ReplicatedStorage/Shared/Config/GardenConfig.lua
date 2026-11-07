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
GardenConfig.GardenSlotSpacing = 50 -- studs entre jardines contiguos (el patio mide 44)

-- Mapa para 12 jugadores: dos filas de 6 jardines frente a frente con una
-- calle/plaza en medio. Los jardines no se rotan (todos los servicios
-- trabajan con offsets locales), así que la fila sur usa su valla trasera
-- como entrada y la fila norte su valla delantera.
GardenConfig.MaxGardens = 12
GardenConfig.GardensPerRow = 6
GardenConfig.StreetWidth = 40
GardenConfig.YardFrontZ = -7
GardenConfig.YardBackZ = 37
GardenConfig.YardMinX = -7
GardenConfig.YardMaxX = 37
-- Margen (studs) al borde de la valla donde NO se pueden colocar flores.
GardenConfig.PlacementMargin = 3
-- Orden de columnas desde el centro hacia fuera: los primeros jugadores
-- quedan cerca de la plaza. Los slots alternan fila (0 sur, 1 norte).
GardenConfig.ColumnOrder = { 2, 3, 1, 4, 0, 5 }

-- Z (local, relativa al origen de la fila norte) de la fila norte.
GardenConfig.NorthRowZ = GardenConfig.YardBackZ + GardenConfig.StreetWidth - GardenConfig.YardFrontZ

export type SlotLayout = {
	origin: Vector3,
	row: number, -- 0 = sur (entra por detrás), 1 = norte (entra por delante)
	entryZ: number, -- Z local donde aparece/entrega el jugador (lado calle)
	outward: number, -- +1 / -1: sentido local de Z hacia la calle
}

function GardenConfig.GetSlotLayout(slot: number): SlotLayout
	local inServer = slot % GardenConfig.MaxGardens
	local overflow = math.floor(slot / GardenConfig.MaxGardens)
	local row = inServer % 2
	local columnIndex = math.floor(inServer / 2) + 1
	local column = GardenConfig.ColumnOrder[columnIndex]
	local z = if row == 0 then 0 else GardenConfig.NorthRowZ
	-- Slots por encima de 12 (solo en pruebas): otro bloque hacia el sur.
	z -= overflow * 150
	return {
		origin = Vector3.new(column * GardenConfig.GardenSlotSpacing, 0, z),
		row = row,
		entryZ = if row == 0 then GardenConfig.YardBackZ + 6 else GardenConfig.YardFrontZ - 4,
		outward = if row == 0 then 1 else -1,
	}
end

-- Centro de la calle central (plaza) en coordenadas de mundo.
function GardenConfig.GetStreetCenter(): Vector3
	local lastColumnX = (GardenConfig.GardensPerRow - 1) * GardenConfig.GardenSlotSpacing
	return Vector3.new(
		(GardenConfig.YardMinX + lastColumnX + GardenConfig.YardMaxX) / 2,
		0,
		(GardenConfig.YardBackZ + GardenConfig.NorthRowZ + GardenConfig.YardFrontZ) / 2
	)
end

return GardenConfig
