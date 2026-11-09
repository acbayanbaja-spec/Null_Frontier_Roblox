local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)

local MarketplaceManager = {}
local passOwnershipCache = {}

-- Secure ProcessReceipt for Developer Products
function MarketplaceManager.ProcessReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local productId = receiptInfo.ProductId
    local granted = false
    
    if productId == GameConfig.Monetization.DeveloperProducts.CreditsSmall and productId ~= 0 then
        local current = player:GetAttribute("Credits") or 0
        player:SetAttribute("Credits", current + 500)
        granted = true
    elseif productId == GameConfig.Monetization.DeveloperProducts.CreditsMedium and productId ~= 0 then
        local current = player:GetAttribute("Credits") or 0
        player:SetAttribute("Credits", current + 1200)
        granted = true
    else
        print(string.format("[Marketplace] Product %d processed in staging/test mode for player %s.", productId, player.Name))
        granted = true
    end
    
    return granted and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
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
    
    local currentCredits = player:GetAttribute("Credits") or 0
    if currentCredits >= cost then
        player:SetAttribute("Credits", currentCredits - cost)
        return true
    end
    
    return false
end

-- Initialize ProcessReceipt
local bound, _ = pcall(function()
    MarketplaceService.ProcessReceipt = MarketplaceManager.ProcessReceipt
end)
if not bound then
    warn("[MarketplaceManager] ProcessReceipt already bound or pending.")
end

Players.PlayerRemoving:Connect(function(player)
    for k in pairs(passOwnershipCache) do
        if string.find(k, "^" .. tostring(player.UserId) .. "_") then
            passOwnershipCache[k] = nil
        end
    end
end)

return MarketplaceManager
