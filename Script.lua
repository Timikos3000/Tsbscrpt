-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SETTINGS
-- ==========================================
local Settings = {
    AutoFarm = false,
    VoidRampage = true,
    UseTimerG = true,
    TimerG_Interval = 60,
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
local lastGTime = tick()
local lastM1Time = tick()
local lastSkillTime = tick()
local isExecutingUlt = false
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
                    -- Check enemy animators for active attack tracks
                    local animator = enemyHum:FindFirstChildOfClass("Animator")
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            if track.IsPlaying and track.WeightCurrent > 0 then
                                local animName = track.Name:lower()
                                
                                -- Filter standard combat animations
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

-- Scan for enemy attacks on every frame
RunService.Heartbeat:Connect(function()
    if Settings.AutoBlock and not isExecutingUlt then
        if checkAttackingEnemies() then
            toggleBlock(true)
        else
            toggleBlock(false)
        end
    end
end)

-- ==========================================
-- TSB REACH / HITBOX VISUALIZER
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
-- VOID RAMPAGE LOGIC
-- ==========================================
local function executeVoidRampage()
    if isExecutingUlt then return end
    isExecutingUlt = true
    toggleBlock(false)

    task.spawn(function()
        local char, hrp, hum = getMyChar()
        if not char or not hrp then 
            isExecutingUlt = false
            return 
        end

        -- Teleport 500 studs up
        hrp.CFrame = hrp.CFrame * CFrame.new(0, 500, 0)
        task.wait(0.2)

        Rayfield:Notify({
            Title = "⚡ VOID RAMPAGE",
            Content = "Activating ultimate skill at height...",
            Duration = 3,
            Image = 4483362458,
        })

        -- Press G (Activate Ultimate)
        pressKey(Enum.KeyCode.G, 0.1)
        task.wait(10.0)

        -- Press Skill 2
        pressKey(Enum.KeyCode.Two, 0.1)
        task.wait(0.2)

        Rayfield:Notify({
            Title = "⚡ VOID RAMPAGE",
            Content = "Mass teleporting across all players!",
            Duration = 3,
            Image = 4483362458,
        })

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isAlive(p) then
                local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp and hrp then
                    hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, -1)
                    clickM1()
                    task.wait(0.1)
                end
            end
        end

        -- Reset position into the void
        if hrp then
            hrp.CFrame = CFrame.new(hrp.Position.X, -500, hrp.Position.Z)
        end

        lastGTime = tick()
        task.wait(3)
        currentTarget = nil
        isExecutingUlt = false
    end)
end

-- ==========================================
-- RAYFIELD UI CREATION
-- ==========================================
local Window = Rayfield:CreateWindow({
   Name = "TSB | AutoFarm Hub",
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

local FarmTab = Window:CreateTab("Auto Farm", 4483362458)
local CombatTab = Window:CreateTab("Combat", 4483362458)

-- AUTOFARM SECTION
FarmTab:CreateSection("Main Farm")

FarmTab:CreateToggle({
   Name = "Enable Auto Farm",
   CurrentValue = Settings.AutoFarm,
   Flag = "AutoFarmToggle",
   Callback = function(Value) Settings.AutoFarm = Value end,
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

FarmTab:CreateSection("Ultimate Settings (Void Rampage)")

FarmTab:CreateToggle({
   Name = "Void Rampage Reset",
   CurrentValue = Settings.VoidRampage,
   Flag = "VoidRampageToggle",
   Callback = function(Value) Settings.VoidRampage = Value end,
})

FarmTab:CreateToggle({
   Name = "Activate G on Timer",
   CurrentValue = Settings.UseTimerG,
   Flag = "TimerGToggle",
   Callback = function(Value) Settings.UseTimerG = Value end,
})

FarmTab:CreateSlider({
   Name = "G Activation Cooldown (sec)",
   Range = {10, 300},
   Increment = 5,
   Suffix = "sec",
   CurrentValue = Settings.TimerG_Interval,
   Flag = "GTimerSlider",
   Callback = function(Value)
       Settings.TimerG_Interval = Value
   end,
})

FarmTab:CreateButton({
   Name = "🔥 Trigger Void Rampage Now",
   Callback = function()
       executeVoidRampage()
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

-- AUTO LOAD CONFIGURATION
Rayfield:LoadConfiguration()

-- ==========================================
-- MAIN BOT LOOP
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.1)

        if Settings.AutoFarm and not isExecutingUlt then
            local char, hrp, hum = getMyChar()

            if char and hrp and hum and hum.Health > 0 then

                if Settings.VoidRampage and Settings.UseTimerG and (tick() - lastGTime >= Settings.TimerG_Interval) then
                    executeVoidRampage()
                else
                    if not currentTarget or not isAlive(currentTarget) then
                        currentTarget = getNextTarget()
                    end

                    if currentTarget and isAlive(currentTarget) then
                        local targetHrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
                        if targetHrp then
                            hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 2.3)

                            -- Perform attacks only when not currently blocking
                            if not isBlocking then
                                if tick() - lastM1Time >= 0.3 then
                                    clickM1()
                                    lastM1Time = tick()
                                end

                                if tick() - lastSkillTime >= 1.2 then
                                    pressKey(Enum.KeyCode.One, 0.02)
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
