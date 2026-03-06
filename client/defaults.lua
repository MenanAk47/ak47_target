-- ak47_target/client/defaults.lua
local bones = { [0] = 'dside_f', [1] = 'pside_f', [2] = 'dside_r', [3] = 'pside_r' }

local function toggleDoor(vehicle, door)
    if GetVehicleDoorLockStatus(vehicle) ~= 2 then
        if GetVehicleDoorAngleRatio(vehicle, door) > 0.0 then
            SetVehicleDoorShut(vehicle, door, false)
        else
            SetVehicleDoorOpen(vehicle, door, false, false)
        end
    end
end

local function canInteractWithDoor(entity, coords, door, useOffset)
    if not GetIsDoorValid(entity, door) or GetVehicleDoorLockStatus(entity) > 1 or IsVehicleDoorDamaged(entity, door) then return false end
    if useOffset then return true end

    local boneName = bones[door]
    if not boneName then return false end

    local boneId = GetEntityBoneIndexByName(entity, 'door_' .. boneName)
    if boneId ~= -1 then
        return #(coords - GetEntityBonePosition_2(entity, boneId)) < 0.5 or
            #(coords - GetEntityBonePosition_2(entity, GetEntityBoneIndexByName(entity, 'seat_' .. boneName))) < 0.72
    end
    return false
end

local function onSelectDoor(data, door)
    local entity = data.entity or data
    if NetworkGetEntityOwner(entity) == PlayerId() then
        toggleDoor(entity, door)
    else
        TriggerServerEvent('ak47_target:server:toggleDoor', NetworkGetNetworkIdFromEntity(entity), door)
    end
end

RegisterNetEvent('ak47_target:client:toggleEntityDoor', function(netId, door)
    local entity = NetToVeh(netId)
    toggleDoor(entity, door)
end)

CreateThread(function()
    exports['ak47_target']:addGlobalVehicle({
        {
            name = 'ak47_target:driverF', icon = 'fas fa-car-side', label = 'Toggle Driver Door',
            bones = { 'door_dside_f', 'seat_dside_f' }, distance = 2.0,
            canInteract = function(entity, distance, coords) return canInteractWithDoor(entity, coords, 0) end,
            onSelect = function(data) onSelectDoor(data, 0) end
        },
        {
            name = 'ak47_target:passengerF', icon = 'fas fa-car-side', label = 'Toggle Passenger Door',
            bones = { 'door_pside_f', 'seat_pside_f' }, distance = 2.0,
            canInteract = function(entity, distance, coords) return canInteractWithDoor(entity, coords, 1) end,
            onSelect = function(data) onSelectDoor(data, 1) end
        },
        {
            name = 'ak47_target:bonnet', icon = 'fas fa-car', label = 'Toggle Hood',
            offset = vector3(0.5, 1.0, 0.5), distance = 2.0,
            canInteract = function(entity, distance, coords) return canInteractWithDoor(entity, coords, 4, true) end,
            onSelect = function(data) onSelectDoor(data, 4) end
        },
        {
            name = 'ak47_target:trunk', icon = 'fas fa-truck-pickup', label = 'Toggle Trunk',
            offset = vector3(0.5, 0.0, 0.5), distance = 2.0,
            canInteract = function(entity, distance, coords) return canInteractWithDoor(entity, coords, 5, true) end,
            onSelect = function(data) onSelectDoor(data, 5) end
        }
    })
end)

