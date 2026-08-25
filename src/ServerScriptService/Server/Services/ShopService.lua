--!strict
--[[
	ShopService.lua
	Seed Shop server-validado. El cliente solo pide "quiero comprar X",
	el servidor decide si es posible (zona desbloqueada + Cash suficiente)
	y es quien concede la semilla al inventario.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlantConfig = require(ReplicatedStorage.Shared.Config.PlantConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local ShopService = {}

local function isZoneUnlocked(profile: any, zoneId: string): boolean
	local zoneData = ZoneConfig[zoneId]
	if not zoneData then
		return false
	end
	return profile.totalCashEarned >= zoneData.unlockCash
end

function ShopService.BuySeed(player: Player, plantId: string): (boolean, any)
	if type(plantId) ~= "string" then
		return false, "invalid_args"
	end

	local profile = DataService.GetProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local plantData = PlantConfig[plantId]
	if not plantData then
		return false, "unknown_plant"
	end

	if not isZoneUnlocked(profile, plantData.zone) then
		return false, "zone_locked"
	end

	local ok = EconomyService.TryRemoveCash(player, plantData.seedPrice, "buy_seed")
	if not ok then
		return false, "not_enough_cash"
	end

	profile.inventory[plantId] = (profile.inventory[plantId] or 0) + 1
	DataService.MarkDirty(player)

	return true, { plantId = plantId, newCount = profile.inventory[plantId] }
end

-- Devuelve solo las plantas de zonas que el jugador ya desbloqueó,
-- ordenadas por zona. Se usa para poblar la Seed Shop en el cliente.
function ShopService.GetAvailableCatalog(player: Player): { any }
	local profile = DataService.GetProfile(player)
	if not profile then
		return {}
	end

	local catalog = {}
	for _, zoneId in ipairs(ZoneConfig.Order) do
		if isZoneUnlocked(profile, zoneId) then
			for _, plantId in ipairs(PlantConfig.OrderByZone[zoneId]) do
				local plantData = PlantConfig[plantId]
				table.insert(catalog, {
					plantId = plantId,
					displayName = plantData.displayName,
					seedPrice = plantData.seedPrice,
					rarity = plantData.rarity,
					zone = zoneId,
				})
			end
		end
	end
	return catalog
end

return ShopService
