--!strict
--[[
	SeasonService.lua
	Pase de Temporada (SeasonConfig). Todo el XP, el nivel y los premios se
	calculan en servidor. Perfil: profile.season = { id, xp, free = {["n"]=true},
	premium = {["n"]=true} } (claves string para DataStore).
	Otros Services llaman a SeasonService.AddXP(player, amount).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local SeasonConfig = require(ReplicatedStorage.Shared.Config.SeasonConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local MonetizationService = require(script.Parent.MonetizationService)

local SeasonService = {}

local updatedEvent = Net.GetRemoteEvent("SeasonUpdated")
local notifyEvent = Net.GetRemoteEvent("NotificationPush")

local MAX_XP_PER_CALL = 5000

-- Devuelve el bloque de temporada del perfil; lo reinicia si cambió la temporada.
local function ensure(profile: any): any
	local seasonId = SeasonConfig.Current(os.time())
	local s = profile.season
	if type(s) ~= "table" or s.id ~= seasonId then
		s = { id = seasonId, xp = 0, free = {}, premium = {} }
		profile.season = s
	end
	if type(s.xp) ~= "number" or s.xp < 0 then
		s.xp = 0
	end
	if type(s.free) ~= "table" then
		s.free = {}
	end
	if type(s.premium) ~= "table" then
		s.premium = {}
	end
	return s
end

function SeasonService.GetStatus(player: Player): any?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local s = ensure(profile)
	local _, endsAt = SeasonConfig.Current(os.time())
	local level, into, need = SeasonConfig.LevelFromXp(s.xp)
	return {
		name = SeasonConfig.Name,
		season = s.id,
		level = level,
		maxLevel = SeasonConfig.MaxLevel,
		xpInto = into,
		xpNeed = need,
		endsIn = math.max(0, endsAt - os.time()),
		hasPass = MonetizationService.GetOwned(player).SeasonPass == true,
		free = s.free,
		premium = s.premium,
		freeRewards = SeasonConfig.Free,
		premiumRewards = SeasonConfig.Premium,
	}
end

local function push(player: Player)
	local status = SeasonService.GetStatus(player)
	if status then
		updatedEvent:FireClient(player, status)
	end
end

function SeasonService.AddXP(player: Player, amount: number)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local s = ensure(profile)
	local before = SeasonConfig.LevelFromXp(s.xp)
	s.xp += math.min(math.floor(amount), MAX_XP_PER_CALL)
	local after = SeasonConfig.LevelFromXp(s.xp)
	DataService.MarkDirty(player)
	if after > before then
		notifyEvent:FireClient(player, { text = "🏆 ¡Nivel " .. after .. " del Pase de Temporada!", kind = "good" })
		push(player)
	end
end

-- Compra de "saltar niveles" (Developer Product): suma el XP justo para subir n niveles.
function SeasonService.AddLevels(player: Player, levels: number)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	local s = ensure(profile)
	for _ = 1, levels do
		local level, into, need = SeasonConfig.LevelFromXp(s.xp)
		if level >= SeasonConfig.MaxLevel then
			break
		end
		s.xp += need - into
	end
	DataService.MarkDirty(player)
	push(player)
end

local function grantReward(player: Player, profile: any, reward: any)
	if reward.cash then
		EconomyService.AddCash(player, reward.cash, "season")
	end
	for packId, amount in pairs(reward.seedPacks or {}) do
		InventoryService.AddSeedPack(player, packId, amount)
	end
	for rarity, amount in pairs(reward.petEggs or {}) do
		InventoryService.AddPetEgg(player, rarity, amount)
	end
	for gearId, amount in pairs(reward.gear or {}) do
		InventoryService.AddGear(player, gearId, amount)
	end
	profile.boosts = profile.boosts or {}
	for stat, seconds in pairs(reward.boosts or {}) do
		profile.boosts[stat] = math.max(profile.boosts[stat] or 0, os.time()) + seconds
	end
end

-- track: "free" | "premium"
function SeasonService.Claim(player: Player, levelArg: any, trackArg: any): (boolean, string?)
	if type(levelArg) ~= "number" or levelArg ~= math.floor(levelArg) then
		return false, "invalid_args"
	end
	if trackArg ~= "free" and trackArg ~= "premium" then
		return false, "invalid_args"
	end
	local level: number = levelArg
	if level < 1 or level > SeasonConfig.MaxLevel then
		return false, "invalid_level"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end
	local s = ensure(profile)
	if SeasonConfig.LevelFromXp(s.xp) < level then
		return false, "level_locked"
	end
	if trackArg == "premium" and not MonetizationService.GetOwned(player).SeasonPass then
		return false, "no_pass"
	end
	local key = tostring(level)
	local claimed = if trackArg == "free" then s.free else s.premium
	if claimed[key] then
		return false, "already_claimed"
	end
	local reward = if trackArg == "free" then SeasonConfig.Free[level] else SeasonConfig.Premium[level]
	if not reward then
		return false, "no_reward"
	end
	claimed[key] = true
	grantReward(player, profile, reward)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	push(player)
	return true, nil
end

-- Reclama todos los premios disponibles de golpe (conveniencia móvil).
function SeasonService.ClaimAll(player: Player): number
	local status = SeasonService.GetStatus(player)
	if not status then
		return 0
	end
	local count = 0
	for level = 1, status.level do
		if SeasonService.Claim(player, level, "free") then
			count += 1
		end
		if status.hasPass and SeasonService.Claim(player, level, "premium") then
			count += 1
		end
	end
	return count
end

function SeasonService.Init()
	-- Nada que enganchar: el XP llega desde otros Services.
	local _ = MonetizationConfig
end

return SeasonService
