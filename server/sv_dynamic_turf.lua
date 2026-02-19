local QBCore = exports['qb-core']:GetCoreObject()
local DynamicTurfs = {}
local ActiveAttacks = {}

-- ==========================================
-- LOAD DATA FROM DATABASE WHEN THE SERVER STARTS
-- ==========================================
CreateThread(function()
    MySQL.query('SELECT * FROM acm_dynamic_turfs', {}, function(result)
        if result then
            for _, v in pairs(result) do
                DynamicTurfs[v.org_id] = {
                    org_id = v.org_id,
                    coords = json.decode(v.coords),
                    placed_by = v.placed_by,
                    attacker_id = v.attacker_id or 0,
                    progress = v.progress or 0,
                    shield = v.shield_expires or 0
                }
            end
            Wait(2000)
            TriggerClientEvent('jk-acm:client:SyncDynamicTurfs', -1, DynamicTurfs)
        end
    end)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('jk-acm:client:SyncDynamicTurfs', src, DynamicTurfs)
end)

-- ==========================================
-- ITEM USAGE (USING THE FLAG)
-- ==========================================
if Config.DynamicTurf and Config.DynamicTurf.ItemName then
    QBCore.Functions.CreateUseableItem(Config.DynamicTurf.ItemName, function(source, item)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)

        MySQL.query('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(member)
            if member and member[1] then
                if member[1].grade == 5 then 
                    local orgId = member[1].org_id
                    
                    if DynamicTurfs[orgId] then
                        TriggerClientEvent('QBCore:Notify', src, "Your organization already has an active territory flag!", "error")
                        return
                    end
                    
                    TriggerClientEvent('jk-acm:client:StartFlagPlacement', src)
                else
                    TriggerClientEvent('QBCore:Notify', src, "Only the Boss can claim a territory!", "error")
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "You are not in an organization!", "error")
            end
        end)
    end)
end

-- ==========================================
-- SAVE FLAG TO DATABASE
-- ==========================================
RegisterNetEvent('jk-acm:server:PlaceDynamicTurf', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    MySQL.query('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(member)
        if not member or not member[1] or member[1].grade ~= 5 then return end

        local orgId = member[1].org_id
        local itemName = Config.DynamicTurf.ItemName

        if Player.Functions.GetItemByName(itemName) then
            if Player.Functions.RemoveItem(itemName, 1) then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "remove")
                
                local shieldTime = os.time() + ((Config.ShieldTime or 1) * 60)
                
                MySQL.insert('INSERT INTO acm_dynamic_turfs (org_id, coords, placed_by, shield_expires) VALUES (?, ?, ?, ?)', {
                    orgId, 
                    json.encode(coords), 
                    Player.PlayerData.citizenid,
                    shieldTime
                }, function(id)
                    DynamicTurfs[orgId] = {
                        org_id = orgId,
                        coords = coords,
                        placed_by = Player.PlayerData.citizenid,
                        attacker_id = 0,
                        progress = 0,
                        shield = shieldTime
                    }
                    
                    TriggerClientEvent('QBCore:Notify', src, "Territory successfully claimed!", "success")
                    TriggerClientEvent('jk-acm:client:SyncDynamicTurfs', -1, DynamicTurfs)
                end)
            end
        end
    end)
end)

-- ==========================================
-- ATTACK LOGIC
-- ==========================================
RegisterNetEvent('jk-acm:server:AttackDynamicTurf', function(targetOrgId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local targetTurf = DynamicTurfs[targetOrgId]
    if not targetTurf then return end

    MySQL.query('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(member)
        if not member or not member[1] then
            TriggerClientEvent('QBCore:Notify', src, "You must be in a syndicate to attack!", "error")
            return
        end

        local myOrgId = member[1].org_id

        if myOrgId == targetOrgId then
            TriggerClientEvent('QBCore:Notify', src, "You cannot attack your own territory!", "error")
            return
        end

        if os.time() < targetTurf.shield then
            TriggerClientEvent('QBCore:Notify', src, "This territory is currently protected by a shield!", "error")
            return
        end

        if targetTurf.attacker_id > 0 and targetTurf.attacker_id ~= myOrgId then
            TriggerClientEvent('QBCore:Notify', src, "Another syndicate is already attacking this territory!", "error")
            return
        end

        if targetTurf.attacker_id == 0 then
            targetTurf.attacker_id = myOrgId
            targetTurf.progress = 0
            ActiveAttacks[targetOrgId] = true
            
            TriggerClientEvent('QBCore:Notify', -1, "A Dynamic Territory is under attack!", "primary")
            TriggerClientEvent('jk-acm:client:SyncDynamicTurfs', -1, DynamicTurfs)
        end
    end)
end)

-- ==========================================
-- ATTACK PROGRESS THREAD (UPDATED)
-- ==========================================
CreateThread(function()
    while true do
        Wait(2000)
        local syncNeeded = false

        for targetOrgId, isAttacked in pairs(ActiveAttacks) do
            if isAttacked and DynamicTurfs[targetOrgId] then
                local turf = DynamicTurfs[targetOrgId]
                local attackerOrg = turf.attacker_id
                
                local attackersNear = 0
                local defendersNear = 0

                local players = QBCore.Functions.GetPlayers()
                for _, pSrc in ipairs(players) do
                    local Player = QBCore.Functions.GetPlayer(pSrc)
                    if Player then
                        local meta = Player.PlayerData.metadata
                        local ped = GetPlayerPed(pSrc)
                        
                        if not meta['isdead'] and not meta['inlaststand'] and GetVehiclePedIsIn(ped, false) == 0 then
                            local pCoords = GetEntityCoords(ped)
                            local tCoords = vector3(turf.coords.x, turf.coords.y, turf.coords.z)
                            
                            if #(pCoords - tCoords) <= (Config.DynamicTurf.Radius or 50.0) then
                                MySQL.query('SELECT org_id FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(res)
                                    if res and res[1] then
                                        local pOrg = res[1].org_id
                                        if pOrg == attackerOrg then attackersNear = attackersNear + 1 end
                                        if pOrg == targetOrgId then defendersNear = defendersNear + 1 end
                                    end
                                end)
                            end
                        end
                    end
                end
                
                Wait(500)

                if attackersNear > 0 and defendersNear == 0 then
                    turf.progress = turf.progress + (Config.DynamicTurf.CaptureProgressRate or 5.0)
                    syncNeeded = true
                    
                    if turf.progress >= 100 then
                        local winnerSrc = nil
                        for _, pSrc in ipairs(players) do
                            local PData = QBCore.Functions.GetPlayer(pSrc)
                            if PData then
                                MySQL.query('SELECT org_id FROM acm_members WHERE citizenid = ?', {PData.PlayerData.citizenid}, function(res)
                                    if res and res[1] and res[1].org_id == attackerOrg and not winnerSrc then
                                        winnerSrc = pSrc
                                        local WPlayer = QBCore.Functions.GetPlayer(winnerSrc)
                                        WPlayer.Functions.AddItem(Config.DynamicTurf.ItemName, 1)
                                        TriggerClientEvent('inventory:client:ItemBox', winnerSrc, QBCore.Shared.Items[Config.DynamicTurf.ItemName], "add")
                                    end
                                end)
                            end
                        end

                        MySQL.query('DELETE FROM acm_dynamic_turfs WHERE org_id = ?', {targetOrgId})
                        DynamicTurfs[targetOrgId] = nil
                        ActiveAttacks[targetOrgId] = nil
                        
                        TriggerClientEvent('QBCore:Notify', -1, "A Syndicate's Territory Flag was destroyed and taken over!", "error")
                        syncNeeded = true
                    end
                elseif attackersNear == 0 then
                    if turf.progress > 0 then
                        turf.progress = turf.progress - (Config.DynamicTurf.CaptureProgressRate or 5.0)
                        if turf.progress <= 0 then
                            turf.progress = 0
                            turf.attacker_id = 0
                            ActiveAttacks[targetOrgId] = nil
                        end
                        syncNeeded = true
                    end
                end
            end
        end

        if syncNeeded then
            TriggerClientEvent('jk-acm:client:SyncDynamicTurfs', -1, DynamicTurfs)
        end
    end
end)