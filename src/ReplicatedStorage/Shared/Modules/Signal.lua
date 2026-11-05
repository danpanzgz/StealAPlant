--!strict
--[[
	Signal.lua
	Implementación ligera de un Signal (patrón observador) sin dependencias
	externas, usada para comunicación interna entre módulos de servidor
	(por ejemplo: PlantService avisa a EconomyService cuando una planta
	genera ingreso, sin acoplarlos directamente).
]]

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable(
	{} :: { _connections: { (...any) -> () } },
	Signal
))

function Signal.new(): Signal
	local self = setmetatable({
		_connections = {},
	}, Signal)
	return self
end

function Signal.Connect(self: Signal, fn: (...any) -> ())
	table.insert(self._connections, fn)
	local connection = {
		Disconnect = function()
			local idx = table.find(self._connections, fn)
			if idx then
				table.remove(self._connections, idx)
			end
		end,
	}
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	for _, fn in ipairs(self._connections) do
		task.spawn(fn, ...)
	end
end

return Signal
