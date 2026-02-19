local QBCore = exports['qb-core']:GetCoreObject()
local ActiveMissions = {} 

local function GetTotalMarkedWorth(Player)
    local totalWorth = 0
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name == Config.Laundry.DirtyItem then
            local worth = (item.info and item.info.worth) or 0
            totalWorth = totalWorth + worth
        end
    end
    return totalWorth
end

local function CheckLaundryPerm(orgId, grade)
    if grade == 5 then return true end
    local success, result = pcall(MySQL.query.await, 'SELECT permissions FROM acm_organizations WHERE id = ?', {orgId})
    if success and result and result[1] and result[1].permissions then
        local status, perms = pcall(json.decode, result[1].permissions)
        if status and perms[tostring(grade)] and perms[tostring(grade)]['laundry'] then
            return true
        end
    end
    return false
end

QBCore.Functions.CreateCallback('jk-acm:server:GetDirtyMoney', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end
    cb(GetTotalMarkedWorth(Player))
end)

RegisterNetEvent('jk-acm:server:StartLaundry', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local amount = tonumber(amount)

    if not Config.Laundry then
        print("^1[ACM-ERROR] Config.Laundry Missing!^7")
        TriggerClientEvent('QBCore:Notify', src, "System Error: Config Missing", "error")
        return
    end

    if not amount or amount <= 0 then return end

    local res = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    local orgId = (res and res[1]) and res[1].org_id or nil
    local myGrade = (res and res[1]) and res[1].grade or nil

    if not orgId then
        TriggerClientEvent('QBCore:Notify', src, "Access Denied: You are not in an organization.", "error")
        return
    end

    if not CheckLaundryPerm(orgId, myGrade) then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Access Denied: Rank restriction (Laundry).", "error")
        return
    end

    local totalWorth = GetTotalMarkedWorth(Player)
    if totalWorth < amount then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Not enough marked bills value (Have: $"..totalWorth..")", "error")
        return
    end

    local randLoc = Config.Laundry.Locations[math.random(#Config.Laundry.Locations)]
    ActiveMissions[src] = { amount = amount, orgId = orgId, coords = randLoc }

    TriggerClientEvent('jk-acm:client:SetupLaundryMission', src, randLoc)
    
    TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Contact established. Check GPS.", "success")
    
    TriggerClientEvent('jk-acm:client:ForceClose', src)
end)

RegisterNetEvent('jk-acm:server:FinishLaundry', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local mission = ActiveMissions[src]

    if not mission then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local dist = #(coords - vector3(mission.coords.x, mission.coords.y, mission.coords.z))

    if dist > 15.0 then return end

    local amountToProcess = mission.amount
    local items = Player.PlayerData.items
    local sortedSlots = {}
    
    for slot, item in pairs(items) do
        if item and item.name == Config.Laundry.DirtyItem then table.insert(sortedSlots, slot) end
    end

    for _, slot in ipairs(sortedSlots) do
        if amountToProcess > 0 then
            local item = items[slot]
            local worth = (item.info and item.info.worth) or 0
            if Player.Functions.RemoveItem(Config.Laundry.DirtyItem, 1, slot) then amountToProcess = amountToProcess - worth end
        end
    end

    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Laundry.DirtyItem], "remove")

    if amountToProcess < 0 then
        local refundAmount = math.abs(amountToProcess)
        Player.Functions.AddItem(Config.Laundry.DirtyItem, 1, false, {worth = refundAmount})
        TriggerClientEvent('QBCore:Notify', src, "Refunded change: $"..refundAmount, "primary")
    end

    local cleanAmount = math.floor(mission.amount * Config.Laundry.ReturnRate)
    local taxAmount = math.floor(mission.amount * Config.Laundry.OrgTax)

    Player.Functions.AddMoney('cash', cleanAmount)
    
    if mission.orgId then
        MySQL.update('UPDATE acm_organizations SET balance = balance + ? WHERE id = ?', {taxAmount, mission.orgId})
        local charName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        MySQL.insert('INSERT INTO acm_logs (org_id, citizenid, name, action, amount, details) VALUES (?, ?, ?, ?, ?, ?)',
        {mission.orgId, Player.PlayerData.citizenid, charName, "Laundry Tax", taxAmount, "Tax from Laundering"})
    end

    TriggerClientEvent('QBCore:Notify', src, "Laundering complete. Received: $"..cleanAmount, "success")
    ActiveMissions[src] = nil
end)