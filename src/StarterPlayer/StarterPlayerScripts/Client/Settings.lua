--!strict
--[[
	Settings.lua
	Ajustes del jugador solo de cliente (sonido, música, gráficos). Los demás
	controladores leen estos valores y escuchan Settings.Changed.
]]

local Settings = {
	Music = true,
	Sfx = true,
	Quality = 2, -- 1 bajo, 2 medio, 3 alto
}

local changed = Instance.new("BindableEvent")
Settings.Changed = changed.Event

function Settings.Set(key: string, value: any)
	if (Settings :: any)[key] == value then
		return
	end
	(Settings :: any)[key] = value
	changed:Fire(key, value)
end

return Settings
