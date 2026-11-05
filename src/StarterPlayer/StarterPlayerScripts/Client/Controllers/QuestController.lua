--!strict
--[[
	QuestController.lua
	Panel "Quests": recompensa diaria (racha de 7 días) + misiones activas
	con barra de progreso y botón de reclamar. Datos 100% del servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Client = script.Parent.Parent
local UI = require(Client.UI)

local QuestController = {}

local dataFn = Net.GetRemoteFunction("GetQuestsAndDaily")
local claimQuestFn = Net.GetRemoteFunction("ClaimQuestReward")
local claimDailyFn = Net.GetRemoteFunction("ClaimDailyReward")

local listFrame: ScrollingFrame
local hud: any
local badge: TextLabel
local lastDaily: any = nil
local lastQuests: any = nil
local dailyToken = 0

local function rewardText(reward: any): string
	local parts = {}
	if reward.cash then
		table.insert(parts, "$" .. UI.Money(reward.cash))
	end
	if reward.seeds then
		for plantId, amount in pairs(reward.seeds) do
			table.insert(parts, amount .. "x " .. plantId)
		end
	end
	return table.concat(parts, " + ")
end

local function updateBadge()
	local pending = 0
	if lastDaily and lastDaily.canClaim then
		pending += 1
	end
	if lastQuests then
		for _, q in ipairs(lastQuests.quests) do
			if q.progress >= q.target and not q.claimed then
				pending += 1
			end
		end
	end
	if badge then
		badge.Visible = pending > 0
		badge.Text = tostring(pending)
	end
end

local function render()
	UI.ClearList(listFrame)
	dailyToken += 1
	local token = dailyToken

	if lastDaily then
		local reward = lastDaily.rewards[lastDaily.nextDay]
		local card = UI.Card(listFrame, 84, 1)
		UI.Label(card, "🎁 Recompensa diaria — Día " .. lastDaily.nextDay .. "/7", UDim2.new(1, -16, 0, 24), UDim2.new(0, 12, 0, 6), UI.Colors.Gold)
		UI.Label(card, rewardText(reward), UDim2.new(1, -140, 0, 20), UDim2.new(0, 12, 0, 34), UI.Colors.Text, false)
		if lastDaily.canClaim then
			local button = UI.Button(card, "¡RECLAMAR!", UI.Colors.Green, UDim2.new(0, 120, 0, 44), UDim2.new(1, -132, 1, -52))
			button.Activated:Connect(function()
				button.Active = false
				local result = claimDailyFn:InvokeServer()
				button.Active = true
				if result and result.success then
					lastDaily = result.status
					updateBadge()
					render()
				else
					hud.Push("No disponible todavía", "warn")
				end
			end)
		else
			local timer = UI.Label(card, "Vuelve en " .. UI.Time(lastDaily.secondsLeft), UDim2.new(1, -16, 0, 18), UDim2.new(0, 12, 1, -26), UI.Colors.Muted, false)
			local left = lastDaily.secondsLeft
			task.spawn(function()
				while token == dailyToken and left > 0 do
					task.wait(1)
					left -= 1
					if token == dailyToken then
						timer.Text = "Vuelve en " .. UI.Time(left)
					end
				end
			end)
		end
	end

	if lastQuests then
		for i, q in ipairs(lastQuests.quests) do
			local card = UI.Card(listFrame, 78, 1 + i)
			UI.Label(card, "📜 " .. q.description, UDim2.new(1, -130, 0, 22), UDim2.new(0, 12, 0, 6))
			UI.Label(card, "Premio: $" .. UI.Money(q.rewardCash), UDim2.new(1, -130, 0, 16), UDim2.new(0, 12, 0, 30), UI.Colors.Gold, false)

			local barBg = Instance.new("Frame")
			barBg.Size = UDim2.new(1, -140, 0, 12)
			barBg.Position = UDim2.new(0, 12, 0, 54)
			barBg.BackgroundColor3 = UI.Colors.Grey
			barBg.BorderSizePixel = 0
			barBg.Parent = card
			UI.Round(barBg, 6)
			local fill = Instance.new("Frame")
			fill.Size = UDim2.new(math.clamp(q.progress / q.target, 0, 1), 0, 1, 0)
			fill.BackgroundColor3 = UI.Colors.Green
			fill.BorderSizePixel = 0
			fill.Parent = barBg
			UI.Round(fill, 6)

			local done = q.progress >= q.target
			local text = if q.claimed then "✔" elseif done then "Reclamar" else (q.progress .. "/" .. q.target)
			local color = if done and not q.claimed then UI.Colors.Green else UI.Colors.Grey
			local button = UI.Button(card, text, color, UDim2.new(0, 100, 0, 44), UDim2.new(1, -112, 0.5, -22))
			button.Activated:Connect(function()
				if not done or q.claimed then
					return
				end
				button.Active = false
				local result = claimQuestFn:InvokeServer(q.id)
				button.Active = true
				if result and result.success then
					hud.Push("🎉 +$" .. UI.Money(result.rewardCash) .. " por la misión", "good")
				end
			end)
		end

		local footer = UI.Card(listFrame, 36, 50)
		UI.Label(footer, "Se renuevan en " .. UI.Time(lastQuests.resetIn), UDim2.new(1, -16, 1, -10), UDim2.new(0, 8, 0, 5), UI.Colors.Muted, false)
	end
end

local function refresh()
	local result = dataFn:InvokeServer()
	if result and result.success then
		lastDaily = result.daily
		lastQuests = result.quests
		updateBadge()
		render()
	end
end

-- Se llama al arrancar para mostrar el aviso de recompensa lista.
function QuestController.Preload(): boolean
	local result = dataFn:InvokeServer()
	if result and result.success then
		lastDaily = result.daily
		lastQuests = result.quests
		updateBadge()
		return result.daily.canClaim
	end
	return false
end

function QuestController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Quests", "Misiones y regalo diario", refresh)
	listFrame = list

	local button = hud.CreateActionButton("QuestButton", "📜", "Quests")
	button.Activated:Connect(function()
		hud.TogglePanel("Quests")
	end)

	badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(0, 20, 0, 20)
	badge.Position = UDim2.new(1, -16, 0, -4)
	badge.BackgroundColor3 = UI.Colors.Red
	badge.TextColor3 = UI.Colors.Text
	badge.Font = Enum.Font.GothamBold
	badge.TextScaled = true
	badge.Visible = false
	badge.ZIndex = 3
	badge.Parent = button
	UI.Round(badge, 10)

	Net.GetRemoteEvent("QuestUpdated").OnClientEvent:Connect(function(state)
		lastQuests = state
		updateBadge()
		if hud.IsPanelOpen("Quests") then
			render()
		end
	end)

	Net.GetRemoteEvent("DailyRewardClaimed").OnClientEvent:Connect(function(payload)
		hud.Push("🎁 ¡Día " .. payload.day .. " reclamado!", "good")
	end)
end

return QuestController
