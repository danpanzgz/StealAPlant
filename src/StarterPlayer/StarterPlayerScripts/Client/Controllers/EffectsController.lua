--!strict
--[[
	EffectsController.lua
	Animaciones de momentos clave (solo presentación, nada se decide aquí):
	  - Plantar una semilla: nube de tierra, hojas y onda verde.
	  - Incubar un huevo: el huevo cae, se agita, se agrieta y explota en
	    confeti revelando la mascota (con su voz).
	  - Planta nueva en el Índice: tarjeta dorada con destellos.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)

local Client = script.Parent.Parent
local UI = require(Client.UI)
local ClientState = require(Client.ClientState)
local FarmArt = require(Client.Modules.FarmArt)
local AudioController = require(script.Parent.AudioController)

local EffectsController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local fxGui: ScreenGui
local hatching = false
local discoveryQueue: { any } = {}
local discoveryRunning = false

local BORDER = Color3.fromRGB(112, 78, 43)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 214, 90), Color3.fromRGB(120, 220, 140),
	Color3.fromRGB(110, 190, 255), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 160, 80),
}

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- ===== Plantar: tierra, hojas y onda ======================================

local function makeEmitter(parent: BasePart, color: Color3, size: number, speed: number, lifetime: number, accel: Vector3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = accel
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.LightEmission = 0
	emitter.Parent = parent
	return emitter
end

function EffectsController.PlayPlanting(position: Vector3, plantId: string?)
	local data = if plantId then PlantConfig[plantId] else nil
	local anchor = Instance.new("Part")
	anchor.Name = "PlantingFX"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace

	makeEmitter(anchor, Color3.fromRGB(122, 86, 55), 1.3, 14, 0.9, Vector3.new(0, -26, 0)):Emit(18) -- tierra
	makeEmitter(anchor, Color3.fromRGB(110, 200, 90), 0.9, 9, 1.1, Vector3.new(0, -8, 0)):Emit(8) -- hojas
	if data then
		makeEmitter(anchor, data.color, 0.6, 7, 1.2, Vector3.new(0, -4, 0)):Emit(6) -- color de la planta
	end

	-- Onda verde que se expande por el suelo.
	local ring = Instance.new("Part")
	ring.Name = "PlantingRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(140, 235, 120)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.25, 1.5, 1.5)
	ring.CFrame = CFrame.new(position.X, position.Y - 0.2, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Workspace
	tween(ring, 0.5, { Size = Vector3.new(0.25, 10, 10), Transparency = 1 })

	-- Pequeño "pop" del brote: un cubito verde que crece y rebota.
	local sprout = Instance.new("Part")
	sprout.Name = "PlantingSprout"
	sprout.Anchored = true
	sprout.CanCollide = false
	sprout.CanQuery = false
	sprout.CanTouch = false
	sprout.Color = Color3.fromRGB(110, 200, 90)
	sprout.Material = Enum.Material.SmoothPlastic
	sprout.Size = Vector3.new(0.2, 0.2, 0.2)
	sprout.Position = position + Vector3.new(0, 0.3, 0)
	sprout.Parent = Workspace
	tween(sprout, 0.25, { Size = Vector3.new(1.1, 1.6, 1.1), Position = position + Vector3.new(0, 1, 0) }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(sprout, 0.3, { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
	end)

	AudioController.PlayAt("Plant", position)
	Debris:AddItem(anchor, 2.5)
	Debris:AddItem(ring, 1)
	Debris:AddItem(sprout, 1)
end

-- ===== Confeti de pantalla ================================================

local function confettiBurst(parent: GuiObject, origin: UDim2, count: number, glyph: string?, power: number)
	for _ = 1, count do
		local piece: GuiObject
		if glyph then
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Text = glyph
			label.TextScaled = true
			label.TextColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
			label.Size = UDim2.fromOffset(22, 22)
			piece = label
		else
			local frame = Instance.new("Frame")
			frame.BorderSizePixel = 0
			frame.BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
			frame.Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(8, 14))
			piece = frame
		end
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = origin
		piece.ZIndex = 40
		piece.Rotation = rng:NextInteger(0, 360)
		piece.Parent = parent

		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(0.6, 1) * power
		local dx = math.cos(angle) * distance
		local dy = math.sin(angle) * distance * 0.8 - 40
		local target = UDim2.new(origin.X.Scale, origin.X.Offset + dx, origin.Y.Scale, origin.Y.Offset + dy)
		tween(piece, 0.7, { Position = target, Rotation = piece.Rotation + rng:NextInteger(-360, 360) }, Enum.EasingStyle.Quad)
		task.delay(0.55, function()
			if piece.Parent then
				local fall = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + 130)
				local t = tween(piece, 0.9, { Position = fall }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				if piece:IsA("Frame") then
					tween(piece, 0.9, { BackgroundTransparency = 1 })
				else
					tween(piece, 0.9, { TextTransparency = 1 })
				end
				t.Completed:Once(function()
					piece:Destroy()
				end)
			end
		end)
	end
end

-- ===== Incubar un huevo ====================================================

local function centered(parent: Instance, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Size = size
	frame.Position = position
	frame.ZIndex = 20
	frame.Parent = parent
	return frame
end

local function scaleArt(art: Frame, scale: number): UIScale
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = scale
	uiScale.Parent = art
	return uiScale
end

local function crackLines(parent: Frame, z: number)
	local color = Color3.fromRGB(102, 71, 46)
	local points = { { 24, 14 }, { 28, 20 }, { 22, 26 }, { 30, 32 }, { 24, 38 } }
	for index = 1, #points - 1 do
		local piece = Instance.new("Frame")
		piece.Name = "Crack"
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = color
		piece.Size = UDim2.fromOffset(4, 8)
		piece.Position = UDim2.fromOffset(points[index][1], points[index][2] + (index - 1) * 1)
		piece.ZIndex = z
		piece.Parent = parent
	end
end

-- Devuelve el resultado de `fetch` (la llamada al servidor). La animación del
-- huevo se muestra mientras se espera y se revela la mascota al terminar.
function EffectsController.HatchEgg(rarityId: string, fetch: () -> any): any
	if hatching then
		return fetch()
	end
	hatching = true

	local rarity = RarityConfig[rarityId]
	local rarityColor = if rarity then rarity.color else Color3.fromRGB(255, 220, 120)

	local overlay = Instance.new("Frame")
	overlay.Name = "EggHatchOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Active = true -- bloquea toques al mundo mientras dura
	overlay.ZIndex = 10
	overlay.Parent = fxGui
	tween(overlay, 0.25, { BackgroundTransparency = 0.35 })

	local stage = centered(overlay, UDim2.fromOffset(220, 240), UDim2.fromScale(0.5, 0.46))
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(160, 160)
	glow.BackgroundColor3 = rarityColor
	glow.BackgroundTransparency = 0.75
	glow.BorderSizePixel = 0
	glow.Rotation = 45
	glow.ZIndex = 21
	glow.Parent = stage

	local egg = FarmArt.CreateEggIcon(stage, rarityColor)
	local eggScale = scaleArt(egg, 0.1)
	egg.ZIndex = 22
	local startedAt = os.clock()

	-- Cae y rebota.
	AudioController.DuckMusic(6)
	AudioController.Play("EggDrop")
	egg.Position = UDim2.new(0.5, 0, -0.6, 0)
	tween(egg, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Bounce)
	tween(eggScale, 0.45, { Scale = 3.4 }, Enum.EasingStyle.Back)

	-- Se agita mientras el servidor responde (mínimo 4 sacudidas).
	local shaking = true
	task.spawn(function()
		task.wait(0.55)
		local direction = 1
		local shakes = 0
		while shaking or shakes < 4 do
			shakes += 1
			local angle = math.min(8 + shakes * 3, 24) * direction
			AudioController.Play("EggShake", 0.9 + shakes * 0.04)
			tween(egg, 0.12, { Rotation = angle }, Enum.EasingStyle.Sine)
			tween(glow, 0.12, { Size = UDim2.fromOffset(160 + shakes * 6, 160 + shakes * 6) })
			task.wait(0.14)
			direction = -direction
			if shakes >= 12 and not shaking then
				break
			end
		end
		tween(egg, 0.1, { Rotation = 0 })
	end)

	local result = fetch()
	local minDuration = 1.9
	local elapsed = os.clock() - startedAt
	if elapsed < minDuration then
		task.wait(minDuration - elapsed)
	end
	shaking = false

	if not (result and result.success) then
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		task.delay(0.25, function()
			overlay:Destroy()
		end)
		hatching = false
		return result
	end

	-- Revelado, en una tarea aparte para devolver el resultado enseguida.
	task.spawn(function()
		task.wait(0.2)
		crackLines(egg, 30)
		AudioController.Play("EggCrack")
		tween(egg, 0.08, { Rotation = 6 })
		task.wait(0.35)

		-- Destello + confeti + pet.
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0
		flash.BorderSizePixel = 0
		flash.ZIndex = 50
		flash.Parent = overlay
		tween(flash, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.55, function()
			flash:Destroy()
		end)

		AudioController.Play("EggHatch")
		egg:Destroy()
		confettiBurst(overlay, UDim2.fromScale(0.5, 0.46), 36, nil, 260)
		confettiBurst(overlay, UDim2.fromScale(0.5, 0.46), 10, "★", 200)

		local petData = PetConfig.Pets[result.petId]
		if petData then
			local pet = FarmArt.CreatePetIcon(stage, petData)
			pet.ZIndex = 24
			local petScale = scaleArt(pet, 0.2)
			tween(petScale, 0.5, { Scale = 3.4 }, Enum.EasingStyle.Back)
			task.delay(0.15, function()
				AudioController.PlayPetCry(result.petId)
			end)
			-- Saltito de alegría.
			task.delay(0.55, function()
				tween(pet, 0.18, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Quad)
				task.delay(0.18, function()
					tween(pet, 0.28, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Bounce)
				end)
			end)
		end

		local title = UI.Label(overlay, "¡" .. tostring(result.displayName) .. "!", UDim2.fromOffset(320, 40), UDim2.new(0.5, -160, 0.46, 130), Color3.new(1, 1, 1))
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.ZIndex = 30
		local sub = UI.Label(overlay, (if rarity then rarity.displayName else rarityId) .. " · Nueva mascota", UDim2.fromOffset(320, 26), UDim2.new(0.5, -160, 0.46, 170), rarityColor)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		sub.ZIndex = 30

		task.wait(3.2)
		tween(overlay, 0.3, { BackgroundTransparency = 1 })
		for _, child in ipairs(overlay:GetDescendants()) do
			if child:IsA("TextLabel") then
				tween(child, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end
		task.wait(0.35)
		overlay:Destroy()
		hatching = false
	end)

	return result
end

-- ===== Planta nueva en el Índice ==========================================

local function showDiscovery(info: any)
	local data = PlantConfig[info.plantId]
	if not data then
		return
	end
	local rarity = RarityConfig[data.rarity]
	local rarityColor = if rarity then rarity.color else Color3.fromRGB(255, 220, 120)

	local card = Instance.new("Frame")
	card.Name = "DiscoveryCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(300, 112)
	card.Position = UDim2.new(0.5, 0, 0, -140)
	card.BackgroundColor3 = Color3.fromRGB(79, 58, 39)
	card.BorderSizePixel = 4
	card.BorderColor3 = rarityColor
	card.ZIndex = 20
	card.Parent = fxGui

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(340, 140)
	limit.Parent = card

	local title = UI.Label(card, "📖 ¡PLANTA NUEVA!", UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 4), Color3.fromRGB(255, 226, 120))
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 22

	local iconHolder = centered(card, UDim2.fromOffset(70, 70), UDim2.fromOffset(52, 68))
	iconHolder.ZIndex = 21
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromOffset(66, 66)
	halo.BackgroundColor3 = rarityColor
	halo.BackgroundTransparency = 0.6
	halo.BorderSizePixel = 0
	halo.Rotation = 45
	halo.ZIndex = 21
	halo.Parent = iconHolder
	local crop = FarmArt.CreateCropIcon(iconHolder, info.plantId, data.color)
	crop.ZIndex = 23
	scaleArt(crop, 1.2)

	local mutationData = if info.mutation then MutationConfig[info.mutation] else nil
	local nameText = data.displayName .. (if mutationData then " · " .. tostring(info.mutation) else "")
	local name = UI.Label(card, nameText, UDim2.new(1, -110, 0, 26), UDim2.fromOffset(98, 32), Color3.new(1, 1, 1))
	name.ZIndex = 22
	local detail = UI.Label(card, (if rarity then rarity.displayName else data.rarity) .. " · Índice " .. info.discovered .. "/" .. info.total, UDim2.new(1, -110, 0, 20), UDim2.fromOffset(98, 60), rarityColor, false)
	detail.ZIndex = 22
	local hint = UI.Label(card, "Registrada en tu Índice", UDim2.new(1, -110, 0, 18), UDim2.fromOffset(98, 82), Color3.fromRGB(226, 205, 157), false)
	hint.ZIndex = 22

	AudioController.Play("Discovery")
	tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		-- Destellos desde el icono (posición aproximada de la tarjeta).
		confettiBurst(fxGui, UDim2.new(0.5, -90, 0, 138), 14, "✦", 120)
		confettiBurst(fxGui, UDim2.new(0.5, -90, 0, 138), 14, nil, 100)
	end)

	-- Latido del halo mientras está visible.
	task.spawn(function()
		for _ = 1, 3 do
			if not halo.Parent then
				return
			end
			tween(halo, 0.5, { Size = UDim2.fromOffset(78, 78), BackgroundTransparency = 0.8 }, Enum.EasingStyle.Sine)
			task.wait(0.5)
			tween(halo, 0.5, { Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 0.55 }, Enum.EasingStyle.Sine)
			task.wait(0.5)
		end
	end)

	task.wait(3.6)
	local out = tween(card, 0.4, { Position = UDim2.new(0.5, 0, 0, -140) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	out.Completed:Wait()
	card:Destroy()
end

local function processDiscoveries()
	if discoveryRunning then
		return
	end
	discoveryRunning = true
	task.spawn(function()
		while #discoveryQueue > 0 do
			local info = table.remove(discoveryQueue, 1)
			showDiscovery(info)
			task.wait(0.2)
		end
		discoveryRunning = false
	end)
end

function EffectsController.Init(hud: any)
	fxGui = Instance.new("ScreenGui")
	fxGui.Name = "EffectsGui"
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = true
	fxGui.DisplayOrder = 60
	fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fxGui.Parent = player:WaitForChild("PlayerGui")

	Net.GetRemoteEvent("PlantPlanted").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and typeof(payload.position) == "Vector3" then
			EffectsController.PlayPlanting(payload.position, payload.plantId)
		end
	end)

	Net.GetRemoteEvent("PlantDiscovered").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.plantId) ~= "string" then
			return
		end
		ClientState.PlantIndex[payload.plantId] = true
		table.insert(discoveryQueue, {
			plantId = payload.plantId,
			mutation = payload.mutation,
			discovered = tonumber(payload.discovered) or 0,
			total = tonumber(payload.total) or 0,
		})
		processDiscoveries()
	end)
end

return EffectsController
