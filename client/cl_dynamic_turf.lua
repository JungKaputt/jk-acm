local QBCore = exports['qb-core']:GetCoreObject()
local DynamicTurfs = {}
local SpawnedFlags = {}
local FlagBlips = {}
local MyOrgId = 0
local isPlacingFlag = false

RegisterNetEvent('jk-acm:client:UpdateMyOrg', function(id)
    MyOrgId = tonumber(id) or 0
    RefreshFlagBlips()
end)

RegisterNetEvent('jk-acm:client:SyncDynamicTurfs', function(data)
    DynamicTurfs = data or {}
    RefreshFlags()
    RefreshFlagBlips()
end)

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

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

local function RayCastGamePlayCamera(distance)
    local rot = GetGameplayCamRot()
    local coord = GetGameplayCamCoord()
    local tZ = (math.pi/180) * rot.z
    local tX = (math.pi/180) * rot.x
    local num = math.abs(math.cos(tX))
    local dir = {x = -math.sin(tZ) * num, y = math.cos(tZ) * num, z = math.sin(tX)}
    local dest = {x = coord.x + dir.x * distance, y = coord.y + dir.y * distance, z = coord.z + dir.z * distance}
    local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(coord.x, coord.y, coord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0))
    return hit, endCoords
end

local function DrawDynamicTurfUI(label, progress, contested, shieldTime, ownerId, attackerId)
    local now = GetCloudTimeAsInt()
    local isShielded = shieldTime > now
    local isOwner = (MyOrgId > 0 and MyOrgId == ownerId)
    local isAttacker = (MyOrgId > 0 and MyOrgId == attackerId)
    
    local baseX, baseY = 0.5, 0.90 
    local width, height = 0.15, 0.07

    local r, g, b = 200, 200, 200 
    if isShielded then r, g, b = 50, 150, 255
    elseif contested then r, g, b = 255, 50, 50
    elseif isOwner then r, g, b = 50, 200, 100
    elseif ownerId > 0 then r, g, b = 200, 80, 80 end

    DrawRect(baseX, baseY, width, height, 15, 15, 15, 220)
    DrawRect(baseX, baseY - (height/2) + 0.002, width, 0.004, r, g, b, 255)

    if isShielded then
        local mins = math.ceil((shieldTime - now) / 60)
        DrawTxt(label, baseX, baseY - 0.025, 0.35, 4, 255, 255, 255, 'center')
        DrawTxt("🛡️ SHIELD ACTIVE (" .. mins .. "m)", baseX, baseY, 0.28, 0, 100, 200, 255, 'center')
        
        if isOwner then
            DrawTxt("Status: Secured", baseX, baseY + 0.015, 0.25, 0, 180, 180, 180, 'center')
        else
            DrawTxt("Status: Protected", baseX, baseY + 0.015, 0.25, 0, 180, 180, 180, 'center')
        end
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
        
        if MyOrgId == 0 then 
            statusText = "NEUTRAL OBSERVER"
        elseif isOwner then
            if attackerId > 0 then
                statusText = "~r~UNDER ATTACK!"
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
                statusText = "PRESS [E] AT FLAG TO ATTACK"
            end
        end
        
        DrawTxt(statusText, baseX, baseY + 0.015, 0.26, 0, 200, 200, 200, 'center')
    end
end

RegisterNetEvent('jk-acm:client:StartFlagPlacement', function()
    if isPlacingFlag then return end
    isPlacingFlag = true
    
    local ped = PlayerPedId()
    local propName = Config.DynamicTurf.PropModel or "prop_flagpole_2a"
    local model = GetHashKey(propName)
    
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do 
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then
            print("[ACM] ERROR: Model bendera gagal di-load!")
            isPlacingFlag = false
            return
        end
    end

    local pCoords = GetEntityCoords(ped)
    local PlacementProp = CreateObject(model, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    SetEntityAlpha(PlacementProp, 150, false)
    SetEntityCollision(PlacementProp, false, false)
    
    QBCore.Functions.Notify("E: Place Flag | BACKSPACE: Cancel", "primary", 5000)

    CreateThread(function()
        while isPlacingFlag do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 142, true)

            local hit, coords = RayCastGamePlayCamera(15.0)
            
            if hit and coords ~= vector3(0,0,0) then
                SetEntityCoords(PlacementProp, coords.x, coords.y, coords.z)
            else
                local forward = GetEntityForwardVector(ped)
                local fallBackPos = pCoords + (forward * 3.0)
                SetEntityCoords(PlacementProp, fallBackPos.x, fallBackPos.y, fallBackPos.z - 1.0)
            end

            if IsControlJustPressed(0, 38) then
                isPlacingFlag = false
                local finalCoords = GetEntityCoords(PlacementProp)
                DeleteEntity(PlacementProp)
                
                local finalCoordsT = {x = finalCoords.x, y = finalCoords.y, z = finalCoords.z, w = 0.0}
                TriggerServerEvent('jk-acm:server:PlaceDynamicTurf', finalCoordsT)
            end
            
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                isPlacingFlag = false
                DeleteEntity(PlacementProp)
                QBCore.Functions.Notify("Flag placement cancelled.", "error")
            end
        end
    end)
end)

function RefreshFlags()
    for orgId, prop in pairs(SpawnedFlags) do
        if not DynamicTurfs[orgId] then
            if DoesEntityExist(prop) then DeleteEntity(prop) end
            SpawnedFlags[orgId] = nil
        end
    end

    local model = GetHashKey(Config.DynamicTurf.PropModel)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do 
        Wait(100) 
        timeout = timeout + 1
        if timeout > 50 then return end
    end

    for orgId, turf in pairs(DynamicTurfs) do
        if not SpawnedFlags[orgId] then
            local prop = CreateObject(model, turf.coords.x, turf.coords.y, turf.coords.z, false, false, false)
            SetEntityCoords(prop, turf.coords.x, turf.coords.y, turf.coords.z)
            PlaceObjectOnGroundProperly(prop)
            FreezeEntityPosition(prop, true)
            SetEntityInvincible(prop, true)
            SpawnedFlags[orgId] = prop
        end
    end
end

function RefreshFlagBlips()
    for orgId, blip in pairs(FlagBlips) do
        if DoesBlipExist(blip.icon) then RemoveBlip(blip.icon) end
        if DoesBlipExist(blip.radius) then RemoveBlip(blip.radius) end
        FlagBlips[orgId] = nil
    end

    for orgId, turf in pairs(DynamicTurfs) do
        if MyOrgId > 0 and MyOrgId == orgId then
            local blip = AddBlipForCoord(turf.coords.x, turf.coords.y, turf.coords.z)
            SetBlipSprite(blip, 38)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Syndicate Headquarters")
            EndTextCommandSetBlipName(blip)
            
            local rBlip = AddBlipForRadius(turf.coords.x, turf.coords.y, turf.coords.z, Config.DynamicTurf.Radius or 50.0)
            SetBlipAlpha(rBlip, 60)
            SetBlipColour(rBlip, 2)
            
            FlagBlips[orgId] = { icon = blip, radius = rBlip }
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, prop in pairs(SpawnedFlags) do
            if DoesEntityExist(prop) then DeleteEntity(prop) end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        local closestTurf = nil
        local closestOrgId = nil
        local closestDist = 9999.0

        for orgId, turf in pairs(DynamicTurfs) do
            local tCoords = vector3(turf.coords.x, turf.coords.y, turf.coords.z)
            local dist = #(pos - tCoords)
            
            if dist < (Config.DynamicTurf.Radius or 100.0) then
                if dist < closestDist then
                    closestDist = dist
                    closestOrgId = orgId
                    closestTurf = turf
                end
            end
        end

        if closestTurf then
            sleep = 0
            local contested = closestTurf.attacker_id > 0
            local isMyTurf = (MyOrgId > 0 and MyOrgId == closestOrgId)
            
            local label = "Rival Syndicate Base"
            if isMyTurf then
                label = "Syndicate Headquarters"
            end

            if isMyTurf or contested then
                DrawDynamicTurfUI(label, closestTurf.progress, contested, closestTurf.shield, closestOrgId, closestTurf.attacker_id)
            end

            if not isMyTurf then
                if closestDist <= (Config.DynamicTurf.CaptureDistance or 5.0) then
                    local now = GetCloudTimeAsInt()
                    
                    if closestTurf.attacker_id == 0 and now > closestTurf.shield then
                        local tCoords = vector3(closestTurf.coords.x, closestTurf.coords.y, closestTurf.coords.z)
                        DrawText3D(tCoords.x, tCoords.y, tCoords.z + 1.5, "[E] Attack Territory")
                        
                        if IsControlJustPressed(0, 38) then
                            TriggerServerEvent('jk-acm:server:AttackDynamicTurf', closestOrgId)
                            Wait(1000)
                        end
                    elseif closestTurf.attacker_id == 0 and now <= closestTurf.shield then
                        local tCoords = vector3(closestTurf.coords.x, closestTurf.coords.y, closestTurf.coords.z)
                        DrawText3D(tCoords.x, tCoords.y, tCoords.z + 1.5, "~b~Shield is Active")
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)