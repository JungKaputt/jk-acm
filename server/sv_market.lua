local QBCore = exports['qb-core']:GetCoreObject()
local ActiveAirdrops = {} 
local MarketCooldowns = {}

QBCore.Functions.CreateCallback('jk-acm:server:GetMarketItems', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local marketData = {}

    local rushFee = 25
    if Config.CooldownSystem and Config.CooldownSystem.RushFee then
        rushFee = Config.CooldownSystem.RushFee
    end

    for k, v in pairs(Config.Blackmarket) do
        marketData[k] = v
        marketData[k].cooldownExpiry = 0
        marketData[k].rushFee = rushFee
    end

    if Player then
        local res = MySQL.query.await('SELECT org_id FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
        if res and res[1] then
            local orgId = res[1].org_id
            
            if MarketCooldowns[orgId] then
                for index, expiry in pairs(MarketCooldowns[orgId]) do
                    if os.time() < expiry then
                        if marketData[index] then
                            marketData[index].cooldownExpiry = expiry
                        end
                    else
                        MarketCooldowns[orgId][index] = nil
                    end
                end
            end
        end
    end

    cb(marketData)
end)

local function CheckMarketPerm(orgId, grade)
    if grade == 5 then return true end
    
    local success, result = pcall(MySQL.query.await, 'SELECT permissions FROM acm_organizations WHERE id = ?', {orgId})
    
    if success and result and result[1] and result[1].permissions then
        local status, perms = pcall(json.decode, result[1].permissions)
        if status and perms[tostring(grade)] and perms[tostring(grade)]['blackmarket'] then
            return true
        end
    end
    
    return false 
end

RegisterNetEvent('jk-acm:server:BuyItem', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemIndex = data.index
    local isRush = data.rush or false 
    local itemData = Config.Blackmarket[itemIndex]

    if not itemData then return end

    local cooldownTime = 10 
    local rushFeePercent = 25 

    if Config.CooldownSystem then
        if Config.CooldownSystem.Duration then cooldownTime = Config.CooldownSystem.Duration end
        if Config.CooldownSystem.RushFee then rushFeePercent = Config.CooldownSystem.RushFee end
    end

    local res = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    
    if res and res[1] then
        local orgId = res[1].org_id
        local myGrade = res[1].grade

        if not CheckMarketPerm(orgId, myGrade) then
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Access Denied: Rank restriction (Blackmarket).", "error")
            return
        end

        local currentPrice = itemData.price
        local currentTime = os.time()
        
        if MarketCooldowns[orgId] and MarketCooldowns[orgId][itemIndex] then
            local expiry = MarketCooldowns[orgId][itemIndex]
            if currentTime < expiry then
                if not isRush then
                    TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Item is on cooldown. Wait or pay the rush fee.", "error")
                    return
                else
                    local extra = math.floor(itemData.price * (rushFeePercent / 100))
                    currentPrice = currentPrice + extra
                end
            end
        end

        local org = MySQL.query.await('SELECT * FROM acm_organizations WHERE id = ?', {orgId})
        
        if org and org[1] and org[1].balance >= currentPrice then
            MySQL.update('UPDATE acm_organizations SET balance = balance - ? WHERE id = ?', {currentPrice, orgId})
            
            local charName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            
            local logDetails = "Bought " .. itemData.label
            if isRush then
                logDetails = logDetails .. " (RUSH ORDER - +"..rushFeePercent.."%)"
            end

            MySQL.insert('INSERT INTO acm_logs (org_id, citizenid, name, action, amount, details) VALUES (?, ?, ?, ?, ?, ?)', 
            {orgId, Player.PlayerData.citizenid, charName, "Purchase", currentPrice, logDetails})

            if not MarketCooldowns[orgId] then MarketCooldowns[orgId] = {} end
            MarketCooldowns[orgId][itemIndex] = os.time() + (cooldownTime * 60)

            local dropCoords = Config.DropZones[math.random(#Config.DropZones)]
            local dropId = math.random(100000, 999999)
            
            ActiveAirdrops[dropId] = {
                item = itemData.item,
                label = itemData.label,
                coords = dropCoords,
                ownerSrc = src,
                orgId = orgId
            }

            local orgMembers = MySQL.query.await('SELECT citizenid FROM acm_members WHERE org_id = ?', {orgId})
            local memberMap = {}
            for _, v in pairs(orgMembers) do
                memberMap[v.citizenid] = true
            end

            local players = QBCore.Functions.GetPlayers()
            for _, playerId in pairs(players) do
                local targetPlayer = QBCore.Functions.GetPlayer(playerId)
                if targetPlayer then
                    local isOrgMember = memberMap[targetPlayer.PlayerData.citizenid] == true
                    local isBuyer = (playerId == src)

                    TriggerClientEvent('jk-acm:client:StartAirdropGlobal', playerId, dropId, dropCoords, itemData.label, isBuyer, isOrgMember)
                end
            end
            
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Order Successful. Airdrop inbound to coordinates.', 'success')
            
            TriggerClientEvent('jk-acm:client:RefreshOrg', src)
        else
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Transaction Failed: Insufficient Organization Funds.', 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Access Denied: You are not in an organization.', 'error')
    end
end)

RegisterNetEvent('jk-acm:server:ClaimPackage', function(dropId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local dropData = ActiveAirdrops[dropId]
    if not dropData then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dist = #(coords - dropData.coords)

    if dist < 15.0 then
        if Player.Functions.AddItem(dropData.item, 1) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[dropData.item], "add")
            TriggerClientEvent('QBCore:Notify', src, "Retrieved: " .. dropData.label, "success")
            
            ActiveAirdrops[dropId] = nil
            
            TriggerClientEvent('jk-acm:client:AirdropTaken', -1, dropId)
        else
            TriggerClientEvent('QBCore:Notify', src, "Inventory Full!", "error")
        end
    else
        print("^1[ACM-ALERT] Player " .. src .. " tried to claim airdrop from too far away!^7")
    end
end)