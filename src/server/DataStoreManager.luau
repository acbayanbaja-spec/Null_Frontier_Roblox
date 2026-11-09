-- DataStoreManager for NULL FRONTIER
-- Production-grade, cross-server session-locked persistence engine.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)

local DATA_VERSION = 1
local DATASTORE_NAME = "NullFrontier_PlayerData_v" .. tostring(DATA_VERSION)
local MAX_RETRIES = 3
local RETRY_BACKOFF = {1.0, 2.0, 4.0}
local SESSION_LOCK_DURATION = GameConfig.SessionLockDuration or 1200 -- 20 minutes

local DataStoreManager = {}

-- State caches
local activeSessions = {}     -- userId (number) | player -> profile table
local sessionLoaded = {}      -- userId (number) | player -> boolean
local isDataStoreAvailable = true
local studioMockStore = {}    -- key -> serialized JSON string (with full session lock simulation)

-- Safe helper to resolve Player or UserId or Mock table
local function resolvePlayer(target: any): (number, string)
    if typeof(target) == "Instance" and target:IsA("Player") then
        return target.UserId, target.Name
    elseif type(target) == "table" and target.UserId then
        return target.UserId, target.Name or tostring(target.UserId)
    elseif type(target) == "number" then
        return target, tostring(target)
    end
    return 0, "Unknown"
end

-- Probe DataStore availability safely
local probeSuccess, probeErr = pcall(function()
    local ds = DataStoreService:GetDataStore("NullFrontier_SystemProbe")
    ds:GetAsync("__probe__")
end)

if not probeSuccess then
    warn(string.format("[DataStoreManager] Live DataStore API not accessible (%s). Operating in High-Fidelity Session Mock Mode.", tostring(probeErr)))
    isDataStoreAvailable = false
else
    print("[DataStoreManager] Live DataStore API confirmed accessible with Session-Locking active.")
end

-- Default Operative Template
function DataStoreManager.GetDefaultProfile(player: any)
    local userId, playerName = resolvePlayer(player)
    return {
        Version = DATA_VERSION,
        CreatedTime = os.time(),
        LastSaved = os.time(),
        Session = {
            LockJobId = game.JobId,
            LockTime = os.time()
        },
        Level = 1,
        XP = 0,
        LifetimeXP = 0,
        Credits = 0,
        ProcessedPurchases = {},
        Missions = {
            ["DAILY_PATROL"] = { Progress = 0, Target = 250, Completed = false, Claimed = false, ResetTimestamp = os.time() + 86400 },
            ["DAILY_COMM"] = { Progress = 0, Target = 1, Completed = false, Claimed = false, ResetTimestamp = os.time() + 86400 },
            ["EXPLORE_NEXUS"] = { Progress = 0, Target = 4, Completed = false, Claimed = false },
            ["VISIT_TECH"] = { Progress = 0, Target = 1, Completed = false, Claimed = false },
            ["FORM_SQUAD"] = { Progress = 0, Target = 1, Completed = false, Claimed = false },
            ["REACH_LEVEL_2"] = { Progress = 0, Target = 2, Completed = false, Claimed = false },
            ["ACCUMULATE_CREDITS"] = { Progress = 0, Target = 300, Completed = false, Claimed = false },
        },
        Achievements = {
            ["ACH_FIRST_BOOT"] = { Unlocked = true, UnlockedAt = os.time(), Claimed = false },
            ["ACH_SPRINT_VETERAN"] = { Unlocked = false, UnlockedAt = 0, Claimed = false },
            ["ACH_SURVEYOR"] = { Unlocked = false, UnlockedAt = 0, Claimed = false },
            ["ACH_SQUADRON"] = { Unlocked = false, UnlockedAt = 0, Claimed = false },
            ["ACH_REACH_LVL_3"] = { Unlocked = false, UnlockedAt = 0, Claimed = false },
            ["ACH_CREDIT_BARON"] = { Unlocked = false, UnlockedAt = 0, Claimed = false },
        },
        Inventory = {},
        Equipment = {
            Head = nil,
            Body = nil,
            Back = nil,
            Weapon = nil,
            Emote = nil
        },
        Stats = {
            PlayTime = 0,
            DistanceSprinted = 0,
            DistrictsVisited = {},
            TotalClaims = 0
        }
    }
end

-- Data Reconciler
local function reconcileData(savedData: table, template: table): table
    for k, v in pairs(template) do
        if savedData[k] == nil then
            if type(v) == "table" then
                savedData[k] = HttpService:JSONDecode(HttpService:JSONEncode(v))
            else
                savedData[k] = v
            end
        elseif type(v) == "table" and type(savedData[k]) == "table" then
            for subK, subV in pairs(v) do
                if savedData[k][subK] == nil then
                    savedData[k][subK] = subV
                end
            end
        end
    end
    return savedData
end

-- Mock UpdateAsync Implementation for Studio / Offline
local function mockUpdateAsync(key: string, transformFunc: (any) -> any): (boolean, any)
    local raw = studioMockStore[key]
    local existing = nil
    if raw then
        local decSuccess, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
        if decSuccess then
            existing = parsed
        end
    end
    
    local updated = transformFunc(existing)
    if updated ~= nil then
        studioMockStore[key] = HttpService:JSONEncode(updated)
        return true, updated
    end
    return false, "Aborted by transform function or session lock conflict"
end

-- Load Profile with Session-Locking via UpdateAsync
function DataStoreManager.LoadProfile(player: any): (table, boolean)
    local userId, playerName = resolvePlayer(player)
    local key = "Operative_" .. tostring(userId)
    local finalProfile = nil
    local lockConflict = false
    local store = isDataStoreAvailable and DataStoreService:GetDataStore(DATASTORE_NAME) or nil
    
    for attempt = 1, MAX_RETRIES do
        local opSuccess, result
        if isDataStoreAvailable and store then
            opSuccess, result = pcall(function()
                return store:UpdateAsync(key, function(existing)
                    local now = os.time()
                    if existing ~= nil and type(existing) == "table" then
                        if existing.Session and existing.Session.LockJobId and existing.Session.LockJobId ~= game.JobId then
                            local lockAge = now - (existing.Session.LockTime or 0)
                            if lockAge < SESSION_LOCK_DURATION then
                                lockConflict = true
                                return nil
                            else
                                warn(string.format("[DataStoreManager] Overriding expired session lock (age: %ds) for %s from JobId %s.",
                                    lockAge, playerName, tostring(existing.Session.LockJobId)))
                            end
                        end
                        existing.Session = {
                            LockJobId = game.JobId,
                            LockTime = now
                        }
                        return existing
                    else
                        local fresh = DataStoreManager.GetDefaultProfile(player)
                        fresh.Session = {
                            LockJobId = game.JobId,
                            LockTime = now
                        }
                        return fresh
                    end
                end)
            end)
        else
            opSuccess, result = mockUpdateAsync(key, function(existing)
                local now = os.time()
                if existing ~= nil and type(existing) == "table" then
                    if existing.Session and existing.Session.LockJobId and existing.Session.LockJobId ~= game.JobId then
                        local lockAge = now - (existing.Session.LockTime or 0)
                        if lockAge < SESSION_LOCK_DURATION then
                            lockConflict = true
                            return nil
                        end
                    end
                    existing.Session = { LockJobId = game.JobId, LockTime = now }
                    return existing
                else
                    local fresh = DataStoreManager.GetDefaultProfile(player)
                    fresh.Session = { LockJobId = game.JobId, LockTime = now }
                    return fresh
                end
            end)
        end
        
        if opSuccess and result ~= nil then
            finalProfile = reconcileData(result, DataStoreManager.GetDefaultProfile(player))
            break
        elseif lockConflict then
            warn(string.format("[DataStoreManager] SESSION CONFLICT: Operative %s profile is currently locked by another active server.", playerName))
            break
        else
            warn(string.format("[DataStoreManager] UpdateAsync load attempt %d failed for %s: %s", attempt, playerName, tostring(result)))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_BACKOFF[attempt] or 1.0)
            end
        end
    end
    
    if finalProfile == nil then
        sessionLoaded[player] = false
        sessionLoaded[userId] = false
        warn(string.format("[DataStoreManager] CRITICAL: Profile load failed for %s. Operating in read-only quarantine.", playerName))
        local fallback = DataStoreManager.GetDefaultProfile(player)
        fallback.Session = nil
        activeSessions[player] = fallback
        activeSessions[userId] = fallback
        return fallback, false
    end
    
    activeSessions[player] = finalProfile
    activeSessions[userId] = finalProfile
    sessionLoaded[player] = true
    sessionLoaded[userId] = true
    print(string.format("[DataStoreManager] Session lock acquired for %s (JobId: %s, Level %d, %d CR).",
        playerName, game.JobId, finalProfile.Level, finalProfile.Credits))
    return finalProfile, true
end

-- Save Profile with Session-Lock Verification via UpdateAsync
function DataStoreManager.SaveProfile(player: any, isReleasing: boolean?): boolean
    local userId, playerName = resolvePlayer(player)
    
    if sessionLoaded[userId] ~= true and sessionLoaded[player] ~= true then
        warn(string.format("[DataStoreManager] SKIPPED save for %s: Session was not loaded cleanly (Protection Against Data Corruption active).", playerName))
        return false
    end
    
    local profile = activeSessions[player] or activeSessions[userId]
    if not profile then
        warn(string.format("[DataStoreManager] SKIPPED save for %s: No active session profile found in memory.", playerName))
        return false
    end
    
    profile.LastSaved = os.time()
    local key = "Operative_" .. tostring(userId)
    local saveSuccess = false
    local store = isDataStoreAvailable and DataStoreService:GetDataStore(DATASTORE_NAME) or nil
    
    for attempt = 1, MAX_RETRIES do
        local opSuccess, result
        if isDataStoreAvailable and store then
            opSuccess, result = pcall(function()
                return store:UpdateAsync(key, function(existing)
                    local now = os.time()
                    if existing and existing.Session and existing.Session.LockJobId and existing.Session.LockJobId ~= game.JobId then
                        local lockAge = now - (existing.Session.LockTime or 0)
                        if lockAge < SESSION_LOCK_DURATION then
                            warn(string.format("[DataStoreManager] Session ownership lost during save for %s! Aborting write.", playerName))
                            return nil
                        end
                    end
                    
                    if isReleasing then
                        profile.Session = nil
                    else
                        profile.Session = {
                            LockJobId = game.JobId,
                            LockTime = now
                        }
                    end
                    return profile
                end)
            end)
        else
            opSuccess, result = mockUpdateAsync(key, function(existing)
                local now = os.time()
                if existing and existing.Session and existing.Session.LockJobId and existing.Session.LockJobId ~= game.JobId then
                    local lockAge = now - (existing.Session.LockTime or 0)
                    if lockAge < SESSION_LOCK_DURATION then
                        return nil
                    end
                end
                if isReleasing then
                    profile.Session = nil
                else
                    profile.Session = { LockJobId = game.JobId, LockTime = now }
                end
                return profile
            end)
        end
        
        if opSuccess and result ~= nil then
            saveSuccess = true
            break
        else
            warn(string.format("[DataStoreManager] UpdateAsync save attempt %d failed for %s: %s", attempt, playerName, tostring(result)))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_BACKOFF[attempt] or 1.0)
            end
        end
    end
    
    if saveSuccess then
        print(string.format("[DataStoreManager] Confirmed save for %s (Releasing: %s).", playerName, tostring(isReleasing == true)))
    else
        warn(string.format("[DataStoreManager] FAILED to save profile for %s after %d retries.", playerName, MAX_RETRIES))
    end
    return saveSuccess
end

function DataStoreManager.GetSessionData(player: any): table?
    local userId = resolvePlayer(player)
    return activeSessions[player] or activeSessions[userId]
end

function DataStoreManager.ReleaseSession(player: any)
    local userId, playerName = resolvePlayer(player)
    
    DataStoreManager.SaveProfile(player, true)
    
    activeSessions[player] = nil
    activeSessions[userId] = nil
    sessionLoaded[player] = nil
    sessionLoaded[userId] = nil
    print(string.format("[DataStoreManager] Session lock cleanly released for %s.", playerName))
end

-- Periodic Auto-Save Loop
task.spawn(function()
    while true do
        task.wait(300)
        local count = 0
        for player, _ in pairs(activeSessions) do
            if typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
                DataStoreManager.SaveProfile(player, false)
                count = count + 1
            end
        end
        if count > 0 then
            print(string.format("[DataStoreManager] Periodic auto-save completed for %d online operatives.", count))
        end
    end
end)

-- BindToClose
game:BindToClose(function()
    print("[DataStoreManager] Server shutdown initiated. Synchronizing all active operative profiles...")
    local pendingPlayers = {}
    for player, _ in pairs(activeSessions) do
        if typeof(player) == "Instance" and player:IsA("Player") then
            table.insert(pendingPlayers, player)
        end
    end
    
    local remaining = #pendingPlayers
    if remaining == 0 then
        print("[DataStoreManager] No active profiles to flush.")
        return
    end
    
    for _, player in ipairs(pendingPlayers) do
        task.spawn(function()
            local ok = DataStoreManager.SaveProfile(player, true)
            if ok then
                print(string.format("[DataStoreManager] Shutdown flush confirmed for %s.", player.Name))
            else
                warn(string.format("[DataStoreManager] Shutdown flush error for %s.", player.Name))
            end
            remaining = remaining - 1
        end)
    end
    
    local waitStart = os.clock()
    while remaining > 0 and (os.clock() - waitStart) < 25 do
        task.wait(0.1)
    end
    print(string.format("[DataStoreManager] Server shutdown save completed. (%d remaining, elapsed: %.2fs)",
        remaining, os.clock() - waitStart))
end)

function DataStoreManager.GetMockStoreDump(): table
    return studioMockStore
end

return DataStoreManager
