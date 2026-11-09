--!strict
--[[
	SeasonController.lua
	Panel "Temporada": nivel, barra de XP, cuenta atrás y la lista de 30
	niveles con pista gratis y premium. Todo lo calcula el servidor; el
	cliente solo muestra y pide reclamar.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Client = script.Parent.Parent
local UI = require(Client.UI)

local SeasonController = {}

local statusFn = Net.GetRemoteFunction("GetSeasonStatus")
local claimFn = Net.GetRemoteFunction("ClaimSeasonReward")

local player = Players.LocalPlayer
local listFrame: ScrollingFrame
local hud: any
local badge: TextLabel
local status: any = nil

local PACK_NAMES = { Common = "Común", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }

local function rewardText(reward: any): string
	if not reward then
		return "—"
	end
	local parts = {}
	if reward.cash then
		table.insert(parts, "$" .. UI.Money(reward.cash))
	end
	for id, n in pairs(reward.seedPacks or {}) do
		table.insert(parts, n .. "x Pack " .. (PACK_NAMES[id] or id))
	end
	for id, n in pairs(reward.petEggs or {}) do
		table.insert(parts, n .. "x Huevo " .. (PACK_NAMES[id] or id))
	end
	for id, n in pairs(reward.gear or {}) do
		table.insert(parts, n .. "x " .. id)
	end
	for stat, seconds in pairs(reward.boosts or {}) do
		table.insert(parts, "x2 " .. stat .. " " .. math.floor(seconds / 60) .. "m")
	end
	return table.concat(parts, " + ")
end

local function claimableCount(): number
	if not status then
		return 0
	end
	local n = 0
	for level = 1, status.level do
		local key = tostring(level)
		if status.freeRewards[level] and not status.free[key] then
			n += 1
		end
		if status.hasPass and status.premiumRewards[level] and not status.premium[key] then
			n += 1
		end
	end
	return n
end

local function updateBadge()
	if not badge then
		return
	end
	local n = claimableCount()
	badge.Visible = n > 0
	badge.Text = tostring(n)
end

local render: () -> ()

local function claim(level: any, track: string?)
	local result = claimFn:InvokeServer(level, track)
	if result and result.status then
		status = result.status
	end
	if result and result.success then
		hud.Push("🏆 ¡Premio de temporada reclamado!", "good")
	end
	updateBadge()
	render()
end

local function addTrackRow(card: Frame, y: number, label: string, reward: any, level: number, track: string, claimed: boolean, unlocked: boolean, locked: boolean)
	UI.Label(card, label .. rewardText(reward), UDim2.new(1, -120, 0, 20), UDim2.new(0, 12, 0, y), if locked then UI.Colors.Muted else UI.Colors.Text, false)
	local text = if claimed then "✔" elseif locked then "🔒" elseif unlocked then "Reclamar" else "…"
	local color = if unlocked and not claimed and not locked then UI.Colors.Green else UI.Colors.Grey
	local button = UI.Button(card, text, color, UDim2.new(0, 90, 0, 30), UDim2.new(1, -100, 0, y - 4))
	button.Activated:Connect(function()
		if claimed or not unlocked then
			return
		end
		if locked then
			local pass = MonetizationConfig.GamePasses.SeasonPass
			if pass.id == 0 then
				hud.Push("⚙️ Configura el ID del Pase en MonetizationConfig", "warn")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
			return
		end
		button.Active = false
		claim(level, track)
	end)
end

function render()
	UI.ClearList(listFrame)
	if not status then
		return
	end

	local head = UI.Card(listFrame, 118, 1)
	UI.Label(head, "🏆 " .. status.name .. " #" .. status.season, UDim2.new(1, -16, 0, 24), UDim2.new(0, 12, 0, 6), UI.Colors.Gold)
	UI.Label(head, "Nivel " .. status.level .. "/" .. status.maxLevel .. " · termina en " .. UI.Time(status.endsIn), UDim2.new(1, -16, 0, 18), UDim2.new(0, 12, 0, 32), UI.Colors.Text, false)
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -24, 0, 14)
	barBg.Position = UDim2.new(0, 12, 0, 56)
	barBg.BackgroundColor3 = UI.Colors.Grey
	barBg.BorderSizePixel = 0
	barBg.Parent = head
	UI.Round(barBg, 7)
	local fill = Instance.new("Frame")
	local ratio = if status.xpNeed > 0 then status.xpInto / status.xpNeed else 1
	fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = UI.Colors.Gold
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	UI.Round(fill, 7)
	local xpText = if status.xpNeed > 0 then (status.xpInto .. " / " .. status.xpNeed .. " XP") else "¡Nivel máximo!"
	UI.Label(head, xpText, UDim2.new(1, -150, 0, 18), UDim2.new(0, 12, 0, 80), UI.Colors.Muted, false)

	local count = claimableCount()
	if count > 0 then
		local all = UI.Button(head, "Reclamar todo (" .. count .. ")", UI.Colors.Green, UDim2.new(0, 130, 0, 30), UDim2.new(1, -142, 1, -38))
		all.Activated:Connect(function()
			all.Active = false
			claim("all", nil)
		end)
	end
	if not status.hasPass then
		local buy = UI.Button(listFrame, "Desbloquear pista premium · R$ " .. MonetizationConfig.GamePasses.SeasonPass.robux, UI.Colors.Blue, UDim2.new(1, -8, 0, 44), UDim2.new(0, 0, 0, 0))
		buy.LayoutOrder = 2
		buy.Activated:Connect(function()
			local pass = MonetizationConfig.GamePasses.SeasonPass
			if pass.id == 0 then
				hud.Push("⚙️ Configura el ID del Pase en MonetizationConfig", "warn")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
	end

	for level = 1, status.maxLevel do
		local key = tostring(level)
		local unlocked = level <= status.level
		local card = UI.Card(listFrame, 92, 10 + level)
		UI.Label(card, "Nivel " .. level .. (if unlocked then "  ✅" else ""), UDim2.new(1, -16, 0, 20), UDim2.new(0, 12, 0, 4), if unlocked then UI.Colors.Gold else UI.Colors.Muted)
		addTrackRow(card, 30, "🆓 ", status.freeRewards[level], level, "free", status.free[key] == true, unlocked, false)
		addTrackRow(card, 62, "⭐ ", status.premiumRewards[level], level, "premium", status.premium[key] == true, unlocked, not status.hasPass)
	end
end

local function refresh()
	local result = statusFn:InvokeServer()
	if result and result.success then
		status = result.status
		updateBadge()
		render()
	end
end

function SeasonController.Init(hudController: any)
	hud = hudController
	local _, list = hud.CreatePanel("Season", "Pase de Temporada", refresh)
	listFrame = list

	local button = hud.CreateActionButton("SeasonButton", "🏆", "Temporada")
	button.Activated:Connect(function()
		hud.TogglePanel("Season")
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

	Net.GetRemoteEvent("SeasonUpdated").OnClientEvent:Connect(function(newStatus)
		status = newStatus
		updateBadge()
		if hud.IsPanelOpen("Season") then
			render()
		end
	end)

	task.spawn(refresh)
end

return SeasonController
