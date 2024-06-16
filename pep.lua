getgenv().AutoProgress = false
--task.wait(2)
getgenv().AutoProgress = true
getgenv().Config = {
    PotatoMode = false, -- ⚠️
    AutoWorld = {
        Enabled = true,
        PurchasePetSlots = true, -- 🙏
        AutoTap = true -- 🙏
    },
    AutoRank = {
        Enabled = true, -- 🙏
        InitialRank = 10, -- Rank up to rank 3 before/during Auto World, false to skip. 🙏
        Flags = {"Magnet Flag", "Coins Flag", "Hasty Flag", "Magnet Flag", "Diamonds Flag"}, -- Flags to use for USE_FLAG quest 🙏
        Potions = {"Damage", "Coins", "Egg", "Speed", "Diamonds", "Treasure Hunter"} -- Potions to use for USE_POTION quest 🙏
    },
    SmartTnt = false, -- 🙏
    UseTntOnNewZone = false, -- 🙏
    UseTntOnDelay = false, -- Use tnt on set intervals, does not respect SmartTnt -- ⚠️
    TntDelay = 10 -- Interval Delay -- ⚠️
}
getgenv().SmartTntConfig = { -- 🙏
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

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ModuleScripts
local Library = ReplicatedStorage.Library
local Directory = ReplicatedStorage.__DIRECTORY
local Network = ReplicatedStorage.Network

local NetworkModule = require(Library.Client.Network)

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

--[[
for itemID, data in pairs(Save.Get().Inventory["Potion"]) do
    print(itemID, "------------------")
    for i, v in pairs(data) do
        print(i, v)
    end
end
]]

-- Skip Egg EggAnim
hookfunction(EggAnim.PlayEggAnimation, function()
    return
end)

-- Infinite Pet Speed
hookfunction(require(Library.Client.PlayerPet).CalculateSpeedMultiplier, function()
    return 999
end)

-- Variables
local CurrentlyFarming = true
local GlobalAutoTapper = nil
local CurrentNonBlocking = {}
local ConsumedTNT = 0
local OldZone = nil
local Quests = {}
local DelayedQuests = {}
local IgnoredQuests = {}

for i, v in pairs(require(Library.Types.Quests)["Goals"]) do
    Quests[v] = i
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

local function getQuest(num)
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
            if string.find(breakable:GetAttribute("BreakableID"):lower(), name:lower()) and not string.find(breakable:GetAttribute("BreakableID"):lower(), "vip") then
                return breakable:GetAttribute("BreakableUID")
            end
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

    local function Stop()
        ultimate = false
    end

    task.spawn(function()
        while ultimate do
            local UltimateItem = UltimateCmds.GetEquippedItem()

            if UltimateCmds.IsCharged(UltimateItem:GetId()) then
                UltimateCmds.Activate(UltimateItem:GetId())
            end

            task.wait(1)
        end
    end)

    return {Stop = Stop}
end

local function TeleportToZone(name, data)
    local Zone = name

    if data and data["WorldNumber"] ~= WorldsUtil.GetWorldNumber() then
        return Network["World"..WorldsUtil.GetWorldNumber().."Teleport"]:InvokeServer()
    end

    if typeof(name) == "string" then
        Zone = MapUtil.GetZone(name)
    end

    print(name, Zone)

    LocalPlayer:RequestStreamAroundAsync(Zone["PERSISTENT"]:FindFirstChild("Teleport").Position or Zone["PERSISTENT"]:GetChildren()[1].Position)

    local i = 0
    repeat i = i + 1 until string.find(Zone:WaitForChild("INTERACT")["BREAKABLE_SPAWNS"]:GetChildren()[i].Name, "Main")
    LocalPlayer.Character.HumanoidRootPart.CFrame = Zone:WaitForChild("INTERACT"):WaitForChild("BREAKABLE_SPAWNS"):GetChildren()[i].CFrame --+ Vector3.new(0, 5, 0)

    return Zone
end

local QuestFunctions
QuestFunctions = {
    SPAWN_OBBY = function()
        if WorldsUtil.GetWorldNumber() ~= 1 then
            return table.insert(IgnoredQuests, parentFunc())
        end
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.SpawnObby.Teleports.Enter.CFrame
        task.wait(12)
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.SpawnObby.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Spawn Obby"})
        task.wait(3)
    end,
    JUNGLE_OBBY = function()
        if WorldsUtil.GetWorldNumber() ~= 1 then
            return table.insert(IgnoredQuests, parentFunc())
        end
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.JungleObby.Teleports.Enter.CFrame
        task.wait(12)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.JungleObby.Interactable.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Jungle Obby"})
        task.wait(5)
    end,
    ICE_OBBY = function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.IceObby.Teleports.Enter.CFrame
        task.wait(12)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.IceObby.Interactable.Goal.Pad.CFrame
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Jungle Obby"})
        task.wait(3)
    end,
    PYRAMID_OBBY = function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.Instances.PyramidObby.Teleports.Enter.CFrame
        task.wait(12)
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
        until #posTbl == 0 or getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress
        LocalPlayer.Character.HumanoidRootPart.Position = workspace.__THINGS.__INSTANCE_CONTAINER.Active.Minefield.Model.WorldPivot.Position
    end,
    HATCH_RARE_PET = function(num)
        local Eggs = require(game.ReplicatedStorage.Library.Directory.Eggs)
        local EggId = nil
        local HatchCount = Save.Get().EggHatchCount
    
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
    
        Players.LocalPlayer.Character.HumanoidRootPart.Anchored = false
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Egg Quest"})
    end,
    EGG = function(num) -- Temporary
        QuestFunctions.BEST_EGG(num)
    end,
    BEST_COIN_JAR = function(num) -- CAN BE MODIFIED
        local Zone, ZoneData = ZoneCmds.GetMaxOwnedZone()
        local CurrentWorldNumber = WorldsUtil.GetWorldNumber()
    
        if ZoneData["WorldNumber"] ~= CurrentWorldNumber then
            return Network["World"..CurrentWorldNumber.."Teleport"]:InvokeServer()
        end
    
        TeleportToZone(Zone)
    
        LocalPlayer.Character.HumanoidRootPart.CFrame = MapUtil.GetZone(Zone)["INTERACT"]["BREAKABLE_SPAWNS"].Main.CFrame + Vector3.new(0, 5, 0)
    
        while getQuest(num).Progress < getQuest(num).Amount do
            local item = getItem("Misc", "Basic Coin Jar")
    
            if not item then
                warn("No coin jars available")
                break
            end
    
            Network.CoinJar_Spawn:InvokeServer(item)
    
            task.wait(2)
        end
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Best Coinjar"})
    end,
    COIN_JAR = function(num) -- Temporary
        QuestFunctions.BEST_COIN_JAR(num)
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
                return NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Paused Diamond Pile"})
            end

            task.wait(.5)
        until getQuest(num).Progress >= getQuest(num).Amount or getQuest(num).Name ~= cn

        autoTapper:Stop()
        GlobalAutoTapper:Resume()

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Diamond Pile"})
    end,
    NON_BLOCKING_CURRENCY = function(num)
            --if getQuest(num).CurrenciID == "Diamonds" then // Non-blocking works fine tbh
        --    DIAMOND_BREAKABLE(num)
        --else
        GlobalAutoTapper:Pause()
        local autoTapper = autoTap(getQuest(num).CurrencyID)
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)

        autoTapper:Stop()
        GlobalAutoTapper:Resume()

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Currency"})
        --end
    end,
    NON_BLOCKING_MINI_CHEST = function(num)
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name)
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Mini Chest"})
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
                    if getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress then
                        break
                    end
                    task.wait(math.random(0.2, 1))
                end
            end
            if getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress then
                break
            end
        end

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Use Potion"})
    end,
    NON_BLOCKING_COLLECT_POTION = function(num)
        local _, zoneData = ZoneCmds.GetMaxOwnedZone()
        for i = 2, zoneData.ZoneNumber do
            local Zone = TeleportToZone(ZonesUtil.GetZoneFromNumber(i))
            if Zone:FindFirstChild("INTERACT"):FindFirstChild("Machines") then
                for _, machine in pairs(Zone:FindFirstChild("INTERACT"):FindFirstChild("Machines"):GetChildren()) do
                    local machineModule = require(Directory["VendingMachine"..machine.Name])

                    if machineModule.Stock > 0 then
                        LocalPlayer.Character.Humanoid.CFrame = machine.Pad.CFrame + Vector3.new(0, 2, 0)
                        repeat
                            Network.VendingMachines_Purchase:InvokeServer(machine.MachineName, 1)
                            task.wait(.5)
                        until machine.Stock <= 0 or getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress

                        if getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress then
                            break
                        end
                    end
                end

                if getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress then
                    break
                end

                task.wait(.4)
            end
        end

        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))

        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Collect Potion"})
    end,
    NON_BLOCKING_COLLECT_ENCHANT = function(num) -- IGNORED
        table.insert(IgnoredQuests, "COLLET_ENCHANT")
    end,
    NON_BLOCKING_ZONE = function(num)
        repeat
            task.wait(.1)
        until getQuest(num).Progress >= getQuest(num).Amount or not string.find(parentFunc(), getQuest(num).Name) or not Config.AutoRank.Enabled or not AutoProgress
    
        table.remove(CurrentNonBlocking, table.find(CurrentNonBlocking, parentFunc()))
    
        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed Unlock Area"})
    end,
    NON_BLOCKING_BEST_COMET = function(num)
        local Zone = ZoneCmds.GetMaxOwnedZone()

        --TeleportToZone(Zone)

        task.wait(1)
    
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

-- Auto World 
task.spawn(function()
    if Config.AutoWorld.Enabled then
        GlobalAutoTapper = autoTap()
    end

    while AutoProgress and Config.AutoWorld.Enabled do
        repeat task.wait() until CurrentlyFarming

        if not OldZone or ZoneCmds.GetMaxOwnedZone() ~= OldZone and not Variables.IsRankingUp then
            --if RebirthCmds.Get() >= 4 and WorldsUtil.GetWorld().WorldNumber == 1 then
                --ReplicatedStorage.Network.World2Teleport:InvokeServer()
            --end

            local ZoneData
            OldZone, ZoneData = ZoneCmds.GetMaxOwnedZone()

            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="New Zone Unlocked!"}) -- [10/239]

            if Config.PurchasePetSlots then
                if Save.Get().PetSlotsPurchased < RankCmds.GetMaxPurchasableEquipSlots() and not Variables.IsRankingUp and WorldsUtil.GetWorldNumber() == 1 then
                    local Zone = TeleportToZone("Green Forest")
                    LocalPlayer.Character.HumanoidRootPart.Anchored = true
                    LocalPlayer.Character.HumanoidRootPart.CFrame = Zone.INTERACT.Machines.EquipSlotsMachine.Pad.CFrame

                    for n = Save.Get().PetSlotsPurchased,  RankCmds.GetMaxPurchasableEquipSlots() do
                        task.wait(1)
                        Network.EquipSlotsMachine_RequestPurchase:InvokeServer(n)
                    end

                    LocalPlayer.Character.HumanoidRootPart.Anchored = false
                end
            end

            TeleportToZone(ZoneCmds.GetMaxOwnedZone())

            task.wait(1)

            if Config.UseTntOnNewZone and (not Config.SmartTnt or ZoneData.ZoneNumber >= SmartTntConfig[RebirthCmds.Get()].Min and ZoneData.ZoneNumber <= SmartTntConfig[RebirthCmds.Get()].Max) then
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
    while AutoProgress do
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

-- Auto Rank
task.spawn(function()
    local dqt = {}
    local IgnoredQuests = {}

    local function checkQuest(quest)
        if QuestFunctions["NON_BLOCKING_"..quest] and not table.find(IgnoredQuests, quest.Name) and not table.find(dqt, quest.Name) and not table.find(CurrentNonBlocking, quest.Name) and not Variables.IsRankingUp then
            return "NON_BLOCKING", QuestFunctions["NON_BLOCKING_"..quest]
        elseif QuestFunctions[quest] and not table.find(IgnoredQuests, quest.Name) and not table.find(dqt, quest.Name) and #CurrentNonBlocking == 0 and not Variables.IsRankingUp then
            return "BLOCKING", QuestFunctions[quest]
        end
    end

    while AutoProgress and Config.AutoRank.Enabled do
        if typeof(Config.AutoRank.InitialRank) == "boolean" and Config.AutoRank.InitialRank == false or Save.Get().Rank >= Config.AutoRank.InitialRank then
            print("Auto Rank has finished doing initial rank")
        end

        if #getQuests() == 0 then
            for i = 1, 20, 1 do
                Network.Ranks_ClaimReward:FireServer(i)
                task.wait(.1)
            end
            
            task.wait(1)

            Network.Ranks_RankUp:FireServer()
        end

        for i, data in pairs(getQuests()) do
            local quest = getQuest(i)
            for i, v in pairs(quest) do print(i, v) end
            local check, questFunc = checkQuest(quest.Name) 
            if check and check == "NON_BLOCKING" then
                print("[STARTING] NON BLOCKING "..quest.Name)
                CurrentlyFarming = false
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting "..quest.Name})
                questFunc(i)
            elseif check and check == "BLOCKING" then
                print("[STARTING] BLOCKING "..quest.Name)
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting "..quest.Name})
                CurrentlyFarming = false
                task.wait(.1)
                questFunc(i)
                TeleportToZone(ZoneCmds.GetMaxOwnedZone())
                CurrentlyFarming = true
                --NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Completed "..quest.Name})
            else
                warn("Skipping "..quest.Name)
                NotificationCmds.Message.Bottom({Color=Color3.new(1, 0.917647, 0.447058), Message="Skipping "..quest.Name})
            end
        end
    end
end)
