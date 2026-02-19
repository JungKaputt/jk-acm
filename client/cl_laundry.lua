local QBCore = exports['qb-core']:GetCoreObject()
local LaundryPed = nil
local LaundryBlip = nil
local isLaundryActive = false
local MissionCoords = nil

RegisterNetEvent('jk-acm:client:SetupLaundryMission', function(coords)
    if isLaundryActive then
        QBCore.Functions.Notify("You still have an active contract!", "error")
        return
    end

    MissionCoords = coords
    isLaundryActive = true

    if DoesBlipExist(LaundryBlip) then RemoveBlip(LaundryBlip) end
    LaundryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(LaundryBlip, 500) 
    SetBlipColour(LaundryBlip, 2) 
    SetBlipRoute(LaundryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Courier Contact")
    EndTextCommandSetBlipName(LaundryBlip)

    CreateThread(function()
        while isLaundryActive do
            local sleep = 1000
            local ped = PlayerPedId()
            local myCoords = GetEntityCoords(ped)
            local dist = #(myCoords - vector3(coords.x, coords.y, coords.z))

            if dist < 50.0 and not DoesEntityExist(LaundryPed) then
                local model = GetHashKey(Config.Laundry.PedModel)
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(0) end
                
                LaundryPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
                SetEntityInvincible(LaundryPed, true)
                FreezeEntityPosition(LaundryPed, true) 
                SetBlockingOfNonTemporaryEvents(LaundryPed, true) 
                TaskStartScenarioInPlace(LaundryPed, "WORLD_HUMAN_STAND_MOBILE", 0, true) 
            end

            if dist < 3.0 and DoesEntityExist(LaundryPed) then
                sleep = 0
                DrawText3D(coords.x, coords.y, coords.z + 1.0, "[E] Submit the Package")
                
                if IsControlJustPressed(0, 38) then
                    ProcessLaundry()
                end
            end
            
            Wait(sleep)
        end
    end)
end)

function ProcessLaundry()
    local ped = PlayerPedId()
    
    FreezeEntityPosition(LaundryPed, false)
    TaskTurnPedToFaceEntity(LaundryPed, ped, 1000)
    Wait(1000)
    
    QBCore.Functions.Progressbar("laundering_money", "Exchange the Bag...", Config.Laundry.InteractionTime, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "misscarsteal4@actor",
        anim = "actor_berating_loop", 
        flags = 16,
    }, {}, {}, function() 
        TriggerServerEvent('jk-acm:server:FinishLaundry')
        CleanupLaundry() 
    end, function() 
        QBCore.Functions.Notify("Transaction Cancelled", "error")
    end)
end

function CleanupLaundry()
    isLaundryActive = false
    
    if DoesBlipExist(LaundryBlip) then RemoveBlip(LaundryBlip) end
    
    if DoesEntityExist(LaundryPed) then
        SetEntityAsNoLongerNeeded(LaundryPed)
        
        FreezeEntityPosition(LaundryPed, false)
        SetBlockingOfNonTemporaryEvents(LaundryPed, false)
        SetEntityInvincible(LaundryPed, false)
        
        ClearPedTasks(LaundryPed)
        TaskWanderStandard(LaundryPed, 10.0, 10)
        
        PlayPedAmbientSpeechNative(LaundryPed, "GENERIC_BYE", "SPEECH_PARAMS_FORCE_NORMAL")
        
        LaundryPed = nil 
    end
end

function DrawText3D(x, y, z, text)
	SetTextScale(0.35, 0.35); SetTextFont(4); SetTextProportional(1); SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING"); SetTextCentre(true); AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0); DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75); ClearDrawOrigin()
end