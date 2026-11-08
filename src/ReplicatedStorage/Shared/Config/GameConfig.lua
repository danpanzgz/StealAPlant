--!strict
--[[
	GameConfig.lua
	Ajustes globales del juego. Cambiar valores aquí afecta a todo el juego
	sin tocar lógica. Todo lo que sea "balance" vive en /Config.
]]

local GameConfig = {}

GameConfig.CurrencyName = "Cash"

-- Cambia esto en cada entrega: se ve en pantalla (esquina) para saber qué
-- versión está corriendo realmente en tu Studio.
GameConfig.Version = "v0.6 · efectos+colocar"

-- Ritmo de crecimiento / ticks del servidor
GameConfig.GrowthTickInterval = 1 -- segundos entre chequeos de crecimiento de planta
GameConfig.IncomeTickInterval = 60 -- segundos entre pagos de flores colocadas

-- Autosave / DataStore
GameConfig.AutosaveInterval = 120 -- segundos
GameConfig.DataStoreName = "StealAPlant_PlayerData_v1"
GameConfig.MaxSaveRetries = 5
GameConfig.SaveRetryBackoff = 2 -- segundos, se multiplica exponencialmente

-- Robo
GameConfig.StealCooldown = 45 -- segundos entre intentos de robo por jugador
GameConfig.StealRange = 14 -- studs, distancia máxima al jardín objetivo
GameConfig.StealDuration = 4 -- segundos que tarda la animación/interacción de robo
GameConfig.StealBaseSuccessChance = 0.55 -- probabilidad base, modificada por defensas
GameConfig.StealAlarmDuration = 6 -- segundos que dura la alarma visual/sonora en el jardín robado
GameConfig.StealLockoutAfterCaught = 8 -- segundos de "teletransporte corto" fuera del jardín si te atrapan

-- Defensa
GameConfig.MaxDefensesPerGarden = 3

-- Jardines
GameConfig.DefaultPlotsUnlocked = 4

-- Rebirth / reinicio de progreso
GameConfig.RebirthBaseCost = 25000
GameConfig.RebirthCostMultiplier = 1.8
GameConfig.RebirthCashBonus = 0.2
GameConfig.MaxOfflineEarningsMinutes = 180
GameConfig.MaxOfflineEarningsCash = 100000
GameConfig.OfflineEarningsPerMinute = 3

-- Recompensa diaria
GameConfig.DailyRewardResetHours = 24

-- Quests
GameConfig.MaxActiveQuests = 3
GameConfig.QuestRefreshHours = 24

-- Primeros minutos (onboarding)
GameConfig.StarterSeedId = "Carrot"
GameConfig.StarterCash = 50

return GameConfig
