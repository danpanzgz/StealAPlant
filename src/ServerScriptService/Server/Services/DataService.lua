--!strict
--[[
	DataService.lua
	Única fuente de verdad para leer/escribir datos persistentes de jugador.
	Ningún otro Service debe llamar a DataStoreService directamente: todos
	pasan por aquí para que el guardado, los reintentos y el manejo de
	errores estén centralizados en un solo lugar.

	Garantías:
	  - Carga con reintentos (backoff exponencial) al entrar el jugador.
	  - Autosave periódico (GameConfig.AutosaveInterval).
	  - Guardado al salir el jugador (PlayerRemoving).
	  - Guardado final en BindToClose para evitar pérdida de datos si el
	    servidor se apaga (deploys, shutdown de Roblox, etc).
	  - Si el jugador se desconecta antes de terminar de cargar, no se
	    intenta guardar un perfil vacío/corrupto.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DataService = {}

local playerStore = DataStoreService:GetDataStore(GameConfig.DataStoreName)

-- Perfil por defecto para un jugador nuevo. GardenService, EconomyService,
-- etc. leen/escriben sobre esta forma de tabla.
local function newDefaultProfile()
	return {
		version = 1,
		cash = GameConfig.StarterCash,
		totalCashEarned = 0,
		gardenLevel = 1,
		inventory = {
			-- [plantId] = cantidad de semillas sin plantar
			-- Semillas de bienvenida: el jugador puede plantar su primera
			-- planta en segundos, sin pasar antes por la tienda.
			[GameConfig.StarterSeedId] = 3,
		},
		plots = {
			-- [plotIndex] = { plantId, plantedAt, stage, mutation, harvestable }
		},
		defenses = {
			-- [slotIndex] = { defenseId, placedAt }
		},
		unlockedZones = { "StarterMeadow" },
		ownedGamePasses = {},
		questProgress = {},
		lastDailyRewardAt = 0,
		dailyRewardStreak = 0,
		stats = {
			plantsHarvested = 0,
			plantsStolen = 0,
			plantsLost = 0,
		},
		createdAt = os.time(),
	}
end

-- profiles[userId] = { data = <tabla>, loaded = bool, dirty = bool }
local profiles: { [number]: { data: any, loaded: boolean, dirty: boolean } } = {}

local function attemptWithRetries<T>(fn: () -> T, maxRetries: number): (boolean, T?)
	local attempt = 0
	local waitTime = GameConfig.SaveRetryBackoff
	while attempt < maxRetries do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(string.format("[DataService] Intento %d/%d fallido: %s", attempt, maxRetries, tostring(result)))
		if attempt < maxRetries then
			task.wait(waitTime)
			waitTime *= 2
		end
	end
	return false, nil
end

function DataService.LoadProfile(player: Player)
	local key = "Player_" .. player.UserId

	local ok, data = attemptWithRetries(function()
		return playerStore:GetAsync(key)
	end, GameConfig.MaxSaveRetries)

	-- Si el jugador ya se fue mientras cargábamos, no seguimos.
	if not player.Parent then
		return
	end

	if not ok then
		warn("[DataService] No se pudo cargar el perfil de", player.Name, "- usando perfil temporal en memoria")
		-- Perfil temporal: el jugador puede jugar, pero se marcará como "no
		-- persistente" para no sobreescribir datos reales con datos vacíos.
		profiles[player.UserId] = { data = newDefaultProfile(), loaded = false, dirty = false }
		return
	end

	local profileData = data or newDefaultProfile()
	profiles[player.UserId] = { data = profileData, loaded = true, dirty = false }
end

function DataService.GetProfile(player: Player): any?
	local entry = profiles[player.UserId]
	if not entry then
		return nil
	end
	return entry.data
end

-- Marca el perfil como modificado para que el próximo autosave lo incluya.
function DataService.MarkDirty(player: Player)
	local entry = profiles[player.UserId]
	if entry then
		entry.dirty = true
	end
end

function DataService.SaveProfile(player: Player, isFinalSave: boolean?)
	local entry = profiles[player.UserId]
	if not entry then
		return
	end
	if not entry.loaded then
		-- Nunca sobreescribimos datos reales con un perfil que falló al cargar.
		return
	end
	if not isFinalSave and not entry.dirty then
		return -- nada que guardar, evita escrituras innecesarias
	end

	local key = "Player_" .. player.UserId
	local ok = attemptWithRetries(function()
		playerStore:SetAsync(key, entry.data)
	end, GameConfig.MaxSaveRetries)

	if ok then
		entry.dirty = false
	else
		warn("[DataService] Guardado final fallido para", player.Name, "- los datos pueden perderse")
	end
end

function DataService.ReleaseProfile(player: Player)
	profiles[player.UserId] = nil
end

-- ===== Ciclo de vida =====

Players.PlayerRemoving:Connect(function(player)
	DataService.SaveProfile(player, true)
	DataService.ReleaseProfile(player)
end)

game:BindToClose(function()
	-- Al apagar el servidor, guardamos todo lo que quede en memoria.
	-- BindToClose da un margen de tiempo antes de que Roblox cierre el proceso.
	local threads = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(threads, task.spawn(function()
			DataService.SaveProfile(player, true)
		end))
	end
	-- Pequeño margen para que los pcall/reintentos terminen.
	task.wait(3)
end)

function DataService.StartAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.SaveProfile(player, false)
			end
		end
	end)
end

return DataService
