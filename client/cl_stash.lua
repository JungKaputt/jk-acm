local QBCore = exports['qb-core']:GetCoreObject()
local ServerStashes = {}
local StashProps = {}
local isPlacing = false
local PlacementProp = nil

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('jk-acm:server:ReloadStashes')
end)

RegisterNetEvent('jk-acm:client:SyncStashes', function(data)
    ServerStashes = data
    RefreshStashProps()
end)

RegisterNetEvent('jk-acm:client:ForceStashRefresh', function()
    SendNUIMessage({
        action = "refreshStash"
    })
end)

CreateThread(function()
    Wait(2000) 
    QBCore.Functions.TriggerCallback('jk-acm:server:GetStashes', function(data)
        ServerStashes = data or {}
        RefreshStashProps()
    end)
end)

function RefreshStashProps()
    for _, prop in pairs(StashProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    StashProps = {}

    local model = GetHashKey(Config.Stash.PropModel)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    for _, stash in pairs(ServerStashes) do
        if stash.coords and stash.coords.x then
            local coords = vector3(stash.coords.x, stash.coords.y, stash.coords.z) 
            local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
            SetEntityCollision(obj, false, false)
            SetEntityCoords(obj, coords.x, coords.y, coords.z)
            SetEntityHeading(obj, stash.coords.w or 0.0)
            FreezeEntityPosition(obj, true)
            SetEntityCollision(obj, true, true)
            SetEntityInvincible(obj, true)
            table.insert(StashProps, obj)
        end
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, prop in pairs(StashProps) do DeleteEntity(prop) end
        if DoesEntityExist(PlacementProp) then DeleteEntity(PlacementProp) end
    end
end)

RegisterNetEvent('jk-acm:client:UseStashItem', function()
    if isPlacing then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    StartPlacementLoop()
end)

function StartPlacementLoop()
    isPlacing = true
    local ped = PlayerPedId()
    local model = GetHashKey(Config.Stash.PropModel)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local pCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.0, 0.0)
    PlacementProp = CreateObject(model, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    SetEntityAlpha(PlacementProp, 200, false)
    SetEntityCollision(PlacementProp, false, false)
    local zOffset = 0.0
    local manualHeading = GetEntityHeading(ped)

    QBCore.Functions.Notify("ARROWS: Position | E: Confirm | ESC: Cancel", "primary", 5000)

    CreateThread(function()
        while isPlacing do
            Wait(0)
            DisableControlAction(0, 24, true); DisableControlAction(0, 142, true)
            local hit, coords, _ = RayCastGamePlayCamera(10.0)
            if hit then
                if IsControlPressed(0, 174) then manualHeading = manualHeading - 1.0 end
                if IsControlPressed(0, 175) then manualHeading = manualHeading + 1.0 end
                if IsControlPressed(0, 172) then zOffset = zOffset + 0.01 end
                if IsControlPressed(0, 173) then zOffset = zOffset - 0.01 end
                
                local finalX = coords.x; local finalY = coords.y; local finalZ = coords.z + zOffset
                SetEntityCoords(PlacementProp, finalX, finalY, finalZ)
                SetEntityHeading(PlacementProp, manualHeading)

                if IsControlJustPressed(0, 38) then
                    local finalCoords = {x=finalX, y=finalY, z=finalZ, w=manualHeading}
                    OpenPinSetup(finalCoords)
                    isPlacing = false
                    DeleteEntity(PlacementProp)
                end
                if IsControlJustPressed(0, 177) then 
                    isPlacing = false; DeleteEntity(PlacementProp) 
                end
            end
        end
    end)
end

function RayCastGamePlayCamera(distance)
    local rot = GetGameplayCamRot(); local coord = GetGameplayCamCoord()
    local tZ = (math.pi/180)*rot.z; local tX = (math.pi/180)*rot.x
    local num = math.abs(math.cos(tX))
    local dir = {x = -math.sin(tZ)*num, y = math.cos(tZ)*num, z = math.sin(tX)}
    local dest = {x = coord.x + dir.x*distance, y = coord.y + dir.y*distance, z = coord.z + dir.z*distance}
    local _, hit, endCoords, _, _ = GetShapeTestResult(StartShapeTestRay(coord.x, coord.y, coord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0))
    return hit, endCoords, 0
end

function OpenPinSetup(coords)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openPinSetup",
        coords = coords
    })
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        for _, stash in pairs(ServerStashes) do
            if stash.coords then
                local stashPos = vector3(stash.coords.x, stash.coords.y, stash.coords.z)
                if #(coords - stashPos) < 2.0 then
                    sleep = 0
                    DrawText3D(stashPos.x, stashPos.y, stashPos.z + 1.2, "[E] Open Safe")
                    if IsControlJustPressed(0, 38) then
                        AttemptOpenStash(stash.id)
                        Wait(1000)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function AttemptOpenStash(stashId)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openPinAuth",
        stashId = stashId
    })
end

function DrawText3D(x, y, z, text)
	SetTextScale(0.35, 0.35); SetTextFont(4); SetTextProportional(1); SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING"); SetTextCentre(true); AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0); DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75); ClearDrawOrigin()
end

RegisterNUICallback('closeStashUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('finalizeStashSetup', function(data, cb)
    SetNuiFocus(false, false)
    if data.coords and data.pin then
        TriggerServerEvent('jk-acm:server:SaveStash', { coords = data.coords, pin = data.pin })
    end
    cb('ok')
end)

RegisterNUICallback('verifyStashAuth', function(data, cb)
    if data.stashId and data.pin then
        QBCore.Functions.TriggerCallback('jk-acm:server:VerifyStashPin', function(isCorrect)
            if isCorrect then
                PlaySoundFrontend(-1, "SAFE_DOOR_OPEN", "SAFE_CRACK_SOUNDSET", true)
                local label = "Org Safe #" .. data.stashId
                
                TriggerEvent('jk-acm:client:OpenCustomStash', data.stashId, label)
            else
                QBCore.Functions.Notify("Incorrect PIN", "error")
            end
        end, data.stashId, data.pin)
    end
    cb('ok')
end)

RegisterNetEvent('jk-acm:client:OpenCustomStash', function(stashId, stashLabel)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openStashWindow",
        id = stashId,
        label = stashLabel
    })
end)