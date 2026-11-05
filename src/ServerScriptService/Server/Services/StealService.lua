--!strict
--[[
	StealService.lua
	Robo de plantas 100% NO gráfico: mantener pulsado un ProximityPrompt
	("Steal"), tirada de éxito en servidor, alarma al dueño y, si te pillan,
	teletransporte corto a tu jardín + ralentización con confeti cómico.
	También crea el "Jardín del Vecino" de la plaza: demostración
	controlada del robo para que el jugador lo descubra en minutos.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local DefenseConfig: any = require(ReplicatedStorage.Shared.Config.DefenseConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GardenService = require(script.Parent.GardenService)
local PlantService = require(script.Parent.PlantService)
local InventoryService = require(script.Parent.InventoryService)
local DefenseService = require(script.Parent.DefenseService)
local QuestService = require(script.Parent.QuestService)

local StealService = {}

local notifyEvent = Net.GetRemoteEvent("NotificationPush")
local resolvedEvent = Net.GetRemoteEvent("StealAttemptResolved")
local alarmEvent = Net.GetRemoteEvent("GardenAlarmTriggered")

local cooldownUntil: { [number]: number } = {} -- userId -> os.clock()
local carryByUser: { [number]: any } = {}
local domeUntil: { [number]: number } = {}
local domeCooldownUntil: { [number]: number } = {}
local domeByUser: { [number]: BasePart } = {}
local DOME_COOLDOWN = 180
-- Cada jugador puede reclamar cada planta generada una vez por sesión.
local tutorialClaims: { [number]: { [string]: boolean } } = {}

local function notify(player: Player, text: string, kind: string)
	notifyEvent:FireClient(player, { text = text, kind = kind })
end

local function confetti(parent: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(12, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 80)),
	})
	emitter.Parent = parent
	emitter:Emit(40)
	Debris:AddItem(emitter, 2)
end

function StealService.GrantShield(player: Player, seconds: number)
	player:SetAttribute("ShieldUntil", os.time() + seconds)
end

function StealService.ToggleGardenShield(player: Player): (boolean, string?, number?)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	local garden = GardenService.GetGardenModel(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not garden or not root then
		return false, "garden_unavailable"
	end
	if (root.Position - garden:GetPivot().Position).Magnitude > 55 then
		return false, "too_far_from_garden"
	end
	local now = os.time()
	if (domeUntil[player.UserId] or 0) > now then
		domeUntil[player.UserId] = nil
		local dome = domeByUser[player.UserId]
		if dome then
			dome:Destroy()
			domeByUser[player.UserId] = nil
		end
		player:SetAttribute("GardenShieldUntil", 0)
		return true, "deactivated"
	end
	if (domeCooldownUntil[player.UserId] or 0) > now then
		return false, "shield_cooldown"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local boundary = garden:FindFirstChild("YardBoundary")
	local floor = boundary and boundary:FindFirstChild("GardenFloor")
	if not floor or not floor:IsA("BasePart") then
		return false, "garden_unavailable"
	end
	local dome = Instance.new("Part")
	dome.Name = "GardenShieldDome"
	dome.Shape = Enum.PartType.Ball
	dome.Anchored = true
	dome.CanCollide = false
	dome.CanTouch = false
	dome.CanQuery = false
	dome.Transparency = 0.78
	dome.Material = Enum.Material.ForceField
	dome.Color = Color3.fromRGB(105, 208, 255)
	dome.Size = Vector3.new(floor.Size.X + 8, 34, floor.Size.Z + 8)
	dome.Position = floor.Position + Vector3.new(0, 16, 0)
	dome.Parent = garden
	domeByUser[player.UserId] = dome
	local duration = GameConfig.GardenShieldBaseDuration
		+ (profile.rebirthCount or 0) * GameConfig.GardenShieldDurationPerRebirth
	domeUntil[player.UserId] = now + duration
	domeCooldownUntil[player.UserId] = now + DOME_COOLDOWN
	player:SetAttribute("GardenShieldUntil", domeUntil[player.UserId])
	return true, "activated", duration
end

local function restoreCarriedPlant(thief: Player, returnToOwner: boolean, alreadyGranted: boolean?)
	local carry = carryByUser[thief.UserId]
	if not carry then
		return
	end
	carryByUser[thief.UserId] = nil
	if carry.model and carry.model.Parent then
		carry.model:Destroy()
	end
	thief:SetAttribute("CarryingStolenPlant", false)
	local humanoid = carry.humanoid
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = carry.originalSpeed
	end

	local owner = Players:GetPlayerByUserId(carry.ownerUserId)
	local ownerProfile = owner and DataService.GetProfile(owner)
	if returnToOwner and owner and ownerProfile then
		if InventoryService.AddPlant(owner, carry.item) then
			ownerProfile.stats.plantsLost = math.max(0, ownerProfile.stats.plantsLost - 1)
			DataService.MarkDirty(owner)
			notify(owner, "Tu flor volvió al jardín porque el robo se interrumpió.", "good")
			return
		end
	end

	if alreadyGranted then
		return
	end
	local thiefProfile = DataService.GetProfile(thief)
	if thiefProfile and InventoryService.AddPlant(thief, carry.item) then
		thiefProfile.stats.plantsStolen += 1
		DataService.MarkDirty(thief)
		notify(thief, "La flor se guardó en tu colección al salir del servidor.", "good")
	end
end

local function beginCarry(thief: Player, owner: Player, plantItem: any): boolean
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plantData = PlantConfig[plantItem.plantId]
	if not character or not humanoid or not root or not plantData then
		return false
	end

	local model = Instance.new("Model")
	model.Name = "CarriedStolenPlant"
	model.Parent = character
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Anchored = false
	stem.CanCollide = false
	stem.Massless = true
	stem.Size = Vector3.new(0.35, 1.8, 0.35)
	stem.Color = Color3.fromRGB(67, 151, 74)
	stem.Material = Enum.Material.SmoothPlastic
	stem.CFrame = root.CFrame * CFrame.new(0, 0.4, -1.8)
	stem.Parent = model
	local bloom = Instance.new("Part")
	bloom.Name = "Flower"
	bloom.Anchored = false
	bloom.CanCollide = false
	bloom.Massless = true
	bloom.Size = Vector3.new(1.2, 1.2, 1.2)
	bloom.Color = plantItem.mutation == "Gold" and Color3.fromRGB(255, 207, 72)
		or plantItem.mutation == "Diamond" and Color3.fromRGB(99, 222, 255)
		or plantData.color
	bloom.Material = if plantItem.mutation then Enum.Material.Neon else Enum.Material.SmoothPlastic
	bloom.CFrame = root.CFrame * CFrame.new(0, 1.4, -1.8)
	bloom.Parent = model
	for _, part in ipairs({ stem, bloom }) do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	carryByUser[thief.UserId] = {
		item = plantItem,
		ownerUserId = owner.UserId,
		model = model,
		humanoid = humanoid,
		originalSpeed = humanoid.WalkSpeed,
	}
	thief:SetAttribute("CarryingStolenPlant", true)
	humanoid.WalkSpeed = math.max(8, humanoid.WalkSpeed * 0.9)
	humanoid.Died:Connect(function()
		if carryByUser[thief.UserId] then
			restoreCarriedPlant(thief, true)
		end
	end)
	return true
end

-- Si te pillan: vuelves a tu jardín y vas lento unos segundos (efecto cómico).
local function sendThiefHome(thief: Player)
	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local garden = GardenService.GetGardenModel(thief)
	if not (character and root and humanoid and garden) then
		return
	end

	confetti(root)
	character:PivotTo(CFrame.new(GardenService.GetEntryPosition(garden, 4)))

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = math.max(6, originalSpeed * 0.4)
	task.delay(GameConfig.StealLockoutAfterCaught, function()
		if humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

local function flashPlot(plotPart: BasePart)
	local original = plotPart.Color
	plotPart.Color = Color3.fromRGB(255, 90, 90)
	task.delay(GameConfig.StealAlarmDuration, function()
		if plotPart.Parent then
			plotPart.Color = original
		end
	end)
end

local function attemptSteal(thief: Player, owner: Player, plotIndex: number, plotPart: BasePart)
	if thief == owner then
		return
	end
	if thief:GetAttribute("CarryingStolenPlant") == true then
		notify(thief, "Primero lleva la flor que robaste hasta tu jardín.", "warn")
		return
	end

	local now = os.clock()
	local cooldown = (cooldownUntil[thief.UserId] or 0) - now
	if cooldown > 0 then
		notify(thief, "⏳ Espera " .. math.ceil(cooldown) .. "s para robar otra vez", "warn")
		return
	end

	local ownerProfile = DataService.GetProfile(owner)
	local thiefProfile = DataService.GetProfile(thief)
	if not ownerProfile or not thiefProfile then
		return
	end

	local plotData = ownerProfile.plots[plotIndex]
	local plantData = plotData and PlantConfig[plotData.plantId]
	if not plotData or not plantData then
		notify(thief, "Ya no hay planta aquí", "warn")
		return
	end
	if (os.time() - plotData.plantedAt) < plantData.growTimeSeconds then
		notify(thief, "🌱 Aún está creciendo", "warn")
		return
	end

	-- Distancia (anti-trampas): el ladrón debe estar realmente cerca.
	local root = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - plotPart.Position).Magnitude > GameConfig.StealRange + 6 then
		return
	end

	local shieldLeft = (owner:GetAttribute("ShieldUntil") or 0) - os.time()
	local domeLeft = (owner:GetAttribute("GardenShieldUntil") or 0) - os.time()
	if shieldLeft > 0 or domeLeft > 0 then
		shieldLeft = math.max(shieldLeft, domeLeft)
		notify(thief, "🛡️ Jardín protegido (" .. shieldLeft .. "s)", "warn")
		return
	end

	cooldownUntil[thief.UserId] = now + GameConfig.StealCooldown

	-- Alarma para el dueño (siempre suena al intentar robar)
	notify(owner, "🚨 ¡" .. thief.DisplayName .. " intenta robar tu " .. plantData.displayName .. "!", "alarm")
	alarmEvent:FireClient(owner, { duration = GameConfig.StealAlarmDuration })
	flashPlot(plotPart)

	local chance = math.clamp(
		GameConfig.StealBaseSuccessChance - DefenseService.GetChanceReduction(owner),
		DefenseConfig.MinStealChance,
		1
	)

	if math.random() < chance then
		local stolen, plantItem = PlantService.StealCrop(owner, thief, plotIndex)
		if not stolen then
			notify(thief, "No se pudo recoger esa planta (" .. tostring(plantItem) .. ")", "warn")
			return
		end
		PlantService.RefreshPlot(owner, plotIndex)
		StealService.GrantShield(owner, DefenseConfig.StolenShieldSeconds)

		if not beginCarry(thief, owner, plantItem) then
			local ownerProfile = DataService.GetProfile(owner)
			if ownerProfile and InventoryService.AddPlant(owner, plantItem) then
				ownerProfile.stats.plantsLost = math.max(0, ownerProfile.stats.plantsLost - 1)
				DataService.MarkDirty(owner)
			else
				warn("[StealService] Could not return a plant after failed carry setup:", plantData.id)
			end
			notify(thief, "No se pudo empezar a transportar la flor.", "warn")
			return
		end
		notify(thief, "🌼 ¡Lleva " .. plantData.displayName .. " hasta tu jardín para asegurarla!", "good")
		notify(owner, "😮 ¡" .. thief.DisplayName .. " lleva tu " .. plantData.displayName .. "! Protege tu jardín.", "alarm")
		resolvedEvent:FireClient(thief, { success = true, carrying = true, plantId = plantData.id })
		resolvedEvent:FireClient(owner, { success = false, plantId = plantData.id, stolen = true })
	else
		notify(thief, "😵 ¡Te pillaron! Vuelves a tu jardín", "warn")
		notify(owner, "✅ ¡Defendiste tu jardín!", "good")
		QuestService.Report(owner, "defend", 1)
		resolvedEvent:FireClient(thief, { success = false, plantId = plantData.id })
		sendThiefHome(thief)
	end
end

function StealService.Init()
	GardenService.PlotCreated:Connect(function(owner: Player, plotIndex: number, plotPart: BasePart)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Steal"
		prompt.ActionText = "Steal"
		prompt.ObjectText = "Ripe plant"
		prompt.HoldDuration = GameConfig.StealDuration
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.Parent = plotPart
		-- El cliente decide localmente cuándo mostrarlo (planta madura y
		-- jardín ajeno); el servidor revalida todo en attemptSteal.

		prompt.Triggered:Connect(function(thief: Player)
			attemptSteal(thief, owner, plotIndex, plotPart)
		end)
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.time()
		for userId, activeUntil in pairs(domeUntil) do
			local owner = Players:GetPlayerByUserId(userId)
			if activeUntil <= now or not owner then
				domeUntil[userId] = nil
				local dome = domeByUser[userId]
				if dome then
					dome:Destroy()
					domeByUser[userId] = nil
				end
				if owner then
					owner:SetAttribute("GardenShieldUntil", 0)
				end
			else
				local garden = GardenService.GetGardenModel(owner)
				local boundary = garden and garden:FindFirstChild("YardBoundary")
				local floor = boundary and boundary:FindFirstChild("GardenFloor")
				if floor and floor:IsA("BasePart") then
					local dome = domeByUser[userId]
					if dome then
						dome.Size = Vector3.new(floor.Size.X + 8, 34, floor.Size.Z + 8)
						dome.Position = floor.Position + Vector3.new(0, 16, 0)
					end
					for _, visitor in ipairs(Players:GetPlayers()) do
						if visitor ~= owner then
							local character = visitor.Character
							local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
							if root then
								local localPosition = floor.CFrame:PointToObjectSpace(root.Position)
								if math.abs(localPosition.X) <= floor.Size.X / 2 + 3
									and math.abs(localPosition.Z) <= floor.Size.Z / 2 + 3
									and localPosition.Y >= -4 and localPosition.Y <= 32 then
									character:PivotTo(CFrame.new(GardenService.GetEntryPosition(garden, 3, 3)))
								end
							end
						end
					end
				end
			end
		end

		for userId, carry in pairs(carryByUser) do
			local thief = Players:GetPlayerByUserId(userId)
			local character = thief and thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local garden = thief and GardenService.GetGardenModel(thief)
			if thief and root and garden then
				local base = GardenService.GetEntryPosition(garden, 0)
				if (root.Position - base).Magnitude <= 13 then
					local profile = DataService.GetProfile(thief)
					if profile and InventoryService.AddPlant(thief, carry.item) then
						profile.stats.plantsStolen += 1
						DataService.MarkDirty(thief)
						local plantData = PlantConfig[carry.item.plantId]
						QuestService.Report(thief, "steal", 1)
						notify(thief, "🎉 ¡" .. (plantData and plantData.displayName or "La flor") .. " está a salvo en tu jardín!", "good")
						local owner = Players:GetPlayerByUserId(carry.ownerUserId)
						if owner then
							notify(owner, "La flor llegó a otro jardín.", "alarm")
						end
						if plantData and plantData.rarity ~= "Common" then
							notifyEvent:FireAllClients({
								text = "🕵️ " .. thief.DisplayName .. " se llevó una " .. plantData.displayName .. " (" .. plantData.rarity .. ")",
								kind = "social",
							})
						end
						resolvedEvent:FireClient(thief, { success = true, delivered = true, plantId = carry.item.plantId })
						restoreCarriedPlant(thief, false, true)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldownUntil[player.UserId] = nil
		tutorialClaims[player.UserId] = nil
		if carryByUser[player.UserId] then
			restoreCarriedPlant(player, true)
		end
		local dome = domeByUser[player.UserId]
		if dome then
			dome:Destroy()
		end
		domeByUser[player.UserId] = nil
		domeUntil[player.UserId] = nil
		domeCooldownUntil[player.UserId] = nil
	end)
end

-- Jardín del Vecino: aparece una planta nueva cada minuto y su rareza mejora con el tiempo.
function StealService.CreateTutorialGarden(center: Vector3)
	local model = Instance.new("Model")
	model.Name = "NeighborGarden"
	model.Parent = workspace

	local startedAt = os.clock()
	local spawnCount = 0
	local columns = 8
	local spacing = 10
	local random = Random.new()

	local soil = Instance.new("Part")
	soil.Name = "NeighborSoil"
	soil.Anchored = true
	soil.Size = Vector3.new(columns * spacing, 0.4, spacing + 4)
	soil.Position = center + Vector3.new(0, -0.2, 2)
	soil.Material = Enum.Material.Ground
	soil.Color = Color3.fromRGB(120, 85, 55)
	soil.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "NeighborSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.Position = center + Vector3.new(0, 9, -7)
	sign.Parent = model
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.fromOffset(190, 48)
	signGui.MaxDistance = 60
	signGui.Adornee = sign
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.Text = "Jardín del Vecino\nUna planta nueva cada minuto"
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = signGui

	local function getSpawnRarity(elapsedMinutes: number): string
		if elapsedMinutes >= 140 then
			return "Celestial"
		elseif elapsedMinutes >= 70 then
			return "Mythic"
		elseif elapsedMinutes >= 30 then
			return "Legendary"
		elseif elapsedMinutes >= 10 then
			return "Epic"
		end
		return "Common"
	end

	local function spawnPlant()
		local elapsedMinutes = (os.clock() - startedAt) / 60
		local rarityId = getSpawnRarity(elapsedMinutes)
		local candidates = {}
		for _, plantId in ipairs(PlantConfig.Order) do
			local data = PlantConfig[plantId]
			if data.rarity == rarityId then
				table.insert(candidates, plantId)
			end
		end
		table.sort(candidates)
		if #candidates == 0 then
			warn("[StealService] No plants configured for neighbor garden rarity:", rarityId)
			return
		end

		local plantId = candidates[random:NextInteger(1, #candidates)]
		local data = PlantConfig[plantId]
		local rarity = RarityConfig[rarityId]
		spawnCount += 1
		local column = (spawnCount - 1) % columns
		local row = math.floor((spawnCount - 1) / columns)
		local localX = (column - (columns - 1) / 2) * spacing
		local localZ = row * spacing
		local plantPosition = center + Vector3.new(localX, 0, localZ)

		local rowCount = row + 1
		soil.Size = Vector3.new(columns * spacing, 0.4, rowCount * spacing + 4)
		soil.Position = center + Vector3.new(0, -0.2, (rowCount - 1) * spacing / 2 + 2)

		local pad = Instance.new("Part")
		pad.Name = "NeighborPlot_" .. spawnCount
		pad.Anchored = true
		pad.Size = Vector3.new(8, 1, 8)
		pad.Position = plantPosition + Vector3.new(0, 0.5, 0)
		pad.Material = Enum.Material.Grass
		pad.Color = Color3.fromRGB(91, 154, 76)
		pad.Parent = model

		local plant = Instance.new("Part")
		plant.Name = "Plant_" .. spawnCount
		plant.Shape = Enum.PartType.Ball
		plant.Anchored = true
		plant.CanCollide = false
		plant.Size = Vector3.new(3.4, 3.4, 3.4)
		plant.Position = pad.Position + Vector3.new(0, 2.2, 0)
		plant.Color = data.color
		plant.Material = Enum.Material.SmoothPlastic
		plant.Parent = model

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(150, 28)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.MaxDistance = 60
		gui.Adornee = plant
		gui.Parent = plant
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = rarity.displayName .. " · " .. data.displayName
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = rarity.color
		label.TextStrokeTransparency = 0.4
		label.Parent = gui

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TutorialSteal"
		prompt.ActionText = "Steal"
		prompt.ObjectText = rarity.displayName .. " · " .. data.displayName
		prompt.HoldDuration = 2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.Parent = pad

		local spawnId = tostring(spawnCount)
		prompt.Triggered:Connect(function(player: Player)
			local claims = tutorialClaims[player.UserId]
			if not claims then
				claims = {}
				tutorialClaims[player.UserId] = claims
			end
			if claims[spawnId] then
				notify(player, "Ya has conseguido la semilla de esta planta.", "warn")
				return
			end
			claims[spawnId] = true
			confetti(pad)

			InventoryService.AddSeed(player, plantId, 1)
			EconomyService.AddCash(player, 20, "tutorial_steal")
			QuestService.Report(player, "steal", 1)
			notify(player, "🎉 ¡Robaste " .. data.displayName .. "! +semilla +$20", "good")
		end)

		signLabel.Text = "Jardín del Vecino\n" .. spawnCount .. " plantas · 1 nueva/min"
	end

	task.spawn(function()
		while model.Parent do
			task.wait(60)
			if model.Parent then
				spawnPlant()
			end
		end
	end)
end

return StealService
