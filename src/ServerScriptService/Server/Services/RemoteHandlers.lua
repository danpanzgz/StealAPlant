--!strict
--[[
	RemoteHandlers.lua
	Única capa que conecta RemoteFunctions con los Services. Ningún Service
	escucha remotos directamente: así toda entrada de datos del cliente
	pasa por un mismo punto donde se puede loguear, limitar (rate-limit)
	y validar tipos antes de llegar a la lógica real.

	Regla de oro: NUNCA confiar en el tipo/forma de los argumentos que
	manda el cliente. Cada handler los valida antes de usarlos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)

local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local PlantService = require(script.Parent.PlantService)
local ShopService = require(script.Parent.ShopService)
local EconomyService = require(script.Parent.EconomyService)

local RemoteHandlers = {}

-- Rate limiting simple por jugador y por remoto: evita que un cliente
-- modificado spamee llamadas a RemoteFunctions costosas.
local lastCallAt: { [number]: { [string]: number } } = {}
local MIN_CALL_INTERVAL = 0.25 -- segundos

local function isRateLimited(player: Player, remoteName: string): boolean
	local userTable = lastCallAt[player.UserId]
	if not userTable then
		userTable = {}
		lastCallAt[player.UserId] = userTable
	end
	local last = userTable[remoteName] or 0
	local now = os.clock()
	if now - last < MIN_CALL_INTERVAL then
		return true
	end
	userTable[remoteName] = now
	return false
end

function RemoteHandlers.Init()
	Net.GetRemoteFunction("BuySeed").OnServerInvoke = function(player: Player, plantId: any)
		if isRateLimited(player, "BuySeed") then
			return { success = false, reason = "rate_limited" }
		end
		local ok, result = ShopService.BuySeed(player, plantId)
		if ok then
			return { success = true, plantId = result.plantId, newCount = result.newCount, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("PlantSeed").OnServerInvoke = function(player: Player, plotIndex: any, plantId: any)
		if isRateLimited(player, "PlantSeed") then
			return { success = false, reason = "rate_limited" }
		end
		local ok, reason = PlantService.PlantSeed(player, plotIndex, plantId)
		return { success = ok, reason = if ok then nil else reason }
	end

	Net.GetRemoteFunction("HarvestPlant").OnServerInvoke = function(player: Player, plotIndex: any)
		if isRateLimited(player, "HarvestPlant") then
			return { success = false, reason = "rate_limited" }
		end
		local ok, resultOrReason = PlantService.HarvestPlant(player, plotIndex)
		if ok then
			return { success = true, cashEarned = resultOrReason, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("UpgradeGarden").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "UpgradeGarden") then
			return { success = false, reason = "rate_limited" }
		end
		local ok, resultOrReason = GardenService.UpgradeGarden(player, EconomyService)
		if ok then
			return { success = true, newLevel = resultOrReason, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("GetPlayerProfileSnapshot").OnServerInvoke = function(player: Player)
		local profile = DataService.GetProfile(player)
		if not profile then
			return { success = false, reason = "no_profile" }
		end
		return {
			success = true,
			cash = profile.cash,
			totalCashEarned = profile.totalCashEarned,
			gardenLevel = profile.gardenLevel,
			inventory = profile.inventory,
			plots = profile.plots,
			unlockedZones = profile.unlockedZones,
			catalog = ShopService.GetAvailableCatalog(player),
		}
	end

	-- Handlers "coming soon": los remotos ya existen (Net.lua los declara
	-- todos por adelantado) pero su lógica llega en la siguiente iteración
	-- (Steal/Defense/Quests/DailyReward). Devolvemos una respuesta segura
	-- en vez de dejar el remoto sin OnServerInvoke, que rompería al cliente.
	local comingSoon = { success = false, reason = "coming_soon" }
	Net.GetRemoteFunction("AttemptSteal").OnServerInvoke = function()
		return comingSoon
	end
	Net.GetRemoteFunction("PlaceDefense").OnServerInvoke = function()
		return comingSoon
	end
	Net.GetRemoteFunction("ClaimDailyReward").OnServerInvoke = function()
		return comingSoon
	end
	Net.GetRemoteFunction("ClaimQuestReward").OnServerInvoke = function()
		return comingSoon
	end
end

return RemoteHandlers
