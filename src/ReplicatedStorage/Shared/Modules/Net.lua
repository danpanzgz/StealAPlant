--!strict
--[[
	Net.lua
	Punto único de acceso a RemoteEvents/RemoteFunctions. Evita duplicar
	nombres de remotos y evita crear más remotos de los necesarios.

	Uso en servidor:
		local heartbeatEvent = Net.GetRemoteEvent("PlantHarvested")
		heartbeatEvent:FireClient(player, payload)

	Uso en cliente:
		local heartbeatEvent = Net.GetRemoteEvent("PlantHarvested")
		heartbeatEvent.OnClientEvent:Connect(function(payload) ... end)

	IMPORTANTE: el servidor es quien crea las instancias (RunService:IsServer()).
	El cliente solo las espera con WaitForChild. Esto evita condiciones de
	carrera y evita que el cliente pueda "inventar" remotos falsos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local REMOTES_FOLDER_NAME = "Remotes"

local function getRemotesFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if existing then
			return existing :: Folder
		end
		local folder = Instance.new("Folder")
		folder.Name = REMOTES_FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	else
		return ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME) :: Folder
	end
end

-- Registro central de nombres de remotos usados en todo el juego.
-- Mantener esta lista evita "remotos fantasma" creados por error.
Net.RemoteEventNames = {
	"PlantHarvested",           -- server -> client: feedback instantáneo al cosechar
	"PlantGrowthUpdated",       -- server -> client: una planta cambió de fase
	"CashUpdated",              -- server -> client: cambio de saldo (para animación de UI)
	"StealAttemptStarted",      -- server -> client (broadcast al dueño): "¡te están robando!"
	"StealAttemptResolved",     -- server -> client: resultado del robo (éxito/fallo)
	"GardenAlarmTriggered",     -- server -> client: alarma visual/sonora
	"QuestUpdated",             -- server -> client: progreso de misión
	"DailyRewardClaimed",       -- server -> client: confirmación visual
	"NotificationPush",         -- server -> client: notificaciones genéricas cortas
	"GlobalEventUpdated",       -- server -> client: estado de evento temporal
}

Net.RemoteFunctionNames = {
	"BuySeed",                  -- client -> server: comprar semilla (valida Cash en servidor)
	"PlantSeed",                -- client -> server: plantar semilla en un plot
	"HarvestPlant",             -- client -> server: cosechar planta madura
	"UpgradeGarden",            -- client -> server: subir de nivel el jardín
	"AttemptSteal",             -- client -> server: intentar robar una planta
	"PlaceDefense",             -- client -> server: colocar una defensa
	"ClaimDailyReward",         -- client -> server: reclamar recompensa diaria
	"ClaimQuestReward",         -- client -> server: reclamar recompensa de misión
	"GetPlayerProfileSnapshot", -- client -> server: pedir estado inicial al cargar UI
}

local eventCache: { [string]: RemoteEvent } = {}
local functionCache: { [string]: RemoteFunction } = {}

function Net.GetRemoteEvent(name: string): RemoteEvent
	if eventCache[name] then
		return eventCache[name]
	end

	local folder = getRemotesFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			eventCache[name] = existing
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		eventCache[name] = remote
		return remote
	else
		local remote = folder:WaitForChild(name) :: RemoteEvent
		eventCache[name] = remote
		return remote
	end
end

function Net.GetRemoteFunction(name: string): RemoteFunction
	if functionCache[name] then
		return functionCache[name]
	end

	local folder = getRemotesFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			functionCache[name] = existing
			return existing
		end
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		functionCache[name] = remote
		return remote
	else
		local remote = folder:WaitForChild(name) :: RemoteFunction
		functionCache[name] = remote
		return remote
	end
end

return Net
