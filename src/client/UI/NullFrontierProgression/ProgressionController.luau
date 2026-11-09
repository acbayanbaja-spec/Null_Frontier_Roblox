-- ProgressionController for NULL FRONTIER
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local ClaimMissionRF = Remotes:WaitForChild("ClaimMission")
local ClaimAchievementRF = Remotes:WaitForChild("ClaimAchievement")
local GetProgressionDataRF = Remotes:WaitForChild("GetProgressionData")
local LevelUpNotificationRE = Remotes:WaitForChild("LevelUpNotification")
local RewardNotificationRE = Remotes:WaitForChild("RewardNotification")
local MissionProgressUpdatedRE = Remotes:WaitForChild("MissionProgressUpdated")
local AchievementUnlockedRE = Remotes:WaitForChild("AchievementUnlocked")

local gui = script.Parent
local mainContainer = gui:WaitForChild("MainContainer")
local toggleBtn = mainContainer:WaitForChild("MissionsToggleBtn")
local modal = mainContainer:WaitForChild("ProgressionModal")
local header = modal:WaitForChild("Header")
local tabFrame = modal:WaitForChild("TabFrame")
local btnTabMissions = tabFrame:WaitForChild("BtnTabMissions")
local btnTabAchievements = tabFrame:WaitForChild("BtnTabAchievements")
local missionsScroll = modal:WaitForChild("MissionsScroll")
local achScroll = modal:WaitForChild("AchievementsScroll")
local closeBtn = modal:WaitForChild("CloseBtn")
local levelUpBanner = mainContainer:WaitForChild("LevelUpBanner")
local rewardToast = mainContainer:WaitForChild("RewardToast")

local currentTab = "Missions"

-- Modal Animations
local function openModal()
    modal.Position = UDim2.new(0.5, 0, 0.54, 0)
    modal.BackgroundTransparency = 1
    modal.Visible = true
    TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.15
    }):Play()
end

local function closeModal()
    local tw = TweenService:Create(modal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.54, 0),
        BackgroundTransparency = 1
    })
    tw:Play()
    tw.Completed:Connect(function()
        modal.Visible = false
    end)
end

-- Category Accent Colors
local CATEGORY_COLORS = {
    Daily = Color3.fromRGB(0, 220, 255),
    Exploration = Color3.fromRGB(0, 255, 170),
    Social = Color3.fromRGB(180, 140, 255),
    Progression = Color3.fromRGB(255, 200, 80),
    Challenge = Color3.fromRGB(255, 90, 90),
    Explorer = Color3.fromRGB(0, 255, 170),
}

-- Render Missions
local function renderMissions(data)
    for _, c in ipairs(missionsScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local catalog = data.MissionCatalog or {}
    local missions = data.Missions or {}
    
    local sortedList = {}
    for id, cfg in pairs(catalog) do
        table.insert(sortedList, cfg)
    end
    table.sort(sortedList, function(a, b)
        local stateA = missions[a.Id] and (missions[a.Id].Claimed and 3 or (missions[a.Id].Completed and 1 or 2)) or 2
        local stateB = missions[b.Id] and (missions[b.Id].Claimed and 3 or (missions[b.Id].Completed and 1 or 2)) or 2
        if stateA ~= stateB then return stateA < stateB end
        return a.Title < b.Title
    end)
    
    for idx, cfg in ipairs(sortedList) do
        local record = missions[cfg.Id] or { Progress = 0, Target = cfg.Target, Completed = false, Claimed = false }
        local isCompleted = record.Completed
        local isClaimed = record.Claimed
        local prog = math.clamp(record.Progress or 0, 0, cfg.Target)
        local ratio = cfg.Target > 0 and (prog / cfg.Target) or 0
        local catColor = CATEGORY_COLORS[cfg.Category] or Color3.fromRGB(0, 200, 255)
        
        local card = Instance.new("Frame")
        card.Name = "Mission_" .. cfg.Id
        card.Size = UDim2.new(1, -6, 0, 74)
        card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
        card.BackgroundTransparency = 0.3
        card.LayoutOrder = idx
        card.Parent = missionsScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = isCompleted and (isClaimed and Color3.fromRGB(30, 45, 40) or Color3.fromRGB(255, 190, 60)) or Color3.fromRGB(30, 42, 60)
        stroke.Thickness = (isCompleted and not isClaimed) and 1.5 or 1
        
        -- Category Chip
        local catTag = Instance.new("TextLabel")
        catTag.Position = UDim2.new(0, 10, 0, 8)
        catTag.Size = UDim2.new(0, 90, 0, 14)
        catTag.BackgroundTransparency = 1
        catTag.Font = Enum.Font.GothamBold
        catTag.Text = string.format("[%s]", cfg.Category:upper())
        catTag.TextColor3 = catColor
        catTag.TextSize = 8
        catTag.TextXAlignment = Enum.TextXAlignment.Left
        catTag.Parent = card
        
        -- Title
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Position = UDim2.new(0, 105, 0, 8)
        titleLbl.Size = UDim2.new(1, -220, 0, 14)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = cfg.Title
        titleLbl.TextColor3 = Color3.fromRGB(240, 248, 255)
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card
        
        -- Description
        local descLbl = Instance.new("TextLabel")
        descLbl.Position = UDim2.new(0, 10, 0, 24)
        descLbl.Size = UDim2.new(1, -125, 0, 16)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = cfg.Description
        descLbl.TextColor3 = Color3.fromRGB(170, 190, 215)
        descLbl.TextSize = 8
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextTruncate = Enum.TextTruncate.AtEnd
        descLbl.Parent = card
        
        -- Progress Bar Track & Fill
        local track = Instance.new("Frame")
        track.Position = UDim2.new(0, 10, 0, 46)
        track.Size = UDim2.new(1, -125, 0, 6)
        track.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
        track.BorderSizePixel = 0
        track.Parent = card
        Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        fill.BackgroundColor3 = isCompleted and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(0, 200, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
        
        -- Progress Label & Rewards Tag
        local progLbl = Instance.new("TextLabel")
        progLbl.Position = UDim2.new(0, 10, 0, 54)
        progLbl.Size = UDim2.new(0, 140, 0, 14)
        progLbl.BackgroundTransparency = 1
        progLbl.Font = Enum.Font.GothamMedium
        progLbl.Text = string.format("%d / %d %s", math.floor(prog), cfg.Target, cfg.Unit or "")
        progLbl.TextColor3 = Color3.fromRGB(150, 175, 205)
        progLbl.TextSize = 8
        progLbl.TextXAlignment = Enum.TextXAlignment.Left
        progLbl.Parent = card
        
        local rwdLbl = Instance.new("TextLabel")
        rwdLbl.Position = UDim2.new(0, 155, 0, 54)
        rwdLbl.Size = UDim2.new(1, -270, 0, 14)
        rwdLbl.BackgroundTransparency = 1
        rwdLbl.Font = Enum.Font.GothamBold
        rwdLbl.Text = string.format("+%d XP  â€¢  +%d CR", cfg.RewardXP, cfg.RewardCredits)
        rwdLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
        rwdLbl.TextSize = 8
        rwdLbl.TextXAlignment = Enum.TextXAlignment.Left
        rwdLbl.Parent = card
        
        -- Action Button
        local actBtn = Instance.new("TextButton")
        actBtn.AnchorPoint = Vector2.new(1, 0.5)
        actBtn.Position = UDim2.new(1, -10, 0.5, 0)
        actBtn.Size = UDim2.new(0, 100, 0, 28)
        actBtn.Parent = card
        Instance.new("UICorner", actBtn).CornerRadius = UDim.new(0, 4)
        
        if isClaimed then
            actBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 26)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = "âœ“ CLAIMED"
            actBtn.TextColor3 = Color3.fromRGB(100, 180, 140)
            actBtn.TextSize = 9
            actBtn.AutoButtonColor = false
        elseif isCompleted then
            actBtn.BackgroundColor3 = Color3.fromRGB(255, 185, 45)
            actBtn.Font = Enum.Font.GothamBlack
            actBtn.Text = "â˜… CLAIM REWARD"
            actBtn.TextColor3 = Color3.fromRGB(15, 20, 30)
            actBtn.TextSize = 9
            
            actBtn.Activated:Connect(function()
                actBtn.Text = "CLAIMING..."
                actBtn.AutoButtonColor = false
                local success, msg = ClaimMissionRF:InvokeServer(cfg.Id)
                if success then
                    actBtn.BackgroundColor3 = Color3.fromRGB(18, 30, 26)
                    actBtn.Font = Enum.Font.GothamBold
                    actBtn.Text = "âœ“ CLAIMED"
                    actBtn.TextColor3 = Color3.fromRGB(100, 180, 140)
                else
                    actBtn.Text = "RETRY"
                    actBtn.AutoButtonColor = true
                end
            end)
        else
            actBtn.BackgroundColor3 = Color3.fromRGB(18, 25, 38)
            actBtn.Font = Enum.Font.GothamBold
            actBtn.Text = "IN PROGRESS"
            actBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
            actBtn.TextSize = 8
            actBtn.AutoButtonColor = false
        end
    end
end

-- Render Achievements
local function renderAchievements(data)
    for _, c in ipairs(achScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local catalog = data.AchievementCatalog or {}
    local achs = data.Achievements or {}
    
    local sortedList = {}
    for id, cfg in pairs(catalog) do
        table.insert(sortedList, cfg)
    end
    table.sort(sortedList, function(a, b)
        local unlA = achs[a.Id] and achs[a.Id].Unlocked or false
        local unlB = achs[b.Id] and achs[b.Id].Unlocked or false
        if unlA ~= unlB then return unlA and not unlB end
        return a.Title < b.Title
    end)
    
    for idx, cfg in ipairs(sortedList) do
        local record = achs[cfg.Id] or { Unlocked = false, UnlockedAt = 0 }
        local isUnlocked = record.Unlocked
        local catColor = CATEGORY_COLORS[cfg.Category] or Color3.fromRGB(255, 200, 80)
        
        local card = Instance.new("Frame")
        card.Name = "Ach_" .. cfg.Id
        card.Size = UDim2.new(1, -6, 0, 62)
        card.BackgroundColor3 = isUnlocked and Color3.fromRGB(18, 26, 40) or Color3.fromRGB(14, 18, 26)
        card.BackgroundTransparency = isUnlocked and 0.25 or 0.5
        card.LayoutOrder = idx
        card.Parent = achScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", card)
        stroke.Color = isUnlocked and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(30, 40, 55)
        stroke.Thickness = isUnlocked and 1.5 or 1
        
        -- Status Badge Tag
        local statusTag = Instance.new("TextLabel")
        statusTag.Position = UDim2.new(0, 10, 0, 8)
        statusTag.Size = UDim2.new(0, 80, 0, 14)
        statusTag.BackgroundTransparency = 1
        statusTag.Font = Enum.Font.GothamBold
        statusTag.Text = isUnlocked and "â˜… UNLOCKED" or "ðŸ”’ LOCKED"
        statusTag.TextColor3 = isUnlocked and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(120, 135, 155)
        statusTag.TextSize = 8
        statusTag.TextXAlignment = Enum.TextXAlignment.Left
        statusTag.Parent = card
        
        -- Title
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Position = UDim2.new(0, 95, 0, 8)
        titleLbl.Size = UDim2.new(1, -210, 0, 14)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.Text = cfg.Title
        titleLbl.TextColor3 = isUnlocked and Color3.fromRGB(240, 248, 255) or Color3.fromRGB(150, 165, 185)
        titleLbl.TextSize = 10
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = card
        
        -- Description / Condition
        local descLbl = Instance.new("TextLabel")
        descLbl.Position = UDim2.new(0, 10, 0, 24)
        descLbl.Size = UDim2.new(1, -125, 0, 16)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Enum.Font.Gotham
        descLbl.Text = cfg.Description .. " (" .. cfg.Condition .. ")"
        descLbl.TextColor3 = isUnlocked and Color3.fromRGB(170, 195, 220) or Color3.fromRGB(100, 115, 135)
        descLbl.TextSize = 8
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextTruncate = Enum.TextTruncate.AtEnd
        descLbl.Parent = card
        
        -- Rewards Tag
        local rwdLbl = Instance.new("TextLabel")
        rwdLbl.Position = UDim2.new(0, 10, 0, 42)
        rwdLbl.Size = UDim2.new(1, -125, 0, 14)
        rwdLbl.BackgroundTransparency = 1
        rwdLbl.Font = Enum.Font.GothamBold
        rwdLbl.Text = string.format("REWARD: +%d XP  â€¢  +%d CREDITS", cfg.RewardXP, cfg.RewardCredits)
        rwdLbl.TextColor3 = isUnlocked and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(120, 135, 155)
        rwdLbl.TextSize = 8
        rwdLbl.TextXAlignment = Enum.TextXAlignment.Left
        rwdLbl.Parent = card
    end
end

-- Refresh Modal
local function refreshData()
    local data = GetProgressionDataRF:InvokeServer()
    if not data then return end
    renderMissions(data)
    renderAchievements(data)
end

-- Tab Switching
local function setTab(tabName)
    currentTab = tabName
    if tabName == "Missions" then
        btnTabMissions.BackgroundColor3 = Color3.fromRGB(25, 38, 56)
        btnTabMissions.TextColor3 = Color3.fromRGB(0, 230, 255)
        btnTabAchievements.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabAchievements.TextColor3 = Color3.fromRGB(160, 180, 200)
        missionsScroll.Visible = true
        achScroll.Visible = false
    else
        btnTabAchievements.BackgroundColor3 = Color3.fromRGB(25, 38, 56)
        btnTabAchievements.TextColor3 = Color3.fromRGB(255, 200, 80)
        btnTabMissions.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
        btnTabMissions.TextColor3 = Color3.fromRGB(160, 180, 200)
        achScroll.Visible = true
        missionsScroll.Visible = false
    end
end

btnTabMissions.Activated:Connect(function() setTab("Missions") end)
btnTabAchievements.Activated:Connect(function() setTab("Achievements") end)

local function toggleModal()
    if modal.Visible then
        closeModal()
    else
        refreshData()
        openModal()
    end
end

toggleBtn.Activated:Connect(toggleModal)
closeBtn.Activated:Connect(closeModal)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.M then
        toggleModal()
    end
end)

-- Level-Up Cinematic Banner Routine
local levelUpThread = nil
LevelUpNotificationRE.OnClientEvent:Connect(function(newLevel, bonusData)
    levelUpBanner.LvlMain.Text = string.format("RANK ADVANCED TO LEVEL %d", newLevel)
    levelUpBanner.LvlBonus.Text = string.format("+%d FRONTIER CREDITS AWARDED", bonusData and bonusData.BonusCredits or 50)
    
    levelUpBanner.Visible = true
    levelUpBanner.Position = UDim2.new(0.5, 0, 0, -120)
    
    TweenService:Create(levelUpBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 30)
    }):Play()
    
    if levelUpThread then task.cancel(levelUpThread) end
    levelUpThread = task.delay(4.5, function()
        if levelUpBanner.Visible then
            local tw = TweenService:Create(levelUpBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -120)
            })
            tw:Play()
            tw.Completed:Connect(function()
                levelUpBanner.Visible = false
            end)
        end
    end)
end)

-- Reward Toast Routine
local toastThread = nil
RewardNotificationRE.OnClientEvent:Connect(function(rewardTitle, xpAmount, creditsAmount)
    rewardToast.ToastTitle.Text = (rewardTitle or "OPERATION REWARD"):upper()
    rewardToast.ToastAmount.Text = string.format("+%d XP  â€¢  +%d CREDITS", xpAmount, creditsAmount)
    
    rewardToast.Visible = true
    rewardToast.Position = UDim2.new(1, -20, 1, 80)
    
    TweenService:Create(rewardToast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -20, 1, -25)
    }):Play()
    
    if toastThread then task.cancel(toastThread) end
    toastThread = task.delay(3.5, function()
        if rewardToast.Visible then
            local tw = TweenService:Create(rewardToast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(1, -20, 1, 80)
            })
            tw:Play()
            tw.Completed:Connect(function()
                rewardToast.Visible = false
            end)
        end
    end)
end)

MissionProgressUpdatedRE.OnClientEvent:Connect(function()
    if modal.Visible and currentTab == "Missions" then
        refreshData()
    end
end)

print("[NullFrontier] ProgressionController initialized.")
