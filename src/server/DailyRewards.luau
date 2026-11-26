-- DailyRewards.luau
-- Server-authoritative 7-day rotating boost rewards. Claim timestamps and active
-- boost expiries are stored in the player's persistent profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DailyRewards = {}
local Data
local rng = Random.new()

local function rewardForDay(day: number)
	if day == 7 then
		local choices = { "DoubleTraining", "DoubleDamage", "DoubleCoins" }
		return choices[rng:NextInteger(1, #choices)], Config.DailyRewards.FinalDuration
	end
	local reward = Config.DailyRewards.Schedule[day]
	return reward.key, reward.duration
end

local function buildState(player: Player)
	local profile = Data.get(player)
	if not profile then
		return { loaded = false }
	end

	local now = os.time()
	local lastClaim = profile.dailyReward.lastClaimAt
	local streak = profile.dailyReward.streak
	if lastClaim > 0 and now - lastClaim >= Config.DailyRewards.StreakResetAfter then
		streak = 0
	end
	local day = (streak % 7) + 1
	local canClaim = lastClaim == 0 or now - lastClaim >= Config.DailyRewards.ClaimCooldown
	local rewardKey, duration = rewardForDay(day)

	local active = {}
	for key, expiresAt in profile.activeBoosts do
		if type(expiresAt) == "number" and expiresAt > now then
			active[key] = expiresAt
		end
	end

	return {
		loaded = true,
		canClaim = canClaim,
		streak = streak,
		nextDay = day,
		nextReward = rewardKey,
		nextDuration = duration,
		nextClaimAt = if canClaim then now else lastClaim + Config.DailyRewards.ClaimCooldown,
		activeBoosts = active,
	}
end

function DailyRewards.start(dataService)
	Data = dataService
	local remotes = ReplicatedStorage.Remotes
	local getState = remotes:WaitForChild("GetDailyRewardState")
	local claim = remotes:WaitForChild("ClaimDailyReward")

	getState.OnServerInvoke = function(player)
		return buildState(player)
	end

	claim.OnServerEvent:Connect(function(player)
		local profile = Data.get(player)
		if not profile then
			return
		end

		local state = buildState(player)
		if not state.loaded or not state.canClaim then
			remotes.Notify:FireClient(player, "error", "Daily reward is not ready yet.")
			return
		end

		local rewardKey, duration = state.nextReward, state.nextDuration
		Data.addBoost(player, rewardKey, duration)
		Data.setDailyReward(player, os.time(), state.nextDay)
		remotes.Notify:FireClient(player, "success", ("Day %d reward: %s for %d minutes!"):format(
			state.nextDay,
			Config.DailyRewards.BoostNames[rewardKey],
			math.floor(duration / 60)
		))
		remotes.DailyRewardUpdate:FireClient(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			if Data.get(player) then
				remotes.DailyRewardUpdate:FireClient(player)
			end
		end)
	end)
end

return DailyRewards
