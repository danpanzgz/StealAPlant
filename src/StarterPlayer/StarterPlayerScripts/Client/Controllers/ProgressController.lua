--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefenseConfig = require(ReplicatedStorage.Shared.Config.DefenseConfig)
local DailyConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Client = script.Parent.Parent
local UI = require(Client.Modules.UIFactory)
local ProgressController = {}

local function clear(content: ScrollingFrame)
	for _, child in ipairs(content:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
end

function ProgressController.Init(snapshot: any, hud: any)
	local dailyFn = Net.GetRemoteFunction("ClaimDailyReward")
	local questFn = Net.GetRemoteFunction("ClaimQuestReward")
	local defenseFn = Net.GetRemoteFunction("PlaceDefense")
	local quests = snapshot.quests or {}

	local dailyShade, dailyContent = UI.Panel(hud.GetScreenGui(), "DailyPanel", "Daily Harvest", "Come back each day to extend your reward streak.")
	local function drawDaily()
		clear(dailyContent)
		local status = snapshot.daily or {}
		for day, reward in ipairs(DailyConfig.Rewards) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -12, 0, 48); row.BackgroundColor3 = day <= (status.streak or 0) and UI.Colors.PrimaryDark or UI.Colors.Canvas; row.Parent = dailyContent
			UI.Corner(row, 9)
			local label = UI.Label(row, "DAY " .. day, UDim2.fromOffset(82, 30), UDim2.fromOffset(14, 9), 13, UI.Colors.Muted); label.Font = Enum.Font.GothamBold
			local rewardLabel = UI.Label(row, "+" .. reward .. " Cash", UDim2.new(1, -120, 0, 30), UDim2.fromOffset(95, 9), 16, UI.Colors.Gold); rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
		end
		local claim = UI.Button(dailyContent, "Claim", status.canClaim and "Claim today's reward" or "Reward already claimed", status.canClaim and UI.Colors.Primary or UI.Colors.PanelLight)
		claim.Size = UDim2.new(1, -12, 0, 50)
		claim.Active = status.canClaim == true
		claim.Activated:Connect(function()
			local r = dailyFn:InvokeServer()
			if r and r.success then
				status.canClaim, status.streak = false, r.data.streak
				drawDaily()
			else hud.ShowNotification("Daily reward: " .. ((r and r.reason) or "error"), UI.Colors.Danger) end
		end)
	end
	drawDaily()
	hud.CreateActionButton("DailyButton", "🎁", "Daily").Activated:Connect(function() dailyShade.Visible = true end)

	local questShade, questContent = UI.Panel(hud.GetScreenGui(), "QuestPanel", "Garden Goals", "Complete goals before the daily reset to collect Cash.")
	local function drawQuests()
		clear(questContent)
		for _, q in ipairs(quests) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -12, 0, 94); row.BackgroundColor3 = UI.Colors.Canvas; row.Parent = questContent; UI.Corner(row, 10)
			local title = UI.Label(row, q.title, UDim2.new(1, -120, 0, 28), UDim2.fromOffset(14, 10), 16); title.Font, title.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Left
			local progress = UI.Label(row, q.progress .. " / " .. q.target .. " · Reward " .. q.reward, UDim2.new(1, -120, 0, 20), UDim2.fromOffset(14, 39), 13, UI.Colors.Muted); progress.TextXAlignment = Enum.TextXAlignment.Left
			local fill = Instance.new("Frame")
			fill.Size, fill.Position, fill.BackgroundColor3 = UDim2.new(math.clamp(q.progress / q.target, 0, 1), 0, 0, 5), UDim2.new(0, 14, 1, -16), UI.Colors.Primary; fill.Parent = row; UI.Corner(fill, 4)
			if q.progress >= q.target and not q.claimed then
				local claim = UI.Button(row, "Claim", "Claim", UI.Colors.Gold)
				claim.Size, claim.Position = UDim2.fromOffset(88, 38), UDim2.new(1, -101, 0.5, -19)
				claim.Activated:Connect(function()
					local r = questFn:InvokeServer(q.id)
					if r and r.success then q.claimed = true; hud.ShowNotification("Quest complete: +" .. r.reward .. " Cash", UI.Colors.Primary); drawQuests() end
				end)
			elseif q.claimed then
				local done = UI.Label(row, "CLAIMED", UDim2.fromOffset(90, 30), UDim2.new(1, -104, 0.5, -15), 12, UI.Colors.Primary); done.Font = Enum.Font.GothamBold
			end
		end
	end
	drawQuests()
	hud.CreateActionButton("QuestButton", "📋", "Goals").Activated:Connect(function() drawQuests(); questShade.Visible = true end)

	local defenseShade, defenseContent = UI.Panel(hud.GetScreenGui(), "DefensePanel", "Garden Defenses", "Defenses reduce a thief's chance of success. Your garden level controls slots.")
	for _, id in ipairs(DefenseConfig.Order) do
		local defense = DefenseConfig[id]
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 78); row.BackgroundColor3 = UI.Colors.Canvas; row.Parent = defenseContent; UI.Corner(row, 10); UI.Stroke(row, defense.color, 0.35)
		local name = UI.Label(row, defense.displayName, UDim2.new(1, -135, 0, 28), UDim2.fromOffset(14, 9), 16); name.Font, name.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Left
		local info = UI.Label(row, "−" .. math.floor(defense.successReduction * 100) .. "% steal chance", UDim2.new(1, -135, 0, 21), UDim2.fromOffset(14, 38), 13, defense.color); info.TextXAlignment = Enum.TextXAlignment.Left
		local buy = UI.Button(row, "Buy", "$" .. defense.price, UI.Colors.PrimaryDark)
		buy.Size, buy.Position = UDim2.fromOffset(92, 42), UDim2.new(1, -106, 0.5, -21)
		buy.Activated:Connect(function()
			local r = defenseFn:InvokeServer(id)
			if r and r.success then hud.ShowNotification("Defense placed: " .. defense.displayName, UI.Colors.Primary)
			else hud.ShowNotification("Defense: " .. ((r and r.reason) or "error"), UI.Colors.Danger) end
		end)
	end
	hud.CreateActionButton("DefenseButton", "🛡", "Guard").Activated:Connect(function() defenseShade.Visible = true end)

	Net.GetRemoteEvent("QuestUpdated").OnClientEvent:Connect(function(update)
		for _, q in ipairs(quests) do
			if q.id == update.id then
				q.progress = update.progress or q.progress; q.claimed = update.claimed or q.claimed
				if q.progress >= q.target and not q.claimed then hud.ShowNotification("Goal ready: " .. q.title, UI.Colors.Gold) end
			end
		end
	end)
end

return ProgressController
