-- ===== UI =====
local Window = Rayfield:CreateWindow({
    Name = "PvP Suite",
    LoadingTitle = "PvP Suite",
    LoadingSubtitle = "client-side build",
    ConfigurationSaving = {Enabled = true, FolderName = "PvPSuite", FileName = "config"},
    KeySystem = false,
})

local Combat = Window:CreateTab("Combat", 4483362458)
local Visuals = Window:CreateTab("Visuals", 4483362458)
local Movement = Window:CreateTab("Movement", 4483362458)

-- COMBAT TAB
Combat:CreateSection("Aimbot")
Combat:CreateToggle({Name="Enable Aimbot", CurrentValue=false, Flag="aimEnabled",
    Callback=function(v) cfg.aimEnabled = v end})
Combat:CreateSlider({Name="FOV", Range={10,600}, Increment=5, Suffix="px", CurrentValue=120, Flag="aimFOV",
    Callback=function(v) cfg.aimFOV = v end})
Combat:CreateSlider({Name="Smooth", Range={0.05,1}, Increment=0.05, CurrentValue=0.25, Flag="aimSmooth",
    Callback=function(v) cfg.aimSmooth = v end})
Combat:CreateDropdown({Name="Target Part", Options={"Head","HumanoidRootPart","Torso"},
    CurrentOption={"Head"}, Flag="aimPart", Callback=function(v) cfg.aimPart = v[1] end})
Combat:CreateToggle({Name="Wall Check", CurrentValue=true, Flag="aimWallCheck",
    Callback=function(v) cfg.aimWallCheck = v end})
Combat:CreateToggle({Name="Team Check", CurrentValue=true, Flag="aimTeamCheck",
    Callback=function(v) cfg.aimTeamCheck = v end})

Combat:CreateSection("Triggerbot")
Combat:CreateToggle({Name="Enable Triggerbot", CurrentValue=false, Flag="trigEnabled",
    Callback=function(v) cfg.triggerEnabled = v end})
Combat:CreateSlider({Name="Delay (s)", Range={0.01,0.5}, Increment=0.01, CurrentValue=0.05, Flag="trigDelay",
    Callback=function(v) cfg.triggerDelay = v end})

Combat:CreateSection("Recoil")
Combat:CreateToggle({Name="No Recoil / No Spread", CurrentValue=false, Flag="noRecoil",
    Callback=function(v) cfg.noRecoil = v end})

-- VISUALS TAB
Visuals:CreateSection("ESP")
Visuals:CreateToggle({Name="Enable ESP", CurrentValue=false, Flag="espEnabled",
    Callback=function(v)
        cfg.espEnabled = v
        if v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then createESP(plr) end
            end
        else
            for plr in pairs(espObjects) do removeESP(plr) end
        end
    end})
Visuals:CreateToggle({Name="Box", CurrentValue=true, Flag="espBox", Callback=function(v) cfg.espBox = v end})
Visuals:CreateToggle({Name="Name", CurrentValue=true, Flag="espName", Callback=function(v) cfg.espName = v end})
Visuals:CreateToggle({Name="Health Bar", CurrentValue=true, Flag="espHealth", Callback=function(v) cfg.espHealth = v end})
Visuals:CreateToggle({Name="Distance", CurrentValue=true, Flag="espDist", Callback=function(v) cfg.espDistance = v end})

Visuals:CreateSection("Hitbox Expander")
Visuals:CreateToggle({Name="Enable Hitbox", CurrentValue=false, Flag="hbEnabled",
    Callback=function(v)
        cfg.hitboxEnabled = v
        if v then applyHitbox(LP) else clearHitbox() end
    end})
Visuals:CreateSlider({Name="Size", Range={1,5}, Increment=0.5, CurrentValue=2, Flag="hbSize",
    Callback=function(v) cfg.hitboxSize = v; if cfg.hitboxEnabled then clearHitbox(); applyHitbox(LP) end end})

-- MOVEMENT TAB
Movement:CreateSection("Speed")
Movement:CreateToggle({Name="Enable Speed", CurrentValue=false, Flag="spdEnabled",
    Callback=function(v) cfg.speedEnabled = v end})
Movement:CreateSlider({Name="WalkSpeed", Range={16,200}, Increment=1, CurrentValue=32, Flag="spdVal",
    Callback=function(v) cfg.speedValue = v end})

Movement:CreateSection("Jump")
Movement:CreateToggle({Name="Infinite Jump", CurrentValue=false, Flag="jmpEnabled",
    Callback=function(v) cfg.jumpEnabled = v end})

Movement:CreateSection("Fly")
Movement:CreateToggle({Name="Enable Fly", CurrentValue=false, Flag="flyEnabled",
    Callback=function(v)
        if v then startFly() else stopFly() end
    end})
Movement:CreateSlider({Name="Fly Speed", Range={10,200}, Increment=5, CurrentValue=50, Flag="flySpeed",
    Callback=function(v) cfg.flySpeed = v end})

Rayfield:Notify({Title="PvP Suite", Content="UI Fixed. Absolute olliE.", Duration=4})
