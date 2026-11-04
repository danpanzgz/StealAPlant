--!strict
-- Construye un hub ligero y las tres zonas físicas. Los portales se resuelven
-- enteramente en servidor: la condición de desbloqueo no depende de la UI.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local DataService = require(script.Parent.DataService)

local ZoneService = {}
local destinations: { [string]: BasePart } = {}

local ZONE_POSITIONS = {
	StarterMeadow = Vector3.new(-90, 0, 20),
	GreenhouseValley = Vector3.new(-90, 0, 85),
	MysticGrove = Vector3.new(-90, 0, 150),
}

local ZONE_COLORS = {
	StarterMeadow = Color3.fromRGB(90, 166, 84),
	GreenhouseValley = Color3.fromRGB(67, 158, 142),
	MysticGrove = Color3.fromRGB(113, 79, 175),
}

local function makePart(parent: Instance, name: string, position: Vector3, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name, part.Anchored, part.Position, part.Size = name, true, position, size
	part.Color, part.Material = color, material
	part.Parent = parent
	return part
end

local function teleport(player: Player, destination: BasePart)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = destination.CFrame + Vector3.new(0, 4, 0) end
end

function ZoneService.Init()
	local old = Workspace:FindFirstChild("World")
	if old then old:Destroy() end
	local world = Instance.new("Folder")
	world.Name, world.Parent = "World", Workspace

	local hub = makePart(world, "Hub", Vector3.new(-90, -1, -35), Vector3.new(52, 2, 52), Color3.fromRGB(57, 86, 91), Enum.Material.Slate)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Anchored = "MainSpawn", true
	spawn.Size, spawn.Position = Vector3.new(8, 1, 8), Vector3.new(-90, 1, -35)
	spawn.Neutral, spawn.Material, spawn.Color = true, Enum.Material.Neon, Color3.fromRGB(116, 226, 148)
	spawn.Parent = world

	for _, zoneId in ipairs(ZoneConfig.Order) do
		local info, pos, color = ZoneConfig[zoneId], ZONE_POSITIONS[zoneId], ZONE_COLORS[zoneId]
		local zone = Instance.new("Model")
		zone.Name, zone.Parent = zoneId, world
		makePart(zone, "Ground", pos + Vector3.new(0, -1, 0), Vector3.new(58, 2, 46), color, Enum.Material.Grass)
		local marker = makePart(zone, "Arrival", pos, Vector3.new(4, 1, 4), color, Enum.Material.Neon)
		marker.Transparency = 1
		destinations[zoneId] = marker
		local sign = makePart(zone, "Sign", pos + Vector3.new(0, 3, -17), Vector3.new(18, 5, 0.5), Color3.fromRGB(70, 51, 38), Enum.Material.Wood)
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(250, 70), Vector3.new(0, 3, 0), true
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text = info.displayName .. "\n" .. info.description
		label.TextColor3, label.Font, label.TextScaled = Color3.fromRGB(255, 248, 220), Enum.Font.GothamBold, true
		label.TextStrokeTransparency = 0.65
		label.Parent = gui

		local portal = makePart(world, zoneId .. "Portal", Vector3.new(-90, 0, -8 + info.order * 11), Vector3.new(9, 1, 7), color, Enum.Material.Neon)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Travel"
		prompt.ObjectText = info.displayName .. (info.unlockCash > 0 and (" · " .. info.unlockCash .. " total Cash") or "")
		prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.35, 10, false
		prompt.Parent = portal
		prompt.Triggered:Connect(function(player)
			local profile = DataService.GetProfile(player)
			if not profile or profile.totalCashEarned < info.unlockCash then return end
			profile.unlockedZones[info.order] = zoneId
			DataService.MarkDirty(player)
			teleport(player, marker)
		end)
	end
	local hubLabel = Instance.new("BillboardGui")
	hubLabel.Size, hubLabel.StudsOffset, hubLabel.AlwaysOnTop = UDim2.fromOffset(300, 50), Vector3.new(0, 5, 0), true
	hubLabel.Parent = hub
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "STEAL A PLANT · TRAVEL HUB"
	text.TextColor3, text.Font, text.TextScaled = Color3.fromRGB(235, 255, 236), Enum.Font.GothamBold, true
	text.Parent = hubLabel
end

return ZoneService
