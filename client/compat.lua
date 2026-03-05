-- =================================================================
-- 1. INTERNAL HELPERS & FORMATTING
-- =================================================================

---@param options table The raw options passed from legacy scripts
---@return table formatted The options converted to the new format
local function FormatOptions(options)
    local formatted = {}
    local distance = options.distance or 2.0
    local targetOptions = options.options or options

    for k, v in pairs(targetOptions) do
        if type(k) == 'number' then
            v.distance = v.distance or distance
            v.name = v.name or v.label
            v.onSelect = v.onSelect or v.action
            
            -- Legacy Translation mapping
            v.groups = v.groups or v.job or v.gang or v.citizenid
            v.items = v.items or v.item or v.required_item
            v.qtarget = true
            
            if v.event and v.type then
                if v.type == 'server' then v.serverEvent = v.event 
                elseif v.type == 'command' then v.command = v.event end
                if v.type ~= 'client' then v.event = nil end
            end
            table.insert(formatted, v)
        end
    end
    return formatted
end

---@param exportName string The name of the export to hook into
---@param func function The function to execute
local function ExportHandler(exportName, func)
    AddEventHandler(('__cfx_export_qb-target_%s'):format(exportName), function(setCB) setCB(func) end)
    AddEventHandler(('__cfx_export_qtarget_%s'):format(exportName), function(setCB) setCB(func) end)
end

-- =================================================================
-- 2. ZONE COMPATIBILITY EXPORTS
-- =================================================================

ExportHandler('AddBoxZone', function(name, center, length, width, options, targetoptions)
    return exports['ak47_target']:addBoxZone({
        name = name, coords = center, size = vector3(width, length, 2.0),
        debug = options.debugPoly,
        options = FormatOptions(targetoptions)
    })
end)

ExportHandler('AddPolyZone', function(name, points, options, targetoptions)
    local newPoints = {}
    local thickness = math.abs((options.maxZ or 10.0) - (options.minZ or -10.0))

    for i = 1, #points do
        table.insert(newPoints, vector3(points[i].x, points[i].y, options.maxZ and (options.maxZ - (thickness / 2)) or 0.0))
    end

    return exports['ak47_target']:addPolyZone({
        name = name,
        points = newPoints,
        thickness = thickness,
        minZ = options.minZ,
        maxZ = options.maxZ,
        debug = options.debugPoly,
        options = FormatOptions(targetoptions),
    })
end)

ExportHandler('AddCircleZone', function(name, center, radius, options, targetoptions)
    return exports['ak47_target']:addSphereZone({
        name = name,
        coords = center,
        radius = radius,
        debug = options.debugPoly,
        options = FormatOptions(targetoptions),
    })
end)

ExportHandler('RemoveZone', function(id) 
    exports['ak47_target']:removeZone(id) 
end)

-- =================================================================
-- 3. GLOBAL ENTITY COMPATIBILITY EXPORTS
-- =================================================================

-- Additions
ExportHandler('AddGlobalPed', function(options) exports['ak47_target']:addGlobalPed(FormatOptions(options)) end)
ExportHandler('AddGlobalVehicle', function(options) exports['ak47_target']:addGlobalVehicle(FormatOptions(options)) end)
ExportHandler('AddGlobalObject', function(options) exports['ak47_target']:addGlobalObject(FormatOptions(options)) end)
ExportHandler('AddGlobalPlayer', function(options) exports['ak47_target']:addGlobalPlayer(FormatOptions(options)) end)

-- qtarget specific legacy aliases
ExportHandler('Ped', function(options) exports['ak47_target']:addGlobalPed(FormatOptions(options)) end)
ExportHandler('Vehicle', function(options) exports['ak47_target']:addGlobalVehicle(FormatOptions(options)) end)
ExportHandler('Object', function(options) exports['ak47_target']:addGlobalObject(FormatOptions(options)) end)
ExportHandler('Player', function(options) exports['ak47_target']:addGlobalPlayer(FormatOptions(options)) end)

-- Removals
ExportHandler('RemovePed', function(labels) exports['ak47_target']:removeGlobalPed(labels) end)
ExportHandler('RemoveVehicle', function(labels) exports['ak47_target']:removeGlobalVehicle(labels) end)
ExportHandler('RemoveObject', function(labels) exports['ak47_target']:removeGlobalObject(labels) end)
ExportHandler('RemovePlayer', function(labels) exports['ak47_target']:removeGlobalPlayer(labels) end)

-- =================================================================
-- 4. SPECIFIC ENTITY & MODEL COMPATIBILITY EXPORTS
-- =================================================================

ExportHandler('AddTargetModel', function(models, options)
    exports['ak47_target']:addModel(models, FormatOptions(options))
end)

ExportHandler('RemoveTargetModel', function(models, labels)
    exports['ak47_target']:removeModel(models, labels)
end)

ExportHandler('AddTargetEntity', function(entities, options)
    exports['ak47_target']:addLocalEntity(entities, FormatOptions(options))
end)

ExportHandler('RemoveTargetEntity', function(entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end
    for _, entity in ipairs(entities) do
        if NetworkGetEntityIsNetworked(entity) then
            exports['ak47_target']:removeEntity(NetworkGetNetworkIdFromEntity(entity), labels)
        else
            exports['ak47_target']:removeLocalEntity(entity, labels)
        end
    end
end)

ExportHandler('AddTargetBone', function(bones, options)
    if type(bones) ~= 'table' then bones = { bones } end
    local formattedOptions = FormatOptions(options)

    for _, v in ipairs(formattedOptions) do
        v.bones = bones
    end

    exports['ak47_target']:addGlobalVehicle(formattedOptions)
end)

ExportHandler('RemoveTargetBone', function()
    
end)

-- =================================================================
-- 5. DEPRECATED / REDIRECTED EXPORTS
-- =================================================================

ExportHandler('AddEntityZone', function(name, entity, options, targetoptions)
    print("^3[ak47_target] Warning: AddEntityZone is deprecated. Re-routing to AddTargetEntity.^0")
    exports['ak47_target']:addLocalEntity(entity, FormatOptions(targetoptions))
end)