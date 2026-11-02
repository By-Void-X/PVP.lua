--[[
    AimbotUI — shooter build
    UI: WindUI (beda dari Rayfield)
    fitur:
      - AIMBOT kamera + smooth + FOV circle
      - target part: Head / Torso / Legs
      - target: Player + Bot (NPC)
      - No recoil
      - ESP lengkap (box, line, nama, health, distance) — player & bot
      - Speed
      - Noclip
    executor: HP (Delta/Fluxus/Arceus)
    absolute ollie, built by olivia
--]]

-- ============================================================
-- UI LIBRARY: WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then warn("[AimbotUI] WindUI gagal load"); return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local State = {
    -- aimbot
    AimbotEnabled = false,
    AimbotSmooth = 5,
    AimbotFov = 150,
    AimbotPart = "Head",        -- Head / Torso / Legs
    AimbotTargetBots = true,
    AimbotTargetPlayers = true,
    AimbotVisibleCheck = false,
    CurrentTarget = nil,

    -- recoil
    NoRecoilEnabled = false,
    noRecoilConn = nil,
    savedCamOffset = nil,

    -- esp
    EspEnabled = false,
    EspBox = true, EspLine = false, EspName = true,
    EspHealth = true, EspDistance = true,
    EspPlayer = true, EspBot = true,
    EspColor = Color3.fromRGB(0, 255, 100),
    EspBotColor = Color3.fromRGB(255, 80, 80),
    EspMaxDist = 1500,
    espObjects = {},            -- [model] = {...}
    espScanTick = 0,

    -- speed
    SpeedEnabled = false,
    WalkSpeed = 50,
    defaultWalkSpeed = 16,

    -- noclip
    NoclipEnabled = false,
    savedCollide = {},
    noclipConn = nil,
}

-- ============================================================
-- UTILS
-- ============================================================
local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function isPlayerModel(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return p end
    end
    return nil
end

local function isBotModel(model)
    if isPlayerModel(model) then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    -- bot = model punya Humanoid tapi bukan character player
    return true
end

local function getTargetPart(model, partName)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    if partName == "Head" then
        return model:FindFirstChild("Head") or hrp
    elseif partName == "Legs" then
        return model:FindFirstChild("LeftLeg") or model:FindFirstChild("LeftFoot") or hrp
    else
        return model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or hrp
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 60
fovCircle.Filled = false
fovCircle.Transparency = 0.8
fovCircle.Color = Color3.fromRGB(0, 255, 100)
fovCircle.Visible = false

local function updateFovCircle()
    if State.AimbotEnabled then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = State.AimbotFov / 2
        fovCircle.Color = State.EspColor
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end

local function isValidTarget(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local player = isPlayerModel(model)
    if player then
        if player == LocalPlayer then return false end
        if not State.AimbotTargetPlayers then return false end
    else
        if not State.AimbotTargetBots then return false end
        if not isBotModel(model) then return false end
    end
    return true
end

local function getClosestTarget()
    local myHRP = getHRP()
    if not myHRP then return nil end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge

    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and isValidTarget(model) then
            local part = getTargetPart(model, State.AimbotPart)
            if part then
                local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= State.AimbotFov / 2 and d < bestDist then
                        if State.AimbotVisibleCheck then
                            local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                            local hit = Workspace:FindPartOnRay(ray, LocalPlayer.Character, false, true)
                            if hit and not hit:IsDescendantOf(model) then
                                -- blocked, skip
                            else
                                best, bestDist = model, d
                            end
                        else
                            best, bestDist = model, d
                        end
                    end
                end
            end
        end
    end
    return best
end

local aimbotConn = RunService.RenderStepped:Connect(function()
    updateFovCircle()
    if not State.AimbotEnabled then return end
    local target = getClosestTarget()
    State.CurrentTarget = target
    if target then
        local part = getTargetPart(target, State.AimbotPart)
        if part then
            local goal = CFrame.new(Camera.CFrame.Position, part.Position)
            local smooth = math.max(1, State.AimbotSmooth)
            Camera.CFrame = Camera.CFrame:Lerp(goal, 1 / smooth)
        end
    end
end)

-- ============================================================
-- NO RECOIL
-- ============================================================
local function startNoRecoil()
    if State.noRecoilConn then State.noRecoilConn:Disconnect() end
    State.savedCamOffset = Camera.CFrame
    State.noRecoilConn = RunService.RenderStepped:Connect(function()
        if not State.NoRecoilEnabled then return end
        -- netralin shake kamera: pakai CFrame stabil dari posisi + look
        local camCF = Camera.CFrame
        local pos = camCF.Position
        local look = camCF.LookVector
        -- flatten rotasi X (pitch) biar nggak naik pas nembak
        local flatLook = Vector3.new(look.X, look.Y * 0.1, look.Z).Unit
        Camera.CFrame = CFrame.new(pos, pos + flatLook)
    end)
end

local function stopNoRecoil()
    if State.noRecoilConn then State.noRecoilConn:Disconnect(); State.noRecoilConn = nil end
end

-- ============================================================
-- ESP (player + bot)
-- ============================================================
local function removeESPForModel(model)
    local obj = State.espObjects[model]
    if not obj then return end
    if obj.highlight then obj.highlight:Destroy() end
    if obj.tracer then obj.tracer:Remove() end
    for _, l in ipairs(obj.boxLines or {}) do l:Remove() end
    if obj.billboard and obj.billboard.Parent then obj.billboard:Destroy() end
    if obj.healthBar and obj.healthBar.Parent and obj.healthBar.Parent:IsA("BillboardGui") then
        obj.healthBar.Parent:Destroy()
    end
    State.espObjects[model] = nil
end

local function clearAllESP()
    for model, _ in pairs(State.espObjects) do removeESPForModel(model) end
    State.espObjects = {}
end

local function createESPForModel(model)
    if State.espObjects[model] or not State.EspEnabled then return end
    local isPlayer = isPlayerModel(model)
    local color = isPlayer and State.EspColor or State.EspBotColor
    if isPlayer and not State.EspPlayer then return end
    if not isPlayer and not State.EspBot then return end

    local obj = { highlight=nil, tracer=nil, boxLines={}, billboard=nil,
                  nameLabel=nil, distLabel=nil, healthBar=nil, healthFg=nil }

    local hl = Instance.new("Highlight")
    hl.Name = "AimESP"
    hl.FillColor = color; hl.OutlineColor = color
    hl.FillTransparency = 0.55; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = model; hl.Parent = model
    obj.highlight = hl

    if State.EspName or State.EspDistance then
        local head = model:FindFirstChild("Head")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Name = "AimESPName"; bb.Adornee = head
            bb.Size = UDim2.new(0, 200, 0, 50); bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true; bb.Parent = head

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, 0, 0.5, 0); nl.BackgroundTransparency = 1
            nl.Text = isPlayer and isPlayer.Name or model.Name
            nl.TextColor3 = color; nl.TextStrokeTransparency = 0
            nl.TextStrokeColor3 = Color3.new(0,0,0); nl.TextScaled = true
            nl.Font = Enum.Font.GothamBold; nl.Visible = State.EspName
            nl.Parent = bb
            obj.nameLabel = nl

            local dl = Instance.new("TextLabel")
            dl.Size = UDim2.new(1, 0, 0.5, 0); dl.Position = UDim2.new(0, 0, 0.5, 0)
            dl.BackgroundTransparency = 1; dl.Text = ""
            dl.TextColor3 = color; dl.TextStrokeTransparency = 0
            dl.TextStrokeColor3 = Color3.new(0,0,0); dl.TextScaled = true
            dl.Font = Enum.Font.Gotham; dl.Visible = State.EspDistance
            dl.Parent = bb
            obj.distLabel = dl
            obj.billboard = bb
        end
    end

    if State.EspHealth then
        local head = model:FindFirstChild("Head")
        if head then
            local hb = Instance.new("BillboardGui")
            hb.Name = "AimESPHealth"; hb.Adornee = head
            hb.Size = UDim2.new(0, 50, 0, 6); hb.StudsOffset = Vector3.new(0, 3.2, 0)
            hb.AlwaysOnTop = true; hb.Parent = head
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            bg.BorderSizePixel = 1; bg.BorderColor3 = Color3.new(0,0,0); bg.Parent = hb
            local fg = Instance.new("Frame")
            fg.Size = UDim2.new(1, 0, 1, 0); fg.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            fg.BorderSizePixel = 0; fg.Parent = bg
            obj.healthBar = bg; obj.healthFg = fg
        end
    end

    if State.EspLine then
        local ok, line = pcall(function() return Drawing.new("Line") end)
        if ok and line then
            line.Color = color; line.Thickness = 1.5; line.Visible = false
            obj.tracer = line
        end
    end

    if State.EspBox then
        for i = 1, 4 do
            local ok, l = pcall(function() return Drawing.new("Line") end)
            if ok and l then
                l.Color = color; l.Thickness = 1; l.Visible = false
                table.insert(obj.boxLines, l)
            end
        end
    end

    State.espObjects[model] = obj
end

local function rebuildAllESP()
    clearAllESP()
    if not State.EspEnabled then return end
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
            if isPlayerModel(model) or isBotModel(model) then
                createESPForModel(model)
            end
        end
    end
end

local function updateESP()
    if not State.EspEnabled then return end

    State.espScanTick = State.espScanTick + 1
    if State.espScanTick >= 60 then
        State.espScanTick = 0
        -- scan model baru
        for _, model in ipairs(Workspace:GetDescendants()) do
            if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
                if (isPlayerModel(model) or isBotModel(model)) and not State.espObjects[model] then
                    createESPForModel(model)
                end
            end
        end
    end

    local myHRP = getHRP()
    local myPos = myHRP and myHRP.Position or Vector3.zero

    for model, obj in pairs(State.espObjects) do
        if not model.Parent then
            removeESPForModel(model)
            continue
        end
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            if obj.tracer then obj.tracer.Visible = false end
            for _, l in ipairs(obj.boxLines) do l.Visible = false end
            if obj.highlight then obj.highlight.Enabled = false end
            continue
        end

        local dist = (hrp.Position - myPos).Magnitude
        local inRange = dist <= State.EspMaxDist
        local isPlayer = isPlayerModel(model)
        local color = isPlayer and State.EspColor or State.EspBotColor

        if obj.highlight then
            obj.highlight.Enabled = inRange and hum.Health > 0
            obj.highlight.FillColor = color
            obj.highlight.OutlineColor = color
        end
        if obj.nameLabel then
            obj.nameLabel.Visible = State.EspName and inRange
            obj.nameLabel.Text = isPlayer and isPlayer.Name or model.Name
            obj.nameLabel.TextColor3 = color
        end
        if obj.distLabel then
            obj.distLabel.Visible = State.EspDistance and inRange
            obj.distLabel.Text = string.format("[%d]", math.floor(dist))
            obj.distLabel.TextColor3 = color
        end
        if obj.healthFg then
            local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            obj.healthFg.Size = UDim2.new(ratio, 0, 1, 0)
            obj.healthFg.BackgroundColor3 = Color3.new(1 - ratio, ratio, 0)
            obj.healthFg.Visible = State.EspHealth and inRange
        end
        if obj.tracer then
            local sp, on = Camera:WorldToViewportPoint(hrp.Position)
            if on and State.EspLine and inRange then
                obj.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, 0)
                obj.tracer.To = Vector2.new(sp.X, sp.Y)
                obj.tracer.Color = color
                obj.tracer.Visible = true
            else
                obj.tracer.Visible = false
            end
        end
        if #obj.boxLines == 4 then
            if State.EspBox and inRange then
                local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                local bot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local ts, ton = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                local bs, bon = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                if ton and bon then
                    local h = math.abs(bs.Y - ts.Y); local w = h * 0.6
                    local cx = (ts.X + bs.X) / 2
                    local tl = Vector2.new(cx - w/2, ts.Y); local tr = Vector2.new(cx + w/2, ts.Y)
                    local bl = Vector2.new(cx - w/2, bs.Y); local br = Vector2.new(cx + w/2, bs.Y)
                    obj.boxLines[1].From = tl; obj.boxLines[1].To = tr
                    obj.boxLines[2].From = tr; obj.boxLines[2].To = br
                    obj.boxLines[3].From = br; obj.boxLines[3].To = bl
                    obj.boxLines[4].From = bl; obj.boxLines[4].To = tl
                    for _, l in ipairs(obj.boxLines) do l.Color = color; l.Visible = true end
                else
                    for _, l in ipairs(obj.boxLines) do l.Visible = false end
                end
            else
                for _, l in ipairs(obj.boxLines) do l.Visible = false end
            end
        end
    end
end

RunService.RenderStepped:Connect(updateESP)

-- ============================================================
-- SPEED
-- ============================================================
local function applySpeed()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = State.SpeedEnabled and State.WalkSpeed or State.defaultWalkSpeed
end

-- ============================================================
-- NOCLIP
-- ============================================================
local function startNoclip()
    local char = getChar()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if State.savedCollide[part] == nil then State.savedCollide[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end
    if State.noclipConn then State.noclipConn:Disconnect() end
    State.noclipConn = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local c = getChar()
        if not c then return end
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                if State.savedCollide[part] == nil then State.savedCollide[part] = true end
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if State.noclipConn then State.noclipConn:Disconnect(); State.noclipConn = nil end
    for part, orig in pairs(State.savedCollide) do
        if part and part.Parent then part.CanCollide = orig end
    end
    State.savedCollide = {}
end

-- ============================================================
-- UI WINDUI
-- ============================================================
local Window = WindUI:CreateWindow({
    Title = "AimbotUI",
    Icon = "crosshair",
    Author = "ByVoid",
    Folder = "AimbotUI",
    Size = UDim2.fromOffset(520, 420),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 160,
    Background = "Textures/denis.png",
    HasOutline = true,
})

-- ============================================================
-- AIMBOT TAB
-- ============================================================
local AimbotTab = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
AimbotTab:Section({ Title = "Aimbot Kamera" })
AimbotTab:Toggle({
    Title = "Enable Aimbot",
    Value = false,
    Callback = function(v) State.AimbotEnabled = v end,
})
AimbotTab:Slider({
    Title = "Smooth",
    Value = { Min = 1, Max = 20, Default = 5 },
    Callback = function(v) State.AimbotSmooth = v end,
})
AimbotTab:Slider({
    Title = "FOV Radius",
    Value = { Min = 20, Max = 600, Default = 150 },
    Callback = function(v) State.AimbotFov = v end,
})
AimbotTab:Dropdown({
    Title = "Target Part",
    Values = { "Head", "Torso", "Legs" },
    Default = "Head",
    Callback = function(v) State.AimbotPart = v end,
})
AimbotTab:Section({ Title = "Target" })
AimbotTab:Toggle({ Title = "Target Player", Value = true,
    Callback = function(v) State.AimbotTargetPlayers = v end })
AimbotTab:Toggle({ Title = "Target Bot", Value = true,
    Callback = function(v) State.AimbotTargetBots = v end })
AimbotTab:Toggle({ Title = "Wall Check (skip di balik dinding)", Value = false,
    Callback = function(v) State.AimbotVisibleCheck = v end })

-- ============================================================
-- COMBAT TAB
-- ============================================================
local CombatTab = Window:Tab({ Title = "Combat", Icon = "flame" })
CombatTab:Section({ Title = "No Recoil" })
CombatTab:Toggle({
    Title = "Enable No Recoil",
    Value = false,
    Callback = function(v)
        State.NoRecoilEnabled = v
        if v then startNoRecoil() else stopNoRecoil() end
    end,
})
CombatTab:Paragraph({ Title = "Info", Desc = "No recoil flatten pitch kamera. Kalau game recoil-nya server-side, fitur ini visual doang." })

-- ============================================================
-- ESP TAB
-- ============================================================
local EspTab = Window:Tab({ Title = "ESP", Icon = "eye" })
EspTab:Section({ Title = "ESP Player + Bot" })
EspTab:Toggle({
    Title = "Enable ESP",
    Value = false,
    Callback = function(v) State.EspEnabled = v
        if v then rebuildAllESP() else clearAllESP() end end,
})
EspTab:Toggle({ Title = "ESP Box", Value = true,
    Callback = function(v) State.EspBox = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Toggle({ Title = "ESP Line", Value = false,
    Callback = function(v) State.EspLine = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Toggle({ Title = "ESP Nama", Value = true,
    Callback = function(v) State.EspName = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Toggle({ Title = "ESP Health Bar", Value = true,
    Callback = function(v) State.EspHealth = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Toggle({ Title = "ESP Distance", Value = true,
    Callback = function(v) State.EspDistance = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Section({ Title = "Filter Target" })
EspTab:Toggle({ Title = "ESP Player", Value = true,
    Callback = function(v) State.EspPlayer = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Toggle({ Title = "ESP Bot", Value = true,
    Callback = function(v) State.EspBot = v; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Slider({ Title = "ESP Max Distance",
    Value = { Min = 100, Max = 5000, Default = 1500 },
    Callback = function(v) State.EspMaxDist = v end })
EspTab:Section({ Title = "Warna" })
EspTab:Colorpicker({ Title = "Warna Player", Default = Color3.fromRGB(0, 255, 100),
    Callback = function(c) State.EspColor = c; if State.EspEnabled then rebuildAllESP() end end })
EspTab:Colorpicker({ Title = "Warna Bot", Default = Color3.fromRGB(255, 80, 80),
    Callback = function(c) State.EspBotColor = c; if State.EspEnabled then rebuildAllESP() end end })

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
local MoveTab = Window:Tab({ Title = "Movement", Icon = "footprints" })
MoveTab:Section({ Title = "Speed" })
MoveTab:Toggle({
    Title = "Enable Speed",
    Value = false,
    Callback = function(v) State.SpeedEnabled = v; applySpeed() end,
})
MoveTab:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 300, Default = 50 },
    Callback = function(v) State.WalkSpeed = v; applySpeed() end,
})
MoveTab:Section({ Title = "Noclip" })
MoveTab:Toggle({
    Title = "Enable Noclip",
    Value = false,
    Callback = function(v)
        State.NoclipEnabled = v
        if v then startNoclip() else stopNoclip() end
    end,
})

-- ============================================================
-- RESPAWN CLEANUP
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applySpeed()
    State.savedCollide = {}
    if State.NoclipEnabled then startNoclip() end
    if State.EspEnabled then rebuildAllESP() end
end)

WindUI:Notify({
    Title = "AimbotUI",
    Content = "No system is safe — aimbot + esp player/bot + speed + noclip",
    Duration = 4,
    Icon = "check",
})
