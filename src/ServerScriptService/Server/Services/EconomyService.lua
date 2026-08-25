--!strict
--[[
	EconomyService.lua
	ÚNICO punto autorizado para modificar el Cash de un jugador.
	Ningún otro sistema debe tocar profile.cash directamente: todos pasan
	por AddCash / TryRemoveCash. Esto es lo que hace imposible que el
	cliente "invente" dinero: el cliente nunca toca esta tabla, solo recibe
	el resultado ya validado.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local cashUpdatedEvent = Net.GetRemoteEvent("CashUpdated")

local function pushCashUpdate(player: Player, profile: any)
	cashUpdatedEvent:FireClient(player, {
		cash = profile.cash,
		totalCashEarned = profile.totalCashEarned,
	})
end

-- Añade Cash de forma segura. "source" es solo para logging/analytics
-- (ej: "harvest", "steal", "daily_reward", "devproduct").
function EconomyService.AddCash(player: Player, amount: number, source: string?)
	if amount <= 0 then
		return
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	profile.cash += amount
	profile.totalCashEarned += amount
	DataService.MarkDirty(player)
	pushCashUpdate(player, profile)
end

-- Intenta gastar Cash. Devuelve true si tenía suficiente y se descontó.
-- SIEMPRE se debe comprobar el valor de retorno antes de otorgar lo que
-- sea que el jugador esté comprando.
function EconomyService.TryRemoveCash(player: Player, amount: number, source: string?): boolean
	if amount <= 0 then
		return true
	end
	local profile = DataService.GetProfile(player)
	if not profile then
		return false
	end
	if profile.cash < amount then
		return false
	end
	profile.cash -= amount
	DataService.MarkDirty(player)
	pushCashUpdate(player, profile)
	return true
end

-- Reenvía el Cash actual al cliente sin modificarlo. Se usa al conectar
-- para que el HUD muestre el saldo real cargado desde DataStore sin
-- esperar a la primera transacción.
function EconomyService.PushSnapshot(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then
		return
	end
	pushCashUpdate(player, profile)
end

function EconomyService.GetCash(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then
		return 0
	end
	return profile.cash
end

return EconomyService
