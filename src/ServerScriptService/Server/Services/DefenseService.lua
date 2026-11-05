--!strict
--[[
	DefenseService.lua
	Defensas de jardín NO dañinas: bajan la probabilidad de robo.
	Cada defensa se guarda en profile.defenses[slot] y se dibuja con Parts
	simples (campana, valla, gnomo cómico) delante del jardín.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefenseConfig: any = require(ReplicatedStorage.Shared.Config.DefenseConfig)
local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GardenService = require(script.Parent.GardenService)
local QuestService = require(script.Parent.QuestService)

local DefenseService = {}

-- userId -> { [slot] = Model }
local visuals: { [number]: { [number]: Model } } = {}

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function buildVisual(player: Player, slot: number, defenseId: string)
	local garden = GardenService.GetGardenModel(player)
	local data = DefenseConfig[defenseId]
	if not garden or not data then
		return
	end

	local userVisuals = visuals[player.UserId]
	if not userVisuals then
		userVisuals = {}
		visuals[player.UserId] = userVisuals
	end
	if userVisuals[slot] then
		userVisuals[slot]:Destroy()
	end

	local origin = garden:GetPivot().Position
	local base = origin + Vector3.new(4 + (slot - 1) * 9, 0.2, -3)

	local model = Instance.new("Model")
	model.Name = "Defense_" .. slot

	if defenseId == "Bell" then
		makePart(model, "Post", Vector3.new(0.7, 5, 0.7), base + Vector3.new(0, 2.5, 0), Color3.fromRGB(120, 85, 55))
		makePart(model, "Bell", Vector3.new(2, 2, 2), base + Vector3.new(0, 5.6, 0), data.color, Enum.PartType.Ball)
	elseif defenseId == "Fence" then
		for i = 0, 3 do
			makePart(model, "Picket", Vector3.new(0.6, 3, 0.6), base + Vector3.new(i * 2 - 3, 1.5, 0), data.color)
		end
		makePart(model, "Rail", Vector3.new(7, 0.5, 0.4), base + Vector3.new(0, 2.2, 0), data.color)
	elseif defenseId == "Gnome" then
		makePart(model, "Body", Vector3.new(1.8, 2.2, 1.6), base + Vector3.new(0, 1.1, 0), Color3.fromRGB(70, 110, 220))
		makePart(model, "Head", Vector3.new(1.4, 1.4, 1.4), base + Vector3.new(0, 2.9, 0), Color3.fromRGB(255, 214, 180), Enum.PartType.Ball)
		local hat = makePart(model, "Hat", Vector3.new(1.6, 1.8, 1.6), base + Vector3.new(0, 4.3, 0), data.color)
		hat.Shape = Enum.PartType.Block
		makePart(model, "Beard", Vector3.new(1.2, 0.9, 0.5), base + Vector3.new(0, 2.2, 0.8), Color3.fromRGB(245, 245, 245))
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 70
	gui.Parent = model:FindFirstChildWhichIsA("BasePart")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = data.emoji
	label.TextScaled = true
	label.Parent = gui

	model.Parent = garden
	userVisuals[slot] = model
end

function DefenseService.GetChanceReduction(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, entry in pairs(profile.defenses) do
		local data = DefenseConfig[entry.defenseId]
		if data then
			total += data.stealChanceReduction
		end
	end
	return total
end

function DefenseService.BuildAll(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end

	function DefenseService.Clear(player: Player)
		local userVisuals = visuals[player.UserId]
		if userVisuals then
			for _, model in pairs(userVisuals) do
				model:Destroy()
			end
			visuals[player.UserId] = nil
		end
	end
	for slot, entry in pairs(profile.defenses) do
		buildVisual(player, slot, entry.defenseId)
	end
end

function DefenseService.Place(player: Player, defenseId: any): (boolean, any)
	if type(defenseId) ~= "string" then
		return false, "invalid_args"
	end
	local data = DefenseConfig[defenseId]
	if not data then
		return false, "unknown_defense"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local levelData = GardenConfig.Levels[profile.gardenLevel] or GardenConfig.Levels[1]
	local freeSlot: number? = nil
	for slot = 1, levelData.defenseSlots do
		if profile.defenses[slot] == nil then
			freeSlot = slot
			break
		end
	end
	if not freeSlot then
		return false, "no_free_slot"
	end

	if not EconomyService.TryRemoveCash(player, data.price, "defense") then
		return false, "not_enough_cash"
	end

	profile.defenses[freeSlot] = { defenseId = defenseId, placedAt = os.time() }
	DataService.MarkDirty(player)
	buildVisual(player, freeSlot, defenseId)
	QuestService.Report(player, "place_defense", 1)
	return true, { slot = freeSlot }
end

Players.PlayerRemoving:Connect(function(player)
	visuals[player.UserId] = nil
end)

return DefenseService
