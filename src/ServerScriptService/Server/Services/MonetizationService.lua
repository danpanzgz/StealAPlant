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

local notifyEvent = Net.GetRemoteEvent("NotificationPush")

-- userId -> { [passKey] = true }
local owned: { [number]: { [string]: boolean } } = {}

local productsById: { [number]: any } = {}
for _, key in ipairs(MonetizationConfig.ProductOrder) do
	local product = MonetizationConfig.DevProducts[key]
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

function MonetizationService.GetCashMultiplier(player: Player): number
	local multiplier = 1 + getPetBonus(player, "cash")
	if MonetizationService.GetOwned(player).DoubleCash then
		multiplier *= MonetizationConfig.GamePasses.DoubleCash.cashMultiplier
	end
	return multiplier
end

function MonetizationService.GetMutationMultiplier(player: Player): number
	local multiplier = 1 + getPetBonus(player, "luck")
	if MonetizationService.GetOwned(player).LuckyMutation then
		multiplier *= MonetizationConfig.GamePasses.LuckyMutation.mutationMultiplier
	end
	return multiplier
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

	EconomyService.AddCash(player, product.cash, "devproduct")
	profile.receipts[receiptKey] = true
	DataService.MarkDirty(player)

	-- Guardamos ANTES de confirmar: si falla, Roblox reintentará y el
	-- receipt en memoria evita conceder dos veces.
	if not DataService.SaveProfile(player, true) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	notifyEvent:FireClient(player, { text = "💎 ¡Compra recibida! +" .. product.cash .. " Cash", kind = "good" })
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
			notifyEvent:FireClient(player, { text = "✅ ¡Pase activado!", kind = "good" })
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		owned[player.UserId] = nil
	end)
end

return MonetizationService
