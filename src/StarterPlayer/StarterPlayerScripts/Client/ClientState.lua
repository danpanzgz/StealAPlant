--!strict
--[[
	ClientState.lua
	Cache local NO autoritativa, usada solo para pintar la UI al instante.
	El servidor es la única fuente de verdad: el inventario se reemplaza
	completo con cada evento InventoryUpdated.
]]

local ClientState = {}

ClientState.Inventory = {
	seeds = {},
	plants = {},
	gear = {},
	pets = {},
	petEggs = {},
	seedPacks = {},
} :: any
ClientState.Cash = 0
ClientState.GardenLevel = 1
ClientState.Defenses = {} :: { any }
ClientState.Passes = {} :: { [string]: boolean }
ClientState.PlacedPlants = {} :: { any }
ClientState.EquippedGear = {} :: { [string]: boolean }

function ClientState.SetInventoryFromSnapshot(inventory: any)
	ClientState.Inventory = inventory or { seeds = {}, plants = {}, gear = {}, pets = {}, petEggs = {}, seedPacks = {} }
end

-- Obsoleto: el servidor empuja el inventario real (InventoryUpdated).
-- Se mantiene como no-op para no romper controladores antiguos.
function ClientState.AdjustInventory(_plantId: string, _delta: number) end

return ClientState
