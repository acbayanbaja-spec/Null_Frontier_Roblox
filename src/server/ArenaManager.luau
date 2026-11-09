-- ArenaManager for NULL FRONTIER
-- Competitive arena match flow, queue staging, spawn allocation, countdown, and reward distribution.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local JoinArenaQueueRF = Remotes:WaitForChild("JoinArenaQueue")
local LeaveArenaQueueRF = Remotes:WaitForChild("LeaveArenaQueue")
local MatchStateNotificationRE = Remotes:WaitForChild("MatchStateNotification")

local ArenaManager = {}
local arenaQueue = {} -- array of players
local isMatchActive = false

local SPAWN_A = Vector3.new(1100, 14, 0)
local SPAWN_B = Vector3.new(1700, 14, 0)
local EXIT_POS = Vector3.new(1000, 12, 0)

function ArenaManager.JoinQueue(player: Player): (boolean, string)
    if isMatchActive then return false, "Match currently in progress" end
    
    for _, p in ipairs(arenaQueue) do
        if p == player then return false, "Already in queue" end
    end
    
    table.insert(arenaQueue, player)
    print(string.format("[ArenaManager] %s joined Apex Arena queue (%d waiting).", player.Name, #arenaQueue))
    
    -- If 2 players queued (or solo duel start)
    if #arenaQueue >= 1 then
        task.defer(function()
            ArenaManager.StartMatch()
        end)
    end
    
    return true, "Queued for Apex Arena"
end

function ArenaManager.LeaveQueue(player: Player): (boolean, string)
    for idx, p in ipairs(arenaQueue) do
        if p == player then
            table.remove(arenaQueue, idx)
            return true, "Removed from queue"
        end
    end
    return false, "Not in queue"
end

function ArenaManager.StartMatch()
    if isMatchActive or #arenaQueue == 0 then return end
    isMatchActive = true
    
    local fighterA = arenaQueue[1]
    local fighterB = arenaQueue[2] or nil
    arenaQueue = {}
    
    local fighters = {fighterA}
    if fighterB then table.insert(fighters, fighterB) end
    
    -- Teleport to Spawns
    if fighterA and fighterA.Character and fighterA.Character:FindFirstChild("HumanoidRootPart") then
        fighterA.Character:PivotTo(CFrame.new(SPAWN_A + Vector3.new(0, 2, 0)))
    end
    if fighterB and fighterB.Character and fighterB.Character:FindFirstChild("HumanoidRootPart") then
        fighterB.Character:PivotTo(CFrame.new(SPAWN_B + Vector3.new(0, 2, 0)))
    end
    
    for _, f in ipairs(fighters) do
        MatchStateNotificationRE:FireClient(f, "Arena", "MatchStarted", { Duration = 45 })
    end
    
    print(string.format("[ArenaManager] Apex Arena Round commenced."))
    
    -- Match Timer
    task.delay(45, function()
        ArenaManager.EndMatch(fighters)
    end)
end

function ArenaManager.EndMatch(fighters: table)
    isMatchActive = false
    local RewardService = require(script.Parent:WaitForChild("RewardService"))
    
    for _, f in ipairs(fighters) do
        if f and f.Parent then
            RewardService.GrantReward(f, "ARENA COMPLETION: APEX PROVING", 200, 400, "Arena_MatchPayout")
            if f.Character and f.Character:FindFirstChild("HumanoidRootPart") then
                f.Character:PivotTo(CFrame.new(EXIT_POS + Vector3.new(0, 2, 0)))
            end
            MatchStateNotificationRE:FireClient(f, "Arena", "MatchEnded", {})
        end
    end
    print("[ArenaManager] Apex Arena Round finalized. Rewards distributed.")
end

-- Wire Entrance Prompts
task.spawn(function()
    local function wirePrompt(prompt: ProximityPrompt?)
        if prompt then
            prompt.Triggered:Connect(function(player)
                ArenaManager.JoinQueue(player)
            end)
        end
    end
    
    local arenaFolder = workspace.World:FindFirstChild("CombatArena")
    local gate = arenaFolder and arenaFolder:FindFirstChild("ArenaEntranceGate")
    local prompt = gate and gate:FindFirstChild("GatePortal") and gate.GatePortal:FindFirstChild("ArenaPrompt")
    wirePrompt(prompt)
    
    local titanArena = workspace.World:FindFirstChild("CombatArena_Titan")
    local queueTerm = titanArena and titanArena:FindFirstChild("ArenaQueueTerminal", true)
    local titanPrompt = queueTerm and queueTerm:FindFirstChild("Console") and queueTerm.Console:FindFirstChild("ArenaPrompt")
    wirePrompt(titanPrompt)
end)

JoinArenaQueueRF.OnServerInvoke = function(player: Player)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local arena = workspace.World:FindFirstChild("CombatArena")
    local gate = arena and arena:FindFirstChild("ArenaEntranceGate")
    local portal = gate and gate:FindFirstChild("GatePortal")
    if hrp and portal then
        local dist = (hrp.Position - portal.Position).Magnitude
        if dist > 40.0 then
            return false, "Must be near the Arena Entrance to enter"
        end
    end
    return ArenaManager.JoinQueue(player)
end

LeaveArenaQueueRF.OnServerInvoke = function(player: Player)
    return ArenaManager.LeaveQueue(player)
end

return ArenaManager
