-- AchievementManager for NULL FRONTIER
-- Server-authoritative achievement unlocks, conditions, and reward pipeline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local AchievementConfig = require(NullFrontier.Config.AchievementConfig)
local Remotes = NullFrontier.Remotes
local AchievementUnlockedRE = Remotes:WaitForChild("AchievementUnlocked")
local ClaimAchievementRF = Remotes:WaitForChild("ClaimAchievement")

local AchievementManager = {}

local function getPlayerAchievements(player: Player): table?
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return nil end
    if not profile.Achievements then profile.Achievements = {} end
    return profile.Achievements
end

-- Unlock Achievement
function AchievementManager.Unlock(player: Player, achId: string): boolean
    local achievements = getPlayerAchievements(player)
    if not achievements then return false end
    
    local cfg = AchievementConfig.Achievements[achId]
    if not cfg then return false end
    
    local record = achievements[achId]
    if not record then
        record = { Unlocked = false, UnlockedAt = 0, Claimed = false }
        achievements[achId] = record
    end
    
    if record.Unlocked then return false end -- Already unlocked
    
    record.Unlocked = true
    record.UnlockedAt = os.time()
    
    -- Auto-grant or award achievement rewards instantly
    local RewardService = require(script.Parent:WaitForChild("RewardService"))
    RewardService.GrantReward(player, "ACHIEVEMENT: " .. cfg.Title, cfg.RewardXP, cfg.RewardCredits, "Ach_" .. achId)
    record.Claimed = true
    
    AchievementUnlockedRE:FireClient(player, achId, {
        Title = cfg.Title,
        Description = cfg.Description,
        Category = cfg.Category,
        RewardXP = cfg.RewardXP,
        RewardCredits = cfg.RewardCredits
    })
    
    print(string.format("[AchievementManager] Operative %s UNLOCKED achievement '%s'!", player.Name, cfg.Title))
    return true
end

-- Condition Observers
function AchievementManager.RecordSprint(player: Player, studs: number)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return end
    
    profile.Stats.DistanceSprinted = (profile.Stats.DistanceSprinted or 0) + studs
    if profile.Stats.DistanceSprinted >= 500 then
        AchievementManager.Unlock(player, "ACH_SPRINT_VETERAN")
    end
end

function AchievementManager.CheckProgressionAchievements(player: Player, level: number)
    if level >= 3 then
        AchievementManager.Unlock(player, "ACH_REACH_LVL_3")
    end
end

function AchievementManager.CheckCreditAchievements(player: Player, credits: number)
    if credits >= 1000 then
        AchievementManager.Unlock(player, "ACH_CREDIT_BARON")
    end
end

ClaimAchievementRF.OnServerInvoke = function(player: Player, achId: string)
    local achievements = getPlayerAchievements(player)
    if not achievements then return false, "No session" end
    
    local record = achievements[achId]
    if not record or not record.Unlocked then return false, "Not unlocked" end
    if record.Claimed then return false, "Already claimed" end
    
    local cfg = AchievementConfig.Achievements[achId]
    if not cfg then return false, "Invalid achievement" end
    
    record.Claimed = true
    local RewardService = require(script.Parent:WaitForChild("RewardService"))
    RewardService.GrantReward(player, cfg.Title, cfg.RewardXP, cfg.RewardCredits, "Ach_" .. achId)
    return true, "Claimed"
end

return AchievementManager
