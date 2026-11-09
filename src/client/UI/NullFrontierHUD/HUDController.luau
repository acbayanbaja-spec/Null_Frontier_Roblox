-- HUDController for NULL FRONTIER
-- Compact, elegant player dossier and mobile action pad controller.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local Remotes = NullFrontier.Remotes
local LocalSprintToggle = Remotes:WaitForChild("LocalSprintToggle")
local TestDamage = Remotes:WaitForChild("TestDamage")

local screenGui = script.Parent
local mainContainer = screenGui:WaitForChild("MainContainer")
local statusPanel = mainContainer:WaitForChild("StatusPanel")
local header = statusPanel:WaitForChild("Header")
local barsContainer = statusPanel:WaitForChild("BarsContainer")
local mobileControls = mainContainer:WaitForChild("MobileControls")
local sprintBtn = mobileControls:WaitForChild("SprintButton")
local attackBtn = mobileControls:FindFirstChild("AttackButton")
local interactBtn = mobileControls:FindFirstChild("InteractButton")

local userLabel = header:WaitForChild("UsernameLabel")
local statusLabel = header:WaitForChild("StatusLabel")
local levelText = header:WaitForChild("LevelBadge"):WaitForChild("LevelText")
local creditsBadge = header:WaitForChild("CreditsBadge")
local creditsText = creditsBadge:WaitForChild("CreditsText")
local avatarImage = header:WaitForChild("AvatarFrame"):WaitForChild("AvatarImage")

local shieldBar = barsContainer:WaitForChild("ShieldBarContainer")
local shieldFill = shieldBar:WaitForChild("Track"):WaitForChild("Fill")
local shieldValue = shieldBar:WaitForChild("ValueLabel")

local healthBar = barsContainer:WaitForChild("HealthBarContainer")
local healthFill = healthBar:WaitForChild("Track"):WaitForChild("Fill")
local healthValue = healthBar:WaitForChild("ValueLabel")

local staminaBar = barsContainer:WaitForChild("StaminaBarContainer")
local staminaFill = staminaBar:WaitForChild("Track"):WaitForChild("Fill")
local staminaValue = staminaBar:WaitForChild("ValueLabel")

local xpBar = barsContainer:WaitForChild("XPBarContainer")
local xpFill = xpBar:WaitForChild("Track"):WaitForChild("Fill")
local xpValue = xpBar:WaitForChild("ValueLabel")

-- Set Player Identity
userLabel.Text = (player.DisplayName ~= "" and player.DisplayName or player.Name):upper()
task.spawn(function()
    pcall(function()
        local thumbType = Enum.ThumbnailType.HeadShot
        local thumbSize = Enum.ThumbnailSize.Size100x100
        local content, isReady = Players:GetUserThumbnailAsync(player.UserId, thumbType, thumbSize)
        if isReady and content then
            avatarImage.Image = content
        end
    end)
end)

-- Mobile touch detection
local function updateMobileControls()
    mobileControls.Visible = UserInputService.TouchEnabled
end
updateMobileControls()
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateMobileControls)

-- Mobile Sprint Button Interactions
local mobileSprintActive = false
sprintBtn.Activated:Connect(function()
    mobileSprintActive = not mobileSprintActive
    LocalSprintToggle:Fire(mobileSprintActive)
    
    local stroke = sprintBtn:FindFirstChild("Stroke") or sprintBtn:FindFirstChildOfClass("UIStroke")
    if mobileSprintActive then
        sprintBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
        sprintBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end
    else
        sprintBtn.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
        sprintBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
        if stroke then stroke.Color = Color3.fromRGB(0, 220, 255) end
    end
end)

-- Mobile Attack Button Interaction (Forward to Combat Remote or TestDamage)
if attackBtn then
    attackBtn.Activated:Connect(function()
        local CombatController = player.PlayerScripts:FindFirstChild("CombatController", true)
        -- Visual feedback
        TweenService:Create(attackBtn, TweenInfo.new(0.08), {Size = UDim2.new(0, 46, 0, 46)}):Play()
        task.delay(0.08, function()
            TweenService:Create(attackBtn, TweenInfo.new(0.08), {Size = UDim2.new(0, 52, 0, 52)}):Play()
        end)
    end)
end

-- Mobile Interact Button Interaction (Triggers nearest ProximityPrompt)
if interactBtn then
    interactBtn.Activated:Connect(function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local nearestPrompt = nil
            local shortestDist = 20.0
            for _, prompt in ipairs(workspace:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    local part = prompt.Parent
                    if part and part:IsA("BasePart") then
                        local dist = (hrp.Position - part.Position).Magnitude
                        if dist < shortestDist and dist <= prompt.MaxActivationDistance then
                            nearestPrompt = prompt
                            shortestDist = dist
                        end
                    end
                end
            end
            if nearestPrompt then
                nearestPrompt:InputHoldBegin()
                task.wait(nearestPrompt.HoldDuration + 0.05)
                nearestPrompt:InputHoldEnd()
            end
        end
    end)
end

-- Tween Helpers
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tweenFill(fillFrame: Frame, percent: number)
    local clamped = math.clamp(percent, 0, 1)
    TweenService:Create(fillFrame, tweenInfo, {Size = UDim2.new(clamped, 0, 1, 0)}):Play()
end

-- Update Functions
local function updateShield()
    local shield = player:GetAttribute("Shield") or GameConfig.MaxShield
    local maxShield = player:GetAttribute("MaxShield") or GameConfig.MaxShield
    local ratio = maxShield > 0 and (shield / maxShield) or 0
    tweenFill(shieldFill, ratio)
    shieldValue.Text = string.format("%d/%d", math.floor(shield + 0.5), maxShield)
end

local function updateHealth(humanoid: Humanoid?)
    if not humanoid then
        tweenFill(healthFill, 0)
        healthValue.Text = "0/100"
        return
    end
    local hp = humanoid.Health
    local maxHp = humanoid.MaxHealth
    local ratio = maxHp > 0 and (hp / maxHp) or 0
    tweenFill(healthFill, ratio)
    healthValue.Text = string.format("%d/%d", math.floor(hp + 0.5), maxHp)
    
    if ratio < 0.25 then
        healthFill.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
    else
        healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 160)
    end
end

local function updateStamina()
    local stamina = player:GetAttribute("Stamina") or GameConfig.MaxStamina
    local maxStamina = player:GetAttribute("MaxStamina") or GameConfig.MaxStamina
    local ratio = maxStamina > 0 and (stamina / maxStamina) or 0
    tweenFill(staminaFill, ratio)
    staminaValue.Text = string.format("%d%%", math.floor(ratio * 100 + 0.5))
    
    local isExhausted = player:GetAttribute("IsExhausted") == true
    if (stamina <= 0 or isExhausted) and mobileSprintActive then
        mobileSprintActive = false
        sprintBtn.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
        sprintBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
        local stroke = sprintBtn:FindFirstChild("Stroke") or sprintBtn:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = Color3.fromRGB(0, 220, 255) end
    end
end

local function updateXP()
    local xp = player:GetAttribute("XP") or 0
    local maxXP = player:GetAttribute("MaxXP") or GameConfig.BaseXPPerLevel
    local ratio = maxXP > 0 and (xp / maxXP) or 0
    tweenFill(xpFill, ratio)
    xpValue.Text = string.format("%d/%d", math.floor(xp + 0.5), maxXP)
end

local function updateLevel()
    local lvl = player:GetAttribute("Level") or 1
    levelText.Text = "LVL " .. tostring(lvl)
    updateXP()
end

local function updateCredits()
    local cr = player:GetAttribute("Credits") or 0
    creditsText.Text = string.format("%d CR", cr)
end

local function updateStatus()
    local st = player:GetAttribute("Status") or "OPERATIVE: ACTIVE"
    statusLabel.Text = st
    if string.find(st, "KIA") or string.find(st, "OFFLINE") then
        statusLabel.TextColor3 = Color3.fromRGB(255, 60, 70)
    else
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
    end
end

-- Connect Attribute Changes
player:GetAttributeChangedSignal("Shield"):Connect(updateShield)
player:GetAttributeChangedSignal("MaxShield"):Connect(updateShield)
player:GetAttributeChangedSignal("Stamina"):Connect(updateStamina)
player:GetAttributeChangedSignal("MaxStamina"):Connect(updateStamina)
player:GetAttributeChangedSignal("IsExhausted"):Connect(updateStamina)
player:GetAttributeChangedSignal("Level"):Connect(updateLevel)
player:GetAttributeChangedSignal("XP"):Connect(updateXP)
player:GetAttributeChangedSignal("MaxXP"):Connect(updateXP)
player:GetAttributeChangedSignal("Credits"):Connect(updateCredits)
player:GetAttributeChangedSignal("Status"):Connect(updateStatus)

-- Character & Humanoid Connections
local healthConn = nil
local maxHealthConn = nil
local diedConn = nil

local function hookCharacter(char)
    if healthConn then healthConn:Disconnect() end
    if maxHealthConn then maxHealthConn:Disconnect() end
    if diedConn then diedConn:Disconnect() end
    
    local humanoid = char:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    
    updateHealth(humanoid)
    updateShield()
    updateStamina()
    updateXP()
    updateLevel()
    updateCredits()
    updateStatus()
    
    healthConn = humanoid.HealthChanged:Connect(function()
        updateHealth(humanoid)
    end)
    
    maxHealthConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        updateHealth(humanoid)
    end)
    
    diedConn = humanoid.Died:Connect(function()
        updateHealth(humanoid)
        updateStatus()
    end)
end

player.CharacterAdded:Connect(hookCharacter)
if player.Character then
    hookCharacter(player.Character)
end

updateXP()
updateLevel()
updateCredits()

print("[NullFrontier] HUDController initialized with Compact Solarpunk Dossier.")
