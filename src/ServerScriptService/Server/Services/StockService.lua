--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local StockService = {}
local purchaseMap = MemoryStoreService:GetHashMap("StealAPlantShopPurchasesV1")
local stockUpdatedEvent = Net.GetRemoteEvent("ShopStockUpdated")
local warnedAboutStudioFallback = false

local function getCycle(now: number?): number
	return math.floor((now or os.time()) / ShopConfig.RestockSeconds)
end

local function getLimit(userId: number, cycle: number, itemId: string): number
	local hash = userId % 2147483647
	for index = 1, #itemId do
		hash = (hash * 31 + string.byte(itemId, index)) % 2147483647
	end
	local seed = (hash + cycle % 100000 * 97) % 2147483647
	return Random.new(seed):NextInteger(5, 15)
end

local function getCatalog(): { any }
	local items = {}
	for packId, pack in pairs(ShopConfig.Packs) do
		table.insert(items, {
			itemId = "Pack:" .. packId,
			kind = "pack",
			packId = packId,
			displayName = pack.displayName,
			description = pack.description,
			price = pack.price,
			rarity = pack.rarity,
			stockWeight = pack.stockWeight,
		})
	end
	for rarity, egg in pairs(ShopConfig.PetEggs) do
		table.insert(items, {
			itemId = "PetEgg:" .. rarity,
			kind = "petEgg",
			eggId = rarity,
			displayName = egg.displayName,
			description = egg.description,
			price = egg.price,
			rarity = egg.rarity,
			stockWeight = egg.stockWeight,
		})
	end
	for gearId, gear in pairs(ShopConfig.Gear) do
		table.insert(items, {
			itemId = "Gear:" .. gearId,
			kind = "gear",
			gearId = gearId,
			displayName = gear.displayName,
			description = gear.description,
			price = gear.price,
			rarity = gear.rarity,
			stockWeight = gear.stockWeight,
		})
	end
	table.sort(items, function(a, b)
		return a.itemId < b.itemId
	end)
	return items
end

function StockService.GetCycle(): number
	return getCycle()
end

function StockService.GetNextRestockAt(): number
	return (getCycle() + 1) * ShopConfig.RestockSeconds
end

function StockService.GetStock(player: Player): { any }
	local cycle = getCycle()
	local random = Random.new(cycle % 2147483647)
	local available = {}
	for _, item in ipairs(getCatalog()) do
		local chance = math.clamp(item.stockWeight / 100, 0.01, 1)
		item.inStock = random:NextNumber() <= chance
		if item.inStock then
			item.limit = getLimit(player.UserId, cycle, item.itemId)
			local purchases = StockService.GetPurchased(player, cycle, item.itemId)
			item.remaining = math.max(0, item.limit - purchases)
		else
			item.limit = 0
			item.remaining = 0
		end
		table.insert(available, item)
	end
	return available
end

function StockService.GetPurchased(player: Player, cycle: number, itemId: string): number
	local key = tostring(cycle) .. ":" .. tostring(player.UserId) .. ":" .. itemId
	local ok, value = pcall(function()
		return purchaseMap:GetAsync(key)
	end)
	if ok then
		return tonumber(value) or 0
	end

	if RunService:IsStudio() then
		if not warnedAboutStudioFallback then
			warn("[StockService] MemoryStore unavailable in Studio; using session-only purchase limits.")
			warnedAboutStudioFallback = true
		end
		local profile = DataService.GetProfile(player)
		if not profile then
			return 0
		end
		profile.shopPurchases = profile.shopPurchases or {}
		return profile.shopPurchases[key] or 0
	end

	warn("[StockService] Could not read shared purchase count:", tostring(value))
	return 0
end

function StockService.ReservePurchase(player: Player, cycle: number, itemId: string, limit: number): (boolean, string?)
	local key = tostring(cycle) .. ":" .. tostring(player.UserId) .. ":" .. itemId
	local ok, updatedValue = pcall(function()
		return purchaseMap:UpdateAsync(key, function(current)
			local purchased = tonumber(current) or 0
			if purchased >= limit then
				return nil
			end
			return purchased + 1
		end, ShopConfig.RestockSeconds * 3)
	end)
	if ok then
		if updatedValue == nil then
			return false, "item_limit_reached"
		end
		return true
	end

	if RunService:IsStudio() then
		local profile = DataService.GetProfile(player)
		if not profile then
			return false, "no_profile"
		end
		profile.shopPurchases = profile.shopPurchases or {}
		local current = profile.shopPurchases[key] or 0
		if current >= limit then
			return false, "item_limit_reached"
		end
		profile.shopPurchases[key] = current + 1
		DataService.MarkDirty(player)
		if not warnedAboutStudioFallback then
			warn("[StockService] MemoryStore unavailable in Studio; using session-only purchase limits.")
			warnedAboutStudioFallback = true
		end
		return true
	end

	warn("[StockService] Could not reserve shared purchase count:", tostring(updatedValue))
	return false, "stock_service_unavailable"
end

function StockService.ReleasePurchase(player: Player, cycle: number, itemId: string)
	local key = tostring(cycle) .. ":" .. tostring(player.UserId) .. ":" .. itemId
	local ok, err = pcall(function()
		purchaseMap:UpdateAsync(key, function(current)
			return math.max(0, (tonumber(current) or 0) - 1)
		end, ShopConfig.RestockSeconds * 3)
	end)
	if not ok then
		if RunService:IsStudio() then
			local profile = DataService.GetProfile(player)
			if profile and profile.shopPurchases then
				profile.shopPurchases[key] = math.max(0, (profile.shopPurchases[key] or 0) - 1)
				DataService.MarkDirty(player)
			end
			return
		end
		warn("[StockService] Could not release purchase reservation:", tostring(err))
	end
end

function StockService.Init()
	task.spawn(function()
		local lastCycle = getCycle()
		while true do
			task.wait(1)
			local currentCycle = getCycle()
			if currentCycle ~= lastCycle then
				lastCycle = currentCycle
				stockUpdatedEvent:FireAllClients({ cycle = currentCycle, nextRestockAt = StockService.GetNextRestockAt() })
			end
		end
	end)
end

return StockService
