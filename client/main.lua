local isTargeting = false
local isMenuOpen = false
local currentTarget = { entity = nil, coords = nil, distance = 0 }
local ActiveOptions = {}
local lastOutlinedEntity = nil
local waitingForRelease = false
local ignoreTargetTime = 0

local function CloseMenu()
    isMenuOpen = false
    if not Config.HideEyeWhenTargetAvailable then
        SendNUIMessage({ type = "eye", state = false })
    end
    SendNUIMessage({ type = "close" })
    SetNuiFocus(false, false)
    ActiveOptions = {}
    if lastOutlinedEntity then
        SetEntityDrawOutline(lastOutlinedEntity, false)
        lastOutlinedEntity = nil
    end
    ignoreTargetTime = GetGameTimer() + 100
end

local function StopTargeting()
    waitingForRelease = false
    ignoreTargetTime = 0

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

local function GenerateMenuPayload(entity, entityType, model, distance, coords, nearbyZones)
    local menuPayload = {}
    local idCounter = 0
    ActiveOptions = {}

    local function processOption(opt, zoneId)
        local canAdd = true
        local matchedBone = nil

        if opt.groups and not Utils.HasGroup(opt.groups) then canAdd = false end
        if canAdd and opt.items and not Utils.HasItem(opt.items, opt.anyItem) then canAdd = false end

        if canAdd and opt.bones and entity and entity > 0 then
            local _type = type(opt.bones)

            if _type == 'string' then
                local boneId = GetEntityBoneIndexByName(entity, opt.bones)
                if boneId ~= -1 and #(coords - GetEntityBonePosition_2(entity, boneId)) <= (opt.distance or 2.0) then
                    matchedBone = boneId
                else
                    canAdd = false
                end
            elseif _type == 'table' then
                local closestBone, closestBoneDistance

                for j = 1, #opt.bones do
                    local boneId = GetEntityBoneIndexByName(entity, opt.bones[j])
                    if boneId ~= -1 then
                        local dist = #(coords - GetEntityBonePosition_2(entity, boneId))
                        if dist <= (opt.distance or 2.0) and (not closestBoneDistance or dist < closestBoneDistance) then
                            closestBone = boneId
                            closestBoneDistance = dist
                        end
                    end
                end

                if closestBone then
                    matchedBone = closestBone
                else
                    canAdd = false
                end
            end
        end

        if canAdd and opt.offset and entity and entity > 0 and model then
            local offset = opt.offset

            if not opt.absoluteOffset then
                local minDim, maxDim = GetModelDimensions(model)
                offset = (maxDim - minDim) * offset + minDim
            end

            local offsetCoords = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
            if #(coords - offsetCoords) > (opt.offsetSize or 1.0) then canAdd = false end
        end

        if canAdd and opt.canInteract then
            local s, res = pcall(opt.canInteract, entity, distance, coords, opt.name, matchedBone)
            canAdd = s and res
        end

        if canAdd then
            opt.zoneId = zoneId
            opt.matchedBone = matchedBone
            idCounter = idCounter + 1
            ActiveOptions[idCounter] = opt
            
            local itemPayload = {
                id = idCounter,
                label = opt.label or "Interact",
                icon = opt.icon or "fas fa-circle",
                description = opt.description or ""
            }

            if opt.submenu and type(opt.submenu) == "table" then
                itemPayload.submenu = {}
                for _, subOpt in ipairs(opt.submenu) do
                    subOpt.distance = subOpt.distance or opt.distance 
                    local childPayload = processOption(subOpt, zoneId)
                    if childPayload then
                        table.insert(itemPayload.submenu, childPayload)
                    end
                end
            end

            return itemPayload
        end
        return nil
    end

    local function parseOptions(opts, zoneId)
        if not opts then return end
        for _, opt in ipairs(opts) do
            if not opt.distance or distance <= opt.distance then
                local payload = processOption(opt, zoneId)
                if payload then
                    table.insert(menuPayload, payload)
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

    for _, z in ipairs(nearbyZones) do parseOptions(z.options, z.id) end

    return menuPayload
end

local function StartTargeting()
    if waitingForRelease then return end
    
    if GetGameTimer() < ignoreTargetTime then
        waitingForRelease = true
        return
    end

    if isTargeting or isMenuOpen or exports['ak47_target']:isDisabled() or IsPauseMenuActive() then return end
    isTargeting = true
    SendNUIMessage({ type = "eye", state = true })

    if Config.ShowZoneBubble and not HasStreamedTextureDictLoaded('shared') then
        RequestStreamedTextureDict('shared', false)
    end

    local nearbyZones = {}
    local hasTarget = false
    local playerPed = PlayerPedId()

    CreateThread(function()
        local playerId = PlayerId()
        while isTargeting do
            Wait(0)
            DisablePlayerFiring(playerId, true) -- Attack
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 140, true) -- Melee
            DisableControlAction(0, 141, true) -- Melee
            DisableControlAction(0, 142, true) -- Melee

            if Config.ShowZoneBubble and HasStreamedTextureDictLoaded('shared') then
                DrawZoneSprites('shared', 'emptydot_32', GetEntityCoords(playerPed), nearbyZones)
            end

            if hasTarget then
                if IsDisabledControlJustReleased(0, 24) then 
                    SetCursorLocation(0.5, 0.5)
                    SendNUIMessage({ type = "focus" })
                    SetNuiFocus(true, true) 
                    
                    isTargeting = false
                    isMenuOpen = true

                    if currentTarget.entity and currentTarget.entity > 0 then
                        CreateThread(function()
                            local trackFlag = 511
                            while isMenuOpen do
                                Wait(150)
                                
                                if DoesEntityExist(currentTarget.entity) then
                                    local _, entityHit, _ = Utils.RaycastCamera(10.0, trackFlag)
                                    
                                    if entityHit ~= currentTarget.entity then
                                        trackFlag = trackFlag == 511 and 26 or 511
                                        local _, _entityHit, _ = Utils.RaycastCamera(10.0, trackFlag)
                                        if _entityHit ~= currentTarget.entity then
                                            CloseMenu()
                                            break
                                        end
                                    end
                                else
                                    CloseMenu()
                                    break
                                end
                            end
                        end)
                    end
                end

                if IsDisabledControlJustReleased(0, 25) then 
                    StopTargeting() 
                end
            end
        end
    end)

    CreateThread(function()
        local flag = 511
        local lastEntityHit = 0
        local lastPayloadJson = '[]'

        local pendingPayload = nil
        local pendingPayloadJson = nil
        local pendingHasTarget = false
        local pendingSince = 0

        local SWITCH_DEBOUNCE_MS = 110
        local CLEAR_DEBOUNCE_MS = 140

        local function applyPayload(payload, payloadJson, isValid, entityHit, entityType, endCoords, distance)
            pendingPayload = nil
            pendingPayloadJson = nil
            pendingHasTarget = false
            pendingSince = 0

            if isValid ~= hasTarget then
                hasTarget = isValid
                lastPayloadJson = payloadJson

                if hasTarget then
                    if Config.HideEyeWhenTargetAvailable then
                        SendNUIMessage({ type = "eye", state = false })
                    end
                    SendNUIMessage({ type = "open", menu = payload })
                else
                    SendNUIMessage({ type = "close" })
                    if Config.HideEyeWhenTargetAvailable then
                        SendNUIMessage({ type = "eye", state = true })
                    end
                end
            elseif hasTarget and payloadJson ~= lastPayloadJson then
                lastPayloadJson = payloadJson
                SendNUIMessage({ type = "open", menu = payload })
            end

            if Config.DrawOutline then
                if hasTarget and entityHit > 0 and entityType ~= 1 then
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
            end

            if hasTarget then
                currentTarget = { entity = entityHit, coords = endCoords, distance = distance }
            end
        end

        while isTargeting do
            if IsPauseMenuActive() then
                StopTargeting()
                break
            end

            local now = GetGameTimer()
            local playerCoords = GetEntityCoords(playerPed)
            local hit, entityHit, endCoords = Utils.RaycastCamera(10.0, flag, playerPed)
            local distance = hit and #(playerCoords - endCoords) or 0
            local entityType = entityHit > 0 and GetEntityType(entityHit) or 0

            if entityType == 0 then
                local altFlag = flag == 511 and 26 or 511
                local altHit, altEntityHit, altEndCoords = Utils.RaycastCamera(10.0, altFlag, playerPed)
                local altDistance = altHit and #(playerCoords - altEndCoords) or 0

                if altHit and (not hit or altDistance < distance) then
                    flag, hit, entityHit, endCoords, distance = altFlag, altHit, altEntityHit, altEndCoords, altDistance
                    entityType = entityHit > 0 and GetEntityType(entityHit) or 0
                end
            end

            if hit then
                local model = (entityHit > 0 and entityType > 0) and GetEntityModel(entityHit) or nil
                nearbyZones = GetNearbyZones(endCoords)
                local payload = GenerateMenuPayload(entityHit, entityType, model, distance, endCoords, nearbyZones)
                local payloadJson = json.encode(payload)
                local isValid = #payload > 0
                local entityChanged = entityHit ~= lastEntityHit

                if entityChanged or (not hasTarget and isValid) then
                    applyPayload(payload, payloadJson, isValid, entityHit, entityType, endCoords, distance)
                elseif payloadJson ~= lastPayloadJson or isValid ~= hasTarget then
                    if pendingPayloadJson ~= payloadJson then
                        pendingPayload = payload
                        pendingPayloadJson = payloadJson
                        pendingHasTarget = isValid
                        pendingSince = now
                    else
                        local debounce = pendingHasTarget and SWITCH_DEBOUNCE_MS or CLEAR_DEBOUNCE_MS
                        if now - pendingSince >= debounce then
                            applyPayload(pendingPayload, pendingPayloadJson, pendingHasTarget, entityHit, entityType, endCoords, distance)
                        end
                    end
                else
                    pendingPayload = nil
                    pendingPayloadJson = nil
                    pendingHasTarget = false
                    pendingSince = 0

                    if hasTarget then
                        currentTarget = { entity = entityHit, coords = endCoords, distance = distance }
                    end

                    if Config.DrawOutline then
                        if hasTarget and entityHit > 0 and entityType ~= 1 then
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
                    end
                end

                lastEntityHit = entityHit
            else
                if hasTarget then
                    if pendingPayloadJson ~= '[]' then
                        pendingPayload = {}
                        pendingPayloadJson = '[]'
                        pendingHasTarget = false
                        pendingSince = now
                    elseif now - pendingSince >= CLEAR_DEBOUNCE_MS then
                        applyPayload({}, '[]', false, 0, 0, endCoords, 0)
                        lastEntityHit = 0
                    end
                else
                    pendingPayload = nil
                    pendingPayloadJson = nil
                    pendingHasTarget = false
                    pendingSince = 0
                    lastEntityHit = 0

                    if lastOutlinedEntity then
                        SetEntityDrawOutline(lastOutlinedEntity, false)
                        lastOutlinedEntity = nil
                    end
                end
            end

            Wait(hit and 75 or 125)
        end

        if Config.ShowZoneBubble and HasStreamedTextureDictLoaded('shared') then
            SetStreamedTextureDictAsNoLongerNeeded('shared')
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
        CloseMenu()

        local response = {}
        for k, v in pairs(option) do
            response[k] = v
        end
        
        response.entity = currentTarget.entity
        response.coords = currentTarget.coords
        response.distance = currentTarget.distance
        response.zone = option.zoneId
        response.bone = option.matchedBone

        response.onSelect = nil
        response.action = nil
        response.canInteract = nil

        if option.onSelect or option.action then
            local func = option.onSelect or option.action
            func(option.qtarget and currentTarget.entity or response)
        elseif option.export then
            if string.find(option.export, "%.") then
                local exportParts = stringSplit(option.export, ".")
                exports[exportParts[1]][exportParts[2]](nil, response)
            else
                local resource = option.resource or "unknown"
                exports[resource][option.export](nil, response)
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
