-- MazeManager for NULL FRONTIER
-- Match flow, party synchronization, checkpoint recovery, puzzle sequence, and story objectives.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local InteractPuzzleRF = Remotes:WaitForChild("InteractPuzzle")
local CollectGoldenKeyRF = Remotes:WaitForChild("CollectGoldenKey")
local JoinMazeQueueRF = Remotes:WaitForChild("JoinMazeQueue")
local LeaveMazeQueueRF = Remotes:WaitForChild("LeaveMazeQueue")
local MatchStateNotificationRE = Remotes:WaitForChild("MatchStateNotification")

local MazeManager = {}

local CHECKPOINT_COORDS = {
    Checkpoint_Alpha = Vector3.new(0, 12, -400),
    Checkpoint_Beta = Vector3.new(-85, 12, -480),
    Checkpoint_Omega = Vector3.new(85, 12, -560)
}

-- Puzzle State
local puzzleSequence = {"Terminal_Alpha", "Terminal_Beta", "Terminal_Gamma"}
local currentPuzzleStep = 1
local isVaultUnlocked = false

-- Teleport Player Safely
local function teleportChar(char: Model, targetPos: Vector3)
    if char and char:FindFirstChild("HumanoidRootPart") then
        char:PivotTo(CFrame.new(targetPos + Vector3.new(0, 2.5, 0)))
    end
end

-- 1. Deploy Player / Party into Maze
function MazeManager.DeployToMaze(player: Player, partyMode: boolean)
    local char = player.Character
    if not char then return false, "No operative character" end
    
    local playersToDeploy = {player}
    
    if partyMode then
        local SocialManager = require(script.Parent:WaitForChild("SocialManager"))
        local partyId = player:GetAttribute("PartyId")
        if partyId then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p:GetAttribute("PartyId") == partyId then
                    table.insert(playersToDeploy, p)
                end
            end
        end
    end
    
    for _, p in ipairs(playersToDeploy) do
        if p.Character then
            teleportChar(p.Character, CHECKPOINT_COORDS.Checkpoint_Alpha)
            p:SetAttribute("MazeCheckpoint", "Checkpoint_Alpha")
            MatchStateNotificationRE:FireClient(p, "Maze", "Deployed", { Checkpoint = "Checkpoint_Alpha" })
            print(string.format("[MazeManager] Deployed operative %s to Checkpoint Alpha.", p.Name))
        end
    end
    
    return true, "Deployed to Proving Grounds"
end

-- 2. Checkpoint Monitoring Loop
task.spawn(function()
    while true do
        task.wait(1.0)
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                -- Check Beta
                if (pos - CHECKPOINT_COORDS.Checkpoint_Beta).Magnitude < 16.0 then
                    if player:GetAttribute("MazeCheckpoint") ~= "Checkpoint_Beta" and player:GetAttribute("MazeCheckpoint") ~= "Checkpoint_Omega" then
                        player:SetAttribute("MazeCheckpoint", "Checkpoint_Beta")
                        MatchStateNotificationRE:FireClient(player, "Maze", "CheckpointReached", { Checkpoint = "Checkpoint_Beta" })
                        print(string.format("[MazeManager] Operative %s reached Checkpoint Beta.", player.Name))
                    end
                -- Check Omega
                elseif (pos - CHECKPOINT_COORDS.Checkpoint_Omega).Magnitude < 16.0 then
                    if player:GetAttribute("MazeCheckpoint") ~= "Checkpoint_Omega" then
                        player:SetAttribute("MazeCheckpoint", "Checkpoint_Omega")
                        MatchStateNotificationRE:FireClient(player, "Maze", "CheckpointReached", { Checkpoint = "Checkpoint_Omega" })
                        print(string.format("[MazeManager] Operative %s reached Checkpoint Omega.", player.Name))
                    end
                end
            end
        end
    end
end)

-- 3. Core Alignment Puzzle Logic
function MazeManager.InteractTerminal(player: Player, terminalName: string): (boolean, string)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end
    
    if isVaultUnlocked then
        return true, "Core Matrix already aligned. Blast Door unsealed."
    end
    
    local expectedTerminal = puzzleSequence[currentPuzzleStep]
    local maze = workspace.World:FindFirstChild("EscobillosMaze")
    local chamber = maze and maze:FindFirstChild("PuzzleChamber")
    local termModel = chamber and chamber:FindFirstChild(terminalName)
    if not termModel or not termModel:FindFirstChild("Console") then
        return false, "Terminal offline or unavailable"
    end
    local dist = (hrp.Position - termModel.Console.Position).Magnitude
    if dist > 18.0 then
        return false, "Operative is too far from terminal console"
    end
    
    if terminalName == expectedTerminal then
        -- Correct Step
        if termModel and termModel:FindFirstChild("Console") then
            termModel.Console.Color = Color3.fromRGB(0, 255, 160)
        end
        currentPuzzleStep = currentPuzzleStep + 1
        
        if currentPuzzleStep > #puzzleSequence then
            -- Puzzle Solved! Open Blast Door
            isVaultUnlocked = true
            local door = maze:FindFirstChild("BlastDoor_Omega")
            if door then
                door.Transparency = 0.85
                door.CanCollide = false
            end
            
            -- Reward all participants
            local RewardService = require(script.Parent:WaitForChild("RewardService"))
            RewardService.GrantReward(player, "PUZZLE SOLVED: CORE ALIGNMENT", 150, 250, "Puzzle_CoreMatrix")
            
            print(string.format("[MazeManager] Operative %s solved Core Alignment! Blast Door Omega UNSEALED.", player.Name))
            return true, "Core Matrix synchronized! Blast Door Omega opened!"
        else
            return true, string.format("Matrix node %d/3 aligned.", currentPuzzleStep - 1)
        end
    else
        -- Wrong sequence! Reset terminals
        currentPuzzleStep = 1
        if chamber then
            for _, tName in ipairs(puzzleSequence) do
                local m = chamber:FindFirstChild(tName)
                if m and m:FindFirstChild("Console") then
                    m.Console.Color = Color3.fromRGB(255, 60, 60)
                end
            end
            task.delay(1.5, function()
                if not isVaultUnlocked and chamber then
                    local colors = {Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 200, 60), Color3.fromRGB(180, 100, 255)}
                    for i, tName in ipairs(puzzleSequence) do
                        local m = chamber:FindFirstChild(tName)
                        if m and m:FindFirstChild("Console") then
                            m.Console.Color = colors[i] or Color3.fromRGB(0, 220, 255)
                        end
                    end
                end
            end)
        end
        return false, "Desynchronization error! Matrix reset."
    end
end

-- 4. Golden Key Story Objective
function MazeManager.ClaimGoldenKey(player: Player): (boolean, string)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "No character" end
    
    local maze = workspace.World:FindFirstChild("EscobillosMaze")
    local vault = maze and maze:FindFirstChild("SecretVault")
    local keyPart = vault and vault:FindFirstChild("StoryCollectible_GoldenKey")
    if not keyPart then return false, "Artefact unavailable" end
    
    local dist = (hrp.Position - keyPart.Position).Magnitude
    if dist > 15.0 then return false, "Too far from artefact pedestal" end
    if not isVaultUnlocked then return false, "Vault security blast door is sealed" end
    
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    if not profile then return false, "Session unavailable" end
    
    if profile.Inventory and profile.Inventory["STORY_GOLDEN_KEY"] then
        return false, "Story artefact already in operative possession"
    end
    
    if not profile.Inventory then profile.Inventory = {} end
    profile.Inventory["STORY_GOLDEN_KEY"] = {
        ItemId = "STORY_GOLDEN_KEY",
        AcquiredAt = os.time(),
        Quantity = 1
    }
    
    local RewardService = require(script.Parent:WaitForChild("RewardService"))
    RewardService.GrantReward(player, "STORY ARTEFACT: THE GOLDEN KEY", 300, 500, "Story_GoldenKey")
    
    keyPart.Transparency = 0.8
    print(string.format("[MazeManager] Operative %s claimed THE GOLDEN KEY!", player.Name))
    return true, "THE GOLDEN KEY SECURED! Archive protocol initiated."
end

-- 5. Safe Extraction
function MazeManager.ExtractToNexus(player: Player)
    local char = player.Character
    if char then
        teleportChar(char, Vector3.new(0, 12, 0))
        player:SetAttribute("MazeCheckpoint", nil)
        MatchStateNotificationRE:FireClient(player, "Maze", "Extracted", {})
        print(string.format("[MazeManager] Operative %s safely evacuated to Central Nexus.", player.Name))
    end
end

-- Wire Proximity Prompts
task.spawn(function()
    local gateway = workspace.World:WaitForChild("EscobilloGateway", 10)
    local prompt = gateway and gateway:FindFirstChild("PortalField") and gateway.PortalField:FindFirstChild("PortalPrompt")
    if prompt then
        prompt.Triggered:Connect(function(player)
            MazeManager.DeployToMaze(player, true)
        end)
    end
    
    local maze = workspace.World:WaitForChild("EscobillosMaze", 10)
    local chamber = maze and maze:WaitForChild("PuzzleChamber", 10)
    if chamber then
        for _, term in ipairs(chamber:GetChildren()) do
            local console = term:FindFirstChild("Console")
            local p = console and console:FindFirstChild("PuzzlePrompt")
            if p then
                p.Triggered:Connect(function(player)
                    MazeManager.InteractTerminal(player, term.Name)
                end)
            end
        end
    end
    
    local vault = maze and maze:WaitForChild("SecretVault", 10)
    local keyPart = vault and vault:WaitForChild("StoryCollectible_GoldenKey", 10)
    local kp = keyPart and keyPart:FindFirstChild("KeyPrompt")
    if kp then
        kp.Triggered:Connect(function(player)
            MazeManager.ClaimGoldenKey(player)
        end)
    end
    
    local extractPad = vault and vault:WaitForChild("ExtractionPortal", 10)
    local ep = extractPad and extractPad:FindFirstChild("ExtractPrompt")
    if ep then
        ep.Triggered:Connect(function(player)
            MazeManager.ExtractToNexus(player)
        end)
    end
end)

-- Remote Invocations
InteractPuzzleRF.OnServerInvoke = function(player: Player, puzzleId: string, switchName: string)
    return MazeManager.InteractTerminal(player, switchName)
end

CollectGoldenKeyRF.OnServerInvoke = function(player: Player)
    return MazeManager.ClaimGoldenKey(player)
end

JoinMazeQueueRF.OnServerInvoke = function(player: Player, partyMode: boolean)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local gateway = workspace.World:FindFirstChild("EscobilloGateway")
    local portal = gateway and gateway:FindFirstChild("PortalField")
    if hrp and portal then
        local dist = (hrp.Position - portal.Position).Magnitude
        if dist > 40.0 then
            return false, "Must be near the Escobillo Gateway to enter"
        end
    end
    return MazeManager.DeployToMaze(player, partyMode)
end

LeaveMazeQueueRF.OnServerInvoke = function(player: Player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local maze = workspace.World:FindFirstChild("EscobillosMaze")
    local vault = maze and maze:FindFirstChild("SecretVault")
    local pad = vault and vault:FindFirstChild("ExtractionPortal")
    if hrp and pad then
        local dist = (hrp.Position - pad.Position).Magnitude
        if dist > 20.0 then
            return false, "Must be on the Extraction Pad to extract"
        end
    end
    MazeManager.ExtractToNexus(player)
    return true
end

return MazeManager
