local RSGCore = exports['rsg-core']:GetCoreObject()
local ox_lib = exports.ox_lib
local traps = {}
local prompts = {}
local capturedAnimals = {}
local spawnedAnimals = {} 


local function IsAnimalPed(ped)
    local model = GetEntityModel(ped)
    local knownAnimals = {
        `a_c_wolf_01`,
        `a_c_elk_01`,
        `a_c_coyote_01`,
        `a_c_bear_01`,
        `a_c_fox_01`,
        `a_c_rabbit_01`,
        `a_c_cougar_01`,
        `a_c_boar_01`,        
        `a_c_raccoon_01`,     
        `a_c_pronghorn_01`    
    }
    for _, animalHash in ipairs(knownAnimals) do
        if model == animalHash then
            return true
        end
    end
    return false
end


local function GetRandomAnimalModel()
    local knownAnimals = {
        `a_c_wolf_01`,
        `a_c_elk_01`,
        `a_c_coyote_01`,
        `a_c_bear_01`,
        `a_c_fox_01`,
        `a_c_rabbit_01`,
        `a_c_cougar_01`,
        `a_c_boar_01`,
        `a_c_raccoon_01`,
        `a_c_pronghorn_01`
    }
    return knownAnimals[math.random(1, #knownAnimals)]
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

    
    local trapModel = `s_beartrapanimated01x`
    local nearestTrap = nil
    local shortestDistance = 55.0 
    local animalCoords = GetEntityCoords(animal)

    local handle, entity = FindFirstObject()
    local success
    repeat
        if DoesEntityExist(entity) and GetEntityModel(entity) == trapModel then
            local entCoords = GetEntityCoords(entity)
            local dist = #(entCoords - animalCoords)
            if dist < shortestDistance then
                nearestTrap = entCoords
                shortestDistance = dist
            end
        end
        success, entity = FindNextObject(handle)
    until not success
    EndFindObject(handle)

    
    if nearestTrap then
        trapCoords = nearestTrap
        if Config.Debug then
            
        end
    else
        if Config.Debug then
            
        end
    end

   
    SetEntityAsMissionEntity(animal, true, true)
    Citizen.InvokeNative(0xE0AB82AAF3A9562E, animal, 1)
    SetBlockingOfNonTemporaryEvents(animal, true)
    Citizen.InvokeNative(0xAAB0FE202E9FC9F0, animal, GetHashKey("DEFAULT"))
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animal, 0, false)
    Citizen.InvokeNative(0xFE07FF6495D52E2A, animal, 0, 0, 0)

    
    SetPedFleeAttributes(animal, 0, false)
    SetPedCombatAttributes(animal, 46, true)
    SetPedCanRagdoll(animal, false)
    SetPedCanPlayAmbientAnims(animal, false)
    SetPedCanPlayGestureAnims(animal, false)
    SetPedCanPlayAmbientBaseAnims(animal, false)

    SetPedConfigFlag(animal, 6, true)
    SetPedConfigFlag(animal, 17, true)
    SetPedConfigFlag(animal, 43, true)
    SetPedConfigFlag(animal, 136, true)
    SetPedConfigFlag(animal, 146, true)
    SetPedConfigFlag(animal, 208, true)
    SetPedConfigFlag(animal, 297, true)
    SetPedConfigFlag(animal, 400, true)

    SetPedRelationshipGroupHash(animal, GetHashKey("REL_PLAYER_LIKE"))
    Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, animal)

    ClearPedTasksImmediately(animal)

    local sequenceId = OpenSequenceTask(0)
    TaskGoToCoordAnyMeans(0, trapCoords.x, trapCoords.y, trapCoords.z, 1.5, 0, false, 786603, 0.1)
    TaskStandStill(0, 1000)
    CloseSequenceTask(sequenceId)
    TaskPerformSequence(animal, sequenceId)
    ClearSequenceTask(sequenceId)

    
    CreateThread(function()
        local stuckTimer = 0
        local lastPos = GetEntityCoords(animal)
        local checkInterval = 500
        local maxStuckTime = 6000

        while DoesEntityExist(animal) and not capturedAnimals[animal] do
            Wait(checkInterval)
            local currentPos = GetEntityCoords(animal)
            local distanceToTrap = #(currentPos - trapCoords)

            if distanceToTrap <= Config.CheckRadius then
                if Config.Debug then
                    
                end
                break
            end

            local distanceMoved = #(currentPos - lastPos)
            if distanceMoved < 0.2 then
                stuckTimer = stuckTimer + checkInterval
                if stuckTimer >= maxStuckTime then
                    if Config.Debug then
                       
                    end
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

    
    SetTimeout(60000, function()
        if DoesEntityExist(animal) and not capturedAnimals[animal] then
            if Config.Debug then
                
            end
            spawnedAnimals[animal] = nil
            DeleteEntity(animal)
        end
    end)
end




local function GetNearbyPeds(coords, radius)
    local peds = {}
    local playerPed = PlayerPedId()
    
    for player = 0, 255 do
        if NetworkIsPlayerActive(player) then
            local ped = GetPlayerPed(player)
            if DoesEntityExist(ped) and ped ~= playerPed then -- Exclude the player's ped
                local pedCoords = GetEntityCoords(ped)
                if #(coords - pedCoords) <= radius then
                    table.insert(peds, ped)
                    if Config.Debug then
                        
                    end
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
                if Config.Debug then
                   
                end
            end
        end
    end
    
    if Config.Debug then
        
    end
    return peds
end

local function SpawnAnimalNearTrap(trapCoords, playerCoords)
    local model = GetRandomAnimalModel()
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    local spawnCoords, success = FindSafeSpawnPosition(trapCoords, playerCoords, 60.0, 40.0)
    local animal = CreatePed(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, math.random(0, 360), true, false, false, false)

    if DoesEntityExist(animal) then
        spawnedAnimals[animal] = true
        MakeAnimalMoveToTrap(animal, trapCoords)
    end

    SetModelAsNoLongerNeeded(model)
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
       
        exports.ox_lib:notify({ type = 'error', title = 'Error', description = 'Trap configuration not found.' })
        return 
    end
    
    TaskStartScenarioInPlace(playerPed, GetHashKey(trapConfig.Animation), -1, true, false, false, false)
    Wait(trapConfig.PlacementTime)
    ClearPedTasks(playerPed)
    
    local groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    local finalZ = groundFound and groundZ or coords.z - 1.0
    
    local modelToUse = trapConfig.Model
    local modelHash = trapConfig.Model
    if Config.Debug then
        
    end

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
            if Config.Debug then
                
            end
            RequestModel(modelHash)
            attempts = 0
            while not HasModelLoaded(modelHash) and attempts < 500 do
                Wait(10)
                attempts = attempts + 1
            end
            if not HasModelLoaded(modelHash) then
                exports.ox_lib:notify({ type = 'error', title = 'Error', description = 'No valid trap model available.' })
                return
            end
        else
            exports.ox_lib:notify({ type = 'error', title = 'Error', description = 'Invalid trap model: ' .. tostring(modelToUse) .. '. Contact server admin.' })
            return
        end
    end
    
    local forward = GetEntityForwardVector(playerPed)
    local offsetDistance = 3.0 -- Place trap 3 units away to prevent player getting stuck
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
        exports.ox_lib:notify({ type = 'error', title = 'Error', description = 'Failed to create trap.' })
        return
    end
    
    PlaceObjectOnGroundProperly(trapObj)
    SetEntityHeading(trapObj, GetEntityHeading(playerPed))
    FreezeEntityPosition(trapObj, true)
    
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
                if Config.Debug then
                    print("Trap networked successfully, trapId: " .. trapId)
                end
            end
        end
    end
    
    traps[trapId] = { 
        obj = trapObj, 
        config = trapConfig, 
        owner = GetPlayerServerId(PlayerId()),
        coords = GetEntityCoords(trapObj),
        isNetworked = isNetworked
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
    if Config.Debug then
        
    end
    
    TriggerServerEvent('rsg_beartraps:trapPlaced', trapId, trapConfig.Item, GetEntityCoords(trapObj))
    
    
    SetTimeout(10000, function()
        if not DoesEntityExist(trapObj) then
            if Config.Debug then
               
            end
            return
        end
        
        local playerPed = PlayerPedId()
        if not playerPed or not DoesEntityExist(playerPed) then
            if Config.Debug then
               
            end
            return
        end
        
        local trapCoords = GetEntityCoords(trapObj)
        local playerCoords = GetEntityCoords(playerPed)
        
        
        local animalsToSpawn = Config.AnimalsPerTrap or 2
        local spawnDelay = Config.SpawnDelay or 2000
        
        for i = 1, animalsToSpawn do
            SetTimeout((i - 1) * spawnDelay, function()
                if not DoesEntityExist(trapObj) then
                    return
                end
                
                local animalModel = GetRandomAnimalModel()
                if not IsModelValid(animalModel) or not IsModelAPed(animalModel) then
                    if Config.Debug then
                        
                    end
                    return
                end
                
                RequestModel(animalModel)
                local animalAttempts = 0
                while not HasModelLoaded(animalModel) and animalAttempts < 2000 do
                    Wait(10)
                    animalAttempts = animalAttempts + 1
                end
                
                if not HasModelLoaded(animalModel) then
                    if Config.Debug then
                       
                    end
                    return
                end
                
                
                local minDistance = Config.MinSpawnDistance or 5.0 -- Reduced from 8.0
                local maxDistance = Config.SpawnRadius or 15.0 -- Reduced from 25.0
                local spawnPos, foundSafePos = FindSafeSpawnPosition(trapCoords, playerCoords, minDistance, maxDistance)
                
                if Config.Debug then
                    
                end
                
                
                local animal = CreatePed(animalModel, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, true)
                local animalTimeout = 0
                while not DoesEntityExist(animal) and animalTimeout < 30 do
                    Wait(100)
                    animalTimeout = animalTimeout + 1
                end
                
                if not DoesEntityExist(animal) then
                    SetModelAsNoLongerNeeded(animalModel)
                    if Config.Debug then
                       
                    end
                    return
                end
                
                
                spawnedAnimals[animal] = trapId
                
                
                Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, animal) -- Set relationship group
                Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animal, 0, false)     -- Set flee attributes
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
                    if NetworkGetEntityIsNetworked(animal) then
                        local netId = NetworkGetNetworkIdFromEntity(animal)
                        if Config.Debug then
                            
                        end
                    end
                end
                
                
                MakeAnimalMoveToTrap(animal, trapCoords, trapId)
                SetModelAsNoLongerNeeded(animalModel)
                
                if Config.Debug then
                    local distanceFromPlayer = #(spawnPos - playerCoords)
                   
                end
            end)
        end
    end)
end)

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

CreateThread(function()
    while true do
        Wait(2000)
        for trapId, trap in pairs(traps) do
            if DoesEntityExist(trap.obj) then
                local trapCoords = GetEntityCoords(trap.obj)
                local nearbyPeds = GetNearbyPeds(trapCoords, Config.CheckRadius)

                for _, ped in pairs(nearbyPeds) do
                    if DoesEntityExist(ped) and not capturedAnimals[ped] then
                        local pedModel = GetEntityModel(ped)
                        if IsAnimalPed(ped) then
                            local canCapture, captureChance = false, 0
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
                                capturedAnimals[ped] = true
                                spawnedAnimals[ped] = nil 
                                FreezeEntityPosition(ped, true)
                                local entityId = trap.isNetworked and NetworkGetNetworkIdFromEntity(ped) or ped
                                TriggerServerEvent('rsg_beartraps:animalCaptured', trapId, pedModel, entityId)
                                SetTimeout(trap.config.CaptureDuration * 1000, function()
                                    if DoesEntityExist(ped) then
                                        SetEntityHealth(ped, 0)
                                        Wait(1000)
                                        FreezeEntityPosition(ped, false)
                                        capturedAnimals[ped] = nil
                                    end
                                end)
                            end
                        elseif IsPedHuman(ped) then
                            capturedAnimals[ped] = true
                            ApplyDamageToPed(ped, trap.config.Damage or 10, true)
                            FreezeEntityPosition(ped, true)
                            local entityId = trap.isNetworked and NetworkGetNetworkIdFromEntity(ped) or ped
                            TriggerServerEvent('rsg_beartraps:humanTrapped', trapId, entityId)
                            SetTimeout(trap.config.CaptureDuration * 1000, function()
                                if DoesEntityExist(ped) then
                                    SetEntityHealth(ped, 0)
                                    Wait(1000)
                                    FreezeEntityPosition(ped, false)
                                    capturedAnimals[ped] = nil
                                end
                            end)
                        end
                    end
                end
            else
                traps[trapId] = nil
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, prompt in pairs(prompts) do
            if prompt then
                PromptDelete(prompt)
            end
        end
        for _, trap in pairs(traps) do
            if DoesEntityExist(trap.obj) then
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
        SetModelAsNoLongerNeeded(modelHash)
        traps[trapData.id] = {
            obj = trapObj,
            config = trapData.config,
            owner = trapData.owner,
            coords = trapData.coords
        }
    end
end)

RegisterNetEvent('rsg_beartraps:removeTrapSync')
AddEventHandler('rsg_beartraps:removeTrapSync', function(trapId)
    if traps[trapId] then
        if DoesEntityExist(traps[trapId].obj) then
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
            DeleteObject(trap.obj)
        end
    end
    -- Clean up all spawned animals
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