local QBCore = exports['qb-core']:GetCoreObject()
local Turfs = {}
local TurfStatus = {}
local PlayerGangs = {} 
local OrgCache = {}
local DefenseTimers = {} 

local function LoadOrgCache()
    MySQL.query('SELECT id, label, logo FROM acm_organizations', {}, function(result)
        if result then
            for _, v in pairs(result) do
                OrgCache[tonumber(v.id)] = { name = v.label, logo = v.logo or "" }
            end
        end
    end)
end

local function UpdatePlayerGang(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    MySQL.query('SELECT org_id FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and result[1] then
            PlayerGangs[src] = tonumber(result[1].org_id) or 0
            TriggerClientEvent('jk-acm:client:UpdateMyOrg', src, PlayerGangs[src])
        else
            PlayerGangs[src] = 0
            TriggerClientEvent('jk-acm:client:UpdateMyOrg', src, 0)
        end
    end)
end

local function GetEnrichedTurfData()
    local finalData = {}
    for k, v in pairs(Turfs) do
        local ownerId = tonumber(v.owner) or 0
        local ownerName = "Neutral"
        local logo = ""
        
        if ownerId > 0 then
            if OrgCache[ownerId] then
                ownerName = OrgCache[ownerId].name
                logo = OrgCache[ownerId].logo
            else
                ownerName = "Unknown Gang"
            end
        end

        finalData[k] = {
            id = k,
            owner = ownerId,
            shield = v.shield or 0,
            ownerName = ownerName,
            logo = logo,
            isContested = TurfStatus[k] and TurfStatus[k].isContested or false,
            progress = TurfStatus[k] and TurfStatus[k].progress or 0,
            attackerOrg = TurfStatus[k] and TurfStatus[k].attacker or 0,
            ownerCount = TurfStatus[k] and TurfStatus[k].ownerCount or 0,
            attackerCount = TurfStatus[k] and TurfStatus[k].attackerCount or 0
        }
    end
    return finalData
end

QBCore.Functions.CreateCallback('jk-acm:server:GetTurfData', function(source, cb)
    cb(GetEnrichedTurfData())
end)

CreateThread(function()
    LoadOrgCache()
    for k, v in pairs(Config.TurfZones) do
        Turfs[k] = { id = k, owner = 0, shield = 0 }
        TurfStatus[k] = { progress = 0, attacker = 0, isContested = false, ownerCount = 0, attackerCount = 0 }
    end

    MySQL.query('SELECT * FROM acm_turfs', {}, function(result)
        if result then
            for _, v in pairs(result) do
                local zoneId = tonumber(v.id)
                if not Turfs[zoneId] and Turfs[v.id] then zoneId = v.id end
                if Turfs[zoneId] then
                    Turfs[zoneId].owner = tonumber(v.owner_org_id)
                    Turfs[zoneId].shield = tonumber(v.shield_expires) or 0
                end
            end
            Wait(1000)
            TriggerClientEvent('jk-acm:client:SyncTurfs', -1, GetEnrichedTurfData())
        end
    end)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    UpdatePlayerGang(source)
end)

AddEventHandler('playerDropped', function()
    PlayerGangs[source] = nil
end)

RegisterNetEvent('jk-acm:server:RequestTurfSync', function()
    local src = source
    TriggerClientEvent('jk-acm:client:SyncTurfs', src, GetEnrichedTurfData())
    TriggerClientEvent('jk-acm:client:UpdateWarStatus', src, TurfStatus)
    UpdatePlayerGang(src)
end)

RegisterNetEvent('jk-acm:server:InitiateWar', function(zoneId)
    local src = source
    local orgId = PlayerGangs[src]
    
    if not orgId or orgId == 0 then 
        TriggerClientEvent('QBCore:Notify', src, "You are not in an organization!", "error") 
        return 
    end

    local zone = Config.TurfZones[zoneId]
    if not zone then return end
    
    local currentOwner = tonumber(Turfs[zoneId].owner) or 0
    if os.time() < Turfs[zoneId].shield then
        TriggerClientEvent('QBCore:Notify', src, "This zone is under Shield Protection!", "error") 
        return
    end

    if currentOwner == orgId then
        TriggerClientEvent('QBCore:Notify', src, "You already own this zone!", "error") 
        return
    end

    local status = TurfStatus[zoneId]
    
    if status.attacker == 0 then
        status.attacker = orgId
        status.isContested = true
        TriggerClientEvent('QBCore:Notify', -1, "WAR STARTED: " .. zone.label .. " is being attacked!", "primary")
        TriggerClientEvent('jk-acm:client:UpdateWarStatus', -1, TurfStatus)
    elseif status.attacker == orgId then
        TriggerClientEvent('QBCore:Notify', src, "Your organization is already attacking this zone!", "error")
    else
        TriggerClientEvent('QBCore:Notify', src, "Another organization is already attacking this zone!", "error")
    end
end)

local function CaptureSuccess(zoneId, newOwner)
    local zone = Config.TurfZones[zoneId]
    local newShield = os.time() + ((Config.ShieldTime or 60) * 60)
    
    MySQL.insert('INSERT INTO acm_turfs (id, label, owner_org_id, shield_expires) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE owner_org_id = ?, shield_expires = ?',
    {zoneId, zone.label, newOwner, newShield, newOwner, newShield})

    if Turfs[zoneId] then
        Turfs[zoneId].owner = newOwner
        Turfs[zoneId].shield = newShield
    end
    
    TurfStatus[zoneId].progress = 0
    TurfStatus[zoneId].attacker = 0
    TurfStatus[zoneId].isContested = false
    TurfStatus[zoneId].ownerCount = 0
    TurfStatus[zoneId].attackerCount = 0
    DefenseTimers[zoneId] = nil

    TriggerClientEvent('QBCore:Notify', -1, 'TURF UPDATE: ' .. zone.label .. ' captured by new owner!', 'primary')
    
    local newData = GetEnrichedTurfData()
    TriggerClientEvent('jk-acm:client:SyncTurfs', -1, newData)
    TriggerClientEvent('jk-acm:client:UpdateWarStatus', -1, TurfStatus)
end

local function DefenseSuccess(zoneId)
    local zone = Config.TurfZones[zoneId]
    local defendTime = Config.DefendShieldTime or 30 
    local newShield = os.time() + (defendTime * 60)

    MySQL.update('UPDATE acm_turfs SET shield_expires = ? WHERE id = ?', {newShield, zoneId})

    if Turfs[zoneId] then
        Turfs[zoneId].shield = newShield
    end

    TurfStatus[zoneId].progress = 0
    TurfStatus[zoneId].attacker = 0
    TurfStatus[zoneId].isContested = false
    TurfStatus[zoneId].ownerCount = 0
    TurfStatus[zoneId].attackerCount = 0
    DefenseTimers[zoneId] = nil

    TriggerClientEvent('QBCore:Notify', -1, 'TURF DEFENDED: ' .. zone.label .. ' is now shielded for ' .. defendTime .. ' mins!', 'success')

    local newData = GetEnrichedTurfData()
    TriggerClientEvent('jk-acm:client:SyncTurfs', -1, newData)
    TriggerClientEvent('jk-acm:client:UpdateWarStatus', -1, TurfStatus)
end

CreateThread(function()
    while true do
        Wait(1000)
        local players = QBCore.Functions.GetPlayers()
        local zoneCounts = {}
        local syncNeeded = false

        for _, src in ipairs(players) do
            local orgId = PlayerGangs[src]
            if orgId and orgId > 0 then
                local Player = QBCore.Functions.GetPlayer(src)
                if Player then
                    local meta = Player.PlayerData.metadata
                    local ped = GetPlayerPed(src)
                    
                    if not meta['isdead'] and not meta['inlaststand'] and GetVehiclePedIsIn(ped, false) == 0 then
                        local coords = GetEntityCoords(ped)
                        for k, zoneData in pairs(Config.TurfZones) do
                            if #(coords - zoneData.coords) < zoneData.radius then
                                if not zoneCounts[k] then zoneCounts[k] = {} end
                                if not zoneCounts[k][orgId] then zoneCounts[k][orgId] = 0 end
                                zoneCounts[k][orgId] = zoneCounts[k][orgId] + 1
                            end
                        end
                    end
                end
            end
        end

        for zoneId, orgsInside in pairs(zoneCounts) do
            if not Turfs[zoneId] then Turfs[zoneId] = { owner = 0, shield = 0 } end
            
            local status = TurfStatus[zoneId]
            local currentOwner = tonumber(Turfs[zoneId].owner) or 0
            local currentAttacker = status.attacker or 0 
            local now = os.time()

            status.ownerCount = 0
            status.attackerCount = 0

            if now >= Turfs[zoneId].shield then
                
                local ownerCount = orgsInside[currentOwner] or 0
                local attackerCount = 0
                
                if currentAttacker > 0 and orgsInside[currentAttacker] then
                    attackerCount = orgsInside[currentAttacker]
                end

                status.ownerCount = ownerCount
                status.attackerCount = attackerCount

                local progressRate = Config.ProgressPerPlayer or 1.0
                local recoveryRate = Config.RecoveryRate or 2.0

                if attackerCount > 0 and ownerCount == 0 then
                    status.isContested = false
                    DefenseTimers[zoneId] = nil
                    
                    status.progress = status.progress + (attackerCount * progressRate)
                    syncNeeded = true
                    
                    if status.progress >= 100 then CaptureSuccess(zoneId, currentAttacker) end

                elseif attackerCount > 0 and ownerCount > 0 then
                    DefenseTimers[zoneId] = nil
                    if not status.isContested then
                        status.isContested = true
                        syncNeeded = true
                    end
                else
                     if status.progress > 0 then
                        status.progress = status.progress - recoveryRate
                        if status.progress < 0 then status.progress = 0 end
                        DefenseTimers[zoneId] = nil 
                        syncNeeded = true
                     else
                        if currentAttacker > 0 then
                            status.attacker = 0
                            syncNeeded = true
                        end
                        DefenseTimers[zoneId] = nil 
                     end
                     status.isContested = false
                end
            else
                DefenseTimers[zoneId] = nil
                status.ownerCount = 0
                status.attackerCount = 0
            end
        end

        local decayRate = Config.DecayRate or 0.5
        for zoneId, status in pairs(TurfStatus) do
            if not zoneCounts[zoneId] and status.progress > 0 then
                status.progress = status.progress - decayRate
                status.isContested = false
                status.ownerCount = 0
                status.attackerCount = 0
                DefenseTimers[zoneId] = nil 
                if status.progress <= 0 then 
                    status.progress = 0 
                    status.attacker = 0 
                end
                syncNeeded = true
            end
        end

        if syncNeeded then
            TriggerClientEvent('jk-acm:client:UpdateWarStatus', -1, TurfStatus)
        end
    end
end)