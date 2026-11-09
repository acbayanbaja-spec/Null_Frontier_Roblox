-- EnemyAIManager for NULL FRONTIER
-- Original cybernetic AI adversaries with state machine: Patrol -> Chase -> Attack -> Return.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local EntityDamagedRE = Remotes:WaitForChild("EntityDamaged")

local EnemyAIManager = {}
local activeEnemies = {} -- model -> enemyData

local function buildEnemyModel(name: string, spawnPos: Vector3, maxHealth: number, color: Color3): Model
    local model = Instance.new("Model")
    model.Name = name
    
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2.4, 4.5, 2.4)
    hrp.Position = spawnPos
    hrp.CanCollide = true
    hrp.Material = Enum.Material.SmoothPlastic
    hrp.Color = Color3.fromRGB(242, 246, 252)
    hrp.Parent = model
    
    local chest = Instance.new("Part")
    chest.Name = "ArmorPlate"
    chest.Size = Vector3.new(2.6, 2.8, 2.6)
    chest.CFrame = hrp.CFrame
    chest.Material = Enum.Material.Metal
    chest.Color = (name == "FrontierCorruptor_Alpha") and Color3.fromRGB(215, 140, 45) or Color3.fromRGB(195, 120, 60)
    chest.CanCollide = false
    chest.CanTouch = false
    chest.CanQuery = false
    chest.Parent = model
    local w2 = Instance.new("WeldConstraint")
    w2.Part0 = chest
    w2.Part1 = hrp
    w2.Parent = chest
    
    local eye = Instance.new("Part")
    eye.Name = "OpticSensor"
    eye.Size = Vector3.new(1.8, 0.4, 0.5)
    eye.CFrame = hrp.CFrame * CFrame.new(0, 1.2, -1.25)
    eye.CanCollide = false
    eye.Material = Enum.Material.Neon
    eye.Color = color
    eye.Parent = model
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = eye
    weld.Part1 = hrp
    weld.Parent = eye
    
    local hum = Instance.new("Humanoid")
    hum.MaxHealth = maxHealth
    hum.Health = maxHealth
    hum.WalkSpeed = (name == "FrontierCorruptor_Alpha") and 11 or 14
    hum.Parent = model
    
    -- Overhead Health Bar
    local bb = Instance.new("BillboardGui")
    bb.Name = "HealthTag"
    bb.Size = UDim2.new(0, 110, 0, 24)
    bb.StudsOffset = Vector3.new(0, 3.8, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.Parent = hrp
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 1, -6)
    bar.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
    bar.BorderSizePixel = 0
    bar.Parent = bb
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)
    
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = name:upper():gsub("_", " ")
    title.TextColor3 = color
    title.TextSize = 9
    title.Parent = bb
    
    hum.HealthChanged:Connect(function(newHealth)
        local ratio = math.clamp(newHealth / maxHealth, 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
    end)
    
    model.PrimaryPart = hrp
    local mazeFolder = workspace.World:FindFirstChild("EscobillosMaze_Titan") or workspace.World:FindFirstChild("EscobillosMaze") or workspace.World
    model.Parent = mazeFolder
    return model
end

-- Initialize Adversaries
function EnemyAIManager.Initialize()
    local maze = workspace.World:FindFirstChild("EscobillosMaze_Titan") or workspace.World:WaitForChild("EscobillosMaze", 5)
    
    local enemyConfigs = {
        { Name = "NullSentinel_1", Spawn = Vector3.new(-150, 14, -1050), Waypoints = {Vector3.new(-150, 14, -1000), Vector3.new(-150, 14, -1100)}, HP = 80, Color = Color3.fromRGB(255, 60, 60), Dmg = 14 },
        { Name = "NullSentinel_2", Spawn = Vector3.new(-300, 14, -1250), Waypoints = {Vector3.new(-300, 14, -1200), Vector3.new(-300, 14, -1350)}, HP = 80, Color = Color3.fromRGB(255, 60, 60), Dmg = 14 },
        { Name = "FrontierCorruptor_Alpha", Spawn = Vector3.new(0, -4, -1600), Waypoints = {Vector3.new(-50, -4, -1600), Vector3.new(50, -4, -1600)}, HP = 160, Color = Color3.fromRGB(255, 140, 20), Dmg = 24 },
    }
    
    for _, cfg in ipairs(enemyConfigs) do
        local model = buildEnemyModel(cfg.Name, cfg.Spawn, cfg.HP, cfg.Color)
        local data = {
            Config = cfg,
            Model = model,
            Humanoid = model.Humanoid,
            RootPart = model.HumanoidRootPart,
            State = "Patrol",
            CurrentWaypointIdx = 1,
            LastAttackTime = 0,
            TargetPlayer = nil
        }
        activeEnemies[model] = data
        
        -- Defeat Handler
        model.Humanoid.Died:Connect(function()
            print(string.format("[EnemyAIManager] Adversary '%s' neutralized!", cfg.Name))
            -- Find closest player to award rewards
            local bestPlayer = nil
            local bestDist = 50
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local d = (char.HumanoidRootPart.Position - data.RootPart.Position).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestPlayer = p
                    end
                end
            end
            
            if bestPlayer then
                local RewardService = require(script.Parent:WaitForChild("RewardService"))
                local xpRwd = (cfg.Name == "FrontierCorruptor_Alpha") and 200 or 100
                local crRwd = (cfg.Name == "FrontierCorruptor_Alpha") and 350 or 150
                RewardService.GrantReward(bestPlayer, "HOSTILE NEUTRALIZED: " .. cfg.Name, xpRwd, crRwd, "Defeat_" .. cfg.Name)
            end
            
            activeEnemies[model] = nil
            task.delay(3.0, function() model:Destroy() end)
        end)
    end
    
    print("[EnemyAIManager] 3 Maze adversaries materialized.")
end

-- Lightweight 0.3s State-Machine Loop (Tick-Budgeted)
task.spawn(function()
    while true do
        task.wait(0.3)
        local now = os.clock()
        
        for model, data in pairs(activeEnemies) do
            local hum = data.Humanoid
            local hrp = data.RootPart
            if hum and hum.Health > 0 and hrp then
                -- 1. Scan for nearest operative
                local closestChar = nil
                local closestDist = 28.0 -- Detection range
                
                for _, player in ipairs(Players:GetPlayers()) do
                    local char = player.Character
                    local pHum = char and char:FindFirstChildOfClass("Humanoid")
                    local pHrp = char and char:FindFirstChild("HumanoidRootPart")
                    if pHum and pHum.Health > 0 and pHrp then
                        local d = (pHrp.Position - hrp.Position).Magnitude
                        if d < closestDist then
                            closestDist = d
                            closestChar = char
                        end
                    end
                end
                
                if closestChar then
                    data.TargetPlayer = closestChar
                    data.State = "Chase"
                    hum:MoveTo(closestChar.HumanoidRootPart.Position)
                    
                    -- Attack Check
                    if closestDist <= 7.0 and (now - data.LastAttackTime >= 1.6) then
                        data.LastAttackTime = now
                        local targetPlayer = Players:GetPlayerFromCharacter(closestChar)
                        if targetPlayer then
                            local dmg = data.Config.Dmg
                            local currentShield = targetPlayer:GetAttribute("Shield") or 0
                            if currentShield >= dmg then
                                targetPlayer:SetAttribute("Shield", currentShield - dmg)
                            else
                                local rem = dmg - currentShield
                                targetPlayer:SetAttribute("Shield", 0)
                                closestChar.Humanoid:TakeDamage(rem)
                            end
                            EntityDamagedRE:FireAllClients(closestChar, dmg, currentShield > 0, closestChar.Humanoid.Health)
                            print(string.format("[EnemyAIManager] %s attacked %s for %d dmg.", data.Config.Name, targetPlayer.Name, dmg))
                        end
                    end
                else
                    -- Patrol State
                    data.State = "Patrol"
                    data.TargetPlayer = nil
                    local wpList = data.Config.Waypoints
                    local targetWp = wpList[data.CurrentWaypointIdx]
                    if targetWp then
                        hum:MoveTo(targetWp)
                        if (hrp.Position - targetWp).Magnitude < 6.0 then
                            data.CurrentWaypointIdx = (data.CurrentWaypointIdx % #wpList) + 1
                        end
                    end
                end
            end
        end
    end
end)

return EnemyAIManager
