setfpscap(999)

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

LocalPlayer.Character.HumanoidRootPart.Anchored = true

-- Infinite Pet Speed
hookfunction(require(Library.Client.PlayerPet).CalculateSpeedMultiplier, function()
    return 999
end)

local blacklist = {
    "Idle Tracking",
    "Mobile",
    "Server Closing",
    "Pending",
    "Inventory",
    "Ultimate",
    "ClientMagicOrbs",
    "Pet",
    "Egg"
}

local newtbl = table.clone(table)

newtbl.match = function(t, s)
    for _, k in pairs(t) do
        if string.find(s, k) then
            return true
        end
    end

    return false
end

local env = getfenv(1)
env.table = newtbl

setfenv(1, env)

for _, v in pairs(game:GetService("Players").LocalPlayer.PlayerScripts.Scripts:GetDescendants()) do
    if v:IsA("Script") and not table.match(blacklist, v.Name) and ((not v.Parent) or v.Parent.Name ~= "Breakables") and ((not v.Parent) or v.Parent.Name ~= "Random Events") and ((not v.Parent) or v.Parent.Name ~= "GUI") then
        print("[PERFORMANCE][PLAYERSCRIPTS][DESTROYED]", v.Name)
        v:Destroy()
    end
end

local blacklist = {
    "Flags",
    "Instances",
    "Items",
    "Loot",
    "Orb",
    "__",
    "Breakable",
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
    print("[PERFORMANCE][EGGS][DESTROYED]", v.Name)
    v:Destroy()
end

for _, v in pairs(workspace.__THINGS:GetChildren()) do
    if (not table.match(blacklist, v.Name) or table.match(whitelist, v.Name)) then
        print("[PERFORMANCE][__THINGS][DESTROYED]", v.Name)
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
        print("[PERFORMANCE][PATH][DESTROYED]", v.Name)
        v:Destroy()
    end
end

for _, v in pairs(WorldsUtil.GetMap():GetDescendants()) do
    pcall(function()
        v.Transparency = 1
    end)
end

for i, v in pairs(require(game:GetService("ReplicatedStorage").Library.Client.WorldFX)) do
    print("[PERFORMANCE][WORLDFX][DISABLED]", v.Name)
    require(game:GetService("ReplicatedStorage").Library.Client.WorldFX)[i] = function()
        return
    end
end

for i, v in pairs(game:GetService("ReplicatedStorage").Assets.Particles:GetDescendants()) do
    if v:IsA("ParticleEmitter") then
        print("[PERFORMANCE][PARTICLES][DISABLED]", v.Name)
        v.Texture = ""
        v.TimeScale = 0
    end
end

local orbs = {}

hookfunction(require(game:GetService("ReplicatedStorage").Library.Client.OrbCmds.Orb).new, function(uid)
    table.insert(orbs, uid)
    return
end)

task.spawn(function()
    while task.wait(1) do
        NetworkModule.Fire("Orbs: Collect", orbs)
    end
end)

for _, zone in pairs(WorldsUtil.GetMap():GetChildren()) do
    if zone.Name ~= "SHOP" and not string.find(zone.Name:lower(), "shop") then
        if zone:FindFirstChild("PARTS_LOD") then
            zone.PARTS_LOD:Destroy()
        end
    
        if zone:FindFirstChild("PARTS") then
            zone.PARTS:Destroy()
        end

        if zone:FindFirstChild("_PARTS") then
            zone._PARTS:Destroy()
        end
    
        zone.DescendantAdded:Connect(function(desc)
            task.wait()
            pcall(function()
                if desc:IsDescendantOf(zone:FindFirstChild("PARTS")) then
                    zone.PARTS:Destroy()
                end
            end)
    
            pcall(function()
                if desc:IsDescendantOf(zone.PARTS_LOD:FindFirstChild("WALLS")) then
                    zone.PARTS_LOD.WALLS:Destroy()
                end
            end)
        end)
    end
end
