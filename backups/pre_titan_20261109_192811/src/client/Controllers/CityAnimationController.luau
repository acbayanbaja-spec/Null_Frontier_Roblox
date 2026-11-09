local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local world = workspace:WaitForChild("World", 10)
if not world then return end

-- 1. Central Monument Animation
local centralPlaza = world:WaitForChild("CentralPlaza", 10)
local monument = centralPlaza and centralPlaza:WaitForChild("CentralNexusMonument", 10)
local core = monument and monument:WaitForChild("NexusCore", 10)
local ring = monument and monument:WaitForChild("HoloRing", 10)
local coreLight = core and core:FindFirstChildOfClass("PointLight")

-- 2. Maglev Transit Animation
local resDistrict = world:WaitForChild("ResidentialDistrict", 10)
local maglev = resDistrict and resDistrict:WaitForChild("MaglevTransitSystem", 10)
local trainCar = maglev and maglev:WaitForChild("MaglevTrainCar", 10)

-- Maglev Train State
local trainStartX = -120
local trainEndX = -200
local trainSpeed = 16 -- studs/sec
local trainDir = -1
local currentTrainX = trainStartX
local trainCarParts = trainCar and trainCar:GetChildren() or {}

-- Store relative offsets for train car parts
local trainOffsets = {}
if trainCar then
    for _, part in ipairs(trainCarParts) do
        if part:IsA("BasePart") then
            trainOffsets[part] = part.CFrame.Position - Vector3.new(currentTrainX, 19.5, 18)
        end
    end
end

-- Animation Loop (Lightweight, physics-free RenderStepped)
local coreRotAngle = 0
local ringRotAngle = 0
local pulseTime = 0

RunService.RenderStepped:Connect(function(dt)
    -- Rotate Central Core
    if core then
        coreRotAngle = (coreRotAngle + dt * 45) % 360
        core.CFrame = CFrame.new(0, 15, 0) * CFrame.Angles(0, math.rad(coreRotAngle), 0)
    end
    
    -- Rotate and Tilt Holo Ring
    if ring then
        ringRotAngle = (ringRotAngle - dt * 30) % 360
        ring.CFrame = CFrame.new(0, 15, 0) * CFrame.Angles(math.rad(12), math.rad(ringRotAngle), math.rad(8))
    end
    
    -- Subtle Core Light Pulse
    if coreLight then
        pulseTime = pulseTime + dt * 2.5
        coreLight.Brightness = 3.5 + math.sin(pulseTime) * 0.8
    end
    
    -- Move Maglev Train smoothly along elevated track
    if trainCar and #trainCarParts > 0 then
        currentTrainX = currentTrainX + (trainDir * trainSpeed * dt)
        if currentTrainX <= trainEndX then
            currentTrainX = trainEndX
            trainDir = 1 -- reverse direction smoothly
        elseif currentTrainX >= trainStartX then
            currentTrainX = trainStartX
            trainDir = -1
        end
        
        local centerPos = Vector3.new(currentTrainX, 19.5, 18)
        for part, offset in pairs(trainOffsets) do
            part.CFrame = CFrame.new(centerPos + offset)
        end
    end
end)

print("[NullFrontier] CityAnimationController initialized.")
