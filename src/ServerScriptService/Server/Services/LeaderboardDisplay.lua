--!strict
--[[
	LeaderboardDisplay.lua
	Parte física del ranking en la plaza:
	  - 3 estatuas (oro / plata / bronce) con el avatar de los más ricos.
	  - Un tablón de madera con el Top 50 (2 columnas de 25).
	Se refresca solo cada 30 s con LeaderboardService.GetTop().
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LeaderboardService = require(script.Parent.LeaderboardService)

local LeaderboardDisplay = {}

local REFRESH_SECONDS = 30
local METALS = {
	{ color = Color3.fromRGB(255, 205, 70), label = "🥇" },
	{ color = Color3.fromRGB(205, 210, 220), label = "🥈" },
	{ color = Color3.fromRGB(205, 135, 85), label = "🥉" },
}
local WOOD = Color3.fromRGB(139, 94, 56)
local DARK_WOOD = Color3.fromRGB(92, 60, 36)

local root: Model
local statueSlots: { { anchor: Vector3, pedestalTop: number, plate: TextLabel, model: Model?, userId: number } } = {}
local boardLabels: { TextLabel } = {}
local titleLabel: TextLabel

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function abbreviate(value: number): string
	local units = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local index = 1
	while value >= 1000 and index < #units do
		value /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(math.floor(value))
	end
	return string.format("%.1f%s", value, units[index])
end

local function buildBoard(anchor: Vector3)
	-- Tablón: dos postes + panel de madera con SurfaceGui (cara frontal = -Z, hacia la plaza).
	local width, height = 26, 15
	local centerY = 10
	for _, dx in ipairs({ -width / 2 + 1, width / 2 - 1 }) do
		part(root, "BoardPost", Vector3.new(1.2, centerY + height / 2, 1.2), CFrame.new(anchor + Vector3.new(dx, (centerY + height / 2) / 2, 0.8)), DARK_WOOD, Enum.Material.Wood)
	end
	local board = part(root, "Top50Board", Vector3.new(width, height, 1), CFrame.new(anchor + Vector3.new(0, centerY, 0)), WOOD, Enum.Material.WoodPlanks)
	part(root, "BoardFrame", Vector3.new(width + 1.4, height + 1.4, 0.8), CFrame.new(anchor + Vector3.new(0, centerY, 0.3)), DARK_WOOD, Enum.Material.Wood)
	local roof = part(root, "BoardRoof", Vector3.new(width + 3, 0.8, 3), CFrame.new(anchor + Vector3.new(0, centerY + height / 2 + 1.2, -0.3)), Color3.fromRGB(176, 78, 62), Enum.Material.Wood)
	roof.Name = "BoardRoof"

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 72)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 236, 170)
	titleLabel.Text = "🏆 LOS 50 MÁS RICOS"
	titleLabel.Parent = gui

	for column = 1, 2 do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.new((column - 1) * 0.5, 14, 0, 80)
		holder.Size = UDim2.new(0.5, -28, 1, -88)
		holder.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = holder
		for row = 1, 25 do
			local rank = (column - 1) * 25 + row
			local label = Instance.new("TextLabel")
			label.LayoutOrder = row
			label.BackgroundTransparency = if row % 2 == 0 then 0.85 else 1
			label.BackgroundColor3 = Color3.new(0, 0, 0)
			label.Size = UDim2.new(1, 0, 0, 20)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 17
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Color3.fromRGB(255, 244, 214)
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.RichText = false
			label.Text = string.format("%2d. —", rank)
			label.Parent = holder
			boardLabels[rank] = label
		end
	end
end

local function buildStatueBase(anchor: Vector3, index: number)
	local heights = { 4.4, 3.2, 2.4 } -- el 1º más alto
	local metal = METALS[index]
	local height = heights[index]
	part(root, "StatueBase", Vector3.new(5.6, height, 5.6), CFrame.new(anchor + Vector3.new(0, height / 2, 0)), Color3.fromRGB(190, 190, 198), Enum.Material.Marble)
	part(root, "StatueTrim", Vector3.new(6.2, 0.5, 6.2), CFrame.new(anchor + Vector3.new(0, height + 0.25, 0)), metal.color, Enum.Material.Metal)

	local plateHost = part(root, "StatuePlate", Vector3.new(4.6, 1.5, 0.3), CFrame.new(anchor + Vector3.new(0, height * 0.55, -2.9)), DARK_WOOD, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = plateHost
	local plate = Instance.new("TextLabel")
	plate.BackgroundTransparency = 1
	plate.Size = UDim2.fromScale(1, 1)
	plate.Font = Enum.Font.GothamBlack
	plate.TextScaled = true
	plate.TextColor3 = metal.color
	plate.Text = metal.label .. " —"
	plate.Parent = gui
	table.insert(statueSlots, { anchor = anchor, pedestalTop = height + 0.5, plate = plate, model = nil, userId = 0 })
end

-- Convierte un avatar en una estatua de metal.
local function statuefy(model: Model, color: Color3)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Clothing") or descendant:IsA("ShirtGraphic") or descendant:IsA("Decal") or descendant:IsA("SurfaceAppearance") or descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Color = color
			descendant.Material = Enum.Material.Metal
			if descendant:IsA("MeshPart") then
				descendant.TextureID = ""
			end
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function placeStatue(index: number, entry: any?)
	local slot = statueSlots[index]
	if not slot then
		return
	end
	if not entry then
		slot.plate.Text = METALS[index].label .. " —"
		if slot.model then
			slot.model:Destroy()
			slot.model = nil
		end
		slot.userId = 0
		return
	end
	slot.plate.Text = string.format("%s %s\n$%s", METALS[index].label, entry.name, abbreviate(entry.score))
	if slot.userId == entry.userId and slot.model then
		return -- mismo jugador: no reconstruir
	end
	slot.userId = entry.userId
	if slot.model then
		slot.model:Destroy()
		slot.model = nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(entry.userId)
	end)
	local statue: Model
	if ok and model then
		statue = model
	else
		-- Sin avatar (Studio sin red, usuario inexistente...): figura de bloques.
		statue = Instance.new("Model")
		part(statue, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		part(statue, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 4.7, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		part(statue, "ArmL", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		part(statue, "ArmR", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		part(statue, "LegL", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		part(statue, "LegR", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), Color3.new(1, 1, 1), Enum.Material.Metal)
		statue.PrimaryPart = statue:FindFirstChild("Torso") :: BasePart
	end
	statuefy(statue, METALS[index].color)
	statue.Name = "Statue" .. index
	statue.Parent = root
	statue:PivotTo(CFrame.new(slot.anchor + Vector3.new(0, 20, 0)))
	-- Apoya los pies sobre el pedestal y escala un poco (1º más grande).
	pcall(function()
		statue:ScaleTo(if index == 1 then 1.5 else 1.3)
	end)
	local boxCFrame, boxSize = statue:GetBoundingBox()
	local feetY = boxCFrame.Position.Y - boxSize.Y / 2
	statue:PivotTo(statue:GetPivot() + Vector3.new(0, slot.anchor.Y + slot.pedestalTop - feetY, 0))
	slot.model = statue
end

local function refresh()
	local entries = LeaderboardService.GetTop()
	for rank, label in ipairs(boardLabels) do
		local entry = entries[rank]
		if entry then
			label.Text = string.format("%2d. %s  $%s", rank, entry.name, abbreviate(entry.score))
			label.TextColor3 = if rank == 1 then METALS[1].color elseif rank == 2 then METALS[2].color elseif rank == 3 then METALS[3].color else Color3.fromRGB(255, 244, 214)
		else
			label.Text = string.format("%2d. —", rank)
			label.TextColor3 = Color3.fromRGB(190, 170, 140)
		end
	end
	for index = 1, 3 do
		placeStatue(index, entries[index])
	end
end

-- anchor: centro del suelo donde va el conjunto (la cara de las estatuas y del tablón mira a -Z).
function LeaderboardDisplay.Build(anchor: Vector3)
	root = Instance.new("Model")
	root.Name = "LeaderboardPlaza"
	root.Parent = Workspace

	buildBoard(anchor + Vector3.new(0, 0, 4.5))
	-- Podio: 2º - 1º - 3º
	buildStatueBase(anchor + Vector3.new(-7, 0, 0), 2)
	buildStatueBase(anchor + Vector3.new(0, 0, 0), 1)
	buildStatueBase(anchor + Vector3.new(7, 0, 0), 3)
	-- El orden de statueSlots sigue el de creación (2,1,3): reordenar por posición de medalla.
	local ordered = { statueSlots[2], statueSlots[1], statueSlots[3] }
	statueSlots = ordered

	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[LeaderboardDisplay] " .. tostring(err))
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardDisplay
