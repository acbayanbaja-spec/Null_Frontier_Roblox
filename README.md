# NULL FRONTIER (2099)
**A Premier Multiplayer Digital Civilization & Proving Challenge in Roblox**

[![Roblox](https://img.shields.io/badge/Platform-Roblox%20Studio-00A2FF?logo=roblox&logoColor=white)](https://www.roblox.com)
[![Luau](https://img.shields.io/badge/Language-Luau-00A2FF?logo=lua&logoColor=white)](https://luau-lang.org)
[![Status](https://img.shields.io/badge/Release%20Status-Launch%20Ready%20%2F%20Overhauled-brightgreen)](#milestones-overview)

---

## 1. Overview & Vision

The year is **2099**. Operatives inhabit **FRONTIER**, a massive utopian digital civilization created by the enigmatic Escobillo.

**NULL FRONTIER** combines open-world solarpunk megacity exploration, competitive tactical combat, party synchronization, an interconnected multi-level garden labyrinth maze, server-authoritative progression, and deep story lore surrounding the elusive **Golden Key**.

### Core Pillars
- **Authentic Player Identity:** Players explore as their own normal Roblox avatars; clothing, accessories, hair, and packages are 100% preserved. Zero forced character swaps.
- **Fair Play & Clean Spawns:** Starting loadouts are completely clean with zero pre-equipped armor or weapons. Gateway access, the Central Nexus, maze proving grounds, and duels are 100% free with no paywalls.
- **Server Authority Everywhere:** Health, shields, stamina, XP, levels, currency transactions, inventory ownership, cooldowns, and combat damage are strictly server-validated.

---

## 2. Completed Milestones & Feature Roadmap

All 8 core development milestones and the comprehensive AAA visual overhaul have been implemented, tested, and verified:

| Milestone | Subsystem | Key Implementations | Documentation |
|---|---|---|---|
| **Milestone 1** | **Core Movement & Stamina** | 16 stud/s walk, 26 stud/s sprint, stamina drain/regen, mobile touch controls. | Verified in Engine |
| **Milestone 2** | **HUD & Main Menu** | Cinematic camera drift, preload sequence, live health/shield/stamina/XP bars. | Verified in Engine |
| **Milestone 3** | **Central Nexus Megacity** | 10 urban districts (Central Plaza, Commercial, Tech, Residential, Training Yard, Skyline). | Verified in Engine |
| **Milestone 4** | **Multiplayer & Social** | Squad party system (4-player cap), invite cooldowns, proximity tactical comms, Operatives Directory. | [`Milestone 4 Report`](docs/Milestone_4_Completion_Report.md) |
| **Milestone 5** | **Progression & Economy** | Mathematical XP curve ($\text{BaseXP} \times \text{Level}^{1.35}$), Frontier Credits, daily/exploration missions, achievements, DataStore persistence. | [`Milestone 5 Report`](docs/Milestone_5_Completion_Report.md) |
| **Milestone 6** | **Marketplace & Loadout** | Supply Depot catalog, atomic credit purchases, duplicate purchase protection, non-colliding cosmetic attachments (`Massless = true`). | [`Milestone 6 Report`](docs/Milestone_6_Completion_Report.md) |
| **Milestone 7** | **Escobillo's Game & Combat** | 240x240 proving maze, Checkpoints Alpha/Beta/Omega, Core Matrix puzzle, The Golden Key story claim, cyber adversaries (`NullSentinel`, `FrontierCorruptor`), Apex Arena duels. | [`Milestone 7 Report`](docs/Milestone_7_Completion_Report.md) |
| **Milestone 8** | **Integration & Security** | 3D spatial anti-exploit distance checks, 391 parts optimized for physics (`CanTouch = false`), 207 parts optimized for GPU (`CastShadow = false`), 34-point QA test suite (34/34 passed). | [`Milestone 8 Report`](docs/Milestone_8_Release_Readiness_Report.md) |
| **Overhaul** | **Ultimate Visual Overhaul** | Radiant sunny daylight (`ClockTime = 14.25`), turquoise reflecting pools, fountains, cypress gardens, classical rotunda gazebo, stadium grandstands, airship, and festival promenade. | [`Overhaul Report`](docs/Ultimate_Visual_Overhaul_Completion_Report.md) |

---

## 3. Project Structure

```
Null_Frontier_Roblox/
├── Place2.rbxl                     # Master Roblox Studio place file (Binary)
├── README.md                       # Repository documentation & guide
├── .gitignore                      # Git configuration & ignored files
├── docs/                           # Detailed engineering and QA milestone reports
│   ├── Milestone_4_Completion_Report.md
│   ├── Milestone_5_Completion_Report.md
│   ├── Milestone_6_Completion_Report.md
│   ├── Milestone_7_Completion_Report.md
│   ├── Milestone_8_Release_Readiness_Report.md
│   ├── Visual_Overhaul_Plan.md
│   └── Ultimate_Visual_Overhaul_Completion_Report.md
└── src/                            # Deconstructed Luau codebase
    ├── server/                     # ServerScriptService (Server-authoritative backend)
    │   ├── PlayerManager.luau
    │   ├── DataStoreManager.luau
    │   ├── ProgressionManager.luau
    │   ├── InventoryManager.luau
    │   ├── CombatManager.luau
    │   ├── EnemyAIManager.luau
    │   ├── MazeManager.luau
    │   ├── ArenaManager.luau
    │   ├── SocialManager.luau
    │   ├── MissionManager.luau
    │   ├── AchievementManager.luau
    │   ├── RewardService.luau
    │   └── MarketplaceManager.luau
    ├── client/                     # StarterPlayerScripts & StarterGui (Frontend controllers)
    │   ├── Controllers/
    │   │   ├── MovementController.luau
    │   │   ├── CombatController.luau
    │   │   └── CityAnimationController.luau
    │   └── UI/
    │       ├── NullFrontierHUD/HUDController.luau
    │       ├── NullFrontierMenu/MenuController.luau
    │       ├── NullFrontierSocial/SocialController.luau
    │       ├── NullFrontierProgression/ProgressionController.luau
    │       └── NullFrontierMarketplace/MarketplaceController.luau
    └── shared/                     # ReplicatedStorage (Shared modules & configurations)
        ├── Config/
        │   ├── GameConfig.luau
        │   ├── ItemConfig.luau
        │   ├── MissionConfig.luau
        │   └── AchievementConfig.luau
        └── Modules/
            ├── FormatUtil.luau
            └── SettingsController.luau
```

---

## 4. Controls & Input Mapping

| Action | Desktop (Keyboard & Mouse) | Mobile (Touch Controls) | Gamepad (Controller) |
|---|---|---|---|
| **Move** | `W`, `A`, `S`, `D` | Dynamic Touch Joystick | Left Thumbstick |
| **Sprint** | `LeftShift` (Hold while moving) | `⚡ SPRINT` Touch Button (Toggle) | `ButtonL3` (Click Thumbstick) |
| **Jump** | `Space` | Jump Button | `ButtonA` |
| **Light Melee Strike** | `Mouse1` (Left Click) or `F` | `⚔ STRIKE` Touch Button | `ButtonR2` |
| **Squad / Directory** | `[👥 SQUAD]` Button | `[👥 SQUAD]` Button | D-Pad Left |
| **Missions Modal** | `[★ MISSIONS]` Button or `M` | `[★ MISSIONS]` Button | D-Pad Up |
| **Supply Depot** | `[🛒 DEPOT]` Button | `[🛒 DEPOT]` Button | D-Pad Right |
| **Interact / Prompts** | `E` (Proximity Prompt) | Tap Proximity Prompt | `ButtonX` |

---

## 5. Security & Anti-Exploit Summary

- **Spatial Distance Validations:** Gateway deployment, arena duels, matrix console triggers, and Golden Key collection enforce server-side Euclidean distance checks ($15$ to $40$ studs).
- **Line-of-Sight Raycasting:** Melee attacks enforce line-of-sight raycasts to prevent attacking through walls or blast doors.
- **Persistence Integrity:** `DataStoreManager` employs dual-indexing (`Player` instance & `Player.UserId`), exponential retry backoff, session locking, and a high-fidelity mock store in Studio testing.
- **Rate-Limiting:** Cooldowns enforced on invites (6.0s), attacks (0.45s), and queue submissions.
