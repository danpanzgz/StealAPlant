--!strict

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
local listFrame: ScrollingFrame
local hud: any
local restockAt = 0
local timerLabel: TextLabel?
local activeCategory = "Seeds"
local refresh: () -> ()
local renderCategoryButtons: () -> ()

local categories = {
	{ id = "Seeds", label = "Semillas", kind = "pack" },
	{ id = "Gear", label = "Herramientas", kind = "gear" },
	{ id = "Pets", label = "Huevos", kind = "petEgg" },
}
local categoryKinds = { Seeds = "pack", Gear = "gear", Pets = "petEgg" }

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function createCard(item: any, order: number)
	local rarity = RarityConfig[item.rarity]
	local card = UI.Card(listFrame, 96, order)
	if rarity then
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 6, 1, 0)
		stripe.ZIndex = card.ZIndex + 1
		stripe.BackgroundColor3 = rarity.color
		stripe.BorderSizePixel = 0
		stripe.Parent = card
		UI.Round(stripe, 8)
	end

	local icon
	if item.kind == "petEgg" then
		icon = FarmArt.CreateEggIcon(card, rarity and rarity.color or UI.Colors.Gold)
	elseif item.kind == "pack" then
		icon = FarmArt.CreateSeedPackIcon(card, rarity and rarity.color or UI.Colors.Green)
	elseif item.kind == "gear" then
		icon = FarmArt.CreateGearIcon(card, item.gearId, rarity and rarity.color or UI.Colors.Grey)
	end
	if icon then
		icon.Position = UDim2.fromOffset(8, 20)
	end

	UI.Label(card, item.displayName, UDim2.new(1, -190, 0, 23), UDim2.new(0, 68, 0, 5))
	local description = UI.Label(
		card,
		(rarity and rarity.displayName or item.rarity) .. " · " .. item.description,
		UDim2.new(1, -190, 0, 38),
		UDim2.new(0, 68, 0, 31),
		rarity and rarity.color or UI.Colors.Muted,
		false
	)
	description.TextWrapped = true
	UI.Label(
		card,
		string.format("Limit %d · %d left this restock", item.limit, item.remaining),
		UDim2.new(1, -190, 0, 18),
		UDim2.new(0, 68, 0, 70),
		UI.Colors.Muted,
		false
	)

	local buttonText = if item.remaining <= 0 then "Agotado" else ("$" .. UI.Money(item.price))
	local button = UI.Button(
		card,
		buttonText,
		if item.remaining <= 0 then UI.Colors.Grey else UI.Colors.Green,
		UDim2.new(0, 106, 0, 42),
		UDim2.new(1, -116, 0.5, -21)
	)
	button.Activated:Connect(function()
		if item.remaining <= 0 then
			return
		end
		button.Active = false
		local result = buyFn:InvokeServer(item.itemId)
		button.Active = true
		if result and result.success then
			hud.Push("Compraste " .. result.displayName, "good")
			task.defer(refresh)
		else
			hud.Push("Compra fallida: " .. tostring(result and result.reason or "error"), "warn")
		end
	end)
end

renderCategoryButtons = function()
	local card = UI.Card(listFrame, 40, -80)
	for index, category in ipairs(categories) do
		local width = 1 / #categories
		local button = UI.Button(
			card,
			category.label,
			if activeCategory == category.id then UI.Colors.Green else UI.Colors.Grey,
			UDim2.new(width, -6, 0, 30),
			UDim2.new((index - 1) * width, 3, 0, 5)
		)
		button.TextSize = 11
		button.Activated:Connect(function()
			activeCategory = category.id
			refresh()
		end)
	end
end

refresh = function()
	local snapshot = snapshotFn:InvokeServer()
	if not snapshot or not snapshot.success then
		hud.Push("No se pudo cargar el stock de la tienda", "warn")
		return
	end
	UI.ClearList(listFrame)
	restockAt = snapshot.nextRestockAt or 0
	local header = UI.Card(listFrame, 44, -100)
	timerLabel = UI.Label(
		header,
		"Stock global · se renueva en " .. formatTime(restockAt - os.time()),
		UDim2.new(1, -16, 1, -10),
		UDim2.new(0, 8, 0, 5),
		UI.Colors.Gold,
		true
	)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	local note = UI.Card(listFrame, 38, -90)
	UI.Label(note, "Stock global · límite personal por reabastecimiento", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4), UI.Colors.Muted, false)
	renderCategoryButtons()

	local filteredItems = {}
	for _, item in ipairs(snapshot.items) do
		if item.kind == categoryKinds[activeCategory] then
			table.insert(filteredItems, item)
		end
	end
	if #filteredItems == 0 then
		local empty = UI.Card(listFrame, 58, 1)
		UI.Label(empty, "No hay artículos. Vuelve después del siguiente reabastecimiento.", UDim2.new(1, -16, 1, -12), UDim2.new(0, 8, 0, 6), UI.Colors.Muted, false)
		return
	end
	for index, item in ipairs(filteredItems) do
		createCard(item, index)
	end
end

function ShopController.Init(_snapshot: any, hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Shop", "Seeds, Eggs & Gear", refresh)
	listFrame = list

	local button = hud.CreateActionButton("ShopButton", "SHOP", "Tienda")
	button.Activated:Connect(function()
		hud.TogglePanel("Shop")
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == Players.LocalPlayer and prompt.Name == "ShopPrompt" then
			local shopType = prompt:GetAttribute("ShopType")
			if type(shopType) == "string" and categoryKinds[shopType] then
				activeCategory = shopType
			end
			hud.TogglePanel("Shop")
		end
	end)

	Net.GetRemoteEvent("ShopStockUpdated").OnClientEvent:Connect(function()
		if hud.IsPanelOpen("Shop") then
			refresh()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if timerLabel and timerLabel.Parent and hud.IsPanelOpen("Shop") then
				timerLabel.Text = "Stock global · se renueva en " .. formatTime(restockAt - os.time())
			end
		end
	end)
end

return ShopController
