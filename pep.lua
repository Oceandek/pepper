getgenv().Config = {
    Farming = {
        AutoCollectOrbs = true,
    },
    Misc = {
        ClaimFreeRewards = true, -- ❌
        DisableItemNotifications = true
    },
    Performance = {
        SetFpsCap = 999, -- ✅
        FpsBooster = {
            Enabled = true,
            InvisibleMap = true,
        },
        Disable3dRendering = false -- ✅
    },
    Client = {
        Blackout = {
            Enabled = false,
            Toggle = Enum.KeyCode.P,
            Disable3dRendering = true
        },
        Debug = true
    }
}

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

-- LocalScripts
local AutoTapper = getsenv(LocalPlayer.PlayerScripts.Scripts.GUIs["Auto Tapper"])
local EggAnim = getsenv(LocalPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])

if Config.Client.Blackout.Enabled then
    local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
    local blackoutFrame = Instance.new("Frame", ScreenGui)
    --local rankText = Instance.new("TextLabel", blackoutFrame)

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
local CurrentZone = MapCmds.GetCurrentZone()

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
    local Zone = name

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

    LocalPlayer.Character.HumanoidRootPart.CFrame = Zone:WaitForChild("INTERACT").BREAK_ZONES.BREAK_ZONE.CFrame

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

-- Anti Afk
task.spawn(function()
    while true do
        NetworkModule.Fire("Idle Tracking: Stop Timer")
        task.wait(math.random(0, 1.5))
    end
end)

task.spawn(function()
    autoTap()
    autoUltimate()

    TeleportToZone(ZoneCmds.GetMaxOwnedZone())

    local EggId = EggsUtil.GetIdByNumber(Save.Get().MaximumAvailableEgg)
    local HatchCount = Save.Get().EggHatchCount

    NotificationCmds.Message.Bottom({Color=Color3.new(1, 1, 1), Message="Hatching "..HatchCount.."x "..EggId.."s"})

    --while task.wait(.2) do
        Network.Eggs_RequestPurchase:InvokeServer(EggId, HatchCount)
    --end
end)

task.wait(2)

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
