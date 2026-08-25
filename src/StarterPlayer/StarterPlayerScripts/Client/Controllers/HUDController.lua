--!strict
--[[
	HUDController.lua
	HUD principal, construido 100% por código (sin depender de GUIs
	prediseñadas en Studio) para que todo el proyecto viva en control de
	versiones como texto. Diseño mobile-first: botones grandes, zonas de
	toque generosas, layout que se adapta con UIListLayout/UIScale en vez
	de posiciones absolutas fijas pensadas solo para PC.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HUDController = {}

local screenGui: ScreenGui
local cashLabel: TextLabel
local notificationContainer: Frame

function HUDController.GetScreenGui(): ScreenGui
	return screenGui
end

local function createTopBar()
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(0, 170, 0, 46)
	topBar.Position = UDim2.new(0, 12, 0, 12)
	topBar.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = topBar

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(0, 30, 1, 0)
	icon.Position = UDim2.new(0, 8, 0, 0)
	icon.Text = "💵"
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.Parent = topBar

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.BackgroundTransparency = 1
	cashLabel.Size = UDim2.new(1, -46, 1, 0)
	cashLabel.Position = UDim2.new(0, 42, 0, 0)
	cashLabel.Text = "0"
	cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextScaled = true
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.Parent = topBar
end

local function createNotificationLayer()
	notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "Notifications"
	notificationContainer.BackgroundTransparency = 1
	notificationContainer.AnchorPoint = Vector2.new(0.5, 0)
	notificationContainer.Position = UDim2.new(0.5, 0, 0, 70)
	notificationContainer.Size = UDim2.new(0, 280, 0, 200)
	notificationContainer.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 6)
	layout.Parent = notificationContainer
end

-- Feedback instantáneo y no intrusivo: un toast que sube y se desvanece.
-- Se usa para cosechas, resultados de robo, recompensas, etc.
function HUDController.ShowNotification(text: string, color: Color3?)
	if not notificationContainer then
		return
	end

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	label.BackgroundTransparency = 0.25
	label.Size = UDim2.new(0, 260, 0, 34)
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = notificationContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	task.delay(1.6, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

function HUDController.UpdateCash(cash: number)
	if cashLabel then
		cashLabel.Text = string.format("%d", cash)
	end
end

-- Contenedor reservado para botones de acción (Shop, Inventory, Garden
-- Upgrade...). Cada Controller añade su propio botón aquí, así el HUD no
-- necesita conocer a los demás Controllers.
function HUDController.GetActionBar(): Frame
	local existing = screenGui:FindFirstChild("ActionBar")
	if existing then
		return existing :: Frame
	end

	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(1, 1)
	-- Esquina inferior derecha con margen generoso: zona cómoda para el
	-- pulgar derecho en móvil, y no molesta con los controles por defecto.
	actionBar.Position = UDim2.new(1, -12, 1, -16)
	actionBar.Size = UDim2.new(0, 120, 0, 260)
	actionBar.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 10)
	layout.Parent = actionBar

	return actionBar
end

-- Crea un botón de acción estándar (tamaño táctil mínimo 56x56 recomendado
-- por accesibilidad móvil) y lo añade a la ActionBar.
function HUDController.CreateActionButton(name: string, emoji: string, labelText: string): TextButton
	local actionBar = HUDController.GetActionBar()

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 64, 0, 64)
	button.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	button.BackgroundTransparency = 0.05
	button.AutoButtonColor = true
	button.Text = emoji .. "\n" .. labelText
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = actionBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	return button
end

function HUDController.Init(snapshot: any)
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false -- respeta la barra de estado/notch en móvil
	screenGui.Parent = playerGui

	createTopBar()
	createNotificationLayer()

	HUDController.UpdateCash(snapshot.cash)

	local cashUpdatedEvent = Net.GetRemoteEvent("CashUpdated")
	cashUpdatedEvent.OnClientEvent:Connect(function(payload)
		HUDController.UpdateCash(payload.cash)
	end)

	local plantHarvestedEvent = Net.GetRemoteEvent("PlantHarvested")
	plantHarvestedEvent.OnClientEvent:Connect(function(payload)
		HUDController.ShowNotification("+" .. payload.cashEarned .. " Cash — " .. payload.plantId .. (payload.mutation and (" ✨" .. payload.mutation) or ""), Color3.fromRGB(120, 255, 140))
	end)
end

return HUDController
