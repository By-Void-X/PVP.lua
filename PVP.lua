-- pvp_menu_v4_mobile.lua | Roblox PVP mod menu — mobile ready

if not getgenv then error("[PVP] executor dengan getgenv() dibutuhkan") end

local PVP = {}
getgenv().PVP = PVP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
if not LP then error("[PVP] tunggu game load") end

-- ============ CONFIG ============
PVP.Config = {
    aimbot = false, aimFov = 120, aimSmooth = 0.25, aimPart = "Head",
    hitbox = false, hitboxSize = 8,
    esp = false, espColor = Color3.fromRGB(0, 255, 120),
    wallhack = false,
    speed = false, speedValue = 50,
    noclip = false,
    pov = false, povValue = 70,
}

-- ============ UTIL ============
local function getChar(plr)
    local c = plr.Character
    if not c then return nil end
    local hum = c:FindFirstChildOfClass("Humanoid")
    local root = c:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return nil end
    return c, hum, root
end

local function getTarget()
    local cam = workspace.CurrentCamera
    local mouse = UIS:GetMouseLocation()
    local best, bestDist = nil, PVP.Config.aimFov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = getChar(plr)
        if not char then continue end
        local part = char:FindFirstChild(PVP.Config.aimPart) or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local screen, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d = (Vector2.new(screen.X, screen.Y) - mouse).Magnitude
        if d < bestDist then best, bestDist = part, d end
    end
    return best
end

-- ============ FITUR ============
local function doAim()
    local target = getTarget()
    if not target then return end
    local cam = workspace.CurrentCamera
    cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, target.Position), 1 - PVP.Config.aimSmooth)
end

local function doHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char, _, root = getChar(plr)
        if not char then continue end
        local hb = char:FindFirstChild("__pvp_hitbox")
        if not hb then
            hb = Instance.new("Part")
            hb.Name = "__pvp_hitbox"; hb.Transparency = 1; hb.CanCollide = false
            hb.CanQuery = false; hb.Massless = true; hb.Parent = char
            local w = Instance.new("WeldConstraint"); w.Part0 = hb; w.Part1 = root; w.Parent = hb
        end
        hb.Size = Vector3.new(PVP.Config.hitboxSize, PVP.Config.hitboxSize, PVP.Config.hitboxSize)
        hb.CFrame = root.CFrame
    end
end

local function clearHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if not char then continue end
        local hb = char:FindFirstChild("__pvp_hitbox")
        if hb then hb:Destroy() end
    end
end

local function doESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head or head:FindFirstChild("__pvp_esp") then continue end
        local bb = Instance.new("BillboardGui")
        bb.Name = "__pvp_esp"; bb.Adornee = head; bb.Size = UDim2.new(0, 200, 0, 40)
        bb.AlwaysOnTop = true; bb.Parent = head
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0); tl.BackgroundTransparency = 1
        tl.TextColor3 = PVP.Config.espColor; tl.TextStrokeTransparency = 0
        tl.Font = Enum.Font.Code; tl.TextSize = 14; tl.Text = plr.Name; tl.Parent = bb
    end
end

local function doWallhack()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then continue end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and not part:FindFirstChild("__pvp_hl") then
                local hl = Instance.new("Highlight")
                hl.Name = "__pvp_hl"; hl.FillColor = PVP.Config.espColor
                hl.FillTransparency = 0.6; hl.OutlineColor = Color3.new(1, 1, 1)
                hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = part
            end
        end
    end
end

local function clearWallhack()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if not char then continue end
        for _, d in ipairs(char:GetDescendants()) do
            if d.Name == "__pvp_hl" or d.Name == "__pvp_esp" then d:Destroy() end
        end
    end
end

local function doSpeed()
    local _, hum = getChar(LP)
    if hum then hum.WalkSpeed = PVP.Config.speedValue end
end

local noclipConn
local function doNoclip()
    if not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            if not PVP.Config.noclip then return end
            local char = LP.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end)
    end
end

local function doPOV()
    local cam = workspace.CurrentCamera
    if cam and PVP.Config.pov then cam.FieldOfView = PVP.Config.povValue end
end

-- ============ LOOP ============
RunService.RenderStepped:Connect(function()
    if PVP.Config.aimbot then doAim() end
    if PVP.Config.esp then doESP() end
    if PVP.Config.wallhack then doWallhack() end
    if PVP.Config.pov then doPOV() end
end)
RunService.Heartbeat:Connect(function()
    if PVP.Config.hitbox then doHitbox() else clearHitbox() end
    if PVP.Config.speed then doSpeed() end
    if PVP.Config.noclip then doNoclip() end
end)

-- ============ UI MOBILE ============
PVP.UI = { open = true }

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local vp = workspace.CurrentCamera.ViewportSize
local panelW = math.min(340, vp.X - 40)

local COL = {
    bg = Color3.fromRGB(18, 18, 24),
    header = Color3.fromRGB(0, 160, 90),
    panel = Color3.fromRGB(32, 32, 40),
    btnOff = Color3.fromRGB(44, 44, 54),
    btnOn = Color3.fromRGB(0, 150, 80),
    txt = Color3.fromRGB(235, 235, 235),
    dim = Color3.fromRGB(165, 165, 175),
    red = Color3.fromRGB(210, 55, 55),
}

local function mk(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local gui = mk("ScreenGui", {
    Name = "__pvp_menu",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    Parent = LP:WaitForChild("PlayerGui"),
}, LP:WaitForChild("PlayerGui"))

-- ===== FLOATING TOGGLE (drag-able) =====
local toggleBtn = mk("TextButton", {
    Size = UDim2.new(0, 54, 0, 54),   -- tap target >= 44px
    Position = UDim2.new(0, 16, 0, 90),
    BackgroundColor3 = COL.header,
    Text = "▼",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Code,
    TextSize = 20,
    AutoButtonColor = false,
    Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, toggleBtn)
mk("UIStroke", { Color = Color3.fromRGB(0, 230, 140), Thickness = 2 }, toggleBtn)

-- ===== MAIN FRAME =====
local frame = mk("Frame", {
    Size = UDim2.new(0, panelW, 0, math.min(520, vp.Y - 160)),
    Position = UDim2.new(0, 16, 0, 150),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Visible = PVP.UI.open,
    Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
mk("UIStroke", { Color = Color3.fromRGB(0, 200, 120), Thickness = 1.5 }, frame)

-- Header + drag (mouse & touch)
local header = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = COL.header,
    BorderSizePixel = 0,
    Active = true,
    Parent = frame,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 12) }, header)

mk("TextLabel", {
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "PVP MENU v4",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Code,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = header,
}, header)

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 36, 0, 36),
    Position = UDim2.new(1, -44, 0, 4),
    BackgroundColor3 = COL.red,
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.Code,
    TextSize = 16,
    AutoButtonColor = false,
    Parent = header,
}, header)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, closeBtn)

-- drag logic works for mouse + touch
local dragging, dragStart, startPos = false, nil, nil
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPos = frame.Position
end
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input)
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Body scroll (touch scroll native)
local scroll = mk("ScrollingFrame", {
    Size = UDim2.new(1, -14, 1, -54),
    Position = UDim2.new(0, 7, 0, 50),
    BackgroundTransparency = 1,
    ScrollBarThickness = 5,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = frame,
}, frame)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }, scroll)

local layout = mk("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = scroll,
}, scroll)

-- ===== BUILDERS (tap target 44px) =====
local function section(text)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = "▸ " .. text,
        TextColor3 = Color3.fromRGB(0, 220, 130),
        Font = Enum.Font.Code,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = scroll,
    }, scroll)
end

local function addToggle(label, key)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),   -- 44px tap target
        BackgroundColor3 = PVP.Config[key] and COL.btnOn or COL.btnOff,
        Text = (PVP.Config[key] and "● " or "○ ") .. label,
        TextColor3 = COL.txt,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = scroll,
    }, scroll)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, btn)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 12) }, btn)
    btn.MouseButton1Click:Connect(function()
        PVP.Config[key] = not PVP.Config[key]
        btn.BackgroundColor3 = PVP.Config[key] and COL.btnOn or COL.btnOff
        btn.Text = (PVP.Config[key] and "● " or "○ ") .. label
        if key == "wallhack" and not PVP.Config[key] then clearWallhack() end
    end)
end

local function addInput(label, key, min, max)
    local holder = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        Parent = scroll,
    }, scroll)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = COL.dim,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    }, holder)
    local box = mk("TextBox", {
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = COL.panel,
        Text = tostring(PVP.Config[key]),
        TextColor3 = COL.txt,
        Font = Enum.Font.Code,
        TextSize = 14,
        ClearTextOnFocus = false,
        Parent = holder,
    }, holder)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            n = math.clamp(n, min, max)
            PVP.Config[key] = n
            box.Text = tostring(n)
        else
            box.Text = tostring(PVP.Config[key])
        end
    end)
end

-- ===== CONTENT =====
section("AIMBOT")
addToggle("Aimbot", "aimbot")
addInput("Aim FOV", "aimFov", 10, 500)
addInput("Aim Smooth", "aimSmooth", 0.05, 0.95)

section("VISUAL")
addToggle("ESP Player", "esp")
addToggle("Wallhack (Chams)", "wallhack")
addToggle("Hitbox Expander", "hitbox")
addInput("Hitbox Size", "hitboxSize", 2, 30)

section("MOVEMENT")
addToggle("Speed", "speed")
addInput("Speed Value", "speedValue", 16, 200)
addToggle("Noclip", "noclip")

section("CAMERA")
addToggle("POV Override", "pov")
addInput("Camera FOV", "povValue", 20, 120)

-- auto canvas
local function resizeCanvas()
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
end
resizeCanvas()
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeCanvas)

-- ===== OPEN/CLOSE =====
local function setOpen(v)
    PVP.UI.open = v
    frame.Visible = v
    toggleBtn.Text = v and "▼" or "▲"
    toggleBtn.Position = v and toggleBtn.Position or toggleBtn.Position
end

toggleBtn.MouseButton1Click:Connect(function()
    setOpen(not PVP.UI.open)
end)
closeBtn.MouseButton1Click:Connect(function()
    setOpen(false)
end)

-- toggle button drag-able (HP: geser biar nggak nutupin tombol game)
local tbDragging, tbStart, tbPos = false, nil, nil
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        tbDragging = true
        tbStart = input.Position
        tbPos = toggleBtn.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not tbDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - tbStart
        if d.Magnitude > 6 then  -- threshold: klik vs drag
            toggleBtn.Position = UDim2.new(
                tbPos.X.Scale, tbPos.X.Offset + d.X,
                tbPos.Y.Scale, tbPos.Y.Offset + d.Y
            )
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        tbDragging = false
    end
end)

-- mobile hotkey: 3-finger tap toggle (buat HP)
local touches = 0
UIS.TouchStarted:Connect(function() touches = touches + 1 end)
UIS.TouchEnded:Connect(function() touches = 0 end)

print("[PVP] v4 mobile ready — tombol ▼ buka, X tutup, tombol bisa digeser")
