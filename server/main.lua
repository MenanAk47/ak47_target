local entityStates = {}

RegisterNetEvent('ak47_target:server:setEntityHasOptions', function(netId)
    local entity = Entity(NetworkGetEntityFromNetworkId(netId))
    if entity then
        entity.state.hasTargetOptions = true
        entityStates[netId] = entity
    end
end)

RegisterNetEvent('ak47_target:server:toggleDoor', function(netId, door)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local owner = NetworkGetEntityOwner(entity)
    TriggerClientEvent('ak47_target:client:toggleEntityDoor', owner, netId, door)
end)

CreateThread(function()
    while true do
        Wait(10000)
        local toRemove = {}
        for netId, entity in pairs(entityStates) do
            if not DoesEntityExist(entity.__data) or not entity.state.hasTargetOptions then
                entityStates[netId] = nil
                table.insert(toRemove, netId)
            end
        end
        if #toRemove > 0 then
            TriggerClientEvent('ak47_target:client:removeEntity', -1, toRemove)
        end
    end
end)
