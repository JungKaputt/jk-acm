local QBCore = exports['qb-core']:GetCoreObject()
local PendingInvites = {} 
local ServerStashes = {}

local DefaultPerms = {
    ['1'] = {deposit=false, withdraw=false, invite=false, kick=false, promote=false, laundry=false, blackmarket=false},
    ['2'] = {deposit=false, withdraw=false, invite=false, kick=false, promote=false, laundry=false, blackmarket=false},
    ['3'] = {deposit=true, withdraw=false, invite=true, kick=false, promote=false, laundry=true, blackmarket=false},
    ['4'] = {deposit=true, withdraw=true, invite=true, kick=true, promote=true, laundry=true, blackmarket=true},
    ['5'] = {deposit=true, withdraw=true, invite=true, kick=true, promote=true, laundry=true, blackmarket=true}
}

local function HasPerm(orgId, grade, action)
    if grade == 5 then return true end
    local success, result = pcall(MySQL.query.await, 'SELECT permissions FROM acm_organizations WHERE id = ?', {orgId})
    if success and result and result[1] and result[1].permissions then
        local status, perms = pcall(json.decode, result[1].permissions)
        if status and perms and perms[tostring(grade)] and perms[tostring(grade)][action] then return true end
    end
    return DefaultPerms[tostring(grade)] and DefaultPerms[tostring(grade)][action] or false
end

QBCore.Functions.CreateCallback('jk-acm:server:GetFullOrgData', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end
    
    local successM, member = pcall(MySQL.query.await, 'SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if not successM then return cb(nil) end
    
    if member and member[1] then
        local orgId = member[1].org_id
        local myGrade = member[1].grade
        
        local successO, org = pcall(MySQL.query.await, 'SELECT * FROM acm_organizations WHERE id = ?', {orgId})
        if not successO or not org or not org[1] then return cb(nil) end
        
        local orgData = org[1]
        if not orgData.logo then orgData.logo = "" end 
        if not orgData.slogan then orgData.slogan = "" end

        local successList, members = pcall(MySQL.query.await, 'SELECT * FROM acm_members WHERE org_id = ? ORDER BY grade DESC', {orgId})
        local successL, logs = pcall(MySQL.query.await, 'SELECT * FROM acm_logs WHERE org_id = ? ORDER BY created_at DESC LIMIT 20', {orgId})
        local successApp, applications = pcall(MySQL.query.await, 'SELECT * FROM acm_applications WHERE org_id = ? ORDER BY created_at DESC', {orgId})

        local perms = DefaultPerms
        if orgData.permissions then
            local status, decoded = pcall(json.decode, orgData.permissions)
            if status then perms = decoded end
        end
        
        cb({ 
            org = orgData, 
            members = members or {}, 
            logs = logs or {}, 
            applications = applications or {}, 
            permissions = perms, 
            myGrade = myGrade 
        })
    else 
        cb(nil) 
    end
end)

RegisterNetEvent('jk-acm:server:HandleApplication', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local appId = data.appId
    local action = data.action 

    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if not member or not member[1] then return end
    
    local orgId = member[1].org_id
    
    if not HasPerm(orgId, member[1].grade, 'invite') then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Access Denied: No invite permission.', 'error')
        return
    end

    local appData = MySQL.query.await('SELECT * FROM acm_applications WHERE id = ? AND org_id = ?', {appId, orgId})
    if not appData or not appData[1] then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Application not found.', 'error')
        return
    end
    
    local targetCid = appData[1].citizenid
    local targetName = appData[1].name

    if action == 'accept' then
        local check = MySQL.query.await('SELECT org_id FROM acm_members WHERE citizenid = ?', {targetCid})
        if check and check[1] then
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Player has already joined another organization.', 'error')
            MySQL.query('DELETE FROM acm_applications WHERE id = ?', {appId}) 
            TriggerClientEvent('jk-acm:client:RefreshOrg', src)
            return
        end

        MySQL.insert('INSERT INTO acm_members (org_id, citizenid, name, grade) VALUES (?, ?, ?, ?)', {orgId, targetCid, targetName, 1})
        MySQL.query('DELETE FROM acm_applications WHERE id = ?', {appId})
        
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, targetName .. " has been accepted!", "success")
        
        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCid)
        if targetPlayer then
            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Congratulations! Your application was accepted.", "success")
            TriggerClientEvent('jk-acm:client:RefreshOrg', targetPlayer.PlayerData.source)
        end

    elseif action == 'reject' then
        MySQL.query('DELETE FROM acm_applications WHERE id = ?', {appId})
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Application rejected.', 'success')
    end

    TriggerClientEvent('jk-acm:client:RefreshOrg', src)
end)

QBCore.Functions.CreateCallback('jk-acm:server:GetSyndicateList', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local myCid = Player and Player.PlayerData.citizenid or ""

    local query = [[
        SELECT 
            id, 
            label, 
            logo, 
            slogan, 
            color, 
            (SELECT COUNT(*) FROM acm_members WHERE org_id = acm_organizations.id) as memberCount,
            (SELECT name FROM acm_members WHERE org_id = acm_organizations.id AND grade = 5 LIMIT 1) as bossName
        FROM acm_organizations
    ]]
    
    local result = MySQL.query.await(query, {}) or {}

    local myApps = MySQL.query.await('SELECT org_id FROM acm_applications WHERE citizenid = ?', {myCid})
    local appMap = {}
    if myApps then
        for _, v in pairs(myApps) do
            appMap[v.org_id] = true
        end
    end

    for _, v in pairs(result) do
        v.hasApplied = appMap[v.id] or false
        
        if not v.logo then v.logo = "" end
    end

    cb(result)
end)

RegisterNetEvent('jk-acm:server:ApplyToOrg', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local orgId = data.orgId
    local message = data.message or "I want to join."

    local check = MySQL.query.await('SELECT org_id FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if check and check[1] then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Error: You are already in an organization.", "error")
        return
    end

    local checkApp = MySQL.query.await('SELECT id FROM acm_applications WHERE citizenid = ? AND org_id = ?', {Player.PlayerData.citizenid, orgId})
    if checkApp and checkApp[1] then
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "You have already applied to this syndicate.", "error")
        return
    end

    local charName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    MySQL.insert('INSERT INTO acm_applications (org_id, citizenid, name, message) VALUES (?, ?, ?, ?)', {
        orgId, Player.PlayerData.citizenid, charName, message
    })

    TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Application sent successfully.", "success")
    TriggerClientEvent('jk-acm:client:RefreshOrg', src) 
end)

RegisterNetEvent('jk-acm:server:TreasuryAction', function(action, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    
    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        local orgId = member[1].org_id
        local grade = member[1].grade
        
        local orgInfo = MySQL.query.await('SELECT balance, label FROM acm_organizations WHERE id = ?', {orgId})
        local orgLabel = (orgInfo and orgInfo[1]) and orgInfo[1].label or "Organization"
        
        if action == 'deposit' then
            if Player.Functions.RemoveMoney('bank', amount) then
                MySQL.update('UPDATE acm_organizations SET balance = balance + ? WHERE id = ?', {amount, orgId})
                MySQL.insert('INSERT INTO acm_logs (org_id, citizenid, name, action, amount, details) VALUES (?, ?, ?, ?, ?, ?)', {orgId, Player.PlayerData.citizenid, Player.PlayerData.charinfo.firstname, "Deposit", amount, "Deposited from Bank"})
                
                TriggerClientEvent('jk-acm:client:RefreshOrg', src)
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Successfully deposited $"..amount, "success")
                
                TriggerClientEvent('qb-phone:server:sendNewMail', src, {
                    sender = "Maze Bank",
                    subject = "Debit Transaction",
                    message = "You have transferred $" .. amount .. " to " .. orgLabel .. " Treasury.",
                    button = {}
                })
            else 
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Not enough funds in bank.', 'error') 
            end
            
        elseif action == 'withdraw' then
            if HasPerm(orgId, grade, 'withdraw') then
                if orgInfo and orgInfo[1] and orgInfo[1].balance >= amount then
                    MySQL.update('UPDATE acm_organizations SET balance = balance - ? WHERE id = ?', {amount, orgId})
                    Player.Functions.AddMoney('bank', amount)
                    MySQL.insert('INSERT INTO acm_logs (org_id, citizenid, name, action, amount, details) VALUES (?, ?, ?, ?, ?, ?)', {orgId, Player.PlayerData.citizenid, Player.PlayerData.charinfo.firstname, "Withdraw", amount, "Withdrew to Bank"})
                    
                    TriggerClientEvent('jk-acm:client:RefreshOrg', src)
                    TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Successfully withdrew $"..amount, "success")

                    TriggerClientEvent('qb-phone:server:sendNewMail', src, {
                        sender = "Maze Bank",
                        subject = "Incoming Funds",
                        message = "You received $" .. amount .. " from " .. orgLabel .. " Treasury.",
                        button = {}
                    })
                else 
                    TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Insufficient funds in treasury.', 'error') 
                end
            else 
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Access Denied: No Withdraw Permission.', 'error') 
            end
        end
    end
end)

RegisterNetEvent('jk-acm:server:ManageMember', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local targetCid = data.targetCid
    local action = data.action

    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        local orgId = member[1].org_id
        local myGrade = member[1].grade
        local permReq = (action == 'kick') and 'kick' or 'promote'
        
        if not HasPerm(orgId, myGrade, permReq) then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Access Denied: No Permission.', 'error') 
            return 
        end

        local targetMember = MySQL.query.await('SELECT grade, name FROM acm_members WHERE citizenid = ? AND org_id = ?', {targetCid, orgId})
        if not targetMember or not targetMember[1] then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Target member not found.', 'error') 
            return 
        end
        local targetGrade = targetMember[1].grade
        local targetName = targetMember[1].name

        if action == 'kick' then
            if targetGrade >= myGrade then 
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Cannot kick member with equal/higher rank.', 'error') 
                return 
            end
            MySQL.query('DELETE FROM acm_members WHERE citizenid = ? AND org_id = ?', {targetCid, orgId})
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, targetName .. " has been kicked.", 'success')

        elseif action == 'promote' then
            if targetGrade >= 5 then
                 TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Member is already at max rank.', 'error')
                 return
            end

            if (targetGrade + 1) >= myGrade then 
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Cannot promote to rank equal/higher than yours.', 'error') 
                return 
            end
            
            MySQL.query('UPDATE acm_members SET grade = grade + 1 WHERE citizenid = ? AND org_id = ? AND grade < 5', {targetCid, orgId})
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, targetName .. " promoted to Rank " .. (targetGrade + 1), 'success')

        elseif action == 'demote' then
            if targetGrade >= myGrade then 
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Cannot demote member with equal/higher rank.', 'error') 
                return 
            end
            if targetGrade <= 1 then
                TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Member is already at lowest rank.', 'error')
                return
            end

            MySQL.query('UPDATE acm_members SET grade = grade - 1 WHERE citizenid = ? AND org_id = ? AND grade > 1', {targetCid, orgId})
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, targetName .. " demoted to Rank " .. (targetGrade - 1), 'success')
        end
        Wait(100)
        TriggerClientEvent('jk-acm:client:RefreshOrg', src)
    end
end)

RegisterNetEvent('jk-acm:server:LeaveOrg', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        if member[1].grade == 5 then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Boss cannot leave. Use Disband option.', 'error') 
            return 
        end
        MySQL.query('DELETE FROM acm_members WHERE citizenid = ? AND org_id = ?', {Player.PlayerData.citizenid, member[1].org_id})
        
        TriggerClientEvent('QBCore:Notify', src, 'You have left the organization.', 'success')
        TriggerClientEvent('jk-acm:client:ForceClose', src)
    end
end)

RegisterNetEvent('jk-acm:server:DisbandOrg', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        local orgId = member[1].org_id
        
        if member[1].grade ~= 5 then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Only the Boss can disband the organization.', 'error') 
            return 
        end

        local allMembers = MySQL.query.await('SELECT citizenid FROM acm_members WHERE org_id = ?', {orgId})
        
        MySQL.query('DELETE FROM acm_members WHERE org_id = ?', {orgId})
        MySQL.query('DELETE FROM acm_logs WHERE org_id = ?', {orgId})
        MySQL.query('DELETE FROM acm_turfs WHERE owner_org_id = ?', {orgId})
        MySQL.query('DELETE FROM acm_stashes WHERE org_id = ?', {orgId})
        MySQL.query('DELETE FROM acm_organizations WHERE id = ?', {orgId})
        MySQL.query('DELETE FROM acm_applications WHERE org_id = ?', {orgId}) 

        TriggerClientEvent('QBCore:Notify', src, 'Organization permanently disbanded.', 'success')
        TriggerClientEvent('jk-acm:client:ForceClose', src)

        if allMembers then
            for _, m in pairs(allMembers) do
                local tPlayer = QBCore.Functions.GetPlayerByCitizenId(m.citizenid)
                if tPlayer and tPlayer.PlayerData.source ~= src then
                    TriggerClientEvent('QBCore:Notify', tPlayer.PlayerData.source, 'Your organization has been disbanded by the Boss.', 'error')
                    TriggerClientEvent('jk-acm:client:ForceClose', tPlayer.PlayerData.source)
                end
            end
        end
        TriggerEvent('jk-acm:server:ReloadStashes')
    end
end)

RegisterNetEvent('jk-acm:server:SaveSettings', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] and member[1].grade == 5 then
        local orgId = member[1].org_id
        if data.type == 'info' then
            MySQL.update('UPDATE acm_organizations SET rules = ?, announcements = ? WHERE id = ?', {data.rules, data.announce, orgId})
        elseif data.type == 'perms' then
            MySQL.update('UPDATE acm_organizations SET permissions = ? WHERE id = ?', {json.encode(data.perms), orgId})
        elseif data.type == 'profile' then
            MySQL.update('UPDATE acm_organizations SET logo = ?, slogan = ?, color = ? WHERE id = ?', {data.logo, data.slogan, data.color, orgId})
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Profile & Theme updated successfully.', 'success')
        end
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Settings saved successfully.', 'success')
        TriggerClientEvent('jk-acm:client:RefreshOrg', src)
    else 
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, 'Only Boss can change settings.', 'error') 
    end
end)

RegisterNetEvent('jk-acm:server:InvitePlayer', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(targetId)
    if not Player then return end
    
    if not Target then 
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Player not found or offline.", "error") 
        return 
    end
    if src == targetId then 
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Cannot invite yourself.", "error") 
        return 
    end

    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    if member and member[1] then
        local orgId = member[1].org_id
        if not HasPerm(orgId, member[1].grade, 'invite') then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Access Denied: No invite permission.", "error") 
            return 
        end

        local targetCheck = MySQL.query.await('SELECT org_id FROM acm_members WHERE citizenid = ?', {Target.PlayerData.citizenid})
        if targetCheck and targetCheck[1] then 
            TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Player is already in an organization.", "error") 
            return 
        end

        local org = MySQL.query.await('SELECT label FROM acm_organizations WHERE id = ?', {orgId})
        PendingInvites[targetId] = { orgId = orgId, orgLabel = org[1].label, inviter = src }
        
        TriggerClientEvent('QBCore:Notify', targetId, "INVITE: You have been invited to " .. org[1].label, "success", 10000)
        TriggerClientEvent('QBCore:Notify', targetId, "Type /joinorg to accept.", "primary", 10000)
        
        TriggerClientEvent('jk-acm:client:LaptopNotify', src, "Invite sent to " .. Target.PlayerData.charinfo.firstname, "success")
    end
end)

QBCore.Commands.Add('joinorg', 'Accept Organization Invite', {}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local invite = PendingInvites[src]
    if invite then
        local charName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        MySQL.insert('INSERT INTO acm_members (org_id, citizenid, name, grade) VALUES (?, ?, ?, ?)', {invite.orgId, Player.PlayerData.citizenid, charName, 1})
        TriggerClientEvent('QBCore:Notify', src, "Welcome to " .. invite.orgLabel .. "!", "success")
        
        if QBCore.Functions.GetPlayer(invite.inviter) then
            TriggerClientEvent('QBCore:Notify', invite.inviter, charName .. " accepted your invite.", "success")
            TriggerClientEvent('jk-acm:client:RefreshOrg', invite.inviter)
        end
        PendingInvites[src] = nil
    else 
        TriggerClientEvent('QBCore:Notify', src, "No pending invites.", "error") 
    end
end)

CreateThread(function()
    MySQL.query('SELECT * FROM acm_stashes', {}, function(result)
        if result then
            ServerStashes = result
            for k, v in pairs(ServerStashes) do
                v.coords = json.decode(v.coords)
            end
        end
    end)
end)

RegisterNetEvent('jk-acm:server:ReloadStashes', function()
    MySQL.query('SELECT * FROM acm_stashes', {}, function(result)
        if result then
            ServerStashes = result
            for k, v in pairs(ServerStashes) do
                v.coords = json.decode(v.coords)
            end
            TriggerClientEvent('jk-acm:client:SyncStashes', -1, ServerStashes)
        end
    end)
end)

QBCore.Functions.CreateCallback('jk-acm:server:GetStashes', function(source, cb)
    cb(ServerStashes)
end)

RegisterNetEvent('jk-acm:server:SaveStash', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local coords = data.coords
    local pin = data.pin
    
    if not Player then return end
    
    if not Player.Functions.GetItemByName(Config.Stash.ItemName) then 
        TriggerClientEvent('QBCore:Notify', src, "Error: You don't have the Safe Item.", "error")
        return 
    end

    local member = MySQL.query.await('SELECT org_id, grade FROM acm_members WHERE citizenid = ?', {Player.PlayerData.citizenid})
    
    if member and member[1] then
        local orgId = member[1].org_id
        local grade = member[1].grade
        
        if Config.Stash.AllowedRanksToPlace[grade] then
            
            MySQL.insert('INSERT INTO acm_stashes (org_id, coords, pin, placed_by) VALUES (?, ?, ?, ?)', {
                orgId, 
                json.encode(coords), 
                pin,
                Player.PlayerData.citizenid
            }, function(id)
                if id then
                    Player.Functions.RemoveItem(Config.Stash.ItemName, 1)
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Stash.ItemName], "remove")
                    
                    TriggerClientEvent('QBCore:Notify', src, "Safe installed successfully. PIN: " .. pin, "success", 10000)
                    
                    TriggerEvent('jk-acm:server:ReloadStashes')
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "Access Denied: Your rank cannot place a safe.", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "You must be in an organization to place this.", "error")
    end
end)

QBCore.Functions.CreateCallback('jk-acm:server:VerifyStashPin', function(source, cb, stashId, enteredPin)
    local src = source
    
    local targetStash = nil
    for _, s in pairs(ServerStashes) do
        if s.id == stashId then
            targetStash = s
            break
        end
    end

    if targetStash then
        if targetStash.pin == enteredPin then
            cb(true)
        else
            cb(false)
        end
    else
        cb(false)
    end
end)