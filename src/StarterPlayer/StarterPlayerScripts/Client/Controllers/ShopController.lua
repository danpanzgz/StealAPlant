--!strict
--[[
	ShopController.lua
	Seed Shop mobile-first: panel a pantalla completa con scroll, tarjetas
	grandes y un botón de compra por item. Toda compra se resuelve con un
	RemoteFunction (BuySeed): el cliente nunca añade semillas al inventario
	por su cuenta, solo refleja lo que el servidor confirme.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)

local ShopController = {}

local buySeedFn = Net.GetRemoteFunction("BuySeed")

local shopFrame: Frame
local listFrame: ScrollingFrame

local function createCard(item: any, parent: Instance)
	local rarityData = RarityConfig[item.rarity]

	local card = Instance.new("Frame")
	card.Name = item.plantId
	card.Size = UDim2.new(1, -16, 0, 76)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 6, 1, 0)
	stripe.BackgroundColor3 = rarityData.color
	stripe.BorderSizePixel = 0
	stripe.Parent = card
	local stripeCorner = Instance.new("UICorner")
	stripeCorner.CornerRadius = UDim.new(0, 10)
	stripeCorner.Parent = stripe

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 20, 0, 8)
	nameLabel.Size = UDim2.new(1, -110, 0, 24)
	nameLabel.Text = item.displayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Position = UDim2.new(0, 20, 0, 34)
	rarityLabel.Size = UDim2.new(1, -110, 0, 18)
	rarityLabel.Text = rarityData.displayName
	rarityLabel.TextColor3 = rarityData.color
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextScaled = true
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = card

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0, 84, 0, 44)
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -12, 0.5, 0)
	buyButton.BackgroundColor3 = Color3.fromRGB(70, 180, 90)
	buyButton.Text = item.seedPrice <= 0 and "FREE" or ("$" .. item.seedPrice)
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextScaled = true
	buyButton.Parent = card

	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 8)
	buyCorner.Parent = buyButton

	buyButton.Activated:Connect(function()
		buyButton.Active = false
		local result = buySeedFn:InvokeServer(item.plantId)
		buyButton.Active = true
		if result and result.success then
			ClientState.AdjustInventory(item.plantId, 1)
			ShopController.HUDController.ShowNotification("Bought " .. item.displayName .. " seed", Color3.fromRGB(120, 255, 140))
		else
			local reason = (result and result.reason) or "error"
			ShopController.HUDController.ShowNotification("Can't buy: " .. reason, Color3.fromRGB(255, 110, 110))
		end
	end)
end

local function buildShopFrame(snapshot: any)
	local screenGui = ShopController.HUDController.GetScreenGui()

	shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopPanel"
	shopFrame.Visible = false
	shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	-- Tamaño relativo (no absoluto) para que se adapte igual de bien a
	-- pantallas de móvil verticales que a PC.
	shopFrame.Size = UDim2.new(0.9, 0, 0.75, 0)
	shopFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	shopFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = shopFrame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -60, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 6)
	title.Text = "Seed Shop"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = shopFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 8)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Parent = shopFrame
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(1, 0)
	closeCorner.Parent = closeButton
	closeButton.Activated:Connect(function()
		shopFrame.Visible = false
	end)

	listFrame = Instance.new("ScrollingFrame")
	listFrame.BackgroundTransparency = 1
	listFrame.Position = UDim2.new(0, 8, 0, 56)
	listFrame.Size = UDim2.new(1, -16, 1, -64)
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.ScrollBarThickness = 6
	listFrame.Parent = shopFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listFrame

	for _, item in ipairs(snapshot.catalog) do
		createCard(item, listFrame)
	end
end

function ShopController.Init(snapshot: any, hudController: any)
	ShopController.HUDController = hudController
	ClientState.SetInventoryFromSnapshot(snapshot.inventory)

	buildShopFrame(snapshot)

	local shopButton = hudController.CreateActionButton("ShopButton", "🌱", "Shop")
	shopButton.Activated:Connect(function()
		shopFrame.Visible = not shopFrame.Visible
	end)
end

return ShopController
