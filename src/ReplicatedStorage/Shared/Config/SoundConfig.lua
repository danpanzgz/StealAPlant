--!strict
--[[
	SoundConfig.lua
	Todos los sonidos y la música del juego. Para activar un sonido pega su
	asset id ("rbxassetid://123456") en el campo `id`. Si `id` está vacío el
	sonido simplemente no suena (no da errores).

	IMPORTANTE: usa solo audios que tú hayas subido a Roblox o que sean
	públicos y de uso permitido; Roblox restringe los audios de terceros.
	Los dos `rbxasset://sounds/...` de abajo son archivos internos del cliente
	de Roblox usados como marcador; cámbialos cuando tengas los tuyos.
]]

export type SfxDef = { id: string, volume: number, speed: number? }

local SoundConfig = {}

-- Volúmenes globales (0..1). El jugador puede silenciar música/efectos desde el botón de audio.
SoundConfig.MusicVolume = 0.35
SoundConfig.SfxVolume = 0.8

-- Efectos de sonido por nombre. Los usan AudioController / EffectsController.
SoundConfig.Sfx = {
	Plant = { id = "rbxasset://sounds/snap.mp3", volume = 0.6, speed = 0.9 }, -- plantar semilla
	Harvest = { id = "", volume = 0.7 }, -- cosechar
	Discovery = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, speed = 0.9 }, -- planta nueva en el Índice
	EggDrop = { id = "", volume = 0.7 }, -- el huevo aparece
	EggShake = { id = "", volume = 0.6 }, -- el huevo se agita (se repite 4 veces)
	EggCrack = { id = "", volume = 0.8 }, -- grieta
	EggHatch = { id = "", volume = 0.9 }, -- se abre el huevo
	Alarm = { id = "", volume = 0.7 }, -- alarma del jardín
	StealResolved = { id = "", volume = 0.7 },
	DailyReward = { id = "", volume = 0.8 },
} :: { [string]: SfxDef }

-- Canciones de fondo (se reproducen en bucle, en orden aleatorio).
-- Añade las que quieras: { id = "rbxassetid://...", volume = 1 }
SoundConfig.Music = {
	-- { id = "rbxassetid://0000000", volume = 1 },
} :: { { id: string, volume: number } }

-- Voz de cada mascota al salir del huevo. Si no hay id propio se usa
-- `DefaultCry` con un tono distinto por mascota para que no suenen iguales.
SoundConfig.DefaultCry = { id = "", volume = 0.9 } :: SfxDef
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
