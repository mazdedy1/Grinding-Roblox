-- AdminModeration.luau
-- Moderation wrapper around Roblox's built-in experience ban API.
local Players = game:GetService("Players")

local Moderation = {}

function Moderation.kick(target: Player, reason: string)
	if not target or not target.Parent then return false, "Player is no longer in this server." end
	target:Kick(string.sub(reason ~= "" and reason or "Removed by moderation.", 1, 300))
	return true, "Kicked " .. target.Name .. "."
end

function Moderation.ban(target: Player, durationSeconds: number, reason: string)
	if not target or not target.Parent then return false, "Target must be online." end
	if not Players.BanningEnabled then
		return false, "Enable Players.BanningEnabled in Studio to use bans."
	end
	local displayReason = string.sub(reason ~= "" and reason or "You are banned from this experience.", 1, 350)
	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { target.UserId },
			Duration = durationSeconds,
			DisplayReason = displayReason,
			PrivateReason = "In-game admin moderation",
			ExcludeAltAccounts = true,
			ApplyToUniverse = true,
		})
	end)
	if not ok then return false, "Ban failed: " .. tostring(err) end
	return true, "Banned " .. target.Name .. "."
end

function Moderation.unban(userId: number)
	if not Players.BanningEnabled then
		return false, "Enable Players.BanningEnabled in Studio to use bans."
	end
	local ok, err = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	if not ok then return false, "Unban failed: " .. tostring(err) end
	return true, "Unban request completed for UserId " .. userId .. "."
end

return Moderation
