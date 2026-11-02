-- pvp_menu_v5.lua | Roblox PVP mod menu — slider + FOV circle + UI v5

if not getgenv then error("[PVP] executor dengan getgenv() dibutuhkan") end

local PVP = {}
getgenv().PVP = PVP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
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

-- ============ UI ============
PVP.UI = { open = true }

local vp = workspace.CurrentCamera.ViewportSize
local panelW = math.min(360, vp.X - 32)

local COL = {
    bg = Color3.fromRGB(14, 15, 20),
    bg2 = Color3.fromRGB(22, 24, 32),
    accent = Color3.fromRGB(0, 200, 130),
    accent2 = Color3.fromRGB(0, 120, 255),
    on = Color3.fromRGB(0, 170, 100),
    off = Color3.fromRGB(38, 40, 50),
    txt = Color3.fromRGB(235, 237, 245),
    dim = Color3.fromRGB(150, 155, 170),
    red = Color3.fromRGB(220, 60, 70),
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

-- ===== FOV CIRCLE (ring di tengah layar) =====
local fovGui = mk("ScreenGui", {
    Name = "__pvp_fov", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 998, Parent = gui.Parent,
})
local fovCircle = mk("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, PVP.Config.aimFov * 2, 0, PVP.Config.aimFov * 2),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = fovGui,
}, fovGui)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fovCircle)
local fovStroke = mk("UIStroke", {
    Color = COL.accent, Thickness = 1.5, Transparency = 0.25,
}, fovCircle)

local function updateFovCircle()
    local size = PVP.Config.aimFov * 2
    fovCircle.Size = UDim2.new(0, size, 0, size)
    fovCircle.Visible = PVP.Config.aimbot and PVP.UI.open
end

-- ===== TOGGLE BUTTON =====
local toggleBtn = mk("TextButton", {
    Size = UDim2.new(0, 54, 0, 54),
    Position = UDim2.new(0, 16, 0, 90),
    BackgroundColor3 = COL.accent,
    Text = "▼",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    AutoButtonColor = false,
    Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(1, 0) }, toggleBtn)
mk("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.5 }, toggleBtn)

-- ===== MAIN FRAME =====
local frame = mk("Frame", {
    Size = UDim2.new(0, panelW, 0, 0),
    Position = UDim2.new(0, 16, 0, 150),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = PVP.UI.open,
    Parent = gui,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
mk("UIStroke", { Color = COL.accent, Thickness = 1.5, Transparency = 0.3 }, frame)

local targetH = math.min(540, vp.Y - 180)
frame.Size = UDim2.new(0, panelW, 0, targetH)

-- gradient header
local header = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = COL.accent,
    BorderSizePixel = 0,
    Active = true,
    Parent = frame,
}, frame)
mk("UICorner", { CornerRadius = UDim.new(0, 14) }, header)
mk("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COL.accent),
        ColorSequenceKeypoint.new(1, COL.accent2),
    }),
    Rotation = 0,
}, header)

mk("TextLabel", {
    Size = UDim2.new(1, -110, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "✦ PVP MENU v5",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = header,
}, header)

local closeBtn = mk("TextButton", {
    Size = UDim2.new(0, 36, 0, 36),
    Position = UDim2.new(1, -44, 0, 6),
    BackgroundColor3 = COL.red,
    Text = "✕",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    AutoButtonColor = false,
    Parent = header,
}, header)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, closeBtn)

-- drag header
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = frame.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- body
local scroll = mk("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -58),
    Position = UDim2.new(0, 8, 0, 52),
    BackgroundTransparency = 1,
    ScrollBarThickness = 5,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = frame,
}, frame)
mk("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }, scroll)
local layout = mk("UIListLayout", {
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll,
}, scroll)

-- ===== BUILDERS =====
local function section(text)
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = "▸ " .. text,
        TextColor3 = COL.accent, Font = Enum.Font.GothamBold,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll,
    }, scroll)
end

local function addToggle(label, key, onChange)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = PVP.Config[key] and COL.on or COL.off,
        Text = (PVP.Config[key] and "● " or "○ ") .. label,
        TextColor3 = COL.txt, Font = Enum.Font.Gotham,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false, Parent = scroll,
    }, scroll)
    mk("UICorner", { CornerRadius = UDim.new(0, 10) }, btn)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 14) }, btn)
    btn.MouseButton1Click:Connect(function()
        PVP.Config[key] = not PVP.Config[key]
        btn.BackgroundColor3 = PVP.Config[key] and COL.on or COL.off
        btn.Text = (PVP.Config[key] and "● " or "○ ") .. label
        if key == "wallhack" and not PVP.Config[key] then clearWallhack() end
        if onChange then onChange() end
        updateFovCircle()
    end)
end

local function addSlider(label, key, min, max)
    local holder = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = scroll,
    }, scroll)

    local lbl = mk("TextLabel", {
        Size = UDim2.new(1, -60, 0, 20), BackgroundTransparency = 1,
        Text = label, TextColor3 = COL.dim, Font = Enum.Font.Gotham,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    }, holder)

    local valLbl = mk("TextLabel", {
        Size = UDim2.new(0, 55, 0, 20), Position = UDim2.new(1, -55, 0, 0),
        BackgroundTransparency = 1, Text = tostring(PVP.Config[key]),
        TextColor3 = COL.accent, Font = Enum.Font.GothamBold,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
    }, holder)

    local track = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = COL.off, Parent = holder,
    }, holder)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

    local fill = mk("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = COL.accent, Parent = track,
    }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local knob = mk("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
    }, track)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
    mk("UIStroke", { Color = COL.accent, Thickness = 2 }, knob)

    local function setFromX(px)
        local trackW = track.AbsoluteSize.X
        if trackW <= 0 then return end
        local rel = math.clamp(px / trackW, 0, 1)
        local val = min + (max - min) * rel
        val = math.floor(val * 100 + 0.5) / 100
        PVP.Config[key] = val
        valLbl.Text = tostring(val)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        if key == "aimFov" then updateFovCircle() end
    end

    local dragging = false
    local function begin(input)
        dragging = true
        local relX = input.Position.X - track.AbsolutePosition.X
        setFromX(relX)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            begin(input)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X - track.AbsolutePosition.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- init posisi
    task.defer(function()
        local rel = (PVP.Config[key] - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
    end)
end

-- ===== CONTENT =====
section("AIMBOT")
addToggle("Aimbot", "aimbot", updateFovCircle)
addSlider("Aim FOV", "aimFov", 10, 500)
addSlider("Aim Smooth", "aimSmooth", 0.05, 0.95)

section("VISUAL")
addToggle("ESP Player", "esp")
addToggle("Wallhack (Chams)", "wallhack")
addToggle("Hitbox Expander", "hitbox")
addSlider("Hitbox Size", "hitboxSize", 2, 30)

section("MOVEMENT")
addToggle("Speed", "speed")
addSlider("Speed Value", "speedValue", 16, 200)
addToggle("Noclip", "noclip")

section("CAMERA")
addToggle("POV Override", "pov")
addSlider("Camera FOV", "povValue", 20, 120)

local function resizeCanvas()
    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
end
resizeCanvas()
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeCanvas)

-- ===== OPEN/CLOSE (animasi tween) =====
local function setOpen(v)
    PVP.UI.open = v
    if v then
        frame.Visible = true
        frame.Size = UDim2.new(0, panelW, 0, 0)
        TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(0, panelW, 0, targetH) }):Play()
    else
        local t = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Size = UDim2.new(0, panelW, 0, 0) })
        t:Play()
        t.Completed:Connect(function() if not PVP.UI.open then frame.Visible = false end end)
    end
    toggleBtn.Text = v and "▼" or "▲"
    updateFovCircle()
end

toggleBtn.MouseButton1Click:Connect(function() setOpen(not PVP.UI.open) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

-- toggle button draggable
local tbDrag, tbStart, tbPos = false, nil, nil
toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        tbDrag = true; tbStart = input.Position; tbPos = toggleBtn.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not tbDrag then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - tbStart
        if d.Magnitude > 6 then
            toggleBtn.Position = UDim2.new(
                tbPos.X.Scale, tbPos.X.Offset + d.X,
                tbPos.Y.Scale, tbPos.Y.Offset + d.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then tbDrag = false end
end)

-- render loop utk FOV circle ukuran realtime
RunService.RenderStepped:Connect(function()
    if fovCircle.Visible then
        local size = PVP.Config.aimFov * 2
        fovCircle.Size = UDim2.new(0, size, 0, size)
    end
end)

updateFovCircle()
print("[PVP] v5 ready — slider drag, FOV circle, UI animated")
