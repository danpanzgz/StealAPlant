--!strict
--[[
	SeasonConfig.lua
	Pase de Temporada: 30 niveles, pista gratis + pista premium (Game Pass
	"SeasonPass"). La temporada dura 30 días y se calcula con os.time() en el
	servidor, así que no hace falta actualizar nada a mano: al cambiar de
	temporada el progreso se reinicia (lo ya reclamado se conserva en el
	inventario del jugador).

	El XP viene de jugar: plantar, cosechar, robar, defender, misiones,
	recompensa diaria y abrir huevos. Nada se bloquea tras el pago: el pase
	solo añade una segunda pista de premios.

	Premios: { cash = n, seedPacks = {id=n}, petEggs = {rarity=n},
	           gear = {id=n}, boosts = {cash|growth|luck = segundos} }
]]

local SeasonConfig = {}

SeasonConfig.Name = "Temporada del Jardín Salvaje"
SeasonConfig.DurationDays = 30
-- Lunes 1 de enero de 2024 00:00 UTC: inicio de la temporada 1 (rejilla fija).
SeasonConfig.EpochUnix = 1704067200
SeasonConfig.MaxLevel = 30

-- XP necesario para pasar del nivel L al L+1.
function SeasonConfig.XpForLevel(level: number): number
	return 200 + 40 * (level - 1)
end

-- XP por acción (QuestService.Report usa estas claves).
SeasonConfig.XpPerAction = {
	plant = 4,
	harvest = 12,
	steal = 50,
	defend = 40,
	place_defense = 10,
}
SeasonConfig.XpQuestClaim = 60
SeasonConfig.XpDailyClaim = 40
SeasonConfig.XpPetHatch = 30

-- ===== Tabla de premios =====
local free: { [number]: any } = {}
local premium: { [number]: any } = {}

for level = 1, SeasonConfig.MaxLevel do
	-- Base: cada nivel da algo en ambas pistas.
	free[level] = { cash = 400 + level * 250 }
	premium[level] = { cash = 1500 + level * 900 }
end

-- Hitos de la pista gratis.
free[3] = { seedPacks = { Common = 2 } }
free[5] = { petEggs = { Common = 1 }, cash = 2500 }
free[8] = { gear = { WaterCan = 3 } }
free[10] = { seedPacks = { Rare = 1 }, boosts = { cash = 600 } }
free[13] = { boosts = { growth = 600 } }
free[15] = { petEggs = { Rare = 1 }, cash = 12000 }
free[18] = { seedPacks = { Rare = 1 } }
free[20] = { seedPacks = { Epic = 1 }, boosts = { luck = 600 } }
free[24] = { gear = { WaterCan = 5 }, cash = 25000 }
free[27] = { petEggs = { Rare = 1 } }
free[30] = { seedPacks = { Epic = 2 }, petEggs = { Epic = 1 }, cash = 80000 }

-- Hitos de la pista premium.
premium[1] = { seedPacks = { Rare = 1 }, cash = 5000 }
premium[3] = { seedPacks = { Rare = 2 } }
premium[5] = { petEggs = { Rare = 1 }, boosts = { cash = 1800 } }
premium[7] = { gear = { MutationTotem = 1 } }
premium[10] = { seedPacks = { Epic = 1 }, boosts = { cash = 1800, growth = 1800 } }
premium[12] = { petEggs = { Rare = 2 } }
premium[15] = { seedPacks = { Epic = 2 }, gear = { SizeTotem = 1 }, cash = 60000 }
premium[18] = { petEggs = { Epic = 1 } }
premium[20] = { seedPacks = { Legendary = 1 }, boosts = { luck = 3600 } }
premium[23] = { gear = { MutationTotem = 2 } }
premium[25] = { seedPacks = { Epic = 3 }, petEggs = { Epic = 1 } }
premium[28] = { seedPacks = { Legendary = 1 }, boosts = { cash = 3600, luck = 3600 } }
premium[30] = { seedPacks = { Legendary = 3 }, petEggs = { Epic = 2 }, cash = 500000 }

SeasonConfig.Free = free
SeasonConfig.Premium = premium

-- Producto de saltar niveles: ver MonetizationConfig.DevProducts.SeasonSkip*.

-- Temporada actual a partir de la hora del servidor.
function SeasonConfig.Current(now: number): (number, number)
	local length = SeasonConfig.DurationDays * 86400
	local index = math.floor((now - SeasonConfig.EpochUnix) / length)
	local endsAt = SeasonConfig.EpochUnix + (index + 1) * length
	return index + 1, endsAt
end

-- Nivel y XP restante a partir del XP total.
function SeasonConfig.LevelFromXp(totalXp: number): (number, number, number)
	local level, remaining = 0, totalXp
	while level < SeasonConfig.MaxLevel do
		local need = SeasonConfig.XpForLevel(level + 1)
		if remaining < need then
			return level, remaining, need
		end
		remaining -= need
		level += 1
	end
	return level, 0, 0
end

return SeasonConfig
