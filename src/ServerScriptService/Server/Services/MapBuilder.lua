--!strict
--[[
	MapBuilder.lua
	Construye el mapa por código (sin assets externos): suelo, camino
	principal, plaza con spawn, fuentes, tiendas, árboles y lago. También decora cada jardín (tierra, valla,
	cartel, spawn propio). Estética low-poly, colorida y sin violencia.
	Todo es Anchored y sin colisión innecesaria para rendir bien en móvil.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)

local MapBuilder = {}

-- Plaza central (spawn inicial, tienda y vecino)
MapBuilder.PlazaCenter = GardenConfig.GetStreetCenter()
-- Jardín "vecino" del tutorial: sobre el eje de la calle, junto al mercado.
MapBuilder.TutorialGardenCenter = MapBuilder.PlazaCenter + Vector3.new(82, 0, 0)

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = canCollide == true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, text: string, size: UDim2, offset: Vector3, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
end

local function buildTree(parent: Instance, position: Vector3, scale: number, variant: string)
	local trunkColor = if variant == "Birch" then Color3.fromRGB(224, 211, 176) else Color3.fromRGB(126, 84, 55)
	part(parent, variant .. "Trunk", Vector3.new(1.8, 6, 1.8) * scale, position + Vector3.new(0, 3 * scale, 0), trunkColor, Enum.Material.Wood, true)

	if variant == "Pine" then
		local green = Color3.fromRGB(50, 133, 86)
		part(parent, "PineCanopyLow", Vector3.new(7, 3, 7) * scale, position + Vector3.new(0, 5.6 * scale, 0), green, Enum.Material.Grass)
		part(parent, "PineCanopyMid", Vector3.new(5.3, 3, 5.3) * scale, position + Vector3.new(0, 7.8 * scale, 0), Color3.fromRGB(61, 153, 94), Enum.Material.Grass)
		part(parent, "PineCanopyTop", Vector3.new(3.4, 3.2, 3.4) * scale, position + Vector3.new(0, 9.9 * scale, 0), Color3.fromRGB(76, 171, 102), Enum.Material.Grass)
	elseif variant == "Cherry" then
		local blossom = Color3.fromRGB(242, 151, 185)
		part(parent, "CherryCanopy", Vector3.new(6.6, 4.4, 6.6) * scale, position + Vector3.new(0, 8 * scale, 0), blossom, Enum.Material.SmoothPlastic)
		part(parent, "CherryCanopyLeft", Vector3.new(3.2, 2.8, 3.2) * scale, position + Vector3.new(-3.1 * scale, 7.1 * scale, 0), Color3.fromRGB(255, 190, 207), Enum.Material.SmoothPlastic)
		part(parent, "CherryCanopyRight", Vector3.new(3.1, 2.7, 3.1) * scale, position + Vector3.new(3 * scale, 7.2 * scale, 0), Color3.fromRGB(231, 125, 165), Enum.Material.SmoothPlastic)
	elseif variant == "Birch" then
		part(parent, "BirchBarkLow", Vector3.new(1.9, 0.32, 1.9) * scale, position + Vector3.new(0, 1.5 * scale, 0), Color3.fromRGB(100, 79, 65), Enum.Material.Wood)
		part(parent, "BirchBarkHigh", Vector3.new(1.9, 0.32, 1.9) * scale, position + Vector3.new(0, 4.3 * scale, 0), Color3.fromRGB(100, 79, 65), Enum.Material.Wood)
		part(parent, "BirchCanopy", Vector3.new(5.8, 5.1, 5.8) * scale, position + Vector3.new(0, 8 * scale, 0), Color3.fromRGB(115, 185, 102), Enum.Material.Grass)
		part(parent, "BirchCanopyTop", Vector3.new(3.5, 2.1, 3.5) * scale, position + Vector3.new(0, 10.3 * scale, 0), Color3.fromRGB(146, 207, 114), Enum.Material.Grass)
	else
		local green = Color3.fromRGB(75, 159, 86)
		part(parent, "OakCanopy", Vector3.new(6.4, 4.8, 6.4) * scale, position + Vector3.new(0, 8 * scale, 0), green, Enum.Material.Grass)
		part(parent, "OakCanopyLeft", Vector3.new(3.1, 3.3, 3.1) * scale, position + Vector3.new(-2.8 * scale, 7.1 * scale, 0), Color3.fromRGB(89, 175, 91), Enum.Material.Grass)
		part(parent, "OakCanopyRight", Vector3.new(3.1, 3.3, 3.1) * scale, position + Vector3.new(2.8 * scale, 7.1 * scale, 0), Color3.fromRGB(62, 145, 83), Enum.Material.Grass)
	end
end

local function buildFlowerClump(parent: Instance, position: Vector3, color: Color3, scale: number)
	local green = Color3.fromRGB(66, 144, 72)
	part(parent, "FlowerStem", Vector3.new(0.34, 1.15, 0.34) * scale, position + Vector3.new(0, 0.58 * scale, 0), green, Enum.Material.Grass)
	part(parent, "FlowerLeafLeft", Vector3.new(0.75, 0.22, 0.38) * scale, position + Vector3.new(-0.38 * scale, 0.52 * scale, 0), Color3.fromRGB(90, 177, 80), Enum.Material.Grass)
	part(parent, "FlowerLeafRight", Vector3.new(0.75, 0.22, 0.38) * scale, position + Vector3.new(0.38 * scale, 0.76 * scale, 0), Color3.fromRGB(78, 162, 77), Enum.Material.Grass)
	local petalOffsets = {
		Vector3.new(-0.34, 1.25, 0),
		Vector3.new(0.34, 1.25, 0),
		Vector3.new(0, 1.25, -0.34),
		Vector3.new(0, 1.25, 0.34),
	}
	for _, offset in ipairs(petalOffsets) do
		part(parent, "BlockPetal", Vector3.new(0.52, 0.42, 0.52) * scale, position + offset * scale, color, Enum.Material.SmoothPlastic)
	end
	part(parent, "FlowerCenter", Vector3.new(0.36, 0.36, 0.36) * scale, position + Vector3.new(0, 1.27 * scale, 0), Color3.fromRGB(255, 220, 95), Enum.Material.SmoothPlastic)
end

local function buildLampPost(parent: Instance, position: Vector3)
	local darkWood = Color3.fromRGB(95, 78, 57)
	part(parent, "LampBase", Vector3.new(2.2, 0.5, 2.2), position + Vector3.new(0, 0.25, 0), darkWood, Enum.Material.Wood, true)
	part(parent, "LampPost", Vector3.new(0.55, 6, 0.55), position + Vector3.new(0, 3.25, 0), darkWood, Enum.Material.Wood, true)
	part(parent, "LampCap", Vector3.new(2.2, 0.4, 2.2), position + Vector3.new(0, 6.35, 0), Color3.fromRGB(63, 117, 80))
	local lantern = part(parent, "Lantern", Vector3.new(1.3, 1.3, 1.3), position + Vector3.new(0, 5.55, 0), Color3.fromRGB(255, 226, 130), Enum.Material.Neon)
	lantern.Transparency = 0.08
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 224, 153)
	light.Brightness = 0.6
	light.Range = 14
	light.Parent = lantern
end

local function buildFarmer(parent: Instance, name: string, position: Vector3, coatColor: Color3, hatColor: Color3)
	local farmer = Instance.new("Model")
	farmer.Name = name
	farmer.Parent = parent
	part(farmer, "Body", Vector3.new(1.7, 2, 1), position + Vector3.new(0, 2.2, 1.1), coatColor)
	part(farmer, "Apron", Vector3.new(1.15, 1.2, 0.15), position + Vector3.new(0, 1.9, 0.55), Color3.fromRGB(105, 71, 46), Enum.Material.Fabric)
	part(farmer, "Head", Vector3.new(1.35, 1.35, 1.2), position + Vector3.new(0, 3.9, 1.1), Color3.fromRGB(238, 190, 144))
	part(farmer, "HatBrim", Vector3.new(1.9, 0.2, 1.7), position + Vector3.new(0, 4.65, 1.1), hatColor, Enum.Material.Fabric)
	part(farmer, "HatTop", Vector3.new(1.2, 0.65, 1.1), position + Vector3.new(0, 5.05, 1.1), hatColor, Enum.Material.Fabric)
	part(farmer, "EyeLeft", Vector3.new(0.13, 0.16, 0.08), position + Vector3.new(-0.3, 3.98, 0.48), Color3.fromRGB(48, 41, 34))
	part(farmer, "EyeRight", Vector3.new(0.13, 0.16, 0.08), position + Vector3.new(0.3, 3.98, 0.48), Color3.fromRGB(48, 41, 34))
	part(farmer, "HandLeft", Vector3.new(0.48, 0.85, 0.48), position + Vector3.new(-1.1, 2, 1.05), Color3.fromRGB(238, 190, 144))
	part(farmer, "HandRight", Vector3.new(0.48, 0.85, 0.48), position + Vector3.new(1.1, 2, 1.05), Color3.fromRGB(238, 190, 144))
end

local function buildShop(parent: Instance, position: Vector3, shopType: string, title: string, roofColor: Color3, coatColor: Color3)
	local wood = Color3.fromRGB(150, 105, 65)
	local stall = Instance.new("Model")
	stall.Name = shopType .. "Shop"
	stall.Parent = parent
	part(stall, "ShopFloor", Vector3.new(12, 0.4, 9), position + Vector3.new(0, 0.2, 0), Color3.fromRGB(210, 190, 150))
	local counter = part(stall, "ShopCounter", Vector3.new(9, 3, 3), position + Vector3.new(0, 1.9, -2), wood, Enum.Material.Wood, true)
	for _, dx in ipairs({ -5, 5 }) do
		for _, dz in ipairs({ -3.5, 3.5 }) do
			part(stall, "ShopPole", Vector3.new(0.6, 7, 0.6), position + Vector3.new(dx, 3.5, dz), wood, Enum.Material.Wood)
		end
	end
	part(stall, "ShopRoof", Vector3.new(13, 0.6, 10), position + Vector3.new(0, 7.2, 0), roofColor)
	part(stall, "ShopRoofStripe", Vector3.new(13.1, 0.62, 3), position + Vector3.new(0, 7.2, 0), Color3.fromRGB(255, 255, 255))
	part(stall, "ShopFrontAwning", Vector3.new(12, 0.45, 1.8), position + Vector3.new(0, 5.1, -4.7), roofColor)
	for index = 1, 4 do
		part(
			stall,
			"ShopAwningStripe",
			Vector3.new(0.5, 0.48, 1.82),
			position + Vector3.new(-4.8 + (index - 1) * 3.2, 5.1, -4.75),
			Color3.fromRGB(248, 239, 201)
		)
	end
	billboard(counter, title, UDim2.fromOffset(170, 34), Vector3.new(0, 6, 0), 45)
	buildFarmer(stall, shopType .. "Farmer", position, coatColor, roofColor)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt:SetAttribute("ShopType", shopType)
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = counter
end

local function buildFountain(parent: Instance, position: Vector3)
	part(parent, "FountainBase", Vector3.new(12, 1.4, 12), position + Vector3.new(0, 0.7, 0), Color3.fromRGB(190, 190, 200), Enum.Material.Concrete, true)
	local water = part(parent, "FountainWater", Vector3.new(9.8, 0.5, 9.8), position + Vector3.new(0, 1.5, 0), Color3.fromRGB(90, 180, 255))
	water.Transparency = 0.3
	part(parent, "FountainPillar", Vector3.new(1.6, 3, 1.6), position + Vector3.new(0, 3.2, 0), Color3.fromRGB(190, 190, 200))
	part(parent, "FountainTop", Vector3.new(2.6, 1, 2.6), position + Vector3.new(0, 5.2, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
end

local function buildBench(parent: Instance, position: Vector3, rotationY: number)
	local bench = Instance.new("Model")
	bench.Name = "Bench"
	bench.Parent = parent
	bench:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(rotationY), 0))

	local seat = part(bench, "BenchSeat", Vector3.new(7, 0.5, 1.5), Vector3.new(0, 1.3, 0), Color3.fromRGB(160, 120, 80), Enum.Material.Wood, true)
	part(bench, "BenchLegA", Vector3.new(0.6, 1.1, 0.6), Vector3.new(-3, 0.65, 0), Color3.fromRGB(110, 75, 50), Enum.Material.Wood, true)
	part(bench, "BenchLegB", Vector3.new(0.6, 1.1, 0.6), Vector3.new(3, 0.65, 0), Color3.fromRGB(110, 75, 50), Enum.Material.Wood, true)
	part(bench, "BenchBack", Vector3.new(7, 0.5, 0.5), Vector3.new(0, 2.05, -0.55), Color3.fromRGB(140, 100, 65), Enum.Material.Wood, true)
	seat.Parent = bench
	bench:MoveTo(position)
end

local function buildPlanter(parent: Instance, position: Vector3, size: Vector3, color: Color3)
	part(parent, "PlanterBase", size + Vector3.new(0.8, 0.8, 0.8), position + Vector3.new(0, 0.5, 0), color, Enum.Material.SmoothPlastic, true)
	part(parent, "PlanterSoil", size, position + Vector3.new(0, 1.2, 0), Color3.fromRGB(120, 85, 55), Enum.Material.Ground, true)
	buildFlowerClump(parent, position + Vector3.new(-1.5, 2.35, 0), Color3.fromRGB(246, 122, 114), 0.8)
	buildFlowerClump(parent, position + Vector3.new(1.5, 2.35, 0), Color3.fromRGB(255, 181, 82), 0.78)
	buildFlowerClump(parent, position + Vector3.new(0, 2.35, 1.5), Color3.fromRGB(161, 130, 240), 0.82)
end

local COBBLE = Color3.fromRGB(203, 185, 153)

local function buildArch(parent: Instance, position: Vector3, title: string)
	local wood = Color3.fromRGB(150, 105, 65)
	for _, dz in ipairs({ -17, 17 }) do
		part(parent, "ArchPost", Vector3.new(1.6, 11, 1.6), position + Vector3.new(0, 5.5, dz), wood, Enum.Material.Wood, true)
		part(parent, "ArchPostCap", Vector3.new(2.4, 0.7, 2.4), position + Vector3.new(0, 11.3, dz), Color3.fromRGB(102, 171, 83))
	end
	part(parent, "ArchBeam", Vector3.new(1.6, 1.4, 38), position + Vector3.new(0, 11.2, 0), wood, Enum.Material.Wood)
	local board = part(parent, "ArchSign", Vector3.new(0.8, 4, 20), position + Vector3.new(0, 8.4, 0), Color3.fromRGB(255, 240, 200))
	billboard(board, title, UDim2.fromOffset(220, 44), Vector3.new(0, 0, 0), 120)
end

local function scatterTrees(parent: Instance, rng: Random, count: number, area: { minX: number, maxX: number, minZ: number, maxZ: number }, avoid: { { cx: number, cz: number, r: number } })
	local types = { "Oak", "Pine", "Cherry", "Birch" }
	for _ = 1, count do
		local x = rng:NextNumber(area.minX, area.maxX)
		local z = rng:NextNumber(area.minZ, area.maxZ)
		local blocked = false
		for _, zone in ipairs(avoid) do
			if (Vector2.new(x, z) - Vector2.new(zone.cx, zone.cz)).Magnitude < zone.r then
				blocked = true
				break
			end
		end
		if not blocked then
			buildTree(parent, Vector3.new(x, 0, z), rng:NextNumber(0.85, 1.2), types[rng:NextInteger(1, #types)])
		end
	end
end

function MapBuilder.BuildWorld()
	local oldBase = Workspace:FindFirstChild("Baseplate")
	if oldBase then
		oldBase:Destroy()
	end
	local oldMap = Workspace:FindFirstChild("Map")
	if oldMap then
		oldMap:Destroy()
	end

	-- Distancias cómodas en móvil.
	StarterPlayer.CharacterWalkSpeed = 20

	-- Iluminación alegre
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(145, 151, 158)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 183, 166)
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.1
	atmosphere.Haze = 0.1
	atmosphere.Color = Color3.fromRGB(214, 235, 255)

	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	local C = MapBuilder.PlazaCenter
	local streetHalf = GardenConfig.StreetWidth / 2
	local lastColumnX = (GardenConfig.GardensPerRow - 1) * GardenConfig.GardenSlotSpacing
	local streetMinX = GardenConfig.YardMinX - 8
	local streetMaxX = lastColumnX + GardenConfig.YardMaxX + 8
	local southBackZ = GardenConfig.YardBackZ
	local northFrontZ = GardenConfig.NorthRowZ + GardenConfig.YardFrontZ

	-- Suelo: base de tierra sólida + capa de césped (un solo bloque cada uno).
	local minX, maxX, minZ, maxZ = -72, lastColumnX + 112, -175, math.max(GardenConfig.NorthRowZ + 62, C.Z + 220)
	local widthX, depthZ = maxX - minX, maxZ - minZ
	part(map, "DirtFoundation", Vector3.new(widthX, 2, depthZ), Vector3.new((minX + maxX) / 2, -1, (minZ + maxZ) / 2), Color3.fromRGB(126, 91, 61), Enum.Material.Ground, true)
	part(map, "GrassSurface", Vector3.new(widthX - 2, 0.16, depthZ - 2), Vector3.new((minX + maxX) / 2, 0.08, (minZ + maxZ) / 2), Color3.fromRGB(112, 190, 96), Enum.Material.Grass)

	-- Muros invisibles: nadie se cae del mapa.
	local function wall(size: Vector3, position: Vector3)
		local w = part(map, "BoundaryWall", size, position, Color3.new(1, 1, 1), nil, true)
		w.Transparency = 1
		w.CanQuery = false
	end
	wall(Vector3.new(widthX, 80, 2), Vector3.new((minX + maxX) / 2, 40, minZ))
	wall(Vector3.new(widthX, 80, 2), Vector3.new((minX + maxX) / 2, 40, maxZ))
	wall(Vector3.new(2, 80, depthZ), Vector3.new(minX, 40, (minZ + maxZ) / 2))
	wall(Vector3.new(2, 80, depthZ), Vector3.new(maxX, 40, (minZ + maxZ) / 2))

	-- Calle central empedrada con bordillos de piedra.
	local roadWidth = GardenConfig.StreetWidth - 4
	part(map, "StreetEdge", Vector3.new(streetMaxX - streetMinX, 0.22, GardenConfig.StreetWidth), Vector3.new(C.X, 0.11, C.Z), Color3.fromRGB(162, 177, 133), Enum.Material.Slate)
	part(map, "StreetRoad", Vector3.new(streetMaxX - streetMinX - 2, 0.26, roadWidth), Vector3.new(C.X, 0.14, C.Z), COBBLE, Enum.Material.Cobblestone)
	-- Caminos a las dos puertas de cada jardín (empedrado hasta la calle).
	for column = 0, GardenConfig.GardensPerRow - 1 do
		local gateX = column * GardenConfig.GardenSlotSpacing + 15
		part(map, "GatePathSouth", Vector3.new(12, 0.2, 5), Vector3.new(gateX, 0.12, southBackZ + 4.5), COBBLE, Enum.Material.Cobblestone)
		part(map, "GatePathNorth", Vector3.new(12, 0.2, 5), Vector3.new(gateX, 0.12, northFrontZ - 4.5 + 0), COBBLE, Enum.Material.Cobblestone)
	end

	-- Plaza central: losas, anillo y bordes, entre las dos filas de jardines.
	part(map, "Plaza", Vector3.new(96, 0.3, roadWidth), Vector3.new(C.X, 0.3, C.Z), Color3.fromRGB(233, 227, 209), Enum.Material.Pebble)
	part(map, "PlazaRing", Vector3.new(82, 0.2, roadWidth - 8), Vector3.new(C.X, 0.4, C.Z), Color3.fromRGB(200, 195, 180), Enum.Material.Slate)
	part(map, "PlazaInset", Vector3.new(66, 0.12, roadWidth - 18), Vector3.new(C.X, 0.5, C.Z), Color3.fromRGB(241, 230, 199), Enum.Material.SmoothPlastic)

	-- Mercado: las tres tiendas en fila sobre el eje de la calle (frente al sur).
	buildShop(map, C + Vector3.new(-24, 0, 0), "Seeds", "SEED FARMER", Color3.fromRGB(102, 171, 83), Color3.fromRGB(114, 166, 87))
	buildShop(map, C + Vector3.new(0, 0, 0), "Gear", "GEAR FARMER", Color3.fromRGB(93, 147, 202), Color3.fromRGB(102, 130, 168))
	buildShop(map, C + Vector3.new(24, 0, 0), "Pets", "EGG FARMER", Color3.fromRGB(165, 119, 205), Color3.fromRGB(151, 110, 176))

	-- Fuentes a ambos lados del mercado y parterres con flores.
	buildFountain(map, C + Vector3.new(-50, 0, 0))
	buildFountain(map, C + Vector3.new(50, 0, 0))
	for index, offset in ipairs({
		Vector3.new(-12, 0, 9), Vector3.new(12, 0, 9), Vector3.new(-12, 0, -9), Vector3.new(12, 0, -9),
	}) do
		local bed = C + offset
		part(map, "PlazaFlowerBed", Vector3.new(9, 0.8, 4), bed + Vector3.new(0, 0.5, 0), Color3.fromRGB(90, 150, 80), Enum.Material.Grass)
		for flower = 1, 3 do
			local colors = { Color3.fromRGB(248, 139, 165), Color3.fromRGB(255, 213, 106), Color3.fromRGB(166, 145, 245) }
			buildFlowerClump(map, bed + Vector3.new((flower - 2) * 2.8, 0.9, 0), colors[(flower + index) % 3 + 1], 0.55)
		end
	end
	for _, dx in ipairs({ -34, 34 }) do
		buildBench(map, C + Vector3.new(dx, 0.6, 12), 0)
		buildBench(map, C + Vector3.new(dx, 0.6, -12), 180)
	end

	-- Spawn de la plaza (por defecto; cada jugador aparece en su jardín).
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(C.X, 0.5, C.Z + 12)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Transparency = 0.4
	spawn.CanCollide = false
	spawn.Parent = map

	-- Farolas a lo largo de la calle, entre puerta y puerta (no tapan accesos).
	for column = 0, GardenConfig.GardensPerRow - 1 do
		local x = column * GardenConfig.GardenSlotSpacing + 30
		buildLampPost(map, Vector3.new(x, 0, southBackZ + 5))
		buildLampPost(map, Vector3.new(x, 0, northFrontZ - 5))
	end

	-- Arcos de entrada en los dos extremos de la calle.
	buildArch(map, Vector3.new(streetMinX, 0, C.Z), "🌱 STEAL A PLANT")
	buildArch(map, Vector3.new(streetMaxX, 0, C.Z), "🌱 STEAL A PLANT")

	-- Estanque al oeste, a la vista desde el arco.
	part(map, "PondSand", Vector3.new(36, 0.35, 29), Vector3.new(streetMinX - 34, 0.18, C.Z), Color3.fromRGB(226, 204, 139), Enum.Material.Sand)
	local water = part(map, "Pond", Vector3.new(30, 0.35, 23), Vector3.new(streetMinX - 34, 0.36, C.Z), Color3.fromRGB(80, 170, 240), Enum.Material.Glass)
	water.Transparency = 0.25
	part(map, "PondWaterStep", Vector3.new(18, 0.15, 11), Vector3.new(streetMinX - 34, 0.58, C.Z), Color3.fromRGB(123, 205, 255), Enum.Material.Glass).Transparency = 0.35

	-- Árboles y arbustos en los pasillos de 6 studs entre jardines.
	local gapColors = { Color3.fromRGB(242, 144, 181), Color3.fromRGB(255, 205, 103), Color3.fromRGB(164, 146, 242) }
	for column = 0, GardenConfig.GardensPerRow - 2 do
		local gapX = column * GardenConfig.GardenSlotSpacing + (GardenConfig.YardMaxX + GardenConfig.GardenSlotSpacing + GardenConfig.YardMinX) / 2
		for rowIndex, rowZ in ipairs({ 0, GardenConfig.NorthRowZ }) do
			buildTree(map, Vector3.new(gapX, 0, rowZ + 6), 0.62, if (column + rowIndex) % 2 == 0 then "Cherry" else "Oak")
			buildTree(map, Vector3.new(gapX, 0, rowZ + 26), 0.62, if (column + rowIndex) % 2 == 0 then "Birch" else "Pine")
			buildFlowerClump(map, Vector3.new(gapX, 0.14, rowZ + 16), gapColors[(column + rowIndex) % 3 + 1], 0.7)
		end
	end

	-- Bosque exterior y flores en los bordes del mapa.
	local rng = Random.new(1337)
	local avoidPond = { { cx = streetMinX - 34, cz = C.Z, r = 30 } }
	scatterTrees(map, rng, 34, { minX = minX + 8, maxX = maxX - 8, minZ = -60, maxZ = -22 }, avoidPond)
	scatterTrees(map, rng, 30, { minX = minX + 8, maxX = maxX - 8, minZ = GardenConfig.NorthRowZ + 48, maxZ = maxZ - 6 }, avoidPond)
	scatterTrees(map, rng, 12, { minX = minX + 8, maxX = streetMinX - 10, minZ = -22, maxZ = GardenConfig.NorthRowZ + 44 }, avoidPond)
	scatterTrees(map, rng, 12, { minX = streetMaxX + 14, maxX = maxX - 8, minZ = -22, maxZ = GardenConfig.NorthRowZ + 44 }, avoidPond)
	for index = 0, 24 do
		local x = streetMinX + index * 12
		buildFlowerClump(map, Vector3.new(x, 0.14, -14), gapColors[index % 3 + 1], 0.7)
		buildFlowerClump(map, Vector3.new(x, 0.14, GardenConfig.NorthRowZ + 44), gapColors[(index + 1) % 3 + 1], 0.7)
	end

	-- Manchas de césped/tierra para romper la planitud (bajas en partes).
	local patchRandom = Random.new(7481)
	for _ = 1, 40 do
		local x = patchRandom:NextNumber(minX + 10, maxX - 10)
		local z = patchRandom:NextNumber(minZ + 10, -24)
		local isSoil = patchRandom:NextInteger(1, 4) == 1
		part(
			map,
			if isSoil then "ExposedSoilPatch" else "GrassPatch",
			Vector3.new(patchRandom:NextInteger(12, 26), 0.06, patchRandom:NextInteger(10, 22)),
			Vector3.new(x, 0.13, z),
			if isSoil
				then Color3.fromRGB(patchRandom:NextInteger(123, 151), patchRandom:NextInteger(84, 108), patchRandom:NextInteger(59, 76))
				else Color3.fromRGB(patchRandom:NextInteger(91, 125), patchRandom:NextInteger(164, 195), patchRandom:NextInteger(82, 111)),
			if isSoil then Enum.Material.Ground else Enum.Material.Grass
		)
	end
end

-- Decora el jardín de un jugador y le asigna su punto de reaparición.
function MapBuilder.DecorateGarden(player: Player, garden: Model): Part
	local origin = garden:GetPivot().Position
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = garden

	local wood = Color3.fromRGB(165, 120, 75)
	local entryZ = (garden:GetAttribute("EntryZ") :: number?) or -11
	local outward = (garden:GetAttribute("Outward") :: number?) or -1

	-- GardenService builds and expands the fenced planting yard.
	buildPlanter(decor, origin + Vector3.new(4, 0, -3), Vector3.new(3, 1.4, 2.4), wood)
	buildPlanter(decor, origin + Vector3.new(26, 0, -3), Vector3.new(3, 1.4, 2.4), wood)

	-- Cartel con el nombre del dueño, en el lado de la calle (visible desde la plaza).
	local signZ = if outward > 0 then GardenConfig.YardBackZ + 3 else GardenConfig.YardFrontZ - 3
	local signPost = part(decor, "SignPost", Vector3.new(0.8, 6, 0.8), origin + Vector3.new(-3, 3, signZ), wood, Enum.Material.Wood)
	local board = part(decor, "OwnerSign", Vector3.new(11, 2.4, 0.6), origin + Vector3.new(-3, 6.5, signZ), Color3.fromRGB(255, 240, 200))
	billboard(board, "🌱 " .. player.DisplayName .. "'s Garden", UDim2.fromOffset(160, 34), Vector3.new(0, 0, 0), 60)
	signPost.Name = "SignPost"

	-- Arbustos en las esquinas traseras
	for _, offset in ipairs({ Vector3.new(-5, 1.5, 25), Vector3.new(35, 1.5, 25) }) do
		part(decor, "BlockyBushBase", Vector3.new(4, 3, 4), origin + offset, Color3.fromRGB(60, 150, 75), Enum.Material.Grass)
		part(decor, "BlockyBushTop", Vector3.new(2.6, 1.6, 2.6), origin + offset + Vector3.new(0, 1.8, 0), Color3.fromRGB(84, 177, 82), Enum.Material.Grass)
	end

	-- Punto de reaparición propio del jardín (lado calle)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GardenSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + Vector3.new(15, 0.5, entryZ)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = garden
	player.RespawnLocation = spawn

	return spawn
end 

return MapBuilder
