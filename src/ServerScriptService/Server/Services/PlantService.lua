--!strict
--[[
	PlantService.lua
	Core loop de plantar, reclamar flores individuales, colocarlas para
	generar ingresos y venderlas. El servidor autoritativo conserva los datos.

	Estado por plot, en profile.plots[plotIndex]:
		{ plantId, plantedAt, mutation, size, weight }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local PlantInstanceConfig = require(ReplicatedStorage.Shared.Config.PlantInstanceConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PlantModels = require(ReplicatedStorage.Shared.Modules.PlantModels)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local EventService = require(script.Parent.EventService)
local MonetizationService = require(script.Parent.MonetizationService)
local QuestService = require(script.Parent.QuestService)

local PlantService = {}

local growthUpdatedEvent = Net.GetRemoteEvent("PlantGrowthUpdated")
local plantedEvent = Net.GetRemoteEvent("PlantPlanted")
local plantHarvestedEvent = Net.GetRemoteEvent("PlantHarvested")

local weak = { __mode = "k" }
local plantModelsByPlot: { [BasePart]: Model } = setmetatable({}, weak) :: any
local promptsByPlot: { [BasePart]: ProximityPrompt } = setmetatable({}, weak) :: any
local labelsByPlot: { [BasePart]: TextLabel } = setmetatable({}, weak) :: any
local visualKeyByPlot: { [BasePart]: string } = setmetatable({}, weak) :: any

local floweringPlants = {
	Sunflower = true,
	EmberRose = true,
	Moonflower = true,
	CelestialOrchid = true,
	PhoenixBloom = true,
	CosmicPeony = true,
	AuroraLotus = true,
}

-- ===== Utilidades =====

local function rollMutation(player: Player): string | false
	local luck = MonetizationService.GetMutationMultiplier(player)
	local profile = DataService.GetProfile(player)
	if profile and profile.equippedGear and profile.equippedGear.MutationTotem then
		luck *= ShopConfig.Gear.MutationTotem.mutationLuck
	end
	for _, mutationId in ipairs(MutationConfig.Order) do
		local data = MutationConfig[mutationId]
		local chance = data.chance * EventService.GetMutationMultiplier(data.weatherTag) * luck
		if math.random() < chance then
			return mutationId
		end
	end
	return false
end

local function getPlotProgress(plotData: any, plantData: any): number
	local now = os.time()
	local elapsed = math.max(0, now - plotData.plantedAt) * (plotData.growthMultiplier or 1)
	elapsed += plotData.growthBonusSeconds or 0
	if plotData.boostStartedAt and plotData.boostEndsAt then
		local boostedSeconds = math.max(0, math.min(now, plotData.boostEndsAt) - plotData.boostStartedAt)
		elapsed += boostedSeconds * math.max(0, (plotData.boostMultiplier or 1) - 1)
	end
	return math.clamp(elapsed / plantData.growTimeSeconds, 0, 1)
end

local function rollSize(player: Player): string
	local weights = {}
	local totalWeight = 0
	local profile = DataService.GetProfile(player)
	local sizeLuck = profile and profile.equippedGear and profile.equippedGear.SizeTotem
		and ShopConfig.Gear.SizeTotem.sizeLuck or 1
	for _, sizeId in ipairs(PlantInstanceConfig.SizeOrder) do
		local weight = PlantInstanceConfig.Sizes[sizeId].weight
		if sizeId ~= "Normal" then
			weight *= sizeLuck
		end
		weights[sizeId] = weight
		totalWeight += weight
	end
	local roll = math.random() * totalWeight
	for _, sizeId in ipairs(PlantInstanceConfig.SizeOrder) do
		roll -= weights[sizeId]
		if roll <= 0 then
			return sizeId
		end
	end
	return "Normal"
end

local function createPlantItem(plotData: any): any?
	local plantData = PlantConfig[plotData.plantId]
	if not plantData then
		return nil
	end
	local rarity = RarityConfig[plantData.rarity]
	local mutation = plotData.mutation
	local mutationMultiplier = mutation and MutationConfig[mutation] and MutationConfig[mutation].valueMultiplier or 1
	local sizeId = plotData.size or "Normal"
	local sizeData = PlantInstanceConfig.Sizes[sizeId] or PlantInstanceConfig.Sizes.Normal
	local weight = tonumber(plotData.weight) or math.sqrt(plantData.baseSellValue) * 0.45
	local baseWeight = math.sqrt(plantData.baseSellValue) * 0.45
	local weightFactor = math.max(0.5, weight / math.max(baseWeight, 0.1))
	local value = math.max(1, math.floor(plantData.baseSellValue * rarity.sellMultiplier * mutationMultiplier * weightFactor))
	local incomePerMinute = math.max(1, math.floor(plantData.passiveIncomePerCycle * 12 * sizeData.multiplier * mutationMultiplier))
	return {
		uid = HttpService:GenerateGUID(false),
		plantId = plantData.id,
		weight = math.floor(weight * 100) / 100,
		size = sizeId,
		mutation = mutation or false,
		rarity = plantData.rarity,
		value = value,
		incomePerMinute = incomePerMinute,
		createdAt = os.time(),
	}
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
	labelsByPlot[plotPart] = nil
	visualKeyByPlot[plotPart] = nil
end

local function addCropBlock(
	model: Model,
	name: string,
	plotPosition: Vector3,
	offset: Vector3,
	size: Vector3,
	color: Color3,
	scale: number,
	material: Enum.Material?
): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Anchored = true
	block.CanCollide = false
	block.CanTouch = false
	block.CanQuery = false
	block.Material = material or Enum.Material.SmoothPlastic
	block.Color = color
	block.Size = size * scale
	block.Position = plotPosition + Vector3.new(0, 0.58, 0) + offset * scale
	block.Parent = model
	return block
end

local function addPollenEffect(adornee: BasePart, plantId: string, color: Color3)
	if not floweringPlants[plantId] then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PollenPoint"
	attachment.Parent = adornee
	local pollen = Instance.new("ParticleEmitter")
	pollen.Name = "Pollen"
	pollen.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pollen.Color = ColorSequence.new(color, Color3.fromRGB(255, 242, 190))
	pollen.Rate = 1.5
	pollen.Lifetime = NumberRange.new(1, 1.8)
	pollen.Speed = NumberRange.new(0.15, 0.45)
	pollen.SpreadAngle = Vector2.new(120, 120)
	pollen.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	pollen.LightEmission = 0.35
	pollen.Parent = attachment

	if plantId == "PhoenixBloom" or plantId == "AuroraLotus" then
		local glow = Instance.new("PointLight")
		glow.Name = "BloomGlow"
		glow.Color = color
		glow.Brightness = 0.45
		glow.Range = 7
		glow.Parent = adornee
	end
end

local function buildPlantVisual(plotPart: BasePart, plantData: any, stage: number, stageCount: number, mutation: string | false, sizeId: string?)
	clearPlantVisual(plotPart)

	local model = Instance.new("Model")
	model.Name = "PlantVisual"

	local sizeMultiplier = (PlantInstanceConfig.Sizes[sizeId or "Normal"] or PlantInstanceConfig.Sizes.Normal).visualScale
	local fruitColor = if mutation then MutationConfig[mutation].color else plantData.color
	local position = plotPart.Position

	addCropBlock(model, "TilledSoil", position, Vector3.new(0, 0, 0), Vector3.new(7.5, 0.18, 7.5), Color3.fromRGB(112, 76, 48), 1)
	for furrow = -1, 1 do
		addCropBlock(model, "SoilFurrow", position, Vector3.new(furrow * 2.2, 0.04, 0), Vector3.new(0.13, 0.04, 6.8), Color3.fromRGB(78, 53, 38), 1)
	end

	local plantId = plantData.id
	local progress = (stage - 1) / math.max(stageCount - 1, 1)
	local stem, plantHeight = PlantModels.Build(model, plantId, position + Vector3.new(0, 0.67, 0), progress, {
		fruitColor = fruitColor,
		mutated = mutation ~= false,
		scale = sizeMultiplier,
	})

	model.PrimaryPart = stem
	if stage >= stageCount then
		addPollenEffect(stem, plantId, plantData.color)
	end
	local mutationData = if mutation then MutationConfig[mutation] else nil
	if mutationData then
		local highlight = Instance.new("Highlight")
		highlight.Name = mutation .. "Aura"
		highlight.Adornee = model
		highlight.FillColor = mutationData.color
		highlight.FillTransparency = 0.84
		highlight.OutlineColor = mutationData.color
		highlight.OutlineTransparency = 0.08
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		local attachment = Instance.new("Attachment")
		attachment.Name = mutation .. "SparklePoint"
		attachment.Parent = stem
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = mutation .. "Sparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(mutationData.color)
		sparkles.Rate = if mutation == "Diamond" then 5 else 3
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(0.25, 0.7)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.55, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.LightEmission = 0.7
		sparkles.Parent = attachment

		local glow = Instance.new("PointLight")
		glow.Name = mutation .. "Glow"
		glow.Color = mutationData.color
		glow.Brightness = if mutation == "Diamond" then 0.9 else 0.45
		glow.Range = if mutation == "Diamond" then 10 else 7
		glow.Parent = stem

	end

	-- Indicador de progreso sobre la planta
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 26)
	gui.StudsOffset = Vector3.new(0, plantHeight + 1.2, 0)
	gui.MaxDistance = 60
	gui.Adornee = stem
	gui.Parent = stem

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	labelsByPlot[plotPart] = label

	model.Parent = plotPart.Parent
	plantModelsByPlot[plotPart] = model
end

local function updatePrompt(prompt: ProximityPrompt, actionText: string, objectText: string, enabled: boolean)
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.Enabled = enabled
end

local function refreshPlot(player: Player, plotIndex: number, plotPart: BasePart)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end

	local prompt = promptsByPlot[plotPart]
	local plotData = profile.plots[plotIndex]

	if not plotData then
		clearPlantVisual(plotPart)
		plotPart:SetAttribute("Stealable", false)
		if prompt then
			updatePrompt(prompt, "Plant", "Empty Plot", true)
		end
		return
	end

	local plantData = PlantConfig[plotData.plantId]
	if not plantData then
		profile.plots[plotIndex] = nil
		DataService.MarkDirty(player)
		return
	end

	local progress = getPlotProgress(plotData, plantData)
	local stage = getStageFromProgress(progress, plantData.stageCount)
	local ready = progress >= 1

	-- Solo reconstruimos la planta cuando cambia de fase (rendimiento).
	local key = plantData.id .. ":" .. stage .. ":" .. tostring(plotData.mutation) .. ":" .. tostring(plotData.size)
	if visualKeyByPlot[plotPart] ~= key then
		buildPlantVisual(plotPart, plantData, stage, plantData.stageCount, plotData.mutation, plotData.size)
		visualKeyByPlot[plotPart] = key
	end

	plotPart:SetAttribute("Stealable", ready)

	local secondsLeft = math.max(0, math.ceil(plantData.growTimeSeconds * (1 - progress)))
	local label = labelsByPlot[plotPart]
	if label then
		label.Text = if ready
			then ("✔ " .. PlantInstanceConfig.FormatName(plantData.displayName, plotData.size, plotData.mutation, plotData.weight))
			else (secondsLeft .. "s")
		label.TextColor3 = if ready then Color3.fromRGB(150, 255, 150) else Color3.fromRGB(255, 255, 255)
	end

	if prompt then
		if ready then
			local text = plantData.displayName .. (plotData.mutation and (" (" .. plotData.mutation .. ")") or "")
			updatePrompt(prompt, "Claim", text, true)
		else
			updatePrompt(prompt, "Growing...", plantData.displayName .. " (" .. secondsLeft .. "s)", false)
		end
	end
end

function PlantService.RefreshPlot(player: Player, plotIndex: number)
	local plotPart = GardenService.GetPlotPart(player, plotIndex)
	if plotPart then
		refreshPlot(player, plotIndex, plotPart)
	end
end

-- ===== API pública =====

function PlantService.PlantSeed(player: Player, plotIndex: number | Vector3, plantId: string): (boolean, string?)
	if (type(plotIndex) ~= "number" and typeof(plotIndex) ~= "Vector3") or type(plantId) ~= "string" then
		return false, "invalid_args"
	end
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end

	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local plantData = PlantConfig[plantId]
	if not plantData then
		return false, "unknown_plant"
	end
	local owned = InventoryService.GetSeedCount(player, plantId)
	if owned <= 0 then
		return false, "no_seed_in_inventory"
	end

	if typeof(plotIndex) == "Vector3" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local yardPosition = GardenService.GetYardPosition(player, plotIndex)
		if not yardPosition then
			return false, "invalid_garden_position"
		end
		if not root or (root.Position - yardPosition).Magnitude > 18 then
			return false, "too_far_from_plot"
		end
		GardenService.EnsureAvailablePlot(player)
		local placedIndex = GardenService.PlaceEmptyPlotAt(player, plotIndex)
		if not placedIndex then
			return false, "invalid_garden_position"
		end
		plotIndex = placedIndex
	else
		plotIndex = math.floor(plotIndex)
	end

	local plotPart = GardenService.GetPlotPart(player, plotIndex)
	if plotIndex < 1 or not plotPart then
		return false, "invalid_plot"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - plotPart.Position).Magnitude > 18 then
		return false, "too_far_from_plot"
	end

	if profile.plots[plotIndex] ~= nil then
		return false, "plot_occupied"
	end

	profile.inventory.seeds[plantId] = owned - 1
	if profile.inventory.seeds[plantId] <= 0 then
		profile.inventory.seeds[plantId] = nil
	end
	local sizeId = rollSize(player)
	local sizeData = PlantInstanceConfig.Sizes[sizeId]
	local baseWeight = math.sqrt(plantData.baseSellValue) * 0.45
	profile.plots[plotIndex] = {
		plantId = plantId,
		plantedAt = os.time(),
		mutation = rollMutation(player),
		size = sizeId,
		weight = baseWeight * sizeData.multiplier * (0.75 + math.random() * 0.5),
		growthMultiplier = (if profile.equippedGear and profile.equippedGear.Sprinkler then ShopConfig.Gear.Sprinkler.growthMultiplier else 1)
			* MonetizationService.GetGrowthMultiplier(player),
	}
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	QuestService.Report(player, "plant", 1)

	PlantService.RefreshPlot(player, plotIndex)
	GardenService.EnsureAvailablePlot(player)
	growthUpdatedEvent:FireClient(player, { plotIndex = plotIndex, plantId = plantId, stage = 1 })
	plantedEvent:FireClient(player, {
		plotIndex = plotIndex,
		plantId = plantId,
		position = plotPart.Position + Vector3.new(0, 0.6, 0),
	})

	return true
end

function PlantService.HarvestPlant(player: Player, plotIndex: number): (boolean, any)
	if type(plotIndex) ~= "number" then
		return false, "invalid_args"
	end
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	plotIndex = math.floor(plotIndex)

	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local plotData = profile.plots[plotIndex]
	if not plotData then
		return false, "plot_empty"
	end
	local plotPart = GardenService.GetPlotPart(player, plotIndex)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plotPart or not root or (root.Position - plotPart.Position).Magnitude > 18 then
		return false, "too_far_from_plot"
	end

	local plantData = PlantConfig[plotData.plantId]
	if not plantData then
		profile.plots[plotIndex] = nil
		return false, "unknown_plant"
	end

	if getPlotProgress(plotData, plantData) < 1 then
		return false, "not_mature"
	end

	local plantItem = createPlantItem(plotData)
	if not plantItem or not InventoryService.AddPlant(player, plantItem) then
		return false, "inventory_full"
	end
	profile.stats.plantsHarvested += 1
	profile.plots[plotIndex] = nil
	DataService.MarkDirty(player)

	PlantService.RefreshPlot(player, plotIndex)

	plantHarvestedEvent:FireClient(player, {
		plotIndex = plotIndex,
		plantId = plantData.id,
		mutation = plotData.mutation,
		plant = plantItem,
	})

	QuestService.Report(player, "harvest", 1)

	return true, plantItem
end

function PlantService.ResetPlots(player: Player)
	for plotIndex = 1, GardenService.GetCurrentPlotCount(player) do
		PlantService.RefreshPlot(player, plotIndex)
	end
	GardenService.EnsureAvailablePlot(player)
end

function PlantService.StealCrop(owner: Player, thief: Player, plotIndex: number): (boolean, any)
	local ownerProfile = DataService.GetProfile(owner)
	if not ownerProfile or not DataService.GetProfile(thief) then
		return false, "profile_missing"
	end
	local plotData = ownerProfile.plots[plotIndex]
	local plantData = plotData and PlantConfig[plotData.plantId]
	if not plotData or not plantData or getPlotProgress(plotData, plantData) < 1 then
		return false, "plant_not_ready"
	end
	local plantItem = createPlantItem(plotData)
	if not plantItem then
		return false, "inventory_full"
	end
	ownerProfile.plots[plotIndex] = nil
	ownerProfile.stats.plantsLost += 1
	DataService.MarkDirty(owner)
	PlantService.RefreshPlot(owner, plotIndex)
	return true, plantItem
end

local function isNearGarden(player: Player, garden: Model): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - garden:GetPivot().Position).Magnitude <= 100
end

local function buildCollectionPlantVisual(player: Player, plant: any, folder: Folder, slot: number)
	local plantData = PlantConfig[plant.plantId]
	if not plantData then
		return
	end
	local garden = GardenService.GetGardenModel(player)
	if not garden then
		return
	end
	local mutationData = plant.mutation and MutationConfig[plant.mutation] or nil
	local bloomColor = mutationData and mutationData.color or plantData.color
	local sizeData = PlantInstanceConfig.Sizes[plant.size] or PlantInstanceConfig.Sizes.Normal
	local scale = sizeData.visualScale
	local origin = garden:GetPivot().Position
	local savedPosition = plant.position
	local position = if type(savedPosition) == "table" and type(savedPosition.x) == "number" and type(savedPosition.z) == "number"
		then origin + Vector3.new(savedPosition.x, 0, savedPosition.z)
		else origin + Vector3.new(-5, 0, (slot - 1) * 5 - 4)

	local model = Instance.new("Model")
	model.Name = "CollectionPlant_" .. plant.uid
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("PlantUid", plant.uid)
	model.Parent = folder

	local stem, plantHeight = PlantModels.Build(model, plant.plantId, position, 1, {
		fruitColor = bloomColor,
		mutated = mutationData ~= nil,
		scale = scale * 0.75,
	})

	-- Hitbox invisible: sostiene el prompt y la etiqueta.
	local bloom = Instance.new("Part")
	bloom.Name = "Bloom"
	bloom.Anchored = true
	bloom.CanCollide = false
	bloom.CanTouch = false
	bloom.CanQuery = true
	bloom.Transparency = 1
	bloom.Size = Vector3.new(3, math.max(plantHeight, 2), 3)
	bloom.Position = position + Vector3.new(0, math.max(plantHeight, 2) / 2, 0)
	bloom.Parent = model
	model.PrimaryPart = stem
	if mutationData then
		local highlight = Instance.new("Highlight")
		highlight.Name = plant.mutation .. "Aura"
		highlight.Adornee = model
		highlight.FillColor = mutationData.color
		highlight.FillTransparency = 0.84
		highlight.OutlineColor = mutationData.color
		highlight.OutlineTransparency = 0.08
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		local attachment = Instance.new("Attachment")
		attachment.Name = plant.mutation .. "SparklePoint"
		attachment.Parent = stem
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = plant.mutation .. "Sparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(mutationData.color)
		sparkles.Rate = if plant.mutation == "Diamond" then 5 else 3
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(0.25, 0.7)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.16)
		sparkles.LightEmission = 0.7
		sparkles.Parent = attachment

		local glow = Instance.new("PointLight")
		glow.Name = plant.mutation .. "Glow"
		glow.Color = mutationData.color
		glow.Brightness = if plant.mutation == "Diamond" then 0.9 else 0.45
		glow.Range = if plant.mutation == "Diamond" then 10 else 7
		glow.Parent = stem
	end
	addPollenEffect(stem, plant.plantId, plantData.color)

	local labelGui = Instance.new("BillboardGui")
	labelGui.Size = UDim2.fromOffset(150, 42)
	labelGui.StudsOffset = Vector3.new(0, math.max(plantHeight, 2) / 2 + 1.2, 0)
	labelGui.MaxDistance = 70
	labelGui.Adornee = bloom
	labelGui.Parent = bloom
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = PlantInstanceConfig.FormatName(plantData.displayName, plant.size, plant.mutation, plant.weight) .. string.format(" · $%d/min", plant.incomePerMinute or 0)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = labelGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPlacedPlant"
	prompt.ActionText = "Collect"
	prompt.ObjectText = plantData.displayName
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = bloom
	prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer == player then
			PlantService.CollectCollectionPlant(player, plant.uid)
		end
	end)
end

local function rebuildPlacedPlants(player: Player)
	local profile = DataService.GetProfile(player)
	local garden = GardenService.GetGardenModel(player)
	if not profile or not garden then
		return
	end
	local oldFolder = garden:FindFirstChild("CollectionPlants")
	if oldFolder then
		oldFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CollectionPlants"
	folder.Parent = garden
	GardenService.ExpandGardenForPlants(player, #profile.placedPlants)
	for slot, plant in ipairs(profile.placedPlants) do
		buildCollectionPlantVisual(player, plant, folder, slot)
	end
end

function PlantService.LoadPlacedPlants(player: Player)
	rebuildPlacedPlants(player)
end

function PlantService.PlaceCollectionPlant(player: Player, plantUid: string, requestedPosition: Vector3?): (boolean, string?)
	if type(plantUid) ~= "string" or #plantUid > 64 then
		return false, "invalid_item"
	end
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	local profile = DataService.GetProfile(player)
	local garden = GardenService.GetGardenModel(player)
	if not profile or not garden then
		return false, "no_profile"
	end
	if not isNearGarden(player, garden) then
		return false, "too_far_from_garden"
	end
	local plantPosition: Vector3? = nil
	if requestedPosition ~= nil then
		if typeof(requestedPosition) ~= "Vector3" then
			return false, "invalid_position"
		end
		plantPosition = GardenService.GetYardPosition(player, requestedPosition)
		if not plantPosition then
			return false, "invalid_garden_position"
		end
		for placedIndex, placedPlant in ipairs(profile.placedPlants) do
			local existing = placedPlant.position
			local localPosition = if type(existing) == "table" and type(existing.x) == "number" and type(existing.z) == "number"
				then Vector3.new(existing.x, 0, existing.z)
				else Vector3.new(-5, 0, (placedIndex - 1) * 5 - 4)
			local worldPosition = garden:GetPivot().Position + localPosition
			if (worldPosition - plantPosition).Magnitude < 4 then
				return false, "position_occupied"
			end
		end
		for plotIndex in pairs(profile.plots) do
			local plotPart = if type(plotIndex) == "number" then GardenService.GetPlotPart(player, plotIndex) else nil
			if plotPart and (plotPart.Position - plantPosition).Magnitude < 4.5 then
				return false, "position_occupied"
			end
		end
	end
	local capacity = PlantInstanceConfig.PlaceCapacityBase
		+ (profile.rebirthCount or 0) * PlantInstanceConfig.PlaceCapacityPerRebirth
	if #profile.placedPlants >= capacity then
		return false, "plant_capacity_reached"
	end
	local index, plant = InventoryService.FindPlant(player, plantUid)
	if not index or not plant then
		return false, "plant_not_owned"
	end
	table.remove(profile.inventory.plants, index)
	if plantPosition then
		local origin = garden:GetPivot().Position
		plant.position = { x = plantPosition.X - origin.X, z = plantPosition.Z - origin.Z }
	end
	table.insert(profile.placedPlants, plant)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	rebuildPlacedPlants(player)
	return true
end

function PlantService.CollectCollectionPlant(player: Player, plantUid: string): (boolean, string?)
	if type(plantUid) ~= "string" or #plantUid > 64 then
		return false, "invalid_item"
	end
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	local profile = DataService.GetProfile(player)
	local garden = GardenService.GetGardenModel(player)
	if not profile or not garden then
		return false, "no_profile"
	end
	if not isNearGarden(player, garden) then
		return false, "too_far_from_garden"
	end
	for index, plant in ipairs(profile.placedPlants) do
		if plant.uid == plantUid then
			table.remove(profile.placedPlants, index)
			table.insert(profile.inventory.plants, plant)
			DataService.MarkDirty(player)
			InventoryService.Push(player)
			rebuildPlacedPlants(player)
			return true
		end
	end
	return false, "plant_not_placed"
end

function PlantService.SellCollectionPlant(player: Player, plantUid: string): (boolean, any)
	if type(plantUid) ~= "string" or #plantUid > 64 then
		return false, "invalid_item"
	end
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	local plant = InventoryService.RemovePlant(player, plantUid)
	if not plant then
		return false, "plant_not_owned"
	end
	local value = math.max(0, math.floor(tonumber(plant.value) or 0))
	if value <= 0 then
		InventoryService.AddPlant(player, plant)
		return false, "invalid_value"
	end
	local cashEarned = math.floor(value * MonetizationService.GetCashMultiplier(player))
	EconomyService.AddCash(player, cashEarned, "sell_plant")
	QuestService.Report(player, "earn_cash", cashEarned)
	return true, cashEarned
end

function PlantService.UseGear(player: Player, gearId: string): (boolean, any)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	local profile = DataService.GetProfile(player)
	local gear = ShopConfig.Gear[gearId]
	if not profile or not gear then
		return false, "unknown_gear"
	end
	if (profile.inventory.gear[gearId] or 0) < 1 then
		return false, "gear_not_owned"
	end

	if gear.kind == "passive" then
		profile.equippedGear = profile.equippedGear or {}
		profile.equippedGear[gearId] = not profile.equippedGear[gearId] or nil
		DataService.MarkDirty(player)
		InventoryService.Push(player)
		return true, profile.equippedGear[gearId] == true
	end

	if gearId ~= "WaterCan" then
		return false, "unsupported_gear"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "character_unavailable"
	end
	local nearestIndex: number? = nil
	local nearestDistance = 18
	for plotIndex, plotData in pairs(profile.plots) do
		if type(plotIndex) == "number" and type(plotData) == "table" then
			local plotPart = GardenService.GetPlotPart(player, plotIndex)
			local plantData = PlantConfig[plotData.plantId]
			if plotPart and plantData and getPlotProgress(plotData, plantData) < 1
				and (not plotData.boostEndsAt or plotData.boostEndsAt <= os.time()) then
				local distance = (root.Position - plotPart.Position).Magnitude
				if distance < nearestDistance then
					nearestIndex = plotIndex
					nearestDistance = distance
				end
			end
		end
	end
	if not nearestIndex then
		return false, "no_growing_crop_nearby"
	end
	local plotData = profile.plots[nearestIndex]
	if plotData.boostStartedAt and plotData.boostEndsAt then
		local previousBoostSeconds = math.max(0, plotData.boostEndsAt - plotData.boostStartedAt)
		plotData.growthBonusSeconds = (plotData.growthBonusSeconds or 0)
			+ previousBoostSeconds * math.max(0, (plotData.boostMultiplier or 1) - 1)
	end
	plotData.boostStartedAt = os.time()
	plotData.boostEndsAt = os.time() + 20
	plotData.boostMultiplier = 5
	profile.inventory.gear[gearId] -= 1
	if profile.inventory.gear[gearId] <= 0 then
		profile.inventory.gear[gearId] = nil
	end
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	PlantService.RefreshPlot(player, nearestIndex)
	return true, "used"
end

-- ===== Ciclo de vida =====

function PlantService.Init()
	GardenService.PlotCreated:Connect(function(player: Player, plotIndex: number, plotPart: BasePart)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Interact"
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0.4
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.ActionText = "Plant"
		prompt.ObjectText = "Empty Plot"
		prompt.Parent = plotPart
		promptsByPlot[plotPart] = prompt

		prompt.Triggered:Connect(function(triggeringPlayer: Player)
			-- Solo el dueño planta/cosecha su plot. El robo lo gestiona StealService.
			if triggeringPlayer ~= player then
				return
			end
			local profile = DataService.GetProfile(player)
			if profile and profile.plots[plotIndex] then
				PlantService.HarvestPlant(player, plotIndex)
			end
			-- Plot vacío: el cliente abre el selector y llama a PlantSeed.
		end)

		refreshPlot(player, plotIndex, plotPart)
	end)

	-- Tick de crecimiento: actualiza fases, contadores y prompts.
	task.spawn(function()
		while true do
			task.wait(GameConfig.GrowthTickInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					for plotIndex in pairs(profile.plots) do
						PlantService.RefreshPlot(player, plotIndex)
					end
				end
			end
		end
	end)

	-- Ingreso pasivo de plantas maduras sin cosechar.
	task.spawn(function()
		while true do
			task.wait(GameConfig.IncomeTickInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					local total = 0
					for _, plant in ipairs(profile.placedPlants or {}) do
						total += math.max(0, math.floor(tonumber(plant.incomePerMinute) or 0))
					end
					if total > 0 then
						EconomyService.AddCash(player, total * MonetizationService.GetCashMultiplier(player), "plant_income")
					end
				end
			end
		end
	end)
end

return PlantService
