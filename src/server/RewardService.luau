-- RewardService for NULL FRONTIER
-- Unified, atomic, anti-duplication reward transaction engine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local RewardNotificationRE = Remotes:WaitForChild("RewardNotification")

local RewardService = {}
local processedTransactions = {} -- UUID -> timestamp

-- Reusable reward dispatcher
function RewardService.GrantReward(player: Player, rewardTitle: string, xpAmount: number, creditsAmount: number, sourceId: string): boolean
    if not player or not player.Parent then return false end
    
    xpAmount = math.max(0, math.floor(xpAmount or 0))
    creditsAmount = math.max(0, math.floor(creditsAmount or 0))
    
    if xpAmount == 0 and creditsAmount == 0 then
        return false
    end
    
    -- Generate transaction UUID
    local txId = string.format("TX_%d_%s_%s", player.UserId, sourceId or "REWARD", HttpService:GenerateGUID(false):sub(1, 8))
    if processedTransactions[txId] then
        warn(string.format("[RewardService] DUPLICATE ATTEMPT: %s already processed.", txId))
        return false
    end
    processedTransactions[txId] = os.time()
    
    -- Lazy-load managers to avoid circular dependency
    local ProgressionManager = require(script.Parent:WaitForChild("ProgressionManager"))
    
    -- 1. Grant XP (Handles level-ups)
    if xpAmount > 0 then
        ProgressionManager.AddXP(player, xpAmount, sourceId)
    end
    
    -- 2. Grant Credits
    if creditsAmount > 0 then
        ProgressionManager.AddCredits(player, creditsAmount, sourceId)
    end
    
    -- 3. Notify Client
    RewardNotificationRE:FireClient(player, rewardTitle or "OPERATION REWARD", xpAmount, creditsAmount)
    
    print(string.format("[RewardService] [%s] Awarded +%d XP and +%d CR to %s for '%s'.", txId, xpAmount, creditsAmount, player.Name, rewardTitle))
    return true
end

return RewardService
