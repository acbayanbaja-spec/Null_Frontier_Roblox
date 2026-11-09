-- MissionManager for NULL FRONTIER
-- Server-authoritative mission objectives, progress validation, and reward claiming.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local MissionConfig = require(NullFrontier.Config.MissionConfig)
local Remotes = NullFrontier.Remotes
local ClaimMissionRF = Remotes:WaitForChild("ClaimMission")
local MissionProgressUpdatedRE = Remotes:WaitForChild("MissionProgressUpdated")
local GetProgressionDataRF = Remotes:WaitForChild("GetProgressionData")

local MissionManager = {}

-- Helper to fetch player's mission record
local function getPlayerMissions(player: Player): table?
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return nil end
    if not profile.Missions then profile.Missions = {} end
    return profile.Missions
end

-- Update progress and broadcast if changed
local function addProgress(player: Player, missionId: string, amount: number)
    local missions = getPlayerMissions(player)
    if not missions then return end
    
    local cfg = MissionConfig.Missions[missionId]
    if not cfg then return end
    
    local record = missions[missionId]
    if not record then
        record = { Progress = 0, Target = cfg.Target, Completed = false, Claimed = false }
        missions[missionId] = record
    end
    
    if record.Completed then return end
    
    record.Progress = math.min(cfg.Target, record.Progress + amount)
    if record.Progress >= cfg.Target then
        record.Completed = true
        print(string.format("[MissionManager] Operative %s COMPLETED mission '%s'!", player.Name, cfg.Title))
    end
    
    MissionProgressUpdatedRE:FireClient(player, missionId, record.Progress, record.Target, record.Completed, record.Claimed)
end

-- Objective Tracking Hooks
function MissionManager.RecordSprintDistance(player: Player, studs: number)
    if studs <= 0 then return end
    addProgress(player, "DAILY_PATROL", studs)
    
    -- Also track lifetime sprint for achievements
    local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
    AchievementManager.RecordSprint(player, studs)
end

function MissionManager.RecordDistrictVisited(player: Player, districtName: string)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return end
    
    if not profile.Stats.DistrictsVisited then profile.Stats.DistrictsVisited = {} end
    if not profile.Stats.DistrictsVisited[districtName] then
        profile.Stats.DistrictsVisited[districtName] = true
        
        local count = 0
        for _ in pairs(profile.Stats.DistrictsVisited) do count = count + 1 end
        
        print(string.format("[MissionManager] Operative %s charted sector '%s' (%d/4 charted).", player.Name, districtName, count))
        
        if districtName == "TechnologyDistrict" then
            addProgress(player, "VISIT_TECH", 1)
        end
        
        addProgress(player, "EXPLORE_NEXUS", 1)
        
        if count >= 4 then
            local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
            AchievementManager.Unlock(player, "ACH_SURVEYOR")
        end
    end
end

function MissionManager.RecordSquadFormed(player: Player)
    addProgress(player, "FORM_SQUAD", 1)
    local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
    AchievementManager.Unlock(player, "ACH_SQUADRON")
end

function MissionManager.RecordProfileInspected(player: Player)
    addProgress(player, "DAILY_COMM", 1)
end

function MissionManager.CheckProgressionMissions(player: Player, level: number)
    if level >= 2 then
        addProgress(player, "REACH_LEVEL_2", level)
    end
end

function MissionManager.CheckCreditMissions(player: Player, credits: number)
    local missions = getPlayerMissions(player)
    if not missions then return end
    
    local record = missions["ACCUMULATE_CREDITS"]
    if record and not record.Completed then
        record.Progress = math.min(300, credits)
        if record.Progress >= 300 then
            record.Completed = true
            MissionProgressUpdatedRE:FireClient(player, "ACCUMULATE_CREDITS", record.Progress, 300, true, record.Claimed)
        end
    end
end

-- Claim Mission Reward
function MissionManager.ClaimReward(player: Player, missionId: string): (boolean, string)
    local missions = getPlayerMissions(player)
    if not missions then return false, "Profile session unavailable" end
    
    local cfg = MissionConfig.Missions[missionId]
    if not cfg then return false, "Invalid mission directive" end
    
    local record = missions[missionId]
    if not record then return false, "Mission data missing" end
    if not record.Completed then return false, "Mission objective incomplete" end
    if record.Claimed then return false, "Reward already claimed" end
    
    record.Claimed = true
    
    -- Grant via RewardService
    local RewardService = require(script.Parent:WaitForChild("RewardService"))
    RewardService.GrantReward(player, cfg.Title, cfg.RewardXP, cfg.RewardCredits, "Mission_" .. missionId)
    
    MissionProgressUpdatedRE:FireClient(player, missionId, record.Progress, record.Target, record.Completed, true)
    return true, "Reward successfully claimed"
end

ClaimMissionRF.OnServerInvoke = function(player: Player, missionId: string)
    if type(missionId) ~= "string" then return false, "Invalid argument" end
    return MissionManager.ClaimReward(player, missionId)
end

-- Return Full Progression Telemetry (Missions + Achievements + Stats)
GetProgressionDataRF.OnServerInvoke = function(player: Player)
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return nil end
    
    local AchievementConfig = require(NullFrontier.Config.AchievementConfig)
    
    return {
        Level = player:GetAttribute("Level") or profile.Level,
        XP = player:GetAttribute("XP") or profile.XP,
        MaxXP = player:GetAttribute("MaxXP") or 100,
        LifetimeXP = player:GetAttribute("LifetimeXP") or profile.LifetimeXP,
        Credits = player:GetAttribute("Credits") or profile.Credits,
        Missions = profile.Missions,
        MissionCatalog = MissionConfig.Missions,
        Achievements = profile.Achievements,
        AchievementCatalog = AchievementConfig.Achievements,
        Stats = profile.Stats
    }
end

return MissionManager
