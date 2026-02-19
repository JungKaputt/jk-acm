local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('jk-acm:server:CanOpen', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end
    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        cb(true, { hasOrg = true, orgId = member[1].org_id, grade = member[1].grade })
    else
        cb(true, { hasOrg = false })
    end
end)

RegisterNetEvent('jk-acm:server:CreateOrganization', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cost = Config.CreateCost or 50000
    local orgLabel = data.name 

    if not orgLabel or string.len(orgLabel) < 3 then
        TriggerClientEvent('QBCore:Notify', src, "Organization name is too short (minimum 3 characters).", "error")
        return
    end
    local orgName = orgLabel:lower():gsub("%s+", "")

    if Player.Functions.GetMoney('cash') >= cost then
        local id = MySQL.insert.await('INSERT INTO acm_organizations (name, label, owner, balance) VALUES (?, ?, ?, ?)', {
            orgName, orgLabel, Player.PlayerData.citizenid, 0
        })
        local charName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        MySQL.insert('INSERT INTO acm_members (org_id, citizenid, grade, name) VALUES (?, ?, ?, ?)', {
            id, Player.PlayerData.citizenid, 5, charName
        })
        Player.Functions.RemoveMoney('cash', cost)
        TriggerClientEvent('QBCore:Notify', src, "Organization Successfully Created!", "success")
        
        if Config.DynamicTurf and Config.DynamicTurf.ItemName then
            if Player.Functions.AddItem(Config.DynamicTurf.ItemName, 1) then
                if QBCore.Shared.Items[Config.DynamicTurf.ItemName] then
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.DynamicTurf.ItemName], "add")
                end
                TriggerClientEvent('QBCore:Notify', src, "You received a Territory Flag.", "primary")
            end
        end
        
        TriggerClientEvent('jk-acm:client:OrgCreated', src)
    else
        TriggerClientEvent('QBCore:Notify', src, "Insufficient funds (Requires $"..cost..").", "error")
    end
end)

if Config.Stash and Config.Stash.ItemName then
    QBCore.Functions.CreateUseableItem(Config.Stash.ItemName, function(source, item)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if Player.Functions.GetItemByName(Config.Stash.ItemName) then
            TriggerClientEvent('jk-acm:client:UseStashItem', src)
        end
    end)
end

QBCore.Functions.CreateCallback('jk-acm:server:GetCustomStashData', function(source, cb, stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local stashName = "ACM_Safe_" .. stashId

    local playerItems = {}
    if Player.PlayerData.items then
        for _, item in pairs(Player.PlayerData.items) do
            if item then table.insert(playerItems, item) end
        end
    end

    local result = MySQL.query.await('SELECT items FROM acm_stashes WHERE id = ?', {stashId})
    local stashItems = {}
    
    if result and result[1] and result[1].items then
        stashItems = json.decode(result[1].items) or {}
    end

    cb({ playerItems = playerItems, stashItems = stashItems })
end)

RegisterNetEvent('jk-acm:server:HandleStashMove', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local stashId = data.stashId
    local action = data.action
    local amount = tonumber(data.amount)
    local itemName = data.item
    local slot = data.slot 

    if not Player or amount <= 0 then return end

    local result = MySQL.query.await('SELECT items FROM acm_stashes WHERE id = ?', {stashId})
    if not result or not result[1] then return end
    
    local currentStashItems = json.decode(result[1].items) or {}
    local dbUpdated = false 

    if action == 'deposit' then
        local playerItem = Player.Functions.GetItemBySlot(slot)
        
        if playerItem and playerItem.name == itemName and playerItem.amount >= amount then
            if Player.Functions.RemoveItem(itemName, amount, slot) then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "remove")
                
                local found = false
                for k, v in pairs(currentStashItems) do
                    if v.name == itemName and json.encode(v.info) == json.encode(playerItem.info) then
                        v.amount = v.amount + amount
                        found = true
                        break
                    end
                end

                if not found then
                    table.insert(currentStashItems, {
                        name = itemName,
                        amount = amount,
                        label = QBCore.Shared.Items[itemName].label,
                        info = playerItem.info or {},
                        type = playerItem.type,
                        image = playerItem.image
                    })
                end
                
                dbUpdated = true
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "Invalid item.", "error")
        end

    elseif action == 'withdraw' then
        local foundIndex = -1
        local itemData = nil

        for k, v in pairs(currentStashItems) do
            if v.name == itemName then
                foundIndex = k
                itemData = v
                break
            end
        end

        if itemData and itemData.amount >= amount then
            if Player.Functions.AddItem(itemName, amount, false, itemData.info) then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
                
                itemData.amount = itemData.amount - amount
                if itemData.amount <= 0 then
                    table.remove(currentStashItems, foundIndex)
                end

                dbUpdated = true
            else
                TriggerClientEvent('QBCore:Notify', src, "Inventory Full!", "error")
            end
        end
    end

    if dbUpdated then
        MySQL.update.await('UPDATE acm_stashes SET items = ? WHERE id = ?', {json.encode(currentStashItems), stashId})
        
        TriggerClientEvent('jk-acm:client:ForceStashRefresh', src)
    end
end)