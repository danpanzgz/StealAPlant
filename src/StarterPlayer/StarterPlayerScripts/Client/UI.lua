--!strict
--[[
	UI.lua
	Helpers mínimos para construir la interfaz por código (mobile-first).
]]

local UI = {}

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
	return card
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
