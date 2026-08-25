--!strict
--[[
	Main.server.lua
	Punto de entrada único del servidor. Orden de arranque importa:
	  1. Remotos (deben existir antes de que cualquier cliente los espere)
	  2. Services que no dependen de jugadores (ninguno en esta fase)
	  3. Handlers de remotos (necesitan que los Services ya estén cargados)
	  4. Loops (autosave, crecimiento, ingreso pasivo)
	  5. Conexión de jugadores (carga de perfil -> asignación de jardín)
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

local RemoteBootstrap = require(Server.Remotes.RemoteBootstrap)
RemoteBootstrap.Init()

local DataService = require(Server.Services.DataService)
local EconomyService = require(Server.Services.EconomyService)
local GardenService = require(Server.Services.GardenService)
local PlantService = require(Server.Services.PlantService)
local ShopService = require(Server.Services.ShopService)
local RemoteHandlers = require(Server.Services.RemoteHandlers)

RemoteHandlers.Init()
PlantService.Init()
DataService.StartAutosaveLoop()

local function onPlayerAdded(player: Player)
	DataService.LoadProfile(player)

	-- Si el jugador se desconectó durante la carga, no seguimos.
	if not player.Parent then
		return
	end

	GardenService.AssignGarden(player)

	-- Empuja el estado inicial de Cash para que el HUD del cliente no
	-- tenga que esperar a la primera acción para mostrar el saldo real.
	EconomyService.PushSnapshot(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Por si el script se recarga en Studio con jugadores ya conectados (Play Solo, etc).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[Main] Steal a Plant server inicializado. Servicios activos:",
	"DataService, EconomyService, GardenService, PlantService, ShopService, RemoteHandlers")
