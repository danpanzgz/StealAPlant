--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local ShopConfig = require(ReplicatedStorage.Shared.Config.ShopConfig)
local DataService = require(script.Parent.DataService)

local InventoryService = {}
local inventoryEvent = Net.GetRemoteEvent("InventoryUpdated")
local discoveredEvent = Net.GetRemoteEvent("PlantDiscovered")

local function countDiscovered(profile: any): number
	local count = 0
	for plantId in pairs(profile.plantIndex or {}) do
		if PlantConfig[plantId] then
			count += 1
		end
	end
	return count
end

local function totalPlants(): number
	return #PlantConfig.GetCatalog()
end

-- Registra la planta en el Índice. Devuelve true si es la primera vez.
local function registerDiscovery(player: Player, profile: any, plant: any): boolean
	profile.plantIndex = profile.plantIndex or {}
	if profile.plantIndex[plant.plantId] then
		return false
	end
	profile.plantIndex[plant.plantId] = true
	discoveredEvent:FireClient(player, {
		plantId = plant.plantId,
		mutation = plant.mutation,
		mutations = plant.mutations,
		size = plant.size,
		discovered = countDiscovered(profile),
		total = totalPlants(),
	})
	return true
end

local function ensureInventory(profile: any)
	profile.inventory.seeds = profile.inventory.seeds or {}
	profile.inventory.plants = profile.inventory.plants or {}
	profile.inventory.gear = profile.inventory.gear or {}
	profile.inventory.pets = profile.inventory.pets or {}
	profile.inventory.petEggs = profile.inventory.petEggs or {}
	profile.inventory.seedPacks = profile.inventory.seedPacks or {}
end

function InventoryService.Push(player: Player)
	local profile = DataService.GetProfile(player)
	if profile then
		ensureInventory(profile)
		inventoryEvent:FireClient(player, profile.inventory, profile.placedPlants or {}, profile.equippedGear or {})
	end
end

function InventoryService.GetSeedCount(player: Player, plantId: string): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	ensureInventory(profile)
	return profile.inventory.seeds[plantId] or 0
end

function InventoryService.AddSeed(player: Player, plantId: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not PlantConfig[plantId] or amount <= 0 then
		return false
	end
	ensureInventory(profile)
	profile.inventory.seeds[plantId] = (profile.inventory.seeds[plantId] or 0) + math.floor(amount)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.AddSeeds(player: Player, grants: { [string]: number }): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	ensureInventory(profile)
	for plantId, amount in pairs(grants) do
		if not PlantConfig[plantId] or type(amount) ~= "number" or amount < 1 then
			return false
		end
	end
	for plantId, amount in pairs(grants) do
		profile.inventory.seeds[plantId] = (profile.inventory.seeds[plantId] or 0) + math.floor(amount)
	end
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.AddSeedPack(player: Player, packId: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or type(packId) ~= "string" or amount < 1 then
		return false
	end
	ensureInventory(profile)
	profile.inventory.seedPacks[packId] = (profile.inventory.seedPacks[packId] or 0) + math.floor(amount)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.ConsumeSeedPack(player: Player, packId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	ensureInventory(profile)
	local count = profile.inventory.seedPacks[packId] or 0
	if count < 1 then
		return false
	end
	profile.inventory.seedPacks[packId] = count - 1
	if profile.inventory.seedPacks[packId] <= 0 then
		profile.inventory.seedPacks[packId] = nil
	end
	DataService.MarkDirty(player)
	return true
end

function InventoryService.AddPetEgg(player: Player, rarity: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not ShopConfig.PetEggs[rarity] or amount < 1 then
		return false
	end
	ensureInventory(profile)
	profile.inventory.petEggs[rarity] = (profile.inventory.petEggs[rarity] or 0) + math.floor(amount)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.ConsumePetEgg(player: Player, rarity: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not ShopConfig.PetEggs[rarity] then
		return false
	end
	ensureInventory(profile)
	local count = profile.inventory.petEggs[rarity] or 0
	if count < 1 then
		return false
	end
	profile.inventory.petEggs[rarity] = count - 1
	if profile.inventory.petEggs[rarity] <= 0 then
		profile.inventory.petEggs[rarity] = nil
	end
	DataService.MarkDirty(player)
	return true
end

function InventoryService.AddPet(player: Player, petId: string): boolean
	local profile = DataService.GetProfile(player)
	if not profile or not PetConfig.Pets[petId] then
		return false
	end
	ensureInventory(profile)
	table.insert(profile.inventory.pets, petId)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.AddGear(player: Player, gearId: string, amount: number): boolean
	local profile = DataService.GetProfile(player)
	if not profile or type(gearId) ~= "string" or amount < 1 then
		return false
	end
	ensureInventory(profile)
	profile.inventory.gear[gearId] = (profile.inventory.gear[gearId] or 0) + math.floor(amount)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.AddPlant(player: Player, plant: any): boolean
	local profile = DataService.GetProfile(player)
	if not profile or type(plant) ~= "table" or not PlantConfig[plant.plantId] or type(plant.uid) ~= "string" then
		return false
	end
	ensureInventory(profile)
	table.insert(profile.inventory.plants, plant)
	registerDiscovery(player, profile, plant)
	-- Récord de peso por especie (Índice).
	local weight = tonumber(plant.weight)
	if weight and PlantConfig[plant.plantId] then
		profile.plantRecords = profile.plantRecords or {}
		local record = profile.plantRecords[plant.plantId]
		if not record then
			record = { min = weight, max = weight, count = 0 }
			profile.plantRecords[plant.plantId] = record
		end
		record.min = math.min(record.min, weight)
		record.max = math.max(record.max, weight)
		record.count += 1
	end
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return true
end

function InventoryService.FindPlant(player: Player, uid: string): (number?, any?)
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil, nil
	end
	ensureInventory(profile)
	for index, plant in ipairs(profile.inventory.plants) do
		if plant.uid == uid then
			return index, plant
		end
	end
	return nil, nil
end

function InventoryService.RemovePlant(player: Player, uid: string): any?
	local profile = DataService.GetProfile(player)
	if not profile then
		return nil
	end
	local index, plant = InventoryService.FindPlant(player, uid)
	if not index then
		return nil
	end
	table.remove(profile.inventory.plants, index)
	DataService.MarkDirty(player)
	InventoryService.Push(player)
	return plant
end

function InventoryService.GiftSeed(fromPlayer: Player, targetPlayer: Player, plantId: string, amount: number): (boolean, string)
	if fromPlayer == targetPlayer then
		return false, "self_gift"
	end
	if not PlantConfig[plantId] or type(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 or amount > 99 then
		return false, "invalid_item"
	end

	local fromProfile = DataService.GetProfile(fromPlayer)
	local targetProfile = DataService.GetProfile(targetPlayer)
	if not fromProfile or not targetProfile then
		return false, "profile_missing"
	end
	ensureInventory(fromProfile)
	ensureInventory(targetProfile)
	if (fromProfile.inventory.seeds[plantId] or 0) < amount then
		return false, "not_enough"
	end

	fromProfile.inventory.seeds[plantId] -= amount
	if fromProfile.inventory.seeds[plantId] <= 0 then
		fromProfile.inventory.seeds[plantId] = nil
	end
	targetProfile.inventory.seeds[plantId] = (targetProfile.inventory.seeds[plantId] or 0) + amount
	DataService.MarkDirty(fromPlayer)
	DataService.MarkDirty(targetPlayer)
	InventoryService.Push(fromPlayer)
	InventoryService.Push(targetPlayer)
	return true, targetPlayer.DisplayName
end

function InventoryService.GiftPlant(fromPlayer: Player, targetPlayer: Player, plantUid: string): (boolean, string)
	if fromPlayer == targetPlayer then
		return false, "self_gift"
	end
	if type(plantUid) ~= "string" or #plantUid > 64 then
		return false, "invalid_item"
	end
	local fromProfile = DataService.GetProfile(fromPlayer)
	local targetProfile = DataService.GetProfile(targetPlayer)
	if not fromProfile or not targetProfile then
		return false, "profile_missing"
	end
	for _, placed in ipairs(fromProfile.placedPlants or {}) do
		if placed.uid == plantUid then
			return false, "plant_is_placed"
		end
	end
	local index, plant = InventoryService.FindPlant(fromPlayer, plantUid)
	if not index or not plant then
		return false, "item_not_found"
	end
	ensureInventory(targetProfile)
	table.remove(fromProfile.inventory.plants, index)
	table.insert(targetProfile.inventory.plants, plant)
	DataService.MarkDirty(fromPlayer)
	DataService.MarkDirty(targetPlayer)
	InventoryService.Push(fromPlayer)
	InventoryService.Push(targetPlayer)
	return true, targetPlayer.DisplayName
end

return InventoryService
