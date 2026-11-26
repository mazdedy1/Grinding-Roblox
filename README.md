# 👊 Power Punch Simulator

A complete Roblox clicker/simulator game built **100% in code** — the map, the UI, the economy, everything is generated from Luau source. No manual Studio editing. Managed with [Rojo](https://rojo.space) so the whole game lives in this repo.

[![CI](https://github.com/LILRINO71/power-punch-simulator/actions/workflows/ci.yml/badge.svg)](https://github.com/LILRINO71/power-punch-simulator/actions/workflows/ci.yml)

## The game

Punch to gain **Power** 💪 and **Coins** 🪙 → buy gear that multiplies your punches → unlock stronger training zones (Beach → City → Volcano → Space) → **Rebirth** to reset with a permanent multiplier → climb the cross-server current-Power leaderboard.

- **4 unlockable zones + a VIP island**, procedurally built by [MapBuilder](src/server/MapBuilder.luau) from [Config](src/shared/Config.luau)
- **6 gear tiers** (Foam Gloves → Void Knuckles, up to x200)
- **Rebirth system** with exponential cost scaling and permanent bonuses
- **Persistent data** (DataStore retries, session locking, guarded loading, autosave, and temporary Studio fallback)
- **Global top-10 current-Power leaderboard** on a physical board (OrderedDataStore)
- **Daily boost rewards**: 7-day streak with temporary 2x Training, 2x Damage, and 2x Coins boosts; persistent cooldowns and expiries
- **Combat**: server-validated Training Dummy with health, attack cooldown, and temporary damage boosts
- **Three-tier custom admin**: hardcoded Developer tier with economy tools, DataStore-backed Admin tier without economy access, and DataStore-backed Streamer tier with a free overhead nametag
- **Admin events**: timed server-local multipliers, announcements, moderation, role assignment, and in-memory audit log
- **Monetization**: 4 gamepasses (2x Power, 2x Coins, Auto Train, VIP Island) + 3 coin-pack developer products
- **Server-authoritative everywhere**: punch rate limiting, zone bonuses validated against real position + power, all purchases granted server-side

## Architecture

```
src/
├── shared/
│   ├── Config.luau
│   ├── AdminConfig.luau       # shared tier permission policy (no Developer IDs)
│   └── Formulas.luau
├── server/
│   ├── init.server.luau
│   ├── Data.luau
│   ├── Training.luau
│   ├── Combat.luau
│   ├── DailyRewards.luau
│   ├── Admin.luau             # hardcoded Developer IDs + server-side command router
│   ├── AdminRoles.luau        # DataStore-backed Admin / Streamer assignments
│   ├── StreamerNametag.luau   # free STREAMER overhead nametag
│   ├── AdminEvents.luau
│   ├── AdminModeration.luau
│   ├── Shop.luau
│   ├── Monetization.luau
│   ├── MapBuilder.luau
│   └── GlobalLeaderboard.luau
└── client/
    ├── init.client.luau
    ├── UI.luau
    ├── Hud.luau
    ├── AdminUi.luau
    ├── ShopUi.luau
    ├── RebirthUi.luau
    ├── DailyRewardUi.luau
    ├── Effects.luau
    └── ZoneGates.luau
```

**Security model:** the client is only ever a *view*. It fires intent and renders replicated state. The server checks every admin permission and every gameplay action. Developer IDs are held in a server-only script. Admin and Streamer role assignments are loaded from a separate DataStore; DataStore failures fail closed and never grant a role.

## Run it locally

1. Install [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (or use `tools/rojo.exe` if present)
2. Build the place file:
   ```
   rojo build default.project.json -o build/PowerPunchSimulator.rbxl
   ```
3. Open the `.rbxl` in Studio and hit **Play**

For live-sync development instead: `rojo plugin install` once, then `rojo serve` and connect from Studio's Rojo plugin.

> DataStores require a published experience and API Services enabled for Studio tests. Studio fallback player data is temporary.

## Admin tiers and commands

### Tiers

| Tier | Assignment | Access |
|---|---|---|
| Developer | Numeric UserId hardcoded in server-only `src/server/Admin.luau` | All admin features, including Power and Coins grants |
| Admin | Stored in `AdminRoles_v1` DataStore | Player tools, moderation, events, boosts, announcements; no economy commands |
| Streamer / Content Creator | Stored in `AdminRoles_v1` DataStore | Free overhead `STREAMER` nametag only |

The Developer allowlist currently contains UserId `10522335269` (`rajabarongz`), based on the account screenshot supplied for this setup. To add another Developer, edit `DEVELOPER_USER_IDS` in the server-only `Admin.luau`; do not put Developer IDs in replicated shared config.

Only a Developer can assign or revoke DataStore-backed tiers:
- `grantrole <numericUserId> admin`
- `grantrole <numericUserId> streamer`
- `revokerole <numericUserId>`

Admin commands:
- `help`, `players`
- `event start <megagrind|coinrush|damagefrenzy|superhour> <minutes>`, `event stop`
- `boost all <training|coins|damage> <1x-5x> <minutes>`, `boost stop`
- `announce <message>`
- `kick <player> <reason>`, `ban <player> <minutes> <reason>`, `unban <userId>`
- `tp <player>`

Developer-only economy commands:
- `givepower <player> <amount>`
- `givecoins <player> <amount>`

In Roblox Studio, enable Studio Access to API Services for DataStore-backed Admin/Streamer roles. For ban/unban, enable `Players.BanningEnabled` in the Players service properties. Role assignment is persistent; players already in another server may need to rejoin before that server sees a changed role. Events apply to the current server only, expire automatically, and do not alter saved player boost data. Audit entries are held in server memory and reset when that server closes.

## Enabling monetization

1. Publish the game (File → Publish to Roblox)
2. Creator Dashboard → your experience → **Monetization**:
   - Create 4 **Passes**: 2x Power (199 R$), 2x Coins (199 R$), Auto Train (349 R$), VIP (499 R$)
   - Create 3 **Developer Products**: 25K Coins (49 R$), 150K Coins (199 R$), 1M Coins (799 R$)
3. Paste the IDs into `Config.GamePasses` / `Config.DevProducts` in [Config.luau](src/shared/Config.luau)
4. Game Settings → Security → enable **Studio Access to API Services** (for DataStores in Studio)

Items with an ID of `0` are hidden from the shop automatically, so the game is fully playable before this step.

## Roadmap

- [ ] Pets: hatch from eggs, equip for multipliers (the big retention + monetization system)
- [x] Daily rewards with temporary boosts
- [ ] Playtime prizes
- [ ] Trails/aura cosmetics for big rebirth milestones
- [ ] Quests ("punch 1,000 times in the Volcano")
- [ ] Publish via Open Cloud from CI (push-to-deploy)
