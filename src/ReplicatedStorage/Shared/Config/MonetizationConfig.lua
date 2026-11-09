--!strict
--[[
	MonetizationConfig.lua
	Game Passes (ventajas permanentes) y Developer Products (compras
	repetibles). IMPORTANTE: los id = 0 son PLACEHOLDERS. Crea los pases y
	productos en el Creator Hub (Monetization) y pega aquí sus IDs reales.
	Mientras id = 0, el botón de la tienda avisa de que falta configurar.

	Principios (lo que funciona en Grow a Garden / Steal a Brainrot y similares):
	  - Ofertas de bienvenida de UNA sola compra con mucho valor aparente.
	  - Boosts temporales baratos (impulso compulsivo, repetible).
	  - Paquetes de semillas/huevos para saltarse espera, no para ganar solo.
	  - Pases permanentes de comodidad (slots, velocidad, VIP).
	  - Nada bloquea el progreso gratuito (regla de diseño 5 y 6).
	Los precios son puntos de partida: ajústalos con los datos reales.

	Tipos de producto (`kind`):
	  cash        -> `cash`
	  boost       -> `boosts = { cash = seg, growth = seg, luck = seg }`
	  instantGrow -> madura al instante todas tus plantas en crecimiento
	  shield      -> `seconds` de escudo de jardín
	  bundle      -> `grants = { cash, seedPacks, petEggs, gear, boosts }`
	`oneTime = true` -> solo se ofrece una vez por jugador.
]]

local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	DoubleCash = {
		id = 0, displayName = "x2 Cash", robux = 79,
		description = "Duplica los ingresos del jardín y el dinero por vender flores.",
		cashMultiplier = 2,
	},
	LuckyMutation = {
		id = 0, displayName = "Lucky Mutation", robux = 199,
		description = "Más probabilidad de efectos y mutaciones (x1.5).",
		mutationMultiplier = 1.5,
	},
	GreenThumb = {
		id = 0, displayName = "Pulgar verde", robux = 99,
		description = "Los cultivos que plantes crecen un 25% más rápido.",
		growthMultiplier = 1.25,
	},
	OfflineFarmer = {
		id = 0, displayName = "Granjero incansable", robux = 149,
		description = "Amplía a 6 horas el tiempo de ingresos offline y los aumenta un 25%.",
		offlineMinutes = 360,
		offlineCashMultiplier = 1.25,
	},
	ExtraSpeed = {
		id = 0, displayName = "Velocidad extra", robux = 149,
		description = "Corres un 25% más rápido: llegas antes a la tienda y a tu base.",
		speedMultiplier = 1.25,
	},
	ShieldMaster = {
		id = 0, displayName = "Maestro del escudo", robux = 249,
		description = "El domo de tu jardín dura un 50% más (45 s → 68 s).",
		domeMultiplier = 1.5,
	},
	SeasonPass = {
		id = 0, displayName = "🏆 Pase de Temporada", robux = 449,
		description = "Desbloquea la pista premium: 30 niveles de packs, huevos, tótems, boosts y Cash extra. Cada temporada dura 30 días.",
	},
	VIP = {
		id = 0, displayName = "VIP", robux = 299,
		description = "+15% Cash, un pack Rare gratis cada día al reclamar la recompensa y etiqueta VIP.",
		cashMultiplier = 1.15,
		dailyPackId = "Rare",
	},
} :: { [string]: any }

MonetizationConfig.PassOrder = {
	"SeasonPass", "DoubleCash", "VIP", "GreenThumb", "OfflineFarmer", "LuckyMutation", "ExtraSpeed", "ShieldMaster",
}

-- Multiplicadores de los boosts temporales.
MonetizationConfig.BoostMultipliers = { cash = 2, growth = 2, luck = 2 }
MonetizationConfig.BoostNames = { cash = "x2 Cash", growth = "x2 Crecimiento", luck = "x2 Suerte" }

MonetizationConfig.DevProducts = {
	-- ===== Ofertas de bienvenida (una vez por jugador) =====
	StarterPack = {
		id = 0, kind = "bundle", oneTime = true, robux = 149, badge = "-70%",
		displayName = "🎁 Starter Pack",
		description = "25.000 Cash · 3 packs Rare · 1 pack Epic · 1 huevo Rare · 5 regaderas · 30 min x2 Cash",
		valueNote = "Valor 499 R$",
		grants = {
			cash = 25000,
			seedPacks = { Rare = 3, Epic = 1 },
			petEggs = { Rare = 1 },
			gear = { WaterCan = 5 },
			boosts = { cash = 1800 },
		},
	},
	ProPack = {
		id = 0, kind = "bundle", oneTime = true, robux = 399, badge = "-75%",
		displayName = "👑 Pro Pack",
		description = "150.000 Cash · 3 packs Epic · 1 Legendary · 2 huevos Epic · 2 tótems · 1 h x2 Cash y Suerte",
		valueNote = "Valor 1.599 R$",
		grants = {
			cash = 150000,
			seedPacks = { Epic = 3, Legendary = 1 },
			petEggs = { Epic = 2 },
			gear = { MutationTotem = 1, SizeTotem = 1 },
			boosts = { cash = 3600, luck = 3600 },
		},
	},

	-- ===== Boosts temporales =====
	BoostCash = {
		id = 0, kind = "boost", robux = 19, displayName = "⚡ x2 Cash (10 min)",
		description = "Duplica tus ingresos durante 10 minutos (se acumula).",
		boosts = { cash = 600 },
	},
	BoostGrowth = {
		id = 0, kind = "boost", robux = 19, displayName = "🌱 x2 Crecimiento (10 min)",
		description = "Todas tus plantas crecen al doble durante 10 minutos.",
		boosts = { growth = 600 },
	},
	BoostLuck = {
		id = 0, kind = "boost", robux = 49, displayName = "🍀 x2 Suerte (10 min)",
		description = "Doble probabilidad de efectos y mutaciones durante 10 minutos.",
		boosts = { luck = 600 },
	},
	BoostAll = {
		id = 0, kind = "boost", robux = 99, badge = "MEJOR", displayName = "🚀 Super Boost (30 min)",
		description = "x2 Cash + x2 Crecimiento + x2 Suerte durante 30 minutos.",
		boosts = { cash = 1800, growth = 1800, luck = 1800 },
	},

	-- ===== Utilidades =====
	InstantGrow = {
		id = 0, kind = "instantGrow", robux = 29, displayName = "⏩ Crecimiento instantáneo",
		description = "Todas tus plantas en crecimiento maduran ahora mismo.",
	},
	ShieldHour = {
		id = 0, kind = "shield", seconds = 1800, robux = 39, displayName = "🛡️ Escudo 30 min",
		description = "Tu jardín queda protegido de robos durante 30 minutos.",
	},

	-- ===== Paquetes =====
	EpicBundle = {
		id = 0, kind = "bundle", robux = 79, displayName = "📦 Pack Epic x3",
		description = "3 packs de semillas Epic para ir directo a lo bueno.",
		grants = { seedPacks = { Epic = 3 } },
	},
	EggBundle = {
		id = 0, kind = "bundle", robux = 59, displayName = "🥚 Huevos Rare x3",
		description = "3 huevos Rare para tu colección de mascotas (necesitas el incubador).",
		grants = { petEggs = { Rare = 3 } },
	},
	LegendaryBundle = {
		id = 0, kind = "bundle", robux = 199, displayName = "🌟 Pack Legendary x2",
		description = "2 packs de semillas Legendary.",
		grants = { seedPacks = { Legendary = 2 } },
	},

	-- ===== Pase de Temporada =====
	SeasonSkip = {
		id = 0, kind = "seasonLevels", levels = 1, robux = 39, displayName = "🏆 +1 nivel de temporada",
		description = "Sube un nivel del Pase de Temporada al instante.",
	},
	SeasonSkip5 = {
		id = 0, kind = "seasonLevels", levels = 5, robux = 149, badge = "-25%", displayName = "🏆 +5 niveles de temporada",
		description = "Sube cinco niveles del Pase de Temporada al instante.",
	},

	-- ===== Cash =====
	CashSmall = { id = 0, kind = "cash", displayName = "💰 Small Cash Pack", robux = 19, cash = 10000 },
	CashMedium = { id = 0, kind = "cash", displayName = "💰 Medium Cash Pack", robux = 49, cash = 60000 },
	CashLarge = { id = 0, kind = "cash", displayName = "💰 Large Cash Pack", robux = 149, cash = 250000 },
	CashHuge = { id = 0, kind = "cash", displayName = "💰 Huge Cash Pack", robux = 399, cash = 1000000, badge = "x2 valor" },
} :: { [string]: any }

-- Secciones de la tienda (orden y títulos).
MonetizationConfig.Sections = {
	{ title = "🎁 Ofertas de bienvenida (una sola vez)", products = { "StarterPack", "ProPack" } },
	{ title = "⚡ Boosts", products = { "BoostAll", "BoostCash", "BoostGrowth", "BoostLuck" } },
	{ title = "🛠️ Utilidades", products = { "InstantGrow", "ShieldHour" } },
	{ title = "📦 Paquetes", products = { "EpicBundle", "EggBundle", "LegendaryBundle" } },
	{ title = "🏆 Pase de Temporada", products = { "SeasonSkip", "SeasonSkip5" } },
	{ title = "💰 Cash", products = { "CashSmall", "CashMedium", "CashLarge", "CashHuge" } },
} :: { { title: string, products: { string } } }

-- Lista plana (para registrar los productos en el servidor).
local order: { string } = {}
for _, section in ipairs(MonetizationConfig.Sections) do
	for _, key in ipairs(section.products) do
		table.insert(order, key)
	end
end
MonetizationConfig.ProductOrder = order

return MonetizationConfig
