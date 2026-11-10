--!strict
--[[
	SlapController.lua
	Recibe el empujón del palo (SlapHit). El personaje lo mueve su dueño, por
	eso el golpe se aplica aquí: un impulso corto y un aviso gracioso.
	El palo se usa desde la barra rápida (casilla 1 por defecto), sin botón propio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local SlapController = {}
local player = Players.LocalPlayer

function SlapController.Init(hud: any)
	Net.GetRemoteEvent("SlapHit").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or typeof(payload.direction) ~= "Vector3" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end
		local power = math.clamp(tonumber(payload.power) or 1, 0.5, 4)
		local direction = Vector3.new(payload.direction.X, 0, payload.direction.Z)
		if direction.Magnitude < 0.01 then
			direction = root.CFrame.LookVector
		end
		root.AssemblyLinearVelocity = direction.Unit * (44 * power) + Vector3.new(0, 26 + 4 * power, 0)
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		task.delay(0.9, function()
			if humanoid.Parent then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
		hud.Push("🪵 ¡" .. tostring(payload.by or "Alguien") .. " te dio un empujón!", "warn")
	end)
end

return SlapController
