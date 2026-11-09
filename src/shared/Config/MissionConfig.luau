-- Mission Configuration for NULL FRONTIER
local MissionConfig = {
    Missions = {
        -- Daily Missions (Reset every 24h)
        ["DAILY_PATROL"] = {
            Id = "DAILY_PATROL",
            Category = "Daily",
            Title = "Sector Reconnaissance",
            Description = "Patrol the Central Nexus and sprint at least 250 studs.",
            Target = 250,
            Unit = "studs",
            RewardXP = 80,
            RewardCredits = 150,
        },
        ["DAILY_COMM"] = {
            Id = "DAILY_COMM",
            Category = "Daily",
            Title = "Operative Uplink",
            Description = "View another operative's tactical dossier in the sector.",
            Target = 1,
            Unit = "inspect",
            RewardXP = 60,
            RewardCredits = 100,
        },
        
        -- Exploration Missions
        ["EXPLORE_NEXUS"] = {
            Id = "EXPLORE_NEXUS",
            Category = "Exploration",
            Title = "Nexus Pioneer",
            Description = "Explore all 4 core districts of the Central Nexus (Commercial, Tech, Residential, Training Yard).",
            Target = 4,
            Unit = "districts",
            RewardXP = 200,
            RewardCredits = 350,
        },
        ["VISIT_TECH"] = {
            Id = "VISIT_TECH",
            Category = "Exploration",
            Title = "Silicon Gateway",
            Description = "Navigate to the Technology District to inspect high-frequency data arrays.",
            Target = 1,
            Unit = "visit",
            RewardXP = 90,
            RewardCredits = 120,
        },
        
        -- Social Missions
        ["FORM_SQUAD"] = {
            Id = "FORM_SQUAD",
            Category = "Social",
            Title = "Tactical Fireteam",
            Description = "Form or join a tactical squad with other operatives.",
            Target = 1,
            Unit = "squad",
            RewardXP = 150,
            RewardCredits = 250,
        },
        
        -- Progression Missions
        ["REACH_LEVEL_2"] = {
            Id = "REACH_LEVEL_2",
            Category = "Progression",
            Title = "Field Clearance",
            Description = "Accumulate sufficient field experience to advance to Level 2.",
            Target = 2,
            Unit = "level",
            RewardXP = 100,
            RewardCredits = 200,
        },
        ["ACCUMULATE_CREDITS"] = {
            Id = "ACCUMULATE_CREDITS",
            Category = "Progression",
            Title = "Economic Footprint",
            Description = "Earn a balance of at least 300 Frontier Credits.",
            Target = 300,
            Unit = "credits",
            RewardXP = 120,
            RewardCredits = 200,
        }
    }
}

return table.freeze(MissionConfig)
