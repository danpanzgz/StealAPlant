--!strict
--[[
	SellController.lua
	Puesto de venta del mapa. Al acercarte y pulsar, ofrece varias opciones:
	la planta que llevas en la mano, todas, comunes y repetidas. Los precios
	salen del servidor (GetSellQuote), que es quien paga.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local PlantInstanceConfig = require(ReplicatedStorage.Shared.Config.PlantInstanceConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)
local Hotbar = require(script.Parent.HotbarController)

local SellController = {}

local quoteFn = Net.GetRemoteFunction("GetSellQuote")
local sellHeldFn = Net.GetRemoteFunction("SellHeld")
local sellAllFn = Net.GetRemoteFunction("SellAll")

local hud: any
local listFrame: ScrollingFrame
local busy = false
local render: (quotes: any, multiplier: number) -> ()

local function heldPlant(): any
	local entry = Hotbar.ActiveEntry
	if not entry or entry.kind ~= "plant" then
		return nil
	end
	for _, plant in ipairs(ClientState.Inventory.plants or {}) do
		if plant.uid == entry.id then
			return plant
		end
	end
	return nil
end

local function load()
	local result = quoteFn:InvokeServer()
	if result and result.success then
		render(result.quotes, result.multiplier or 1)
	elseif result then
		hud.Fail(result.reason)
	end
end

local function row(order: number, title: string, subtitle: string, buttonText: string, enabled: boolean, run: () -> ())
	local card = UI.Card(listFrame, 74, order)
	UI.Label(card, title, UDim2.new(1, -130, 0, 24), UDim2.new(0, 10, 0, 6), UI.Colors.Text, true)
	local sub = UI.Label(card, subtitle, UDim2.new(1, -130, 0, 34), UDim2.new(0, 10, 0, 32), UI.Colors.Muted, false)
	sub.TextWrapped = true
	local button = UI.Button(card, buttonText, if enabled then UI.Colors.Green else UI.Colors.Grey, UDim2.fromOffset(104, 44), UDim2.new(1, -114, 0.5, -22))
	button.TextSize = 13
	button.Activated:Connect(function()
		if busy then
			return
		end
		if not enabled then
			hud.Fail("nothing_to_sell")
			return
		end
		busy = true
		run()
		busy = false
		task.spawn(load)
	end)
end

render = function(quotes: any, multiplier: number)
	UI.UseList(listFrame, 8)
	UI.ClearList(listFrame)

	local plant = heldPlant()
	if plant then
		local data = PlantConfig[plant.plantId]
		local price = math.floor((plant.value or 0) * multiplier)
		row(1, "✋ La que llevas en la mano", PlantInstanceConfig.FormatName(data.displayName, plant.size, plant.mutations or plant.mutation, plant.weight) .. " · $" .. UI.Money(price), "Vender $" .. UI.Money(price), true, function()
			local result = sellHeldFn:InvokeServer(plant.uid)
			if result and result.success then
				hud.Push("💰 Vendida por $" .. UI.Money(result.cashEarned), "good")
			else
				hud.Fail(result and result.reason)
			end
		end)
	else
		row(1, "✋ La que llevas en la mano", "Equipa una planta desde la barra para venderla (verás su precio).", "—", false, function() end)
	end

	local function bulk(order: number, title: string, mode: string, hint: string)
		local quote = quotes[mode]
		local count = quote and quote.count or 0
		local cash = quote and quote.cash or 0
		row(order, title, if count > 0 then string.format("%d plantas · $%s", count, UI.Money(cash)) else hint, if count > 0 then ("Vender $" .. UI.Money(cash)) else "—", count > 0, function()
			local result = sellAllFn:InvokeServer(mode)
			if result and result.success then
				hud.Push(string.format("💰 Vendiste %d plantas por $%s", result.count, UI.Money(result.cashEarned)), "good")
			else
				hud.Fail(result and result.reason)
			end
		end)
	end
	bulk(2, "🌿 Comunes y poco comunes", "common", "No tienes plantas comunes.")
	bulk(3, "♊ Repetidas (guardo la mejor)", "duplicates", "No tienes repetidas.")
	bulk(4, "🧺 Todas las plantas", "all", "No tienes plantas en la mochila.")

	local note = UI.Label(listFrame, "Las plantas colocadas en el jardín no se venden: recógelas antes.", UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 0), UI.Colors.Muted, false)
	note.LayoutOrder = 5
	note.TextWrapped = true
end

function SellController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Sell", "💰 Puesto de venta", function()
		task.spawn(load)
	end)
	listFrame = list
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == Players.LocalPlayer and prompt.Name == "SellPrompt" then
			if hud.IsPanelOpen("Sell") then
				task.spawn(load)
			else
				hud.TogglePanel("Sell")
			end
		end
	end)
end

return SellController
