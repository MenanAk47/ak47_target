-- =================================================================
-- 1. INITIALIZATION & DATA STRUCTURE
-- =================================================================

TargetAPI = {
    Peds = {},
    Vehicles = {},
    Objects = {},
    Players = {},
    Models = {},
    Entities = {},
    LocalEntities = {},
    Globals = {},
    Zones = {}
}

local isDisabled = false

-- =================================================================
-- 2. INTERNAL HELPER FUNCTIONS
-- =================================================================

---@param tbl table The target table to add to
---@param options table|table[] The option or list of options to add
local function AddTargetToTable(tbl, options)
    if type(options) ~= 'table' then return end
    if options.label or options.name then options = {options} end
    
    -- Tracks which resource added the option for cleanup on stop
    local resource = GetInvokingResource() or "ak47_target"

    for _, opt in ipairs(options) do
        opt.resource = resource
        table.insert(tbl, opt)
    end
end

---@param tbl table The target table to remove from
---@param labels string|string[] The name or label of the option(s) to remove
local function RemoveTargetFromTable(tbl, labels)
    if type(labels) ~= 'table' then labels = {labels} end
    for i = #tbl, 1, -1 do
        for _, label in ipairs(labels) do
            if tbl[i].name == label or tbl[i].label == label then
                table.remove(tbl, i)
            end
        end
    end
end

local function ExportHandler(exportName, func)
    AddEventHandler(('__cfx_export_ox_target_%s'):format(exportName), function(setCB) setCB(func) end)
end

-- =================================================================
-- 3. TARGET ADDITION EXPORTS (GLOBALS)
-- =================================================================

local function addGlobalPed(options) AddTargetToTable(TargetAPI.Peds, options) end
exports('addGlobalPed', addGlobalPed)
ExportHandler('addGlobalPed', addGlobalPed)

local function addGlobalVehicle(options) AddTargetToTable(TargetAPI.Vehicles, options) end
exports('addGlobalVehicle', addGlobalVehicle)
ExportHandler('addGlobalVehicle', addGlobalVehicle)

local function addGlobalObject(options) AddTargetToTable(TargetAPI.Objects, options) end
exports('addGlobalObject', addGlobalObject)
ExportHandler('addGlobalObject', addGlobalObject)

local function addGlobalPlayer(options) AddTargetToTable(TargetAPI.Players, options) end
exports('addGlobalPlayer', addGlobalPlayer)
ExportHandler('addGlobalPlayer', addGlobalPlayer)

local function addGlobalOption(options) AddTargetToTable(TargetAPI.Globals, options) end
exports('addGlobalOption', addGlobalOption)
ExportHandler('addGlobalOption', addGlobalOption)

-- =================================================================
-- 4. TARGET ADDITION EXPORTS (SPECIFICS)
-- =================================================================

local function addModel(models, options)
    if type(models) ~= 'table' then models = {models} end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        if not TargetAPI.Models[hash] then TargetAPI.Models[hash] = {} end
        AddTargetToTable(TargetAPI.Models[hash], options)
    end
end
exports('addModel', addModel)
ExportHandler('addModel', addModel)

local function addEntity(netIds, options)
    if type(netIds) ~= 'table' then netIds = {netIds} end
    for _, netId in ipairs(netIds) do
        if NetworkDoesNetworkIdExist(netId) then
            if not TargetAPI.Entities[netId] then 
                TargetAPI.Entities[netId] = {} 
                
                local entity = NetworkGetEntityFromNetworkId(netId)
                if entity > 0 and not Entity(entity).state.hasTargetOptions then
                    TriggerServerEvent('ak47_target:server:setEntityHasOptions', netId)
                end
            end
            AddTargetToTable(TargetAPI.Entities[netId], options)
        end
    end
end
exports('addEntity', addEntity)
ExportHandler('addEntity', addEntity)

local function addLocalEntity(entityIds, options)
    if type(entityIds) ~= 'table' then entityIds = {entityIds} end
    for _, ent in ipairs(entityIds) do
        if not TargetAPI.LocalEntities[ent] then TargetAPI.LocalEntities[ent] = {} end
        AddTargetToTable(TargetAPI.LocalEntities[ent], options)
    end
end
exports('addLocalEntity', addLocalEntity)
ExportHandler('addLocalEntity', addLocalEntity)

-- =================================================================
-- 5. TARGET REMOVAL EXPORTS
-- =================================================================

local function removeGlobalPed(labels) RemoveTargetFromTable(TargetAPI.Peds, labels) end
exports('removeGlobalPed', removeGlobalPed)
ExportHandler('removeGlobalPed', removeGlobalPed)

local function removeGlobalVehicle(labels) RemoveTargetFromTable(TargetAPI.Vehicles, labels) end
exports('removeGlobalVehicle', removeGlobalVehicle)
ExportHandler('removeGlobalVehicle', removeGlobalVehicle)

local function removeGlobalObject(labels) RemoveTargetFromTable(TargetAPI.Objects, labels) end
exports('removeGlobalObject', removeGlobalObject)
ExportHandler('removeGlobalObject', removeGlobalObject)

local function removeGlobalPlayer(labels) RemoveTargetFromTable(TargetAPI.Players, labels) end
exports('removeGlobalPlayer', removeGlobalPlayer)
ExportHandler('removeGlobalPlayer', removeGlobalPlayer)

local function removeGlobalOption(labels) RemoveTargetFromTable(TargetAPI.Globals, labels) end
exports('removeGlobalOption', removeGlobalOption)
ExportHandler('removeGlobalOption', removeGlobalOption)

local function removeModel(models, labels)
    if type(models) ~= 'table' then models = {models} end
    for _, model in ipairs(models) do
        local hash = type(model) == 'string' and joaat(model) or model
        if TargetAPI.Models[hash] then
            RemoveTargetFromTable(TargetAPI.Models[hash], labels)
        end
    end
end
exports('removeModel', removeModel)
ExportHandler('removeModel', removeModel)

local function removeEntity(netIds, labels)
    if type(netIds) ~= 'table' then netIds = {netIds} end
    for _, netId in ipairs(netIds) do
        if TargetAPI.Entities[netId] then
            RemoveTargetFromTable(TargetAPI.Entities[netId], labels)
            if #TargetAPI.Entities[netId] == 0 then
                TargetAPI.Entities[netId] = nil
            end
        end
    end
end
exports('removeEntity', removeEntity)
ExportHandler('removeEntity', removeEntity)
RegisterNetEvent('ak47_target:client:removeEntity', removeEntity)

local function removeLocalEntity(entityIds, labels)
    if type(entityIds) ~= 'table' then entityIds = {entityIds} end
    for _, ent in ipairs(entityIds) do
        if TargetAPI.LocalEntities[ent] then
            RemoveTargetFromTable(TargetAPI.LocalEntities[ent], labels)
            if #TargetAPI.LocalEntities[ent] == 0 then
                TargetAPI.LocalEntities[ent] = nil
            end
        end
    end
end
exports('removeLocalEntity', removeLocalEntity)
ExportHandler('removeLocalEntity', removeLocalEntity)

-- =================================================================
-- 6. UTILITY & STATE EXPORTS
-- =================================================================

local function disableTargeting(value)
    isDisabled = value
    if value then
        SendNUIMessage({ type = "eye", state = false })
        SendNUIMessage({ type = "close" })
    end
end
exports('disableTargeting', disableTargeting)
ExportHandler('disableTargeting', disableTargeting)

local function isTargetDisabled()
    return isDisabled
end
exports('isDisabled', isTargetDisabled)
ExportHandler('isDisabled', isTargetDisabled)

local function zoneExists(id)
    return TargetAPI.Zones[id] ~= nil
end
exports('zoneExists', zoneExists)
ExportHandler('zoneExists', zoneExists)

local function getTargetOptions(entity, _type, model)
    return {
        global = TargetAPI.Globals,
        model = model and TargetAPI.Models[model] or nil,
        entity = entity and TargetAPI.LocalEntities[entity] or nil,
    }
end
exports('getTargetOptions', getTargetOptions)
ExportHandler('getTargetOptions', getTargetOptions)


-- =================================================================
-- 7. ZONE EXPORTS
-- =================================================================

local function addSphereZone(data)
    if not data.options then data.options = {data} end 
    return createZone('sphere', data.coords, data.options, { radius = data.radius, debug = data.debug })
end
exports('addSphereZone', addSphereZone)
ExportHandler('addSphereZone', addSphereZone)

local function addBoxZone(data)
    return createZone('box', data.coords, data.options, { size = data.size, rotation = data.rotation or 0.0, debug = data.debug })
end
exports('addBoxZone', addBoxZone)
ExportHandler('addBoxZone', addBoxZone)

local function addPolyZone(data)
    return createZone('poly', nil, data.options, { points = data.points, thickness = data.thickness, minZ = data.minZ, maxZ = data.maxZ, debug = data.debug })
end
exports('addPolyZone', addPolyZone)
ExportHandler('addPolyZone', addPolyZone)

local function removeZone(id)
    if TargetAPI.Zones[id] then 
        TargetAPI.Zones[id] = nil 
    end
end
exports('removeZone', removeZone)
ExportHandler('removeZone', removeZone)