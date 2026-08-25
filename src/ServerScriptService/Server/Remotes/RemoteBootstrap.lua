--!strict
--[[
	RemoteBootstrap.lua
	Crea todos los RemoteEvents/RemoteFunctions declarados en Net.lua al
	arrancar el servidor, ANTES de que ningún jugador se conecte. Así
	evitamos crear remotos "sobre la marcha" y evitamos duplicados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local RemoteBootstrap = {}

function RemoteBootstrap.Init()
	for _, name in ipairs(Net.RemoteEventNames) do
		Net.GetRemoteEvent(name)
	end
	for _, name in ipairs(Net.RemoteFunctionNames) do
		Net.GetRemoteFunction(name)
	end
	print("[RemoteBootstrap] Remotos inicializados:",
		#Net.RemoteEventNames, "events,", #Net.RemoteFunctionNames, "functions")
end

return RemoteBootstrap
