local GameConfig = {
    -- Movement & Physics
    WalkSpeed = 16,
    SprintSpeed = 26,
    JumpPower = 50,
    
    -- Stamina System
    MaxStamina = 100,
    StaminaDrainRate = 18,       -- Stamina drained per second while sprinting
    StaminaRegenRate = 15,       -- Stamina regenerated per second when resting
    StaminaRegenDelay = 1.0,     -- Seconds before stamina regen starts after sprinting stops
    MinSprintStamina = 10,       -- Minimum stamina required to resume sprinting
    
    -- Health & Shield System
    MaxHealth = 100,
    MaxShield = 100,
    ShieldRegenRate = 12,        -- Shield restored per second
    ShieldRegenDelay = 3.5,      -- Seconds before shield regen starts after taking damage
    
    -- Avatar & Spawning Architecture (Updated Design)
    UseDefaultRobloxAvatar = true,        -- Always use player's standard Roblox avatar
    PreserveAvatarAppearance = true,      -- Keep accessories, clothing, hair, body proportions
    ForceCharacterSelection = false,      -- No forced character pick screen
    GiveStartingWeapons = false,          -- Spawns completely unarmed (no starting tools)
    GiveStartingArmor = false,            -- No starting armor equipment
    
    -- Progression & In-Game Economy
    DefaultLevel = 1,
    DefaultStatus = "OPERATIVE: ACTIVE",
    StartingCredits = 0,                  -- In-game currency earned via missions and gameplay
    BaseXPPerLevel = 100,
    XPScalingMultiplier = 1.25,
    
    -- Campaign & Story Operatives (NPCs for Story / Missions only; NOT player avatars)
    StoryNPCs = {
        Jahred = { Role = "Tactical Commander", Location = "Central Nexus Command" },
        Angel = { Role = "Chief Tech Specialist", Location = "Engineering Deck" },
        JohnSteve = { Role = "Field Operative", Location = "Frontier Outpost" },
        Joyce = { Role = "Intelligence Analyst", Location = "Communications Array" },
        JesselMae = { Role = "Logistics Coordinator", Location = "Nexus Depot" }
    },
    
    -- Marketplace & Monetization Architecture (Optional Purchases)
    Monetization = {
        FairPlayRules = {
            CoreGameplayFree = true,          -- Essential gameplay & access are 100% free
            ServerValidatedOnly = true,       -- Client requests never grant purchases directly
            AntiPayToWin = true               -- Equipment earnable via in-game progression
        },
        -- Registered GamePass IDs and Developer Product IDs (Configurable)
        GamePasses = {
            VIPAccess = 0,                    -- Replace with actual GamePass ID when published
            CosmeticPack = 0
        },
        DeveloperProducts = {
            CreditsSmall = 0,
            CreditsMedium = 0
        }
    }
}

return table.freeze(GameConfig)
