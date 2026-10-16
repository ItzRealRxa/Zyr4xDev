local myScriptCode = [===[
if _G.__rivals_loaded then
    warn("[rivals] already running - blocked duplicate execution.")
    return
end
_G.__rivals_loaded = true

local VirtualInputManager = game:GetService("VirtualInputManager")
local Players             = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local TweenService         = game:GetService("TweenService")
local Lighting             = game:GetService("Lighting")
local HttpService          = game:GetService("HttpService")

local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local CACHE_FOLDER = "Rivals Script by Zyr4x"
local CACHE_FILE   = CACHE_FOLDER .. "/rivals_settings.json"

pcall(function()
    if makefolder then
        local exists = isfolder and isfolder(CACHE_FOLDER)

        if not exists then
            makefolder(CACHE_FOLDER)
        end
    end
end)

local THEME_PURPLE = Color3.fromRGB(168, 85, 247)
local ESP_BOX_COLOR = Color3.fromRGB(186, 104, 255)

local DefaultSettings = {
    ESP_Enabled            = true,
    ESP_Highlight          = true,
    ESP_Name               = true,
    ESP_Studs              = true,
    ESP_Tracer              = false,
    ESP_BoxTransparency    = 0.5,
    ESP_MaxDistance        = 500,
    Aimbot_Enabled         = true,
    Aimbot_FOVRadius       = 100,
    Aimbot_WallCheck       = false,
    Aimbot_Smoothness      = 1,
    Aimbot_TargetPart      = "Head",
    Triggerbot_Enabled     = true,
    Triggerbot_MaxDistance = 1000,
    Triggerbot_FOVRadius   = 50,
    InfJump_Enabled        = false,
    DeviceSpoofer_Active   = nil,
    AutoReload_Enabled     = true,
    SilentAim_Enabled      = true,
    SilentAim_FOVRadius    = 150,
    SilentAim_WallCheck    = false,
    Hitbox_Enabled         = false,
    Hitbox_Size            = 15,
}

local function loadSettings()
    local ok, result = pcall(function()
        if isfile and isfile(CACHE_FILE) then
            local raw     = readfile(CACHE_FILE)
            local decoded = HttpService:JSONDecode(raw)

            for k, v in pairs(DefaultSettings) do
                if decoded[k] == nil then
                    decoded[k] = v
                end
            end

            return decoded
        end
    end)

    if ok and result then
        return result
    end

    local t = {}

    for k, v in pairs(DefaultSettings) do
        t[k] = v
    end

    return t
end

local SERIALIZABLE_TYPES = {
    boolean = true,
    number = true,
    string = true
}

local function saveSettings(s)
    pcall(function()
        if writefile then
            pcall(function()
                if makefolder then
                    local exists = isfolder and isfolder(CACHE_FOLDER)

                    if not exists then
                        makefolder(CACHE_FOLDER)
                    end
                end
            end)

            local clean = {}

            for k, v in pairs(s) do
                if SERIALIZABLE_TYPES[typeof(v)] or v == nil then
                    clean[k] = v
                end
            end

            writefile(
                CACHE_FILE,
                HttpService:JSONEncode(clean)
            )
        end
    end)
end

local Settings = loadSettings()

if Settings.ESP_Tracer == nil and Settings.ESP_Snapline ~= nil then
    Settings.ESP_Tracer = Settings.ESP_Snapline
end

Settings.ESP_Snapline           = nil
Settings.Triggerbot_MaxDistance = 1000

local SetControlsRemote = nil

pcall(function()
    SetControlsRemote = ReplicatedStorage
        :WaitForChild("Remotes", 5)
        :WaitForChild("Replication", 5)
        :WaitForChild("Fighter", 5)
        :WaitForChild("SetControls", 5)
end)

local function spoofDevice(deviceValue)
    if not SetControlsRemote then
        return
    end

    pcall(function()
        SetControlsRemote:FireServer(deviceValue)
    end)
end

local function reapplySpooferOnLoad()
    if Settings.DeviceSpoofer_Active then
        task.wait(1.5)
        spoofDevice(Settings.DeviceSpoofer_Active)
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    character.ChildAdded:Connect(function(child)
        if child.Name == "HumanoidRootPart" then
            reapplySpooferOnLoad()
        end
    end)
end)

if LocalPlayer.Character
and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    reapplySpooferOnLoad()
end

local function isVoteScreenActive()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

    if not playerGui then
        return false
    end

    local mainGui = playerGui:FindFirstChild("MainGUI")

    if not mainGui then
        return false
    end

    local mainFrame = mainGui:FindFirstChild("MainFrame")

    if not mainFrame then
        return false
    end

    local di1 = mainFrame:FindFirstChild("DuelInterface")

    if not di1 then
        return false
    end

    local di2 = di1:FindFirstChild("DuelInterface")

    if not di2 then
        return false
    end

    local voting = di2:FindFirstChild("Voting")

    if not voting then
        return false
    end

    if voting.Visible then
        return true
    end

    local maps = voting:FindFirstChild("Maps")

    if not maps then
        return false
    end

    if maps.Visible then
        return true
    end

    local mapsList = maps:FindFirstChild("MapsList")

    return mapsList ~= nil
end

local function isInActiveRound()
    local character = LocalPlayer.Character

    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    if not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    if isVoteScreenActive() then
        return false
    end

    return true
end

local cachedAmmoLabel   = nil
local lastReloadAttempt = 0
local lastGuiScan       = 0

local function getEquippedWeaponAmmo()
    local char = LocalPlayer.Character
    if not char then return nil end

    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") or child:IsA("Model") then
            local ammoVal = child:FindFirstChild("Ammo")
                or child:FindFirstChild("CurrentAmmo")
                or child:FindFirstChild("Clip")
            if ammoVal and (ammoVal:IsA("IntValue") or ammoVal:IsA("NumberValue")) then
                return ammoVal.Value
            end
            local ammoAttr = child:GetAttribute("Ammo")
                or child:GetAttribute("CurrentAmmo")
                or child:GetAttribute("Clip")
            if typeof(ammoAttr) == "number" then
                return ammoAttr
            end
        end
    end
    return nil
end

local function checkAndAutoReload()
    if not Settings.AutoReload_Enabled then
        return
    end

    if not isInActiveRound() then
        return
    end

    local now = os.clock()
    if now - lastReloadAttempt < 0.8 then
        return
    end

    local currentAmmo = getEquippedWeaponAmmo()

    if currentAmmo == nil and cachedAmmoLabel and cachedAmmoLabel.Parent and cachedAmmoLabel.Visible then
        local text = cachedAmmoLabel.Text
        local num = text:match("^(%d+)%s*/") or text:match("^(%d+)$")
        if num then
            currentAmmo = tonumber(num)
        else
            cachedAmmoLabel = nil
        end
    end

    if currentAmmo == nil and (now - lastGuiScan > 3.0) then
        lastGuiScan = now
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local mainGui = pg:FindFirstChild("MainGUI") or pg:FindFirstChild("HUD")
            local searchRoot = mainGui or pg
            for _, obj in ipairs(searchRoot:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Visible then
                    local name = obj.Name:lower()
                    if name:find("ammo") or name:find("mag") or name:find("bullet") or name:find("clip") then
                        local text = obj.Text
                        local num = text:match("^(%d+)%s*/") or text:match("^(%d+)$")
                        if num then
                            cachedAmmoLabel = obj
                            currentAmmo = tonumber(num)
                            break
                        end
                    end
                end
            end
        end
    end

    if currentAmmo ~= nil and currentAmmo <= 0 then
        lastReloadAttempt = now
        VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.R,
            false,
            game
        )
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.R,
            false,
            game
        )
    end
end

local function purgeStartupBlurs()
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BlurEffect") and v.Name == "StartupBlur" then
            v:Destroy()
        end
    end
end

local function ShowStartup()
    purgeStartupBlurs()

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local oldStartup = playerGui:FindFirstChild("StartupOverlay")

    if oldStartup then
        oldStartup:Destroy()
    end

    local startupGui = Instance.new("ScreenGui")
    startupGui.Name            = "StartupOverlay"
    startupGui.ResetOnSpawn    = false
    startupGui.IgnoreGuiInset = true
    startupGui.DisplayOrder    = 1000
    startupGui.Parent          = playerGui

    local lightingBlur = Instance.new("BlurEffect")
    lightingBlur.Name = "StartupBlur"
    lightingBlur.Size = 18
    lightingBlur.Parent = Lighting

    local overlay = Instance.new("Frame")
    overlay.Size                   = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.18
    overlay.BorderSizePixel        = 0
    overlay.Parent                 = startupGui

    local card = Instance.new("Frame")
    card.AnchorPoint      = Vector2.new(0.5, 0.5)
    card.Position         = UDim2.fromScale(0.5, 0.5)
    card.Size             = UDim2.fromOffset(430, 210)
    card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    card.BorderSizePixel  = 0
    card.Parent           = overlay

    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color        = Color3.fromRGB(45, 45, 45)
    cardStroke.Thickness    = 1
    cardStroke.Transparency = 0.15
    cardStroke.Parent       = card

    local title = Instance.new("TextLabel")
    title.AnchorPoint            = Vector2.new(0.5, 0.5)
    title.Position               = UDim2.new(0.5, 0, 0.36, 0)
    title.Size                   = UDim2.new(1, -40, 0, 40)
    title.BackgroundTransparency = 1
    title.Text                   = "Rivals By Zyr4x Dev"
    title.TextColor3             = Color3.fromRGB(255, 255, 255)
    title.TextSize               = 25
    title.Font                   = Enum.Font.GothamBold
    title.Parent                 = card

    local subtitle = Instance.new("TextLabel")
    subtitle.AnchorPoint            = Vector2.new(0.5, 0.5)
    subtitle.Position               = UDim2.new(0.5, 0, 0.55, 0)
    subtitle.Size                   = UDim2.new(1, -40, 0, 28)
    subtitle.BackgroundTransparency = 1
    subtitle.Text                   = "Click [ ⚡ MENU ] or press Right Control / Insert to open"
    subtitle.TextColor3 = Color3.fromRGB(165, 165, 165)
    subtitle.TextSize   = 15
    subtitle.Font       = Enum.Font.GothamMedium
    subtitle.Parent     = card

    local line = Instance.new("Frame")
    line.AnchorPoint      = Vector2.new(0.5, 0.5)
    line.Position         = UDim2.new(0.5, 0, 0.70, 0)
    line.Size             = UDim2.new(0.72, 0, 0, 1)
    line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    line.BorderSizePixel  = 0
    line.Parent           = card

    local credit = Instance.new("TextLabel")
    credit.AnchorPoint            = Vector2.new(0.5, 0.5)
    credit.Position               = UDim2.new(0.5, 0, 0.84, 0)
    credit.Size                   = UDim2.new(1, -40, 0, 25)
    credit.BackgroundTransparency = 1
    credit.Text                   = "by Zyr4x"
    credit.TextColor3             = Color3.fromRGB(125, 125, 125)
    credit.TextSize               = 14
    credit.Font                   = Enum.Font.GothamMedium
    credit.Parent                 = card

    task.delay(3, function()
        if not startupGui.Parent then
            purgeStartupBlurs()
            return
        end

        local fade = TweenInfo.new(
            0.45,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

        TweenService:Create(overlay, fade, {
            BackgroundTransparency = 1
        }):Play()

        TweenService:Create(card, fade, {
            BackgroundTransparency = 1
        }):Play()

        TweenService:Create(title, fade, {
            TextTransparency = 1
        }):Play()

        TweenService:Create(subtitle, fade, {
            TextTransparency = 1
        }):Play()

        TweenService:Create(credit, fade, {
            TextTransparency = 1
        }):Play()

        TweenService:Create(line, fade, {
            BackgroundTransparency = 1
        }):Play()

        task.wait(0.5)

        purgeStartupBlurs()

        if startupGui.Parent then
            startupGui:Destroy()
        end
    end)
end

ShowStartup()

local _connections = {}

local function trackConn(c)
    table.insert(_connections, c)
    return c
end

local _killed     = false
local circleDraw  = nil
local tracerLines = {}
local releaseTab       = nil
local resetAllHitboxes = nil

local function killScript()
    if _killed then
        return
    end

    _killed = true

    if releaseTab then
        pcall(releaseTab)
    end

    Settings.Aimbot_Enabled     = false
    Settings.Triggerbot_Enabled = false
    Settings.ESP_Enabled        = false
    Settings.InfJump_Enabled    = false
    Settings.AutoReload_Enabled = false
    Settings.SilentAim_Enabled  = false
    Settings.Hitbox_Enabled     = false

    if resetAllHitboxes then
        pcall(resetAllHitboxes)
    end

    for _, c in ipairs(_connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, name in ipairs({
                "ESP_Highlight",
                "ESP_Billboard",
                "HealthBackground",
                "HealthOutline"
            }) do
                local obj = player.Character:FindFirstChild(name)

                if obj then
                    pcall(function()
                        obj:Destroy()
                    end)
                end
            end
        end
    end

    local capturedCircle = circleDraw
    circleDraw = nil

    pcall(function()
        if capturedCircle then
            capturedCircle:Remove()
        end
    end)

    local capturedLines = tracerLines
    tracerLines = {}

    for _, line in pairs(capturedLines) do
        pcall(function()
            line.Visible = false
            line:Remove()
        end)
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

    if playerGui then
        for _, name in ipairs({
            "MenuGUI",
            "MobileToggleGui",
            "StartupOverlay",
            "KillConfirmGui"
        }) do
            local g = playerGui:FindFirstChild(name)

            if g then
                pcall(function()
                    g:Destroy()
                end)
            end
        end
    end

    purgeStartupBlurs()

    pcall(function()
        if writefile then
            writefile(CACHE_FOLDER .. "/rivals_main.lua", "-- killed")
            writefile(CACHE_FOLDER .. "/rivals_queue.lua", "-- killed")
        end
    end)

    _G.__rivals_loaded = nil

    print("[rivals] script killed and queue chain cleared.")
end

local isMinimized = false
local closeMenu
local openMenu
local toggleMenu

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "MenuGUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.IgnoreGuiInset  = true
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder    = 999
ScreenGui.Parent          = LocalPlayer:WaitForChild("PlayerGui")

local Watermark = Instance.new("TextLabel")
Watermark.AnchorPoint            = Vector2.new(0, 1)
Watermark.Position               = UDim2.new(0, 10, 1, -10)
Watermark.Size                   = UDim2.fromOffset(200, 30)
Watermark.BackgroundTransparency = 1
Watermark.Text                   = "ZYR4X HUB • RIVALS"
Watermark.TextColor3             = THEME_PURPLE
Watermark.Font                   = Enum.Font.GothamBold
Watermark.TextSize               = 16
Watermark.TextXAlignment         = Enum.TextXAlignment.Left
Watermark.TextYAlignment         = Enum.TextYAlignment.Center
Watermark.TextStrokeTransparency = 0.8
Watermark.ZIndex                 = 120
Watermark.Visible                = false
Watermark.Parent                 = ScreenGui

local BackgroundFrame = Instance.new("Frame")
BackgroundFrame.Size                   = UDim2.fromScale(1, 1)
BackgroundFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
BackgroundFrame.BackgroundTransparency = 1
BackgroundFrame.BorderSizePixel        = 0
BackgroundFrame.Visible                = false
BackgroundFrame.ZIndex                 = 100
BackgroundFrame.Parent                 = ScreenGui

-- Helper UI builders
local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function makeStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(45, 48, 62)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.25
    s.Parent = parent
    return s
end

local allVisualUpdaters = {}
local function updateAllSubToggles()
    for _, fn in ipairs(allVisualUpdaters) do
        pcall(fn)
    end
end
local function recalcMenuHeight() end
local function updateKillButtonPosition() end

-- ==============================================================================
-- UNIVERSAL FLOATING TOGGLE BUTTON (PC & MOBILE)
-- ==============================================================================
local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Name            = "FloatingToggle"
FloatingToggle.AnchorPoint     = Vector2.new(0, 0.5)
FloatingToggle.Position        = UDim2.new(0, 16, 0.5, 0)
FloatingToggle.Size            = UDim2.fromOffset(108, 36)
FloatingToggle.BackgroundColor3= Color3.fromRGB(18, 19, 26)
FloatingToggle.BorderSizePixel = 0
FloatingToggle.Text            = ""
FloatingToggle.AutoButtonColor = false
FloatingToggle.ZIndex          = 250
FloatingToggle.Parent          = ScreenGui

makeCorner(FloatingToggle, 18)
makeStroke(FloatingToggle, THEME_PURPLE, 1.4, 0.2)

local ftIcon = Instance.new("TextLabel", FloatingToggle)
ftIcon.Size                   = UDim2.new(0, 24, 1, 0)
ftIcon.Position               = UDim2.new(0, 8, 0, 0)
ftIcon.BackgroundTransparency = 1
ftIcon.Text                   = "⚡"
ftIcon.TextColor3             = THEME_PURPLE
ftIcon.Font                   = Enum.Font.GothamBold
ftIcon.TextSize               = 14
ftIcon.ZIndex                 = 251

local ftLabel = Instance.new("TextLabel", FloatingToggle)
ftLabel.Size                   = UDim2.new(1, -44, 1, 0)
ftLabel.Position               = UDim2.new(0, 30, 0, 0)
ftLabel.BackgroundTransparency = 1
ftLabel.Text                   = "MENU"
ftLabel.TextColor3             = Color3.fromRGB(240, 240, 245)
ftLabel.Font                   = Enum.Font.GothamBold
ftLabel.TextSize               = 12
ftLabel.TextXAlignment         = Enum.TextXAlignment.Left
ftLabel.ZIndex                 = 251

local ftDot = Instance.new("Frame", FloatingToggle)
ftDot.Size             = UDim2.fromOffset(6, 6)
ftDot.Position         = UDim2.new(1, -14, 0.5, -3)
ftDot.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
ftDot.BorderSizePixel  = 0
ftDot.ZIndex           = 251
makeCorner(ftDot, 3)

-- Floating Toggle Dragging & Interaction
local ftMoved = false
do
    local ftDragging = false
    local ftDragStart, ftStartPos

    FloatingToggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ftDragging  = true
            ftMoved     = false
            ftDragStart = input.Position
            ftStartPos  = FloatingToggle.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    ftDragging = false
                end
            end)
        end
    end)

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if ftDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - ftDragStart
            if delta.Magnitude > 6 then
                ftMoved = true
            end
            FloatingToggle.Position = UDim2.new(
                ftStartPos.X.Scale,
                ftStartPos.X.Offset + delta.X,
                ftStartPos.Y.Scale,
                ftStartPos.Y.Offset + delta.Y
            )
        end
    end))

    FloatingToggle.MouseButton1Click:Connect(function()
        if not ftMoved then
            if toggleMenu then
                toggleMenu()
            end
        end
    end)

    FloatingToggle.MouseEnter:Connect(function()
        TweenService:Create(FloatingToggle, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(28, 30, 42)
        }):Play()
    end)

    FloatingToggle.MouseLeave:Connect(function()
        TweenService:Create(FloatingToggle, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(18, 19, 26)
        }):Play()
    end)
end

-- ==============================================================================
-- KILL CONFIRMATION MODAL
-- ==============================================================================
local function showKillConfirm()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local oldConfirm = playerGui:FindFirstChild("KillConfirmGui")
    if oldConfirm then oldConfirm:Destroy() end

    local confirmGui = Instance.new("ScreenGui")
    confirmGui.Name            = "KillConfirmGui"
    confirmGui.ResetOnSpawn    = false
    confirmGui.IgnoreGuiInset  = true
    confirmGui.DisplayOrder    = 2000
    confirmGui.Parent          = playerGui

    local overlay = Instance.new("Frame")
    overlay.Size                   = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 200
    overlay.Parent                 = confirmGui

    local card = Instance.new("Frame")
    card.AnchorPoint      = Vector2.new(0.5, 0.5)
    card.Position         = UDim2.fromScale(0.5, 0.5)
    card.Size             = UDim2.fromOffset(340, 148)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
    card.BorderSizePixel  = 0
    card.ZIndex           = 201
    card.Parent           = overlay
    makeCorner(card, 14)

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color        = Color3.fromRGB(55, 55, 55)
    cardStroke.Thickness    = 1
    cardStroke.Transparency = 0.1
    cardStroke.Parent       = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size                   = UDim2.new(1, -32, 0, 28)
    titleLabel.Position               = UDim2.new(0, 16, 0, 16)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text                   = "Kill Script"
    titleLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
    titleLabel.Font                   = Enum.Font.GothamBold
    titleLabel.TextSize               = 17
    titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
    titleLabel.ZIndex                 = 202
    titleLabel.Parent                 = card

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.Size                   = UDim2.new(1, -32, 0, 36)
    bodyLabel.Position               = UDim2.new(0, 16, 0, 48)
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Text                   = "This will completely destroy the script and clear the queue chain. You'll need to re-inject to use it again."
    bodyLabel.TextColor3             = Color3.fromRGB(220, 220, 225)
    bodyLabel.Font                   = Enum.Font.GothamMedium
    bodyLabel.TextSize               = 12
    bodyLabel.TextXAlignment         = Enum.TextXAlignment.Left
    bodyLabel.TextWrapped            = true
    bodyLabel.ZIndex                 = 202
    bodyLabel.Parent                 = card

    local divider = Instance.new("Frame")
    divider.Size             = UDim2.new(1, -32, 0, 1)
    divider.Position         = UDim2.new(0, 16, 0, 96)
    divider.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    divider.BorderSizePixel  = 0
    divider.ZIndex           = 202
    divider.Parent           = card

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size             = UDim2.new(0.5, -20, 0, 32)
    cancelBtn.Position         = UDim2.new(0, 16, 0, 105)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    cancelBtn.BorderSizePixel  = 0
    cancelBtn.Text             = "Cancel"
    cancelBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    cancelBtn.Font             = Enum.Font.GothamMedium
    cancelBtn.TextSize         = 13
    cancelBtn.AutoButtonColor  = false
    cancelBtn.ZIndex           = 202
    cancelBtn.Parent           = card
    makeCorner(cancelBtn, 8)

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size             = UDim2.new(0.5, -20, 0, 32)
    confirmBtn.Position         = UDim2.new(0.5, 4, 0, 105)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(140, 28, 28)
    confirmBtn.BorderSizePixel  = 0
    confirmBtn.Text             = "Kill Script"
    confirmBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font             = Enum.Font.GothamBold
    confirmBtn.TextSize         = 13
    confirmBtn.AutoButtonColor  = false
    confirmBtn.ZIndex           = 202
    confirmBtn.Parent           = card
    makeCorner(confirmBtn, 8)

    cancelBtn.MouseButton1Click:Connect(function()
        confirmGui:Destroy()
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        confirmGui:Destroy()
        killScript()
    end)
end

-- ==============================================================================
-- MAIN MENU PANEL
-- ==============================================================================
local PANEL_WIDTH  = 370
local PANEL_HEIGHT = 485

local MenuFrame = Instance.new("Frame")
MenuFrame.Name             = "MainPanel"
MenuFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
MenuFrame.Size             = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
MenuFrame.Position         = UDim2.fromScale(0.5, 0.5)
MenuFrame.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
MenuFrame.BorderSizePixel  = 0
MenuFrame.ClipsDescendants = true
MenuFrame.Visible          = false
MenuFrame.ZIndex           = 110
MenuFrame.Parent           = ScreenGui

makeCorner(MenuFrame, 12)
local MenuStroke = makeStroke(MenuFrame, THEME_PURPLE, 1.4, 0.25)

-- Header Bar / Drag Bar
local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 42)
Header.BackgroundColor3 = Color3.fromRGB(21, 23, 31)
Header.BorderSizePixel  = 0
Header.ZIndex           = 111
Header.Parent           = MenuFrame

makeCorner(Header, 12)

local headerBottomFill = Instance.new("Frame")
headerBottomFill.Size             = UDim2.new(1, 0, 0, 12)
headerBottomFill.Position         = UDim2.new(0, 0, 1, -12)
headerBottomFill.BackgroundColor3 = Color3.fromRGB(21, 23, 31)
headerBottomFill.BorderSizePixel  = 0
headerBottomFill.ZIndex           = 111
headerBottomFill.Parent           = Header

local headerIcon = Instance.new("TextLabel")
headerIcon.Size                   = UDim2.new(0, 24, 1, 0)
headerIcon.Position               = UDim2.new(0, 12, 0, 0)
headerIcon.BackgroundTransparency = 1
headerIcon.Text                   = "⚡"
headerIcon.TextColor3             = THEME_PURPLE
headerIcon.Font                   = Enum.Font.GothamBold
headerIcon.TextSize               = 16
headerIcon.ZIndex                 = 112
headerIcon.Parent                 = Header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size                   = UDim2.new(1, -145, 1, 0)
headerTitle.Position               = UDim2.new(0, 36, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text                   = "ZYR4X HUB • RIVALS"
headerTitle.TextColor3             = Color3.fromRGB(245, 245, 250)
headerTitle.Font                   = Enum.Font.GothamBold
headerTitle.TextSize               = 12
headerTitle.TextXAlignment         = Enum.TextXAlignment.Left
headerTitle.ZIndex                 = 112
headerTitle.Parent                 = Header

-- Window control buttons: Minimize & Close
local minBtn = Instance.new("TextButton")
minBtn.Size             = UDim2.fromOffset(26, 26)
minBtn.Position         = UDim2.new(1, -62, 0.5, -13)
minBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
minBtn.BorderSizePixel  = 0
minBtn.Text             = "-"
minBtn.TextColor3       = Color3.fromRGB(200, 205, 220)
minBtn.Font             = Enum.Font.GothamBold
minBtn.TextSize         = 15
minBtn.AutoButtonColor  = false
minBtn.ZIndex           = 113
minBtn.Parent           = Header
makeCorner(minBtn, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.fromOffset(26, 26)
closeBtn.Position         = UDim2.new(1, -32, 0.5, -13)
closeBtn.BackgroundColor3 = Color3.fromRGB(48, 25, 32)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(255, 100, 120)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 12
closeBtn.AutoButtonColor  = false
closeBtn.ZIndex           = 113
closeBtn.Parent           = Header
makeCorner(closeBtn, 6)

-- Header Dragging
do
    local panelDragging = false
    local panelDragStart, panelStartPos

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            panelDragging  = true
            panelDragStart = input.Position
            panelStartPos  = MenuFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    panelDragging = false
                end
            end)
        end
    end)

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if panelDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - panelDragStart
            MenuFrame.Position = UDim2.new(
                panelStartPos.X.Scale,
                panelStartPos.X.Offset + delta.X,
                panelStartPos.Y.Scale,
                panelStartPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- Body Container
local bodyContainer = Instance.new("Frame")
bodyContainer.Name                   = "BodyContainer"
bodyContainer.Size                   = UDim2.new(1, 0, 1, -42)
bodyContainer.Position               = UDim2.new(0, 0, 0, 42)
bodyContainer.BackgroundTransparency = 1
bodyContainer.BorderSizePixel        = 0
bodyContainer.ZIndex                 = 111
bodyContainer.Parent                 = MenuFrame

-- Tab Bar
local tabBar = Instance.new("Frame")
tabBar.Name             = "TabBar"
tabBar.Size             = UDim2.new(1, -20, 0, 32)
tabBar.Position         = UDim2.new(0, 10, 0, 6)
tabBar.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
tabBar.BorderSizePixel  = 0
tabBar.ZIndex           = 112
tabBar.Parent           = bodyContainer
makeCorner(tabBar, 8)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection       = Enum.FillDirection.Horizontal
tabLayout.SortOrder           = Enum.SortOrder.LayoutOrder
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding             = UDim.new(0, 4)
tabLayout.Parent              = tabBar

local pagesContainer = Instance.new("Frame")
pagesContainer.Name                   = "PagesContainer"
pagesContainer.Size                   = UDim2.new(1, -20, 1, -48)
pagesContainer.Position               = UDim2.new(0, 10, 0, 44)
pagesContainer.BackgroundTransparency = 1
pagesContainer.BorderSizePixel        = 0
pagesContainer.ZIndex                 = 112
pagesContainer.Parent                 = bodyContainer

-- Tab definition & switching
local TABS = {
    { Name = "Combat",  Icon = "⚔️" },
    { Name = "Visuals", Icon = "👁️" },
    { Name = "Misc",    Icon = "⚡" },
    { Name = "System",  Icon = "⚙️" },
}

local tabButtons = {}
local tabPages   = {}

local function switchTab(name)
    for tName, page in pairs(tabPages) do
        page.Visible = (tName == name)
    end
    for tName, btn in pairs(tabButtons) do
        local isActive = (tName == name)
        btn.BackgroundColor3 = isActive and THEME_PURPLE or Color3.fromRGB(25, 27, 36)
        local lbl = btn:FindFirstChildOfClass("TextLabel")
        if lbl then
            lbl.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 155, 170)
        end
    end
end

for i, tabInfo in ipairs(TABS) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name             = "Tab_" .. tabInfo.Name
    tabBtn.Size             = UDim2.new(0.24, -3, 1, -6)
    tabBtn.Position         = UDim2.new(0, 0, 0, 3)
    tabBtn.BackgroundColor3 = (i == 1) and THEME_PURPLE or Color3.fromRGB(25, 27, 36)
    tabBtn.BorderSizePixel  = 0
    tabBtn.Text             = ""
    tabBtn.AutoButtonColor  = false
    tabBtn.LayoutOrder      = i
    tabBtn.ZIndex           = 113
    tabBtn.Parent           = tabBar
    makeCorner(tabBtn, 6)

    local tabLbl = Instance.new("TextLabel")
    tabLbl.Size                   = UDim2.fromScale(1, 1)
    tabLbl.BackgroundTransparency = 1
    tabLbl.Text                   = tabInfo.Name
    tabLbl.TextColor3             = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 155, 170)
    tabLbl.Font                   = Enum.Font.GothamBold
    tabLbl.TextSize               = 11
    tabLbl.ZIndex                 = 114
    tabLbl.Parent                 = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        switchTab(tabInfo.Name)
    end)

    tabButtons[tabInfo.Name] = tabBtn

    -- Page Scrolling Frame
    local page = Instance.new("ScrollingFrame")
    page.Name                   = "Page_" .. tabInfo.Name
    page.Size                   = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel        = 0
    page.ScrollBarThickness     = 3
    page.ScrollBarImageColor3   = THEME_PURPLE
    page.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    page.CanvasSize             = UDim2.new(0, 0, 0, 0)
    page.Visible                = (i == 1)
    page.ZIndex                 = 113
    page.Parent                 = pagesContainer

    local pageList = Instance.new("UIListLayout")
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Padding   = UDim.new(0, 6)
    pageList.Parent    = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingTop    = UDim.new(0, 4)
    pagePad.PaddingBottom = UDim.new(0, 10)
    pagePad.PaddingLeft   = UDim.new(0, 2)
    pagePad.PaddingRight  = UDim.new(0, 6)
    pagePad.Parent        = page

    tabPages[tabInfo.Name] = page
end

-- ==============================================================================
-- COMPONENT BUILDERS (Toggles, Sliders, Selectors, Headers)
-- ==============================================================================
local function createSectionHeader(page, title, order)
    local f = Instance.new("Frame")
    f.Size                   = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.LayoutOrder            = order
    f.ZIndex                 = 113
    f.Parent                 = page

    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text                   = string.upper(title)
    l.TextColor3             = THEME_PURPLE
    l.Font                   = Enum.Font.GothamBold
    l.TextSize               = 10
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.ZIndex                 = 114
    l.Parent                 = f
    return f
end

local function createToggle(page, labelText, getVal, setVal, onChange, order)
    local card = Instance.new("TextButton")
    card.Size             = UDim2.new(1, 0, 0, 38)
    card.BackgroundColor3 = Color3.fromRGB(22, 23, 31)
    card.BorderSizePixel  = 0
    card.Text             = ""
    card.AutoButtonColor  = false
    card.LayoutOrder      = order
    card.ZIndex           = 113
    card.Parent           = page

    makeCorner(card, 8)
    makeStroke(card, Color3.fromRGB(38, 40, 52), 1, 0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -55, 1, 0)
    lbl.Position               = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = Color3.fromRGB(225, 225, 235)
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextSize               = 13
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 114
    lbl.Parent                 = card

    local switchPill = Instance.new("Frame")
    switchPill.Size             = UDim2.fromOffset(36, 18)
    switchPill.Position         = UDim2.new(1, -46, 0.5, -9)
    switchPill.BackgroundColor3 = Color3.fromRGB(36, 38, 48)
    switchPill.BorderSizePixel  = 0
    switchPill.ZIndex           = 114
    switchPill.Parent           = card
    makeCorner(switchPill, 9)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.fromOffset(12, 12)
    knob.Position         = UDim2.new(0, 3, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(130, 135, 150)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 115
    knob.Parent           = switchPill
    makeCorner(knob, 6)

    local function updateVisual()
        local active = getVal()
        if active then
            TweenService:Create(switchPill, TweenInfo.new(0.18), {
                BackgroundColor3 = THEME_PURPLE
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.18), {
                Position         = UDim2.new(1, -15, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.18), {
                TextColor3 = Color3.fromRGB(255, 255, 255)
            }):Play()
        else
            TweenService:Create(switchPill, TweenInfo.new(0.18), {
                BackgroundColor3 = Color3.fromRGB(36, 38, 48)
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.18), {
                Position         = UDim2.new(0, 3, 0.5, -6),
                BackgroundColor3 = Color3.fromRGB(130, 135, 150)
            }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.18), {
                TextColor3 = Color3.fromRGB(200, 200, 215)
            }):Play()
        end
    end

    card.MouseButton1Click:Connect(function()
        local newVal = not getVal()
        setVal(newVal)
        updateVisual()
        saveSettings(Settings)
        if onChange then
            pcall(onChange, newVal)
        end
    end)

    card.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(28, 30, 40)
        }):Play()
    end)

    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(22, 23, 31)
        }):Play()
    end)

    updateVisual()
    table.insert(allVisualUpdaters, updateVisual)
    return card, updateVisual
end

local function createSlider(page, labelText, minVal, maxVal, stepVal, getVal, setVal, unitStr, order)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 50)
    card.BackgroundColor3 = Color3.fromRGB(22, 23, 31)
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.ZIndex           = 113
    card.Parent           = page

    makeCorner(card, 8)
    makeStroke(card, Color3.fromRGB(38, 40, 52), 1, 0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -70, 0, 20)
    lbl.Position               = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = Color3.fromRGB(225, 225, 235)
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextSize               = 12
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 114
    lbl.Parent                 = card

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                   = UDim2.new(0, 60, 0, 20)
    valLbl.Position               = UDim2.new(1, -70, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                   = tostring(getVal()) .. (unitStr and (" " .. unitStr) or "")
    valLbl.TextColor3             = THEME_PURPLE
    valLbl.Font                   = Enum.Font.GothamBold
    valLbl.TextSize               = 12
    valLbl.TextXAlignment         = Enum.TextXAlignment.Right
    valLbl.ZIndex                 = 114
    valLbl.Parent                 = card

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -24, 0, 4)
    track.Position         = UDim2.new(0, 12, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(38, 41, 54)
    track.BorderSizePixel  = 0
    track.ZIndex           = 114
    track.Parent           = card
    makeCorner(track, 2)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = THEME_PURPLE
    fill.BorderSizePixel  = 0
    fill.ZIndex           = 115
    fill.Parent           = track
    makeCorner(fill, 2)

    local thumb = Instance.new("TextButton")
    thumb.Size             = UDim2.fromOffset(14, 14)
    thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
    thumb.Position         = UDim2.new(0, 0, 0.5, 0)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel  = 0
    thumb.Text             = ""
    thumb.AutoButtonColor  = false
    thumb.ZIndex           = 116
    thumb.Parent           = track
    makeCorner(thumb, 7)
    makeStroke(thumb, THEME_PURPLE, 1.5, 0)

    local function updatePosition()
        local current = math.clamp(tonumber(getVal()) or minVal, minVal, maxVal)
        local alpha = math.clamp((current - minVal) / (maxVal - minVal), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
        valLbl.Text = tostring(current) .. (unitStr and (" " .. unitStr) or "")
    end

    local isDragging = false
    local function processInput(inputX)
        local startX = track.AbsolutePosition.X
        local width = track.AbsoluteSize.X
        if width > 0 then
            local rel = math.clamp(inputX - startX, 0, width)
            local alpha = rel / width
            local rawVal = minVal + alpha * (maxVal - minVal)
            local step = stepVal or 1
            local snapped = math.floor((rawVal / step) + 0.5) * step
            snapped = math.clamp(snapped, minVal, maxVal)
            setVal(snapped)
            updatePosition()
            saveSettings(Settings)
        end
    end

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if input.Position.Y >= track.AbsolutePosition.Y - 10 and input.Position.Y <= track.AbsolutePosition.Y + 14 then
                isDragging = true
                processInput(input.Position.X)
            end
        end
    end)

    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end))

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            processInput(input.Position.X)
        end
    end))

    task.defer(updatePosition)
    table.insert(allVisualUpdaters, updatePosition)
    return card, updatePosition
end

local function createSelector(page, labelText, options, getVal, setVal, order)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 38)
    card.BackgroundColor3 = Color3.fromRGB(22, 23, 31)
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.ZIndex           = 113
    card.Parent           = page

    makeCorner(card, 8)
    makeStroke(card, Color3.fromRGB(38, 40, 52), 1, 0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -110, 1, 0)
    lbl.Position               = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = Color3.fromRGB(225, 225, 235)
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.TextSize               = 13
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 114
    lbl.Parent                 = card

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 95, 0, 26)
    btn.Position         = UDim2.new(1, -103, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(32, 34, 46)
    btn.BorderSizePixel  = 0
    btn.Font             = Enum.Font.GothamBold
    btn.Text             = tostring(getVal())
    btn.TextColor3       = THEME_PURPLE
    btn.TextSize         = 11
    btn.AutoButtonColor  = false
    btn.ZIndex           = 115
    btn.Parent           = card
    makeCorner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        local cur = getVal()
        local curIdx = 1
        for i, v in ipairs(options) do
            if v == cur then curIdx = i break end
        end
        local nextIdx = (curIdx % #options) + 1
        setVal(options[nextIdx])
        btn.Text = tostring(options[nextIdx])
        saveSettings(Settings)
    end)

    return card
end

-- ==============================================================================
-- TAB 1: COMBAT PAGE POPULATION
-- ==============================================================================
local combatPage = tabPages["Combat"]

createSectionHeader(combatPage, "Aimbot & Aim Assist", 1)

createToggle(combatPage, "Aimbot Master", function() return Settings.Aimbot_Enabled end, function(v) Settings.Aimbot_Enabled = v end, nil, 2)
createSlider(combatPage, "Aimbot FOV Radius", 20, 500, 5, function() return Settings.Aimbot_FOVRadius end, function(v) Settings.Aimbot_FOVRadius = v end, "px", 3)
createSlider(combatPage, "Aimbot Smoothness", 1, 20, 1, function() return Settings.Aimbot_Smoothness end, function(v) Settings.Aimbot_Smoothness = v end, "", 4)
createToggle(combatPage, "Aimbot Wall Check", function() return Settings.Aimbot_WallCheck end, function(v) Settings.Aimbot_WallCheck = v end, nil, 5)
createSelector(combatPage, "Target Bone", {"Head"}, function() return Settings.Aimbot_TargetPart or "Head" end, function(v) Settings.Aimbot_TargetPart = v end, 6)

createSectionHeader(combatPage, "Silent Aim & Triggerbot", 7)

createToggle(combatPage, "Silent Aim", function() return Settings.SilentAim_Enabled end, function(v) Settings.SilentAim_Enabled = v end, nil, 8)
createSlider(combatPage, "Silent Aim FOV", 20, 500, 5, function() return Settings.SilentAim_FOVRadius or 150 end, function(v) Settings.SilentAim_FOVRadius = v end, "px", 9)
createToggle(combatPage, "Silent Aim Wall Check", function() return Settings.SilentAim_WallCheck end, function(v) Settings.SilentAim_WallCheck = v end, nil, 10)
createToggle(combatPage, "Triggerbot Auto-Fire", function() return Settings.Triggerbot_Enabled end, function(v) Settings.Triggerbot_Enabled = v end, nil, 11)

createSectionHeader(combatPage, "Hitbox & Weapons", 12)

createToggle(combatPage, "Hitbox Expander", function() return Settings.Hitbox_Enabled end, function(v)
    Settings.Hitbox_Enabled = v
    if not v and resetAllHitboxes then
        pcall(resetAllHitboxes)
    end
end, nil, 13)
createSlider(combatPage, "Hitbox Size", 2, 35, 1, function() return Settings.Hitbox_Size or 15 end, function(v) Settings.Hitbox_Size = v end, "studs", 14)
createToggle(combatPage, "Auto Reload Weapon", function() return Settings.AutoReload_Enabled end, function(v) Settings.AutoReload_Enabled = v end, nil, 15)

-- ==============================================================================
-- TAB 2: VISUALS (ESP) PAGE POPULATION
-- ==============================================================================
local visualsPage = tabPages["Visuals"]

createSectionHeader(visualsPage, "ESP Master Control", 1)

createToggle(visualsPage, "ESP Master Enabled", function() return Settings.ESP_Enabled end, function(v) Settings.ESP_Enabled = v end, nil, 2)

createSectionHeader(visualsPage, "ESP Elements", 3)

createToggle(visualsPage, "Player Highlights (Chams)", function() return Settings.ESP_Highlight end, function(v) Settings.ESP_Highlight = v end, nil, 4)
createToggle(visualsPage, "Player Names", function() return Settings.ESP_Name end, function(v) Settings.ESP_Name = v end, nil, 5)
createToggle(visualsPage, "Distance Indicators (Studs)", function() return Settings.ESP_Studs end, function(v) Settings.ESP_Studs = v end, nil, 6)
createToggle(visualsPage, "Enemy Tracers", function() return Settings.ESP_Tracer end, function(v) Settings.ESP_Tracer = v end, nil, 7)

-- ==============================================================================
-- TAB 3: MISC PAGE POPULATION
-- ==============================================================================
local miscPage = tabPages["Misc"]

createSectionHeader(miscPage, "Movement", 1)

createToggle(miscPage, "Infinite Jump", function() return Settings.InfJump_Enabled end, function(v) Settings.InfJump_Enabled = v end, nil, 2)

createSectionHeader(miscPage, "Device Emulation", 3)

local SPOOFER_DEVICES = {
    { label = "🖥️  PC (Mouse & Keyboard)", value = "MouseKeyboard" },
    { label = "🎮  Console (Gamepad)",       value = "Gamepad" },
    { label = "📱  Mobile (Touch Device)",    value = "Touch" },
    { label = "🥽  VR Headset",               value = "VR" },
}

local spooferCard = Instance.new("Frame")
spooferCard.Size             = UDim2.new(1, 0, 0, 185)
spooferCard.BackgroundColor3 = Color3.fromRGB(22, 23, 31)
spooferCard.BorderSizePixel  = 0
spooferCard.LayoutOrder      = 4
spooferCard.ZIndex           = 113
spooferCard.Parent           = miscPage
makeCorner(spooferCard, 8)
makeStroke(spooferCard, Color3.fromRGB(38, 40, 52), 1, 0.4)

local spooferTitle = Instance.new("TextLabel", spooferCard)
spooferTitle.Size                   = UDim2.new(1, -20, 0, 24)
spooferTitle.Position               = UDim2.new(0, 10, 0, 6)
spooferTitle.BackgroundTransparency = 1
spooferTitle.Text                   = "Device Spoofer Status"
spooferTitle.TextColor3             = Color3.fromRGB(225, 225, 235)
spooferTitle.Font                   = Enum.Font.GothamBold
spooferTitle.TextSize               = 12
spooferTitle.TextXAlignment         = Enum.TextXAlignment.Left
spooferTitle.ZIndex                 = 114

local spooferStatusBadge = Instance.new("TextLabel", spooferCard)
spooferStatusBadge.Size                   = UDim2.new(1, -20, 0, 16)
spooferStatusBadge.Position               = UDim2.new(0, 10, 0, 28)
spooferStatusBadge.BackgroundTransparency = 1
spooferStatusBadge.Text                   = "Active: " .. (Settings.DeviceSpoofer_Active or "Default")
spooferStatusBadge.TextColor3             = THEME_PURPLE
spooferStatusBadge.Font                   = Enum.Font.GothamMedium
spooferStatusBadge.TextSize               = 11
spooferStatusBadge.TextXAlignment         = Enum.TextXAlignment.Left
spooferStatusBadge.ZIndex                 = 114

local spooferBtnsList = Instance.new("Frame", spooferCard)
spooferBtnsList.Size                   = UDim2.new(1, -20, 0, 130)
spooferBtnsList.Position               = UDim2.new(0, 10, 0, 48)
spooferBtnsList.BackgroundTransparency = 1
spooferBtnsList.ZIndex                 = 114

local spooferLayout = Instance.new("UIListLayout", spooferBtnsList)
spooferLayout.Padding   = UDim.new(0, 4)
spooferLayout.SortOrder = Enum.SortOrder.LayoutOrder

local spooferButtonUpdaters = {}

for idx, dev in ipairs(SPOOFER_DEVICES) do
    local dBtn = Instance.new("TextButton", spooferBtnsList)
    dBtn.Size             = UDim2.new(1, 0, 0, 28)
    dBtn.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
    dBtn.BorderSizePixel  = 0
    dBtn.Text             = ""
    dBtn.AutoButtonColor  = false
    dBtn.LayoutOrder      = idx
    dBtn.ZIndex           = 115
    makeCorner(dBtn, 6)

    local dLbl = Instance.new("TextLabel", dBtn)
    dLbl.Size                   = UDim2.new(1, -30, 1, 0)
    dLbl.Position               = UDim2.new(0, 10, 0, 0)
    dLbl.BackgroundTransparency = 1
    dLbl.Text                   = dev.label
    dLbl.TextColor3             = Color3.fromRGB(205, 205, 220)
    dLbl.Font                   = Enum.Font.GothamMedium
    dLbl.TextSize               = 11
    dLbl.TextXAlignment         = Enum.TextXAlignment.Left
    dLbl.ZIndex                 = 116

    local dDot = Instance.new("Frame", dBtn)
    dDot.Size             = UDim2.fromOffset(8, 8)
    dDot.Position         = UDim2.new(1, -16, 0.5, -4)
    dDot.BackgroundColor3 = Color3.fromRGB(50, 52, 65)
    dDot.BorderSizePixel  = 0
    dDot.ZIndex           = 116
    makeCorner(dDot, 4)

    local function updateDevBtn()
        local isCurrent = (Settings.DeviceSpoofer_Active == dev.value)
        dDot.BackgroundColor3 = isCurrent and THEME_PURPLE or Color3.fromRGB(50, 52, 65)
        dBtn.BackgroundColor3 = isCurrent and Color3.fromRGB(36, 32, 52) or Color3.fromRGB(28, 30, 40)
        dLbl.TextColor3       = isCurrent and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 185, 200)
    end

    dBtn.MouseButton1Click:Connect(function()
        if Settings.DeviceSpoofer_Active == dev.value then
            Settings.DeviceSpoofer_Active = nil
            pcall(function()
                if SetControlsRemote then
                    SetControlsRemote:FireServer("MouseKeyboard")
                end
            end)
            spooferStatusBadge.Text = "Active: Default"
        else
            Settings.DeviceSpoofer_Active = dev.value
            spoofDevice(dev.value)
            spooferStatusBadge.Text = "Active: " .. dev.value
        end

        for _, fn in ipairs(spooferButtonUpdaters) do fn() end
        saveSettings(Settings)
    end)

    updateDevBtn()
    table.insert(spooferButtonUpdaters, updateDevBtn)
end

-- ==============================================================================
-- TAB 4: SYSTEM PAGE POPULATION
-- ==============================================================================
local systemPage = tabPages["System"]

createSectionHeader(systemPage, "Script Information", 1)

local function makeInfoRow(page, labelText, valueText, order)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 34)
    card.BackgroundColor3 = Color3.fromRGB(22, 23, 31)
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.ZIndex           = 113
    card.Parent           = page
    makeCorner(card, 8)
    makeStroke(card, Color3.fromRGB(38, 40, 52), 1, 0.4)

    local l = Instance.new("TextLabel", card)
    l.Size                   = UDim2.new(0.5, -10, 1, 0)
    l.Position               = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text                   = labelText
    l.TextColor3             = Color3.fromRGB(170, 175, 190)
    l.Font                   = Enum.Font.GothamMedium
    l.TextSize               = 12
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.ZIndex                 = 114

    local r = Instance.new("TextLabel", card)
    r.Size                   = UDim2.new(0.5, -10, 1, 0)
    r.Position               = UDim2.new(0.5, -2, 0, 0)
    r.BackgroundTransparency = 1
    r.Text                   = valueText
    r.TextColor3             = Color3.fromRGB(240, 240, 245)
    r.Font                   = Enum.Font.GothamBold
    r.TextSize               = 12
    r.TextXAlignment         = Enum.TextXAlignment.Right
    r.ZIndex                 = 114
    return card
end

makeInfoRow(systemPage, "Status", "🟢 Active", 2)
makeInfoRow(systemPage, "Hotkeys", "Right Control / Insert / Shift", 3)
makeInfoRow(systemPage, "Floating Button", "⚡ Click or Drag", 4)
makeInfoRow(systemPage, "Author", "Zyr4x", 5)

createSectionHeader(systemPage, "Danger Zone", 6)

local killCard = Instance.new("TextButton")
killCard.Size             = UDim2.new(1, 0, 0, 38)
killCard.BackgroundColor3 = Color3.fromRGB(48, 22, 26)
killCard.BorderSizePixel  = 0
killCard.Text             = "💀  KILL SCRIPT"
killCard.TextColor3       = Color3.fromRGB(255, 110, 120)
killCard.Font             = Enum.Font.GothamBold
killCard.TextSize         = 13
killCard.AutoButtonColor  = false
killCard.LayoutOrder      = 7
killCard.ZIndex           = 113
killCard.Parent           = systemPage
makeCorner(killCard, 8)
makeStroke(killCard, Color3.fromRGB(160, 45, 55), 1, 0.3)

killCard.MouseButton1Click:Connect(function()
    showKillConfirm()
end)

killCard.MouseEnter:Connect(function()
    TweenService:Create(killCard, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(70, 25, 30)
    }):Play()
end)

killCard.MouseLeave:Connect(function()
    TweenService:Create(killCard, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(48, 22, 26)
    }):Play()
end)

-- Minimize & Close button connections
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        bodyContainer.Visible = false
        MenuFrame.Size = UDim2.fromOffset(PANEL_WIDTH, 42)
        minBtn.Text = "+"
    else
        MenuFrame.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
        bodyContainer.Visible = true
        minBtn.Text = "-"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    if closeMenu then
        closeMenu()
    else
        MenuFrame.Visible = false
    end
end)

local teamCache     = {}
local teamCacheTime = {}
local TEAM_CACHE_DURATION = 0.15

local function normalizeTeamValue(value)
    if value == nil then
        return nil
    end

    local valueType = typeof(value)

    if valueType == "Instance" then
        return value
    end

    if valueType == "Color3" then
        return string.format(
            "color:%.4f:%.4f:%.4f",
            value.R,
            value.G,
            value.B
        )
    end

    if valueType == "BrickColor" then
        return "brick:" .. value.Name
    end

    if valueType == "string" then
        return value == ""
            and nil
            or "string:" .. value
    end

    if valueType == "number" then
        return "number:" .. tostring(value)
    end

    if valueType == "boolean" then
        return "boolean:" .. tostring(value)
    end

    return nil
end

local function isTeamName(name)
    if typeof(name) ~= "string" then
        return false
    end

    local lowered = string.gsub(
        string.lower(name),
        "[%s_%-]",
        ""
    )

    return lowered == "team"
        or lowered == "teamid"
        or lowered == "teamidentifier"
        or lowered == "teamindex"
        or lowered == "teamcolor"
        or lowered == "teamcolour"
        or string.find(
            lowered,
            "teamid",
            1,
            true
        ) ~= nil
end

local function getTeamFromAttributes(container)
    if not container then
        return nil
    end

    local ok, attrs = pcall(function()
        return container:GetAttributes()
    end)

    if not ok or not attrs then
        return nil
    end

    for name, value in pairs(attrs) do
        if isTeamName(name) then
            local n = normalizeTeamValue(value)

            if n ~= nil then
                return n
            end
        end
    end

    return nil
end

local function getTeamFromValues(container)
    if not container then
        return nil
    end

    local ok, children = pcall(function()
        return container:GetChildren()
    end)

    if not ok or not children then
        return nil
    end

    for _, object in ipairs(children) do
        if isTeamName(object.Name) then
            local n = normalizeTeamValue(object.Value)

            if n then
                return n
            end
        end
    end

    return nil
end

local function getRivalsTeamSignature(player)
    if not player then
        return nil
    end

    local now = os.clock()

    if teamCache[player] ~= nil
    and teamCacheTime[player]
    and now - teamCacheTime[player]
        < TEAM_CACHE_DURATION then
        return teamCache[player]
    end

    local signature =
        player.Team
        or getTeamFromAttributes(player)
        or getTeamFromValues(player)
        or (
            player.Character
            and getTeamFromAttributes(player.Character)
        )
        or (
            player.Character
            and getTeamFromValues(player.Character)
        )

    if not signature then
        local ok, tc = pcall(function()
            return player.TeamColor
        end)

        if ok and tc then
            local colorName = tc.Name

            if colorName
            and colorName ~= "Medium stone grey" then
                signature = "brick:" .. colorName
            end
        end
    end

    teamCache[player]     = signature
    teamCacheTime[player] = now

    return signature
end

local function clearTeamCache(player)
    teamCache[player]     = nil
    teamCacheTime[player] = nil
end

trackConn(Players.PlayerAdded:Connect(function(player)
    clearTeamCache(player)

    trackConn(
        player:GetPropertyChangedSignal("Team"):Connect(
            function()
                clearTeamCache(player)
            end
        )
    )

    trackConn(
        player:GetPropertyChangedSignal("TeamColor"):Connect(
            function()
                clearTeamCache(player)
            end
        )
    )

    trackConn(
        player.CharacterAdded:Connect(function()
            clearTeamCache(player)
        end)
    )
end))

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        trackConn(
            player:GetPropertyChangedSignal("Team"):Connect(
                function()
                    clearTeamCache(player)
                end
            )
        )

        trackConn(
            player:GetPropertyChangedSignal("TeamColor"):Connect(
                function()
                    clearTeamCache(player)
                end
            )
        )

        trackConn(
            player.CharacterAdded:Connect(function()
                clearTeamCache(player)
            end)
        )
    end
end

trackConn(Players.PlayerRemoving:Connect(function(player)
    clearTeamCache(player)
end))

local function isTeammate(player)
    if not player or player == LocalPlayer then
        return true
    end

    local ok1, lTeam = pcall(function()
        return LocalPlayer.Team
    end)

    local ok2, pTeam = pcall(function()
        return player.Team
    end)

    if ok1 and ok2 and lTeam and pTeam then
        return lTeam == pTeam
    end

    local ls = getRivalsTeamSignature(LocalPlayer)
    local ts = getRivalsTeamSignature(player)

    if ls ~= nil and ts ~= nil then
        if typeof(ls) == "Instance"
        and typeof(ts) == "Instance" then
            return ls == ts
        end

        return tostring(ls) == tostring(ts)
    end

    local ok3, ltc = pcall(function()
        return LocalPlayer.TeamColor
    end)

    local ok4, ptc = pcall(function()
        return player.TeamColor
    end)

    if ok3 and ok4 and ltc and ptc then
        local lc = ltc.Name
        local tc = ptc.Name

        if lc ~= "Medium stone grey"
        and tc ~= "Medium stone grey" then
            return lc == tc
        end
    end

    return false
end

local function isEnemy(player)
    if not player or player == LocalPlayer then
        return false
    end

    return not isTeammate(player)
end

local cachedEnemies   = {}
local enemyCacheTime  = 0
local ENEMY_CACHE_TTL = 0.08

local function getEnemies()
    local now = os.clock()

    if now - enemyCacheTime < ENEMY_CACHE_TTL then
        return cachedEnemies
    end

    local result = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
        and player.Character
        and isEnemy(player) then
            local humanoid =
                player.Character:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > 0 then
                table.insert(result, player)
            end
        end
    end

    cachedEnemies  = result
    enemyCacheTime = now

    return result
end

local originalPartProps = {}

local function resetHitboxForPlayer(player)
    local char = player.Character
    if not char then return end

    local props = originalPartProps[player]
    if not props then return end

    for partName, data in pairs(props) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            pcall(function()
                part.Size         = data.Size
                part.Transparency = data.Transparency
                part.CanCollide   = data.CanCollide
            end)
        end
    end

    originalPartProps[player] = nil
end

resetAllHitboxes = function()
    for player, _ in pairs(originalPartProps) do
        resetHitboxForPlayer(player)
    end
    originalPartProps = {}
end

local function updateHitboxes()
    if not Settings.Hitbox_Enabled then
        if next(originalPartProps) ~= nil then
            resetAllHitboxes()
        end
        return
    end

    local sizeVal = tonumber(Settings.Hitbox_Size) or 15
    local expandSize = Vector3.new(sizeVal, sizeVal, sizeVal)

    for _, player in ipairs(getEnemies()) do
        local char = player.Character
        if char then
            local part = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
            if part and part:IsA("BasePart") then
                if not originalPartProps[player] then
                    originalPartProps[player] = {}
                end

                if not originalPartProps[player][part.Name] then
                    originalPartProps[player][part.Name] = {
                        Size         = part.Size,
                        Transparency = part.Transparency,
                        CanCollide   = part.CanCollide,
                    }
                end

                pcall(function()
                    part.Size         = expandSize
                    part.Transparency = 0.6
                    part.CanCollide   = false
                end)
            end
        end
    end
end

local raycastBlacklistDirty = true

trackConn(Players.PlayerRemoving:Connect(function(player)
    resetHitboxForPlayer(player)
    enemyCacheTime        = 0
    raycastBlacklistDirty = true
end))

trackConn(Players.PlayerAdded:Connect(function()
    enemyCacheTime        = 0
    raycastBlacklistDirty = true
end))

local function getCrosshairPosition()
    if not Camera then
        return Vector2.new(0, 0)
    end

    if UserInputService.MouseBehavior
        == Enum.MouseBehavior.LockCenter then
        local vp = Camera.ViewportSize

        return Vector2.new(
            vp.X / 2,
            vp.Y / 2
        )
    end

    return UserInputService:GetMouseLocation()
end

local function worldToScreen(position)
    if not Camera then
        return nil, false
    end

    local ok, result = pcall(function()
        return Camera:WorldToScreenPoint(position)
    end)

    if not ok or not result then
        return nil, false
    end

    return Vector2.new(
        result.X,
        result.Y
    ), result.Z > 0
end

local sharedRaycastParams = RaycastParams.new()
sharedRaycastParams.FilterType =
    Enum.RaycastFilterType.Blacklist

local raycastBlacklistTime = 0

local function getSharedRaycastParams(targetCharacter)
    local now = os.clock()

    if raycastBlacklistDirty
    or now - raycastBlacklistTime > 0.5 then
        local blacklist = {}

        if LocalPlayer.Character then
            table.insert(
                blacklist,
                LocalPlayer.Character
            )
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer
            and player.Character
            and player.Character ~= targetCharacter then
                table.insert(
                    blacklist,
                    player.Character
                )
            end
        end

        sharedRaycastParams.FilterDescendantsInstances =
            blacklist

        raycastBlacklistDirty = false
        raycastBlacklistTime  = now
    end

    return sharedRaycastParams
end

local function hasLineOfSight(targetPart)
    if not targetPart or not Camera then
        return false
    end

    local partParent = targetPart.Parent

    if not partParent then
        return false
    end

    local cameraPos = Camera.CFrame.Position

    local ok_pos, targetPos = pcall(function()
        return targetPart.Position
    end)

    if not ok_pos then
        return false
    end

    local offset   = targetPos - cameraPos
    local distance = offset.Magnitude

    if distance <= 0 then
        return false
    end

    local params =
        getSharedRaycastParams(partParent)

    local ok, rayResult = pcall(function()
        return workspace:Raycast(
            cameraPos,
            offset.Unit * distance,
            params
        )
    end)

    if not ok then
        return true
    end

    if not rayResult
    or not rayResult.Instance then
        return true
    end

    return rayResult.Instance:IsDescendantOf(
        partParent
    )
end

trackConn(UserInputService.JumpRequest:Connect(function()
    if Settings.InfJump_Enabled then
        local character = LocalPlayer.Character

        if character then
            local humanoid =
                character:FindFirstChildOfClass("Humanoid")

            if humanoid then
                humanoid:ChangeState(
                    Enum.HumanoidStateType.Jumping
                )
            end
        end
    end
end))

local lockedTarget = nil

local function getAimTarget()
    local crosshair = getCrosshairPosition()
    local localChar = LocalPlayer.Character

    if not localChar then
        return nil
    end

    local localRoot =
        localChar:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return nil
    end

    local targetPartName = Settings.Aimbot_TargetPart or "Head"

    if lockedTarget then
        if not isEnemy(lockedTarget) then
            lockedTarget = nil
        else
            local character = lockedTarget.Character
            local aimPart =
                character
                and (character:FindFirstChild(targetPartName)
                    or character:FindFirstChild("Head"))
            local humanoid =
                character
                and character:FindFirstChildOfClass("Humanoid")

            if aimPart
            and humanoid
            and humanoid.Health > 0 then
                local dist =
                    (
                        localRoot.Position
                        - aimPart.Position
                    ).Magnitude

                if dist > Settings.Triggerbot_MaxDistance then
                    lockedTarget = nil
                elseif Settings.Aimbot_WallCheck
                and not hasLineOfSight(aimPart) then
                    lockedTarget = nil
                else
                    return aimPart
                end
            else
                lockedTarget = nil
            end
        end
    end

    local bestPlayer
    local bestDist = math.huge

    for _, player in ipairs(getEnemies()) do
        local character = player.Character

        if not character then
            continue
        end

        local aimPart = character:FindFirstChild(targetPartName)
            or character:FindFirstChild("Head")

        if not aimPart then
            continue
        end

        local dist3d =
            (
                localRoot.Position
                - aimPart.Position
            ).Magnitude

        if dist3d > Settings.Triggerbot_MaxDistance then
            continue
        end

        local screenPos, onScreen =
            worldToScreen(aimPart.Position)

        if screenPos and onScreen then
            local dist2d =
                (screenPos - crosshair).Magnitude

            if dist2d <= Settings.Aimbot_FOVRadius then
                if Settings.Aimbot_WallCheck
                and not hasLineOfSight(aimPart) then
                    continue
                end

                if dist2d < bestDist then
                    bestDist   = dist2d
                    bestPlayer = player
                end
            end
        end
    end

    if bestPlayer then
        lockedTarget = bestPlayer

        local character = bestPlayer.Character
        return character
            and (character:FindFirstChild(targetPartName)
                or character:FindFirstChild("Head"))
    end

    return nil
end

local isSilentAimChecking = false

local function getSilentAimTarget()
    if not Settings.SilentAim_Enabled or isSilentAimChecking then
        return nil
    end

    isSilentAimChecking = true
    local ok, bestPart = pcall(function()
        local localChar = LocalPlayer.Character
        if not localChar then return nil end

        local localRoot = localChar:FindFirstChild("HumanoidRootPart")
        if not localRoot then return nil end

        local crosshair = getCrosshairPosition()
        local targetPartName = Settings.Aimbot_TargetPart or "Head"
        local foundPart = nil
        local bestDist = Settings.SilentAim_FOVRadius or 150

        for _, player in ipairs(getEnemies()) do
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local part = character:FindFirstChild(targetPartName) or character:FindFirstChild("Head")
                    if part then
                        if not Settings.SilentAim_WallCheck or hasLineOfSight(part) then
                            local screenPos, onScreen = worldToScreen(part.Position)
                            if onScreen and screenPos then
                                local dist2d = (screenPos - crosshair).Magnitude
                                if dist2d <= bestDist then
                                    bestDist = dist2d
                                    foundPart = part
                                end
                            end
                        end
                    end
                end
            end
        end

        return foundPart
    end)
    isSilentAimChecking = false

    if ok then
        return bestPart
    end
    return nil
end

local function getTargetPart(character)
    if not character then
        return nil
    end

    local partName = Settings.Aimbot_TargetPart or "Head"
    local part = character:FindFirstChild(partName)

    if not part then
        part = character:FindFirstChild("Head")
    end

    return part
end

local function forceAimAtHead(head)
    if not head
    or not head.Parent
    or not Camera then
        return false
    end

    local character = LocalPlayer.Character

    if not character then
        return false
    end

    local rootPart =
        character:FindFirstChild("HumanoidRootPart")

    if not rootPart then
        return false
    end

    local ok, headPos = pcall(function()
        return head.Position
    end)

    if not ok then
        return false
    end

    local camPos = Camera.CFrame.Position

    local targetCFrame = CFrame.lookAt(
        camPos,
        headPos,
        Vector3.new(0, 1, 0)
    )

    local smoothness = Settings.Aimbot_Smoothness or 1
    local alpha = math.clamp(1 / math.max(smoothness, 1), 0.01, 1)

    if smoothness <= 1 then
        Camera.CFrame = targetCFrame
    else
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, alpha)
    end

    return true
end

local function updateLockedBody()
    if not Settings.Aimbot_Enabled
    or not lockedTarget then
        return
    end

    if not isEnemy(lockedTarget) then
        lockedTarget = nil
        return
    end

    local character = lockedTarget.Character

    local targetPartName = Settings.Aimbot_TargetPart or "Head"
    local aimPart =
        character
        and (character:FindFirstChild(targetPartName)
            or character:FindFirstChild("Head"))

    local humanoid =
        character
        and character:FindFirstChildOfClass("Humanoid")

    if not character
    or not aimPart
    or not humanoid
    or humanoid.Health <= 0 then
        lockedTarget = nil
        return
    end

    local localChar = LocalPlayer.Character

    if localChar then
        local localRoot =
            localChar:FindFirstChild("HumanoidRootPart")

        if localRoot then
            local ok, partPos = pcall(function()
                return aimPart.Position
            end)

            if ok
            and (
                localRoot.Position - partPos
            ).Magnitude > Settings.Triggerbot_MaxDistance then
                lockedTarget = nil
                return
            end
        end
    end

    if Settings.Aimbot_WallCheck
    and not hasLineOfSight(aimPart) then
        lockedTarget = nil
        return
    end

    forceAimAtHead(aimPart)
end

local HITBOX_PARTS = {
    "Head",
    "UpperTorso",
    "LowerTorso",
    "HumanoidRootPart",
    "LeftUpperArm",
    "RightUpperArm",
    "LeftLowerArm",
    "RightLowerArm",
    "LeftUpperLeg",
    "RightUpperLeg",
    "LeftLowerLeg",
    "RightLowerLeg",
}

local function getHitboxScreenBounds(part)
    if not Camera
    or not part
    or not part.Parent then
        return nil
    end

    local ok, cf, size = pcall(function()
        return part.CFrame,
            part.Size * 0.5
    end)

    if not ok
    or not cf
    or not size then
        return nil
    end

    local sx, sy, sz =
        size.X,
        size.Y,
        size.Z

    local corners = {
        cf * Vector3.new( sx,  sy,  sz),
        cf * Vector3.new(-sx,  sy,  sz),
        cf * Vector3.new( sx, -sy,  sz),
        cf * Vector3.new(-sx, -sy,  sz),
        cf * Vector3.new( sx,  sy, -sz),
        cf * Vector3.new(-sx,  sy, -sz),
        cf * Vector3.new( sx, -sy, -sz),
        cf * Vector3.new(-sx, -sy, -sz),
    }

    local minX, minY =
        math.huge,
        math.huge

    local maxX, maxY =
        -math.huge,
        -math.huge

    local anyOnScreen = false

    for _, corner in ipairs(corners) do
        local ok2, result = pcall(function()
            return Camera:WorldToScreenPoint(corner)
        end)

        if ok2
        and result
        and result.Z > 0 then
            anyOnScreen = true

            if result.X < minX then
                minX = result.X
            end

            if result.Y < minY then
                minY = result.Y
            end

            if result.X > maxX then
                maxX = result.X
            end

            if result.Y > maxY then
                maxY = result.Y
            end
        end
    end

    if not anyOnScreen then
        return nil
    end

    return minX,
        minY,
        maxX,
        maxY
end

local function shouldFire()
    if not Camera then
        return false
    end

    if not isInActiveRound() then
        return false
    end

    if Settings.Aimbot_Enabled
    and lockedTarget
    and isEnemy(lockedTarget) then
        local character = lockedTarget.Character

        local targetPartName = Settings.Aimbot_TargetPart or "Head"
        local aimPart =
            character
            and (character:FindFirstChild(targetPartName)
                or character:FindFirstChild("Head"))

        local humanoid =
            character
            and character:FindFirstChildOfClass("Humanoid")

        if aimPart
        and humanoid
        and humanoid.Health > 0 then
            local los = hasLineOfSight(aimPart)

            if los then
                local aimed = forceAimAtHead(aimPart)

                if aimed then
                    return true
                end
            else
                lockedTarget = nil
            end
        else
            lockedTarget = nil
        end
    end

    if not Settings.Triggerbot_Enabled then
        return false
    end

    local crosshair = getCrosshairPosition()

    local cx, cy =
        crosshair.X,
        crosshair.Y

    local camPos =
        Camera.CFrame.Position

    for _, player in ipairs(getEnemies()) do
        local character = player.Character

        if not character then
            continue
        end

        local humanoid =
            character:FindFirstChildOfClass("Humanoid")

        if not humanoid
        or humanoid.Health <= 0 then
            continue
        end

        local root =
            character:FindFirstChild("HumanoidRootPart")

        if not root
        or not root.Parent then
            continue
        end

        local ok_rp, rootPos = pcall(function()
            return root.Position
        end)

        if not ok_rp then
            continue
        end

        local _, rootOnScreen = worldToScreen(rootPos)
        if not rootOnScreen then
            continue
        end

        for _, partName in ipairs(HITBOX_PARTS) do
            local part =
                character:FindFirstChild(partName)

            if part then
                local minX,
                    minY,
                    maxX,
                    maxY =
                    getHitboxScreenBounds(part)

                if minX
                and cx >= minX
                and cx <= maxX
                and cy >= minY
                and cy <= maxY then
                    if hasLineOfSight(part) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function getTracerLine(player)
    if tracerLines[player] then
        return tracerLines[player]
    end

    local ok, result = pcall(function()
        local d = Drawing.new("Line")

        d.Thickness    = 1.5
        d.Color        = Color3.fromRGB(255, 255, 255)
        d.Transparency = 1
        d.Visible      = false

        return d
    end)

    if ok and result then
        tracerLines[player] = result
        return result
    end

    return nil
end

local function removeTracerLine(player)
    local line = tracerLines[player]

    if line then
        tracerLines[player] = nil

        pcall(function()
            line.Visible = false
            line:Remove()
        end)
    end
end

local function hideTracerLines()
    for _, line in pairs(tracerLines) do
        pcall(function()
            line.Visible = false
        end)
    end
end

trackConn(Players.PlayerRemoving:Connect(function(player)
    removeTracerLine(player)
    clearTeamCache(player)

    enemyCacheTime        = 0
    raycastBlacklistDirty = true
end))

local function updateTracer()
    if not Settings.ESP_Enabled
    or not Settings.ESP_Tracer
    or (MenuFrame.Visible and not isMinimized) then
        hideTracerLines()
        return
    end

    local localCharacter = LocalPlayer.Character

    local localRoot =
        localCharacter
        and localCharacter:FindFirstChild(
            "HumanoidRootPart"
        )

    if not localRoot or not Camera then
        hideTracerLines()
        return
    end

    local vp     = Camera.ViewportSize
    local origin = Vector2.new(
        vp.X / 2,
        vp.Y / 2
    )

    local seen = {}

    for _, player in ipairs(getEnemies()) do
        local character = player.Character

        local humanoid =
            character
            and character:FindFirstChildOfClass("Humanoid")

        local root =
            character
            and character:FindFirstChild(
                "HumanoidRootPart"
            )

        if humanoid
        and humanoid.Health > 0
        and root then
            local ok_rp, rootPos = pcall(function()
                return root.Position
            end)

            if ok_rp
            and (
                rootPos - localRoot.Position
            ).Magnitude <= 1000 then
                local head =
                    character:FindFirstChild("Head")

                local ok_hp, targetPos = pcall(function()
                    return head
                        and head.Position
                        or root.Position
                end)

                if ok_hp then
                    local ok_sp, sp = pcall(function()
                        return Camera:WorldToViewportPoint(
                            targetPos
                        )
                    end)

                    if ok_sp and sp.Z > 0 then
                        local line =
                            getTracerLine(player)

                        if line then
                            line.From    = origin
                            line.To      = Vector2.new(
                                sp.X,
                                sp.Y
                            )
                            line.Visible = true
                            seen[player] = true
                        end
                    end
                end
            end
        end
    end

    for player, line in pairs(tracerLines) do
        if not seen[player] then
            pcall(function()
                line.Visible = false
            end)
        end
    end
end

pcall(function()
    if Drawing then
        circleDraw =
            Drawing.new("Circle")

        circleDraw.Thickness = 2
        circleDraw.Color =
            THEME_PURPLE
        circleDraw.Filled = false
        circleDraw.Visible = false
    end
end)

local function updateCircle()
    if not circleDraw then
        return
    end

    if Settings.Aimbot_Enabled
    and (not MenuFrame.Visible or isMinimized) then
        circleDraw.Position =
            getCrosshairPosition()

        circleDraw.Radius =
            Settings.Aimbot_FOVRadius

        circleDraw.Visible = true
    else
        circleDraw.Visible = false
    end
end

local tabHeld = false

local function holdTab()
    if not tabHeld then
        VirtualInputManager:SendKeyEvent(
            true,
            Enum.KeyCode.Tab,
            false,
            game
        )

        tabHeld = true
    end
end

releaseTab = function()
    if tabHeld then
        VirtualInputManager:SendKeyEvent(
            false,
            Enum.KeyCode.Tab,
            false,
            game
        )

        tabHeld = false
    end
end

local AutoclickActive = false

closeMenu = function()
    if not MenuFrame.Visible then
        return
    end

    MenuFrame.Visible       = false
    if BackgroundFrame then
        BackgroundFrame.Visible = false
    end
    if Watermark then
        Watermark.Visible = false
    end
    AutoclickActive = false

    releaseTab()
end

openMenu = function()
    if MenuFrame.Visible then
        return
    end

    MenuFrame.Visible       = true
    if BackgroundFrame then
        BackgroundFrame.Visible = false
    end
    if Watermark then
        Watermark.Visible = false
    end
    lockedTarget            = nil
    AutoclickActive         = false

    hideTracerLines()
    updateAllSubToggles()
    holdTab()
end

toggleMenu = function()
    if MenuFrame.Visible then
        closeMenu()
    else
        openMenu()
    end
end

trackConn(UserInputService.InputBegan:Connect(
    function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.RightControl
        or input.KeyCode == Enum.KeyCode.Insert
        or input.KeyCode == Enum.KeyCode.RightShift then
            toggleMenu()
            return
        end
    end
))

local function removeESPObjects(character)
    if not character then
        return
    end

    for _, name in ipairs({
        "ESP_Highlight",
        "ESP_Billboard",
        "ESP_HealthBar",
        "HealthBackground",
        "HealthOutline"
    }) do
        local obj =
            character:FindFirstChild(name)

        if obj then
            obj:Destroy()
        end
    end
end

local ESP_GUI_WIDTH     = 220
local ESP_GUI_HEIGHT    = 58
local HEALTH_BAR_WIDTH  = 120
local HEALTH_BAR_HEIGHT = 7

local function createESPBillboard(
    character,
    head
)
    local billboard = Instance.new("BillboardGui")

    billboard.Name =
        "ESP_Billboard"

    billboard.Adornee =
        head

    billboard.AlwaysOnTop =
        true

    billboard.LightInfluence =
        0

    billboard.MaxDistance =
        Settings.ESP_MaxDistance

    billboard.Size =
        UDim2.fromOffset(
            ESP_GUI_WIDTH,
            ESP_GUI_HEIGHT
        )

    billboard.StudsOffsetWorldSpace =
        Vector3.new(0, 2.7, 0)

    billboard.ClipsDescendants =
        false

    billboard.Parent =
        character

    local healthOutline =
        Instance.new("Frame")

    healthOutline.Name =
        "HealthOutline"

    healthOutline.Position =
        UDim2.fromOffset(
            (ESP_GUI_WIDTH - HEALTH_BAR_WIDTH) / 2 - 1,
            1
        )

    healthOutline.Size =
        UDim2.fromOffset(
            HEALTH_BAR_WIDTH + 2,
            HEALTH_BAR_HEIGHT + 2
        )

    healthOutline.BackgroundColor3 =
        Color3.fromRGB(0, 0, 0)

    healthOutline.BackgroundTransparency =
        0.15

    healthOutline.BorderSizePixel =
        0

    healthOutline.ZIndex =
        5

    healthOutline.Parent =
        billboard

    makeCorner(
        healthOutline,
        4
    )

    local healthBackground =
        Instance.new("Frame")

    healthBackground.Name =
        "HealthBackground"

    healthBackground.Position =
        UDim2.fromOffset(1, 1)

    healthBackground.Size =
        UDim2.fromOffset(
            HEALTH_BAR_WIDTH,
            HEALTH_BAR_HEIGHT
        )

    healthBackground.BackgroundColor3 =
        Color3.fromRGB(35, 35, 35)

    healthBackground.BorderSizePixel =
        0

    healthBackground.ZIndex =
        6

    healthBackground.Parent =
        healthOutline

    makeCorner(
        healthBackground,
        3
    )

    local healthBar =
        Instance.new("Frame")

    healthBar.Name =
        "ESP_HealthBar"

    healthBar.Position =
        UDim2.fromOffset(0, 0)

    healthBar.Size =
        UDim2.fromOffset(
            HEALTH_BAR_WIDTH,
            HEALTH_BAR_HEIGHT
        )

    healthBar.BackgroundColor3 =
        Color3.fromRGB(0, 220, 80)

    healthBar.BorderSizePixel =
        0

    healthBar.ZIndex =
        7

    healthBar.Parent =
        healthBackground

    makeCorner(
        healthBar,
        3
    )

    local infoLabel =
        Instance.new("TextLabel")

    infoLabel.Name =
        "ESP_Info"

    infoLabel.Position =
        UDim2.fromOffset(0, 14)

    infoLabel.Size =
        UDim2.fromOffset(
            ESP_GUI_WIDTH,
            22
        )

    infoLabel.BackgroundTransparency =
        1

    infoLabel.Font =
        Enum.Font.GothamBold

    infoLabel.TextSize =
        14

    infoLabel.TextColor3 =
        Color3.fromRGB(255, 255, 255)

    infoLabel.TextStrokeTransparency =
        0.45

    infoLabel.TextXAlignment =
        Enum.TextXAlignment.Center

    infoLabel.TextYAlignment =
        Enum.TextYAlignment.Center

    infoLabel.Text =
        ""

    infoLabel.ZIndex =
        8

    infoLabel.Parent =
        billboard

    return billboard
end

local function updateESP()
    if not Settings.ESP_Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer
            and player.Character then
                removeESPObjects(
                    player.Character
                )
            end
        end

        return
    end

    local localCharacter =
        LocalPlayer.Character

    local localRoot =
        localCharacter
        and localCharacter:FindFirstChild(
            "HumanoidRootPart"
        )

    if not localRoot or not Camera then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            continue
        end

        local character =
            player.Character

        if not character then
            continue
        end

        if not isEnemy(player) then
            removeESPObjects(character)
            continue
        end

        local humanoid =
            character:FindFirstChildOfClass(
                "Humanoid"
            )

        local root =
            character:FindFirstChild(
                "HumanoidRootPart"
            )

        local head =
            character:FindFirstChild("Head")

        if not humanoid
        or humanoid.Health <= 0
        or not root
        or not head then
            removeESPObjects(character)
            continue
        end

        local ok_rp, rootPos = pcall(function()
            return root.Position
        end)

        if not ok_rp then
            removeESPObjects(character)
            continue
        end

        local distance =
            (
                rootPos
                - localRoot.Position
            ).Magnitude

        if distance > Settings.ESP_MaxDistance then
            removeESPObjects(character)
            continue
        end

        local highlight =
            character:FindFirstChild(
                "ESP_Highlight"
            )

        if Settings.ESP_Highlight then
            if not highlight then
                highlight =
                    Instance.new("Highlight")

                highlight.Name =
                    "ESP_Highlight"

                highlight.Adornee =
                    character

                highlight.DepthMode =
                    Enum.HighlightDepthMode.AlwaysOnTop

                highlight.Parent =
                    character
            end

            highlight.FillColor =
                ESP_BOX_COLOR

            highlight.FillTransparency =
                Settings.ESP_BoxTransparency

            highlight.OutlineColor =
                ESP_BOX_COLOR

            highlight.OutlineTransparency =
                0

            highlight.Enabled =
                true
        elseif highlight then
            highlight:Destroy()
        end

        local billboard =
            character:FindFirstChild(
                "ESP_Billboard"
            )

        if not billboard
        or not billboard:IsA("BillboardGui") then
            if billboard then
                billboard:Destroy()
            end

            billboard =
                createESPBillboard(
                    character,
                    head
                )
        end

        billboard.Adornee =
            head

        billboard.AlwaysOnTop =
            true

        billboard.LightInfluence =
            0

        billboard.MaxDistance =
            Settings.ESP_MaxDistance

        billboard.Size =
            UDim2.fromOffset(
                ESP_GUI_WIDTH,
                ESP_GUI_HEIGHT
            )

        billboard.StudsOffsetWorldSpace =
            Vector3.new(0, 2.7, 0)

        billboard.Enabled =
            true

        local healthOutline =
            billboard:FindFirstChild(
                "HealthOutline"
            )

        local healthBackground =
            healthOutline
            and healthOutline:FindFirstChild(
                "HealthBackground"
            )

        local healthBar =
            healthBackground
            and healthBackground:FindFirstChild(
                "ESP_HealthBar"
            )

        if not healthOutline
        or not healthBackground
        or not healthBar then
            billboard:Destroy()

            billboard =
                createESPBillboard(
                    character,
                    head
                )

            healthOutline =
                billboard:FindFirstChild(
                    "HealthOutline"
                )

            healthBackground =
                healthOutline
                and healthOutline:FindFirstChild(
                    "HealthBackground"
                )

            healthBar =
                healthBackground
                and healthBackground:FindFirstChild(
                    "ESP_HealthBar"
                )

            if not healthBar then
                continue
            end
        end

        local healthPercent =
            math.clamp(
                humanoid.Health
                / math.max(
                    humanoid.MaxHealth,
                    1
                ),
                0,
                1
            )

        healthBar.Size =
            UDim2.fromOffset(
                math.max(
                    0,
                    math.floor(
                        HEALTH_BAR_WIDTH
                        * healthPercent
                    )
                ),
                HEALTH_BAR_HEIGHT
            )

        if healthPercent > 0.6 then
            healthBar.BackgroundColor3 =
                Color3.fromRGB(
                    0,
                    220,
                    80
                )
        elseif healthPercent > 0.3 then
            healthBar.BackgroundColor3 =
                Color3.fromRGB(
                    255,
                    190,
                    0
                )
        else
            healthBar.BackgroundColor3 =
                Color3.fromRGB(
                    235,
                    45,
                    45
                )
        end

        local infoLabel =
            billboard:FindFirstChild(
                "ESP_Info"
            )

        if infoLabel then
            local showName =
                Settings.ESP_Name

            local showStuds =
                Settings.ESP_Studs

            if showName and showStuds then
                infoLabel.Text =
                    player.Name
                    .. " | "
                    .. string.format(
                        "%.1f studs",
                        distance
                    )

                infoLabel.Visible =
                    true
            elseif showName then
                infoLabel.Text =
                    player.Name

                infoLabel.Visible =
                    true
            elseif showStuds then
                infoLabel.Text =
                    string.format(
                        "%.1f studs",
                        distance
                    )

                infoLabel.Visible =
                    true
            else
                infoLabel.Text =
                    ""

                infoLabel.Visible =
                    false
            end
        end
    end
end

task.spawn(function()
    while not _killed do
        if AutoclickActive
        and not isVoteScreenActive() then
            if not Camera then
                Camera =
                    workspace.CurrentCamera
            end

            if Camera then
                local vp =
                    Camera.ViewportSize

                if vp then
                    local cx =
                        vp.X / 2

                    local cy =
                        vp.Y / 2

                    local silentTarget = Settings.SilentAim_Enabled and getSilentAimTarget()
                    local oldCamCF = nil

                    if silentTarget and silentTarget.Parent then
                        local ok_pos, sPos = pcall(function() return silentTarget.Position end)
                        if ok_pos and sPos then
                            oldCamCF = Camera.CFrame
                            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, sPos)
                        end
                    end

                    VirtualInputManager:SendMouseButtonEvent(
                        cx,
                        cy,
                        0,
                        true,
                        game,
                        0
                    )

                    task.wait(0.015)

                    VirtualInputManager:SendMouseButtonEvent(
                        cx,
                        cy,
                        0,
                        false,
                        game,
                        0
                    )

                    if oldCamCF then
                        Camera.CFrame = oldCamCF
                    end
                end
            end
            task.wait(0.05)
        else
            task.wait(0.03)
        end
    end
end)

trackConn(
    RunService.RenderStepped:Connect(function()
        if _killed then
            return
        end

        if not Camera then
            Camera =
                workspace.CurrentCamera
        end

        if not Camera then
            return
        end

        if not LocalPlayer.Character then
            return
        end

        updateCircle()
        updateTracer()

        if MenuFrame.Visible and not isMinimized then
            AutoclickActive = false
            return
        end

        if Settings.Aimbot_Enabled then
            if lockedTarget then
                updateLockedBody()
            else
                local targetHead =
                    getAimTarget()

                if targetHead then
                    forceAimAtHead(
                        targetHead
                    )
                end
            end
        else
            lockedTarget = nil
        end

        if Settings.Triggerbot_Enabled then
            AutoclickActive =
                shouldFire()
        else
            AutoclickActive = false
        end
    end)
)

task.spawn(function()
    while not _killed do
        task.wait(0.15)

        if not _killed then
            pcall(updateESP)
        end
    end
end)

task.spawn(function()
    while not _killed do
        task.wait(0.1)

        if not _killed then
            pcall(checkAndAutoReload)
        end
    end
end)

task.spawn(function()
    while not _killed do
        task.wait(0.2)

        if not _killed then
            pcall(updateHitboxes)
        end
    end
end)

print(
    "[rivals] Script loaded. Click [ ⚡ MENU ] or press Right Control / Insert to open menu. Cache: "
    .. CACHE_FILE
)
]===]

local CACHE_FOLDER = "Rivals Script by Zyr4x"
local SCRIPT_FILE  = CACHE_FOLDER .. "/rivals_main.lua"
local QUEUE_FILE   = CACHE_FOLDER .. "/rivals_queue.lua"

local function ensureCacheFolder()
    pcall(function()
        if makefolder then
            local exists =
                isfolder
                and isfolder(CACHE_FOLDER)

            if not exists then
                makefolder(CACHE_FOLDER)
            end
        end
    end)
end

ensureCacheFolder()

pcall(function()
    if writefile then
        writefile(
            SCRIPT_FILE,
            myScriptCode
        )
    end
end)

local fn, compileErr =
    loadstring(myScriptCode)

if not fn then
    warn(
        "[rivals] loadstring compile error: "
        .. tostring(compileErr)
    )
else
    local success, runErr =
        pcall(fn)

    if not success then
        warn(
            "[rivals] runtime error: "
            .. tostring(runErr)
        )
    end
end

local queuePayload = [===[
task.wait(2)

local CACHE_FOLDER = "Rivals Script by Zyr4x"
local SCRIPT_FILE  = CACHE_FOLDER .. "/rivals_main.lua"
local QUEUE_FILE   = CACHE_FOLDER .. "/rivals_queue.lua"

local function ensureCacheFolder()
    pcall(function()
        if makefolder then
            local exists =
                isfolder
                and isfolder(CACHE_FOLDER)

            if not exists then
                makefolder(CACHE_FOLDER)
            end
        end
    end)
end

ensureCacheFolder()

local function getQueueFn()
    return queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
end

local function readFileSafe(path)
    local result = nil

    pcall(function()
        if isfile and isfile(path) then
            result = readfile(path)
        end
    end)

    if typeof(result) ~= "string"
    or result == "" then
        return nil
    end

    return result
end

local code =
    readFileSafe(SCRIPT_FILE)

if not code
or code == "-- killed" then
    print(
        "[rivals] queue: no usable script found - chain stopped."
    )
    return
end

if loadstring then
    local fn, ce =
        loadstring(code)

    if not fn then
        warn(
            "[rivals/queue] compile error: "
            .. tostring(ce)
        )
    else
        local ok, e =
            pcall(fn)

        if not ok then
            warn(
                "[rivals/queue] runtime error: "
                .. tostring(e)
            )
        else
            print(
                "[rivals] cached script loaded."
            )
        end
    end
else
    warn(
        "[rivals/queue] loadstring is unavailable."
    )
end

local qf = getQueueFn()

if qf then
    local queueCode =
        readFileSafe(QUEUE_FILE)

    if queueCode
    and queueCode ~= "-- killed" then
        pcall(function()
            qf(queueCode)
        end)

        print(
            "[rivals] re-queued for next teleport."
        )
    else
        print(
            "[rivals] queue file missing or killed - chain stopped."
        )
    end
end
]===]

ensureCacheFolder()

pcall(function()
    if writefile then
        writefile(
            QUEUE_FILE,
            queuePayload
        )
    end
end)

local queueFunc =
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queueFunc then
    local ok_read, storedQueue =
        pcall(function()
            if isfile
            and isfile(QUEUE_FILE) then
                return readfile(
                    QUEUE_FILE
                )
            end
        end)

    local toQueue =
        (
            ok_read
            and storedQueue
            and storedQueue ~= "-- killed"
        )
        and storedQueue
        or queuePayload

    pcall(function()
        queueFunc(toQueue)
    end)

    print(
        "[rivals] queued for next teleport. "
        .. "Script saved to "
        .. SCRIPT_FILE
    )
else
    print(
        "[rivals] Warning: executor does not support queue_on_teleport."
    )
end
