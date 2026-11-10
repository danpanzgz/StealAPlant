--!strict
--[[
	HotbarController.lua
	Barra rápida propia (sustituye a la mochila nativa de Roblox, que está
	desactivada). 6 casillas con teclas 1-6. Contenido de cada casilla:
	  { kind = "stick" | "seed" | "plant" | "gear", id = string }
	- stick: equipa/guarda el palo
	- seed:  equipa la semilla; tocando una parcela se planta (se mantiene en la mano)
	- plant: inicia la colocación de esa flor (uid)
	- gear:  usa la herramienta
	Se guarda en el servidor (SetHotbar) para que sobreviva entre sesiones.
	La mochila arrastra objetos aquí con HotbarController.SlotAt / Assign.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PlantInstanceConfig = require(ReplicatedStorage.Shared.Config.PlantInstanceConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)
local FarmArt = require(Client.Modules.FarmArt)
local PlantController = require(script.Parent.PlantController)

local HotbarController = {}

local SLOTS = 6
local STICK_NAME = "Farm Slap Stick"
local player = Players.LocalPlayer

local getHotbarFn = Net.GetRemoteFunction("GetHotbar")
local setHotbarFn = Net.GetRemoteFunction("SetHotbar")
local useGearFn = Net.GetRemoteFunction("UseGear")
local quoteFn = Net.GetRemoteFunction("GetSellQuote")

local hud: any
local api: any
local bar: Frame
local infoLabel: TextLabel
local slotButtons: { TextButton } = {}
local layout: { [string]: any } = {}
local activeSlot: number? = nil
local editMode = false
local saveToken = 0
local sellMultiplier = 1
local multiplierAt = 0

HotbarController.ActiveEntry = nil :: any

local function entryOf(slot: number): any
	return layout[tostring(slot)]
end

local function findPlant(uid: string): any
	for _, plant in ipairs(ClientState.Inventory.plants or {}) do
		if plant.uid == uid then
			return plant
		end
	end
	return nil
end

-- ¿Sigue existiendo lo que apunta la casilla?
local function amountOf(entry: any): number
	if entry.kind == "stick" then
		return 1
	elseif entry.kind == "seed" then
		return ClientState.Inventory.seeds[entry.id] or 0
	elseif entry.kind == "plant" then
		return if findPlant(entry.id) then 1 else 0
	elseif entry.kind == "gear" then
		return (ClientState.Inventory.gear or {})[entry.id] or 0
	end
	return 0
end

function HotbarController.FillIcon(holder: Instance, entry: any)
	if entry.kind == "stick" then
		local mark = UI.Label(holder, "🪵", UDim2.fromScale(1, 1), UDim2.new(0, 0, 0, 0), Color3.new(1, 1, 1))
		mark.TextScaled = true
		mark.TextXAlignment = Enum.TextXAlignment.Center
	elseif entry.kind == "seed" then
		local plant = PlantConfig[entry.id]
		if plant then
			FarmArt.CreateCropIcon(holder, entry.id, plant.color)
		end
	elseif entry.kind == "plant" then
		local plant = findPlant(entry.id)
		local config = plant and PlantConfig[plant.plantId]
		if config then
			FarmArt.CreateCropIcon(holder, plant.plantId, config.color)
		end
	elseif entry.kind == "gear" then
		local gear = ShopConfig.Gear[entry.id]
		if gear then
			FarmArt.CreateGearIcon(holder, entry.id, RarityConfig[gear.rarity].color)
		end
	end
end

local function borderColorOf(entry: any): Color3?
	if entry.kind == "seed" then
		local plant = PlantConfig[entry.id]
		return plant and RarityConfig[plant.rarity].color
	elseif entry.kind == "plant" then
		local plant = findPlant(entry.id)
		local config = plant and PlantConfig[plant.plantId]
		return config and RarityConfig[plant.rarity or config.rarity].color
	end
	return nil
end

local function save()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			setHotbarFn:InvokeServer(layout)
		end
	end)
end

local function showInfo()
	local slot = activeSlot
	local entry = slot and entryOf(slot)
	if not entry or entry.kind ~= "plant" then
		infoLabel.Visible = false
		return
	end
	local plant = findPlant(entry.id)
	local config = plant and PlantConfig[plant.plantId]
	if not plant or not config then
		infoLabel.Visible = false
		return
	end
	infoLabel.Visible = true
	local function paint()
		infoLabel.Text = string.format(
			"%s · se vende por $%s",
			PlantInstanceConfig.FormatName(config.displayName, plant.size, plant.mutations or plant.mutation, plant.weight),
			UI.Money(math.floor((plant.value or 0) * sellMultiplier))
		)
	end
	paint()
	if os.clock() - multiplierAt > 15 then
		multiplierAt = os.clock()
		task.spawn(function()
			local result = quoteFn:InvokeServer()
			if result and result.success and type(result.multiplier) == "number" then
				sellMultiplier = result.multiplier
				if infoLabel.Visible then
					paint()
				end
			end
		end)
	end
end

local function refresh()
	local character = player.Character
	local holding = character and character:FindFirstChildOfClass("Tool")
	-- La casilla activa sale de lo que tienes en la mano.
	local placingUid = api and api.GetPlacingUid and api.GetPlacingUid()
	local newActive: number? = nil
	for slot = 1, SLOTS do
		local entry = entryOf(slot)
		if entry then
			if entry.kind == "stick" and holding and holding.Name == STICK_NAME then
				newActive = slot
			elseif entry.kind == "seed" and holding and holding:GetAttribute("SeedTool") == true and holding:GetAttribute("PlantId") == entry.id then
				newActive = slot
			elseif entry.kind == "plant" and placingUid == entry.id then
				newActive = slot
			end
		end
	end
	activeSlot = newActive
	HotbarController.ActiveEntry = if newActive then entryOf(newActive) else nil

	for slot = 1, SLOTS do
		local button = slotButtons[slot]
		local entry = entryOf(slot)
		for _, child in ipairs(button:GetChildren()) do
			if child.Name == "Content" then
				child:Destroy()
			end
		end
		local active = slot == activeSlot
		button.BorderColor3 = if active then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(112, 78, 43)
		button.BorderSizePixel = if active then 4 else 3
		button.BackgroundColor3 = if active then Color3.fromRGB(255, 233, 160) else UI.Colors.Card
		if entry then
			local amount = amountOf(entry)
			local content = Instance.new("Frame")
			content.Name = "Content"
			content.BackgroundTransparency = 1
			content.Size = UDim2.fromScale(1, 1)
			content.ZIndex = button.ZIndex + 1
			content.Parent = button
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(52, 56)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.46)
			holder.ZIndex = content.ZIndex + 1
			holder.Parent = content
			local scale = Instance.new("UIScale")
			scale.Scale = button.AbsoluteSize.X / 62
			scale.Parent = holder
			HotbarController.FillIcon(holder, entry)
			if amount <= 0 then
				content:Destroy() -- ya no existe: casilla vacía (se limpia al usarla)
			else
				local color = borderColorOf(entry)
				if color and not active then
					button.BorderColor3 = color
				end
				if entry.kind == "seed" or entry.kind == "gear" then
					local count = UI.Label(content, "x" .. amount, UDim2.new(1, -4, 0, 14), UDim2.new(0, 2, 1, -15), UI.Colors.Text)
					count.TextXAlignment = Enum.TextXAlignment.Right
					count.TextScaled = false
					count.TextSize = 12
				end
				if editMode then
					local remove = UI.Button(content, "✕", Color3.fromRGB(190, 70, 60), UDim2.fromOffset(20, 20), UDim2.new(1, -20, 0, -4))
					remove.TextSize = 12
					remove.ZIndex = content.ZIndex + 5
					remove.Activated:Connect(function()
						HotbarController.Assign(slot, nil)
					end)
				end
			end
		end
	end
	showInfo()
end

function HotbarController.Refresh()
	if bar then
		refresh()
	end
end

function HotbarController.SetEditMode(on: boolean)
	editMode = on
	if bar then
		refresh()
	end
end

function HotbarController.SlotAt(position: Vector2): number?
	if not bar or not bar.Visible then
		return nil
	end
	for slot, button in ipairs(slotButtons) do
		local p, s = button.AbsolutePosition, button.AbsoluteSize
		-- Margen extra: soltar "cerca" también vale (dedos gordos).
		if position.X >= p.X - 4 and position.X <= p.X + s.X + 4 and position.Y >= p.Y - 8 and position.Y <= p.Y + s.Y + 8 then
			return slot
		end
	end
	return nil
end

function HotbarController.FirstFree(): number?
	for slot = 1, SLOTS do
		local entry = entryOf(slot)
		if not entry or amountOf(entry) <= 0 then
			return slot
		end
	end
	return nil
end

function HotbarController.Assign(slot: number, entry: any?)
	if slot < 1 or slot > SLOTS then
		return
	end
	if entry then
		-- Un objeto no puede estar en dos casillas a la vez.
		for other = 1, SLOTS do
			local existing = entryOf(other)
			if existing and existing.kind == entry.kind and existing.id == entry.id then
				layout[tostring(other)] = nil
			end
		end
		layout[tostring(slot)] = { kind = entry.kind, id = entry.id }
	else
		layout[tostring(slot)] = nil
	end
	refresh()
	save()
end

function HotbarController.Contains(kind: string, id: string): boolean
	for slot = 1, SLOTS do
		local entry = entryOf(slot)
		if entry and entry.kind == kind and entry.id == id then
			return true
		end
	end
	return false
end

local function unequip()
	PlantController.ClearSeedTools(false)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
	if api and api.CancelPlacementSilently then
		api.CancelPlacementSilently()
	end
end

function HotbarController.Use(slot: number)
	local entry = entryOf(slot)
	if not entry then
		return
	end
	if amountOf(entry) <= 0 then
		layout[tostring(slot)] = nil
		refresh()
		save()
		return
	end
	if activeSlot == slot then
		unequip()
		task.defer(refresh)
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if entry.kind == "stick" then
		unequip()
		local backpack = player:FindFirstChildOfClass("Backpack")
		local tool = backpack and backpack:FindFirstChild(STICK_NAME)
		if tool and humanoid and player:GetAttribute("CarryingStolenPlant") ~= true then
			humanoid:EquipTool(tool :: Tool)
		end
	elseif entry.kind == "seed" then
		if api and api.CancelPlacementSilently then
			api.CancelPlacementSilently()
		end
		PlantController.EquipSeed(entry.id)
	elseif entry.kind == "plant" then
		unequip()
		if api and api.StartPlacement then
			api.StartPlacement(entry.id)
		end
	elseif entry.kind == "gear" then
		local result = useGearFn:InvokeServer(entry.id)
		if result and result.success then
			if result.placed then
				hud.Push(string.format("🪤 Trampa colocada (%d/%d)", result.active, result.max), "good")
			else
				hud.Push("🧰 Herramienta usada", "good")
			end
		else
			hud.Fail(result and result.reason)
		end
	end
	task.defer(refresh)
end

local function layoutBar()
	local touch = UserInputService.TouchEnabled
	local size = if touch then 46 else 54
	local gap = 5
	bar.Size = UDim2.fromOffset(SLOTS * size + (SLOTS - 1) * gap, size)
	bar.Position = UDim2.new(0.5, 0, 1, if touch then -16 else -12)
	for _, button in ipairs(slotButtons) do
		button.Size = UDim2.fromOffset(size, size)
	end
	infoLabel.Position = UDim2.new(0.5, 0, 1, -(size + 22))
end

function HotbarController.Init(hudController: any, inventoryApi: any)
	hud = hudController
	api = inventoryApi
	local gui = hud.GetScreenGui()

	bar = Instance.new("Frame")
	bar.Name = "Hotbar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.ZIndex = 12
	bar.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bar

	for slot = 1, SLOTS do
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. slot
		button.LayoutOrder = slot
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = UI.Colors.Card
		button.BorderSizePixel = 3
		button.BorderColor3 = Color3.fromRGB(112, 78, 43)
		button.ZIndex = 13
		button.Parent = bar
		local number = UI.Label(button, tostring(slot), UDim2.fromOffset(14, 14), UDim2.fromOffset(2, 0), UI.Colors.Muted)
		number.ZIndex = 20
		number.TextScaled = false
		number.TextSize = 11
		button.Activated:Connect(function()
			HotbarController.Use(slot)
		end)
		table.insert(slotButtons, button)
	end

	infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "HeldInfo"
	infoLabel.AnchorPoint = Vector2.new(0.5, 1)
	infoLabel.Size = UDim2.fromOffset(300, 24)
	infoLabel.BackgroundColor3 = Color3.fromRGB(40, 28, 18)
	infoLabel.BackgroundTransparency = 0.25
	infoLabel.BorderSizePixel = 0
	infoLabel.TextColor3 = Color3.fromRGB(255, 240, 190)
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextScaled = true
	infoLabel.Visible = false
	infoLabel.ZIndex = 14
	infoLabel.Parent = gui
	UI.Round(infoLabel, 8)

	layoutBar()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBar)

	-- Teclas 1-6.
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local index = table.find(keys, input.KeyCode)
		if index then
			HotbarController.Use(index)
		end
	end)

	-- Qué tengo en la mano: cambia al equipar/guardar herramientas.
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(refresh)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(refresh)
			end
		end)
		task.defer(refresh)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end

	Net.GetRemoteEvent("InventoryUpdated").OnClientEvent:Connect(function()
		task.defer(refresh)
	end)

	-- Estado guardado. Por defecto: el palo en la casilla 1.
	layout = { ["1"] = { kind = "stick", id = "stick" } }
	refresh()
	task.spawn(function()
		local result = getHotbarFn:InvokeServer()
		if result and result.success and type(result.hotbar) == "table" then
			local loaded: { [string]: any } = {}
			for slot = 1, SLOTS do
				local entry = result.hotbar[tostring(slot)]
				if type(entry) == "table" then
					loaded[tostring(slot)] = entry
				end
			end
			if next(loaded) ~= nil then
				layout = loaded
			end
			refresh()
		end
	end)
end

return HotbarController
