--!strict
--[[
	MutationVisuals.lua
	Efectos visuales de TODAS las mutaciones de una planta (sin límite de
	cantidad lógica; el número de emisores visibles se limita por rendimiento).
	  Wet     -> gotas que caen de la planta
	  Frozen  -> copos de nieve flotando
	  Shiny   -> destellos blancos
	  Gold    -> chispas doradas
	  Rainbow -> chispas multicolor
	  Diamond -> destellos azul cian + luz
	Apply(model, host, list, heightStuds)
]]

local MutationConfig = require(script.Parent.Parent.Config.MutationConfig)

local MutationVisuals = {}

local MAX_EMITTERS = 6
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function emitter(parent: Instance, name: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = SPARKLE
	e.Parent = parent
	return e
end

function MutationVisuals.Apply(model: Model, host: BasePart, list: { string }, height: number)
	if #list == 0 then
		return
	end
	height = math.max(height, 1.5)

	-- Parte invisible que cubre la planta: aquí viven los emisores.
	local emitHost = Instance.new("Part")
	emitHost.Name = "MutationFX"
	emitHost.Anchored = true
	emitHost.CanCollide = false
	emitHost.CanTouch = false
	emitHost.CanQuery = false
	emitHost.CastShadow = false
	emitHost.Transparency = 1
	emitHost.Size = Vector3.new(math.max(2, height * 0.6), height, math.max(2, height * 0.6))
	emitHost.Position = host.Position + Vector3.new(0, height / 2 - 0.3, 0)
	emitHost.Parent = model

	local count = 0
	local primaryColor: Color3? = nil
	for _, id in ipairs(list) do
		local data = (MutationConfig :: any)[id]
		if data and count < MAX_EMITTERS then
			count += 1
			primaryColor = primaryColor or data.color
			local e = emitter(emitHost, id .. "FX")
			e.Color = ColorSequence.new(data.color)
			e.EmissionDirection = Enum.NormalId.Top
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			e.LightEmission = 0.6
			if id == "Wet" then
				-- Gotas que caen desde la planta.
				e.Texture = "rbxasset://textures/particles/smoke_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255))
				e.EmissionDirection = Enum.NormalId.Bottom
				e.Rate = 7
				e.Lifetime = NumberRange.new(0.9, 1.3)
				e.Speed = NumberRange.new(2, 3)
				e.Acceleration = Vector3.new(0, -14, 0)
				e.SpreadAngle = Vector2.new(8, 8)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.28),
					NumberSequenceKeypoint.new(1, 0.1),
				})
				e.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(1, 0.8),
				})
				e.LightEmission = 0.2
			elseif id == "Frozen" then
				e.Color = ColorSequence.new(Color3.fromRGB(210, 240, 255))
				e.Rate = 4
				e.Lifetime = NumberRange.new(1.4, 2.2)
				e.Speed = NumberRange.new(0.3, 0.8)
				e.Acceleration = Vector3.new(0, -1.2, 0)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = NumberSequence.new(0.2)
			elseif id == "Rainbow" then
				e.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
					ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
				})
				e.Rate = 6
				e.Lifetime = NumberRange.new(0.9, 1.5)
				e.Speed = NumberRange.new(0.4, 1)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = NumberSequence.new(0.28)
			else
				e.Rate = if id == "Diamond" then 6 else 3
				e.Lifetime = NumberRange.new(0.8, 1.4)
				e.Speed = NumberRange.new(0.25, 0.7)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.12),
					NumberSequenceKeypoint.new(0.55, 0.24),
					NumberSequenceKeypoint.new(1, 0),
				})
			end
		end
	end

	-- Aura (un solo Highlight) con el color del efecto principal.
	if primaryColor then
		local highlight = Instance.new("Highlight")
		highlight.Name = "MutationAura"
		highlight.Adornee = model
		highlight.FillColor = primaryColor
		highlight.FillTransparency = 0.84
		highlight.OutlineColor = primaryColor
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model

		local glow = Instance.new("PointLight")
		glow.Name = "MutationGlow"
		glow.Color = primaryColor
		glow.Brightness = math.min(0.4 + 0.15 * #list, 1.2)
		glow.Range = 7
		glow.Parent = emitHost
	end
end

return MutationVisuals
