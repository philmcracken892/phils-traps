local RSGCore = exports['rsg-core']:GetCoreObject()
local activeTrap = {} 


RSGCore.Functions.CreateUseableItem('beartrap', function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    
    if Config.RequireJob then
        local job = Player.PlayerData.job.name
        local allowed = false
        for _, allowedJob in pairs(Config.AllowedJobs) do
            if job == allowedJob then
                allowed = true
                break
            end
        end
        if not allowed then
            TriggerClientEvent('ox_lib:notify', src, { 
                type = 'error', 
                title = 'Error', 
                description = 'You don\'t have the required job to use this trap.' 
            })
            return
        end
    end
    
   
    local playerTrapCount = 0
    for _, trapData in pairs(activeTrap) do
        if trapData.owner == src then
            playerTrapCount = playerTrapCount + 1
        end
    end
    if playerTrapCount >= Config.MaxTrapsPerPlayer then
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'error', 
            title = 'Error', 
            description = 'You have reached the maximum number of active traps.' 
        })
        return
    end

    
    Player.Functions.RemoveItem(item.name, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item.name], "remove")

    
    TriggerClientEvent('rsg_beartraps:placeTrap', src, item.name)
end)


RegisterNetEvent('rsg_beartraps:trapPlaced')
AddEventHandler('rsg_beartraps:trapPlaced', function(trapId, trapItem, coords)
    local src = source
    activeTrap[trapId] = {
        captures = 0,
        owner = src,
        item = trapItem,
        coords = coords
    }
    if Config.Debug then
        print("Trap registered with ID: " .. trapId)
    end
end)


RegisterNetEvent('rsg_beartraps:animalCaptured')
AddEventHandler('rsg_beartraps:animalCaptured', function(trapId, animalModel, entityId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    -- Validate trap existence
    if not activeTrap[trapId] then
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'error', 
            title = 'Error', 
            description = 'Invalid trap ID.' 
        })
        return
    end

    -- Notify player that the animal is bleeding out
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'warning', 
        title = 'Animal Trapped', 
        description = 'An animal is caught in your trap and is bleeding out!' 
    })

    -- Simulate bleeding out with a delay before confirming the capture
    Citizen.Wait(5000) -- 5-second delay to simulate bleeding out (adjust as needed)

    -- Notify player of successful capture (animal has "died")
    TriggerClientEvent('ox_lib:notify', src, { 
        type = 'success', 
        title = 'Trap Success', 
        description = 'You caught an animal! It has died.' 
    })

    -- Increment capture count
    activeTrap[trapId].captures = activeTrap[trapId].captures + 1

    -- Check if trap should break (after max captures)
    local maxCaptures = Config.MaxCaptures or 3 -- Use Config or default to 3
    if activeTrap[trapId].captures >= maxCaptures then
        TriggerClientEvent('rsg_beartraps:removeTrapSync', -1, trapId)
        activeTrap[trapId] = nil
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'info', 
            title = 'Trap Broken', 
            description = 'Your trap broke after multiple uses.' 
        })
    end
end)



RegisterNetEvent('rsg_beartraps:humanTrapped')
AddEventHandler('rsg_beartraps:humanTrapped', function(trapId, entityId)
    local src = source
    
    -- The player who stepped on the trap is the one triggering this event
    local victimSrc = src
    
    -- Notify the victim
    TriggerClientEvent('ox_lib:notify', victimSrc, { 
        type = 'error', 
        title = 'Trapped!', 
        description = 'You stepped on a bear trap!' 
    })
    
    -- Find the trap owner and notify them
    local trapData = activeTrap[trapId]
    if trapData and trapData.owner then
        local trapOwner = trapData.owner
        
        if trapOwner ~= victimSrc then
            -- Different player stepped on the trap
            TriggerClientEvent('ox_lib:notify', trapOwner, { 
                type = 'info', 
                title = 'Trap Triggered', 
                description = 'Someone stepped on your trap!' 
            })
        else
            -- Owner stepped on their own trap
            TriggerClientEvent('ox_lib:notify', trapOwner, { 
                type = 'warning', 
                title = 'Own Trap!', 
                description = 'You stepped on your own trap!' 
            })
        end
    end
end)


RegisterNetEvent('rsg_beartraps:checkTrap')
AddEventHandler('rsg_beartraps:checkTrap', function(trapId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local trapData = activeTrap[trapId]
    if trapData then
        local captureCount = trapData.captures or 0
        local condition = "Good"
        
        if captureCount >= 2 then
            condition = "Worn"
        elseif captureCount >= 1 then
            condition = "Used"
        end
        
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'info', 
            title = 'Trap Status', 
            description = 'Condition: ' .. condition .. ' | Captures: ' .. captureCount 
        })
    else
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'info', 
            title = 'Trap Status', 
            description = 'Trap is set and ready.' 
        })
    end
end)


RegisterNetEvent('rsg_beartraps:removeTrap')
AddEventHandler('rsg_beartraps:removeTrap', function(trapId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
   
    local trapData = activeTrap[trapId]
    local breakChance = 0
    
    if trapData and trapData.captures then
        breakChance = trapData.captures * 15 -- 15% chance per capture
    end
    
    if math.random(1, 100) <= breakChance then
        
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'error', 
            title = 'Trap Broken', 
            description = 'The trap broke when you tried to pick it up!' 
        })
        
        if RSGCore.Shared.Items['iron_ore'] then
            Player.Functions.AddItem('iron_ore', 1)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['iron_ore'], "add", 1)
        end
    else
       
        Player.Functions.AddItem('beartrap', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['beartrap'], "add", 1)
        TriggerClientEvent('ox_lib:notify', src, { 
            type = 'success', 
            title = 'Trap Retrieved', 
            description = 'You picked up the bear trap.' 
        })
    end
    
    
    activeTrap[trapId] = nil
    
  
    TriggerClientEvent('rsg_beartraps:removeTrapSync', -1, trapId)
end)



AddEventHandler('playerDropped', function(reason)
    local src = source
    for trapId, trapData in pairs(activeTrap) do
        if trapData.owner == src then
            activeTrap[trapId] = nil
            TriggerClientEvent('rsg_beartraps:removeTrapSync', -1, trapId)
        end
    end
end)
