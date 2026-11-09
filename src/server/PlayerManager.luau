-- PlayerManager for NULL FRONTIER
-- Coordinates character lifecycle, progression loading, data persistence, and server-authoritative stamina/movement.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local Remotes = NullFrontier.Remotes
local RequestSprint = Remotes:WaitForChild("RequestSprint")
local TestDamage = Remotes:WaitForChild("TestDamage")

local MarketplaceManager = require(script.Parent:WaitForChild("MarketplaceManager"))
local SocialManager = require(script.Parent:WaitForChild("SocialManager"))
local ProgressionManager = require(script.Parent:WaitForChild("ProgressionManager"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
local MissionManager = require(script.Parent:WaitForChild("MissionManager"))
local AchievementManager = require(script.Parent:WaitForChild("AchievementManager"))
local InventoryManager = require(script.Parent:WaitForChild("InventoryManager"))
local CombatManager = require(script.Parent:WaitForChild("CombatManager"))
local EnemyAIManager = require(script.Parent:WaitForChild("EnemyAIManager"))
local MazeManager = require(script.Parent:WaitForChild("MazeManager"))
local ArenaManager = require(script.Parent:WaitForChild("ArenaManager"))

local CHECKPOINT_COORDS = {
    Checkpoint_Alpha = Vector3.new(0, 14, -850),
    Checkpoint_Beta = Vector3.new(-250, 14, -1250),
    Checkpoint_Gamma = Vector3.new(250, 28, -1300),
    Checkpoint_Delta = Vector3.new(0, -5, -1550),
    Checkpoint_Omega = Vector3.new(0, 16, -1850)
}

task.defer(function()
    EnemyAIManager.Initialize()
end)

local playerData = {}

local function setupPlayer(player: Player)
    playerData[player] = {
        LastDamageTime = 0,
        Stamina = GameConfig.MaxStamina,
        WantsToSprint = false,
        IsSprinting = false,
        IsExhausted = false,
        LastSprintEndTime = os.clock(),
        LastSprintReqTime = 0,
        LastPos = nil,
    }
    
    -- Set Initial Combat Attributes
    player:SetAttribute("MaxHealth", GameConfig.MaxHealth)
    player:SetAttribute("MaxShield", GameConfig.MaxShield)
    player:SetAttribute("Shield", GameConfig.MaxShield)
    player:SetAttribute("MaxStamina", GameConfig.MaxStamina)
    player:SetAttribute("Stamina", GameConfig.MaxStamina)
    player:SetAttribute("IsExhausted", false)
    player:SetAttribute("IsSprinting", false)
    player:SetAttribute("Status", GameConfig.DefaultStatus)
    
    -- Setup Progression (Loads persistent profile from DataStoreManager with session locking)
    ProgressionManager.SetupPlayer(player)
    
    -- Award first join achievement
    task.defer(function()
        AchievementManager.Unlock(player, "ACH_FIRST_BOOT")
    end)
    
    local function onCharacterAdded(character: Model)
        local humanoid = character:WaitForChild("Humanoid", 10)
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not hrp then return end
        
        -- Standard Roblox avatar preservation: Keep hair, accessories, clothes, proportions
        SocialManager.SetupCharacterSocial(player, character)
        InventoryManager.SetupCharacterEquipment(player, character)
        
        -- Checkpoint respawn routing
        local chk = player:GetAttribute("MazeCheckpoint")
        if chk and CHECKPOINT_COORDS[chk] then
            task.defer(function()
                if hrp and hrp.Parent then
                    hrp.CFrame = CFrame.new(CHECKPOINT_COORDS[chk] + Vector3.new(0, 3, 0))
                end
            end)
        end
        humanoid.WalkSpeed = GameConfig.WalkSpeed
        humanoid.MaxHealth = GameConfig.MaxHealth
        humanoid.Health = GameConfig.MaxHealth
        
        -- Safe respawn resets
        player:SetAttribute("Shield", GameConfig.MaxShield)
        player:SetAttribute("Stamina", GameConfig.MaxStamina)
        player:SetAttribute("IsExhausted", false)
        player:SetAttribute("IsSprinting", false)
        player:SetAttribute("Status", GameConfig.DefaultStatus)
        
        if playerData[player] then
            playerData[player].Stamina = GameConfig.MaxStamina
            playerData[player].WantsToSprint = false
            playerData[player].IsSprinting = false
            playerData[player].IsExhausted = false
            playerData[player].LastDamageTime = 0
            playerData[player].LastPos = hrp.Position
        end
        
        humanoid.Died:Connect(function()
            player:SetAttribute("Status", "OPERATIVE: KIA")
            player:SetAttribute("Shield", 0)
        end)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        task.spawn(onCharacterAdded, player.Character)
    end
end

local function cleanupPlayer(player: Player)
    -- Save and release session lock cleanly before removing from memory
    DataStoreManager.ReleaseSession(player)
    playerData[player] = nil
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

for _, p in ipairs(Players:GetPlayers()) do
    setupPlayer(p)
end

-- Server-Authoritative Sprint Request Handling
RequestSprint.OnServerEvent:Connect(function(player: Player, wantsToSprint: boolean)
    local data = playerData[player]
    if not data then return end
    
    local now = os.clock()
    -- Anti-spam debounce
    if now - data.LastSprintReqTime < 0.05 then
        return
    end
    data.LastSprintReqTime = now
    
    -- Register intent; server Heartbeat loop strictly validates physics & stamina
    data.WantsToSprint = (wantsToSprint == true)
    if not data.WantsToSprint and data.IsSprinting then
        data.LastSprintEndTime = now
    end
end)

-- Shield Absorption and Damage function
local function applyDamage(player: Player, amount: number)
    local data = playerData[player]
    if not data then return end
    
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    data.LastDamageTime = os.clock()
    
    local currentShield = player:GetAttribute("Shield") or 0
    if currentShield >= amount then
        player:SetAttribute("Shield", math.max(0, currentShield - amount))
    else
        local remainingDamage = amount - currentShield
        player:SetAttribute("Shield", 0)
        humanoid:TakeDamage(remainingDamage)
    end
end

-- Remote for Testing Shield & Damage
TestDamage.OnServerEvent:Connect(function(player: Player, amount: number)
    if not RunService:IsStudio() then return end
    if type(amount) ~= "number" then return end
    local safeAmount = math.clamp(amount, 1, 100)
    applyDamage(player, safeAmount)
end)

-- Heartbeat loop: Server-Authoritative Stamina, Shield Regen & Anti-Cheat WalkSpeed Enforcement
local distanceAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    distanceAccumulator = distanceAccumulator + dt
    
    for player, data in pairs(playerData) do
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and hrp then
                -- Menu check
                if player:GetAttribute("InMenu") == true then
                    if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
                    continue
                end
                
                -- 1. Shield Regeneration
                if now - data.LastDamageTime >= GameConfig.ShieldRegenDelay then
                    local currentShield = player:GetAttribute("Shield") or 0
                    local maxShield = player:GetAttribute("MaxShield") or GameConfig.MaxShield
                    if currentShield < maxShield then
                        local newShield = math.min(maxShield, currentShield + (GameConfig.ShieldRegenRate * dt))
                        player:SetAttribute("Shield", newShield)
                    end
                end
                
                -- 2. Server-Authoritative Stamina Simulation
                local isMoving = humanoid.MoveDirection.Magnitude > 0.05
                local canSprint = data.WantsToSprint and isMoving and not data.IsExhausted and data.Stamina > 0
                
                if canSprint then
                    -- Drain Stamina on Server
                    data.Stamina = math.max(0, data.Stamina - (GameConfig.StaminaDrainRate * dt))
                    data.IsSprinting = true
                    humanoid.WalkSpeed = GameConfig.SprintSpeed
                    
                    if data.Stamina <= 0 then
                        -- Exhaustion Triggered on Server
                        data.IsExhausted = true
                        data.IsSprinting = false
                        data.WantsToSprint = false
                        data.LastSprintEndTime = now
                        humanoid.WalkSpeed = GameConfig.WalkSpeed
                    end
                else
                    -- Resting / Normal Walk
                    data.IsSprinting = false
                    if humanoid.WalkSpeed > GameConfig.SprintSpeed then
                        -- Enforce maximum speed ceiling against speed exploits
                        humanoid.WalkSpeed = GameConfig.SprintSpeed
                    elseif humanoid.WalkSpeed ~= GameConfig.WalkSpeed then
                        humanoid.WalkSpeed = GameConfig.WalkSpeed
                    end
                    
                    if not data.WantsToSprint and data.LastSprintEndTime == 0 then
                        data.LastSprintEndTime = now
                    end
                    
                    -- Server Stamina Regeneration
                    if now - data.LastSprintEndTime >= GameConfig.StaminaRegenDelay then
                        if data.Stamina < GameConfig.MaxStamina then
                            data.Stamina = math.min(GameConfig.MaxStamina, data.Stamina + (GameConfig.StaminaRegenRate * dt))
                        end
                        -- Recover from exhaustion once above minimum sprint stamina threshold
                        if data.IsExhausted and data.Stamina >= GameConfig.MinSprintStamina then
                            data.IsExhausted = false
                        end
                    end
                end
                
                -- Replicate Authoritative Values
                player:SetAttribute("Stamina", math.floor(data.Stamina * 10) / 10)
                player:SetAttribute("IsExhausted", data.IsExhausted)
                player:SetAttribute("IsSprinting", data.IsSprinting)
                
                -- 3. Sprint Distance Measurement for Missions
                if data.IsSprinting and data.LastPos then
                    local dist = (hrp.Position - data.LastPos).Magnitude
                    if dist > 0.1 and dist < 50 then -- Sanity filter against teleports
                        MissionManager.RecordSprintDistance(player, dist)
                    end
                end
                data.LastPos = hrp.Position
            end
        end
    end
end)

-- Periodic 1.5-second Sector Exploration Observer
task.spawn(function()
    while true do
        task.wait(1.5)
        for player, data in pairs(playerData) do
            local character = player.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                if pos.X <= -800 and pos.X >= -2000 then
                    MissionManager.RecordDistrictVisited(player, "FrontierWilds")
                elseif pos.Z <= -800 and pos.Z >= -2200 then
                    MissionManager.RecordDistrictVisited(player, "EscobillosMaze")
                elseif pos.X >= 1000 and pos.X <= 1800 then
                    MissionManager.RecordDistrictVisited(player, "CombatArena")
                elseif math.abs(pos.X) <= 120 and pos.Z <= -75 and pos.Z >= -350 then
                    MissionManager.RecordDistrictVisited(player, "CommercialDistrict")
                elseif math.abs(pos.X) <= 120 and pos.Z >= 75 and pos.Z <= 350 then
                    MissionManager.RecordDistrictVisited(player, "FrontierTrainingYard")
                elseif pos.X >= 75 and pos.X <= 350 and math.abs(pos.Z) <= 120 then
                    MissionManager.RecordDistrictVisited(player, "TechnologyDistrict")
                elseif pos.X <= -75 and pos.X >= -350 and math.abs(pos.Z) <= 120 then
                    MissionManager.RecordDistrictVisited(player, "ResidentialDistrict")
                end
            end
        end
    end
end)

print("[NullFrontier] PlayerManager initialized (Authoritative Stamina + Session-Locking + Full Progression).")
