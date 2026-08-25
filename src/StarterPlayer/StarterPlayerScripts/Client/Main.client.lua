--!strict
--[[
	Main.client.lua
	Punto de entrada del cliente. Pide el snapshot inicial del jugador al
	servidor, arranca el HUD y los controladores de interacción.
	Todo lo que se muestra aquí es solo presentación: ninguna cantidad de
	Cash/inventario se calcula en el cliente, siempre viene del servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local player = Players.LocalPlayer
local Client = script.Parent

local HUDController = require(Client.Controllers.HUDController)
local ShopController = require(Client.Controllers.ShopController)
local PlantController = require(Client.Controllers.PlantController)

local getSnapshotFn = Net.GetRemoteFunction("GetPlayerProfileSnapshot")

local function bootstrap()
	local snapshot = getSnapshotFn:InvokeServer()
	if not snapshot or snapshot.success == false then
		warn("[Main.client] No se pudo obtener el snapshot inicial, reintentando en 2s")
		task.wait(2)
		return bootstrap()
	end

	HUDController.Init(snapshot)
	ShopController.Init(snapshot, HUDController)
	PlantController.Init(HUDController)
end

bootstrap()
