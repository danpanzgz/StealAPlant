--!strict
--[[
	SkyController.lua
	Cielo de atardecer "de peli" con estética cúbica tipo Minecraft:
	  - Sol cuadrado (capas neón naranja/rosa) que sigue la dirección real del sol.
	  - Nubes cuadradas teñidas de rosa/naranja que derivan despacio.
	  - Pequeñas luciérnagas/polen flotando por el mapa.
	Todo es local (cada jugador lo crea) y barato: ~60 partes y 1 emisor.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SkyController = {}

local SUN_DISTANCE = 1400
local CLOUD_HEIGHT = 190
local CLOUD_AREA = { minX = -500, maxX = 900, minZ = -500, maxZ = 600 }

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

function SkyController.Init()
	local folder = Instance.new("Folder")
	folder.Name = "SkyDecor"
	folder.Parent = Workspace

	-- ===== Sol cuadrado (capas concéntricas) =====
	local layers: { Part } = {
		newPart(folder, "SunGlowOuter", Vector3.new(520, 520, 1), Color3.fromRGB(255, 118, 140), 0.88),
		newPart(folder, "SunGlowMid", Vector3.new(340, 340, 1), Color3.fromRGB(255, 160, 95), 0.7),
		newPart(folder, "SunHalo", Vector3.new(230, 230, 1), Color3.fromRGB(255, 200, 110), 0.35),
		newPart(folder, "SunCore", Vector3.new(160, 160, 1), Color3.fromRGB(255, 238, 178), 0),
	}

	-- ===== Nubes cuadradas =====
	local random = Random.new(515)
	local cloudFolder = Instance.new("Folder")
	cloudFolder.Name = "Clouds"
	cloudFolder.Parent = folder
	local clouds: { { part: Part, speed: number } } = {}
	local cloudColors = {
		Color3.fromRGB(255, 196, 190), Color3.fromRGB(255, 176, 150), Color3.fromRGB(246, 160, 190), Color3.fromRGB(255, 218, 190),
	}
	for _ = 1, 16 do
		local cx = random:NextNumber(CLOUD_AREA.minX, CLOUD_AREA.maxX)
		local cz = random:NextNumber(CLOUD_AREA.minZ, CLOUD_AREA.maxZ)
		local cy = CLOUD_HEIGHT + random:NextNumber(-20, 40)
		local color = cloudColors[random:NextInteger(1, #cloudColors)]
		local speed = random:NextNumber(1.5, 3.5)
		-- Cada nube = un grupo de bloques planos apilados (aspecto voxel).
		local blocks = random:NextInteger(4, 7)
		for _ = 1, blocks do
			local w = random:NextInteger(3, 6) * 10
			local d = random:NextInteger(3, 5) * 10
			local part = newPart(cloudFolder, "Cloud", Vector3.new(w, random:NextInteger(6, 10), d), color, 0.12)
			part.Material = Enum.Material.SmoothPlastic
			part.Position = Vector3.new(cx + random:NextInteger(-3, 3) * 14, cy + random:NextInteger(0, 1) * 6, cz + random:NextInteger(-2, 2) * 14)
			table.insert(clouds, { part = part, speed = speed })
		end
	end

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

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
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
		-- Las nubes derivan hacia el este y reaparecen por el oeste.
		for _, cloud in ipairs(clouds) do
			local position = cloud.part.Position + Vector3.new(cloud.speed * dt, 0, 0)
			if position.X > CLOUD_AREA.maxX + 100 then
				position = Vector3.new(CLOUD_AREA.minX - 100, position.Y, position.Z)
			end
			cloud.part.Position = position
		end
		dust.Position = camPos + Vector3.new(0, 4, 0)
	end)
end

return SkyController
