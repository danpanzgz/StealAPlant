--!strict
--[[
	HUDController.lua
	HUD principal construido por código. Mobile-first y adaptable:
	  - El ScreenGui respeta el área segura (notch) y la barra superior de
	    Roblox (ScreenInsets), así que nada se pinta bajo los iconos nativos.
	  - Cash, banner de evento y notificaciones forman una columna centrada
	    arriba; los botones de acción se colocan según el dispositivo y NUNCA
	    en las esquinas inferiores (thumbstick y botón de salto nativos).
	  - Todo se recalcula al rotar / redimensionar (layoutHUD).
	  - Paneles grandes y relativos, con scroll, de uno en uno.
	  - Notificaciones toast con tope de apilado, por encima de los paneles.
	  - Alarma de robo suave (nada violento).
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

local HUDController = {}

type PanelEntry = { frame: Frame, onOpen: (() -> ())?, limit: UISizeConstraint, title: TextLabel }
type Notification = { label: TextLabel, stroke: UIStroke, token: number }
type Profile = { kind: string, landscape: boolean, size: Vector2, touch: boolean }

local MARGIN = 8
local GAP = 6
local MAX_NOTIFICATIONS = 4
local MAX_NOTIFICATION_CHARS = 140
local NOTIFICATION_SECONDS = 3
local EVENT_BANNER_HEIGHT = 36
local BORDER_COLOR = Color3.fromRGB(74, 48, 30)
local CREAM = Color3.fromRGB(255, 244, 211)

local screenGui: ScreenGui
local topBar: Frame
local cashLabel: TextLabel
local notificationContainer: Frame
local eventBanner: TextLabel
local alarmOverlay: Frame
local alarmLabel: TextLabel
local actionBar: Frame? = nil
local actionGrid: UIGridLayout? = nil
local actionButtons: { TextButton } = {}

local panels: { [string]: PanelEntry } = {}
local notifications: { Notification } = {}
local notificationCounter = 0
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

-- ===== Perfil de dispositivo (se reevalúa en cada layout) =====

local function getProfile(): Profile
	local size = Vector2.new(1280, 720)
	if screenGui and screenGui.AbsoluteSize.X > 0 and screenGui.AbsoluteSize.Y > 0 then
		size = screenGui.AbsoluteSize
	elseif workspace.CurrentCamera then
		size = workspace.CurrentCamera.ViewportSize
	end
	local touch = UserInputService.TouchEnabled
	local kind = "desktop"
	if touch and math.min(size.X, size.Y) <= 600 then
		kind = "mobile"
	elseif touch or size.X <= 820 then
		kind = "tablet"
	end
	return { kind = kind, landscape = size.X > size.Y, size = size, touch = touch }
end

-- ===== Paneles: tamaño según perfil =====

local function applyPanelSize(entry: PanelEntry, profile: Profile)
	local titleSize = 22
	if profile.kind == "mobile" then
		titleSize = 19
		if profile.landscape then
			entry.frame.Size = UDim2.fromScale(0.74, 0.94)
			entry.limit.MaxSize = Vector2.new(620, 420)
		else
			entry.frame.Size = UDim2.fromScale(0.94, 0.82)
			entry.limit.MaxSize = Vector2.new(430, 700)
		end
	elseif profile.kind == "tablet" then
		entry.frame.Size = UDim2.fromScale(0.8, 0.82)
		entry.limit.MaxSize = Vector2.new(640, 660)
	else
		entry.frame.Size = UDim2.fromScale(0.6, 0.8)
		entry.limit.MaxSize = Vector2.new(720, 680)
	end
	entry.title.TextSize = titleSize
end

-- ===== Layout general =====

-- Devuelve (siguienteY de la columna central, ancho reservado a la izquierda).
local function layoutActionBar(profile: Profile, stackY: number): (number, number)
	local bar = actionBar
	local grid = actionGrid
	if not bar or not grid then
		return stackY, 0
	end
	local count = #actionButtons
	bar.Visible = count > 0
	if count == 0 then
		return stackY, 0
	end

	local avail = profile.size.X - MARGIN * 2
	local gap = 4
	local cellW = 46
	local cellH = 46
	local perRow = 2
	local portraitMobile = profile.kind == "mobile" and not profile.landscape
	if portraitMobile then
		cellH = 48
		perRow = math.max(1, math.min(count, math.floor((avail + gap) / (44 + gap))))
		cellW = math.clamp(math.floor((avail - (perRow - 1) * gap) / perRow), 44, 60)
	elseif profile.kind == "mobile" then
		-- Apaisado: cuadrícula arriba a la izquierda, sin invadir el Cash central
		-- ni el thumbstick (abajo a la izquierda).
		local sideSpace = profile.size.X / 2 - 164 / 2 - MARGIN * 2
		perRow = math.clamp(math.floor((sideSpace + gap) / (cellW + gap)), 1, count)
	elseif profile.kind == "tablet" then
		gap, cellW, cellH, perRow = 8, 62, 56, 2
	else
		gap, cellW, cellH, perRow = 8, 68, 60, 2
	end

	local rows = math.ceil(count / perRow)
	local barW = perRow * cellW + (perRow - 1) * gap
	local barH = rows * cellH + (rows - 1) * gap
	grid.CellSize = UDim2.fromOffset(cellW, cellH)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.FillDirectionMaxCells = perRow
	bar.Size = UDim2.fromOffset(barW, barH)

	if portraitMobile then
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, stackY)
		return stackY + barH + GAP, 0
	elseif profile.touch then
		bar.AnchorPoint = Vector2.new(0, 0)
		bar.Position = UDim2.fromOffset(MARGIN, MARGIN)
		return stackY, barW + MARGIN * 2
	end
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, MARGIN, 1, -MARGIN - 10)
	return stackY, 0
end

local function layoutHUD()
	if not screenGui or not topBar or not eventBanner or not notificationContainer then
		return
	end
	local profile = getProfile()
	local mobile = profile.kind == "mobile"

	-- Cash arriba al centro
	local cashW = if mobile then 164 else if profile.kind == "tablet" then 186 else 204
	local cashH = if mobile then 44 else 52
	topBar.Size = UDim2.fromOffset(cashW, cashH)
	topBar.Position = UDim2.new(0.5, 0, 0, MARGIN)
	cashLabel.TextSize = if mobile then 20 else 22
	local stackY = MARGIN + cashH + GAP

	-- Botones de acción
	local leftReserved: number
	stackY, leftReserved = layoutActionBar(profile, stackY)

	-- Banner de evento (debajo del Cash, nunca en la esquina de la lista de jugadores)
	eventBanner.AnchorPoint = Vector2.new(0.5, 0)
	eventBanner.Position = UDim2.new(0.5, 0, 0, stackY)
	eventBanner.Size = UDim2.fromOffset(math.min(if mobile then 170 else 220, profile.size.X - MARGIN * 2), EVENT_BANNER_HEIGHT)
	if eventBanner.Visible then
		stackY += EVENT_BANNER_HEIGHT + GAP
	end

	-- Notificaciones debajo de todo lo anterior, entre las zonas de controles
	local notifWidth = math.clamp(profile.size.X - 2 * leftReserved - MARGIN * 2, 200, 360)
	notificationContainer.AnchorPoint = Vector2.new(0.5, 0)
	notificationContainer.Position = UDim2.new(0.5, 0, 0, stackY)
	notificationContainer.Size = UDim2.fromOffset(notifWidth, 200)

	for _, entry in pairs(panels) do
		applyPanelSize(entry, profile)
	end
end

-- ===== Construcción =====

local function createTopBar()
	topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = UI.Colors.Green
	topBar.BorderSizePixel = 4
	topBar.BorderColor3 = BORDER_COLOR
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Size = UDim2.fromOffset(164, 44)
	topBar.Parent = screenGui

	local iconPlate = Instance.new("Frame")
	iconPlate.Name = "CashIconPlate"
	iconPlate.AnchorPoint = Vector2.new(0, 0.5)
	iconPlate.Size = UDim2.fromOffset(36, 36)
	iconPlate.Position = UDim2.new(0, 6, 0.5, 0)
	iconPlate.BackgroundColor3 = UI.Colors.Gold
	iconPlate.BorderSizePixel = 2
	iconPlate.BorderColor3 = BORDER_COLOR
	iconPlate.Parent = topBar

	local function pixel(name: string, size: UDim2, position: UDim2, color: Color3)
		local block = Instance.new("Frame")
		block.Name = name
		block.Size = size
		block.Position = position
		block.BackgroundColor3 = color
		block.BorderSizePixel = 1
		block.BorderColor3 = BORDER_COLOR
		block.ZIndex = iconPlate.ZIndex + 1
		block.Parent = iconPlate
	end
	pixel("PetalTop", UDim2.fromOffset(10, 10), UDim2.fromOffset(13, 3), Color3.fromRGB(255, 235, 169))
	pixel("PetalLeft", UDim2.fromOffset(10, 10), UDim2.fromOffset(3, 13), Color3.fromRGB(255, 235, 169))
	pixel("PetalRight", UDim2.fromOffset(10, 10), UDim2.fromOffset(23, 13), Color3.fromRGB(255, 235, 169))
	pixel("PetalBottom", UDim2.fromOffset(10, 10), UDim2.fromOffset(13, 23), Color3.fromRGB(255, 235, 169))
	pixel("FlowerCenter", UDim2.fromOffset(8, 8), UDim2.fromOffset(14, 14), Color3.fromRGB(110, 75, 43))
	pixel("Leaf", UDim2.fromOffset(8, 5), UDim2.fromOffset(22, 27), Color3.fromRGB(79, 125, 55))

	-- Posiciones relativas a la altura: valen para 44 (móvil) y 52 (resto).
	local caption = UI.Label(topBar, "CASH DE GRANJA", UDim2.new(1, -58, 0.34, 0), UDim2.new(0, 52, 0.06, 0), Color3.fromRGB(242, 222, 164), true)
	caption.TextScaled = false
	caption.TextSize = 10
	-- El Cash crece de forma exponencial: TextScaled evita que se corte con cifras grandes.
	cashLabel = UI.Label(topBar, "0", UDim2.new(1, -58, 0.52, 0), UDim2.new(0, 52, 0.4, 0), Color3.fromRGB(255, 255, 255), true)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.Font = Enum.Font.GothamBold
end

local function createNotificationLayer()
	notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "Notifications"
	notificationContainer.BackgroundTransparency = 1
	-- Por encima de los paneles (ZIndex 5) y del selector de semillas (8).
	notificationContainer.ZIndex = 30
	notificationContainer.Size = UDim2.fromOffset(300, 200)
	notificationContainer.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = notificationContainer
end

local function createEventBanner()
	eventBanner = Instance.new("TextLabel")
	eventBanner.Name = "EventBanner"
	eventBanner.Visible = false
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
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.MaxTextSize = 20
	limit.Parent = eventBanner
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
	alarmLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
	alarmLabel.Size = UDim2.new(0.9, 0, 0, 40)
	alarmLabel.Text = "🚨 ¡Intentan robar tu jardín!"
	alarmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	alarmLabel.TextStrokeTransparency = 0.2
	alarmLabel.Font = Enum.Font.GothamBold
	alarmLabel.TextScaled = true
	alarmLabel.ZIndex = 51
	alarmLabel.Parent = alarmOverlay
	-- En pantallas anchas el texto no debe crecer sin límite.
	local alarmLimit = Instance.new("UISizeConstraint")
	alarmLimit.MaxSize = Vector2.new(380, 48)
	alarmLimit.Parent = alarmLabel
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

-- ===== Notificaciones =====

local function dismissNotification(entry: Notification)
	local index = table.find(notifications, entry)
	if index then
		table.remove(notifications, index)
	end
	local label = entry.label
	if not label.Parent then
		return
	end
	local info = TweenInfo.new(0.3)
	TweenService:Create(label, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	local strokeTween = TweenService:Create(entry.stroke, info, { Transparency = 1 })
	strokeTween.Completed:Connect(function()
		label:Destroy()
	end)
	strokeTween:Play()
end

local function scheduleDismiss(entry: Notification)
	entry.token += 1
	local token = entry.token
	task.delay(NOTIFICATION_SECONDS, function()
		if entry.token == token then
			dismissNotification(entry)
		end
	end)
end

function HUDController.ShowNotification(text: string, color: Color3?)
	if not notificationContainer then
		return
	end

	-- Textos larguísimos se recortan para no tapar media pantalla.
	local length = utf8.len(text)
	if length and length > MAX_NOTIFICATION_CHARS then
		local cut = utf8.offset(text, MAX_NOTIFICATION_CHARS + 1)
		if cut then
			text = string.sub(text, 1, cut - 1) .. "…"
		end
	end

	-- El mismo aviso repetido no apila otra tarjeta: solo renueva el tiempo.
	local newest = notifications[#notifications]
	if newest and newest.label.Parent and newest.label.Text == text then
		scheduleDismiss(newest)
		return
	end

	local mobile = getProfile().kind == "mobile"
	notificationCounter += 1
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = UI.Colors.Panel
	label.BorderSizePixel = 0
	label.LayoutOrder = notificationCounter
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.Arcade
	label.TextSize = if mobile then 14 else 15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = notificationContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Colors.Gold
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label

	local entry: Notification = { label = label, stroke = stroke, token = 0 }
	table.insert(notifications, entry)
	while #notifications > MAX_NOTIFICATIONS do
		dismissNotification(notifications[1])
	end
	scheduleDismiss(entry)
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
		layoutHUD()
		return
	end
	local endsAt = os.clock() + state.secondsLeft
	eventBanner.Visible = true
	layoutHUD()
	task.spawn(function()
		while token == eventToken and os.clock() < endsAt do
			eventBanner.Text = state.displayName .. " " .. UI.Time(endsAt - os.clock())
			task.wait(1)
		end
		if token == eventToken then
			eventBanner.Visible = false
			layoutHUD()
		end
	end)
end

-- ===== Botones de acción y paneles =====

function HUDController.GetActionBar(): Frame
	if actionBar then
		return actionBar
	end
	local bar = Instance.new("Frame")
	bar.Name = "ActionBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(120, 60)
	bar.Parent = screenGui

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(56, 48)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.FillDirectionMaxCells = 2
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bar

	actionBar = bar
	actionGrid = grid
	return bar
end

local ICON_LABELS = {
	ShopButton = "SHOP",
	BagButton = "BAG",
	GardenButton = "YARD",
	QuestButton = "TASK",
	StoreButton = "PASS",
}

local BUTTON_COLORS = {
	ShopButton = Color3.fromRGB(103, 151, 68),
	BagButton = Color3.fromRGB(79, 133, 151),
	GardenButton = Color3.fromRGB(91, 145, 67),
	QuestButton = Color3.fromRGB(174, 126, 53),
	StoreButton = Color3.fromRGB(126, 105, 154),
}

function HUDController.CreateActionButton(name: string, emoji: string, labelText: string): TextButton
	local bar = HUDController.GetActionBar()

	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = #actionButtons + 1
	button.BorderSizePixel = 3
	button.BorderColor3 = BORDER_COLOR
	button.AutoButtonColor = false
	button.Selectable = true
	button.Text = "" -- el texto vive en dos etiquetas (icono + pie) para que escale bien
	button.Parent = bar

	local accent = BUTTON_COLORS[name] or Color3.fromRGB(95, 155, 112)
	button.BackgroundColor3 = accent

	local iconText = ICON_LABELS[name] or emoji
	-- Si el pie repite el icono ("TOP" / "Top") se omite en lugar de duplicarlo.
	local showCaption = labelText ~= "" and string.lower(labelText) ~= string.lower(iconText)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = if showCaption then UDim2.new(1, -4, 0.56, 0) else UDim2.new(1, -4, 0.8, 0)
	icon.Position = if showCaption then UDim2.new(0, 2, 0.06, 0) else UDim2.new(0, 2, 0.1, 0)
	icon.Text = iconText
	icon.TextColor3 = CREAM
	icon.Font = Enum.Font.Arcade
	icon.TextScaled = true
	icon.TextStrokeColor3 = Color3.fromRGB(19, 30, 24)
	icon.TextStrokeTransparency = 0.75
	icon.Parent = button
	local iconLimit = Instance.new("UITextSizeConstraint")
	iconLimit.MinTextSize = 8
	iconLimit.MaxTextSize = 20
	iconLimit.Parent = icon

	if showCaption then
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.BackgroundTransparency = 1
		caption.Size = UDim2.new(1, -4, 0.28, 0)
		caption.Position = UDim2.new(0, 2, 0.66, 0)
		caption.Text = labelText
		caption.TextColor3 = Color3.fromRGB(242, 222, 164)
		caption.Font = Enum.Font.Gotham
		caption.TextScaled = true
		caption.Parent = button
		local captionLimit = Instance.new("UITextSizeConstraint")
		captionLimit.MinTextSize = 7
		captionLimit.MaxTextSize = 11
		captionLimit.Parent = caption
	end

	button.SelectionGained:Connect(function()
		button.BorderColor3 = UI.Colors.Gold
	end)
	button.SelectionLost:Connect(function()
		button.BorderColor3 = BORDER_COLOR
	end)
	button.MouseEnter:Connect(function()
		button.BorderColor3 = UI.Colors.Gold
	end)
	button.MouseLeave:Connect(function()
		button.BorderColor3 = BORDER_COLOR
		-- En táctil el dedo puede salirse del botón sin MouseButton1Up: sin esto
		-- el botón se quedaba oscuro.
		button.BackgroundColor3 = accent
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = accent:Lerp(Color3.new(0, 0, 0), 0.2)
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = accent
	end)

	table.insert(actionButtons, button)
	layoutHUD()
	return button
end

function HUDController.CreatePanel(name: string, titleText: string, onOpen: (() -> ())?): (Frame, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Panel"
	frame.Visible = false
	-- Active: sin esto un toque/clic en el panel "atraviesa" y activa la
	-- herramienta equipada (palo o semilla) sobre el mundo de detrás.
	frame.Active = true
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
	headerAccent.Position = UDim2.new(0, 12, 0, 54)
	headerAccent.BackgroundColor3 = UI.Colors.Gold
	headerAccent.BorderSizePixel = 0
	headerAccent.ZIndex = frame.ZIndex + 1
	headerAccent.Parent = frame

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, 680)
	limit.Parent = frame

	local title = UI.Label(frame, titleText, UDim2.new(1, -74, 0, 40), UDim2.new(0, 18, 0, 6), Color3.fromRGB(255, 243, 204), true)
	title.TextScaled = false
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextSize = 22

	-- 44x44: tamaño mínimo cómodo para un toque.
	local close = UI.Button(frame, "X", UI.Colors.Grey, UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 6))
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 8, 0, 66)
	list.Size = UDim2.new(1, -16, 1, -74)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.BorderSizePixel = 0
	list.ZIndex = frame.ZIndex + 1
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	-- Las tarjetas miden "ancho - 16": centradas quedan 8px a cada lado y la
	-- barra de scroll no las tapa.
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list

	local entry: PanelEntry = { frame = frame, onOpen = onOpen, limit = limit, title = title }
	panels[name] = entry
	applyPanelSize(entry, getProfile())
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
	-- Respeta notch y barra superior de Roblox (antes IgnoreGuiInset=true hacía
	-- que el HUD se pintara bajo los iconos nativos de menú/chat).
	screenGui.IgnoreGuiInset = false
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	createTopBar()
	createNotificationLayer()
	createEventBanner()
	createAlarm()
	layoutHUD()
	-- Rotación del móvil, redimensionado de ventana, cambio de insets...
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutHUD)

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
