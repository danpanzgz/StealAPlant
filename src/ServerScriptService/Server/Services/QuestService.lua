--!strict
--[[
	QuestService.lua
	Misiones diarias básicas. El progreso se guarda en
	profile.questProgress = { resetAt = <unix>, list = { {id, progress, claimed} } }.
	Otros Services llaman a QuestService.Report(player, kind, amount).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SeasonConfig = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local SeasonService = require(script.Parent.SeasonService)

local QuestService = {}

local questUpdatedEvent = Net.GetRemoteEvent("QuestUpdated")

local poolById: { [string]: any } = {}
for _, quest in ipairs(QuestConfig.Pool) do
	poolById[quest.id] = quest
end

local function rollNewSet(qp: any)
	local ids = {}
	for _, quest in ipairs(QuestConfig.Pool) do
		table.insert(ids, quest.id)
	end
	for i = #ids, 2, -1 do
		local j = math.random(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local list = {}
	for i = 1, math.min(GameConfig.MaxActiveQuests, #ids) do
		table.insert(list, { id = ids[i], progress = 0, claimed = false })
	end
	qp.list = list
	qp.resetAt = os.time() + GameConfig.QuestRefreshHours * 3600
end

local function ensure(profile: any): any
	local qp = profile.questProgress
	if type(qp.list) ~= "table" or os.time() >= (qp.resetAt or 0) then
		rollNewSet(qp)
	end
	return qp
end

function QuestService.GetState(player: Player): any
	local profile = DataService.GetProfile(player)
	if not profile then
		return { quests = {}, resetIn = 0 }
	end
	local qp = ensure(profile)
	local quests = {}
	for _, entry in ipairs(qp.list) do
		local def = poolById[entry.id]
		if def then
			table.insert(quests, {
				id = entry.id,
				description = def.description,
				target = def.target,
				progress = math.min(entry.progress, def.target),
				claimed = entry.claimed,
				rewardCash = def.rewardCash,
			})
		end
	end
	return { quests = quests, resetIn = math.max(0, qp.resetAt - os.time()) }
end

function QuestService.Report(player: Player, kind: string, amount: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local seasonXp = SeasonConfig.XpPerAction[kind]
	if seasonXp then
		SeasonService.AddXP(player, seasonXp)
	end
	local qp = ensure(profile)
	local changed = false
	for _, entry in ipairs(qp.list) do
		local def = poolById[entry.id]
		if def and def.kind == kind and entry.progress < def.target then
			entry.progress = math.min(def.target, entry.progress + amount)
			changed = true
		end
	end
	if changed then
		DataService.MarkDirty(player)
		questUpdatedEvent:FireClient(player, QuestService.GetState(player))
	end
end

function QuestService.Claim(player: Player, questId: any): (boolean, any)
	if type(questId) ~= "string" then
		return false, "invalid_args"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end
	local qp = ensure(profile)
	for _, entry in ipairs(qp.list) do
		if entry.id == questId then
			local def = poolById[questId]
			if not def then
				return false, "unknown_quest"
			end
			if entry.claimed then
				return false, "already_claimed"
			end
			if entry.progress < def.target then
				return false, "not_completed"
			end
			entry.claimed = true
			EconomyService.AddCash(player, def.rewardCash, "quest")
			DataService.MarkDirty(player)
			questUpdatedEvent:FireClient(player, QuestService.GetState(player))
			SeasonService.AddXP(player, SeasonConfig.XpQuestClaim)
			return true, def.rewardCash
		end
	end
	return false, "unknown_quest"
end

return QuestService
