--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local InventoryController = require(controllers:WaitForChild("InventoryController"))
local inputs = ReplicatedStorage:WaitForChild("Inputs")
local gameplayContext = inputs:WaitForChild("GameplayContext")

local toggleInventory = gameplayContext:WaitForChild("ToggleInventory") :: InputAction
toggleInventory.Pressed:Connect(function()
	InventoryController.ToggleBag()
end)

-- La colocación de plantas se gestiona directamente en InventoryController
-- (InputBegan + botones en pantalla), sin depender de InputContext.
