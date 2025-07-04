Config = {}

-- Configuration for player trapping
Config.PlayerTrapSettings = {
    Damage = 15,                     -- Base damage when caught in trap
    RagdollDuration = 5000,          -- 5 seconds initial ragdoll
    TrapDuration = 10000,            -- 10 seconds in trap
    LimpDuration = 30000,            -- 30 seconds of limping after release
    TrapChance = 80,                 -- Chance to trigger when stepped on (1-100)
    UnfreezeAfterRagdoll = true,     -- Unfreeze after ragdoll
    SoundEffect = "Bait_Steal_Large" -- Sound effect for player capture
}

-- Configuration for animal trapping
Config.AnimalTrapSettings = {
    CheckRadius = 2.0,               -- Radius to check for animals
    CaptureChance = 80,              -- Default capture chance (overridden by bait-specific chances)
    CaptureDuration = 1,            -- Default duration (overridden by trap-specific CaptureDuration)
}

-- General configuration
Config.InteractionDistance = 2.0      -- Distance for interacting with traps
Config.AnimalsPerTrap = 1           -- Number of animals to spawn per trap
Config.SpawnDelay = 2000             -- Delay between animal spawns (ms)
Config.MinSpawnDistance = 5.0        -- Minimum distance for animal spawn
Config.SpawnRadius = 15.0            -- Maximum distance for animal spawn
Config.MaxTrapsPerPlayer = 5         -- Maximum traps per player
Config.RequireJob = false            -- Whether to require specific jobs
Config.AllowedJobs = {}              -- Jobs allowed to use traps
Config.Debug = false                 -- Debug mode

Config.Prompts = {
    Collect = "Collect Trap",
    Check = "Check Trap"
}

-- Trap configuration
Config.Traps = {
    {
        Item = 'beartrap',
        Model = `s_beartrapanimated01x`, 
        FallbackModel = `s_beartrapanimated01x`, 
        Baits = {
            { 
                item = nil, 
                animals = { 'a_c_bear_01', 'a_c_wolf_01', 'a_c_cougar_01' }, 
                chance = 75 
            },
            { 
                item = nil, 
                animals = { 'a_c_fox_01', 'a_c_coyote_01', 'a_c_raccoon_01', 'a_c_boar_01', 'A_C_Beaver_01', 'A_C_Skunk_01' }, 
                chance = 60 
            },
            { 
                item = nil, 
                animals = { 'a_c_deer_01', 'a_c_elk_01', 'a_c_pronghorn_01', 'A_C_Buck_01' }, 
                chance = 50 
            },
            {
                item = nil,
                animals = { 'a_c_rabbit_01', 'a_c_squirrel_01', 'a_c_rat_01' },
                chance = 25
            }
        },
        CaptureDuration = 20,
        Damage = 90,
        Animation = 'WORLD_HUMAN_CROUCH_INSPECT',
        MaxCaptures = 3,
        PlacementTime = 5000,
        AnimalTrapAnimation = {
            dict = "amb_creatures_mammal@pain",
            anim = "pain_loop"
        },
        TrapAnimation = {
            dict = "script_re@bear_trap",
            open_anim = "bandage_dailog01_trap",
            close_anim = "bandage_dailog02_trap"
        }
    }
}
