--!strict

local PetConfig = {
	StarterPetId = "MeadowCube",
	Pets = {} :: { [string]: any },
	PetsByRarity = {} :: { [string]: { string } },
}

type PetDefinition = { any }

local definitions: { [string]: { PetDefinition } } = {
	Common = {
		{ "MeadowCube", "Brotes", Color3.fromRGB(119, 205, 91), Color3.fromRGB(247, 214, 96), "leaf" },
		{ "BerryCube", "Mora", Color3.fromRGB(178, 93, 177), Color3.fromRGB(255, 151, 196), "ears" },
		{ "PebblePup", "Cachorro Guijarro", Color3.fromRGB(149, 157, 167), Color3.fromRGB(211, 221, 225), "tail" },
		{ "CloudCub", "Osito Nube", Color3.fromRGB(222, 235, 246), Color3.fromRGB(126, 197, 243), "ears" },
		{ "SproutFrog", "Rana Brote", Color3.fromRGB(96, 193, 139), Color3.fromRGB(247, 226, 105), "leaf" },
	},
	Uncommon = {
		{ "MossBunny", "Conejo Musgo", Color3.fromRGB(120, 173, 95), Color3.fromRGB(194, 225, 141), "longEars" },
		{ "HoneyBear", "Oso Miel", Color3.fromRGB(205, 147, 67), Color3.fromRGB(255, 215, 111), "roundEars" },
		{ "MintFox", "Zorro Menta", Color3.fromRGB(88, 194, 161), Color3.fromRGB(202, 255, 208), "tail" },
		{ "PondDuck", "Patito de Charca", Color3.fromRGB(248, 218, 91), Color3.fromRGB(255, 151, 66), "beak" },
		{ "AcornSquirrel", "Ardilla Bellota", Color3.fromRGB(190, 119, 76), Color3.fromRGB(238, 181, 111), "tail" },
	},
	Rare = {
		{ "CrystalFox", "Zorro Cristal", Color3.fromRGB(90, 182, 232), Color3.fromRGB(205, 249, 255), "crystal" },
		{ "MoonOwl", "Buhito Lunar", Color3.fromRGB(119, 119, 201), Color3.fromRGB(237, 228, 181), "wings" },
		{ "RiverOtter", "Nutria de Rio", Color3.fromRGB(153, 113, 83), Color3.fromRGB(120, 214, 225), "tail" },
		{ "BloomDeer", "Ciervo Flor", Color3.fromRGB(192, 154, 111), Color3.fromRGB(255, 160, 192), "antlers" },
		{ "StormPup", "Cachorro Tormenta", Color3.fromRGB(94, 117, 153), Color3.fromRGB(113, 207, 255), "spikes" },
	},
	Epic = {
		{ "StarDragon", "Dragon Estelar", Color3.fromRGB(116, 87, 190), Color3.fromRGB(255, 206, 86), "wings" },
		{ "PrismAxolotl", "Ajolote Prisma", Color3.fromRGB(235, 139, 179), Color3.fromRGB(117, 224, 238), "gills" },
		{ "EmberTiger", "Tigre Brasa", Color3.fromRGB(239, 124, 56), Color3.fromRGB(255, 219, 97), "stripes" },
		{ "FrostWolf", "Lobo Escarcha", Color3.fromRGB(149, 206, 237), Color3.fromRGB(241, 252, 255), "spikes" },
		{ "TwilightBat", "Murcielago Crepusculo", Color3.fromRGB(91, 73, 139), Color3.fromRGB(213, 144, 255), "wings" },
	},
	Legendary = {
		{ "SunPhoenix", "Fenix Solar", Color3.fromRGB(255, 128, 51), Color3.fromRGB(255, 231, 100), "wings" },
		{ "RoyalLion", "Leon Real", Color3.fromRGB(236, 174, 65), Color3.fromRGB(255, 226, 128), "mane" },
		{ "AuroraUnicorn", "Unicornio Aurora", Color3.fromRGB(192, 142, 239), Color3.fromRGB(111, 235, 221), "horn" },
		{ "ThunderGriffin", "Grifo Trueno", Color3.fromRGB(120, 139, 213), Color3.fromRGB(255, 220, 92), "wings" },
		{ "GalaxyWhale", "Ballena Galaxia", Color3.fromRGB(66, 137, 199), Color3.fromRGB(185, 140, 255), "fins" },
	},
	Mythic = {
		{ "VoidSerpent", "Serpiente del Vacio", Color3.fromRGB(71, 48, 113), Color3.fromRGB(236, 97, 197), "spikes" },
		{ "CosmicDragon", "Dragon Cosmico", Color3.fromRGB(75, 93, 177), Color3.fromRGB(104, 239, 243), "wings" },
		{ "DreamKirin", "Kirin de los Suenos", Color3.fromRGB(203, 111, 172), Color3.fromRGB(255, 221, 137), "horn" },
		{ "EclipseRaven", "Cuervo Eclipse", Color3.fromRGB(56, 61, 93), Color3.fromRGB(177, 137, 255), "wings" },
		{ "NebulaCat", "Gato Nebulosa", Color3.fromRGB(101, 80, 161), Color3.fromRGB(255, 134, 212), "ears" },
	},
	Celestial = {
		{ "CelestialGuardian", "Guardian Celestial", Color3.fromRGB(114, 195, 220), Color3.fromRGB(255, 244, 181), "crown" },
		{ "SolarFox", "Zorro Solar", Color3.fromRGB(255, 177, 66), Color3.fromRGB(255, 245, 139), "tail" },
		{ "LunarStag", "Ciervo Lunar", Color3.fromRGB(144, 164, 220), Color3.fromRGB(232, 241, 255), "antlers" },
		{ "AstralDragon", "Dragon Astral", Color3.fromRGB(111, 104, 222), Color3.fromRGB(255, 172, 224), "wings" },
		{ "InfinityTurtle", "Tortuga Infinita", Color3.fromRGB(89, 190, 156), Color3.fromRGB(140, 237, 228), "shell" },
	},
}

for rarity, entries in pairs(definitions) do
	local rarityPets = {}
	for _, entry in ipairs(entries) do
		local petId, displayName, color, accentColor, feature = entry[1], entry[2], entry[3], entry[4], entry[5]
		PetConfig.Pets[petId] = {
			displayName = displayName,
			rarity = rarity,
			color = color,
			accentColor = accentColor,
			feature = feature,
		}
		table.insert(rarityPets, petId)
	end
	PetConfig.PetsByRarity[rarity] = rarityPets
end

-- Qué animal es cada mascota (para la animación al abrir el huevo).
local animals: { [string]: { string } } = {
	MeadowCube = { "🌱", "Brote vivo" }, BerryCube = { "🫐", "Mora saltarina" },
	PebblePup = { "🐶", "Perrito" }, CloudCub = { "🐻‍❄️", "Osito" }, SproutFrog = { "🐸", "Rana" },
	MossBunny = { "🐰", "Conejo" }, HoneyBear = { "🐻", "Oso" }, MintFox = { "🦊", "Zorro" },
	PondDuck = { "🦆", "Pato" }, AcornSquirrel = { "🐿️", "Ardilla" },
	CrystalFox = { "🦊", "Zorro de cristal" }, MoonOwl = { "🦉", "Búho" }, RiverOtter = { "🦦", "Nutria" },
	BloomDeer = { "🦌", "Ciervo" }, StormPup = { "🐺", "Cachorro de tormenta" },
	StarDragon = { "🐲", "Dragón" }, PrismAxolotl = { "🦎", "Ajolote" }, EmberTiger = { "🐯", "Tigre" },
	FrostWolf = { "🐺", "Lobo" }, TwilightBat = { "🦇", "Murciélago" },
	SunPhoenix = { "🔥", "Fénix" }, RoyalLion = { "🦁", "León" }, AuroraUnicorn = { "🦄", "Unicornio" },
	ThunderGriffin = { "🦅", "Grifo" }, GalaxyWhale = { "🐋", "Ballena" },
	VoidSerpent = { "🐍", "Serpiente" }, CosmicDragon = { "🐉", "Dragón cósmico" }, DreamKirin = { "🦌", "Kirin" },
	EclipseRaven = { "🐦‍⬛", "Cuervo" }, NebulaCat = { "🐱", "Gato" },
	CelestialGuardian = { "👼", "Guardián" }, SolarFox = { "🦊", "Zorro solar" }, LunarStag = { "🦌", "Ciervo lunar" },
	AstralDragon = { "🐲", "Dragón astral" }, InfinityTurtle = { "🐢", "Tortuga" },
}

-- Devuelve (emoji, nombre del animal) de una mascota.
function PetConfig.GetAnimal(petId: string?): (string, string)
	local entry = if petId then animals[petId] else nil
	if entry then
		return entry[1], entry[2]
	end
	return "🐾", "Mascota"
end

-- Bonus de la mascota EQUIPADA según su rareza (fracciones: 0.25 = +25%).
--   cash   : ingresos por minuto, ventas y ganancias offline
--   growth : velocidad de crecimiento de lo que plantes
--   luck   : probabilidad de mutación
PetConfig.Bonuses = {
	Common = { cash = 0.05, growth = 0, luck = 0 },
	Uncommon = { cash = 0.10, growth = 0.05, luck = 0 },
	Rare = { cash = 0.15, growth = 0.10, luck = 0.10 },
	Epic = { cash = 0.25, growth = 0.15, luck = 0.20 },
	Legendary = { cash = 0.40, growth = 0.25, luck = 0.35 },
	Mythic = { cash = 0.60, growth = 0.40, luck = 0.60 },
	Celestial = { cash = 1.00, growth = 0.60, luck = 1.00 },
} :: { [string]: { cash: number, growth: number, luck: number } }

local ZERO_BONUS = { cash = 0, growth = 0, luck = 0 }

function PetConfig.GetBonuses(petId: string?): { cash: number, growth: number, luck: number }
	local pet = if petId then PetConfig.Pets[petId] else nil
	if not pet then
		return ZERO_BONUS
	end
	return PetConfig.Bonuses[pet.rarity] or ZERO_BONUS
end

-- Texto corto para la interfaz: "+25% Cash · +15% Crecimiento · +20% Suerte".
function PetConfig.Describe(petId: string?): string
	local bonuses = PetConfig.GetBonuses(petId)
	local parts = {}
	if bonuses.cash > 0 then
		table.insert(parts, string.format("+%d%% Cash", math.floor(bonuses.cash * 100 + 0.5)))
	end
	if bonuses.growth > 0 then
		table.insert(parts, string.format("+%d%% Crecimiento", math.floor(bonuses.growth * 100 + 0.5)))
	end
	if bonuses.luck > 0 then
		table.insert(parts, string.format("+%d%% Suerte", math.floor(bonuses.luck * 100 + 0.5)))
	end
	return table.concat(parts, " · ")
end

return PetConfig
