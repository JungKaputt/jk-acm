Config = {}

-- ==============================
--        CORE SETTINGS
-- ==============================
Config.Debug = false 
Config.OpenCommand = "acm" 
Config.OpenKey = "F6" 

Config.DiscordWebhook = "INSERT_YOUR_DISCORD_WEBHOOK_HERE" 
Config.DiscordName = "ACM Logs"
Config.DiscordIcon = "https://i.imgur.com/P7Z8W5d.png"

Config.RequiredItem = "black_laptop" 

Config.CreateCost = 50000 

Config.RestrictedJobs = {
    ['police'] = true,
    ['ambulance'] = true,
    ['government'] = true
}

-- ==============================
--      ORGANIZATION RANKS
-- ==============================
Config.Ranks = {
    [1] = "Recruit",
    [2] = "Soldier",
    [3] = "Captain",
    [4] = "Underboss",
    [5] = "Boss"
}

Config.Colors = {
    primary = "#6c5ce7",
    danger = "#d63031",
    success = "#00b894"
}

-- ==============================
--      STASH / SAFE CONFIG
-- ==============================
Config.Stash = {
    ItemName = "acm_safe",
    PropModel = "prop_ld_int_safe_01",
    Slots = 50,
    Weight = 100000,
    AllowedRanksToPlace = { [4] = true, [5] = true },
    InventoryResource = "qb-inventory" 
}

-- ==============================
--        BLACKMARKET CONFIG
-- ==============================
Config.Blackmarket = {
    { label = "Heavy Pistol", item = "weapon_heavypistol", price = 5000, description = "Heavy hitting sidearm.", image = "weapon_heavypistol.png" },
    { label = "Assault Rifle", item = "weapon_assaultrifle", price = 15000, description = "Fully automatic rifle.", image = "weapon_assaultrifle.png" },
    { label = "Lockpick Set", item = "advancedlockpick", price = 500, description = "For cracking cars and doors.", image = "lockpick.png" },
    { label = "C4 Explosive", item = "weapon_stickybomb", price = 20000, description = "Handle care.", image = "c4.png" },
    { label = "Kevlar Armor", item = "armor", price = 1000, description = "Heavy ballistic protection.", image = "armor.png" },
    { label = "Org Safe", item = "acm_safe", price = 50000, description = "Secure storage for your organization.", image = "safe.png" }
}

-- ==============================
--       AIRDROP SYSTEM
-- ==============================
Config.DropZones = {
    vector3(2553.86, 4673.34, 33.95),
    --vector3(1637.76, 3224.27, 40.57),
    --vector3(1992.42, 3051.84, 47.21),
    --vector3(602.43, 2811.45, 42.66), 
    --vector3(-2235.6, 3267.31, 32.81) 
}

Config.PlaneModel = "cuban800"        
Config.CrateModel = "prop_box_wood02a_pu" 
Config.ParachuteModel = "p_cargo_chute_s" 
Config.DropHeight = 300.0

-- ==============================
--        TURF WAR SYSTEM
-- ==============================
Config.TurfCheckInterval = 1000 -- Check every 10 seconds (save server resources)
Config.ProgressPerPlayer = 10.0 -- 1 Player = 1% per interval
Config.DecayRate = 2.0 -- If there are no players, progress decreases by 2% per interval
Config.ShieldTime = 1 -- Shield duration (in minutes) after a successful capture
Config.DefenseHoldTime = 1 -- Time (minutes) must remain at 0% before the shield activates.
Config.DefendShieldTime = 1 -- Shield active duration after successfully defending.

Config.TurfTick = 30 -- Minutes (reward income)

Config.TurfZones = {
    ['grove_street'] = {
        label = "Grove St. Hood",
        coords = vector3(86.9, -1945.7, 20.8), 
        radius = 60.0, 
        reward = 500, 
        color = 2 
    },
    ['chamberlain'] = {
        label = "Chamberlain Hills",
        coords = vector3(3328.48, 5457.59, 18.39), 
        radius = 60.0,
        reward = 600,
        color = 1 
    },
    ['sandy_shores'] = {
        label = "Sandy Meth Lab",
        coords = vector3(1469.7, 3591.9, 36.4),
        radius = 80.0,
        reward = 1000,
        color = 5 
    },
}

-- ==============================
--      MONEY LAUNDRY CONFIG
-- ==============================
Config.Laundry = {
    DirtyItem = "markedbills", -- Make sure this item name is correct
    ReturnRate = 0.70, -- Get 70%
    OrgTax = 0.10, -- Fee 10%
    Locations = {
        vector4(1206.09, -3112.44, 5.54, 267.0),
        vector4(764.08, -3183.02, 6.09, 2.0),
        vector4(-2178.5, 4287.0, 49.0, 150.0),
        vector4(160.0, 2779.0, 43.0, 100.0)
    },
    PedModel = "g_m_m_armboss_01",
    InteractionTime = 5000
}

Config.CooldownSystem = {
    Duration = 20, 
    RushFee = 50   
}

-- ==============================
--     DYNAMIC TURF CONFIG
-- ==============================
Config.DynamicTurf = {
    ItemName = "territory_flag",
    PropModel = "prop_flagpole_1a", -- Flagpole model
    Radius = 100.0, -- Dynamic territory radius (blip area)
    CaptureProgressRate = 5.0, -- Capture progress speed (per second)
    CaptureDistance = 5.0 -- Maximum player distance to the flagpole while attacking
}
