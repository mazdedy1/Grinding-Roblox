-- Admin.luau
-- Server-authoritative custom admin command router, permission checks and audit log.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.AdminConfig)
local AdminEvents = require(script.Parent.AdminEvents)
local Moderation = require(script.Parent.AdminModeration)

local Admin = {}
local Data
local remote
local logs = {}
local lastCommand = {}

local function roleFor(player: Player): string?
	for _, userId in Config.OwnerUserIds do
		if player.UserId == userId then return "Owner" end
	end
	return Config.Staff[player.UserId]
end

local function levelFor(role: string?): number
	return role and (Config.Roles[role] or 0) or 0
end

local function hasPermission(player: Player, permission: string): boolean
	local role = roleFor(player)
	return role ~= nil and levelFor(role) >= (Config.Permissions[permission] or math.huge)
end

local function log(actor: Player, command: string, result: string)
	table.insert(logs, 1, {
		at = os.time(),
		actor = actor.Name,
		userId = actor.UserId,
		command = string.sub(command, 1, 180),
		result = string.sub(result, 1, 180),
	})
	while #logs > Config.LogLimit do table.remove(logs) end
end

local function reply(player: Player, message: string, success: boolean?)
	remote:FireClient(player, "result", message, success ~= false)
end

local function findPlayer(query: string): Player?
	local lowered = string.lower(query)
	for _, candidate in Players:GetPlayers() do
		if string.lower(candidate.Name) == lowered or string.lower(candidate.DisplayName) == lowered then
			return candidate
		end
	end
	for _, candidate in Players:GetPlayers() do
		if string.sub(string.lower(candidate.Name), 1, #lowered) == lowered then
			return candidate
		end
	end
	return nil
end

local function execute(player: Player, raw: string)
	if type(raw) ~= "string" or #raw > 300 then return end
	local role = roleFor(player)
	if not role then return end
	local now = os.clock()
	if now - (lastCommand[player] or 0) < 0.35 then return end
	lastCommand[player] = now

	local command = string.match(raw, "^%s*(.-)%s*$") or ""
	if command == "" then return end
	command = string.gsub(command, "%s+", " ")
	local parts = string.split(command, " ")
	local verb = string.lower(parts[1] or "")
	local requiredPermission = ({
		players = "players", tp = "players",
		event = "events", boost = "events",
		announce = "announce",
		kick = "moderation", ban = "moderation", unban = "moderation",
		givepower = "economy", givecoins = "economy",
	})[verb]
	if requiredPermission and not hasPermission(player, requiredPermission) then
		log(player, command, "Permission denied.")
		reply(player, "Your role cannot use this command.", false)
		return
	end
	local ok, message = false, "Unknown command."
	local permission = nil

	if verb == "help" then
		ok = true
		message = "Commands: players | event start <megagrind|coinrush|damagefrenzy|superhour> <minutes> | event stop | announce <message> | kick <player> <reason> | ban <player> <minutes> <reason> | unban <userId> | givepower/givecoins <player> <amount> | tp <player>"
	elseif verb == "players" then
		permission = "players"
		local names = {}
		for _, target in Players:GetPlayers() do table.insert(names, target.Name) end
		ok, message = true, "Online: " .. table.concat(names, ", ")
	elseif verb == "event" then
		permission = "events"
		if string.lower(parts[2] or "") == "stop" then
			ok, message = AdminEvents.stop("Admin ended the event.")
		elseif string.lower(parts[2] or "") == "start" then
			local minutes = tonumber(parts[4])
			if minutes and minutes % 1 == 0 and minutes >= 1 and minutes <= Config.MaxEventMinutes then
				ok, message = AdminEvents.start(parts[3] or "", minutes * 60)
			else
				message = "Usage: event start <preset> <minutes 1-60>"
			end
		else
			message = "Usage: event start <preset> <minutes> OR event stop"
		end
	elseif verb == "boost" then
		permission = "events"
		if string.lower(parts[2] or "") == "stop" then
			ok, message = AdminEvents.stop("Admin ended the boost event.")
		elseif string.lower(parts[2] or "") == "all" then
			local kind = string.lower(parts[3] or "")
			local multiplierText = string.lower(parts[4] or "")
			local multiplier = tonumber(string.gsub(multiplierText, "x", ""))
			local durationText = string.lower(parts[5] or "")
			local minutes = tonumber(string.match(durationText, "^(%d+)m$")) or tonumber(durationText)
			if (kind == "training" or kind == "coins" or kind == "damage")
				and multiplier and multiplier % 1 == 0 and multiplier >= 1 and multiplier <= 5
				and minutes and minutes % 1 == 0 and minutes >= 1 and minutes <= Config.MaxEventMinutes then
				local training = if kind == "training" then multiplier else 1
				local coins = if kind == "coins" then multiplier else 1
				local damage = if kind == "damage" then multiplier else 1
				ok, message = AdminEvents.startCustom(string.upper(kind) .. " BOOST", training, coins, damage, minutes * 60)
			else
				message = "Usage: boost all <training|coins|damage> <1x-5x> <minutes>"
			end
		else
			message = "Usage: boost all <training|coins|damage> <1x-5x> <minutes> OR boost stop"
		end
	elseif verb == "announce" then
		permission = "announce"
		local announcement = string.sub(command, 10, 300)
		if announcement ~= "" then
			for _, target in Players:GetPlayers() do
				target:SetAttribute("AdminAnnouncement", announcement)
			end
			ok, message = true, "Announcement sent."
		else message = "Usage: announce <message>" end
	elseif verb == "kick" or verb == "ban" then
		permission = "moderation"
		local target = findPlayer(parts[2] or "")
		local reasonStart = if verb == "ban" then 4 else 3
		local reason = table.concat(parts, " ", reasonStart)
		if not target then
			message = "Player not found. Target must be online."
		elseif target == player then
			message = "You cannot moderate yourself."
		elseif levelFor(roleFor(target)) >= levelFor(role) then
			message = "You cannot moderate an equal or higher role."
		elseif verb == "kick" then
			ok, message = Moderation.kick(target, reason)
		else
			local minutes = tonumber(parts[3])
			if minutes and minutes % 1 == 0 and minutes >= 1 and minutes <= 525600 then
				ok, message = Moderation.ban(target, minutes * 60, reason)
			else message = "Usage: ban <player> <minutes> <reason>" end
		end
	elseif verb == "unban" then
		permission = "moderation"
		local userId = tonumber(parts[2])
		if userId and userId > 0 and userId % 1 == 0 then
			ok, message = Moderation.unban(userId)
		else message = "Usage: unban <numericUserId>" end
	elseif verb == "givepower" or verb == "givecoins" then
		permission = "economy"
		local target = findPlayer(parts[2] or "")
		local amount = tonumber(parts[3])
		if not target then message = "Player not found."
		elseif not amount or amount % 1 ~= 0 or amount < 1 or amount > Config.MaxGrant then
			message = "Amount must be an integer from 1 to " .. Config.MaxGrant .. "."
		else
			ok = Data.adminGrant(target, if verb == "givepower" then "power" else "coins", amount)
			message = if ok then "Granted " .. tostring(amount) .. " to " .. target.Name .. "." else "Could not update player data."
		end
	elseif verb == "tp" then
		permission = "players"
		local target = findPlayer(parts[2] or "")
		local character = player.Character
		local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if targetRoot and root then
			root.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
			ok, message = true, "Teleported to " .. target.Name .. "."
		else message = "Target or your character is unavailable." end
	end

	log(player, command, message)
	reply(player, message, ok)
end

function Admin.start(dataService)
	Data = dataService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remote = remotes:WaitForChild("AdminRequest")
	AdminEvents.startService()

	local function setup(player: Player)
		local role = roleFor(player)
		player:SetAttribute("IsAdmin", role ~= nil)
		player:SetAttribute("AdminRole", role or "")
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do setup(player) end

	remote.OnServerEvent:Connect(function(player, action, payload)
		if type(action) ~= "string" then return end
		if action == "command" then
			execute(player, payload)
		elseif action == "state" and roleFor(player) then
			remote:FireClient(player, "state", {
				role = roleFor(player),
				players = (function()
					local list = {}
					for _, target in Players:GetPlayers() do
						table.insert(list, { name = target.Name, displayName = target.DisplayName, userId = target.UserId })
					end
					return list
				end)(),
				event = AdminEvents.getState(),
				logs = logs,
			})
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
end

return Admin
