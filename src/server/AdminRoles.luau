-- AdminRoles.luau
-- Persistent non-Developer tiers. Only the server-side Admin module calls this.
local DataStoreService = game:GetService("DataStoreService")

local AdminRoles = {}
local store
local cache = {}

local VALID_ROLES = {
	Admin = true,
	Streamer = true,
}

local function getStore()
	if not store then
		store = DataStoreService:GetDataStore("AdminRoles_v1")
	end
	return store
end

function AdminRoles.getRole(userId: number): string?
	if type(userId) ~= "number" or userId < 1 or userId % 1 ~= 0 then
		return nil
	end
	if cache[userId] ~= nil then
		return cache[userId] ~= false and cache[userId] or nil
	end

	local ok, value = pcall(function()
		return getStore():GetAsync("user_" .. tostring(userId))
	end)
	if not ok then
		warn("[AdminRoles] Could not load role for UserId " .. tostring(userId) .. ": " .. tostring(value))
		return nil -- Fail closed: DataStore errors never grant access.
	end

	local role = if type(value) == "table" and VALID_ROLES[value.role] then value.role else nil
	cache[userId] = role or false
	return role
end

function AdminRoles.setRole(userId: number, role: string, actorUserId: number): (boolean, string)
	if type(userId) ~= "number" or userId < 1 or userId % 1 ~= 0 then
		return false, "UserId must be a positive integer."
	end
	if not VALID_ROLES[role] then
		return false, "Only Admin or Streamer can be assigned through DataStore."
	end

	local ok, result = pcall(function()
		return getStore():UpdateAsync("user_" .. tostring(userId), function()
			return {
				role = role,
				updatedAt = os.time(),
				updatedBy = actorUserId,
			}
		end)
	end)
	if not ok or type(result) ~= "table" or result.role ~= role then
		return false, "Could not persist role: " .. tostring(result)
	end

	cache[userId] = role
	return true, role .. " role saved for UserId " .. tostring(userId) .. "."
end

function AdminRoles.removeRole(userId: number): (boolean, string)
	if type(userId) ~= "number" or userId < 1 or userId % 1 ~= 0 then
		return false, "UserId must be a positive integer."
	end

	local ok, err = pcall(function()
		getStore():RemoveAsync("user_" .. tostring(userId))
	end)
	if not ok then
		return false, "Could not remove role: " .. tostring(err)
	end

	cache[userId] = false
	return true, "Stored role removed for UserId " .. tostring(userId) .. "."
end

return AdminRoles
