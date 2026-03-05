local isTargeting = false
local isMenuOpen = false
local currentTarget = { entity = nil, coords = nil, distance = 0 }
local ActiveOptions = {}
local currentMenu = nil
local menuHistory = {}
local lastOutlinedEntity = nil

local function CloseMenu()
    isMenuOpen = false
    currentMenu = nil
    menuHistory = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "close" })
    ActiveOptions = {}
    if lastOutlinedEntity then
        SetEntityDrawOutline(lastOutlinedEntity, false)
        lastOutlinedEntity = nil
    end
end

local function StopTargeting()
    if not isMenuOpen then
        isTargeting = false
        SendNUIMessage({ type = "close" })
        SendNUIMessage({ type = "eye", state = false })
        if lastOutlinedEntity then
            SetEntityDrawOutline(lastOutlinedEntity, false)
            lastOutlinedEntity = nil
        end
    end
end

local function GenerateMenuPayload(entity, entityType, model, distance, coords)
    local menuPayload = {}
    local idCounter = 0
    ActiveOptions = {}

    local function parseOptions(opts, zoneId)
        if not opts then return end
        for _, opt in ipairs(opts) do
            local optMenuName = opt.menuName or nil
            if optMenuName == currentMenu then
                if not opt.distance or distance <= opt.distance then
                    local canAdd = true
                    local matchedBone = nil

                    if opt.groups and not Utils.HasGroup(opt.groups) then canAdd = false end
                    if canAdd and opt.items and not Utils.HasItem(opt.items, opt.anyItem) then canAdd = false end

                    if canAdd and opt.bones and entity and entity > 0 then
                        local boneFound = false
                        local _type = type(opt.bones)
                        local closestDist = opt.distance or 2.0

                        if _type == 'string' then
                            local boneId = GetEntityBoneIndexByName(entity, opt.bones)
                            if boneId ~= -1 and #(coords - GetEntityBonePosition_2(entity, boneId)) <= closestDist then
                                boneFound = true
                                matchedBone = boneId
                            end
                        elseif _type == 'table' then
                            for j = 1, #opt.bones do
                                local boneId = GetEntityBoneIndexByName(entity, opt.bones[j])
                                if boneId ~= -1 and #(coords - GetEntityBonePosition_2(entity, boneId)) <= closestDist then
                                    boneFound = true
                                    matchedBone = boneId
                                    break
                                end
                            end
                        end
                        if not boneFound then canAdd = false end
                    end

                    if canAdd and opt.offset and entity and entity > 0 and model then
                        local offsetCoords = GetOffsetFromEntityInWorldCoords(entity, opt.offset.x, opt.offset.y, opt.offset.z)
                        if #(coords - offsetCoords) > (opt.offsetSize or 1.0) then canAdd = false end
                    end

                    if canAdd and opt.canInteract then
                        local s, res = pcall(opt.canInteract, entity, distance, coords, opt.name, matchedBone)
                        canAdd = s and res
                    end

                    if canAdd then
                        opt.zoneId = zoneId
                        idCounter = idCounter + 1
                        ActiveOptions[idCounter] = opt
                        table.insert(menuPayload, {
                            id = idCounter,
                            label = opt.label or "Interact",
                            icon = opt.icon or "fas fa-circle",
                            description = opt.description or ""
                        })
                    end
                end
            end
        end
    end

    parseOptions(TargetAPI.Globals)
    if entityType == 1 then parseOptions(TargetAPI.Peds)
    elseif entityType == 2 then parseOptions(TargetAPI.Vehicles)
    elseif entityType == 3 then parseOptions(TargetAPI.Objects) end
    if IsPedAPlayer(entity) then parseOptions(TargetAPI.Players) end
    if model then parseOptions(TargetAPI.Models[model]) end
    if entity and TargetAPI.LocalEntities[entity] then parseOptions(TargetAPI.LocalEntities[entity]) end
    
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    if netId and TargetAPI.Entities[netId] then parseOptions(TargetAPI.Entities[netId]) end

    local zones = GetNearbyZones(coords)
    for _, z in ipairs(zones) do parseOptions(z.options, z.id) end

    if currentMenu ~= nil then
        idCounter = idCounter + 1
        ActiveOptions[idCounter] = { builtin = 'goback' }
        table.insert(menuPayload, 1, {
            id = idCounter,
            label = "Go Back",
            icon = "fas fa-circle-chevron-left",
            description = ""
        })
    end

    return menuPayload
end

local function StartTargeting()
    if isTargeting or isMenuOpen or exports[GetCurrentResourceName()]:isDisabled() or IsPauseMenuActive() then return end
    isTargeting = true
    SendNUIMessage({ type = "eye", state = true })
    currentMenu = nil

    CreateThread(function()
        while isTargeting do
            Wait(0)
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee
        end
    end)

    CreateThread(function()
        local hasTarget = false
        local flag = 511 -- Start with default raycast flag
        local lastPayloadCount = 0 -- Tracks options to update menu dynamically if you walk closer

        while isTargeting do
            if IsPauseMenuActive() then
                StopTargeting()
                break
            end

            local playerCoords = GetEntityCoords(PlayerPedId())
            local hit, entityHit, endCoords = Utils.RaycastCamera(10.0, flag)

            if hit then
                local distance = #(playerCoords - endCoords)
                
                local entityType = entityHit > 0 and GetEntityType(entityHit) or 0

                -- Alternating Raycast: If we hit the world, swap flags and try again to catch entities in glass/water
                if entityType == 0 then
                    local _flag = flag == 511 and 26 or 511
                    local _hit, _entityHit, _endCoords = Utils.RaycastCamera(10.0, _flag)
                    local _distance = #(playerCoords - _endCoords)

                    if _distance < distance then
                        flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance
                        entityType = entityHit > 0 and GetEntityType(entityHit) or 0
                    end
                end

                -- Line of Sight Check: Prevent targeting through solid walls when using alternative flags
                if entityHit > 0 and flag ~= 511 then
                    if not HasEntityClearLosToEntity(entityHit, PlayerPedId(), 7) then
                        entityHit = 0
                        entityType = 0
                    end
                end

                local model = nil
                if entityHit > 0 then
                    local success, result = pcall(GetEntityModel, entityHit)
                    model = success and result
                end
                
                local payload = GenerateMenuPayload(entityHit, entityType, model, distance, endCoords)
                local isValid = #payload > 0

                -- Dynamic UI Update
                if isValid ~= hasTarget then
                    hasTarget = isValid
                    if hasTarget then
                        lastPayloadCount = #payload
                        SendNUIMessage({ type = "eye", state = false })
                        SendNUIMessage({ type = "open", menu = payload })
                    else
                        lastPayloadCount = 0
                        SendNUIMessage({ type = "close" })
                        SendNUIMessage({ type = "eye", state = true })
                    end
                elseif hasTarget and #payload ~= lastPayloadCount then
                    lastPayloadCount = #payload
                    SendNUIMessage({ type = "open", menu = payload })
                end

                -- Outline Logic
                if hasTarget and entityHit > 0 and entityType ~= 1 then -- Avoid outlining peds/players
                    if lastOutlinedEntity ~= entityHit then
                        if lastOutlinedEntity then SetEntityDrawOutline(lastOutlinedEntity, false) end
                        SetEntityDrawOutline(entityHit, true)
                        lastOutlinedEntity = entityHit
                    end
                else
                    if lastOutlinedEntity then
                        SetEntityDrawOutline(lastOutlinedEntity, false)
                        lastOutlinedEntity = nil
                    end
                end

                if IsDisabledControlJustReleased(0, 24) and hasTarget then 
                    currentTarget = { entity = entityHit, coords = endCoords, distance = distance }
                    isTargeting = false
                    isMenuOpen = true
                    
                    SetCursorLocation(0.5, 0.5)
                    SetNuiFocus(true, true) 
                end

                if IsDisabledControlJustReleased(0, 25) then 
                    StopTargeting() 
                end

            end

            -- Swap raycast flag for the next tick if we didn't find anything
            if not hasTarget then
                flag = flag == 511 and 26 or 511
            end

            Wait(hit and 1 or 100)
        end
    end)
end

RegisterCommand('+target', StartTargeting, false)
RegisterCommand('-target', StopTargeting, false)
RegisterKeyMapping('+target', 'Toggle Target UI', 'keyboard', 'LMENU')

local function stringSplit(inputstr, sep)
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do table.insert(t, str) end
    return t
end

RegisterNUICallback('clicked', function(data, cb)
    local optId = tonumber(data)
    local option = ActiveOptions[optId]
    cb('ok')

    if option then
        if option.builtin == 'goback' then
            currentMenu = table.remove(menuHistory)
            local payload = GenerateMenuPayload(currentTarget.entity, GetEntityType(currentTarget.entity), GetEntityModel(currentTarget.entity), currentTarget.distance, currentTarget.coords)
            SendNUIMessage({ type = "open", menu = payload })
            return
        elseif option.openMenu then
            table.insert(menuHistory, currentMenu)
            currentMenu = option.openMenu
            local payload = GenerateMenuPayload(currentTarget.entity, GetEntityType(currentTarget.entity), GetEntityModel(currentTarget.entity), currentTarget.distance, currentTarget.coords)
            SendNUIMessage({ type = "open", menu = payload })
            return
        end

        CloseMenu()

        local response = {
            entity = currentTarget.entity,
            coords = currentTarget.coords,
            distance = currentTarget.distance,
            zone = option.zoneId
        }

        if option.onSelect or option.action then
            local func = option.onSelect or option.action
            func(option.qtarget and currentTarget.entity or response)
        elseif option.export then
            local exportParts = stringSplit(option.export, ".")
            if #exportParts == 2 then
                exports[exportParts[1]][exportParts[2]](nil, response)
            else
                print("^1[ak47_target] Invalid export format. Use 'resource.exportName'^0")
            end
        elseif option.event then
            TriggerEvent(option.event, response)
        elseif option.serverEvent then
            local netId = (response.entity and response.entity > 0) and NetworkGetNetworkIdFromEntity(response.entity) or 0
            response.entity = netId
            TriggerServerEvent(option.serverEvent, response)
        elseif option.command then
            ExecuteCommand(option.command)
        end
    else
        CloseMenu()
    end
end)

RegisterNUICallback('close', function(data, cb)
    CloseMenu()
    cb('ok')
end)

exports('isActive', function() return isTargeting end)