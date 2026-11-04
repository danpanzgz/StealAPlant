--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlapController = {}

function SlapController.Init(hud: any)
	local button = hud.CreateActionButton("SlapButton", "SLAP", "Palo")
	local context = ReplicatedStorage:WaitForChild("Inputs"):WaitForChild("GameplayContext")
	local action = context:WaitForChild("Slap") :: InputAction
	local buttonBinding = Instance.new("InputBinding")
	buttonBinding.Name = "TouchButton"
	buttonBinding.Type = Enum.InputBindingType.Automatic
	buttonBinding.UIButton = button
	buttonBinding.Parent = action
end

return SlapController
