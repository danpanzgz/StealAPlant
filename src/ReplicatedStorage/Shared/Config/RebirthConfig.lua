--!strict
--[[
	RebirthConfig.lua
	Todo lo del renacimiento en un sitio (cliente y servidor leen esto):
	  - Coste en Cash (crece con cada renacimiento)
	  - Planta que hay que SACRIFICAR (una concreta por renacimiento)
	  - Multiplicador de cobro permanente: x2, x3, x4...
	  - Suerte: se DUPLICA con cada renacimiento (x2, x4, x8...)
	  - Huecos de plantación: +2 por renacimiento (ver GardenConfig.GetMaxPlots)
	  - Palo: mejora automáticamente con cada renacimiento
]]

local GameConfig = require(script.Parent.GameConfig)

local RebirthConfig = {}

-- Planta a sacrificar para el renacimiento nº (índice 1 = primer renacimiento).
-- Debe estar en tu mochila (no colocada ni creciendo).
RebirthConfig.Sacrifices = {
	"Pumpkin", "Watermelon", "Pineapple", "Dragonfruit", "EmberRose",
	"CrystalBerry", "Moonflower", "CelestialOrchid", "PhoenixBloom", "CosmicPeony",
}
RebirthConfig.SacrificeFallback = "AuroraLotus" -- del renacimiento 11 en adelante

RebirthConfig.MaxLuck = 1024

function RebirthConfig.SacrificeFor(nextRebirth: number): string
	return RebirthConfig.Sacrifices[nextRebirth] or RebirthConfig.SacrificeFallback
end

function RebirthConfig.Cost(rebirths: number): number
	return math.floor(GameConfig.RebirthBaseCost * (GameConfig.RebirthCostMultiplier ^ rebirths))
end

-- Multiplicador de cobro permanente tras N renacimientos: 0 -> x1, 1 -> x2, 2 -> x3...
function RebirthConfig.CashMultiplier(rebirths: number): number
	return 1 + math.max(0, math.floor(rebirths))
end

-- Suerte: x1, x2, x4, x8...
function RebirthConfig.Luck(rebirths: number): number
	return math.min(RebirthConfig.MaxLuck, 2 ^ math.max(0, math.floor(rebirths)))
end

-- Palo: un nivel por renacimiento (el último se repite).
RebirthConfig.StickTiers = {
	{ name = "Palo de madera", color = Color3.fromRGB(142, 91, 48), material = Enum.Material.Wood, length = 3, power = 1.0, cooldown = 1.2 },
	{ name = "Palo reforzado", color = Color3.fromRGB(176, 112, 60), material = Enum.Material.WoodPlanks, length = 3.4, power = 1.25, cooldown = 1.1 },
	{ name = "Bastón de plata", color = Color3.fromRGB(200, 205, 215), material = Enum.Material.Metal, length = 3.8, power = 1.55, cooldown = 1.0 },
	{ name = "Cetro dorado", color = Color3.fromRGB(255, 205, 70), material = Enum.Material.Metal, length = 4.2, power = 1.9, cooldown = 0.95 },
	{ name = "Vara de cristal", color = Color3.fromRGB(130, 225, 255), material = Enum.Material.Glass, length = 4.6, power = 2.3, cooldown = 0.9 },
	{ name = "Vara arcoíris", color = Color3.fromRGB(255, 120, 220), material = Enum.Material.Neon, length = 5, power = 2.8, cooldown = 0.8 },
}

function RebirthConfig.StickTier(rebirths: number): number
	return math.clamp(math.floor(rebirths) + 1, 1, #RebirthConfig.StickTiers)
end

return RebirthConfig
