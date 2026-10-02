-- ==========================================
-- TSB AUTO-FARM HUB | Developer: JustTim :)
-- Multi-Region & KZ Optimization Fix
-- UI: Rayfield (Auto-Fallback Loader)
-- ==========================================

-- Блок безопасной загрузки UI (Обход блокировок провайдеров KZ / Beeline / Kazakhtelecom)
local Rayfield
local loadSuccess, err = pcall(function()
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end)

if not loadSuccess or not Rayfield then
    pcall(function()
        Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
end

if not Rayfield then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "TSB Hub Error",
        Text = "Не удалось загрузить UI. Включите 1.1.1.1 (WARP) или VPN!",
        Duration = 10
    })
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SETTINGS
-- ==========================================
local Settings = {
    AutoFarm = false,
    TweenSpeed = 90,
    AttackDistance = 3.5,
    
    -- Network & Ping Adaptations
    AdaptivePing = true,
    BaseCooldown = 0.45,

    -- Safe Zone
    AutoSafeZone = true,
    LowHealthThreshold = 30,
    SafePlatformPos = Vector3.new(0, 750, 0),

    -- Auto Skills & Awakening
    AutoAwakening = true,
    AutoSkills = true,

    -- Protections
    AntiFling = true,
    FastRecovery = true,
    AntiAFK = true
}

local currentTarget = nil
local lastSkillTime = 0
local isInSafeZone = false
local safePlatformInstance = nil

-- ==========================================
-- NETWORK UTILITIES
-- ==========================================
local function getPing()
    local pingItem = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
    if pingItem then
        return pingItem:GetValue() / 1000
    end
    return 0.15
end

local function getAdaptiveDelay()
    if not Settings.AdaptivePing then return Settings.BaseCooldown end
    local currentPing = getPing()
    return math.clamp(Settings.BaseCooldown + (currentPing * 0.8), 0.3, 1.2)
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================
local function isAlive(player)
    if not player or not player.Parent then return false end
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

local function useSkills(char, hum)
    local dynamicCooldown = getAdaptiveDelay()
    if not Settings.AutoSkills or (tick() - lastSkillTime < dynamicCooldown) then return end
    
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not backpack then return end

    local skills = {}
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(skills, item)
        end
    end

    if #skills > 0 then
        for _, skillTool in ipairs(skills) do
            pcall(function()
                hum:EquipTool(skillTool)
                task.wait(0.04 + (getPing() * 0.2))
                skillTool:Activate()
            end)
        end
        lastSkillTime = tick()
    end
end

local function getOrCreateSafePlatform()
    if safePlatformInstance and safePlatformInstance.Parent then
        return safePlatformInstance
    end

    local part = Instance.new("Part")
    part.Name = "TSB_SafePlatform_Bypass"
    part.Size = Vector3.new(80, 3, 80)
    part.Position = Settings.SafePlatformPos
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0.5
    part.Color = Color3.fromRGB(0, 200, 255)
    part.Material = Enum.Material.ForceField
    part.Parent = workspace

    safePlatformInstance = part
    return part
end

local function serverHopOptimized()
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

local function getNextTargetFromQueue()
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            table.insert(targets, p)
        end
    end

    if #targets > 0 then
        return targets[math.random(1, #targets)]
    end
    return nil
end

-- ==========================================
-- ANTI-AFK & PROTECTIONS
-- ==========================================
LocalPlayer.Idled:Connect(function()
    if Settings.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

RunService.Stepped:Connect(function()
    local myChar, _, myHum = getMyChar()

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

    if Settings.FastRecovery and myHum then
        local state = myHum:GetState()
        if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
            myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

-- AUTO AWAKENING
task.spawn(function()
    while true do
        task.wait(0.6 + getPing())
        if Settings.AutoAwakening and not isInSafeZone then
            local myChar = LocalPlayer.Character
            if myChar then
                local isFull = myChar:GetAttribute("Ultimate") == 100 or myChar:GetAttribute("Awakening") == true
                if isFull then
                    pcall(function()
                        game:GetService("ReplicatedStorage").Knit.Services.ClassService.RF.Awaken:InvokeServer()
                    end)
                end
            end
        end
    end
end)

-- ==========================================
-- RAYFIELD UI CREATION
-- ==========================================
local Window = Rayfield:CreateWindow({
   Name = "TSB Target AutoFarm [KZ Fix]",
   Icon = 0,
   LoadingTitle = "Loading AutoFarm Hub...",
   LoadingSubtitle = "by JustTim :)",
   Theme = "Default",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false
})

local FarmTab = Window:CreateTab("Auto Farm", 0)
local DefenseTab = Window:CreateTab("Safety", 0)
local CombatTab = Window:CreateTab("Combat", 0)
local ServerTab = Window:CreateTab("Server", 0)

FarmTab:CreateSection("Network & Optimization")
FarmTab:CreateToggle({
   Name = "Adaptive Ping Delay (KZ Lag Fix)",
   CurrentValue = Settings.AdaptivePing,
   Flag = "AdaptivePingToggle",
   Callback = function(Value) Settings.AdaptivePing = Value end,
})

FarmTab:CreateSection("Rotation Farm Settings")
FarmTab:CreateToggle({
   Name = "Enable Player Rotation AutoFarm",
   CurrentValue = Settings.AutoFarm,
   Flag = "AutoFarmToggle",
   Callback = function(Value) 
       Settings.AutoFarm = Value 
       currentTarget = nil
   end,
})

FarmTab:CreateSlider({
   Name = "Move Speed",
   Range = {30, 180},
   Increment = 5,
   Suffix = "studs/s",
   CurrentValue = Settings.TweenSpeed,
   Flag = "SpeedSlider",
   Callback = function(Value) Settings.TweenSpeed = Value end,
})

DefenseTab:CreateSection("Safe Zone / Low HP Escape")
DefenseTab:CreateToggle({
   Name = "Enable Safe Zone on Low HP",
   CurrentValue = Settings.AutoSafeZone,
   Flag = "SafeZoneToggle",
   Callback = function(Value) Settings.AutoSafeZone = Value end,
})

CombatTab:CreateSection("Skills & Combat")
CombatTab:CreateToggle({
   Name = "Auto Use Skills",
   CurrentValue = Settings.AutoSkills,
   Flag = "AutoSkillsToggle",
   Callback = function(Value) Settings.AutoSkills = Value end,
})

CombatTab:CreateToggle({
   Name = "Auto Awakening (G)",
   CurrentValue = Settings.AutoAwakening,
   Flag = "AutoAwakeToggle",
   Callback = function(Value) Settings.AutoAwakening = Value end,
})

ServerTab:CreateSection("Server Control")
ServerTab:CreateButton({
   Name = "Server Hop",
   Callback = function() serverHopOptimized() end,
})

-- ==========================================
-- MAIN BOT LOOP
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
                    getOrCreateSafePlatform()
                    myHrp.CFrame = CFrame.new(Settings.SafePlatformPos + Vector3.new(0, 4, 0))
                end
            elseif isInSafeZone and hpPercent >= (Settings.LowHealthThreshold + 25) then
                isInSafeZone = false
            end

            if Settings.AutoFarm and not isInSafeZone then
                if not currentTarget or not isAlive(currentTarget) then
                    currentTarget = getNextTargetFromQueue()
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
                            local nextPos = myPos + (direction * moveAmount)
                            
                            myHrp.CFrame = CFrame.new(nextPos, Vector3.new(targetPos.X, myPos.Y, targetPos.Z))
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
