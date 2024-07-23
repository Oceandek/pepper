getgenv().AutoProgress = false
--task.wait(2)
getgenv().AutoProgress = true -- ✅
getgenv().Config = {
    AutoWorld = {
        Enabled = true, -- ✅
        AutoQuest = true,
        PurchasePetSlots = true, -- ✅
        AutoRebirth = true, -- ✅
        AutoTap = true, -- ✅
        AutoUltimate = true, -- 🟨
        UseTntOnDelay = false, -- Use tnt on set intervals, does not respect SmartTnt
        TntDelay = 10, -- 🟨
        SmartTnt = false, -- 🟨
        UseTntOnNewZone = false, -- 🟨
    },
    AutoRank = {
        Enabled = true, -- ✅
        InitialRank = 10, -- Rank up to rank n before/during Auto World, false to skip. ✅
        IgnoredQuests = {"DIAMOND_BREAKABLE"}, -- ✅
        Flags = {"Magnet Flag", "Coins Flag", "Hasty Flag", "Magnet Flag", "Diamonds Flag"}, -- Flags to use for USE_FLAG quest ✅
        Potions = {"Damage", "Coins", "Egg", "Speed", "Diamonds", "Treasure Hunter"} -- Potions to use for USE_POTION quest ✅
    },
    Farming = {
        AutoCollectOrbs = true,
    },
    EnchantLoadout = {
        Enabled = true,
        Farm = {"Coins VII", "Treasure Hunter VII", "Super Lightning", "Strong Pets VII", "Criticals VII"},
        Hatch = {"Huge Hunter", "Shiny Hunter", "Egg Luck VII", "Shiny Hunter", "Huge Hunter"},
        Cool = {"Coins VI", "Tap Power VI", "Exotic Pet"}
    },
    Webhooks = { -- ❌
        Statistics = {
            Enabled = false,
            Delay = 60,
            WebhookUrl = ""
        },
    },
    Misc = {
        ClaimFreeRewards = true, -- ❌
        DisableItemNotifications = true
    },
    Performance = {
        SetFpsCap = 999, -- ✅
        FpsBooster = {
            Enabled = true,
            InvisibleMap = false,
        },
        Disable3dRendering = false -- ✅
    },
    Client = {
        Blackout = {
            Enabled = true,
            Toggle = Enum.KeyCode.P,
            Disable3dRendering = true
        },
        Debug = false,
        SimpleDebug = true,
        Anchored = false
    }
}
getgenv().SmartTntConfig = {
    [0] = { -- Rebirth Number
        Max = 25, -- Max Zone to use TNT at
        Min = 1 -- Min Zone to use TNT at
    },
    [1] = {
        Max = 50,
        Min = 25
    },
    [2] = {
        Max = 75,
        Min = 50
    },
    [3] = {
        Max = 99,
        Min = 75
    }
}
getgenv().CoinjarQuestConfig = {
    [1] = 1, -- WorldNumber, ZoneNumber
    [2] = 100,
    [3] = 200
}

game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = Config.Client.Anchored

setfpscap(Config.Performance.SetFpsCap)
game:GetService("RunService"):Set3dRenderingEnabled((not Config.Performance.Disable3dRendering))

-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ModuleScripts
local Library = ReplicatedStorage.Library
local Directory = ReplicatedStorage.__DIRECTORY
local Network = ReplicatedStorage.Network

local NetworkModule = require(Library.Client.Network)
local TabController = require(game.ReplicatedStorage.Library.Client.TabController)
local GUI = require(ReplicatedStorage.Library.Client.GUI)

local Save = require(Library.Client.Save)
local Signal = require(Library.Signal)
local Variables = require(Library.Variables)

local LocalPlayer = Players.LocalPlayer

-- Util
local MapUtil = require(Library.Util.MapUtil)
local EggsUtil = require(Library.Util.EggsUtil)
local WorldsUtil = require(Library.Util.WorldsUtil)
local ZonesUtil = require(Library.Util.ZonesUtil)

-- Cmds
local ZoneCmds = require(Library.Client.ZoneCmds)
local CurrencyCmds = require(Library.Client.CurrencyCmds)
local MasteryCmds = require(Library.Client.MasteryCmds)
local FlagCmds = require(Library.Client.ZoneFlagCmds)
local PotionCmds = require(Library.Client.PotionCmds)
local PetCmds = require(Library.Client.PetCmds)
local MapCmds = require(Library.Client.MapCmds)
local RankCmds = require(Library.Client.RankCmds)
local NotificationCmds = require(Library.Client.NotificationCmds)
local BreakableCmds = require(game.ReplicatedStorage.Library.Client.BreakableCmds)
local RebirthCmds = require(Library.Client.RebirthCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)

-- LocalScripts
local AutoTapper = getsenv(LocalPlayer.PlayerScripts.Scripts.GUIs["Auto Tapper"])
local EggAnim = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])

local Machines = {
    World1 = {
        Gold = 10,
        Rainbow = 31
    },
    World2 = {
        SuperComputer = 100
    },
    World3 = {
        SuperComputer = 200
    }
}

if Config.Client.Blackout.Enabled then
    local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    local blackoutFrame = Instance.new("Frame", ScreenGui)
    local rankText = Instance.new("TextLabel", blackoutFrame)

    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder = 999

    blackoutFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    blackoutFrame.Size = UDim2.new(1, 0, 1, 0)

    --[[rankText.BackgroundTransparency = 1
    rankText.Size = blackoutFrame.Size
    rankText.TextColor3 = Color3.new(1, 1, 1)
    rankText.TextSize = 100
    rankText.TextYAlignment = Enum.TextYAlignment.Center
    rankText.TextXAlignment = Enum.TextXAlignment.Center
    rankText.Text = "Rank "..Save.Get().Rank]]

    game:GetService("RunService"):Set3dRenderingEnabled((not Config.Client.Blackout.Disable3dRendering))

    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Config.Client.Blackout.Toggle then
            if Config.Client.Blackout.Disable3dRendering then
                game:GetService("RunService"):Set3dRenderingEnabled(blackoutFrame.Visible)
            end
            blackoutFrame.Visible = (not blackoutFrame.Visible)
        end
    end)
end

local newtbl = table.clone(table)

newtbl.shuffle = function(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end

    return t
end

newtbl.match = function(t, s)
    for _, k in pairs(t) do
        if string.find(s, k) then
            return true
        end
    end

    return false
end

newtbl.duplicates = function(t, k)
    local amt = 0

    for _, v in pairs(t) do
        if v == k then
            amt += 1
        end
    end

    return amt
end

local env = getfenv(1)
env.table = newtbl

setfenv(1, env)

-- Variables
local CurrentlyFarming = true
local GlobalAutoTapper, GlobalAutoUltimate
local CurrentNonBlocking = {}
local ConsumedTNT = 0
local OldZone = nil
local Quests = {}
local DelayedQuests = {}
local IgnoredQuests = Config.AutoRank.IgnoredQuests
local CurrentZone = MapCmds.GetCurrentZone()

for i, v in pairs(require(Library.Types.Quests)["Goals"]) do
    Quests[v] = i
end

-- Anti Afk
for i, v in pairs(getconnections(game.Players.LocalPlayer.Idled)) do
    v:Disable()
end

local vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
   vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
   task.wait(1)
   vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

-- Skip Egg EggAnim
hookfunction(EggAnim.PlayEggAnimation, function()
    return
end)

-- Infinite Pet Speed
hookfunction(require(Library.Client.PlayerPet).CalculateSpeedMultiplier, function()
    return 999
end)

-- Custom Current Zone
hookfunction(MapCmds.GetCurrentZone, function()
    return CurrentZone
end)

if Config.Farming.AutoCollectOrbs then
    local orbs, lootbags = {}, {}

    hookfunction(require(game:GetService("ReplicatedStorage").Library.Client.OrbCmds.Orb).new, function(uid)
        table.insert(orbs, uid)
        return
    end)

    task.spawn(function()
        while task.wait(1) do
            if #orbs > 0 then
                NetworkModule.Fire("Orbs: Collect", orbs)
            end
            if #lootbags > 0 then
                NetworkModule.Fire("Lootbags: Collect", lootbags)
            end
        end
    end)
end

if Config.Misc.DisableItemNotifications then
    require(Library.Client.NotificationCmds).Item.Bottom = function()
        return
    end

    require(Library.Client.NotificationCmds).ItemAlert.Bottom = function()
        return
    end
end

local function parentFunc()
    local info = debug.getinfo(2, "n")
    if info and info.name then
        return info.name
    else
        warn("Caller function not found.")
    end
end

local function getQuests()
    return Save.Get()["Goals"]
end

local function getZoneQuest()
    local quest, questActive = {}, Save.Get().ZoneGateQuest

    if not questActive then
        return
    end

    for i, v in pairs(questActive) do
        quest[i] = v
    end

    quest["Name"] = Quests[quest.Type]

    return quest
end

local function getQuest(num)
    if WorldsUtil.GetWorldNumber() == 3 then
        return getZoneQuest()
    end

    if not num then
        return warn("Missing Quest Number")
    end

    local quest = {}
    for i, v in pairs(getQuests()[tostring(num)]) do
        quest[i] = v
    end
    quest["Name"] = Quests[quest.Type]

    return quest
end

local function getItem(class, name)
    for itemID, data in pairs(Save.Get().Inventory[class]) do
        if data.id:lower() == name:lower() then
            return itemID, (data._am or 1)
        end
    end

    return nil, nil
end

local function getItems(class, filter: table? | string?)
    local items = {}
    if not Save.Get().Inventory[class] then
        return warn("Class '"..class.."' not found")
    elseif typeof(filter) ~= "table" then
        local filt = {}
        filt["id"] = filter
        filter = filt
    elseif filter == nil then
        filter = "All"
    end

    for itemID, data in pairs(Save.Get().Inventory[class]) do
        for k, v in pairs(data) do
            if typeof(filter) == "string" and filter == "All" or filter[k] == v then
                table.insert(items, {ItemID = itemID, Name = data.id, Amount = data._am or 1})
            end
        end
    end

    return items
end

local function SetCurrentZone(zone)
    
end

local function autoTap(name)
    local tapping = true
    local paused = false
    local BreakableUID = nil

    local function Stop()
        tapping = false
    end

    local function Pause()
        paused = true
    end

    local function Resume()
        paused = false
    end

    local function getBreakable()
        local breakables = BreakableCmds.AllByZoneAndClass(MapCmds.GetCurrentZone(), "Normal")
        for i, v in pairs(BreakableCmds.AllByZoneAndClass(MapCmds.GetCurrentZone(), "Chest")) do
            breakables[i] = v
        end

        for _, breakable in pairs(breakables) do
            pcall(function()
                if string.find(breakable:GetAttribute("BreakableID"):lower(), name:lower()) and not string.find(breakable:GetAttribute("BreakableID"):lower(), "vip") then
                    return breakable:GetAttribute("BreakableUID")
                end
            end)
        end
    end

    task.spawn(function()
        while tapping do
            repeat task.wait() until not paused

            if not BreakableUID or not workspace.__THINGS.Breakables:FindFirstChild(BreakableUID) then
               BreakableUID = getBreakable()
            end

            pcall(function() Signal.Fire("AutoClicker_Nearby", BreakableUID or AutoTapper.GetNearestBreakable():GetAttribute("BreakableUID")) end)

            task.wait(.1)
        end
    end)

    return {Stop = Stop, Pause = Pause, Resume = Resume}
end

local function autoUltimate()
    local ultimate = true
    local paused = false

    local function Stop()
        ultimate = false
    end

    local function Pause()
        paused = true
    end

    local function Resume()
        paused = false
    end

    task.spawn(function()
        while ultimate do
            local UltimateItem = UltimateCmds.GetEquippedItem()

            if UltimateItem and UltimateCmds.IsCharged(UltimateItem:GetId()) then
                UltimateCmds.Activate(UltimateItem:GetId())
            elseif not UltimateItem then
                break
            end

            task.wait(1)
        end
    end)

    return {Stop = Stop, Pause = Pause, Resume = Resume}
end

local function TeleportToZone(name, data)
    local Zone, BreakZone = name

    LocalPlayer.Character.HumanoidRootPart.Anchored = Config.Client.Anchored

    if data and data["WorldNumber"] ~= WorldsUtil.GetWorldNumber() then
        return Network["World"..data["WorldNumber"].."Teleport"]:InvokeServer()
    end

    if typeof(name) == "string" then
        Zone = MapUtil.GetZone(name)
    end

    print("[TELEPORT]", name, Zone)
    CurrentZone = name
    MapCmds.ZoneChanged:FireAsync(name)

    LocalPlayer:RequestStreamAroundAsync(Zone["PERSISTENT"]:FindFirstChild("Teleport").Position or Zone["PERSISTENT"]:GetChildren()[1].Position)
    BreakZone = Zone:WaitForChild("INTERACT").BREAK_ZONES.BREAK_ZONE

    if not Zone:FindFirstChild("UndergroundPart") then
        local part = Instance.new("Part", Zone)
        part.Name = "UndergroundPart"
        part.Size = Vector3.new(10, 4, 10)
        part.Anchored = true
        part.Position = Vector3.new(BreakZone.Position.X, BreakZone.Position.Y-10, BreakZone.Position.Z)
        BreakZone.CFrame += Vector3.new(0, -10, 0)
        if Zone:FindFirstChild("_PARTS") then
            Zone._PARTS:Destroy()
        end
        if Zone:FindFirstChild("PARTS") then
            Zone.PARTS:Destroy()
        end
        Zone.PARTS_LOD.GROUND:Destroy()
    end

    LocalPlayer.Character.HumanoidRootPart.CFrame = Zone.UndergroundPart.CFrame + Vector3.new(0, 3, 0)

    return Zone
end

local function romanToInt(roman)
    local romanMap = {
        I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000
    }
    local sum = 0
    local prevValue = 0

    for i = #roman, 1, -1 do
        local char = roman:sub(i, i)
        local value = romanMap[char]

        if value < prevValue then
            sum = sum - value
        else
            sum = sum + value
        end

        prevValue = value
    end

    return sum
end

local function processName(name)
    local properties = {}
    local originalString = name

    if name:find("Shiny") then
        properties.sh = true
        originalString = originalString:gsub("Shiny", "")
    end

    if name:find("Golden") then
        properties.pt = 1
        originalString = originalString:gsub("Golden", "")
    end

    if name:find("Rainbow") then
        properties.pt = 2
        originalString = originalString:gsub("Rainbow", "")
    end

    if name:find("Potion") then
        originalString = originalString:gsub("Potion", "")
    end

    if name:find("Enchant") then
        originalString = originalString:gsub("Enchant", "")
    end

    local namePart, romanPart = originalString:match("(.-)%s+(%u+)$")
    if romanPart and romanPart:match("^[IVXLCDM]+$") then
        properties.tn = romanToInt(romanPart)
        originalString = namePart
    end

    originalString = originalString:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    return originalString, properties
end

local function questStatus(fnc, num, zone: boolean?)
    --if zone then
        
    --else
        if getQuest(num).Progress >= getQuest(num).Amount or
        not string.find(fnc, getQuest(num).Name) or
        --not Config.AutoRank.Enabled and not Config.AutoWorld.AutoQuest or
        not AutoProgress then
            if Config.Client.SimpleDebug then
                print("[FINISHED] Quest")
            end
            return true
        end
    --end

    return false
end

--[[
for name, loadout in pairs(Config.EnchantLoadout) do
    if typeof(loadout) == "table" then
        local tbl = {}
        for _, v in ipairs(loadout) do
            local name = processName(v)
            table.insert(tbl, name)
        end
        Config.EnchantLoadout[name] = tbl
    end
end

local enchants = getItems("Enchant", Config.EnchantLoadout.Cool)
local enchant_ids = {}

for i, v in pairs(enchants) do
    if table.find(Config.EnchantLoadout.Cool, v.Name) and not table.duplicates(enchant_ids, v.ItemID) >= table.duplicates(Config.EnchantLoadout.Cool) then
        print("ID", v.ItemID)
        table.insert(enchant_ids, v.ItemID)
    end
end

for i = 1, Save.Get().MaxEnchantsEquipped do
    NetworkModule.Fire("Enchants_ClearSlot", i)
    task.wait(0.1)
    if enchant_ids[i] then
        NetworkModule.Fire("Enchants_Equip", enchant_ids[i])
    --else
        -- send webhook
        -- break
    end
end
]]
local QuestFunctions
QuestFunctions = {
    SPAWN_OBBY = function()
        if WorldsUtil.GetWorldNumber() ~= 1 then
            return table.insert(IgnoredQuests, parentFunc())
        end
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.SpawnObby.Teleports.Enter.CFrame
        task.wait(9)
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.SpawnObby.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Spawn Obby"})
        task.wait(3)
    end,
    JUNGLE_OBBY = function()
        if WorldsUtil.GetWorldNumber() ~= 1 then
            return table.insert(IgnoredQuests, parentFunc())
        end
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.JungleObby.Teleports.Enter.CFrame
        task.wait(9)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.JungleObby.Interactable.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Jungle Obby"})
        task.wait(5)
    end,
    ICE_OBBY = function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.IceObby.Teleports.Enter.CFrame
        task.wait(9)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.IceObby.Interactable.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Jungle Obby"})
        task.wait(3)
    end,
    PYRAMID_OBBY = function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.PyramidObby.Teleports.Enter.CFrame
        task.wait(9)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.PyramidObby.Interactable.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Pyramid Obby"})
        task.wait(3)
    end,
    ATLANTIS = function()
        if WorldsUtil.GetWorldNumber() ~= 1 then
            return table.insert(IgnoredQuests, parentFunc())
        end
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.Atlantis.Teleports.Enter.CFrame
        repeat task.wait(.1) until workspace.__THINGS.__INSTANCE_CONTAINER.Active:FindFirstChild("Atlantis")
        for i = 1, 31 do
            LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.Atlantis.Rings:WaitForChild(i).Collision.CFrame
            task.wait(1) -- Works with 0.1, doesn't reward unless enough time is spent on the minigame.
        end
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Atlantis Minigame"})
        task.wait(3)
    end,
    CHEST_RUSH = function() -- NOT WORKING
        table.insert(IgnoredQuests, "COLLET_ENCHANT")
        --LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.ChestRush.Teleports.Enter.CFrame
        --task.wait(3)
        --for _, breakZone in pairs(workspace.__THINGS.__INSTANCE_CONTAINER.Active.ChestRush.BREAK_ZONES:GetChildren()) do
            ----game.Players.LocalPlayer.Character.HumanoidRootPart = breakZone
        --end
    end,
    MINEFIELD = function(num)
        local posMap = {}
        local posTbl = {}

        local function checkStatus(pad)
            if pad.BrickColor == BrickColor.new("Lime green") then
                return true
            else
                return false
            end
        end

        for _, mine in pairs(workspace.__THINGS.__INSTANCE_CONTAINER.Active.Minefield.Mines:GetChildren()) do
            if posMap[tostring(math.round(mine.WorldPivot.Position.X))] == nil then
                posMap[tostring(math.round(mine.WorldPivot.Position.X))] = {
                    Complete = checkStatus(mine.Pad),
                    Mines = {
                        mine
                    }
                }

                if posMap[tostring(math.round(mine.WorldPivot.Position.X))].Complete == false then     
                    table.insert(posTbl, math.round(mine.WorldPivot.Position.X))
                end
            else
                table.insert(posMap[tostring(math.round(mine.WorldPivot.Position.X))].Mines, mine)

                posMap[tostring(math.round(mine.WorldPivot.Position.X))].Complete = checkStatus(mine.Pad)
            end
        end

        table.sort(posTbl, function(a, b)
            return a > b
        end)

        repeat
            for _, mine in pairs(posMap[tostring(posTbl[#posTbl])].Mines) do
                if not checkStatus(mine.Pad) and mine.Pad.BrickColor == BrickColor.new("Dark taupe") then
                    repeat task.wait() until LocalPlayer.Character.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead
                    LocalPlayer.Character.HumanoidRootPart.CFrame = mine.Pad.CFrame
                    task.wait(.5)
                    if mine.Pad.BrickColor == BrickColor.new("Lime green") then
                        posMap[tostring(posTbl[#posTbl])].Complete = true
                        table.remove(posTbl, #posTbl)
                    end
                    break
                elseif mine.Pad.BrickColor == BrickColor.new("Lime green") then
                    table.remove(posTbl, #posTbl)
                end
            end
        until #posTbl == 0 or questStatus(parentFunc(), num)
        LocalPlayer.Character.HumanoidRootPart.Position = workspace.__THINGS.__INSTANCE_CONTAINER.Active.Minefield.Model.WorldPivot.Position
    end,
        _RARE_PET = function(num)
        local Eggs = require(game.ReplicatedStorage.Library.Directory.Eggs)
        local EggId = nil
        local HatchCount = Save.Get().EggHatchCount
        --[[
        if Config.EnchantLoadout.Enabled then
            local enchants = getItems("Enchant", Config.EnchantLoadout.Hatching)
            local enchant_ids = {}

            for i, v in pairs(enchants) do
                if table.find(Config.EnchantLoadout.Hatching, v.Name) and not table.duplicates(enchant_ids, v.ItemID) >= table.duplicates(Config.EnchantLoadout.Hatching) then
                    table.insert(enchant_ids, v.ItemID)
                end
            end

            for i = 1, Save.Get().MaxEnchantsEquipped do
                NetworkModule.Fire("Enchants_ClearSlot", i)
                task.wait(0.1)
                if enchant_ids[i] then
                    NetworkModule.Fire("Enchants_Equip", enchant_ids[i])
                --else
                    -- send webhook
                    -- break
                end
            end
        end]]
    
        for i = 1, Save.Get().MaximumAvailableEgg, 1 do
            for _, pet in pairs(Eggs[EggsUtil.GetIdByNumber(i)].pets) do
                if pet[3] and pet[3] == "Insane" then
                    if not EggId or EggId > i and i >= (100 * WorldsUtil.GetWorldNumber()) - 100 then
                        EggId = i
                    end
                    --break
                end
            end
        end
    
        if not EggId then
            return table.insert(IgnoredQuests, parentFunc())
        end
    
        Players.LocalPlayer.Character.HumanoidRootPart.CFrame = (workspace.__THINGS.Eggs:FindFirstChild("World"..WorldsUtil.GetWorldNumber()) or workspace.__THINGS.Eggs:FindFirstChild("Main"))[EggId .. " - Egg Capsule"].Tier.CFrame + Vector3.new(0, 5, 0)
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Hatching "..HatchCount.."x "..EggsUtil.GetIdByNumber(EggId).."s"})
    
        repeat Network.Eggs_RequestPurchase:InvokeServer(EggsUtil.GetIdByNumber(EggId), HatchCount) task.wait(.2) until getQuest(num).Progress >= getQuest(num).Amount or getQuest(num).Name ~= parentFunc()
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Hatch Rare Pet Quest"})
    end,
    BEST_EGG = function(num)
        local EggId = EggsUtil.GetIdByNumber(Save.Get().MaximumAvailableEgg)
        local HatchCount = Save.Get().EggHatchCount
    
        --Players.LocalPlayer.Character.HumanoidRootPart.Anchored = true
        Players.LocalPlayer.Character.HumanoidRootPart.CFrame = (workspace.__THINGS.Eggs:FindFirstChild("World"..WorldsUtil.GetWorldNumber()) or workspace.__THINGS.Eggs:FindFirstChild("Main"))[Save.Get().MaximumAvailableEgg .. " - Egg Capsule"].Tier.CFrame + Vector3.new(0, 5, 0)
    
        --NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting Auto Egg"})
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Hatching "..HatchCount.."x "..EggId.."s"})
    
        repeat Network.Eggs_RequestPurchase:InvokeServer(EggId, HatchCount) task.wait(.2) until getQuest(num).Progress >= getQuest(num).Amount or getQuest(num).Name ~= parentFunc() and not getQuest(num).Name ~= "EGG" or not Config.AutoRank.Enabled or not AutoProgress
        --print(getQuest(num).Name,":", parentFunc())
    
        --Players.LocalPlayer.Character.HumanoidRootPart.Anchored = false
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Egg Quest"})
    end,
    EGG = function(num) -- Temporary
        QuestFunctions.BEST_EGG(num)
    end,
    BEST_COIN_JAR = function(num)
        local Zone, ZoneData = ZoneCmds.GetMaxOwnedZone()

        if ZoneData["WorldNumber"] ~= WorldsUtil.GetWorldNumber() then
            return Network["World"..ZoneData["WorldNumber"].."Teleport"]:InvokeServer()
        end
    
        TeleportToZone(Zone)
    
        LocalPlayer.Character.HumanoidRootPart.CFrame = MapUtil.GetZone(Zone)["INTERACT"]["BREAKABLE_SPAWNS"].Main.CFrame + Vector3.new(0, 5, 0)
    
        repeat
            local item = getItem("Misc", "Basic Coin Jar")
    
            if not item then
                warn("No coin jars available")
                break
            end
    
            Network.CoinJar_Spawn:InvokeServer(item)
    
            task.wait(2)
        until questStatus(parentFunc(), num)

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Coinjar"})
    end,
    COIN_JAR = function(num)
        local Zone, ZoneData = ZonesUtil.GetZoneFromNumber(CoinjarQuestConfig[WorldsUtil.GetWorldNumber()])

        TeleportToZone(Zone)

        LocalPlayer.Character.HumanoidRootPart.CFrame = MapUtil.GetZone(Zone)["INTERACT"]["BREAKABLE_SPAWNS"].Main.CFrame + Vector3.new(0, 5, 0)

        repeat
            local item = getItem("Misc", "Basic Coin Jar")

            if not item then
                warn("No coin jars available")
                break
            end

            Network.CoinJar_Spawn:InvokeServer(item)

            task.wait(2)
        until questStatus(parentFunc(), num)

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Coinjar"})
    end,
    DIAMOND_BREAKABLE = function(num)
        local ZoneNumber = tonumber(MapUtil.GetSpawnZone().Name:match("%d+"))
        local Zone = ZonesUtil.GetZoneFromNumber(ZoneNumber)
        local _, MaxZoneData = ZoneCmds.GetMaxOwnedZone()
        local cn, _ = parentFunc()

        TeleportToZone(Zone)

        GlobalAutoTapper:Pause()
        local autoTapper = autoTap("diamond")

        repeat
            local i = 0

            repeat i = i + 1 until string.find(MapUtil.GetZone(Zone):WaitForChild("INTERACT")["BREAKABLE_SPAWNS"]:GetChildren()[i].Name, "Main")

            LocalPlayer.Character.HumanoidRootPart.CFrame = MapUtil.GetZone(Zone):WaitForChild("INTERACT")["BREAKABLE_SPAWNS"]:GetChildren()[i].CFrame + Vector3.new(0, 5, 0)

            for _, obj in pairs(workspace.__THINGS.Breakables:GetChildren()) do
                if obj:GetAttribute("ParentID") == Zone and obj:GetAttribute("BreakableID") == "Diamond Pile" then
                    print(obj.Name)
                    repeat task.wait() until not workspace.__THINGS.Breakables:FindFirstChild(obj.Name)
                end
            end

            ZoneNumber = ZoneNumber + 1
            Zone = ZonesUtil.GetZoneFromNumber(ZoneNumber)

            if ZoneNumber >= MaxZoneData.ZoneNumber then
                table.insert(DelayedQuests, {Quest = parentFunc(), Time = tick() + 120})
                warn("Paused Diamond Pile")
                return NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Paused Diamond Pile"})
            end

            task.wait(1)
        until getQuest(num).Progress >= getQuest(num).Amount or getQuest(num).Name ~= cn

        autoTapper:Stop()
        GlobalAutoTapper:Resume()

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Diamond Pile"})
    end,
    --[[
    GOLD_PET = function(amt) -- UNTESTED
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.INTERACT.Machines.GoldMachine.Pad.CFrame
        local uid
        for id, data in pairs(Save.Get().Inventory.Pet) do
            if data._am ~= nil and data._am >= 10 and data.pt == nil then
                uid = id
                break
            end
        end

        if uid and math.floor(Save.Get().Inventory.Pet[uid]._am / 10) > 0 then
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Turned "..(math.floor(Save.Get().Inventory.Pet[uid]._am / 10) * 10).."x "..Save.Get().Inventory.Pet[uid].id.." into gold"})

            NetworkModule.Invoke("GoldMachine_Activate", uid, math.floor(Save.Get().Inventory.Pet[uid]._am / 10))
        else
            NotificationCmds.Message.Bottom({Color=Color3.fromRGB(255, 90, 90), Message="No Eligible Pet Found"})
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Hatching Eggs"})
            QuestFunctions["EGG"](((amt or (getQuest().Amount - getQuest().Progress)) * 10))
        end
    end,
    RAINBOW_PET = function() -- UNTESTED
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.INTERACT.Machines.RainbowMachine.Pad.CFrame
        local uid
        for id, data in pairs(Save.Get().Inventory.Pet) do
            if data._am ~= nil and data._am >= 10 and data.pt ~= nil and data.pt == 1 then
                uid = id
                break
            end
        end

        if uid and math.floor(Save.Get().Inventory.Pet[uid]._am / 10) > 0 then
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Turned "..(math.floor(Save.Get().Inventory.Pet[uid]._am / 10) * 10).."x "..Save.Get().Inventory.Pet[uid].id.." into gold"})

            NetworkModule.Invoke("RainbowMachine_Activate", uid, math.floor(Save.Get().Inventory.Pet[uid]._am / 10))
        else
            NotificationCmds.Message.Bottom({Color=Color3.fromRGB(255, 90, 90), Message="No Eligible Pet Found"})
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Hatching Eggs"})
            QuestFunctions["GOLD_PET"]((getQuest().Amount - getQuest().Progress) * 10)
        end
    end,
    ]]
    BEST_RAINBOW_PET = function(num)

    end,
    NON_BLOCKING_CURRENCY = function(num)
            --if getQuest(num).CurrenciID == "Diamonds" then // Non-blocking works fine tbh
        --    DIAMOND_BREAKABLE(num)
        --else
        GlobalAutoTapper:Pause()
        local autoTapper = autoTap(string.sub(getQuest(num).CurrencyID, -1, 1))
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Currency"})
        --end
    end,
    NON_BLOCKING_BREAKABLE = function(num)
        GlobalAutoTapper:Pause()
        local autoTapper
        if getQuest(num).BreakableType then
            if string.find(getQuest(num).BreakableType:lower(), "safe") then
                autoTapper = autoTap("safe")
            else
                autoTapper = autoTap(getQuest(num).BreakableType)
            end
        else
            autoTapper = autoTap()
        end
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Currency"})
        --end
    end,
    NON_BLOCKING_BEST_MINI_CHEST = function(num)
        GlobalAutoTapper:Pause()
        local autoTapper = autoTap("minichest")
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Mini Chest"})
    end,
    NON_BLOCKING_MINI_CHEST = function(num)
        QuestFunctions.NON_BLOCKING_BEST_MINI_CHEST(num)
    end,
    NON_BLOCKING_USE_FLAG = function(num)
        local ZoneName = MapCmds.GetCurrentZone()
        local Zone = MapUtil.GetZone(ZoneName)
    
        LocalPlayer.Character.HumanoidRootPart.CFrame = Zone["INTERACT"]["BREAKABLE_SPAWNS"].Main.CFrame + Vector3.new(0, 5, 0)
    
        task.wait(1)
    
        local item, itemId, amt
        if FlagCmds.GetActiveFlags()[ZoneName] and table.find(Config.AutoRank.Flags, FlagCmds.GetActiveFlags()[ZoneName].ZoneFlag._id) then
            item = FlagCmds.GetActiveFlags()[ZoneName].ZoneFlag._id
            itemId, amt = getItem("Misc", item)
        elseif FlagCmds.GetActiveFlags()[ZoneName] and not table.find(Config.AutoRank.Flags, FlagCmds.GetActiveFlags()[ZoneName].ZoneFlag._id) then
            warn("Zone's Active Flag Not Whitelisted")
        else
            for _, flag in pairs(Config.AutoRank.Flags) do
                itemId, amt = getItem("Misc", flag)
                if itemId and amt then
                    item = flag
                    break
                end
            end
        end
    
        if not item then
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Not Enough Flags"})
        else
            FlagCmds.Consume(item, itemId, (getQuest(num).Amount - getQuest(num).Progress <= amt) and getQuest(num).Amount - getQuest(num).Progress or amt)
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Use Flag"})
        end
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    end,
    NON_BLOCKING_USE_POTION = function(num)
        for _, data in pairs(getItems("Potion", {tn = getQuest(num).PotionTier})) do
            if table.find(Config.AutoRank.Potions, data.Name) then
                for i = 1, data.Amount do
                    PotionCmds.Consume(data.ItemID)
                    if questStatus(parentFunc(), num) then
                        break
                    end
                    task.wait(math.random(0.2, 1))
                end
            end
            if questStatus(parentFunc(), num) then
                break
            end
        end

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Use Potion"})
    end,
    NON_BLOCKING_COLLECT_POTION = function(num)
        table.insert(IgnoredQuests, "COLLECT_POTION")
        --[[
        local _, zoneData = ZoneCmds.GetMaxOwnedZone()
        for i = 2, zoneData.ZoneNumber do
            local Zone = TeleportToZone(ZonesUtil.GetZoneFromNumber(i))
            if Zone:FindFirstChild("INTERACT"):FindFirstChild("Machines") then
                for _, machine in pairs(Zone:FindFirstChild("INTERACT"):FindFirstChild("Machines"):GetChildren()) do
                    if Directory.VendingMachines:FindFirstChild("VendingMachine | "..machine.Name) then
                        local machineModule = require(Directory.VendingMachines["VendingMachine | "..machine.Name])

                        if machineModule.Stock > 0 then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = machine.Pad.CFrame + Vector3.new(0, 2, 0)
                            repeat
                                Network.VendingMachines_Purchase:InvokeServer(machineModule.MachineName, 1)
                                task.wait(.5)
                            until machineModule.Stock <= 0 or questStatus(parentFunc(), num)

                            if questStatus(parentFunc(), num) then
                                break
                            end
                        end
                    end
                end

                if questStatus(parentFunc(), num) then
                    break
                end

                task.wait(.4)
            end
        end

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Collect Potion"})
        ]]
    end,
    NON_BLOCKING_COLLECT_ENCHANT = function(num) -- IGNORED
        table.insert(IgnoredQuests, "COLLET_ENCHANT")
    end,
    NON_BLOCKING_ZONE = function(num)
        repeat
            task.wait(.1)
        until questStatus(parentFunc(), num)
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Unlock Area"})
    end,
    NON_BLOCKING_BEST_SUPERIOR_MINI_CHEST = function(num)
        GlobalAutoTapper:Pause()
        local autoTapper = autoTap("minichest")
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Mini Chest"})
    end,
    NON_BLOCKING_SUPERIOR_MINI_CHEST = function(num)
        QuestFunctions.NON_BLOCKING_BEST_SUPERIOR_MINI_CHEST(num)
    end,
    BEST_COMET = function(num) -- BLOCKING COMET
        local Zone = ZoneCmds.GetMaxOwnedZone()

        --TeleportToZone(Zone)

        --task.wait(1)

        GlobalAutoTapper:Pause()
        local autoTapper = autoTap("comet")
    
        repeat
            local itemId = getItem("Misc", "Comet")
            if itemId then
                local cometFound = false
                for _, obj in pairs(workspace.__THINGS.Breakables:GetChildren()) do
                    if obj:GetAttribute("ParentID") == Zone and obj:GetAttribute("BreakableID") == "Comet" then
                        cometFound = true
                        break
                    end
                end
                if not cometFound then
                    Network.Comet_Spawn:InvokeServer(itemId)
                end
            else
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Not Enough Comets"})
                table.insert(DelayedQuests, {Quest = parentFunc(), Time = tick() + 120})
                return
            end
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Comet"})
    end,
    COMET = function(num)
        local Zone = ZoneCmds.GetMaxOwnedZone()

        --TeleportToZone(Zone)

        --task.wait(1)

        GlobalAutoTapper:Pause()
        local autoTapper = autoTap("comet")
    
        repeat
            local itemId = getItem("Misc", "Comet")
            if itemId then
                local cometFound = false
                for _, obj in pairs(workspace.__THINGS.Breakables:GetChildren()) do
                    if obj:GetAttribute("ParentID") == Zone and obj:GetAttribute("BreakableID") == "Comet" then
                        cometFound = true
                        break
                    end
                end
                if not cometFound then
                    Network.Comet_Spawn:InvokeServer(itemId)
                end
            else
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Not Enough Comets"})
                table.insert(DelayedQuests, {Quest = parentFunc(), Time = tick() + 120})
                return
            end
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Comet"})
    end
}

local function numberSuffix(number)
    local lastDigit = number % 10
    local lastTwoDigits = number % 100
    local suffix = (lastTwoDigits == 11 or lastTwoDigits == 12 or lastTwoDigits == 13) and "th" or
                   (lastDigit == 1 and "st" or
                   lastDigit == 2 and "nd" or
                   lastDigit == 3 and "rd" or "th")
    return tostring(number..suffix)
end

if Config.Performance.FpsBooster.Enabled then
    LocalPlayer.Character.HumanoidRootPart.Anchored = false

    local blacklist = {
        "Idle Tracking",
        "Mobile",
        "Server Closing",
        "Pending",
        "Inventory",
        "Ultimate",
        "ClientMagicOrbs",
        "Random Global Events",
        "Currency 2",
        "Pet",
        "Egg"
    }
    
    for _, v in pairs(game:GetService("Players").LocalPlayer.PlayerScripts.Scripts:GetDescendants()) do
        if v:IsA("Script") and not table.match(blacklist, v.Name) and ((not v.Parent) or v.Parent.Name ~= "Breakables") and ((not v.Parent) or v.Parent.Name ~= "Random Events") and ((not v.Parent) or v.Parent.Name ~= "GUI") then
            if Config.Client.Debug then
                print("[PERFORMANCE][PLAYERSCRIPTS][DESTROYED]", v.Name)
            end
            v:Destroy()
        end
    end
    
    local blacklist = {
        "Flags",
        "Sprinkler",
        "Instances",
        "Items",
        "Loot",
        "Orb",
        "__",
        "Breakable",
        "RandomEvents",
        "Chest",
        "Egg",
        "Pet"
    }
    
    local whitelist = {
        "RenderedEggs",
        "__FAKE_GROUND"
    }
    
    local path = (workspace.__THINGS.Eggs:FindFirstChild("World"..WorldsUtil.GetWorldNumber()) or workspace.__THINGS.Eggs.Main)
    for i, v in pairs(path:GetChildren()) do
        local p = Instance.new("Part", path)
        p.Name = v.Name
        p.Anchored = true
        p.CFrame = v.WorldPivot
        if Config.Client.Debug then
            print("[PERFORMANCE][EGGS][DESTROYED]", v.Name)
        end
        v:Destroy()
    end
    
    for _, v in pairs(workspace.__THINGS:GetChildren()) do
        if (not table.match(blacklist, v.Name) or table.match(whitelist, v.Name)) then
            if Config.Client.Debug then
                print("[PERFORMANCE][__THINGS][DESTROYED]", v.Name)
            end
            v:Destroy()
        end
    end
    
    local paths = {
        (workspace:FindFirstChild("ALWAYS_RENDERING_"..WorldsUtil.GetWorldNumber()) or workspace.ALWAYS_RENDERING),
        (workspace:FindFirstChild("Border"..WorldsUtil.GetWorldNumber()) or workspace.Border),
        (workspace:FindFirstChild("FlyBorder"..WorldsUtil.GetWorldNumber()) or workspace.FlyBorder),
        --workspace.__DEBRIS
    }
    
    for _, v in pairs(paths) do
        if v.Parent then
            if Config.Client.Debug then
                print("[PERFORMANCE][PATH][DESTROYED]", v.Name)
            end
            v:Destroy()
        end
    end
    
    if Config.Performance.FpsBooster.InvisibleMap then
        if Config.Client.Debug then
            print("[PERFORMANCE] Invisible Map")
        end
        for _, v in pairs(WorldsUtil.GetMap():GetDescendants()) do
            pcall(function()
                v.Transparency = 1
            end)
        end
    end
    
    for i, v in pairs(require(game:GetService("ReplicatedStorage").Library.Client.WorldFX)) do
        if Config.Client.Debug then
            print("[PERFORMANCE][WORLDFX][DISABLED]", i)
        end
        require(game:GetService("ReplicatedStorage").Library.Client.WorldFX)[i] = function()
            return
        end
    end
    
    for i, v in pairs(game:GetService("ReplicatedStorage").Assets.Particles:GetDescendants()) do
        if v:IsA("ParticleEmitter") then
            if Config.Client.Debug then
                print("[PERFORMANCE][PARTICLES][DISABLED]", v.Name)
            end
            v.Texture = ""
            v.TimeScale = 0
        end
    end
end

if workspace.__THINGS:FindFirstChild("__FAKE_GROUND") then
    workspace.__THINGS.__FAKE_GROUND:Destroy()
end

-- Auto World 
task.spawn(function()
    if Config.AutoWorld.Enabled then
        GlobalAutoTapper = autoTap()
        GlobalAutoUltimate = autoUltimate()
    end
    
    print("[STARTING] Auto Rank")

    while AutoProgress and Config.AutoWorld.Enabled do
        repeat task.wait() until CurrentlyFarming

        if not OldZone or ZoneCmds.GetMaxOwnedZone() ~= OldZone and not Variables.IsRankingUp then
            --if RebirthCmds.Get() >= 4 and WorldsUtil.GetWorld().WorldNumber == 1 then
                --ReplicatedStorage.Network.World2Teleport:InvokeServer()
            --end

            local ZoneData
            OldZone, ZoneData = ZoneCmds.GetMaxOwnedZone()

            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="New Zone Unlocked!"}) -- [10/239]

            if Config.AutoWorld.PurchasePetSlots then
                if Save.Get().PetSlotsPurchased < RankCmds.GetMaxPurchasableEquipSlots() and not Variables.IsRankingUp then--and WorldsUtil.GetWorldNumber() == 1 then
                    --local Zone = TeleportToZone("Green Forest")
                    --LocalPlayer.Character.HumanoidRootPart.Anchored = true
                    --LocalPlayer.Character.HumanoidRootPart.CFrame = Zone.INTERACT.Machines.EquipSlotsMachine.Pad.CFrame

                    for n = Save.Get().PetSlotsPurchased, RankCmds.GetMaxPurchasableEquipSlots() do
                        task.wait(1)
                        Network.EquipSlotsMachine_RequestPurchase:InvokeServer(n)
                        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message=numberSuffix(n).." Pet Slot Unlocked!"})
                    end

                    --LocalPlayer.Character.HumanoidRootPart.Anchored = false
                end
            end

            TeleportToZone(ZoneCmds.GetMaxOwnedZone())

            task.wait(1)

            if Config.AutoWorld.UseTntOnNewZone and (not Config.AutoWorld.SmartTnt or ZoneData.ZoneNumber >= SmartTntConfig[RebirthCmds.Get()].Min and ZoneData.ZoneNumber <= SmartTntConfig[RebirthCmds.Get()].Max) then
                ConsumedTNT = ConsumedTNT + 1
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Consuming "..numberSuffix(ConsumedTNT).." TNT"})
                Network.TNT_Crate_Consume:InvokeServer()
            end
        else
            if ZoneCmds.GetNextZone() then
                ReplicatedStorage.Network.Zones_RequestPurchase:InvokeServer(ZoneCmds.GetNextZone())
            else
                break
            end
            task.wait(1)
        end

        if WorldsUtil.GetWorldNumber() == 3 and getZoneQuest() then
            local quest = getZoneQuest()

            if not ((QuestFunctions["NON_BLOCKING_"..quest.Name] ~= nil and QuestFunctions["NON_BLOCKING_"..quest.Name]()) or (QuestFunctions[quest.Name] and QuestFunctions[quest.Name]())) then
                NotificationCmds.Message.Bottom({Color=Color3.fromRGB(255, 90, 90), Message=quest.Name.." not found!"})
                --error(quest.Name.." not found")
                --return
            end
        end

    end

    print("[DISABLED] Auto World")
end)

-- TNT Interval
task.spawn(function()
    while AutoProgress and Config.AutoWorld.UseTntOnDelay do
        repeat task.wait() until CurrentlyFarming

        ConsumedTNT = ConsumedTNT + 1
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Consuming "..numberSuffix(ConsumedTNT).." TNT"})
        Network.TNT_Crate_Consume:InvokeServer()

        task.wait(Config.AutoWorld.TntDelay)
    end
end)

-- Anti Afk
task.spawn(function()
    while AutoProgress do
        NetworkModule.Fire("Idle Tracking: Stop Timer")
        task.wait(math.random(0, 1.5))
    end
end)

-- Auto Collect Orbs
task.spawn(function()
    for _, v in pairs(workspace.__THINGS.Orbs:GetDescendants()) do
        ReplicatedStorage.Network["Orbs: Collect"]:FireServer(tonumber(v.Name))
        task.spawn(function()
            task.wait(.1)
            v:Destroy()
        end)
    end

    workspace.__THINGS.Orbs.DescendantAdded:Connect(function(descendant)
        ReplicatedStorage.Network["Orbs: Collect"]:FireServer(tonumber(descendant.Name))
        task.spawn(function()
            task.wait(.1)
            descendant:Destroy()
        end)
    end)

    for _, v in pairs(workspace.__THINGS.Lootbags:GetChildren()) do
        ReplicatedStorage.Network.Lootbags_Claim:FireServer(tostring(v.Name))
        task.spawn(function()
            task.wait(.1)
            v:Destroy()
        end)
    end

    workspace.__THINGS.Lootbags.DescendantAdded:Connect(function(descendant)
        ReplicatedStorage.Network.Lootbags_Claim:FireServer(tostring(descendant.Name))
        task.spawn(function()
            task.wait(.1)
            descendant:Destroy()
        end)
    end)
end)

-- Auto Tap
task.spawn(function()
    while AutoProgress and Config.AutoWorld.AutoTap do
        repeat task.wait() until CurrentlyFarming
        pcall(function() Signal.Fire("AutoClicker_Nearby", AutoTapper.GetNearestBreakable():GetAttribute("BreakableUID")) end)
        task.wait(.1)
    end
end)

-- Auto Ultimate
task.spawn(function()
    while AutoWorld do
        repeat task.wait() until CurrentlyFarming
        local UltimateItem = UltimateCmds.GetEquippedItem()

        if UltimateItem and UltimateCmds.IsCharged(UltimateItem:GetId()) then
            UltimateCmds.Activate(UltimateItem:GetId())
        end

        task.wait(1)
    end
end)

-- Auto Rebirth
task.spawn(function()
    while AutoProgress and Config.AutoWorld.AutoRebirth do
        repeat task.wait() until CurrentlyFarming
        if not RebirthCmds.GetNextRebirth() then break end
        local _, ZoneData = ZoneCmds.GetMaxOwnedZone()
        local NextRebirth = RebirthCmds.GetZoneNumberByRebirth(RebirthCmds.GetNextRebirth().RebirthNumber)

        if ZoneData.ZoneNumber >= RebirthCmds.GetNextRebirth().ZoneNumberRequired then
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Rebirthing to Rebirth "..RebirthCmds.GetNextRebirth().RebirthNumber})
            ReplicatedStorage.Network.Rebirth_Request:InvokeServer(tostring(RebirthCmds.GetNextRebirth().RebirthNumber))
        else
            break
        end
        task.wait(1.5)
    end
end)

task.wait(4)

-- Statistics
task.spawn(function()
    while Config.Webhooks.Statistics.Enabled do
        task.wait(Config.Webhooks.Statistics.Delay)
        local data = {
            ["username"] =  "webhook thingie",
            ["avatar_url"] = "https://cdn.discordapp.com/avatars/593552251939979275/58ea82801d6003749293c7bba1efabc8.webp?size=1024&format=webp&width=0&height=256",
            ["content"] = "",
            ["embeds"] = {
                {
                    ["author"] = {
                        ["name"] = game.Players.LocalPlayer.Name,
                        ["url"] = "https://www.roblox.com/users/" ..game.Players.LocalPlayer.UserId,
                        ["icon_url"] = HttpService:JSONDecode(request({Url = "https://thumbnails.roblox.com/v1/users/avatar-bust?userIds=" .. game.Players.LocalPlayer.UserId .. "&size=420x420&format=Png&isCircular=false", Method = "GET", Headers = {["Content-Type"] = "application/json"}}).Body).data[1].imageUrl,
                    },
                    ["title"] = "Pet Simulator 99 ("..Config.Webhooks.Statistics.Delay.."s)",
                    ["color"] = 0x212325,
                    ["thumbnail"] = {
                        ["url"] = "https://cdn.discordapp.com/attachments/1213966172932939816/1252329987114139758/6ocaKOJ.png?ex=6671d2b0&is=66708130&hm=c3792d7e1c5b7cb4db88b20aeb8922f9c448510b591ec486a885b9ce3a1e582f&"
                    },
                    ["footer"] = {
                        ["text"] = "00:00:007 - Wave 8 - Foosha Village"
                    }
                },
            },
            ['timestamp'] = DateTime(),
        }

        request({Url = Config.Webhooks.Statistics.WebhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
    end
end)

-- Auto Rank
task.spawn(function()
    local dqt = {}

    local function checkQuest(quest)
        print(typeof(IgnoredQuests), typeof(dqt), typeof(CurrentNonBlocking))
        if QuestFunctions["NON_BLOCKING_"..quest] and not table.find(IgnoredQuests, quest) and not table.find(dqt, quest) and not table.find(CurrentNonBlocking, quest) and not Variables.IsRankingUp then
            return "NON_BLOCKING", QuestFunctions["NON_BLOCKING_"..quest]
        elseif QuestFunctions[quest] and not table.find(IgnoredQuests, quest) and not table.find(dqt, quest) and #CurrentNonBlocking == 0 and not Variables.IsRankingUp then
            return "BLOCKING", QuestFunctions[quest]
        end
    end

    print("[STARTING] Auto Rank")

    while AutoProgress and Config.AutoRank.Enabled and WorldsUtil.GetWorldNumber() ~= 3 do
        if typeof(Config.AutoRank.InitialRank) == "boolean" and Config.AutoRank.InitialRank == false or Save.Get().Rank >= Config.AutoRank.InitialRank then
            print("[FINISHED] Initial Auto Rank")
        end

        if #getQuests() == 0 then
            for i = 1, 20, 1 do
                Network.Ranks_ClaimReward:FireServer(i)
                task.wait(.1)
            end
            
            task.wait(1)

            Network.Ranks_RankUp:FireServer()
        end

        table.clear(dqt)
        for i, v in ipairs(DelayedQuests) do
            if v.Time >= tick() then
                table.remove(DelayedQuests, i)
            else
                table.insert(dqt, v.Quest)
            end
        end

        for i, data in pairs(getQuests()) do
            local quest = getQuest(i)
            --for i, v in pairs(quest) do print(i, v) end
            local check, questFunc = checkQuest(quest.Name)
            if check and check == "NON_BLOCKING" then
                print("[STARTING] NON BLOCKING "..quest.Name)
                --CurrentlyFarming = false
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting "..quest.Name})
                questFunc(i)
                --CurrentlyFarming = true
            elseif check and check == "BLOCKING" and WorldsUtil.GetWorldNumber() ~= 3 then
                print("[STARTING] BLOCKING "..quest.Name)
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting "..quest.Name})
                CurrentlyFarming = false
                task.wait(.1)
                questFunc(i)
                TeleportToZone(ZoneCmds.GetMaxOwnedZone())
                CurrentlyFarming = true
                --NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed "..quest.Name})
            else
                warn("[SKIPPING] "..quest.Name)
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 0.917647, 0.447058), Message="Skipping "..quest.Name})
            end
        end
    end

    print("[DISABLED] Auto Rank")
end)
