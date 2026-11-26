-- Monetization.luau
-- Gamepass ownership cache and durable, idempotent Developer Product grants.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Monetization = {}
local ownership = {}
local Data

local function refreshPasses(player: Player)
	local owned = ownership[player] or {}
	ownership[player] = owned

	for key, passId in Config.GamePasses do
		if passId == 0 then
			owned[key] = false
			player:SetAttribute("Owns" .. key, false)
		else
			-- A transient API failure is not proof that the player does not own it.
			for attempt = 1, 3 do
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if ok then
					owned[key] = owned[key] == true or result == true
					player:SetAttribute("Owns" .. key, owned[key])
					break
				end
				warn(`[Monetization] Gamepass check failed ({key}, attempt {attempt}): {result}`)
				task.wait(attempt * 2)
			end
		end
	end
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not Data.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, product in Config.DevProducts do
		if product.id ~= 0 and product.id == receiptInfo.ProductId then
			local granted = Data.grantProductReceipt(player, tostring(receiptInfo.PurchaseId), product.coins)
			if not granted then
				-- Roblox retries this receipt. Never acknowledge a grant that
				-- has not been durably recorded with the player's profile.
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "success", `Purchased {product.label}!`)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	warn(`[Monetization] Receipt for unknown product id {receiptInfo.ProductId}`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Monetization.ownsPass(player: Player, passKey: string): boolean
	local owned = ownership[player]
	return owned ~= nil and owned[passKey] == true
end

function Monetization.start(dataService)
	Data = dataService

	Players.PlayerAdded:Connect(function(player)
		task.spawn(refreshPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownership[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, id in Config.GamePasses do
			if id == passId and id ~= 0 then
				local owned = ownership[player]
				if owned then
					owned[key] = true
				end
				player:SetAttribute("Owns" .. key, true)
				local info = Config.GamePassInfo[key]
				local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
				if notify and info then
					notify:FireClient(player, "success", `{info.title} unlocked!`)
				end
			end
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return Monetization
