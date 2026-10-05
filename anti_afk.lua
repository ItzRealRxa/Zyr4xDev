-- Zyr4x Hub: Anti-AFK, Auto-Clicker & Smart Auto-Rebirth
-- Built for Zyr4x

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local localPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- State
local antiAfkEnabled = true
local autoRebirthEnabled = false
local autoClickerEnabled = false
local clickSpeed = 0.05
local resetCount = 0
local rebirthCount = 0
local afkConnection = nil
local rebirthThread = nil
local clickerThread = nil
local cachedClickRemotes = nil

-- Safe GUI parent
local function getGuiParent()
    local okHui, hui = pcall(function()
        if typeof(gethui) == "function" then
            return gethui()
        end
    end)
    if okHui and hui then return hui end

    local okCore, core = pcall(function() return CoreGui end)
    if okCore and core then
        local canParent = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = core
            test:Destroy()
        end)
        if canParent then return core end
    end

    return localPlayer:WaitForChild("PlayerGui")
end

-- Cleanup old GUI
local old = getGuiParent():FindFirstChild("Zyr4xHub_ScreenGui") or getGuiParent():FindFirstChild("AntiAFK_ScreenGui")
if old then pcall(function() old:Destroy() end) end

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Zyr4xHub_ScreenGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = getGuiParent()

-- Main Frame (Clean layout without count clutter)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 485)
mainFrame.Position = UDim2.new(0.5, -140, 0.35, -242)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 1.2
stroke.Color = Color3.fromRGB(50, 50, 60)

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFill = Instance.new("Frame", titleBar)
titleFill.Size = UDim2.new(1, 0, 0, 10)
titleFill.Position = UDim2.new(0, 0, 1, -10)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
titleFill.BorderSizePixel = 0

local titleText = Instance.new("TextLabel", titleBar)
titleText.Size = UDim2.new(1, -50, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.Text = "Zyr4x Hub"
titleText.TextColor3 = Color3.fromRGB(240, 240, 245)
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
closeBtn.TextSize = 12
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Helper: make label
local function makeLabel(text, yPos)
    local lbl = Instance.new("TextLabel", mainFrame)
    lbl.Size = UDim2.new(1, -24, 0, 16)
    lbl.Position = UDim2.new(0, 12, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(180, 180, 195)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

local function makeSectionTitle(text, yPos)
    local lbl = makeLabel(text, yPos)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(140, 140, 160)
    lbl.TextSize = 10
    return lbl
end

local function makeButton(text, yPos, height, bgColor)
    local btn = Instance.new("TextButton", mainFrame)
    btn.Size = UDim2.new(1, -24, 0, height)
    btn.Position = UDim2.new(0, 12, 0, yPos)
    btn.BackgroundColor3 = bgColor
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- SECTION: Anti-AFK
makeSectionTitle("ANTI-AFK", 44)
local afkStats = makeLabel("Kicks Prevented: 0", 62)
local afkToggleBtn = makeButton("Anti-AFK: ON", 82, 28, Color3.fromRGB(231, 76, 60))

-- Divider
local div = Instance.new("Frame", mainFrame)
div.Size = UDim2.new(1, -24, 0, 1)
div.Position = UDim2.new(0, 12, 0, 118)
div.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
div.BorderSizePixel = 0

-- SECTION: Auto-Clicker
makeSectionTitle("AUTO-CLICKER (TURBO)", 126)

-- Speed / CPS Input Container
local speedContainer = Instance.new("Frame", mainFrame)
speedContainer.Size = UDim2.new(1, -24, 0, 26)
speedContainer.Position = UDim2.new(0, 12, 0, 144)
speedContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
speedContainer.BorderSizePixel = 0
Instance.new("UICorner", speedContainer).CornerRadius = UDim.new(0, 6)

local speedLabel = Instance.new("TextLabel", speedContainer)
speedLabel.Size = UDim2.new(0, 130, 1, 0)
speedLabel.Position = UDim2.new(0, 10, 0, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.Gotham
speedLabel.Text = "Clicks / Sec (CPS):"
speedLabel.TextColor3 = Color3.fromRGB(180, 180, 195)
speedLabel.TextSize = 11
speedLabel.TextXAlignment = Enum.TextXAlignment.Left

local speedBox = Instance.new("TextBox", speedContainer)
speedBox.Size = UDim2.new(0, 90, 1, -6)
speedBox.Position = UDim2.new(1, -96, 0, 3)
speedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
speedBox.BorderSizePixel = 0
speedBox.Font = Enum.Font.GothamBold
speedBox.Text = "20"
speedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
speedBox.TextSize = 11
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 4)

local clickerStatusLabel = makeLabel("Mode: In-game Remote Turbo", 174)
clickerStatusLabel.Font = Enum.Font.GothamMedium
clickerStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 175)
clickerStatusLabel.TextSize = 10

local clickerToggleBtn = makeButton("Enable Turbo Clicker", 192, 28, Color3.fromRGB(46, 204, 113))

-- Divider 2
local div2 = Instance.new("Frame", mainFrame)
div2.Size = UDim2.new(1, -24, 0, 1)
div2.Position = UDim2.new(0, 12, 0, 228)
div2.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
div2.BorderSizePixel = 0

-- SECTION: Auto-Rebirth
makeSectionTitle("AUTO-REBIRTH", 236)

local rebirthStatusLabel = makeLabel("Status: Idle", 254)
rebirthStatusLabel.TextWrapped = true
rebirthStatusLabel.Size = UDim2.new(1, -24, 0, 24)

local rebirthToggleBtn = makeButton("Enable Auto-Rebirth", 282, 28, Color3.fromRGB(46, 204, 113))

local scanBtn = makeButton("Scan All Buttons (F9 Console)", 318, 24, Color3.fromRGB(40, 40, 52))
scanBtn.Font = Enum.Font.GothamMedium

local dumpBtn = makeButton("Dump All Remotes (F9 Console)", 348, 24, Color3.fromRGB(40, 40, 52))
dumpBtn.Font = Enum.Font.GothamMedium

-- Hint
local hint = Instance.new("TextLabel", mainFrame)
hint.Size = UDim2.new(1, -24, 0, 68)
hint.Position = UDim2.new(0, 12, 0, 380)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.Text = "Turbo Clicker accelerates in-game clicking by multiplying the game's training remote at custom CPS! Keep in-game auto ON for best results."
hint.TextColor3 = Color3.fromRGB(110, 110, 125)
hint.TextSize = 10
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Center

-- Drag
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- =====================================================================
-- ANTI-AFK LOGIC
-- =====================================================================

local function onIdled()
    if not antiAfkEnabled then return end
    pcall(function()
        VirtualUser:CaptureController()
    end)
    pcall(function()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    resetCount = resetCount + 1
    afkStats.Text = "Kicks Prevented: " .. tostring(resetCount)
end

local function startAntiAfk()
    if afkConnection then afkConnection:Disconnect() end
    afkConnection = localPlayer.Idled:Connect(onIdled)
    afkToggleBtn.Text = "Anti-AFK: ON"
    afkToggleBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
end

local function stopAntiAfk()
    if afkConnection then afkConnection:Disconnect(); afkConnection = nil end
    afkToggleBtn.Text = "Anti-AFK: OFF"
    afkToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
end

afkToggleBtn.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    if antiAfkEnabled then startAntiAfk() else stopAntiAfk() end
end)

-- =====================================================================
-- TURBO AUTO-CLICKER ENGINE
-- =====================================================================

local detectedClickRemote = nil
local detectedClickArgs = {}

-- Sniff the game's actual remote event whenever in-game auto clicker fires
pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "FireServer" or method == "fireServer") and self:IsA("RemoteEvent") then
                local n = self.Name:lower()
                -- Filter out unrelated services
                if not (n:find("chat") or n:find("ping") or n:find("report") or n:find("teleport") or n:find("analytics") or n:find("rebirth")) then
                    detectedClickRemote = self
                    detectedClickArgs = {...}
                    if clickerStatusLabel then
                        clickerStatusLabel.Text = "Target: " .. self.Name .. " (Locked)"
                        clickerStatusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

local trainKeywords = {
    "click", "tap", "train", "power", "swing", "punch", "attack",
    "strength", "weapon", "hit", "damage", "gain", "addpower", "lift",
    "exercise", "farm", "muscle", "givepower", "bicep", "hand", "fight"
}

local function doSingleClick()
    -- Priority 1: Fire the sniffed remote captured from the in-game auto-clicker
    if detectedClickRemote then
        pcall(function()
            if #detectedClickArgs > 0 then
                detectedClickRemote:FireServer(table.unpack(detectedClickArgs))
            else
                detectedClickRemote:FireServer()
                detectedClickRemote:FireServer(1)
            end
        end)
    end

    -- Priority 2: Fire all discovered training & power remotes in ReplicatedStorage
    pcall(function()
        if not cachedClickRemotes then
            cachedClickRemotes = {}
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local n = obj.Name:lower()
                    for _, kw in ipairs(trainKeywords) do
                        if n:find(kw, 1, true) then
                            table.insert(cachedClickRemotes, obj)
                            break
                        end
                    end
                end
            end
            if #cachedClickRemotes > 0 and not detectedClickRemote and clickerStatusLabel then
                clickerStatusLabel.Text = "Target: " .. cachedClickRemotes[1].Name .. " (" .. #cachedClickRemotes .. " remotes)"
                clickerStatusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
            end
        end

        for _, remote in ipairs(cachedClickRemotes) do
            pcall(function()
                remote:FireServer()
                remote:FireServer(1)
                remote:FireServer(true)
            end)
        end
    end)

    -- Priority 3: Hardware cursor click offset from center so player model doesn't block it
    pcall(function()
        local cam = workspace.CurrentCamera
        local viewport = cam and cam.ViewportSize or Vector2.new(800, 600)
        VirtualUser:ClickButton1(Vector2.new(viewport.X * 0.35, viewport.Y * 0.45))
    end)

    -- Priority 4: Tool activation
    local char = localPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
end

local function parseClickSpeed()
    local text = speedBox.Text:gsub("%s+", "")
    local cps = tonumber(text)
    if not cps or cps <= 0 then
        cps = 20
        speedBox.Text = "20"
    elseif cps > 100 then
        cps = 100
        speedBox.Text = "100"
    end
    clickSpeed = 1 / cps
    return cps
end

speedBox.FocusLost:Connect(function()
    parseClickSpeed()
end)

local function startAutoClicker()
    local cps = parseClickSpeed()
    autoClickerEnabled = true
    clickerToggleBtn.Text = "Disable Turbo Clicker"
    clickerToggleBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    if clickerStatusLabel and not detectedClickRemote then
        clickerStatusLabel.Text = "Turbo Active (" .. cps .. " CPS)"
    end

    clickerThread = task.spawn(function()
        while autoClickerEnabled do
            doSingleClick()
            task.wait(clickSpeed)
        end
    end)
end

local function stopAutoClicker()
    autoClickerEnabled = false
    clickerToggleBtn.Text = "Enable Turbo Clicker"
    clickerToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    if clickerStatusLabel then
        clickerStatusLabel.Text = "Mode: In-game Remote Turbo"
        clickerStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 175)
    end
    if clickerThread then pcall(task.cancel, clickerThread); clickerThread = nil end
end

clickerToggleBtn.MouseButton1Click:Connect(function()
    if autoClickerEnabled then stopAutoClicker() else startAutoClicker() end
end)

-- =====================================================================
-- SMART REBIRTH ENGINE v3
-- Strategy: Open menu -> click rebirth -> fire remotes -> repeat
-- =====================================================================

-- Check if a GUI element is truly visible on screen
local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    while current and current ~= game do
        if current:IsA("GuiObject") then
            if not current.Visible then return false end
            if current.BackgroundTransparency >= 1 and current.Size == UDim2.new(0,0,0,0) then return false end
        end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        current = current.Parent
    end
    return true
end

-- Best-effort click simulation using every available method
local function clickButton(btn)
    if not btn then return false end
    local methods = {}
    
    -- Method 1: fireclick (Synapse/Fluxus/etc)
    pcall(function()
        if fireclick then
            fireclick(btn)
            table.insert(methods, "fireclick")
        end
    end)
    
    -- Method 2: firesignal on all relevant signals
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            table.insert(methods, "firesignal(Click)")
        end
    end)
    
    pcall(function()
        if firesignal then
            firesignal(btn.Activated)
            table.insert(methods, "firesignal(Activated)")
        end
    end)
    
    -- Method 3: getconnections -> fire each
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                if c.Fire then c:Fire() end
            end
            for _, c in ipairs(getconnections(btn.Activated)) do
                if c.Fire then c:Fire() end
            end
            for _, c in ipairs(getconnections(btn.MouseButton1Down)) do
                if c.Fire then c:Fire() end
            end
            table.insert(methods, "getconnections")
        end
    end)
    
    -- Method 4: VirtualUser click WITHOUT CaptureController
    -- CaptureController() is what locks the mouse - ClickButton1 alone is safe
    pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        if size.X > 0 and size.Y > 0 then
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2
            -- DO NOT call VirtualUser:CaptureController() here
            VirtualUser:ClickButton1(Vector2.new(cx, cy))
            table.insert(methods, "VirtualUser")
        end
    end)
    
    if #methods > 0 then
        print("[Rebirth] Clicked: " .. btn:GetFullName() .. " via: " .. table.concat(methods, ", "))
    end
    
    return #methods > 0
end

-- Recursively search PlayerGui for buttons matching keywords
local function searchButtons(keywords, exactMatch)
    local results = {}
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return results end
    
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsDescendantOf(screenGui) then continue end
        if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then continue end
        
        local btnText = ""
        if obj:IsA("TextButton") then
            btnText = obj.Text:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        end
        
        -- Also check child TextLabels for text
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("TextLabel") and child.Text ~= "" then
                btnText = btnText .. " " .. child.Text:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
        
        local objName = obj.Name:lower()
        
        for _, kw in ipairs(keywords) do
            local kwLower = kw:lower()
            local match = false
            
            if exactMatch then
                match = (btnText == kwLower) or (objName == kwLower)
            else
                match = btnText:find(kwLower, 1, true) or objName:find(kwLower, 1, true)
            end
            
            if match then
                table.insert(results, {
                    button = obj,
                    text = btnText,
                    name = obj.Name,
                    path = obj:GetFullName(),
                    visible = isActuallyVisible(obj),
                    keyword = kw
                })
                break
            end
        end
    end
    
    return results
end

-- Fire all rebirth-related remotes
local function fireRebirthRemotes()
    local fired = 0
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local n = desc.Name:lower()
            if n:find("rebirth") or n:find("prestige") or n:find("ascend") then
                pcall(function()
                    if desc:IsA("RemoteEvent") then
                        desc:FireServer()
                        desc:FireServer(1)
                        desc:FireServer("Rebirth")
                        desc:FireServer(true)
                    else
                        desc:InvokeServer()
                        desc:InvokeServer(1)
                        desc:InvokeServer("Rebirth")
                    end
                end)
                fired = fired + 1
                print("[Rebirth] Fired remote: " .. desc:GetFullName())
            end
        end
    end
    return fired
end

-- Execute rebirth: scan visible buttons each tick + fire remotes
local function executeRebirth()
    local detail = ""
    local didSomething = false
    
    -- Find and click VISIBLE rebirth buttons right now
    local rebirthBtns = searchButtons({"rebirth"}, false)
    for _, info in ipairs(rebirthBtns) do
        if info.text:find("auto") or info.text:find("skip") then continue end
        if info.visible then
            clickButton(info.button)
            detail = "Rebirth btn (" .. info.name .. ")"
            didSomething = true
        end
    end
    
    -- Also try auto rebirth button if available
    if not didSomething then
        local autoBtns = searchButtons({"auto rebirth", "autorebirth"}, false)
        for _, info in ipairs(autoBtns) do
            if info.visible then
                clickButton(info.button)
                detail = "Auto Rebirth btn"
                didSomething = true
            end
        end
    end
    
    -- Fire rebirth remotes
    local remotesFired = fireRebirthRemotes()
    if remotesFired > 0 then
        didSomething = true
        if detail == "" then detail = "Fired " .. remotesFired .. " remote(s)" end
    end
    
    if didSomething then
        rebirthCount = rebirthCount + 1
        rebirthStatusLabel.Text = string.format("Rebirths: %d | %s", rebirthCount, detail)
    else
        rebirthStatusLabel.Text = "Rebirths: " .. rebirthCount .. " | No targets found"
    end
end

-- Auto-Rebirth Loop
local function startAutoRebirth()
    autoRebirthEnabled = true
    rebirthToggleBtn.Text = "Disable Auto-Rebirth"
    rebirthToggleBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    
    rebirthThread = task.spawn(function()
        while autoRebirthEnabled do
            executeRebirth()
            task.wait(1.0)
        end
    end)
end

local function stopAutoRebirth()
    autoRebirthEnabled = false
    rebirthToggleBtn.Text = "Enable Auto-Rebirth"
    rebirthToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    rebirthStatusLabel.Text = string.format("Rebirths: %d | Stopped", rebirthCount)
    if rebirthThread then pcall(task.cancel, rebirthThread); rebirthThread = nil end
end

rebirthToggleBtn.MouseButton1Click:Connect(function()
    if autoRebirthEnabled then stopAutoRebirth() else startAutoRebirth() end
end)

-- DIAGNOSTIC: Scan all buttons in PlayerGui
scanBtn.MouseButton1Click:Connect(function()
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then print("[Scan] No PlayerGui found") return end
    
    print("\n========== FULL BUTTON SCAN ==========")
    local count = 0
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsDescendantOf(screenGui) then continue end
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local txt = obj:IsA("TextButton") and obj.Text or "(ImageButton)"
            local vis = isActuallyVisible(obj)
            print(string.format("  [%s] Name=%s | Text='%s' | Visible=%s | Path=%s",
                obj.ClassName, obj.Name, txt, tostring(vis), obj:GetFullName()))
            count = count + 1
        end
    end
    print("========== Total: " .. count .. " buttons ==========\n")
    rebirthStatusLabel.Text = "Scanned " .. count .. " buttons (F9)"
end)

-- DIAGNOSTIC: Dump all remotes in ReplicatedStorage
dumpBtn.MouseButton1Click:Connect(function()
    print("\n========== REMOTE DUMP ==========")
    local count = 0
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            print(string.format("  [%s] %s", desc.ClassName, desc:GetFullName()))
            count = count + 1
        end
    end
    print("========== Total: " .. count .. " remotes ==========\n")
    rebirthStatusLabel.Text = "Found " .. count .. " remotes (F9)"
end)

-- Close
closeBtn.MouseButton1Click:Connect(function()
    stopAntiAfk()
    stopAutoClicker()
    stopAutoRebirth()
    screenGui:Destroy()
end)

-- Init
startAntiAfk()
print("[Zyr4x Hub] Loaded. Use F9 console for diagnostics.")
