-- ============================================================================
-- Zyr4x Hub | Universal Movement & Utility Suite
-- Created for Zyr4x
-- Features: WalkSpeed (100), 3D Free Fly (50, Up/Down), Noclip,
--           Infinite Jump, Fullbright, ESP, Instant Prompts, Anti-AFK
-- ============================================================================

if _G.Zyr4xHubRunning then
    pcall(function() _G.Zyr4xHubRunning() end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Global Hub State
local State = {
    WalkSpeedEnabled = false,
    WalkSpeedValue = 100,      -- Requested 100
    FlyEnabled = false,
    FlySpeed = 50,             -- Requested 50
    NoclipEnabled = false,
    InfJumpEnabled = false,
    InstantPromptEnabled = false,
    FullbrightEnabled = false,
    EspEnabled = false,
    ClickTpEnabled = false,
    AntiAfkEnabled = true,
}

local connections = {}
local flyingBodyGyro = nil
local flyingBodyVelocity = nil

-- Save original Lighting settings for clean reset
local defaultLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

-- Clean-up handler for re-execution
_G.Zyr4xHubRunning = function()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    -- Reset flight objects
    if flyingBodyGyro then pcall(function() flyingBodyGyro:Destroy() end) end
    if flyingBodyVelocity then pcall(function() flyingBodyVelocity:Destroy() end) end

    -- Reset Humanoid
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        local hum = char:FindFirstChildOfClass("Humanoid")
        hum.WalkSpeed = 16
        hum.PlatformStand = false
    end

    -- Reset Lighting
    pcall(function()
        Lighting.Ambient = defaultLighting.Ambient
        Lighting.Brightness = defaultLighting.Brightness
        Lighting.ClockTime = defaultLighting.ClockTime
        Lighting.FogEnd = defaultLighting.FogEnd
        Lighting.GlobalShadows = defaultLighting.GlobalShadows
    end)

    -- Remove ESP Highlights
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Zyr4x_ESP") then
            pcall(function() p.Character.Zyr4x_ESP:Destroy() end)
        end
    end

    -- Destroy UI
    if CoreGui:FindFirstChild("Zyr4xHubUI") then
        CoreGui.Zyr4xHubUI:Destroy()
    end
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("Zyr4xHubUI") then
        LocalPlayer.PlayerGui.Zyr4xHubUI:Destroy()
    end
    print("[Zyr4x Hub] Unloaded cleanly.")
end

-- ==============================================================================
-- 1. Anti-AFK (Prevents 20-Minute Kick)
-- ==============================================================================
local afkConn = LocalPlayer.Idled:Connect(function()
    if State.AntiAfkEnabled then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end)
table.insert(connections, afkConn)

-- ==============================================================================
-- 2. Movement Logic: WalkSpeed, Noclip, Infinite Jump
-- ==============================================================================

-- WalkSpeed Enforcer (ensures speed stays active)
local speedConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char and State.WalkSpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= State.WalkSpeedValue then
            hum.WalkSpeed = State.WalkSpeedValue
        end
    end
end)
table.insert(connections, speedConn)

-- Noclip Logic
local noclipConn = RunService.Stepped:Connect(function()
    if not State.NoclipEnabled then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)
table.insert(connections, noclipConn)

-- Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if State.InfJumpEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
table.insert(connections, jumpConn)

-- ==============================================================================
-- 3. 3D Full-Directional Flight Engine (WASD + Space Up / Shift Down)
-- ==============================================================================
local flyKeys = { W = false, A = false, S = false, D = false, Space = false, Shift = false }

local function stopFlying()
    if flyingBodyVelocity then
        pcall(function() flyingBodyVelocity:Destroy() end)
        flyingBodyVelocity = nil
    end
    if flyingBodyGyro then
        pcall(function() flyingBodyGyro:Destroy() end)
        flyingBodyGyro = nil
    end
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid").PlatformStand = false
    end
end

local function startFlying()
    stopFlying()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    hum.PlatformStand = true

    flyingBodyGyro = Instance.new("BodyGyro")
    flyingBodyGyro.P = 9e4
    flyingBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyingBodyGyro.CFrame = root.CFrame
    flyingBodyGyro.Parent = root

    flyingBodyVelocity = Instance.new("BodyVelocity")
    flyingBodyVelocity.Velocity = Vector3.zero
    flyingBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyingBodyVelocity.Parent = root
end

local flyHeartbeat = RunService.RenderStepped:Connect(function()
    if not State.FlyEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    if not flyingBodyVelocity or not flyingBodyGyro or flyingBodyVelocity.Parent ~= root then
        startFlying()
    end

    hum.PlatformStand = true
    flyingBodyGyro.CFrame = Camera.CFrame

    local moveDir = Vector3.zero
    -- Camera directional flight
    if flyKeys.W then moveDir = moveDir + Camera.CFrame.LookVector end
    if flyKeys.S then moveDir = moveDir - Camera.CFrame.LookVector end
    if flyKeys.A then moveDir = moveDir - Camera.CFrame.RightVector end
    if flyKeys.D then moveDir = moveDir + Camera.CFrame.RightVector end
    -- Dedicated Vertical Elevation (Space = UP, Shift = DOWN)
    if flyKeys.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
    if flyKeys.Shift then moveDir = moveDir - Vector3.new(0, 1, 0) end

    -- Mobile touch / Gamepad joystick support
    if hum.MoveDirection.Magnitude > 0 and moveDir.Magnitude == 0 then
        moveDir = Camera.CFrame:VectorToWorldSpace(hum.MoveDirection)
    end

    if moveDir.Magnitude > 0 then
        flyingBodyVelocity.Velocity = moveDir.Unit * State.FlySpeed
    else
        flyingBodyVelocity.Velocity = Vector3.zero
    end
end)
table.insert(connections, flyHeartbeat)

-- Key inputs for Flying & Hotkeys
local inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = true
    elseif input.KeyCode == Enum.KeyCode.S then flyKeys.S = true
    elseif input.KeyCode == Enum.KeyCode.A then flyKeys.A = true
    elseif input.KeyCode == Enum.KeyCode.D then flyKeys.D = true
    elseif input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = true
    elseif input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.Shift = true
    end

    -- Click to Teleport (Ctrl + Left Click)
    if State.ClickTpEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local mouse = LocalPlayer:GetMouse()
        if mouse and mouse.Hit and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso")
            if root then
                root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)
table.insert(connections, inputBegan)

local inputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = false
    elseif input.KeyCode == Enum.KeyCode.S then flyKeys.S = false
    elseif input.KeyCode == Enum.KeyCode.A then flyKeys.A = false
    elseif input.KeyCode == Enum.KeyCode.D then flyKeys.D = false
    elseif input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = false
    elseif input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.Shift = false
    end
end)
table.insert(connections, inputEnded)

-- Respawn Handler
local charAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if State.FlyEnabled then startFlying() end
    if State.WalkSpeedEnabled then
        local hum = char:WaitForChild("Humanoid", 3)
        if hum then hum.WalkSpeed = State.WalkSpeedValue end
    end
end)
table.insert(connections, charAdded)

-- ==============================================================================
-- 4. Instant Proximity Prompts (0 Second Hold)
-- ==============================================================================
local promptConn = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if State.InstantPromptEnabled then
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
            else
                prompt.HoldDuration = 0
            end
        end)
    end
end)
table.insert(connections, promptConn)

-- ==============================================================================
-- 5. Fullbright & No Fog
-- ==============================================================================
local brightConn = RunService.RenderStepped:Connect(function()
    if State.FullbrightEnabled then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
    end
end)
table.insert(connections, brightConn)

-- ==============================================================================
-- 6. Universal Player ESP (Roblox Highlights)
-- ==============================================================================
local function applyEsp(player)
    if player == LocalPlayer then return end
    local function onChar(char)
        if not char then return end
        if char:FindFirstChild("Zyr4x_ESP") then
            char.Zyr4x_ESP:Destroy()
        end
        if State.EspEnabled then
            local highlight = Instance.new("Highlight")
            highlight.Name = "Zyr4x_ESP"
            highlight.FillColor = Color3.fromRGB(150, 75, 255)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = char
        end
    end

    if player.Character then onChar(player.Character) end
    player.CharacterAdded:Connect(onChar)
end

for _, p in ipairs(Players:GetPlayers()) do
    applyEsp(p)
end
local playerAddedConn = Players.PlayerAdded:Connect(applyEsp)
table.insert(connections, playerAddedConn)

local function refreshAllEsp()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if State.EspEnabled then
                if not p.Character:FindFirstChild("Zyr4x_ESP") then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "Zyr4x_ESP"
                    highlight.FillColor = Color3.fromRGB(150, 75, 255)
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = p.Character
                end
            else
                if p.Character:FindFirstChild("Zyr4x_ESP") then
                    p.Character.Zyr4x_ESP:Destroy()
                end
            end
        end
    end
end

-- ==============================================================================
-- 7. Modern Floating UI Hub
-- ==============================================================================
local function getGuiParent()
    local success, parent = pcall(function() return CoreGui end)
    if success and parent then return parent end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Zyr4xHubUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()

local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, 390, 0, 490)
Main.Position = UDim2.new(0.5, -195, 0.5, -245)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(120, 65, 240)
MainStroke.Thickness = 1.6

-- Window Dragging
local dragging, dragInput, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Top Header
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopBarCorner = Instance.new("UICorner", TopBar)
TopBarCorner.CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "[Zyr4x Hub]  |  Movement Suite"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar

local CloseBtnCorner = Instance.new("UICorner", CloseBtn)
CloseBtnCorner.CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    _G.Zyr4xHubRunning()
end)

-- Content Scroll Frame
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -50)
Content.Position = UDim2.new(0, 8, 0, 46)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(120, 65, 240)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.Parent = Main

local ContentLayout = Instance.new("UIListLayout", Content)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 8)

local function createSection(title)
    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, -8, 0, 22)
    sec.BackgroundTransparency = 1
    sec.Text = string.upper(title)
    sec.TextColor3 = Color3.fromRGB(120, 65, 240)
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 11
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.Parent = Content
    return sec
end

local function createToggleRow(title, defaultVal, onToggle)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 38)
    card.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
    card.BorderSizePixel = 0
    card.Parent = Content

    local corner = Instance.new("UICorner", card)
    corner.CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(235, 235, 235)
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 0, 24)
    btn.Position = UDim2.new(1, -68, 0.5, -12)
    btn.BackgroundColor3 = defaultVal and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 45, 55)
    btn.Text = defaultVal and "ON" or "OFF"
    btn.TextColor3 = defaultVal and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = card

    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 6)

    local state = defaultVal
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 45, 55)
        btn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
        btn.Text = state and "ON" or "OFF"
        onToggle(state)
    end)
    return card
end

-- ==============================================================================
-- Section 1: Movement
-- ==============================================================================
createSection("Movement & Flight")

-- WalkSpeed Card (Set to 100 by default)
local SpeedCard = Instance.new("Frame")
SpeedCard.Size = UDim2.new(1, -8, 0, 64)
SpeedCard.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
SpeedCard.BorderSizePixel = 0
SpeedCard.Parent = Content
Instance.new("UICorner", SpeedCard).CornerRadius = UDim.new(0, 6)

local SpeedTitle = Instance.new("TextLabel")
SpeedTitle.Size = UDim2.new(1, -80, 0, 26)
SpeedTitle.Position = UDim2.new(0, 10, 0, 4)
SpeedTitle.BackgroundTransparency = 1
SpeedTitle.Text = "WalkSpeed Modifier"
SpeedTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
SpeedTitle.Font = Enum.Font.GothamSemibold
SpeedTitle.TextSize = 12
SpeedTitle.TextXAlignment = Enum.TextXAlignment.Left
SpeedTitle.Parent = SpeedCard

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(0, 60, 0, 24)
SpeedToggle.Position = UDim2.new(1, -68, 0, 4)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
SpeedToggle.Text = "OFF"
SpeedToggle.TextColor3 = Color3.fromRGB(180, 180, 180)
SpeedToggle.Font = Enum.Font.GothamBold
SpeedToggle.TextSize = 11
SpeedToggle.BorderSizePixel = 0
SpeedToggle.Parent = SpeedCard
Instance.new("UICorner", SpeedToggle).CornerRadius = UDim.new(0, 6)

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(1, -20, 0, 24)
SpeedBox.Position = UDim2.new(0, 10, 0, 32)
SpeedBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
SpeedBox.Text = tostring(State.WalkSpeedValue)
SpeedBox.PlaceholderText = "Speed (Default: 100)"
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.Gotham
SpeedBox.TextSize = 12
SpeedBox.BorderSizePixel = 0
SpeedBox.Parent = SpeedCard
Instance.new("UICorner", SpeedBox).CornerRadius = UDim.new(0, 4)

SpeedToggle.MouseButton1Click:Connect(function()
    State.WalkSpeedEnabled = not State.WalkSpeedEnabled
    SpeedToggle.BackgroundColor3 = State.WalkSpeedEnabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 45, 55)
    SpeedToggle.TextColor3 = State.WalkSpeedEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    SpeedToggle.Text = State.WalkSpeedEnabled and "ON" or "OFF"
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = State.WalkSpeedEnabled and State.WalkSpeedValue or 16 end
end)

SpeedBox.FocusLost:Connect(function()
    local val = tonumber(SpeedBox.Text)
    if val and val > 0 then
        State.WalkSpeedValue = val
        if State.WalkSpeedEnabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = State.WalkSpeedValue end
        end
    else
        SpeedBox.Text = tostring(State.WalkSpeedValue)
    end
end)

-- Fly Card (Set to 50 by default, 3D Up/Down flight)
local FlyCard = Instance.new("Frame")
FlyCard.Size = UDim2.new(1, -8, 0, 64)
FlyCard.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
FlyCard.BorderSizePixel = 0
FlyCard.Parent = Content
Instance.new("UICorner", FlyCard).CornerRadius = UDim.new(0, 6)

local FlyTitle = Instance.new("TextLabel")
FlyTitle.Size = UDim2.new(1, -80, 0, 26)
FlyTitle.Position = UDim2.new(0, 10, 0, 4)
FlyTitle.BackgroundTransparency = 1
FlyTitle.Text = "Fly (WASD | Space = Up | Shift = Down)"
FlyTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
FlyTitle.Font = Enum.Font.GothamSemibold
FlyTitle.TextSize = 12
FlyTitle.TextXAlignment = Enum.TextXAlignment.Left
FlyTitle.Parent = FlyCard

local FlyToggle = Instance.new("TextButton")
FlyToggle.Size = UDim2.new(0, 60, 0, 24)
FlyToggle.Position = UDim2.new(1, -68, 0, 4)
FlyToggle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
FlyToggle.Text = "OFF"
FlyToggle.TextColor3 = Color3.fromRGB(180, 180, 180)
FlyToggle.Font = Enum.Font.GothamBold
FlyToggle.TextSize = 11
FlyToggle.BorderSizePixel = 0
FlyToggle.Parent = FlyCard
Instance.new("UICorner", FlyToggle).CornerRadius = UDim.new(0, 6)

local FlyBox = Instance.new("TextBox")
FlyBox.Size = UDim2.new(1, -20, 0, 24)
FlyBox.Position = UDim2.new(0, 10, 0, 32)
FlyBox.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
FlyBox.Text = tostring(State.FlySpeed)
FlyBox.PlaceholderText = "Fly Speed (Default: 50)"
FlyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyBox.Font = Enum.Font.Gotham
FlyBox.TextSize = 12
FlyBox.BorderSizePixel = 0
FlyBox.Parent = FlyCard
Instance.new("UICorner", FlyBox).CornerRadius = UDim.new(0, 4)

FlyToggle.MouseButton1Click:Connect(function()
    State.FlyEnabled = not State.FlyEnabled
    FlyToggle.BackgroundColor3 = State.FlyEnabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 45, 55)
    FlyToggle.TextColor3 = State.FlyEnabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
    FlyToggle.Text = State.FlyEnabled and "ON" or "OFF"
    if State.FlyEnabled then startFlying() else stopFlying() end
end)

FlyBox.FocusLost:Connect(function()
    local val = tonumber(FlyBox.Text)
    if val and val > 0 then
        State.FlySpeed = val
    else
        FlyBox.Text = tostring(State.FlySpeed)
    end
end)

-- Noclip Toggle
createToggleRow("Noclip (Walk Through Walls)", State.NoclipEnabled, function(on)
    State.NoclipEnabled = on
end)

-- Infinite Jump Toggle
createToggleRow("Infinite Jump (Space in air)", State.InfJumpEnabled, function(on)
    State.InfJumpEnabled = on
end)

-- ==============================================================================
-- Section 2: Visuals & World
-- ==============================================================================
createSection("Visuals & Lighting")

createToggleRow("Fullbright & No Fog", State.FullbrightEnabled, function(on)
    State.FullbrightEnabled = on
    if not on then
        pcall(function()
            Lighting.Ambient = defaultLighting.Ambient
            Lighting.Brightness = defaultLighting.Brightness
            Lighting.ClockTime = defaultLighting.ClockTime
            Lighting.FogEnd = defaultLighting.FogEnd
            Lighting.GlobalShadows = defaultLighting.GlobalShadows
        end)
    end
end)

createToggleRow("Player ESP (Wall Chams)", State.EspEnabled, function(on)
    State.EspEnabled = on
    refreshAllEsp()
end)

-- ==============================================================================
-- Section 3: Universal Utilities
-- ==============================================================================
createSection("Server Utilities")

createToggleRow("Instant Prompts (0s Hold)", State.InstantPromptEnabled, function(on)
    State.InstantPromptEnabled = on
end)

createToggleRow("Click-TP (Hold Ctrl + Click)", State.ClickTpEnabled, function(on)
    State.ClickTpEnabled = on
end)

createToggleRow("Anti-AFK (No 20-Min Kick)", State.AntiAfkEnabled, function(on)
    State.AntiAfkEnabled = on
end)

-- Rejoin Button
local RejoinCard = Instance.new("Frame")
RejoinCard.Size = UDim2.new(1, -8, 0, 38)
RejoinCard.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
RejoinCard.BorderSizePixel = 0
RejoinCard.Parent = Content
Instance.new("UICorner", RejoinCard).CornerRadius = UDim.new(0, 6)

local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(1, -20, 0, 26)
RejoinBtn.Position = UDim2.new(0, 10, 0.5, -13)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(120, 65, 240)
RejoinBtn.Text = "Rejoin Current Server"
RejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RejoinBtn.Font = Enum.Font.GothamBold
RejoinBtn.TextSize = 11
RejoinBtn.BorderSizePixel = 0
RejoinBtn.Parent = RejoinCard
Instance.new("UICorner", RejoinBtn).CornerRadius = UDim.new(0, 6)

RejoinBtn.MouseButton1Click:Connect(function()
    local TeleportService = game:GetService("TeleportService")
    if #Players:GetPlayers() <= 1 then
        LocalPlayer:Kick("\nRejoining...")
        task.wait(0.2)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
end)

-- Floating UI Toggle Pill
local ToggleGuiBtn = Instance.new("TextButton")
ToggleGuiBtn.Name = "Zyr4xToggleBtn"
ToggleGuiBtn.Size = UDim2.new(0, 110, 0, 32)
ToggleGuiBtn.Position = UDim2.new(0, 15, 0.5, -16)
ToggleGuiBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
ToggleGuiBtn.Text = "Zyr4x Menu"
ToggleGuiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleGuiBtn.Font = Enum.Font.GothamBold
ToggleGuiBtn.TextSize = 12
ToggleGuiBtn.BorderSizePixel = 0
ToggleGuiBtn.Parent = ScreenGui

local ToggleGuiCorner = Instance.new("UICorner", ToggleGuiBtn)
ToggleGuiCorner.CornerRadius = UDim.new(0, 6)

local ToggleGuiStroke = Instance.new("UIStroke", ToggleGuiBtn)
ToggleGuiStroke.Color = Color3.fromRGB(120, 65, 240)
ToggleGuiStroke.Thickness = 1.2

ToggleGuiBtn.MouseButton1Click:Connect(function()
    Main.Visible = not Main.Visible
end)

print("[Zyr4x Hub] Loaded with WalkSpeed 100 & 3D Fly 50!")
