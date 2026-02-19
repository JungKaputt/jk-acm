local laptopProp = nil
local laptopModel = "prop_laptop_01a"
local animDict = "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a"
local animName = "idle_a"

function LoadPhoneAnim()
    local ped = PlayerPedId()

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(0) end
    
    RequestModel(laptopModel)
    while not HasModelLoaded(laptopModel) do Wait(0) end

    if not laptopProp then
        laptopProp = CreateObject(GetHashKey(laptopModel), 0, 0, 0, true, true, true)
        AttachEntityToEntity(laptopProp, ped, GetPedBoneIndex(ped, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
        
        AttachEntityToEntity(laptopProp, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, -0.05, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    end
    
    TaskPlayAnim(ped, animDict, animName, 3.0, -1, -1, 49, 0, false, false, false)
end

function UnloadPhoneAnim()
    local ped = PlayerPedId()
    StopAnimTask(ped, animDict, animName, 1.0)
    if laptopProp then
        DeleteEntity(laptopProp)
        laptopProp = nil
    end
end