--!strict
--[[
	SettingsController.lua
	Panel de ajustes: música, efectos y calidad gráfica. Son solo de cliente
	(ver Settings.lua); AudioController y SkyController los leen.
]]

local UI = require(script.Parent.Parent.UI)
local Settings = require(script.Parent.Parent.Settings)

local SettingsController = {}

local QUALITY_NAMES = { "Baja", "Media", "Alta" }

function SettingsController.Init(hud: any)
	local _, list = hud.CreatePanel("Settings", "Ajustes", nil, true)
	UI.UseList(list, 8)

	local function toggleRow(order: number, label: string, key: string)
		local card = UI.Card(list, 52, order)
		UI.Label(card, label, UDim2.new(1, -130, 1, -8), UDim2.new(0, 12, 0, 4), UI.Colors.Text, true)
		local button = UI.Button(card, "", UI.Colors.Green, UDim2.fromOffset(96, 36), UDim2.new(1, -106, 0.5, -18))
		local function paint()
			local on = (Settings :: any)[key] == true
			button.Text = if on then "SÍ" else "NO"
			button.BackgroundColor3 = if on then UI.Colors.Green else UI.Colors.Grey
		end
		paint()
		button.Activated:Connect(function()
			Settings.Set(key, not ((Settings :: any)[key] == true))
			paint()
		end)
	end

	toggleRow(1, "🎵 Música", "Music")
	toggleRow(2, "🔊 Efectos de sonido", "Sfx")

	local card = UI.Card(list, 52, 3)
	UI.Label(card, "🖥️ Gráficos", UDim2.new(1, -130, 1, -8), UDim2.new(0, 12, 0, 4), UI.Colors.Text, true)
	local quality = UI.Button(card, QUALITY_NAMES[Settings.Quality], UI.Colors.Blue, UDim2.fromOffset(96, 36), UDim2.new(1, -106, 0.5, -18))
	quality.Activated:Connect(function()
		local nextQuality = Settings.Quality % 3 + 1
		Settings.Set("Quality", nextQuality)
		quality.Text = QUALITY_NAMES[nextQuality]
	end)

	local note = UI.Card(list, 48, 4)
	local text = UI.Label(note, "Gráficos bajos: menos nubes y partículas. Ideal para móviles antiguos.", UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4), UI.Colors.Muted, false)
	text.TextWrapped = true

	local button = hud.CreateActionButton("SettingsButton", "⚙️", "Ajustes")
	button.Activated:Connect(function()
		hud.TogglePanel("Settings")
	end)
end

return SettingsController
