--!strict
--[[
	OfflineEarningsService.lua
	Premia al jugador por el tiempo que estuvo fuera de línea. El cálculo se
	basada en minutos desconectados y en cuántas plantas maduras tenía en su
	jardín antes de volver a entrar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)

local OfflineEarningsService = {}
local notificationEvent = Net.GetRemoteEvent("NotificationPush")

local function getCurrentReward(player: Player, profile: any): number
	local now = os.time()
	local lastSeenAt = profile.lastSeenAt or now
	if lastSeenAt <= 0 or now <= lastSeenAt then
		return 0
	end

	local maxOfflineMinutes = MonetizationService.GetOfflineEarningsMinutes(player)
	local timeAwaySeconds = math.min(now - lastSeenAt, maxOfflineMinutes * 60)
	local timeAwayMinutes = math.floor(timeAwaySeconds / 60)
	if timeAwayMinutes <= 0 then
		return 0
	end

	local incomePerMinute = 0
	for _, plant in ipairs(profile.placedPlants or {}) do
		incomePerMinute += math.max(0, math.floor(tonumber(plant.incomePerMinute) or 0))
	end

	local multiplier = 1 + (profile.rebirthCount or 0) * GameConfig.RebirthCashBonus
	local totalReward = math.floor(
		((timeAwayMinutes * GameConfig.OfflineEarningsPerMinute)
			+ (incomePerMinute * timeAwayMinutes * multiplier))
			* MonetizationService.GetOfflineCashMultiplier(player)
			* MonetizationService.GetCashMultiplier(player)
	)
	return math.clamp(totalReward, 0, GameConfig.MaxOfflineEarningsCash)
end

function OfflineEarningsService.GetReward(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	return getCurrentReward(player, profile)
end

function OfflineEarningsService.Apply(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end

	local reward = getCurrentReward(player, profile)
	if reward > 0 then
		EconomyService.AddCash(player, reward, "offline_earnings")
		notificationEvent:FireClient(player, {
			text = "💤 +$" .. reward .. " offline · tus cultivos siguieron creciendo",
			kind = "good",
		})
	end

	profile.lastSeenAt = os.time()
	DataService.MarkDirty(player)
	return reward
end

return OfflineEarningsService
