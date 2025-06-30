local RSGCore = exports['rsg-core']:GetCoreObject()
local ox_lib = exports.ox_lib
local traps = {}
local prompts = {}
local capturedAnimals = {}
local spawnedAnimals = {}

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
                animals = { 'a_c_rabbit_01', 'a_c_squirrel_01', 'a_c_chipmunk_01' },
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

local function MakePlayerLimp(ped, duration)
    if not DoesEntityExist(ped) then return end
    
    -- Set injured state
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, 1)
    
    -- Reduce movement speed
    SetPedMoveRateOverride(ped, 0.5)
    
    -- Disable sprint and jump
    SetPedConfigFlag(ped, 43, true)  -- Disable melee
    SetPedConfigFlag(ped, 4, true)   -- Disable jumping
    
    -- Reset after duration
    SetTimeout(duration, function()
        if DoesEntityExist(ped) then
            Citizen.InvokeNative(0x59BD177A1A48600A, ped, 0)
            SetPedConfigFlag(ped, 43, false)
            SetPedConfigFlag(ped, 4, false)
            SetPedMoveRateOverride(ped, 1.0)
            
            -- Notify player they've recovered
            ox_lib:notify({
                type = 'success',
                title = 'Injury',
                description = 'You have recovered from your injury',
                duration = 5000
            })
        end
    end)
end

local function IsAnimalPed(ped)
    local model = GetEntityModel(ped)
    for _, trap in pairs(Config.Traps) do
        for _, bait in pairs(trap.Baits) do
            for _, animal in pairs(bait.animals) do
                if model == GetHashKey(animal) then
                    return true
                end
            end
        end
    end
    return false
end

local function GetRandomAnimalModel()
    local allAnimals = {}
    for _, trap in pairs(Config.Traps) do
        for _, bait in pairs(trap.Baits) do
            for _, animal in pairs(bait.animals) do
                if not allAnimals[animal] then
                    allAnimals[animal] = true
                    table.insert(allAnimals, GetHashKey(animal))
                end
            end
        end
    end
    return allAnimals[math.random(1, #allAnimals)]
end

local function RagdollPlayer(ped, duration)
    if not IsPedHuman(ped) then return end
    
    -- Force ragdoll
    SetPedToRagdoll(ped, duration, duration, 0, true, true, false)
    
    
    -- Visual effects
    Citizen.InvokeNative(0x4102732DF6B4005F, "HitReaction", ped, 1.0)
    Citizen.InvokeNative(0x59BD177A1A48600A, ped, 1)
    
    -- Temporary disable controls
    DisableControlAction(0, 0x8FFC75D6, true) -- Disable sprint
    DisableControlAction(0, 0x07CE1E61, true) -- Disable jump
end

local function CaptureAnimal(ped, trapId, trap)
    if not DoesEntityExist(ped) or capturedAnimals[ped] then return end
    
    -- Increment capture count
    traps[trapId].captureCount = (traps[trapId].captureCount or 0) + 1
    
    capturedAnimals[ped] = true
    spawnedAnimals[ped] = nil
    
    -- Stop the animal's movement
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    
    -- Play trap close animation
    if trap.config.TrapAnimation then
        RequestAnimDict(trap.config.TrapAnimation.dict)
        local timeout = 0
        while not HasAnimDictLoaded(trap.config.TrapAnimation.dict) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 1
        end
        if HasAnimDictLoaded(trap.config.TrapAnimation.dict) then
            TaskPlayAnim(trap.obj, trap.config.TrapAnimation.dict, trap.config.TrapAnimation.close_anim, 
                        8.0, -8.0, -1, 0, 0, false, false, false)
            RemoveAnimDict(trap.config.TrapAnimation.dict)
        end
    end
    
    -- Play animal trap animation if available
    if trap.config.AnimalTrapAnimation then
        RequestAnimDict(trap.config.AnimalTrapAnimation.dict)
        local timeout = 0
        while not HasAnimDictLoaded(trap.config.AnimalTrapAnimation.dict) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 1
        end
        if HasAnimDictLoaded(trap.config.AnimalTrapAnimation.dict) then
            TaskPlayAnim(ped, trap.config.AnimalTrapAnimation.dict, 
                        trap.config.AnimalTrapAnimation.anim, 
                        8.0, -8.0, -1, 1, 0, false, false, false)
            RemoveAnimDict(trap.config.AnimalTrapAnimation.dict)
        end
    end
    
    -- Play trap sound
    if trap.config.TrapSound then
        Citizen.InvokeNative(0xCE5D0FFE8390B7FB, trap.obj, trap.config.TrapSound, 1.0, 0, 0, 0, 0)
        -- Alternative: PlaySoundFrontend("trap_snap", "bear_trap_sounds", true, 0)
    end
    
    -- Notify server
    local entityId = trap.isNetworked and NetworkGetNetworkIdFromEntity(ped) or ped
    TriggerServerEvent('rsg_beartraps:animalCaptured', trapId, GetEntityModel(ped), entityId)
    
    -- Kill animal immediately
    if DoesEntityExist(ped) then
        SetEntityHealth(ped, 0)
        capturedAnimals[ped] = nil
    end
    
    -- Reset trap to open animation after duration
    SetTimeout(trap.config.CaptureDuration * 1000, function()
        if DoesEntityExist(trap.obj) and trap.config.TrapAnimation then
            RequestAnimDict(trap.config.TrapAnimation.dict)
            local timeout = 0
            while not HasAnimDictLoaded(trap.config.TrapAnimation.dict) and timeout < 1000 do
                Wait(10)
                timeout = timeout + 1
            end
            if HasAnimDictLoaded(trap.config.TrapAnimation.dict) then
                TaskPlayAnim(trap.obj, trap.config.TrapAnimation.dict, trap.config.TrapAnimation.open_anim, 
                            8.0, -8.0, -1, 1, 0, false, false, false)
                RemoveAnimDict(trap.config.TrapAnimation.dict)
            end
        end
        
        -- Check if trap reached max captures
        if traps[trapId] and traps[trapId].captureCount >= trap.config.MaxCaptures then
            if DoesEntityExist(trap.obj) then
                ClearPedTasks(trap.obj)
                DeleteObject(trap.obj)
            end
            if prompts[trapId .. '_collect'] then
                PromptDelete(prompts[trapId .. '_collect'])
                prompts[trapId .. '_collect'] = nil
            end
            if prompts[trapId .. '_check'] then
                PromptDelete(prompts[trapId .. '_check'])
                prompts[trapId .. '_check'] = nil
            end
            TriggerServerEvent('rsg_beartraps:removeTrap', trapId)
            traps[trapId] = nil
        end
    end)
end
local function FindSafeSpawnPosition(trapCoords, playerCoords, minDistance, maxDistance)
    local attempts = 0
    local maxAttempts = 50
    
    while attempts < maxAttempts do
        local angle = math.random() * 2 * math.pi
        local radius = math.random(minDistance, maxDistance)
        local spawnX = trapCoords.x + math.cos(angle) * radius
        local spawnY = trapCoords.y + math.sin(angle) * radius
        
        local groundFound, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, trapCoords.z + 50.0, false)
        if not groundFound then
            groundFound, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, trapCoords.z + 10.0, false)
        end
        
        local spawnZ = groundFound and groundZ + 1.0 or trapCoords.z + 1.0
        local spawnPos = vector3(spawnX, spawnY, spawnZ)
        
        local distanceFromPlayer = #(spawnPos - playerCoords)
        
        local hit, _, _, _, _ = GetShapeTestResult(StartShapeTestRay(spawnPos.x, spawnPos.y, spawnZ + 5.0, spawnPos.x, spawnPos.y, spawnZ - 2.0, -1, 0, 7))
        
        if distanceFromPlayer >= minDistance and hit == 0 then
            return spawnPos, true
        end
        
        attempts = attempts + 1
    end
    
    return vector3(trapCoords.x + minDistance, trapCoords.y + minDistance, trapCoords.z + 1.0), false
end

local function MakeAnimalMoveToTrap(animal, trapCoords, trapId)
    if not DoesEntityExist(animal) or IsPedHuman(animal) then return end

    -- Set animal behavior
    SetEntityAsMissionEntity(animal, true, true)
    Citizen.InvokeNative(0xE0AB82AAF3A9562E, animal, 1)
    SetBlockingOfNonTemporaryEvents(animal, true)
    Citizen.InvokeNative(0xAAB0FE202E9FC9F0, animal, GetHashKey("DEFAULT"))
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animal, 0, false)
    Citizen.InvokeNative(0xFE07FF6495D52E2A, animal, 0, 0, 0)

    -- Configure combat attributes
    SetPedFleeAttributes(animal, 0, false)
    SetPedCombatAttributes(animal, 46, true)
    SetPedCanRagdoll(animal, false)
    
    -- Disable unnecessary behaviors
    SetPedCanPlayAmbientAnims(animal, false)
    SetPedCanPlayGestureAnims(animal, false)
    SetPedCanPlayAmbientBaseAnims(animal, false)

    -- Important ped flags
    SetPedConfigFlag(animal, 6, true)
    SetPedConfigFlag(animal, 17, true)
    SetPedConfigFlag(animal, 43, true)
    SetPedConfigFlag(animal, 136, true)
    SetPedConfigFlag(animal, 146, true)
    SetPedConfigFlag(animal, 208, true)
    SetPedConfigFlag(animal, 297, true)
    SetPedConfigFlag(animal, 400, true)

    -- Set relationship
    SetPedRelationshipGroupHash(animal, GetHashKey("REL_PLAYER_LIKE"))
    Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, animal)

    -- Clear tasks
    ClearPedTasksImmediately(animal)

    -- Create movement task sequence
    local sequenceId = OpenSequenceTask(0)
    TaskGoToCoordAnyMeans(0, trapCoords.x, trapCoords.y, trapCoords.z, 1.5, 0, false, 786603, 0.1)
    TaskStandStill(0, 1000)
    CloseSequenceTask(sequenceId)
    TaskPerformSequence(animal, sequenceId)
    ClearSequenceTask(sequenceId)

    -- Stuck detection thread
    CreateThread(function()
        local stuckTimer = 0
        local lastPos = GetEntityCoords(animal)
        local checkInterval = 500
        local maxStuckTime = 6000

        while DoesEntityExist(animal) and not capturedAnimals[animal] do
            Wait(checkInterval)
            local currentPos = GetEntityCoords(animal)
            local distanceToTrap = #(currentPos - trapCoords)

            if distanceToTrap <= Config.AnimalTrapSettings.CheckRadius then
                break
            end

            local distanceMoved = #(currentPos - lastPos)
            if distanceMoved < 0.2 then
                stuckTimer = stuckTimer + checkInterval
                if stuckTimer >= maxStuckTime then
                    ClearPedTasks(animal)
                    Wait(50)
                    local offsetX = math.random(-0.3, 0.3)
                    local offsetY = math.random(-0.3, 0.3)
                    local newSeq = OpenSequenceTask(0)
                    TaskGoStraightToCoord(0, trapCoords.x + offsetX, trapCoords.y + offsetY, trapCoords.z, 1.5, -1, 0.0, 0.0)
                    CloseSequenceTask(newSeq)
                    TaskPerformSequence(animal, newSeq)
                    ClearSequenceTask(newSeq)
                    stuckTimer = 0
                end
            else
                stuckTimer = 0
            end

            lastPos = currentPos
        end
    end)

    
end

local function GetNearbyPeds(coords, radius)
    local peds = {}
    local playerPed = PlayerPedId()
    
    for player = 0, 255 do
        if NetworkIsPlayerActive(player) then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) then
                local pedCoords = GetEntityCoords(ped)
                if #(coords - pedCoords) <= radius then
                    table.insert(peds, ped)
                end
            end
        end
    end
    
    local animals = GetGamePool('CPed')
    for i = 1, #animals do
        local animal = animals[i]
        if DoesEntityExist(animal) and IsAnimalPed(animal) then
            local animalCoords = GetEntityCoords(animal)
            if #(coords - animalCoords) <= radius then
                table.insert(peds, animal)
            end
        end
    end
    
    return peds
end

RegisterNetEvent('rsg_beartraps:placeTrap')
AddEventHandler('rsg_beartraps:placeTrap', function(itemName)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local trapConfig = nil
    
    for _, trap in pairs(Config.Traps) do
        if trap.Item == itemName then
            trapConfig = trap
            break
        end
    end
    
    if not trapConfig then 
        ox_lib:notify({ type = 'error', title = 'Error', description = 'Trap configuration not found.' })
        return 
    end
    
    TaskStartScenarioInPlace(playerPed, GetHashKey(trapConfig.Animation), -1, true, false, false, false)
    Wait(trapConfig.PlacementTime)
    ClearPedTasks(playerPed)
    
    local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    local finalZ = groundFound and groundZ or coords.z - 1.0
    
    local modelToUse = trapConfig.Model
    local modelHash = trapConfig.Model

    RequestModel(modelHash)
    local attempts = 0
    while not HasModelLoaded(modelHash) and attempts < 500 do
        Wait(10)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(modelHash) then
        if trapConfig.FallbackModel then
            modelHash = trapConfig.FallbackModel
            modelToUse = trapConfig.FallbackModel
            RequestModel(modelHash)
            attempts = 0
            while not HasModelLoaded(modelHash) and attempts < 500 do
                Wait(10)
                attempts = attempts + 1
            end
            if not HasModelLoaded(modelHash) then
                ox_lib:notify({ type = 'error', title = 'Error', description = 'No valid trap model available.' })
                return
            end
        else
            ox_lib:notify({ type = 'error', title = 'Error', description = 'Invalid trap model: ' .. tostring(modelToUse) .. '. Contact server admin.' })
            return
        end
    end
    
    local forward = GetEntityForwardVector(playerPed)
    local offsetDistance = 3.0
    local x = coords.x + forward.x * offsetDistance
    local y = coords.y + forward.y * offsetDistance
    local trapObj = CreateObject(modelHash, x, y, finalZ, true, false, false)
    local timeout = 0
    while not DoesEntityExist(trapObj) and timeout < 200 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(trapObj) then
        SetModelAsNoLongerNeeded(modelHash)
        ox_lib:notify({ type = 'error', title = 'Error', description = 'Failed to create trap.' })
        return
    end
    
    PlaceObjectOnGroundProperly(trapObj)
    SetEntityHeading(trapObj, GetEntityHeading(playerPed))
    FreezeEntityPosition(trapObj, true)
    
    -- Play open animation on trap placement
    if trapConfig.TrapAnimation then
        RequestAnimDict(trapConfig.TrapAnimation.dict)
        local animTimeout = 0
        while not HasAnimDictLoaded(trapConfig.TrapAnimation.dict) and animTimeout < 1000 do
            Wait(10)
            animTimeout = animTimeout + 1
        end
        if HasAnimDictLoaded(trapConfig.TrapAnimation.dict) then
            TaskPlayAnim(trapObj, trapConfig.TrapAnimation.dict, trapConfig.TrapAnimation.open_anim, 
                        8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end
    
    local isNetworked = false
    local trapId = trapObj
    if NetworkRegisterEntityAsNetworked(trapObj) then
        timeout = 0
        while not NetworkGetEntityIsNetworked(trapObj) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
        if NetworkGetEntityIsNetworked(trapObj) then
            local networkId = NetworkGetNetworkIdFromEntity(trapObj)
            if networkId ~= 0 then
                trapId = networkId
                isNetworked = true
            end
        end
    end
    
    traps[trapId] = { 
        obj = trapObj, 
        config = trapConfig, 
        owner = GetPlayerServerId(PlayerId()),
        coords = GetEntityCoords(trapObj),
        isNetworked = isNetworked,
        captureCount = 0
    }
    
    local collectPrompt = PromptRegisterBegin()
    PromptSetControlAction(collectPrompt, 0xF3830D8E) -- [J]
    PromptSetText(collectPrompt, CreateVarString(10, 'LITERAL_STRING', Config.Prompts.Collect))
    PromptSetEnabled(collectPrompt, true)
    PromptSetVisible(collectPrompt, false)
    PromptSetStandardMode(collectPrompt, true)
    PromptRegisterEnd(collectPrompt)
    prompts[trapId .. '_collect'] = collectPrompt

    local checkPrompt = PromptRegisterBegin()
    PromptSetControlAction(checkPrompt, 0xD9D0E1C0) -- [SPACE]
    PromptSetText(checkPrompt, CreateVarString(10, 'LITERAL_STRING', Config.Prompts.Check))
    PromptSetEnabled(checkPrompt, true)
    PromptSetVisible(checkPrompt, false)
    PromptSetStandardMode(checkPrompt, true)
    PromptRegisterEnd(checkPrompt)
    prompts[trapId .. '_check'] = checkPrompt
    
    SetModelAsNoLongerNeeded(modelHash)
    
    TriggerServerEvent('rsg_beartraps:trapPlaced', trapId, trapConfig.Item, GetEntityCoords(trapObj))
    
    SetTimeout(10000, function()
        if not DoesEntityExist(trapObj) then return end
        
        local playerPed = PlayerPedId()
        if not playerPed or not DoesEntityExist(playerPed) then return end
        
        local trapCoords = GetEntityCoords(trapObj)
        local playerCoords = GetEntityCoords(playerPed)
        
        local animalsToSpawn = Config.AnimalsPerTrap or 2
        local spawnDelay = Config.SpawnDelay or 2000
        
        for i = 1, animalsToSpawn do
            SetTimeout((i - 1) * spawnDelay, function()
                if not DoesEntityExist(trapObj) then return end
                
                local animalModel = GetRandomAnimalModel()
                if not IsModelValid(animalModel) or not IsModelAPed(animalModel) then return end
                
                RequestModel(animalModel)
                local animalAttempts = 0
                while not HasModelLoaded(animalModel) and animalAttempts < 2000 do
                    Wait(10)
                    animalAttempts = animalAttempts + 1
                end
                
                if not HasModelLoaded(animalModel) then return end
                
                local minDistance = Config.MinSpawnDistance or 5.0
                local maxDistance = Config.SpawnRadius or 15.0
                local spawnPos, foundSafePos = FindSafeSpawnPosition(trapCoords, playerCoords, minDistance, maxDistance)
                
                local animal = CreatePed(animalModel, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, true)
                local animalTimeout = 0
                while not DoesEntityExist(animal) and animalTimeout < 30 do
                    Wait(100)
                    animalTimeout = animalTimeout + 1
                end
                
                if not DoesEntityExist(animal) then
                    SetModelAsNoLongerNeeded(animalModel)
                    return
                end
                
                spawnedAnimals[animal] = trapId
                Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, animal)
                Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animal, 0, false)
                SetEntityAsMissionEntity(animal, true, true)
                
                SetEntityVisible(animal, true)
                SetEntityCollision(animal, true, true)
                SetEntityCanBeDamaged(animal, true)
                
                Wait(500)
                
                if NetworkRegisterEntityAsNetworked(animal) then
                    local netTimeout = 0
                    while not NetworkGetEntityIsNetworked(animal) and netTimeout < 500 do
                        Wait(10)
                        netTimeout = netTimeout + 1
                    end
                end
                
                MakeAnimalMoveToTrap(animal, trapCoords, trapId)
                SetModelAsNoLongerNeeded(animalModel)
                
                -- Per-animal check thread
                CreateThread(function()
                    if not Config.AnimalTrapSettings then
                        print("Error: Config.AnimalTrapSettings is not defined for animal " .. tostring(animal))
                        return
                    end
                    while DoesEntityExist(animal) and not capturedAnimals[animal] and DoesEntityExist(trapObj) do
                        Wait(1000)
                        local animalCoords = GetEntityCoords(animal)
                        local distance = #(animalCoords - trapCoords)
                        if distance <= Config.AnimalTrapSettings.CheckRadius then
                            local pedModel = GetEntityModel(animal)
                            local canCapture, captureChance = false, Config.AnimalTrapSettings.CaptureChance
                            
                            for _, bait in pairs(traps[trapId].config.Baits or {}) do
                                for _, animalType in pairs(bait.animals) do
                                    if pedModel == GetHashKey(animalType) then
                                        canCapture = true
                                        captureChance = bait.chance
                                        break
                                    end
                                end
                                if canCapture then break end
                            end
                            
                            if canCapture and math.random(1, 100) <= captureChance then
                                CaptureAnimal(animal, trapId, traps[trapId])
                                break
                            end
                        end
                    end
                end)
            end)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(1000) -- Check every 1 second
        
        if not Config.AnimalTrapSettings then
            print("Error: Config.AnimalTrapSettings is not defined!")
            Wait(5000)
            return
        end
        
        -- Collect trap IDs to avoid iteration issues
        local trapIds = {}
        for id, _ in pairs(traps) do
            table.insert(trapIds, id)
        end
        
        for _, trapId in ipairs(trapIds) do
            local trap = traps[trapId]
            if not trap or not DoesEntityExist(trap.obj) then
                traps[trapId] = nil
                print("Trap with ID " .. tostring(trapId) .. " is invalid or deleted, removing from traps table.")
                goto continue
            end
            
            local trapCoords = GetEntityCoords(trap.obj)
            local nearbyPeds = GetNearbyPeds(trapCoords, Config.AnimalTrapSettings.CheckRadius)

            for _, ped in pairs(nearbyPeds) do
                if DoesEntityExist(ped) and not capturedAnimals[ped] then
                    local pedModel = GetEntityModel(ped)
                    
                    -- Animal capture logic
                    if IsAnimalPed(ped) then
                        local canCapture, captureChance = false, Config.AnimalTrapSettings.CaptureChance
                        
                        for _, bait in pairs(trap.config.Baits or {}) do
                            for _, animal in pairs(bait.animals) do
                                if pedModel == GetHashKey(animal) then
                                    canCapture = true
                                    captureChance = bait.chance
                                    break
                                end
                            end
                            if canCapture then break end
                        end
                        
                        if canCapture and math.random(1, 100) <= captureChance then
                            CaptureAnimal(ped, trapId, trap)
                        end
                    
                    -- Player capture logic
                    elseif IsPedHuman(ped) and math.random(1, 100) <= Config.PlayerTrapSettings.TrapChance then
                        capturedAnimals[ped] = true
                        
                        -- Play trap close animation
                        if trap.config and trap.config.TrapAnimation then
                            RequestAnimDict(trap.config.TrapAnimation.dict)
                            local timeout = 0
                            while not HasAnimDictLoaded(trap.config.TrapAnimation.dict) and timeout < 1000 do
                                Wait(10)
                                timeout = timeout + 1
                            end
                            if HasAnimDictLoaded(trap.config.TrapAnimation.dict) then
                                TaskPlayAnim(trap.obj, trap.config.TrapAnimation.dict, 
                                            trap.config.TrapAnimation.close_anim, 
                                            8.0, -8.0, -1, 0, 0, false, false, false)
                            else
                                print("Failed to load animation dictionary: " .. tostring(trap.config.TrapAnimation.dict))
                            end
                        else
                            print("Trap animation config missing for trap ID: " .. tostring(trapId))
                        end
                        
                        -- Apply effects
                        ApplyDamageToPed(ped, Config.PlayerTrapSettings.Damage, true)
                        Citizen.InvokeNative(0x4102732DF6B4005F, "HitReaction", ped, 1.0)
                        Citizen.InvokeNative(0x59BD177A1A48600A, ped, 1)
                        
                        -- Ragdoll player
                        RagdollPlayer(ped, Config.PlayerTrapSettings.RagdollDuration)
                        
                        -- Freeze if not auto-unfreezing
                        if not Config.PlayerTrapSettings.UnfreezeAfterRagdoll then
                            FreezeEntityPosition(ped, true)
                        end
                        
                        -- Notify server
                        local entityId = trap.isNetworked and NetworkGetNetworkIdFromEntity(ped) or ped
                        TriggerServerEvent('rsg_beartraps:humanTrapped', trapId, entityId)
                        
                        -- Release after duration
                        SetTimeout(Config.PlayerTrapSettings.TrapDuration, function()
                            if DoesEntityExist(ped) then
                                FreezeEntityPosition(ped, false)
                                if Config.PlayerTrapSettings.UnfreezeAfterRagdoll then
                                    MakePlayerLimp(ped, Config.PlayerTrapSettings.LimpDuration)
                                end
                                capturedAnimals[ped] = nil
                            end
                            -- Reset trap to open animation
                            if traps[trapId] and DoesEntityExist(trap.obj) and trap.config and trap.config.TrapAnimation then
                                RequestAnimDict(trap.config.TrapAnimation.dict)
                                local timeout = 0
                                while not HasAnimDictLoaded(trap.config.TrapAnimation.dict) and timeout < 1000 do
                                    Wait(10)
                                    timeout = timeout + 1
                                end
                                if HasAnimDictLoaded(trap.config.TrapAnimation.dict) then
                                    TaskPlayAnim(trap.obj, trap.config.TrapAnimation.dict, 
                                                trap.config.TrapAnimation.open_anim, 
                                                8.0, -8.0, -1, 1, 0, false, false, false)
                                end
                            end
                        end)
                    end
                end
            end
            ::continue::
        end
    end
end)
-- Interaction thread
CreateThread(function()
    while true do
        Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local playerServerId = GetPlayerServerId(PlayerId())
        
        for trapId, trap in pairs(traps) do
            if DoesEntityExist(trap.obj) then
                local trapCoords = GetEntityCoords(trap.obj)
                local distance = #(playerCoords - trapCoords)
                
                if distance < Config.InteractionDistance then
                    local isOwner = trap.owner == playerServerId
                    PromptSetVisible(prompts[trapId .. '_collect'], isOwner)
                    PromptSetVisible(prompts[trapId .. '_check'], true)
                    
                    if isOwner and PromptHasStandardModeCompleted(prompts[trapId .. '_collect']) then
                        ClearPedTasks(trap.obj)
                        DeleteObject(trap.obj)
                        traps[trapId] = nil
                        PromptDelete(prompts[trapId .. '_collect'])
                        PromptDelete(prompts[trapId .. '_check'])
                        prompts[trapId .. '_collect'] = nil
                        prompts[trapId .. '_check'] = nil
                        TriggerServerEvent('rsg_beartraps:removeTrap', trapId)
                    elseif PromptHasStandardModeCompleted(prompts[trapId .. '_check']) then
                        TriggerServerEvent('rsg_beartraps:checkTrap', trapId)
                    end
                else
                    if prompts[trapId .. '_collect'] then
                        PromptSetVisible(prompts[trapId .. '_collect'], false)
                    end
                    if prompts[trapId .. '_check'] then
                        PromptSetVisible(prompts[trapId .. '_check'], false)
                    end
                end
            else
                if prompts[trapId .. '_collect'] then
                    PromptDelete(prompts[trapId .. '_collect'])
                    prompts[trapId .. '_collect'] = nil
                end
                if prompts[trapId .. '_check'] then
                    PromptDelete(prompts[trapId .. '_check'])
                    prompts[trapId .. '_check'] = nil
                end
                traps[trapId] = nil
            end
        end
        
        local hasNearbyTraps = false
        for _, trap in pairs(traps) do
            if DoesEntityExist(trap.obj) then
                local distance = #(playerCoords - GetEntityCoords(trap.obj))
                if distance < Config.InteractionDistance * 2 then
                    hasNearbyTraps = true
                    break
                end
            end
        end
        
        if not hasNearbyTraps then
            Wait(500)
        end
    end
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, prompt in pairs(prompts) do
            if prompt then
                PromptDelete(prompt)
            end
        end
        for _, trap in pairs(traps) do
            if DoesEntityExist(trap.obj) then
                ClearPedTasks(trap.obj)
                DeleteObject(trap.obj)
            end
        end
        
        for animal, _ in pairs(spawnedAnimals) do
            if DoesEntityExist(animal) then
                DeleteEntity(animal)
            end
        end
        prompts = {}
        traps = {}
        capturedAnimals = {}
        spawnedAnimals = {}
    end
end)

-- Sync events
RegisterNetEvent('rsg_beartraps:syncTrap')
AddEventHandler('rsg_beartraps:syncTrap', function(trapData)
    if not traps[trapData.id] then
        local modelHash = GetHashKey(trapData.model)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end
        local trapObj = CreateObject(modelHash, trapData.coords.x, trapData.coords.y, trapData.coords.z, true, true, false)
        PlaceObjectOnGroundProperly(trapObj)
        
        -- Play open animation for synced trap
        if trapData.config.TrapAnimation then
            RequestAnimDict(trapData.config.TrapAnimation.dict)
            local timeout = 0
            while not HasAnimDictLoaded(trapData.config.TrapAnimation.dict) and timeout < 1000 do
                Wait(10)
                timeout = timeout + 1
            end
            if HasAnimDictLoaded(trapData.config.TrapAnimation.dict) then
                TaskPlayAnim(trapObj, trapData.config.TrapAnimation.dict, trapData.config.TrapAnimation.open_anim, 
                            8.0, -8.0, -1, 1, 0, false, false, false)
            end
        end
        
        SetModelAsNoLongerNeeded(modelHash)
        traps[trapData.id] = {
            obj = trapObj,
            config = trapData.config,
            owner = trapData.owner,
            coords = trapData.coords,
            isNetworked = true,
            captureCount = trapData.captureCount or 0
        }
    end
end)

RegisterNetEvent('rsg_beartraps:removeTrapSync')
AddEventHandler('rsg_beartraps:removeTrapSync', function(trapId)
    if traps[trapId] then
        if DoesEntityExist(traps[trapId].obj) then
            ClearPedTasks(traps[trapId].obj)
            DeleteObject(traps[trapId].obj)
        end
        if prompts[trapId .. '_collect'] then
            PromptDelete(prompts[trapId .. '_collect'])
            prompts[trapId .. '_collect'] = nil
        end
        if prompts[trapId .. '_check'] then
            PromptDelete(prompts[trapId .. '_check'])
            prompts[trapId .. '_check'] = nil
        end
       
        for animal, associatedTrapId in pairs(spawnedAnimals) do
            if associatedTrapId == trapId and DoesEntityExist(animal) then
                DeleteEntity(animal)
                spawnedAnimals[animal] = nil
            end
        end
        traps[trapId] = nil
    end
end)

RegisterNetEvent('rsg_beartraps:clearAllTraps')
AddEventHandler('rsg_beartraps:clearAllTraps', function()
    for _, prompt in pairs(prompts) do
        if prompt then
            PromptDelete(prompt)
        end
    end
    for _, trap in pairs(traps) do
        if DoesEntityExist(trap.obj) then
            ClearPedTasks(trap.obj)
            DeleteObject(trap.obj)
        end
    end
    for animal, _ in pairs(spawnedAnimals) do
        if DoesEntityExist(animal) then
            DeleteEntity(animal)
        end
    end
    prompts = {}
    traps = {}
    capturedAnimals = {}
    spawnedAnimals = {}
end)
