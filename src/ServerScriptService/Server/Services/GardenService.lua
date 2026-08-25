--!strict
--[[
	GardenService.lua
	Responsable de:
	  - Asignar a cada jugador una parcela de terreno física en Workspace
	    (su "jardín"), separada de la de los demás jugadores.
	  - Crear los Parts de cada plot (parcela individual para una planta)
	    según GardenConfig y el nivel de jardín guardado en su perfil.
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
end

-- Construye o actualiza el jardín físico del jugador según su perfil.
function GardenService.AssignGarden(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end

	local slot = takeSlot()
	assignedSlots[player.UserId] = slot

	local origin = Vector3.new(slot * GardenConfig.GardenSlotSpacing, 0, 0)

	local gardenModel = Instance.new("Model")
	gardenModel.Name = "Garden_" .. player.UserId
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

	local levelData = GardenConfig.Levels[profile.gardenLevel] or GardenConfig.Levels[1]
	ensurePlotsExist(player, gardenModel, levelData.plotCount)
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
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	local levelData = GardenConfig.Levels[profile.gardenLevel] or GardenConfig.Levels[1]
	return levelData.plotCount
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
