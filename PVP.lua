--[[
    Delta PvP Mod Menu — MOBILE FIXED
    Drag pakai InputChanged (bukan frame.Draggable)
    Layout pakai UIScale + offset yang muat layar HP kecil
    Toggle GUI: tombol O pink (bisa digeser juga)
]]

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
    or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    and Players.LocalPlayer

local guiParent
pcall(function()
    guiParent = gethui and gethui() or game:GetService("CoreGui")
end)
if not guiParent then
    guiParent = LocalPlayer:WaitForChild("PlayerGui", 10) or LocalPlayer.PlayerGui
end

for _, obj in ipairs(guiParent:GetChildren()) do
    if obj.Name == "DeltaPvPMenu" then obj:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local Config = {
    Aimbot = { Enabled = false, FOV = 120, Smooth = 0.15, WallCheck = false, TeamCheck = true, ShowFOV = true, AimPart = "Head" },
    ESP = { Enabled = false, Box = true, Name = true, Dist = true, Health = true, Tracer = false },
    Speed = { Enabled = false, Value = 50, Original = 16 },
    Noclip = { Enabled = false },
    FOV = { Enabled = false, Value = 90, Original = 70 },
    Fullbright = { Enabled = false },
    InfJump = { Enabled = false },
}

local Connections = {}
local ESPObjects = {}
local FOVCircle = nil
local HoldingAim = false

-- ═══════════════════════════════════════════════════════════════
-- RESPONSIVE SIZING (menyesuaikan layar HP)
-- ═══════════════════════════════════════════════════════════════
local viewport = workspace.CurrentCamera.ViewportSize
local isSmall = viewport.X < 500
local MENU_W = isSmall and math.floor(viewport.X * 0.92) or 320
local MENU_H = isSmall and math.min(math.floor(viewport.Y * 0.75), 460) or 440
local TB_H = 46

-- ═══════════════════════════════════════════════════════════════
-- GUI ROOT
-- ═══════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPvPMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = guiParent

-- ═══════════════════════════════════════════════════════════════
-- FLOATING TOGGLE (draggable, mobile-friendly)
-- ═══════════════════════════════════════════════════════════════
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatBtn"
FloatBtn.Size = UDim2.new(0, 54, 0, 54)
FloatBtn.Position = UDim2.new(1, -74, 0.5, -27)
FloatBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 120)
FloatBtn.Text = "O"
FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatBtn.TextSize = 24
FloatBtn.Font = Enum.Font.GothamBlack
FloatBtn.AutoButtonColor = false
FloatBtn.Active = true
FloatBtn.Parent = ScreenGui

Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local fStroke = Instance.new("UIStroke", FloatBtn)
fStroke.Color = Color3.fromRGB(255, 255, 255)
fStroke.Thickness = 2
fStroke.Transparency = 0.5

-- ═══════════════════════════════════════════════════════════════
-- MAIN FRAME
-- ═══════════════════════════════════════════════════════════════
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, MENU_W, 0, MENU_H)
Main.Position = UDim2.new(0.5, -MENU_W / 2, 0.5, -MENU_H / 2)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(220, 60, 120)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.3

-- ═══════════════════════════════════════════════════════════════
-- TITLE BAR (DRAG ZONE)
-- ═══════════════════════════════════════════════════════════════
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, TB_H)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.Parent = Main

Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TBTitleFill = Instance.new("Frame")
TBTitleFill.Size = UDim2.new(1, 0, 0, 20)
TBTitleFill.Position = UDim2.new(0, 0, 1, -20)
TBTitleFill.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TBTitleFill.BorderSizePixel = 0
TBTitleFill.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -100, 1, 0)
TitleText.Position = UDim2.new(0, 14, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "DELTA PVP // ollie"
TitleText.TextColor3 = Color3.fromRGB(220, 60, 120)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.GothamBold
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Size = UDim2.new(0, 34, 0, 34)
CollapseBtn.Position = UDim2.new(1, -82, 0, 6)
CollapseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
CollapseBtn.Text = "—"
CollapseBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
CollapseBtn.TextSize = 22
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.AutoButtonColor = false
CollapseBtn.Parent = TitleBar
Instance.new("UICorner", CollapseBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.Position = UDim2.new(1, -44, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- ═══════════════════════════════════════════════════════════════
-- SCROLL CONTENT
-- ═══════════════════════════════════════════════════════════════
local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.Size = UDim2.new(1, -12, 1, -(TB_H + 10))
Scroll.Position = UDim2.new(0, 6, 0, TB_H + 6)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 5
Scroll.ScrollBarImageColor3 = Color3.fromRGB(220, 60, 120)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

-- ═══════════════════════════════════════════════════════════════
-- WIDGET BUILDERS
-- ═══════════════════════════════════════════════════════════════
local function CreateLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 26)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 60, 120)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Scroll
    return lbl
end

local function CreateToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 46)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(215, 215, 225)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 32)
    btn.Position = UDim2.new(1, -70, 0, 7)
    btn.BackgroundColor3 = default and Color3.fromRGB(220, 60, 120) or Color3.fromRGB(45, 45, 55)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(220, 60, 120) or Color3.fromRGB(45, 45, 55)
        if callback then callback(state) end
    end)
    return frame
end

local function CreateSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 58)
    frame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    frame.BorderSizePixel = 0
    frame.Parent = Scroll
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. default
    label.TextColor3 = Color3.fromRGB(215, 215, 225)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -24, 0, 14)
    barBg.Position = UDim2.new(0, 12, 0, 34)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 7)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(220, 60, 120)
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 7)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(fill.Size.X.Scale, -9, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = barBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function setVal(input)
        local pos = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        knob.Position = UDim2.new(pos, -9, 0.5, -9)
        label.Text = name .. ": " .. val
        if callback then callback(val) end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setVal(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setVal(input)
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
-- BUILD WIDGETS
-- ═══════════════════════════════════════════════════════════════
CreateLabel("// AIMBOT")
CreateToggle("Aimbot", false, function(v) Config.Aimbot.Enabled = v end)
CreateToggle("Show FOV Circle", true, function(v) Config.Aimbot.ShowFOV = v end)
CreateToggle("Wall Check", false, function(v) Config.Aimbot.WallCheck = v end)
CreateToggle("Team Check", true, function(v) Config.Aimbot.TeamCheck = v end)
CreateSlider("FOV Radius", 30, 400, 120, function(v) Config.Aimbot.FOV = v end)
CreateSlider("Smoothness %", 1, 100, 15, function(v) Config.Aimbot.Smooth = v / 100 end)

CreateLabel("// ESP")
CreateToggle("ESP Enabled", false, function(v) Config.ESP.Enabled = v end)
CreateToggle("Box", true, function(v) Config.ESP.Box = v end)
CreateToggle("Name", true, function(v) Config.ESP.Name = v end)
CreateToggle("Distance", true, function(v) Config.ESP.Dist = v end)
CreateToggle("Health", true, function(v) Config.ESP.Health = v end)
CreateToggle("Tracer", false, function(v) Config.ESP.Tracer = v end)

CreateLabel("// MOVEMENT")
CreateToggle("Speed Hack", false, function(v)
    Config.Speed.Enabled = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Config.Speed.Original end
    end
end)
CreateSlider("Speed Value", 16, 300, 50, function(v) Config.Speed.Value = v end)
CreateToggle("Noclip", false, function(v) Config.Noclip.Enabled = v end)
CreateToggle("Infinite Jump", false, function(v) Config.InfJump.Enabled = v end)

CreateLabel("// VISUAL")
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
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- DRAG SYSTEM (BENERAN JALAN DI HP)
-- Menggunakan InputBegan di handle + InputChanged global
-- ═══════════════════════════════════════════════════════════════
local function makeDraggable(frame, handle)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragInput = input
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    handle.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            dragInput = nil
        end
    end)
end

makeDraggable(Main, TitleBar)
makeDraggable(FloatBtn, FloatBtn)

-- ═══════════════════════════════════════════════════════════════
-- COLLAPSE / HIDE
-- ═══════════════════════════════════════════════════════════════
local collapsed = false
local EXPANDED = UDim2.new(0, MENU_W, 0, MENU_H)
local COLLAPSED = UDim2.new(0, MENU_W, 0, TB_H)

local function setCollapsed(state)
    collapsed = state
    TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = state and COLLAPSED or EXPANDED,
    }):Play()
    Scroll.Visible = not state
    CollapseBtn.Text = state and "+" or "—"
end

CollapseBtn.MouseButton1Click:Connect(function()
    setCollapsed(not collapsed)
end)

local mainVisible = true
local function setMenuVisible(v)
    mainVisible = v
    Main.Visible = v
end

CloseBtn.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

FloatBtn.MouseButton1Click:Connect(function()
    setMenuVisible(not mainVisible)
end)

-- ═══════════════════════════════════════════════════════════════
-- AIMBOT
-- ═══════════════════════════════════════════════════════════════
local function getAimPart(char)
    if not char then return nil end
    local p = char:FindFirstChild(Config.Aimbot.AimPart)
    if p then return p end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function visible(part)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
    local result = workspace:Raycast(origin, dir, params)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function closestTarget()
    local best, bestDist = nil, Config.Aimbot.FOV
    local center = Camera.ViewportSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and plr.Team == LocalPlayer.Team then continue end
        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = getAimPart(char)
        if not part or not visible(part) then continue end
        local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < bestDist then
            bestDist = d
            best = part
        end
    end
    return best
end

if Drawing then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 2
    FOVCircle.Color = Color3.fromRGB(220, 60, 120)
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.8
end

Connections.Aimbot = RunService.RenderStepped:Connect(function()
    if FOVCircle then
        local show = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
        FOVCircle.Visible = show
        if show then
            FOVCircle.Position = Camera.ViewportSize / 2
            FOVCircle.Radius = Config.Aimbot.FOV
        end
    end
    if not (Config.Aimbot.Enabled and HoldingAim) then return end
    local target = closestTarget()
    if not target then return end
    local goal = CFrame.new(Camera.CFrame.Position, target.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goal, 1 - Config.Aimbot.Smooth)
end)

UserInputService.TouchStarted:Connect(function(input)
    if Config.Aimbot.Enabled then HoldingAim = true end
end)
UserInputService.TouchEnded:Connect(function(input)
    HoldingAim = false
end)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        HoldingAim = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        HoldingAim = false
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════
local function buildESP(plr)
    if ESPObjects[plr] then return end
    ESPObjects[plr] = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Dist = Drawing.new("Text"),
        Health = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
    }
    local o = ESPObjects[plr]
    o.Box.Thickness = 1.5
    o.Box.Color = Color3.fromRGB(220, 60, 120)
    o.Box.Filled = false
    o.Name.Size = 15
    o.Name.Center = true
    o.Name.Outline = true
    o.Name.Color = Color3.fromRGB(255, 255, 255)
    o.Dist.Size = 13
    o.Dist.Center = true
    o.Dist.Outline = true
    o.Dist.Color = Color3.fromRGB(200, 200, 200)
    o.Health.Filled = true
    o.Health.Thickness = 1
    o.Tracer.Thickness = 1.5
    o.Tracer.Color = Color3.fromRGB(220, 60, 120)
end

local function hideESP(plr)
    local o = ESPObjects[plr]
    if not o then return end
    for _, d in pairs(o) do pcall(function() d.Visible = false end) end
end

Connections.ESP = RunService.RenderStepped:Connect(function()
    if not Config.ESP.Enabled then
        for p in pairs(ESPObjects) do hideESP(p) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if Config.Aimbot.TeamCheck and plr.Team == LocalPlayer.Team then
            hideESP(plr); continue
        end
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not (hum and hrp and head and hum.Health > 0) then
            hideESP(plr); continue
        end
        if not ESPObjects[plr] then buildESP(plr) end
        local o = ESPObjects[plr]
        local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        local headPos = Camera:WorldToViewportPoint(head.Position)
        if not onScreen then
            for _, d in pairs(o) do pcall(function() d.Visible = false end) end
            continue
        end
        local h = math.abs(headPos.Y - rootPos.Y) + 14
        local w = h * 0.55
        local bx = rootPos.X - w / 2
        local by = headPos.Y - 7

        o.Box.Visible = Config.ESP.Box
        if Config.ESP.Box then
            o.Box.Size = Vector2.new(w, h)
            o.Box.Position = Vector2.new(bx, by)
        end

        o.Name.Visible = Config.ESP.Name
        if Config.ESP.Name then
            o.Name.Text = plr.Name
            o.Name.Position = Vector2.new(rootPos.X, by - 18)
        end

        local dist = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            and (LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude or 0
        o.Dist.Visible = Config.ESP.Dist
        if Config.ESP.Dist then
            o.Dist.Text = math.floor(dist) .. " studs"
            o.Dist.Position = Vector2.new(rootPos.X, by + h + 2)
        end

        o.Health.Visible = Config.ESP.Health
        if Config.ESP.Health then
            local ratio = hum.Health / hum.MaxHealth
            local bh = h * ratio
            o.Health.Size = Vector2.new(3, bh)
            o.Health.Position = Vector2.new(bx - 6, by + h - bh)
            o.Health.Color = ratio > 0.5 and Color3.fromRGB(50, 255, 50)
                or ratio > 0.25 and Color3.fromRGB(255, 255, 50)
                or Color3.fromRGB(255, 50, 50)
        end

        o.Tracer.Visible = Config.ESP.Tracer
        if Config.ESP.Tracer then
            o.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            o.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════════════════════════
Connections.Speed = RunService.Heartbeat:Connect(function()
    if not Config.Speed.Enabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Config.Speed.Value end
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

UserInputService.JumpRequest:Connect(function()
    if not Config.InfJump.Enabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

Connections.FOV = RunService.RenderStepped:Connect(function()
    if Config.FOV.Enabled then Camera.FieldOfView = Config.FOV.Value end
end)

Players.PlayerRemoving:Connect(function(plr)
    local o = ESPObjects[plr]
    if o then
        for _, d in pairs(o) do pcall(function() d:Remove() end) end
        ESPObjects[plr] = nil
    end
end)

LocalPlayer.OnTeleport:Connect(function()
    for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
    for p in pairs(ESPObjects) do hideESP(p) end
    if FOVCircle then pcall(function() FOVCircle:Remove() end) end
end)

print("[DeltaPvP] ollie mobile fixed — drag title bar, tap O to show")
