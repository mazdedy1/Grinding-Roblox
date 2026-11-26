-- Formulas.luau
-- Pure functions shared by the server (authoritative math) and the client.

local Config = require(script.Parent.Config)

local Formulas = {}

function Formulas.gearMultiplier(gearLevel: number): number
	if gearLevel <= 0 then
		return 1
	end
	local gear = Config.Gear[math.min(gearLevel, #Config.Gear)]
	return gear.multiplier
end

function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + math.max(0, rebirths) * Config.Rebirth.BonusPerRebirth
end

function Formulas.powerPerPunch(state): number
	local amount = Config.Training.BasePowerPerPunch
		* Formulas.gearMultiplier(state.gearLevel)
		* Formulas.rebirthMultiplier(state.rebirths)
		* (state.zoneMultiplier or 1)
		* (state.eventMultiplier or 1)
	if state.hasDoublePower or state.hasDoubleTraining then
		amount *= 2
	end
	if amount ~= amount or amount == math.huge then
		return 9_000_000_000_000_000
	end
	return math.clamp(math.floor(amount + 0.5), 1, 9_000_000_000_000_000)
end

function Formulas.damagePerHit(state): number
	local amount = Config.Combat.BaseDamage
		* Formulas.gearMultiplier(state.gearLevel)
		* Formulas.rebirthMultiplier(state.rebirths)
	if state.hasDoubleDamage then
		amount *= 2
	end
	amount *= (state.eventMultiplier or 1)
	if amount ~= amount or amount == math.huge then
		return 9_000_000_000_000_000
	end
	return math.clamp(math.floor(amount + 0.5), 1, 9_000_000_000_000_000)
end

function Formulas.coinsForPower(powerGained: number, hasDoubleCoins: boolean?, eventMultiplier: number?): number
	local coins = powerGained * Config.Training.CoinsPerPowerGained
	if hasDoubleCoins then
		coins *= 2
	end
	coins *= (eventMultiplier or 1)
	-- Keep fractional rewards; Data.addCoins accumulates the remainder.
	return math.max(0, coins)
end

function Formulas.rebirthCost(rebirths: number): number
	local base = Config.Rebirth.BaseCost
	local growth = Config.Rebirth.CostGrowth
	local maximum = 9_000_000_000_000_000
	if base <= 0 or growth <= 1 then
		return maximum
	end
	local exponent = math.max(0, math.floor(rebirths))
	local logCost = math.log(base) + exponent * math.log(growth)
	if logCost >= math.log(maximum) then
		return maximum
	end
	return math.max(1, math.floor(math.exp(logCost)))
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Formulas.abbreviate(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local index = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 1000 ^ index
	local formatted
	if scaled >= 100 then
		formatted = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		formatted = string.format("%.1f", scaled)
	else
		formatted = string.format("%.2f", scaled)
	end
	return formatted .. SUFFIXES[index + 1]
end

return Formulas
