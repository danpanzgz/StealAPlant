--!strict
--[[
	PlantConfig.lua
	Catálogo completo de las plantas. Esta es LA fuente de verdad
	para precio de semilla, tiempo de crecimiento, valor de venta e ingreso
	pasivo. Todo el balance de progresión se ajusta editando esta tabla.

	growTimeSeconds: tiempo total para pasar de Seed -> Mature.
	stageCount: número de fases visuales de crecimiento (Seed, Sprout, ... Mature).
	baseSellValue: valor de venta al cosechar en estado Mature, sin mutación.
	passiveIncomePerCycle: base histórica usada para calcular el ingreso por
		minuto de una flor individual colocada en el jardín.
	color: color base usado para representar la planta con Parts simples
		(placeholder art-friendly, reemplazable por modelos reales sin tocar lógica).
]]

export type PlantData = {
	id: string,
	displayName: string,
	rarity: string,
	seedPrice: number,
	growTimeSeconds: number,
	stageCount: number,
	baseSellValue: number,
	passiveIncomePerCycle: number,
	color: Color3,
}

local PlantConfig: { [string]: PlantData } = {

	Carrot = {
		id = "Carrot", displayName = "Carrot", rarity = "Common",
		seedPrice = 0, growTimeSeconds = 25, stageCount = 3,
		baseSellValue = 8, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(255, 140, 40),
	},
	Potato = {
		id = "Potato", displayName = "Potato", rarity = "Common",
		seedPrice = 15, growTimeSeconds = 40, stageCount = 3,
		baseSellValue = 12, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(198, 156, 109),
	},
	Tomato = {
		id = "Tomato", displayName = "Tomato", rarity = "Common",
		seedPrice = 30, growTimeSeconds = 55, stageCount = 4,
		baseSellValue = 20, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(224, 58, 47),
	},
	Corn = {
		id = "Corn", displayName = "Corn", rarity = "Common",
		seedPrice = 45, growTimeSeconds = 70, stageCount = 4,
		baseSellValue = 28, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(255, 221, 89),
	},
	Sunflower = {
		id = "Sunflower", displayName = "Sunflower", rarity = "Uncommon",
		seedPrice = 90, growTimeSeconds = 100, stageCount = 4,
		baseSellValue = 55, passiveIncomePerCycle = 4,
		color = Color3.fromRGB(255, 200, 40),
	},
	Strawberry = {
		id = "Strawberry", displayName = "Strawberry", rarity = "Uncommon",
		seedPrice = 120, growTimeSeconds = 130, stageCount = 4,
		baseSellValue = 70, passiveIncomePerCycle = 5,
		color = Color3.fromRGB(235, 45, 90),
	},
	Pumpkin = {
		id = "Pumpkin", displayName = "Pumpkin", rarity = "Uncommon",
		seedPrice = 180, growTimeSeconds = 160, stageCount = 4,
		baseSellValue = 95, passiveIncomePerCycle = 6,
		color = Color3.fromRGB(255, 140, 20),
	},

	Cactus = {
		id = "Cactus", displayName = "Cactus", rarity = "Uncommon",
		seedPrice = 260, growTimeSeconds = 150, stageCount = 4,
		baseSellValue = 110, passiveIncomePerCycle = 7,
		color = Color3.fromRGB(60, 158, 90),
	},
	Blueberry = {
		id = "Blueberry", displayName = "Blueberry", rarity = "Uncommon",
		seedPrice = 320, growTimeSeconds = 170, stageCount = 4,
		baseSellValue = 135, passiveIncomePerCycle = 8,
		color = Color3.fromRGB(70, 90, 200),
	},
	Grape = {
		id = "Grape", displayName = "Grape", rarity = "Rare",
		seedPrice = 480, growTimeSeconds = 220, stageCount = 5,
		baseSellValue = 210, passiveIncomePerCycle = 12,
		color = Color3.fromRGB(120, 60, 170),
	},
	Watermelon = {
		id = "Watermelon", displayName = "Watermelon", rarity = "Rare",
		seedPrice = 650, growTimeSeconds = 260, stageCount = 5,
		baseSellValue = 280, passiveIncomePerCycle = 15,
		color = Color3.fromRGB(45, 175, 90),
	},
	Pineapple = {
		id = "Pineapple", displayName = "Pineapple", rarity = "Rare",
		seedPrice = 800, growTimeSeconds = 300, stageCount = 5,
		baseSellValue = 340, passiveIncomePerCycle = 18,
		color = Color3.fromRGB(230, 200, 40),
	},
	Coconut = {
		id = "Coconut", displayName = "Coconut", rarity = "Rare",
		seedPrice = 950, growTimeSeconds = 330, stageCount = 5,
		baseSellValue = 390, passiveIncomePerCycle = 20,
		color = Color3.fromRGB(150, 110, 70),
	},
	Dragonfruit = {
		id = "Dragonfruit", displayName = "Dragonfruit", rarity = "Epic",
		seedPrice = 1400, growTimeSeconds = 400, stageCount = 5,
		baseSellValue = 620, passiveIncomePerCycle = 30,
		color = Color3.fromRGB(230, 60, 140),
	},

	Starfruit = {
		id = "Starfruit", displayName = "Starfruit", rarity = "Rare",
		seedPrice = 1800, growTimeSeconds = 360, stageCount = 5,
		baseSellValue = 700, passiveIncomePerCycle = 34,
		color = Color3.fromRGB(255, 230, 90),
	},
	EmberRose = {
		id = "EmberRose", displayName = "Ember Rose", rarity = "Epic",
		seedPrice = 2600, growTimeSeconds = 420, stageCount = 5,
		baseSellValue = 980, passiveIncomePerCycle = 45,
		color = Color3.fromRGB(255, 90, 60),
	},
	CrystalBerry = {
		id = "CrystalBerry", displayName = "Crystal Berry", rarity = "Epic",
		seedPrice = 3200, growTimeSeconds = 460, stageCount = 5,
		baseSellValue = 1150, passiveIncomePerCycle = 52,
		color = Color3.fromRGB(140, 220, 255),
	},
	Moonflower = {
		id = "Moonflower", displayName = "Moonflower", rarity = "Epic",
		seedPrice = 4000, growTimeSeconds = 500, stageCount = 5,
		baseSellValue = 1400, passiveIncomePerCycle = 60,
		color = Color3.fromRGB(200, 190, 255),
	},
	CelestialOrchid = {
		id = "CelestialOrchid", displayName = "Celestial Orchid", rarity = "Legendary",
		seedPrice = 6500, growTimeSeconds = 600, stageCount = 6,
		baseSellValue = 2400, passiveIncomePerCycle = 95,
		color = Color3.fromRGB(255, 255, 255),
	},
	PhoenixBloom = {
		id = "PhoenixBloom", displayName = "Phoenix Bloom", rarity = "Legendary",
		seedPrice = 9000, growTimeSeconds = 720, stageCount = 6,
		baseSellValue = 3200, passiveIncomePerCycle = 130,
		color = Color3.fromRGB(255, 140, 40),
	},
	CosmicPeony = {
		id = "CosmicPeony", displayName = "Cosmic Peony", rarity = "Mythic",
		seedPrice = 25000, growTimeSeconds = 900, stageCount = 6,
		baseSellValue = 9500, passiveIncomePerCycle = 360,
		color = Color3.fromRGB(255, 91, 158),
	},
	AuroraLotus = {
		id = "AuroraLotus", displayName = "Aurora Lotus", rarity = "Celestial",
		seedPrice = 80000, growTimeSeconds = 1200, stageCount = 6,
		baseSellValue = 30000, passiveIncomePerCycle = 1000,
		color = Color3.fromRGB(120, 225, 255),
	},
}

PlantConfig.Order = {
	"Carrot", "Potato", "Tomato", "Corn", "Sunflower", "Strawberry", "Pumpkin",
	"Cactus", "Blueberry", "Grape", "Watermelon", "Pineapple", "Coconut", "Dragonfruit",
	"Starfruit", "EmberRose", "CrystalBerry", "Moonflower", "CelestialOrchid",
	"PhoenixBloom", "CosmicPeony", "AuroraLotus",
} :: any

function PlantConfig.GetCatalog(): { [number]: any }
	local catalog = {}
	for _, plantId in ipairs(PlantConfig.Order) do
		local plant = PlantConfig[plantId]
		if plant then
			table.insert(catalog, {
				id = plant.id,
				displayName = plant.displayName,
				rarity = plant.rarity,
				seedPrice = plant.seedPrice,
				growTimeSeconds = plant.growTimeSeconds,
				baseSellValue = plant.baseSellValue,
				passiveIncomePerCycle = plant.passiveIncomePerCycle,
				color = plant.color,
			})
		end
	end
	return catalog
end

return PlantConfig
