--!strict
--[[
	IndexController.lua
	Panel "Índice": catálogo de todas las plantas por zona. Las que aún no
	has conseguido aparecen como "???". El servidor registra los
	descubrimientos (PlantDiscovered); aquí solo se pinta.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local Client = script.Parent.Parent
local UI = require(Client.UI)
local ClientState = require(Client.ClientState)
local FarmArt = require(Client.Modules.FarmArt)

local IndexController = {}

local listFrame: ScrollingFrame

local function refresh()
	UI.ClearList(listFrame)

	local total, found = 0, 0
	for _, zoneId in ipairs(ZoneConfig.Order) do
		for _, plantId in ipairs(PlantConfig.OrderByZone[zoneId] or {}) do
			total += 1
			if ClientState.PlantIndex[plantId] then
				found += 1
			end
		end
	end

	local order = 0
	local header = UI.Card(listFrame, 40, order)
	UI.Label(header, string.format("📖 Índice de plantas  %d/%d", found, total), UDim2.new(1, -16, 1, -10), UDim2.new(0, 8, 0, 5), UI.Colors.Gold)

	for _, zoneId in ipairs(ZoneConfig.Order) do
		local zone = ZoneConfig[zoneId]
		order += 1
		local zoneCard = UI.Card(listFrame, 28, order)
		zoneCard.BackgroundColor3 = UI.Colors.Blue
		UI.Label(zoneCard, zone.displayName, UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4), Color3.new(1, 1, 1))

		for _, plantId in ipairs(PlantConfig.OrderByZone[zoneId] or {}) do
			local data = PlantConfig[plantId]
			local discovered = ClientState.PlantIndex[plantId] == true
			local rarity = RarityConfig[data.rarity]
			order += 1
			local card = UI.Card(listFrame, 64, order)
			if discovered then
				local icon = FarmArt.CreateCropIcon(card, plantId, data.color)
				icon.Position = UDim2.fromOffset(8, 4)
				UI.Label(card, data.displayName, UDim2.new(1, -80, 0, 24), UDim2.fromOffset(68, 8), rarity.color)
				UI.Label(
					card,
					string.format("%s · Vende $%s", rarity.displayName, UI.Money(data.baseSellValue)),
					UDim2.new(1, -80, 0, 18),
					UDim2.fromOffset(68, 36),
					UI.Colors.Muted,
					false
				)
			else
				card.BackgroundColor3 = Color3.fromRGB(176, 160, 122)
				local mark = UI.Label(card, "?", UDim2.fromOffset(52, 52), UDim2.fromOffset(8, 6), UI.Colors.Muted)
				mark.TextXAlignment = Enum.TextXAlignment.Center
				UI.Label(card, "???", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(68, 8), UI.Colors.Muted)
				UI.Label(card, rarity.displayName .. " · sin descubrir", UDim2.new(1, -80, 0, 18), UDim2.fromOffset(68, 36), UI.Colors.Muted, false)
			end
		end
	end
end

function IndexController.Init(hud: any, snapshot: any)
	for plantId, value in pairs(snapshot.plantIndex or {}) do
		if value == true then
			ClientState.PlantIndex[plantId] = true
		end
	end

	local _, list = hud.CreatePanel("Index", "Índice", refresh)
	listFrame = list

	local button = hud.CreateActionButton("IndexButton", "📖", "Índice")
	button.Activated:Connect(function()
		hud.TogglePanel("Index")
	end)
end

return IndexController
