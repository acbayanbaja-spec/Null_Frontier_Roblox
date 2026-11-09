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

-- State
local isShiftPressed = false
local isGamepadSprintActive = false
local isMobileSprintActive = false
local isExhausted = false
local isCurrentlySprinting = false
local lastSprintEndTime = 0
local character = nil
local humanoid = nil

local function updateCharacter(newChar)
    character = newChar
    isShiftPressed = false
    isGamepadSprintActive = false
    isMobileSprintActive = false
    isExhausted = false
    isCurrentlySprinting = false
    lastSprintEndTime = 0
    
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

-- Key Input Handling (PC & Gamepad)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isShiftPressed = true
    elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
        -- Toggle sprint on gamepad thumbstick click
        isGamepadSprintActive = not isGamepadSprintActive
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isShiftPressed = false
    end
end)

-- Window focus lost safety (prevents stuck keys when alt-tabbing)
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

-- Main Movement & Stamina Loop
RunService.Heartbeat:Connect(function(dt)
    if not character or not humanoid or humanoid.Health <= 0 or player:GetAttribute("InMenu") == true then
        if humanoid and player:GetAttribute("InMenu") == true and humanoid.WalkSpeed ~= 0 then
            humanoid.WalkSpeed = 0
        end
        return
    end
    
    local currentStamina = player:GetAttribute("Stamina") or GameConfig.MaxStamina
    local maxStamina = player:GetAttribute("MaxStamina") or GameConfig.MaxStamina
    
    local wantsToSprint = (isShiftPressed or isGamepadSprintActive or isMobileSprintActive)
    local isMoving = humanoid.MoveDirection.Magnitude > 0.05
    
    -- Check exhaustion recovery
    if isExhausted then
        if currentStamina >= GameConfig.MinSprintStamina then
            isExhausted = false
        else
            wantsToSprint = false
        end
    end
    
    -- Determine actual sprint state
    local canSprint = wantsToSprint and isMoving and currentStamina > 0 and not isExhausted
    
    if canSprint then
        -- Drain stamina
        local newStamina = math.max(0, currentStamina - (GameConfig.StaminaDrainRate * dt))
        player:SetAttribute("Stamina", newStamina)
        
        if humanoid.WalkSpeed ~= GameConfig.SprintSpeed then
            humanoid.WalkSpeed = GameConfig.SprintSpeed
        end
        
        if not isCurrentlySprinting then
            isCurrentlySprinting = true
            RequestSprint:FireServer(true)
        end
        
        if newStamina <= 0 then
            -- Reached exhaustion
            isExhausted = true
            isMobileSprintActive = false
            isGamepadSprintActive = false
            lastSprintEndTime = os.clock()
        end
    else
        -- Not sprinting
        if humanoid.WalkSpeed ~= GameConfig.WalkSpeed then
            humanoid.WalkSpeed = GameConfig.WalkSpeed
        end
        
        if isCurrentlySprinting then
            isCurrentlySprinting = false
            lastSprintEndTime = os.clock()
            RequestSprint:FireServer(false)
        end
        
        -- Stamina regeneration
        if os.clock() - lastSprintEndTime >= GameConfig.StaminaRegenDelay then
            if currentStamina < maxStamina then
                local newStamina = math.min(maxStamina, currentStamina + (GameConfig.StaminaRegenRate * dt))
                player:SetAttribute("Stamina", newStamina)
            end
        end
    end
end)

print("[NullFrontier] MovementController initialized.")
