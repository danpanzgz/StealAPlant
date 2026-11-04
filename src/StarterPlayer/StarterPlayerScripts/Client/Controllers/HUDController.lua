--!strict
--[[
	HUDController.lua
	HUD principal construido por código. Mobile-first:
	  - Cash arriba a la izquierda, banner de evento arriba a la derecha.
	  - Botones de acción en una cuadrícula 2x3 a la izquierda (no tapa el
	    joystick ni el botón de salto).
	  - Paneles grandes y relativos, con scroll, de uno en uno.
	  - Notificaciones toast, alarma de robo suave (no violenta).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)

local Client = script.Parent.Parent
local ClientState = require(Client.ClientState)
local UI = require(Client.UI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local HUDController = {}

local screenGui: ScreenGui

local function getViewportSize(): Vector2
	if Camera then
		return Camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function getDeviceProfile()
	local viewport = getViewportSize()
	local shortSide = math.min(viewport.X, viewport.Y)
	if UserInputService.TouchEnabled and shortSide <= 600 then
		return "mobile"
	end
	if UserInputService.TouchEnabled then
		return "tablet"
	end
	if viewport.X <= 820 then
		return "tablet"
	end
	return "desktop"
end
local cashLabel: TextLabel
local notificationContainer: Frame
local eventBanner: TextLabel
local alarmOverlay: Frame
local alarmLabel: TextLabel

local panels: { [string]: { frame: Frame, onOpen: (() -> ())? } } = {}
local actionOrder = 0
local eventToken = 0
local alarmToken = 0
local rainPart: Part?

local KIND_COLORS = {
	good = Color3.fromRGB(120, 255, 140),
	warn = Color3.fromRGB(255, 200, 90),
	alarm = Color3.fromRGB(255, 110, 110),
	social = Color3.fromRGB(140, 200, 255),
	event = Color3.fromRGB(255, 230, 120),
	info = Color3.fromRGB(255, 255, 255),
}

function HUDController.GetScreenGui(): ScreenGui
	return screenGui
end

local function createTopBar()
	local profile = getDeviceProfile()
	local width = if profile == "mobile" then 164 else if profile == "tablet" then 186 else 204
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = UI.Colors.Green
	topBar.BorderSizePixel = 4
	topBar.BorderColor3 = Color3.fromRGB(74, 48, 30)
	topBar.Size = UDim2.new(0, width, 0, 52)
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 16)
	topBar.Parent = screenGui
	local iconPlate = Instance.new("Frame")
	iconPlate.Name = "CashIconPlate"
	iconPlate.Size = UDim2.fromOffset(36, 36)
	iconPlate.Position = UDim2.fromOffset(8, 8)
	iconPlate.BackgroundColor3 = UI.Colors.Gold
	iconPlate.BorderSizePixel = 2
	iconPlate.BorderColor3 = Color3.fromRGB(74, 48, 30)
	iconPlate.Parent = topBar

	local function pixel(name: string, size: UDim2, position: UDim2, color: Color3)
		local block = Instance.new("Frame")
		block.Name = name
		block.Size = size
		block.Position = position
		block.BackgroundColor3 = color
		block.BorderSizePixel = 1
		block.BorderColor3 = Color3.fromRGB(74, 48, 30)
		block.ZIndex = iconPlate.ZIndex + 1
		block.Parent = iconPlate
	end
	pixel("PetalTop", UDim2.fromOffset(10, 10), UDim2.fromOffset(13, 3), Color3.fromRGB(255, 235, 169))
	pixel("PetalLeft", UDim2.fromOffset(10, 10), UDim2.fromOffset(3, 13), Color3.fromRGB(255, 235, 169))
	pixel("PetalRight", UDim2.fromOffset(10, 10), UDim2.fromOffset(23, 13), Color3.fromRGB(255, 235, 169))
	pixel("PetalBottom", UDim2.fromOffset(10, 10), UDim2.fromOffset(13, 23), Color3.fromRGB(255, 235, 169))
	pixel("FlowerCenter", UDim2.fromOffset(8, 8), UDim2.fromOffset(14, 14), Color3.fromRGB(110, 75, 43))
	pixel("Leaf", UDim2.fromOffset(8, 5), UDim2.fromOffset(22, 27), Color3.fromRGB(79, 125, 55))

	local caption = UI.Label(topBar, "CASH DE GRANJA", UDim2.new(1, -58, 0, 15), UDim2.new(0, 52, 0, 5), Color3.fromRGB(242, 222, 164), true)
	caption.TextSize = 10
	caption.TextScaled = false
	cashLabel = UI.Label(topBar, "0", UDim2.new(1, -60, 0, 27), UDim2.new(0, 52, 0, 19), Color3.fromRGB(255, 255, 255), true)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextScaled = false
	cashLabel.TextSize = if profile == "mobile" then 20 else 22
	cashLabel.Font = Enum.Font.GothamBold
end

local function createNotificationLayer()
	notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "Notifications"
	notificationContainer.BackgroundTransparency = 1
	local viewport = getViewportSize()
	local touchDevice = UserInputService.TouchEnabled
	local mobile = getDeviceProfile() == "mobile"
	local landscapeMobile = mobile and viewport.X > viewport.Y
	if landscapeMobile then
		notificationContainer.AnchorPoint = Vector2.new(0, 1)
		notificationContainer.Position = UDim2.new(0, 154, 1, -96)
		notificationContainer.Size = UDim2.new(1, -166, 0, 160)
	else
		notificationContainer.AnchorPoint = Vector2.new(0.5, if touchDevice then 1 else 0)
		notificationContainer.Position = if touchDevice then UDim2.new(0.5, 0, 1, -96) else UDim2.new(0.5, 0, 0, 64)
		notificationContainer.Size = if mobile then UDim2.new(1, -24, 0, 160) else UDim2.new(0, 300, 0, 220)
	end
	notificationContainer.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, 6)
	layout.Parent = notificationContainer
end

local function createEventBanner()
	local profile = getDeviceProfile()
	local width = if profile == "mobile" then 150 else 190
	eventBanner = Instance.new("TextLabel")
	eventBanner.Name = "EventBanner"
	eventBanner.Visible = false
	eventBanner.AnchorPoint = if profile == "mobile" then Vector2.new(0.5, 0) else Vector2.new(1, 0)
	eventBanner.Position = if profile == "mobile" then UDim2.new(0.5, 0, 0, 74) else UDim2.new(1, -14, 0, 12)
	eventBanner.Size = UDim2.new(0, width, 0, 46)
	eventBanner.BackgroundColor3 = UI.Colors.Panel
	eventBanner.BorderSizePixel = 3
	eventBanner.BorderColor3 = UI.Colors.Gold
	eventBanner.TextColor3 = Color3.fromRGB(255, 220, 128)
	eventBanner.Font = Enum.Font.Arcade
	eventBanner.TextScaled = true
	eventBanner.Text = ""
	eventBanner.Parent = screenGui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = eventBanner
end

local function createAlarm()
	alarmOverlay = Instance.new("Frame")
	alarmOverlay.Name = "AlarmOverlay"
	alarmOverlay.Visible = false
	alarmOverlay.Active = false
	alarmOverlay.Size = UDim2.fromScale(1, 1)
	alarmOverlay.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	alarmOverlay.BackgroundTransparency = 1
	alarmOverlay.BorderSizePixel = 0
	alarmOverlay.ZIndex = 50
	alarmOverlay.Parent = screenGui

	alarmLabel = Instance.new("TextLabel")
	alarmLabel.BackgroundTransparency = 1
	alarmLabel.AnchorPoint = Vector2.new(0.5, 0)
	alarmLabel.Position = UDim2.new(0.5, 0, 0.18, 0)
	alarmLabel.Size = UDim2.new(0, 300, 0, 40)
	alarmLabel.Text = "🚨 ¡Intentan robar tu jardín!"
	alarmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	alarmLabel.TextStrokeTransparency = 0.2
	alarmLabel.Font = Enum.Font.GothamBold
	alarmLabel.TextScaled = true
	alarmLabel.ZIndex = 51
	alarmLabel.Parent = alarmOverlay
end

-- Pulso suave de pantalla roja (lento y tenue; nada violento).
function HUDController.Alarm(duration: number)
	alarmToken += 1
	local token = alarmToken
	alarmOverlay.Visible = true
	task.spawn(function()
		local endsAt = os.clock() + duration
		local up = true
		while os.clock() < endsAt and token == alarmToken do
			TweenService:Create(alarmOverlay, TweenInfo.new(0.6), { BackgroundTransparency = if up then 0.85 else 0.95 }):Play()
			up = not up
			task.wait(0.6)
		end
		if token == alarmToken then
			alarmOverlay.BackgroundTransparency = 1
			alarmOverlay.Visible = false
		end
	end)
end

function HUDController.ShowNotification(text: string, color: Color3?)
	if not notificationContainer then
		return
	end

	local mobile = getDeviceProfile() == "mobile"
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = UI.Colors.Panel
	label.BorderSizePixel = 2
	label.BorderColor3 = UI.Colors.Gold
	label.Size = if mobile then UDim2.new(1, -8, 0, 52) else UDim2.new(0, 290, 0, 34)
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.Arcade
	label.TextSize = 14
	label.TextScaled = not mobile
	label.TextWrapped = mobile
	label.Parent = notificationContainer
	UI.Round(label, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = label

	task.delay(2.6, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end)
end

function HUDController.Push(text: string, kind: string?)
	HUDController.ShowNotification(text, KIND_COLORS[kind or "info"] or KIND_COLORS.info)
end

function HUDController.UpdateCash(cash: number)
	ClientState.Cash = cash
	if cashLabel then
		cashLabel.Text = UI.Money(cash)
	end
end

-- state: { active, displayName, secondsLeft }
function HUDController.SetEvent(state: any)
	eventToken += 1
	local token = eventToken
	local raining = state and state.active and state.id == "RainShower"
	if raining and not rainPart then
		local rain = Instance.new("Part")
		rain.Name = "LocalRainEmitter"
		rain.Anchored = true
		rain.CanCollide = false
		rain.CanTouch = false
		rain.CanQuery = false
		rain.Transparency = 1
		rain.Size = Vector3.one
		rain.Parent = workspace
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Rain"
		emitter.Enabled = true
		emitter.Rate = 240
		emitter.Lifetime = NumberRange.new(0.65, 1)
		emitter.Speed = NumberRange.new(48, 62)
		emitter.Acceleration = Vector3.new(0, -30, 0)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.SpreadAngle = Vector2.new(6, 6)
		emitter.Size = NumberSequence.new(0.08)
		emitter.Transparency = NumberSequence.new(0.15)
		emitter.Color = ColorSequence.new(Color3.fromRGB(177, 220, 255))
		emitter.LightEmission = 0.45
		emitter.Parent = rain
		rainPart = rain
	elseif not raining and rainPart then
		rainPart:Destroy()
		rainPart = nil
	end

	if not state or not state.active then
		eventBanner.Visible = false
		return
	end
	local endsAt = os.clock() + state.secondsLeft
	eventBanner.Visible = true
	task.spawn(function()
		while token == eventToken and os.clock() < endsAt do
			eventBanner.Text = state.displayName .. " " .. UI.Time(endsAt - os.clock())
			task.wait(1)
		end
		if token == eventToken then
			eventBanner.Visible = false
		end
	end)
end

-- ===== Botones de acción y paneles =====

function HUDController.GetActionBar(): Frame
	local existing = screenGui:FindFirstChild("ActionBar")
	if existing then
		return existing :: Frame
	end

	local profile = getDeviceProfile()
	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.BackgroundTransparency = 1
	local cellHeight = if profile == "mobile" then 48 else if profile == "tablet" then 56 else 60
	actionBar.Size = UDim2.new(0, if profile == "mobile" then 140 else if profile == "tablet" then 164 else 180, 0, cellHeight * 3 + 16)
	if UserInputService.TouchEnabled then
		actionBar.Position = UDim2.new(0, 14, 0, 70)
	else
		actionBar.AnchorPoint = Vector2.new(0, 1)
		actionBar.Position = UDim2.new(0, 14, 1, -18)
	end
	actionBar.Parent = screenGui

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, if profile == "mobile" then 56 else if profile == "tablet" then 62 else 68, 0, cellHeight)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.FillDirectionMaxCells = 2
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = actionBar

	return actionBar
end

function HUDController.CreateActionButton(name: string, emoji: string, labelText: string): TextButton
	local actionBar = HUDController.GetActionBar()
	actionOrder += 1
	if actionOrder > 6 then
		local profile = getDeviceProfile()
		local rowHeight = if profile == "mobile" then 48 else if profile == "tablet" then 56 else 60
		actionBar.Size = UDim2.new(actionBar.Size.X.Scale, actionBar.Size.X.Offset, 0, rowHeight * math.ceil(actionOrder / 2) + 32)
	end

	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = actionOrder
	button.BackgroundColor3 = UI.Colors.Green
	button.BorderSizePixel = 3
	button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	button.AutoButtonColor = false
	button.Selectable = true
	local iconLabels = {
		ShopButton = "SHOP",
		BagButton = "BAG",
		GardenButton = "YARD",
		QuestButton = "TASK",
		TopButton = "TOP",
		StoreButton = "PASS",
		SlapButton = "SLAP",
	}
	button.Text = (iconLabels[name] or emoji) .. "\n" .. labelText
	button.TextColor3 = Color3.fromRGB(255, 244, 211)
	button.Font = Enum.Font.Arcade
	button.TextScaled = true
	button.TextWrapped = true
	button.TextStrokeColor3 = Color3.fromRGB(19, 30, 24)
	button.TextStrokeTransparency = 0.75
	button.Parent = actionBar

	local buttonColors = {
		ShopButton = Color3.fromRGB(103, 151, 68),
		BagButton = Color3.fromRGB(79, 133, 151),
		GardenButton = Color3.fromRGB(91, 145, 67),
		QuestButton = Color3.fromRGB(174, 126, 53),
		TopButton = Color3.fromRGB(127, 93, 59),
		StoreButton = Color3.fromRGB(126, 105, 154),
		SlapButton = Color3.fromRGB(168, 92, 63),
	}
	local accent = buttonColors[name] or Color3.fromRGB(95, 155, 112)
	button.BackgroundColor3 = accent
	button.SelectionGained:Connect(function()
		button.BorderColor3 = UI.Colors.Gold
	end)
	button.SelectionLost:Connect(function()
		button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	end)

	button.MouseEnter:Connect(function()
		button.BorderColor3 = UI.Colors.Gold
	end)
	button.MouseLeave:Connect(function()
		button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.2)
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = accent
	end)

	return button
end

function HUDController.CreatePanel(name: string, titleText: string, onOpen: (() -> ())?): (Frame, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Panel"
	frame.Visible = false
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0.92, 0, 0.8, 0)
	frame.BackgroundColor3 = UI.Colors.Panel
	frame.BorderSizePixel = 4
	frame.BorderColor3 = UI.Colors.Gold
	frame.ZIndex = 5
	frame.Parent = screenGui

	local headerAccent = Instance.new("Frame")
	headerAccent.Name = "HeaderAccent"
	headerAccent.Size = UDim2.new(1, -24, 0, 3)
	headerAccent.Position = UDim2.new(0, 12, 0, 50)
	headerAccent.BackgroundColor3 = UI.Colors.Gold
	headerAccent.BorderSizePixel = 0
	headerAccent.ZIndex = frame.ZIndex + 1
	headerAccent.Parent = frame

	local profile = getDeviceProfile()
	local limitSize = if profile == "mobile" then Vector2.new(390, 520) else if profile == "tablet" then Vector2.new(600, 620) else Vector2.new(720, 680)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = limitSize
	limit.Parent = frame

	local title = UI.Label(frame, titleText, UDim2.new(1, -74, 0, 36), UDim2.new(0, 18, 0, 8), Color3.fromRGB(255, 243, 204), true)
	title.TextScaled = false
	title.TextSize = if profile == "mobile" then 19 else 22

	local close = UI.Button(frame, "X", UI.Colors.Grey, UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 8))
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 8, 0, 62)
	list.Size = UDim2.new(1, -16, 1, -70)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.BorderSizePixel = 0
	list.ZIndex = frame.ZIndex + 1
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	panels[name] = { frame = frame, onOpen = onOpen }
	return frame, list
end

function HUDController.TogglePanel(name: string)
	local target = panels[name]
	if not target then
		return
	end
	local willOpen = not target.frame.Visible
	for _, entry in pairs(panels) do
		entry.frame.Visible = false
	end
	if willOpen then
		target.frame.Visible = true
		if target.onOpen then
			task.spawn(target.onOpen)
		end
	end
end

function HUDController.IsPanelOpen(name: string): boolean
	local target = panels[name]
	return target ~= nil and target.frame.Visible
end

function HUDController.Init(snapshot: any)
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	createTopBar()
	createNotificationLayer()
	createEventBanner()
	createAlarm()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if rainPart and camera then
			rainPart.CFrame = camera.CFrame * CFrame.new(0, 20, -8)
		end
	end)

	ClientState.GardenLevel = snapshot.gardenLevel
	HUDController.UpdateCash(snapshot.cash)
	HUDController.SetEvent(snapshot.event)

	Net.GetRemoteEvent("CashUpdated").OnClientEvent:Connect(function(payload)
		HUDController.UpdateCash(payload.cash)
	end)

	Net.GetRemoteEvent("PlantHarvested").OnClientEvent:Connect(function(payload)
		local mutation = if payload.mutation then (" ✨" .. payload.mutation .. "!") else ""
		local plantData = payload.plant
		local plant = PlantConfig[payload.plantId]
		HUDController.Push(
			"🌼 " .. (plant and plant.displayName or payload.plantId) .. mutation
				.. " se añadió a tu colección"
				.. (plantData and (" · vender $" .. UI.Money(plantData.value) .. " · $" .. UI.Money(plantData.incomePerMinute) .. "/min") or ""),
			"good"
		)
	end)

	Net.GetRemoteEvent("NotificationPush").OnClientEvent:Connect(function(payload)
		HUDController.Push(payload.text, payload.kind)
	end)

	Net.GetRemoteEvent("GardenAlarmTriggered").OnClientEvent:Connect(function(payload)
		HUDController.Alarm(payload.duration or 6)
	end)

	Net.GetRemoteEvent("GlobalEventUpdated").OnClientEvent:Connect(function(state)
		HUDController.SetEvent(state)
	end)

	Net.GetRemoteEvent("InventoryUpdated").OnClientEvent:Connect(function(inventory)
		ClientState.SetInventoryFromSnapshot(inventory)
	end)
end

return HUDController
