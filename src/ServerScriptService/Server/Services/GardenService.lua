--!strict
--[[
	GardenService.lua
	Responsable de:
	  - Asignar a cada jugador una parcela de terreno física en Workspace
	    (su "jardín"), separada de la de los demás jugadores.
	  - Crear los Parts de cultivo y ampliar el patio vallado cuando se
	    ocupan las parcelas disponibles.
	  - Gestionar la mejora de nivel de jardín (cobra Cash vía EconomyService).

	No conoce nada de plantas ni de robo: eso vive en PlantService / StealService,
	que escuchan la señal PlotCreated para añadir su propia lógica a cada plot
	sin acoplar este módulo a los demás.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

local DataService = require(script.Parent.DataService)

local GardenService = {}

-- Se dispara (player, plotIndex, plotPart) cada vez que se crea un plot nuevo.
-- PlantService y DefenseService/StealService escuchan esto para añadir
-- ProximityPrompts y estado sin que GardenService tenga que conocerlos.
GardenService.PlotCreated = Signal.new()

local gardensFolder = Workspace:FindFirstChild("Gardens")
if not gardensFolder then
	gardensFolder = Instance.new("Folder")
	gardensFolder.Name = "Gardens"
	gardensFolder.Parent = Workspace
end

-- userId -> slotIndex (posición del jardín en el mapa)
local assignedSlots: { [number]: number } = {}
local freeSlots: { number } = {}
local nextSlotIndex = 0

-- userId -> { [plotIndex] = BasePart }
local plotPartsByUser: { [number]: { [number]: BasePart } } = {}

-- userId -> Model (el jardín completo del jugador)
local gardenModelByUser: { [number]: Model } = {}

local function takeSlot(): number
	if #freeSlots > 0 then
		return table.remove(freeSlots) :: number
	end
	local slot = nextSlotIndex
	nextSlotIndex += 1
	return slot
end

local function releaseSlot(slot: number)
	table.insert(freeSlots, slot)
end

local function createPlotPart(player: Player, plotIndex: number, position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "Plot_" .. plotIndex
	part.Anchored = true
	part.CanCollide = false
	part.Size = GardenConfig.PlotSize
	part.Position = position
	part.Material = Enum.Material.Grass
	part.Color = Color3.fromRGB(91, 154, 76)
	part.Transparency = 1 -- el hueco no se ve: la planta trae su propia tierra labrada
	part.CanQuery = false
	part:SetAttribute("PlotIndex", plotIndex)
	part:SetAttribute("OwnerUserId", player.UserId)
	return part
end

local function mk(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Cartel de bienvenida sobre una puerta: "Jardín de <nombre>" legible desde
-- ambos lados, con el nivel de rebirth debajo.
local function buildGateSign(yard: Folder, center: Vector3, style: any, ownerName: string, rebirths: number)
	local board = mk(yard, "OwnerSign", Vector3.new(15.4, 3.4, 0.6), center, style.signColor, Enum.Material.SmoothPlastic, false)
	-- Marco fino alrededor del cartel
	mk(yard, "SignTrim", Vector3.new(15.8, 0.35, 0.8), center + Vector3.new(0, 1.85, 0), style.gateColor, style.gateMaterial, false)
	mk(yard, "SignTrim", Vector3.new(15.8, 0.35, 0.8), center - Vector3.new(0, 1.85, 0), style.gateColor, style.gateMaterial, false)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0
		gui.MaxDistance = 140
		gui.Parent = board
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(0.94, 0.62)
		title.Position = UDim2.fromScale(0.03, 0.06)
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.TextColor3 = style.signTextColor
		title.Text = "Jardín de " .. ownerName
		title.Parent = gui
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Size = UDim2.fromScale(0.8, 0.24)
		sub.Position = UDim2.fromScale(0.1, 0.7)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextTransparency = 0.15
		sub.TextColor3 = style.signTextColor
		sub.Text = if rebirths > 0 then ("♻️ Rebirth " .. rebirths .. " · " .. style.name) else ("🌱 " .. style.name)
		sub.Parent = gui
	end
end

local function rebuildGardenYard(gardenModel: Model, origin: Vector3, plotCount: number, minimumRows: number?)
	-- Tamaño FIJO: el patio nunca crece (antes se comía la calle y la tienda).
	local _ = plotCount
	local __ = minimumRows
	local frontZ = GardenConfig.YardFrontZ
	local backZ = GardenConfig.YardBackZ
	local depth = backZ - frontZ
	local centerZ = (frontZ + backZ) / 2

	local rebirths = (gardenModel:GetAttribute("Rebirths") :: number?) or 0
	local ownerName = (gardenModel:GetAttribute("OwnerName") :: string?) or "Jugador"
	local tier = GardenConfig.GetFenceTier(rebirths)
	local style: any = GardenConfig.FenceStyles[tier]

	-- Si nada cambió (misma profundidad, estilo y nombre) no reconstruimos:
	-- colocar flores llama a esto muy a menudo.
	local row = (gardenModel:GetAttribute("Row") :: number?) or 0
	local key = table.concat({ tostring(depth), tostring(tier), ownerName, tostring(rebirths), tostring(row) }, ":")
	local oldYard = gardenModel:FindFirstChild("YardBoundary")
	if oldYard and gardenModel:GetAttribute("YardKey") == key then
		return
	end
	if oldYard then
		oldYard:Destroy()
	end
	gardenModel:SetAttribute("YardKey", key)

	local decor = gardenModel:FindFirstChild("Decor")
	if decor then
		for _, child in ipairs(decor:GetChildren()) do
			if child.Name == "SoilPad" or child.Name == "Rail" or child.Name == "Post" or child.Name == "GatePost" then
				child:Destroy()
			end
		end
	end

	local yard = Instance.new("Folder")
	yard.Name = "YardBoundary"
	yard.Parent = gardenModel

	-- Suelo del jardín: cara superior en y=0.22 (por encima del césped, 0.16).
	local floor = mk(yard, "GardenFloor", Vector3.new(44, 0.4, depth), origin + Vector3.new(15, 0.02, centerZ), Color3.fromRGB(120, 85, 55), Enum.Material.Ground, true)
	floor.CastShadow = true
	-- UNA sola entrada, la que da a la calle: fila sur por detrás, fila norte por delante.
	local gateZ = if row == 0 then backZ else frontZ
	local closedZ = if row == 0 then frontZ else backZ
	do
		local dir = if gateZ == frontZ then 1 else -1
		mk(yard, "GatePaving", Vector3.new(6, 0.12, 5), origin + Vector3.new(15, 0.26, gateZ + dir * 3), Color3.fromRGB(190, 180, 160), Enum.Material.Cobblestone, false)
	end

	local lanternColor = if style.sparkle then style.capColor else Color3.fromRGB(255, 226, 130)

	-- Un tramo de valla recto. axis "x": a lo largo de X en z=fixed; "z": a lo largo de Z en x=fixed.
	local function run(axis: string, fixed: number, a: number, b: number)
		local len = b - a
		local mid = (a + b) / 2
		local function at(along: number, y: number): Vector3
			return origin + (if axis == "x" then Vector3.new(along, y, fixed) else Vector3.new(fixed, y, along))
		end
		local function dims(alongLen: number, height: number, thick: number): Vector3
			return if axis == "x" then Vector3.new(alongLen, height, thick) else Vector3.new(thick, height, alongLen)
		end
		if style.baseHeight > 0 then
			mk(yard, "FenceBase", dims(len, style.baseHeight, 1), at(mid, style.baseHeight / 2), style.baseColor, style.baseMaterial, true)
		end
		for _, height in ipairs(style.railHeights) do
			mk(yard, "FenceRail", dims(len, style.railThickness, style.railThickness), at(mid, height), style.railColor, style.railMaterial, true)
		end
		if style.picketSpacing > 0 then
			local count = math.floor(len / style.picketSpacing)
			for i = 1, count do
				local along = a + (i - 0.5) * len / count
				local ps = style.picketSize
				local picket = mk(
					yard, "FencePicket", dims(ps.X, ps.Y, ps.Z),
					at(along, style.baseHeight + ps.Y / 2 - 0.1), style.picketColor, style.picketMaterial, false
				)
				picket.Transparency = style.picketTransparency
			end
		end
		local postCount = math.max(1, math.round(len / style.postSpacing))
		for i = 0, postCount do
			local along = a + len * i / postCount
			local ps = style.postSize
			local post = mk(yard, "FencePost", ps, at(along, ps.Y / 2), style.postColor, style.postMaterial, true)
			if style.postMaterial == Enum.Material.Glass then
				post.Transparency = 0.2
			end
			local topY = ps.Y
			if style.capShape == "ball" then
				local cap = mk(yard, "FenceCap", Vector3.new(style.capSize, style.capSize, style.capSize), at(along, topY + style.capSize * 0.4), style.capColor, style.capMaterial, false)
				cap.Shape = Enum.PartType.Ball
				topY += style.capSize * 0.9
			elseif style.capShape == "block" then
				mk(yard, "FenceCap", Vector3.new(style.capSize, 0.4, style.capSize), at(along, topY + 0.2), style.capColor, style.capMaterial, false)
				topY += 0.4
			elseif style.capShape == "diamond" then
				local cap = mk(yard, "FenceCap", Vector3.new(style.capSize, style.capSize, style.capSize), at(along, topY + style.capSize * 0.7), style.capColor, style.capMaterial, false)
				cap.CFrame = CFrame.new(cap.Position) * CFrame.Angles(math.rad(45), math.rad(45), 0)
				topY += style.capSize * 1.4
			end
			if style.lantern then
				mk(yard, "FenceLantern", Vector3.new(0.7, 0.8, 0.7), at(along, topY + 0.4), lanternColor, Enum.Material.Neon, false)
			end
		end
	end

	-- Lados completos y frentes con hueco de puerta (x 8..22).
	run("z", -7, frontZ, backZ)
	run("z", 37, frontZ, backZ)
	run("x", gateZ, -7, 8)
	run("x", gateZ, 22, 37)
	run("x", closedZ, -7, 37) -- lado cerrado: valla continua, sin puerta

	-- Puerta única: dos pilares con viga y cartel con el nombre del dueño.
	for _, z in ipairs({ gateZ }) do
		for _, x in ipairs({ 8, 22 }) do
			mk(yard, "GatePillar", Vector3.new(1.5, 7, 1.5), origin + Vector3.new(x, 3.5, z), style.gateColor, style.gateMaterial, true)
			mk(yard, "GatePillarCap", Vector3.new(2, 0.5, 2), origin + Vector3.new(x, 7.25, z), style.capShape == "none" and style.railColor or style.capColor, if style.capShape == "none" then Enum.Material.Wood else style.capMaterial, false)
			mk(yard, "GateLamp", Vector3.new(1.1, 1.0, 1.1), origin + Vector3.new(x, 8.0, z), lanternColor, Enum.Material.Neon, false)
		end
		mk(yard, "GateBeam", Vector3.new(15.5, 0.8, 1.1), origin + Vector3.new(15, 6.7, z), style.gateColor, style.gateMaterial, false)
		buildGateSign(yard, origin + Vector3.new(15, 8.9, z), style, ownerName, rebirths)
	end

	-- Destellos en las cuatro esquinas (solo vallas de cristal y doradas).
	if style.sparkle then
		for _, corner in ipairs({ Vector3.new(-7, 0, frontZ), Vector3.new(37, 0, frontZ), Vector3.new(-7, 0, backZ), Vector3.new(37, 0, backZ) }) do
			local host = mk(yard, "CornerSparkle", Vector3.new(0.5, 0.5, 0.5), origin + corner + Vector3.new(0, 5.4, 0), style.capColor, Enum.Material.Neon, false)
			host.Transparency = 1
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Color = ColorSequence.new(style.capColor)
			emitter.Rate = 3
			emitter.Lifetime = NumberRange.new(1, 1.8)
			emitter.Speed = NumberRange.new(0.4, 1.2)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
			emitter.LightEmission = 0.8
			emitter.Parent = host
		end
	end
end

-- Crea (si faltan) los plots hasta llegar a targetPlotCount. Nunca destruye
-- plots existentes: así una mejora de jardín no interrumpe plantas que ya
-- están creciendo.
local function ensurePlotsExist(player: Player, gardenModel: Model, targetPlotCount: number)
	local userPlots = plotPartsByUser[player.UserId]
	if not userPlots then
		userPlots = {}
		plotPartsByUser[player.UserId] = userPlots
	end

	local columns = 4
	for plotIndex = 1, targetPlotCount do
		if not userPlots[plotIndex] then
			local col = (plotIndex - 1) % columns
			local row = math.floor((plotIndex - 1) / columns)
			local localOffset = Vector3.new(col * GardenConfig.PlotSpacing, 0, row * GardenConfig.PlotSpacing)
			local worldPosition = (gardenModel:GetPivot().Position) + localOffset
			local saved = DataService.GetProfile(player)
			local savedPlot = saved and saved.plots and saved.plots[plotIndex]
			if type(savedPlot) == "table" and type(savedPlot.pos) == "table" and type(savedPlot.pos.x) == "number" and type(savedPlot.pos.z) == "number" then
				worldPosition = gardenModel:GetPivot().Position + Vector3.new(savedPlot.pos.x, 0, savedPlot.pos.z)
			end

			local part = createPlotPart(player, plotIndex, worldPosition)
			part.Parent = gardenModel
			userPlots[plotIndex] = part

			GardenService.PlotCreated:Fire(player, plotIndex, part)
		end
	end
	rebuildGardenYard(gardenModel, gardenModel:GetPivot().Position, targetPlotCount)
end

-- Posición de mundo en la calle, frente a la puerta de entrada del jardín.
-- `outwardExtra` aleja más hacia la calle (para expulsar ladrones).
function GardenService.GetEntryPosition(garden: Model, height: number, outwardExtra: number?): Vector3
	local entryZ = (garden:GetAttribute("EntryZ") :: number?) or -11
	local outward = (garden:GetAttribute("Outward") :: number?) or -1
	return garden:GetPivot().Position + Vector3.new(15, height, entryZ + outward * (outwardExtra or 0))
end

-- Construye o actualiza el jardín físico del jugador según su perfil.
function GardenService.AssignGarden(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end

	local slot = takeSlot()
	assignedSlots[player.UserId] = slot
	player:SetAttribute("Luck", RebirthConfig.Luck(profile.rebirthCount or 0))

	local layout = GardenConfig.GetSlotLayout(slot)
	local origin = layout.origin

	local gardenModel = Instance.new("Model")
	gardenModel.Name = "Garden_" .. player.UserId
	gardenModel:SetAttribute("OwnerUserId", player.UserId)
	gardenModel:SetAttribute("OwnerName", player.DisplayName)
	gardenModel:SetAttribute("Rebirths", profile.rebirthCount or 0)
	gardenModel:SetAttribute("Slot", slot)
	gardenModel:SetAttribute("Row", layout.row)
	gardenModel:SetAttribute("EntryZ", layout.entryZ)
	gardenModel:SetAttribute("Outward", layout.outward)
	gardenModel:PivotTo(CFrame.new(origin))
	gardenModel.Parent = gardensFolder
	gardenModelByUser[player.UserId] = gardenModel

	-- Marcador de spawn/base del jardín, útil para teletransportar al
	-- dueño de vuelta tras un robo fallido (StealService, próxima iteración).
	local baseMarker = Instance.new("Part")
	baseMarker.Name = "GardenOrigin"
	baseMarker.Anchored = true
	baseMarker.CanCollide = false
	baseMarker.Transparency = 1
	baseMarker.Size = Vector3.new(1, 1, 1)
	baseMarker.Position = origin
	baseMarker.Parent = gardenModel

	local incubator = Instance.new("Model")
	incubator.Name = "PetIncubator"
	incubator.Parent = gardenModel
	local incubatorBase = Instance.new("Part")
	incubatorBase.Name = "IncubatorBase"
	incubatorBase.Anchored = true
	incubatorBase.Size = Vector3.new(4, 2, 4)
	incubatorBase.Position = origin + Vector3.new(40.5, 0.95, 16)
	incubatorBase.Material = Enum.Material.Wood
	incubatorBase.Color = Color3.fromRGB(143, 95, 57)
	incubatorBase.Parent = incubator
	local eggCradle = Instance.new("Part")
	eggCradle.Name = "EggCradle"
	eggCradle.Anchored = true
	eggCradle.CanCollide = false
	eggCradle.Size = Vector3.new(2.2, 1.5, 2.2)
	eggCradle.Position = origin + Vector3.new(40.5, 2.4, 16)
	eggCradle.Material = Enum.Material.Neon
	eggCradle.Color = Color3.fromRGB(255, 207, 99)
	eggCradle.Parent = incubator
	local incubatorPrompt = Instance.new("ProximityPrompt")
	incubatorPrompt.Name = "IncubatorPrompt"
	incubatorPrompt:SetAttribute("OwnerUserId", player.UserId)
	incubatorPrompt.ActionText = "Open"
	incubatorPrompt.ObjectText = "Pet Incubator"
	incubatorPrompt.HoldDuration = 0
	incubatorPrompt.MaxActivationDistance = 10
	incubatorPrompt.RequiresLineOfSight = false
	incubatorPrompt.Parent = incubatorBase

	local highestSavedPlot = 0
	for plotIndex in pairs(profile.plots or {}) do
		if type(plotIndex) == "number" then
			highestSavedPlot = math.max(highestSavedPlot, plotIndex)
		end
	end
	ensurePlotsExist(player, gardenModel, math.max(GardenConfig.GetMaxPlots(profile.rebirthCount or 0), highestSavedPlot))
end

function GardenService.GetPlotPart(player: Player, plotIndex: number): BasePart?
	local userPlots = plotPartsByUser[player.UserId]
	if not userPlots then
		return nil
	end
	return userPlots[plotIndex]
end

function GardenService.GetGardenModel(player: Player): Model?
	return gardenModelByUser[player.UserId]
end

function GardenService.GetCurrentPlotCount(player: Player): number
	local userPlots = plotPartsByUser[player.UserId]
	local highest = 0
	if userPlots then
		for plotIndex in pairs(userPlots) do
			highest = math.max(highest, plotIndex)
		end
	end
	return highest
end

function GardenService.GetYardPosition(player: Player, position: Vector3): Vector3?
	local garden = gardenModelByUser[player.UserId]
	local floor = garden and garden:FindFirstChild("YardBoundary")
		and garden.YardBoundary:FindFirstChild("GardenFloor")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local function finite(value: number): boolean
		return value == value and value > -1_000_000 and value < 1_000_000
	end
	if not finite(position.X) or not finite(position.Y) or not finite(position.Z)
		or not garden or not floor or not floor:IsA("BasePart") or not root
		or (root.Position - position).Magnitude > 55 then
		return nil
	end

	local localPosition = floor.CFrame:PointToObjectSpace(position)
	if math.abs(localPosition.X) > floor.Size.X / 2 - GardenConfig.PlacementMargin
		or math.abs(localPosition.Z) > floor.Size.Z / 2 - GardenConfig.PlacementMargin then
		return nil
	end
	return floor.CFrame:PointToWorldSpace(Vector3.new(localPosition.X, floor.Size.Y / 2, localPosition.Z))
end

function GardenService.PlaceEmptyPlotAt(player: Player, position: Vector3): number?
	local profile = DataService.GetProfile(player)
	local garden = gardenModelByUser[player.UserId]
	local userPlots = plotPartsByUser[player.UserId]
	local yardPosition = GardenService.GetYardPosition(player, position)
	if not profile or not garden or not userPlots or not yardPosition then
		return nil
	end

	local selectedIndex: number? = nil
	local selectedPart: BasePart? = nil
	local nearestDistance = math.huge
	for plotIndex, plotPart in pairs(userPlots) do
		if profile.plots[plotIndex] == nil then
			local distance = (plotPart.Position - yardPosition).Magnitude
			if distance < nearestDistance then
				selectedIndex = plotIndex
				selectedPart = plotPart
				nearestDistance = distance
			end
		end
	end
	if not selectedIndex or not selectedPart then
		return nil
	end

	local snappedX = math.floor(yardPosition.X * 2 + 0.5) / 2
	local snappedZ = math.floor(yardPosition.Z * 2 + 0.5) / 2
	local destination = Vector3.new(snappedX, selectedPart.Position.Y, snappedZ)
	for otherIndex, otherPart in pairs(userPlots) do
		if otherIndex ~= selectedIndex and profile.plots[otherIndex] ~= nil
			and (otherPart.Position - destination).Magnitude < 8 then
			return nil
		end
	end
	local gardenOrigin = garden:GetPivot().Position
	for placedIndex, plant in ipairs(profile.placedPlants or {}) do
		local savedPosition = plant.position
		local localPosition = if type(savedPosition) == "table" and type(savedPosition.x) == "number" and type(savedPosition.z) == "number"
			then Vector3.new(savedPosition.x, 0, savedPosition.z)
			else Vector3.new(-5, 0, (placedIndex - 1) * 5 - 4)
		local plantPosition = gardenOrigin + localPosition
		if (plantPosition - destination).Magnitude < 4.5 then
			return nil
		end
	end
	selectedPart.Position = destination
	return selectedIndex
end

-- Los huecos son los que permite el renacimiento; nunca se crean más.
function GardenService.EnsureAvailablePlot(player: Player)
	local profile = DataService.GetProfile(player)
	local gardenModel = gardenModelByUser[player.UserId]
	if profile and gardenModel then
		ensurePlotsExist(player, gardenModel, GardenConfig.GetMaxPlots(profile.rebirthCount or 0))
	end
end

-- Huecos libres / totales (para mostrar "3/6" y el error de jardín lleno).
function GardenService.GetPlotUsage(player: Player): (number, number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0, 0
	end
	local used = 0
	for _, plotData in pairs(profile.plots) do
		if plotData ~= nil then
			used += 1
		end
	end
	return used, GardenConfig.GetMaxPlots(profile.rebirthCount or 0)
end

-- Actualiza valla y cartel (p. ej. tras un Rebirth o cambiar el nombre).
function GardenService.RefreshFence(player: Player)
	local gardenModel = gardenModelByUser[player.UserId]
	local profile = DataService.GetProfile(player)
	if not gardenModel or not profile then
		return
	end
	gardenModel:SetAttribute("Rebirths", profile.rebirthCount or 0)
	gardenModel:SetAttribute("OwnerName", player.DisplayName)
	ensurePlotsExist(player, gardenModel, GardenConfig.GetMaxPlots(profile.rebirthCount or 0))
	rebuildGardenYard(gardenModel, gardenModel:GetPivot().Position, GardenService.GetCurrentPlotCount(player), nil)
end

function GardenService.ExpandGardenForPlants(_player: Player, _activePlantCount: number)
	-- El jardín tiene tamaño fijo (no-op conservado por compatibilidad).
end

-- Sube el nivel de jardín del jugador si tiene Cash suficiente.
-- Devuelve (success, newLevel/errorReason)
function GardenService.UpgradeGarden(player: Player, EconomyService: any): (boolean, any)
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local nextLevel = profile.gardenLevel + 1
	local nextLevelData = GardenConfig.Levels[nextLevel]
	if not nextLevelData then
		return false, "max_level"
	end

	local ok = EconomyService.TryRemoveCash(player, nextLevelData.upgradePrice, "garden_upgrade")
	if not ok then
		return false, "not_enough_cash"
	end

	profile.gardenLevel = nextLevel
	DataService.MarkDirty(player)

	return true, nextLevel
end

function GardenService.ReleaseGarden(player: Player)
	local slot = assignedSlots[player.UserId]
	if slot then
		releaseSlot(slot)
		assignedSlots[player.UserId] = nil
	end

	local model = gardenModelByUser[player.UserId]
	if model then
		model:Destroy()
		gardenModelByUser[player.UserId] = nil
	end

	plotPartsByUser[player.UserId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	GardenService.ReleaseGarden(player)
end)

return GardenService
