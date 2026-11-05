--!strict
--[[
	EventService.lua
	Eventos globales temporales (EventConfig). Un solo temporizador del
	servidor decide cuándo empieza/termina cada evento y lo emite a todos.
	Otros Services consultan los multiplicadores activos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local EventService = {}

local eventUpdated = Net.GetRemoteEvent("GlobalEventUpdated")
local notifyEvent = Net.GetRemoteEvent("NotificationPush")

local current: any = nil
local endsAt = 0

local function buildState(): any
	if not current then
		return { active = false }
	end
	return {
		active = true,
		id = current.id,
		displayName = current.displayName,
		description = current.description,
		secondsLeft = math.max(0, endsAt - os.time()),
	}
end

function EventService.GetState(): any
	return buildState()
end

function EventService.PushState(player: Player)
	eventUpdated:FireClient(player, buildState())
end

function EventService.GetMutationMultiplier(weatherTag: string?): number
	if current and weatherTag and current.weatherTag == weatherTag then
		return current.mutationChanceMultiplier
	end
	return 1
end

function EventService.GetSellMultiplier(): number
	if current then
		return current.sellMultiplier
	end
	return 1
end

function EventService.Init()
	task.spawn(function()
		task.wait(EventConfig.FirstEventDelay)
		while true do
			local id = EventConfig.Order[math.random(1, #EventConfig.Order)]
			current = EventConfig.Events[id]
			endsAt = os.time() + EventConfig.DurationSeconds
			eventUpdated:FireAllClients(buildState())
			notifyEvent:FireAllClients({ text = "🎉 " .. current.displayName .. " " .. current.description, kind = "event" })

			task.wait(EventConfig.DurationSeconds)

			current = nil
			eventUpdated:FireAllClients(buildState())
			task.wait(EventConfig.IntervalSeconds)
		end
	end)
end

return EventService
