--!strict
--[[
	SoundConfig.lua
	Todos los sonidos y la música del juego. Para activar un sonido pega su
	asset id ("rbxassetid://123456") en el campo `id`. Si `id` está vacío el
	sonido simplemente no suena (no da errores).

	IMPORTANTE: usa solo audios que tú hayas subido a Roblox o que sean
	públicos y de uso permitido; Roblox restringe los audios de terceros.
	Los `rbxasset://sounds/...` de abajo son archivos internos del cliente de
	Roblox usados como sonidos provisionales (suenan "a máquina"); cámbialos por
	los tuyos cuando los tengas. Si alguno no existe en tu versión, no suena.
]]

export type SfxDef = { id: string, volume: number, speed: number? }

local SoundConfig = {}

-- Volúmenes globales (0..1). El jugador puede silenciar música/efectos desde el botón de audio.
SoundConfig.MusicVolume = 0.35
SoundConfig.SfxVolume = 0.8

-- Efectos de sonido por nombre. Los usan AudioController / EffectsController.
SoundConfig.Sfx = {
	Plant = { id = "rbxasset://sounds/snap.mp3", volume = 0.7, speed = 0.8 }, -- plantar semilla
	Harvest = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 1.3 }, -- cosechar
	Discovery = { id = "rbxasset://sounds/victory.wav", volume = 0.8 }, -- planta nueva en el Índice
	EggDrop = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.8 }, -- el huevo cae
	EggShake = { id = "rbxasset://sounds/clickfast.wav", volume = 0.7, speed = 0.8 }, -- se agita (x4)
	EggCrack = { id = "rbxasset://sounds/snap.mp3", volume = 0.9, speed = 0.55 }, -- grieta
	EggHatch = { id = "rbxasset://sounds/victory.wav", volume = 0.9, speed = 1.2 }, -- se abre
	Alarm = { id = "", volume = 0.7 }, -- alarma del jardín
	StealResolved = { id = "", volume = 0.7 },
	Click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.45, speed = 1.1 }, -- cualquier botón
	MenuOpen = { id = "rbxasset://sounds/switch.wav", volume = 0.55 }, -- abrir/cerrar menú
	PlantPlace = { id = "rbxasset://sounds/snap.mp3", volume = 0.8, speed = 0.7 }, -- flor colocada
	EventStart = { id = "rbxasset://sounds/victory.wav", volume = 0.7, speed = 1.4 }, -- empieza un evento
	EventEnd = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 0.7 },
	DailyReward = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8 },
} :: { [string]: SfxDef }

-- Ambiente en bucle. "Garden" suena siempre; el resto solo durante su evento
-- (clave = id del evento en EventConfig). Pega aquí tus ids (vacío = silencio).
SoundConfig.Ambient = {
	Garden = { id = "", volume = 0.25 }, -- pájaros / viento
	RainShower = { id = "", volume = 0.5 }, -- lluvia
	GoldRush = { id = "", volume = 0.35 }, -- brillos / campanillas
} :: { [string]: SfxDef }

-- Canciones de fondo (se reproducen en bucle, en orden aleatorio).
-- Añade las que quieras: { id = "rbxassetid://...", volume = 1 }
SoundConfig.Music = {
	-- { id = "rbxassetid://0000000", volume = 1 },
} :: { { id: string, volume: number } }

-- Voz de cada mascota al salir del huevo. Si no hay id propio se usa
-- `DefaultCry` con un tono distinto por mascota para que no suenen iguales.
SoundConfig.DefaultCry = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.9 } :: SfxDef
SoundConfig.PetCries = {
	-- MeadowCube = { id = "rbxassetid://...", volume = 0.9 },
	-- PondDuck = { id = "rbxassetid://...", volume = 0.9 },
} :: { [string]: SfxDef }

-- Tono (PlaybackSpeed) determinista por mascota, entre 0.75 y 1.45.
function SoundConfig.PetPitch(petId: string): number
	local hash = 0
	for index = 1, #petId do
		hash = (hash * 31 + string.byte(petId, index)) % 9973
	end
	return 0.75 + (hash % 71) / 100
end

return SoundConfig
