--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)
local PlantInstanceConfig = require(ReplicatedStorage.Shared.Config.PlantInstanceConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local UI = require(script.Parent.Parent.UI)
local ClientState = require(script.Parent.Parent.ClientState)
local PlantController = require(script.Parent.PlantController)
local FarmArt = require(script.Parent.Parent.Modules.FarmArt)
local EffectsController = require(script.Parent.EffectsController)

local InventoryController = {}
local player = Players.LocalPlayer
local listFrame: ScrollingFrame
local hud: any
local stats: any = nil
local activeTab = "Semillas"
local sortMode = "Weight"
local searchQuery = ""
local rarityFilter = "Todas"
local mutationFilter = "Todas"
local pendingPlantPlacementUid: string? = nil
local incubatorUnlocked = false
local giftFrame: Frame?
local giftList: ScrollingFrame?
local render: () -> ()
local refresh: () -> ()

local snapshotFn = Net.GetRemoteFunction("GetPlayerProfileSnapshot")
local giftFn = Net.GetRemoteFunction("GiftItem")
local openPackFn = Net.GetRemoteFunction("OpenSeedPack")
local openPetEggFn = Net.GetRemoteFunction("OpenPetEgg")
local unlockIncubatorFn = Net.GetRemoteFunction("UnlockIncubator")
local equipPetFn = Net.GetRemoteFunction("EquipPet")
local useGearFn = Net.GetRemoteFunction("UseGear")
local placePlantFn = Net.GetRemoteFunction("PlaceCollectionPlant")
local collectPlantFn = Net.GetRemoteFunction("CollectCollectionPlant")
local sellPlantFn = Net.GetRemoteFunction("SellCollectionPlant")

local tabs = { "Semillas", "Plantas", "Gear", "Mascotas" }
local sortModes = {
	{ id = "Weight", label = "Peso" },
	{ id = "Rarity", label = "Rareza" },
	{ id = "Mutation", label = "Mutación" },
	{ id = "Value", label = "Valor" },
}
local rarityFilters = { "Todas", table.unpack(RarityConfig.Order) }

local function matchesSearch(...: string?): boolean
	if searchQuery == "" then
		return true
	end
	local query = string.lower(searchQuery)
	for _, value in ipairs({ ... }) do
		if value and string.find(string.lower(tostring(value)), query, 1, true) then
			return true
		end
	end
	return false
end

local function closeGiftPanel()
	if giftFrame then
		giftFrame.Visible = false
	end
end

local function openGiftPanel(itemId: string, itemKind: string, displayName: string)
	if not giftFrame then
		giftFrame = Instance.new("Frame")
		giftFrame.Name = "GiftPanel"
		giftFrame.Visible = false
		giftFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		giftFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		giftFrame.Size = UDim2.new(0.82, 0, 0.62, 0)
		giftFrame.BackgroundColor3 = UI.Colors.Panel
		giftFrame.BorderSizePixel = 4
		giftFrame.BorderColor3 = UI.Colors.Gold
		giftFrame.ZIndex = 20
		giftFrame.Parent = hud.GetScreenGui()
		UI.Round(giftFrame, 18)

		local title = UI.Label(giftFrame, "Regalar " .. displayName, UDim2.new(1, -70, 0, 34), UDim2.new(0, 16, 0, 10), Color3.fromRGB(255, 243, 204), true)
		title.ZIndex = 21
		local close = UI.Button(giftFrame, "X", UI.Colors.Grey, UDim2.new(0, 36, 0, 36), UDim2.new(1, -48, 0, 10))
		close.ZIndex = 21
		close.Activated:Connect(closeGiftPanel)

		giftList = Instance.new("ScrollingFrame")
		giftList.Name = "GiftList"
		giftList.BackgroundTransparency = 1
		giftList.Position = UDim2.new(0, 12, 0, 54)
		giftList.Size = UDim2.new(1, -24, 1, -66)
		giftList.AutomaticCanvasSize = Enum.AutomaticSize.Y
		giftList.CanvasSize = UDim2.new(0, 0, 0, 0)
		giftList.ScrollBarThickness = 6
		giftList.ZIndex = 21
		giftList.Parent = giftFrame
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = giftList
	end

	local currentList = giftList
	if not currentList or not giftFrame then
		return
	end
	for _, child in ipairs(currentList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local others = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			table.insert(others, other)
		end
	end
	if #others == 0 then
		local label = UI.Label(currentList, "No hay jugadores conectados para regalar.", UDim2.new(1, -16, 0, 38), UDim2.new(0, 8, 0, 8), UI.Colors.Muted, false)
		label.ZIndex = 22
		giftFrame.Visible = true
		return
	end

	for _, other in ipairs(others) do
		local row = UI.Button(currentList, other.DisplayName .. " (" .. other.Name .. ")", UI.Colors.Green, UDim2.new(1, -8, 0, 46), UDim2.new(0, 4, 0, 0))
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextSize = 14
		row.ZIndex = 22
		row.Activated:Connect(function()
			local result = giftFn:InvokeServer(other.Name, itemId, 1, itemKind)
			if result and result.success then
				hud.Push("Regalo enviado a " .. other.DisplayName, "good")
			else
				hud.Push("No se pudo regalar: " .. tostring(result and result.reason or "error"), "warn")
			end
			closeGiftPanel()
			task.defer(function()
				if hud.IsPanelOpen("Bag") then
					refresh()
				end
			end)
		end)
	end
	giftFrame.Visible = true
end

local function setPlacementContextEnabled(enabled: boolean)
	local inputs = ReplicatedStorage:FindFirstChild("Inputs")
	local context = inputs and inputs:FindFirstChild("PlacementContext")
	if context and context:IsA("InputContext") then
		context.Enabled = enabled
	end
end

local PLACE_REASONS: { [string]: string } = {
	invalid_garden_position = "Toca dentro de la zona verde de TU jardín.",
	invalid_position = "Posición no válida, prueba otro punto.",
	position_occupied = "Ahí ya hay una planta o un bancal. Elige un hueco libre.",
	plant_capacity_reached = "Tu jardín no admite más flores colocadas (más espacio con Rebirth). Vende o recoge alguna.",
	too_far_from_garden = "Acércate a tu jardín para colocarla.",
	carrying_stolen_plant = "Primero lleva a tu jardín la planta robada.",
	plant_not_owned = "Esa planta ya no está en tu inventario.",
	no_profile = "Tus datos aún se están cargando, espera un momento.",
}

local placementZone: Part? = nil
local placementGhost: Part? = nil
local placementConn: RBXScriptConnection? = nil

local function getYardFloor(): BasePart?
	local gardens = workspace:FindFirstChild("Gardens")
	local garden = gardens and gardens:FindFirstChild("Garden_" .. player.UserId)
	local boundary = garden and garden:FindFirstChild("YardBoundary")
	local floor = boundary and boundary:FindFirstChild("GardenFloor")
	if floor and floor:IsA("BasePart") then
		return floor
	end
	return nil
end

local function isInsideYard(floor: BasePart, position: Vector3): boolean
	local localPosition = floor.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= floor.Size.X / 2 - GardenConfig.PlacementMargin
		and math.abs(localPosition.Z) <= floor.Size.Z / 2 - GardenConfig.PlacementMargin
end

local function stopPlacementPreview()
	if placementConn then
		placementConn:Disconnect()
		placementConn = nil
	end
	if placementZone then
		placementZone:Destroy()
		placementZone = nil
	end
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

local function newPreviewPart(name: string, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	return part
end

-- Zona verde sobre el suelo válido + marcador que sigue al cursor (ratón).
local function startPlacementPreview()
	stopPlacementPreview()
	local floor = getYardFloor()
	if not floor then
		return
	end
	local margin = GardenConfig.PlacementMargin
	local zone = newPreviewPart("PlacementZone", Color3.fromRGB(110, 230, 120), 0.7)
	zone.Size = Vector3.new(floor.Size.X - margin * 2, 0.1, floor.Size.Z - margin * 2)
	zone.CFrame = floor.CFrame * CFrame.new(0, 0, 0)
	zone.Position = Vector3.new(zone.Position.X, 0.32, zone.Position.Z)
	zone.Parent = workspace
	placementZone = zone

	local ghost = newPreviewPart("PlacementGhost", Color3.fromRGB(110, 230, 120), 0.35)
	ghost.Size = Vector3.new(3, 0.3, 3)
	ghost.Parent = workspace
	placementGhost = ghost

	placementConn = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not UserInputService.MouseEnabled then
			ghost.Transparency = 1
			return
		end
		local pointer = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 512, params)
		if not hit then
			ghost.Transparency = 1
			return
		end
		ghost.Transparency = 0.35
		ghost.Color = if isInsideYard(floor, hit.Position) then Color3.fromRGB(110, 230, 120) else Color3.fromRGB(235, 90, 80)
		ghost.Position = Vector3.new(hit.Position.X, 0.45, hit.Position.Z)
	end)
end

function InventoryController.ToggleBag()
	if hud then
		hud.TogglePanel("Bag")
	end
end

function InventoryController.CancelPlacement()
	if not pendingPlantPlacementUid then
		return
	end
	pendingPlantPlacementUid = nil
	setPlacementContextEnabled(false)
	stopPlacementPreview()
	PlantController.RestoreSlapTool()
	hud.Push("Colocación cancelada", "warn")
end

function InventoryController.ConfirmPlacement(screenPosition: Vector2)
	if not pendingPlantPlacementUid then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		hud.Push("No se pudo encontrar la cámara para colocar la flor.", "warn")
		return
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 512, params)
	if not hit then
		hud.Push("Elige un punto visible dentro de tu jardín.", "warn")
		return
	end

	local floor = getYardFloor()
	if floor and not isInsideYard(floor, hit.Position) then
		hud.Push(PLACE_REASONS.invalid_garden_position, "warn")
		return
	end

	local result = placePlantFn:InvokeServer(pendingPlantPlacementUid, hit.Position)
	if result and result.success then
		pendingPlantPlacementUid = nil
		setPlacementContextEnabled(false)
		stopPlacementPreview()
		PlantController.RestoreSlapTool()
		hud.Push("Flor colocada en tu jardín", "good")
	else
		local reason = tostring(result and result.reason or "error")
		-- La colocación sigue activa: el jugador puede probar otro punto.
		hud.Push(PLACE_REASONS[reason] or ("No se pudo colocar: " .. reason), "warn")
	end
end

local function makeTabBar()
	local card = UI.Card(listFrame, 42, -100)
	for index, tab in ipairs(tabs) do
		local width = 1 / #tabs
		local button = UI.Button(
			card,
			tab,
			if activeTab == tab then UI.Colors.Green else UI.Colors.Grey,
			UDim2.new(width, -6, 0, 32),
			UDim2.new((index - 1) * width, 3, 0, 5)
		)
		button.TextSize = 12
		button.Activated:Connect(function()
			activeTab = tab
			render()
		end)
	end
end

local function makeSearchBar()
	local card = UI.Card(listFrame, 42, -90)
	local search = Instance.new("TextBox")
	search.Name = "InventorySearch"
	search.Size = UDim2.new(1, -14, 1, -10)
	search.Position = UDim2.fromOffset(7, 5)
	search.ZIndex = card.ZIndex + 1
	search.BackgroundColor3 = Color3.fromRGB(247, 235, 201)
	search.BorderSizePixel = 2
	search.BorderColor3 = Color3.fromRGB(112, 78, 43)
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Buscar en esta sección..."
	search.PlaceholderColor3 = UI.Colors.Muted
	search.Text = searchQuery
	search.TextColor3 = UI.Colors.Text
	search.Font = Enum.Font.Gotham
	search.TextSize = 16
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = card
	search.FocusLost:Connect(function()
		searchQuery = search.Text
		render()
	end)
end

local function addSeedRows(order: number)
	local seedPacks = ClientState.Inventory.seedPacks or {}
	local hasPack = false
	local hasVisiblePack = false
	for packId, count in pairs(seedPacks) do
		if count > 0 then
			hasPack = true
			local pack = ShopConfig.Packs[packId]
			local packName = pack and pack.displayName or (packId .. " Seed Pack")
			if matchesSearch(packName, packId) then
				hasVisiblePack = true
				order += 1
				local card = UI.Card(listFrame, 66, order)
				local packIcon = FarmArt.CreateSeedPackIcon(card, RarityConfig[pack and pack.rarity or "Common"].color)
				packIcon.Position = UDim2.fromOffset(8, 5)
				UI.Label(card, packName .. "  x" .. count, UDim2.new(1, -170, 0, 25), UDim2.new(0, 68, 0, 6))
				UI.Label(card, "Abre semillas aleatorias", UDim2.new(1, -170, 0, 18), UDim2.new(0, 68, 0, 36), UI.Colors.Muted, false)
				local openButton = UI.Button(card, "Abrir", UI.Colors.Green, UDim2.new(0, 74, 0, 38), UDim2.new(1, -84, 0.5, -19))
				openButton.Activated:Connect(function()
					openButton.Active = false
					local result = openPackFn:InvokeServer(packId)
					openButton.Active = true
					if result and result.success then
						local names = {}
						for plantId, amount in pairs(result.seeds) do
							table.insert(names, PlantConfig[plantId].displayName .. " x" .. amount)
						end
						table.sort(names)
						hud.Push("Pack abierto: " .. table.concat(names, ", "), "good")
					else
						hud.Push("No se pudo abrir: " .. tostring(result and result.reason or "error"), "warn")
					end
				end)
			end
		end
	end

	local ids = {}
	for plantId, count in pairs(ClientState.Inventory.seeds or {}) do
		if count > 0 and PlantConfig[plantId] and matchesSearch(PlantConfig[plantId].displayName, plantId) then
			table.insert(ids, plantId)
		end
	end
	table.sort(ids, function(a, b)
		local rarityA = RarityConfig[PlantConfig[a].rarity].order
		local rarityB = RarityConfig[PlantConfig[b].rarity].order
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		return PlantConfig[a].displayName < PlantConfig[b].displayName
	end)
	if #ids == 0 and not hasVisiblePack then
		order += 1
		local card = UI.Card(listFrame, 58, order)
		local message = if searchQuery ~= "" and (hasPack or next(ClientState.Inventory.seeds or {}) ~= nil)
			then "No hay resultados para esa búsqueda."
			else "No tienes semillas. Visita la tienda para conseguir un pack."
		UI.Label(card, message, UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
	end

	for _, plantId in ipairs(ids) do
		order += 1
		local data = PlantConfig[plantId]
		local rarity = RarityConfig[data.rarity]
		local card = UI.Card(listFrame, 68, order)
		local cropIcon = FarmArt.CreateCropIcon(card, plantId, data.color)
		cropIcon.Position = UDim2.fromOffset(8, 6)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 5, 1, 0)
		stripe.BackgroundColor3 = rarity.color
		stripe.BorderSizePixel = 0
		stripe.Parent = card
		UI.Round(stripe, 8)
		UI.Label(card, data.displayName .. " Seeds  x" .. ClientState.Inventory.seeds[plantId], UDim2.new(1, -240, 0, 24), UDim2.new(0, 68, 0, 6))
		UI.Label(card, rarity.displayName .. " · " .. data.growTimeSeconds .. "s to grow", UDim2.new(1, -240, 0, 18), UDim2.new(0, 68, 0, 35), rarity.color, false)
		local holdButton = UI.Button(card, "Usar", UI.Colors.Blue, UDim2.new(0, 62, 0, 30), UDim2.new(1, -138, 0.5, -15))
		holdButton.Activated:Connect(function()
			if PlantController.EquipSeed(plantId) then
				hud.Push("Semilla en mano: toca una parcela para plantar.", "good")
			else
				hud.Push("No tienes esas semillas", "warn")
			end
		end)
		local giftButton = UI.Button(card, "Regalar", UI.Colors.Grey, UDim2.new(0, 62, 0, 30), UDim2.new(1, -68, 0.5, -15))
		giftButton.Activated:Connect(function()
			openGiftPanel(plantId, "seed", data.displayName .. " Seeds")
		end)
	end
end

local function comparePlants(a: any, b: any): boolean
	if sortMode == "Weight" then
		return (a.weight or 0) > (b.weight or 0)
	elseif sortMode == "Rarity" then
		local rankA = RarityConfig[a.rarity or PlantConfig[a.plantId].rarity].order
		local rankB = RarityConfig[b.rarity or PlantConfig[b.plantId].rarity].order
		if rankA ~= rankB then
			return rankA > rankB
		end
	elseif sortMode == "Mutation" then
		local valueA = a.mutation and a.mutation ~= false and a.mutation ~= "" and 1 or 0
		local valueB = b.mutation and b.mutation ~= false and b.mutation ~= "" and 1 or 0
		if valueA ~= valueB then
			return valueA > valueB
		end
		if valueA == 1 and a.mutation ~= b.mutation then
			return tostring(a.mutation) > tostring(b.mutation)
		end
	elseif sortMode == "Value" then
		return (a.value or 0) > (b.value or 0)
	end
	return tostring(a.uid) < tostring(b.uid)
end

local function makePlantSortBar(order: number): number
	order += 1
	local card = UI.Card(listFrame, 40, order)
	for index, mode in ipairs(sortModes) do
		local width = 1 / #sortModes
		local button = UI.Button(
			card,
			mode.label,
			if sortMode == mode.id then UI.Colors.Blue else UI.Colors.Grey,
			UDim2.new(width, -6, 0, 30),
			UDim2.new((index - 1) * width, 3, 0, 5)
		)
		button.TextSize = 11
		button.Activated:Connect(function()
			sortMode = mode.id
			render()
		end)
	end
	return order
end

local function makePlantFilterBar(order: number): number
	order += 1
	local card = UI.Card(listFrame, 42, order)
	local rarityName = if rarityFilter == "Todas" then "Todas" else RarityConfig[rarityFilter].displayName
	local rarityButton = UI.Button(
		card,
		"Rareza: " .. rarityName,
		UI.Colors.Grey,
		UDim2.new(0.52, -7, 0, 32),
		UDim2.new(0, 3, 0, 5)
	)
	rarityButton.TextSize = 11
	rarityButton.Activated:Connect(function()
		local currentIndex = table.find(rarityFilters, rarityFilter) or 1
		rarityFilter = rarityFilters[currentIndex % #rarityFilters + 1]
		render()
	end)

	local mutationButton = UI.Button(
		card,
		"Mutación: " .. mutationFilter,
		UI.Colors.Grey,
		UDim2.new(0.48, -7, 0, 32),
		UDim2.new(0.52, 4, 0, 5)
	)
	mutationButton.TextSize = 11
	mutationButton.Activated:Connect(function()
		if mutationFilter == "Todas" then
			mutationFilter = "Con mutación"
		elseif mutationFilter == "Con mutación" then
			mutationFilter = "Sin mutación"
		else
			mutationFilter = "Todas"
		end
		render()
	end)
	return order
end

local function addPlantRows(order: number)
	order = makePlantFilterBar(order)
	order = makePlantSortBar(order)
	local plants = {}
	for _, plant in ipairs(ClientState.Inventory.plants or {}) do
		local data = PlantConfig[plant.plantId]
		local rarity = plant.rarity or (data and data.rarity)
		local hasMutation = plant.mutation ~= nil and plant.mutation ~= false and plant.mutation ~= ""
		local matchesRarity = rarityFilter == "Todas" or rarity == rarityFilter
		local matchesMutation = mutationFilter == "Todas"
			or (mutationFilter == "Con mutación" and hasMutation)
			or (mutationFilter == "Sin mutación" and not hasMutation)
		if data and matchesRarity and matchesMutation and matchesSearch(data.displayName, plant.plantId, plant.mutation) then
			table.insert(plants, plant)
		end
	end
	table.sort(plants, comparePlants)
	local placedPlants = {}
	for _, plant in ipairs(ClientState.PlacedPlants) do
		local data = PlantConfig[plant.plantId]
		local rarity = plant.rarity or (data and data.rarity)
		local hasMutation = plant.mutation ~= nil and plant.mutation ~= false and plant.mutation ~= ""
		local matchesMutation = mutationFilter == "Todas"
			or (mutationFilter == "Con mutación" and hasMutation)
			or (mutationFilter == "Sin mutación" and not hasMutation)
		if data and (rarityFilter == "Todas" or rarity == rarityFilter)
			and matchesMutation and matchesSearch(data.displayName, plant.plantId, plant.mutation) then
			table.insert(placedPlants, plant)
		end
	end
	if #plants == 0 and #placedPlants == 0 then
		order += 1
		local card = UI.Card(listFrame, 58, order)
		local message = if #(ClientState.Inventory.plants or {}) > 0 or #ClientState.PlacedPlants > 0
			then "No hay flores que coincidan con estos filtros."
			else "Reclama un cultivo maduro para añadir una flor a tu colección."
		UI.Label(card, message, UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
	end

	for _, plant in ipairs(plants) do
		local data = PlantConfig[plant.plantId]
		if data then
			order += 1
			local rarity = RarityConfig[plant.rarity or data.rarity]
			local card = UI.Card(listFrame, 94, order)
			local cropIcon = FarmArt.CreateCropIcon(card, plant.plantId, data.color)
			cropIcon.Position = UDim2.fromOffset(8, 6)
			local title = UI.Label(card, PlantInstanceConfig.FormatName(data.displayName, plant.size, plant.mutation, plant.weight), UDim2.new(1, -82, 0, 24), UDim2.new(0, 68, 0, 5), rarity.color)
			title.TextTruncate = Enum.TextTruncate.AtEnd
			UI.Label(
				card,
				string.format("%s · Sell $%s · $%s/min", rarity.displayName, UI.Money(plant.value or 0), UI.Money(plant.incomePerMinute or 0)),
				UDim2.new(1, -82, 0, 18),
				UDim2.new(0, 68, 0, 30),
				UI.Colors.Muted,
				false
			)

			local actionButton = UI.Button(card, "Colocar", UI.Colors.Green, UDim2.new(0, 68, 0, 28), UDim2.new(0, 68, 1, -34))
			actionButton.TextSize = 11
			actionButton.Activated:Connect(function()
				pendingPlantPlacementUid = plant.uid
				PlantController.ClearSeedTools(false)
				setPlacementContextEnabled(true)
				startPlacementPreview()
				hud.TogglePanel("Bag")
				hud.Push("Toca la zona verde de tu jardín para colocarla. Esc para cancelar.", "good")
			end)

			local sellButton = UI.Button(card, "Vender", Color3.fromRGB(174, 116, 50), UDim2.new(0, 58, 0, 28), UDim2.new(0, 142, 1, -34))
			sellButton.TextSize = 11
			sellButton.Activated:Connect(function()
				local result = sellPlantFn:InvokeServer(plant.uid)
				if result and result.success then
					hud.Push("Vendiste por $" .. UI.Money(result.cashEarned), "good")
				else
					hud.Push("No se pudo vender: " .. tostring(result and result.reason or "error"), "warn")
				end
			end)

			local giftButton = UI.Button(card, "Regalar", UI.Colors.Grey, UDim2.new(0, 58, 0, 28), UDim2.new(0, 206, 1, -34))
			giftButton.TextSize = 11
			giftButton.Activated:Connect(function()
				openGiftPanel(plant.uid, "plant", data.displayName)
			end)
		end
	end

	for _, plant in ipairs(placedPlants) do
		local data = PlantConfig[plant.plantId]
		if data then
			order += 1
			local rarity = RarityConfig[plant.rarity or data.rarity]
			local card = UI.Card(listFrame, 66, order)
			local cropIcon = FarmArt.CreateCropIcon(card, plant.plantId, data.color)
			cropIcon.Position = UDim2.fromOffset(8, 5)
			local placedTitle = UI.Label(card, PlantInstanceConfig.FormatName(data.displayName, plant.size, plant.mutation, plant.weight), UDim2.new(1, -164, 0, 24), UDim2.new(0, 68, 0, 6), rarity.color)
			placedTitle.TextTruncate = Enum.TextTruncate.AtEnd
			UI.Label(card, "$" .. UI.Money(plant.incomePerMinute or 0) .. " por minuto", UDim2.new(1, -164, 0, 18), UDim2.new(0, 68, 0, 34), UI.Colors.Muted, false)
			local collectButton = UI.Button(card, "Recoger", UI.Colors.Blue, UDim2.new(0, 72, 0, 34), UDim2.new(1, -82, 0.5, -17))
			collectButton.Activated:Connect(function()
				local result = collectPlantFn:InvokeServer(plant.uid)
				if result and result.success then
					hud.Push("La flor volvió a tu colección", "good")
				else
					hud.Push("No se pudo recoger: " .. tostring(result and result.reason or "error"), "warn")
				end
			end)
		end
	end
end

local function addGearRows(order: number)
	local gearCounts = ClientState.Inventory.gear or {}
	local gearIds = {}
	for gearId, count in pairs(gearCounts) do
		local gear = ShopConfig.Gear[gearId]
		if count > 0 and gear and matchesSearch(gear.displayName, gear.description, gearId) then
			table.insert(gearIds, gearId)
		end
	end
	table.sort(gearIds)
	if #gearIds == 0 then
		order += 1
		local card = UI.Card(listFrame, 58, order)
		local message = if searchQuery ~= "" then "No hay herramientas que coincidan con la búsqueda." else "Compra una regadera, aspersor o tótem en la tienda."
		UI.Label(card, message, UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
	end
	for _, gearId in ipairs(gearIds) do
		order += 1
		local gear = ShopConfig.Gear[gearId]
		local card = UI.Card(listFrame, 74, order)
		local gearIcon = FarmArt.CreateGearIcon(card, gearId, RarityConfig[gear.rarity].color)
		gearIcon.Position = UDim2.fromOffset(8, 9)
		UI.Label(card, gear.displayName .. "  x" .. gearCounts[gearId], UDim2.new(1, -182, 0, 24), UDim2.new(0, 68, 0, 5))
		UI.Label(card, gear.description, UDim2.new(1, -182, 0, 34), UDim2.new(0, 68, 0, 31), UI.Colors.Muted, false)
		local equipped = ClientState.EquippedGear[gearId] == true
		local button = UI.Button(card, if gear.kind == "passive" then (if equipped then "Quitar" else "Equipar") else "Usar", UI.Colors.Blue, UDim2.new(0, 92, 0, 38), UDim2.new(1, -102, 0.5, -19))
		button.TextSize = 11
		button.Activated:Connect(function()
			local result = useGearFn:InvokeServer(gearId)
			if result and result.success then
				hud.Push(gear.kind == "passive" and (result.equipped and "Gear equipado" or "Gear retirado") or "Regadera usada en la planta más cercana", "good")
			else
				hud.Push("No se pudo usar: " .. tostring(result and result.reason or "error"), "warn")
			end
		end)
	end
end

local function addPetRows(order: number)
	if not incubatorUnlocked then
		order += 1
		local card = UI.Card(listFrame, 72, order)
		UI.Label(card, "Incubadora de jardín · $1,000", UDim2.new(1, -130, 0, 25), UDim2.new(0, 12, 0, 8), UI.Colors.Gold)
		UI.Label(card, "Desbloquéala para incubar tus huevos.", UDim2.new(1, -130, 0, 22), UDim2.new(0, 12, 0, 37), UI.Colors.Muted, false)
		local unlockButton = UI.Button(card, "Desbloquear", UI.Colors.Green, UDim2.new(0, 112, 0, 38), UDim2.new(1, -122, 0.5, -19))
		unlockButton.TextSize = 11
		unlockButton.Activated:Connect(function()
			local result = unlockIncubatorFn:InvokeServer()
			if result and result.success then
				incubatorUnlocked = true
				hud.Push("Incubadora desbloqueada en tu jardín", "good")
				refresh()
			else
				hud.Push("No se pudo desbloquear: " .. tostring(result and result.reason or "error"), "warn")
			end
		end)
	end

	local eggs = ClientState.Inventory.petEggs or {}
	local eggRarities = {}
	for rarity, count in pairs(eggs) do
		local egg = ShopConfig.PetEggs[rarity]
		if count > 0 and egg and matchesSearch(egg.displayName, rarity) then
			table.insert(eggRarities, rarity)
		end
	end
	table.sort(eggRarities, function(a, b)
		return RarityConfig[a].order > RarityConfig[b].order
	end)

	for _, rarityId in ipairs(eggRarities) do
		order += 1
		local rarity = RarityConfig[rarityId]
		local egg = ShopConfig.PetEggs[rarityId]
		local card = UI.Card(listFrame, 72, order)
		local eggIcon = FarmArt.CreateEggIcon(card, rarity.color)
		eggIcon.Position = UDim2.fromOffset(8, 8)
		UI.Label(card, egg.displayName .. "  x" .. eggs[rarityId], UDim2.new(1, -180, 0, 24), UDim2.new(0, 68, 0, 5), rarity.color)
		UI.Label(card, "5 mascotas posibles · 1 de cada 5", UDim2.new(1, -180, 0, 20), UDim2.new(0, 68, 0, 34), UI.Colors.Muted, false)
		local openButton = UI.Button(card, "Incubar", UI.Colors.Gold, UDim2.new(0, 90, 0, 38), UDim2.new(1, -100, 0.5, -19))
		openButton.TextSize = 12
		openButton.Active = incubatorUnlocked
		if not incubatorUnlocked then
			openButton.Text = "Bloqueado"
		end
		openButton.Activated:Connect(function()
			if not incubatorUnlocked then
				hud.Push("Desbloquea primero la incubadora de tu jardín por $1,000", "warn")
				return
			end
			openButton.Active = false
			-- Animación de incubación mientras el servidor decide la mascota.
			local result = EffectsController.HatchEgg(rarityId, function()
				return openPetEggFn:InvokeServer(rarityId)
			end)
			openButton.Active = true
			if result and result.success then
				hud.Push("¡Nueva mascota: " .. result.displayName .. "!", "good")
				task.defer(refresh)
			else
				hud.Push("No se pudo incubar: " .. tostring(result and result.reason or "error"), "warn")
			end
		end)
	end

	local pets = {}
	for _, petId in ipairs(ClientState.Inventory.pets or {}) do
		local pet = PetConfig.Pets[petId]
		if matchesSearch(pet and pet.displayName, petId) then
			table.insert(pets, petId)
		end
	end
	if #pets == 0 and #eggRarities == 0 then
		order += 1
		local card = UI.Card(listFrame, 58, order)
		local message = if searchQuery ~= "" then "No hay huevos ni mascotas que coincidan con la búsqueda." else "Consigue un huevo en la tienda para incubar tu primera mascota."
		UI.Label(card, message, UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
	end

	for _, petId in ipairs(pets) do
		local pet = PetConfig.Pets[petId]
		order += 1
		local card = UI.Card(listFrame, 66, order)
		local rarity = pet and RarityConfig[pet.rarity]
		if pet then
			local petIcon = FarmArt.CreatePetIcon(card, pet)
			petIcon.Position = UDim2.fromOffset(8, 5)
		end
		UI.Label(card, pet and pet.displayName or tostring(petId), UDim2.new(1, -184, 0, 24), UDim2.new(0, 68, 0, 5), rarity and rarity.color or UI.Colors.Text)
		UI.Label(
			card,
			rarity and (rarity.displayName .. " · " .. PetConfig.Describe(petId)) or "Mascota",
			UDim2.new(1, -184, 0, 28),
			UDim2.new(0, 68, 0, 31),
			UI.Colors.Muted,
			false
		).TextWrapped = true
		local equipped = ClientState.Inventory.equippedPet == petId
		local equipButton = UI.Button(
			card,
			if equipped then "Activa" else "Equipar",
			if equipped then UI.Colors.Green else UI.Colors.Blue,
			UDim2.new(0, 88, 0, 36),
			UDim2.new(1, -98, 0.5, -18)
		)
		equipButton.TextSize = 11
		equipButton.Active = not equipped
		equipButton.Activated:Connect(function()
			local result = equipPetFn:InvokeServer(petId)
			if result and result.success then
				hud.Push("Mascota equipada", "good")
				task.defer(refresh)
			else
				hud.Push("No se pudo equipar: " .. tostring(result and result.reason or "error"), "warn")
			end
		end)
	end
end

render = function()
	if not listFrame then
		return
	end
	UI.ClearList(listFrame)
	makeTabBar()
	makeSearchBar()
	local order = 0
	if stats then
		order += 1
		local card = UI.Card(listFrame, 40, order)
		UI.Label(
			card,
			string.format("Claimed %d · Stolen %d · Lost %d", stats.plantsHarvested, stats.plantsStolen, stats.plantsLost),
			UDim2.new(1, -16, 1, -10),
			UDim2.new(0, 8, 0, 5),
			UI.Colors.Muted,
			false
		)
	end
	if activeTab == "Semillas" then
		addSeedRows(order)
	elseif activeTab == "Plantas" then
		addPlantRows(order)
	elseif activeTab == "Gear" then
		addGearRows(order)
	elseif activeTab == "Mascotas" then
		addPetRows(order)
	end
end

refresh = function()
	local snapshot = snapshotFn:InvokeServer()
	if snapshot and snapshot.success then
		ClientState.SetInventoryFromSnapshot(snapshot.inventory)
		ClientState.PlacedPlants = snapshot.placedPlants or {}
		ClientState.EquippedGear = snapshot.equippedGear or {}
		incubatorUnlocked = snapshot.incubatorUnlocked == true
		stats = snapshot.stats
	end
	render()
end

function InventoryController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Bag", "Mochila · º", refresh)
	listFrame = list

	local button = hud.CreateActionButton("BagButton", "INV", "Mochila")
	local gameplayContext = ReplicatedStorage:WaitForChild("Inputs"):WaitForChild("GameplayContext")
	local toggleInventory = gameplayContext:WaitForChild("ToggleInventory") :: InputAction
	local buttonBinding = Instance.new("InputBinding")
	buttonBinding.Name = "TouchButton"
	buttonBinding.Type = Enum.InputBindingType.Automatic
	buttonBinding.UIButton = button
	buttonBinding.Parent = toggleInventory
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player or prompt.Name ~= "IncubatorPrompt"
			or prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		activeTab = "Mascotas"
		if hud.IsPanelOpen("Bag") then
			refresh()
		else
			hud.TogglePanel("Bag")
		end
	end)
	Net.GetRemoteEvent("InventoryUpdated").OnClientEvent:Connect(function(inventory: any, placedPlants: any, equippedGear: any)
		ClientState.SetInventoryFromSnapshot(inventory)
		ClientState.PlacedPlants = placedPlants or ClientState.PlacedPlants
		ClientState.EquippedGear = equippedGear or ClientState.EquippedGear
		if hud.IsPanelOpen("Bag") then
			render()
		end
	end)
end

return InventoryController
