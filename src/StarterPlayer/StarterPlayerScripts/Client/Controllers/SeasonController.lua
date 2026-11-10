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

local function promptPass()
	local pass = MonetizationConfig.GamePasses.SeasonPass
	if pass.id == 0 then
		hud.Push("⚙️ Configura el ID del Pase en MonetizationConfig", "warn")
	else
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	end
end

-- Una pista (gratis o premium) dentro de la tarjeta de un nivel.
local function addTrack(card: Frame, y: number, height: number, icon: string, reward: any, level: number, track: string, claimed: boolean, unlocked: boolean, locked: boolean)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, -12, 0, height)
	box.Position = UDim2.new(0, 6, 0, y)
	box.BackgroundColor3 = if track == "premium" then Color3.fromRGB(235, 218, 255) else Color3.fromRGB(226, 238, 205)
	box.BorderSizePixel = 0
	box.ZIndex = card.ZIndex + 1
	box.Parent = card
	UI.Round(box, 8)
	local title = UI.Label(box, icon, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 2), UI.Colors.Muted, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local text = UI.Label(box, rewardText(reward), UDim2.new(1, -10, 0, height - 56), UDim2.new(0, 5, 0, 20), if locked then UI.Colors.Muted else UI.Colors.Text, false)
	text.TextWrapped = true
	text.TextScaled = false
	text.TextSize = 12
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextXAlignment = Enum.TextXAlignment.Center
	local label = if claimed then "✔" elseif locked then "🔒" elseif unlocked then "Reclamar" else "…"
	local color = if unlocked and not claimed and not locked then UI.Colors.Green else UI.Colors.Grey
	local button = UI.Button(box, label, color, UDim2.new(1, -12, 0, 30), UDim2.new(0, 6, 1, -34))
	button.TextSize = 13
	button.Activated:Connect(function()
		if claimed then
			return
		end
		if locked then
			promptPass()
			return
		end
		if not unlocked then
			hud.Push("Sube de nivel para reclamarlo", "info")
			return
		end
		button.Active = false
		claim(level, track)
	end)
end

local headFrame: Frame

function render()
	UI.ClearList(listFrame)
	UI.ClearList(headFrame)
	if not status then
		return
	end

	UI.Label(headFrame, "🏆 " .. status.name .. " #" .. status.season, UDim2.new(1, -170, 0, 24), UDim2.new(0, 10, 0, 4), UI.Colors.Gold)
	UI.Label(headFrame, "Nivel " .. status.level .. "/" .. status.maxLevel .. " · termina en " .. UI.Time(status.endsIn), UDim2.new(1, -170, 0, 18), UDim2.new(0, 10, 0, 28), UI.Colors.Text, false)
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 14)
	barBg.Position = UDim2.new(0, 10, 0, 52)
	barBg.BackgroundColor3 = UI.Colors.Grey
	barBg.BorderSizePixel = 0
	barBg.ZIndex = headFrame.ZIndex + 1
	barBg.Parent = headFrame
	UI.Round(barBg, 7)
	local fill = Instance.new("Frame")
	local ratio = if status.xpNeed > 0 then status.xpInto / status.xpNeed else 1
	fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = UI.Colors.Gold
	fill.BorderSizePixel = 0
	fill.ZIndex = barBg.ZIndex + 1
	fill.Parent = barBg
	UI.Round(fill, 7)
	local xpText = if status.xpNeed > 0 then (status.xpInto .. " / " .. status.xpNeed .. " XP") else "¡Nivel máximo!"
	UI.Label(headFrame, xpText, UDim2.new(0.5, 0, 0, 18), UDim2.new(0, 10, 0, 70), UI.Colors.Muted, false)

	local count = claimableCount()
	if count > 0 then
		local all = UI.Button(headFrame, "Reclamar (" .. count .. ")", UI.Colors.Green, UDim2.new(0, 150, 0, 32), UDim2.new(1, -160, 0, 6))
		all.Activated:Connect(function()
			all.Active = false
			claim("all", nil)
		end)
	elseif not status.hasPass then
		local buy = UI.Button(headFrame, "⭐ Premium R$ " .. MonetizationConfig.GamePasses.SeasonPass.robux, UI.Colors.Blue, UDim2.new(0, 150, 0, 32), UDim2.new(1, -160, 0, 6))
		buy.TextSize = 12
		buy.Activated:Connect(promptPass)
	end

	-- Niveles de lado a lado: se desliza horizontalmente.
	for level = 1, status.maxLevel do
		local key = tostring(level)
		local unlocked = level <= status.level
		local card = UI.Card(listFrame, 230, level)
		card.Size = UDim2.fromOffset(132, 230)
		card.BorderColor3 = if level == status.level then UI.Colors.Gold else Color3.fromRGB(112, 78, 43)
		local head = UI.Label(card, "Nivel " .. level .. (if unlocked then " ✅" else ""), UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 4), if unlocked then UI.Colors.Gold else UI.Colors.Muted, true)
		head.TextXAlignment = Enum.TextXAlignment.Center
		addTrack(card, 28, 94, "🆓 GRATIS", status.freeRewards[level], level, "free", status.free[key] == true, unlocked, false)
		addTrack(card, 128, 98, "⭐ PREMIUM", status.premiumRewards[level], level, "premium", status.premium[key] == true, unlocked, not status.hasPass)
	end
	task.defer(function()
		listFrame.CanvasPosition = Vector2.new(math.max(0, (status.level - 2) * 140), 0)
	end)
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
	local frame, list = hud.CreatePanel("Season", "Pase de Temporada", refresh)
	listFrame = list
	headFrame = Instance.new("Frame")
	headFrame.Name = "SeasonHead"
	headFrame.BackgroundColor3 = UI.Colors.Card
	headFrame.BorderSizePixel = 3
	headFrame.BorderColor3 = Color3.fromRGB(112, 78, 43)
	headFrame.Position = UDim2.new(0, 8, 0, 62)
	headFrame.Size = UDim2.new(1, -16, 0, 96)
	headFrame.ZIndex = frame.ZIndex + 2
	headFrame.Parent = frame
	UI.UseRow(list, 8)
	list.Position = UDim2.new(0, 8, 0, 168)
	list.Size = UDim2.new(1, -16, 1, -176)
	list.ScrollingDirection = Enum.ScrollingDirection.XY
	list.AutomaticCanvasSize = Enum.AutomaticSize.XY

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
