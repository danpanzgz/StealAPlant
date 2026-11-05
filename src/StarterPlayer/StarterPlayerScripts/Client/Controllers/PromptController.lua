--!strict
--[[
	PromptController.lua
	Ajusta localmente qué ProximityPrompts ve cada jugador (solo visual; el
	servidor revalida siempre):
	  - "Interact" (plantar/cosechar): solo en tus propias parcelas.
	  - "Steal": solo en parcelas ajenas con planta madura (atributo Stealable).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PromptController = {}

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local plot = prompt.Parent
	if not plot or not plot:IsA("BasePart") then
		return
	end
	if prompt.Name ~= "Interact" and prompt.Name ~= "Steal" then
		return
	end

	local isMine = plot:GetAttribute("OwnerUserId") == player.UserId

	if prompt.Name == "Interact" then
		if not isMine then
			prompt.Enabled = false
			prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if prompt.Enabled then
					prompt.Enabled = false
				end
			end)
		end
	else
		local function update()
			prompt.Enabled = (not isMine) and plot:GetAttribute("Stealable") == true
		end
		update()
		plot:GetAttributeChangedSignal("Stealable"):Connect(update)
	end
end

function PromptController.Init()
	local gardens = Workspace:WaitForChild("Gardens")
	for _, descendant in ipairs(gardens:GetDescendants()) do
		setupPrompt(descendant)
	end
	gardens.DescendantAdded:Connect(setupPrompt)
end

return PromptController
