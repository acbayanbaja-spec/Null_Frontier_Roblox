-- MovementController for NULL FRONTIER
-- Responsive client movement & sprint handling respecting server-authoritative stamina.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local GameConfig = require(NullFrontier.Config.GameConfig)
local Remotes = NullFrontier.Remotes
local RequestSprint = Remotes:WaitForChild("RequestSprint")
local LocalSprintToggle = Remotes:WaitForChild("LocalSprintToggle")

-- Input States
local isShiftPressed = false
local isGamepadSprintActive = false
local isMobileSprintActive = false
local isCurrentlySprinting = false
local character = nil
local humanoid = nil

local function updateCharacter(newChar)
    character = newChar
    isShiftPressed = false
    isGamepadSprintActive = false
    isMobileSprintActive = false
    isCurrentlySprinting = false
    
    if character then
        humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.WalkSpeed = GameConfig.WalkSpeed
        end
    end
end

player.CharacterAdded:Connect(updateCharacter)
if player.Character then
    updateCharacter(player.Character)
end

-- Keyboard & Gamepad Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isShiftPressed = true
    elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
        isGamepadSprintActive = not isGamepadSprintActive
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isShiftPressed = false
    end
end)

-- Window focus safety
UserInputService.WindowFocused:Connect(function()
    isShiftPressed = false
end)
UserInputService.WindowFocusReleased:Connect(function()
    isShiftPressed = false
end)

-- Mobile Sprint Toggle Handling (via BindableEvent from HUD)
LocalSprintToggle.Event:Connect(function(activeState: boolean?)
    if activeState ~= nil then
        isMobileSprintActive = activeState
    else
        isMobileSprintActive = not isMobileSprintActive
    end
end)

-- React to Server Exhaustion Signal
player:GetAttributeChangedSignal("IsExhausted"):Connect(function()
    if player:GetAttribute("IsExhausted") == true then
        isMobileSprintActive = false
        isGamepadSprintActive = false
        if isCurrentlySprinting then
            isCurrentlySprinting = false
            RequestSprint:FireServer(false)
            if humanoid then
                humanoid.WalkSpeed = GameConfig.WalkSpeed
            end
        end
    end
end)

-- Main Responsive Client Movement Loop
RunService.RenderStepped:Connect(function()
    if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InMenu") == true then
        if humanoid and player:GetAttribute("InMenu") == true and humanoid.WalkSpeed ~= 0 then
            humanoid.WalkSpeed = 0
        end
        return
    end
    
    local serverStamina = player:GetAttribute("Stamina") or GameConfig.MaxStamina
    local serverExhausted = player:GetAttribute("IsExhausted") == true
    
    local wantsToSprint = (isShiftPressed or isGamepadSprintActive or isMobileSprintActive)
    local isMoving = humanoid.MoveDirection.Magnitude > 0.05
    
    local shouldSprint = wantsToSprint and isMoving and not serverExhausted and serverStamina > 0
    
    if shouldSprint then
        if not isCurrentlySprinting then
            isCurrentlySprinting = true
            RequestSprint:FireServer(true)
        end
        -- Client-side prediction for instant responsive feel
        if humanoid.WalkSpeed ~= GameConfig.SprintSpeed then
            humanoid.WalkSpeed = GameConfig.SprintSpeed
        end
    else
        if isCurrentlySprinting then
            isCurrentlySprinting = false
            RequestSprint:FireServer(false)
        end
        if humanoid.WalkSpeed ~= GameConfig.WalkSpeed then
            humanoid.WalkSpeed = GameConfig.WalkSpeed
        end
    end
end)

print("[NullFrontier] MovementController initialized (Server-Authoritative Compliant).")
