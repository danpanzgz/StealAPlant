--!strict
--[[
	PlantInstanceConfig.lua
	Tamaños de cada planta individual.
	  multiplier  : multiplica valor, ingresos y peso.
	  visualScale : tamaño en el mundo (Big y Giant son MUCHO más grandes).
	  label       : prefijo en nombres ("" = Normal, no se muestra nada).
]]

local MutationUtil = require(script.Parent.Parent.Modules.MutationUtil)

local PlantInstanceConfig = {}

PlantInstanceConfig.Sizes = {
	Normal = { displayName = "Normal", label = "", multiplier = 1, visualScale = 1, weight = 84 },
	Large = { displayName = "Big", label = "Big", multiplier = 1.65, visualScale = 2.2, weight = 14 },
	Giant = { displayName = "Giant", label = "Giant", multiplier = 3, visualScale = 4.5, weight = 2 },
}
PlantInstanceConfig.SizeOrder = { "Normal", "Large", "Giant" }
PlantInstanceConfig.MutationOrder = { "Diamond", "Gold" }
PlantInstanceConfig.PlaceCapacityBase = 6
PlantInstanceConfig.PlaceCapacityPerRebirth = 2

-- Nombre mostrado en inventario y etiquetas:
--   [Big|Giant] Nombre [· Efecto · Efecto...] [· 1.23 kg]      (Normal no lleva prefijo)
function PlantInstanceConfig.FormatName(displayName: string, sizeId: string?, mutationId: any, weightKg: number?): string
	local size = PlantInstanceConfig.Sizes[sizeId or "Normal"]
	local text = displayName
	if size and size.label ~= "" then
		text = size.label .. " " .. text
	end
	-- `mutationId` puede ser un id suelto o la lista completa de efectos.
	local list = MutationUtil.List(if type(mutationId) == "table" then mutationId else nil, if type(mutationId) == "string" then mutationId else nil)
	if #list > 0 then
		text ..= " · " .. MutationUtil.DisplayNames(list)
	end
	if weightKg then
		text ..= string.format(" · %.2f kg", weightKg)
	end
	return text
end

return PlantInstanceConfig
