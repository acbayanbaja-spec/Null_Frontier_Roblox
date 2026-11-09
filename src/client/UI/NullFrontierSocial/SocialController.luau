local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local GetPlayerProfileRF = Remotes:WaitForChild("GetPlayerProfile")
local SendPartyInviteRE = Remotes:WaitForChild("SendPartyInvite")
local PartyInviteReceivedRE = Remotes:WaitForChild("PartyInviteReceived")
local RespondPartyInviteRE = Remotes:WaitForChild("RespondPartyInvite")
local LeavePartyRE = Remotes:WaitForChild("LeaveParty")
local PartyUpdateRE = Remotes:WaitForChild("PartyUpdate")

local gui = script.Parent
local mainContainer = gui:WaitForChild("MainContainer")
local socialModal = mainContainer:WaitForChild("SocialModal")
local profileModal = mainContainer:WaitForChild("ProfileModal")
local inviteBanner = mainContainer:WaitForChild("PartyInviteBanner")
local squadHud = mainContainer:WaitForChild("SquadHUD")
local directoryModal = mainContainer:WaitForChild("OperativesDirectory")
local dirToggleBtn = mainContainer:WaitForChild("OperativesToggleBtn")

local currentTargetPlayer = nil

-- Modal Animation Helpers
local function openModal(frame: Frame)
    frame.Position = UDim2.new(0.5, 0, 0.54, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = true
    TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.15
    }):Play()
end

local function closeModal(frame: Frame)
    local tw = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.54, 0),
        BackgroundTransparency = 1
    })
    tw:Play()
    tw.Completed:Connect(function()
        frame.Visible = false
    end)
end

-- Populate Profile Modal with verified Server Data
local function displayProfile(userId: number)
    local data = GetPlayerProfileRF:InvokeServer(userId)
    if not data then return end
    
    local info = profileModal.InfoPanel
    info.OperativeName.Text = data.DisplayName
    info.OperativeHandle.Text = "@" .. data.Username
    info.StatusBadge.Text = data.Status
    
    local stats = profileModal.StatsBox
    stats.CellLevel.ValText.Text = "LEVEL " .. tostring(data.Level)
    stats.CellCredits.ValText.Text = tostring(data.Credits) .. " CR"
    stats.CellService.ValText.Text = tostring(data.AccountAge) .. " DAYS"
    stats.CellSquad.ValText.Text = data.InParty and (data.IsLeader and "SQUAD LEADER" or "SQUAD MEMBER") or "SOLO"
    stats.CellVitality.ValText.Text = string.format("%d / %d", math.floor(data.Health + 0.5), data.MaxHealth)
    stats.CellShield.ValText.Text = string.format("%d / 100", math.floor(data.Shield + 0.5))
    
    task.spawn(function()
        pcall(function()
            local thumb, isReady = Players:GetUserThumbnailAsync(data.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150)
            if isReady and thumb then
                profileModal.BustImage.Image = thumb
            end
        end)
    end)
    
    openModal(profileModal)
end

-- 1. ProximityPrompt Handling (Hide on own character, trigger on other players)
local function checkPrompt(prompt: ProximityPrompt)
    if prompt.Name == "SocialPrompt" then
        local char = prompt.Parent and prompt.Parent.Parent
        if char == player.Character then
            prompt.Enabled = false
        end
    end
end
ProximityPromptService.PromptShown:Connect(checkPrompt)

-- Open Social Interaction Modal for a player
local function openSocialForPlayer(target: Player)
    if not target or target == player then return end
    currentTargetPlayer = target
    
    local header = socialModal:WaitForChild("Header")
    header.DisplayName.Text = target.DisplayName
    header.Subtitle.Text = string.format("@%s â€¢ LVL %d", target.Name, target:GetAttribute("Level") or 1)
    
    task.spawn(function()
        pcall(function()
            local thumb, isReady = Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            if isReady and thumb then
                header.AvatarThumb.Image = thumb
            end
        end)
    end)
    
    local btnSquad = socialModal.ButtonList:WaitForChild("BtnSquad")
    btnSquad.Text = "+  INVITE TO TACTICAL SQUAD"
    
    openModal(socialModal)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
    if triggeredPlayer == player and prompt.Name == "SocialPrompt" then
        local char = prompt.Parent and prompt.Parent.Parent
        if char and char ~= player.Character then
            local target = Players:GetPlayerFromCharacter(char)
            if target then
                openSocialForPlayer(target)
            end
        end
    end
end)

-- 2. Social Modal Buttons
local smBtnList = socialModal:WaitForChild("ButtonList")

smBtnList.BtnProfile.Activated:Connect(function()
    if not currentTargetPlayer then return end
    closeModal(socialModal)
    displayProfile(currentTargetPlayer.UserId)
end)

smBtnList.BtnSquad.Activated:Connect(function()
    if not currentTargetPlayer then return end
    SendPartyInviteRE:FireServer(currentTargetPlayer.UserId)
    smBtnList.BtnSquad.Text = "âœ“  INVITE TRANSMITTED"
end)

smBtnList.BtnFriend.Activated:Connect(function()
    if not currentTargetPlayer then return end
    pcall(function()
        StarterGui:SetCore("PromptSendFriendRequest", currentTargetPlayer)
    end)
end)

smBtnList.BtnReport.Activated:Connect(function()
    if not currentTargetPlayer then return end
    pcall(function()
        StarterGui:SetCore("PromptReportPlayer", currentTargetPlayer)
    end)
end)

smBtnList.BtnClose.Activated:Connect(function()
    closeModal(socialModal)
end)

profileModal.CloseBtn.Activated:Connect(function()
    closeModal(profileModal)
end)

-- 3. Party Invite Banner Listener
local currentInviteSenderId = nil
local inviteTimeoutThread = nil

PartyInviteReceivedRE.OnClientEvent:Connect(function(senderUserId, senderDisplayName, senderLevel)
    currentInviteSenderId = senderUserId
    inviteBanner.InviteText.Text = string.format("%s (LVL %d) INVITED YOU TO SQUAD", senderDisplayName:upper(), senderLevel)
    
    inviteBanner.Visible = true
    inviteBanner.Position = UDim2.new(0.5, 0, 0, -70)
    TweenService:Create(inviteBanner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 25)
    }):Play()
    
    if inviteTimeoutThread then task.cancel(inviteTimeoutThread) end
    inviteTimeoutThread = task.delay(15, function()
        if inviteBanner.Visible then
            TweenService:Create(inviteBanner, TweenInfo.new(0.2), {Position = UDim2.new(0.5, 0, 0, -80)}):Play()
            task.wait(0.2)
            inviteBanner.Visible = false
        end
    end)
end)

local function closeInviteBanner()
    if inviteTimeoutThread then task.cancel(inviteTimeoutThread) end
    TweenService:Create(inviteBanner, TweenInfo.new(0.2), {Position = UDim2.new(0.5, 0, 0, -80)}):Play()
    task.wait(0.2)
    inviteBanner.Visible = false
end

inviteBanner.AcceptBtn.Activated:Connect(function()
    if currentInviteSenderId then
        RespondPartyInviteRE:FireServer(currentInviteSenderId, true)
    end
    closeInviteBanner()
end)

inviteBanner.DeclineBtn.Activated:Connect(function()
    if currentInviteSenderId then
        RespondPartyInviteRE:FireServer(currentInviteSenderId, false)
    end
    closeInviteBanner()
end)

-- 4. Squad HUD Updates
PartyUpdateRE.OnClientEvent:Connect(function(partyId, memberList)
    if #memberList == 0 then
        squadHud.Visible = false
        return
    end
    
    squadHud.Visible = true
    squadHud.Header.Title.Text = string.format("SQUAD [%d/4]", #memberList)
    
    local list = squadHud.MemberList
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    for idx, mem in ipairs(memberList) do
        local row = Instance.new("Frame")
        row.Name = "Member_" .. mem.UserId
        row.Size = UDim2.new(1, 0, 0, 20)
        row.BackgroundTransparency = 1
        row.LayoutOrder = idx
        row.Parent = list
        
        local leaderTag = mem.IsLeader and "â˜… " or ""
        local nameText = Instance.new("TextLabel")
        nameText.Size = UDim2.new(1, -60, 1, 0)
        nameText.BackgroundTransparency = 1
        nameText.Font = Enum.Font.GothamMedium
        nameText.Text = leaderTag .. mem.DisplayName
        nameText.TextColor3 = mem.IsLeader and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(220, 235, 250)
        nameText.TextSize = 10
        nameText.TextXAlignment = Enum.TextXAlignment.Left
        nameText.Parent = row
        
        local hpText = Instance.new("TextLabel")
        hpText.AnchorPoint = Vector2.new(1, 0)
        hpText.Position = UDim2.new(1, 0, 0, 0)
        hpText.Size = UDim2.new(0, 56, 1, 0)
        hpText.BackgroundTransparency = 1
        hpText.Font = Enum.Font.GothamBold
        hpText.Text = string.format("%d HP", math.floor(mem.Health + 0.5))
        hpText.TextColor3 = Color3.fromRGB(0, 255, 160)
        hpText.TextSize = 9
        hpText.TextXAlignment = Enum.TextXAlignment.Right
        hpText.Parent = row
    end
end)

squadHud.Header.LeaveBtn.Activated:Connect(function()
    LeavePartyRE:FireServer()
end)

-- 5. Operatives Directory Modal (Tab Menu / Active Operatives)
local function populateDirectory()
    local scroll = directoryModal.ScrollList
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    local allPlayers = Players:GetPlayers()
    for idx, p in ipairs(allPlayers) do
        local row = Instance.new("Frame")
        row.Name = "Operative_" .. p.UserId
        row.Size = UDim2.new(1, 0, 0, 36)
        row.BackgroundColor3 = (p == player) and Color3.fromRGB(15, 30, 48) or Color3.fromRGB(16, 22, 34)
        row.BackgroundTransparency = 0.3
        row.LayoutOrder = idx
        row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        
        local img = Instance.new("ImageLabel")
        img.Position = UDim2.new(0, 6, 0.5, -13)
        img.Size = UDim2.new(0, 26, 0, 26)
        img.BackgroundColor3 = Color3.fromRGB(20, 28, 42)
        img.Parent = row
        Instance.new("UICorner", img).CornerRadius = UDim.new(0, 4)
        
        task.spawn(function()
            pcall(function()
                local thumb, isReady = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                if isReady and thumb then img.Image = thumb end
            end)
        end)
        
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Position = UDim2.new(0, 38, 0, 2)
        nameLbl.Size = UDim2.new(0, 180, 0, 18)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = p.DisplayName .. ((p == player) and " (YOU)" or "")
        nameLbl.TextColor3 = (p == player) and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(240, 248, 255)
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row
        
        local handleLbl = Instance.new("TextLabel")
        handleLbl.Position = UDim2.new(0, 38, 0, 18)
        handleLbl.Size = UDim2.new(0, 180, 0, 14)
        handleLbl.BackgroundTransparency = 1
        handleLbl.Font = Enum.Font.Gotham
        handleLbl.Text = string.format("@%s â€¢ LVL %d", p.Name, p:GetAttribute("Level") or 1)
        handleLbl.TextColor3 = Color3.fromRGB(0, 210, 255)
        handleLbl.TextSize = 9
        handleLbl.TextXAlignment = Enum.TextXAlignment.Left
        handleLbl.Parent = row
        
        -- Action Button
        if p ~= player then
            local interactBtn = Instance.new("TextButton")
            interactBtn.AnchorPoint = Vector2.new(1, 0.5)
            interactBtn.Position = UDim2.new(1, -8, 0.5, 0)
            interactBtn.Size = UDim2.new(0, 72, 0, 22)
            interactBtn.BackgroundColor3 = Color3.fromRGB(25, 36, 52)
            interactBtn.Font = Enum.Font.GothamBold
            interactBtn.Text = "INTERACT"
            interactBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
            interactBtn.TextSize = 9
            interactBtn.Parent = row
            Instance.new("UICorner", interactBtn).CornerRadius = UDim.new(0, 4)
            
            interactBtn.Activated:Connect(function()
                closeModal(directoryModal)
                openSocialForPlayer(p)
            end)
        else
            local viewOwnBtn = Instance.new("TextButton")
            viewOwnBtn.AnchorPoint = Vector2.new(1, 0.5)
            viewOwnBtn.Position = UDim2.new(1, -8, 0.5, 0)
            viewOwnBtn.Size = UDim2.new(0, 76, 0, 22)
            viewOwnBtn.BackgroundColor3 = Color3.fromRGB(18, 38, 30)
            viewOwnBtn.Font = Enum.Font.GothamBold
            viewOwnBtn.Text = "MY PROFILE"
            viewOwnBtn.TextColor3 = Color3.fromRGB(0, 255, 170)
            viewOwnBtn.TextSize = 9
            viewOwnBtn.Parent = row
            Instance.new("UICorner", viewOwnBtn).CornerRadius = UDim.new(0, 4)
            
            viewOwnBtn.Activated:Connect(function()
                closeModal(directoryModal)
                displayProfile(player.UserId)
            end)
        end
    end
end

local function toggleDirectory()
    if directoryModal.Visible then
        closeModal(directoryModal)
    else
        populateDirectory()
        openModal(directoryModal)
    end
end

dirToggleBtn.Activated:Connect(toggleDirectory)
directoryModal.CloseBtn.Activated:Connect(function()
    closeModal(directoryModal)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Tab then
        toggleDirectory()
    end
end)

print("[NullFrontier] SocialController initialized.")
