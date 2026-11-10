--!strict
--[[
	SlapService.lua
	Palo cómico: un empujón amistoso, sin daño. Mejora solo con cada
	renacimiento (RebirthConfig.StickTiers). El golpe lo decide el servidor
	(alcance, cooldown, dirección) y el EMPUJÓN lo aplica el cliente de la
	víctima (SlapHit): un personaje lo controla su dueño, así que mover su
	HumanoidRootPart desde el servidor no funciona de forma fiable.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local DataService = require(script.Parent.DataService)

local SlapService = {}
local lastSlapAt: { [number]: number } = {}
local RANGE = 11
local TOOL_NAME = "Farm Slap Stick"

local hitEvent = Net.GetRemoteEvent("SlapHit")

local function tierOf(player: Player): any
	local profile = DataService.GetProfile(player)
	return RebirthConfig.StickTiers[RebirthConfig.StickTier(if profile then (profile.rebirthCount or 0) else 0)]
end

local function findTool(player: Player): Tool?
	for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		local tool = container and container:FindFirstChild(TOOL_NAME)
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

-- Golpe visible: el brazo derecho sube y baja con el palo (R15) + estela de aire.
-- Se anima desde el servidor para que todos lo vean.
local function swing(character: Model, tool: Tool?)
	local arm = character:FindFirstChild("RightUpperArm")
	local shoulder = arm and arm:FindFirstChild("RightShoulder")
	if shoulder and shoulder:IsA("Motor6D") then
		local base = shoulder.C0
		task.spawn(function()
			local function setAngle(degrees: number, seconds: number)
				local tween = TweenService:Create(shoulder, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * CFrame.Angles(math.rad(degrees), 0, 0) })
				tween:Play()
				tween.Completed:Wait()
			end
			setAngle(160, 0.1) -- se levanta
			setAngle(25, 0.09) -- golpe hacia delante
			setAngle(0, 0.15) -- vuelve
			shoulder.C0 = base
		end)
	end
	if tool and tool.Parent == character then
		local base = tool.Grip
		task.spawn(function()
			tool.Grip = base * CFrame.Angles(math.rad(-50), 0, 0)
			task.wait(0.1)
			tool.Grip = base * CFrame.Angles(math.rad(35), 0, 0)
			task.wait(0.12)
			if tool.Parent then
				tool.Grip = base
			end
		end)
	end
	-- Estela: un arco blanco semitransparente delante del jugador.
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local arc = Instance.new("Part")
		arc.Anchored = true
		arc.CanCollide = false
		arc.CanQuery = false
		arc.CanTouch = false
		arc.CastShadow = false
		arc.Material = Enum.Material.Neon
		arc.Color = Color3.new(1, 1, 1)
		arc.Transparency = 0.45
		arc.Size = Vector3.new(5, 0.2, 5)
		arc.CFrame = root.CFrame * CFrame.new(0, 0.5, -3.2) * CFrame.Angles(0, 0, math.rad(35))
		arc.Parent = workspace
		TweenService:Create(arc, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(8, 0.2, 8) }):Play()
		Debris:AddItem(arc, 0.3)
	end
end

local function pop(root: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.6
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(18)
	Debris:AddItem(emitter, 1.5)
end

function SlapService.TrySlap(player: Player)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return
	end
	local tier = tierOf(player)
	local now = os.clock()
	if now - (lastSlapAt[player.UserId] or 0) < tier.cooldown then
		return
	end
	lastSlapAt[player.UserId] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	swing(character :: Model, findTool(player))

	local look = root.CFrame.LookVector
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = RANGE
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player then
			local candidate = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if candidate and humanoid and humanoid.Health > 0 then
				local offset = candidate.Position - root.Position
				local distance = offset.Magnitude
				-- Cono amplio: basta con tenerlo delante, no hay que apuntar al milímetro.
				if distance > 0 and distance < bestDistance and look:Dot(offset.Unit) > -0.1 then
					best, bestRoot, bestDistance = target, candidate, distance
				end
			end
		end
	end
	if not best or not bestRoot then
		return
	end

	local direction = Vector3.new(look.X, 0, look.Z)
	if direction.Magnitude < 0.001 then
		return
	end
	pop(bestRoot, tier.color)
	hitEvent:FireClient(best, { direction = direction.Unit, power = tier.power, by = player.DisplayName })
end

-- (Re)crea el palo según el nivel de renacimiento actual.
function SlapService.RefreshTool(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, container in ipairs({ backpack, character }) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child.Name == TOOL_NAME then
				child:Destroy()
			end
		end
	end

	local tier = tierOf(player)
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = tier.name .. " · un empujón amistoso; mejora con cada renacimiento"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("Hotbar", "stick")
	tool.Grip = CFrame.new(0, -tier.length * 0.4, 0) * CFrame.Angles(0, 0, math.rad(28))
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, tier.length, 0.35)
	handle.Color = tier.color
	handle.Material = tier.material
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	if tier.material == Enum.Material.Neon or tier.material == Enum.Material.Glass then
		local light = Instance.new("PointLight")
		light.Color = tier.color
		light.Range = 8
		light.Brightness = 1
		light.Parent = handle
	end
	tool.Activated:Connect(function()
		SlapService.TrySlap(player)
	end)
	tool.Parent = backpack
end

local function bindPlayer(player: Player)
	player:GetAttributeChangedSignal("CarryingStolenPlant"):Connect(function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and player:GetAttribute("CarryingStolenPlant") == true then
			humanoid:UnequipTools()
		end
	end)
	player.CharacterAdded:Connect(function()
		task.defer(SlapService.RefreshTool, player)
	end)
	if player.Character then
		task.defer(SlapService.RefreshTool, player)
	end
end

function SlapService.Init()
	Net.GetRemoteEvent("SlapAction").OnServerEvent:Connect(function(player: Player)
		SlapService.TrySlap(player)
	end)

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastSlapAt[player.UserId] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end
end

return SlapService
