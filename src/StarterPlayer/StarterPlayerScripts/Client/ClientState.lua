--!strict
--[[
	ClientState.lua
	Cache local NO autoritativo del inventario del jugador, usado solo
	para pintar la UI al instante (evita esperar un roundtrip al servidor
	cada vez que se abre un panel). El servidor sigue siendo la única
	fuente de verdad: si hay discrepancia, el servidor gana y el cliente
	se corrige en la siguiente respuesta.
]]

local ClientState = {}

ClientState.Inventory = {} :: { [string]: number }
ClientState.Cash = 0

function ClientState.SetInventoryFromSnapshot(inventory: { [string]: number })
	ClientState.Inventory = inventory or {}
end

function ClientState.AdjustInventory(plantId: string, delta: number)
	local current = ClientState.Inventory[plantId] or 0
	ClientState.Inventory[plantId] = math.max(0, current + delta)
end

return ClientState
