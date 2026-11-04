--!strict
--[[
	QuestConfig.lua
	Pool de misiones. Cada jugador recibe GameConfig.MaxActiveQuests al azar
	y se renuevan cada GameConfig.QuestRefreshHours.
	kind: plant | harvest | buy_seed | steal | defend | earn_cash | place_defense
]]

export type QuestData = {
	id: string,
	description: string,
	kind: string,
	target: number,
	rewardCash: number,
}

local QuestConfig = {}

QuestConfig.Pool = {
	{ id = "plant3", description = "Planta 3 semillas", kind = "plant", target = 3, rewardCash = 60 },
	{ id = "harvest3", description = "Cosecha 3 plantas", kind = "harvest", target = 3, rewardCash = 100 },
	{ id = "buy2", description = "Compra 2 semillas", kind = "buy_seed", target = 2, rewardCash = 80 },
	{ id = "steal1", description = "Roba 1 planta", kind = "steal", target = 1, rewardCash = 200 },
	{ id = "earn300", description = "Gana 300 Cash cosechando", kind = "earn_cash", target = 300, rewardCash = 150 },
	{ id = "defense1", description = "Coloca 1 defensa", kind = "place_defense", target = 1, rewardCash = 120 },
	{ id = "defend1", description = "Defiende tu jardín 1 vez", kind = "defend", target = 1, rewardCash = 250 },
} :: { QuestData }

return QuestConfig
