--!strict
--[[
	GardenController.lua
	Panel "Garden": mejora de nivel del jardín y defensas (alarmas, vallas,
	gnomos cómicos). Todo se valida en servidor; aquí solo se pide y se pinta.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)
local DefenseConfig: any = require(ReplicatedStorage.Shared.Config.DefenseConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)

local GardenController = {}

local snapshotFn = Net.GetRemoteFunction("GetPlayerProfileSnapshot")
local upgradeFn = Net.GetRemoteFunction("UpgradeGarden")
local placeDefenseFn = Net.GetRemoteFunction("PlaceDefense")
local toggleShieldFn = Net.GetRemoteFunction("ToggleGardenShield")

local listFrame: ScrollingFrame
local hud: any
local refresh: () -> ()
local shieldActiveUntil = 0

local REASONS = {
	not_enough_cash = "No tienes Cash suficiente",
	max_level = "Nivel máximo",
	no_free_slot = "Sin slots libres: mejora el jardín",
	rate_limited = "Más despacio 😅",
	shield_cooldown = "El domo está recargando",
	too_far_from_garden = "Acércate a tu jardín para usar el domo",
	carrying_stolen_plant = "Entrega primero la flor que estás llevando",
}

local function render()
	UI.ClearList(listFrame)

	local level = ClientState.GardenLevel
	local levelData = GardenConfig.Levels[level]
	local nextData = GardenConfig.Levels[level + 1]

	-- Mejora de jardín
	local card = UI.Card(listFrame, 84, 1)
	UI.Label(card, "🏡 " .. levelData.displayName .. " (Nv." .. level .. ")", UDim2.new(1, -130, 0, 24), UDim2.new(0, 12, 0, 6))
	UI.Label(card, levelData.plotCount .. " parcelas · " .. levelData.defenseSlots .. " slots de defensa", UDim2.new(1, -130, 0, 18), UDim2.new(0, 12, 0, 32), UI.Colors.Muted, false)
	if nextData then
		UI.Label(card, "Siguiente: " .. nextData.plotCount .. " parcelas, " .. nextData.defenseSlots .. " defensas", UDim2.new(1, -130, 0, 16), UDim2.new(0, 12, 0, 54), UI.Colors.Muted, false)
		local button = UI.Button(card, "⬆ $" .. UI.Money(nextData.upgradePrice), UI.Colors.Blue, UDim2.new(0, 108, 0, 48), UDim2.new(1, -120, 0.5, -24))
		button.Activated:Connect(function()
			button.Active = false
			local result = upgradeFn:InvokeServer()
			button.Active = true
			if result and result.success then
				ClientState.GardenLevel = result.newLevel
				hud.Push("🎉 ¡Jardín mejorado!", "good")
				render()
			else
				local reason = result and result.reason or "error"
				hud.Push(REASONS[reason] or reason, "alarm")
			end
		end)
	else
		local tag = UI.Label(card, "MAX ⭐", UDim2.new(0, 90, 0, 30), UDim2.new(1, -100, 0.5, -15), UI.Colors.Gold)
		tag.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- Defensas instaladas
	local installed = UI.Card(listFrame, 70, 2)
	local names = {}
	for _, entry in ipairs(ClientState.Defenses) do
		local d = DefenseConfig[entry.defenseId]
		if d then
			table.insert(names, d.emoji .. " " .. d.displayName)
		end
	end
	UI.Label(installed, "Defensas " .. #names .. "/" .. levelData.defenseSlots, UDim2.new(1, -16, 0, 22), UDim2.new(0, 12, 0, 6), UI.Colors.Gold)
	UI.Label(installed, if #names > 0 then table.concat(names, ", ") else "Ninguna. ¡Protege tus plantas!", UDim2.new(1, -16, 0, 34), UDim2.new(0, 12, 0, 30), UI.Colors.Muted, false)

	-- Catálogo de defensas
	for i, defenseId in ipairs(DefenseConfig.Order) do
		local d = DefenseConfig[defenseId]
		local row = UI.Card(listFrame, 76, 2 + i)
		UI.Label(row, d.emoji .. " " .. d.displayName, UDim2.new(1, -120, 0, 24), UDim2.new(0, 12, 0, 6))
		UI.Label(row, d.description, UDim2.new(1, -120, 0, 18), UDim2.new(0, 12, 0, 32), UI.Colors.Muted, false)
		UI.Label(row, "Robos -" .. math.floor(d.stealChanceReduction * 100) .. "% de éxito", UDim2.new(1, -120, 0, 16), UDim2.new(0, 12, 0, 54), UI.Colors.Green, false)

		local button = UI.Button(row, "$" .. UI.Money(d.price), UI.Colors.Green, UDim2.new(0, 84, 0, 44), UDim2.new(1, -96, 0.5, -22))
		button.Activated:Connect(function()
			button.Active = false
			local result = placeDefenseFn:InvokeServer(defenseId)
			button.Active = true
			if result and result.success then
				hud.Push("🛡️ " .. d.displayName .. " colocada", "good")
				refresh()
			else
				local reason = result and result.reason or "error"
				hud.Push(REASONS[reason] or reason, "alarm")
			end
		end)
	end

	local shieldCard = UI.Card(listFrame, 74, 20)
	local shieldIsActive = shieldActiveUntil > os.time()
	UI.Label(
		shieldCard,
		shieldIsActive and ("Domo activo · " .. math.max(0, shieldActiveUntil - os.time()) .. "s")
			or "Domo protector · 45s de protección",
		UDim2.new(1, -140, 0, 25),
		UDim2.new(0, 12, 0, 8),
		shieldIsActive and UI.Colors.Blue or UI.Colors.Gold
	)
	UI.Label(shieldCard, "Expulsa visitantes y bloquea los robos.", UDim2.new(1, -140, 0, 22), UDim2.new(0, 12, 0, 40), UI.Colors.Muted, false)
	local shieldButton = UI.Button(
		shieldCard,
		shieldIsActive and "Apagar" or "Activar",
		shieldIsActive and UI.Colors.Grey or UI.Colors.Blue,
		UDim2.new(0, 112, 0, 40),
		UDim2.new(1, -122, 0.5, -20)
	)
	shieldButton.TextSize = 12
	shieldButton.Activated:Connect(function()
		local result = toggleShieldFn:InvokeServer()
		if result and result.success then
			shieldActiveUntil = if result.state == "activated" then os.time() + 45 else 0
			hud.Push(result.state == "activated" and "Domo protector activado" or "Domo protector apagado", "good")
			render()
		else
			local reason = result and result.reason or "error"
			hud.Push(REASONS[reason] or reason, "warn")
		end
	end)

	local tip = UI.Card(listFrame, 44, 21)
	UI.Label(tip, "Escudo al entrar y tras un robo. Cooldown de robo: " .. GameConfig.StealCooldown .. "s", UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
end

refresh = function()
	local snapshot = snapshotFn:InvokeServer()
	if snapshot and snapshot.success then
		ClientState.GardenLevel = snapshot.gardenLevel
		ClientState.Defenses = snapshot.defenses
		shieldActiveUntil = snapshot.gardenShieldUntil or 0
	end
	render()
end

function GardenController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Garden", "Mi jardín", refresh)
	listFrame = list

	local button = hud.CreateActionButton("GardenButton", "🏡", "Garden")
	button.Activated:Connect(function()
		hud.TogglePanel("Garden")
	end)
end

return GardenController
