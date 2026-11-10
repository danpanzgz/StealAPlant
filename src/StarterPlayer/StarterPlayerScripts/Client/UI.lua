--!strict
--[[
	UI.lua
	Helpers mínimos para construir la interfaz por código (mobile-first).
]]

local TweenService = game:GetService("TweenService")

local UI = {}

-- Degradado suave (luz arriba, sombra abajo): da volumen sin perder el estilo pixel.
local function addGradient(target: GuiObject, strength: number)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Shine"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(
		Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), 0),
		Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), strength)
	)
	gradient.Parent = target
end

UI.Colors = {
	Panel = Color3.fromRGB(79, 58, 39),
	Card = Color3.fromRGB(226, 205, 157),
	Text = Color3.fromRGB(54, 43, 30),
	Muted = Color3.fromRGB(103, 82, 54),
	Green = Color3.fromRGB(79, 125, 55),
	Red = Color3.fromRGB(168, 66, 45),
	Gold = Color3.fromRGB(198, 145, 43),
	Blue = Color3.fromRGB(63, 117, 132),
	Grey = Color3.fromRGB(112, 82, 52),
}

function UI.Round(inst: Instance, _radius: number)
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

function UI.Label(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	label.Size = size
	label.Position = position
	label.Text = text
	label.TextColor3 = color or UI.Colors.Text
	label.Font = if bold == false then Enum.Font.Gotham else Enum.Font.Arcade
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 10
	textConstraint.MaxTextSize = 22
	textConstraint.Parent = label
	return label
end

function UI.Button(parent: Instance, text: string, background: Color3, size: UDim2, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	if position then
		button.Position = position
	end
	button.BackgroundColor3 = background
	button.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	button.Text = text
	button.TextColor3 = UI.Colors.Text
	button.Font = Enum.Font.Arcade
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Selectable = true
	button.Parent = parent
	button.TextColor3 = Color3.fromRGB(255, 244, 211)
	button.BorderSizePixel = 3
	button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 10
	textConstraint.MaxTextSize = 20
	textConstraint.Parent = button
	local baseBorderColor = Color3.fromRGB(74, 48, 30)
	addGradient(button, 0.22)

	-- Animación de pulsación y hover: se hunde al tocar, crece al pasar el ratón.
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function animate(target: number, time: number)
		TweenService:Create(scale, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
	button.MouseEnter:Connect(function()
		animate(1.04, 0.1)
	end)
	button.MouseLeave:Connect(function()
		animate(1, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		animate(0.94, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		animate(1.04, 0.1)
	end)
	button.SelectionGained:Connect(function()
		button.BorderColor3 = UI.Colors.Gold
	end)
	button.SelectionLost:Connect(function()
		button.BorderColor3 = baseBorderColor
	end)
	return button
end

-- Tarjeta de lista con altura fija. Devuelve el Frame.
function UI.Card(parent: Instance, height: number, order: number?): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -16, 0, height)
	card.BackgroundColor3 = UI.Colors.Card
	card.BorderSizePixel = 0
	card.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	if order then
		card.LayoutOrder = order
	end
	card.Parent = parent
	card.BorderSizePixel = 3
	card.BorderColor3 = Color3.fromRGB(112, 78, 43)
	addGradient(card, 0.12)
	return card
end

-- ===== Cuadrículas y filas =====

local function stripLayouts(list: Instance)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

-- Convierte una lista con scroll en una cuadrícula de cuadraditos (scroll vertical corto).
function UI.UseGrid(list: ScrollingFrame, cell: Vector2, pad: number)
	stripLayouts(list)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.fromOffset(pad, pad)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list
end

-- Lista vertical clásica.
function UI.UseList(list: ScrollingFrame, pad: number?)
	stripLayouts(list)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, pad or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
end

-- Fila horizontal con scroll de lado a lado.
function UI.UseRow(list: ScrollingFrame, pad: number?)
	stripLayouts(list)
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.ScrollBarThickness = 8
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, pad or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = list
end

-- Cuadradito de cuadrícula (inventario, índice...). `icon` rellena el hueco central.
export type TileOptions = {
	order: number?,
	title: string?,
	count: number?,
	color: Color3?, -- color del borde (rareza)
	locked: boolean?,
	selected: boolean?,
	icon: ((holder: Frame) -> ())?,
	text: string?, -- texto grande central si no hay icono (p. ej. "?")
}

function UI.Tile(parent: Instance, options: TileOptions): TextButton
	local tile = Instance.new("TextButton")
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = options.order or 0
	tile.BackgroundColor3 = if options.locked then Color3.fromRGB(170, 152, 114) else UI.Colors.Card
	tile.BorderSizePixel = if options.selected then 4 else 3
	tile.BorderColor3 = if options.selected then Color3.fromRGB(255, 255, 255) elseif options.color then options.color else Color3.fromRGB(112, 78, 43)
	tile.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	tile.Parent = parent
	addGradient(tile, 0.12)

	if options.icon then
		local holder = Instance.new("Frame")
		holder.Name = "IconHolder"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(52, 56)
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 3)
		holder.ZIndex = tile.ZIndex + 1
		holder.Parent = tile
		options.icon(holder)
	elseif options.text then
		local mark = UI.Label(tile, options.text, UDim2.new(1, 0, 0.6, 0), UDim2.new(0, 0, 0, 2), UI.Colors.Muted)
		mark.TextXAlignment = Enum.TextXAlignment.Center
	end
	if options.title then
		local name = UI.Label(tile, options.title, UDim2.new(1, -4, 0, 15), UDim2.new(0, 2, 1, -17), UI.Colors.Text, false)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextScaled = false
		name.TextSize = 11
	end
	if options.count and options.count > 1 then
		local count = UI.Label(tile, "x" .. options.count, UDim2.new(0, 34, 0, 16), UDim2.new(1, -36, 0, 1), UI.Colors.Text)
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextScaled = false
		count.TextSize = 13
	end
	return tile
end

function UI.ClearList(list: Instance)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UI.Money(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function UI.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%d:%02d", m, s)
end

return UI
