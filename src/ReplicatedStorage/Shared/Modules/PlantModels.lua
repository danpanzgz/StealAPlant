--!strict
--[[
	PlantModels.lua
	Convierte los blueprints (PlantBlueprints) en Parts voxel. Lo usan
	PlantService (plots y flores colocadas). No toca datos ni economía.

	Build(parent, plantId, groundPosition, progress, opts) -> (primaryPart, height)
	  progress : 0..1 (fase actual). Por debajo de Young solo se ve un brote.
	  opts.fruitColor : color base de la planta (o de la mutación)
	  opts.mutated    : true => fruta/brillo en Neon
	  opts.scale      : multiplicador de tamaño (Normal/Large/Giant)
	  opts.rotation   : giro Y (radianes) opcional
]]

local PlantBlueprints = require(script.Parent.PlantBlueprints)

local PlantModels = {}

export type Options = {
	fruitColor: Color3,
	mutated: boolean?,
	scale: number?,
	rotation: number?,
}

local function paletteColor(key: string): Color3?
	local c = PlantBlueprints.Palette[key]
	if c then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return nil
end

local function shade(color: Color3, factor: number): Color3
	if factor < 1 then
		return Color3.new(color.R * factor, color.G * factor, color.B * factor)
	end
	local t = factor - 1
	return Color3.new(color.R + (1 - color.R) * t, color.G + (1 - color.G) * t, color.B + (1 - color.B) * t)
end

function PlantModels.HasBlueprint(plantId: string): boolean
	return PlantBlueprints.Species[plantId] ~= nil
end

function PlantModels.Build(
	parent: Model,
	plantId: string,
	ground: Vector3,
	progress: number,
	opts: Options
): (BasePart, number)
	local blueprint = PlantBlueprints.Species[plantId]
	local mutated = opts.mutated == true
	local sizeScale = opts.scale or 1
	-- La planta crece de forma visible: 0.55 -> 1.0 del tamaño final.
	local scale = (0.55 + 0.45 * math.clamp(progress, 0, 1)) * sizeScale
	local rotation = opts.rotation or 0
	local cosR, sinR = math.cos(rotation), math.sin(rotation)

	local base = opts.fruitColor
	local colors: { [string]: Color3 } = {
		fruit = base,
		fruit2 = shade(base, 0.72),
		fruit3 = shade(base, 1.35),
	}

	local primary: BasePart? = nil
	local maxHeight = 0
	local count = 0

	local function place(
		shape: string, ox: number, oy: number, oz: number,
		sx: number, sy: number, sz: number,
		colorKey: string, at: number, kind: string
	)
		if progress < at then
			return
		end
		local color = colors[colorKey] or paletteColor(colorKey) or base
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Color = color
		if kind == "glow" or (mutated and kind == "fruit") then
			part.Material = Enum.Material.Neon
		elseif kind == "leaf" then
			part.Material = Enum.Material.Grass
		else
			part.Material = Enum.Material.SmoothPlastic
		end
		local rx = ox * cosR - oz * sinR
		local rz = ox * sinR + oz * cosR
		local size = Vector3.new(sx, sy, sz) * scale
		local center = ground + Vector3.new(rx, oy, rz) * scale
		if shape == "S" then
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.new(sx, sx, sx) * scale
			part.CFrame = CFrame.new(center)
		elseif shape == "C" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(sy, sx, sz) * scale
			part.CFrame = CFrame.new(center) * CFrame.Angles(0, rotation, math.pi / 2)
		else
			part.Size = size
			part.CFrame = CFrame.new(center) * CFrame.Angles(0, rotation, 0)
		end
		part.Name = kind
		part.Parent = parent
		count += 1
		maxHeight = math.max(maxHeight, (oy + sy / 2))
		if not primary and (kind == "stem" or kind == "fruit") then
			primary = part
		end
	end

	if progress < PlantBlueprints.Thresholds.Young then
		-- Brote: montículo + dos hojitas. Siempre visible para que el jugador
		-- sepa que la semilla está plantada.
		place("B", 0, 0.14, 0, 0.7, 0.28, 0.7, "soil", 0, "deco")
		place("B", 0, 0.5, 0, 0.14, 0.5, 0.14, "stem", 0, "stem")
		place("B", -0.22, 0.72, 0, 0.36, 0.12, 0.2, "leaf", 0, "leaf")
		place("B", 0.22, 0.8, 0, 0.36, 0.12, 0.2, "leaf2", 0, "leaf")
	elseif blueprint then
		blueprint(place)
	end

	if not primary then
		-- Cualquier especie sin partes visibles aún: ancla mínima.
		local anchor = Instance.new("Part")
		anchor.Name = "Anchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = ground + Vector3.new(0, 0.3, 0)
		anchor.Parent = parent
		primary = anchor
	end

	return primary :: BasePart, maxHeight * scale
end

return PlantModels
