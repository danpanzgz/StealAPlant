--!strict
--[[
	PlantService.lua
	Corazón del Core Loop: plantar semilla, crecer por fases, cosechar,
	generar ingreso pasivo. TODO el cálculo de tiempo se hace con
	os.time()/timestamps guardados en el perfil del jugador, nunca con
	temporizadores del cliente, así que no se puede "hacer trampa"
	editando el tiempo local ni recargando la app.

	Estado por plot, guardado en profile.plots[plotIndex]:
		{
			plantId = "Tomato",
			plantedAt = <unix time>,
			mutation = "Golden" | false,
			harvestable = boolean, -- calculado, no autoritativo, solo cache
		}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local EconomyService = require(script.Parent.EconomyService)

local PlantService = {}

local growthUpdatedEvent = Net.GetRemoteEvent("PlantGrowthUpdated")
local plantHarvestedEvent = Net.GetRemoteEvent("PlantHarvested")

-- plotPart -> modelo visual de la planta actual (para poder reemplazarlo/limpiarlo)
local plantModelsByPlot: { [BasePart]: Model } = {}
-- plotPart -> ProximityPrompt de interacción de plantar/cosechar
local promptsByPlot: { [BasePart]: ProximityPrompt } = {}

-- ===== Utilidades internas =====

local function rollMutation(): string | false
	for _, mutationId in ipairs(MutationConfig.Order) do
		local data = MutationConfig[mutationId]
		if math.random() < data.chance then
			return mutationId
		end
	end
	return false
end

local function getPlotProgress(plotData: any, plantData: any): number
	local elapsed = os.time() - plotData.plantedAt
	return math.clamp(elapsed / plantData.growTimeSeconds, 0, 1)
end

local function getStageFromProgress(progress: number, stageCount: number): number
	return math.clamp(math.floor(progress * stageCount) + 1, 1, stageCount)
end

local function clearPlantVisual(plotPart: BasePart)
	local existing = plantModelsByPlot[plotPart]
	if existing then
		existing:Destroy()
		plantModelsByPlot[plotPart] = nil
	end
end

-- Representación simple con Parts (arte placeholder, reemplazable por
-- modelos reales sin tocar ninguna lógica de este Service).
local function buildPlantVisual(plotPart: BasePart, plantData: any, stage: number, stageCount: number, mutation: string | false)
	clearPlantVisual(plotPart)

	local model = Instance.new("Model")
	model.Name = "PlantVisual"

	local scale = 0.3 + (stage / stageCount) * 0.9
	local color = plantData.color
	if mutation then
		color = MutationConfig[mutation].color
	end

	local part = Instance.new("Part")
	part.Name = "Body"
	part.Anchored = true
	part.CanCollide = false
	part.Material = mutation and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = Vector3.new(2.5, 2.5, 2.5) * scale
	part.Position = plotPart.Position + Vector3.new(0, (part.Size.Y / 2) + 0.55, 0)
	part.Shape = Enum.PartType.Ball
	part.Parent = model

	model.PrimaryPart = part
	model.Parent = plotPart.Parent
	plantModelsByPlot[plotPart] = model
end

local function updatePrompt(prompt: ProximityPrompt, actionText: string, objectText: string, enabled: boolean)
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.Enabled = enabled
end

-- Redibuja el estado visual de un plot (vacío / creciendo / maduro) a
-- partir del perfil guardado. Se llama al crear el plot y en cada tick
-- de crecimiento.
local function refreshPlot(player: Player, plotIndex: number, plotPart: BasePart)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end

	local prompt = promptsByPlot[plotPart]
	local plotData = profile.plots[plotIndex]

	if not plotData then
		clearPlantVisual(plotPart)
		if prompt then
			updatePrompt(prompt, "Plant", "Empty Plot", true)
		end
		return
	end

	local plantData = PlantConfig[plotData.plantId]
	if not plantData then
		-- Dato corrupto/plantId desconocido: limpiar de forma segura.
		profile.plots[plotIndex] = nil
		DataService.MarkDirty(player)
		return
	end

	local progress = getPlotProgress(plotData, plantData)
	local stage = getStageFromProgress(progress, plantData.stageCount)

	buildPlantVisual(plotPart, plantData, stage, plantData.stageCount, plotData.mutation)

	if prompt then
		if progress >= 1 then
			local label = plantData.displayName .. (plotData.mutation and (" (" .. plotData.mutation .. ")") or "")
			updatePrompt(prompt, "Harvest", label, true)
		else
			local secondsLeft = math.max(0, math.ceil(plantData.growTimeSeconds - (os.time() - plotData.plantedAt)))
			updatePrompt(prompt, "Growing...", plantData.displayName .. " (" .. secondsLeft .. "s)", false)
		end
	end
end

-- ===== API pública =====

-- plantId es sugerido por el cliente pero SIEMPRE se revalida aquí:
-- inventario real, plot vacío, plot dentro del nivel de jardín actual.
function PlantService.PlantSeed(player: Player, plotIndex: number, plantId: string): (boolean, string?)
	if type(plotIndex) ~= "number" or type(plantId) ~= "string" then
		return false, "invalid_args"
	end

	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local plantData = PlantConfig[plantId]
	if not plantData then
		return false, "unknown_plant"
	end

	local maxPlots = GardenService.GetCurrentPlotCount(player)
	if plotIndex < 1 or plotIndex > maxPlots then
		return false, "invalid_plot"
	end

	if profile.plots[plotIndex] ~= nil then
		return false, "plot_occupied"
	end

	local owned = profile.inventory[plantId] or 0
	if owned <= 0 then
		return false, "no_seed_in_inventory"
	end

	profile.inventory[plantId] = owned - 1
	profile.plots[plotIndex] = {
		plantId = plantId,
		plantedAt = os.time(),
		mutation = rollMutation(),
	}
	DataService.MarkDirty(player)

	local plotPart = GardenService.GetPlotPart(player, plotIndex)
	if plotPart then
		refreshPlot(player, plotIndex, plotPart)
	end

	growthUpdatedEvent:FireClient(player, { plotIndex = plotIndex, plantId = plantId, stage = 1 })

	return true
end

function PlantService.HarvestPlant(player: Player, plotIndex: number): (boolean, any)
	if type(plotIndex) ~= "number" then
		return false, "invalid_args"
	end

	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local plotData = profile.plots[plotIndex]
	if not plotData then
		return false, "plot_empty"
	end

	local plantData = PlantConfig[plotData.plantId]
	if not plantData then
		profile.plots[plotIndex] = nil
		return false, "unknown_plant"
	end

	local progress = getPlotProgress(plotData, plantData)
	if progress < 1 then
		return false, "not_mature"
	end

	local rarityMultiplier = (RarityConfig[plantData.rarity] :: any).sellMultiplier
	local mutationMultiplier = plotData.mutation and MutationConfig[plotData.mutation].valueMultiplier or 1
	local sellValue = math.floor(plantData.baseSellValue * rarityMultiplier * mutationMultiplier)

	EconomyService.AddCash(player, sellValue, "harvest")

	profile.stats.plantsHarvested += 1
	profile.plots[plotIndex] = nil
	DataService.MarkDirty(player)

	local plotPart = GardenService.GetPlotPart(player, plotIndex)
	if plotPart then
		refreshPlot(player, plotIndex, plotPart)
	end

	plantHarvestedEvent:FireClient(player, {
		plotIndex = plotIndex,
		plantId = plantData.id,
		mutation = plotData.mutation,
		cashEarned = sellValue,
	})

	return true, sellValue
end

-- ===== Ciclo de vida =====

function PlantService.Init()
	-- Cada vez que GardenService crea un plot nuevo, le añadimos su
	-- ProximityPrompt y sincronizamos el estado desde el perfil (por si
	-- el jugador ya tenía una planta creciendo de una sesión anterior).
	GardenService.PlotCreated:Connect(function(player: Player, plotIndex: number, plotPart: BasePart)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Interact"
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0.4
		prompt.RequiresLineOfSight = false
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Empty Plot"
		prompt.Parent = plotPart
		promptsByPlot[plotPart] = prompt

		prompt.Triggered:Connect(function(triggeringPlayer: Player)
			-- Solo el dueño puede plantar/cosechar su propio plot.
			-- Interactuar con el plot de OTRO jugador es la base del robo,
			-- que maneja StealService (próxima iteración), no este Service.
			if triggeringPlayer ~= player then
				return
			end

			local profile = DataService.GetProfile(player)
			if not profile then
				return
			end

			local plotData = profile.plots[plotIndex]
			if plotData then
				-- Ya hay una planta: intentamos cosechar directamente.
				PlantService.HarvestPlant(player, plotIndex)
			end
			-- Si el plot está vacío, no hacemos nada aquí: el cliente debe
			-- elegir qué semilla plantar y llamar al RemoteFunction PlantSeed
			-- explícitamente (ver Client/Controllers/PlantController.lua).
		end)

		refreshPlot(player, plotIndex, plotPart)
	end)

	-- Tick de crecimiento: redibuja fases y cuenta atrás en los prompts.
	task.spawn(function()
		local Players = game:GetService("Players")
		while true do
			task.wait(GameConfig.GrowthTickInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					for plotIndex, _ in pairs(profile.plots) do
						local plotPart = GardenService.GetPlotPart(player, plotIndex)
						if plotPart then
							refreshPlot(player, plotIndex, plotPart)
						end
					end
				end
			end
		end
	end)

	-- Tick de ingreso pasivo: las plantas maduras sin cosechar generan
	-- Cash automáticamente, para que el jugador tenga una razón para
	-- volver aunque no esté haciendo click activamente.
	task.spawn(function()
		local Players = game:GetService("Players")
		while true do
			task.wait(GameConfig.IncomeTickInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					for plotIndex, plotData in pairs(profile.plots) do
						local plantData = PlantConfig[plotData.plantId]
						if plantData then
							local progress = getPlotProgress(plotData, plantData)
							if progress >= 1 then
								EconomyService.AddCash(player, plantData.passiveIncomePerCycle, "passive_income")
							end
						end
					end
				end
			end
		end
	end)
end

return PlantService
