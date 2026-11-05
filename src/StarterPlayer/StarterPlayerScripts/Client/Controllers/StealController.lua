--!strict
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local StealController = {}

function StealController.Init(hud: any)
	local attempt = Net.GetRemoteFunction("AttemptSteal")
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer or prompt.Name ~= "StealInteract" then return end
		local part = prompt.Parent
		local owner = part and part:GetAttribute("OwnerUserId")
		local index = part and part:GetAttribute("PlotIndex")
		if type(owner) ~= "number" or type(index) ~= "number" or owner == player.UserId then return end
		local result = attempt:InvokeServer(owner, index)
		if not result or not result.success then hud.ShowNotification("Can't steal: " .. ((result and result.reason) or "error"), Color3.fromRGB(255, 120, 120)) end
	end)
end

return StealController
