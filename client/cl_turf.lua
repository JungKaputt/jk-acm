local QBCore = exports['qb-core']:GetCoreObject()
local Turfs = {}
local TurfStatus = {}
local TurfBlips = {}
local BlipCache = {}
local MyOrgId = 0
local CurrentZone = nil 

RegisterCommand('turf', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        QBCore.Functions.Notify("You cannot do this inside a vehicle!", "error")
        return
    end

    if CurrentZone then
        TriggerServerEvent('jk-acm:server:InitiateWar', CurrentZone)
    else
        QBCore.Functions.Notify("You are not inside any Turf Zone!", "error")
    end
end)

local function UpdateTurfBlips(forceUpdate)
    if not Config or not Config.TurfZones then return end
    
    for k, zone in pairs(Config.TurfZones) do
        local idNum = tonumber(k)
        local turfData = Turfs[k] or Turfs[idNum] or {}
        local ownerId = tonumber(turfData.owner) or 0
        local ownerName = turfData.ownerName or "Neutral"
        
        local color = 39 
        local typeName = "[Neutral]"

        if ownerId > 0 then
            typeName = "[" .. string.upper(ownerName) .. "]"
            if MyOrgId > 0 and MyOrgId == ownerId then
                color = 2
            else
                color = 1
            end
        end

        local blipName = zone.label .. " " .. typeName
        local stateHash = string.format("%d-%d", ownerId, color)

        if forceUpdate then BlipCache[k] = nil end

        if not TurfBlips[k] then
            TurfBlips[k] = {}
            local rBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius + 0.0)
            SetBlipAlpha(rBlip, 60)
            SetBlipColour(rBlip, color)
            TurfBlips[k].radius = rBlip
            
            local cBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(cBlip, 437)
            SetBlipScale(cBlip, 0.7)
            SetBlipColour(cBlip, color)
            SetBlipAsShortRange(cBlip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(blipName)
            EndTextCommandSetBlipName(cBlip)
            TurfBlips[k].icon = cBlip
            BlipCache[k] = stateHash
        else
            if BlipCache[k] ~= stateHash then
                SetBlipColour(TurfBlips[k].radius, color)
                SetBlipColour(TurfBlips[k].icon, color)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(blipName)
                EndTextCommandSetBlipName(TurfBlips[k].icon)
                BlipCache[k] = stateHash
            end
        end
    end
end

local function InitialLoad()
    QBCore.Functions.TriggerCallback('jk-acm:server:GetTurfData', function(serverTurfs)
        if serverTurfs then
            Turfs = serverTurfs
            UpdateTurfBlips(false)
        end
    end)
    TriggerServerEvent('jk-acm:client:RequestWarStatus')
    TriggerServerEvent('jk-acm:server:RequestTurfSync')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    InitialLoad()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Wait(1000)
    InitialLoad()
end)

RegisterNetEvent('jk-acm:client:SyncTurfs', function(serverTurfs)
    Turfs = serverTurfs or {}
    UpdateTurfBlips(false)
end)

RegisterNetEvent('jk-acm:client:UpdateWarStatus', function(status)
    TurfStatus = status or {}
end)

RegisterNetEvent('jk-acm:client:UpdateMyOrg', function(id)
    MyOrgId = tonumber(id) or 0
    UpdateTurfBlips(true)
end)

local function DrawTxt(text, x, y, scale, font, r, g, b, align)
    SetTextFont(font)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    if align == 'center' then SetTextCentre(true) end
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function DrawModernTurfUI(label, progress, contested, shieldTime, ownerName, ownerId, attackerId, ownerCount, attackerCount)
    local now = GetCloudTimeAsInt()
    local isShielded = shieldTime > now
    local currentOwner = ownerName or "Neutral"
    local ownerIdNum = tonumber(ownerId) or 0
    local isOwner = (MyOrgId > 0 and MyOrgId == ownerIdNum)
    local isAttacker = (MyOrgId > 0 and MyOrgId == attackerId)
    
    local baseX, baseY = 0.5, 0.90 
    local width, height = 0.15, 0.07

    local r, g, b = 200, 200, 200 
    if isShielded then r, g, b = 50, 150, 255
    elseif contested then r, g, b = 255, 50, 50
    elseif isOwner then r, g, b = 50, 200, 100
    elseif ownerIdNum > 0 then r, g, b = 200, 80, 80 end

    DrawRect(baseX, baseY, width, height, 15, 15, 15, 220)
    DrawRect(baseX, baseY - (height/2) + 0.002, width, 0.004, r, g, b, 255)

    if isShielded then
        local mins = math.ceil((shieldTime - now) / 60)
        DrawTxt(label, baseX, baseY - 0.025, 0.35, 4, 255, 255, 255, 'center')
        DrawTxt("🛡️ SHIELD ACTIVE (" .. mins .. "m)", baseX, baseY, 0.28, 0, 100, 200, 255, 'center')
        DrawTxt("Owner: " .. currentOwner, baseX, baseY + 0.015, 0.25, 0, 180, 180, 180, 'center')
    else
        DrawTxt(label, baseX, baseY - 0.025, 0.35, 4, 255, 255, 255, 'center')

        local barW, barH, barY = width - 0.02, 0.008, baseY + 0.005
        DrawRect(baseX, barY, barW, barH, 40, 40, 40, 255)
        
        local safeProgress = math.max(0, math.min(100, progress))
        if safeProgress > 0 then
            local fillWidth = (safeProgress / 100) * barW
            local fillX = baseX - (barW / 2) + (fillWidth / 2)
            DrawRect(fillX, barY, fillWidth, barH, r, g, b, 255)
        end

        local statusText = ""
        
        local isEqualForce = (attackerCount > 0 and ownerCount > 0 and attackerCount == ownerCount)

        if MyOrgId == 0 then 
            statusText = "NEUTRAL OBSERVER"
        elseif isEqualForce then
             statusText = "~y~CONTESTED" 
        elseif isOwner then
            if attackerId > 0 then
                 if contested then statusText = "~r~UNDER ATTACK!"
                 else statusText = "~g~RECOVERING (" .. math.floor(safeProgress) .. "%)" end
            else
                 statusText = "~g~SECURED AREA"
            end
        else
            if attackerId > 0 then
                if isAttacker then
                    statusText = "ATTACKING " .. math.floor(safeProgress) .. "%"
                else
                    statusText = "WAR IN PROGRESS"
                end
            else
                statusText = "PRESS /TURF TO ATTACK"
            end
        end
        
        DrawTxt(statusText, baseX, baseY + 0.015, 0.26, 0, 200, 200, 200, 'center')
    end
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local foundZone = nil
        if Config and Config.TurfZones then
            for k, zone in pairs(Config.TurfZones) do
                local dist = #(coords - zone.coords)
                if dist < zone.radius then
                    foundZone = k
                    break
                end
            end
        end
        CurrentZone = foundZone
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        if CurrentZone then
            sleep = 0
            local k = CurrentZone
            local zone = Config.TurfZones[k]
            local idNum = tonumber(k)
            local turfData = Turfs[k] or Turfs[idNum] or { shield = 0, ownerName = "Neutral", owner = 0 }
            local status = TurfStatus[k] or TurfStatus[idNum] or { progress = 0, isContested = false, attacker = 0, ownerCount = 0, attackerCount = 0 }
            
            DrawModernTurfUI(zone.label, status.progress, status.isContested, turfData.shield, turfData.ownerName, turfData.owner, status.attacker, status.ownerCount, status.attackerCount)
        end
        Wait(sleep)
    end
end)