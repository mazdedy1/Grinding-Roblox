-- AdminEvents.luau
-- Server-local, time-limited events. Event multipliers are attributes, not
-- permanent player boosts, and apply to players who join while an event runs.
local Players = game:GetService("Players")

local AdminEvents = {}
local activeEvent = nil
local eventToken = 0

local PRESETS = {
	megagrind = { name = "MEGA GRIND", training = 2, coins = 1, damage = 1 },
	coinrush = { name = "COIN RUSH", training = 1, coins = 2, damage = 1 },
	damagefrenzy = { name = "DAMAGE FRENZY", training = 1, coins = 1, damage = 2 },
	superhour = { name = "SUPER GRIND", training = 2, coins = 2, damage = 2 },
}

local function apply(player)
	local event = activeEvent
	player:SetAttribute("Event_TrainingMultiplier", event and event.training or 1)
	player:SetAttribute("Event_CoinMultiplier", event and event.coins or 1)
	player:SetAttribute("Event_DamageMultiplier", event and event.damage or 1)
	player:SetAttribute("ActiveAdminEvent", event and event.name or "")
end

local function broadcast(message)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("AdminEventNotice", message)
	end
end

function AdminEvents.start(name: string, durationSeconds: number)
	local preset = PRESETS[string.lower(name)]
	if not preset then
		return false, "Unknown event preset."
	end
	if type(durationSeconds) ~= "number" or durationSeconds < 60 or durationSeconds > 3600 then
		return false, "Event duration must be 1-60 minutes."
	end

	eventToken += 1
	local token = eventToken
	activeEvent = {
		name = preset.name,
		training = preset.training,
		coins = preset.coins,
		damage = preset.damage,
		endsAt = os.time() + math.floor(durationSeconds),
	}
	for _, player in Players:GetPlayers() do apply(player) end
	broadcast(preset.name .. " started!")
	task.delay(durationSeconds, function()
		if eventToken == token and activeEvent then
			AdminEvents.stop("Event duration ended.")
		end
	end)
	return true, preset.name .. " started for " .. math.floor(durationSeconds / 60) .. " minute(s)."
end

function AdminEvents.stop(reason: string?)
	if not activeEvent then
		return false, "No event is active."
	end
	activeEvent = nil
	eventToken += 1
	for _, player in Players:GetPlayers() do apply(player) end
	broadcast(reason or "Admin event ended.")
	return true, "Event stopped."
end

function AdminEvents.getState()
	if not activeEvent then return nil end
	return {
		name = activeEvent.name,
		training = activeEvent.training,
		coins = activeEvent.coins,
		damage = activeEvent.damage,
		endsAt = activeEvent.endsAt,
	}
end

function AdminEvents.startService()
	Players.PlayerAdded:Connect(function(player)
		task.defer(apply, player)
	end)
	for _, player in Players:GetPlayers() do apply(player) end
end

return AdminEvents
