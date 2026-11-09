-- CombatController for NULL FRONTIER
-- Client-side attack triggering, mobile strike controls, floating damage numbers, and match feedback.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local RequestAttackRE = Remotes:WaitForChild("RequestAttack")
local EntityDamagedRE = Remotes:WaitForChild("EntityDamaged")
local MatchStateNotificationRE = Remotes:WaitForChild("MatchStateNotification")

local lastAttackTime = 0
local ATTACK_COOLDOWN = 0.45

-- Resolve Best Target within melee cone
local function findMeleeTarget(): Instance?
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local forward = hrp.CFrame.LookVector
    local origin = hrp.Position
    local bestTarget = nil
    local bestDist = 12.0
    
    -- Check Maze Enemies
    local maze = Workspace.World:FindFirstChild("EscobillosMaze")
    if maze then
        for _, child in ipairs(maze:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
                local root = child:FindFirstChild("HumanoidRootPart")
                if root and child.Humanoid.Health > 0 then
                    local offset = root.Position - origin
                    local dist = offset.Magnitude
                    if dist <= bestDist then
                        local dot = forward:Dot(offset.Unit)
                        if dot > 0.3 then -- In front
                            bestDist = dist
                            bestTarget = child
                        end
                    end
                end
            end
        end
    end
    
    -- Check Other Players
    for _, otherP in ipairs(Players:GetPlayers()) do
        if otherP ~= player then
            local oChar = otherP.Character
            local oHum = oChar and oChar:FindFirstChildOfClass("Humanoid")
            local oRoot = oChar and oChar:FindFirstChild("HumanoidRootPart")
            if oHum and oHum.Health > 0 and oRoot then
                local offset = oRoot.Position - origin
                local dist = offset.Magnitude
                if dist <= bestDist then
                    local dot = forward:Dot(offset.Unit)
                    if dot > 0.3 then
                        bestDist = dist
                        bestTarget = oChar
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Perform Attack
local function triggerAttack()
    local now = os.clock()
    if now - lastAttackTime < ATTACK_COOLDOWN then return end
    lastAttackTime = now
    
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    
    local target = findMeleeTarget()
    RequestAttackRE:FireServer("LightAttack", target)
    
    -- Visual swing feedback: subtle weapon/hand impulse
    local wepModel = char:FindFirstChild("Equip_Weapon")
    if wepModel and wepModel.PrimaryPart then
        local p = wepModel.PrimaryPart
        p.Color = Color3.fromRGB(255, 255, 255)
        task.delay(0.12, function()
            p.Color = Color3.fromRGB(0, 220, 255)
        end)
    end
end

-- Hook Mouse & Keyboard Inputs
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
        triggerAttack()
    end
end)

-- Hook Mobile Strike Button
task.spawn(function()
    local pgui = player:WaitForChild("PlayerGui")
    local hud = pgui:WaitForChild("NullFrontierHUD", 10)
    local mc = hud and hud:WaitForChild("MainContainer", 10) and hud.MainContainer:WaitForChild("MobileControls", 10)
    local atkBtn = mc and mc:WaitForChild("AttackButton", 10)
    if atkBtn then
        atkBtn.Activated:Connect(triggerAttack)
    end
end)

-- Floating Damage Numbers FX
EntityDamagedRE.OnClientEvent:Connect(function(targetModel, damageAmount, isShieldDamage, newHealth)
    local root = targetModel and (targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Head") or targetModel.PrimaryPart)
    
    pcall(function()
        local SoundService = game:GetService("SoundService")
        local ma = SoundService:FindFirstChild("MasterAudio")
        local sfx = ma and ma:FindFirstChild("SFXGroup")
        local hitSnd = sfx and sfx:FindFirstChild("SFX_Hit")
        if hitSnd then hitSnd:Play() end
    end)
    if not root then return end
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "DamageIndicator"
    bb.Size = UDim2.new(0, 80, 0, 30)
    bb.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.5, math.random(-10, 10) / 10)
    bb.AlwaysOnTop = true
    bb.Adornee = root
    bb.Parent = root
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack
    lbl.Text = "-" .. tostring(math.floor(damageAmount))
    lbl.TextColor3 = isShieldDamage and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 70, 70)
    lbl.TextSize = 16
    lbl.Parent = bb
    
    TweenService:Create(bb, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0)
    }):Play()
    
    TweenService:Create(lbl, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 1
    }):Play()
    
    task.delay(0.7, function() bb:Destroy() end)
end)

-- Match State Notification Toasts
MatchStateNotificationRE.OnClientEvent:Connect(function(matchType, state, payload)
    print(string.format("[MatchState] %s -> %s", matchType, state))
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        local hud = pgui and pgui:FindFirstChild("NullFrontierHUD")
        if not hud then return end
        
        local toast = Instance.new("Frame")
        toast.Name = "MatchToast"
        toast.Size = UDim2.new(0, 320, 0, 44)
        toast.Position = UDim2.new(0.5, -160, 0.15, 0)
        toast.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
        toast.BackgroundTransparency = 0.15
        toast.BorderSizePixel = 0
        toast.Parent = hud
        
        local corner = Instance.new("UICorner", toast)
        corner.CornerRadius = UDim.new(0, 6)
        
        local stroke = Instance.new("UIStroke", toast)
        stroke.Color = Color3.fromRGB(0, 220, 255)
        stroke.Thickness = 1.2
        
        local title = Instance.new("TextLabel", toast)
        title.Size = UDim2.new(1, -16, 1, 0)
        title.Position = UDim2.new(0, 8, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextColor3 = Color3.fromRGB(0, 255, 200)
        title.TextSize = 13
        title.Text = string.format("[%s] %s", matchType:upper(), state:upper())
        
        if payload and payload.Checkpoint then
            title.Text = string.format("[%s] CHECKPOINT: %s", matchType:upper(), tostring(payload.Checkpoint):upper():gsub("_", " "))
        end
        
        TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -160, 0.17, 0)
        }):Play()
        
        task.delay(3.0, function()
            local tw = TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            })
            tw:Play()
            TweenService:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1
            }):Play()
            tw.Completed:Connect(function() toast:Destroy() end)
        end)
    end)
end)

print("[NullFrontier] CombatController initialized.")
