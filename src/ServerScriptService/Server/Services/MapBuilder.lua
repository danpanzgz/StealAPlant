--!strict
--[[
	MapBuilder.lua
	Construye el mapa por código (sin assets externos): suelo, camino
	principal, plaza con spawn, fuente, puesto de la Seed Shop, carteles de
	zonas, árboles y lago. También decora cada jardín (tierra, valla,
	cartel, spawn propio). Estética low-poly, colorida y sin violencia.
	Todo es Anchored y sin colisión innecesaria para rendir bien en móvil.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local MapBuilder = {}
local MAX_MAP_PART_WIDTH = 1800 -- Keep generated parts below Roblox's 2048-stud size limit.

-- Plaza central (spawn inicial, tienda y vecino)
MapBuilder.PlazaCenter = Vector3.new(-50, 0, 10)

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

local function horizontalStrip(
	parent: Instance,
	name: string,
	startX: number,
	endX: number,
	y: number,
	z: number,
	depth: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
)
	local x = startX
	local index = 0
	while x < endX do
		index += 1
		local width = math.min(MAX_MAP_PART_WIDTH, endX - x)
		local partName = if index == 1 then name else name .. "_" .. index
		part(parent, partName, Vector3.new(width, height, depth), Vector3.new(x + width / 2, y, z), color, material, canCollide)
		x += width
	end
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

function MapBuilder.BuildWorld()
	local maxPlayers = math.max(Players.MaxPlayers, 8)
	local lastGardenX = (maxPlayers - 1) * GardenConfig.GardenSlotSpacing
	local minX, maxX = -115, lastGardenX + 70

	local oldBase = Workspace:FindFirstChild("Baseplate")
	if oldBase then
		oldBase:Destroy()
	end
	local oldMap = Workspace:FindFirstChild("Map")
	if oldMap then
		oldMap:Destroy()
	end

	-- Personajes algo más rápidos: distancias entre jardines cómodas en móvil.
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

	local plaza = MapBuilder.PlazaCenter

	-- A solid soil foundation keeps the whole play area safe; the grass cap
	-- leaves a visible block edge and patch tiles vary the terrain palette.
	horizontalStrip(map, "DirtFoundation", minX - 25, maxX + 65, -1, 0, 280, 2, Color3.fromRGB(126, 91, 61), Enum.Material.Ground, true)
	horizontalStrip(map, "GrassSurface", minX - 23, maxX + 63, 0.08, 0, 276, 0.16, Color3.fromRGB(112, 190, 96), Enum.Material.Grass)
	part(map, "SpawnPad", Vector3.new(70, 2, 70), plaza + Vector3.new(0, -1, 0), Color3.fromRGB(145, 228, 130), Enum.Material.Grass, true)
	horizontalStrip(map, "MainRoad", minX, maxX, 0.22, -12, 12, 0.2, Color3.fromRGB(203, 185, 153), Enum.Material.Cobblestone)
	part(map, "CrossRoad", Vector3.new(12, 0.2, 95), Vector3.new(plaza.X, 0.22, 0), Color3.fromRGB(203, 185, 153), Enum.Material.Cobblestone)
	part(map, "EastPath", Vector3.new(26, 0.2, 12), Vector3.new(plaza.X + 34, 0.22, 12), Color3.fromRGB(203, 185, 153), Enum.Material.Cobblestone)
	part(map, "WestPath", Vector3.new(26, 0.2, 12), Vector3.new(plaza.X - 34, 0.22, 12), Color3.fromRGB(203, 185, 153), Enum.Material.Cobblestone)
	local terrainRandom = Random.new(7481)
	for patchIndex = 1, 112 do
		local x: number
		local z: number
		if patchIndex % 4 == 0 then
			local outerSide = terrainRandom:NextInteger(0, 1) == 0
			x = if outerSide then terrainRandom:NextNumber(-132, -105) else terrainRandom:NextNumber(lastGardenX + 44, lastGardenX + 125)
			z = terrainRandom:NextNumber(44, 112)
		else
			x = terrainRandom:NextNumber(minX + 8, maxX - 8)
			z = terrainRandom:NextNumber(-132, -40)
		end
		if (Vector2.new(x, z) - Vector2.new(-50, -55)).Magnitude > 27 then
			local isSoil = terrainRandom:NextInteger(1, 4) == 1
			local color = if isSoil
				then Color3.fromRGB(terrainRandom:NextInteger(123, 151), terrainRandom:NextInteger(84, 108), terrainRandom:NextInteger(59, 76))
				else Color3.fromRGB(terrainRandom:NextInteger(91, 125), terrainRandom:NextInteger(164, 195), terrainRandom:NextInteger(82, 111))
			part(
				map,
				if isSoil then "ExposedSoilPatch" else "GrassPatch",
				Vector3.new(terrainRandom:NextInteger(12, 26), 0.06, terrainRandom:NextInteger(10, 22)),
				Vector3.new(x, 0.13, z),
				color,
				if isSoil then Enum.Material.Ground else Enum.Material.Grass
			)
			if not isSoil then
				for tuft = 1, 3 do
					part(
						map,
						"BlockyGrassTuft",
						Vector3.new(terrainRandom:NextNumber(1.2, 2.4), terrainRandom:NextNumber(0.25, 0.55), terrainRandom:NextNumber(1.2, 2.4)),
						Vector3.new(x + terrainRandom:NextNumber(-5, 5), 0.3, z + terrainRandom:NextNumber(-4, 4)),
						Color3.fromRGB(terrainRandom:NextInteger(75, 111), terrainRandom:NextInteger(145, 179), terrainRandom:NextInteger(74, 102)),
						Enum.Material.Grass
					)
				end
			end
		end
	end

	-- Plaza central más cuidada y accesible
	part(map, "Plaza", Vector3.new(62, 0.35, 52), plaza + Vector3.new(0, 0.18, 0), Color3.fromRGB(233, 227, 209), Enum.Material.Pebble)
	part(map, "PlazaRing", Vector3.new(48, 0.2, 38), plaza + Vector3.new(0, 0.25, 0), Color3.fromRGB(200, 195, 180), Enum.Material.Slate)
	part(map, "PlazaCenterTile", Vector3.new(32, 0.12, 24), plaza + Vector3.new(0, 0.39, 0), Color3.fromRGB(241, 230, 199), Enum.Material.SmoothPlastic)
	part(map, "PlazaCenterInset", Vector3.new(22, 0.08, 14), plaza + Vector3.new(0, 0.49, 0), Color3.fromRGB(208, 222, 164), Enum.Material.SmoothPlastic)
	for _, xOffset in ipairs({ -28, 28 }) do
		part(map, "PlazaBorderStone", Vector3.new(1.2, 0.42, 50), plaza + Vector3.new(xOffset, 0.34, 0), Color3.fromRGB(162, 177, 133), Enum.Material.Slate)
	end
	for _, zOffset in ipairs({ -24, 24 }) do
		part(map, "PlazaBorderStone", Vector3.new(58, 0.42, 1.2), plaza + Vector3.new(0, 0.34, zOffset), Color3.fromRGB(162, 177, 133), Enum.Material.Slate)
	end
	part(map, "PlazaFlowerBedA", Vector3.new(14, 0.8, 7), plaza + Vector3.new(-18, 0.5, 10), Color3.fromRGB(90, 150, 80), Enum.Material.Grass)
	part(map, "PlazaFlowerBedB", Vector3.new(14, 0.8, 7), plaza + Vector3.new(18, 0.5, 10), Color3.fromRGB(90, 150, 80), Enum.Material.Grass)
	part(map, "PlazaFlowerBedC", Vector3.new(14, 0.8, 7), plaza + Vector3.new(0, 0.5, 18), Color3.fromRGB(90, 150, 80), Enum.Material.Grass)
	for bedIndex, bedPosition in ipairs({
		plaza + Vector3.new(-18, 0.9, 10),
		plaza + Vector3.new(18, 0.9, 10),
		plaza + Vector3.new(0, 0.9, 18),
	}) do
		for flowerIndex = 1, 3 do
			local zOffset = if bedIndex == 3 then 0 else if flowerIndex % 2 == 0 then 1.2 else -1.2
			local color = if flowerIndex == 1
				then Color3.fromRGB(248, 139, 165)
				elseif flowerIndex == 2 then Color3.fromRGB(255, 213, 106)
				else Color3.fromRGB(166, 145, 245)
			buildFlowerClump(
				map,
				bedPosition + Vector3.new((flowerIndex - 2) * 3, 0, zOffset),
				color,
				0.52
			)
		end
	end
	buildPlanter(map, plaza + Vector3.new(-24, 0.4, -12), Vector3.new(9, 2.4, 9), Color3.fromRGB(120, 80, 55))
	buildPlanter(map, plaza + Vector3.new(24, 0.4, -12), Vector3.new(9, 2.4, 9), Color3.fromRGB(120, 80, 55))
	buildBench(map, plaza + Vector3.new(-30, 0.6, 0), 0)
	buildBench(map, plaza + Vector3.new(30, 0.6, 0), 180)
	buildBench(map, plaza + Vector3.new(-10, 0.6, -20), 0)
	buildBench(map, plaza + Vector3.new(10, 0.6, -20), 180)

	for _, offset in ipairs({
		Vector3.new(-36, 0, -22),
		Vector3.new(36, 0, -22),
		Vector3.new(-36, 0, 22),
		Vector3.new(36, 0, 22),
	}) do
		buildLampPost(map, plaza + offset)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(plaza.X, 0.5, -8)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Transparency = 0.4
	spawn.CanCollide = false
	spawn.Parent = map

	buildFountain(map, plaza + Vector3.new(12, 0, -6))
	part(map, "MarketPath", Vector3.new(62, 0.18, 30), plaza + Vector3.new(0, 0.12, 34), Color3.fromRGB(203, 185, 153), Enum.Material.Cobblestone)
	buildShop(map, plaza + Vector3.new(-20, 0, 37), "Seeds", "SEED FARMER", Color3.fromRGB(102, 171, 83), Color3.fromRGB(114, 166, 87))
	buildShop(map, plaza + Vector3.new(0, 0, 37), "Gear", "GEAR FARMER", Color3.fromRGB(93, 147, 202), Color3.fromRGB(102, 130, 168))
	buildShop(map, plaza + Vector3.new(20, 0, 37), "Pets", "EGG FARMER", Color3.fromRGB(165, 119, 205), Color3.fromRGB(151, 110, 176))

	-- Carteles de zonas (desde ZoneConfig)
	for i, zoneId in ipairs(ZoneConfig.Order) do
		local zone = ZoneConfig[zoneId]
		local pos = plaza + Vector3.new(-24 + (i - 1) * 24, 0, -30)
		part(map, "SignPost", Vector3.new(0.8, 5, 0.8), pos + Vector3.new(0, 2.5, 0), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)
		local board = part(map, "ZoneSign_" .. zoneId, Vector3.new(10, 3.4, 0.6), pos + Vector3.new(0, 5.5, 0), Color3.fromRGB(95, 160, 220))
		local req = zone.unlockCash > 0 and ("🔒 $" .. zone.unlockCash .. " ganados") or "✅ Libre"
		billboard(board, "Zona " .. zone.order .. "\n" .. zone.displayName .. "\n" .. req, UDim2.fromOffset(130, 34), Vector3.new(0, 0, 0), 32)
	end

	-- A stepped rectangular pond matches the voxel-like village style.
	part(map, "PondSand", Vector3.new(36, 0.35, 29), Vector3.new(-50, 0.18, -55), Color3.fromRGB(226, 204, 139), Enum.Material.Sand)
	local water = part(map, "Pond", Vector3.new(30, 0.35, 23), Vector3.new(-50, 0.36, -55), Color3.fromRGB(80, 170, 240), Enum.Material.Glass)
	water.Transparency = 0.25
	part(map, "PondWaterStep", Vector3.new(18, 0.15, 11), Vector3.new(-50, 0.58, -55), Color3.fromRGB(123, 205, 255), Enum.Material.Glass).Transparency = 0.35
	local groveTreeTypes = { "Oak", "Pine", "Cherry", "Birch" }
	for index, offset in ipairs({
		Vector3.new(-41, 0, -31),
		Vector3.new(41, 0, -31),
		Vector3.new(-41, 0, 31),
		Vector3.new(41, 0, 31),
	}) do
		buildTree(map, Vector3.new(-50, 0, -55) + offset, 0.92, groveTreeTypes[index])
	end
	for index, offset in ipairs({
		Vector3.new(-24, 0.14, -19),
		Vector3.new(24, 0.14, -19),
		Vector3.new(-24, 0.14, 19),
		Vector3.new(24, 0.14, 19),
		Vector3.new(-25, 0.14, 0),
		Vector3.new(25, 0.14, 0),
	}) do
		local color = if index % 3 == 0
			then Color3.fromRGB(246, 139, 173)
			elseif index % 3 == 1 then Color3.fromRGB(255, 207, 97)
			else Color3.fromRGB(166, 145, 242)
		buildFlowerClump(map, Vector3.new(-50, 0, -55) + offset, color, 0.7)
	end

	-- Four square-canopy tree families frame the plaza without blocking gardens.
	local rng = Random.new(1337)
	local treeTypes = { "Oak", "Pine", "Cherry", "Birch" }
	local treeCount = 48 + maxPlayers * 3
	for index = 1, treeCount do
		local x: number
		local z: number
		if index % 4 == 0 then
			if rng:NextInteger(0, 1) == 0 then
				x = rng:NextNumber(-132, -106)
			else
				x = rng:NextNumber(lastGardenX + 45, lastGardenX + 125)
			end
			z = rng:NextNumber(45, 114)
		else
			x = rng:NextNumber(minX + 5, maxX - 5)
			z = rng:NextNumber(-132, -39)
		end
		local awayFromPond = (Vector2.new(x, z) - Vector2.new(-50, -55)).Magnitude > 25
		if awayFromPond then
			buildTree(map, Vector3.new(x, 0, z), rng:NextNumber(0.82, 1.18), treeTypes[rng:NextInteger(1, #treeTypes)])
		end
	end

	-- Flower islands and lanterns give the long garden road clear landmarks.
	for index = 0, math.floor((maxX - minX) / 54) do
		local x = minX + 18 + index * 54
		if x <= maxX - 18 and math.abs(x - plaza.X) > 42 then
			local flowerColor = if index % 3 == 0
				then Color3.fromRGB(242, 144, 181)
				elseif index % 3 == 1 then Color3.fromRGB(255, 205, 103)
				else Color3.fromRGB(164, 146, 242)
			buildFlowerClump(map, Vector3.new(x, 0.14, plaza.Z - 35), flowerColor, 0.72)
		end
	end
	for x = minX + 72, maxX - 30, 120 do
		if math.abs(x - plaza.X) > 60 then
			buildLampPost(map, Vector3.new(x, 0, plaza.Z - 34))
		end
	end

	-- Small flower borders make the plaza feel planted, not empty.
	for index = 1, 14 do
		local side = if index % 2 == 0 then -1 else 1
		local x = plaza.X + (index - 7.5) * 8
		if math.abs(x - plaza.X) > 42 then
			local flowerColor = if index % 3 == 0 then Color3.fromRGB(242, 144, 181) else Color3.fromRGB(255, 205, 103)
			buildFlowerClump(map, Vector3.new(x, 0.14, side * 24), flowerColor, 0.62)
		end
	end
end

-- Decora el jardín de un jugador y le asigna su punto de reaparición.
function MapBuilder.DecorateGarden(player: Player, garden: Model): Part
	local origin = garden:GetPivot().Position
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = garden

	local wood = Color3.fromRGB(165, 120, 75)

	-- GardenService builds and expands the fenced planting yard.
	buildPlanter(decor, origin + Vector3.new(4, 0, -3), Vector3.new(3, 1.4, 2.4), wood)
	buildPlanter(decor, origin + Vector3.new(26, 0, -3), Vector3.new(3, 1.4, 2.4), wood)

	-- Cartel con el nombre del dueño
	local signPost = part(decor, "SignPost", Vector3.new(0.8, 6, 0.8), origin + Vector3.new(-9, 3, -9), wood, Enum.Material.Wood)
	local board = part(decor, "OwnerSign", Vector3.new(11, 2.4, 0.6), origin + Vector3.new(-9, 6.5, -9), Color3.fromRGB(255, 240, 200))
	billboard(board, "🌱 " .. player.DisplayName .. "'s Garden", UDim2.fromOffset(160, 34), Vector3.new(0, 0, 0), 30)
	signPost.Name = "SignPost"

	-- Arbustos en las esquinas traseras
	for _, offset in ipairs({ Vector3.new(-5, 1.5, 25), Vector3.new(35, 1.5, 25) }) do
		part(decor, "BlockyBushBase", Vector3.new(4, 3, 4), origin + offset, Color3.fromRGB(60, 150, 75), Enum.Material.Grass)
		part(decor, "BlockyBushTop", Vector3.new(2.6, 1.6, 2.6), origin + offset + Vector3.new(0, 1.8, 0), Color3.fromRGB(84, 177, 82), Enum.Material.Grass)
	end

	-- Punto de reaparición propio del jardín
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GardenSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + Vector3.new(15, 0.5, -11)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = garden
	player.RespawnLocation = spawn

	return spawn
end

return MapBuilder
