--[[
    PvP Suite — Full Build
    Features: Aimbot | Triggerbot | ESP | Hitbox | NoRecoil | Movement
    Client-side only. Use at your own risk.
    UI: Rayfield Gen2
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = Workspace.CurrentCamera
local LP = Players.LocalPlayer

-- ================= CONFIG =================
local cfg = {
    -- Aimbot
    aimEnabled = false,
    aimFOV = 120,
    aimSmooth = 0.25,
    aimPart = "Head",
    aimWallCheck = true,
    aimTeamCheck = true,
    -- Triggerbot
    triggerEnabled = false,
    triggerDelay = 0.05,
    -- ESP
    espEnabled = false,
    espBox = true,
    espName = true,
    espHealth = true,
    espDistance = true,
    -- Hitbox
    hitboxEnabled = false,
    hitboxSize = 2,
    hitboxTransparency = 0.7,
    -- Combat
    noRecoil = false,
    -- Movement
    speedEnabled = false,
    speedValue = 32,
    jumpEnabled = false,
    flyEnabled = false,
    flySpeed = 50,
}

local hitboxParts = {}
local espObjects = {}
local lastTrigger = 0
local flying = false
local flyBV, flyBG

-- ================= HELPERS =================
local function isAlive(plr)
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getRoot(plr)
    local char = plr.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function isVisible(part)
    if not cfg.aimWallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LP.Character, part}
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local hit = Workspace:Raycast(origin, dir, params)
    return hit == nil
end

local function sameTeam(plr)
    if not cfg.aimTeamCheck then return false end
    return plr.Team ~= nil and LP.Team ~= nil and plr.Team == LP.Team
end

local function getTarget()
    local best, bestDist = nil, cfg.aimFOV
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and isAlive(plr) and not sameTeam(plr) then
            local part = plr.Character:FindFirstChild(cfg.aimPart)
                or plr.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist < bestDist and isVisible(part) then
                        best, bestDist = part, dist
                    end
                end
            end
        end
    end
    return best
end

-- ================= AIMBOT =================
RunService.RenderStepped:Connect(function()
    if not cfg.aimEnabled then return end
    local target = getTarget()
    if not target then return end
    local goal = CFrame.new(Camera.CFrame.Position, target.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goal, cfg.aimSmooth)
end)

-- ================= TRIGGERBOT =================
RunService.RenderStepped:Connect(function()
    if not cfg.triggerEnabled then return end
    if tick() - lastTrigger < cfg.triggerDelay then return end
    local target = getTarget()
    if not target then return end
    local screen, onScreen = Camera:WorldToViewportPoint(target.Position)
    if onScreen then
        local center = Camera.ViewportSize / 2
        local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if dist < 15 then
            lastTrigger = tick()
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        end
    end
end)

-- ================= ESP =================
local function createESP(plr)
    local char = plr.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 60, 60)
    box.Filled = false
    box.Visible = false

    local nameTag = Drawing.new("Text")
    nameTag.Size = 14
    nameTag.Color = Color3.fromRGB(255, 255, 255)
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Visible = false

    local healthBar = Drawing.new("Line")
    healthBar.Thickness = 2
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Visible = false

    local distTag = Drawing.new("Text")
    distTag.Size = 12
    distTag.Color = Color3.fromRGB(200, 200, 200)
    distTag.Center = true
    distTag.Outline = true
    distTag.Visible = false

    espObjects[plr] = {box=box, name=nameTag, health=healthBar, dist=distTag, hum=hum, root=root}
end

local function removeESP(plr)
    local e = espObjects[plr]
    if e then
        for _, obj in pairs(e) do
            if typeof(obj) == "Instance" and obj.Remove then obj:Remove() end
        end
    end
    espObjects[plr] = nil
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function() task.wait(1); if cfg.espEnabled then createESP(plr) end end)
end)
Players.PlayerRemoving:Connect(removeESP)

RunService.RenderStepped:Connect(function()
    for plr, e in pairs(espObjects) do
        if not cfg.espEnabled or not isAlive(plr) then
            e.box.Visible = false; e.name.Visible = false
            e.health.Visible = false; e.dist.Visible = false
        else
            local pos, onScreen = Camera:WorldToViewportPoint(e.root.Position)
            if onScreen then
                local head = e.root.Position + Vector3.new(0, 2, 0)
                local foot = e.root.Position - Vector3.new(0, 3, 0)
                local hs = Camera:WorldToViewportPoint(head)
                local fs = Camera:WorldToViewportPoint(foot)
                local height = math.abs(hs.Y - fs.Y)
                local width = height / 2
                e.box.Size = Vector2.new(width, height)
                e.box.Position = Vector2.new(pos.X - width/2, hs.Y)
                e.box.Visible = cfg.espBox

                e.name.Text = plr.Name
                e.name.Position = Vector2.new(pos.X, hs.Y - 18)
                e.name.Visible = cfg.espName

                local hp = e.hum.Health / e.hum.MaxHealth
                local hbY = hs.Y + height * (1 - hp)
                e.health.From = Vector2.new(pos.X - width/2 - 6, hs.Y + height)
                e.health.To = Vector2.new(pos.X - width/2 - 6, hbY)
                e.health.Color = Color3.fromRGB(255*(1-hp), 255*hp, 0)
                e.health.Visible = cfg.espHealth

                e.dist.Text = math.floor((Camera.CFrame.Position - e.root.Position).Magnitude) .. "m"
                e.dist.Position = Vector2.new(pos.X, fs.Y + 4)
                e.dist.Visible = cfg.espDistance
            else
                e.box.Visible = false; e.name.Visible = false
                e.health.Visible = false; e.dist.Visible = false
            end
        end
    end
end)

-- ================= HITBOX =================
local function applyHitbox(plr)
    if not isAlive(plr) then return end
    local char = plr.Character
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local orig = part:FindFirstChild("OrigSize")
            if not orig then
                local s = Instance.new("Vector3Value")
                s.Name = "OrigSize"
                s.Value = part.Size
                s.Parent = part
            end
            part.Size = part:FindFirstChild("OrigSize").Value * cfg.hitboxSize
            part.Transparency = cfg.hitboxTransparency
            part.CanCollide = false
            table.insert(hitboxParts, part)
        end
    end
end

local function clearHitbox()
    for _, part in ipairs(hitboxParts) do
        if part.Parent then
            local orig = part:FindFirstChild("OrigSize")
            if orig then
                part.Size = orig.Value
                part.Transparency = 0
                orig:Destroy()
            end
            part.CanCollide = true
        end
    end
    hitboxParts = {}
end

-- ================= NO RECOIL =================
RunService.RenderStepped:Connect(function()
    if not cfg.noRecoil then return end
    for _, tool in ipairs(LP.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("NumberValue") then
                    local n = v.Name:lower()
                    if n:find("recoil") or n:find("spread") then
                        v.Value = 0
                    end
                end
            end
        end
    end
end)

-- ================= MOVEMENT =================
RunService.RenderStepped:Connect(function()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if cfg.speedEnabled then hum.WalkSpeed = cfg.speedValue end
    if cfg.jumpEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = 100
    end
end)

local function startFly()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 1000
    flyBG.Parent = root
    flying = true
    UserInputService.InputBegan:Connect(function(input)
        if not flying then return end
        local dir = Vector3.zero
        if input.KeyCode == Enum.KeyCode.W then dir += Camera.CFrame.LookVector end
        if input.KeyCode == Enum.KeyCode.S then dir -= Camera.CFrame.LookVector end
        if input.KeyCode == Enum.KeyCode.A then dir -= Camera.CFrame.RightVector end
        if input.KeyCode == Enum.KeyCode.D then dir += Camera.CFrame.RightVector end
        if input.KeyCode == Enum.KeyCode.Space then dir += Vector3.new(0,1,0) end
        if input.KeyCode == Enum.KeyCode.LeftControl then dir -= Vector3.new(0,1,0) end
        flyBV.Velocity = dir * cfg.flySpeed
    end)
end

local function stopFly()
    flying = false
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    flyBV, flyBG = nil, nil
end

-- ================= UI =================
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

-- Combat Tab
Combat:CreateSection("Aimbot")
Combat:CreateToggle({Name="Enable Aimbot", CurrentValue=false, Flag="aimEnabled", Callback=function(v) cfg.aimEnabled = v end})
Combat:CreateSlider({Name="FOV", Range={10,600}, Increment=5, Suffix="px", CurrentValue=120, Flag="aimFOV", Callback=function(v) cfg.aimFOV = v end})
Combat:CreateSlider({Name="Smooth", Range={0.05,1}, Increment=0.05, CurrentValue=0.25, Flag="aimSmooth", Callback=function(v) cfg.aimSmooth = v end})
Combat:CreateDropdown({Name="Target Part", Options={"Head","HumanoidRootPart","Torso"}, CurrentOption={"Head"}, Flag="aimPart", Callback=function(v) cfg.aimPart = v[1] end})
Combat:CreateToggle({Name="Wall Check", CurrentValue=true, Flag="aimWallCheck", Callback=function(v) cfg.aimWallCheck = v end})
Combat:CreateToggle({Name="Team Check", CurrentValue=true, Flag="aimTeamCheck", Callback=function(v) cfg.aimTeamCheck = v end})

Combat:CreateSection("Triggerbot")
Combat:CreateToggle({Name="Enable Triggerbot", CurrentValue=false, Flag="trigEnabled", Callback=function(v) cfg.triggerEnabled = v end})
Combat:CreateSlider({Name="Delay (s)", Range={0.01,0.5}, Increment=0.01, CurrentValue=0.05, Flag="trigDelay", Callback=function(v) cfg.triggerDelay = v end})

Combat:CreateSection("Recoil")
Combat:CreateToggle({Name="No Recoil / No Spread", CurrentValue=false, Flag="noRecoil", Callback=function(v) cfg.noRecoil = v end})

-- Visuals Tab
Visuals:CreateSection("ESP")
Visuals:CreateToggle({Name="Enable ESP", CurrentValue=false, Flag="espEnabled", Callback=function(v)
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
Visuals:CreateToggle({Name="Enable Hitbox", CurrentValue=false, Flag="hbEnabled", Callback=function(v)
    cfg.hitboxEnabled = v
    if v then applyHitbox(LP) else clearHitbox() end
end})
Visuals:CreateSlider({Name="Size", Range={1,5}, Increment=0.5, CurrentValue=2, Flag="hbSize", Callback=function(v)
    cfg.hitboxSize = v
    if cfg.hitboxEnabled then clearHitbox(); applyHitbox(LP) end
end})

-- Movement Tab
Movement:CreateSection("Speed")
Movement:CreateToggle({Name="Enable Speed", CurrentValue=false, Flag="spdEnabled", Callback=function(v) cfg.speedEnabled = v end})
Movement:CreateSlider({Name="WalkSpeed", Range={16,200}, Increment=1, CurrentValue=32, Flag="spdVal", Callback=function(v) cfg.speedValue = v end})

Movement:CreateSection("Jump")
Movement:CreateToggle({Name="Infinite Jump", CurrentValue=false, Flag="jmpEnabled", Callback=function(v) cfg.jumpEnabled = v end})

Movement:CreateSection("Fly")
Movement:CreateToggle({Name="Enable Fly", CurrentValue=false, Flag="flyEnabled", Callback=function(v)
    if v then startFly() else stopFly() end
end})
Movement:CreateSlider({Name="Fly Speed", Range={10,200}, Increment=5, CurrentValue=50, Flag="flySpeed", Callback=function(v) cfg.flySpeed = v end})

Rayfield:Notify({Title="PvP Suite", Content="Build loaded. Absolute olliE.", Duration=4})
