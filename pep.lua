-- Services
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

--for i, v in pairs(Save.Get().GoodVsEvilEvent) do print(i, v) end

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
local InstancingCmds = require(Library.Client.InstancingCmds)
local InstanceZoneCmds = require(Library.Client.InstanceZoneCmds)
local BreakableCmds = require(game.ReplicatedStorage.Library.Client.BreakableCmds)
local RebirthCmds = require(Library.Client.RebirthCmds)
local UltimateCmds = require(Library.Client.UltimateCmds)

-- LocalScripts
local RankUp = game.Players.LocalPlayer.PlayerScripts.Scripts.GUIs["Rank Up"]
local AutoTapper = getsenv(LocalPlayer.PlayerScripts.Scripts.GUIs["Auto Tapper"])
local EggAnim = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])

-- Variables
local Quests = {}
local EggPos = {Vector3.new(-2160, 293, -15471), Vector3.new(-1853, 290, -15527)}

for i, v in pairs(require(Library.Types.Quests)["Goals"]) do
    Quests[v] = i
end

local oldmath = table.clone(math)

local function new(x)
    if typeof(x) == "Vector3" then
        return Vector3.new(
            oldmath.round(x.X),
            oldmath.round(x.Y),
            oldmath.round(x.Z)
        )
    else
        return oldmath.round(x)
    end
end

local env = getfenv(1)
env.math = setmetatable({round = new}, {__index = oldmath})

setfenv(1, env)

-- Skip Egg EggAnim
hookfunction(EggAnim.PlayEggAnimation, function()
    return
end)

-- Infinite Pet Speed
hookfunction(require(Library.Client.PlayerPet).CalculateSpeedMultiplier, function()
    return 999
end)

local function parentFunc()
    local info = debug.getinfo(2, "n")
    if info and info.name then
        return info.name
    else
        warn("Caller function not found.")
    end
end

local function getQuest()
    local quest, questActive = {}, InstancingCmds.Get():GetSavedValue("QuestActive")

    if not questActive then
        return
    end

    for i, v in pairs(questActive) do
        quest[i] = v
    end

    quest["Name"] = Quests[quest.Type]

    return quest
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

local QuestFunctions
QuestFunctions = {
    BREAKABLE = function()
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame --+ Vector3.new(0, 10, 0) --workspace.__THINGS.Instances.GoodEvilInstance.BREAKABLE_SPAWNS["Main_"..InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0)
        repeat task.wait() until not getQuest() or getQuest().Name ~= parentFunc() or CurrencyCmds.Get("GoodVsEvilCoins") >= 1250 and #Save.Get().Inventory.Pet <= 3-- or getQuest().Progress >= getQuest().Amount
        if CurrencyCmds.Get("GoodVsEvilCoins") >= 1250 and #Save.Get().Inventory.Pet <= 5 then
            QuestFunctions["EGG"](5, true)
        end
        repeat task.wait() until not getQuest() or getQuest().Name ~= parentFunc()
    end,
    EGG = function(amt, nonExplicit)
        LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0)
        task.wait(.5)
        local EggId, cAmt
        local Hatched = 0
        for _, v in pairs(workspace.__THINGS.CustomEggs:GetChildren()) do
            if v:FindFirstChild("EggLock") and v.EggLock.Transparency == 1 then
                if (v.EggLock.Position - workspace.__THINGS.Instances.GoodEvilInstance.BREAKABLE_SPAWNS["Main_"..InstanceZoneCmds.GetMaximumOwnedZoneNumber()].Position).Magnitude < 60 then --workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].Position).Magnitude < 60 then-
                    EggId = v.Name
                    LocalPlayer.Character.HumanoidRootPart.CFrame = v.PriceHUD.CFrame
                end
            end
        end
        repeat task.wait(.1)
            local success = Network.CustomEggs_Hatch:InvokeServer(EggId, Save.Get().EggHatchCount)
            if success then
                Hatched += Save.Get().EggHatchCount
                if Hatched >= amt and nonExplicit then
                    break
                end
                for _, data in pairs(Save.Get().Inventory.Pet) do
                    if data._am ~= nil and data._am >= amt and data.pt == nil then
                        cAmt = true
                        NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Finished Hatching Eggs"})
                    end
                end
            end
        until amt and cAmt or not amt and (not getQuest() or not getQuest().Name == parentFunc() or getQuest().Progress >= getQuest().Amount)
    end,
    GOLD_PET = function(amt)
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
    RAINBOW_PET = function()
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
    end
}

if not Save.Get().PickedStarterPet then
    NetworkModule.Invoke("Pick Starter Pets", "Axolotl", "Cat")
end

if not InstancingCmds.IsInInstance("GoodEvilInstance") then
    if workspace.Map["1 | Spawn"].PARTS:FindFirstChild("EvilGoodDecor") then
        workspace.Map["1 | Spawn"].PARTS.EvilGoodDecor:Destroy()
    end

    LocalPlayer.Character.Humanoid:MoveTo(Vector3.new(180, 18, -139))

    task.wait(13)

    if Save.Get().GoodVsEvilEvent.Team ~= 1 and Save.Get().GoodVsEvilEvent.Team ~= 2 then
        local eggId
        for _, v in pairs(workspace.__THINGS.CustomEggs:GetChildren()) do
            if v:FindFirstChild("PriceHUD") and table.find(EggPos, math.round(v.PriceHUD.Position)) then
                eggId = v.Name
            end
        end

        --LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.CustomEggs[eggId].PriceHUD.CFrame + Vector3.new(5, 0, 0)
        LocalPlayer.Character.Humanoid:MoveTo(workspace.__THINGS.CustomEggs[eggId].PriceHUD.Position + Vector3.new(5, 0, 0))

        task.wait(3)

        game:GetService("ReplicatedStorage").Network.CustomEggs_Hatch:InvokeServer(eggId, 1)

        task.wait(2)
    end
end

-- Auto Instance
task.spawn(function()
    autoTap();autoUltimate()
    local OldZone = InstanceZoneCmds.GetMaximumOwnedZoneNumber()

    while InstanceZoneCmds.GetMaximumOwnedZoneNumber() ~= 5 do
        ReplicatedStorage.Network.InstanceZones_RequestPurchase:InvokeServer(InstancingCmds.GetInstanceID(), InstanceZoneCmds.GetMaximumOwnedZoneNumber() + 1)

        if OldZone ~= InstanceZoneCmds.GetMaximumOwnedZoneNumber() then
            LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0) --workspace.__THINGS.Instances.GoodEvilInstance.BREAKABLE_SPAWNS["Main_"..InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame
            OldZone = InstanceZoneCmds.GetMaximumOwnedZoneNumber()
        end
        task.wait(1)
    end
end)

-- Auto Quests
task.spawn(function()
    while InstanceZoneCmds.GetMaximumOwnedZoneNumber() ~= 5 do
        local quest = getQuest()
        if quest and QuestFunctions[quest.Name] ~= nil then
            NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Starting "..quest.Name})
            QuestFunctions[quest.Name]()
        else
            LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0)
            repeat task.wait() until getQuest() or CurrencyCmds.Get("GoodVsEvilCoins") >= 1250 and #Save.Get().Inventory.Pet <= 3
            if CurrencyCmds.Get("GoodVsEvilCoins") >= 1250 and #Save.Get().Inventory.Pet <= 5 then
                QuestFunctions["EGG"](5, true)
            end
            LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0)
            repeat task.wait() until getQuest()
        end
        print(quest.Name)
        task.wait(1)
    end
end)

-- Auto Collect Orbs
task.spawn(function()
    for _, v in pairs(workspace.__THINGS.Orbs:GetChildren()) do
        ReplicatedStorage.Network["Orbs: Collect"]:FireServer(tonumber(v.Name))
        v:Destroy()
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
        v:Destroy()
    end

    workspace.__THINGS.Lootbags.DescendantAdded:Connect(function(descendant)
        ReplicatedStorage.Network.Lootbags_Claim:FireServer(tostring(descendant.Name))
        task.spawn(function()
            task.wait(.1)
            descendant:Destroy()
        end)
    end)
end)

if InstanceZoneCmds.GetMaximumOwnedZoneNumber() == 5 then
    LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].CFrame + Vector3.new(0, 10, 0)
    task.wait(.5)
    local EggId
    for _, v in pairs(workspace.__THINGS.CustomEggs:GetChildren()) do
        if v:FindFirstChild("EggLock") and v.EggLock.Transparency == 1 then
            if (v.EggLock.Position - --[[workspace.__THINGS.__INSTANCE_CONTAINER.Active.GoodEvilInstance.ZONE_GROUND[InstanceZoneCmds.GetMaximumOwnedZoneNumber()].Position).Magnitude < 60 then]]workspace.__THINGS.Instances.GoodEvilInstance.BREAKABLE_SPAWNS["Main_"..InstanceZoneCmds.GetMaximumOwnedZoneNumber()].Position).Magnitude < 60 then
                EggId = v.Name
                LocalPlayer.Character.HumanoidRootPart.CFrame = v.PriceHUD.CFrame
            end
        end
    end
    
    while task.wait(.1) do
        Network.CustomEggs_Hatch:InvokeServer(EggId, Save.Get().EggHatchCount)
    end
end
