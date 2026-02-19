local QBCore = exports['qb-core']:GetCoreObject()
local isPhoneOpen = false

local function ToggleACM()
    if isPhoneOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "close" })
        UnloadPhoneAnim()
        isPhoneOpen = false
    else
        QBCore.Functions.TriggerCallback('jk-acm:server:CanOpen', function(canOpen, data)
            if canOpen then
                LoadPhoneAnim()
                SetNuiFocus(true, true)
                SendNUIMessage({ 
                    action = "open", 
                    playerData = data,
                    createCost = Config.CreateCost
                })
                isPhoneOpen = true
            else
                QBCore.Functions.Notify("Access Denied.", "error")
            end
        end)
    end
end

RegisterCommand(Config.OpenCommand, function() ToggleACM() end)
RegisterKeyMapping(Config.OpenCommand, 'Open Criminal Phone', 'keyboard', Config.OpenKey)

RegisterNetEvent('jk-acm:client:ForceClose', function()
    if isPhoneOpen then ToggleACM() end
end)

RegisterNetEvent('jk-acm:client:RefreshOrg', function()
    if isPhoneOpen then
        SendNUIMessage({ action = "refreshData" })
    end
end)

RegisterNetEvent('jk-acm:client:OrgCreated', function()
    ToggleACM()
    Wait(500)
    ToggleACM()
end)

RegisterNetEvent('jk-acm:client:LaptopNotify', function(msg, type)
    SendNUIMessage({ action = "notify", msg = msg, type = type })
end)

RegisterNUICallback('close', function(data, cb)
    ToggleACM()
    cb('ok')
end)

RegisterNUICallback('createOrg', function(data, cb)
    TriggerServerEvent('jk-acm:server:CreateOrganization', data)
    cb('ok')
end)

RegisterNUICallback('getFullOrgData', function(_, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetFullOrgData', function(data) cb(data) end)
end)

RegisterNUICallback('treasuryAction', function(data, cb)
    TriggerServerEvent('jk-acm:server:TreasuryAction', data.type, data.amount)
    cb('ok')
end)

RegisterNUICallback('inviteMember', function(data, cb)
    TriggerServerEvent('jk-acm:server:InvitePlayer', data.targetId)
    cb('ok')
end)

RegisterNUICallback('leaveOrg', function(_, cb)
    TriggerServerEvent('jk-acm:server:LeaveOrg')
    cb('ok')
end)

RegisterNUICallback('manageMember', function(data, cb)
    TriggerServerEvent('jk-acm:server:ManageMember', data)
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('jk-acm:server:SaveSettings', data)
    cb('ok')
end)

RegisterNUICallback('getMarketItems', function(_, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetMarketItems', function(items) cb(items) end)
end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('jk-acm:server:BuyItem', data)
    cb('ok')
end)

RegisterNUICallback('getTurfData', function(_, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetTurfData', function(serverTurfs)
        local finalData = {}
        for id, zone in pairs(Config.TurfZones) do
            local sData = serverTurfs[id] or {}
            
            finalData[id] = { 
                label = zone.label, 
                ownerName = sData.ownerName or "Neutral", 
                isOwned = (sData.owner and sData.owner ~= 0), 
                shield = sData.shield or 0,
                
                logo = sData.logo,
                isContested = sData.isContested,
                progress = sData.progress
            }
        end
        cb(finalData)
    end)
end)

RegisterNUICallback('getDirtyMoney', function(_, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetDirtyMoney', function(amt) cb(amt) end)
end)

RegisterNUICallback('startLaundry', function(data, cb)
    TriggerServerEvent('jk-acm:server:StartLaundry', data.amount)
    cb('ok')
end)

RegisterNUICallback('disbandOrg', function(_, cb)
    TriggerServerEvent('jk-acm:server:DisbandOrg')
    cb('ok')
end)

RegisterNUICallback('getStashData', function(data, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetCustomStashData', function(result)
        cb(result)
    end, data.stashId)
end)

RegisterNUICallback('handleStashMove', function(data, cb)
    TriggerServerEvent('jk-acm:server:HandleStashMove', data)
    cb('ok')
end)

RegisterNUICallback('getSyndicateList', function(_, cb)
    QBCore.Functions.TriggerCallback('jk-acm:server:GetSyndicateList', function(data)
        cb(data)
    end)
end)

RegisterNUICallback('applyToOrg', function(data, cb)
    TriggerServerEvent('jk-acm:server:ApplyToOrg', data)
    cb('ok')
end)

RegisterNUICallback('handleApplication', function(data, cb)
    TriggerServerEvent('jk-acm:server:HandleApplication', data)
    cb('ok')
end)