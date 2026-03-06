local isTargeting = false
local isMenuOpen = false
local currentTarget = { entity = nil, coords = nil, distance = 0 }
local ActiveOptions = {}
local currentMenu = nil
local menuHistory = {}
local lastOutlinedEntity = nil
local waitingForRelease = false
local ignoreTargetTime = 0

local function CloseMenu()
    isMenuOpen = false
    currentMenu = nil
    menuHistory = {}
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
                        opt.matchedBone = matchedBone
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
    if waitingForRelease then return end
    
    if GetGameTimer() < ignoreTargetTime then
        waitingForRelease = true
        return
    end

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
        local flag = 511
        local lastPayloadCount = 0

        RequestStreamedTextureDict('shared', false)

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

                if entityType == 0 then
                    local _flag = flag == 511 and 26 or 511
                    local _hit, _entityHit, _endCoords = Utils.RaycastCamera(10.0, _flag)
                    local _distance = #(playerCoords - _endCoords)

                    if _distance < distance then
                        flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance
                        entityType = entityHit > 0 and GetEntityType(entityHit) or 0
                    end
                end

                if entityHit > 0 and flag ~= 511 then
                    if not HasEntityClearLosToEntity(entityHit, PlayerPedId(), 7) then
                        entityHit = 0
                        entityType = 0
                    end
                end

                local model = (entityHit > 0 and entityType > 0) and GetEntityModel(entityHit) or nil
                
                if HasStreamedTextureDictLoaded('shared') then
                    DrawZoneSprites('shared', 'emptydot_32', playerCoords, GetNearbyZones(endCoords))
                end

                local payload = GenerateMenuPayload(entityHit, entityType, model, distance, endCoords)
                local isValid = #payload > 0

                if isValid ~= hasTarget then
                    hasTarget = isValid
                    if hasTarget then
                        lastPayloadCount = #payload
                        if Config.HideEyeWhenTargetAvailable then
                            SendNUIMessage({ type = "eye", state = false })
                        end
                        SendNUIMessage({ type = "open", menu = payload })
                    else
                        lastPayloadCount = 0
                        SendNUIMessage({ type = "close" })
                        if Config.HideEyeWhenTargetAvailable then
                            SendNUIMessage({ type = "eye", state = true })
                        end
                    end
                elseif hasTarget and #payload ~= lastPayloadCount then
                    lastPayloadCount = #payload
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

                if IsDisabledControlJustReleased(0, 24) and hasTarget then 
                    currentTarget = { entity = entityHit, coords = endCoords, distance = distance }
                    isTargeting = false
                    isMenuOpen = true
                    
                    SetCursorLocation(0.5, 0.5)
                    SendNUIMessage({ type = "focus" })
                    SetNuiFocus(true, true) 

                    if currentTarget.entity and currentTarget.entity > 0 then
                        CreateThread(function()
                            local flag = 511

                            while isMenuOpen do
                                Wait(100)
                                
                                if DoesEntityExist(currentTarget.entity) then
                                    local hit, entityHit, endCoords = Utils.RaycastCamera(10.0, flag)
                                    
                                    if entityHit == 0 then
                                        local _flag = flag == 511 and 26 or 511
                                        local _, _entityHit, _ = Utils.RaycastCamera(10.0, _flag)
                                        if _entityHit == currentTarget.entity then
                                            entityHit = _entityHit
                                            flag = _flag
                                        end
                                    end

                                    if entityHit ~= currentTarget.entity then
                                        CloseMenu()
                                        break
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

            if not hasTarget then
                flag = flag == 511 and 26 or 511
            end

            Wait(hit and 1 or 100) 
        end
        
        SetStreamedTextureDictAsNoLongerNeeded('shared')
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