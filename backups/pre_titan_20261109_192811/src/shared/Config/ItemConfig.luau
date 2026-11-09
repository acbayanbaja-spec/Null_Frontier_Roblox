-- ItemConfig for NULL FRONTIER
-- Catalog of all cosmetics, armor, weapons, accessories, and marketplace products.
local ItemConfig = {
    -- Optional Robux Monetization Framework (Configurable by Place Owner)
    Monetization = {
        IsConfigured = false, -- Explicitly marks monetization as NOT CONFIGURED until real IDs are set
        GamePasses = {
            VIP_ACCESS = { Id = 0, Name = "Nexus VIP Access", Description = "Exclusive VIP nameplate and priority matchmaking", PriceRobux = 299 },
            COSMETIC_BUNDLE = { Id = 0, Name = "Vanguard Holo Pack", Description = "Access to exclusive neon cosmetic variants", PriceRobux = 199 }
        },
        DeveloperProducts = {
            CREDITS_500 = { Id = 0, Name = "500 Frontier Credits", Amount = 500, PriceRobux = 99 },
            CREDITS_1500 = { Id = 0, Name = "1,500 Frontier Credits", Amount = 1500, PriceRobux = 249 }
        }
    },
    
    -- In-Game Earned-Currency Items
    Items = {
        ["COSM_CYBER_VISOR_MK1"] = {
            Id = "COSM_CYBER_VISOR_MK1",
            Name = "Specter Cyber Visor",
            Category = "Cosmetics",
            Slot = "Head",
            Rarity = "Rare",
            PriceCredits = 150,
            Description = "High-frequency biometric scanning optic with HUD target acquisition.",
            ModelType = "Visor",
            AccentColor = Color3.fromRGB(0, 220, 255),
        },
        ["COSM_HOLO_HALO"] = {
            Id = "COSM_HOLO_HALO",
            Name = "Apex Holo-Crown",
            Category = "Cosmetics",
            Slot = "Head",
            Rarity = "Epic",
            PriceCredits = 350,
            Description = "Floating crystalline neon emitter hovering above the operative's crown.",
            ModelType = "Halo",
            AccentColor = Color3.fromRGB(255, 200, 60),
        },
        ["ARMOR_AEGIS_CORE"] = {
            Id = "ARMOR_AEGIS_CORE",
            Name = "Aegis Kinetic Core",
            Category = "Armor",
            Slot = "Body",
            Rarity = "Rare",
            PriceCredits = 250,
            Description = "Chest-mounted energy matrix that disperses kinetic shockwaves.",
            ModelType = "ChestCore",
            AccentColor = Color3.fromRGB(0, 255, 170),
        },
        ["ARMOR_NANITE_PLATING"] = {
            Id = "ARMOR_NANITE_PLATING",
            Name = "Obsidian Nanite Weave",
            Category = "Armor",
            Slot = "Body",
            Rarity = "Epic",
            PriceCredits = 500,
            Description = "Ultra-dense cybernetic armor plating engineered for hazardous zones.",
            ModelType = "Plating",
            AccentColor = Color3.fromRGB(180, 140, 255),
        },
        ["BACK_ION_WINGS"] = {
            Id = "BACK_ION_WINGS",
            Name = "Photon Glider Wings",
            Category = "Back",
            Slot = "Back",
            Rarity = "Legendary",
            PriceCredits = 800,
            Description = "Dual aerodynamic energy foils generating subtle particle trails.",
            ModelType = "Wings",
            AccentColor = Color3.fromRGB(0, 255, 230),
        },
        ["BACK_COMM_PACK"] = {
            Id = "BACK_COMM_PACK",
            Name = "Tactical Comms Pack",
            Category = "Back",
            Slot = "Back",
            Rarity = "Common",
            PriceCredits = 100,
            Description = "Rugged communications array with satellite uplink beacon.",
            ModelType = "Pack",
            AccentColor = Color3.fromRGB(150, 170, 190),
        },
        ["WEAPON_PLASMA_SABER"] = {
            Id = "WEAPON_PLASMA_SABER",
            Name = "Arc-Light Plasma Blade",
            Category = "Weapons",
            Slot = "Weapon",
            Rarity = "Epic",
            PriceCredits = 400,
            Description = "Retractable high-frequency plasma blade for close-quarters breach.",
            ModelType = "Blade",
            AccentColor = Color3.fromRGB(0, 220, 255),
        },
        ["WEAPON_CYBER_BATON"] = {
            Id = "WEAPON_CYBER_BATON",
            Name = "Shock Enforcement Baton",
            Category = "Weapons",
            Slot = "Weapon",
            Rarity = "Common",
            PriceCredits = 120,
            Description = "Heavy alloy shock baton standard-issue for sector pacification.",
            ModelType = "Baton",
            AccentColor = Color3.fromRGB(255, 180, 40),
        },
        ["EMOTE_FRONTIER_SALUTE"] = {
            Id = "EMOTE_FRONTIER_SALUTE",
            Name = "Frontier Holo-Salute",
            Category = "Emotes",
            Slot = "Emote",
            Rarity = "Common",
            PriceCredits = 50,
            Description = "Displays the official Central Nexus holographic badge salute.",
            ModelType = "Emote",
            AccentColor = Color3.fromRGB(0, 255, 180),
        }
    }
}

return table.freeze(ItemConfig)
