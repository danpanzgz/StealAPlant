--!strict
--[[
	DefenseConfig.lua
	Defensas de jardín. Todas son NO dañinas: solo bajan la probabilidad de
	que un robo tenga éxito (alarmas, vallas, gnomos guardianes cómicos).
	Cada defensa ocupa un slot (ver GardenConfig.Levels[n].defenseSlots).
]]

export type DefenseData = {
	id: string,
	displayName: string,
	emoji: string,
	price: number,
	stealChanceReduction: number, -- se resta a GameConfig.StealBaseSuccessChance
	description: string,
	color: Color3,
}

local DefenseConfig: { [string]: DefenseData } = {
	Bell = {
		id = "Bell", displayName = "Alarm Bell", emoji = "🔔", price = 250,
		stealChanceReduction = 0.10,
		description = "Una campana que suena fuerte cuando alguien se acerca.",
		color = Color3.fromRGB(255, 205, 60),
	},
	Fence = {
		id = "Fence", displayName = "Picket Fence", emoji = "🚧", price = 700,
		stealChanceReduction = 0.20,
		description = "Una valla blanca y alegre que despista a los ladrones.",
		color = Color3.fromRGB(245, 245, 245),
	},
	Gnome = {
		id = "Gnome", displayName = "Guard Gnome", emoji = "🧙", price = 1800,
		stealChanceReduction = 0.30,
		description = "Un gnomo cómico que silba y marca a los intrusos.",
		color = Color3.fromRGB(220, 60, 60),
	},
}

DefenseConfig.Order = { "Bell", "Fence", "Gnome" } :: any

-- La probabilidad de robo nunca baja de este valor (siempre hay emoción).
DefenseConfig.MinStealChance = 0.10 :: any
-- Escudos temporales (segundos): al entrar y tras ser robado.
DefenseConfig.JoinShieldSeconds = 60 :: any
DefenseConfig.StolenShieldSeconds = 30 :: any

return DefenseConfig
