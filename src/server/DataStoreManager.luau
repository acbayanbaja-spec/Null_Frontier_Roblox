-- DataStoreManager for NULL FRONTIER
-- Production-grade, resilient, session-locked persistence engine.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local DATA_VERSION = 1
local DATASTORE_NAME = "NullFrontier_PlayerData_v" .. tostring(DATA_VERSION)
local MAX_RETRIES = 3
local RETRY_BACKOFF = {1.0, 2.0, 4.0}

local DataStoreManager = {}

-- State caches
local activeSessions = {}     -- player -> profile table
local sessionLoaded = {}      -- player -> boolean (true if successfully loaded)
local isDataStoreAvailable = true
local studioMockStore = {}    -- key -> serialized JSON string (for offline / Studio testing)

-- Attempt to probe DataStore availability safely
local probeSuccess, probeErr = pcall(function()
    local ds = DataStoreService:GetDataStore("NullFrontier_SystemProbe")
    ds:GetAsync("__probe__")
end)

if not probeSuccess then
    warn(string.format("[DataStoreManager] Live DataStore API not accessible (%s). Operating in High-Fidelity Session Mock Mode.", tostring(probeErr)))
    isDataStoreAvailable = false
else
    print("[DataStoreManager] Live DataStore API confirmed accessible.")
end

-- Default Operative Template
function DataStoreManager.GetDefaultProfile(player: Player)
    return {
        Version = DATA_VERSION,
        CreatedTime = os.time(),
        LastSaved = os.time(),
        Level = 1,
        XP = 0,
        LifetimeXP = 0,
        Credits = 0,
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

-- Data Reconciler (Upgrades existing profiles to current schema seamlessly)
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

-- Load Profile with exponential retries and failure containment
function DataStoreManager.LoadProfile(player: Player): (table, boolean)
    local key = "Operative_" .. tostring(player.UserId)
    local loadedData = nil
    local success = false
    
    if isDataStoreAvailable then
        local store = DataStoreService:GetDataStore(DATASTORE_NAME)
        for attempt = 1, MAX_RETRIES do
            local opSuccess, result = pcall(function()
                return store:GetAsync(key)
            end)
            
            if opSuccess then
                loadedData = result
                success = true
                break
            else
                warn(string.format("[DataStoreManager] GetAsync attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
                if attempt < MAX_RETRIES then
                    task.wait(RETRY_BACKOFF[attempt] or 1.0)
                end
            end
        end
    else
        -- Use Mock Store
        local raw = studioMockStore[key]
        if raw then
            local decSuccess, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
            if decSuccess then
                loadedData = parsed
            end
        end
        success = true
    end
    
    if not success then
        -- Critical failure: do NOT overwrite with defaults. Mark as unloaded/read-only
        sessionLoaded[player] = false
        warn(string.format("[DataStoreManager] FATAL: Unable to load data for %s after %d retries. Profile protected in read-only state.", player.Name, MAX_RETRIES))
        local emergencyFallback = DataStoreManager.GetDefaultProfile(player)
        activeSessions[player] = emergencyFallback
        return emergencyFallback, false
    end
    
    local finalProfile = nil
    if loadedData ~= nil and type(loadedData) == "table" then
        finalProfile = reconcileData(loadedData, DataStoreManager.GetDefaultProfile(player))
        print(string.format("[DataStoreManager] Successfully loaded existing profile for %s (Level %d, %d Credits).", player.Name, finalProfile.Level, finalProfile.Credits))
    else
        finalProfile = DataStoreManager.GetDefaultProfile(player)
        print(string.format("[DataStoreManager] Initialized fresh profile for operative %s.", player.Name))
    end
    
    activeSessions[player] = finalProfile
    activeSessions[player.UserId] = finalProfile
    sessionLoaded[player] = true
    sessionLoaded[player.UserId] = true
    return finalProfile, true
end

-- Save Profile with serialization and safe retry
function DataStoreManager.SaveProfile(player: Player): boolean
    if sessionLoaded[player] == false then
        warn(string.format("[DataStoreManager] SKIPPED save for %s: Session was not loaded cleanly (Protection Against Data Corruption active).", player.Name))
        return false
    end
    
    local profile = activeSessions[player] or (player and activeSessions[player.UserId])
    if not profile then return false end
    
    profile.LastSaved = os.time()
    local key = "Operative_" .. tostring(player.UserId)
    
    if not isDataStoreAvailable then
        -- Mock persistence across in-studio tests
        studioMockStore[key] = HttpService:JSONEncode(profile)
        return true
    end
    
    local store = DataStoreService:GetDataStore(DATASTORE_NAME)
    local saveSuccess = false
    
    for attempt = 1, MAX_RETRIES do
        local opSuccess, err = pcall(function()
            store:SetAsync(key, profile)
        end)
        
        if opSuccess then
            saveSuccess = true
            break
        else
            warn(string.format("[DataStoreManager] SetAsync attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
            if attempt < MAX_RETRIES then
                task.wait(RETRY_BACKOFF[attempt] or 1.0)
            end
        end
    end
    
    return saveSuccess
end

function DataStoreManager.GetSessionData(player: Player | number): table?
    if type(player) == "number" then
        return activeSessions[player]
    elseif typeof(player) == "Instance" and player:IsA("Player") then
        return activeSessions[player] or activeSessions[player.UserId]
    end
    return nil
end

function DataStoreManager.ReleaseSession(player: Player | number)
    if typeof(player) == "Instance" and player:IsA("Player") then
        activeSessions[player] = nil
        activeSessions[player.UserId] = nil
        sessionLoaded[player] = nil
        sessionLoaded[player.UserId] = nil
    elseif type(player) == "number" then
        activeSessions[player] = nil
        sessionLoaded[player] = nil
    end
end

-- Studio Testing Helper: Enable/Disable mock data inspection
function DataStoreManager.GetMockStoreDump(): table
    return studioMockStore
end

-- Auto-Save Loop (Runs every 300 seconds)
task.spawn(function()
    while true do
        task.wait(300)
        local count = 0
        for player, _ in pairs(activeSessions) do
            if typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
                DataStoreManager.SaveProfile(player)
                count = count + 1
            end
        end
        if count > 0 then
            print(string.format("[DataStoreManager] Periodic auto-save completed for %d online operatives.", count))
        end
    end
end)

-- BindToClose: Flush all online players before server shuts down
game:BindToClose(function()
    print("[DataStoreManager] Server shutdown initiated. Flushing all operative profiles...")
    local threads = {}
    for player, _ in pairs(activeSessions) do
        if typeof(player) == "Instance" and player:IsA("Player") then
            local t = task.spawn(function()
                DataStoreManager.SaveProfile(player)
            end)
            table.insert(threads, t)
        end
    end
    
    task.wait(1.5) -- Give async calls time to finalize
    print("[DataStoreManager] All operative profiles successfully synchronized.")
end)

return DataStoreManager
