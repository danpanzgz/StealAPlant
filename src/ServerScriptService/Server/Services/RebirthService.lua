--!strict
--[[
	RebirthService.lua
	Reinicia la progresión del jugador sin borrar el progreso global del
	perfil, dando una fuerte marca de "renacimiento" y un pequeño premio
	para fomentar la reactivación del jugador.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local PlantService = require(script.Parent.PlantService)
local DefenseService = require(script.Parent.DefenseService)
local GardenService = require(script.Parent.GardenService)

local RebirthService = {}
local notificationEvent = Net.GetRemoteEvent("NotificationPush")

local function getRebirthCost(profile: any): number
	local rebirths = profile.rebirthCount or 0
	return math.floor(GameConfig.RebirthBaseCost * (GameConfig.RebirthCostMultiplier ^ rebirths))
end

function RebirthService.GetCost(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	return getRebirthCost(profile)
end

function RebirthService.TryRebirth(player: Player): (boolean, any)
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local cost = getRebirthCost(profile)
	if profile.cash < cost then
		return false, "not_enough_cash"
	end

	local ok = EconomyService.TryRemoveCash(player, cost, "rebirth")
	if not ok then
		return false, "not_enough_cash"
	end

	profile.rebirthCount = (profile.rebirthCount or 0) + 1
	for _, plotData in pairs(profile.plots or {}) do
		if type(plotData) == "table" and PlantConfig[plotData.plantId] then
			local seeds = profile.inventory.seeds
			seeds[plotData.plantId] = (seeds[plotData.plantId] or 0) + 1
		end
	end
	profile.plots = {}
	profile.defenses = {}
	DefenseService.Clear(player)
	profile.questProgress = {}
	local lifetimeEarnings = profile.totalCashEarned or 0
	profile.cash = 0
	profile.totalCashEarned = 0
	profile.gardenLevel = 1
	profile.lastSeenAt = os.time()
	GardenService.RefreshForRebirth(player)
	InventoryService.Push(player)
	PlantService.ResetPlots(player)

	local bonusCash = math.floor(lifetimeEarnings * GameConfig.RebirthCashBonus)
	if bonusCash > 0 then
		EconomyService.AddCash(player, bonusCash, "rebirth_bonus")
	end

	DataService.MarkDirty(player)
	notificationEvent:FireClient(player, {
		text = "♻️ Rebirth #" .. profile.rebirthCount .. " completado. +$" .. bonusCash .. " de bonificación",
		kind = "good",
	})

	return true, {
		rebirthCount = profile.rebirthCount,
		cost = cost,
		bonusCash = bonusCash,
	}
end

return RebirthService
