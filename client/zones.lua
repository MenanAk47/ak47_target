local zoneIdCounter = 0
local isDebugging = false

-- ==========================================
-- 3D VISUAL DEBUG RENDERERS
-- ==========================================
local function DrawSphereDebug(coords, radius)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius*2, radius*2, radius*2, 0, 200, 255, 50, false, false, 2, false, nil, nil, false)
end

local function DrawBoxDebug(coords, size, rotation)
    local w, l, h = size.x / 2, size.y / 2, (size.z or 2.0) / 2
    local rad = math.rad(-rotation)
    local cosRot, sinRot = math.cos(rad), math.sin(rad)
    
    local function getPoint(dx, dy, dz)
        local rx, ry = dx * cosRot - dy * sinRot, dx * sinRot + dy * cosRot
        return vector3(coords.x + rx, coords.y + ry, coords.z + dz)
    end
    
    local p = {
        getPoint(-w, -l, -h), getPoint(w, -l, -h), getPoint(w, l, -h), getPoint(-w, l, -h),
        getPoint(-w, -l, h), getPoint(w, -l, h), getPoint(w, l, h), getPoint(-w, l, h)
    }
    
    local r, g, b = 255, 0, 0
    -- Bottom & Top Lines
    for i=1, 4 do 
        DrawLine(p[i], p[i%4+1], r,g,b, 255) 
        DrawLine(p[i+4], p[(i%4)+5], r,g,b, 255) 
        DrawLine(p[i], p[i+4], r,g,b, 255) -- Pillars
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
        
        DrawLine(b1, b2, r,g,b, 255) -- Bottom
        DrawLine(t1, t2, r,g,b, 255) -- Top
        DrawLine(b1, t1, r,g,b, 255) -- Pillars
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
            
            for _, zone in pairs(TargetAPI.Zones) do
                if zone.debug then
                    hasActive = true
                    -- Optimization: Only draw if within 50 units
                    local checkCoord = zone.type == 'poly' and zone.data.points[1] or zone.coords
                    if #(plyCoords - checkCoord) < 50.0 then
                        if zone.type == 'box' then DrawBoxDebug(zone.coords, zone.data.size, zone.data.rotation)
                        elseif zone.type == 'sphere' then DrawSphereDebug(zone.coords, zone.data.radius)
                        elseif zone.type == 'poly' then DrawPolyDebug(zone.data.points, zone.data.minZ, zone.data.maxZ) end
                    end
                end
            end
            if not hasActive then isDebugging = false end -- Sleep thread if no debug zones exist
        end
    end)
end

-- ==========================================
-- ZONE MATHEMATICS (Unchanged)
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

local function isPointInBox(point, boxCenter, size, rotation)
    local rad = math.rad(-rotation)
    local cosRot, sinRot = math.cos(rad), math.sin(rad)
    local dx, dy = point.x - boxCenter.x, point.y - boxCenter.y
    local rotX, rotY = dx * cosRot - dy * sinRot, dx * sinRot + dy * cosRot
    return math.abs(rotX) <= (size.x / 2) and math.abs(rotY) <= (size.y / 2)
end

function createZone(zoneType, coords, options, customData)
    zoneIdCounter = zoneIdCounter + 1
    local id = "zone_"..zoneIdCounter
    TargetAPI.Zones[id] = {
        id = id, type = zoneType, coords = coords, options = options,
        data = customData, 
        debug = customData.debug, -- New: Stores the debug flag
        resource = GetInvokingResource() or "ak47_target"
    }
    
    if customData.debug then StartDebugThread() end
    return id
end

function GetNearbyZones(playerCoords)
    local active = {}
    for id, zone in pairs(TargetAPI.Zones) do
        if zone.type == 'sphere' then
            if #(playerCoords - zone.coords) <= zone.data.radius then table.insert(active, zone) end
        elseif zone.type == 'box' then
            local zDiff = math.abs(playerCoords.z - zone.coords.z)
            if zDiff <= (zone.data.size.z or 2.0) and isPointInBox(playerCoords, zone.coords, zone.data.size, zone.data.rotation) then table.insert(active, zone) end
        elseif zone.type == 'poly' then
            local zValid = true
            if zone.data.minZ and playerCoords.z < zone.data.minZ then zValid = false end
            if zone.data.maxZ and playerCoords.z > zone.data.maxZ then zValid = false end
            if zValid and zone.data.points and #zone.data.points >= 3 and isPointInPolygon(playerCoords, zone.data.points) then table.insert(active, zone) end
        end
    end
    return active
end