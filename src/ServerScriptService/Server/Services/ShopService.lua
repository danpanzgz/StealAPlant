--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local StockService = require(script.Parent.StockService)
local GardenService = require(script.Parent.GardenService)
local SlapService = require(script.Parent.SlapService)

local ShopService = {}
local rarityOrder: { [string]: number } = {}
for index, rarityId in ipairs(RarityConfig.Order) do
	rarityOrder[rarityId] = index
end

local function getSeedPool(rarityId: string): { string }
	local ids = {}
	for _, plantId in ipairs(PlantConfig.Order) do
		if PlantConfig[plantId].rarity == rarityId then
			table.insert(ids, plantId)
		end
	end
	return ids
end

local function addRandomSeeds(grants: { [string]: number }, rarityId: string, count: number, random: Random): boolean
	local pool = getSeedPool(rarityId)
	if #pool == 0 then
		warn("[ShopService] No plants configured for pack rarity:", rarityId)
		return false
	end
	for _ = 1, count do
		local plantId = pool[random:NextInteger(1, #pool)]
		grants[plantId] = (grants[plantId] or 0) + 1
	end
	return true
end

local function rollPack(packId: string): { [string]: number }?
	if not ShopConfig.Packs[packId] then
		return nil
	end
	local random = Random.new()
	local grants: { [string]: number } = {}
	local tier = rarityOrder[packId]
	if not tier then
		return nil
	end

	if packId == "Common" then
		if not addRandomSeeds(grants, "Common", random:NextInteger(3, 4), random)
			or not addRandomSeeds(grants, "Uncommon", random:NextInteger(1, 2), random) then
			return nil
		end
		for _, bonus in ipairs({
			{ rarity = "Rare", chance = 0.25 },
			{ rarity = "Legendary", chance = 0.05 },
			{ rarity = "Mythic", chance = 0.0099 },
		}) do
			if random:NextNumber() < bonus.chance and not addRandomSeeds(grants, bonus.rarity, 1, random) then
				return nil
			end
		end
		return grants
	end

	if not addRandomSeeds(grants, packId, random:NextInteger(3, 4), random) then
		return nil
	end
	if packId == "Celestial" then
		if not addRandomSeeds(grants, packId, 1, random) then
			return nil
		end
		return grants
	end

	local nextRarity = RarityConfig.Order[tier + 1]
	if nextRarity and not addRandomSeeds(grants, nextRarity, random:NextInteger(1, 2), random) then
		return nil
	end

	local bonusRarities: { any } = {}
	if packId == "Uncommon" then
		bonusRarities = {
			{ rarity = "Epic", chance = 0.25 },
			{ rarity = "Legendary", chance = 0.05 },
			{ rarity = "Mythic", chance = 0.0099 },
		}
	elseif packId == "Rare" then
		bonusRarities = {
			{ rarity = "Legendary", chance = 0.25 },
			{ rarity = "Mythic", chance = 0.05 },
			{ rarity = "Celestial", chance = 0.0099 },
		}
	elseif packId == "Epic" then
		bonusRarities = {
			{ rarity = "Mythic", chance = 0.25 },
			{ rarity = "Celestial", chance = 0.05 },
		}
	elseif packId == "Legendary" then
		bonusRarities = { { rarity = "Celestial", chance = 0.05 } }
	end
	for _, bonus in ipairs(bonusRarities) do
		if random:NextNumber() < bonus.chance and not addRandomSeeds(grants, bonus.rarity, 1, random) then
			return nil
		end
	end
	return grants
end

function ShopService.GetStock(player: Player): { any }
	return {
		items = StockService.GetStock(player),
		cycle = StockService.GetCycle(),
		nextRestockAt = StockService.GetNextRestockAt(),
		restockSeconds = ShopConfig.RestockSeconds,
	}
end

function ShopService.BuyItem(player: Player, itemId: string): (boolean, any)
	if type(itemId) ~= "string" or #itemId > 64 then
		return false, "invalid_args"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local snapshot = ShopService.GetStock(player)
	if snapshot.cycle ~= StockService.GetCycle() then
		return false, "stock_refreshed"
	end
	local selected = nil
	for _, item in ipairs(snapshot.items) do
		if item.itemId == itemId then
			selected = item
			break
		end
	end
	if not selected then
		return false, "out_of_stock"
	end
	if not selected.inStock then
		return false, "out_of_stock"
	end
	if selected.remaining <= 0 then
		return false, "item_limit_reached"
	end
	if profile.cash < selected.price then
		return false, "not_enough_cash"
	end

	local reserved, reserveReason = StockService.ReservePurchase(player, snapshot.cycle, itemId, selected.limit)
	if not reserved then
		return false, reserveReason
	end
	if not EconomyService.TryRemoveCash(player, selected.price, "shop_purchase") then
		StockService.ReleasePurchase(player, snapshot.cycle, itemId)
		return false, "not_enough_cash"
	end

	local granted = false
	if selected.kind == "pack" then
		granted = InventoryService.AddSeedPack(player, selected.packId, 1)
	elseif selected.kind == "petEgg" then
		granted = InventoryService.AddPetEgg(player, selected.eggId, 1)
	elseif selected.kind == "gear" then
		granted = InventoryService.AddGear(player, selected.gearId, 1)
	end
	if not granted then
		EconomyService.AddCash(player, selected.price, "shop_refund")
		StockService.ReleasePurchase(player, snapshot.cycle, itemId)
		return false, "grant_failed"
	end
	if selected.gearId == "SlapStick" then
		SlapService.Refresh(player)
	end
	return true, {
		itemId = itemId,
		displayName = selected.displayName,
		cash = EconomyService.GetCash(player),
	}
end

function ShopService.OpenSeedPack(player: Player, packId: string): (boolean, any)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	if type(packId) ~= "string" or not ShopConfig.Packs[packId] then
		return false, "invalid_pack"
	end
	if not InventoryService.ConsumeSeedPack(player, packId) then
		return false, "pack_not_owned"
	end
	local grants = rollPack(packId)
	if not grants or not InventoryService.AddSeeds(player, grants) then
		InventoryService.AddSeedPack(player, packId, 1)
		return false, "pack_open_failed"
	end
	return true, grants
end

function ShopService.OpenPetEgg(player: Player, rarity: string): (boolean, any)
	if player:GetAttribute("CarryingStolenPlant") == true then
		return false, "carrying_stolen_plant"
	end
	if type(rarity) ~= "string" or not ShopConfig.PetEggs[rarity] then
		return false, "invalid_egg"
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end
	if profile.incubatorUnlocked ~= true then
		return false, "incubator_locked"
	end
	local petPool = PetConfig.PetsByRarity[rarity]
	if not petPool or #petPool ~= 5 then
		warn("[ShopService] Pet egg must have exactly five configured pets:", rarity)
		return false, "egg_not_configured"
	end
	if not InventoryService.ConsumePetEgg(player, rarity) then
		return false, "egg_not_owned"
	end
	local petId = petPool[Random.new():NextInteger(1, #petPool)]
	if not InventoryService.AddPet(player, petId) then
		InventoryService.AddPetEgg(player, rarity, 1)
		return false, "pet_grant_failed"
	end
	return true, { petId = petId, displayName = PetConfig.Pets[petId].displayName }
end

function ShopService.UnlockIncubator(player: Player): (boolean, string?)
	local profile = DataService.GetProfile(player)
	local garden = GardenService.GetGardenModel(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not garden or not root then
		return false, "no_profile"
	end
	if (root.Position - garden:GetPivot().Position).Magnitude > 55 then
		return false, "too_far_from_garden"
	end
	if profile.incubatorUnlocked == true then
		return false, "already_unlocked"
	end
	if not EconomyService.TryRemoveCash(player, 1000, "incubator_unlock") then
		return false, "not_enough_cash"
	end
	profile.incubatorUnlocked = true
	DataService.MarkDirty(player)
	return true
end

function ShopService.GetAvailableCatalog(player: Player): { any }
	return ShopService.GetStock(player).items
end

function ShopService.Init()
	StockService.Init()
end

return ShopService
