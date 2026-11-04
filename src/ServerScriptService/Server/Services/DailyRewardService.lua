--!strict
--[[
	DailyRewardService.lua
	Recompensa diaria con racha de 7 días (DailyRewardConfig). Todo se
	calcula con os.time() en el servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)

local DailyRewardService = {}

local claimedEvent = Net.GetRemoteEvent("DailyRewardClaimed")

local function effectiveStreak(profile: any): number
	local last = profile.lastDailyRewardAt
	if last > 0 and os.time() - last > DailyRewardConfig.StreakGraceHours * 3600 then
		return 0
	end
	return profile.dailyRewardStreak
end

function DailyRewardService.GetStatus(player: Player): any
	local profile = DataService.GetProfile(player)
	if not profile then
		return { canClaim = false, secondsLeft = 0, nextDay = 1, rewards = DailyRewardConfig.Rewards }
	end
	local cooldown = DailyRewardConfig.CooldownHours * 3600
	local elapsed = os.time() - profile.lastDailyRewardAt
	local streak = effectiveStreak(profile)
	return {
		canClaim = elapsed >= cooldown,
		secondsLeft = math.max(0, cooldown - elapsed),
		nextDay = (streak % #DailyRewardConfig.Rewards) + 1,
		rewards = DailyRewardConfig.Rewards,
	}
end

function DailyRewardService.Claim(player: Player): (boolean, any)
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end
	local status = DailyRewardService.GetStatus(player)
	if not status.canClaim then
		return false, "not_ready"
	end

	local day = status.nextDay
	local reward = DailyRewardConfig.Rewards[day]

	profile.lastDailyRewardAt = os.time()
	profile.dailyRewardStreak = day
	DataService.MarkDirty(player)

	if reward.cash then
		EconomyService.AddCash(player, reward.cash, "daily_reward")
	end
	if reward.seeds then
		for plantId, amount in pairs(reward.seeds) do
			InventoryService.AddSeed(player, plantId, amount)
		end
	end

	claimedEvent:FireClient(player, { day = day, cash = reward.cash, seeds = reward.seeds })
	return true, { day = day, cash = reward.cash, seeds = reward.seeds }
end

return DailyRewardService
