-- AdminConfig.luau
-- Shared, non-secret tier policy. Developer identities are hardcoded only in
-- the server-only Admin module, never replicated to clients.

local AdminConfig = {}

AdminConfig.Roles = {
	Developer = "Developer",
	Admin = "Admin",
	Streamer = "Streamer",
}

AdminConfig.Permissions = {
	players = { Developer = true, Admin = true },
	moderation = { Developer = true, Admin = true },
	events = { Developer = true, Admin = true },
	announce = { Developer = true, Admin = true },
	economy = { Developer = true },
	roles = { Developer = true },
}

AdminConfig.MaxGrant = 1000000000
AdminConfig.MaxEventMinutes = 60
AdminConfig.LogLimit = 100

return AdminConfig
