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
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local GardenConfig = require(ReplicatedStorage.Shared.Config.GardenConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local PlantService = require(script.Parent.PlantService)
local GardenService = require(script.Parent.GardenService)
local DefenseService = require(script.Parent.DefenseService)
local SlapService = require(script.Parent.SlapService)

local RebirthService = {}
local notificationEvent = Net.GetRemoteEvent("NotificationPush")

local function getRebirthCost(profile: any): number
	return RebirthConfig.Cost(profile.rebirthCount or 0)
end

function RebirthService.GetCost(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	return getRebirthCost(profile)
end

-- Estado para la UI: coste, planta a sacrificar, si la tienes y qué ganas.
function RebirthService.GetInfo(player: Player): any?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local rebirths = profile.rebirthCount or 0
	local sacrificeId = RebirthConfig.SacrificeFor(rebirths + 1)
	local owned = 0
	for _, plant in ipairs(profile.inventory.plants or {}) do
		if plant.plantId == sacrificeId then
			owned += 1
		end
	end
	local tier = RebirthConfig.StickTiers[RebirthConfig.StickTier(rebirths + 1)]
	return {
		rebirths = rebirths,
		cost = getRebirthCost(profile),
		cash = profile.cash,
		sacrificeId = sacrificeId,
		sacrificeName = PlantConfig[sacrificeId].displayName,
		sacrificeOwned = owned,
		nextMultiplier = RebirthConfig.CashMultiplier(rebirths + 1),
		multiplier = RebirthConfig.CashMultiplier(rebirths),
		nextLuck = RebirthConfig.Luck(rebirths + 1),
		luck = RebirthConfig.Luck(rebirths),
		nextPlots = GardenConfig.GetMaxPlots(rebirths + 1),
		plots = GardenConfig.GetMaxPlots(rebirths),
		nextStick = tier.name,
	}
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

	-- Sacrificio: una copia de la planta pedida, de la mochila.
	local sacrificeId = RebirthConfig.SacrificeFor((profile.rebirthCount or 0) + 1)
	local sacrificeIndex: number? = nil
	for index, plant in ipairs(profile.inventory.plants or {}) do
		if plant.plantId == sacrificeId then
			sacrificeIndex = index
			break
		end
	end
	if not sacrificeIndex then
		return false, "missing_sacrifice"
	end

	local ok = EconomyService.TryRemoveCash(player, cost, "rebirth")
	if not ok then
		return false, "not_enough_cash"
	end

	table.remove(profile.inventory.plants, sacrificeIndex)
	profile.rebirthCount = (profile.rebirthCount or 0) + 1
	player:SetAttribute("Luck", RebirthConfig.Luck(profile.rebirthCount))
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
	InventoryService.Push(player)
	PlantService.ResetPlots(player)
	GardenService.RefreshFence(player) -- valla y cartel suben de estilo con cada Rebirth

	local _ = lifetimeEarnings
	local bonusCash = 0
	SlapService.RefreshTool(player) -- el palo sube de nivel solo

	DataService.MarkDirty(player)
	notificationEvent:FireClient(player, {
		text = "♻️ Rebirth #" .. profile.rebirthCount .. " · cobras x" .. RebirthConfig.CashMultiplier(profile.rebirthCount)
			.. " · suerte x" .. RebirthConfig.Luck(profile.rebirthCount),
		kind = "good",
	})

	return true, {
		rebirthCount = profile.rebirthCount,
		cost = cost,
		bonusCash = bonusCash,
	}
end

return RebirthService
