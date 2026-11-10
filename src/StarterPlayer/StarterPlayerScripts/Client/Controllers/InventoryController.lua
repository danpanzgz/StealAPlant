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
local AudioController = require(script.Parent.AudioController)
local Hotbar = require(script.Parent.HotbarController)

local InventoryController = {}
local player = Players.LocalPlayer
local listFrame: ScrollingFrame
local hud: any
local stats: any = nil
local activeTab = "Plantas"
local sortMode = "Value"
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
				hud.Fail(result and result.reason)
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
local placementInputConn: RBXScriptConnection? = nil
local placementGui: ScreenGui? = nil
local placing = false

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
	if placementInputConn then
		placementInputConn:Disconnect()
		placementInputConn = nil
	end
	if placementGui then
		placementGui:Destroy()
		placementGui = nil
	end
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

local confirmAt: (Vector2?) -> ()
local placeAtFeet: () -> ()

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
	zone.Position = Vector3.new(zone.Position.X, floor.Position.Y + floor.Size.Y / 2 + 0.08, zone.Position.Z)
	zone.Parent = workspace
	placementZone = zone

	local ghost = newPreviewPart("PlacementGhost", Color3.fromRGB(110, 230, 120), 0.35)
	ghost.Size = Vector3.new(3, 0.3, 3)
	ghost.Parent = workspace
	placementGhost = ghost

	-- Entrada directa (ratón o toque): no depende de InputContext.
	placementInputConn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not pendingPlantPlacementUid then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			confirmAt(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.X then
			InventoryController.CancelPlacement()
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonA then
			placeAtFeet()
		end
	end)

	-- Botones en pantalla (móvil y PC): colocar a mis pies / cancelar.
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlacementPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	placementGui = gui
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -110)
	bar.Size = UDim2.fromOffset(330, 100)
	bar.Parent = gui
	local tip = UI.Label(bar, "Toca el suelo verde de tu jardín", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), Color3.new(1, 1, 1))
	tip.TextSize = 16
	tip.TextStrokeTransparency = 0.3
	local feet = UI.Button(bar, "📍 Colocar aquí", UI.Colors.Green, UDim2.new(0.58, -4, 0, 48), UDim2.new(0, 0, 0, 34))
	feet.Activated:Connect(function()
		placeAtFeet()
	end)
	local cancel = UI.Button(bar, "✖ Cancelar", Color3.fromRGB(200, 70, 70), UDim2.new(0.42, -4, 0, 48), UDim2.new(0.58, 4, 0, 34))
	cancel.Activated:Connect(function()
		InventoryController.CancelPlacement()
	end)

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
		ghost.Position = Vector3.new(hit.Position.X, floor.Position.Y + floor.Size.Y / 2 + 0.2, hit.Position.Z)
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
	Hotbar.Refresh()
	hud.Push("Colocación cancelada", "warn")
end

local function sendPlacement(position: Vector3)
	if placing or not pendingPlantPlacementUid then
		return
	end
	local floor = getYardFloor()
	if floor and not isInsideYard(floor, position) then
		hud.Push(PLACE_REASONS.invalid_garden_position, "warn")
		return
	end
	placing = true
	local ok, result = pcall(function()
		return placePlantFn:InvokeServer(pendingPlantPlacementUid, position)
	end)
	placing = false
	if ok and result and result.success then
		pendingPlantPlacementUid = nil
		setPlacementContextEnabled(false)
		stopPlacementPreview()
		PlantController.RestoreSlapTool()
		Hotbar.Refresh()
		hud.Push("¡Flor colocada en tu jardín!", "good")
		AudioController.Play("PlantPlace")
	else
		local reason = tostring(if ok and result then result.reason else "error")
		-- La colocación sigue activa: el jugador puede probar otro punto.
		hud.Push(PLACE_REASONS[reason] or require(ReplicatedStorage.Shared.Modules.ErrorMessages).Get(reason), "warn")
	end
end

confirmAt = function(screenPosition: Vector2?)
	if not pendingPlantPlacementUid or not screenPosition then
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
	sendPlacement(hit.Position)
end

placeAtFeet = function()
	if not pendingPlantPlacementUid then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	-- Un poco por delante del jugador para no taparse con sus pies.
	local origin = root.Position + root.CFrame.LookVector * 3
	local hit = workspace:Raycast(origin, Vector3.new(0, -30, 0), params)
	sendPlacement(if hit then hit.Position else Vector3.new(origin.X, root.Position.Y - 3, origin.Z))
end

function InventoryController.ConfirmPlacement(screenPosition: Vector2)
	confirmAt(screenPosition)
end


local function comparePlants(a: any, b: any): boolean
	local valueA, valueB = a.value or 0, b.value or 0
	if valueA ~= valueB then
		return valueA > valueB
	end
	return tostring(a.uid) < tostring(b.uid)
end

-- ===== Cuadrícula de objetos + detalle + arrastrar a la barra rápida =====

type Selection = { kind: string, id: string }
local selected: Selection? = nil
local tabFrame: Frame
local detailFrame: Frame
local detailTitle: TextLabel
local detailSub: TextLabel
local detailButtons: Frame
local bagFrame: Frame
local ghost: Frame? = nil
local justDragged = false
local dragConns: { RBXScriptConnection } = {}

local TAB_ICONS = { Plantas = "🌼 Plantas", Semillas = "🌱 Semillas", Equipo = "🧰 Equipo", Mascotas = "🐾 Mascotas" }
local tabs2 = { "Plantas", "Semillas", "Equipo", "Mascotas" }

local function findPlantByUid(uid: string): any
	for _, plant in ipairs(ClientState.Inventory.plants or {}) do
		if plant.uid == uid then
			return plant
		end
	end
	for _, plant in ipairs(ClientState.PlacedPlants or {}) do
		if plant.uid == uid then
			return plant
		end
	end
	return nil
end

function InventoryController.StartPlacement(uid: string)
	if player:GetAttribute("CarryingStolenPlant") == true then
		hud.Fail("carrying_stolen_plant")
		return
	end
	pendingPlantPlacementUid = uid
	PlantController.ClearSeedTools(false)
	setPlacementContextEnabled(true)
	startPlacementPreview()
	if hud.IsPanelOpen("Bag") then
		hud.TogglePanel("Bag")
	end
	hud.Push("Toca la zona marrón de tu jardín para colocarla.", "good")
	Hotbar.Refresh()
end

function InventoryController.GetPlacingUid(): string?
	return pendingPlantPlacementUid
end

function InventoryController.CancelPlacementSilently()
	if not pendingPlantPlacementUid then
		return
	end
	pendingPlantPlacementUid = nil
	setPlacementContextEnabled(false)
	stopPlacementPreview()
	Hotbar.Refresh()
end

local function pinSelection(sel: Selection)
	local slot = Hotbar.FirstFree()
	if not slot then
		hud.Push("La barra está llena: arrastra el objeto sobre una casilla.", "warn")
		return
	end
	Hotbar.Assign(slot, { kind = sel.kind, id = sel.id })
	hud.Push("📌 Guardado en la casilla " .. slot, "good")
end

-- Texto y botones del objeto seleccionado (se recalcula con datos frescos).
local function describe(sel: Selection): (string, string, { { text: string, color: Color3, run: () -> () } })
	local buttons = {}
	local function add(text: string, color: Color3, run: () -> ())
		table.insert(buttons, { text = text, color = color, run = run })
	end
	if sel.kind == "seed" then
		local data = PlantConfig[sel.id]
		local count = ClientState.Inventory.seeds[sel.id] or 0
		local rarity = RarityConfig[data.rarity]
		add("🌱 En mano", UI.Colors.Green, function()
			if PlantController.EquipSeed(sel.id) then
				hud.TogglePanel("Bag")
				hud.Push("Semilla en mano: toca una parcela para plantar.", "good")
			else
				hud.Fail("no_seed_in_inventory")
			end
		end)
		add("📌 Barra", UI.Colors.Blue, function() pinSelection(sel) end)
		add("🎁", UI.Colors.Grey, function() openGiftPanel(sel.id, "seed", data.displayName .. " Seeds") end)
		return data.displayName .. " Seeds  x" .. count, rarity.displayName .. " · crece en " .. data.growTimeSeconds .. "s", buttons
	elseif sel.kind == "pack" then
		local pack = ShopConfig.Packs[sel.id]
		local count = ClientState.Inventory.seedPacks[sel.id] or 0
		add("Abrir", UI.Colors.Green, function()
			local result = openPackFn:InvokeServer(sel.id)
			if result and result.success then
				local names = {}
				for plantId, amount in pairs(result.seeds) do
					table.insert(names, PlantConfig[plantId].displayName .. " x" .. amount)
				end
				table.sort(names)
				hud.Push("Pack abierto: " .. table.concat(names, ", "), "good")
			else
				hud.Fail(result and result.reason)
			end
		end)
		return (pack and pack.displayName or sel.id) .. "  x" .. count, "Abre semillas aleatorias", buttons
	elseif sel.kind == "plant" or sel.kind == "placed" then
		local plant = findPlantByUid(sel.id)
		local data = plant and PlantConfig[plant.plantId]
		if not plant or not data then
			return "—", "", buttons
		end
		local rarity = RarityConfig[plant.rarity or data.rarity]
		if sel.kind == "plant" then
			add("Colocar", UI.Colors.Green, function() InventoryController.StartPlacement(sel.id) end)
			add("📌 Barra", UI.Colors.Blue, function() pinSelection(sel) end)
			add("🎁", UI.Colors.Grey, function() openGiftPanel(sel.id, "plant", data.displayName) end)
		else
			add("Recoger", UI.Colors.Blue, function()
				local result = collectPlantFn:InvokeServer(sel.id)
				if result and result.success then
					hud.Push("La flor volvió a tu mochila", "good")
				else
					hud.Fail(result and result.reason)
				end
			end)
		end
		return PlantInstanceConfig.FormatName(data.displayName, plant.size, plant.mutations or plant.mutation, plant.weight),
			string.format("%s · vale $%s · $%s/min", rarity.displayName, UI.Money(plant.value or 0), UI.Money(plant.incomePerMinute or 0)),
			buttons
	elseif sel.kind == "gear" then
		local gear = ShopConfig.Gear[sel.id]
		local count = (ClientState.Inventory.gear or {})[sel.id] or 0
		if gear then
			local equipped = ClientState.EquippedGear[sel.id] == true
			add(if gear.kind == "passive" then (if equipped then "Quitar" else "Equipar") else "Usar", UI.Colors.Green, function()
				local result = useGearFn:InvokeServer(sel.id)
				if result and result.success then
					hud.Push("🧰 Hecho", "good")
				else
					hud.Fail(result and result.reason)
				end
			end)
			add("📌 Barra", UI.Colors.Blue, function() pinSelection(sel) end)
			return gear.displayName .. "  x" .. count, gear.description, buttons
		end
	elseif sel.kind == "stick" then
		add("📌 Barra", UI.Colors.Blue, function() pinSelection(sel) end)
		return "🪵 Palo", "Empuja a los ladrones. Mejora solo con cada renacimiento.", buttons
	end
	return "—", "", buttons
end

local function showDetail()
	for _, child in ipairs(detailButtons:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local sel = selected
	if not sel then
		detailTitle.Text = "Toca un objeto"
		detailSub.Text = "Mantén pulsado y arrastra a la barra de abajo para tenerlo a mano."
		return
	end
	local title, sub, buttons = describe(sel)
	detailTitle.Text = title
	detailSub.Text = sub
	for index, info in ipairs(buttons) do
		local button = UI.Button(detailButtons, info.text, info.color, UDim2.fromOffset(if #info.text > 6 then 92 else 62, 34), nil)
		button.LayoutOrder = index
		button.TextSize = 12
		button.Activated:Connect(function()
			info.run()
			task.defer(function()
				if detailFrame.Parent then
					showDetail()
				end
			end)
		end)
	end
end

local function endDrag()
	for _, conn in ipairs(dragConns) do
		conn:Disconnect()
	end
	table.clear(dragConns)
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	listFrame.ScrollingEnabled = true
end

-- Pulsación larga (o arrastre con ratón) sobre un cuadradito -> fantasma que se suelta en la barra.
local function attachDrag(tile: GuiButton, entry: { kind: string, id: string })
	tile.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		endDrag()
		local startPos = Vector2.new(input.Position.X, input.Position.Y)
		local dragging = false
		local alive = true
		local function begin()
			if dragging or not alive then
				return
			end
			dragging = true
			justDragged = true
			listFrame.ScrollingEnabled = false
			local screen = hud.GetScreenGui()
			local g = Instance.new("Frame")
			g.Name = "DragGhost"
			g.Size = UDim2.fromOffset(60, 60)
			g.AnchorPoint = Vector2.new(0.5, 0.5)
			g.BackgroundColor3 = UI.Colors.Card
			g.BackgroundTransparency = 0.15
			g.BorderSizePixel = 3
			g.BorderColor3 = UI.Colors.Gold
			g.ZIndex = 80
			g.Parent = screen
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(52, 56)
			holder.Position = UDim2.fromOffset(4, 2)
			holder.ZIndex = 81
			holder.Parent = g
			Hotbar.FillIcon(holder, entry)
			ghost = g
		end
		local function place(position: Vector3)
			if ghost then
				local inset = hud.GetScreenGui().AbsolutePosition
				ghost.Position = UDim2.fromOffset(position.X - inset.X, position.Y - inset.Y)
			end
		end
		-- El ratón arrastra al instante; el dedo necesita mantener 0.25 s.
		if kind == Enum.UserInputType.Touch then
			task.delay(0.25, function()
				if alive and not dragging and (not input.UserInputState or input.UserInputState ~= Enum.UserInputState.End) then
					begin()
					place(input.Position)
				end
			end)
		end
		table.insert(dragConns, UserInputService.InputChanged:Connect(function(changed: InputObject)
			if changed ~= input and changed.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local now = Vector2.new(changed.Position.X, changed.Position.Y)
			if not dragging and kind == Enum.UserInputType.MouseButton1 and (now - startPos).Magnitude > 8 then
				begin()
			end
			if not dragging and kind == Enum.UserInputType.Touch and (now - startPos).Magnitude > 14 then
				alive = false -- el dedo se movió antes: era un scroll
			end
			if dragging then
				place(changed.Position)
			end
		end))
		table.insert(dragConns, UserInputService.InputEnded:Connect(function(ended: InputObject)
			if ended ~= input then
				return
			end
			alive = false
			if dragging then
				local slot = Hotbar.SlotAt(Vector2.new(ended.Position.X, ended.Position.Y))
				if slot then
					Hotbar.Assign(slot, entry)
					hud.Push("📌 Guardado en la casilla " .. slot, "good")
				end
				task.delay(0.1, function()
					justDragged = false
				end)
			end
			endDrag()
		end))
	end)
end

local function addTile(order: number, sel: Selection, title: string, count: number?, color: Color3?, icon: (Frame) -> (), draggable: boolean)
	local isSelected = selected ~= nil and selected.kind == sel.kind and selected.id == sel.id
	local tile = UI.Tile(listFrame, { order = order, title = title, count = count, color = color, selected = isSelected, icon = icon })
	tile.Activated:Connect(function()
		if justDragged then
			return
		end
		selected = sel
		for _, other in ipairs(listFrame:GetChildren()) do
			if other:IsA("TextButton") then
				other.BorderSizePixel = 3
			end
		end
		tile.BorderSizePixel = 4
		tile.BorderColor3 = Color3.fromRGB(255, 255, 255)
		showDetail()
	end)
	if draggable then
		attachDrag(tile, sel)
	end
end

local function emptyNote(order: number, text: string)
	local note = UI.Label(listFrame, text, UDim2.new(1, -16, 0, 60), UDim2.new(0, 8, 0, 8), UI.Colors.Muted, false)
	note.LayoutOrder = order
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Center
end

local function fillTiles()
	local order = 0
	if activeTab == "Plantas" then
		local plants = {}
		for _, plant in ipairs(ClientState.Inventory.plants or {}) do
			if PlantConfig[plant.plantId] then
				table.insert(plants, plant)
			end
		end
		table.sort(plants, comparePlants)
		for _, plant in ipairs(plants) do
			local data = PlantConfig[plant.plantId]
			order += 1
			addTile(order, { kind = "plant", id = plant.uid }, data.displayName, nil, RarityConfig[plant.rarity or data.rarity].color, function(holder)
				FarmArt.CreateCropIcon(holder, plant.plantId, data.color)
			end, true)
		end
		for _, plant in ipairs(ClientState.PlacedPlants or {}) do
			local data = PlantConfig[plant.plantId]
			if data then
				order += 1
				addTile(order, { kind = "placed", id = plant.uid }, "📍 " .. data.displayName, nil, Color3.fromRGB(90, 170, 90), function(holder)
					FarmArt.CreateCropIcon(holder, plant.plantId, data.color)
				end, false)
			end
		end
		if order == 0 then
			emptyNote(1, "Aún no tienes plantas. Cosecha una en tu jardín 🌱")
		end
	elseif activeTab == "Semillas" then
		for packId, count in pairs(ClientState.Inventory.seedPacks or {}) do
			if count > 0 then
				local pack = ShopConfig.Packs[packId]
				order += 1
				addTile(order, { kind = "pack", id = packId }, pack and pack.displayName or packId, count, RarityConfig[pack and pack.rarity or "Common"].color, function(holder)
					FarmArt.CreateSeedPackIcon(holder, RarityConfig[pack and pack.rarity or "Common"].color)
				end, false)
			end
		end
		local ids = {}
		for plantId, count in pairs(ClientState.Inventory.seeds or {}) do
			if count > 0 and PlantConfig[plantId] then
				table.insert(ids, plantId)
			end
		end
		table.sort(ids, function(a, b)
			local ra, rb = RarityConfig[PlantConfig[a].rarity].order, RarityConfig[PlantConfig[b].rarity].order
			if ra ~= rb then
				return ra > rb
			end
			return PlantConfig[a].displayName < PlantConfig[b].displayName
		end)
		for _, plantId in ipairs(ids) do
			local data = PlantConfig[plantId]
			order += 1
			addTile(order, { kind = "seed", id = plantId }, data.displayName, ClientState.Inventory.seeds[plantId], RarityConfig[data.rarity].color, function(holder)
				FarmArt.CreateCropIcon(holder, plantId, data.color)
			end, true)
		end
		if order == 0 then
			emptyNote(1, "No tienes semillas. Compra en la tienda de semillas del mapa 🛒")
		end
	elseif activeTab == "Equipo" then
		order += 1
		addTile(order, { kind = "stick", id = "stick" }, "Palo", nil, Color3.fromRGB(142, 91, 48), function(holder)
			local mark = UI.Label(holder, "🪵", UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1))
			mark.TextScaled = true
			mark.TextXAlignment = Enum.TextXAlignment.Center
		end, true)
		local gearIds = {}
		for gearId, count in pairs(ClientState.Inventory.gear or {}) do
			if count > 0 and ShopConfig.Gear[gearId] then
				table.insert(gearIds, gearId)
			end
		end
		table.sort(gearIds)
		for _, gearId in ipairs(gearIds) do
			local gear = ShopConfig.Gear[gearId]
			order += 1
			addTile(order, { kind = "gear", id = gearId }, gear.displayName, (ClientState.Inventory.gear or {})[gearId], RarityConfig[gear.rarity].color, function(holder)
				FarmArt.CreateGearIcon(holder, gearId, RarityConfig[gear.rarity].color)
			end, true)
		end
	end
end

local function makeTabs()
	UI.ClearList(tabFrame)
	for index, tab in ipairs(tabs2) do
		local width = 1 / #tabs2
		local button = UI.Button(tabFrame, TAB_ICONS[tab], if activeTab == tab then UI.Colors.Green else UI.Colors.Grey, UDim2.new(width, -4, 1, 0), UDim2.new((index - 1) * width, 2, 0, 0))
		button.TextSize = 12
		button.Activated:Connect(function()
			if activeTab == tab then
				return
			end
			activeTab = tab
			selected = nil
			render()
			if tab == "Mascotas" then
				task.spawn(refresh)
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
				hud.Fail(result and result.reason)
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
				hud.Fail(result and result.reason)
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
				hud.Fail(result and result.reason)
			end
		end)
	end
end


render = function()
	if not listFrame or not listFrame.Parent then
		return
	end
	makeTabs()
	UI.ClearList(listFrame)
	if activeTab == "Mascotas" then
		UI.UseList(listFrame, 8)
		detailFrame.Visible = false
		listFrame.Size = UDim2.new(1, -16, 1, -112)
		addPetRows(0)
		return
	end
	detailFrame.Visible = true
	listFrame.Size = UDim2.new(1, -16, 1, -112 - 84)
	UI.UseGrid(listFrame, Vector2.new(74, 82), 6)
	-- Si lo seleccionado ya no existe (vendido, plantado...) se deselecciona.
	if selected then
		local sel = selected
		local exists = false
		if sel.kind == "seed" then
			exists = (ClientState.Inventory.seeds[sel.id] or 0) > 0
		elseif sel.kind == "pack" then
			exists = (ClientState.Inventory.seedPacks[sel.id] or 0) > 0
		elseif sel.kind == "plant" or sel.kind == "placed" then
			exists = findPlantByUid(sel.id) ~= nil
		elseif sel.kind == "gear" then
			exists = ((ClientState.Inventory.gear or {})[sel.id] or 0) > 0
		elseif sel.kind == "stick" then
			exists = true
		end
		if not exists then
			selected = nil
		end
	end
	fillTiles()
	showDetail()
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
	if hud.IsPanelOpen("Bag") then
		render()
	end
end

function InventoryController.Init(hudController: any)
	hud = hudController
	-- Se abre al instante con lo que ya sabe el cliente (el servidor lo empuja
	-- con InventoryUpdated); no espera ninguna llamada de red.
	local frame, list = hud.CreatePanel("Bag", "Mochila", function()
		Hotbar.SetEditMode(true)
		render()
	end)
	bagFrame = frame
	listFrame = list
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			Hotbar.SetEditMode(false)
			endDrag()
		end
	end)

	tabFrame = Instance.new("Frame")
	tabFrame.Name = "Tabs"
	tabFrame.BackgroundTransparency = 1
	tabFrame.Position = UDim2.new(0, 8, 0, 62)
	tabFrame.Size = UDim2.new(1, -16, 0, 36)
	tabFrame.ZIndex = frame.ZIndex + 2
	tabFrame.Parent = frame

	list.Position = UDim2.new(0, 8, 0, 104)

	detailFrame = Instance.new("Frame")
	detailFrame.Name = "Detail"
	detailFrame.AnchorPoint = Vector2.new(0, 1)
	detailFrame.Position = UDim2.new(0, 8, 1, -8)
	detailFrame.Size = UDim2.new(1, -16, 0, 76)
	detailFrame.BackgroundColor3 = UI.Colors.Card
	detailFrame.BorderSizePixel = 3
	detailFrame.BorderColor3 = Color3.fromRGB(112, 78, 43)
	detailFrame.ZIndex = frame.ZIndex + 2
	detailFrame.Parent = frame
	detailTitle = UI.Label(detailFrame, "", UDim2.new(1, -12, 0, 22), UDim2.new(0, 8, 0, 3), UI.Colors.Text, true)
	detailTitle.TextTruncate = Enum.TextTruncate.AtEnd
	detailSub = UI.Label(detailFrame, "", UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 25), UI.Colors.Muted, false)
	detailSub.TextScaled = false
	detailSub.TextSize = 12
	detailSub.TextTruncate = Enum.TextTruncate.AtEnd
	detailButtons = Instance.new("Frame")
	detailButtons.BackgroundTransparency = 1
	detailButtons.Position = UDim2.new(0, 8, 1, -38)
	detailButtons.Size = UDim2.new(1, -16, 0, 34)
	detailButtons.ZIndex = detailFrame.ZIndex + 1
	detailButtons.Parent = detailFrame
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.Padding = UDim.new(0, 6)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = detailButtons

	local button = hud.CreateActionButton("BagButton", "🎒", "Mochila")
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
			render()
			task.spawn(refresh)
		else
			hud.TogglePanel("Bag")
			task.spawn(refresh)
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
	-- Estado inicial (incubadora, estadísticas) sin bloquear la apertura.
	task.spawn(refresh)
end

return InventoryController
