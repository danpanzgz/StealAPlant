--!strict
--[[
	DataService.lua
	Única fuente de verdad para leer/escribir datos persistentes de jugador.
	Garantías:
	  - Carga con reintentos (backoff exponencial).
	  - Autosave periódico, guardado al salir y en BindToClose.
	  - Un perfil que falló al cargar NUNCA sobreescribe datos reales.
	  - "Reconcile": perfiles antiguos reciben los campos nuevos.
	  - plots/defenses usan claves numéricas dispersas en memoria; el
	    DataStore no las admite, así que se guardan con claves string.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)

local DataService = {}

local playerStore = DataStoreService:GetDataStore(GameConfig.DataStoreName)

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

local function newDefaultProfile(): any
	return {
		version = 2,
		cash = GameConfig.StarterCash,
		totalCashEarned = 0,
		gardenLevel = 1,
		incubatorUnlocked = false,
		inventory = {
			seeds = { [GameConfig.StarterSeedId] = 3 },
			plants = {},
			gear = {},
			pets = { PetConfig.StarterPetId },
			equippedPet = PetConfig.StarterPetId,
			petEggs = { Common = 1 },
			seedPacks = { Common = 1 },
		},
		plots = {}, -- [plotIndex] = { plantId, plantedAt, mutation, size, weight }
		placedPlants = {},
		equippedGear = {},
		shopPurchases = {},
		defenses = {}, -- [slotIndex] = { defenseId, placedAt }
		unlockedZones = { "StarterMeadow" },
		ownedGamePasses = {},
		questProgress = {},
		receipts = {}, -- [tostring(PurchaseId)] = true (compras ya concedidas)
		lastDailyRewardAt = 0,
		dailyRewardStreak = 0,
		stats = {
			plantsHarvested = 0,
			plantsStolen = 0,
			plantsLost = 0,
		},
		rebirthCount = 0,
		lastSeenAt = os.time(),
		createdAt = os.time(),
	}
end

local function normalizeInventory(raw: any): any
	local inventory = {
		seeds = {},
		plants = {},
		gear = {},
		pets = { PetConfig.StarterPetId },
		equippedPet = PetConfig.StarterPetId,
		petEggs = {},
		seedPacks = {},
	}

	if type(raw) ~= "table" then
		inventory.seeds[GameConfig.StarterSeedId] = 3
		inventory.seedPacks.Common = 1
		inventory.petEggs.Common = 1
		return inventory
	end

	if type(raw.seeds) == "table" then
		inventory.seeds = deepCopy(raw.seeds)
	else
		-- v1 profiles stored seed counts directly under inventory.
		for itemId, count in pairs(raw) do
			if type(itemId) == "string" and type(count) == "number" and count > 0 then
				inventory.seeds[itemId] = math.floor(count)
			end
		end
		inventory.seedPacks.Common = 1
	end

	for _, field in ipairs({ "plants", "gear", "pets", "seedPacks", "petEggs" }) do
		if type(raw[field]) == "table" then
			inventory[field] = deepCopy(raw[field])
		end
	end
	for index, petId in ipairs(inventory.pets) do
		if petId == "GardenCat" then
			inventory.pets[index] = PetConfig.StarterPetId
		end
	end
	if #inventory.pets == 0 then
		inventory.pets = { PetConfig.StarterPetId }
	end
	if type(raw.petEggs) ~= "table" then
		inventory.petEggs.Common = 1
	end
	local equippedPet = raw.equippedPet
	if equippedPet == "GardenCat" or not PetConfig.Pets[equippedPet] then
		equippedPet = inventory.pets[1]
	end
	inventory.equippedPet = equippedPet

	return inventory
end

local function reconcile(data: any, defaults: any)
	for key, defaultValue in pairs(defaults) do
		if data[key] == nil then
			data[key] = deepCopy(defaultValue)
		elseif key == "stats" and type(data[key]) == "table" then
			reconcile(data[key], defaultValue)
		end
	end
end

local function stringKeys(t: any): any
	local out = {}
	for k, v in pairs(t) do
		out[tostring(k)] = v
	end
	return out
end

local function numberKeys(t: any): any
	local out = {}
	for k, v in pairs(t) do
		out[tonumber(k) or k] = v
	end
	return out
end

local function toSaveData(data: any): any
	local copy = table.clone(data)
	copy.plots = stringKeys(data.plots or {})
	copy.defenses = stringKeys(data.defenses or {})
	return copy
end

local function fromSaveData(data: any): any
	data.plots = numberKeys(data.plots or {})
	data.defenses = numberKeys(data.defenses or {})
	reconcile(data, newDefaultProfile())
	data.inventory = normalizeInventory(data.inventory)
	data.placedPlants = type(data.placedPlants) == "table" and data.placedPlants or {}
	data.incubatorUnlocked = data.incubatorUnlocked == true
	data.equippedGear = type(data.equippedGear) == "table" and data.equippedGear or {}
	data.shopPurchases = type(data.shopPurchases) == "table" and data.shopPurchases or {}
	data.version = 2
	return data
end

local profiles: { [number]: { data: any, loaded: boolean, dirty: boolean } } = {}

local function attemptWithRetries(fn: () -> any, maxRetries: number): (boolean, any)
	local attempt = 0
	local waitTime = GameConfig.SaveRetryBackoff
	while attempt < maxRetries do
		attempt += 1
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		local errorMessage = tostring(result)
		warn(string.format("[DataService] Intento %d/%d fallido: %s", attempt, maxRetries, errorMessage))
		if RunService:IsStudio() and string.find(errorMessage, "Studio access to APIs is not allowed", 1, true) then
			return false, nil
		end
		if attempt < maxRetries then
			task.wait(waitTime)
			waitTime *= 2
		end
	end
	return false, nil
end

function DataService.LoadProfile(player: Player)
	local key = "Player_" .. player.UserId

	local ok, data = attemptWithRetries(function()
		return playerStore:GetAsync(key)
	end, GameConfig.MaxSaveRetries)

	if not player.Parent then
		return
	end

	if not ok then
		warn("[DataService] No se pudo cargar el perfil de", player.Name, "- perfil temporal (no se guardará)")
		profiles[player.UserId] = { data = newDefaultProfile(), loaded = false, dirty = false }
		return
	end

	local needsPetMigration = type(data) == "table"
		and (
			type(data.inventory) ~= "table"
			or type(data.inventory.pets) ~= "table"
			or #data.inventory.pets == 0
			or type(data.inventory.petEggs) ~= "table"
			or data.inventory.equippedPet == nil
			or data.inventory.equippedPet == "GardenCat"
		)
	local profileData
	if type(data) == "table" then
		profileData = fromSaveData(data)
	else
		profileData = newDefaultProfile()
	end
	-- Jugador nuevo: marcar dirty para que se guarde en el primer autosave.
	profiles[player.UserId] = { data = profileData, loaded = true, dirty = data == nil or needsPetMigration }
end

function DataService.GetProfile(player: Player): any?
	local entry = profiles[player.UserId]
	if not entry then
		return nil
	end
	return entry.data
end

function DataService.IsLoaded(player: Player): boolean
	local entry = profiles[player.UserId]
	return entry ~= nil and entry.loaded
end

function DataService.MarkDirty(player: Player)
	local entry = profiles[player.UserId]
	if entry then
		entry.dirty = true
	end
end

-- Devuelve true si el guardado fue correcto (o no hacía falta).
function DataService.SaveProfile(player: Player, isFinalSave: boolean?): boolean
	local entry = profiles[player.UserId]
	if not entry then
		return true
	end
	if not entry.loaded then
		return false
	end
	if not isFinalSave and not entry.dirty then
		return true
	end

	local key = "Player_" .. player.UserId
	local ok = attemptWithRetries(function()
		playerStore:SetAsync(key, toSaveData(entry.data))
	end, GameConfig.MaxSaveRetries)

	if ok then
		entry.dirty = false
	else
		warn("[DataService] Guardado fallido para", player.Name, "- los datos pueden perderse")
	end
	return ok
end

function DataService.ReleaseProfile(player: Player)
	profiles[player.UserId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	local profile = DataService.GetProfile(player)
	if profile then
		profile.lastSeenAt = os.time()
		DataService.MarkDirty(player)
	end
	DataService.SaveProfile(player, true)
	DataService.ReleaseProfile(player)
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			local profile = DataService.GetProfile(player)
			if profile then
				profile.lastSeenAt = os.time()
				DataService.MarkDirty(player)
			end
			DataService.SaveProfile(player, true)
			pending -= 1
		end)
	end
	local startedAt = os.clock()
	while pending > 0 and os.clock() - startedAt < 25 do
		task.wait(0.2)
	end
end)

function DataService.StartAutosaveLoop()
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.GetProfile(player)
				if profile then
					profile.lastSeenAt = os.time()
					DataService.MarkDirty(player)
				end
				task.spawn(DataService.SaveProfile, player, false)
			end
		end
	end)
end

return DataService
