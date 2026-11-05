--!strict
--[[
	MonetizationConfig.lua
	Game Passes (ventajas permanentes) y Developer Products (compras
	repetibles). IMPORTANTE: los id = 0 son PLACEHOLDERS. Crea los pases y
	productos en el Creator Hub (Monetization) y pega aquí sus IDs reales.
	Mientras id = 0, el botón de la tienda avisa de que falta configurar.
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
		description = "Más probabilidad de mutaciones (x1.5).",
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
} :: { [string]: any }

MonetizationConfig.PassOrder = { "DoubleCash", "LuckyMutation", "GreenThumb", "OfflineFarmer" }

MonetizationConfig.DevProducts = {
	CashSmall = { id = 0, displayName = "Small Cash Pack", robux = 19, cash = 2500 },
	CashMedium = { id = 0, displayName = "Medium Cash Pack", robux = 49, cash = 10000 },
	CashLarge = { id = 0, displayName = "Large Cash Pack", robux = 149, cash = 50000 },
} :: { [string]: any }

MonetizationConfig.ProductOrder = { "CashSmall", "CashMedium", "CashLarge" }

return MonetizationConfig
