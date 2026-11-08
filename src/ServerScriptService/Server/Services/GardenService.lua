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
	part:SetAttribute("PlotIndex", plotIndex)
	part:SetAttribute("OwnerUserId", player.UserId)
	return part
end

local function rebuildGardenYard(gardenModel: Model, origin: Vector3, plotCount: number, minimumRows: number?)
	local decor = gardenModel:FindFirstChild("Decor")
	if decor then
		for _, child in ipairs(decor:GetChildren()) do
			if child.Name == "SoilPad" or child.Name == "Rail" or child.Name == "Post" or child.Name == "GatePost" then
				child:Destroy()
			end
		end
	end

	local oldYard = gardenModel:FindFirstChild("YardBoundary")
	if oldYard then
		oldYard:Destroy()
	end
	local yard = Instance.new("Folder")
	yard.Name = "YardBoundary"
	yard.Parent = gardenModel

	local rowCount = math.max(4, math.ceil(plotCount / 4), minimumRows or 0)
	local frontZ = -7
	local backZ = math.max(37, (rowCount - 1) * GardenConfig.PlotSpacing + 7)
	local depth = backZ - frontZ
	local centerZ = (frontZ + backZ) / 2
	local wood = Color3.fromRGB(165, 120, 75)

	local floor = Instance.new("Part")
	floor.Name = "GardenFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(44, 0.4, depth)
	floor.Position = origin + Vector3.new(15, 0.02, centerZ) -- cara superior en y=0.22, por encima del césped (0.16)
	floor.Material = Enum.Material.Ground
	floor.Color = Color3.fromRGB(120, 85, 55)
	floor.Parent = yard

	local function rail(size: Vector3, offset: Vector3)
		local part = Instance.new("Part")
		part.Name = "FenceRail"
		part.Anchored = true
		part.Size = size
		part.Position = origin + offset
		part.Material = Enum.Material.Wood
		part.Color = wood
		part.Parent = yard
	end

	rail(Vector3.new(15, 0.5, 0.5), Vector3.new(0.5, 2.2, backZ))
	rail(Vector3.new(15, 0.5, 0.5), Vector3.new(29.5, 2.2, backZ))
	rail(Vector3.new(0.5, 0.5, depth), Vector3.new(-7, 2.2, centerZ))
	rail(Vector3.new(0.5, 0.5, depth), Vector3.new(37, 2.2, centerZ))
	rail(Vector3.new(15, 0.5, 0.5), Vector3.new(0.5, 2.2, frontZ))
	rail(Vector3.new(15, 0.5, 0.5), Vector3.new(29.5, 2.2, frontZ))

	for x = -7, 37, 8 do
		for _, z in ipairs({ frontZ, backZ }) do
			local post = Instance.new("Part")
			post.Name = "FencePost"
			post.Anchored = true
			post.Size = Vector3.new(0.9, 3.4, 0.9)
			post.Position = origin + Vector3.new(x, 1.7, z)
			post.Material = Enum.Material.Wood
			post.Color = wood
			post.Parent = yard
		end
	end
	-- Pilares de entrada con farol en ambas puertas (delantera y trasera).
	for _, z in ipairs({ frontZ, backZ }) do
		for _, x in ipairs({ 8, 22 }) do
			local pillar = Instance.new("Part")
			pillar.Name = "GatePillar"
			pillar.Anchored = true
			pillar.Size = Vector3.new(1.2, 5, 1.2)
			pillar.Position = origin + Vector3.new(x, 2.5, z)
			pillar.Material = Enum.Material.Wood
			pillar.Color = Color3.fromRGB(120, 85, 55)
			pillar.Parent = yard
			local lamp = Instance.new("Part")
			lamp.Name = "GateLamp"
			lamp.Anchored = true
			lamp.CanCollide = false
			lamp.Size = Vector3.new(1.1, 0.9, 1.1)
			lamp.Position = origin + Vector3.new(x, 5.4, z)
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(255, 226, 130)
			lamp.Parent = yard
		end
	end

	for z = frontZ, backZ, 8.5 do
		for _, x in ipairs({ -7, 37 }) do
			local post = Instance.new("Part")
			post.Name = "FencePost"
			post.Anchored = true
			post.Size = Vector3.new(0.9, 3.4, 0.9)
			post.Position = origin + Vector3.new(x, 1.7, z)
			post.Material = Enum.Material.Wood
			post.Color = wood
			post.Parent = yard
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

	local layout = GardenConfig.GetSlotLayout(slot)
	local origin = layout.origin

	local gardenModel = Instance.new("Model")
	gardenModel.Name = "Garden_" .. player.UserId
	gardenModel:SetAttribute("OwnerUserId", player.UserId)
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
	incubatorBase.Position = origin + Vector3.new(30, 0.95, 1)
	incubatorBase.Material = Enum.Material.Wood
	incubatorBase.Color = Color3.fromRGB(143, 95, 57)
	incubatorBase.Parent = incubator
	local eggCradle = Instance.new("Part")
	eggCradle.Name = "EggCradle"
	eggCradle.Anchored = true
	eggCradle.CanCollide = false
	eggCradle.Size = Vector3.new(2.2, 1.5, 2.2)
	eggCradle.Position = origin + Vector3.new(30, 2.4, 1)
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
	local levelData = GardenConfig.Levels[profile.gardenLevel] or GardenConfig.Levels[1]
	ensurePlotsExist(player, gardenModel, math.max(levelData.plotCount, highestSavedPlot + 1))
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

function GardenService.EnsureAvailablePlot(player: Player)
	local profile = DataService.GetProfile(player)
	local gardenModel = gardenModelByUser[player.UserId]
	local userPlots = plotPartsByUser[player.UserId]
	if not profile or not gardenModel or not userPlots then
		return
	end

	for plotIndex in pairs(userPlots) do
		if profile.plots[plotIndex] == nil then
			return
		end
	end

	ensurePlotsExist(player, gardenModel, GardenService.GetCurrentPlotCount(player) + 1)
end

function GardenService.ExpandGardenForPlants(player: Player, activePlantCount: number)
	local gardenModel = gardenModelByUser[player.UserId]
	if not gardenModel then
		return
	end
	rebuildGardenYard(
		gardenModel,
		gardenModel:GetPivot().Position,
		GardenService.GetCurrentPlotCount(player),
		activePlantCount + 1
	)
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

	local gardenModel = gardenModelByUser[player.UserId]
	if gardenModel then
		ensurePlotsExist(player, gardenModel, nextLevelData.plotCount)
	end

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
