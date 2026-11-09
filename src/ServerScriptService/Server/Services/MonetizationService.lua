--!strict
--[[
	MonetizationService.lua
	  - Game Passes (ventajas permanentes): se comprueban con
	    MarketplaceService:UserOwnsGamePassAsync y se refrescan en
	    PromptGamePassPurchaseFinished.
	  - Developer Products (compras repetibles): se conceden SOLO dentro de
	    MarketplaceService.ProcessReceipt, de forma idempotente (receipts por
	    PurchaseId guardados en el perfil) y guardando antes de confirmar.
	Mientras los IDs de MonetizationConfig sean 0, no se procesa nada.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Shared.Config.PetConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local MonetizationService = {}
local grantProduct: (Player, any, any) -> ()

local notifyEvent = Net.GetRemoteEvent("NotificationPush")

-- userId -> { [passKey] = true }
local owned: { [number]: { [string]: boolean } } = {}

local productsById: { [number]: any } = {}
for _, key in ipairs(MonetizationConfig.ProductOrder) do
	local product = MonetizationConfig.DevProducts[key]
	product.key = key
	if product.id ~= 0 then
		productsById[product.id] = product
	end
end

local function passKeyById(passId: number): string?
	for _, key in ipairs(MonetizationConfig.PassOrder) do
		if MonetizationConfig.GamePasses[key].id == passId and passId ~= 0 then
			return key
		end
	end
	return nil
end

function MonetizationService.LoadPlayer(player: Player)
	local set = {}
	for _, key in ipairs(MonetizationConfig.PassOrder) do
		local passId = MonetizationConfig.GamePasses[key].id
		if passId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and result then
				set[key] = true
			end
		end
	end
	owned[player.UserId] = set
	MonetizationService.ApplySpeed(player)
end

function MonetizationService.GetOwned(player: Player): { [string]: boolean }
	return owned[player.UserId] or {}
end

-- Bonus de la mascota equipada (según rareza). Siempre decidido en servidor.
local function getPetBonus(player: Player, kind: "cash" | "growth" | "luck"): number
	local profile = DataService.GetProfile(player)
	local equipped = profile and profile.inventory and profile.inventory.equippedPet
	if type(equipped) ~= "string" then
		return 0
	end
	return PetConfig.GetBonuses(equipped)[kind]
end

-- Boost temporal activo (x2 por defecto) o 1. Se guarda como hora de fin.
function MonetizationService.GetBoost(player: Player, stat: string): number
	local profile = DataService.GetProfile(player)
	local endsAt = profile and profile.boosts and profile.boosts[stat]
	if type(endsAt) == "number" and endsAt > os.time() then
		return MonetizationConfig.BoostMultipliers[stat] or 1
	end
	return 1
end

function MonetizationService.GetCashMultiplier(player: Player): number
	local multiplier = 1 + getPetBonus(player, "cash")
	local passes = MonetizationService.GetOwned(player)
	if passes.DoubleCash then
		multiplier *= MonetizationConfig.GamePasses.DoubleCash.cashMultiplier
	end
	if passes.VIP then
		multiplier *= MonetizationConfig.GamePasses.VIP.cashMultiplier
	end
	return multiplier * MonetizationService.GetBoost(player, "cash")
end

function MonetizationService.GetMutationMultiplier(player: Player): number
	local multiplier = 1 + getPetBonus(player, "luck")
	if MonetizationService.GetOwned(player).LuckyMutation then
		multiplier *= MonetizationConfig.GamePasses.LuckyMutation.mutationMultiplier
	end
	return multiplier * MonetizationService.GetBoost(player, "luck")
end

-- Huecos extra para flores colocadas (pase +3 huecos).
function MonetizationService.GetExtraPlaceSlots(player: Player): number
	if MonetizationService.GetOwned(player).ExtraSlots then
		return MonetizationConfig.GamePasses.ExtraSlots.extraPlaceSlots
	end
	return 0
end

-- Duración del domo del jardín (Maestro del escudo).
function MonetizationService.GetDomeMultiplier(player: Player): number
	if MonetizationService.GetOwned(player).ShieldMaster then
		return MonetizationConfig.GamePasses.ShieldMaster.domeMultiplier
	end
	return 1
end

-- Velocidad extra: se aplica una sola vez por personaje.
function MonetizationService.ApplySpeed(player: Player)
	if not MonetizationService.GetOwned(player).ExtraSpeed then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetAttribute("SpeedPass") ~= true then
		humanoid:SetAttribute("SpeedPass", true)
		humanoid.WalkSpeed *= MonetizationConfig.GamePasses.ExtraSpeed.speedMultiplier
	end
end

function MonetizationService.GetGrowthMultiplier(player: Player): number
	local multiplier = 1 + getPetBonus(player, "growth")
	if MonetizationService.GetOwned(player).GreenThumb then
		multiplier *= MonetizationConfig.GamePasses.GreenThumb.growthMultiplier
	end
	return multiplier
end

function MonetizationService.GetOfflineEarningsMinutes(player: Player): number
	if MonetizationService.GetOwned(player).OfflineFarmer then
		return MonetizationConfig.GamePasses.OfflineFarmer.offlineMinutes
	end
	return GameConfig.MaxOfflineEarningsMinutes
end

function MonetizationService.GetOfflineCashMultiplier(player: Player): number
	if MonetizationService.GetOwned(player).OfflineFarmer then
		return MonetizationConfig.GamePasses.OfflineFarmer.offlineCashMultiplier
	end
	return 1
end

-- Concede el contenido de un producto (siempre en servidor).
function grantProduct(player: Player, profile: any, product: any)
	local InventoryService = require(script.Parent.InventoryService)
	profile.boosts = profile.boosts or {}
	profile.oncePurchased = profile.oncePurchased or {}

	local function addBoosts(boosts: any)
		for stat, seconds in pairs(boosts) do
			local now = os.time()
			-- Se acumulan: comprar otro suma tiempo al que queda.
			profile.boosts[stat] = math.max(profile.boosts[stat] or 0, now) + seconds
		end
	end

	local kind = product.kind
	if kind == "cash" then
		EconomyService.AddCash(player, product.cash, "devproduct")
	elseif kind == "boost" then
		addBoosts(product.boosts)
	elseif kind == "instantGrow" then
		require(script.Parent.PlantService).InstantGrowAll(player)
	elseif kind == "shield" then
		require(script.Parent.StealService).GrantShield(player, product.seconds)
	elseif kind == "bundle" then
		local grants = product.grants
		if grants.cash then
			EconomyService.AddCash(player, grants.cash, "devproduct")
		end
		for packId, amount in pairs(grants.seedPacks or {}) do
			InventoryService.AddSeedPack(player, packId, amount)
		end
		for rarity, amount in pairs(grants.petEggs or {}) do
			InventoryService.AddPetEgg(player, rarity, amount)
		end
		for gearId, amount in pairs(grants.gear or {}) do
			InventoryService.AddGear(player, gearId, amount)
		end
		if grants.boosts then
			addBoosts(grants.boosts)
		end
	end
	if product.oneTime then
		profile.oncePurchased[product.key] = true
	end
	InventoryService.Push(player)
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.GetProfile(player)
	if not profile or not DataService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(info.PurchaseId)
	if profile.receipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- ya concedido antes
	end

	local product = productsById[info.ProductId]
	if not product then
		warn("[Monetization] ProductId desconocido:", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grantProduct(player, profile, product)
	profile.receipts[receiptKey] = true
	DataService.MarkDirty(player)

	-- Guardamos ANTES de confirmar: si falla, Roblox reintentará y el
	-- receipt en memoria evita conceder dos veces.
	if not DataService.SaveProfile(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	notifyEvent:FireClient(player, { text = "💎 ¡Compra recibida! " .. tostring(product.displayName), kind = "good" })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = function(info)
		local ok, result = pcall(processReceipt, info)
		if ok then
			return result
		end
		warn("[Monetization] Error en ProcessReceipt:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, wasPurchased: boolean)
		if not wasPurchased then
			return
		end
		local key = passKeyById(passId)
		if key then
			owned[player.UserId] = owned[player.UserId] or {}
			owned[player.UserId][key] = true
			MonetizationService.ApplySpeed(player)
			notifyEvent:FireClient(player, { text = "✅ ¡Pase activado!", kind = "good" })
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			MonetizationService.ApplySpeed(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player.UserId] = nil
	end)
end

return MonetizationService
