--!strict
-- Componentes visuales compartidos. Mantener el estilo en un único módulo
-- permite que cada panel se adapte igual de bien a móvil, consola y PC.
local UIFactory = {}

UIFactory.Colors = {
	Canvas = Color3.fromRGB(226, 205, 157),
	Panel = Color3.fromRGB(79, 58, 39),
	PanelLight = Color3.fromRGB(126, 91, 53),
	Primary = Color3.fromRGB(79, 125, 55),
	PrimaryDark = Color3.fromRGB(56, 90, 43),
	Gold = Color3.fromRGB(198, 145, 43),
	Text = Color3.fromRGB(255, 244, 211),
	Muted = Color3.fromRGB(210, 187, 142),
	Danger = Color3.fromRGB(168, 66, 45),
}

function UIFactory.Corner(parent: Instance, _radius: number)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UICorner") then
			child:Destroy()
		end
	end
end

function UIFactory.Label(parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	label.Size, label.Position = size, position
	label.Text = text
	label.TextColor3 = color or UIFactory.Colors.Text
	label.Font = Enum.Font.Gotham
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = parent
	return label
end

function UIFactory.Button(parent: Instance, name: string, text: string, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color or UIFactory.Colors.Primary
	button.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	button.AutoButtonColor = true
	button.Selectable = true
	button.Text = text
	button.TextColor3 = UIFactory.Colors.Text
	button.Font = Enum.Font.Arcade
	button.TextSize = 15
	button.BorderSizePixel = 3
	button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	button.Parent = parent
	UIFactory.Corner(button, 10)
	button.SelectionGained:Connect(function()
		button.BorderColor3 = UIFactory.Colors.Gold
	end)
	button.SelectionLost:Connect(function()
		button.BorderColor3 = Color3.fromRGB(74, 48, 30)
	end)
	return button
end

function UIFactory.Panel(screenGui: ScreenGui, name: string, title: string, subtitle: string?): (Frame, ScrollingFrame)
	local shade = Instance.new("TextButton")
	shade.Name = name .. "Shade"
	shade.Visible = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.Text = ""
	shade.AutoButtonColor = false
	shade.Selectable = false
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 10
	shade.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.76)
	panel.BackgroundColor3 = UIFactory.Colors.Panel
	panel.BorderSizePixel = 3
	panel.BorderColor3 = UIFactory.Colors.Gold
	panel.ZIndex = 11
	panel.Parent = shade
	UIFactory.Corner(panel, 16)
	local titleLabel = UIFactory.Label(panel, title, UDim2.new(1, -80, 0, 31), UDim2.fromOffset(20, 14), 23)
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	if subtitle then
		local sub = UIFactory.Label(panel, subtitle, UDim2.new(1, -48, 0, 30), UDim2.fromOffset(20, 47), 13, UIFactory.Colors.Muted)
		sub.TextXAlignment = Enum.TextXAlignment.Left
	end
	local close = UIFactory.Button(panel, "Close", "×", UIFactory.Colors.PanelLight)
	close.Size, close.Position = UDim2.fromOffset(42, 42), UDim2.new(1, -56, 0, 14)
	close.TextSize = 25
	close.Activated:Connect(function() shade.Visible = false end)
	shade.Activated:Connect(function() shade.Visible = false end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Content"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(14, 84)
	list.Size = UDim2.new(1, -28, 1, -98)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 5
	list.ZIndex = panel.ZIndex + 1
	list.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	padding.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 9)
	layout.Parent = list
	return shade, list
end

return UIFactory
