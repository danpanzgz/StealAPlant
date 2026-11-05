--!strict
--[[
	DailyRewardConfig.lua
	Ciclo de 7 días. Si el jugador pierde más de StreakGraceHours, la racha
	se reinicia al día 1.
]]

local DailyRewardConfig = {}

DailyRewardConfig.CooldownHours = 24
DailyRewardConfig.StreakGraceHours = 48

DailyRewardConfig.Rewards = {
	{ cash = 100 },
	{ cash = 50, seeds = { Potato = 2 } },
	{ cash = 250 },
	{ seeds = { Tomato = 2 } },
	{ cash = 500 },
	{ seeds = { Sunflower = 1 } },
	{ cash = 1500, seeds = { Pumpkin = 1 } },
} :: { { cash: number?, seeds: { [string]: number }? } }

return DailyRewardConfig
