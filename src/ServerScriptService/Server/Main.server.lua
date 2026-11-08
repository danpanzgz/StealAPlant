--!strict
--[[
	Main.server.lua
	Punto de entrada único del servidor. Orden de arranque:
	  1. Remotos (deben existir antes de que cualquier cliente los espere)
	  2. Services y handlers
	  3. Mapa y loops (autosave, crecimiento, eventos, leaderboard)
	  4. Conexión de jugadores (perfil -> pases -> jardín -> decoración)
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService.Server
local DefenseConfig: any = require(ReplicatedStorage.Shared.Config.DefenseConfig)

local RemoteBootstrap = require(Server.Remotes.RemoteBootstrap)
RemoteBootstrap.Init()

local DataService = require(Server.Services.DataService)
local EconomyService = require(Server.Services.EconomyService)
local GardenService = require(Server.Services.GardenService)
local InventoryService = require(Server.Services.InventoryService)
local PlantService = require(Server.Services.PlantService)
local ShopService = require(Server.Services.ShopService)
local DefenseService = require(Server.Services.DefenseService)
local StealService = require(Server.Services.StealService)
local EventService = require(Server.Services.EventService)
local MonetizationService = require(Server.Services.MonetizationService)
local LeaderboardService = require(Server.Services.LeaderboardService)
local MapBuilder = require(Server.Services.MapBuilder)
local RemoteHandlers = require(Server.Services.RemoteHandlers)
local OfflineEarningsService = require(Server.Services.OfflineEarningsService)
local RebirthService = require(Server.Services.RebirthService)
local PetService = require(Server.Services.PetService)
local SlapService = require(Server.Services.SlapService)

MapBuilder.BuildWorld()
StealService.CreateTutorialGarden(MapBuilder.TutorialGardenCenter)

RemoteHandlers.Init()
MonetizationService.Init()
EventService.Init()
LeaderboardService.Init()
PlantService.Init() -- conecta PlotCreated (prompt de plantar/cosechar)
PetService.Init()
ShopService.Init() -- restock compartido sincronizado por ciclo de 5 minutos
StealService.Init() -- conecta PlotCreated (prompt de robo)
SlapService.Init()
DataService.StartAutosaveLoop()

local function moveToGarden(player: Player)
	local garden = GardenService.GetGardenModel(player)
	if not garden then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 10)
	local spawnPosition = GardenService.GetEntryPosition(garden, 4)
	local plazaTarget = Vector3.new(MapBuilder.PlazaCenter.X, spawnPosition.Y, MapBuilder.PlazaCenter.Z)
	character:PivotTo(CFrame.lookAt(spawnPosition, plazaTarget))
end

local function onPlayerAdded(player: Player)
	DataService.LoadProfile(player)
	if not player.Parent then
		return
	end
	PetService.LoadPlayer(player)

	MonetizationService.LoadPlayer(player)
	OfflineEarningsService.Apply(player)
	LeaderboardService.SetupPlayer(player)
	if not player.Parent then
		return
	end

	GardenService.AssignGarden(player)
	local garden = GardenService.GetGardenModel(player)
	if garden then
		MapBuilder.DecorateGarden(player, garden)
	end
	PlantService.LoadPlacedPlants(player)
	DefenseService.BuildAll(player)

	StealService.GrantShield(player, DefenseConfig.JoinShieldSeconds)

	EconomyService.PushSnapshot(player)
	InventoryService.Push(player)
	EventService.PushState(player)

	-- Primera planta rápida: aparece directamente frente a su jardín.
	moveToGarden(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Red de seguridad: si alguien acaba bajo el mapa o fuera de los límites
-- (lag, bug de física...), vuelve a la entrada de su jardín (o a la plaza).
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position.Y < -6 or math.abs(root.Position.X - MapBuilder.PlazaCenter.X) > 600 or math.abs(root.Position.Z - MapBuilder.PlazaCenter.Z) > 600) then
				local garden = GardenService.GetGardenModel(player)
				local target = if garden
					then GardenService.GetEntryPosition(garden, 4)
					else Vector3.new(MapBuilder.PlazaCenter.X, 5, MapBuilder.PlazaCenter.Z + 12)
				root.AssemblyLinearVelocity = Vector3.zero
				local character = player.Character :: Model
				character:PivotTo(CFrame.new(target))
			end
		end
	end
end)

print("[Main] Steal a Plant server inicializado.")
