--!strict
--[[
	MutationUtil.lua
	Una planta puede tener TODOS los efectos (mutaciones) que quiera: no hay
	límite. Cada efecto multiplica el valor, así que más efectos = más precio.
	Datos: `mutations` = lista de ids; `mutation` = efecto principal (el de
	mayor multiplicador, se conserva por compatibilidad con perfiles viejos).
]]

local MutationConfig = require(script.Parent.Parent.Config.MutationConfig)

local MutationUtil = {}

local function dataOf(id: any): any
	if type(id) ~= "string" then
		return nil
	end
	local data = (MutationConfig :: any)[id]
	if type(data) == "table" and type(data.valueMultiplier) == "number" then
		return data
	end
	return nil
end

-- Lista limpia y ordenada (mayor multiplicador primero, sin repetidos).
function MutationUtil.List(mutations: any, mutation: any): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: any)
		if dataOf(id) and not seen[id] then
			seen[id] = true
			table.insert(result, id)
		end
	end
	if type(mutations) == "table" then
		for _, id in ipairs(mutations) do
			add(id)
		end
	end
	add(mutation)
	table.sort(result, function(a, b)
		return dataOf(a).valueMultiplier > dataOf(b).valueMultiplier
	end)
	return result
end

function MutationUtil.Multiplier(list: { string }): number
	local multiplier = 1
	for _, id in ipairs(list) do
		multiplier *= dataOf(id).valueMultiplier
	end
	return multiplier
end

-- Efecto principal (el más valioso) o false.
function MutationUtil.Primary(list: { string }): string | false
	return list[1] or false
end

-- Color mezclado de todos los efectos (o `fallback` si no hay).
function MutationUtil.BlendColor(list: { string }, fallback: Color3): Color3
	if #list == 0 then
		return fallback
	end
	local r, g, b = 0, 0, 0
	for _, id in ipairs(list) do
		local color: Color3 = dataOf(id).color
		r += color.R
		g += color.G
		b += color.B
	end
	return Color3.new(r / #list, g / #list, b / #list)
end

function MutationUtil.DisplayNames(list: { string }): string
	local names = {}
	for _, id in ipairs(list) do
		table.insert(names, dataOf(id).displayName)
	end
	return table.concat(names, " · ")
end

return MutationUtil
