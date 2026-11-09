--!strict
--[[
	PlantBlueprints.lua
	Datos puros (sin APIs de Roblox) que describen la silueta voxel de cada
	planta. PlantModels.lua los convierte en Parts. Al ser puro, se puede
	ejecutar fuera de Studio para previsualizar las siluetas.

	Cada especie es una función que recibe `e` (emit) y emite bloques:
	  e(shape, ox, oy, oz, sx, sy, sz, color, at, kind)
	    shape : "B" bloque, "C" cilindro vertical, "S" esfera
	    ox,oy,oz : centro del bloque relativo al suelo (y = 0 es el suelo)
	    sx,sy,sz : tamaño
	    color : clave de PlantBlueprints.Palette o "fruit" / "fruit2" / "fruit3"
	            (color de la planta, más oscuro y más claro; cambia con la mutación)
	    at    : fracción de crecimiento (0..1) a partir de la cual aparece
	    kind  : "fruit" | "leaf" | "stem" | "glow" | "deco"
	            ("fruit" y "glow" se vuelven Neon si la planta está mutada)
	Frente del jardín = -Z. Las flores grandes miran hacia -Z.
]]

export type Emit = (
	shape: string, ox: number, oy: number, oz: number,
	sx: number, sy: number, sz: number,
	color: string, at: number, kind: string
) -> ()

local PlantBlueprints = {}

-- Umbrales de crecimiento: con 3-6 fases siempre aparecen de forma gradual.
local YOUNG, MID, FULL = 0.3, 0.6, 1.0
PlantBlueprints.Thresholds = { Young = YOUNG, Mid = MID, Full = FULL }

PlantBlueprints.Palette = {
	leaf = { 86, 160, 74 }, leaf2 = { 122, 194, 86 }, leaf3 = { 56, 122, 64 },
	stem = { 92, 128, 62 }, stem2 = { 68, 102, 52 },
	wood = { 136, 95, 60 }, wood2 = { 102, 70, 44 }, bark = { 120, 84, 52 },
	soil = { 96, 66, 44 },
	white = { 255, 255, 255 }, cream = { 255, 244, 214 }, black = { 38, 34, 40 },
	seed = { 255, 236, 160 }, gold = { 255, 214, 92 }, pink = { 248, 160, 190 },
	rose = { 232, 96, 140 }, violet = { 150, 110, 230 }, indigo = { 92, 70, 190 },
	cyan = { 120, 225, 255 }, teal = { 64, 190, 180 }, mint = { 140, 240, 190 },
	orange = { 255, 140, 40 }, red = { 214, 58, 46 }, brown = { 104, 71, 41 },
	ember = { 255, 205, 80 }, rock = { 92, 96, 112 },
} :: { [string]: { number } }

local function box(e: Emit, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: string, at: number, kind: string?)
	e("B", x, y, z, sx, sy, sz, color, at, kind or "deco")
end

-- Esfera voxel: 3 bloques apilados + brillo.
local function orb(e: Emit, x: number, y: number, z: number, r: number, color: string, at: number, kind: string?)
	local k = kind or "fruit"
	e("B", x, y, z, r, r * 0.72, r, color, at, k)
	e("B", x, y + r * 0.5, z, r * 0.7, r * 0.3, r * 0.7, color, at, k)
	e("B", x, y - r * 0.47, z, r * 0.7, r * 0.28, r * 0.7, color, at, k)
	e("B", x - r * 0.26, y + r * 0.2, z - r * 0.5, r * 0.2, r * 0.2, r * 0.1, "white", at, "deco")
end

-- Baya pequeña: 1 bloque + brillo (barata para racimos).
local function bead(e: Emit, x: number, y: number, z: number, r: number, color: string, at: number)
	e("B", x, y, z, r, r, r, color, at, "fruit")
	e("B", x - r * 0.2, y + r * 0.2, z - r * 0.5, r * 0.22, r * 0.22, r * 0.08, "white", at, "deco")
end

local function stalk(e: Emit, x: number, z: number, h: number, w: number, color: string, at: number)
	box(e, x, h / 2, z, w, h, w, color, at, "stem")
end

local function leaf(e: Emit, x: number, y: number, z: number, lx: number, lz: number, color: string, at: number)
	box(e, x, y, z, lx, 0.16, lz, color, at, "leaf")
end

local function leafRing(e: Emit, y: number, r: number, len: number, at: number)
	leaf(e, -r, y, 0, len, len * 0.5, "leaf", at)
	leaf(e, r, y + 0.14, 0, len, len * 0.5, "leaf2", at)
	leaf(e, 0, y + 0.07, -r, len * 0.5, len, "leaf2", at)
	leaf(e, 0, y + 0.21, r, len * 0.5, len, "leaf", at)
end

-- Anillo de n bloques. plane "XY" = disco vertical mirando a -Z; "XZ" = horizontal.
local function ring(
	e: Emit, cx: number, cy: number, cz: number, r: number, n: number,
	sx: number, sy: number, sz: number, c1: string, c2: string, at: number, kind: string?, phase: number?
)
	for i = 0, n - 1 do
		local a = (i / n) * math.pi * 2 + (phase or 0)
		local px, py = math.cos(a) * r, math.sin(a) * r
		local color = if i % 2 == 0 then c1 else c2
		e("B", cx + px, cy + py, cz, sx, sy, sz, color, at, kind or "fruit")
	end
end

local function ringFlat(
	e: Emit, cx: number, cy: number, cz: number, r: number, n: number,
	sx: number, sy: number, sz: number, c1: string, c2: string, at: number, kind: string?, phase: number?
)
	for i = 0, n - 1 do
		local a = (i / n) * math.pi * 2 + (phase or 0)
		local color = if i % 2 == 0 then c1 else c2
		e("B", cx + math.cos(a) * r, cy, cz + math.sin(a) * r, sx, sy, sz, color, at, kind or "fruit")
	end
end

local Species: { [string]: (Emit) -> () } = {}

-- ===== Zona 1: Starter Meadow =====

Species.Carrot = function(e)
	box(e, 0, 0.3, 0, 0.95, 0.6, 0.95, "fruit", YOUNG, "fruit")
	box(e, -0.25, 0.5, -0.45, 0.22, 0.14, 0.1, "fruit3", MID, "deco")
	box(e, 0, 0.62, 0, 0.7, 0.14, 0.7, "fruit2", MID, "fruit")
	box(e, -0.3, 1.1, 0.05, 0.22, 1.2, 0.22, "leaf", YOUNG, "stem")
	box(e, 0.3, 1.0, -0.05, 0.22, 1.0, 0.22, "leaf3", YOUNG, "stem")
	box(e, 0, 1.45, 0, 0.24, 1.9, 0.24, "leaf2", YOUNG, "stem")
	box(e, -0.3, 1.8, 0.05, 0.5, 0.3, 0.24, "leaf", MID, "leaf")
	box(e, 0.32, 1.6, -0.05, 0.5, 0.3, 0.24, "leaf3", MID, "leaf")
	box(e, 0, 2.5, 0, 0.6, 0.35, 0.26, "leaf2", MID, "leaf")
	box(e, 0, 2.05, 0.2, 0.26, 0.3, 0.5, "leaf", FULL, "leaf")
end

Species.Potato = function(e)
	box(e, -0.55, 0.38, -0.3, 1.0, 0.76, 0.9, "fruit", YOUNG, "fruit")
	box(e, 0.5, 0.34, -0.1, 0.9, 0.68, 0.8, "fruit2", MID, "fruit")
	box(e, 0.05, 0.3, 0.6, 0.8, 0.6, 0.7, "fruit", FULL, "fruit")
	box(e, -0.75, 0.55, -0.72, 0.16, 0.16, 0.1, "brown", FULL, "deco")
	box(e, 0.4, 0.5, -0.5, 0.16, 0.16, 0.1, "brown", FULL, "deco")
	stalk(e, 0, 0, 1.3, 0.24, "stem", YOUNG)
	leafRing(e, 0.85, 0.55, 1.1, YOUNG)
	leafRing(e, 1.3, 0.4, 0.9, MID)
	box(e, 0.12, 1.55, -0.05, 0.34, 0.26, 0.34, "white", FULL, "deco")
	box(e, -0.3, 1.2, 0.2, 0.28, 0.22, 0.28, "violet", FULL, "deco")
end

Species.Tomato = function(e)
	box(e, 1.1, 1.4, 0.55, 0.16, 2.8, 0.16, "wood", YOUNG, "stem") -- tutor
	stalk(e, 0, 0, 2.3, 0.3, "stem", YOUNG)
	leafRing(e, 0.7, 0.75, 1.2, YOUNG)
	leafRing(e, 1.35, 0.7, 1.15, MID)
	leafRing(e, 2.0, 0.55, 0.95, MID)
	orb(e, -0.75, 0.75, -0.45, 0.72, "fruit", MID)
	orb(e, 0.7, 1.15, -0.3, 0.7, "fruit", MID)
	orb(e, -0.2, 1.7, -0.7, 0.66, "fruit", FULL)
	orb(e, 0.45, 0.6, 0.55, 0.6, "fruit2", FULL)
	box(e, -0.75, 1.25, -0.45, 0.42, 0.1, 0.42, "leaf3", FULL, "leaf")
	box(e, 0.7, 1.65, -0.3, 0.42, 0.1, 0.42, "leaf3", FULL, "leaf")
	box(e, -0.2, 2.2, -0.7, 0.4, 0.1, 0.4, "leaf3", FULL, "leaf")
end

Species.Corn = function(e)
	stalk(e, 0, 0, 3.7, 0.5, "stem", YOUNG)
	for i = 0, 3 do
		local side = if i % 2 == 0 then -1 else 1
		box(e, side * 0.85, 0.9 + i * 0.7, 0, 1.5, 0.16, 0.46, if i % 2 == 0 then "leaf" else "leaf2", YOUNG, "leaf")
	end
	box(e, -0.6, 2.4, -0.1, 0.5, 0.34, 0.4, "leaf3", MID, "leaf")
	box(e, 0.55, 1.55, -0.55, 0.62, 1.25, 0.62, "fruit", MID, "fruit")
	box(e, 0.55, 1.5, -0.88, 0.7, 1.2, 0.1, "leaf", MID, "leaf")
	box(e, 0.55, 2.1, -0.55, 0.5, 0.2, 0.5, "fruit2", FULL, "fruit")
	box(e, -0.55, 2.0, 0.45, 0.62, 1.2, 0.62, "fruit", FULL, "fruit")
	box(e, -0.55, 2.0, 0.13, 0.7, 1.15, 0.1, "leaf2", FULL, "leaf")
	box(e, 0, 3.95, 0, 0.7, 0.34, 0.7, "gold", FULL, "deco")
	box(e, 0, 4.3, 0, 0.3, 0.45, 0.3, "seed", FULL, "deco")
end

Species.Sunflower = function(e)
	stalk(e, 0, 0, 3.8, 0.4, "stem", YOUNG)
	leaf(e, -0.9, 1.1, 0, 1.4, 0.7, "leaf", YOUNG)
	leaf(e, 0.9, 1.7, 0, 1.4, 0.7, "leaf2", YOUNG)
	leaf(e, 0, 2.4, 0.8, 0.7, 1.2, "leaf", MID)
	box(e, 0, 3.8, 0.2, 0.3, 0.7, 0.3, "stem", MID, "stem")
	ring(e, 0, 4.25, -0.2, 1.05, 8, 0.7, 0.7, 0.3, "fruit", "fruit3", MID, "fruit")
	ring(e, 0, 4.25, -0.2, 0.62, 4, 0.55, 0.55, 0.32, "fruit2", "fruit2", FULL, "fruit", math.pi / 4)
	box(e, 0, 4.25, -0.18, 1.05, 1.05, 0.5, "brown", MID, "deco")
	box(e, 0, 4.25, -0.46, 0.65, 0.65, 0.1, "wood2", FULL, "deco")
	box(e, 0.18, 4.4, -0.54, 0.14, 0.14, 0.06, "gold", FULL, "deco")
end

Species.Strawberry = function(e)
	leaf(e, -0.9, 0.35, 0, 1.3, 1.0, "leaf3", YOUNG)
	leaf(e, 0.9, 0.42, 0.1, 1.3, 1.0, "leaf", YOUNG)
	leaf(e, 0, 0.5, 0.9, 1.0, 1.2, "leaf2", YOUNG)
	leaf(e, 0, 0.58, -0.9, 1.0, 1.1, "leaf3", MID)
	box(e, 0, 0.8, 0, 0.9, 0.8, 0.9, "leaf", MID, "leaf")
	box(e, 0, 1.3, 0, 0.7, 0.4, 0.7, "leaf2", MID, "leaf")
	for _, p in ipairs({ { -0.85, 0.55, -0.7 }, { 0.8, 0.5, -0.5 }, { 0.15, 0.62, -1.15 }, { -0.2, 0.45, 0.9 } }) do
		box(e, p[1], p[2], p[3], 0.62, 0.32, 0.62, "fruit", FULL, "fruit")
		box(e, p[1], p[2] - 0.28, p[3], 0.44, 0.26, 0.44, "fruit", FULL, "fruit")
		box(e, p[1], p[2] - 0.5, p[3], 0.22, 0.2, 0.22, "fruit2", FULL, "fruit")
		box(e, p[1], p[2] + 0.2, p[3], 0.5, 0.12, 0.5, "leaf3", FULL, "leaf")
		box(e, p[1] - 0.12, p[2] - 0.1, p[3] - 0.3, 0.07, 0.07, 0.05, "seed", FULL, "deco")
		box(e, p[1] + 0.14, p[2] - 0.28, p[3] - 0.22, 0.07, 0.07, 0.05, "seed", FULL, "deco")
	end
	box(e, 0.5, 1.15, 0.5, 0.34, 0.12, 0.34, "white", MID, "deco")
end

Species.Pumpkin = function(e)
	for i, x in ipairs({ -0.95, -0.32, 0.32, 0.95 }) do
		local tall = if i == 2 or i == 3 then 1.55 else 1.3
		box(e, x, tall / 2 + 0.05, 0, 0.74, tall, 1.9, if i % 2 == 0 then "fruit" else "fruit2", YOUNG, "fruit")
		box(e, x, tall + 0.12, 0, 0.6, 0.14, 1.5, if i % 2 == 0 then "fruit2" else "fruit", MID, "fruit")
	end
	box(e, 0.1, 1.95, 0, 0.42, 0.55, 0.42, "wood", MID, "stem")
	box(e, 0.3, 2.3, 0, 0.3, 0.3, 0.3, "stem", FULL, "stem")
	leaf(e, -1.9, 0.3, 0.8, 1.4, 1.1, "leaf", MID)
	leaf(e, 1.8, 0.35, -0.7, 1.3, 1.0, "leaf2", MID)
	box(e, -1.3, 0.2, 1.3, 0.14, 0.14, 0.9, "stem2", FULL, "stem")
end

-- ===== Zona 2: Greenhouse Valley =====

Species.Cactus = function(e)
	box(e, 0, 1.45, 0, 1.0, 2.9, 1.0, "leaf", YOUNG, "leaf")
	box(e, 0, 1.45, -0.52, 0.2, 2.6, 0.06, "leaf2", YOUNG, "deco")
	box(e, -1.0, 1.45, 0, 1.0, 0.45, 0.45, "leaf", MID, "leaf")
	box(e, -1.38, 1.95, 0, 0.45, 1.1, 0.45, "leaf2", MID, "leaf")
	box(e, 1.0, 1.9, 0, 1.0, 0.45, 0.45, "leaf", FULL, "leaf")
	box(e, 1.38, 2.4, 0, 0.45, 1.1, 0.45, "leaf2", FULL, "leaf")
	for _, p in ipairs({ { 0.5, 0.8 }, { -0.5, 1.6 }, { 0.5, 2.3 } }) do
		box(e, p[1], p[2], -0.3, 0.08, 0.08, 0.3, "cream", MID, "deco")
	end
	box(e, 0, 3.05, 0, 0.6, 0.3, 0.6, "leaf2", MID, "leaf")
	box(e, 0, 3.35, 0, 0.5, 0.3, 0.5, "pink", FULL, "fruit")
	box(e, 0, 3.6, 0, 0.26, 0.26, 0.26, "gold", FULL, "deco")
end

Species.Blueberry = function(e)
	box(e, 0, 0.85, 0, 2.3, 1.5, 2.1, "leaf3", YOUNG, "leaf")
	box(e, -0.2, 1.7, 0.1, 1.7, 0.7, 1.5, "leaf", YOUNG, "leaf")
	box(e, 0.3, 2.1, -0.1, 1.0, 0.5, 1.0, "leaf2", MID, "leaf")
	box(e, -1.2, 0.5, 0.6, 0.9, 0.9, 0.9, "leaf", MID, "leaf")
	box(e, 1.25, 0.55, -0.4, 0.9, 0.9, 0.9, "leaf2", MID, "leaf")
	for _, p in ipairs({
		{ -0.7, 1.25, -1.1 }, { 0.5, 1.4, -1.1 }, { 1.2, 0.9, -0.95 }, { -1.15, 0.75, -0.8 },
		{ 0.0, 0.7, -1.15 }, { 0.2, 2.0, -0.7 }, { -0.5, 1.95, -0.6 },
	}) do
		bead(e, p[1], p[2], p[3], 0.5, "fruit", FULL)
		box(e, p[1], p[2] + 0.05, p[3] - 0.24, 0.14, 0.14, 0.05, "black", FULL, "deco")
	end
end

Species.Grape = function(e)
	box(e, -1.5, 1.7, 0, 0.24, 3.4, 0.24, "wood", YOUNG, "stem")
	box(e, 1.5, 1.7, 0, 0.24, 3.4, 0.24, "wood", YOUNG, "stem")
	box(e, 0, 3.35, 0, 3.4, 0.24, 0.3, "wood2", YOUNG, "stem")
	box(e, 0, 2.35, 0, 3.0, 0.14, 0.14, "wood2", MID, "stem")
	stalk(e, -0.9, 0.2, 2.0, 0.28, "stem2", YOUNG)
	for i = 0, 4 do
		leaf(e, -1.2 + i * 0.6, 3.05 - (i % 2) * 0.5, 0.05, 1.0, 0.9, if i % 2 == 0 then "leaf" else "leaf2", MID)
	end
	for _, cx in ipairs({ -0.7, 0.55 }) do
		for row = 0, 3 do
			local n = 4 - row
			for i = 0, n - 1 do
				bead(e, cx + (i - (n - 1) / 2) * 0.42, 2.9 - row * 0.4, -0.15, 0.42, if (i + row) % 2 == 0 then "fruit" else "fruit2", FULL)
			end
		end
	end
end

Species.Watermelon = function(e)
	box(e, 0, 0.8, 0, 2.5, 1.5, 1.8, "fruit", YOUNG, "fruit")
	box(e, 0, 1.65, 0, 2.1, 0.35, 1.45, "fruit", YOUNG, "fruit")
	box(e, 0, 0.12, 0, 2.1, 0.25, 1.5, "fruit2", YOUNG, "fruit")
	for _, x in ipairs({ -0.85, -0.28, 0.28, 0.85 }) do
		box(e, x, 0.85, -0.92, 0.2, 1.5, 0.06, "leaf3", MID, "deco")
		box(e, x, 1.84, 0, 0.2, 0.06, 1.2, "leaf3", MID, "deco")
	end
	box(e, 0.1, 2.0, 0, 0.3, 0.4, 0.3, "stem", MID, "stem")
	box(e, -0.9, 0.9, -0.93, 0.35, 0.2, 0.06, "fruit3", FULL, "deco")
	leaf(e, -2.2, 0.25, 0.7, 1.4, 1.0, "leaf", MID)
	leaf(e, 2.1, 0.3, -0.5, 1.4, 1.0, "leaf2", MID)
	box(e, 1.5, 0.5, 1.2, 0.34, 0.26, 0.34, "gold", FULL, "deco")
end

Species.Pineapple = function(e)
	box(e, 0, 1.0, 0, 1.4, 2.0, 1.4, "fruit", YOUNG, "fruit")
	box(e, 0, 1.0, 0, 1.45, 0.14, 1.45, "fruit2", MID, "fruit")
	for row = 0, 2 do
		for col = -1, 1 do
			box(e, col * 0.42, 0.45 + row * 0.6, -0.73, 0.34, 0.3, 0.06, if (row + col) % 2 == 0 then "fruit2" else "orange", MID, "deco")
		end
	end
	for _, o in ipairs({ { -1.0, 0 }, { 1.0, 0 }, { 0, -1.0 }, { 0, 1.0 } }) do
		box(e, o[1], 0.35, o[2], if o[1] == 0 then 0.5 else 1.0, 0.18, if o[1] == 0 then 1.0 else 0.5, "leaf", YOUNG, "leaf")
	end
	box(e, 0, 2.5, 0, 0.35, 1.0, 0.35, "leaf2", MID, "leaf")
	box(e, -0.4, 2.35, 0, 0.3, 0.75, 0.3, "leaf", MID, "leaf")
	box(e, 0.4, 2.35, 0, 0.3, 0.75, 0.3, "leaf", MID, "leaf")
	box(e, 0, 2.35, -0.38, 0.3, 0.7, 0.3, "leaf3", FULL, "leaf")
	box(e, 0, 2.35, 0.38, 0.3, 0.7, 0.3, "leaf3", FULL, "leaf")
	box(e, 0, 3.15, 0, 0.26, 0.5, 0.26, "leaf2", FULL, "leaf")
end

Species.Coconut = function(e)
	for i = 0, 5 do
		local w = 0.85 - i * 0.07
		box(e, i * 0.07, 0.38 + i * 0.76, 0, w, 0.78, w, if i % 2 == 0 then "wood" else "wood2", YOUNG, "stem")
	end
	box(e, 0.4, 4.7, 0, 0.8, 0.4, 0.8, "leaf3", YOUNG, "leaf")
	local fronds = {
		{ -1.5, 4.85, 0, 2.4, 0.2, 0.7 }, { 1.7, 4.85, 0, 2.4, 0.2, 0.7 },
		{ 0.4, 4.85, -1.5, 0.7, 0.2, 2.4 }, { 0.4, 4.85, 1.5, 0.7, 0.2, 2.4 },
	}
	for i, f in ipairs(fronds) do
		box(e, f[1], f[2], f[3], f[4], f[5], f[6], if i % 2 == 0 then "leaf" else "leaf2", MID, "leaf")
	end
	box(e, -2.9, 4.45, 0, 0.7, 0.2, 0.5, "leaf3", FULL, "leaf")
	box(e, 3.1, 4.45, 0, 0.7, 0.2, 0.5, "leaf3", FULL, "leaf")
	box(e, 0.4, 4.45, -2.9, 0.5, 0.2, 0.7, "leaf3", FULL, "leaf")
	box(e, 0.4, 4.45, 2.9, 0.5, 0.2, 0.7, "leaf3", FULL, "leaf")
	box(e, 0.4, 5.3, 0, 0.5, 0.7, 0.5, "leaf2", FULL, "leaf")
	orb(e, -0.15, 4.2, -0.5, 0.62, "fruit", FULL)
	orb(e, 0.85, 4.15, -0.4, 0.58, "fruit2", FULL)
	orb(e, 0.35, 4.1, 0.55, 0.6, "fruit", FULL)
end

Species.Dragonfruit = function(e)
	box(e, 0, 1.6, 0, 0.8, 3.2, 0.8, "leaf", YOUNG, "leaf")
	box(e, 0, 1.6, -0.5, 0.2, 3.0, 0.14, "leaf2", YOUNG, "deco")
	box(e, -0.55, 1.6, 0, 0.14, 3.0, 0.2, "leaf2", YOUNG, "deco")
	box(e, 0.6, 1.6, 0, 0.14, 3.0, 0.2, "leaf3", YOUNG, "deco")
	box(e, -0.75, 2.1, 0, 0.7, 0.4, 0.5, "leaf", MID, "leaf")
	box(e, -0.95, 2.6, 0, 0.4, 0.8, 0.5, "leaf2", MID, "leaf")
	box(e, 0.75, 2.5, 0, 0.7, 0.4, 0.5, "leaf", MID, "leaf")
	box(e, 0.95, 3.0, 0, 0.4, 0.8, 0.5, "leaf2", MID, "leaf")
	box(e, 0, 3.45, 0, 0.7, 0.3, 0.7, "leaf2", MID, "leaf")
	box(e, -0.95, 3.3, 0, 0.8, 1.1, 0.8, "fruit", FULL, "fruit")
	box(e, 0.95, 3.8, 0, 0.8, 1.1, 0.8, "fruit", FULL, "fruit")
	box(e, 0, 3.75, 0, 0.5, 0.7, 0.5, "fruit2", FULL, "fruit")
	for _, p in ipairs({ { -1.4, 3.1 }, { -0.5, 3.5 }, { 1.4, 3.6 }, { 0.5, 4.0 } }) do
		box(e, p[1], p[2], 0, 0.36, 0.3, 0.2, "leaf2", FULL, "leaf")
	end
	box(e, -0.95, 3.3, -0.42, 0.2, 0.2, 0.06, "white", FULL, "deco")
end

-- ===== Zona 3: Mystic Grove =====

Species.Starfruit = function(e)
	stalk(e, 0, 0, 2.6, 0.55, "wood", YOUNG)
	box(e, 0, 2.9, 0, 2.2, 0.8, 2.0, "leaf3", YOUNG, "leaf")
	box(e, 0, 3.5, 0, 1.6, 0.6, 1.5, "leaf", MID, "leaf")
	box(e, -1.2, 2.55, 0, 0.9, 0.5, 0.9, "leaf2", MID, "leaf")
	box(e, 1.2, 2.55, 0, 0.9, 0.5, 0.9, "leaf2", MID, "leaf")
	for _, p in ipairs({ { -1.05, 1.7 }, { 1.0, 2.05 } }) do
		local cx, cy = p[1], p[2]
		box(e, cx, cy, -1.05, 0.75, 0.75, 0.4, "fruit", FULL, "glow")
		box(e, cx, cy + 0.55, -1.05, 0.38, 0.5, 0.4, "fruit", FULL, "glow")
		box(e, cx, cy - 0.55, -1.05, 0.38, 0.5, 0.4, "fruit", FULL, "glow")
		box(e, cx - 0.55, cy, -1.05, 0.5, 0.38, 0.4, "fruit", FULL, "glow")
		box(e, cx + 0.55, cy, -1.05, 0.5, 0.38, 0.4, "fruit", FULL, "glow")
		box(e, cx - 0.4, cy + 0.4, -1.05, 0.3, 0.3, 0.38, "fruit2", FULL, "glow")
		box(e, cx + 0.4, cy + 0.4, -1.05, 0.3, 0.3, 0.38, "fruit2", FULL, "glow")
		box(e, cx - 0.4, cy - 0.4, -1.05, 0.3, 0.3, 0.38, "fruit2", FULL, "glow")
		box(e, cx + 0.4, cy - 0.4, -1.05, 0.3, 0.3, 0.38, "fruit2", FULL, "glow")
	end
	box(e, 0, 4.0, 0, 0.3, 0.3, 0.3, "gold", FULL, "glow")
end

Species.EmberRose = function(e)
	stalk(e, 0, 0, 2.7, 0.34, "stem2", YOUNG)
	leaf(e, -0.8, 0.9, 0, 1.2, 0.6, "leaf3", YOUNG)
	leaf(e, 0.8, 1.5, 0, 1.2, 0.6, "leaf3", MID)
	box(e, 0.3, 1.2, -0.25, 0.1, 0.22, 0.1, "red", MID, "deco")
	box(e, -0.3, 1.9, 0.25, 0.1, 0.22, 0.1, "red", MID, "deco")
	box(e, 0, 3.0, 0, 1.9, 0.4, 1.9, "fruit2", MID, "fruit")
	box(e, 0, 3.35, 0, 1.5, 0.4, 1.5, "fruit", MID, "fruit")
	box(e, 0, 3.7, 0, 1.1, 0.4, 1.1, "fruit2", FULL, "fruit")
	box(e, 0, 4.0, 0, 0.7, 0.4, 0.7, "fruit", FULL, "fruit")
	box(e, 0, 4.3, 0, 0.36, 0.4, 0.36, "ember", FULL, "glow")
	for _, o in ipairs({ { -0.75, -0.75 }, { 0.75, -0.75 }, { -0.75, 0.75 }, { 0.75, 0.75 } }) do
		box(e, o[1], 3.25, o[2], 0.55, 0.5, 0.55, "fruit3", FULL, "fruit")
	end
	box(e, -0.3, 4.9, 0.1, 0.2, 0.4, 0.2, "ember", FULL, "glow")
	box(e, 0.35, 5.2, -0.1, 0.16, 0.34, 0.16, "orange", FULL, "glow")
end

Species.CrystalBerry = function(e)
	box(e, 0, 0.3, 0, 2.2, 0.6, 2.0, "rock", YOUNG, "deco")
	box(e, 0, 1.9, 0, 0.8, 2.8, 0.8, "fruit", YOUNG, "glow")
	box(e, 0, 3.55, 0, 0.5, 0.6, 0.5, "fruit3", MID, "glow")
	box(e, -0.85, 1.4, 0.1, 0.6, 1.9, 0.6, "fruit2", YOUNG, "glow")
	box(e, -0.85, 2.6, 0.1, 0.36, 0.5, 0.36, "fruit3", MID, "glow")
	box(e, 0.85, 1.2, -0.1, 0.6, 1.5, 0.6, "fruit2", MID, "glow")
	box(e, 0.85, 2.15, -0.1, 0.36, 0.45, 0.36, "fruit3", MID, "glow")
	box(e, 0.1, 1.0, -0.85, 0.5, 1.2, 0.5, "fruit", MID, "glow")
	box(e, -0.5, 0.9, 0.85, 0.5, 1.0, 0.5, "fruit", FULL, "glow")
	box(e, 0.6, 0.8, 0.75, 0.4, 0.8, 0.4, "fruit2", FULL, "glow")
	orb(e, -0.3, 0.95, -1.15, 0.42, "white", FULL, "glow")
	orb(e, 0.7, 0.55, -1.05, 0.36, "white", FULL, "glow")
	leaf(e, -1.3, 0.35, -0.7, 0.8, 0.5, "leaf3", MID)
	leaf(e, 1.3, 0.35, 0.6, 0.8, 0.5, "leaf3", MID)
end

Species.Moonflower = function(e)
	stalk(e, 0, 0, 3.2, 0.34, "stem", YOUNG)
	box(e, 0.3, 3.3, 0, 0.3, 0.7, 0.3, "stem", MID, "stem")
	leaf(e, -0.9, 1.0, 0, 1.4, 0.7, "leaf", YOUNG)
	leaf(e, 0.9, 1.7, 0, 1.4, 0.7, "leaf2", MID)
	ring(e, 0.3, 4.0, -0.3, 1.05, 8, 0.75, 0.75, 0.3, "fruit", "white", MID, "fruit")
	ring(e, 0.3, 4.0, -0.3, 0.6, 4, 0.55, 0.55, 0.32, "fruit3", "fruit3", FULL, "fruit", math.pi / 4)
	box(e, 0.3, 4.0, -0.3, 0.8, 0.8, 0.46, "gold", MID, "glow")
	-- luna creciente flotante
	box(e, -1.7, 5.7, 0.4, 0.4, 1.6, 0.34, "cream", FULL, "glow")
	box(e, -1.35, 6.5, 0.4, 0.5, 0.4, 0.34, "cream", FULL, "glow")
	box(e, -1.35, 4.9, 0.4, 0.5, 0.4, 0.34, "cream", FULL, "glow")
	box(e, -0.95, 6.75, 0.4, 0.4, 0.34, 0.34, "cream", FULL, "glow")
	box(e, -0.95, 4.65, 0.4, 0.4, 0.34, 0.34, "cream", FULL, "glow")
	box(e, 1.9, 5.2, 0.2, 0.2, 0.2, 0.2, "white", FULL, "glow")
	box(e, 2.3, 4.5, -0.2, 0.16, 0.16, 0.16, "white", FULL, "glow")
end

Species.CelestialOrchid = function(e)
	box(e, 0, 1.0, 0, 0.28, 2.0, 0.28, "stem", YOUNG, "stem")
	box(e, 0.45, 2.45, 0, 0.28, 1.0, 0.28, "stem", YOUNG, "stem")
	box(e, 1.05, 3.45, 0, 0.28, 1.1, 0.28, "stem", MID, "stem")
	box(e, 1.6, 4.5, 0, 0.28, 1.1, 0.28, "stem", MID, "stem")
	leaf(e, -1.0, 0.5, 0, 2.0, 0.6, "leaf", YOUNG)
	leaf(e, 1.0, 0.4, 0.3, 2.0, 0.6, "leaf2", YOUNG)
	for _, f in ipairs({ { 0.45, 2.9, 0.9 }, { 1.05, 4.0, 1.0 }, { 1.7, 5.15, 1.15 } }) do
		local cx, cy, s = f[1], f[2], f[3]
		box(e, cx - 0.5 * s, cy + 0.35 * s, -0.4, 0.8 * s, 0.9 * s, 0.22, "white", MID, "fruit")
		box(e, cx + 0.5 * s, cy + 0.35 * s, -0.4, 0.8 * s, 0.9 * s, 0.22, "white", MID, "fruit")
		box(e, cx, cy + 0.75 * s, -0.4, 0.7 * s, 0.75 * s, 0.22, "fruit3", MID, "fruit")
		box(e, cx - 0.55 * s, cy - 0.15 * s, -0.4, 0.55 * s, 0.5 * s, 0.22, "fruit3", FULL, "fruit")
		box(e, cx + 0.55 * s, cy - 0.15 * s, -0.4, 0.55 * s, 0.5 * s, 0.22, "fruit3", FULL, "fruit")
		box(e, cx, cy - 0.3 * s, -0.46, 0.55 * s, 0.7 * s, 0.22, "fruit", FULL, "fruit")
		box(e, cx, cy + 0.1 * s, -0.5, 0.3 * s, 0.3 * s, 0.2, "gold", FULL, "glow")
	end
	box(e, -1.1, 4.4, -0.2, 0.2, 0.2, 0.2, "white", FULL, "glow")
	box(e, 0.1, 5.4, 0.3, 0.16, 0.16, 0.16, "cyan", FULL, "glow")
	box(e, 2.6, 3.2, 0.1, 0.18, 0.18, 0.18, "gold", FULL, "glow")
	box(e, -0.6, 3.2, 0.2, 0.14, 0.14, 0.14, "white", FULL, "glow")
end

Species.PhoenixBloom = function(e)
	stalk(e, 0, 0, 2.3, 0.4, "black", YOUNG)
	leaf(e, -1.0, 0.9, 0, 1.4, 0.5, "leaf3", YOUNG)
	leaf(e, 1.0, 1.4, 0, 1.4, 0.5, "leaf3", YOUNG)
	box(e, 0, 2.6, 0, 1.5, 0.5, 1.0, "red", YOUNG, "fruit")
	box(e, 0, 3.7, 0, 0.85, 2.0, 0.55, "fruit", MID, "fruit")
	box(e, -0.95, 3.2, 0, 0.6, 1.5, 0.45, "fruit2", MID, "fruit")
	box(e, 0.95, 3.2, 0, 0.6, 1.5, 0.45, "fruit2", MID, "fruit")
	box(e, 0, 5.1, 0, 0.5, 1.1, 0.4, "ember", FULL, "glow")
	box(e, -0.95, 4.2, 0, 0.4, 0.9, 0.35, "ember", FULL, "glow")
	box(e, 0.95, 4.2, 0, 0.4, 0.9, 0.35, "ember", FULL, "glow")
	box(e, -1.7, 2.9, 0, 0.5, 1.0, 0.35, "red", FULL, "fruit")
	box(e, 1.7, 2.9, 0, 0.5, 1.0, 0.35, "red", FULL, "fruit")
	box(e, 0, 1.5, 0.75, 0.4, 1.4, 0.3, "orange", FULL, "glow")
	box(e, -0.4, 1.0, 1.0, 0.34, 1.1, 0.26, "red", FULL, "glow")
	box(e, 0.4, 1.0, 1.0, 0.34, 1.1, 0.26, "ember", FULL, "glow")
	box(e, 0, 3.7, -0.34, 0.3, 0.4, 0.1, "white", FULL, "glow")
end

Species.CosmicPeony = function(e)
	stalk(e, 0, 0, 2.6, 0.4, "stem2", YOUNG)
	leaf(e, -1.0, 0.9, 0, 1.5, 0.7, "leaf3", YOUNG)
	leaf(e, 1.0, 1.5, 0, 1.5, 0.7, "leaf3", YOUNG)
	box(e, 0, 2.85, 0, 2.8, 0.4, 2.8, "fruit2", YOUNG, "fruit")
	box(e, 0, 3.25, 0, 2.3, 0.4, 2.3, "fruit", MID, "fruit")
	box(e, 0, 3.65, 0, 1.8, 0.4, 1.8, "fruit3", MID, "fruit")
	box(e, 0, 4.05, 0, 1.3, 0.4, 1.3, "fruit", FULL, "fruit")
	box(e, 0, 4.45, 0, 0.8, 0.4, 0.8, "fruit3", FULL, "fruit")
	box(e, 0, 4.8, 0, 0.4, 0.34, 0.4, "white", FULL, "glow")
	ringFlat(e, 0, 3.5, 0, 2.7, 8, 0.28, 0.28, 0.28, "violet", "cyan", FULL, "glow")
	ringFlat(e, 0, 5.3, 0, 1.3, 4, 0.2, 0.2, 0.2, "white", "pink", FULL, "glow", math.pi / 4)
	box(e, 0, 5.9, 0, 0.16, 0.16, 0.16, "white", FULL, "glow")
end

Species.AuroraLotus = function(e)
	box(e, 0, 0.18, 0, 3.8, 0.2, 3.8, "teal", YOUNG, "leaf")
	box(e, 0, 0.1, 0, 3.0, 0.14, 3.0, "cyan", YOUNG, "glow")
	ringFlat(e, 0, 1.0, 0, 1.15, 8, 0.7, 1.6, 0.4, "fruit", "fruit3", MID, "fruit")
	ringFlat(e, 0, 1.45, 0, 0.7, 4, 0.55, 1.5, 0.4, "fruit3", "fruit", MID, "fruit", math.pi / 4)
	box(e, 0, 0.9, 0, 0.7, 1.4, 0.7, "gold", MID, "glow")
	box(e, 0, 1.8, 0, 0.4, 0.4, 0.4, "white", FULL, "glow")
	-- cintas de aurora
	box(e, -0.9, 3.4, 0.2, 0.34, 3.0, 0.2, "cyan", FULL, "glow")
	box(e, 0, 4.0, 0, 0.34, 3.6, 0.2, "mint", FULL, "glow")
	box(e, 0.9, 3.6, -0.2, 0.34, 3.2, 0.2, "violet", FULL, "glow")
	box(e, -0.45, 5.2, 0, 0.2, 0.5, 0.2, "white", FULL, "glow")
	box(e, 0.5, 5.6, 0, 0.2, 0.5, 0.2, "white", FULL, "glow")
	leaf(e, -1.7, 0.4, 1.2, 1.0, 1.0, "leaf2", MID)
	leaf(e, 1.8, 0.4, -1.2, 1.0, 1.0, "leaf2", MID)
end

-- ===== Arquetipos reutilizables (siluetas distintas con pocos parámetros) =====

-- Hortaliza de raíz: bulbo que asoma + penacho de hojas.
local function rootVeg(e: Emit, w: number, h: number, leafH: number, leafKey: string)
	box(e, 0, h / 2, 0, w, h, w, "fruit", YOUNG, "fruit")
	box(e, 0, h + 0.1, 0, w * 0.7, 0.22, w * 0.7, "fruit2", MID, "fruit")
	box(e, -w * 0.25, h * 0.55, -w * 0.52, w * 0.2, h * 0.3, 0.1, "fruit3", MID, "deco")
	for i = -1, 1 do
		box(e, i * w * 0.26, h + leafH / 2, 0, 0.2, leafH, 0.2, leafKey, YOUNG, "stem")
		box(e, i * w * 0.4, h + leafH, 0, 0.5, 0.14, 0.32, "leaf2", MID, "leaf")
	end
end

-- Cabeza de hojas apiladas (lechuga, col).
local function leafyHead(e: Emit, r: number, layers: number)
	for i = 1, layers do
		local size = r * (1.1 - (i - 1) * 0.17)
		box(e, 0, 0.25 + (i - 1) * 0.36, 0, size, 0.4, size, if i % 2 == 1 then "fruit" else "fruit2", YOUNG + (i / layers) * 0.3, "fruit")
	end
	leaf(e, -r * 0.65, 0.35, 0, r * 0.7, r * 0.5, "leaf", MID)
	leaf(e, r * 0.65, 0.4, 0, r * 0.7, r * 0.5, "leaf2", MID)
	leaf(e, 0, 0.3, -r * 0.65, r * 0.5, r * 0.7, "leaf", FULL)
	leaf(e, 0, 0.45, r * 0.65, r * 0.5, r * 0.7, "leaf2", FULL)
end

-- Enredadera con vainas colgando de una estaca.
local function podVine(e: Emit, h: number, pods: number)
	box(e, 0, h / 2, 0.5, 0.18, h, 0.18, "wood", 0, "stem")
	stalk(e, 0, 0, h * 0.8, 0.2, "stem", YOUNG)
	for i = 1, pods do
		local side = if i % 2 == 0 then -1 else 1
		leaf(e, side * 0.5, 0.5 + i * (h / (pods + 1)) * 0.9, 0, 0.9, 0.5, if side > 0 then "leaf" else "leaf2", YOUNG + i * 0.05)
		box(e, side * 0.45, 0.35 + i * (h / (pods + 1)) * 0.9, -0.3, 0.22, 0.7, 0.22, "fruit", MID + i * 0.04, "fruit")
	end
end

-- Arbusto con bayas.
local function berryBush(e: Emit, r: number, h: number, beads: number, beadR: number)
	stalk(e, 0, 0, h * 0.6, 0.28, "stem", YOUNG)
	box(e, 0, h * 0.7, 0, r * 2, h * 0.45, r * 2, "leaf", YOUNG, "leaf")
	box(e, 0, h * 1.0, 0, r * 1.4, h * 0.3, r * 1.4, "leaf2", MID, "leaf")
	for i = 0, beads - 1 do
		local a = (i / beads) * math.pi * 2
		bead(e, math.cos(a) * r * 0.95, h * 0.65 + (i % 2) * 0.35, math.sin(a) * r * 0.95 - 0.15, beadR, "fruit", MID + (i % 3) * 0.12)
	end
end

-- Árbol frutal pequeño.
local function fruitTree(e: Emit, trunkH: number, canopyR: number, fruits: number, fruitR: number, canopyKey: string)
	box(e, 0, trunkH / 2, 0, 0.55, trunkH, 0.55, "bark", YOUNG, "stem")
	box(e, 0, trunkH + 0.4, 0, canopyR * 2, 0.9, canopyR * 2, canopyKey, YOUNG, "leaf")
	box(e, 0, trunkH + 1.2, 0, canopyR * 1.5, 0.9, canopyR * 1.5, "leaf2", MID, "leaf")
	box(e, 0, trunkH + 1.9, 0, canopyR * 0.9, 0.7, canopyR * 0.9, canopyKey, MID, "leaf")
	for i = 0, fruits - 1 do
		local a = (i / fruits) * math.pi * 2 + 0.4
		bead(e, math.cos(a) * canopyR * 0.95, trunkH + 0.2 + (i % 2) * 0.7, math.sin(a) * canopyR * 0.95 - 0.1, fruitR, "fruit", MID + (i % 3) * 0.12)
	end
end

-- Flor de disco vertical con tallo.
local function discFlower(e: Emit, h: number, petals: number, petalR: number, petalSize: number, centerKey: string, glowing: boolean)
	stalk(e, 0, 0, h, 0.3, "stem", YOUNG)
	leaf(e, -0.8, h * 0.35, 0, 1.2, 0.6, "leaf", YOUNG)
	leaf(e, 0.8, h * 0.55, 0, 1.2, 0.6, "leaf2", MID)
	ring(e, 0, h + petalR, -0.25, petalR, petals, petalSize, petalSize, 0.28, "fruit", "fruit3", MID, if glowing then "glow" else "fruit")
	box(e, 0, h + petalR, -0.25, petalR * 0.8, petalR * 0.8, 0.4, centerKey, MID, if glowing then "glow" else "deco")
end

-- Seta: tallo + sombrero en capas con motas.
local function mushroom(e: Emit, stemH: number, capR: number, spots: number, glowing: boolean)
	box(e, 0, stemH / 2, 0, capR * 0.4, stemH, capR * 0.4, "cream", YOUNG, "stem")
	box(e, 0, stemH + 0.2, 0, capR * 2, 0.5, capR * 2, "fruit2", YOUNG, "fruit")
	box(e, 0, stemH + 0.6, 0, capR * 1.7, 0.5, capR * 1.7, "fruit", MID, "fruit")
	box(e, 0, stemH + 1.0, 0, capR * 1.1, 0.4, capR * 1.1, "fruit3", MID, "fruit")
	for i = 0, spots - 1 do
		local a = (i / spots) * math.pi * 2
		box(e, math.cos(a) * capR * 0.7, stemH + 1.0, math.sin(a) * capR * 0.7 - 0.05, 0.3, 0.14, 0.3, "white", FULL, if glowing then "glow" else "deco")
	end
end

-- Árbol grande/mágico con orbes.
local function bigTree(e: Emit, trunkW: number, trunkH: number, canopyR: number, tiers: number, orbKey: string, orbs: number)
	box(e, 0, trunkH / 2, 0, trunkW, trunkH, trunkW, "bark", YOUNG, "stem")
	box(e, -trunkW * 0.8, 0.25, 0, trunkW * 0.7, 0.5, trunkW * 0.5, "wood2", YOUNG, "stem")
	box(e, trunkW * 0.8, 0.25, 0, trunkW * 0.7, 0.5, trunkW * 0.5, "wood2", YOUNG, "stem")
	for i = 1, tiers do
		local size = canopyR * 2 * (1.05 - (i - 1) * 0.22)
		box(e, 0, trunkH + (i - 1) * 0.8, 0, size, 0.85, size, if i % 2 == 1 then "fruit" else "fruit3", YOUNG + (i / tiers) * 0.3, "fruit")
	end
	for i = 0, orbs - 1 do
		local a = (i / orbs) * math.pi * 2
		box(e, math.cos(a) * canopyR * 0.9, trunkH - 0.5 + (i % 2) * 0.9, math.sin(a) * canopyR * 0.9, 0.4, 0.4, 0.4, orbKey, FULL, "glow")
	end
end

-- ===== Zona 1 (nuevas) =====
Species.Radish = function(e) rootVeg(e, 0.9, 0.9, 1.3, "leaf") end
Species.Lettuce = function(e) leafyHead(e, 1.6, 4) end
Species.Onion = function(e) rootVeg(e, 1.2, 1.1, 1.6, "leaf2") end
Species.Cabbage = function(e) leafyHead(e, 2.0, 5) end
Species.Peas = function(e) podVine(e, 3.0, 5) end
Species.Raspberry = function(e) berryBush(e, 1.0, 1.8, 7, 0.34) end
Species.Eggplant = function(e)
	stalk(e, 0, 0, 1.6, 0.3, "stem", YOUNG)
	leafRing(e, 1.0, 0.8, 1.3, YOUNG)
	box(e, -0.35, 0.9, -0.3, 0.7, 1.3, 0.7, "fruit", YOUNG, "fruit")
	box(e, -0.35, 1.65, -0.3, 0.5, 0.35, 0.5, "fruit2", MID, "fruit")
	box(e, -0.35, 1.9, -0.3, 0.55, 0.2, 0.55, "leaf3", MID, "leaf")
	box(e, 0.45, 0.8, 0.1, 0.65, 1.1, 0.65, "fruit", MID, "fruit")
	box(e, 0.45, 1.45, 0.1, 0.45, 0.3, 0.45, "fruit2", FULL, "fruit")
	box(e, 0.45, 1.68, 0.1, 0.5, 0.2, 0.5, "leaf3", FULL, "leaf")
	box(e, -0.5, 1.0, -0.68, 0.14, 0.5, 0.08, "white", FULL, "deco")
end

-- ===== Zona 2 (nuevas) =====
Species.Broccoli = function(e)
	stalk(e, 0, 0, 1.4, 0.55, "leaf2", YOUNG)
	leafRing(e, 0.7, 0.7, 1.1, YOUNG)
	for _, c in ipairs({ { 0, 1.9, 0, 1.5 }, { -0.8, 1.7, 0.1, 1.0 }, { 0.8, 1.75, -0.1, 1.0 }, { 0, 2.1, 0.7, 0.9 }, { 0, 2.0, -0.7, 0.9 } }) do
		orb(e, c[1], c[2], c[3], c[4], "fruit", MID + math.abs(c[1]) * 0.1)
	end
end
Species.Lemon = function(e) fruitTree(e, 1.8, 1.4, 5, 0.55, "leaf") end
Species.BellPepper = function(e)
	stalk(e, 0, 0, 1.8, 0.3, "stem", YOUNG)
	leafRing(e, 1.2, 0.7, 1.2, YOUNG)
	for i, x in ipairs({ -0.6, 0.6, 0 }) do
		box(e, x, 0.95 + i * 0.12, -0.15 * i, 0.8, 0.9, 0.8, "fruit", MID + i * 0.1, "fruit")
		box(e, x, 1.5 + i * 0.12, -0.15 * i, 0.3, 0.25, 0.3, "leaf3", MID + i * 0.1, "stem")
		box(e, x - 0.2, 0.95 + i * 0.12, -0.15 * i - 0.42, 0.18, 0.5, 0.06, "white", FULL, "deco")
	end
end
Species.Cherry = function(e)
	fruitTree(e, 2.2, 1.5, 0, 0.4, "pink")
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.5
		box(e, math.cos(a) * 1.2, 2.5, math.sin(a) * 1.2, 0.06, 0.7, 0.06, "stem2", MID, "stem")
		bead(e, math.cos(a) * 1.2, 2.0, math.sin(a) * 1.2, 0.5, "fruit", MID + i * 0.1)
		bead(e, math.cos(a) * 1.2 + 0.3, 2.1, math.sin(a) * 1.2, 0.46, "fruit2", MID + i * 0.1)
	end
end
Species.Peach = function(e) fruitTree(e, 2.0, 1.6, 6, 0.7, "leaf") end
Species.Mango = function(e) fruitTree(e, 2.4, 1.8, 5, 0.8, "leaf3") end
Species.Lavender = function(e)
	for i = -2, 2 do
		local h = 2.6 - math.abs(i) * 0.35
		stalk(e, i * 0.38, 0, h, 0.12, "stem", YOUNG)
		for j = 0, 3 do
			box(e, i * 0.38, h - 0.3 + j * 0.28, 0, 0.26, 0.26, 0.26, if j % 2 == 0 then "fruit" else "fruit3", MID + j * 0.08, "fruit")
		end
	end
	leaf(e, -0.9, 0.5, 0, 1.0, 0.5, "leaf", YOUNG)
	leaf(e, 0.9, 0.55, 0, 1.0, 0.5, "leaf2", YOUNG)
end
Species.Banana = function(e)
	stalk(e, 0, 0, 3.2, 0.5, "stem", YOUNG)
	leaf(e, -1.3, 3.3, 0, 2.2, 0.8, "leaf", YOUNG)
	leaf(e, 1.3, 3.4, 0, 2.2, 0.8, "leaf2", YOUNG)
	leaf(e, 0, 3.4, -1.3, 0.8, 2.2, "leaf", MID)
	leaf(e, 0, 3.5, 1.3, 0.8, 2.2, "leaf2", MID)
	for i = 0, 3 do
		box(e, -0.2 + i * 0.22, 2.7 - i * 0.12, -0.65, 0.22, 0.9, 0.3, "fruit", MID + i * 0.1, "fruit")
	end
	box(e, 0.3, 3.1, -0.4, 0.3, 0.3, 0.3, "violet", FULL, "deco")
end

-- ===== Zona 3 (nuevas) =====
Species.GlowShroom = function(e) mushroom(e, 1.6, 1.3, 6, true) end
Species.FrostLily = function(e) discFlower(e, 2.4, 8, 1.0, 0.7, "white", true) end
Species.GiantMushroom = function(e) mushroom(e, 2.6, 2.0, 8, false) end
Species.MagicTree = function(e) bigTree(e, 0.9, 2.6, 1.9, 3, "cyan", 6) end
Species.ThunderBloom = function(e)
	discFlower(e, 2.8, 6, 1.1, 0.9, "gold", true)
	box(e, -1.4, 4.4, -0.2, 0.2, 1.0, 0.16, "gold", FULL, "glow")
	box(e, -1.2, 3.8, -0.2, 0.4, 0.2, 0.16, "gold", FULL, "glow")
	box(e, 1.5, 4.6, -0.2, 0.2, 1.0, 0.16, "gold", FULL, "glow")
	box(e, 1.3, 4.0, -0.2, 0.4, 0.2, 0.16, "gold", FULL, "glow")
end
Species.GoldenApple = function(e)
	fruitTree(e, 2.4, 1.6, 0, 0.4, "leaf2")
	orb(e, 0, 2.2, -0.6, 1.5, "fruit", MID)
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.6
		bead(e, math.cos(a) * 1.5, 3.3, math.sin(a) * 1.5, 0.6, "fruit", MID + i * 0.08)
	end
	box(e, 0, 3.15, -0.6, 0.2, 0.4, 0.1, "leaf3", FULL, "stem")
	ringFlat(e, 0, 4.7, 0, 0.9, 4, 0.2, 0.2, 0.2, "gold", "white", FULL, "glow")
end
Species.AncientTree = function(e) bigTree(e, 1.3, 3.2, 2.4, 4, "gold", 7) end
Species.SolarSunflower = function(e)
	discFlower(e, 3.4, 12, 1.5, 0.8, "orange", true)
	ringFlat(e, 0, 5.6, 0, 1.9, 6, 0.24, 0.24, 0.24, "gold", "white", FULL, "glow")
end
Species.MoltenLily = function(e)
	discFlower(e, 2.2, 8, 1.2, 0.9, "ember", true)
	box(e, 0, 0.25, 0, 3.0, 0.2, 3.0, "rock", YOUNG, "deco")
	box(e, 0, 0.18, 0, 2.2, 0.16, 2.2, "orange", YOUNG, "glow")
	box(e, -0.9, 4.1, 0.2, 0.2, 0.2, 0.2, "ember", FULL, "glow")
	box(e, 0.8, 4.6, 0.3, 0.16, 0.16, 0.16, "orange", FULL, "glow")
end
Species.AmberVine = function(e)
	stalk(e, 0, 0, 3.6, 0.36, "wood2", YOUNG)
	for i = 0, 5 do
		local side = if i % 2 == 0 then -1 else 1
		box(e, side * 0.7, 0.8 + i * 0.55, 0, 1.2, 0.2, 0.4, "leaf2", YOUNG + i * 0.05, "leaf")
		box(e, side * 1.0, 0.5 + i * 0.55, -0.2, 0.55, 0.75, 0.55, "fruit", MID + i * 0.06, "glow")
	end
	box(e, 0, 3.9, 0, 0.8, 0.5, 0.8, "gold", FULL, "glow")
end

Species.VoidPlant = function(e)
	stalk(e, 0, 0, 2.2, 0.4, "black", YOUNG)
	for i = -1, 1, 2 do
		box(e, i * 0.6, 1.2, 0, 0.3, 0.3, 0.3, "black", YOUNG, "stem")
		box(e, i * 1.0, 1.9, 0, 0.28, 0.9, 0.28, "indigo", MID, "stem")
		box(e, i * 1.3, 2.6, 0, 0.24, 0.8, 0.24, "black", MID, "stem")
		box(e, i * 1.5, 3.2, 0, 0.3, 0.3, 0.3, "violet", FULL, "glow")
	end
	orb(e, 0, 3.4, 0, 1.6, "fruit", MID, "fruit")
	ringFlat(e, 0, 3.4, 0, 1.5, 8, 0.22, 0.22, 0.22, "violet", "indigo", FULL, "glow")
	box(e, -0.25, 3.5, -0.85, 0.2, 0.2, 0.1, "white", FULL, "glow")
	box(e, 0.25, 3.5, -0.85, 0.2, 0.2, 0.1, "white", FULL, "glow")
end
Species.PhoenixTree = function(e)
	bigTree(e, 1.0, 2.8, 1.7, 3, "ember", 5)
	for i = 1, 3 do
		box(e, -1.9 - i * 0.5, 3.4 + i * 0.55, 0, 1.2, 0.34, 0.2, if i % 2 == 0 then "fruit3" else "ember", FULL, "glow")
		box(e, 1.9 + i * 0.5, 3.4 + i * 0.55, 0, 1.2, 0.34, 0.2, if i % 2 == 0 then "fruit3" else "ember", FULL, "glow")
	end
	box(e, 0, 5.4, 0, 0.5, 0.9, 0.4, "ember", FULL, "glow")
end
Species.StarBlossom = function(e)
	stalk(e, 0, 0, 3.0, 0.36, "stem", YOUNG)
	leaf(e, -1.0, 1.2, 0, 1.4, 0.7, "leaf3", YOUNG)
	leaf(e, 1.0, 1.8, 0, 1.4, 0.7, "leaf3", YOUNG)
	ring(e, 0, 4.3, -0.3, 1.3, 5, 0.9, 0.9, 0.3, "fruit", "fruit3", MID, "fruit", math.pi / 2)
	ring(e, 0, 4.3, -0.3, 0.55, 5, 0.5, 0.5, 0.34, "gold", "white", MID, "glow", math.pi / 2 + math.pi / 5)
	box(e, 0, 4.3, -0.3, 0.8, 0.8, 0.46, "white", FULL, "glow")
	box(e, -2.0, 5.6, 0.3, 0.3, 0.3, 0.2, "gold", FULL, "glow")
	box(e, 2.1, 5.1, 0.3, 0.24, 0.24, 0.2, "white", FULL, "glow")
	box(e, 1.4, 6.3, 0.2, 0.2, 0.2, 0.2, "gold", FULL, "glow")
end
Species.DreamWillow = function(e)
	box(e, 0, 1.6, 0, 0.9, 3.2, 0.9, "bark", YOUNG, "stem")
	box(e, 0, 3.4, 0, 3.8, 0.9, 3.8, "fruit", YOUNG, "fruit")
	box(e, 0, 4.2, 0, 2.6, 0.8, 2.6, "fruit3", MID, "fruit")
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local len = 2.4 - (i % 3) * 0.5
		box(e, math.cos(a) * 1.7, 3.0 - len / 2, math.sin(a) * 1.7, 0.18, len, 0.18, if i % 2 == 0 then "cyan" else "pink", MID + (i % 3) * 0.1, "glow")
	end
	box(e, 0, 5.0, 0, 0.5, 0.5, 0.5, "white", FULL, "glow")
end
Species.ObsidianRose = function(e)
	stalk(e, 0, 0, 2.4, 0.3, "black", YOUNG)
	box(e, -0.5, 0.9, -0.15, 0.2, 0.2, 0.3, "black", YOUNG, "deco")
	box(e, 0.5, 1.5, -0.15, 0.2, 0.2, 0.3, "black", MID, "deco")
	leaf(e, -0.9, 1.3, 0, 1.2, 0.6, "leaf3", YOUNG)
	box(e, 0, 2.7, 0, 2.0, 0.5, 2.0, "black", YOUNG, "fruit")
	box(e, 0, 3.1, 0, 1.6, 0.5, 1.6, "fruit", MID, "fruit")
	box(e, 0, 3.5, 0, 1.2, 0.5, 1.2, "black", MID, "fruit")
	box(e, 0, 3.9, 0, 0.8, 0.5, 0.8, "fruit", FULL, "fruit")
	ringFlat(e, 0, 3.0, 0, 1.2, 8, 0.2, 0.2, 0.2, "rose", "violet", FULL, "glow")
	box(e, 0, 4.3, 0, 0.3, 0.3, 0.3, "white", FULL, "glow")
end

Species.MoonLotus = function(e)
	box(e, 0, 0.18, 0, 3.8, 0.2, 3.8, "leaf3", YOUNG, "leaf")
	ringFlat(e, 0, 1.0, 0, 1.2, 8, 0.7, 1.5, 0.4, "white", "fruit", MID, "fruit")
	ringFlat(e, 0, 1.4, 0, 0.7, 4, 0.5, 1.4, 0.4, "fruit3", "white", MID, "fruit", math.pi / 4)
	box(e, 0, 0.9, 0, 0.7, 1.3, 0.7, "gold", MID, "glow")
	orb(e, 0, 3.6, 0, 1.8, "cream", FULL, "glow")
	ring(e, 0, 3.6, 0.1, 1.5, 12, 0.18, 0.18, 0.18, "white", "cyan", FULL, "glow")
end
Species.HeavenSeed = function(e)
	orb(e, 0, 1.4, 0, 1.8, "fruit", YOUNG, "fruit")
	orb(e, 0, 1.4, -0.3, 0.9, "gold", MID, "glow")
	for i = 1, 3 do
		box(e, -1.3 - i * 0.55, 1.6 + i * 0.4, 0, 1.0, 0.3, 0.18, "white", MID + i * 0.1, "glow")
		box(e, 1.3 + i * 0.55, 1.6 + i * 0.4, 0, 1.0, 0.3, 0.18, "white", MID + i * 0.1, "glow")
	end
	ring(e, 0, 3.7, 0, 0.9, 8, 0.24, 0.24, 0.24, "gold", "white", FULL, "glow")
	box(e, 0, 2.7, 0, 0.18, 0.7, 0.18, "leaf2", FULL, "stem")
end
Species.BlackLotus = function(e)
	box(e, 0, 0.18, 0, 4.0, 0.2, 4.0, "black", YOUNG, "leaf")
	ringFlat(e, 0, 1.0, 0, 1.3, 8, 0.75, 1.7, 0.4, "black", "indigo", MID, "fruit")
	ringFlat(e, 0, 1.5, 0, 0.75, 4, 0.55, 1.6, 0.4, "fruit", "black", MID, "fruit", math.pi / 4)
	orb(e, 0, 1.2, 0, 0.9, "rose", MID, "glow")
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2
		box(e, math.cos(a) * 1.9, 2.0 + (i % 3) * 0.7, math.sin(a) * 1.9, 0.22, 0.22, 0.22, if i % 2 == 0 then "violet" else "rose", FULL, "glow")
	end
end
Species.WorldTree = function(e)
	bigTree(e, 1.7, 3.6, 3.0, 4, "cyan", 8)
	box(e, -1.9, 0.3, -0.6, 1.2, 0.6, 0.6, "wood2", YOUNG, "stem")
	box(e, 1.9, 0.3, 0.6, 1.2, 0.6, 0.6, "wood2", YOUNG, "stem")
	box(e, 0, 0.3, 1.8, 0.6, 0.6, 1.2, "wood2", YOUNG, "stem")
	ring(e, 0, 7.2, 0, 1.6, 10, 0.26, 0.26, 0.26, "gold", "white", FULL, "glow")
	box(e, 0, 7.2, 0, 0.9, 0.9, 0.9, "white", FULL, "glow")
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.3
		box(e, math.cos(a) * 2.7, 2.6, math.sin(a) * 2.7, 0.18, 1.8, 0.18, "mint", FULL, "glow")
	end
end
Species.GlitchPlant = function(e)
	stalk(e, 0, 0, 2.0, 0.3, "cyan", YOUNG)
	stalk(e, 0.35, 0, 1.4, 0.3, "rose", YOUNG)
	box(e, -0.6, 2.2, 0, 0.7, 0.7, 0.7, "fruit", YOUNG, "fruit")
	box(e, 0.5, 2.7, -0.2, 0.9, 0.5, 0.5, "cyan", MID, "glow")
	box(e, -0.1, 3.3, 0.1, 0.6, 0.6, 0.6, "rose", MID, "glow")
	box(e, 0.9, 3.6, 0, 0.4, 0.4, 0.4, "white", MID, "glow")
	box(e, -1.0, 3.1, -0.3, 0.5, 0.3, 0.5, "black", FULL, "deco")
	box(e, 0.1, 4.1, -0.1, 1.2, 0.3, 0.3, "fruit3", FULL, "glow")
	box(e, -0.7, 4.5, 0.2, 0.3, 0.9, 0.3, "cyan", FULL, "glow")
	box(e, 0.8, 4.9, -0.2, 0.5, 0.5, 0.5, "rose", FULL, "glow")
	box(e, -1.4, 2.0, 0.4, 0.4, 0.4, 0.4, "white", FULL, "glow")
	box(e, 1.5, 2.0, -0.4, 0.3, 0.3, 0.3, "black", FULL, "glow")
end

PlantBlueprints.Species = Species

return PlantBlueprints
