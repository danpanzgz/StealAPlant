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

-- Vallas: el estilo mejora con cada Rebirth (Rebirth 0 = estilo 1 ... Rebirth 5+ = estilo 6).
export type FenceStyle = {
	name: string,
	postSize: Vector3,
	postColor: Color3,
	postMaterial: Enum.Material,
	postSpacing: number,
	railColor: Color3,
	railMaterial: Enum.Material,
	railHeights: { number },
	railThickness: number,
	baseHeight: number, -- muro bajo continuo (0 = sin muro)
	baseColor: Color3,
	baseMaterial: Enum.Material,
	picketSpacing: number, -- 0 = sin barrotes
	picketSize: Vector3,
	picketColor: Color3,
	picketMaterial: Enum.Material,
	picketTransparency: number,
	capShape: string, -- none | ball | block | diamond
	capSize: number,
	capColor: Color3,
	capMaterial: Enum.Material,
	lantern: boolean, -- farolillo sobre cada poste
	sparkle: boolean, -- destellos en las esquinas
	gateColor: Color3,
	gateMaterial: Enum.Material,
	signColor: Color3,
	signTextColor: Color3,
}

GardenConfig.FenceStyles = {
	{
		name = "Valla rústica",
		postSize = Vector3.new(0.9, 3.4, 0.9), postColor = Color3.fromRGB(150, 108, 68), postMaterial = Enum.Material.Wood, postSpacing = 6,
		railColor = Color3.fromRGB(165, 120, 75), railMaterial = Enum.Material.Wood, railHeights = { 1.2, 2.5 }, railThickness = 0.4,
		baseHeight = 0, baseColor = Color3.new(1, 1, 1), baseMaterial = Enum.Material.Slate,
		picketSpacing = 0, picketSize = Vector3.new(0.3, 2, 0.15), picketColor = Color3.new(1, 1, 1), picketMaterial = Enum.Material.Wood, picketTransparency = 0,
		capShape = "none", capSize = 0, capColor = Color3.new(1, 1, 1), capMaterial = Enum.Material.Wood,
		lantern = false, sparkle = false,
		gateColor = Color3.fromRGB(120, 85, 55), gateMaterial = Enum.Material.Wood,
		signColor = Color3.fromRGB(255, 240, 200), signTextColor = Color3.fromRGB(86, 58, 34),
	},
	{
		name = "Valla blanca",
		postSize = Vector3.new(0.8, 3.8, 0.8), postColor = Color3.fromRGB(250, 248, 240), postMaterial = Enum.Material.SmoothPlastic, postSpacing = 5,
		railColor = Color3.fromRGB(245, 243, 235), railMaterial = Enum.Material.SmoothPlastic, railHeights = { 1.0, 2.6 }, railThickness = 0.35,
		baseHeight = 0, baseColor = Color3.new(1, 1, 1), baseMaterial = Enum.Material.Slate,
		picketSpacing = 1.4, picketSize = Vector3.new(0.4, 3, 0.18), picketColor = Color3.fromRGB(252, 250, 244), picketMaterial = Enum.Material.SmoothPlastic, picketTransparency = 0,
		capShape = "ball", capSize = 1.0, capColor = Color3.fromRGB(255, 255, 255), capMaterial = Enum.Material.SmoothPlastic,
		lantern = false, sparkle = false,
		gateColor = Color3.fromRGB(240, 238, 228), gateMaterial = Enum.Material.SmoothPlastic,
		signColor = Color3.fromRGB(255, 252, 240), signTextColor = Color3.fromRGB(60, 120, 70),
	},
	{
		name = "Muro de piedra",
		postSize = Vector3.new(1.7, 4.2, 1.7), postColor = Color3.fromRGB(150, 150, 156), postMaterial = Enum.Material.Cobblestone, postSpacing = 8,
		railColor = Color3.fromRGB(140, 140, 146), railMaterial = Enum.Material.Cobblestone, railHeights = {}, railThickness = 0,
		baseHeight = 2.4, baseColor = Color3.fromRGB(165, 165, 170), baseMaterial = Enum.Material.Cobblestone,
		picketSpacing = 0, picketSize = Vector3.new(0.3, 2, 0.15), picketColor = Color3.new(1, 1, 1), picketMaterial = Enum.Material.Wood, picketTransparency = 0,
		capShape = "block", capSize = 2.1, capColor = Color3.fromRGB(120, 120, 128), capMaterial = Enum.Material.Slate,
		lantern = true, sparkle = false,
		gateColor = Color3.fromRGB(140, 140, 148), gateMaterial = Enum.Material.Cobblestone,
		signColor = Color3.fromRGB(226, 226, 230), signTextColor = Color3.fromRGB(50, 50, 60),
	},
	{
		name = "Hierro forjado",
		postSize = Vector3.new(0.8, 4.4, 0.8), postColor = Color3.fromRGB(38, 40, 50), postMaterial = Enum.Material.Metal, postSpacing = 5,
		railColor = Color3.fromRGB(46, 48, 58), railMaterial = Enum.Material.Metal, railHeights = { 0.9, 3.6 }, railThickness = 0.3,
		baseHeight = 0.9, baseColor = Color3.fromRGB(150, 150, 156), baseMaterial = Enum.Material.Cobblestone,
		picketSpacing = 1.1, picketSize = Vector3.new(0.2, 3.4, 0.2), picketColor = Color3.fromRGB(42, 44, 54), picketMaterial = Enum.Material.Metal, picketTransparency = 0,
		capShape = "diamond", capSize = 0.9, capColor = Color3.fromRGB(255, 205, 80), capMaterial = Enum.Material.Metal,
		lantern = true, sparkle = false,
		gateColor = Color3.fromRGB(40, 42, 52), gateMaterial = Enum.Material.Metal,
		signColor = Color3.fromRGB(46, 48, 60), signTextColor = Color3.fromRGB(255, 220, 130),
	},
	{
		name = "Cristal",
		postSize = Vector3.new(0.9, 4.6, 0.9), postColor = Color3.fromRGB(150, 225, 255), postMaterial = Enum.Material.Glass, postSpacing = 5,
		railColor = Color3.fromRGB(110, 220, 255), railMaterial = Enum.Material.Neon, railHeights = { 1.0, 4.0 }, railThickness = 0.22,
		baseHeight = 0.9, baseColor = Color3.fromRGB(205, 240, 255), baseMaterial = Enum.Material.Glass,
		picketSpacing = 1.2, picketSize = Vector3.new(0.3, 3.6, 0.3), picketColor = Color3.fromRGB(150, 225, 255), picketMaterial = Enum.Material.Glass, picketTransparency = 0.3,
		capShape = "diamond", capSize = 1.2, capColor = Color3.fromRGB(120, 235, 255), capMaterial = Enum.Material.Neon,
		lantern = true, sparkle = true,
		gateColor = Color3.fromRGB(150, 225, 255), gateMaterial = Enum.Material.Glass,
		signColor = Color3.fromRGB(30, 60, 90), signTextColor = Color3.fromRGB(150, 245, 255),
	},
	{
		name = "Real dorada",
		postSize = Vector3.new(1.0, 5.0, 1.0), postColor = Color3.fromRGB(255, 200, 60), postMaterial = Enum.Material.Metal, postSpacing = 4.5,
		railColor = Color3.fromRGB(255, 215, 90), railMaterial = Enum.Material.Metal, railHeights = { 1.1, 4.3 }, railThickness = 0.35,
		baseHeight = 1.1, baseColor = Color3.fromRGB(250, 246, 236), baseMaterial = Enum.Material.Marble,
		picketSpacing = 1.0, picketSize = Vector3.new(0.24, 3.9, 0.24), picketColor = Color3.fromRGB(255, 205, 70), picketMaterial = Enum.Material.Metal, picketTransparency = 0,
		capShape = "ball", capSize = 1.3, capColor = Color3.fromRGB(255, 235, 140), capMaterial = Enum.Material.Neon,
		lantern = true, sparkle = true,
		gateColor = Color3.fromRGB(255, 205, 70), gateMaterial = Enum.Material.Metal,
		signColor = Color3.fromRGB(120, 40, 140), signTextColor = Color3.fromRGB(255, 232, 130),
	},
} :: { FenceStyle }

-- Estilo de valla según los rebirths del jugador (0 = primero).
function GardenConfig.GetFenceTier(rebirths: number): number
	return math.clamp(math.floor(rebirths) + 1, 1, #GardenConfig.FenceStyles)
end

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
