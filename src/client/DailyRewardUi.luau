-- DailyRewardUi.luau
-- Daily reward panel and live cooldown/boost status.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local UI = require(script.Parent.UI)

local DailyRewardUi = {}
local player = Players.LocalPlayer

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, secs)
end

function DailyRewardUi.build()
	local content = UI.window("DailyReward", "DAILY BOOST REWARDS", UDim2.fromOffset(440, 390))
	local summary = UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		Text = "Loading reward status...",
		TextColor3 = UI.Palette.text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextWrapped = true,
		Parent = content,
	})

	local schedule = UI.create("Frame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 205),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		UI.create("UIListLayout", { Padding = UDim.new(0, 4) }),
	})

	for day, reward in Config.DailyRewards.Schedule do
		local row = UI.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = UI.Palette.panelLight,
			BackgroundTransparency = 0.15,
			Text = string.format("DAY %d   %s   %d min", day, Config.DailyRewards.BoostNames[reward.key], math.floor(reward.duration / 60)),
			TextColor3 = UI.Palette.text,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Parent = schedule,
		})
		UI.corner(6).Parent = row
	end
	local finalRow = UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = UI.Palette.accent,
		Text = "DAY 7   RANDOM BOOST   10 min",
		TextColor3 = Color3.fromRGB(35, 35, 35),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Parent = schedule,
	})
	UI.corner(6).Parent = finalRow

	local activeLabel = UI.create("TextLabel", {
		Position = UDim2.fromOffset(0, 266),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "Active boosts: none",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		Parent = content,
	})

	local claimButton = UI.button({
		Text = "CLAIM DAILY REWARD",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 310),
		Color = UI.Palette.accent,
		MaxTextSize = 20,
		Parent = content,
	})

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local function refresh()
		local ok, state = pcall(function()
			return remotes.GetDailyRewardState:InvokeServer()
		end)
		if not ok or not state or not state.loaded then
			summary.Text = "Player data is still loading."
			claimButton.Active = false
			return
		end

		local nextName = Config.DailyRewards.BoostNames[state.nextReward] or "Random Boost"
		summary.Text = state.canClaim
			and string.format("Streak: %d days  |  Ready: Day %d - %s", state.streak, state.nextDay, nextName)
			or string.format("Streak: %d days  |  Next claim in %s", state.streak, formatTime(state.nextClaimAt - os.time()))
		claimButton.Text = state.canClaim and "CLAIM DAILY REWARD" or "NOT READY YET"
		claimButton.Active = state.canClaim
		claimButton.AutoButtonColor = state.canClaim
		claimButton.BackgroundColor3 = state.canClaim and UI.Palette.accent or UI.Palette.locked

		local active = {}
		for key, expiresAt in state.activeBoosts do
			table.insert(active, string.format("%s (%s)", Config.DailyRewards.BoostNames[key] or key, formatTime(expiresAt - os.time())))
		end
		activeLabel.Text = #active > 0 and ("Active: " .. table.concat(active, "  |  ")) or "Active boosts: none"
	end

	claimButton.Activated:Connect(function()
		claimButton.Active = false
		remotes.ClaimDailyReward:FireServer()
		task.delay(0.25, refresh)
	end)
	remotes.DailyRewardUpdate.OnClientEvent:Connect(refresh)
	remotes.Notify.OnClientEvent:Connect(function()
		task.delay(0.1, refresh)
	end)
	refresh()
end

return DailyRewardUi
