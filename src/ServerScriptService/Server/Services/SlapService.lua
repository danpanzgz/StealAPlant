--!strict

local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)

local SlapService = {}
local lastSlapAt: { [number]: number } = {}
local COOLDOWN_SECONDS = 1.2
local RANGE = 9
local SLAP_GEAR_ID = "SlapStick"
local SLAP_TOOL_NAME = "Farm Slap Stick"

local function getRebirthBonus(rebirthCount: number): number
	local bonus = 0
	for rebirth = 1, math.max(0, math.floor(rebirthCount)) do
		bonus += math.max(7, 22 - rebirth * 2)
	end
	return bonus
end

function SlapService.TrySlap(player: Player)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return
	end
	local now = os.clock()
	if now - (lastSlapAt[player.UserId] or 0) < COOLDOWN_SECONDS then
		return
	end
	lastSlapAt[player.UserId] = now

	local profile = DataService.GetProfile(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or (profile.inventory.gear[SLAP_GEAR_ID] or 0) <= 0 or not root then
		return
	end

	local look = root.CFrame.LookVector
	local targetRoot: BasePart? = nil
	local nearestDistance = RANGE
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= player then
			local targetCharacter = target.Character
			local candidate = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			if candidate and humanoid and humanoid.Health > 0 then
				local offset = candidate.Position - root.Position
				local distance = offset.Magnitude
				if distance > 0 and distance < nearestDistance and look:Dot(offset.Unit) > 0.1 then
					targetRoot = candidate
					nearestDistance = distance
				end
			end
		end
	end
	if not targetRoot then
		return
	end

	local rebirthCount = profile.rebirthCount or 0
	local bonus = getRebirthBonus(rebirthCount)
	local horizontalForce = math.min(88, 42 * (1 + bonus / 100))
	local direction = Vector3.new(look.X, 0, look.Z)
	if direction.Magnitude < 0.001 then
		return
	end
	direction = direction.Unit
	local verticalForce = math.min(42, 20 * (1 + bonus / 100))
	targetRoot:ApplyImpulse((direction * horizontalForce + Vector3.new(0, verticalForce, 0)) * targetRoot.AssemblyMass)
end

local function findSlapTool(player: Player): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local tool = backpack and backpack:FindFirstChild(SLAP_TOOL_NAME)
	if tool and tool:IsA("Tool") then
		return tool
	end
	tool = character and character:FindFirstChild(SLAP_TOOL_NAME)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function removeSlapTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local function removeFrom(container: Instance?)
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child.Name == SLAP_TOOL_NAME then
					child:Destroy()
				end
			end
		end
	end
	removeFrom(backpack)
	removeFrom(character)
end

function SlapService.Refresh(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	if (profile.inventory.gear[SLAP_GEAR_ID] or 0) <= 0 then
		removeSlapTools(player)
		return
	end
	if findSlapTool(player) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack or not backpack:IsA("Backpack") then
		warn("[SlapService] Backpack unavailable; could not grant the purchased slap tool.")
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = SLAP_TOOL_NAME
	tool.ToolTip = "Un empujón amistoso; mejora con cada renacimiento"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.rad(28))
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 3, 0.35)
	handle.Color = Color3.fromRGB(142, 91, 48)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Activated:Connect(function()
		SlapService.TrySlap(player)
	end)
	tool.Parent = backpack
end

local function bindPlayer(player: Player)
	player:GetAttributeChangedSignal("CarryingStolenPlant"):Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		if player:GetAttribute("CarryingStolenPlant") == true then
			humanoid:UnequipTools()
		else
			local tool = findSlapTool(player)
			if tool and tool:IsA("Tool") then
				humanoid:EquipTool(tool)
			end
		end
	end)
	player.CharacterAdded:Connect(function(character)
		task.defer(SlapService.Refresh, player)
	end)
	task.defer(SlapService.Refresh, player)
end

function SlapService.Init()
	Players.PlayerAdded:Connect(function(player)
		bindPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSlapAt[player.UserId] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end
end

return SlapService
