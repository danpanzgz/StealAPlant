--!strict
--[[
	TrapService.lua
	Trampas colocables (Trampa de red / de burbuja). Son cómicas y no hacen
	daño: ralentizan o "pegan" un instante al intruso. Cada jugador puede tener
	como máximo ShopConfig.MaxActiveTraps activas a la vez; se gasta una unidad
	del inventario al colocarla y la trampa se consume al saltar (o caduca).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local InventoryService = require(script.Parent.InventoryService)

local TrapService = {}

local notifyEvent = Net.GetRemoteEvent("NotificationPush")
local activeByUser: { [number]: { Part } } = {}
local slowToken: { [Humanoid]: number } = {}

local function notify(player: Player, text: string, kind: string)
	notifyEvent:FireClient(player, { text = text, kind = kind })
end

local function activeCount(userId: number): number
	local list = activeByUser[userId]
	if not list then
		return 0
	end
	for index = #list, 1, -1 do
		if not list[index].Parent then
			table.remove(list, index)
		end
	end
	return #list
end

function TrapService.GetActiveCount(player: Player): number
	return activeCount(player.UserId)
end

local function confetti(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.5
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(30)
	Debris:AddItem(anchor, 2)
end

local function trigger(trap: Part, owner: Player, victim: Player, config: any)
	if trap:GetAttribute("Spent") == true then
		return
	end
	trap:SetAttribute("Spent", true)
	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		trap:SetAttribute("Spent", nil)
		return
	end

	local original = humanoid.WalkSpeed
	local token = (slowToken[humanoid] or 0) + 1
	slowToken[humanoid] = token
	humanoid.WalkSpeed = original * config.speedFactor

	local bubble: Part? = nil
	if config.bubble then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(8, 8, 8)
		ball.Material = Enum.Material.Glass
		ball.Color = config.color
		ball.Transparency = 0.55
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Massless = true
		ball.CFrame = root.CFrame
		ball.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ball
		weld.Parent = ball
		bubble = ball
	end

	confetti(trap.Position + Vector3.new(0, 1, 0), config.color)
	notify(victim, "🕸️ ¡Caíste en una trampa de " .. owner.DisplayName .. "!", "warn")
	notify(owner, "🪤 ¡Tu trampa atrapó a " .. victim.DisplayName .. "!", "good")
	trap:Destroy()

	task.delay(config.slowSeconds, function()
		if bubble then
			bubble:Destroy()
		end
		if humanoid.Parent and slowToken[humanoid] == token then
			humanoid.WalkSpeed = original
			slowToken[humanoid] = nil
		end
	end)
end

function TrapService.Place(player: Player, gearId: string): (boolean, any)
	local config = ShopConfig.Gear[gearId]
	if not config or config.kind ~= "trap" then
		return false, "unsupported_gear"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end
	if (profile.inventory.gear[gearId] or 0) < 1 then
		return false, "gear_not_owned"
	end
	if activeCount(player.UserId) >= ShopConfig.MaxActiveTraps then
		return false, "too_many_traps"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local garden = GardenService.GetGardenModel(player)
	local boundary = garden and garden:FindFirstChild("YardBoundary")
	local floor = boundary and boundary:FindFirstChild("GardenFloor")
	if not root or not floor or not floor:IsA("BasePart") then
		return false, "character_unavailable"
	end
	-- Solo dentro de tu patio.
	local local_ = floor.CFrame:PointToObjectSpace(root.Position)
	if math.abs(local_.X) > floor.Size.X / 2 - 2 or math.abs(local_.Z) > floor.Size.Z / 2 - 2 then
		return false, "trap_outside_garden"
	end

	profile.inventory.gear[gearId] -= 1
	if profile.inventory.gear[gearId] <= 0 then
		profile.inventory.gear[gearId] = nil
	end
	DataService.MarkDirty(player)
	InventoryService.Push(player)

	local top = floor.Position.Y + floor.Size.Y / 2
	local trap = Instance.new("Part")
	trap.Name = "GardenTrap"
	trap.Anchored = true
	trap.CanCollide = false
	trap.CanQuery = false
	trap.Size = Vector3.new(4.5, 0.3, 4.5)
	trap.Position = Vector3.new(root.Position.X, top + 0.2, root.Position.Z)
	trap.Color = config.color
	trap.Material = Enum.Material.Neon
	trap.Transparency = 0.45 -- visible pero discreta
	trap:SetAttribute("OwnerUserId", player.UserId)
	trap.Parent = garden
	local mark = Instance.new("Part")
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.Size = Vector3.new(2.2, 0.35, 2.2)
	mark.Position = trap.Position + Vector3.new(0, 0.05, 0)
	mark.Color = Color3.new(1, 1, 1)
	mark.Material = Enum.Material.SmoothPlastic
	mark.Transparency = 0.5
	mark.Parent = trap

	trap.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local victim = character and Players:GetPlayerFromCharacter(character)
		if victim and victim ~= player then
			trigger(trap, player, victim, config)
		end
	end)

	activeByUser[player.UserId] = activeByUser[player.UserId] or {}
	table.insert(activeByUser[player.UserId], trap)
	Debris:AddItem(trap, ShopConfig.TrapLifetimeSeconds)
	return true, { placed = true, active = activeCount(player.UserId), max = ShopConfig.MaxActiveTraps }
end

Players.PlayerRemoving:Connect(function(player: Player)
	local list = activeByUser[player.UserId]
	if list then
		for _, trap in ipairs(list) do
			trap:Destroy()
		end
	end
	activeByUser[player.UserId] = nil
end)

return TrapService
