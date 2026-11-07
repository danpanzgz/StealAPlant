--!strict
--[[
	Main.client.lua
	Punto de entrada del cliente. Pide el snapshot inicial al servidor,
	arranca HUD y controladores y lanza el onboarding (primera planta,
	primera recompensa, descubrir el robo, proteger el jardín).
	Todo es presentación: Cash e inventario siempre vienen del servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Client = script.Parent
local ClientState = require(Client.ClientState)

local HUDController = require(Client.Controllers.HUDController)
local ShopController = require(Client.Controllers.ShopController)
local PlantController = require(Client.Controllers.PlantController)
local InventoryController = require(Client.Controllers.InventoryController)
local GardenController = require(Client.Controllers.GardenController)
local QuestController = require(Client.Controllers.QuestController)
local LeaderboardController = require(Client.Controllers.LeaderboardController)
local StoreController = require(Client.Controllers.StoreController)
local PromptController = require(Client.Controllers.PromptController)
local SlapController = require(Client.Controllers.SlapController)
local IndexController = require(Client.Controllers.IndexController)
local AudioController = require(Client.Controllers.AudioController)
local EffectsController = require(Client.Controllers.EffectsController)

local getSnapshotFn = Net.GetRemoteFunction("GetPlayerProfileSnapshot")

local function getSnapshot(): any
	while true do
		local snapshot = getSnapshotFn:InvokeServer()
		if snapshot and snapshot.success then
			return snapshot
		end
		task.wait(1.5) -- el perfil aún se está cargando
	end
end

local function onboarding()
	task.delay(1.5, function()
		HUDController.Push("🌱 ¡Bienvenido! Abre Bag → Seeds, elige Hold y toca una parcela vacía para plantar", "good")
	end)
	task.delay(8, function()
		HUDController.Push("🌼 Al madurar, reclama tu flor. Colócala para ganar Cash por minuto o véndela desde Plants.", "good")
	end)
	task.delay(45, function()
		HUDController.Push("🕵️ Visita el Jardín del Vecino en la plaza y consigue flores (mantén F)", "social")
	end)
	task.delay(75, function()
		HUDController.Push("♻️ Cada renacimiento aumenta el número de flores que puedes colocar a la vez.", "info")
	end)
end

local snapshot = getSnapshot()

ClientState.SetInventoryFromSnapshot(snapshot.inventory)
ClientState.GardenLevel = snapshot.gardenLevel
ClientState.Defenses = snapshot.defenses
ClientState.Passes = snapshot.passes
ClientState.PlacedPlants = snapshot.placedPlants or {}
ClientState.EquippedGear = snapshot.equippedGear or {}

HUDController.Init(snapshot)
ShopController.Init(snapshot, HUDController)
PlantController.Init(HUDController)
InventoryController.Init(HUDController)
GardenController.Init(HUDController)
QuestController.Init(HUDController)
LeaderboardController.Init(HUDController)
StoreController.Init(HUDController)
PromptController.Init()
SlapController.Init(HUDController)
IndexController.Init(HUDController, snapshot)
AudioController.Init(HUDController)
EffectsController.Init(HUDController)

onboarding()

if QuestController.Preload() then
	task.delay(3, function()
		HUDController.Push("🎁 ¡Tu recompensa diaria está lista! Abre 📜 Quests", "event")
	end)
end
