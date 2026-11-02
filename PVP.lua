--[[
    Delta PvP Mod Menu
    Executor: Delta (Mobile/PC)
    Features: Aimbot, ESP, Speed Hack, Noclip, FOV Changer
    Usage: Paste into Delta executor, attach to Roblox, execute.
    Toggle GUI: RightShift
]]

-- ═══════════════════════════════════════════════════════════════
-- BOOT GUARD
-- ═══════════════════════════════════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
    or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    and Players.LocalPlayer

-- Delta-safe GUI parent
local guiParent
pcall(function()
    guiParent = gethui and gethui() or game:GetService("CoreGui")
end)
if not guiParent then
    guiParent = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui
end

-- Clean previous instance
for _, obj in ipairs(guiParent:GetChildren()) do
    if obj.Name == "DeltaPvPMenu" then obj:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIG STATE
-- ═══════════════════════════════════════════════════════════════
local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.UserInputType.MouseButton2,
        FOV = 120,
        Smoothness = 0.15,
        AimPart = "Head",
        WallCheck = false,
        TeamCheck = true,
        ShowFOV = true,
        AutoFire = false,
    },
    ESP = {
        Enabled = false,
        Box = true,
        Name = true,
        Distance = true,
        Tracer = false,
        Health = true,
    },
    Speed = {
        Enabled = false,
        Value = 50,
        Original = 16,
    },
    Noclip = {
        Enabled = false,
    },
    FOV = {
        Enabled = false,
        Value = 90,
        Original = 70,
    },
    Fullbright = {
        Enabled = false,
    },
    InfiniteJump = {
        Enabled = false,
    },
}

local Connections = {}
local ESPObjects = {}
local FOVCircle = nil
local HoldingAim = false

-- ═══════════════════════════════════════════════════════════════
-- GUI BUILDER
-- ═══════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPvPMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 280, 0, 420)
Main.Position = UDim2.new(0.5, -140, 0.3, -210)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Main

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -70, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "DELTA PVP // ollie"
TitleText.TextColor3 = Color3.fromRGB(220, 60, 120)
TitleText.TextSize = 14
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 28, 0, 28)
ToggleBtn.Position = UDim2.new(1, -38, 0, 4)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
ToggleBtn.Text = "—"
ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
ToggleBtn.TextSize = 16
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = TitleBar

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

-- Content Scroll
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -16, 1, -52)
Scroll.Position = UDim2.new(0, 8, 0, 44)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════
local function CreateLabel(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(180, 180, 200)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Scroll
    return lbl
end

local function CreateToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 5)
    fc.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 44, 0, 22)
    btn.Position = UDim2.new(1, -54, 0, 5)
    btn.BackgroundColor3 = default and Color3.fromRGB(180, 50, 90) or Color3.fromRGB(45, 45, 55)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(180, 50, 90) or Color3.fromRGB(45, 45, 55)
        if callback then callback(state) end
    end)

    return frame
end

local function CreateSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 5)
    fc.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 16)
    label.Position = UDim2.new(0, 10, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(210, 210, 220)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -20, 0, 6)
    barBg.Position = UDim2.new(0, 10, 0, 26)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame

    local bgc = Instance.new("UICorner")
    bgc.CornerRadius = UDim.new(0, 3)
    bgc.Parent = barBg

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(180, 50, 90)
    fill.BorderSizePixel = 0
    fill.Parent = barBg

    local fillc = Instance.new("UICorner")
    fillc.CornerRadius = UDim.new(0, 3)
    fillc.Parent = fill

    local dragging = false
    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = name .. ": " .. val
        if callback then callback(val) end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)

    barBg.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return frame
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD GUI
-- ═══════════════════════════════════════════════════════════════
CreateLabel("// AIMBOT", Color3.fromRGB(220, 60, 120))

CreateToggle("Aimbot", false, function(v) Config.Aimbot.Enabled = v end)
CreateToggle("Show FOV Circle", true, function(v) Config.Aimbot.ShowFOV = v end)
CreateToggle("Wall Check", false, function(v) Config.Aimbot.WallCheck = v end)
CreateToggle("Team Check", true, function(v) Config.Aimbot.TeamCheck = v end)
CreateSlider("FOV Radius", 30, 400, 120, function(v) Config.Aimbot.FOV = v end)
CreateSlider("Smoothness %", 1, 100, 15, function(v) Config.Aimbot.Smoothness = v / 100 end)

CreateLabel("// ESP", Color3.fromRGB(220, 60, 120))

CreateToggle("ESP Enabled", false, function(v) Config.ESP.Enabled = v end)
CreateToggle("Box", true, function(v) Config.ESP.Box = v end)
CreateToggle("Name", true, function(v) Config.ESP.Name = v end)
CreateToggle("Distance", true, function(v) Config.ESP.Distance = v end)
CreateToggle("Health", true, function(v) Config.ESP.Health = v end)
CreateToggle("Tracer", false, function(v) Config.ESP.Tracer = v end)

CreateLabel("// MOVEMENT", Color3.fromRGB(220, 60, 120))

CreateToggle("Speed Hack", false, function(v)
    Config.Speed.Enabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Config.Speed.Original end
    end
end)
CreateSlider("Speed Value", 16, 300, 50, function(v) Config.Speed.Value = v end)

CreateToggle("Noclip", false, function(v) Config.Noclip.Enabled = v end)
CreateToggle("Infinite Jump", false, function(v) Config.InfiniteJump.Enabled = v end)

CreateLabel("// VISUAL", Color3.fromRGB(220, 60, 120))

CreateToggle("FOV Changer", false, function(v)
    Config.FOV.Enabled = v
    if not v then Camera.FieldOfView = Config.FOV.Original end
end)
CreateSlider("FOV Value", 50, 120, 90, function(v) Config.FOV.Value = v end)
CreateToggle("Fullbright", false, function(v)
    Config.Fullbright.Enabled = v
    if v then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
    end
end)

-- Collapse logic
local collapsed = false
ToggleBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    Scroll.Visible = not collapsed
    Main.Size = collapsed and UDim2.new(0, 280, 0, 36) or UDim2.new(0, 280, 0, 420)
    ToggleBtn.Text = collapsed and "+" or "—"
end)

-- ═══════════════════════════════════════════════════════════════
-- AIMBOT
-- ═══════════════════════════════════════════════════════════════
local function getAimPart(character)
    if not character then return nil end
    local part = character:FindFirstChild(Config.Aimbot.AimPart)
    if part then return part end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function getClosestTarget()
    local closest = nil
    local shortest = Config.Aimbot.FOV
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not char then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = getAimPart(char)
        if not part then continue end
        if not isVisible(part) then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < shortest then
            shortest = dist
            closest = part
        end
    end

    return closest
end

-- FOV Circle
local function createFOVCircle()
    if FOVCircle then FOVCircle:Remove() end
    local drawing = Drawing.new("Circle")
    drawing.Thickness = 1.5
    drawing.Color = Color3.fromRGB(220, 60, 120)
    drawing.Filled = false
    drawing.Transparency = 0.7
    FOVCircle = drawing
end

if Drawing then
    createFOVCircle()
end

-- Aimbot render loop
Connections.Aimbot = RunService.RenderStepped:Connect(function()
    -- FOV circle
    if FOVCircle then
        FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled
        if Config.Aimbot.ShowFOV and Config.Aimbot.Enabled then
            FOVCircle.Position = Camera.ViewportSize / 2
            FOVCircle.Radius = Config.Aimbot.FOV
        end
    end

    -- Aim
    if not Config.Aimbot.Enabled then return end
    if not HoldingAim then return end

    local target = getClosestTarget()
    if not target then return end

    local targetPos = target.Position
    local currentCF = Camera.CFrame
    local goal = CFrame.new(currentCF.Position, targetPos)
    Camera.CFrame = currentCF:Lerp(goal, 1 - Config.Aimbot.Smoothness)
end)

-- Aim input
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Config.Aimbot.Key then
        HoldingAim = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Config.Aimbot.Key then
        HoldingAim = false
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════
local function createESP(player)
    if ESPObjects[player] then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(220, 60, 120)
    box.Filled = false
    box.Transparency = 0.8
    box.Visible = false

    local nameTag = Drawing.new("Text")
    nameTag.Size = 14
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Color = Color3.fromRGB(255, 255, 255)
    nameTag.Visible = false

    local distTag = Drawing.new("Text")
    distTag.Size = 12
    distTag.Center = true
    distTag.Outline = true
    distTag.Color = Color3.fromRGB(180, 180, 180)
    distTag.Visible = false

    local healthBar = Drawing.new("Square")
    healthBar.Thickness = 1
    healthBar.Color = Color3.fromRGB(50, 255, 50)
    healthBar.Filled = true
    healthBar.Transparency = 0.9
    healthBar.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Color3.fromRGB(220, 60, 120)
    tracer.Transparency = 0.7
    tracer.Visible = false

    ESPObjects[player] = {
        Box = box,
        Name = nameTag,
        Dist = distTag,
        Health = healthBar,
        Tracer = tracer,
    }
end

local function removeESP(player)
    local objs = ESPObjects[player]
    if not objs then return end
    for _, obj in pairs(objs) do
        pcall(function() obj:Remove() end)
    end
    ESPObjects[player] = nil
end

-- ESP update loop
Connections.ESP = RunService.RenderStepped:Connect(function()
    if not Config.ESP.Enabled then
        for _, objs in pairs(ESPObjects) do
            for _, obj in pairs(objs) do
                pcall(function() obj.Visible = false end)
            end
        end
        return
    end

    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then
            if ESPObjects[player] then
                for _, obj in pairs(ESPObjects[player]) do
                    pcall(function() obj.Visible = false end)
                end
            end
            continue
        end

        local char = player.Character
        if not char then
            if ESPObjects[player] then
                for _, obj in pairs(ESPObjects[player]) do
                    pcall(function() obj.Visible = false end)
                end
            end
            continue
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not hum or not hrp or not head or hum.Health <= 0 then
            if ESPObjects[player] then
                for _, obj in pairs(ESPObjects[player]) do
                    pcall(function() obj.Visible = false end)
                end
            end
            continue
        end

        if not ESPObjects[player] then
            createESP(player)
        end

        local objs = ESPObjects[player]
        local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        local headPos = Camera:WorldToViewportPoint(head.Position)

        if not onScreen then
            for _, obj in pairs(objs) do
                pcall(function() obj.Visible = false end)
            end
            continue
        end

        -- Box dimensions
        local height = math.abs(headPos.Y - rootPos.Y) + 12
        local width = height * 0.55
        local boxX = rootPos.X - width / 2
        local boxY = headPos.Y - 6

        -- Box
        objs.Box.Visible = Config.ESP.Box
        if Config.ESP.Box then
            objs.Box.Size = Vector2.new(width, height)
            objs.Box.Position = Vector2.new(boxX, boxY)
        end

        -- Name
        objs.Name.Visible = Config.ESP.Name
        if Config.ESP.Name then
            objs.Name.Text = player.Name
            objs.Name.Position = Vector2.new(rootPos.X, boxY - 16)
        end

        -- Distance
        local distance = (LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            and (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
            or 0
        objs.Dist.Visible = Config.ESP.Distance
        if Config.ESP.Distance then
            objs.Dist.Text = string.format("%d studs", math.floor(distance))
            objs.Dist.Position = Vector2.new(rootPos.X, boxY + height + 2)
        end

        -- Health bar
        objs.Health.Visible = Config.ESP.Health
        if Config.ESP.Health then
            local hpRatio = hum.Health / hum.MaxHealth
            local barH = height * hpRatio
            objs.Health.Size = Vector2.new(2, barH)
            objs.Health.Position = Vector2.new(boxX - 5, boxY + height - barH)
            objs.Health.Color = hpRatio > 0.5 and Color3.fromRGB(50, 255, 50)
                or hpRatio > 0.25 and Color3.fromRGB(255, 255, 50)
                or Color3.fromRGB(255, 50, 50)
        end

        -- Tracer
        objs.Tracer.Visible = Config.ESP.Tracer
        if Config.ESP.Tracer then
            objs.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            objs.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════════════════════════
Connections.Speed = RunService.Heartbeat:Connect(function()
    if not Config.Speed.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.Speed.Value
    end
end)

Connections.Noclip = RunService.Stepped:Connect(function()
    if not Config.Noclip.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if not Config.InfiniteJump.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- FOV Changer
Connections.FOV = RunService.RenderStepped:Connect(function()
    if Config.FOV.Enabled then
        Camera.FieldOfView = Config.FOV.Value
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PLAYER CLEANUP
-- ═══════════════════════════════════════════════════════════════
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- ═══════════════════════════════════════════════════════════════
-- GUI TOGGLE (RightShift)
-- ═══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP ON REJOIN
-- ═══════════════════════════════════════════════════════════════
LocalPlayer.OnTeleport:Connect(function()
    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    for player, _ in pairs(ESPObjects) do
        removeESP(player)
    end
    if FOVCircle then FOVCircle:Remove() end
end)

print("[DeltaPvP] ollie loaded — RightShift to toggle")
