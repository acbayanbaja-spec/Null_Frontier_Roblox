-- CombatManager for NULL FRONTIER
-- Server-authoritative hit detection, cooldowns, range verification, and shield absorption.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NullFrontier = ReplicatedStorage:WaitForChild("NullFrontier")
local Remotes = NullFrontier.Remotes
local RequestAttackRE = Remotes:WaitForChild("RequestAttack")
local EntityDamagedRE = Remotes:WaitForChild("EntityDamaged")

local CombatManager = {}
local attackCooldowns = {} -- player -> timestamp

local ATTACK_COOLDOWN = 0.45
local MAX_ATTACK_DISTANCE = 13.0
local BASE_UNARMED_DAMAGE = 20
local WEAPON_DAMAGE = 35

-- Server-Authoritative Attack Handler
RequestAttackRE.OnServerEvent:Connect(function(player: Player, attackType: string, targetEntity: Instance?)
    local now = os.clock()
    local lastAttack = attackCooldowns[player] or 0
    if now - lastAttack < ATTACK_COOLDOWN then return end
    attackCooldowns[player] = now
    
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then return end
    
    -- Check if player has an equipped weapon to enhance damage
    local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))
    local profile = DataStoreManager.GetSessionData(player)
    local hasWeapon = profile and profile.Equipment and profile.Equipment.Weapon ~= nil
    local damageAmount = hasWeapon and WEAPON_DAMAGE or BASE_UNARMED_DAMAGE
    
    if not targetEntity or not targetEntity.Parent then return end
    
    -- Resolve Target Model & Humanoid
    local targetModel = targetEntity:IsA("Model") and targetEntity or targetEntity:FindFirstAncestorOfClass("Model")
    if not targetModel or targetModel == char then return end
    
    local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
    local targetPart = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Head") or targetModel.PrimaryPart
    if not targetHum or targetHum.Health <= 0 or not targetPart then return end
    
    -- 1. Distance Check
    local dist = (hrp.Position - targetPart.Position).Magnitude
    if dist > MAX_ATTACK_DISTANCE then return end
    
    -- 2. Line of Sight Raycast (Prevents attacking through walls)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {char, targetModel}
    local rayResult = Workspace:Raycast(hrp.Position, (targetPart.Position - hrp.Position), rayParams)
    if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
        return -- Blocked by geometry
    end
    
    -- 3. Apply Damage (Respecting Shield if Target is a Player)
    local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
    local isShieldHit = false
    
    if targetPlayer then
        local currentShield = targetPlayer:GetAttribute("Shield") or 0
        if currentShield >= damageAmount then
            targetPlayer:SetAttribute("Shield", currentShield - damageAmount)
            isShieldHit = true
        else
            local remaining = damageAmount - currentShield
            targetPlayer:SetAttribute("Shield", 0)
            targetHum:TakeDamage(remaining)
        end
    else
        -- NPC Enemy Model
        targetHum:TakeDamage(damageAmount)
    end
    
    -- 4. Broadcast Hit Feedback
    EntityDamagedRE:FireAllClients(targetModel, damageAmount, isShieldHit, targetHum.Health)
    
    print(string.format("[CombatManager] %s hit %s for %d damage (ShieldHit: %s, NewHP: %d).", player.Name, targetModel.Name, damageAmount, tostring(isShieldHit), targetHum.Health))
end)

Players.PlayerRemoving:Connect(function(player)
    attackCooldowns[player] = nil
end)

return CombatManager
