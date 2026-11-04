--!strict
--[[
	LeaderboardController.lua
	Panel "Top": los 10 jugadores con más Cash total ganado (global si el
	OrderedDataStore responde; si no, el top del servidor actual).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Client = script.Parent.Parent
local UI = require(Client.UI)

local LeaderboardController = {}

local leaderboardFn = Net.GetRemoteFunction("GetLeaderboard")
local listFrame: ScrollingFrame

local MEDALS = { "🥇", "🥈", "🥉" }
local MEDAL_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(200, 205, 215), Color3.fromRGB(205, 140, 90) }

local function refresh()
	local result = leaderboardFn:InvokeServer()
	UI.ClearList(listFrame)
	if not result or not result.success then
		return
	end

	local header = UI.Card(listFrame, 36, 0)
	local source = if result.source == "global" then "Top global" else "Top de este servidor"
	UI.Label(header, "🏆 Más ricos — " .. source, UDim2.new(1, -16, 1, -10), UDim2.new(0, 8, 0, 5), UI.Colors.Gold)

	for _, entry in ipairs(result.entries) do
		local top = entry.rank <= 3
		local row = UI.Card(listFrame, if top then 56 else 44, entry.rank)
		local rank = UI.Label(row, if top then MEDALS[entry.rank] else ("#" .. entry.rank), UDim2.new(0, 48, 1, -12), UDim2.new(0, 8, 0, 6), if top then MEDAL_COLORS[entry.rank] else UI.Colors.Muted)
		rank.TextXAlignment = Enum.TextXAlignment.Center
		UI.Label(row, entry.name, UDim2.new(1, -190, 1, -14), UDim2.new(0, 64, 0, 7))
		local score = UI.Label(row, "$" .. UI.Money(entry.score), UDim2.new(0, 110, 1, -14), UDim2.new(1, -118, 0, 7), UI.Colors.Green)
		score.TextXAlignment = Enum.TextXAlignment.Right
	end
end

function LeaderboardController.Init(hud: any)
	local _, list = hud.CreatePanel("Top", "Leaderboard", refresh)
	listFrame = list

	local button = hud.CreateActionButton("TopButton", "🏆", "Top")
	button.Activated:Connect(function()
		hud.TogglePanel("Top")
	end)
end

return LeaderboardController
