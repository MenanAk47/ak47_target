local zoneIdCounter = 0
local isDebugging = false
local CHUNK_SIZE = 50.0

local function GetChunkCoords(x, y)
    return math.floor(x / CHUNK_SIZE), math.floor(y / CHUNK_SIZE)
end

local function AddZoneToGrid(zone)
    local minX = zone.coords.x - zone.data.maxRadius
    local maxX = zone.coords.x + zone.data.maxRadius
    local minY = zone.coords.y - zone.data.maxRadius
    local maxY = zone.coords.y + zone.data.maxRadius

    local startCX, startCY = GetChunkCoords(minX, minY)
    local endCX, endCY = GetChunkCoords(maxX, maxY)

    zone.chunks = {}
    for cx = startCX, endCX do
        if not TargetAPI.Grid[cx] then TargetAPI.Grid[cx] = {} end
        for cy = startCY, endCY do
            if not TargetAPI.Grid[cx][cy] then TargetAPI.Grid[cx][cy] = {} end
            TargetAPI.Grid[cx][cy][zone.id] = zone
            table.insert(zone.chunks, {x = cx, y = cy})
        end
    end
end

local function RemoveZoneFromGrid(zone)
    if not zone.chunks then return end
    for _, chunk in ipairs(zone.chunks) do
        if TargetAPI.Grid[chunk.x] and TargetAPI.Grid[chunk.x][chunk.y] then
            TargetAPI.Grid[chunk.x][chunk.y][zone.id] = nil
        end
    end
    zone.chunks = nil
end

-- ==========================================
-- 3D VISUAL DEBUG RENDERERS
-- ==========================================
local function DrawSphereDebug(coords, radius)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2, radius * 2, radius * 2, 0, 200, 255, 50, false, false, 2, false, nil, nil, false)
end

local function DrawBoxDebug(coords, size, rotation)
    local w, l, h = size.x / 2, size.y / 2, (size.z or 2.0) / 2
    
    local rad = math.rad(rotation) 
    local cosRot, sinRot = math.cos(rad), math.sin(rad)

    local function getPoint(dx, dy, dz)
        local rx, ry = dx * cosRot - dy * sinRot, dx * sinRot + dy * cosRot
        return vector3(coords.x + rx, coords.y + ry, coords.z + dz)
    end

    local p = {
        getPoint(-w, -l, -h), getPoint(w, -l, -h), getPoint(w, l, -h), getPoint(-w, l, -h),
        getPoint(-w, -l, h), getPoint(w, -l, h), getPoint(w, l, h), getPoint(-w, l, h),
    }

    local r, g, b = 255, 0, 0
    for i = 1, 4 do
        DrawLine(p[i], p[i % 4 + 1], r, g, b, 255)
        DrawLine(p[i + 4], p[(i % 4) + 5], r, g, b, 255)
        DrawLine(p[i], p[i + 4], r, g, b, 255)
    end
end

local function DrawPolyDebug(points, minZ, maxZ)
    local r, g, b = 0, 255, 0
    local z1 = minZ or (points[1].z - 2.0)
    local z2 = maxZ or (points[1].z + 2.0)

    for i = 1, #points do
        local nextI = (i % #points) + 1
        local b1, b2 = vector3(points[i].x, points[i].y, z1), vector3(points[nextI].x, points[nextI].y, z1)
        local t1, t2 = vector3(points[i].x, points[i].y, z2), vector3(points[nextI].x, points[nextI].y, z2)

        DrawLine(b1, b2, r, g, b, 255) -- Bottom
        DrawLine(t1, t2, r, g, b, 255) -- Top
        DrawLine(b1, t1, r, g, b, 255) -- Pillars
    end
end

local function StartDebugThread()
    if isDebugging then return end
    isDebugging = true
    CreateThread(function()
        while isDebugging do
            Wait(0)
            local hasActive = false
            local plyCoords = GetEntityCoords(PlayerPedId())
            local cx, cy = GetChunkCoords(plyCoords.x, plyCoords.y)

            for x = cx - 1, cx + 1 do
                if TargetAPI.Grid[x] then
                    for y = cy - 1, cy + 1 do
                        if TargetAPI.Grid[x][y] then
                            for _, zone in pairs(TargetAPI.Grid[x][y]) do
                                if zone.debug then
                                    hasActive = true
                                    local checkCoord = zone.type == 'poly' and zone.data.points[1] or zone.coords
                                    if #(plyCoords - checkCoord) < 50.0 then
                                        if zone.type == 'box' then DrawBoxDebug(zone.coords, zone.data.size, zone.data.rotation)
                                        elseif zone.type == 'sphere' then DrawSphereDebug(zone.coords, zone.data.radius)
                                        elseif zone.type == 'poly' then DrawPolyDebug(zone.data.points, zone.data.minZ, zone.data.maxZ) end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not hasActive then isDebugging = false end
        end
    end)
end

-- ==========================================
-- ZONE MATHEMATICS
-- ==========================================
local function isPointInPolygon(point, polygon)
    local oddNodes, j = false, #polygon
    for i = 1, #polygon do
        if (polygon[i].y < point.y and polygon[j].y >= point.y or polygon[j].y < point.y and polygon[i].y >= point.y) then
            if (polygon[i].x + (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) * (polygon[j].x - polygon[i].x) < point.x) then oddNodes = not oddNodes end
        end
        j = i
    end
    return oddNodes
end

local function isPointInBox(point, boxCenter, size, cosRot, sinRot)
    local dx, dy = point.x - boxCenter.x, point.y - boxCenter.y
    local rotX = dx * cosRot - dy * sinRot
    local rotY = dx * sinRot + dy * cosRot
    return math.abs(rotX) <= (size.x / 2) and math.abs(rotY) <= (size.y / 2)
end

function createZone(zoneType, coords, options, customData)
    zoneIdCounter = zoneIdCounter + 1
    local id = zoneIdCounter

    if zoneType == 'box' then
        local rot = customData.rotation or 0.0
        customData.cosRot = math.cos(math.rad(-rot))
        customData.sinRot = math.sin(math.rad(-rot))
        -- Box bounding sphere radius
        customData.maxRadius = math.sqrt((customData.size.x/2)^2 + (customData.size.y/2)^2 + ((customData.size.z or 2.0)/2)^2)
    elseif zoneType == 'sphere' then
        customData.maxRadius = customData.radius or 2.0
    elseif zoneType == 'poly' then
        local cx, cy, cz = 0, 0, 0
        for _, p in ipairs(customData.points) do
            cx = cx + p.x; cy = cy + p.y; cz = cz + p.z
        end
        local pts = #customData.points
        coords = vector3(cx/pts, cy/pts, cz/pts) -- Overwrite polygon center for grid sorting
        local maxRad = 0
        for _, p in ipairs(customData.points) do
            local dist = #(vector3(p.x, p.y, p.z) - coords)
            if dist > maxRad then maxRad = dist end
        end
        customData.maxRadius = maxRad
    end

    local zone = {
        id = id,
        type = zoneType,
        coords = coords,
        options = options,
        data = customData,
        debug = customData.debug,
        resource = customData.resource or GetInvokingResource() or "ak47_target"
    }

    TargetAPI.Zones[id] = zone
    AddZoneToGrid(zone)

    if customData.debug then StartDebugThread() end
    return id
end
exports('createZone', createZone)

function GetNearbyZones(playerCoords)
    local active = {}
    local cx, cy = GetChunkCoords(playerCoords.x, playerCoords.y)

    if TargetAPI.Grid[cx] and TargetAPI.Grid[cx][cy] then
        for id, zone in pairs(TargetAPI.Grid[cx][cy]) do
            local dist = #(playerCoords - zone.coords)
            if dist <= (zone.data.maxRadius + 1.5) then 
                if zone.type == 'sphere' then
                    if dist <= zone.data.maxRadius then table.insert(active, zone) end

                elseif zone.type == 'box' then
                    if zone.data.size then
                        local zDiff = math.abs(playerCoords.z - zone.coords.z)
                        if zDiff <= ((zone.data.size.z or 2.0) / 2) and isPointInBox(playerCoords, zone.coords, zone.data.size, zone.data.cosRot, zone.data.sinRot) then
                            table.insert(active, zone)
                        end
                    end

                elseif zone.type == 'poly' then
                    local zValid = true
                    if zone.data.minZ and playerCoords.z < zone.data.minZ then zValid = false end
                    if zone.data.maxZ and playerCoords.z > zone.data.maxZ then zValid = false end
                    if zValid and zone.data.points and #zone.data.points >= 3 and isPointInPolygon(playerCoords, zone.data.points) then
                        table.insert(active, zone)
                    end
                end
            end
        end
    end
    return active
end
exports('GetNearbyZones', GetNearbyZones)

function DrawZoneSprites(dict, texture, playerCoords, hoveredZones)
    local drawn = 0
    local width = 0.02
    local height = width * GetAspectRatio(false)
    local normalColour = vector4(155, 155, 155, 175)
    local hoverColour = vector4(98, 135, 236, 255)

    local hoveredSet = {}
    if hoveredZones then
        for _, z in ipairs(hoveredZones) do
            hoveredSet[z.id] = true
        end
    end

    local cx, cy = GetChunkCoords(playerCoords.x, playerCoords.y)
    local checkedZones = {}

    for x = cx - 1, cx + 1 do
        if TargetAPI.Grid[x] then
            for y = cy - 1, cy + 1 do
                if TargetAPI.Grid[x][y] then
                    for id, zone in pairs(TargetAPI.Grid[x][y]) do
                        if not checkedZones[id] and zone.data.drawSprite ~= false then
                            checkedZones[id] = true
                            local renderCoords = zone.coords
                            if zone.type == 'poly' and zone.data.points and zone.data.points[1] then
                                renderCoords = zone.data.points[1]
                            end

                            if renderCoords and #(playerCoords - renderCoords) < 10.0 then
                                local color = hoveredSet[id] and hoverColour or normalColour
                                SetDrawOrigin(renderCoords.x, renderCoords.y, renderCoords.z)
                                DrawSprite(dict, texture, 0, 0, width, height, 0, math.floor(color.x), math.floor(color.y), math.floor(color.z), math.floor(color.w))
                                
                                drawn = drawn + 1
                                if drawn >= 24 then break end
                            end
                        end
                    end
                end
            end
        end
    end
    if drawn > 0 then ClearDrawOrigin() end
end
exports('DrawZoneSprites', DrawZoneSprites)

function removeZone(id)
    if TargetAPI.Zones[id] then
        RemoveZoneFromGrid(TargetAPI.Zones[id])
        TargetAPI.Zones[id] = nil
    end
end