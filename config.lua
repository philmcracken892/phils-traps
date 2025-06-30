Config = {}

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
                animals = { 'a_c_fox_01', 'a_c_coyote_01', 'a_c_raccoon_01', 'a_c_boar_01' }, 
                chance = 60 
            },
            { 
                item = nil, 
                animals = { 'a_c_deer_01', 'a_c_elk_01', 'a_c_pronghorn_01' }, 
                chance = 50 
            },
            {
                item = nil,
                animals = { 
                    'a_c_rabbit_01', 'a_c_squirrel_01', 'a_c_chipmunk_01',
                    'a_c_fox_01', 'a_c_coyote_01', 'a_c_wolf_01' 
                },
                chance = 25
            }
        },
        CaptureDuration = 20,
        Damage = 90,
        Animation = 'WORLD_HUMAN_CROUCH_INSPECT',
        MaxCaptures = 3,
        PlacementTime = 5000
    }
}




Config.InteractionDistance = 2.5
Config.CheckRadius = 2.0 -- Radius for animal detection
Config.SpawnRadius = 60.0 -- Max radius for spawning random animal
Config.MinSpawnDistance = 5.0 -- Minimum distance from player for animal spawn
Config.AnimalsPerTrap = 1 
Config.Prompts = {
    Collect = 'Collect Trap',
    Check = 'Check Trap'
}







Config.UpdateInterval = 2000 
Config.MaxTrapsPerPlayer = 1 


Config.Debug = false


Config.UseOxLib = true 


Config.RequireJob = false -- Set to true if only certain jobs can use traps
Config.AllowedJobs = { 'hunter', 'trapper' } -- Jobs that can use traps if RequireJob is true


Config.RestrictedZones = {
    -- Add coordinates where traps cannot be placed
    -- { coords = vector3(x, y, z), radius = 50.0, name = "Town Center" }
}


Config.Sounds = {
    PlaceTrap = nil, -- 'trap_place'
    TrapTriggered = nil, -- 'trap_snap'
    CollectTrap = nil -- 'trap_collect'
}