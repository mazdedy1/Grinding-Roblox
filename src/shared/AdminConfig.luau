-- AdminConfig.luau
-- Add the experience owner's Roblox UserId before publishing.
local AdminConfig = {}

AdminConfig.OwnerUserIds = {
	-- REQUIRED: add the owner's numeric Roblox UserId here.
}

-- Optional additional staff: [userId] = "HeadAdmin" | "Admin" | "Moderator"
AdminConfig.Staff = {
	-- [123456789] = "Admin",
}

AdminConfig.Roles = {
	Owner = 100,
	HeadAdmin = 80,
	Admin = 60,
	Moderator = 30,
}

AdminConfig.Permissions = {
	players = 30,
	moderation = 30,
	events = 60,
	economy = 60,
	announce = 30,
}

AdminConfig.MaxGrant = 1000000000
AdminConfig.MaxEventMinutes = 60
AdminConfig.LogLimit = 100

return AdminConfig
