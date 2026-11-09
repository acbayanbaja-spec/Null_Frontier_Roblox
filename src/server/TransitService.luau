-- TransitService for NULL FRONTIER
-- Coordinates seamless fast-transit between Central Nexus, Escobillo's Maze, Apex Arena, and Frontier Wilds.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local function teleportChar(player: Player, targetPos: Vector3)
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 3, 0)))
        print(string.format("[TransitService] Teleported operative %s to %s.", player.Name, tostring(targetPos)))
    end
end

local function wirePrompt(prompt: ProximityPrompt?, callback: (Player) -> ())
    if prompt then
        prompt.Triggered:Connect(callback)
    end
end

task.defer(function()
    local nte = workspace.World:WaitForChild("NexusTitanExpansion", 10)
    local station = nte and nte:WaitForChild("NexusTransitStation", 10)
    
    if station then
        local mazeGate = station:FindFirstChild("TravelTo_Maze")
        local pMaze = mazeGate and mazeGate:FindFirstChildOfClass("ProximityPrompt")
        wirePrompt(pMaze, function(player)
            teleportChar(player, Vector3.new(0, 14, -850))
        end)
        
        local arenaGate = station:FindFirstChild("TravelTo_Arena")
        local pArena = arenaGate and arenaGate:FindFirstChildOfClass("ProximityPrompt")
        wirePrompt(pArena, function(player)
            teleportChar(player, Vector3.new(1005, 12, 0))
        end)
        
        local wildsGate = station:FindFirstChild("TravelTo_Wilds")
        local pWilds = wildsGate and wildsGate:FindFirstChildOfClass("ProximityPrompt")
        wirePrompt(pWilds, function(player)
            teleportChar(player, Vector3.new(-1000, 12, 0))
        end)
    end
    
    -- Return pads
    local NEXUS_RETURN_POS = Vector3.new(70, 12, 60)
    
    local arena = workspace.World:WaitForChild("CombatArena_Titan", 10)
    local arenaReturn = arena and arena:WaitForChild("ArenaReturnPad", 10)
    local pArenaRet = arenaReturn and arenaReturn:FindFirstChildOfClass("ProximityPrompt")
    wirePrompt(pArenaRet, function(player)
        teleportChar(player, NEXUS_RETURN_POS)
    end)
    
    local wilds = workspace.World:WaitForChild("FrontierWilds_Titan", 10)
    local wildsReturn = wilds and wilds:WaitForChild("WildsReturnPad", 10)
    local pWildsRet = wildsReturn and wildsReturn:FindFirstChildOfClass("ProximityPrompt")
    wirePrompt(pWildsRet, function(player)
        teleportChar(player, NEXUS_RETURN_POS)
    end)
    
    local maze = workspace.World:WaitForChild("EscobillosMaze_Titan", 10)
    local s1 = maze and maze:WaitForChild("Sector1_SunlitEntrance", 10)
    local mazeReturn = s1 and s1:WaitForChild("MazeReturnPad", 10)
    local pMazeRet = mazeReturn and mazeReturn:FindFirstChildOfClass("ProximityPrompt")
    wirePrompt(pMazeRet, function(player)
        teleportChar(player, NEXUS_RETURN_POS)
    end)
    
    -- Dropship flight recorder cache
    local cache = wilds and wilds:FindFirstChild("DropshipDataCache", true)
    local pCache = cache and cache:FindFirstChildOfClass("ProximityPrompt")
    wirePrompt(pCache, function(player)
        local RewardService = require(script.Parent:WaitForChild("RewardService"))
        RewardService.GrantReward(player, "FLIGHT RECORDER SALVAGED", 120, 200, "Dropship_Recorder")
        pCache.Enabled = false
        task.delay(60, function()
            pCache.Enabled = true
        end)
    end)
    
    -- Story NPC Consultations
    local npcsFolder = workspace.World:FindFirstChild("StoryNPCs")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local NullFrontier = ReplicatedStorage:FindFirstChild("NullFrontier")
    local PlayerNotificationRE = NullFrontier and NullFrontier:FindFirstChild("Remotes") and NullFrontier.Remotes:FindFirstChild("PlayerNotification")
    
    local npcDialogues = {
        Jahred = {"COMMANDER JAHRED", "Operative, welcome to Central Nexus. Check your tactical logs and explore the Proving Grounds."},
        Angel = {"SPECIALIST ANGEL", "The matrix arrays in Sector 6 are unstable. Synchronize all 3 puzzle nodes before opening Blast Door Omega."},
        JohnSteve = {"SCOUT JOHNSTEVE", "Watch your step past the river gorge. A downed dropship holds valuable telemetry if you can reach it."},
        Joyce = {"ANALYST JOYCE", "Long-range sensors detect high-energy resonance in Escobillo's core. The Golden Key awaits in Sector 7."},
        JesselMae = {"QUARTERMASTER JESSELMAE", "Credits earned from trials and arena duels are recognized across all sectors. Stay sharp out there."}
    }
    
    if npcsFolder and PlayerNotificationRE then
        for name, data in pairs(npcDialogues) do
            local model = npcsFolder:FindFirstChild(name)
            local prompt = model and model:FindFirstChildOfClass("ProximityPrompt", true)
            wirePrompt(prompt, function(player)
                PlayerNotificationRE:FireClient(player, data[1], data[2], 5.0)
                print(string.format("[TransitService] %s consulted %s.", player.Name, data[1]))
            end)
        end
    end
    
    print("[TransitService] All 4-Way Fast-Transit hubs and NPC uplinks operational.")
end)
