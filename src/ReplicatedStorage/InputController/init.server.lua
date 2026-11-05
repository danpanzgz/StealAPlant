--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local controllers = playerScripts:WaitForChild("Client"):WaitForChild("Controllers")
local InventoryController = require(controllers:WaitForChild("InventoryController"))
local inputs = ReplicatedStorage:WaitForChild("Inputs")
local gameplayContext = inputs:WaitForChild("GameplayContext")
local placementContext = inputs:WaitForChild("PlacementContext")

local toggleInventory = gameplayContext:WaitForChild("ToggleInventory") :: InputAction
toggleInventory.Pressed:Connect(function()
	InventoryController.ToggleBag()
end)

local placementPointer = gameplayContext:WaitForChild("PlacementPointer") :: InputAction
local confirmPlacement = placementContext:WaitForChild("ConfirmPlacement") :: InputAction
confirmPlacement.Pressed:Connect(function()
	local binding = confirmPlacement.PreferredBinding
	local position = placementPointer:GetState()
	if binding and binding.KeyCode == Enum.KeyCode.ButtonA then
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		position = camera.ViewportSize / 2
	end
	if typeof(position) ~= "Vector2" then
		return
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui and #playerGui:GetGuiObjectsAtPosition(position.X, position.Y) > 0 then
		return
	end
	InventoryController.ConfirmPlacement(position)
end)

local cancelPlacement = placementContext:WaitForChild("CancelPlacement") :: InputAction
cancelPlacement.Pressed:Connect(function()
	InventoryController.CancelPlacement()
end)
