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
local SeasonController = require(Client.Controllers.SeasonController)
local LeaderboardController = require(Client.Controllers.LeaderboardController)
local StoreController = require(Client.Controllers.StoreController)
local PromptController = require(Client.Controllers.PromptController)
local SlapController = require(Client.Controllers.SlapController)
local IndexController = require(Client.Controllers.IndexController)
local AudioController = require(Client.Controllers.AudioController)
local EffectsController = require(Client.Controllers.EffectsController)
local SkyController = require(Client.Controllers.SkyController)
local HotbarController = require(Client.Controllers.HotbarController)
local SellController = require(Client.Controllers.SellController)
local RebirthController = require(Client.Controllers.RebirthController)
local SettingsController = require(Client.Controllers.SettingsController)

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
		HUDController.Push("🌱 ¡Bienvenido! Abre 🎒 la Mochila, arrastra una semilla a tu barra y toca el suelo marrón de tu jardín", "good")
	end)
	task.delay(8, function()
		HUDController.Push("🌼 Al madurar, reclama tu flor. Colócala para ganar dinero o véndela en el puesto de venta del mapa.", "good")
	end)
	task.delay(45, function()
		HUDController.Push("🕵️ Visita el Jardín del Vecino en la plaza y consigue flores (mantén F)", "social")
	end)
	task.delay(75, function()
		HUDController.Push("♻️ Cada renacimiento da +2 huecos, más suerte y cobras más. ¡Pulsa Renacer!", "info")
	end)
end

local snapshot = getSnapshot()

ClientState.SetInventoryFromSnapshot(snapshot.inventory)
ClientState.GardenLevel = snapshot.gardenLevel
ClientState.Defenses = snapshot.defenses
ClientState.Passes = snapshot.passes
ClientState.Boosts = snapshot.boosts or {}
ClientState.OncePurchased = snapshot.oncePurchased or {}
ClientState.PlacedPlants = snapshot.placedPlants or {}
ClientState.EquippedGear = snapshot.equippedGear or {}

-- Cada controlador se inicia aislado: si uno falla se avisa en Output y el
-- resto del juego (incluidos audio y animaciones) sigue funcionando.
local function safeInit(name: string, init: () -> ())
	local ok, err = pcall(init)
	if not ok then
		warn(string.format("[Client] %s.Init falló: %s", name, tostring(err)))
	end
end

HUDController.Init(snapshot)
safeInit("SkyController", function() SkyController.Init() end)
safeInit("ShopController", function() ShopController.Init(snapshot, HUDController) end)
safeInit("PlantController", function() PlantController.Init(HUDController) end)
safeInit("InventoryController", function() InventoryController.Init(HUDController) end)
safeInit("HotbarController", function() HotbarController.Init(HUDController, InventoryController) end)
safeInit("SellController", function() SellController.Init(HUDController) end)
safeInit("RebirthController", function() RebirthController.Init(HUDController) end)
safeInit("SettingsController", function() SettingsController.Init(HUDController) end)
safeInit("GardenController", function() GardenController.Init(HUDController) end)
safeInit("QuestController", function() QuestController.Init(HUDController) end)
safeInit("SeasonController", function() SeasonController.Init(HUDController) end)
safeInit("LeaderboardController", function() LeaderboardController.Init(HUDController) end)
safeInit("StoreController", function() StoreController.Init(HUDController) end)
safeInit("PromptController", function() PromptController.Init() end)
safeInit("SlapController", function() SlapController.Init(HUDController) end)
safeInit("IndexController", function() IndexController.Init(HUDController, snapshot) end)
safeInit("AudioController", function() AudioController.Init(HUDController) end)
safeInit("EffectsController", function() EffectsController.Init(HUDController) end)

onboarding()

if QuestController.Preload() then
	task.delay(3, function()
		HUDController.Push("🎁 ¡Tu recompensa diaria está lista! Abre 📜 Quests", "event")
	end)
end
