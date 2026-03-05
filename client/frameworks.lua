-- ak47_target/client/frameworks.lua

local QBCore = GetResourceState('qb-core') == 'started' and exports['qb-core']:GetCoreObject() or nil
local ESX = GetResourceState('es_extended') == 'started' and exports['es_extended']:getSharedObject() or nil
local QBX = GetResourceState('qbx_core') == 'started' and exports.qbx_core or nil
local usingOxInventory = GetResourceState('ox_inventory') == 'started'

Utils = Utils or {}

function Utils.HasGroup(filter)
    if not filter then return true end
    local _type = type(filter)

    if QBX then
        return QBX:HasGroup(filter)
    elseif QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData then return false end
        if _type == 'string' then
            return (PlayerData.job and PlayerData.job.name == filter) or 
                   (PlayerData.gang and PlayerData.gang.name == filter) or 
                   (PlayerData.citizenid == filter)
        elseif _type == 'table' then
            local tabletype = table.type(filter)
            if tabletype == 'hash' then
                for name, grade in pairs(filter) do
                    if (PlayerData.job and PlayerData.job.name == name and PlayerData.job.grade.level >= grade) or
                       (PlayerData.gang and PlayerData.gang.name == name and PlayerData.gang.grade.level >= grade) or
                       (PlayerData.citizenid == name) then
                        return true
                    end
                end
            elseif tabletype == 'array' then
                for i = 1, #filter do
                    local name = filter[i]
                    if (PlayerData.job and PlayerData.job.name == name) or
                       (PlayerData.gang and PlayerData.gang.name == name) or
                       (PlayerData.citizenid == name) then
                        return true
                    end
                end
            end
        end
        return false
    elseif ESX then
        local PlayerData = ESX.GetPlayerData()
        if not PlayerData or not PlayerData.job then return false end
        if _type == 'string' then
            return PlayerData.job.name == filter
        elseif _type == 'table' then
            local tabletype = table.type(filter)
            if tabletype == 'hash' then
                for name, grade in pairs(filter) do
                    if PlayerData.job.name == name and PlayerData.job.grade >= grade then return true end
                end
            elseif tabletype == 'array' then
                for i = 1, #filter do
                    if PlayerData.job.name == filter[i] then return true end
                end
            end
        end
        return false
    else
        return true 
    end
end

function Utils.HasItem(items, hasAny)
    if not items then return true end
    local _type = type(items)

    if usingOxInventory then
        if _type == 'string' then
            return exports.ox_inventory:Search('count', items) > 0
        elseif _type == 'table' then
            for k, v in pairs(items) do
                local itemName = type(k) == 'number' and v or k
                local requiredAmount = type(k) == 'number' and 1 or v
                local hasThisItem = exports.ox_inventory:Search('count', itemName) >= requiredAmount
                if hasAny then
                    if hasThisItem then return true end
                else
                    if not hasThisItem then return false end
                end
            end
            return not hasAny
        end
        return false
    elseif QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData or not PlayerData.items then return false end
        local function getItemCount(itemName)
            local count = 0
            for _, item in pairs(PlayerData.items) do
                if item.name == itemName then count = count + item.amount end
            end
            return count
        end
        if _type == 'string' then
            return getItemCount(items) > 0
        elseif _type == 'table' then
            for k, v in pairs(items) do
                local itemName = type(k) == 'number' and v or k
                local requiredAmount = type(k) == 'number' and 1 or v
                local hasThisItem = getItemCount(itemName) >= requiredAmount
                if hasAny then
                    if hasThisItem then return true end
                else
                    if not hasThisItem then return false end
                end
            end
            return not hasAny
        end
        return false
    else
        return true 
    end
end