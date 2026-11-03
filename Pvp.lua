--[[
    ByVoid — No system is safe
    update: OPTIMIZED (ringan buat HP)
      - ESP update 30 FPS (Heartbeat + throttle)
      - cache getPlayerRoot (scan tiap 5s, bukan tiap frame)
      - aimbot findBestTarget tiap 3 frame
      - fallback scan default OFF
      - low graphics apply sekali + loop 5s
      - fullbright loop 5s
      - box 3D update tiap 2 frame
    fitur UTUH:
      jump tahan, fly HP, speed, ESP brutal, noclip, wallhack glow,
      spinbot, god mode + map support tag, fullbright, low graphics,
      POV, aimbot brutal, tp
    executor: HP (Delta/Fluxus/Arceus) — Rayfield UI
    absolute ollie, built by olivia
--]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then warn("[ByVoid] Rayfield gagal load"); return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- PERF SETTINGS
-- ============================================================
local PERF = {
    ESP_HZ = 30,              -- ESP update 30 FPS (bukan 60)
    ROOT_CACHE_TTL = 5,       -- cache root player 5 detik
    AIMBOT_TARGET_EVERY = 3,  -- cari target tiap 3 frame
    BOX3D_EVERY = 2,          -- box 3D update tiap 2 frame
    FB_LOOP = 5,              -- fullbright re-apply 5 detik
    LOWGFX_LOOP = 5,          -- low gfx re-apply 5 detik
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    MultiJumpEnabled = false, jumpVelocity = 50, JumpHoldInterval = 0.08, jumpInputActive = false,
    FlyEnabled = false, FlySpeed = 100, flyConn = nil, flyBV = nil, flyBG = nil, flyUp = false, flyDown = false,
    SpeedEnabled = false, WalkSpeed = 50, defaultWalkSpeed = 16,
    EspEnabled = false, EspGlow = false, EspLine = false, EspBox = false,
    EspName = false, EspHealth = false, EspDistance = false, EspBox3D = false,
    EspFallbackScan = false,   -- DEFAULT OFF
    EspColor = Color3.fromRGB(0, 255, 100), EspMaxDist = 500,
    espObjects = {}, espScanTick = 0,
    rootCache = {},            -- [player] = {hrp, char, t}
    NoclipEnabled = false, WallhackGlowEnabled = false,
    WallhackColor = Color3.fromRGB(255, 60, 60),
    wallhackObjects = {}, savedCollide = {}, noclipConn = nil,
    SpinBotEnabled = false, SpinBotSpeed = 20, spinConn = nil,
    GodModeEnabled = false, godConn = nil, godHealthConn = nil,
    savedHealth = nil, savedMaxHealth = nil,
    godSupportStatus = "belum dites", godTestResult = nil, godTestDone = false,
    FullbrightEnabled = false, fbThread = nil, fbSaved = nil,
    PovEnabled = false, PovValue = 70, defaultFOV = 70,
    LowGfxEnabled = false, lowGfxThread = nil, lowGfxSaved = nil,
    -- AIMBOT
    AimbotEnabled = false,
    AimbotTargetPart = "Head",
    AimbotMode = "Cuma Pas Nembak",  -- default lebih ringan
    AimbotFov = 150,
    AimbotSmooth = 0,
    AimbotPredict = true,
    AimbotPredictAmount = 0.12,
    AimbotFreeMove = false,
    AimbotShowFov = true,
    AimbotColor = Color3.fromRGB(255, 50, 50),
    aimbotTarget = nil, aimbotShooting = false, aimbotFrame = 0,
    fovCircle = nil,
    savedAutoRotate = nil,
    SelectedPlayer = nil,
}

local GodSupportLabel = nil
local AIMBOT_BIND = "ByVoidAimbotRender"
local lastESPUpdate = 0
local box3DFrame = 0

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
local function notify(t, c)
    Rayfield:Notify({ Title = t, Content = c, Duration = 4 })
end

-- cached root: jangan scan workspace tiap frame
local function getPlayerRoot(p)
    local now = os.clock()
    local c = State.rootCache[p]
    if c and (now - c.t) < PERF.ROOT_CACHE_TTL then
        if c.hrp and c.hrp.Parent then return c.hrp, c.char end
        if c.char and c.char.Parent then
            local hrp = c.char:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp, c.char end
        end
    end
    -- refresh cache
    local char = p.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            State.rootCache[p] = { hrp = hrp, char = char, t = now }
            return hrp, char
        end
    end
    -- fallback scan cuma kalau toggle ON
    if State.EspFallbackScan then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent and d.Parent.Name == p.Name then
                local hrp = d.Parent:FindFirstChild("HumanoidRootPart")
                if hrp then
                    State.rootCache[p] = { hrp = hrp, char = d.Parent, t = now }
                    return hrp, d.Parent
                end
            end
        end
    end
    State.rootCache[p] = { hrp = nil, char = nil, t = now }
    return nil, nil
end

local function setGodSupportLabel(txt)
    State.godSupportStatus = txt
    if GodSupportLabel then GodSupportLabel:Set(txt) end
end

-- ============================================================
-- 1. MULTI JUMP
-- ============================================================
local jumpHolding = false
local jumpHoldThread = nil

local function doJump()
    if not State.MultiJumpEnabled or not State.jumpInputActive then return end
    local hum = getHum()
    if not hum or hum.Health <= 0 then return end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return end
    local hrp = getHRP()
    if not hrp then return end
    local vel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, State.jumpVelocity, vel.Z)
end

local function startJumpHold()
    if not State.MultiJumpEnabled or jumpHolding then return end
    jumpHolding = true
    State.jumpInputActive = true
    if jumpHoldThread then task.cancel(jumpHoldThread); jumpHoldThread = nil end
    jumpHoldThread = task.spawn(function()
        while jumpHolding and State.jumpInputActive do
            doJump()
            task.wait(State.JumpHoldInterval)
        end
        jumpHolding = false
    end)
end

local function stopJumpHold()
    State.jumpInputActive = false
    jumpHolding = false
    if jumpHoldThread then task.cancel(jumpHoldThread); jumpHoldThread = nil end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not State.MultiJumpEnabled then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        startJumpHold()
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        stopJumpHold()
    end
end)

local function hookTouchJumpButton()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end
    local touchGui = playerGui:WaitForChild("TouchGui", 10)
    if not touchGui then return end
    local frame = touchGui:WaitForChild("TouchControlFrame", 10)
    if not frame then return end
    local jumpBtn = frame:WaitForChild("JumpButton", 10)
    if not jumpBtn then return end
    jumpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and State.MultiJumpEnabled then startJumpHold() end
    end)
    jumpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then stopJumpHold() end
    end)
    jumpBtn.MouseButton1Down:Connect(function()
        if State.MultiJumpEnabled then startJumpHold() end
    end)
    jumpBtn.MouseButton1Up:Connect(function() stopJumpHold() end)
end
task.spawn(hookTouchJumpButton)
LocalPlayer.CharacterAdded:Connect(function() task.wait(2); task.spawn(hookTouchJumpButton) end)

local function setMultiJump(v)
    State.MultiJumpEnabled = v
    if not v then stopJumpHold() end
end

-- ============================================================
-- 2. FLY
-- ============================================================
local function stopFly()
    if State.flyConn then State.flyConn:Disconnect(); State.flyConn = nil end
    if State.flyBV then State.flyBV:Destroy(); State.flyBV = nil end
    if State.flyBG then State.flyBG:Destroy(); State.flyBG = nil end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
    State.FlyEnabled = false; State.flyUp = false; State.flyDown = false
    if _G.OllieFlyUI then _G.OllieFlyUI.hide() end
end

local function startFly()
    local hrp = getHRP(); local hum = getHum()
    if not hrp or not hum then return end
    stopFly()
    State.FlyEnabled = true
    if _G.OllieFlyUI then _G.OllieFlyUI.show() end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero; bv.Parent = hrp
    State.flyBV = bv
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9000; bg.D = 500; bg.Parent = hrp
    State.flyBG = bg
    hum.PlatformStand = true
    State.flyConn = RunService.Heartbeat:Connect(function()
        if not State.FlyEnabled then return end
        local hrp2 = getHRP(); local hum2 = getHum()
        if not hrp2 or not hum2 or hum2.Health <= 0 then stopFly(); return end
        bg.CFrame = Camera.CFrame
        local dir = hum2.MoveDirection
        local vel = Vector3.zero
        if dir.Magnitude > 0 then vel = dir.Unit * State.FlySpeed end
        local vert = 0
        if State.flyUp or UserInputService:IsKeyDown(Enum.KeyCode.E) then vert = 1 end
        if State.flyDown or UserInputService:IsKeyDown(Enum.KeyCode.Q) then vert = -1 end
        vel = vel + Vector3.new(0, vert * State.FlySpeed, 0)
        bv.Velocity = vel
    end)
end
local function toggleFly(v) if v then startFly() else stopFly() end end

-- ============================================================
-- 3. SPEED
-- ============================================================
local function applySpeed()
    local hum = getHum()
    if not hum then return end
    hum.WalkSpeed = State.SpeedEnabled and State.WalkSpeed or State.defaultWalkSpeed
end

-- ============================================================
-- 4. ESP (optimized)
-- ============================================================
local function removeESP(p)
    local obj = State.espObjects[p]
    if not obj then return end
    if obj.highlight then obj.highlight:Destroy() end
    if obj.tracer then obj.tracer:Remove() end
    for _, l in ipairs(obj.boxLines or {}) do l:Remove() end
    for _, l in ipairs(obj.box3DLines or {}) do l:Remove() end
    if obj.billboard and obj.billboard.Parent then obj.billboard:Destroy() end
    if obj.healthBg and obj.healthBg.Parent and obj.healthBg.Parent:IsA("BillboardGui") then
        obj.healthBg.Parent:Destroy()
    end
    State.espObjects[p] = nil
end
local function clearAllESP()
    for p, _ in pairs(State.espObjects) do removeESP(p) end
    State.espObjects = {}
    State.rootCache = {}
end

local function createESP(p)
    if p == LocalPlayer or State.espObjects[p] or not State.EspEnabled then return end
    local obj = { highlight=nil, tracer=nil, boxLines={}, box3DLines={}, billboard=nil,
                  nameLabel=nil, distLabel=nil, healthBg=nil, healthFg=nil, cachedChar=nil }
    local char = p.Character

    if State.EspGlow and char then
        local hl = Instance.new("Highlight")
        hl.Name = "OllieESP"; hl.FillColor = State.EspColor; hl.OutlineColor = State.EspColor
        hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char; hl.Parent = char
        obj.highlight = hl
    end

    if (State.EspName or State.EspDistance) and char then
        local head = char:FindFirstChild("Head")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Name = "OllieESPName"; bb.Adornee = head
            bb.Size = UDim2.new(0, 220, 0, 60); bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true; bb.Parent = head
            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, 0, 0.5, 0); nl.Position = UDim2.new(0, 0, 0, 0)
            nl.BackgroundTransparency = 1; nl.Text = p.Name
            nl.TextColor3 = State.EspColor; nl.TextStrokeTransparency = 0
            nl.TextStrokeColor3 = Color3.new(0, 0, 0); nl.TextScaled = true
            nl.Font = Enum.Font.GothamBold; nl.Visible = State.EspName; nl.Parent = bb
            obj.nameLabel = nl
            local dl = Instance.new("TextLabel")
            dl.Size = UDim2.new(1, 0, 0.5, 0); dl.Position = UDim2.new(0, 0, 0.5, 0)
            dl.BackgroundTransparency = 1; dl.Text = ""
            dl.TextColor3 = State.EspColor; dl.TextStrokeTransparency = 0
            dl.TextStrokeColor3 = Color3.new(0, 0, 0); dl.TextScaled = true
            dl.Font = Enum.Font.Gotham; dl.Visible = State.EspDistance; dl.Parent = bb
            obj.distLabel = dl; obj.billboard = bb
        end
    end

    if State.EspHealth and char then
        local head = char:FindFirstChild("Head")
        if head then
            local hb = Instance.new("BillboardGui")
            hb.Name = "OllieESPHealth"; hb.Adornee = head
            hb.Size = UDim2.new(0, 50, 0, 6); hb.StudsOffset = Vector3.new(0, 3.2, 0)
            hb.AlwaysOnTop = true; hb.Parent = head
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(1, 0, 1, 0); bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            bg.BorderSizePixel = 1; bg.BorderColor3 = Color3.new(0,0,0); bg.Parent = hb
            local fg = Instance.new("Frame")
            fg.Size = UDim2.new(1, 0, 1, 0); fg.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            fg.BorderSizePixel = 0; fg.Parent = bg
            obj.healthBg = bg; obj.healthFg = fg
        end
    end

    if State.EspLine then
        local ok, line = pcall(function() return Drawing.new("Line") end)
        if ok and line then
            line.Color = State.EspColor; line.Thickness = 1.5; line.Visible = false
            obj.tracer = line
        end
    end
    if State.EspBox then
        for i = 1, 4 do
            local ok, l = pcall(function() return Drawing.new("Line") end)
            if ok and l then l.Color = State.EspColor; l.Thickness = 1; l.Visible = false
                table.insert(obj.boxLines, l) end
        end
    end
    if State.EspBox3D then
        for i = 1, 12 do
            local ok, l = pcall(function() return Drawing.new("Line") end)
            if ok and l then l.Color = State.EspColor; l.Thickness = 1; l.Visible = false
                table.insert(obj.box3DLines, l) end
        end
    end

    State.espObjects[p] = obj
end

local function rebuildAllESP()
    clearAllESP()
    if not State.EspEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then createESP(p) end
    end
end

local function drawBox3D(obj, hrp)
    if #obj.box3DLines ~= 12 then return end
    local half = Vector3.new(1.5, 3, 1.5)
    local cf = CFrame.new(hrp.Position)
    local offs = {
        Vector3.new(-half.X,-half.Y,-half.Z), Vector3.new(half.X,-half.Y,-half.Z),
        Vector3.new(half.X,half.Y,-half.Z), Vector3.new(-half.X,half.Y,-half.Z),
        Vector3.new(-half.X,-half.Y,half.Z), Vector3.new(half.X,-half.Y,half.Z),
        Vector3.new(half.X,half.Y,half.Z), Vector3.new(-half.X,half.Y,half.Z),
    }
    local corners = {}
    for i = 1, 8 do
        local sp, on = Camera:WorldToViewportPoint((cf + offs[i]).Position)
        corners[i] = {sp=sp, on=on}
    end
    local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for i, e in ipairs(edges) do
        local a, b = corners[e[1]], corners[e[2]]
        local l = obj.box3DLines[i]
        if a and b and a.on and b.on then
            l.From = Vector2.new(a.sp.X, a.sp.Y); l.To = Vector2.new(b.sp.X, b.sp.Y)
            l.Color = State.EspColor; l.Visible = true
        else l.Visible = false end
    end
end

local function updateESP()
    if not State.EspEnabled then return end

    -- throttle ke PERF.ESP_HZ
    local now = os.clock()
    if now - lastESPUpdate < (1 / PERF.ESP_HZ) then return end
    lastESPUpdate = now

    State.espScanTick = State.espScanTick + 1
    if State.espScanTick >= PERF.ESP_HZ * 2 then  -- scan player baru tiap 2s
        State.espScanTick = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not State.espObjects[p] then
                local hrp = getPlayerRoot(p)
                if hrp then createESP(p) end
            end
        end
    end

    box3DFrame = box3DFrame + 1
    local updateBox3D = (box3DFrame % PERF.BOX3D_EVERY == 0)

    local myHRP = getHRP()
    local myPos = myHRP and myHRP.Position or Vector3.zero

    for p, obj in pairs(State.espObjects) do
        local hrp, char = getPlayerRoot(p)
        if char and obj.cachedChar ~= char then
            obj.cachedChar = char
            if obj.highlight then obj.highlight.Adornee = char end
            local head = char:FindFirstChild("Head")
            if head and obj.billboard then obj.billboard.Adornee = head end
            if head and obj.healthBg and obj.healthBg.Parent and obj.healthBg.Parent:IsA("BillboardGui") then
                obj.healthBg.Parent.Adornee = head
            end
        end
        if not hrp then
            if obj.tracer then obj.tracer.Visible = false end
            for _, l in ipairs(obj.boxLines) do l.Visible = false end
            for _, l in ipairs(obj.box3DLines) do l.Visible = false end
            if obj.nameLabel then obj.nameLabel.TextTransparency = 1 end
            if obj.distLabel then obj.distLabel.TextTransparency = 1 end
            if obj.highlight then obj.highlight.Enabled = false end
            if obj.healthFg then obj.healthFg.Visible = false end
            continue
        end
        local dist = (hrp.Position - myPos).Magnitude
        local inRange = dist <= State.EspMaxDist

        if obj.highlight then
            obj.highlight.FillColor = State.EspColor; obj.highlight.OutlineColor = State.EspColor
            obj.highlight.Enabled = State.EspGlow and inRange
        end
        if obj.nameLabel then
            obj.nameLabel.Visible = State.EspName and inRange
            obj.nameLabel.TextColor3 = State.EspColor
        end
        if obj.distLabel then
            obj.distLabel.Visible = State.EspDistance and inRange
            obj.distLabel.TextColor3 = State.EspColor
            obj.distLabel.Text = string.format("[%d]", math.floor(dist))
        end
        if obj.healthFg then
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                obj.healthFg.Size = UDim2.new(ratio, 0, 1, 0)
                obj.healthFg.BackgroundColor3 = Color3.new(1 - ratio, ratio, 0)
                obj.healthFg.Visible = State.EspHealth and inRange
            end
        end
        if obj.tracer then
            local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and State.EspLine and inRange then
                obj.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, 0)
                obj.tracer.To = Vector2.new(sp.X, sp.Y)
                obj.tracer.Color = State.EspColor; obj.tracer.Visible = true
            else obj.tracer.Visible = false end
        end
        if #obj.boxLines == 4 then
            if State.EspBox and inRange then
                local topPos = hrp.Position + Vector3.new(0, 3, 0)
                local botPos = hrp.Position - Vector3.new(0, 3, 0)
                local ts, ton = Camera:WorldToViewportPoint(topPos)
                local bs, bon = Camera:WorldToViewportPoint(botPos)
                if ton and bon then
                    local h = math.abs(bs.Y - ts.Y); local w = h * 0.6
                    local cx = (ts.X + bs.X) / 2
                    local tl = Vector2.new(cx - w/2, ts.Y); local tr = Vector2.new(cx + w/2, ts.Y)
                    local bl = Vector2.new(cx - w/2, bs.Y); local br = Vector2.new(cx + w/2, bs.Y)
                    obj.boxLines[1].From = tl; obj.boxLines[1].To = tr
                    obj.boxLines[2].From = tr; obj.boxLines[2].To = br
                    obj.boxLines[3].From = br; obj.boxLines[3].To = bl
                    obj.boxLines[4].From = bl; obj.boxLines[4].To = tl
                    for _, l in ipairs(obj.boxLines) do l.Color = State.EspColor; l.Visible = true end
                else for _, l in ipairs(obj.boxLines) do l.Visible = false end end
            else for _, l in ipairs(obj.boxLines) do l.Visible = false end end
        end
        if #obj.box3DLines == 12 then
            if State.EspBox3D and inRange and updateBox3D then drawBox3D(obj, hrp)
            elseif not State.EspBox3D then for _, l in ipairs(obj.box3DLines) do l.Visible = false end end
        end
    end
end

local function setupPlayerESP(p)
    if p == LocalPlayer then return end
    if State.EspEnabled then createESP(p) end
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        State.rootCache[p] = nil
        removeESP(p)
        if State.EspEnabled then createESP(p) end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do setupPlayerESP(p) end
Players.PlayerAdded:Connect(setupPlayerESP)
Players.PlayerRemoving:Connect(function(p) removeESP(p); State.rootCache[p] = nil end)
RunService.Heartbeat:Connect(updateESP)  -- Heartbeat, bukan RenderStepped

-- ============================================================
-- 5A. NOCLIP
-- ============================================================
local function setNoclipParts(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if State.savedCollide[part] == nil then State.savedCollide[part] = part.CanCollide end
            part.CanCollide = false
        end
    end
end
local function startNoclip()
    local char = getChar()
    if char then setNoclipParts(char) end
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
-- 5B. WALLHACK GLOW
-- ============================================================
local function createWallhackGlow(p)
    if p == LocalPlayer then return end
    local char = p.Character
    if not char then return end
    local old = char:FindFirstChild("OllieWH")
    if old then old:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = "OllieWH"; hl.FillColor = State.WallhackColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char; hl.Parent = char
    State.wallhackObjects[p] = hl
end
local function removeWallhackGlow(p)
    local char = p.Character
    if char then
        local hl = char:FindFirstChild("OllieWH")
        if hl then hl:Destroy() end
    end
    State.wallhackObjects[p] = nil
end
local function applyAllWallhackGlow()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then createWallhackGlow(p) end
    end
end
local function clearAllWallhackGlow()
    for _, p in ipairs(Players:GetPlayers()) do removeWallhackGlow(p) end
    State.wallhackObjects = {}
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if State.WallhackGlowEnabled then createWallhackGlow(p) end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if State.WallhackGlowEnabled then createWallhackGlow(p) end
        end)
    end
end

-- ============================================================
-- 5C. SPINBOT
-- ============================================================
local function startSpinBot()
    if State.spinConn then State.spinConn:Disconnect() end
    State.SpinBotEnabled = true
    local angle = 0
    State.spinConn = RunService.Heartbeat:Connect(function(dt)
        if not State.SpinBotEnabled then return end
        local hrp = getHRP()
        if not hrp then return end
        angle = angle + math.rad(State.SpinBotSpeed) * (dt * 60)
        if angle > math.pi * 2 then angle = angle - math.pi * 2 end
        local pos = hrp.Position
        hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
    end)
end
local function stopSpinBot()
    State.SpinBotEnabled = false
    if State.spinConn then State.spinConn:Disconnect(); State.spinConn = nil end
end

-- ============================================================
-- 5D. GOD MODE
-- ============================================================
local function runGodModeTest()
    setGodSupportLabel("testing...")
    task.spawn(function()
        local hum = getHum()
        if not hum then setGodSupportLabel("no humanoid"); return end
        local origMax = hum.MaxHealth
        local origHealth = hum.Health
        local origStateEnabled = nil
        pcall(function() origStateEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Dead) end)

        local maxSetOk = pcall(function() hum.MaxHealth = math.huge end)
        task.wait(0.2)
        local maxHeld = (hum.MaxHealth == math.huge)

        local healthSetOk = pcall(function() hum.Health = math.huge end)
        task.wait(0.2)
        local healthHeld = (hum.Health == math.huge)

        local stateSetOk = pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
        task.wait(0.1)
        local stateHeld = false
        pcall(function() stateHeld = (hum:GetStateEnabled(Enum.HumanoidStateType.Dead) == false) end)

        if healthHeld then pcall(function() hum:TakeDamage(10) end) end
        task.wait(0.3)
        local healedBack = healthHeld and (hum.Health >= hum.MaxHealth - 1)

        pcall(function()
            hum.MaxHealth = origMax
            hum.Health = origHealth
        end)
        if origStateEnabled ~= nil then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, origStateEnabled) end)
        end

        local score = 0
        if maxSetOk and maxHeld then score = score + 1 end
        if healthSetOk and healthHeld then score = score + 1 end
        if stateSetOk and stateHeld then score = score + 1 end
        if healedBack then score = score + 1 end

        local txt
        if score >= 4 then txt = "SUPPORT PENUH (4/4)"
        elseif score == 3 then txt = "SUPPORT TINGGI (3/4)"
        elseif score == 2 then txt = "SUPPORT PARSIAL (2/4)"
        elseif score == 1 then txt = "SUPPORT RENDAH (1/4)"
        else txt = "TIDAK SUPPORT (0/4)" end
        setGodSupportLabel(txt)
        State.godTestDone = true
        State.godTestResult = score
        notify("ByVoid God Mode", txt)
    end)
end

local function applyGodMode(hum)
    if not hum then return end
    if State.savedHealth == nil then State.savedHealth = hum.Health end
    if State.savedMaxHealth == nil then State.savedMaxHealth = hum.MaxHealth end
    hum.MaxHealth = math.huge
    hum.Health = math.huge
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
end

local function startGodMode()
    State.GodModeEnabled = true
    local hum = getHum()
    applyGodMode(hum)
    if State.godConn then State.godConn:Disconnect() end
    State.godConn = RunService.Heartbeat:Connect(function()
        if not State.GodModeEnabled then return end
        local h = getHum()
        if not h then return end
        if h.Health < h.MaxHealth or h.MaxHealth < math.huge then
            h.MaxHealth = math.huge
            h.Health = math.huge
        end
    end)
    local char = getChar()
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h and not State.godHealthConn then
            State.godHealthConn = h.HealthChanged:Connect(function(newHealth)
                if not State.GodModeEnabled then return end
                if newHealth < h.MaxHealth then h.Health = h.MaxHealth end
            end)
        end
    end
    if not State.godTestDone then
        task.wait(1)
        if State.GodModeEnabled then runGodModeTest() end
    end
end

local function stopGodMode()
    State.GodModeEnabled = false
    if State.godConn then State.godConn:Disconnect(); State.godConn = nil end
    if State.godHealthConn then State.godHealthConn:Disconnect(); State.godHealthConn = nil end
    local hum = getHum()
    if hum then
        if State.savedMaxHealth then hum.MaxHealth = State.savedMaxHealth end
        if State.savedHealth then hum.Health = math.min(State.savedHealth, hum.MaxHealth) end
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
    end
    State.savedHealth = nil
    State.savedMaxHealth = nil
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.GodModeEnabled then
        State.savedHealth = nil
        State.savedMaxHealth = nil
        State.godHealthConn = nil
        startGodMode()
    end
end)

-- ============================================================
-- 5E. FULLBRIGHT (apply sekali + loop 5s)
-- ============================================================
local function saveLighting()
    State.fbSaved = {
        Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        ClockTime = Lighting.ClockTime, ExposureCompensation = Lighting.ExposureCompensation,
    }
end
local function applyFullbright()
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6
    Lighting.ClockTime = 12; Lighting.ExposureCompensation = 0.5
end
local function restoreLighting()
    if not State.fbSaved then return end
    for k, v in pairs(State.fbSaved) do pcall(function() Lighting[k] = v end) end
    State.fbSaved = nil
end
local function startFullbright()
    if not State.fbSaved then saveLighting() end
    State.FullbrightEnabled = true
    applyFullbright()
    if State.fbThread then pcall(function() task.cancel(State.fbThread) end); State.fbThread = nil end
    State.fbThread = task.spawn(function()
        while State.FullbrightEnabled do
            task.wait(PERF.FB_LOOP)
            if State.FullbrightEnabled then applyFullbright() end
        end
    end)
end
local function stopFullbright()
    State.FullbrightEnabled = false
    if State.fbThread then pcall(function() task.cancel(State.fbThread) end); State.fbThread = nil end
    restoreLighting()
end

-- ============================================================
-- 5F. POV
-- ============================================================
local function applyPov()
    if not Camera then return end
    Camera.FieldOfView = State.PovEnabled and State.PovValue or State.defaultFOV
end
Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
    if State.PovEnabled and Camera.FieldOfView ~= State.PovValue then
        Camera.FieldOfView = State.PovValue
    end
end)

-- ============================================================
-- 5G. LOW GRAPHICS (apply sekali + loop 5s)
-- ============================================================
local function saveLowGfx()
    State.lowGfxSaved = {
        TerrainDecoration = Workspace.Terrain.Decoration,
        TerrainWaterWaveSize = Workspace.Terrain.WaterWaveSize,
        TerrainWaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed,
        TerrainWaterReflectance = Workspace.Terrain.WaterReflectance,
        TerrainWaterTransparency = Workspace.Terrain.WaterTransparency,
        GlobalShadows = Lighting.GlobalShadows, LightingFogEnd = Lighting.FogEnd,
    }
end
local function applyLowGfx()
    pcall(function()
        Workspace.Terrain.Decoration = false
        Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0
        Workspace.Terrain.WaterReflectance = 0
        Workspace.Terrain.WaterTransparency = 1
    end)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6
end
local function restoreLowGfx()
    if not State.lowGfxSaved then return end
    pcall(function()
        Workspace.Terrain.Decoration = State.lowGfxSaved.TerrainDecoration
        Workspace.Terrain.WaterWaveSize = State.lowGfxSaved.TerrainWaterWaveSize
        Workspace.Terrain.WaterWaveSpeed = State.lowGfxSaved.TerrainWaterWaveSpeed
        Workspace.Terrain.WaterReflectance = State.lowGfxSaved.TerrainWaterReflectance
        Workspace.Terrain.WaterTransparency = State.lowGfxSaved.TerrainWaterTransparency
    end)
    Lighting.GlobalShadows = State.lowGfxSaved.GlobalShadows
    Lighting.FogEnd = State.lowGfxSaved.LightingFogEnd
    State.lowGfxSaved = nil
end
local function startLowGfx()
    if not State.lowGfxSaved then saveLowGfx() end
    State.LowGfxEnabled = true
    applyLowGfx()
    if State.lowGfxThread then pcall(function() task.cancel(State.lowGfxThread) end); State.lowGfxThread = nil end
    State.lowGfxThread = task.spawn(function()
        while State.LowGfxEnabled do
            task.wait(PERF.LOWGFX_LOOP)
            if State.LowGfxEnabled then applyLowGfx() end
        end
    end)
end
local function stopLowGfx()
    State.LowGfxEnabled = false
    if State.lowGfxThread then pcall(function() task.cancel(State.lowGfxThread) end); State.lowGfxThread = nil end
    restoreLowGfx()
end

-- ============================================================
-- 5H. AIMBOT (optimized)
-- ============================================================
local function getTargetPart(char)
    if not char then return nil end
    if State.AimbotTargetPart == "Head" then return char:FindFirstChild("Head")
    elseif State.AimbotTargetPart == "Badan" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    elseif State.AimbotTargetPart == "Kaki" then
        return char:FindFirstChild("LeftFoot") or char:FindFirstChild("RightFoot") or char:FindFirstChild("LeftLeg") or char:FindFirstChild("RightLeg")
    end
    return char:FindFirstChild("Head")
end

local function findBestTarget()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)

    if State.aimbotTarget and State.aimbotTarget.player then
        local p = State.aimbotTarget.player
        if p.Parent then
            local hrp, char = getPlayerRoot(p)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local part = char and getTargetPart(char)
            if part and hum and hum.Health > 0 then
                local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= State.AimbotFov then return { player = p, part = part } end
                end
            end
        end
        State.aimbotTarget = nil
    end

    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local hrp, char = getPlayerRoot(p)
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local part = char and getTargetPart(char)
            if part and hum and hum.Health > 0 then
                local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= State.AimbotFov and d < bestDist then
                        bestDist = d; best = { player = p, part = part }
                    end
                end
            end
        end
    end
    return best
end

local function destroyFovCircle()
    if State.fovCircle then pcall(function() State.fovCircle:Remove() end); State.fovCircle = nil end
end

local function createFovCircle()
    destroyFovCircle()
    local ok, circle = pcall(function() return Drawing.new("Circle") end)
    if ok and circle then
        circle.Thickness = 1.5; circle.NumSides = 64
        circle.Color = State.AimbotColor; circle.Filled = false
        circle.Transparency = 0.85; circle.Visible = false
        State.fovCircle = circle
    end
end

local function updateFovCircle()
    if not State.fovCircle then return end
    if State.AimbotEnabled and State.AimbotShowFov then
        State.fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        State.fovCircle.Radius = State.AimbotFov
        State.fovCircle.Color = State.AimbotColor
        State.fovCircle.Visible = true
    else State.fovCircle.Visible = false end
end

local function aimbotShouldLock()
    if not State.AimbotEnabled then return false end
    if State.AimbotMode == "Selalu Aktif" then return true end
    return State.aimbotShooting
end

local function aimbotRenderStep(dt)
    updateFovCircle()
    if not State.AimbotEnabled then return end

    if not aimbotShouldLock() then
        State.aimbotTarget = nil
        local h = getHum()
        if h and State.savedAutoRotate ~= nil then
            h.AutoRotate = State.savedAutoRotate; State.savedAutoRotate = nil
        end
        return
    end

    -- throttle target scan
    State.aimbotFrame = State.aimbotFrame + 1
    if not State.aimbotTarget or State.aimbotFrame >= PERF.AIMBOT_TARGET_EVERY then
        if State.aimbotFrame >= PERF.AIMBOT_TARGET_EVERY then
            State.aimbotFrame = 0
            State.aimbotTarget = findBestTarget()
        end
    end
    local target = State.aimbotTarget
    if not target or not target.part or not target.part.Parent then return end

    local h = getHum()
    if h then
        if State.AimbotFreeMove then
            if State.savedAutoRotate == nil then State.savedAutoRotate = h.AutoRotate end
            h.AutoRotate = false
        else
            if State.savedAutoRotate ~= nil then
                h.AutoRotate = State.savedAutoRotate; State.savedAutoRotate = nil
            end
        end
    end

    local camPos = Camera.CFrame.Position
    local targetPos = target.part.Position
    if State.AimbotPredict then
        targetPos = targetPos + target.part.AssemblyLinearVelocity * State.AimbotPredictAmount
    end
    local desired = CFrame.lookAt(camPos, targetPos)
    if State.AimbotSmooth <= 0.01 then
        Camera.CFrame = desired
    else
        local alpha = math.clamp(1 - State.AimbotSmooth, 0.01, 1)
        Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
    end
end

local function startAimbot()
    State.AimbotEnabled = true
    State.aimbotTarget = nil; State.aimbotFrame = 0
    createFovCircle()
    pcall(function() RunService:UnbindFromRenderStep(AIMBOT_BIND) end)
    RunService:BindToRenderStep(AIMBOT_BIND, Enum.RenderPriority.Camera.Value + 1, aimbotRenderStep)
end

local function stopAimbot()
    State.AimbotEnabled = false
    State.aimbotTarget = nil
    pcall(function() RunService:UnbindFromRenderStep(AIMBOT_BIND) end)
    destroyFovCircle()
    local h = getHum()
    if h and State.savedAutoRotate ~= nil then
        h.AutoRotate = State.savedAutoRotate; State.savedAutoRotate = nil
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local isShoot = false
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isShoot = true
    elseif input.UserInputType == Enum.UserInputType.Touch then
        local vp = Camera.ViewportSize
        if input.Position.X > vp.X * 0.5 then isShoot = true end
    end
    if isShoot then State.aimbotShooting = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        State.aimbotShooting = false
    end
end)

-- ============================================================
-- 6. TP
-- ============================================================
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end
local function teleportToPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then return end
    local tHRP = getPlayerRoot(target)
    local myHRP = getHRP()
    if not tHRP or not myHRP then return end
    myHRP.CFrame = tHRP.CFrame + Vector3.new(0, 3, 0)
end

-- ============================================================
-- FLY UI
-- ============================================================
local flyGui = Instance.new("ScreenGui")
flyGui.Name = "OllieFlyUI"; flyGui.ResetOnSpawn = false
flyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local upBtn = Instance.new("TextButton")
upBtn.Size = UDim2.new(0, 60, 0, 60); upBtn.Position = UDim2.new(0, 20, 1, -160)
upBtn.Text = "↑"; upBtn.TextSize = 32
upBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
upBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
upBtn.BackgroundTransparency = 0.3; upBtn.Visible = false; upBtn.Parent = flyGui

local downBtn = Instance.new("TextButton")
downBtn.Size = UDim2.new(0, 60, 0, 60); downBtn.Position = UDim2.new(0, 20, 1, -90)
downBtn.Text = "↓"; downBtn.TextSize = 32
downBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
downBtn.TextColor3 = Color3.fromRGB(0, 255, 100)
downBtn.BackgroundTransparency = 0.3; downBtn.Visible = false; downBtn.Parent = flyGui

upBtn.MouseButton1Down:Connect(function() State.flyUp = true end)
upBtn.MouseButton1Up:Connect(function() State.flyUp = false end)
upBtn.MouseLeave:Connect(function() State.flyUp = false end)
downBtn.MouseButton1Down:Connect(function() State.flyDown = true end)
downBtn.MouseButton1Up:Connect(function() State.flyDown = false end)
downBtn.MouseLeave:Connect(function() State.flyDown = false end)
_G.OllieFlyUI = {
    show = function() upBtn.Visible = true; downBtn.Visible = true end,
    hide = function() upBtn.Visible = false; downBtn.Visible = false end,
}

-- ============================================================
-- UI RAYFIELD
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "ByVoid",
    LoadingTitle = "ByVoid",
    LoadingSubtitle = "No system is safe",
    ConfigurationSaving = { Enabled = false },
    Keybind = Enum.KeyCode.RightShift,
})

-- MOVEMENT
local MoveTab = Window:CreateTab("Movement", 4483362458)
MoveTab:CreateSection("Multi Jump (Unlimited — Tahan)")
MoveTab:CreateToggle({ Name = "Enable Multi Jump", CurrentValue = false, Flag = "MultiJump",
    Callback = function(v) setMultiJump(v) end })
MoveTab:CreateSlider({ Name = "Jump Velocity", Range = {30, 200}, Increment = 5, Suffix = "vel",
    CurrentValue = 50, Flag = "JumpVel", Callback = function(v) State.jumpVelocity = v end })
MoveTab:CreateSlider({ Name = "Jump Spam Interval", Range = {0.03, 0.5}, Increment = 0.01, Suffix = "s",
    CurrentValue = 0.08, Flag = "JumpInterval", Callback = function(v) State.JumpHoldInterval = v end })
MoveTab:CreateSection("Fly")
MoveTab:CreateToggle({ Name = "Enable Fly", CurrentValue = false, Flag = "Fly",
    Callback = function(v) toggleFly(v) end })
MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10, 500}, Increment = 10, Suffix = "studs/s",
    CurrentValue = 100, Flag = "FlySpeed", Callback = function(v) State.FlySpeed = v end })
MoveTab:CreateSection("Speed")
MoveTab:CreateToggle({ Name = "Enable Speed", CurrentValue = false, Flag = "Speed",
    Callback = function(v) State.SpeedEnabled = v; applySpeed() end })
MoveTab:CreateSlider({ Name = "Walk Speed", Range = {16, 300}, Increment = 1, Suffix = "studs/s",
    CurrentValue = 50, Flag = "WalkSpeed",
    Callback = function(v) State.WalkSpeed = v; applySpeed() end })

-- AIMBOT
local AimTab = Window:CreateTab("Aimbot", 4483362458)
AimTab:CreateSection("Aimbot Brutal Lock")
AimTab:CreateToggle({ Name = "Enable Aimbot", CurrentValue = false, Flag = "Aimbot",
    Callback = function(v) if v then startAimbot() else stopAimbot() end end })
AimTab:CreateDropdown({
    Name = "Target Part", Options = {"Head", "Badan", "Kaki"},
    CurrentOption = {"Head"}, MultipleOptions = false, Flag = "AimPart",
    Callback = function(opt) if opt and opt[1] then State.AimbotTargetPart = opt[1] end end,
})
AimTab:CreateDropdown({
    Name = "Mode Aktif", Options = {"Selalu Aktif", "Cuma Pas Nembak"},
    CurrentOption = {"Cuma Pas Nembak"}, MultipleOptions = false, Flag = "AimMode",
    Callback = function(opt) if opt and opt[1] then State.AimbotMode = opt[1] end end,
})
AimTab:CreateSlider({ Name = "FOV Radius (pixel)", Range = {20, 600}, Increment = 5, Suffix = "px",
    CurrentValue = 150, Flag = "AimFov",
    Callback = function(v) State.AimbotFov = v end })
AimTab:CreateSlider({ Name = "Smoothness (0 = snap)", Range = {0, 0.95}, Increment = 0.05,
    CurrentValue = 0, Flag = "AimSmooth",
    Callback = function(v) State.AimbotSmooth = v end })
AimTab:CreateToggle({ Name = "Prediction", CurrentValue = true, Flag = "AimPredict",
    Callback = function(v) State.AimbotPredict = v end })
AimTab:CreateSlider({ Name = "Prediction Amount", Range = {0, 0.5}, Increment = 0.02, Suffix = "s",
    CurrentValue = 0.12, Flag = "AimPredictAmt",
    Callback = function(v) State.AimbotPredictAmount = v end })
AimTab:CreateToggle({ Name = "Free Move", CurrentValue = false, Flag = "AimFree",
    Callback = function(v)
        State.AimbotFreeMove = v
        if not v then
            local h = getHum()
            if h and State.savedAutoRotate ~= nil then
                h.AutoRotate = State.savedAutoRotate; State.savedAutoRotate = nil
            end
        end
    end })
AimTab:CreateToggle({ Name = "Show FOV Circle", CurrentValue = true, Flag = "AimFovShow",
    Callback = function(v) State.AimbotShowFov = v end })
AimTab:CreateColorPicker({ Name = "FOV Circle Color", Color = Color3.fromRGB(255, 50, 50), Flag = "AimColor",
    Callback = function(color) State.AimbotColor = color end })
AimTab:CreateParagraph({ Title = "Info Optimized",
    Content = "Target di-scan tiap 3 frame (bukan tiap frame). Mode default 'Cuma Pas Nembak' biar ringan. FOV circle tetap update tiap frame buat visual." })

-- FUN
local FunTab = Window:CreateTab("Fun", 4483362458)
FunTab:CreateSection("God Mode")
FunTab:CreateToggle({ Name = "Enable God Mode", CurrentValue = false, Flag = "God",
    Callback = function(v) if v then startGodMode() else stopGodMode() end end })
GodSupportLabel = FunTab:CreateLabel("Map Support: belum dites")
FunTab:CreateButton({ Name = "Test Map Support", Callback = function()
    if not State.GodModeEnabled then notify("ByVoid", "aktifkan God Mode dulu"); return end
    State.godTestDone = false
    runGodModeTest()
end })
FunTab:CreateSection("Spinbot")
FunTab:CreateToggle({ Name = "Enable Spinbot", CurrentValue = false, Flag = "Spin",
    Callback = function(v) if v then startSpinBot() else stopSpinBot() end end })
FunTab:CreateSlider({ Name = "Spin Speed", Range = {1, 100}, Increment = 1, Suffix = "deg",
    CurrentValue = 20, Flag = "SpinSpeed", Callback = function(v) State.SpinBotSpeed = v end })

-- VISUAL
local VisualTab = Window:CreateTab("Visual", 4483362458)
VisualTab:CreateSection("POV / FOV Kamera")
VisualTab:CreateToggle({ Name = "Enable POV Changer", CurrentValue = false, Flag = "Pov",
    Callback = function(v) State.PovEnabled = v; applyPov() end })
VisualTab:CreateSlider({ Name = "FOV Value", Range = {10, 120}, Increment = 1, Suffix = "°",
    CurrentValue = 70, Flag = "PovVal",
    Callback = function(v) State.PovValue = v; applyPov() end })

VisualTab:CreateSection("ESP (Default OFF — Optimized)")
VisualTab:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "ESP",
    Callback = function(v)
        State.EspEnabled = v
        if v then
            if not (State.EspGlow or State.EspLine or State.EspBox or State.EspName or State.EspBox3D or State.EspHealth or State.EspDistance) then
                notify("ByVoid", "pilih minimal 1 sub-ESP")
            end
            rebuildAllESP()
        else clearAllESP() end
    end })
VisualTab:CreateToggle({ Name = "ESP Glow", CurrentValue = false, Flag = "ESPGlow",
    Callback = function(v) State.EspGlow = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Line", CurrentValue = false, Flag = "ESPLine",
    Callback = function(v) State.EspLine = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Box 2D", CurrentValue = false, Flag = "ESPBox",
    Callback = function(v) State.EspBox = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Box 3D (berat)", CurrentValue = false, Flag = "ESPBox3D",
    Callback = function(v) State.EspBox3D = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Nama", CurrentValue = false, Flag = "ESPName",
    Callback = function(v) State.EspName = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Distance", CurrentValue = false, Flag = "ESPDistance",
    Callback = function(v) State.EspDistance = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Health Bar", CurrentValue = false, Flag = "ESPHealth",
    Callback = function(v) State.EspHealth = v; if State.EspEnabled then rebuildAllESP() end end })
VisualTab:CreateToggle({ Name = "ESP Fallback Scan (berat)", CurrentValue = false, Flag = "ESPScan",
    Callback = function(v) State.EspFallbackScan = v; State.rootCache = {} end })
VisualTab:CreateSlider({ Name = "ESP Max Distance", Range = {50, 3000}, Increment = 50, Suffix = "studs",
    CurrentValue = 500, Flag = "ESPDist", Callback = function(v) State.EspMaxDist = v end })
VisualTab:CreateColorPicker({ Name = "ESP Color", Color = Color3.fromRGB(0, 255, 100), Flag = "ESPColor",
    Callback = function(color)
        State.EspColor = color
        for _, obj in pairs(State.espObjects) do
            if obj.highlight then obj.highlight.FillColor = color; obj.highlight.OutlineColor = color end
            if obj.tracer then obj.tracer.Color = color end
            for _, l in ipairs(obj.boxLines) do l.Color = color end
            for _, l in ipairs(obj.box3DLines) do l.Color = color end
            if obj.nameLabel then obj.nameLabel.TextColor3 = color end
            if obj.distLabel then obj.distLabel.TextColor3 = color end
        end
    end })

VisualTab:CreateSection("Fullbright & Low Graphics")
VisualTab:CreateToggle({ Name = "Enable Fullbright", CurrentValue = false, Flag = "Fullbright",
    Callback = function(v) if v then startFullbright() else stopFullbright() end end })
VisualTab:CreateToggle({ Name = "Enable Low Graphics", CurrentValue = false, Flag = "LowGfx",
    Callback = function(v) if v then startLowGfx() else stopLowGfx() end end })

VisualTab:CreateSection("Wallhack")
VisualTab:CreateToggle({ Name = "Wallhack Noclip", CurrentValue = false, Flag = "Noclip",
    Callback = function(v) State.NoclipEnabled = v; if v then startNoclip() else stopNoclip() end end })
VisualTab:CreateToggle({ Name = "Wallhack Glow", CurrentValue = false, Flag = "WHGlow",
    Callback = function(v) State.WallhackGlowEnabled = v
        if v then applyAllWallhackGlow() else clearAllWallhackGlow() end end })
VisualTab:CreateColorPicker({ Name = "Wallhack Glow Color", Color = Color3.fromRGB(255, 60, 60), Flag = "WHColor",
    Callback = function(color)
        State.WallhackColor = color
        for _, hl in pairs(State.wallhackObjects) do
            if hl and hl.Parent then hl.FillColor = color end
        end
    end })

-- TELEPORT
local TpTab = Window:CreateTab("Teleport", 4483362458)
local playerDropdown
local function refreshList()
    if playerDropdown then playerDropdown:Refresh(getPlayerNames()) end
end
playerDropdown = TpTab:CreateDropdown({
    Name = "Pilih Player", Options = getPlayerNames(), CurrentOption = {},
    MultipleOptions = false, Flag = "PlayerSelect",
    Callback = function(opt) if opt and opt[1] then State.SelectedPlayer = opt[1] end end,
})
TpTab:CreateButton({ Name = "Refresh List", Callback = refreshList })
TpTab:CreateButton({ Name = "Teleport ke Player", Callback = function()
    if not State.SelectedPlayer then notify("ByVoid", "pilih player dulu"); return end
    teleportToPlayer(State.SelectedPlayer)
end })
Players.PlayerAdded:Connect(function() task.wait(0.5); refreshList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshList() end)

-- ============================================================
-- RESPAWN CLEANUP
-- ============================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    stopFly()
    stopJumpHold()
    stopSpinBot()
    applySpeed()
    State.savedCollide = {}
    State.savedAutoRotate = nil
    State.rootCache = {}
    if State.NoclipEnabled then startNoclip() end
end)

notify("ByVoid", "No system is safe — optimized v4.7 loaded")
