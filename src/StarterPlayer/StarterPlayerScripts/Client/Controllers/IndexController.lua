--!strict
--[[
	IndexController.lua
	Índice: cuadrícula de cuadraditos con todas las plantas. Las que aún no
	has conseguido son "???". Tocar una descubierta abre su ficha (peso
	mínimo y máximo que has conseguido, valor, tiempo...). Arriba, tus
	estadísticas totales: dinero, plantas plantadas, suerte, renacimientos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)

local Client = script.Parent.Parent
local UI = require(Client.UI)
local ClientState = require(Client.ClientState)
local FarmArt = require(Client.Modules.FarmArt)

local IndexController = {}

local getIndexFn = Net.GetRemoteFunction("GetIndexData")

local listFrame: ScrollingFrame
local statsFrame: Frame
local detailFrame: Frame
local detailBody: Frame
local hud: any
local data: any = nil -- caché de GetIndexData

local function statChip(parent: Instance, text: string, order: number)
	local chip = Instance.new("TextLabel")
	chip.LayoutOrder = order
	chip.BackgroundColor3 = UI.Colors.Card
	chip.BorderSizePixel = 2
	chip.BorderColor3 = Color3.fromRGB(112, 78, 43)
	chip.Font = Enum.Font.Arcade
	chip.TextColor3 = UI.Colors.Text
	chip.TextScaled = true
	chip.Text = text
	chip.ZIndex = parent.ZIndex + 1
	chip.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.MaxTextSize = 14
	limit.Parent = chip
end

local function renderStats()
	for _, child in ipairs(statsFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local found, total = 0, #PlantConfig.Order
	for _, plantId in ipairs(PlantConfig.Order) do
		if ClientState.PlantIndex[plantId] then
			found += 1
		end
	end
	statChip(statsFrame, string.format("📖 %d/%d", found, total), 1)
	local stats = data and data.stats
	if stats then
		statChip(statsFrame, "💰 $" .. UI.Money(stats.lifetimeCash), 2)
		statChip(statsFrame, "🌱 " .. UI.Money(stats.plantsPlanted) .. " plantadas", 3)
		statChip(statsFrame, "🍀 Suerte x" .. UI.Money(stats.luck), 4)
		statChip(statsFrame, "♻️ Renac. " .. stats.rebirths .. " · cobro x" .. stats.cashMultiplier, 5)
		statChip(statsFrame, "🕵️ Robos " .. UI.Money(stats.plantsStolen), 6)
		statChip(statsFrame, string.format("🌿 Huecos %d/%d", stats.plotsUsed, stats.plotsMax), 7)
	end
end

local function line(parent: Instance, text: string, order: number, color: Color3?)
	local label = UI.Label(parent, text, UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 0), color or UI.Colors.Text, false)
	label.LayoutOrder = order
	label.TextSize = 16
	label.TextScaled = false
	label.TextWrapped = true
	return label
end

local function openDetail(plantId: string)
	for _, child in ipairs(detailBody:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local plant = PlantConfig[plantId]
	local rarity = RarityConfig[plant.rarity]
	local discovered = ClientState.PlantIndex[plantId] == true

	local iconHolder = Instance.new("Frame")
	iconHolder.LayoutOrder = 1
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.new(1, 0, 0, 72)
	iconHolder.ZIndex = detailBody.ZIndex + 1
	iconHolder.Parent = detailBody
	if discovered then
		local icon = FarmArt.CreateCropIcon(iconHolder, plantId, plant.color)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
	else
		local mark = UI.Label(iconHolder, "?", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), UI.Colors.Muted)
		mark.TextXAlignment = Enum.TextXAlignment.Center
	end

	local title = line(detailBody, if discovered then plant.displayName else "???", 2, rarity.color)
	title.TextSize = 24
	title.Size = UDim2.new(1, -16, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = line(detailBody, rarity.displayName, 3, rarity.color)
	sub.TextXAlignment = Enum.TextXAlignment.Center

	if not discovered then
		local hint = line(detailBody, "Consigue esta planta para ver su información.", 4, UI.Colors.Muted)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.Size = UDim2.new(1, -16, 0, 44)
	else
		local record = data and data.records and data.records[plantId]
		line(detailBody, "🌰 Semilla: $" .. UI.Money(plant.seedPrice), 4)
		line(detailBody, "⏱️ Crece en " .. UI.Time(plant.growTimeSeconds), 5)
		line(detailBody, "💵 Valor base: $" .. UI.Money(plant.baseSellValue), 6)
		line(detailBody, "📈 Ingreso base: $" .. UI.Money(plant.passiveIncomePerCycle * 12) .. "/min", 7)
		if record then
			line(detailBody, string.format("⚖️ Peso mínimo: %.2f kg", record.min), 8, UI.Colors.Green)
			line(detailBody, string.format("⚖️ Peso máximo: %.2f kg", record.max), 9, UI.Colors.Gold)
			line(detailBody, "🧺 Conseguidas: " .. UI.Money(record.count), 10)
		else
			line(detailBody, "⚖️ Aún no has registrado su peso", 8, UI.Colors.Muted)
		end
	end
	detailFrame.Visible = true
end

local function renderGrid()
	UI.ClearList(listFrame)
	UI.UseGrid(listFrame, Vector2.new(88, 92), 8)
	for order, plantId in ipairs(PlantConfig.Order) do
		local plant = PlantConfig[plantId]
		local rarity = RarityConfig[plant.rarity]
		local discovered = ClientState.PlantIndex[plantId] == true
		local tile = UI.Tile(listFrame, {
			order = order,
			title = if discovered then plant.displayName else "???",
			color = rarity.color,
			locked = not discovered,
			text = if discovered then nil else "?",
			icon = if discovered then function(holder: Frame)
				FarmArt.CreateCropIcon(holder, plantId, plant.color)
			end else nil,
		})
		tile.Activated:Connect(function()
			openDetail(plantId)
		end)
	end
end

local function refresh()
	-- Se pinta al instante con lo que ya sabemos; los datos nuevos llegan después.
	renderStats()
	renderGrid()
	task.spawn(function()
		local result = getIndexFn:InvokeServer()
		if result and result.success then
			data = result
			for plantId, value in pairs(result.index or {}) do
				if value == true then
					ClientState.PlantIndex[plantId] = true
				end
			end
			renderStats()
			renderGrid()
		end
	end)
end

function IndexController.Init(hudController: any, snapshot: any)
	hud = hudController
	for plantId, value in pairs(snapshot.plantIndex or {}) do
		if value == true then
			ClientState.PlantIndex[plantId] = true
		end
	end

	local panel, list = hud.CreatePanel("Index", "Índice", refresh)
	listFrame = list

	-- Estadísticas arriba (cuadrícula de etiquetas), la cuadrícula de plantas debajo.
	statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.BackgroundTransparency = 1
	statsFrame.Position = UDim2.new(0, 8, 0, 62)
	statsFrame.Size = UDim2.new(1, -16, 0, 70)
	statsFrame.ZIndex = panel.ZIndex + 1
	statsFrame.Parent = panel
	local statsGrid = Instance.new("UIGridLayout")
	statsGrid.CellSize = UDim2.new(0.333, -4, 0, 30)
	statsGrid.CellPadding = UDim2.fromOffset(4, 4)
	statsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	statsGrid.Parent = statsFrame
	list.Position = UDim2.new(0, 8, 0, 138)
	list.Size = UDim2.new(1, -16, 1, -146)

	-- Ficha de planta (cubre la cuadrícula).
	detailFrame = Instance.new("Frame")
	detailFrame.Name = "Detail"
	detailFrame.Visible = false
	detailFrame.Active = true
	detailFrame.BackgroundColor3 = UI.Colors.Panel
	detailFrame.BorderSizePixel = 0
	detailFrame.Position = UDim2.new(0, 8, 0, 62)
	detailFrame.Size = UDim2.new(1, -16, 1, -70)
	detailFrame.ZIndex = panel.ZIndex + 5
	detailFrame.Parent = panel
	detailBody = Instance.new("Frame")
	detailBody.BackgroundTransparency = 1
	detailBody.Position = UDim2.new(0, 0, 0, 0)
	detailBody.Size = UDim2.new(1, 0, 1, -54)
	detailBody.ZIndex = detailFrame.ZIndex + 1
	detailBody.Parent = detailFrame
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 2)
	bodyLayout.Parent = detailBody
	local back = UI.Button(detailFrame, "⬅ Volver", UI.Colors.Green, UDim2.new(1, -16, 0, 44), UDim2.new(0, 8, 1, -50))
	back.Activated:Connect(function()
		detailFrame.Visible = false
	end)

	local button = hud.CreateActionButton("IndexButton", "📖", "Índice")
	button.Activated:Connect(function()
		hud.TogglePanel("Index")
	end)

	Net.GetRemoteEvent("PlantDiscovered").OnClientEvent:Connect(function(payload)
		ClientState.PlantIndex[payload.plantId] = true
	end)
end

return IndexController
