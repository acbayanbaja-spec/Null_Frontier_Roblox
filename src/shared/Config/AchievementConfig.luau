-- Achievement Configuration for NULL FRONTIER
local AchievementConfig = {
    Achievements = {
        ["ACH_FIRST_BOOT"] = {
            Id = "ACH_FIRST_BOOT",
            Category = "Progression",
            Title = "Digital Awaken",
            Description = "Successfully materialize into NULL FRONTIER Central Nexus.",
            Condition = "Join the Central Nexus for the first time.",
            RewardXP = 50,
            RewardCredits = 100,
        },
        ["ACH_SPRINT_VETERAN"] = {
            Id = "ACH_SPRINT_VETERAN",
            Category = "Challenge",
            Title = "Overclocked Mobility",
            Description = "Sprint for a cumulative distance of 500 studs.",
            Condition = "Sprint 500 studs.",
            RewardXP = 100,
            RewardCredits = 150,
        },
        ["ACH_SURVEYOR"] = {
            Id = "ACH_SURVEYOR",
            Category = "Explorer",
            Title = "City Surveyor",
            Description = "Chart all 4 perimeter sectors of the megacity.",
            Condition = "Visit Commercial, Tech, Residential, and Training Yard.",
            RewardXP = 250,
            RewardCredits = 500,
        },
        ["ACH_SQUADRON"] = {
            Id = "ACH_SQUADRON",
            Category = "Social",
            Title = "Networked Operatives",
            Description = "Establish a unified tactical squad connection.",
            Condition = "Form or join a 2+ player squad.",
            RewardXP = 150,
            RewardCredits = 300,
        },
        ["ACH_REACH_LVL_3"] = {
            Id = "ACH_REACH_LVL_3",
            Category = "Progression",
            Title = "Tier-1 Operative",
            Description = "Ascend through combat and exploration to reach Level 3.",
            Condition = "Reach Player Level 3.",
            RewardXP = 200,
            RewardCredits = 400,
        },
        ["ACH_CREDIT_BARON"] = {
            Id = "ACH_CREDIT_BARON",
            Category = "Progression",
            Title = "Frontier Tycoon",
            Description = "Amass a total treasury of 1,000 Frontier Credits.",
            Condition = "Hold 1,000 Credits simultaneously.",
            RewardXP = 300,
            RewardCredits = 600,
        }
    }
}

return table.freeze(AchievementConfig)
