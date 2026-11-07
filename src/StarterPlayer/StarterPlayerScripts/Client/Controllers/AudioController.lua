--!strict
--[[
	AudioController.lua
	Música de fondo en bucle + efectos de sonido. Los ids viven en
	SoundConfig; un id vacío no suena. Botón de audio: música+efectos ->
	solo efectos -> silencio.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)

local AudioController = {}

local sfxGroup: SoundGroup
local musicGroup: SoundGroup
local currentTrack: Sound? = nil
local lastTrackIndex = 0
local audioMode = 1 -- 1 música+efectos, 2 solo efectos, 3 silencio
local MODE_LABELS = { "🔊", "🔉", "🔇" }
local musicRandom = Random.new()

local function newGroup(name: string, volume: number): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = volume
	group.Parent = SoundService
	return group
end

local function createSound(id: string, volume: number, speed: number?, group: SoundGroup): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.SoundGroup = group
	return sound
end

local function playOnce(sound: Sound, parent: Instance)
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, math.max(sound.TimeLength, 4) + 2)
end

function AudioController.Play(name: string, speedOverride: number?)
	local def = SoundConfig.Sfx[name]
	if not def then
		return
	end
	local sound = createSound(def.id, def.volume, speedOverride or def.speed, sfxGroup)
	if sound then
		playOnce(sound, SoundService)
	end
end

-- Sonido posicional (3D) en un punto del mundo.
function AudioController.PlayAt(name: string, position: Vector3)
	local def = SoundConfig.Sfx[name]
	if not def or def.id == "" then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = Workspace
	local sound = createSound(def.id, def.volume, def.speed, sfxGroup)
	if sound then
		playOnce(sound, anchor)
	end
	Debris:AddItem(anchor, 8)
end

-- Voz de la mascota que sale del huevo (tono propio por mascota).
function AudioController.PlayPetCry(petId: string)
	local def = SoundConfig.PetCries[petId] or SoundConfig.DefaultCry
	local speed = if SoundConfig.PetCries[petId] then 1 else SoundConfig.PetPitch(petId)
	local sound = createSound(def.id, def.volume, speed, sfxGroup)
	if sound then
		playOnce(sound, SoundService)
	end
end

-- Baja la música mientras ocurre algo importante (apertura de huevo).
function AudioController.DuckMusic(seconds: number)
	if audioMode ~= 1 then
		return
	end
	local base = SoundConfig.MusicVolume
	TweenService:Create(musicGroup, TweenInfo.new(0.3), { Volume = base * 0.25 }):Play()
	task.delay(seconds, function()
		if audioMode == 1 then
			TweenService:Create(musicGroup, TweenInfo.new(0.8), { Volume = base }):Play()
		end
	end)
end

local function playNextTrack()
	local tracks = SoundConfig.Music
	if #tracks == 0 or audioMode ~= 1 then
		return
	end
	local index = musicRandom:NextInteger(1, #tracks)
	if #tracks > 1 and index == lastTrackIndex then
		index = index % #tracks + 1
	end
	lastTrackIndex = index
	local def = tracks[index]
	local sound = createSound(def.id, 0, 1, musicGroup)
	if not sound then
		return
	end
	sound.Name = "MusicTrack"
	sound.Parent = SoundService
	currentTrack = sound
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(2), { Volume = def.volume }):Play()
	sound.Ended:Once(function()
		if currentTrack == sound then
			currentTrack = nil
			sound:Destroy()
			task.defer(playNextTrack)
		end
	end)
end

local function stopMusic()
	local track = currentTrack
	currentTrack = nil
	if track then
		local tween = TweenService:Create(track, TweenInfo.new(0.6), { Volume = 0 })
		tween:Play()
		tween.Completed:Once(function()
			track:Destroy()
		end)
	end
end

local function applyMode()
	musicGroup.Volume = if audioMode == 1 then SoundConfig.MusicVolume else 0
	sfxGroup.Volume = if audioMode == 3 then 0 else SoundConfig.SfxVolume
	if audioMode == 1 then
		if not currentTrack then
			playNextTrack()
		end
	else
		stopMusic()
	end
end

function AudioController.Init(hud: any)
	sfxGroup = newGroup("SFX", SoundConfig.SfxVolume)
	musicGroup = newGroup("Music", SoundConfig.MusicVolume)

	-- Eventos del servidor que suenan sin animación propia.
	Net.GetRemoteEvent("PlantHarvested").OnClientEvent:Connect(function()
		AudioController.Play("Harvest")
	end)
	Net.GetRemoteEvent("GardenAlarmTriggered").OnClientEvent:Connect(function()
		AudioController.Play("Alarm")
	end)
	Net.GetRemoteEvent("StealAttemptResolved").OnClientEvent:Connect(function()
		AudioController.Play("StealResolved")
	end)
	Net.GetRemoteEvent("DailyRewardClaimed").OnClientEvent:Connect(function()
		AudioController.Play("DailyReward")
	end)

	local button = hud.CreateActionButton("AudioButton", MODE_LABELS[audioMode], "Audio")
	button.Activated:Connect(function()
		audioMode = audioMode % 3 + 1
		local icon = button:FindFirstChild("Icon")
		if icon and icon:IsA("TextLabel") then
			icon.Text = MODE_LABELS[audioMode]
		end
		applyMode()
		hud.Push(
			if audioMode == 1 then "Música y efectos activados" elseif audioMode == 2 then "Solo efectos" else "Audio silenciado",
			"info"
		)
	end)

	applyMode()
end

return AudioController
