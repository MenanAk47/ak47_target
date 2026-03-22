-- =================================================================
-- 1. INTERNAL HELPERS & FORMATTING
-- =================================================================

---@param options table The raw options passed from legacy scripts
---@param isQtarget boolean True if the export was called via qtarget, false if qb-target
---@param invokingResource string The resource that called the export
---@return table formatted The options converted to the new format
local function FormatOptions(options, isQtarget, invokingResource)
    local distance = options.distance
    local targetOptions = options.options or options

    if type(targetOptions) ~= 'table' then return {} end

    local numericOptions = {}
    for k, v in pairs(targetOptions) do
        table.insert(numericOptions, v)
    end
    targetOptions = numericOptions

    for id, v in pairs(targetOptions) do
        if type(id) ~= 'number' then
            targetOptions[id] = nil
            goto continue
        end

        v.onSelect = v.action or v.onSelect
        v.distance = v.distance or distance
        v.name = v.name or v.label
        v.items = v.item or v.required_item or v.items
        v.groups = v.job or v.groups

        -- Group formatting (job, gang, citizenid) without relying on non-standard table.type()
        local groupType = type(v.groups)
        if groupType == 'nil' then
            v.groups = {}
            groupType = 'table'
        end
        
        if groupType == 'string' then
            local val = v.gang
            if type(v.gang) == 'table' then
                val = {}
                for k in pairs(v.gang) do val[#val + 1] = k end
            end
            if val then
                v.groups = {v.groups, type(val) == 'table' and table.unpack(val) or val}
            end

            val = v.citizenid
            if type(v.citizenid) == 'table' then
                val = {}
                for k in pairs(v.citizenid) do val[#val+1] = k end
            end
            if val then
                v.groups = {v.groups, type(val) == 'table' and table.unpack(val) or val}
            end
        elseif groupType == 'table' then
            local val = {}
            local isArray = true
            for k, _ in pairs(v.groups) do
                if type(k) ~= 'number' then isArray = false break end
            end
            
            if not isArray then
                for k in pairs(v.groups) do val[#val + 1] = k end
                v.groups = val
                val = nil
            end

            val = v.gang
            if type(v.gang) == 'table' then
                local gangArr = {}
                for k in pairs(v.gang) do gangArr[#gangArr + 1] = k end
                val = gangArr
            end
            if val then
                v.groups = {table.unpack(v.groups), type(val) == 'table' and table.unpack(val) or val}
            end

            val = v.citizenid
            if type(v.citizenid) == 'table' then
                local citArr = {}
                for k in pairs(v.citizenid) do citArr[#citArr+1] = k end
                val = citArr
            end
            if val then
                v.groups = {table.unpack(v.groups), type(val) == 'table' and table.unpack(val) or val}
            end
        end

        if type(v.groups) == 'table' and #v.groups == 0 then
            v.groups = nil
        end

        -- Event and Command Routing
        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end
            v.event = nil
            v.type = nil
        end

        -- Garbage collection
        v.action = nil
        v.job = nil
        v.gang = nil
        v.citizenid = nil
        v.item = nil
        v.required_item = nil
        
        -- Flag for main.lua payload routing (Sends entity directly instead of response table)
        v.resource = invokingResource
        v.qtarget = true

        ::continue::
    end

    return targetOptions
end

---@param exportName string The name of the export to hook into
---@param func function The function to execute
local function ExportHandler(exportName, func)
    AddEventHandler(('__cfx_export_qb-target_%s'):format(exportName), function(setCB) 
        setCB(function(...) return func(false, GetInvokingResource(), ...) end) 
    end)
    AddEventHandler(('__cfx_export_qtarget_%s'):format(exportName), function(setCB) 
        setCB(function(...) return func(true, GetInvokingResource(), ...) end) 
    end)
end

-- =================================================================
-- 2. ZONE COMPATIBILITY EXPORTS
-- =================================================================

ExportHandler('AddBoxZone', function(isQtarget, invokingResource, name, center, length, width, options, targetoptions)
    local centerZ = center.z
    local height = 2.0

    if options.minZ and options.maxZ then
        height = math.abs(options.maxZ - options.minZ)
        centerZ = (options.maxZ + options.minZ) / 2.0
    elseif options.minZ then
        height = math.abs((center.z + 2.0) - options.minZ)
        centerZ = options.minZ + (height / 2.0)
    elseif options.maxZ then
        height = math.abs(options.maxZ - (center.z - 2.0))
        centerZ = options.maxZ - (height / 2.0)
    else
        height = 900.0
        centerZ = center.z
    end

    local formattedOpts = FormatOptions(targetoptions, isQtarget, invokingResource)
    formattedOpts._legacyName = name

    return exports['ak47_target']:addBoxZone({
        name = name,
        coords = vec3(center.x, center.y, centerZ),
        size = vec3(width, length, height),
        debug = options.debugPoly,
        rotation = options.heading,
        options = formattedOpts,
        resource = invokingResource
    })
end)

ExportHandler('AddPolyZone', function(isQtarget, invokingResource, name, points, options, targetoptions)
    local newPoints = {}
    
    if not options.minZ then options.minZ = -100 end
    if not options.maxZ then options.maxZ = 800 end
    local thickness = math.abs(options.maxZ - options.minZ)

    for i = 1, #points do
        local point = points[i]
        table.insert(newPoints, vec3(point.x, point.y, options.maxZ - (thickness / 2)))
    end

    local formattedOpts = FormatOptions(targetoptions, isQtarget, invokingResource)
    formattedOpts._legacyName = name 

    return exports['ak47_target']:addPolyZone({
        name = name,
        points = newPoints,
        thickness = thickness,
        debug = options.debugPoly,
        options = formattedOpts,
        resource = invokingResource
    })
end)

ExportHandler('AddCircleZone', function(isQtarget, invokingResource, name, center, radius, options, targetoptions)
    local formattedOpts = FormatOptions(targetoptions, isQtarget, invokingResource)
    formattedOpts._legacyName = name 

    return exports['ak47_target']:addSphereZone({
        name = name,
        coords = vec3(center.x, center.y, center.z),
        radius = radius,
        debug = options.debugPoly,
        options = formattedOpts,
        resource = invokingResource
    })
end)

ExportHandler('RemoveZone', function(isQtarget, invokingResource, id) 
    if type(id) == 'number' then
        exports['ak47_target']:removeZone(id)
        return
    end

    if TargetAPI and TargetAPI.Zones then
        for zoneId, zone in pairs(TargetAPI.Zones) do
            if zone.options and zone.options[1] and zone.options[1]._legacyName == id then
                exports['ak47_target']:removeZone(zoneId)
            end
        end
    end
end)

-- =================================================================
-- 3. GLOBAL ENTITY COMPATIBILITY EXPORTS
-- =================================================================

ExportHandler('AddGlobalPed', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalPed(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('AddGlobalVehicle', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalVehicle(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('AddGlobalObject', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalObject(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('AddGlobalPlayer', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalPlayer(FormatOptions(options, isQtarget, invokingResource)) end)

ExportHandler('Ped', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalPed(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('Vehicle', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalVehicle(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('Object', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalObject(FormatOptions(options, isQtarget, invokingResource)) end)
ExportHandler('Player', function(isQtarget, invokingResource, options) exports['ak47_target']:addGlobalPlayer(FormatOptions(options, isQtarget, invokingResource)) end)

ExportHandler('RemoveGlobalPed', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalPed(labels) end)
ExportHandler('RemoveGlobalVehicle', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalVehicle(labels) end)
ExportHandler('RemoveGlobalObject', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalObject(labels) end)
ExportHandler('RemoveGlobalPlayer', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalPlayer(labels) end)

ExportHandler('RemovePed', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalPed(labels) end)
ExportHandler('RemoveVehicle', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalVehicle(labels) end)
ExportHandler('RemoveObject', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalObject(labels) end)
ExportHandler('RemovePlayer', function(isQtarget, invokingResource, labels) exports['ak47_target']:removeGlobalPlayer(labels) end)

-- =================================================================
-- 4. SPECIFIC ENTITY & MODEL COMPATIBILITY EXPORTS
-- =================================================================

ExportHandler('AddTargetModel', function(isQtarget, invokingResource, models, options)
    exports['ak47_target']:addModel(models, FormatOptions(options, isQtarget, invokingResource))
end)

ExportHandler('RemoveTargetModel', function(isQtarget, invokingResource, models, labels)
    exports['ak47_target']:removeModel(models, labels)
end)

ExportHandler('AddTargetEntity', function(isQtarget, invokingResource, entities, options)
    if type(entities) ~= 'table' then entities = { entities } end
    local formattedOpts = FormatOptions(options, isQtarget, invokingResource)

    for i = 1, #entities do
        local entity = entities[i]
        if NetworkGetEntityIsNetworked(entity) then
            exports['ak47_target']:addEntity(NetworkGetNetworkIdFromEntity(entity), formattedOpts)
        else
            exports['ak47_target']:addLocalEntity(entity, formattedOpts)
        end
    end
end)

ExportHandler('RemoveTargetEntity', function(isQtarget, invokingResource, entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end

    for i = 1, #entities do
        local entity = entities[i]
        if NetworkGetEntityIsNetworked(entity) then
            exports['ak47_target']:removeEntity(NetworkGetNetworkIdFromEntity(entity), labels)
        else
            exports['ak47_target']:removeLocalEntity(entity, labels)
        end
    end
end)

ExportHandler('AddTargetBone', function(isQtarget, invokingResource, bones, options)
    if type(bones) ~= 'table' then bones = { bones } end
    local formattedOptions = FormatOptions(options, isQtarget, invokingResource)

    for _, v in pairs(formattedOptions) do
        v.bones = bones
    end

    exports['ak47_target']:addGlobalVehicle(formattedOptions)
end)

-- =================================================================
-- 5. DEPRECATED / REDIRECTED EXPORTS
-- =================================================================

ExportHandler('AddEntityZone', function(isQtarget, invokingResource, name, entity, options, targetoptions)
    print("^3[ak47_target] Warning: AddEntityZone is deprecated. Re-routing to AddTargetEntity.^0")
    exports['ak47_target']:addLocalEntity(entity, FormatOptions(targetoptions, isQtarget, invokingResource))
end)

ExportHandler('RemoveTargetBone', function(isQtarget, invokingResource, bones, labels)
    print("^3[ak47_target] Warning: RemoveTargetBone is not fully supported, rerouting to removeGlobalVehicle.^0")
    if type(labels) ~= 'table' then labels = { labels } end
    exports['ak47_target']:removeGlobalVehicle(labels)
end)