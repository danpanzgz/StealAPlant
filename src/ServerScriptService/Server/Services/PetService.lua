--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local PetService = {}
local activePets: { [Player]: { model: Model, connection: RBXScriptConnection, character: Model } } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

-- Escala del modelo en construcción (se fija en createPetModel; sin yields).
local buildScale = 1

local function addBlock(
	model: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Size = size * buildScale
	block.Color = color
	block.Material = material or Enum.Material.SmoothPlastic
	block.Transparency = transparency or 0
	block.Anchored = true
	block.CanCollide = false
	block.CanTouch = false
	block.CanQuery = false
	block.CastShadow = false
	block.CFrame = CFrame.new(offset * buildScale)
	block.Parent = model
	return block
end

-- Escala por rareza: cuanto más rara, más grande y vistosa.
local SCALE_BY_ORDER = { 1, 1, 1, 1.05, 1.15, 1.3, 1.4 }
local GOLD = Color3.fromRGB(255, 214, 92)

-- Partes máximas (peor caso, rasgo "gills"): Common 14 · Uncommon 20 · Rare 26
-- · Epic 29 · Legendary 33 · Mythic 36 · Celestial 43.
local function createPetModel(petId: string): Model?
	local petData = PetConfig.Pets[petId]
	if not petData then
		return nil
	end

	local rarity = RarityConfig[petData.rarity]
	local ro = if rarity then rarity.order else 1
	buildScale = SCALE_BY_ORDER[math.clamp(ro, 1, #SCALE_BY_ORDER)]
	local model = Instance.new("Model")
	model.Name = "BlockPet_" .. petId
	model:SetAttribute("PetScale", buildScale)

	local root = addBlock(model, "Root", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root
	addBlock(model, "Body", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 0, 0), petData.color)

	local dark = Color3.fromRGB(42, 43, 55)
	local cream = Color3.fromRGB(255, 246, 220)
	local accent = petData.accentColor
	local muzzleColor = petData.color:Lerp(cream, 0.45)
	local fancy = if ro >= 6 then Enum.Material.Neon else Enum.Material.SmoothPlastic

	-- Común: cuerpo, hocico, ojos, nariz y su rasgo.
	addBlock(model, "Muzzle", Vector3.new(0.9, 0.52, 0.18), Vector3.new(0, -0.38, -1.16), muzzleColor)
	addBlock(model, "LeftEyeWhite", Vector3.new(0.34, 0.4, 0.12), Vector3.new(-0.43, 0.24, -1.14), cream)
	addBlock(model, "RightEyeWhite", Vector3.new(0.34, 0.4, 0.12), Vector3.new(0.43, 0.24, -1.14), cream)
	addBlock(model, "LeftPupil", Vector3.new(0.17, 0.28, 0.08), Vector3.new(-0.4, 0.22, -1.22), dark)
	addBlock(model, "RightPupil", Vector3.new(0.17, 0.28, 0.08), Vector3.new(0.46, 0.22, -1.22), dark)
	addBlock(model, "Nose", Vector3.new(0.22, 0.16, 0.12), Vector3.new(0, -0.11, -1.28), accent, fancy)

	-- Poco común: patas, mejillas y brillo en los ojos.
	if ro >= 2 then
		addBlock(model, "LeftFoot", Vector3.new(0.56, 0.38, 0.58), Vector3.new(-0.62, -1.08, -0.38), accent)
		addBlock(model, "RightFoot", Vector3.new(0.56, 0.38, 0.58), Vector3.new(0.62, -1.08, -0.38), accent)
		addBlock(model, "LeftCheek", Vector3.new(0.22, 0.12, 0.08), Vector3.new(-0.72, -0.16, -1.2), accent:Lerp(cream, 0.4))
		addBlock(model, "RightCheek", Vector3.new(0.22, 0.12, 0.08), Vector3.new(0.72, -0.16, -1.2), accent:Lerp(cream, 0.4))
		addBlock(model, "LeftEyeShine", Vector3.new(0.07, 0.08, 0.04), Vector3.new(-0.43, 0.29, -1.27), cream)
		addBlock(model, "RightEyeShine", Vector3.new(0.07, 0.08, 0.04), Vector3.new(0.43, 0.29, -1.27), cream)
	end

	-- Raro: bufanda con colgante y parches de color en el lomo y los costados.
	if ro >= 3 then
		addBlock(model, "Collar", Vector3.new(1.05, 0.18, 0.16), Vector3.new(0, -0.82, -1.13), Color3.fromRGB(126, 78, 47))
		addBlock(model, "CollarTag", Vector3.new(0.22, 0.3, 0.12), Vector3.new(0, -0.98, -1.24), accent, fancy)
		local patch = petData.color:Lerp(accent, 0.45)
		addBlock(model, "BackPatchA", Vector3.new(0.7, 0.12, 0.7), Vector3.new(-0.35, 1.13, 0.4), patch)
		addBlock(model, "BackPatchB", Vector3.new(0.5, 0.12, 0.5), Vector3.new(0.55, 1.13, -0.2), patch)
		addBlock(model, "SidePatchL", Vector3.new(0.12, 0.6, 0.6), Vector3.new(-1.13, 0.1, 0.35), patch)
		addBlock(model, "SidePatchR", Vector3.new(0.12, 0.6, 0.6), Vector3.new(1.13, 0.1, 0.35), patch)
	end

	local feature = petData.feature
	local featureMaterial = if ro >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if feature == "wings" or feature == "fins" then
		addBlock(model, "LeftFeature", Vector3.new(0.65, 1.05, 0.3), Vector3.new(-1.32, 0.08, 0.08), accent, featureMaterial)
		addBlock(model, "RightFeature", Vector3.new(0.65, 1.05, 0.3), Vector3.new(1.32, 0.08, 0.08), accent, featureMaterial)
	elseif feature == "longEars" or feature == "roundEars" or feature == "ears" then
		local earSize = if feature == "longEars" then Vector3.new(0.44, 1.1, 0.45) else Vector3.new(0.58, 0.58, 0.48)
		addBlock(model, "LeftEar", earSize, Vector3.new(-0.72, 1.25, 0.02), accent, featureMaterial)
		addBlock(model, "RightEar", earSize, Vector3.new(0.72, 1.25, 0.02), accent, featureMaterial)
	elseif feature == "horn" or feature == "antlers" or feature == "crown" then
		addBlock(model, "CrownBase", Vector3.new(1.15, 0.25, 0.4), Vector3.new(0, 1.16, 0), accent, featureMaterial)
		addBlock(model, "CrownLeft", Vector3.new(0.3, 0.75, 0.32), Vector3.new(-0.38, 1.58, 0), accent, featureMaterial)
		addBlock(model, "CrownRight", Vector3.new(0.3, 0.75, 0.32), Vector3.new(0.38, 1.58, 0), accent, featureMaterial)
	elseif feature == "gills" then
		for _, side in ipairs({ -1, 1 }) do
			for index = 1, 3 do
				addBlock(model, "Gill", Vector3.new(0.28, 0.18, 0.28), Vector3.new(side * 1.2, 0.35 - index * 0.38, -0.05), accent, featureMaterial)
			end
		end
	elseif feature == "beak" then
		addBlock(model, "Beak", Vector3.new(0.5, 0.3, 0.42), Vector3.new(0, -0.12, -1.28), accent, featureMaterial)
	elseif feature == "stripes" then
		for _, offset in ipairs({
			Vector3.new(-0.82, 0.72, -1.14),
			Vector3.new(0.82, 0.72, -1.14),
			Vector3.new(0, -0.72, -1.14),
		}) do
			addBlock(model, "PixelStripe", Vector3.new(0.18, 0.48, 0.08), offset, accent, featureMaterial)
		end
	elseif feature == "mane" or feature == "shell" then
		addBlock(model, "BackFeature", Vector3.new(1.45, 1.45, 0.48), Vector3.new(0, 0.05, 1.25), accent, featureMaterial)
	elseif feature == "crystal" or feature == "spikes" then
		for index = 1, 3 do
			addBlock(model, "BackAccent", Vector3.new(0.28, 0.58, 0.28), Vector3.new((index - 2) * 0.52, 1.23, 0.15), accent, Enum.Material.Neon)
		end
	else
		addBlock(model, "Tail", Vector3.new(0.65, 0.65, 0.65), Vector3.new(0, -0.45, 1.28), accent, featureMaterial)
		if feature == "leaf" then
			addBlock(model, "Leaf", Vector3.new(0.24, 0.8, 0.24), Vector3.new(0, 1.28, 0.12), accent, featureMaterial)
		end
	end

	-- Épico: brillo Neon en detalles mayores (alas pequeñas o cristales).
	if ro >= 4 then
		if feature == "wings" or feature == "fins" then
			addBlock(model, "WingTipL", Vector3.new(0.3, 0.6, 0.22), Vector3.new(-1.6, 0.7, 0.1), rarity.color, Enum.Material.Neon)
			addBlock(model, "WingTipR", Vector3.new(0.3, 0.6, 0.22), Vector3.new(1.6, 0.7, 0.1), rarity.color, Enum.Material.Neon)
		else
			for index = 1, 3 do
				addBlock(model, "TuftCrystal", Vector3.new(0.22, 0.5 + index * 0.08, 0.22), Vector3.new((index - 2) * 0.4, 1.2, 0.85), rarity.color, Enum.Material.Neon)
			end
		end
	end

	-- Legendario: halo flotante dorado.
	local function addHalo(name: string, half: number, height: number, color: Color3)
		addBlock(model, name, Vector3.new(half * 2, 0.12, 0.16), Vector3.new(0, height, -half), color, Enum.Material.Neon)
		addBlock(model, name, Vector3.new(half * 2, 0.12, 0.16), Vector3.new(0, height, half), color, Enum.Material.Neon)
		addBlock(model, name, Vector3.new(0.16, 0.12, half * 2), Vector3.new(-half, height, 0), color, Enum.Material.Neon)
		addBlock(model, name, Vector3.new(0.16, 0.12, half * 2), Vector3.new(half, height, 0), color, Enum.Material.Neon)
	end
	if ro >= 5 then
		addHalo("Halo", 0.8, 2.05, GOLD)
	end

	-- Mítico: 3 orbes que orbitan (se animan en followCharacter).
	if ro >= 6 then
		for index = 1, 3 do
			local orb = addBlock(model, "Orb", Vector3.new(0.38, 0.38, 0.38), Vector3.new(0, 1.2, 0), if index == 2 then accent else rarity.color, Enum.Material.Neon)
			orb.Shape = Enum.PartType.Ball
			orb:SetAttribute("OrbitIndex", index)
		end
	end

	-- Celestial: segundo halo, alas y cola de luz translúcidas.
	if ro >= 7 then
		addHalo("HaloOuter", 1.15, 2.3, rarity.color)
		addBlock(model, "LightWingL", Vector3.new(0.12, 1.5, 1.2), Vector3.new(-1.6, 0.5, 0.9), Color3.new(1, 1, 1), Enum.Material.Neon, 0.45)
		addBlock(model, "LightWingR", Vector3.new(0.12, 1.5, 1.2), Vector3.new(1.6, 0.5, 0.9), Color3.new(1, 1, 1), Enum.Material.Neon, 0.45)
		addBlock(model, "LightTail", Vector3.new(0.4, 0.4, 1.4), Vector3.new(0, -0.2, 1.95), rarity.color, Enum.Material.Neon, 0.4)
	end

	if rarity and ro >= 3 then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RarityAura"
		highlight.Adornee = model
		highlight.FillColor = rarity.color
		highlight.FillTransparency = if ro >= 6 then 0.7 else 0.86
		highlight.OutlineColor = accent
		highlight.OutlineTransparency = if ro >= 5 then 0.05 else 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		local attachment = Instance.new("Attachment")
		attachment.Name = "AuraAttachment"
		attachment.Parent = root
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "RaritySparkles"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		-- Legendario en adelante: chispas doradas.
		particles.Color = if ro >= 5 then ColorSequence.new(GOLD, rarity.color) else ColorSequence.new(accent, rarity.color)
		particles.Rate = 2 + ro * 2
		particles.Lifetime = NumberRange.new(0.7, 1.25)
		particles.Speed = NumberRange.new(0.25, 0.8)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.5, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.LightEmission = 0.75
		particles.Parent = attachment

		-- Épico en adelante: estela ligera tras la mascota (Celestial: estrellas).
		if ro >= 4 then
			local trailAttachment = Instance.new("Attachment")
			trailAttachment.Name = "TrailAttachment"
			trailAttachment.Position = Vector3.new(0, -0.6, 1.2) * buildScale
			trailAttachment.Parent = root
			local trail = Instance.new("ParticleEmitter")
			trail.Name = "PetTrail"
			trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			trail.Color = ColorSequence.new(rarity.color, if ro >= 7 then Color3.new(1, 1, 1) else accent)
			trail.Rate = if ro >= 7 then 8 else 4
			trail.Lifetime = NumberRange.new(0.6, 1)
			trail.Speed = NumberRange.new(0, 0.3)
			trail.SpreadAngle = Vector2.new(25, 25)
			trail.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if ro >= 7 then 0.45 else 0.3),
				NumberSequenceKeypoint.new(1, 0),
			})
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			trail.LightEmission = 0.9
			trail.Parent = trailAttachment
		end

		if ro >= 5 then
			local light = Instance.new("PointLight")
			light.Name = "RarityGlow"
			light.Color = if ro >= 5 and ro < 7 then GOLD:Lerp(rarity.color, if ro >= 6 then 0.5 else 0) else rarity.color
			light.Brightness = ro >= 7 and 1.8 or 1
			light.Range = ro >= 7 and 13 or 9
			light.Parent = root
		end
	end

	buildScale = 1
	return model
end

local function clearPet(player: Player)
	local active = activePets[player]
	if active then
		active.connection:Disconnect()
		active.model:Destroy()
		activePets[player] = nil
	end
end

local function followCharacter(player: Player, character: Model)
	local active = activePets[player]
	if active and active.character == character and active.model.Parent then
		return
	end
	clearPet(player)

	local profile = DataService.GetProfile(player)
	local petId = profile and profile.inventory.equippedPet
	local petData = petId and PetConfig.Pets[petId]
	if not petData then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or not player.Parent then
		return
	end

	local model = createPetModel(petId)
	if not model then
		return
	end
	model.Name = "BlockPet_" .. player.UserId
	model.Parent = workspace

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local startedAt = os.clock()
	local petScale = (model:GetAttribute("PetScale") :: number?) or 1
	local orbs: { Part } = {}
	for _, child in ipairs(model:GetChildren()) do
		if child.Name == "Orb" and child:IsA("Part") then
			table.insert(orbs, child)
		end
	end
	local function getTargetCFrame(now: number): CFrame
		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
		local bounce = if moving then math.abs(math.sin((now - startedAt) * 10)) * 0.24 else math.sin((now - startedAt) * 2.5) * 0.06
		local position = root.Position
			- root.CFrame.LookVector * (2.8 + (petScale - 1) * 2)
			+ root.CFrame.RightVector * (1.8 + (petScale - 1) * 1.5)
			+ Vector3.new(0, -2.9 + 1.27 * petScale + bounce, 0)
		return CFrame.lookAt(position, position + root.CFrame.LookVector)
	end

	model:PivotTo(getTargetCFrame(startedAt))
	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not player.Parent or not character.Parent or not root.Parent or not model.Parent then
			clearPet(player)
			return
		end
		model:PivotTo(model:GetPivot():Lerp(getTargetCFrame(os.clock()), math.min(deltaTime * 8, 1)))
		-- Orbes del Mítico/Celestial: giran alrededor de la mascota (<= 3 partes).
		if #orbs > 0 then
			local now = os.clock()
			local pivot = model:GetPivot()
			for index, orb in ipairs(orbs) do
				local angle = now * 1.8 + (index - 1) * (math.pi * 2 / 3)
				orb.CFrame = pivot * CFrame.new(
					math.cos(angle) * 1.9 * petScale,
					1.2 * petScale + math.sin(now * 2 + index) * 0.25,
					math.sin(angle) * 1.9 * petScale
				)
			end
		end
	end)
	activePets[player] = { model = model, connection = connection, character = character }
end

function PetService.LoadPlayer(player: Player)
	if characterConnections[player] then
		characterConnections[player]:Disconnect()
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		task.spawn(followCharacter, player, character)
	end)
	if player.Character then
		task.spawn(followCharacter, player, player.Character)
	end
end

function PetService.Equip(player: Player, petId: string): (boolean, string?)
	local profile = DataService.GetProfile(player)
	if not profile or not PetConfig.Pets[petId] then
		return false, "unknown_pet"
	end
	local owned = false
	for _, ownedPetId in ipairs(profile.inventory.pets) do
		if ownedPetId == petId then
			owned = true
			break
		end
	end
	if not owned then
		return false, "pet_not_owned"
	end

	profile.inventory.equippedPet = petId
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	clearPet(player)
	if player.Character then
		task.spawn(followCharacter, player, player.Character)
	end
	return true
end

function PetService.Init()
	Players.PlayerRemoving:Connect(function(player)
		clearPet(player)
		local connection = characterConnections[player]
		if connection then
			connection:Disconnect()
			characterConnections[player] = nil
		end
	end)
end

return PetService
