-- MarketplaceManager for NULL FRONTIER
-- Production-grade, durable developer product processing with PurchaseId idempotency.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local MarketplaceManager = {}
local passOwnershipCache = {}

-- Durable Developer Product Receipt Processor
function MarketplaceManager.ProcessReceipt(receiptInfo)
    if not receiptInfo or not receiptInfo.PurchaseId then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local purchaseId = tostring(receiptInfo.PurchaseId)
    local playerId = receiptInfo.PlayerId
    local productId = receiptInfo.ProductId
    
    -- 1. Verify Player Presence on this Server
    local player = Players:GetPlayerByUserId(playerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 2. Verify Active Session Data
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then
        warn(string.format("[MarketplaceManager] Profile session not active for %s. Deferring purchase %s.",
            player.Name, purchaseId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 3. Durable Idempotency Check (Confirm previously fulfilled purchases immediately)
    if not profile.ProcessedPurchases then
        profile.ProcessedPurchases = {}
    end
    
    if profile.ProcessedPurchases[purchaseId] then
        print(string.format("[MarketplaceManager] Idempotent hit: Purchase %s already granted to %s at %d.",
            purchaseId, player.Name, profile.ProcessedPurchases[purchaseId]))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- 4. Monetization Verification Gate (For new unfulfilled purchases)
    if not GameConfig.Monetization or GameConfig.Monetization.Enabled ~= true then
        warn(string.format("[MarketplaceManager] Monetization is currently inactive. Deferred receipt %s for product %d.",
            purchaseId, productId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
        print(string.format("[MarketplaceManager] Idempotent hit: Purchase %s already granted to %s at %d.",
            purchaseId, player.Name, profile.ProcessedPurchases[purchaseId]))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- 5. Product Recognition & Validation
    local rewards = GameConfig.Monetization.ProductRewards or {}
    local reward = rewards[productId]
    
    if not reward or productId <= 0 then
        -- Never grant unknown or unconfigured products
        warn(string.format("[MarketplaceManager] REJECTED unknown or unverified ProductId %d for purchase %s (Player: %s).",
            productId, purchaseId, player.Name))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 6. Apply Verified Reward
    if reward.RewardType == "Credits" and typeof(reward.Amount) == "number" and reward.Amount > 0 then
        local currentCredits = profile.Credits or 0
        profile.Credits = currentCredits + reward.Amount
        player:SetAttribute("Credits", profile.Credits)
        print(string.format("[MarketplaceManager] Granted %d Credits to %s for product %d.",
            reward.Amount, player.Name, productId))
    else
        warn(string.format("[MarketplaceManager] Unhandled reward type %s for product %d.",
            tostring(reward.RewardType), productId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- 7. Record PurchaseId in Durable Profile
    profile.ProcessedPurchases[purchaseId] = os.time()
    
    -- 8. Persist Profile Before Granting Purchase
    local saveOk = DataStoreManager.SaveProfile(player, false)
    if not saveOk then
        warn(string.format("[MarketplaceManager] Failed to persist purchase record %s. Returning NotProcessedYet for safe retry.", purchaseId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    print(string.format("[MarketplaceManager] Successfully fulfilled and persisted purchase %s for %s.", purchaseId, player.Name))
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Server-Side GamePass Validation
function MarketplaceManager.UserOwnsPass(player: Player, passId: number): boolean
    if not passId or passId <= 0 then return false end
    
    local key = tostring(player.UserId) .. "_" .. tostring(passId)
    if passOwnershipCache[key] ~= nil then
        return passOwnershipCache[key]
    end
    
    local success, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    
    if success then
        passOwnershipCache[key] = owns
        return owns
    end
    return false
end

-- In-Game Currency Validation (Strict Anti-Exploit Server Logic)
function MarketplaceManager.ValidateAndDeductCredits(player: Player, cost: number): boolean
    if type(cost) ~= "number" or cost <= 0 then return false end
    
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return false end
    
    local currentCredits = profile.Credits or player:GetAttribute("Credits") or 0
    if currentCredits >= cost then
        profile.Credits = currentCredits - cost
        player:SetAttribute("Credits", profile.Credits)
        return true
    end
    
    return false
end

-- Bind ProcessReceipt callback safely
local bound, bErr = pcall(function()
    MarketplaceService.ProcessReceipt = MarketplaceManager.ProcessReceipt
end)
if not bound then
    warn(string.format("[MarketplaceManager] ProcessReceipt binding note: %s", tostring(bErr)))
end

Players.PlayerRemoving:Connect(function(player)
    for k in pairs(passOwnershipCache) do
        if string.find(k, "^" .. tostring(player.UserId) .. "_") then
            passOwnershipCache[k] = nil
        end
    end
end)

return MarketplaceManager
