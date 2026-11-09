--!strict
--[[
	StoreController.lua
	Panel "Store" (Robux): Game Passes y Developer Products. El cliente solo
	abre el diálogo oficial de compra (MarketplaceService); la concesión la
	hace el servidor (ProcessReceipt / PromptGamePassPurchaseFinished).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)

local StoreController = {}

local snapshotFn = Net.GetRemoteFunction("GetPlayerProfileSnapshot")
local listFrame: ScrollingFrame
local hud: any
local player = Players.LocalPlayer

local function promptId(id: number, isPass: boolean)
	if id == 0 then
		hud.Push("⚙️ Configura el ID en MonetizationConfig", "warn")
		return
	end
	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

local function badge(card: Frame, text: string)
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromOffset(58, 18)
	tag.Position = UDim2.new(1, -66, 0, -4)
	tag.BackgroundColor3 = Color3.fromRGB(214, 62, 62)
	tag.BorderSizePixel = 2
	tag.BorderColor3 = Color3.fromRGB(110, 28, 28)
	tag.Font = Enum.Font.Arcade
	tag.Text = text
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.TextSize = 12
	tag.ZIndex = card.ZIndex + 5
	tag.Parent = card
end

local function render()
	UI.ClearList(listFrame)
	local order = 0

	local function header(text: string)
		order += 1
		local label = UI.Label(listFrame, text, UDim2.new(1, -16, 0, 26), UDim2.new(), UI.Colors.Gold)
		label.LayoutOrder = order
		label.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- Boosts activos (con cuenta atrás aproximada).
	local activeLines = {}
	for stat, endsAt in pairs(ClientState.Boosts) do
		local left = endsAt - os.time()
		if left > 0 then
			table.insert(activeLines, (MonetizationConfig.BoostNames[stat] or stat) .. " " .. UI.Time(left))
		end
	end
	if #activeLines > 0 then
		table.sort(activeLines)
		order += 1
		local card = UI.Card(listFrame, 40, order)
		local label = UI.Label(card, "⚡ Activo: " .. table.concat(activeLines, " · "), UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4), UI.Colors.Green)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = true
	end

	for _, section in ipairs(MonetizationConfig.Sections) do
		local cards = {}
		for _, key in ipairs(section.products) do
			local product = MonetizationConfig.DevProducts[key]
			-- Las ofertas de una sola compra desaparecen cuando ya las tienes.
			if not (product.oneTime and ClientState.OncePurchased[key]) then
				table.insert(cards, product)
			end
		end
		if #cards > 0 then
			header(section.title)
			for _, product in ipairs(cards) do
				order += 1
				local card = UI.Card(listFrame, 84, order)
				UI.Label(card, product.displayName, UDim2.new(1, -130, 0, 24), UDim2.new(0, 12, 0, 6))
				local description = product.description or ("+$" .. UI.Money(product.cash or 0) .. " Cash")
				local body = UI.Label(card, description, UDim2.new(1, -130, 0, 36), UDim2.new(0, 12, 0, 32), UI.Colors.Muted, false)
				body.TextWrapped = true
				body.TextYAlignment = Enum.TextYAlignment.Top
				if product.valueNote then
					UI.Label(card, product.valueNote, UDim2.new(1, -130, 0, 14), UDim2.new(0, 12, 1, -18), UI.Colors.Green, false)
				end
				local button = UI.Button(card, "R$ " .. product.robux, UI.Colors.Blue, UDim2.new(0, 96, 0, 44), UDim2.new(1, -108, 0.5, -22))
				button.Activated:Connect(function()
					promptId(product.id, false)
				end)
				if product.badge then
					badge(card, product.badge)
				end
			end
		end
	end

	header("— Pases (permanentes) —")
	for _, key in ipairs(MonetizationConfig.PassOrder) do
		local pass = MonetizationConfig.GamePasses[key]
		order += 1
		local card = UI.Card(listFrame, 84, order)
		UI.Label(card, pass.displayName, UDim2.new(1, -130, 0, 24), UDim2.new(0, 12, 0, 6))
		local body = UI.Label(card, pass.description, UDim2.new(1, -130, 0, 44), UDim2.new(0, 12, 0, 32), UI.Colors.Muted, false)
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		if ClientState.Passes[key] then
			local tag = UI.Label(card, "✔ Tuyo", UDim2.new(0, 90, 0, 30), UDim2.new(1, -100, 0.5, -15), UI.Colors.Green)
			tag.TextXAlignment = Enum.TextXAlignment.Center
		else
			local button = UI.Button(card, "R$ " .. pass.robux, UI.Colors.Blue, UDim2.new(0, 96, 0, 44), UDim2.new(1, -108, 0.5, -22))
			button.Activated:Connect(function()
				promptId(pass.id, true)
			end)
		end
	end
end

local function refresh()
	local snapshot = snapshotFn:InvokeServer()
	if snapshot and snapshot.success then
		ClientState.Passes = snapshot.passes
		ClientState.Boosts = snapshot.boosts or {}
		ClientState.OncePurchased = snapshot.oncePurchased or {}
	end
	render()
end

function StoreController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Store", "Tienda Robux", refresh)
	listFrame = list

	-- Oferta de bienvenida: un aviso discreto tras unos minutos jugando.
	task.delay(150, function()
		local snapshot = snapshotFn:InvokeServer()
		if snapshot and snapshot.success and not (snapshot.oncePurchased or {}).StarterPack then
			hud.Push("🎁 ¡Oferta de bienvenida! Starter Pack -70% en 💎 Tienda", "good")
		end
	end)

	local button = hud.CreateActionButton("StoreButton", "💎", "Store")
	button.Activated:Connect(function()
		hud.TogglePanel("Store")
	end)
end

return StoreController
