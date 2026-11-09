-- ProgressionManager for NULL FRONTIER
-- Mathematical progression curve, multi-level calculations, atomic economy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local Remotes = NullFrontier.Remotes
local LevelUpNotificationRE = Remotes:WaitForChild("LevelUpNotification")

local ProgressionManager = {}

-- Mathematical XP Formula: XP(lvl) = BaseXP * (lvl ^ 1.35)
function ProgressionManager.GetXPRequiredForLevel(level: number): number
    if level <= 1 then return GameConfig.BaseXPPerLevel end
    return math.floor(GameConfig.BaseXPPerLevel * (level ^ 1.35))
end

-- Initialize Player Session Attributes from Profile Data
function ProgressionManager.SetupPlayer(player: Player)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile, isClean = DataStoreManager.LoadProfile(player)
    
    local level = profile.Level or GameConfig.DefaultLevel
    local xp = profile.XP or 0
    local lifetimeXP = profile.LifetimeXP or 0
    local credits = profile.Credits or GameConfig.StartingCredits
    local maxXP = ProgressionManager.GetXPRequiredForLevel(level)
    
    player:SetAttribute("Level", level)
    player:SetAttribute("XP", xp)
    player:SetAttribute("MaxXP", maxXP)
    player:SetAttribute("LifetimeXP", lifetimeXP)
    player:SetAttribute("Credits", credits)
    
    print(string.format("[ProgressionManager] Operative %s synced: Level %d (%d/%d XP), Lifetime XP %d, Credits %d.", player.Name, level, xp, maxXP, lifetimeXP, credits))
end

-- Server-Authoritative XP Addition with Multi-Level-Up Cascade
function ProgressionManager.AddXP(player: Player, amount: number, source: string): (boolean, number)
    if type(amount) ~= "number" or amount <= 0 then return false, 0 end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    
    local currentXP = player:GetAttribute("XP") or 0
    local currentLevel = player:GetAttribute("Level") or 1
    local lifetimeXP = player:GetAttribute("LifetimeXP") or 0
    local maxXP = ProgressionManager.GetXPRequiredForLevel(currentLevel)
    
    local newXP = currentXP + amount
    local newLifetimeXP = lifetimeXP + amount
    local leveledUp = false
    local startLevel = currentLevel
    
    while newXP >= maxXP do
        newXP = newXP - maxXP
        currentLevel = currentLevel + 1
        maxXP = ProgressionManager.GetXPRequiredForLevel(currentLevel)
        leveledUp = true
    end
    
    -- Sync Player Attributes
    player:SetAttribute("XP", newXP)
    player:SetAttribute("MaxXP", maxXP)
    player:SetAttribute("Level", currentLevel)
    player:SetAttribute("LifetimeXP", newLifetimeXP)
    
    -- Sync Profile
    if profile then
        profile.XP = newXP
        profile.Level = currentLevel
        profile.LifetimeXP = newLifetimeXP
    end
    
    -- Level-up event & rewards bonus (50 Credits per level gained)
    if leveledUp then
        local levelsGained = currentLevel - startLevel
        local bonusCredits = levelsGained * 50
        ProgressionManager.AddCredits(player, bonusCredits, "LevelUpBonus")
        
        LevelUpNotificationRE:FireClient(player, currentLevel, {
            LevelsGained = levelsGained,
            BonusCredits = bonusCredits,
            NewMaxXP = maxXP
        })
        
        print(string.format("[ProgressionManager] *** LEVEL UP *** Operative %s attained Level %d! (+%d CR bonus)", player.Name, currentLevel, bonusCredits))
        
        -- Check Level Missions and Achievements
        local MissionManager = require(script.Parent:WaitForChild("MissionManager"))
        MissionManager.CheckProgressionMissions(player, currentLevel)
        
        local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
        AchievementManager.CheckProgressionAchievements(player, currentLevel)
    end
    
    return leveledUp, currentLevel
end

-- Server-Authoritative In-Game Currency Addition
function ProgressionManager.AddCredits(player: Player, amount: number, source: string): boolean
    if type(amount) ~= "number" or amount <= 0 then return false end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    
    local currentCredits = player:GetAttribute("Credits") or 0
    local newCredits = currentCredits + math.floor(amount)
    
    player:SetAttribute("Credits", newCredits)
    if profile then
        profile.Credits = newCredits
    end
    
    -- Check Credit Missions and Achievements
    local MissionManager = require(script.Parent:WaitForChild("MissionManager"))
    MissionManager.CheckCreditMissions(player, newCredits)
    
    local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
    AchievementManager.CheckCreditAchievements(player, newCredits)
    
    return true
end

-- Server-Authoritative Currency Deduction (Atomic balance verification)
function ProgressionManager.DeductCredits(player: Player, amount: number, reason: string): (boolean, number, string)
    if type(amount) ~= "number" or amount <= 0 then
        return false, player:GetAttribute("Credits") or 0, "Invalid amount"
    end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    
    local currentCredits = player:GetAttribute("Credits") or 0
    if currentCredits < amount then
        return false, currentCredits, "Insufficient balance"
    end
    
    local newCredits = currentCredits - math.floor(amount)
    player:SetAttribute("Credits", newCredits)
    if profile then
        profile.Credits = newCredits
    end
    
    print(string.format("[ProgressionManager] Deducted %d CR from %s for '%s' (New Balance: %d CR).", amount, player.Name, reason or "Purchase", newCredits))
    return true, newCredits, "Success"
end

return ProgressionManager
