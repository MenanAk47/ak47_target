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
    Zones = {},
    Grid = {},
}

local isDisabled = false

-- =================================================================
-- 2. INTERNAL HELPER FUNCTIONS
-- =================================================================

local function typeError(variable, expected, received)
    error(("^1[ak47_target] Expected %s to have type '%s' (received %s)^0"):format(variable, expected, received))
end

---Checks options and throws an error or corrects type mismatch
---@param options table
---@return table
local function checkOptions(options)
    local optionsType = type(options)
    if optionsType ~= 'table' then
        typeError('options', 'table', optionsType)
    end

    if options.label or options.name or options.icon or options.onSelect or options.action then
        options = { options }
    end

    return options
end

---@param tbl table The target table to add to
---@param options table|table[] The option or list of options to add
local function AddTargetToTable(tbl, options)
    options = checkOptions(options)
    local resource = GetInvokingResource() or "ak47_target"

    for _, opt in ipairs(options) do
        opt.distance = opt.distance or 7.0
        opt.label = opt.label or "Interact"
        opt.icon = opt.icon or "fas fa-hand-pointer"
        opt.name = opt.name or (tostring(opt.label):gsub("%s+", "_"):lower() .. "_" .. math.random(10000, 99999))
        opt.resource = opt.resource or resource

        table.insert(tbl, opt)
    end
end

---@param tbl table The target table to remove from
---@param labels string|string[] The name or label of the option(s) to remove
local function RemoveTargetFromTable(tbl, labels)
    if labels == nil then
        for i = #tbl, 1, -1 do
            table.remove(tbl, i)
        end
        return
    end

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
    if not models or not options then return print("^1[ak47_target] Error: addModel is missing models or options.^0") end
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
    if not netIds or not options then return print("^1[ak47_target] Error: addEntity is missing netIds or options.^0") end
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
    if not entityIds or not options then return print("^1[ak47_target] Error: addLocalEntity is missing entityIds or options.^0") end
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
    if type(data) ~= 'table' then return print("^1[ak47_target] Error: addSphereZone requires a data table.^0") end
    if type(data.coords) ~= 'vector3' then 
        data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    
    data.radius = data.radius or 2.0
    
    if not data.options then 
        local opt = {}
        for k, v in pairs(data) do
            if k ~= 'coords' and k ~= 'radius' and k ~= 'debug' and k ~= 'name' and k ~= 'drawSprite' then 
                opt[k] = v 
            end
        end
        data.options = {opt} 
    end 
    
    return createZone('sphere', data.coords, data.options, { radius = data.radius, debug = data.debug, resource = data.resource, drawSprite = data.drawSprite })
end
exports('addSphereZone', addSphereZone)
ExportHandler('addSphereZone', addSphereZone)

local function addBoxZone(data)
    if type(data) ~= 'table' then return print("^1[ak47_target] Error: addBoxZone requires a data table.^0") end
    if type(data.coords) ~= 'vector3' then 
        data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    end
    
    data.size = type(data.size) == 'vector3' and data.size or vector3(2.0, 2.0, 2.0)
    data.rotation = data.rotation or 0.0
    
    if not data.options then 
        local opt = {}
        for k, v in pairs(data) do
            if k ~= 'coords' and k ~= 'size' and k ~= 'rotation' and k ~= 'debug' and k ~= 'name' and k ~= 'drawSprite' then 
                opt[k] = v 
            end
        end
        data.options = {opt} 
    end
    
    return createZone('box', data.coords, data.options, { size = data.size, rotation = data.rotation, debug = data.debug, resource = data.resource, drawSprite = data.drawSprite })
end
exports('addBoxZone', addBoxZone)
ExportHandler('addBoxZone', addBoxZone)

local function addPolyZone(data)
    if type(data) ~= 'table' then return print("^1[ak47_target] Error: addPolyZone requires a data table.^0") end
    if type(data.points) ~= 'table' or #data.points < 3 then 
        return print("^1[ak47_target] Error: addPolyZone requires a 'points' table with at least 3 points.^0") 
    end
    
    data.thickness = data.thickness or 2.0
    
    if not data.options then 
        local opt = {}
        for k, v in pairs(data) do
            if k ~= 'points' and k ~= 'thickness' and k ~= 'minZ' and k ~= 'maxZ' and k ~= 'debug' and k ~= 'name' and k ~= 'drawSprite' then 
                opt[k] = v 
            end
        end
        data.options = {opt} 
    end
    
    return createZone('poly', nil, data.options, { points = data.points, thickness = data.thickness, minZ = data.minZ, maxZ = data.maxZ, debug = data.debug, resource = data.resource, drawSprite = data.drawSprite })
end
exports('addPolyZone', addPolyZone)
ExportHandler('addPolyZone', addPolyZone)

ExportHandler('removeZone', removeZone)
exports('removeZone', removeZone)

-- =================================================================
-- 8. RESOURCE STOP CLEANUP (AUTO-REMOVE TARGETS & ZONES)
-- =================================================================

AddEventHandler('onResourceStop', function(resourceName)
    local simpleTables = { TargetAPI.Peds, TargetAPI.Vehicles, TargetAPI.Objects, TargetAPI.Players, TargetAPI.Globals }
    for _, tbl in ipairs(simpleTables) do
        for i = #tbl, 1, -1 do
            if tbl[i].resource == resourceName then
                table.remove(tbl, i)
            end
        end
    end

    local dictTables = { TargetAPI.Models, TargetAPI.Entities, TargetAPI.LocalEntities }
    for _, dict in ipairs(dictTables) do
        for key, tbl in pairs(dict) do
            for i = #tbl, 1, -1 do
                if tbl[i].resource == resourceName then
                    table.remove(tbl, i)
                end
            end
            if #tbl == 0 then
                dict[key] = nil
            end
        end
    end

    if TargetAPI.Zones then
        local zonesToRemove = {}
        for id, zone in pairs(TargetAPI.Zones) do
            if zone.resource == resourceName then
                table.insert(zonesToRemove, id)
            end
        end
        for _, id in ipairs(zonesToRemove) do
            removeZone(id)
        end
    end
end)