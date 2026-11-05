--!strict
--[[
	LeaderboardService.lua
	  - leaderstats (Cash / Stolen) para la lista nativa de jugadores.
	  - Top global por Cash total ganado usando un OrderedDataStore
	    (si falla o Studio no tiene API habilitada, cae al top del servidor).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local orderedStore = DataStoreService:GetOrderedDataStore("StealAPlant_TotalCash_v1")

local STATS_REFRESH = 3 -- seg: refresco de leaderstats
local PUBLISH_INTERVAL = 60 -- seg: subida al OrderedDataStore
local CACHE_SECONDS = 30

local cache: { entries: { any }, source: string, at: number } = { entries = {}, source = "server", at = 0 }
local nameCache: { [number]: string } = {}

function LeaderboardService.SetupPlayer(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = folder

	local stolen = Instance.new("IntValue")
	stolen.Name = "Stolen"
	stolen.Parent = folder

	folder.Parent = player
end

local function refreshLeaderstats()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.GetProfile(player)
		local folder: any = player:FindFirstChild("leaderstats")
		if profile and folder then
			folder.Cash.Value = math.floor(profile.cash)
			folder.Stolen.Value = profile.stats.plantsStolen
		end
	end
end

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else ("Player" .. userId)
	return nameCache[userId]
end

local function serverTop(): { any }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService.GetProfile(player)
		if profile then
			table.insert(list, { name = player.DisplayName, score = math.floor(profile.totalCashEarned) })
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	for i, entry in ipairs(list) do
		entry.rank = i
	end
	return list
end

function LeaderboardService.GetTop(): (any, string)
	if os.clock() - cache.at < CACHE_SECONDS and #cache.entries > 0 then
		return cache.entries, cache.source
	end

	local ok, page = pcall(function()
		return orderedStore:GetSortedAsync(false, 10):GetCurrentPage()
	end)

	local entries
	local source = "global"
	if ok and #page > 0 then
		entries = {}
		for i, item in ipairs(page) do
			table.insert(entries, { rank = i, name = getName(tonumber(item.key) or 0), score = item.value })
		end
	else
		entries = serverTop()
		source = "server"
	end

	cache = { entries = entries, source = source, at = os.clock() }
	return entries, source
end

function LeaderboardService.Init()
	task.spawn(function()
		local sinceLastPublish = 0
		while true do
			task.wait(STATS_REFRESH)
			refreshLeaderstats()
			sinceLastPublish += STATS_REFRESH
			if sinceLastPublish >= PUBLISH_INTERVAL then
				sinceLastPublish = 0
				for _, player in ipairs(Players:GetPlayers()) do
					local profile = DataService.GetProfile(player)
					if profile and DataService.IsLoaded(player) then
						task.spawn(function()
							pcall(function()
								orderedStore:SetAsync(tostring(player.UserId), math.floor(profile.totalCashEarned))
							end)
						end)
					end
				end
			end
		end
	end)
end

return LeaderboardService
