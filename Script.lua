-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SETTINGS
-- ==========================================
local Settings = {
    AutoFarm = false,
    TweenSpeed = 90, -- Studs per second
    CheckInterval = 0.1, -- 0.1s update interval
    AttackDistance = 3.5,
    TargetStreaks = true,
    
    -- Hitbox Expander / Reach Settings
    HitboxExpanded = false,
    HitboxSize = 15,

    -- Auto-Block Settings
    AutoBlock = false,
    AutoBlockRange = 20
}

local TargetList = {}
local currentTarget = nil
local lastTargetScan = 0
local lastM1Time = tick()
local lastSkillTime = tick()
local isBlocking = false

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

local function pressKey(keyCode, holdTime)
    holdTime = holdTime or 0.05
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(holdTime)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function toggleBlock(state)
    if isBlocking == state then return end
    isBlocking = state
    VirtualInputManager:SendKeyEvent(state, Enum.KeyCode.F, false, game)
end

local function clickM1()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.04)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

-- ==========================================
-- AUTO-BLOCK LOGIC
-- ==========================================
local function checkAttackingEnemies()
    if not Settings.AutoBlock then return false end
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
    if Settings.AutoBlock then
        if checkAttackingEnemies() then
            toggleBlock(true)
        else
            toggleBlock(false)
        end
    end
end)

-- ==========================================
-- HITBOX EXPANDER / REACH VISUALIZER
-- ==========================================
RunService.Heartbeat:Connect(function()
    if Settings.HitboxExpanded then
        local myChar, myHrp = getMyChar()
        if myHrp then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and isAlive(p) then
                    local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if targetHrp then
                        local dist = (myHrp.Position - targetHrp.Position).Magnitude
                        if dist <= Settings.HitboxSize then
                            local highlight = p.Character:FindFirstChild("TSB_Highlight")
                            if not highlight then
                                highlight = Instance.new("Highlight")
                                highlight.Name = "TSB_Highlight"
                                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                                highlight.FillTransparency = 0.5
                                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                                highlight.Parent = p.Character
                            end
                        else
                            if p.Character:FindFirstChild("TSB_Highlight") then
                                p.Character.TSB_Highlight:Destroy()
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function resetHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("TSB_Highlight") then
            p.Character.TSB_Highlight:Destroy()
        end
    end
end

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
    if tick() - lastTargetScan > 60 or #TargetList == 0 then
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
   LoadingSubtitle = "by Assistant",
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
CombatTab:CreateSection("Defense")

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
   Callback = function(Value)
       Settings.AutoBlockRange = Value
   end,
})

CombatTab:CreateSection("Hitbox Expander (Reach)")

CombatTab:CreateToggle({
   Name = "Enable Hitbox Expander",
   CurrentValue = Settings.HitboxExpanded,
   Flag = "HitboxToggle",
   Callback = function(Value)
       Settings.HitboxExpanded = Value
       if not Value then
           resetHitboxes()
       end
   end,
})

CombatTab:CreateSlider({
   Name = "Hitbox Radius (Studs)",
   Range = {2, 50},
   Increment = 1,
   Suffix = "studs",
   CurrentValue = Settings.HitboxSize,
   Flag = "HitboxSizeSlider",
   Callback = function(Value)
       Settings.HitboxSize = Value
   end,
})

Rayfield:LoadConfiguration()

-- ==========================================
-- MAIN BOT LOOP (TWEEN & FARM)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(Settings.CheckInterval)

        if Settings.AutoFarm then
            local char, hrp, hum = getMyChar()

            if char and hrp and hum and hum.Health > 0 then
                if not currentTarget or not isAlive(currentTarget) then
                    currentTarget = getNextTarget()
                end

                if currentTarget and isAlive(currentTarget) then
                    local targetHrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
                    if targetHrp then
                        local targetPos = targetHrp.Position
                        local myPos = hrp.Position
                        local distance = (targetPos - myPos).Magnitude

                        -- Smooth Movement at 90 Studs/Sec
                        if distance > Settings.AttackDistance then
                            local direction = (targetPos - myPos).Unit
                            hrp.CFrame = CFrame.new(myPos + (direction * Settings.TweenSpeed * Settings.CheckInterval), Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
                        else
                            hrp.CFrame = CFrame.new(myPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))

                            if not isBlocking then
                                if tick() - lastM1Time >= 0.25 then
                                    clickM1()
                                    lastM1Time = tick()
                                end

                                if tick() - lastSkillTime >= 1.0 then
                                    pressKey(Enum.KeyCode.One, 0.02)
                                    pressKey(Enum.KeyCode.Two, 0.02)
                                    pressKey(Enum.KeyCode.Three, 0.02)
                                    pressKey(Enum.KeyCode.Four, 0.02)
                                    lastSkillTime = tick()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
