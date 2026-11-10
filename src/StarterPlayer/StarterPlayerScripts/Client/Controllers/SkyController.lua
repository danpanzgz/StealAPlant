--!strict
--[[
	SkyController.lua
	Cielo de atardecer con estética cúbica:
	  - Sol cuadrado (capas neón) que siempre mira a la cámara.
	  - Nubes cuadradas que derivan y SIEMPRE rodean a la cámara: el campo de
	    nubes es un toroide alrededor del jugador, así nunca aparecen ni
	    desaparecen de golpe al girar (se desvanecen en el borde lejano).
	  - Luciérnagas cerca del jugador.
	Todo es local. Las nubes se mueven en bloque con BulkMoveTo (barato) y su
	cantidad depende de la calidad gráfica de Ajustes.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Parent.Settings)

local SkyController = {}

local SUN_DISTANCE = 900
local SUN_SCALE = 900 / 1400
local CLOUD_HEIGHT = 170
local FIELD = 1000 -- lado del campo de nubes centrado en la cámara
local FADE_START = 330 -- a partir de esta distancia se van desvaneciendo
local FADE_END = 480
local CLOUD_COUNTS = { 6, 11, 17 }

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.Color = color
	part.Transparency = transparency
	part.Parent = parent
	return part
end

type Cloud = { parts: { Part }, offsets: { Vector3 }, baseX: number, baseZ: number, y: number, speed: number, fade: number }

function SkyController.Init()
	local folder = Instance.new("Folder")
	folder.Name = "SkyDecor"
	folder.Parent = Workspace

	-- ===== Sol cuadrado (capas concéntricas) =====
	local layers: { Part } = {
		newPart(folder, "SunGlowOuter", Vector3.new(520, 520, 1) * SUN_SCALE, Color3.fromRGB(255, 118, 140), 0.88),
		newPart(folder, "SunGlowMid", Vector3.new(340, 340, 1) * SUN_SCALE, Color3.fromRGB(255, 160, 95), 0.7),
		newPart(folder, "SunHalo", Vector3.new(230, 230, 1) * SUN_SCALE, Color3.fromRGB(255, 200, 110), 0.35),
		newPart(folder, "SunCore", Vector3.new(160, 160, 1) * SUN_SCALE, Color3.fromRGB(255, 238, 178), 0),
	}

	-- ===== Nubes =====
	local cloudFolder = Instance.new("Folder")
	cloudFolder.Name = "Clouds"
	cloudFolder.Parent = folder
	local clouds: { Cloud } = {}
	local flatParts: { Part } = {}
	local flatCFrames: { CFrame } = {}
	local cloudColors = {
		Color3.fromRGB(255, 196, 190), Color3.fromRGB(255, 176, 150), Color3.fromRGB(246, 160, 190), Color3.fromRGB(255, 218, 190),
	}
	local baseTransparency = 0.12

	local function buildClouds()
		cloudFolder:ClearAllChildren()
		table.clear(clouds)
		table.clear(flatParts)
		table.clear(flatCFrames)
		local random = Random.new(515) -- mismo cielo siempre
		local count = CLOUD_COUNTS[math.clamp(Settings.Quality, 1, 3)]
		for _ = 1, count do
			local color = cloudColors[random:NextInteger(1, #cloudColors)]
			local cloud: Cloud = {
				parts = {},
				offsets = {},
				baseX = random:NextNumber(-FIELD / 2, FIELD / 2),
				baseZ = random:NextNumber(-FIELD / 2, FIELD / 2),
				y = CLOUD_HEIGHT + random:NextNumber(-20, 40),
				speed = random:NextNumber(1.5, 3.5),
				fade = 0,
			}
			for _ = 1, random:NextInteger(4, 6) do
				local part = newPart(cloudFolder, "Cloud", Vector3.new(random:NextInteger(3, 6) * 10, random:NextInteger(6, 10), random:NextInteger(3, 5) * 10), color, baseTransparency)
				part.Material = Enum.Material.SmoothPlastic
				table.insert(cloud.parts, part)
				table.insert(cloud.offsets, Vector3.new(random:NextInteger(-3, 3) * 14, random:NextInteger(0, 1) * 6, random:NextInteger(-2, 2) * 14))
				table.insert(flatParts, part)
				table.insert(flatCFrames, CFrame.new())
			end
			table.insert(clouds, cloud)
		end
	end
	buildClouds()
	Settings.Changed:Connect(function(key: string)
		if key == "Quality" then
			buildClouds()
		end
	end)

	-- ===== Luciérnagas / polen cálido cerca del jugador =====
	local dust = Instance.new("Part")
	dust.Name = "FireflyEmitter"
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.Transparency = 1
	dust.Size = Vector3.new(70, 14, 70)
	dust.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 140), Color3.fromRGB(255, 170, 190))
	emitter.Rate = 9
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.5, 1.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Parent = dust
	Settings.Changed:Connect(function(key: string)
		if key == "Quality" then
			emitter.Rate = if Settings.Quality == 1 then 0 elseif Settings.Quality == 2 then 9 else 16
		end
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		clock += dt
		local camPos = camera.CFrame.Position
		-- El sol vive "en el infinito": se coloca respecto a la cámara.
		local sunDirection = Lighting:GetSunDirection()
		if sunDirection.Y < -0.15 then
			sunDirection = Vector3.new(sunDirection.X, -0.15, sunDirection.Z).Unit
		end
		local sunPosition = camPos + sunDirection * SUN_DISTANCE
		for index, layer in ipairs(layers) do
			layer.CFrame = CFrame.lookAt(sunPosition + sunDirection * (index * 0.5), camPos)
		end

		-- Nubes: posición envuelta alrededor de la cámara (siempre dentro del campo).
		local half = FIELD / 2
		local cursor = 0
		for _, cloud in ipairs(clouds) do
			local x = cloud.baseX + clock * cloud.speed
			local dx = ((x - camPos.X + half) % FIELD) - half
			local dz = ((cloud.baseZ - camPos.Z + half) % FIELD) - half
			local distance = math.sqrt(dx * dx + dz * dz)
			local fade = math.clamp((distance - FADE_START) / (FADE_END - FADE_START), 0, 1)
			local center = Vector3.new(camPos.X + dx, cloud.y, camPos.Z + dz)
			for index, offset in ipairs(cloud.offsets) do
				cursor += 1
				flatCFrames[cursor] = CFrame.new(center + offset)
			end
			if math.abs(fade - cloud.fade) > 0.03 then
				cloud.fade = fade
				local transparency = baseTransparency + (1 - baseTransparency) * fade
				for _, part in ipairs(cloud.parts) do
					part.Transparency = transparency
				end
			end
		end
		if cursor > 0 then
			Workspace:BulkMoveTo(flatParts, flatCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		dust.Position = camPos + Vector3.new(0, 4, 0)
	end)
end

return SkyController
