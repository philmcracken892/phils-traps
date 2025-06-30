Config = {}









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
