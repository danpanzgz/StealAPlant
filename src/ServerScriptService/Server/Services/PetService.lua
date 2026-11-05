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

local function addBlock(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	local block = Instance.new("Part")
	block.Name = name
	block.Size = size
	block.Color = color
	block.Material = material or Enum.Material.SmoothPlastic
	block.Anchored = true
	block.CanCollide = false
	block.CanTouch = false
	block.CanQuery = false
	block.CFrame = CFrame.new(offset)
	block.Parent = model
	return block
end

local function createPetModel(petId: string): Model?
	local petData = PetConfig.Pets[petId]
	if not petData then
		return nil
	end

	local rarity = RarityConfig[petData.rarity]
	local model = Instance.new("Model")
	model.Name = "BlockPet_" .. petId

	local root = addBlock(model, "Root", Vector3.new(0.1, 0.1, 0.1), Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root
	addBlock(model, "Body", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 0, 0), petData.color)

	local dark = Color3.fromRGB(42, 43, 55)
	local cream = Color3.fromRGB(255, 246, 220)
	local muzzleColor = petData.color:Lerp(cream, 0.45)
	addBlock(model, "Muzzle", Vector3.new(0.9, 0.52, 0.18), Vector3.new(0, -0.38, -1.16), muzzleColor)
	addBlock(model, "LeftEyeWhite", Vector3.new(0.34, 0.4, 0.12), Vector3.new(-0.43, 0.24, -1.14), cream)
	addBlock(model, "RightEyeWhite", Vector3.new(0.34, 0.4, 0.12), Vector3.new(0.43, 0.24, -1.14), cream)
	addBlock(model, "LeftPupil", Vector3.new(0.17, 0.28, 0.08), Vector3.new(-0.4, 0.22, -1.22), dark)
	addBlock(model, "RightPupil", Vector3.new(0.17, 0.28, 0.08), Vector3.new(0.46, 0.22, -1.22), dark)
	addBlock(model, "LeftEyeShine", Vector3.new(0.07, 0.08, 0.04), Vector3.new(-0.43, 0.29, -1.27), cream)
	addBlock(model, "RightEyeShine", Vector3.new(0.07, 0.08, 0.04), Vector3.new(0.43, 0.29, -1.27), cream)
	addBlock(model, "Nose", Vector3.new(0.22, 0.16, 0.12), Vector3.new(0, -0.11, -1.28), petData.accentColor)
	addBlock(model, "Collar", Vector3.new(1.05, 0.18, 0.16), Vector3.new(0, -0.82, -1.13), Color3.fromRGB(126, 78, 47))
	addBlock(model, "CollarTag", Vector3.new(0.22, 0.3, 0.12), Vector3.new(0, -0.98, -1.24), petData.accentColor)
	addBlock(model, "LeftCheek", Vector3.new(0.22, 0.12, 0.08), Vector3.new(-0.72, -0.16, -1.2), petData.accentColor:Lerp(cream, 0.4))
	addBlock(model, "RightCheek", Vector3.new(0.22, 0.12, 0.08), Vector3.new(0.72, -0.16, -1.2), petData.accentColor:Lerp(cream, 0.4))
	addBlock(model, "LeftFoot", Vector3.new(0.56, 0.38, 0.58), Vector3.new(-0.62, -1.08, -0.38), petData.accentColor)
	addBlock(model, "RightFoot", Vector3.new(0.56, 0.38, 0.58), Vector3.new(0.62, -1.08, -0.38), petData.accentColor)

	local feature = petData.feature
	if feature == "wings" or feature == "fins" then
		addBlock(model, "LeftFeature", Vector3.new(0.65, 1.05, 0.3), Vector3.new(-1.32, 0.08, 0.08), petData.accentColor)
		addBlock(model, "RightFeature", Vector3.new(0.65, 1.05, 0.3), Vector3.new(1.32, 0.08, 0.08), petData.accentColor)
	elseif feature == "longEars" or feature == "roundEars" or feature == "ears" then
		local earSize = if feature == "longEars" then Vector3.new(0.44, 1.1, 0.45) else Vector3.new(0.58, 0.58, 0.48)
		addBlock(model, "LeftEar", earSize, Vector3.new(-0.72, 1.25, 0.02), petData.accentColor)
		addBlock(model, "RightEar", earSize, Vector3.new(0.72, 1.25, 0.02), petData.accentColor)
	elseif feature == "horn" or feature == "antlers" or feature == "crown" then
		addBlock(model, "CrownBase", Vector3.new(1.15, 0.25, 0.4), Vector3.new(0, 1.16, 0), petData.accentColor)
		addBlock(model, "CrownLeft", Vector3.new(0.3, 0.75, 0.32), Vector3.new(-0.38, 1.58, 0), petData.accentColor)
		addBlock(model, "CrownRight", Vector3.new(0.3, 0.75, 0.32), Vector3.new(0.38, 1.58, 0), petData.accentColor)
	elseif feature == "gills" then
		for _, side in ipairs({ -1, 1 }) do
			for index = 1, 3 do
				addBlock(
					model,
					"Gill",
					Vector3.new(0.28, 0.18, 0.28),
					Vector3.new(side * 1.2, 0.35 - index * 0.38, -0.05),
					petData.accentColor
				)
			end
		end
	elseif feature == "beak" then
		addBlock(model, "Beak", Vector3.new(0.5, 0.3, 0.42), Vector3.new(0, -0.12, -1.28), petData.accentColor)
	elseif feature == "stripes" then
		for _, offset in ipairs({
			Vector3.new(-0.82, 0.72, -1.14),
			Vector3.new(0.82, 0.72, -1.14),
			Vector3.new(0, -0.72, -1.14),
		}) do
			addBlock(model, "PixelStripe", Vector3.new(0.18, 0.48, 0.08), offset, petData.accentColor)
		end
	elseif feature == "mane" or feature == "shell" then
		addBlock(model, "BackFeature", Vector3.new(1.45, 1.45, 0.48), Vector3.new(0, 0.05, 1.25), petData.accentColor)
	elseif feature == "crystal" or feature == "spikes" or feature == "stripes" then
		for index = 1, 3 do
			addBlock(
				model,
				"BackAccent",
				Vector3.new(0.28, 0.58, 0.28),
				Vector3.new((index - 2) * 0.52, 1.23, 0.15),
				petData.accentColor,
				Enum.Material.Neon
			)
		end
	else
		addBlock(model, "Tail", Vector3.new(0.65, 0.65, 0.65), Vector3.new(0, -0.45, 1.28), petData.accentColor)
		if feature == "leaf" then
			addBlock(model, "Leaf", Vector3.new(0.24, 0.8, 0.24), Vector3.new(0, 1.28, 0.12), petData.accentColor)
		end
	end

	if rarity and rarity.order >= 3 then
		local highlight = Instance.new("Highlight")
		highlight.Name = "RarityAura"
		highlight.Adornee = model
		highlight.FillColor = rarity.color
		highlight.FillTransparency = if rarity.order >= 6 then 0.7 else 0.86
		highlight.OutlineColor = petData.accentColor
		highlight.OutlineTransparency = if rarity.order >= 5 then 0.05 else 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		local attachment = Instance.new("Attachment")
		attachment.Name = "AuraAttachment"
		attachment.Parent = root
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "RaritySparkles"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(petData.accentColor, rarity.color)
		particles.Rate = 2 + rarity.order * 2
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

		if rarity.order >= 5 then
			local light = Instance.new("PointLight")
			light.Name = "RarityGlow"
			light.Color = rarity.color
			light.Brightness = rarity.order >= 7 and 1.8 or 1
			light.Range = rarity.order >= 7 and 13 or 9
			light.Parent = root
		end
	end

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
	local function getTargetCFrame(now: number): CFrame
		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
		local bounce = if moving then math.abs(math.sin((now - startedAt) * 10)) * 0.24 else math.sin((now - startedAt) * 2.5) * 0.06
		local position = root.Position
			- root.CFrame.LookVector * 2.8
			+ root.CFrame.RightVector * 1.8
			+ Vector3.new(0, -1.5 + bounce, 0)
		return CFrame.lookAt(position, position + root.CFrame.LookVector)
	end

	model:PivotTo(getTargetCFrame(startedAt))
	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not player.Parent or not character.Parent or not root.Parent or not model.Parent then
			clearPet(player)
			return
		end
		model:PivotTo(model:GetPivot():Lerp(getTargetCFrame(os.clock()), math.min(deltaTime * 8, 1)))
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
