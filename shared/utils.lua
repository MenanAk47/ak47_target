Utils = {}

local function RotationToDirection(rotation)
    local rad = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    return {
        x = -math.sin(rad.z) * math.abs(math.cos(rad.x)),
        y =  math.cos(rad.z) * math.abs(math.cos(rad.x)),
        z =  math.sin(rad.x)
    }
end

function Utils.TableClone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Utils.TableClone(orig_key)] = Utils.TableClone(orig_value)
        end
        setmetatable(copy, Utils.TableClone(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function Utils.RaycastCamera(distance, flags, ignore)
    local currentRenderingCam = false
    if not IsGameplayCamRendering() then
        currentRenderingCam = GetRenderingCam()
    end
    local camRot = not currentRenderingCam and GetGameplayCamRot(2) or GetCamRot(currentRenderingCam, 2)
    local camCoord = not currentRenderingCam and GetGameplayCamCoord() or GetCamCoord(currentRenderingCam)
    local dir = RotationToDirection(camRot)
    local dst = {
        x = camCoord.x + dir.x * distance,
        y = camCoord.y + dir.y * distance,
        z = camCoord.z + dir.z * distance
    }
    local rayHandle = StartShapeTestRay(
        camCoord.x, camCoord.y, camCoord.z,
        dst.x, dst.y, dst.z,
        flags or 511,
        ignore or PlayerPedId(), 4
    )
    local _, bHit, vHitCoords, _, hEntity = GetShapeTestResult(rayHandle)
    return bHit == 1, hEntity, vHitCoords
end
