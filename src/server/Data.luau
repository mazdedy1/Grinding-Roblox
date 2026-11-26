-- Data.luau
-- Persistent player profiles with session locking, guarded loading, autosave,
-- and atomic Developer Product receipt grants.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DATASTORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LOAD_RETRIES = 5
local SESSION_TTL = 180

local DEFAULT_DATA = {
	version = 1,
	power = 0,
	coins = 0,
	coinRemainder = 0,
	rebirths = 0,
	gearLevel = 0,
	receiptIds = {},
}

local Data = {}
local profiles = {}
local sessionTokens = {}
local ephemeralProfiles = {}
local store = nil
local memoryOnly = false

local function deepCopy(source)
	local copy = {}
	for key, value in source do
		copy[key] = if type(value) == "table" then deepCopy(value) else value
	end
	return copy
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function normalize(data)
	if type(data) ~= "table" then
		data = deepCopy(DEFAULT_DATA)
	end
	for key, value in DEFAULT_DATA do
		if data[key] == nil or type(data[key]) ~= type(value) then
			data[key] = deepCopy(value)
		end
	end
	for _, key in { "power", "coins", "rebirths", "gearLevel", "coinRemainder" } do
		local value = data[key]
		if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
			data[key] = DEFAULT_DATA[key]
		end
	end
	data.power = math.floor(data.power)
	data.coins = math.floor(data.coins)
	data.rebirths = math.floor(data.rebirths)
	data.gearLevel = math.clamp(math.floor(data.gearLevel), 0, 100)
	return data
end

local function sync(player: Player)
	local profile = profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	stats.Power.Value = profile.power
	stats.Coins.Value = profile.coins
	stats.Rebirths.Value = profile.rebirths
	player:SetAttribute("GearLevel", profile.gearLevel)
end

local function loadProfile(player: Player)
	local token = game.JobId ~= "" and game.JobId .. ":" .. HttpService:GenerateGUID(false)
		or HttpService:GenerateGUID(false)
	sessionTokens[player] = token

	if memoryOnly or not store then
		if RunService:IsStudio() then
			ephemeralProfiles[player] = true
			return deepCopy(DEFAULT_DATA)
		end
		return nil, "DataStore unavailable"
	end

	for attempt = 1, LOAD_RETRIES do
		local ok, result = pcall(function()
			return store:UpdateAsync(keyFor(player), function(current)
				local now = os.time()
				if type(current) == "table"
					and current._sessionId ~= nil
					and current._sessionId ~= token
					and (tonumber(current._sessionExpiresAt) or 0) > now
				then
					return nil -- another live server owns this profile
				end

				local profile = normalize(current)
				profile._sessionId = token
				profile._sessionExpiresAt = now + SESSION_TTL
				return profile
			end)
		end)

		if ok and type(result) == "table" and result._sessionId == token then
			return normalize(result)
		end
		if not ok then
			warn(`[Data] Profile load attempt {attempt} failed for {player.Name}: {result}`)
		end
		if not player.Parent then
			return nil, "Player left while loading"
		end
		task.wait(math.min(2 ^ attempt, 10))
	end

	-- Only unpublished Studio tests may run without persistence. A live game
	-- must never turn a temporary DataStore outage into a fresh profile.
	if RunService:IsStudio() then
		warn(`[Data] Using temporary Studio profile for {player.Name}; progress will not persist.`)
		ephemeralProfiles[player] = true
		sessionTokens[player] = nil
		return deepCopy(DEFAULT_DATA)
	end
	return nil, "Could not load or lock profile"
end

local function saveProfile(player: Player, releaseSession: boolean?)
	local profile = profiles[player]
	if not profile then
		return true
	end
	if ephemeralProfiles[player] then
		return true
	end
	if memoryOnly or not store then
		return RunService:IsStudio()
	end

	local token = sessionTokens[player]
	if not token then
		warn(`[Data] Refusing to save {player.Name}: missing session token`)
		return false
	end

	local snapshot = deepCopy(profile)
	local ok, result = pcall(function()
		return store:UpdateAsync(keyFor(player), function(current)
			if type(current) ~= "table" or current._sessionId ~= token then
				return nil -- never overwrite a profile owned by another server
			end
			snapshot._sessionId = if releaseSession then nil else token
			snapshot._sessionExpiresAt = if releaseSession then nil else os.time() + SESSION_TTL
			return snapshot
		end)
	end)

	if not ok or type(result) ~= "table" then
		warn(`[Data] Save/lock renewal failed for {player.Name}: {result}`)
		return false
	end
	if releaseSession then
		sessionTokens[player] = nil
	end
	return true
end

local function onPlayerAdded(player: Player)
	local profile, loadError = loadProfile(player)
	if not profile then
		warn(`[Data] Refusing to start {player.Name}: {loadError}`)
		player:Kick("Your data could not be loaded safely. Please rejoin in a moment.")
		return
	end
	if not player.Parent then
		return
	end

	profiles[player] = profile
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, statName in { "Power", "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = stats
	end
	stats.Parent = player
	sync(player)
end

function Data.get(player: Player)
	return profiles[player]
end

function Data.addPower(player: Player, amount: number)
	local profile = profiles[player]
	if profile and type(amount) == "number" and amount > 0 and amount < math.huge then
		profile.power += math.floor(amount)
		sync(player)
	end
end

-- Fractional rewards accumulate instead of rounding every punch upward.
function Data.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile and type(amount) == "number" and amount > 0 and amount < math.huge then
		local total = (profile.coinRemainder or 0) + amount
		local wholeCoins = math.floor(total)
		profile.coinRemainder = total - wholeCoins
		profile.coins += wholeCoins
		sync(player)
	end
end

function Data.grantProductReceipt(player: Player, purchaseId: string, amount: number): boolean
	local profile = profiles[player]
	if not profile or type(purchaseId) ~= "string" or purchaseId == "" then
		return false
	end
	if profile.receiptIds[purchaseId] then
		return true
	end

	if ephemeralProfiles[player] or memoryOnly or not store then
		if not RunService:IsStudio() then
			return false
		end
		profile.receiptIds[purchaseId] = true
		Data.addCoins(player, amount)
		return true
	end

	local token = sessionTokens[player]
	if not token then
		return false
	end

	local ok, updated = pcall(function()
		return store:UpdateAsync(keyFor(player), function(current)
			if type(current) ~= "table" or current._sessionId ~= token then
				return nil
			end
			current = normalize(current)
			if not current.receiptIds[purchaseId] then
				current.receiptIds[purchaseId] = true
				local total = (current.coinRemainder or 0) + amount
				local wholeCoins = math.floor(total)
				current.coinRemainder = total - wholeCoins
				current.coins += wholeCoins
			end
			current._sessionExpiresAt = os.time() + SESSION_TTL
			return current
		end)
	end)

	if not ok or type(updated) ~= "table" or updated._sessionId ~= token then
		warn(`[Data] Could not persist receipt {purchaseId} for {player.Name}: {updated}`)
		return false
	end

	profiles[player] = normalize(updated)
	sync(player)
	return true
end

function Data.trySpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or type(amount) ~= "number" or amount <= 0 or amount % 1 ~= 0 or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	sync(player)
	return true
end

function Data.setGearLevel(player: Player, level: number)
	local profile = profiles[player]
	if profile and type(level) == "number" and level % 1 == 0 and level >= 0 then
		profile.gearLevel = level
		sync(player)
	end
end

function Data.applyRebirth(player: Player)
	local profile = profiles[player]
	if profile then
		profile.power = 0
		profile.coins = 0
		profile.coinRemainder = 0
		profile.gearLevel = 0
		profile.rebirths += 1
		sync(player)
	end
end

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	elseif RunService:IsStudio() then
		memoryOnly = true
		warn("[Data] DataStores unavailable in Studio; using temporary, non-persistent data.")
	else
		warn(`[Data] DataStore initialization failed: {result}`)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, true)
		profiles[player] = nil
		sessionTokens[player] = nil
		ephemeralProfiles[player] = nil
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				saveProfile(player, false)
			end
		end
	end)
end

return Data
