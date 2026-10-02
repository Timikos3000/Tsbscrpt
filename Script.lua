-- ==========================================
-- TSB AUTO-FARM HUB | TimUI (Custom Native Engine)
-- Developer: JustTim :)
-- No external UI downloads / 100% Work in KZ
-- ==========================================

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- CUSTOM NATIVE UI LIBRARY (TimUI)
-- ==========================================
local TimUI = {}

function TimUI:CreateWindow(titleText)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TimUI_Hub"
    ScreenGui.ResetOnSpawn = false
    
    -- Защита от Synapse / Delta / Krnl
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = game:GetService("CoreGui")
    end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 420, 0, 360)
    MainFrame.Position = UDim2.new(0.5, -210, 0.5, -180)
    MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim me and UDim.new(0, 10) or UDim.new(0, 10)
    UICorner.Parent = MainFrame

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(60, 60, 75)
    UIStroke.Thickness = 1.5
    UIStroke.Parent = MainFrame

    -- Header / Title Bar
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 10)
    TopCorner.Parent = TopBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 1, 0)
    TitleLabel.Position = UDim2.new(0, 15, 0, 0)
    TitleLabel.Text = titleText or "TimUI Hub"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 15
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Parent = TopBar

    -- Draggable Logic (Перетаскивание)
    local dragging, dragInput, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Container for Elements
    local Container = Instance.new("ScrollingFrame")
    Container.Name = "Container"
    Container.Size = UDim2.new(1, -20, 1, -55)
    Container.Position = UDim2.new(0, 10, 0, 48)
    Container.BackgroundTransparency = 1
    Container.BorderSizePixel = 0
    Container.ScrollBarThickness = 4
    Container.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    Container.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = Container

    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
    end)

    local Window = {}

    -- ELEMENT: TOGGLE
    function Window:CreateToggle(options)
        local name = options.Name or "Toggle"
        local default = options.Default or false
        local callback = options.Callback or function() end

        local state = default

        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Size = UDim2.new(1, 0, 0, 38)
        ToggleFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        ToggleFrame.BorderSizePixel = 0
        ToggleFrame.Parent = Container

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = ToggleFrame

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -60, 1, 0)
        TextLabel.Position = UDim2.new(0, 12, 0, 0)
        TextLabel.Text = name
        TextLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        TextLabel.TextSize = 13
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BackgroundTransparency = 1
        TextLabel.Parent = ToggleFrame

        local SwitchBtn = Instance.new("TextButton")
        SwitchBtn.Size = UDim2.new(0, 42, 0, 22)
        SwitchBtn.Position = UDim2.new(1, -50, 0.5, -11)
        SwitchBtn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(50, 50, 60)
        SwitchBtn.Text = ""
        SwitchBtn.AutoButtonColor = false
        SwitchBtn.Parent = ToggleFrame

        local SwitchCorner = Instance.new("UICorner")
        SwitchCorner.CornerRadius = UDim.new(1, 0)
        SwitchCorner.Parent = SwitchBtn

        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0, 16, 0, 16)
        Circle.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Circle.Parent = SwitchBtn

        local CircleCorner = Instance.new("UICorner")
        CircleCorner.CornerRadius = UDim.new(1, 0)
        CircleCorner.Parent = Circle

        local function toggle()
            state = not state
            local targetBg = state and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(50, 50, 60)
            local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)

            TweenService:Create(SwitchBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetBg}):Play()
            TweenService:Create(Circle, TweenInfo.new(0.2), {Position = targetPos}):Play()

            task.spawn(callback, state)
        end

        SwitchBtn.MouseButton1Click:Connect(toggle)
    end

    -- ELEMENT: SLIDER
    function Window:CreateSlider(options)
        local name = options.Name or "Slider"
        local min = options.Min or 0
        local max = options.Max or 100
        local default = options.Default or min
        local callback = options.Callback or function() end

        local SliderFrame = Instance.new("Frame")
        SliderFrame.Size = UDim2.new(1, 0, 0, 48)
        SliderFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
        SliderFrame.BorderSizePixel = 0
        SliderFrame.Parent = Container

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = SliderFrame

        local TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, -70, 0, 22)
        TextLabel.Position = UDim2.new(0, 12, 0, 4)
        TextLabel.Text = name
        TextLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        TextLabel.TextSize = 13
        TextLabel.Font = Enum.Font.GothamMedium
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.BackgroundTransparency = 1
        TextLabel.Parent = SliderFrame

        local ValLabel = Instance.new("TextLabel")
        ValLabel.Size = UDim2.new(0, 50, 0, 22)
        ValLabel.Position = UDim2.new(1, -62, 0, 4)
        ValLabel.Text = tostring(default)
        ValLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
        ValLabel.TextSize = 12
        ValLabel.Font = Enum.Font.GothamBold
        ValLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValLabel.BackgroundTransparency = 1
        ValLabel.Parent = SliderFrame

        local SliderBar = Instance.new("TextButton")
        SliderBar.Size = UDim2.new(1, -24, 0, 6)
        SliderBar.Position = UDim2.new(0, 12, 0, 32)
        SliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        SliderBar.Text = ""
        SliderBar.AutoButtonColor = false
        SliderBar.Parent = SliderFrame

        local BarCorner = Instance.new("UICorner")
        BarCorner.CornerRadius = UDim.new(1, 0)
        BarCorner.Parent = SliderBar

        local Fill = Instance.new("Frame")
        local startScale = (default - min) / (max - min)
        Fill.Size = UDim2.new(math.clamp(startScale, 0, 1), 0, 1, 0)
        Fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        Fill.Parent = SliderBar

        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(1, 0)
        FillCorner.Parent = Fill

        local isSliding = false

        local function update(input)
            local pos = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * pos)
            Fill.Size = UDim2.new(pos, 0, 1, 0)
            ValLabel.Text = tostring(value)
            task.spawn(callback, value)
        end

        SliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isSliding = true
                update(input)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isSliding = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end

    -- ELEMENT: BUTTON
    function Window:CreateButton(options)
        local name = options.Name or "Button"
        local callback = options.Callback or function() end

        local ButtonFrame = Instance.new("TextButton")
        ButtonFrame.Size = UDim2.new(1, 0, 0, 36)
        ButtonFrame.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
        ButtonFrame.Text = name
        ButtonFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
        ButtonFrame.Font = Enum.Font.GothamBold
        ButtonFrame.TextSize = 13
        ButtonFrame.Parent = Container

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = ButtonFrame

        ButtonFrame.MouseButton1Click:Connect(function()
            TweenService:Create(ButtonFrame, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}):Play()
            task.wait(0.1)
            TweenService:Create(ButtonFrame, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0, 140, 220)}):Play()
            task.spawn(callback)
        end)
    end

    return Window
end

-- ==========================================
-- SCRIPT LOGIC & SETTINGS
-- ==========================================
local Settings = {
    AutoFarm = false,
    TweenSpeed = 90,
    AttackDistance = 3.5,
    AdaptivePing = true,
    BaseCooldown = 0.45,
    AutoSafeZone = true,
    LowHealthThreshold = 30,
    SafePlatformPos = Vector3.new(0, 750, 0),
    AutoAwakening = true,
    AutoSkills = true,
    AntiFling = true,
    FastRecovery = true,
    AntiAFK = true
}

local currentTarget = nil
local lastSkillTime = 0
local isInSafeZone = false
local safePlatformInstance = nil

local function getPing()
    local pingItem = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
    return pingItem and (pingItem:GetValue() / 1000) or 0.15
end

local function isAlive(player)
    if not player or not player.Parent then return false end
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0
end

local function getMyChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function useSkills(char, hum)
    local dynamicCooldown = Settings.AdaptivePing and math.clamp(Settings.BaseCooldown + (getPing() * 0.8), 0.3, 1.2) or Settings.BaseCooldown
    if not Settings.AutoSkills or (tick() - lastSkillTime < dynamicCooldown) then return end
    
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, skillTool in ipairs(backpack:GetChildren()) do
            if skillTool:IsA("Tool") then
                pcall(function()
                    hum:EquipTool(skillTool)
                    task.wait(0.04 + (getPing() * 0.2))
                    skillTool:Activate()
                end)
            end
        end
        lastSkillTime = tick()
    end
end

-- ==========================================
-- INITIALIZE UI
-- ==========================================
local Window = TimUI:CreateWindow("TSB Hub | Native TimUI Engine")

Window:CreateToggle({
    Name = "Enable Player Rotation AutoFarm",
    Default = Settings.AutoFarm,
    Callback = function(v) Settings.AutoFarm = v currentTarget = nil end
})

Window:CreateSlider({
    Name = "Move Speed (studs/s)",
    Min = 30, Max = 180, Default = Settings.TweenSpeed,
    Callback = function(v) Settings.TweenSpeed = v end
})

Window:CreateToggle({
    Name = "Adaptive Ping Lag-Fix (KZ Fix)",
    Default = Settings.AdaptivePing,
    Callback = function(v) Settings.AdaptivePing = v end
})

Window:CreateToggle({
    Name = "Auto SafeZone on Low HP",
    Default = Settings.AutoSafeZone,
    Callback = function(v) Settings.AutoSafeZone = v end
})

Window:CreateToggle({
    Name = "Auto Skills (1-4)",
    Default = Settings.AutoSkills,
    Callback = function(v) Settings.AutoSkills = v end
})

Window:CreateToggle({
    Name = "Auto Awakening (G)",
    Default = Settings.AutoAwakening,
    Callback = function(v) Settings.AutoAwakening = v end
})

Window:CreateButton({
    Name = "Server Hop",
    Callback = function()
        local success, req = pcall(function()
            return game:HttpGet('https://games.roblox.com/v1/games/' .. game.PlaceId .. '/servers/Public?sortOrder=Asc&limit=100')
        end)
        if success and req then
            local body = HttpService:JSONDecode(req)
            if body and body.data then
                for _, v in ipairs(body.data) do
                    if v.playing < (v.maxPlayers - 2) and v.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer)
                        break
                    end
                end
            end
        end
    end
})

-- ==========================================
-- MAIN LOOP
-- ==========================================
task.spawn(function()
    while true do
        local dt = task.wait(0.03 + (getPing() * 0.1))
        local char, myHrp, myHum = getMyChar()

        if char and myHrp and myHum and myHum.Health > 0 then
            local hpPercent = (myHum.Health / myHum.MaxHealth) * 100

            if Settings.AutoSafeZone and hpPercent <= Settings.LowHealthThreshold then
                if not isInSafeZone then
                    isInSafeZone = true
                    myHrp.CFrame = CFrame.new(Settings.SafePlatformPos)
                end
            elseif isInSafeZone and hpPercent >= (Settings.LowHealthThreshold + 25) then
                isInSafeZone = false
            end

            if Settings.AutoFarm and not isInSafeZone then
                if not currentTarget or not isAlive(currentTarget) then
                    local targets = {}
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and isAlive(p) then table.insert(targets, p) end
                    end
                    currentTarget = #targets > 0 and targets[math.random(1, #targets)] or nil
                end

                if currentTarget and isAlive(currentTarget) then
                    local targetHrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
                    if targetHrp then
                        local targetPos = targetHrp.Position
                        local myPos = myHrp.Position
                        local distance = (targetPos - myPos).Magnitude

                        if distance > Settings.AttackDistance then
                            local moveAmount = math.min(Settings.TweenSpeed * dt, distance)
                            local direction = (targetPos - myPos).Unit
                            myHrp.CFrame = CFrame.new(myPos + (direction * moveAmount), Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
                        else
                            myHrp.CFrame = CFrame.new(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
                            useSkills(char, myHum)
                        end
                    end
                end
            end
        end
    end
end)
