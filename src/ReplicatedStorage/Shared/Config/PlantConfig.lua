--!strict
--[[
	PlantConfig.lua
	Catálogo completo de plantas (57). Esta es LA fuente de verdad
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
	zone: string,
	rarity: string,
	seedPrice: number,
	growTimeSeconds: number,
	stageCount: number,
	baseSellValue: number,
	passiveIncomePerCycle: number,
	color: Color3,
}

local PlantConfig: { [string]: PlantData } = {

	-- ===== Zona 1: Starter Meadow =====
	Carrot = {
		id = "Carrot", displayName = "Carrot", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 0, growTimeSeconds = 25, stageCount = 3,
		baseSellValue = 8, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(255, 140, 40),
	},
	Potato = {
		id = "Potato", displayName = "Potato", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 15, growTimeSeconds = 40, stageCount = 3,
		baseSellValue = 12, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(198, 156, 109),
	},
	Tomato = {
		id = "Tomato", displayName = "Tomato", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 30, growTimeSeconds = 55, stageCount = 4,
		baseSellValue = 20, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(224, 58, 47),
	},
	Corn = {
		id = "Corn", displayName = "Corn", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 45, growTimeSeconds = 70, stageCount = 4,
		baseSellValue = 28, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(255, 221, 89),
	},
	Sunflower = {
		id = "Sunflower", displayName = "Sunflower", zone = "StarterMeadow", rarity = "Uncommon",
		seedPrice = 90, growTimeSeconds = 100, stageCount = 4,
		baseSellValue = 55, passiveIncomePerCycle = 4,
		color = Color3.fromRGB(255, 200, 40),
	},
	Strawberry = {
		id = "Strawberry", displayName = "Strawberry", zone = "StarterMeadow", rarity = "Uncommon",
		seedPrice = 120, growTimeSeconds = 130, stageCount = 4,
		baseSellValue = 70, passiveIncomePerCycle = 5,
		color = Color3.fromRGB(235, 45, 90),
	},
	Pumpkin = {
		id = "Pumpkin", displayName = "Pumpkin", zone = "StarterMeadow", rarity = "Uncommon",
		seedPrice = 180, growTimeSeconds = 160, stageCount = 4,
		baseSellValue = 95, passiveIncomePerCycle = 6,
		color = Color3.fromRGB(255, 140, 20),
	},

	-- ===== Zona 2: Greenhouse Valley =====
	Cactus = {
		id = "Cactus", displayName = "Cactus", zone = "GreenhouseValley", rarity = "Uncommon",
		seedPrice = 260, growTimeSeconds = 150, stageCount = 4,
		baseSellValue = 110, passiveIncomePerCycle = 7,
		color = Color3.fromRGB(60, 158, 90),
	},
	Blueberry = {
		id = "Blueberry", displayName = "Blueberry", zone = "GreenhouseValley", rarity = "Uncommon",
		seedPrice = 320, growTimeSeconds = 170, stageCount = 4,
		baseSellValue = 135, passiveIncomePerCycle = 8,
		color = Color3.fromRGB(70, 90, 200),
	},
	Grape = {
		id = "Grape", displayName = "Grape", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 480, growTimeSeconds = 220, stageCount = 5,
		baseSellValue = 210, passiveIncomePerCycle = 12,
		color = Color3.fromRGB(120, 60, 170),
	},
	Watermelon = {
		id = "Watermelon", displayName = "Watermelon", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 650, growTimeSeconds = 260, stageCount = 5,
		baseSellValue = 280, passiveIncomePerCycle = 15,
		color = Color3.fromRGB(45, 175, 90),
	},
	Pineapple = {
		id = "Pineapple", displayName = "Pineapple", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 800, growTimeSeconds = 300, stageCount = 5,
		baseSellValue = 340, passiveIncomePerCycle = 18,
		color = Color3.fromRGB(230, 200, 40),
	},
	Coconut = {
		id = "Coconut", displayName = "Coconut", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 950, growTimeSeconds = 330, stageCount = 5,
		baseSellValue = 390, passiveIncomePerCycle = 20,
		color = Color3.fromRGB(150, 110, 70),
	},
	Dragonfruit = {
		id = "Dragonfruit", displayName = "Dragonfruit", zone = "GreenhouseValley", rarity = "Epic",
		seedPrice = 1400, growTimeSeconds = 400, stageCount = 5,
		baseSellValue = 620, passiveIncomePerCycle = 30,
		color = Color3.fromRGB(230, 60, 140),
	},

	-- ===== Zona 3: Mystic Grove =====
	Starfruit = {
		id = "Starfruit", displayName = "Starfruit", zone = "MysticGrove", rarity = "Rare",
		seedPrice = 1800, growTimeSeconds = 360, stageCount = 5,
		baseSellValue = 700, passiveIncomePerCycle = 34,
		color = Color3.fromRGB(255, 230, 90),
	},
	EmberRose = {
		id = "EmberRose", displayName = "Ember Rose", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 2600, growTimeSeconds = 420, stageCount = 5,
		baseSellValue = 980, passiveIncomePerCycle = 45,
		color = Color3.fromRGB(255, 90, 60),
	},
	CrystalBerry = {
		id = "CrystalBerry", displayName = "Crystal Berry", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 3200, growTimeSeconds = 460, stageCount = 5,
		baseSellValue = 1150, passiveIncomePerCycle = 52,
		color = Color3.fromRGB(140, 220, 255),
	},
	Moonflower = {
		id = "Moonflower", displayName = "Moonflower", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 4000, growTimeSeconds = 500, stageCount = 5,
		baseSellValue = 1400, passiveIncomePerCycle = 60,
		color = Color3.fromRGB(200, 190, 255),
	},
	CelestialOrchid = {
		id = "CelestialOrchid", displayName = "Celestial Orchid", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 6500, growTimeSeconds = 600, stageCount = 6,
		baseSellValue = 2400, passiveIncomePerCycle = 95,
		color = Color3.fromRGB(255, 255, 255),
	},
	PhoenixBloom = {
		id = "PhoenixBloom", displayName = "Phoenix Bloom", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 9000, growTimeSeconds = 720, stageCount = 6,
		baseSellValue = 3200, passiveIncomePerCycle = 130,
		color = Color3.fromRGB(255, 140, 40),
	},
	CosmicPeony = {
		id = "CosmicPeony", displayName = "Cosmic Peony", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 25000, growTimeSeconds = 900, stageCount = 6,
		baseSellValue = 9500, passiveIncomePerCycle = 360,
		color = Color3.fromRGB(255, 91, 158),
	},
	AuroraLotus = {
		id = "AuroraLotus", displayName = "Aurora Lotus", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 80000, growTimeSeconds = 1200, stageCount = 6,
		baseSellValue = 30000, passiveIncomePerCycle = 1000,
		color = Color3.fromRGB(120, 225, 255),
	},

	-- ===== Expansión: +5 plantas por rareza =====
	Radish = {
		id = "Radish", displayName = "Radish", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 10, growTimeSeconds = 20, stageCount = 3,
		baseSellValue = 6, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(230, 70, 90),
	},
	Lettuce = {
		id = "Lettuce", displayName = "Lettuce", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 20, growTimeSeconds = 35, stageCount = 3,
		baseSellValue = 14, passiveIncomePerCycle = 1,
		color = Color3.fromRGB(120, 200, 90),
	},
	Onion = {
		id = "Onion", displayName = "Onion", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 35, growTimeSeconds = 50, stageCount = 3,
		baseSellValue = 22, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(235, 215, 170),
	},
	Cabbage = {
		id = "Cabbage", displayName = "Cabbage", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 55, growTimeSeconds = 80, stageCount = 4,
		baseSellValue = 34, passiveIncomePerCycle = 2,
		color = Color3.fromRGB(130, 200, 120),
	},
	Peas = {
		id = "Peas", displayName = "Peas", zone = "StarterMeadow", rarity = "Common",
		seedPrice = 70, growTimeSeconds = 90, stageCount = 4,
		baseSellValue = 40, passiveIncomePerCycle = 3,
		color = Color3.fromRGB(110, 190, 80),
	},
	Raspberry = {
		id = "Raspberry", displayName = "Raspberry", zone = "StarterMeadow", rarity = "Uncommon",
		seedPrice = 140, growTimeSeconds = 120, stageCount = 4,
		baseSellValue = 62, passiveIncomePerCycle = 5,
		color = Color3.fromRGB(215, 40, 90),
	},
	Eggplant = {
		id = "Eggplant", displayName = "Eggplant", zone = "StarterMeadow", rarity = "Uncommon",
		seedPrice = 210, growTimeSeconds = 170, stageCount = 4,
		baseSellValue = 105, passiveIncomePerCycle = 7,
		color = Color3.fromRGB(110, 60, 150),
	},
	Broccoli = {
		id = "Broccoli", displayName = "Broccoli", zone = "GreenhouseValley", rarity = "Uncommon",
		seedPrice = 290, growTimeSeconds = 160, stageCount = 4,
		baseSellValue = 120, passiveIncomePerCycle = 8,
		color = Color3.fromRGB(70, 160, 70),
	},
	Lemon = {
		id = "Lemon", displayName = "Lemon", zone = "GreenhouseValley", rarity = "Uncommon",
		seedPrice = 350, growTimeSeconds = 180, stageCount = 4,
		baseSellValue = 145, passiveIncomePerCycle = 9,
		color = Color3.fromRGB(250, 225, 70),
	},
	BellPepper = {
		id = "BellPepper", displayName = "Bell Pepper", zone = "GreenhouseValley", rarity = "Uncommon",
		seedPrice = 420, growTimeSeconds = 200, stageCount = 4,
		baseSellValue = 170, passiveIncomePerCycle = 10,
		color = Color3.fromRGB(230, 60, 50),
	},
	Cherry = {
		id = "Cherry", displayName = "Cherry", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 560, growTimeSeconds = 230, stageCount = 5,
		baseSellValue = 240, passiveIncomePerCycle = 13,
		color = Color3.fromRGB(200, 30, 70),
	},
	Peach = {
		id = "Peach", displayName = "Peach", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 720, growTimeSeconds = 280, stageCount = 5,
		baseSellValue = 310, passiveIncomePerCycle = 16,
		color = Color3.fromRGB(255, 170, 120),
	},
	Lavender = {
		id = "Lavender", displayName = "Lavender", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 880, growTimeSeconds = 310, stageCount = 5,
		baseSellValue = 370, passiveIncomePerCycle = 19,
		color = Color3.fromRGB(170, 130, 230),
	},
	Mango = {
		id = "Mango", displayName = "Mango", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 1050, growTimeSeconds = 340, stageCount = 5,
		baseSellValue = 430, passiveIncomePerCycle = 22,
		color = Color3.fromRGB(255, 170, 50),
	},
	Banana = {
		id = "Banana", displayName = "Banana", zone = "GreenhouseValley", rarity = "Rare",
		seedPrice = 1200, growTimeSeconds = 360, stageCount = 5,
		baseSellValue = 480, passiveIncomePerCycle = 25,
		color = Color3.fromRGB(255, 225, 80),
	},
	GlowShroom = {
		id = "GlowShroom", displayName = "Glow Shroom", zone = "GreenhouseValley", rarity = "Epic",
		seedPrice = 1700, growTimeSeconds = 410, stageCount = 5,
		baseSellValue = 700, passiveIncomePerCycle = 33,
		color = Color3.fromRGB(90, 230, 200),
	},
	FrostLily = {
		id = "FrostLily", displayName = "Frost Lily", zone = "GreenhouseValley", rarity = "Epic",
		seedPrice = 2100, growTimeSeconds = 440, stageCount = 5,
		baseSellValue = 820, passiveIncomePerCycle = 38,
		color = Color3.fromRGB(170, 230, 255),
	},
	GiantMushroom = {
		id = "GiantMushroom", displayName = "Giant Mushroom", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 3600, growTimeSeconds = 480, stageCount = 5,
		baseSellValue = 1250, passiveIncomePerCycle = 56,
		color = Color3.fromRGB(220, 70, 70),
	},
	MagicTree = {
		id = "MagicTree", displayName = "Magic Tree", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 4600, growTimeSeconds = 520, stageCount = 5,
		baseSellValue = 1600, passiveIncomePerCycle = 68,
		color = Color3.fromRGB(150, 100, 230),
	},
	ThunderBloom = {
		id = "ThunderBloom", displayName = "Thunder Bloom", zone = "MysticGrove", rarity = "Epic",
		seedPrice = 5200, growTimeSeconds = 540, stageCount = 5,
		baseSellValue = 1850, passiveIncomePerCycle = 78,
		color = Color3.fromRGB(255, 225, 90),
	},
	AmberVine = {
		id = "AmberVine", displayName = "Amber Vine", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 7500, growTimeSeconds = 640, stageCount = 6,
		baseSellValue = 2700, passiveIncomePerCycle = 110,
		color = Color3.fromRGB(255, 170, 40),
	},
	SolarSunflower = {
		id = "SolarSunflower", displayName = "Solar Sunflower", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 10500, growTimeSeconds = 750, stageCount = 6,
		baseSellValue = 3700, passiveIncomePerCycle = 150,
		color = Color3.fromRGB(255, 190, 30),
	},
	GoldenApple = {
		id = "GoldenApple", displayName = "Golden Apple", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 12000, growTimeSeconds = 780, stageCount = 6,
		baseSellValue = 4200, passiveIncomePerCycle = 170,
		color = Color3.fromRGB(255, 210, 70),
	},
	MoltenLily = {
		id = "MoltenLily", displayName = "Molten Lily", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 14000, growTimeSeconds = 820, stageCount = 6,
		baseSellValue = 4800, passiveIncomePerCycle = 195,
		color = Color3.fromRGB(255, 100, 40),
	},
	AncientTree = {
		id = "AncientTree", displayName = "Ancient Tree", zone = "MysticGrove", rarity = "Legendary",
		seedPrice = 17000, growTimeSeconds = 880, stageCount = 6,
		baseSellValue = 5800, passiveIncomePerCycle = 230,
		color = Color3.fromRGB(110, 170, 90),
	},
	StarBlossom = {
		id = "StarBlossom", displayName = "Star Blossom", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 30000, growTimeSeconds = 950, stageCount = 6,
		baseSellValue = 11000, passiveIncomePerCycle = 400,
		color = Color3.fromRGB(255, 230, 120),
	},
	ObsidianRose = {
		id = "ObsidianRose", displayName = "Obsidian Rose", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 36000, growTimeSeconds = 1000, stageCount = 6,
		baseSellValue = 13500, passiveIncomePerCycle = 480,
		color = Color3.fromRGB(70, 50, 90),
	},
	DreamWillow = {
		id = "DreamWillow", displayName = "Dream Willow", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 44000, growTimeSeconds = 1050, stageCount = 6,
		baseSellValue = 16500, passiveIncomePerCycle = 570,
		color = Color3.fromRGB(190, 150, 255),
	},
	PhoenixTree = {
		id = "PhoenixTree", displayName = "Phoenix Tree", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 55000, growTimeSeconds = 1100, stageCount = 6,
		baseSellValue = 20500, passiveIncomePerCycle = 680,
		color = Color3.fromRGB(255, 110, 50),
	},
	VoidPlant = {
		id = "VoidPlant", displayName = "Void Plant", zone = "MysticGrove", rarity = "Mythic",
		seedPrice = 68000, growTimeSeconds = 1150, stageCount = 6,
		baseSellValue = 25000, passiveIncomePerCycle = 800,
		color = Color3.fromRGB(110, 60, 190),
	},
	MoonLotus = {
		id = "MoonLotus", displayName = "Moon Lotus", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 110000, growTimeSeconds = 1300, stageCount = 6,
		baseSellValue = 41000, passiveIncomePerCycle = 1350,
		color = Color3.fromRGB(220, 230, 255),
	},
	HeavenSeed = {
		id = "HeavenSeed", displayName = "Heaven Seed", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 150000, growTimeSeconds = 1400, stageCount = 6,
		baseSellValue = 56000, passiveIncomePerCycle = 1800,
		color = Color3.fromRGB(255, 245, 200),
	},
	BlackLotus = {
		id = "BlackLotus", displayName = "Black Lotus", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 200000, growTimeSeconds = 1500, stageCount = 6,
		baseSellValue = 75000, passiveIncomePerCycle = 2400,
		color = Color3.fromRGB(60, 40, 80),
	},
	WorldTree = {
		id = "WorldTree", displayName = "World Tree", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 280000, growTimeSeconds = 1650, stageCount = 6,
		baseSellValue = 105000, passiveIncomePerCycle = 3300,
		color = Color3.fromRGB(90, 220, 150),
	},
	GlitchPlant = {
		id = "GlitchPlant", displayName = "Glitch Plant", zone = "MysticGrove", rarity = "Celestial",
		seedPrice = 400000, growTimeSeconds = 1800, stageCount = 6,
		baseSellValue = 150000, passiveIncomePerCycle = 4700,
		color = Color3.fromRGB(0, 255, 220),
	},
}

-- Lista ordenada por zona, útil para poblar la Seed Shop en el orden correcto
PlantConfig.OrderByZone = {
	StarterMeadow = { "Carrot", "Radish", "Potato", "Lettuce", "Tomato", "Onion", "Corn", "Cabbage", "Peas", "Sunflower", "Strawberry", "Raspberry", "Pumpkin", "Eggplant" },
	GreenhouseValley = { "Cactus", "Broccoli", "Blueberry", "Lemon", "BellPepper", "Grape", "Cherry", "Watermelon", "Peach", "Pineapple", "Lavender", "Coconut", "Mango", "Banana", "Dragonfruit", "GlowShroom", "FrostLily" },
	MysticGrove = { "Starfruit", "EmberRose", "CrystalBerry", "GiantMushroom", "Moonflower", "MagicTree", "ThunderBloom", "CelestialOrchid", "AmberVine", "PhoenixBloom", "SolarSunflower", "GoldenApple", "MoltenLily", "AncientTree", "CosmicPeony", "StarBlossom", "ObsidianRose", "DreamWillow", "PhoenixTree", "VoidPlant", "AuroraLotus", "MoonLotus", "HeavenSeed", "BlackLotus", "WorldTree", "GlitchPlant" },
} :: any

function PlantConfig.GetCatalog(): { [number]: any }
	local catalog = {}
	for _, zoneId in ipairs({ "StarterMeadow", "GreenhouseValley", "MysticGrove" }) do
		for _, plantId in ipairs(PlantConfig.OrderByZone[zoneId] or {}) do
			local plant = PlantConfig[plantId]
			if plant then
				table.insert(catalog, {
					id = plant.id,
					displayName = plant.displayName,
					zone = plant.zone,
					rarity = plant.rarity,
					seedPrice = plant.seedPrice,
					growTimeSeconds = plant.growTimeSeconds,
					baseSellValue = plant.baseSellValue,
					passiveIncomePerCycle = plant.passiveIncomePerCycle,
					color = plant.color,
				})
			end
		end
	end
	return catalog
end

return PlantConfig
