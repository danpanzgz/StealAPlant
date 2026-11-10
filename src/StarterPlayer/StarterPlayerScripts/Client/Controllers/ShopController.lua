--!strict
--[[
	ShopController.lua
	Tiendas físicas del mapa (Semillas / Herramientas / Huevos). Cada puesto
	abre SOLO lo que vende. No hay botón en el HUD: hay que ir caminando.
	El stock se precarga y se guarda en caché, así que el panel abre al instante.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UI = require(script.Parent.Parent.UI)
local FarmArt = require(script.Parent.Parent.Modules.FarmArt)

local ShopController = {}
local snapshotFn = Net.GetRemoteFunction("GetShopStock")
local buyFn = Net.GetRemoteFunction("BuyShopItem")

local hud: any
local listFrame: ScrollingFrame
local panelFrame: Frame
local titleLabel: TextLabel? = nil
local cached: any = nil
local restockAt = 0
local timerLabel: TextLabel?
local activeCategory = "Seeds"
local buying = false

local CATEGORY = {
	Seeds = { kind = "pack", title = "🌱 Tienda de semillas", empty = "Sin packs ahora mismo. Vuelve en el próximo restock." },
	Gear = { kind = "gear", title = "🧰 Tienda de herramientas", empty = "Sin herramientas ahora mismo. Vuelve en el próximo restock." },
	Pets = { kind = "petEgg", title = "🥚 Tienda de huevos", empty = "Sin huevos ahora mismo. Vuelve en el próximo restock." },
}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local render: () -> ()

local function addItem(item: any, order: number)
	local rarity = RarityConfig[item.rarity]
	local color = if rarity then rarity.color else UI.Colors.Gold
	local card = UI.Card(listFrame, 150, order)
	card.BorderColor3 = color
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(52, 56)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 4)
	holder.ZIndex = card.ZIndex + 1
	holder.Parent = card
	if item.kind == "petEgg" then
		FarmArt.CreateEggIcon(holder, color)
	elseif item.kind == "pack" then
		FarmArt.CreateSeedPackIcon(holder, color)
	elseif item.kind == "gear" then
		FarmArt.CreateGearIcon(holder, item.gearId, color)
	end
	local name = UI.Label(card, item.displayName, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 62), UI.Colors.Text, true)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextScaled = false
	name.TextSize = 13
	local stock = UI.Label(card, string.format("Quedan %d de %d", item.remaining, item.limit), UDim2.new(1, -8, 0, 14), UDim2.new(0, 4, 0, 80), if item.remaining > 0 then UI.Colors.Muted else Color3.fromRGB(190, 70, 60), false)
	stock.TextXAlignment = Enum.TextXAlignment.Center
	stock.TextScaled = false
	stock.TextSize = 11
	local soldOut = item.remaining <= 0
	local button = UI.Button(card, if soldOut then "Agotado" else ("$" .. UI.Money(item.price)), if soldOut then UI.Colors.Grey else UI.Colors.Green, UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 1, -42))
	button.TextSize = 14
	button.Activated:Connect(function()
		if soldOut or buying then
			return
		end
		buying = true
		local result = buyFn:InvokeServer(item.itemId)
		buying = false
		if result and result.success then
			hud.Push("🛒 Compraste " .. result.displayName, "good")
			task.spawn(function()
				local fresh = snapshotFn:InvokeServer()
				if fresh and fresh.success then
					cached = fresh
					restockAt = fresh.nextRestockAt or restockAt
					if hud.IsPanelOpen("Shop") then
						render()
					end
				end
			end)
		else
			hud.Fail(result and result.reason)
		end
	end)
end

render = function()
	local category = CATEGORY[activeCategory]
	if titleLabel then
		titleLabel.Text = category.title
	end
	UI.ClearList(listFrame)
	UI.UseGrid(listFrame, Vector2.new(150, 150), 8)
	if not cached then
		local note = UI.Label(listFrame, "Cargando stock...", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), UI.Colors.Muted, false)
		note.LayoutOrder = 1
		return
	end
	restockAt = cached.nextRestockAt or restockAt
	local count = 0
	for _, item in ipairs(cached.items) do
		if item.kind == category.kind then
			count += 1
			addItem(item, count)
		end
	end
	if count == 0 then
		local note = UI.Label(listFrame, category.empty, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 0), UI.Colors.Muted, false)
		note.LayoutOrder = 1
		note.TextWrapped = true
	end
end

local function loadStock()
	local snapshot = snapshotFn:InvokeServer()
	if snapshot and snapshot.success then
		cached = snapshot
		restockAt = snapshot.nextRestockAt or 0
		if hud.IsPanelOpen("Shop") then
			render()
		end
	elseif snapshot then
		hud.Fail(snapshot.reason)
	end
end

function ShopController.Init(_snapshot: any, hudController: any)
	hud = hudController
	local frame, list = hud.CreatePanel("Shop", "Tienda", function()
		render() -- al instante con la caché
		task.spawn(loadStock)
	end)
	panelFrame = frame
	listFrame = list
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			titleLabel = child
			break
		end
	end
	-- Hueco bajo el título para el contador de restock.
	timerLabel = UI.Label(frame, "", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 60), UI.Colors.Gold, true)
	if timerLabel then
		timerLabel.TextScaled = false
		timerLabel.TextSize = 13
		timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	end
	list.Position = UDim2.new(0, 8, 0, 84)
	list.Size = UDim2.new(1, -16, 1, -92)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == Players.LocalPlayer and prompt.Name == "ShopPrompt" then
			local shopType = prompt:GetAttribute("ShopType")
			if type(shopType) == "string" and CATEGORY[shopType] then
				activeCategory = shopType
			end
			if hud.IsPanelOpen("Shop") then
				render()
			else
				hud.TogglePanel("Shop")
			end
		end
	end)

	Net.GetRemoteEvent("ShopStockUpdated").OnClientEvent:Connect(function()
		task.spawn(loadStock)
	end)

	task.spawn(loadStock)
	-- El contador solo corre mientras el panel está abierto.
	task.spawn(function()
		while true do
			task.wait(1)
			if timerLabel and hud.IsPanelOpen("Shop") then
				timerLabel.Text = "⏱️ Restock en " .. formatTime(restockAt - os.time())
			end
		end
	end)
end

return ShopController
