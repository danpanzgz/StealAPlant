--!strict
--[[
	RebirthController.lua
	Botón fijo de Renacer + panel con el requisito (cash + planta a sacrificar)
	y lo que se gana (cobro x2/x3/x4, suerte x2, huecos, palo mejor).
	Todo lo decide el servidor; aquí solo se muestra y se pide.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UI = require(script.Parent.Parent.UI)
local FarmArt = require(script.Parent.Parent.Modules.FarmArt)

local RebirthController = {}

local infoFn = Net.GetRemoteFunction("GetRebirthInfo")
local rebirthFn = Net.GetRemoteFunction("RebirthPlayer")

local hud: any
local listFrame: ScrollingFrame
local busy = false
local render: (info: any) -> ()

local function line(parent: Instance, order: number, icon: string, text: string, color: Color3?)
	local card = UI.Card(parent, 40, order)
	UI.Label(card, icon .. "  " .. text, UDim2.new(1, -16, 1, -8), UDim2.new(0, 10, 0, 4), color or UI.Colors.Text, false)
end

local function refresh()
	local result = infoFn:InvokeServer()
	if result and result.success then
		render(result.info)
	elseif result then
		hud.Fail(result.reason)
	end
end

render = function(info: any)
	UI.UseList(listFrame, 8)
	UI.ClearList(listFrame)

	local head = UI.Card(listFrame, 64, 1)
	local title = UI.Label(head, string.format("Renacimiento %d → %d", info.rebirths, info.rebirths + 1), UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 6), UI.Colors.Gold, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local sub = UI.Label(head, "Empiezas de cero, pero con premios permanentes", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 36), UI.Colors.Muted, false)
	sub.TextXAlignment = Enum.TextXAlignment.Center

	-- Requisitos
	local reqTitle = UI.Card(listFrame, 30, 2)
	UI.Label(reqTitle, "REQUISITOS", UDim2.new(1, -16, 1, -4), UDim2.new(0, 8, 0, 2), UI.Colors.Muted, true)

	local enoughCash = info.cash >= info.cost
	line(listFrame, 3, if enoughCash then "✅" else "❌", "Dinero: $" .. UI.Money(info.cost) .. " (tienes $" .. UI.Money(info.cash) .. ")", if enoughCash then UI.Colors.Text else Color3.fromRGB(190, 70, 60))

	local sacrificeCard = UI.Card(listFrame, 74, 4)
	local plant = PlantConfig[info.sacrificeId]
	if plant then
		local icon = FarmArt.CreateCropIcon(sacrificeCard, info.sacrificeId, plant.color)
		icon.Position = UDim2.fromOffset(8, 8)
	end
	local rarity = plant and RarityConfig[plant.rarity]
	UI.Label(sacrificeCard, (if info.sacrificeOwned then "✅ " else "❌ ") .. "Sacrificar: " .. tostring(info.sacrificeName), UDim2.new(1, -86, 0, 26), UDim2.new(0, 72, 0, 8), rarity and rarity.color or UI.Colors.Text)
	UI.Label(sacrificeCard, if info.sacrificeOwned then "La tienes en la mochila" else "Debe estar en tu mochila (no colocada). Se gasta al renacer.", UDim2.new(1, -86, 0, 34), UDim2.new(0, 72, 0, 34), UI.Colors.Muted, false)

	-- Premios
	local rewardTitle = UI.Card(listFrame, 30, 5)
	UI.Label(rewardTitle, "PREMIOS", UDim2.new(1, -16, 1, -4), UDim2.new(0, 8, 0, 2), UI.Colors.Muted, true)
	line(listFrame, 6, "💰", string.format("Cobras x%d (ahora x%d)", info.nextMultiplier, info.multiplier), UI.Colors.Green)
	line(listFrame, 7, "🍀", string.format("Suerte x%d (ahora x%d)", info.nextLuck, info.luck), UI.Colors.Green)
	line(listFrame, 8, "🌿", string.format("Huecos de plantar: %d (ahora %d)", info.nextPlots, info.plots), UI.Colors.Green)
	line(listFrame, 9, "🪵", "Palo nuevo: " .. tostring(info.nextStick), UI.Colors.Green)

	local ready = enoughCash and info.sacrificeOwned
	local button = UI.Button(listFrame, if ready then "♻️ ¡RENACER!" else "Aún no cumples los requisitos", if ready then UI.Colors.Green else UI.Colors.Grey, UDim2.new(1, -16, 0, 52), UDim2.new(0, 0, 0, 0))
	button.LayoutOrder = 10
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local result = rebirthFn:InvokeServer()
		busy = false
		if result and result.success then
			hud.TogglePanel("Rebirth")
			hud.Banner(string.format("♻️ ¡RENACISTE! Ahora cobras x%d", result.rebirthCount + 1), Color3.fromRGB(190, 255, 190), 4)
		else
			hud.Fail(result and result.reason)
			task.defer(refresh)
		end
	end)
end

function RebirthController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Rebirth", "Renacer", refresh)
	listFrame = list
	local button = hud.CreateActionButton("RebirthButton", "♻️", "Renacer")
	button.Activated:Connect(function()
		hud.TogglePanel("Rebirth")
	end)
end

return RebirthController
