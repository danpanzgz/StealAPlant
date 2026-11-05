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

local function render()
	UI.ClearList(listFrame)
	local order = 0

	local function header(text: string)
		order += 1
		local label = UI.Label(listFrame, text, UDim2.new(1, -16, 0, 24), UDim2.new(), UI.Colors.Gold)
		label.LayoutOrder = order
		label.TextXAlignment = Enum.TextXAlignment.Center
	end

	header("— Pases (permanentes) —")
	for _, key in ipairs(MonetizationConfig.PassOrder) do
		local pass = MonetizationConfig.GamePasses[key]
		order += 1
		local card = UI.Card(listFrame, 70, order)
		UI.Label(card, pass.displayName, UDim2.new(1, -130, 0, 24), UDim2.new(0, 12, 0, 6))
		UI.Label(card, pass.description, UDim2.new(1, -130, 0, 34), UDim2.new(0, 12, 0, 30), UI.Colors.Muted, false)
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

	header("— Paquetes de Cash —")
	for _, key in ipairs(MonetizationConfig.ProductOrder) do
		local product = MonetizationConfig.DevProducts[key]
		order += 1
		local card = UI.Card(listFrame, 64, order)
		UI.Label(card, product.displayName, UDim2.new(1, -130, 0, 24), UDim2.new(0, 12, 0, 8))
		UI.Label(card, "+$" .. UI.Money(product.cash) .. " Cash", UDim2.new(1, -130, 0, 20), UDim2.new(0, 12, 0, 34), UI.Colors.Green, false)
		local button = UI.Button(card, "R$ " .. product.robux, UI.Colors.Blue, UDim2.new(0, 96, 0, 44), UDim2.new(1, -108, 0.5, -22))
		button.Activated:Connect(function()
			promptId(product.id, false)
		end)
	end
end

local function refresh()
	local snapshot = snapshotFn:InvokeServer()
	if snapshot and snapshot.success then
		ClientState.Passes = snapshot.passes
	end
	render()
end

function StoreController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Store", "Tienda Robux", refresh)
	listFrame = list

	local button = hud.CreateActionButton("StoreButton", "💎", "Store")
	button.Activated:Connect(function()
		hud.TogglePanel("Store")
	end)
end

return StoreController
