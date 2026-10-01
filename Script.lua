-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SETTINGS
-- ==========================================
local Settings = {
    AutoFarm = false,
    TweenSpeed = 90,
    CheckInterval = 0.05,
    AttackDistance = 3.5,
    TargetStreaks = true,
    
    -- Safe Zone / Low HP Escape
    AutoSafeZone = true,
    LowHealthThreshold = 30,
    SafePlatformPos = Vector3.new(0, 500, 0),

    -- Auto-Block
    AutoBlock = false,
    AutoBlockRange = 20,

    -- Auto Awakening (G)
    AutoAwakening = true,

    -- Anti-Fling & Fast Recovery
    AntiFling = true,
    FastRecovery = true,

    -- Smart Combo
    SmartCombo = true,

    -- ESP Visuals
    ESPEnabled = false,

    -- Server Utilities
    AntiAFK = true,
    AutoServerHopOnLowPlayers = false,
    MinPlayersForHop = 3
}

local TargetList = {}
local currentTarget = nil
local lastTargetScan = 0
local lastM1Time = tick()
local lastSkillTime = tick()
local isBlocking = false
local isInSafeZone = false
local safePlatformInstance = nil
local espHolders = {}

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================
local function isAlive(player)
    if not player or not player:IsDescendantOf(Players) then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    return hrp and humanoid and humanoid.Health > 0
end

local function getMyChar()
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function pressKeyAsync(keyCode)
    task.spawn(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function toggleBlock(state)
    if isBlocking == state then return end
    isBlocking = state
    VirtualInputManager:SendKeyEvent(state, Enum.KeyCode.F, false, game)
end

local function clickM1()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

local function getOrCreateSafePlatform()
    if safePlatformInstance and safePlatformInstance.Parent then
        return safePlatformInstance
    end

    local part = Instance.new("Part")
    part.Name = "TSB_SafePlatform"
    part.Size = Vector3.new(50, 2, 50)
    part.Position = Settings.SafePlatformPos
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0.5
    part.Color = Color3.fromRGB(0, 255, 150)
    part.Material = Enum.Material.ForceField
    part.Parent = workspace

    safePlatformInstance = part
    return part
end

local function serverHop()
    local servers = {}
    local req = game:HttpGet('https://games.roblox.com/v1/games/' .. game.PlaceId .. '/servers/Public?sortOrder=Asc&limit=100')
    local body = game:GetService("HttpService"):JSONDecode(req)
    if body and body.data then
        for _, v in ipairs(body.data) do
            if type(v) == "table" and v.playing < v.maxPlayers and v.id ~= game.JobId then
                table.insert(servers, v.id)
            end
        end
    end
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
    else
        Rayfield:Notify({Title = "Server Hop", Content = "Подходящий сервер не найден", Duration = 3})
    end
end

-- ==========================================
-- ANTI-AFK LOGIC
-- ==========================================
LocalPlayer.Idled:Connect(function()
    if Settings.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

-- ==========================================
-- ANTI-FLING & FAST RECOVERY LOGIC
-- ==========================================
RunService.Stepped:Connect(function()
    local myChar, myHrp, myHum = getMyChar()

    -- Anti-Fling
    if Settings.AntiFling and myChar then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in ipairs(p.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end

    -- Fast Recovery (Быстрый подъем из регдолла)
    if Settings.FastRecovery and myHum then
        local state = myHum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

-- ==========================================
-- AUTO AWAKENING (G) LOGIC
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if Settings.AutoAwakening and not isInSafeZone then
            local myChar = LocalPlayer.Character
            if myChar then
                local ultimateBar = LocalPlayer:FindFirstChild("PlayerGui") 
                    and LocalPlayer.PlayerGui:FindFirstChild("ScreenGui") 
                    and LocalPlayer.PlayerGui.ScreenGui:FindFirstChild("MagicHealth")
                
                local isFull = myChar:GetAttribute("Ultimate") == 100 or myChar:GetAttribute("Awakening") == true
                if isFull then
                    pressKeyAsync(Enum.KeyCode.G)
                end
            end
        end
    end
end)

-- ==========================================
-- AUTO-BLOCK LOGIC
-- ==========================================
local function checkAttackingEnemies()
    if not Settings.AutoBlock or isInSafeZone then return false end
    local myChar, myHrp = getMyChar()
    if not myHrp then return false end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local enemyChar = p.Character
            local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
            local enemyHum = enemyChar:FindFirstChildOfClass("Humanoid")

            if enemyHrp and enemyHum then
                local dist = (myHrp.Position - enemyHrp.Position).Magnitude
                if dist <= Settings.AutoBlockRange then
                    local animator = enemyHum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            if track.IsPlaying and track.WeightCurrent > 0 then
                                local animName = track.Name:lower()
                                if animName:find("attack") or animName:find("punch") or animName:find("swing") or animName:find("m1") or animName:find("skill") or animName:find("dash") then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

RunService.Heartbeat:Connect(function()
    if Settings.AutoBlock and not isInSafeZone then
        toggleBlock(checkAttackingEnemies())
    end
end)

-- ==========================================
-- ESP LOGIC
-- ==========================================
local function createESP(player)
    if espHolders[player] or player == LocalPlayer then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TSB_ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(0, 255, 150)
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Font = Enum.Font.SourceSansBold
    label.Parent = billboard

    espHolders[player] = { Billboard = billboard, Label = label }
end

local function removeESP(player)
    if espHolders[player] then
        if espHolders[player].Billboard then
            espHolders[player].Billboard:Destroy()
        end
        espHolders[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not Settings.ESPEnabled then
        for p, data in pairs(espHolders) do
            removeESP(p)
        end
        return
    end

    local _, myHrp = getMyChar()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if isAlive(p) then
                if not espHolders[p] then createESP(p) end

                local data = espHolders[p]
                local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
                local targetHum = p.Character:FindFirstChildOfClass("Humanoid")

                if targetHrp and targetHum and data then
                    data.Billboard.Parent = p.Character
                    local dist = myHrp and math.floor((myHrp.Position - targetHrp.Position).Magnitude) or 0
                    local hp = math.floor((targetHum.Health / targetHum.MaxHealth) * 100)

                    local streak = 0
                    local leaderstats = p:FindFirstChild("leaderstats")
                    if leaderstats and leaderstats:FindFirstChild("Streak") then
                        streak = leaderstats.Streak.Value
                    end

                    data.Label.Text = string.format("%s\nHP: %d%% | Dist: %dm | Streak: %d", p.DisplayName, hp, dist, streak)

                    if streak >= 5 then
                        data.Label.TextColor3 = Color3.fromRGB(255, 50, 50)
                    else
                        data.Label.TextColor3 = Color3.fromRGB(0, 255, 150)
                    end
                end
            else
                removeESP(p)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(removeESP)

-- ==========================================
-- TARGET SELECTION LOGIC
-- ==========================================
local function updateTargetList()
    TargetList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local streak = 0
            local leaderstats = p:FindFirstChild("leaderstats")
            if leaderstats then
                local streakVal = leaderstats:FindFirstChild("Streak") or leaderstats:FindFirstChild("Kills")
                if streakVal then streak = streakVal.Value end
            end
            if p:GetAttribute("Killstreak") then
                streak = p:GetAttribute("Killstreak")
            end
            table.insert(TargetList, { Player = p, Streak = streak })
        end
    end

    if Settings.TargetStreaks then
        table.sort(TargetList, function(a, b)
            return a.Streak > b.Streak
        end)
    end
end

local function getNextTarget()
    if tick() - lastTargetScan > 15 or #TargetList == 0 then
        updateTargetList()
        lastTargetScan = tick()
    end

    for _, data in ipairs(TargetList) do
        local p = data.Player
        if isAlive(p) then
            return p
        end
    end
    return nil
end

-- ==========================================
-- RAYFIELD UI CREATION
-- ==========================================
local Window = Rayfield:CreateWindow({
   Name = "TSB AutoFarm Hub",
   Icon = 0,
   LoadingTitle = "Loading TSB Script...",
   LoadingSubtitle = "by JustTim :)",
   Theme = "Default",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "TSB_AutoFarm_Configs",
      FileName = "DefaultConfig"
   },
   KeySystem = false
})

local FarmTab = Window:CreateTab("Auto Farm", 0)
local CombatTab = Window:CreateTab("Combat", 0)
local DefenseTab = Window:CreateTab("Defense", 0)
local VisualsTab = Window:CreateTab("Visuals", 0)
local ServerTab = Window:CreateTab("Server", 0)

-- CREDITS SECTION
FarmTab:CreateSection("Script Info")
FarmTab:CreateLabel("Developer: JustTim :)")

-- AUTOFARM SECTION
FarmTab:CreateSection("Main Farm Settings")

FarmTab:CreateToggle({
   Name = "Enable Tween AutoFarm",
   CurrentValue = Settings.AutoFarm,
   Flag = "AutoFarmToggle",
   Callback = function(Value) Settings.AutoFarm = Value end,
})

FarmTab:CreateSlider({
   Name = "Tween Speed (Studs/Sec)",
   Range = {30, 200},
   Increment = 5,
   Suffix = "studs/s",
   CurrentValue = Settings.TweenSpeed,
   Flag = "SpeedSlider",
   Callback = function(Value)
       Settings.TweenSpeed = Value
   end,
})

FarmTab:CreateToggle({
   Name = "Target Top Killstreaks",
   CurrentValue = Settings.TargetStreaks,
   Flag = "StreakToggle",
   Callback = function(Value)
       Settings.TargetStreaks = Value
       updateTargetList()
   end,
})

-- COMBAT SECTION
CombatTab:CreateSection("Skills & Ultimate")

CombatTab:CreateToggle({
   Name = "Auto Awakening (G)",
   CurrentValue = Settings.AutoAwakening,
   Flag = "AutoAwakeToggle",
   Callback = function(Value) Settings.AutoAwakening = Value end,
})

CombatTab:CreateToggle({
   Name = "Smart Combo Execution",
   CurrentValue = Settings.SmartCombo,
   Flag = "SmartComboToggle",
   Callback = function(Value) Settings.SmartCombo = Value end,
})

CombatTab:CreateSection("Defense & Movement")

CombatTab:CreateToggle({
   Name = "Enable Auto-Block",
   CurrentValue = Settings.AutoBlock,
   Flag = "AutoBlockToggle",
   Callback = function(Value)
       Settings.AutoBlock = Value
       if not Value then toggleBlock(false) end
   end,
})

CombatTab:CreateSlider({
   Name = "Auto-Block Distance (Studs)",
   Range = {5, 40},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = Settings.AutoBlockRange,
   Flag = "AutoBlockRangeSlider",
   Callback = function(Value) Settings.AutoBlockRange = Value end,
})

CombatTab:CreateToggle({
   Name = "Anti-Fling",
   CurrentValue = Settings.AntiFling,
   Flag = "AntiFlingToggle",
   Callback = function(Value) Settings.AntiFling = Value end,
})

CombatTab:CreateToggle({
   Name = "Fast Get-Up (Ragdoll Recovery)",
   CurrentValue = Settings.FastRecovery,
   Flag = "FastRecoveryToggle",
   Callback = function(Value) Settings.FastRecovery = Value end,
})

-- DEFENSE TAB
DefenseTab:CreateSection("Safe Zone / Low HP Escape")

DefenseTab:CreateToggle({
   Name = "Enable Escape to Safe Zone",
   CurrentValue = Settings.AutoSafeZone,
   Flag = "SafeZoneToggle",
   Callback = function(Value) Settings.AutoSafeZone = Value end,
})

DefenseTab:CreateSlider({
   Name = "Low HP Escape Threshold (%)",
   Range = {10, 80},
   Increment = 5,
   Suffix = "%",
   CurrentValue = Settings.LowHealthThreshold,
   Flag = "LowHPSlider",
   Callback = function(Value) Settings.LowHealthThreshold = Value end,
})

DefenseTab:CreateButton({
   Name = "Manual Teleport to Safe Zone",
   Callback = function()
       local char, hrp = getMyChar()
       if hrp then
           getOrCreateSafePlatform()
           hrp.CFrame = CFrame.new(Settings.SafePlatformPos + Vector3.new(0, 4, 0))
       end
   end,
})

-- VISUALS TAB
VisualsTab:CreateSection("ESP Visuals")

VisualsTab:CreateToggle({
   Name = "Enable Player ESP",
   CurrentValue = Settings.ESPEnabled,
   Flag = "ESPToggle",
   Callback = function(Value) Settings.ESPEnabled = Value end,
})

-- SERVER TAB
ServerTab:CreateSection("Server Management")

ServerTab:CreateToggle({
   Name = "Anti-AFK Protection",
   CurrentValue = Settings.AntiAFK,
   Flag = "AntiAFKToggle",
   Callback = function(Value) Settings.AntiAFK = Value end,
})

ServerTab:CreateButton({
   Name = "Server Hop Now",
   Callback = function() serverHop() end,
})

Rayfield:LoadConfiguration()

-- ==========================================
-- MAIN BOT LOOP (TWEEN, FARM & SAFE ESCAPE)
-- ==========================================
task.spawn(function()
    local comboStep = 1

    while true do
        task.wait(Settings.CheckInterval)

        local char, hrp, hum = getMyChar()

        if char and hrp and hum and hum.Health > 0 then
            local hpPercent = (hum.Health / hum.MaxHealth) * 100

            -- ПРОВЕРКА LOW HP И ПОБЕГ
            if Settings.AutoSafeZone and hpPercent <= Settings.LowHealthThreshold then
                if not isInSafeZone then
                    isInSafeZone = true
                    getOrCreateSafePlatform()
                    hrp.CFrame = CFrame.new(Settings.SafePlatformPos + Vector3.new(0, 4, 0))
                end
            elseif isInSafeZone and hpPercent >= (Settings.LowHealthThreshold + 20) then
                isInSafeZone = false
            end

            -- ОСНОВНОЙ АВТО-ФАРМ
            if Settings.AutoFarm and not isInSafeZone then
                if not currentTarget or not isAlive(currentTarget) then
                    currentTarget = getNextTarget()
                end

                if currentTarget and isAlive(currentTarget) then
                    local targetHrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
                    if targetHrp then
                        local targetPos = targetHrp.Position
                        local myPos = hrp.Position
                        local distance = (targetPos - myPos).Magnitude

                        if distance > Settings.AttackDistance then
                            local direction = (targetPos - myPos).Unit
                            hrp.CFrame = CFrame.new(myPos + (direction * Settings.TweenSpeed * Settings.CheckInterval), Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
                        else
                            hrp.CFrame = CFrame.new(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))

                            if not isBlocking then
                                if Settings.SmartCombo then
                                    -- Умное комбинирование M1 и скиллов
                                    if tick() - lastM1Time >= 0.22 then
                                        clickM1()
                                        lastM1Time = tick()
                                        comboStep = comboStep + 1
                                    end

                                    if comboStep >= 4 and tick() - lastSkillTime >= 0.8 then
                                        pressKeyAsync(Enum.KeyCode.One)
                                        pressKeyAsync(Enum.KeyCode.Two)
                                        pressKeyAsync(Enum.KeyCode.Three)
                                        pressKeyAsync(Enum.KeyCode.Four)
                                        lastSkillTime = tick()
                                        comboStep = 1
                                    end
                                else
                                    -- Обычный спам
                                    if tick() - lastM1Time >= 0.25 then
                                        clickM1()
                                        lastM1Time = tick()
                                    end

                                    if tick() - lastSkillTime >= 1.0 then
                                        pressKeyAsync(Enum.KeyCode.One)
                                        pressKeyAsync(Enum.KeyCode.Two)
                                        pressKeyAsync(Enum.KeyCode.Three)
                                        pressKeyAsync(Enum.KeyCode.Four)
                 
