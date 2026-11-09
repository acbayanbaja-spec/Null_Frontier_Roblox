local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local SettingsController = require(NullFrontier.Modules.SettingsController)

local menuGui = script.Parent
local mainContainer = menuGui:WaitForChild("MainContainer")
local navFrame = mainContainer:WaitForChild("NavFrame")
local playBtn = navFrame:WaitForChild("PlayButton")
local settingsBtn = navFrame:WaitForChild("SettingsButton")
local creditsBtn = navFrame:WaitForChild("CreditsButton")

local settingsModal = mainContainer:WaitForChild("SettingsModal")
local closeSettingsBtn = settingsModal:WaitForChild("CloseSettingsButton")
local creditsModal = mainContainer:WaitForChild("CreditsModal")
local closeCreditsBtn = creditsModal:WaitForChild("CloseCreditsButton")

local loadingOverlay = mainContainer:WaitForChild("LoadingOverlay")
local loadCenter = loadingOverlay:WaitForChild("LoadCenter")
local spinner = loadCenter:WaitForChild("Spinner")
local loadStatus = loadCenter:WaitForChild("Status")

local menuBlur = Lighting:FindFirstChild("MenuBlur")

-- Sound references
local masterAudio = SoundService:WaitForChild("MasterAudio")
local sfxGroup = masterAudio:WaitForChild("SFXGroup")
local musicGroup = masterAudio:WaitForChild("MusicGroup")
local sndHover = sfxGroup:WaitForChild("UI_Hover")
local sndClick = sfxGroup:WaitForChild("UI_Click")
local sndStart = sfxGroup:WaitForChild("UI_Start")
local sndAmbience = musicGroup:WaitForChild("MenuAmbience")

-- State
local inMenu = true
player:SetAttribute("InMenu", true)
local camConn = nil
local spinConn = nil

-- Initial Menu State: Freeze movement & hide HUD
local function applyMenuRestrictions(char)
    if not inMenu then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    end
end

player.CharacterAdded:Connect(applyMenuRestrictions)
if player.Character then
    task.spawn(applyMenuRestrictions, player.Character)
end

-- Hide In-Game HUD during Main Menu
local pgui = player:WaitForChild("PlayerGui")
local function setInterfaceVisible(visible: boolean)
    local hud = pgui:FindFirstChild("NullFrontierHUD")
    if hud and hud:FindFirstChild("MainContainer") then
        hud.MainContainer.Visible = visible
    end
    local social = pgui:FindFirstChild("NullFrontierSocial")
    if social and social:FindFirstChild("MainContainer") then
        social.MainContainer.Visible = visible
    end
end
setInterfaceVisible(false)

-- Cinematic Camera View during Main Menu
local camBaseCFrame = CFrame.new(0, 18, -48) * CFrame.Angles(math.rad(-14), math.rad(180), 0)
local function setupMenuCamera()
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = camBaseCFrame
    
    if menuBlur then
        menuBlur.Size = 12
    end
    
    -- Gentle atmospheric camera drift
    local t0 = os.clock()
    camConn = RunService.RenderStepped:Connect(function()
        if not inMenu then return end
        local elapsed = os.clock() - t0
        local swayX = math.sin(elapsed * 0.4) * 0.8
        local swayY = math.cos(elapsed * 0.3) * 0.4
        camera.CFrame = camBaseCFrame * CFrame.Angles(math.rad(swayY), math.rad(swayX), 0)
    end)
end
setupMenuCamera()

-- Start Ambient Menu Sound
pcall(function() sndAmbience:Play() end)

-- Button Sound Helpers
local function hookButtonFX(btn: GuiButton)
    btn.MouseEnter:Connect(function()
        if inMenu and not loadingOverlay.Visible then
            sndHover:Play()
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if inMenu and not loadingOverlay.Visible then
            local isPrimary = (btn == playBtn)
            TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = isPrimary and 0.25 or 0.35}):Play()
        end
    end)
end
hookButtonFX(playBtn)
hookButtonFX(settingsBtn)
hookButtonFX(creditsBtn)
hookButtonFX(closeSettingsBtn)
hookButtonFX(closeCreditsBtn)

-- Modal Helpers (Smooth Fade & Pop)
local function openModal(modal: Frame)
    sndClick:Play()
    modal.Position = UDim2.new(0.5, 0, 0.54, 0)
    modal.BackgroundTransparency = 1
    modal.Visible = true
    TweenService:Create(modal, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 0.15
    }):Play()
end

local function closeModal(modal: Frame)
    sndClick:Play()
    local tw = TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0.54, 0),
        BackgroundTransparency = 1
    })
    tw:Play()
    tw.Completed:Connect(function()
        modal.Visible = false
    end)
end

-- Settings Button Connections
settingsBtn.Activated:Connect(function()
    creditsModal.Visible = false
    openModal(settingsModal)
end)
closeSettingsBtn.Activated:Connect(function()
    closeModal(settingsModal)
end)

-- Credits Button Connections
creditsBtn.Activated:Connect(function()
    settingsModal.Visible = false
    openModal(creditsModal)
end)
closeCreditsBtn.Activated:Connect(function()
    closeModal(creditsModal)
end)

-- Settings Modal Controls Logic
local smOptions = settingsModal:WaitForChild("OptionsList")
local musicRow = smOptions:WaitForChild("MusicRow")
local sfxRow = smOptions:WaitForChild("SFXRow")
local sensRow = smOptions:WaitForChild("SensitivityRow")
local qualityRow = smOptions:WaitForChild("QualityRow")

-- 1. Music Volume Controls
local musicValLbl = musicRow.Controls.ValueLabel
local function updateMusicDisplay()
    local s = SettingsController.Get()
    musicValLbl.Text = string.format("%d%%", math.floor(s.MusicVolume * 100 + 0.5))
end
musicRow.Controls.MinusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetMusicVolume(s.MusicVolume - 0.1)
    updateMusicDisplay()
    sndClick:Play()
end)
musicRow.Controls.PlusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetMusicVolume(s.MusicVolume + 0.1)
    updateMusicDisplay()
    sndClick:Play()
end)
updateMusicDisplay()

-- 2. SFX Volume Controls
local sfxValLbl = sfxRow.Controls.ValueLabel
local function updateSFXDisplay()
    local s = SettingsController.Get()
    sfxValLbl.Text = string.format("%d%%", math.floor(s.SFXVolume * 100 + 0.5))
end
sfxRow.Controls.MinusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetSFXVolume(s.SFXVolume - 0.1)
    updateSFXDisplay()
    sndClick:Play()
end)
sfxRow.Controls.PlusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetSFXVolume(s.SFXVolume + 0.1)
    updateSFXDisplay()
    sndClick:Play()
end)
updateSFXDisplay()

-- 3. Sensitivity Controls
local sensValLbl = sensRow.Controls.ValueLabel
local function updateSensDisplay()
    local s = SettingsController.Get()
    sensValLbl.Text = string.format("%.1fx", s.CameraSensitivity)
end
sensRow.Controls.MinusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetCameraSensitivity(s.CameraSensitivity - 0.1)
    updateSensDisplay()
    sndClick:Play()
end)
sensRow.Controls.PlusBtn.Activated:Connect(function()
    local s = SettingsController.Get()
    SettingsController.SetCameraSensitivity(s.CameraSensitivity + 0.1)
    updateSensDisplay()
    sndClick:Play()
end)
updateSensDisplay()

-- 4. Quality Mode Cycle
local qBtn = qualityRow:WaitForChild("QualityBtn")
local qualityModes = {"CINEMATIC", "BALANCED", "PERFORMANCE"}
local currentQIdx = 1
qBtn.Activated:Connect(function()
    currentQIdx = (currentQIdx % #qualityModes) + 1
    local mode = qualityModes[currentQIdx]
    qBtn.Text = mode
    SettingsController.SetQualityMode(mode:sub(1,1):upper() .. mode:sub(2):lower())
    sndClick:Play()
end)

-- PLAY BUTTON: Cinematic Launch & Loading Sequence
playBtn.Activated:Connect(function()
    if not inMenu then return end
    inMenu = false
    player:SetAttribute("InMenu", false)
    
    if camConn then
        camConn:Disconnect()
        camConn = nil
    end
    
    sndStart:Play()
    settingsModal.Visible = false
    creditsModal.Visible = false
    
    -- Show Loading Overlay
    loadingOverlay.BackgroundTransparency = 0
    loadingOverlay.Visible = true
    
    -- Animate cyber spinner
    local spinAngle = 0
    spinConn = RunService.RenderStepped:Connect(function(dt)
        spinAngle = (spinAngle + dt * 240) % 360
        spinner.Rotation = spinAngle
    end)
    
    -- Authentic loading sequence with ContentProvider preloading
    local steps = {
        {text = "STREAMING WORLD GEOMETRY...", waitTime = 0.5},
        {text = "VERIFYING OPERATIVE TELEMETRY...", waitTime = 0.4},
        {text = "CALIBRATING NEURAL LINK & AUDIO...", waitTime = 0.5},
        {text = "LINK ESTABLISHED â€” DEPLOYING OPERATIVE", waitTime = 0.6}
    }
    
    -- Preload key assets
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({
                workspace.TrainingEnvironment,
                sfxGroup
            })
        end)
    end)
    
    for _, step in ipairs(steps) do
        loadStatus.Text = step.text
        task.wait(step.waitTime)
    end
    
    if spinConn then
        spinConn:Disconnect()
        spinConn = nil
    end
    
    -- Transition camera to player
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid", 10)
    local root = char:WaitForChild("HumanoidRootPart", 10)
    
    if root and hum then
        -- Smoothly restore camera to Custom Third-Person
        local targetCFrame = CFrame.new(root.Position + Vector3.new(0, 4, 12), root.Position + Vector3.new(0, 2, 0))
        local camTw = TweenService:Create(camera, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = targetCFrame
        })
        camTw:Play()
        camTw.Completed:Wait()
        
        player.CameraMinZoomDistance = 6
        player.CameraMaxZoomDistance = 12
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = hum
        task.delay(0.3, function()
            player.CameraMaxZoomDistance = 14
        end)
    end
    
    -- Remove Menu Blur
    if menuBlur then
        TweenService:Create(menuBlur, TweenInfo.new(0.8), {Size = 0}):Play()
    end
    
    -- Restore player movement
    if hum then
        hum.WalkSpeed = GameConfig.WalkSpeed
        hum.JumpPower = GameConfig.JumpPower
    end
    
    -- Fade out Loading Overlay
    local fadeTw = TweenService:Create(loadingOverlay, TweenInfo.new(0.6), {BackgroundTransparency = 1})
    fadeTw:Play()
    
    -- Fade out Menu Ambience
    TweenService:Create(sndAmbience, TweenInfo.new(1.0), {Volume = 0}):Play()
    
    fadeTw.Completed:Connect(function()
        menuGui.Enabled = false
        sndAmbience:Stop()
    end)
    
    -- Smoothly reveal HUD
    task.wait(0.2)
    setInterfaceVisible(true)
    end)

print("[NullFrontier] MenuController initialized.")

-- Responsive Viewport Layout Handler (Mobile vs Desktop)
local brandFrame = mainContainer:WaitForChild("BrandFrame")
local brandTitle = brandFrame:WaitForChild("TitleLabel")
local brandSub = brandFrame:WaitForChild("SubLabel")

local function updateLayout()
    local vp = camera.ViewportSize
    if vp.Y < 520 then
        -- Mobile / Small Viewport
        brandFrame.Position = UDim2.new(0, 30, 0, 25)
        brandTitle.TextSize = 32
        brandSub.TextSize = 10
        navFrame.Position = UDim2.new(0, 30, 0, 155)
        navFrame.Size = UDim2.new(0, 260, 0, 160)
        settingsModal.Size = UDim2.new(0.9, 0, 0.88, 0)
        creditsModal.Size = UDim2.new(0.9, 0, 0.85, 0)
    else
        -- Desktop / Tablet Viewport
        brandFrame.Position = UDim2.new(0, 60, 0, 80)
        brandTitle.TextSize = 46
        brandSub.TextSize = 13
        navFrame.Position = UDim2.new(0, 60, 0, 270)
        navFrame.Size = UDim2.new(0, 320, 0, 220)
        settingsModal.Size = UDim2.new(0, 440, 0, 360)
        creditsModal.Size = UDim2.new(0, 440, 0, 340)
    end
end

camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
updateLayout()
