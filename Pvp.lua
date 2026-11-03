--[[
    ByVoid — No system is safe
    v5.1 UNIVERSAL BYPASS FRAMEWORK
      A. Client-side anti-detect (protect_gui, randomize nama, hide Drawing)
      B. Speed/Jump loop re-apply tiap frame
      C. Auto-recon remote generic (scan nama, coba FireServer)
      D. Map support tag buat speed + jump (kayak god mode)
    semua fitur lama UTUH:
      jump tahan, fly HP, speed, ESP brutal optimized, noclip,
      wallhack glow, spinbot, god mode, fullbright, low graphics, POV,
      aimbot FOV ring, tp
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local PERF = {
    ESP_HZ = 30, ROOT_CACHE_TTL = 5,
    BOX3D_EVERY = 2, FB_LOOP = 5, LOWGFX_LOOP = 5,
    BYPASS_LOOP_HZ = 60,   -- loop re-apply speed/jump 60 FPS
    RECON_TTL = 30,        -- recon remote ulang tiap 30 detik
}

-- random tag biar nama instance nggak keliatan pola
local TAG = tostring(math.random(100000, 999999))
local function rndName(base) return base .. "_" .. TAG end

local State = {
    MultiJumpEnabled = false, jumpVelocity = 50, JumpHoldInterval = 0.08, jumpInputActive = false,
    FlyEnabled = false, FlySpeed = 100, flyConn = nil, flyBV = nil, flyBG = nil, flyUp = false, flyDown = false,
    SpeedEnabled = false, WalkSpeed = 50, defaultWalkSpeed = 16,
    EspEnabled = false, EspGlow = false, EspLine = false, EspBox = false,
    EspName = false, EspHealth = false, EspDistance = false, EspBox3D = false,
    EspFallbackScan = false, EspColor = Color3.fromRGB(0, 255, 100), EspMaxDist = 500,
    espObjects = {}, espScanTick = 0, rootCache = {},
    NoclipEnabled = false, WallhackGlowEnabled = false,
    WallhackColor = Color3.fromRGB(255, 60, 60),
    wallhackObjects = {}, savedCollide = {}, noclipConn = nil,
    SpinBotEnabled = false, SpinBotSpeed = 20, spinConn = nil,
    GodModeEnabled = false, godConn = nil, godHealthConn = nil,
    savedHealth = nil, savedMaxHealth = nil,
    godSupportStatus = "belum dites", godTestDone = false,
    FullbrightEnabled = false, fbThread = nil, fbSaved = nil,
    PovEnabled = false, PovValue = 70, defaultFOV = 70,
    LowGfxEnabled = false, lowGfxThread = nil, lowGfxSaved = nil,
    -- AIMBOT (FOV ring)
    AimbotEnabled = false,
    AimbotTargetPart = "Head",
    AimbotFov = 40,
    AimbotMaxTransparency = 0.1,
    AimbotRingColor = Color3.fromRGB(128, 0, 128),
    AimbotBind = "ByVoidAimbotRender_" .. TAG,
    fovRing = nil,
    -- BYPASS FRAMEWORK
    SpeedBypassEnabled = false,
    SpeedBypassValue = 50,
    JumpBypassEnabled = false,
    JumpBypassVelocity = 50,
    speedJumpConn = nil,
    speedSupport = "belum dites",
    jumpSupport = "belum dites",
    speedTestDone = false, jumpTestDone = false,
    -- remote recon
    RemoteReconEnabled = false,
    reconThread = nil, reconLast = 0,
    remoteCandidates = {}, -- {remote, kind}
    reconSupport = "belum dites",
    -- anti-detect
    AntiDetectEnabled = false,
    savedGuiNames = {},
    -- misc
    SelectedPlayer = nil,
}

local GodSupportLabel = nil
local SpeedSupportLabel = nil
local JumpSupportLabel = nil
local ReconSupportLabel = nil
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
    local char = p.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then State.rootCache[p] = { hrp = hrp, char = char, t = now }; return hrp, char end
    end
    if State.EspFallbackScan then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Humanoid") and d.Parent and d.Parent.Name == p.Name then
                local hrp = d.Parent:FindFirstChild("HumanoidRootPart")
                if hrp then State.rootCache[p] = { hrp = hrp, char = d.Parent, t = now }; return hrp, d.Parent end
            end
        end
    end
    State.rootCache[p] = { hrp = nil, char = nil, t = now }
    return nil, nil
end

local function setLabel(lbl, txt)
    if lbl then lbl:Set(txt) end
end

-- ============================================================
-- A. CLIENT-SIDE ANTI-DETECT
-- ============================================================
local function startAntiDetect()
    State.AntiDetectEnabled = true
    -- 1. protect_gui kalau executor support
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(Rayfield) end
        if protect_gui then protect_gui(Rayfield) end
    end)
    -- 2. randomize nama ScreenGui / Drawing user-created
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Name:match("^Ollie") then
                    State.savedGuiNames[g] = g.Name
                    g.Name = rndName("Scr")
                end
            end
        end
    end)
    -- 3. hide Drawing object dari getgc (kalau executor support setrenderproperty / gethui)
    pcall(function()
        if gethui then
            -- pindahin drawing ke gethui biar nggak kebaca workspace
            -- (Drawing object nggak punya Parent, cuma referensi internal)
        end
    end)
    notify("ByVoid", "anti-detect aktif — GUI + nama di-randomize")
end

local function stopAntiDetect()
    State.AntiDetectEnabled = false
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for g, orig in pairs(State.savedGuiNames) do
                if g and g.Parent then g.Name = orig end
            end
        end
    end)
    State.savedGuiNames = {}
end

-- ============================================================
-- B. SPEED / JUMP LOOP RE-APPLY
-- ============================================================
local function speedJumpLoop()
    if State.speedJumpConn then State.speedJumpConn:Disconnect() end
    State.speedJumpConn = RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end

        -- SPEED: paksa WalkSpeed tiap frame
        if State.SpeedBypassEnabled then
            local target = State.SpeedBypassValue
            if hum.WalkSpeed ~= target then
                hum.WalkSpeed = target
            end
        end

        -- JUMP: paksa JumpPower tinggi biar loncat tinggi
        if State.JumpBypassEnabled then
            if hum.JumpPower and hum.JumpPower < State.JumpBypassVelocity then
                hum.JumpPower = State.JumpBypassVelocity
            end
            if hum.UseJumpPower == false then
                pcall(function() hum.UseJumpPower = true end)
            end
        end
    end)
end

local function stopSpeedJumpLoop()
    if State.speedJumpConn then State.speedJumpConn:Disconnect(); State.speedJumpConn = nil end
end

-- ============================================================
-- D. MAP SUPPORT TAG — SPEED & JUMP
-- ============================================================
local function runSpeedTest()
    task.spawn(function()
        local hum = getHum()
        if not hum then setLabel(SpeedSupportLabel, "Speed Support: no humanoid"); return end
        local origWS = hum.WalkSpeed
        local origBypass = State.SpeedBypassEnabled
        State.SpeedBypassEnabled = true
        State.SpeedBypassValue = 100
        task.wait(1.2)
        local after = hum.WalkSpeed
        local held = math.abs(after - 100) < 2
        -- restore
        State.SpeedBypassEnabled = origBypass
        State.SpeedBypassValue = 50
        pcall(function() hum.WalkSpeed = origWS end)

        local txt
        if held then txt = "SUPPORT PENUH — speed nempel"
        else
            local diff = math.abs(after - 100)
            if diff < 20 then txt = "SUPPORT PARSIAL — speed goyang dikit"
            else txt = "TIDAK SUPPORT — server reset speed" end
        end
        State.speedSupport = txt; State.speedTestDone = true
        setLabel(SpeedSupportLabel, "Speed Support: " .. txt)
    end)
end

local function runJumpTest()
    task.spawn(function()
        local hum = getHum()
        if not hum then setLabel(JumpSupportLabel, "Jump Support: no humanoid"); return end
        local origJP = hum.JumpPower or 50
        local origBypass = State.JumpBypassEnabled
        State.JumpBypassEnabled = true
        State.JumpBypassVelocity = 100
        task.wait(1.2)
        local after = hum.JumpPower or 0
        local held = math.abs(after - 100) < 5
        State.JumpBypassEnabled = origBypass
        State.JumpBypassVelocity = 50
        pcall(function() hum.JumpPower = origJP end)

        local txt
        if held then txt = "SUPPORT PENUH — jump power nempel"
        else
            local diff = math.abs(after - 100)
            if diff < 20 then txt = "SUPPORT PARSIAL — jump goyang"
            else txt = "TIDAK SUPPORT — server reset jump" end
        end
        State.jumpSupport = txt; State.jumpTestDone = true
        setLabel(JumpSupportLabel, "Jump Support: " .. txt)
    end)
end

-- ============================================================
-- C. AUTO-RECON REMOTE GENERIC
-- ============================================================
local function scanRemotes()
    local found = {}
    local function walk(root, depth)
        if depth > 5 then return end
        for _, obj in ipairs(root:GetChildren()) do
            pcall(function()
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local name = obj.Name:lower()
                    -- filter nama yang nyebut speed/move/jump/walk
                    if name:match("speed") or name:match("move") or
                       name:match("jump") or name:match("walk") or
                       name:match("char") then
                        table.insert(found, { remote = obj, name = obj.Name })
                    end
                end
                walk(obj, depth + 1)
            end)
        end
    end
    walk(ReplicatedStorage, 0)
    walk(Workspace, 0)
    return found
end

local function tryFireRemote(remote, kind)
    -- coba argumen generic, pcall biar nggak error kalau reject
    local argsList = {
        { 100 },                -- angka doang
        { "Speed", 100 },       -- string + angka
        { LocalPlayer, 100 },   -- player + angka
        { 100, 100, 100 },      -- tiga angka
        { { speed = 100 } },    -- table
    }
    local ok = false
    for _, args in ipairs(argsList) do
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(args))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(args))
            end
            ok = true
        end)
        if ok then break end
    end
    return ok
end

local function startRemoteRecon()
    State.RemoteReconEnabled = true
    if State.reconThread then pcall(function() task.cancel(State.reconThread) end); State.reconThread = nil end
    State.reconThread = task.spawn(function()
        while State.RemoteReconEnabled do
            local now = os.clock()
            if now - State.reconLast >= PERF.RECON_TTL then
                State.reconLast = now
                local found = scanRemotes()
                State.remoteCandidates = found
                local txt
                if #found == 0 then
                    txt = "TIDAK ADA REMOTE COCOK — kemungkinan server-authoritative"
                else
                    txt = string.format("NEMU %d REMOTE — coba FireServer generic", #found)
                    -- coba fire tiap kandidat
                    local fired = 0
                    for _, c in ipairs(found) do
                        if tryFireRemote(c.remote, c.name) then fired = fired + 1 end
                    end
                    txt = txt .. string.format(" (%d kepanggil)", fired)
                end
                State.reconSupport = txt
                setLabel(ReconSupportLabel, "Remote Recon: " .. txt)
            end
            task.wait(2)
        end
    end)
end

local function stopRemoteRecon()
    State.RemoteReconEnabled = false
    if State.reconThread then pcall(function() task.cancel(State.reconThread) end); State.reconThread = nil end
end

-- ============================================================
-- MULTI JUMP (TETAP, TAPI LOOP)
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
    jumpHolding = true; State.jumpInputActive = true
    if jumpHoldThread then task.cancel(jumpHoldThread); jumpHoldThread = nil end
    jumpHoldThread = task.spawn(function()
        while jumpHolding and State.jumpInputActive do
            doJump(); task.wait(State.JumpHoldInterval)
        end
        jumpHolding = false
    end)
end
local function stopJumpHold()
    State.jumpInputActive = false; jumpHolding = false
    if jumpHoldThread then task.cancel(jumpHoldThread); jumpHoldThread = nil end
end
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not State.MultiJumpEnabled then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then startJumpHold() end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then stopJumpHold() end
end)
local function hookTouchJumpButton()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10); if not playerGui then return end
    local touchGui = playerGui:WaitForChild("TouchGui", 10); if not touchGui then return end
    local frame = touchGui:WaitForChild("TouchControlFrame", 10); if not frame then return end
    local jumpBtn = frame:WaitForChild("JumpButton", 10); if not jumpBtn then return end
    jumpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and State.MultiJumpEnabled then startJumpHold() end
    end)
    jumpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then stopJumpHold() end
    end)
    jumpBtn.MouseButton1Down:Connect(function() if State.MultiJumpEnabled then startJumpHold() end end)
    jumpBtn.MouseButton1Up:Connect(function() stopJumpHold() end)
end
task.spawn(hookTouchJumpButton)
LocalPlayer.CharacterAdded:Connect(function() task.wait(2); task.spawn(hookTouchJumpButton) end)
local function setMultiJump(v) State.MultiJumpEnabled = v; if not v then stopJumpHold() end end

-- ============================================================
-- FLY
-- ============================================================
local function stopFly()
    if State.flyConn then State.flyConn:Disconnect(); State.flyConn = nil end
    if State.flyBV then State.flyBV:Destroy(); State.flyBV = nil end
    if State.flyBG then State.flyBG:Destroy(); State.flyBG = nil end
    local hum = getHum(); if hum then hum.PlatformStand = false end
    State.FlyEnabled = false; State.flyUp = false; State.flyDown = false
    if _G.OllieFlyUI then _G.OllieFlyUI.hide() end
end
local function startFly()
    local hrp = getHRP(); local hum = getHum()
    if not hrp or not hum then return end
    stopFly(); State.FlyEnabled = true
    if _G.OllieFlyUI then _G.OllieFlyUI.show() end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.zero; bv.Parent = hrp
    State.flyBV = bv
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); bg.P = 9000; bg.D = 500; bg.Parent = hrp
    State.flyBG = bg; hum.PlatformStand = true
    State.flyConn = RunService.Heartbeat:Connect(function()
        if not State.FlyEnabled then return end
        local hrp2 = getHRP(); local hum2 = getHum()
        if not hrp2 or not hum2 or hum2.Health <= 0 then stopFly(); return end
        bg.CFrame = Camera.CFrame
        local dir = hum2.MoveDirection; local vel = Vector3.zero
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
-- SPEED biasa (toggle lama)
-- ============================================================
local function applySpeed()
    local hum = getHum(); if not hum then return end
    hum.WalkSpeed = State.SpeedEnabled and State.WalkSpeed or State.defaultWalkSpeed
end

-- ============================================================
-- ESP (optimized)
-- ============================================================
local function removeESP(p)
    local obj = State.espObjects[p]; if not obj then return end
    if obj.highlight then obj.highlight:Destroy() end
    if obj.tracer then obj.tracer:Remove() end
    for _, l in ipairs(obj.boxLines or {}) do l:Remove() end
    for _, l in ipairs(obj.box3DLines or {}) do l:Remove() end
    if obj.billboard and obj.billboard.Parent then obj.billboard:Destroy() end
    if obj.healthBg and obj.healthBg.Parent and obj.healthBg.Parent:IsA("BillboardGui") then obj.healthBg.Parent:Destroy() end
    State.espObjects[p] = nil
end
local function clearAllESP()
    for p, _ in pairs(State.espObjects) do removeESP(p) end
    State.espObjects = {}; State.rootCache = {}
end
local function createESP(p)
    if p == LocalPlayer or State.espObjects[p] or not State.EspEnabled then return end
    local obj = { highlight=nil, tracer=nil, boxLines={}, box3DLines={}, billboard=nil,
                  nameLabel=nil, distLabel=nil, healthBg=nil, healthFg=nil, cachedChar=nil }
    local char = p.Character
    if State.EspGlow and char then
        local hl = Instance.new("Highlight")
        hl.Name = rndName("ESP"); hl.FillColor = State.EspColor; hl.OutlineColor = State.EspColor
        hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char; hl.Parent = char; obj.highlight = hl
    end
    if (State.EspName or State.EspDistance) and char then
        local head = char:FindFirstChild("Head")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Name = rndName("N"); bb.Adornee = head
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
            hb.Name = rndName("HP"); hb.Adornee = head
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
        if ok and line then line.Color = State.EspColor; line.Thickness = 1.5; line.Visible = false; obj.tracer = line end
    end
    if State.EspBox then
        for i = 1, 4 do
            local ok, l = pcall(function() return Drawing.new("Line") end)
            if ok and l then l.Color = State.EspColor; l.Thickness = 1; l.Visible = false; table.insert(obj.boxLines, l) end
        end
    end
    if State.EspBox3D then
        for i = 1, 12 do
            local ok, l = pcall(function() return Drawing.new("Line") end)
            if ok and l then l.Color = State.EspColor; l.Thickness = 1; l.Visible = false; table.insert(obj.box3DLines, l) end
        end
    end
    State.espObjects[p] = obj
end
local function rebuildAllESP()
    clearAllESP(); if not State.EspEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end
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
    local now = os.clock()
    if now - lastESPUpdate < (1 / PERF.ESP_HZ) then return end
    lastESPUpdate = now
    State.espScanTick = State.espScanTick + 1
    if State.espScanTick >= PERF.ESP_HZ * 2 then
        State.espScanTick = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and not State.espObjects[p] then
                local hrp = getPlayerRoot(p); if hrp then createESP(p) end
            end
        end
    end
    box3DFrame = box3DFrame + 1
    local updateBox3D = (box3DFrame % PERF.BOX3D_EVERY == 0)
    local myHRP = getHRP(); local myPos = myHRP and myHRP.Position or Vector3.zero
    for p, obj in pairs(State.espObjects) do
        local hrp, char = getPlayerRoot(p)
        if char and obj.cachedChar ~= char then
            obj.cachedChar = char
            if obj.highlight then obj.highlight.Adornee = char end
            local head = char:FindFirstChild("Head")
            if head and obj.billboard then obj.billboard.Adornee = head end
            if head and obj.healthBg and obj.healthBg.Parent and obj.healthBg.Parent:IsA("BillboardGui") then obj.healthBg.Parent.Adornee = head end
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
        task.wait(0.5); State.rootCache[p] = nil; removeESP(p)
        if State.EspEnabled then createESP(p) end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do setupPlayerESP(p) end
Players.PlayerAdded:Connect(setupPlayerESP)
Players.PlayerRemoving:Connect(function(p) removeESP(p); State.rootCache[p] = nil end)
RunService.Heartbeat:Connect(updateESP)

-- ============================================================
-- NOCLIP / WALLHACK / SPINBOT
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
    local char = getChar(); if char then setNoclipParts(char) end
    if State.noclipConn then State.noclipConn:Disconnect() end
    State.noclipConn = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local c = getChar(); if not c then return end
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
    for part, orig in pairs(State.savedCollide) do if part and part.Parent then part.CanCollide = orig end end
    State.savedCollide = {}
end
local function createWallhackGlow(p)
    if p == LocalPlayer then return end
    local char = p.Character; if not char then return end
    local old = char:FindFirstChild(rndName("WH")); if old then old:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = rndName("WH"); hl.FillColor = State.WallhackColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char; hl.Parent = char
    State.wallhackObjects[p] = hl
end
local function removeWallhackGlow(p)
    local char = p.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Highlight") and c.Name:match("^WH_") then c:Destroy() end
        end
    end
    State.wallhackObjects[p] = nil
end
local function applyAllWallhackGlow()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createWallhackGlow(p) end end
end
local function clearAllWallhackGlow()
    for _, p in ipairs(Players:GetPlayers()) do removeWallhackGlow(p) end
    State.wallhackObjects = {}
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5); if State.WallhackGlowEnabled then createWallhackGlow(p) end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            task.wait(0.5); if State.WallhackGlowEnabled then createWallhackGlow(p) end
        end)
    end
end
local function startSpinBot()
    if State.spinConn then State.spinConn:Disconnect() end
    State.SpinBotEnabled = true; local angle = 0
    State.spinConn = RunService.Heartbeat:Connect(function(dt)
        if not State.SpinBotEnabled then return end
        local hrp = getHRP(); if not hrp then return end
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
-- GOD MODE
-- ============================================================
local function runGodModeTest()
    setLabel(GodSupportLabel, "God Mode: testing...")
    task.spawn(function()
        local hum = getHum(); if not hum then setLabel(GodSupportLabel, "God Mode: no humanoid"); return end
        local origMax = hum.MaxHealth; local origHealth = hum.Health
        local origStateEnabled = nil
        pcall(function() origStateEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Dead) end)
        local maxSetOk = pcall(function() hum.MaxHealth = math.huge end); task.wait(0.2)
        local maxHeld = (hum.MaxHealth == math.huge)
        local healthSetOk = pcall(function() hum.Health = math.huge end); task.wait(0.2)
        local healthHeld = (hum.Health == math.huge)
        local stateSetOk = pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end); task.wait(0.1)
        local stateHeld = false
        pcall(function() stateHeld = (hum:GetStateEnabled(Enum.HumanoidStateType.Dead) == false) end)
        if healthHeld then pcall(function() hum:TakeDamage(10) end) end; task.wait(0.3)
        local healedBack = healthHeld and (hum.Health >= hum.MaxHealth - 1)
        pcall(function() hum.MaxHealth = origMax; hum.Health = origHealth end)
        if origStateEnabled ~= nil then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, origStateEnabled) end) end
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
        setLabel(GodSupportLabel, "God Mode: " .. txt); State.godTestDone = true
    end)
end
local function applyGodMode(hum)
    if not hum then return end
    if State.savedHealth == nil then State.savedHealth = hum.Health end
    if State.savedMaxHealth == nil then State.savedMaxHealth = hum.MaxHealth end
    hum.MaxHealth = math.huge; hum.Health = math.huge
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
end
local function startGodMode()
    State.GodModeEnabled = true
    local hum = getHum(); applyGodMode(hum)
    if State.godConn then State.godConn:Disconnect() end
    State.godConn = RunService.Heartbeat:Connect(function()
        if not State.GodModeEnabled then return end
        local h = getHum(); if not h then return end
        if h.Health < h.MaxHealth or h.MaxHealth < math.huge then h.MaxHealth = math.huge; h.Health = math.huge end
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
    if not State.godTestDone then task.wait(1); if State.GodModeEnabled then runGodModeTest() end end
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
    State.savedHealth = nil; State.savedMaxHealth = nil
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.GodModeEnabled then
        State.savedHealth = nil; State.savedMaxHealth = nil; State.godHealthConn = nil; startGodMode()
    end
end)

-- ============================================================
-- FULLBRIGHT / POV / LOW GFX
-- ============================================================
local function saveLighting()
    State.fbSaved = {
        Brightness=Lighting.Brightness, Ambient=Lighting.Ambient,
        OutdoorAmbient=Lighting.OutdoorAmbient, GlobalShadows=Lighting.GlobalShadows,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        ClockTime=Lighting.ClockTime, ExposureCompensation=Lighting.ExposureCompensation,
    }
end
local function applyFullbright()
    Lighting.Brightness = 2; Lighting.Ambient = Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255); Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6; Lighting.FogStart = 1e6; Lighting.ClockTime = 12; Lighting.ExposureCompensation = 0.5
end
local function restoreLighting()
    if not State.fbSaved then return end
    for k, v in pairs(State.fbSaved) do pcall(function() Lighting[k] = v end) end
    State.fbSaved = nil
end
local function startFullbright()
    if not State.fbSaved then saveLighting() end
    State.FullbrightEnabled = true; applyFullbright()
    if State.fbThread then pcall(function() task.cancel(State.fbThread) end); State.fbThread = nil end
    State.fbThread = task.spawn(function()
        while State.FullbrightEnabled do task.wait(PERF.FB_LOOP); if State.FullbrightEnabled then applyFullbright() end end
    end)
end
local function stopFullbright()
    State.FullbrightEnabled = false
    if State.fbThread then pcall(function() task.cancel(State.fbThread) end); State.fbThread = nil end
    restoreLighting()
end
local function applyPov()
    if not Camera then return end
    Camera.FieldOfView = State.PovEnabled and State.PovValue or State.defaultFOV
end
Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
    if State.PovEnabled and Camera.FieldOfView ~= State.PovValue then Camera.FieldOfView = State.PovValue end
end)
local function saveLowGfx()
    State.lowGfxSaved = {
        TerrainDecoration=Workspace.Terrain.Decoration, TerrainWaterWaveSize=Workspace.Terrain.WaterWaveSize,
        TerrainWaterWaveSpeed=Workspace.Terrain.WaterWaveSpeed, TerrainWaterReflectance=Workspace.Terrain.WaterReflectance,
        TerrainWaterTransparency=Workspace.Terrain.WaterTransparency, GlobalShadows=Lighting.GlobalShadows,
        LightingFogEnd=Lighting.FogEnd,
    }
end
local function applyLowGfx()
    pcall(function()
        Workspace.Terrain.Decoration = false; Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0; Workspace.Terrain.WaterReflectance = 0
        Workspace.Terrain.WaterTransparency = 1
    end)
    Lighting.GlobalShadows = false; Lighting.FogEnd = 1e6
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
    State.LowGfxEnabled = true; applyLowGfx()
    if State.lowGfxThread then pcall(function() task.cancel(State.lowGfxThread) end); State.lowGfxThread = nil end
    State.lowGfxThread = task.spawn(function()
        while State.LowGfxEnabled do task.wait(PERF.LOWGFX_LOOP); if State.LowGfxEnabled then applyLowGfx() end end
    end)
end
local function stopLowGfx()
    State.LowGfxEnabled = false
    if State.lowGfxThread then pcall(function() task.cancel(State.lowGfxThread) end); State.lowGfxThread = nil end
    restoreLowGfx()
end

-- ============================================================
-- AIMBOT FOV RING
-- ============================================================
local function calculateTransparency(distance, fovRadius)
    local maxDistance = fovRadius
    local transparency = (1 - (distance / maxDistance)) * State.AimbotMaxTransparency
    if transparency < 0 then transparency = 0 end
    return transparency
end
local function getClosestPlayerInFOV(trg_part)
    local nearest = nil; local last = math.huge
    local center = Camera.ViewportSize / 2
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local part = char and char:FindFirstChild(trg_part)
            if part then
                local ePos, isVisible = Camera:WorldToViewportPoint(part.Position)
                local distance = (Vector2.new(ePos.x, ePos.y) - center).Magnitude
                if distance < last and isVisible and distance < State.AimbotFov then
                    last = distance; nearest = player
                end
            end
        end
    end
    return nearest
end
local function lookAt(target)
    local lookVector = (target - Camera.CFrame.Position).unit
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + lookVector)
end
local function aimbotRenderStep()
    if not State.AimbotEnabled or not State.fovRing then return end
    State.fovRing.Position = Camera.ViewportSize / 2
    State.fovRing.Radius = State.AimbotFov
    State.fovRing.Color = State.AimbotRingColor
    State.fovRing.Visible = true
    local closest = getClosestPlayerInFOV(State.AimbotTargetPart)
    if closest and closest.Character then
        local tp = closest.Character:FindFirstChild(State.AimbotTargetPart)
        if tp then
            lookAt(tp.Position)
            local ePos = Camera:WorldToViewportPoint(tp.Position)
            local distance = (Vector2.new(ePos.x, ePos.y) - (Camera.ViewportSize / 2)).Magnitude
            State.fovRing.Transparency = calculateTransparency(distance, State.AimbotFov)
        end
    else
        State.fovRing.Transparency = 0.1
    end
end
local function createFovRing()
    if State.fovRing then return end
    local ok, ring = pcall(function() return Drawing.new("Circle") end)
    if ok and ring then
        ring.Visible = true; ring.Thickness = 2
        ring.Color = State.AimbotRingColor; ring.Filled = false
        ring.Radius = State.AimbotFov; ring.Position = Camera.ViewportSize / 2
        ring.Transparency = 0.1; State.fovRing = ring
    end
end
local function destroyFovRing()
    if State.fovRing then pcall(function() State.fovRing:Remove() end); State.fovRing = nil end
end
local function startAimbot()
    State.AimbotEnabled = true
    createFovRing()
    pcall(function() RunService:UnbindFromRenderStep(State.AimbotBind) end)
    RunService:BindToRenderStep(State.AimbotBind, Enum.RenderPriority.Camera.Value + 1, aimbotRenderStep)
end
local function stopAimbot()
    State.AimbotEnabled = false
    pcall(function() RunService:UnbindFromRenderStep(State.AimbotBind) end)
    destroyFovRing()
end

-- ============================================================
-- TP
-- ============================================================
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end
local function teleportToPlayer(name)
    local target = Players:FindFirstChild(name); if not target then return end
    local tHRP = getPlayerRoot(target); local myHRP = getHRP()
    if not tHRP or not myHRP then return end
    myHRP.CFrame = tHRP.CFrame + Vector3.new(0, 3, 0)
end

-- ============================================================
-- FLY UI
-- ============================================================
local flyGui = Instance.new("ScreenGui")
flyGui.Name = rndName("UI"); flyGui.ResetOnSpawn = false
flyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
local upBtn = Instance.new("TextButton")
upBtn.Size = UDim2.new(0, 60, 0, 60); upBtn.Position = UDim2.new(0, 20, 1, -160)
upBtn.Text = "↑"; upBtn.TextSize = 32; upBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
upBtn.TextColor3 = Color3.fromRGB(0, 255, 100); upBtn.BackgroundTransparency = 0.3
upBtn.Visible = false; upBtn.Parent = flyGui
local downBtn = Instance.new("TextButton")
downBtn.Size = UDim2.new(0, 60, 0, 60); downBtn.Position = UDim2.new(0, 20, 1, -90)
downBtn.Text = "↓"; downBtn.TextSize = 32; downBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
downBtn.TextColor3 = Color3.fromRGB(0, 255, 100); downBtn.BackgroundTransparency = 0.3
downBtn.Visible = false; downBtn.Parent = flyGui
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

-- init speed/jump loop (dipanggil sekali, cek flag)
speedJumpLoop()

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

-- BYPASS TAB
local BypassTab = Window:CreateTab("Bypass", 4483362458)
BypassTab:CreateSection("A. Client-Side Anti-Detect")
BypassTab:CreateToggle({ Name = "Enable Anti-Detect", CurrentValue = false, Flag = "AntiDetect",
    Callback = function(v) if v then startAntiDetect() else stopAntiDetect() end end })
BypassTab:CreateParagraph({ Title = "Info Anti-Detect",
    Content = "protect_gui kalau executor support, randomize nama ScreenGui + Highlight + BillboardGui + FOV ring. Nyembunyiin ByVoid dari scan client-side. Nggak nembus anti-cheat server." })

BypassTab:CreateSection("B. Speed / Jump Loop Re-Apply")
BypassTab:CreateToggle({ Name = "Speed Bypass (loop re-apply)", CurrentValue = false, Flag = "SpdBypass",
    Callback = function(v) State.SpeedBypassEnabled = v end })
BypassTab:CreateSlider({ Name = "Speed Bypass Value", Range = {16, 300}, Increment = 1, Suffix = "ws",
    CurrentValue = 50, Flag = "SpdBypassVal",
    Callback = function(v) State.SpeedBypassValue = v end })
BypassTab:CreateToggle({ Name = "Jump Bypass (loop JumpPower)", CurrentValue = false, Flag = "JmpBypass",
    Callback = function(v) State.JumpBypassEnabled = v end })
BypassTab:CreateSlider({ Name = "Jump Bypass Power", Range = {50, 300}, Increment = 5, Suffix = "jp",
    CurrentValue = 100, Flag = "JmpBypassVal",
    Callback = function(v) State.JumpBypassVelocity = v end })
BypassTab:CreateButton({ Name = "Test Speed Support", Callback = runSpeedTest })
SpeedSupportLabel = BypassTab:CreateLabel("Speed Support: belum dites")
BypassTab:CreateButton({ Name = "Test Jump Support", Callback = runJumpTest })
JumpSupportLabel = BypassTab:CreateLabel("Jump Support: belum dites")

BypassTab:CreateSection("C. Auto-Recon Remote Generic")
BypassTab:CreateToggle({ Name = "Enable Remote Recon", CurrentValue = false, Flag = "Recon",
    Callback = function(v) if v then startRemoteRecon() else stopRemoteRecon() end end })
BypassTab:CreateButton({ Name = "Scan Sekarang", Callback = function()
    local found = scanRemotes()
    State.remoteCandidates = found
    local txt
    if #found == 0 then txt = "TIDAK ADA REMOTE COCOK"
    else txt = string.format("NEMU %d REMOTE", #found) end
    State.reconSupport = txt
    setLabel(ReconSupportLabel, "Remote Recon: " .. txt)
end })
ReconSupportLabel = BypassTab:CreateLabel("Remote Recon: belum dites")
BypassTab:CreateParagraph({ Title = "Info Recon",
    Content = "Scan ReplicatedStorage + Workspace cari RemoteEvent/Function yang namanya nyebut speed/move/jump/walk/char. Coba FireServer argumen generic. Kalau remote nggak bocor, server reject — hasil 'TIDAK ADA REMOTE COCOK' atau 'kepanggil tapi nggak ngefek'." })

-- AIMBOT
local AimTab = Window:CreateTab("Aimbot", 4483362458)
AimTab:CreateSection("Aimbot — FOV Ring")
AimTab:CreateToggle({ Name = "Enable Aimbot", CurrentValue = false, Flag = "Aimbot",
    Callback = function(v) if v then startAimbot() else stopAimbot() end end })
AimTab:CreateDropdown({
    Name = "Target Part", Options = {"Head", "UpperTorso", "Torso", "HumanoidRootPart", "LeftFoot", "RightFoot"},
    CurrentOption = {"Head"}, MultipleOptions = false, Flag = "AimPart",
    Callback = function(opt) if opt and opt[1] then State.AimbotTargetPart = opt[1] end end,
})
AimTab:CreateSlider({ Name = "FOV Radius (pixel)", Range = {20, 400}, Increment = 5, Suffix = "px",
    CurrentValue = 40, Flag = "AimFov",
    Callback = function(v) State.AimbotFov = v end })
AimTab:CreateSlider({ Name = "Ring Transparency", Range = {0.01, 1}, Increment = 0.01,
    CurrentValue = 0.1, Flag = "AimTrans",
    Callback = function(v) State.AimbotMaxTransparency = v end })
AimTab:CreateColorPicker({ Name = "Ring Color", Color = Color3.fromRGB(128, 0, 128), Flag = "AimColor",
    Callback = function(c) State.AimbotRingColor = c end })

-- FUN
local FunTab = Window:CreateTab("Fun", 4483362458)
FunTab:CreateSection("God Mode")
FunTab:CreateToggle({ Name = "Enable God Mode", CurrentValue = false, Flag = "God",
    Callback = function(v) if v then startGodMode() else stopGodMode() end end })
GodSupportLabel = FunTab:CreateLabel("God Mode: belum dites")
FunTab:CreateButton({ Name = "Test Map Support", Callback = function()
    if not State.GodModeEnabled then notify("ByVoid", "aktifkan God Mode dulu"); return end
    State.godTestDone = false; runGodModeTest()
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
        for _, hl in pairs(State.wallhackObjects) do if hl and hl.Parent then hl.FillColor = color end end
    end })

local TpTab = Window:CreateTab("Teleport", 4483362458)
local playerDropdown
local function refreshList() if playerDropdown then playerDropdown:Refresh(getPlayerNames()) end end
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

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    stopFly(); stopJumpHold(); stopSpinBot(); applySpeed()
    State.savedCollide = {}; State.rootCache = {}
    if State.NoclipEnabled then startNoclip() end
    if State.SpeedBypassEnabled or State.JumpBypassEnabled then speedJumpLoop() end
end)

notify("ByVoid", "v5.1 universal bypass loaded")
