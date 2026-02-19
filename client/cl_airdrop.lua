local QBCore = exports['qb-core']:GetCoreObject()
local ActiveDrops = {} 

local PlaneConfig = {
    Model = "cuban800", 
    Speed = 50.0,     
    Height = 350.0,    
    Distance = 2000.0   
}

RegisterNetEvent('jk-acm:client:StartAirdropGlobal', function(dropId, dropCoordsData, itemLabel, isBuyer, isOrgMember)

    local dropCoords = vector3(dropCoordsData.x, dropCoordsData.y, dropCoordsData.z)
    
    ActiveDrops[dropId] = {
        coords = dropCoords,
        label = itemLabel,
        blip = nil
    }

    if isOrgMember then
        local blip = AddBlipForCoord(dropCoords.x, dropCoords.y, dropCoords.z)
        SetBlipSprite(blip, 94) 
        SetBlipColour(blip, 1) 
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Drop Zone: " .. itemLabel)
        EndTextCommandSetBlipName(blip)
        SetBlipRoute(blip, true)
        
        ActiveDrops[dropId].blip = blip

        if isBuyer then
            QBCore.Functions.Notify("PILOT: Coordinates received. Inbound.", "success", 5000)
        end
    end

    Citizen.CreateThread(function()
        print("[DEBUG] Memulai Thread Pesawat...")
        
        local planeHash = GetHashKey(PlaneConfig.Model)
        local pilotHash = GetHashKey("s_m_m_pilot_01")
        
        RequestModel(planeHash)
        RequestModel(pilotHash)
        
        local timeout = 0
        while not HasModelLoaded(planeHash) or not HasModelLoaded(pilotHash) do 
            Wait(100)
            timeout = timeout + 1
            if timeout > 100 then 
                return 
            end
        end

        local randomHeading = math.random(0, 360) + 0.0
        local theta = math.rad(randomHeading)
        
        local spawnX = dropCoords.x + (math.cos(theta) * PlaneConfig.Distance)
        local spawnY = dropCoords.y + (math.sin(theta) * PlaneConfig.Distance)
        local spawnZ = dropCoords.z + PlaneConfig.Height
        local spawnCoords = vector3(spawnX, spawnY, spawnZ)

        local endX = dropCoords.x - (math.cos(theta) * PlaneConfig.Distance)
        local endY = dropCoords.y - (math.sin(theta) * PlaneConfig.Distance)
        local endCoords = vector3(endX, endY, spawnZ)

        print("[DEBUG] Spawning Plane at: " .. spawnCoords)

        local plane = CreateVehicle(planeHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, randomHeading, false, true)
        
        if DoesEntityExist(plane) then
            print("[DEBUG] Pesawat Berhasil Spawn! ID: " .. plane)
            
            SetEntityAsMissionEntity(plane, true, true)
            SetEntityLodDist(plane, 2000) 
            SetEntityInvincible(plane, true)
            SetVehicleEngineOn(plane, true, true, false)
            SetVehicleForwardSpeed(plane, PlaneConfig.Speed)
            ControlLandingGear(plane, 3) 
            SetEntityCoords(plane, spawnCoords.x, spawnCoords.y, spawnCoords.z) 

            local pilot = CreatePed(4, pilotHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, randomHeading, false, true)
            SetPedIntoVehicle(pilot, plane, -1)
            SetBlockingOfNonTemporaryEvents(pilot, true)

            if isOrgMember then
                local planeBlip = AddBlipForEntity(plane)
                SetBlipSprite(planeBlip, 307)
                SetBlipColour(planeBlip, 3) 
                SetBlipScale(planeBlip, 0.8)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Cargo Plane")
                EndTextCommandSetBlipName(planeBlip)
            end

            TaskVehicleDriveToCoord(pilot, plane, dropCoords.x, dropCoords.y, spawnZ, PlaneConfig.Speed, 0, planeHash, 262144, 15.0, true)

            local hasDropped = false
            
            while DoesEntityExist(plane) do
                local planeCoords = GetEntityCoords(plane)
                local distToDrop = #(vector2(planeCoords.x, planeCoords.y) - vector2(dropCoords.x, dropCoords.y))

                if distToDrop % 500 < 10 then 
                end

                if distToDrop < 100.0 and not hasDropped then
                    hasDropped = true
                    
                    if isBuyer then
                        SpawnCrateNetworked(dropId, dropCoords)
                    end
                    
                    TaskVehicleDriveToCoord(pilot, plane, endCoords.x, endCoords.y, spawnZ, PlaneConfig.Speed, 0, planeHash, 262144, 20.0, true)
                end

                local distToEnd = #(vector2(planeCoords.x, planeCoords.y) - vector2(endCoords.x, endCoords.y))
                if distToEnd < 100.0 or #(planeCoords - dropCoords) > (PlaneConfig.Distance + 200.0) then
                    print("[DEBUG] Plane Despawned (Out of range)")
                    DeleteEntity(pilot)
                    DeleteEntity(plane)
                    break
                end

                Wait(500)
            end
        else
            print("[DEBUG-ERROR] Gagal CreateVehicle! (Mungkin area spawn invalid/conflict)")
        end
    end)
end)

function SpawnCrateNetworked(dropId, dropCoords)
    Citizen.CreateThread(function()
        local crateModel = GetHashKey("prop_box_wood02a_pu")
        local chuteModel = GetHashKey("p_cargo_chute_s")
        
        RequestModel(crateModel)
        RequestModel(chuteModel)
        while not HasModelLoaded(crateModel) or not HasModelLoaded(chuteModel) do Wait(10) end

        local spawnZ = dropCoords.z + PlaneConfig.Height - 15.0
        
        local CrateObject = CreateObject(crateModel, dropCoords.x, dropCoords.y, spawnZ, true, true, true)
        local parachute = CreateObject(chuteModel, dropCoords.x, dropCoords.y, spawnZ, true, true, true)
        
        SetEntityLodDist(CrateObject, 2000) 
        ActivatePhysics(CrateObject)
        SetDamping(CrateObject, 2, 0.1)
        SetEntityVelocity(CrateObject, 0.0, 0.0, -15.0) 
        
        SetEntityInvincible(CrateObject, true) 
        SetEntityCanBeDamaged(CrateObject, false)
        SetEntityProofs(CrateObject, true, true, true, true, true, true, 1, true)

        AttachEntityToEntity(parachute, CrateObject, 0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)       

        local landed = false
        while not landed do
            if not DoesEntityExist(CrateObject) then break end
            
            local currentPos = GetEntityCoords(CrateObject)
            local groundZ = 0.0
            local foundGround, zPos = GetGroundZFor_3dCoord(currentPos.x, currentPos.y, currentPos.z, 0)
            
            if foundGround and (currentPos.z - zPos) < 2.5 then
                landed = true
                
                DetachEntity(parachute, true, true)
                DeleteEntity(parachute)
                
                SetEntityCoords(CrateObject, currentPos.x, currentPos.y, zPos)
                PlaceObjectOnGroundProperly(CrateObject)
                FreezeEntityPosition(CrateObject, true) 
                
                TriggerEvent('jk-acm:client:DropLandedEffect', vector3(currentPos.x, currentPos.y, zPos))
            end
            Wait(50)
        end
    end)
end

RegisterNetEvent('jk-acm:client:DropLandedEffect', function(coords)
    local ptDict = "core"
    local ptName = "exp_grd_flare"
    RequestNamedPtfxAsset(ptDict)
    while not HasNamedPtfxAssetLoaded(ptDict) do Wait(0) end
    UseParticleFxAssetNextCall(ptDict)
    StartParticleFxLoopedAtCoord(ptName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
end)

RegisterNetEvent('jk-acm:client:AirdropTaken', function(dropId)
    print("[DEBUG] Cleanup Airdrop ID: " .. dropId)
    
    if ActiveDrops[dropId] then
        if ActiveDrops[dropId].blip then RemoveBlip(ActiveDrops[dropId].blip) end
        
        local dropCoords = ActiveDrops[dropId].coords
        local crateModel = GetHashKey("prop_box_wood02a_pu")
        
        local object = GetClosestObjectOfType(dropCoords.x, dropCoords.y, dropCoords.z, 20.0, crateModel, false, false, false)
        if DoesEntityExist(object) then
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            print("[DEBUG] Crate Object Deleted.")
        end

        ActiveDrops[dropId] = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        for id, data in pairs(ActiveDrops) do
            local dist = #(pos - data.coords)
            
            if dist < 50.0 then 
                local crateModel = GetHashKey("prop_box_wood02a_pu")
                local object = GetClosestObjectOfType(data.coords.x, data.coords.y, data.coords.z, 10.0, crateModel, false, false, false)

                if DoesEntityExist(object) then
                    local objCoords = GetEntityCoords(object)
                    local distObj = #(pos - objCoords)
                    
                    if distObj < 8.0 then
                        sleep = 0
                        DrawText3D(objCoords.x, objCoords.y, objCoords.z + 1.0, "[E] Retrieve " .. (data.label or "Package"))

                        if IsControlJustPressed(0, 38) and distObj < 2.5 then
                            QBCore.Functions.Progressbar("pickup_airdrop", "Opening Package...", 5000, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {
                                animDict = "amb@medic@standing@kneel@base",
                                anim = "base",
                                flags = 1,
                            }, {}, {}, function() 
                                TriggerServerEvent('jk-acm:server:ClaimPackage', id)
                                ClearPedTasks(ped)
                            end, function() 
                                QBCore.Functions.Notify("Cancelled!", "error")
                                ClearPedTasks(ped)
                            end)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function DrawText3D(x, y, z, text)
	SetTextScale(0.35, 0.35); SetTextFont(4); SetTextProportional(1); SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING"); SetTextCentre(true); AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0); DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75); ClearDrawOrigin()
end