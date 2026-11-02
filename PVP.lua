-- pvp_menu_v2.lua | Roblox PVP mod menu
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/user/repo/main/pvp_menu_v2.lua"))()

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
    aimbot = false,
    aimFov = 120,
    aimSmooth = 0.25,
    aimPart = "Head",
    hitbox = false,
    hitboxSize = 8,
    esp = false,
    espColor = Color3.fromRGB(0, 255, 120),
    wallhack = false,
    speed = false,
    speedValue = 50,
    noclip = false,
    pov = false,
    povValue = 70,
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

-- ============ FITUR: AIMBOT ============
local function doAim()
    local target = getTarget()
    if not target then return end
    local cam = workspace.CurrentCamera
    local goal = CFrame.new(cam.CFrame.Position, target.Position)
    cam.CFrame = cam.CFrame:Lerp(goal, 1 - PVP.Config.aimSmooth)
end

-- ============ FITUR: HITBOX EXPANDER ============
local function doHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char, _, root = getChar(plr)
        if not char then continue end
        local hb = char:FindFirstChild("__pvp_hitbox")
        if not hb then
            hb = Instance.new("Part")
            hb.Name = "__pvp_hitbox"
            hb.Transparency = 1
            hb.CanCollide = false
            hb.CanQuery = false
            hb.Massless = true
            hb.Parent = char
            local w = Instance.new("WeldConstraint")
            w.Part0 = hb
            w.Part1 = root
            w.Parent = hb
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

-- ============ FITUR: ESP ============
local function doESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then continue end
        local head = char:FindFirstChild("Head")
        if not head then continue end
        if head:FindFirstChild("__pvp_esp") then continue end
        local bb = Instance.new("BillboardGui")
        bb.Name = "__pvp_esp"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 200, 0, 40)
        bb.AlwaysOnTop = true
        bb.Parent = head
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = PVP.Config.espColor
        tl.TextStrokeTransparency = 0
        tl.Font = Enum.Font.Code
        tl.TextSize = 14
        tl.Text = plr.Name
        tl.Parent = bb
    end
end

-- ============ FITUR: WALLHACK (CHAMS) ============
local function doWallhack()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        if not char then continue end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and not part:FindFirstChild("__pvp_hl") then
                local hl = Instance.new("Highlight")
                hl.Name = "__pvp_hl"
                hl.FillColor = PVP.Config.espColor
                hl.FillTransparency = 0.6
                hl.OutlineColor = Color3.new(1, 1, 1)
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
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

-- ============ FITUR: SPEED ============
local function doSpeed()
    local _, hum = getChar(LP)
    if hum then hum.WalkSpeed = PVP.Config.speedValue end
end

-- ============ FITUR: NOCLIP ============
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

-- ============ FITUR: POV ============
local function doPOV()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if PVP.Config.pov then
        cam.FieldOfView = PVP.Config.povValue
    end
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

-- ============ UI ============
local function buildUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "__pvp_menu"
    gui.ResetOnSpawn = false
    gui.Parent = LP:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 270, 0, 480)
    frame.Position = UDim2.new(0, 20, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 32)
    title.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
    title.Text = "PVP MENU v2"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 36)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.Parent = frame

    local y = 0
    local function addToggle(label, key)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.Position = UDim2.new(0, 0, 0, y)
        btn.BackgroundColor3 = PVP.Config[key] and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(40, 40, 50)
        btn.Text = (PVP.Config[key] and "[ON]  " or "[OFF] ") .. label
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Code
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = scroll
        btn.MouseButton1Click:Connect(function()
            PVP.Config[key] = not PVP.Config[key]
            btn.BackgroundColor3 = PVP.Config[key] and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(40, 40, 50)
            btn.Text = (PVP.Config[key] and "[ON]  " or "[OFF] ") .. label
            if key == "wallhack" and not PVP.Config[key] then clearWallhack() end
        end)
        y = y + 34
    end

    local function addInput(label, key, min, max)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, 0, 0, 46)
        holder.Position = UDim2.new(0, 0, 0, y)
        holder.BackgroundTransparency = 1
        holder.Parent = scroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = label .. ": " .. tostring(PVP.Config[key])
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = holder

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 22)
        box.Position = UDim2.new(0, 0, 0, 20)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        box.Text = tostring(PVP.Config[key])
        box.TextColor3 = Color3.new(1, 1, 1)
        box.Font = Enum.Font.Code
        box.TextSize = 12
        box.Parent = holder

        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then
                n = math.clamp(n, min, max)
                PVP.Config[key] = n
                lbl.Text = label .. ": " .. tostring(n)
                box.Text = tostring(n)
            else
                box.Text = tostring(PVP.Config[key])
            end
        end)
        y = y + 50
    end

    addToggle("Aimbot", "aimbot")
    addInput("Aim FOV", "aimFov", 10, 500)
    addInput("Aim Smooth", "aimSmooth", 0.05, 0.95)
    addToggle("Hitbox Expander", "hitbox")
    addInput("Hitbox Size", "hitboxSize", 2, 30)
    addToggle("ESP Player", "esp")
    addToggle("Wallhack (Chams)", "wallhack")
    addToggle("Speed", "speed")
    addInput("Speed Value", "speedValue", 16, 200)
    addToggle("Noclip", "noclip")
    addToggle("POV Override", "pov")
    addInput("FOV Camera", "povValue", 20, 120)

    scroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)
end

buildUI()
print("[PVP] v2 ready — aimbot/hitbox/ESP/wallhack/speed/noclip/POV loaded")
