--!strict
--[[
	RemoteHandlers.lua
	Única capa que conecta RemoteFunctions con los Services. Todo argumento
	del cliente se valida aquí o en el Service antes de usarse, y cada
	remoto tiene rate limit por jugador.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local PlantService = require(script.Parent.PlantService)
local StealService = require(script.Parent.StealService)
local ShopService = require(script.Parent.ShopService)
local EconomyService = require(script.Parent.EconomyService)
local DefenseService = require(script.Parent.DefenseService)
local QuestService = require(script.Parent.QuestService)
local DailyRewardService = require(script.Parent.DailyRewardService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local EventService = require(script.Parent.EventService)
local MonetizationService = require(script.Parent.MonetizationService)
local OfflineEarningsService = require(script.Parent.OfflineEarningsService)
local RebirthService = require(script.Parent.RebirthService)
local RebirthConfig = require(ReplicatedStorage.Shared.Config.RebirthConfig)
local InventoryService = require(script.Parent.InventoryService)
local PetService = require(script.Parent.PetService)
local SeasonService = require(script.Parent.SeasonService)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)

local RemoteHandlers = {}

local lastCallAt: { [number]: { [string]: number } } = {}
local MIN_CALL_INTERVAL = 0.25

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

Players.PlayerRemoving:Connect(function(player)
	lastCallAt[player.UserId] = nil
end)

local RATE_LIMITED = { success = false, reason = "rate_limited" }

function RemoteHandlers.Init()
	Net.GetRemoteFunction("BuySeed").OnServerInvoke = function(player: Player, plantId: any)
		if isRateLimited(player, "BuySeed") then
			return RATE_LIMITED
		end
		return { success = false, reason = "use_seed_packs" }
	end

	Net.GetRemoteFunction("GetShopStock").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetShopStock") then
			return RATE_LIMITED
		end
		local stock = ShopService.GetStock(player)
		return { success = true, items = stock.items, cycle = stock.cycle, nextRestockAt = stock.nextRestockAt }
	end

	Net.GetRemoteFunction("BuyShopItem").OnServerInvoke = function(player: Player, itemId: any)
		if isRateLimited(player, "BuyShopItem") then
			return RATE_LIMITED
		end
		local ok, result = ShopService.BuyItem(player, itemId)
		if ok then
			return { success = true, itemId = result.itemId, displayName = result.displayName, cash = result.cash }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("OpenSeedPack").OnServerInvoke = function(player: Player, packId: any)
		if isRateLimited(player, "OpenSeedPack") then
			return RATE_LIMITED
		end
		local ok, result = ShopService.OpenSeedPack(player, packId)
		if ok then
			return { success = true, seeds = result }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("OpenPetEgg").OnServerInvoke = function(player: Player, rarity: any)
		if isRateLimited(player, "OpenPetEgg") then
			return RATE_LIMITED
		end
		local ok, result = ShopService.OpenPetEgg(player, rarity)
		if ok then
			return { success = true, petId = result.petId, displayName = result.displayName }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("UnlockIncubator").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "UnlockIncubator") then
			return RATE_LIMITED
		end
		local ok, reason = ShopService.UnlockIncubator(player)
		return { success = ok, reason = if ok then nil else reason }
	end

	Net.GetRemoteFunction("EquipPet").OnServerInvoke = function(player: Player, petId: any)
		if isRateLimited(player, "EquipPet") then
			return RATE_LIMITED
		end
		if type(petId) ~= "string" or #petId > 64 then
			return { success = false, reason = "invalid_pet" }
		end
		local ok, reason = PetService.Equip(player, petId)
		return { success = ok, reason = if ok then nil else reason }
	end

	Net.GetRemoteFunction("PlantSeed").OnServerInvoke = function(player: Player, plotIndex: any, plantId: any)
		if isRateLimited(player, "PlantSeed") then
			return RATE_LIMITED
		end
		local ok, reason = PlantService.PlantSeed(player, plotIndex, plantId)
		return { success = ok, reason = if ok then nil else reason }
	end

	Net.GetRemoteFunction("HarvestPlant").OnServerInvoke = function(player: Player, plotIndex: any)
		if isRateLimited(player, "HarvestPlant") then
			return RATE_LIMITED
		end
		local ok, resultOrReason = PlantService.HarvestPlant(player, plotIndex)
		if ok then
			return { success = true, plant = resultOrReason }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("PlaceCollectionPlant").OnServerInvoke = function(player: Player, plantUid: any, position: any)
		if isRateLimited(player, "PlaceCollectionPlant") then
			return RATE_LIMITED
		end
		local ok, result = PlantService.PlaceCollectionPlant(player, plantUid, position)
		return { success = ok, reason = if ok then nil else result }
	end

	Net.GetRemoteFunction("CollectCollectionPlant").OnServerInvoke = function(player: Player, plantUid: any)
		if isRateLimited(player, "CollectCollectionPlant") then
			return RATE_LIMITED
		end
		local ok, result = PlantService.CollectCollectionPlant(player, plantUid)
		return { success = ok, reason = if ok then nil else result }
	end

	Net.GetRemoteFunction("SellCollectionPlant").OnServerInvoke = function(player: Player, plantUid: any)
		if isRateLimited(player, "SellCollectionPlant") then
			return RATE_LIMITED
		end
		local ok, result = PlantService.SellCollectionPlant(player, plantUid)
		if ok then
			return { success = true, cashEarned = result, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("SellHeld").OnServerInvoke = function(player: Player, plantUid: any)
		if isRateLimited(player, "SellHeld") then
			return RATE_LIMITED
		end
		local ok, result = PlantService.SellCollectionPlant(player, plantUid)
		if ok then
			return { success = true, cashEarned = result, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("GetSellQuote").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetSellQuote") then
			return RATE_LIMITED
		end
		return { success = true, quotes = PlantService.GetSellQuote(player), multiplier = MonetizationService.GetCashMultiplier(player) }
	end

	Net.GetRemoteFunction("SellAll").OnServerInvoke = function(player: Player, mode: any)
		if isRateLimited(player, "SellAll") then
			return RATE_LIMITED
		end
		if type(mode) ~= "string" then
			return { success = false, reason = "invalid_args" }
		end
		local ok, result = PlantService.SellMany(player, mode)
		if ok then
			return { success = true, count = result.count, cashEarned = result.cash, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = result }
	end

	local HOTBAR_SLOTS = 6
	local HOTBAR_KINDS = { stick = true, seed = true, plant = true, gear = true }
	Net.GetRemoteFunction("GetHotbar").OnServerInvoke = function(player: Player)
		local profile = DataService.GetProfile(player)
		if not profile then
			return { success = false, reason = "no_profile" }
		end
		return { success = true, hotbar = profile.hotbar }
	end

	Net.GetRemoteFunction("SetHotbar").OnServerInvoke = function(player: Player, layout: any)
		if isRateLimited(player, "SetHotbar") then
			return RATE_LIMITED
		end
		local profile = DataService.GetProfile(player)
		if not profile or type(layout) ~= "table" then
			return { success = false, reason = "invalid_args" }
		end
		local clean: { [string]: any } = {}
		for slot = 1, HOTBAR_SLOTS do
			local entry = layout[tostring(slot)]
			if type(entry) == "table" and HOTBAR_KINDS[entry.kind] and type(entry.id) == "string" and #entry.id <= 64 then
				clean[tostring(slot)] = { kind = entry.kind, id = entry.id }
			end
		end
		profile.hotbar = clean
		DataService.MarkDirty(player)
		return { success = true }
	end

	Net.GetRemoteFunction("UseGear").OnServerInvoke = function(player: Player, gearId: any)
		if isRateLimited(player, "UseGear") then
			return RATE_LIMITED
		end
		if type(gearId) ~= "string" or not ShopConfig.Gear[gearId] then
			return { success = false, reason = "unknown_gear" }
		end
		local ok, result = PlantService.UseGear(player, gearId)
		if ok and type(result) == "table" and result.placed then
			return { success = true, placed = true, active = result.active, max = result.max }
		end
		return { success = ok, reason = if ok then nil else result, equipped = if ok then result else nil }
	end

	Net.GetRemoteFunction("ToggleGardenShield").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "ToggleGardenShield") then
			return RATE_LIMITED
		end
		local ok, result = StealService.ToggleGardenShield(player)
		return { success = ok, reason = if ok then nil else result, state = if ok then result else nil }
	end

	Net.GetRemoteFunction("UpgradeGarden").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "UpgradeGarden") then
			return RATE_LIMITED
		end
		local ok, resultOrReason = GardenService.UpgradeGarden(player, EconomyService)
		if ok then
			return { success = true, newLevel = resultOrReason, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("PlaceDefense").OnServerInvoke = function(player: Player, defenseId: any)
		if isRateLimited(player, "PlaceDefense") then
			return RATE_LIMITED
		end
		local ok, resultOrReason = DefenseService.Place(player, defenseId)
		if ok then
			return { success = true, slot = resultOrReason.slot, cash = EconomyService.GetCash(player) }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("GetSeasonStatus").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetSeasonStatus") then
			return RATE_LIMITED
		end
		local status = SeasonService.GetStatus(player)
		if not status then
			return { success = false, reason = "no_profile" }
		end
		return { success = true, status = status }
	end

	Net.GetRemoteFunction("ClaimSeasonReward").OnServerInvoke = function(player: Player, level: any, track: any)
		if isRateLimited(player, "ClaimSeasonReward") then
			return RATE_LIMITED
		end
		if level == "all" then
			local count = SeasonService.ClaimAll(player)
			return { success = count > 0, count = count, status = SeasonService.GetStatus(player) }
		end
		local ok, reason = SeasonService.Claim(player, level, track)
		return { success = ok, reason = reason, status = SeasonService.GetStatus(player) }
	end

	Net.GetRemoteFunction("ClaimDailyReward").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "ClaimDailyReward") then
			return RATE_LIMITED
		end
		local ok, resultOrReason = DailyRewardService.Claim(player)
		if ok then
			return { success = true, reward = resultOrReason, status = DailyRewardService.GetStatus(player) }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("ClaimQuestReward").OnServerInvoke = function(player: Player, questId: any)
		if isRateLimited(player, "ClaimQuestReward") then
			return RATE_LIMITED
		end
		local ok, resultOrReason = QuestService.Claim(player, questId)
		if ok then
			return { success = true, rewardCash = resultOrReason }
		end
		return { success = false, reason = resultOrReason }
	end

	Net.GetRemoteFunction("GetQuestsAndDaily").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetQuestsAndDaily") then
			return RATE_LIMITED
		end
		if not DataService.GetProfile(player) then
			return { success = false, reason = "no_profile" }
		end
		return {
			success = true,
			quests = QuestService.GetState(player),
			daily = DailyRewardService.GetStatus(player),
		}
	end

	Net.GetRemoteFunction("GetLeaderboard").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetLeaderboard") then
			return RATE_LIMITED
		end
		local entries, source = LeaderboardService.GetTop()
		return { success = true, entries = entries, source = source }
	end

	Net.GetRemoteFunction("GetPlantCatalog").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetPlantCatalog") then
			return RATE_LIMITED
		end
		return { success = true, catalog = require(ReplicatedStorage.Shared.Config.PlantConfig).GetCatalog() }
	end

	Net.GetRemoteFunction("GetOfflineEarnings").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetOfflineEarnings") then
			return RATE_LIMITED
		end
		return { success = true, reward = OfflineEarningsService.GetReward(player) }
	end

	Net.GetRemoteFunction("GiftItem").OnServerInvoke = function(player: Player, targetName: any, plantId: any, amount: any, itemKind: any)
		if isRateLimited(player, "GiftItem") then
			return RATE_LIMITED
		end
		local target = Players:GetPlayerByUserId(tonumber(targetName) or 0)
		if not target and type(targetName) == "string" then
			for _, candidate in ipairs(Players:GetPlayers()) do
				if candidate.Name:lower() == tostring(targetName):lower() or candidate.DisplayName:lower() == tostring(targetName):lower() then
					target = candidate
					break
				end
			end
		end
		if not target then
			return { success = false, reason = "player_not_found" }
		end
		local ok, reason
		local count = 1
		if itemKind == "plant" then
			ok, reason = InventoryService.GiftPlant(player, target, tostring(plantId))
		else
			count = tonumber(amount) or 1
			ok, reason = InventoryService.GiftSeed(player, target, tostring(plantId), count)
		end
		if not ok then
			return { success = false, reason = reason }
		end
		return { success = true, target = target.Name, plantId = tostring(plantId), amount = count }
	end

	Net.GetRemoteFunction("GetRebirthInfo").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetRebirthInfo") then
			return RATE_LIMITED
		end
		local info = RebirthService.GetInfo(player)
		return { success = info ~= nil, info = info }
	end

	Net.GetRemoteFunction("GetIndexData").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "GetIndexData") then
			return RATE_LIMITED
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return { success = false, reason = "no_profile" }
		end
		local records = {}
		for plantId, record in pairs(profile.plantRecords or {}) do
			records[plantId] = { min = record.min, max = record.max, count = record.count }
		end
		local used, max = GardenService.GetPlotUsage(player)
		return {
			success = true,
			records = records,
			index = profile.plantIndex or {},
			stats = {
				lifetimeCash = profile.stats.lifetimeCash,
				plantsPlanted = profile.stats.plantsPlanted,
				plantsHarvested = profile.stats.plantsHarvested,
				plantsStolen = profile.stats.plantsStolen,
				rebirths = profile.rebirthCount or 0,
				luck = RebirthConfig.Luck(profile.rebirthCount or 0),
				cashMultiplier = RebirthConfig.CashMultiplier(profile.rebirthCount or 0),
				plotsUsed = used,
				plotsMax = max,
			},
		}
	end

	Net.GetRemoteFunction("RebirthPlayer").OnServerInvoke = function(player: Player)
		if isRateLimited(player, "RebirthPlayer") then
			return RATE_LIMITED
		end
		local ok, result = RebirthService.TryRebirth(player)
		if ok then
			return { success = true, rebirthCount = result.rebirthCount, cost = result.cost, bonusCash = result.bonusCash }
		end
		return { success = false, reason = result }
	end

	Net.GetRemoteFunction("GetPlayerProfileSnapshot").OnServerInvoke = function(player: Player)
		local profile = DataService.GetProfile(player)
		if not profile then
			return { success = false, reason = "no_profile" }
		end

		-- Tablas con índices numéricos dispersos no viajan bien por remotos:
		-- las convertimos a listas.
		local defenses = {}
		for slot, entry in pairs(profile.defenses) do
			table.insert(defenses, { slot = slot, defenseId = entry.defenseId })
		end

		return {
			success = true,
			cash = profile.cash,
			totalCashEarned = profile.totalCashEarned,
			gardenLevel = profile.gardenLevel,
			inventory = profile.inventory,
			placedPlants = profile.placedPlants,
			plantIndex = profile.plantIndex or {},
			incubatorUnlocked = profile.incubatorUnlocked == true,
			gardenShieldUntil = player:GetAttribute("GardenShieldUntil") or 0,
			equippedGear = profile.equippedGear,
			defenses = defenses,
			stats = profile.stats,
			passes = MonetizationService.GetOwned(player),
			boosts = profile.boosts or {},
			oncePurchased = profile.oncePurchased or {},
			event = EventService.GetState(),
			catalog = ShopService.GetAvailableCatalog(player),
		}
	end

	-- El robo real ocurre en servidor vía ProximityPrompt (StealService).
	Net.GetRemoteFunction("AttemptSteal").OnServerInvoke = function()
		return { success = false, reason = "use_prompt" }
	end
end

return RemoteHandlers
