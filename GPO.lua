--[[
    ██╗   ██╗███████╗███╗   ██╗██╗ ██████╗███████╗
    ██║   ██║██╔════╝████╗  ██║██║██╔════╝██╔════╝
    ██║   ██║█████╗  ██╔██╗ ██║██║██║     █████╗
    ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║██║██║     ██╔══╝
     ╚████╔╝ ███████╗██║ ╚████║██║╚██████╗███████╗
      ╚═══╝  ╚══════╝╚═╝  ╚═══╝╚═╝ ╚═════╝╚══════╝
      GRAND PIECE ONLINE | HALLOWEEN PT 1 (SPOOKSVILLE)
      Build: Oct 11 2026 | XENO-OPTIMIZED | STEALTH
      + BOSS FARMS + DUNGEONS + AUTO FISH/MERCHANT/HOP
      + AUTO RECOMMENDED QUESTS
      Keyless | No dependencies | PC + Mobile | RightShift
--]]

--============ SERVICES ============
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")
local Lighting         = game:GetService("Lighting")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")
local VirtualUser      = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local function char() return LP.Character end
local function hrp()
    local c = char(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
    local c = char(); return c and c:FindFirstChildOfClass("Humanoid")
end

--============ STATE ============
local State = {
    AutoFarm=false, AutoQuest=false, AutoStats=false, AutoPrompt=false,
    AutoQuestPro=false, QuestCycle=45,
    FruitESP=false, FruitSniper=false, PlayerESP=false, BossESP=false,
    Speed=false, Jump=false, Noclip=false, InfJump=false,
    Fullbright=false, AntiAFK=false,
    Hitbox=false, Fly=false, Jitter=false, NetOwn=false,
    HideHUD=false, LowGfx=false,
    BossFarm=false, RotateBoss=false,
    DungeonAuto=false, AutoReenter=false,
    AutoFish=false, AutoBait=false,
    AutoMerchant=false, HopForBoss=false,
    SpeedVal=90, JumpVal=120, PromptRange=40,
    HitboxSize=12, FlySpeed=60, FOV=70, MaxZoom=400, ClockTime=14,
}
local SelectedEnemy = "Auto"
local CurrentBoss = "Vice Admiral"
local MerchantItem = "Mythical Fruit Chest"
local DungeonTarget = "Impel Down"

--============ REMOTES ============
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes")
local CommF_ = Remotes and Remotes:FindFirstChild("CommF_")
local CommE_ = Remotes and Remotes:FindFirstChild("CommE_")
local function Invoke(...)
    if CommF_ then
        local ok, res = pcall(function() return CommF_:InvokeServer(...) end)
        if ok then return res end
    end
end
local function Fire(...)
    if CommE_ then pcall(function() CommE_:FireServer(...) end) end
end

--============ HELPERS ============
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=title, Text=text, Duration=3})
    end)
end
local function isAlive()
    local h = hum(); return h and h.Health > 0 and hrp() ~= nil
end
local function firePrompt(prompt)
    pcall(function()
        local orig = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd()
        prompt.HoldDuration = orig
    end)
end
local function firePromptsOn(model)
    if not model then return end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then firePrompt(d) end
    end
end

local function getEnemies()
    local list = {}
    local container = workspace:FindFirstChild("Enemies") or workspace
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Model") and obj ~= char() then
            local h = obj:FindFirstChildOfClass("Humanoid")
            local r = obj:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 and not Players:GetPlayerFromCharacter(obj) then
                table.insert(list, {model=obj, hum=h, root=r})
            end
        end
    end
    return list
end

local function nearestEnemy()
    if not isAlive() then return nil end
    local myPos = hrp().Position
    local best, bestDist = nil, math.huge
    for _, e in ipairs(getEnemies()) do
        if SelectedEnemy == "Auto"
        or e.model.Name:lower():find(SelectedEnemy:lower(), 1, true) then
            local d = (e.root.Position - myPos).Magnitude
            if d < bestDist then best, bestDist = e, d end
        end
    end
    return best
end

local moveTarget, moveAlpha = nil, 0
local function moveTo(pos, speed) moveTarget = pos; moveAlpha = speed or 1 end
RunService.RenderStepped:Connect(function(dt)
    if moveTarget and hrp() then
        local r = hrp()
        local goal = CFrame.new(moveTarget, moveTarget + (r.CFrame.LookVector * 5))
        r.CFrame = r.CFrame:Lerp(goal, math.clamp(moveAlpha * dt * 10, 0, 1))
        if (r.Position - moveTarget).Magnitude < 4 then moveTarget = nil end
    end
end)

local function attackModel(m)
    local r = hrp(); if not r or not m then return end
    local mr = m:FindFirstChild("HumanoidRootPart"); if not mr then return end
    r.CFrame = CFrame.lookAt(r.Position,
        Vector3.new(mr.Position.X, r.Position.Y, mr.Position.Z))
    Fire("Attack")
end
local function attackEnemy(e) if e and e.model then attackModel(e.model) end end

local function getFruits()
    local out = {}
    local env = workspace:FindFirstChild("Env")
    local settings = env and env:FindFirstChild("Settings")
    if not settings then return out end
    for _, d in ipairs(settings:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.ObjectText and d.ObjectText ~= "" then
            local base = d.Parent
            if base and base:IsA("BasePart") then
                table.insert(out, {prompt=d, part=base, name=d.ObjectText})
            end
        end
    end
    return out
end

local function getNearbyPrompts(range)
    local out = {}
    if not hrp() then return out end
    local myPos = hrp().Position
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local p = d.Parent
            if p and p:IsA("BasePart")
            and (p.Position - myPos).Magnitude <= (range or State.PromptRange) then
                table.insert(out, d)
            end
        end
    end
    return out
end

local function findPromptsByText(subs)
    local out = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local txt = ((d.ObjectText or "") .. " " .. (d.ActionText or "")):lower()
            for _, s in ipairs(subs) do
                if txt:find(s:lower(), 1, true) then table.insert(out, d); break end
            end
        end
    end
    return out
end

local function findModelByKeyword(kw)
    for _, m in ipairs(workspace:GetDescendants()) do
        if (m:IsA("Model") or m:IsA("BasePart"))
        and m.Name:lower():find(kw:lower(), 1, true) then
            return m
        end
    end
end

-- Quest NPC finder (nearest NPC with a quest/talk prompt or a "!" marker)
local function findQuestNPC()
    if not hrp() then return nil end
    local myPos = hrp().Position
    local best, bd = nil, math.huge
    for _, p in ipairs(findPromptsByText({"quest","talk","turn in","accept","deliver","task"})) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m and m ~= char() then
            local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if r then
                local d = (r.Position - myPos).Magnitude
                if d < bd then best, bd = m, d end
            end
        end
    end
    return best
end

--============ ESP ============
local HAS_DRAWING = (type(Drawing) == "table" or type(Drawing) == "userdata")
                    and Drawing.new ~= nil
local espCache = {}
local function makeESP(obj, color, text)
    if espCache[obj] then return espCache[obj] end
    local box = Drawing.new("Square")
    box.Thickness = 1; box.Filled = false; box.Color = color; box.Visible = true
    local lbl = Drawing.new("Text")
    lbl.Size = 13; lbl.Center = true; lbl.Outline = true
    lbl.Color = color; lbl.Visible = true; lbl.Text = text
    espCache[obj] = {box=box, lbl=lbl}
    return espCache[obj]
end
local function drawBox(cam, r, color, text, active)
    active[r] = true
    local d = makeESP(r, color, text)
    local pos, on = cam:WorldToViewportPoint(r.Position)
    if on then
        local s = 1200 / (cam.CFrame.Position - r.Position).Magnitude
        local w, h = s*1.6, s*2.2
        d.box.Size = Vector2.new(w,h)
        d.box.Position = Vector2.new(pos.X-w/2, pos.Y-h/2)
        d.lbl.Position = Vector2.new(pos.X, pos.Y-h/2-16)
        d.box.Visible = true; d.lbl.Visible = true
    else
        d.box.Visible = false; d.lbl.Visible = false
    end
end
local function updateESP()
    if not HAS_DRAWING then return end
    local cam = workspace.CurrentCamera; if not cam then return end
    local active = {}
    if State.PlayerESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then drawBox(cam, r, Color3.fromRGB(0,170,255), p.Name, active) end
            end
        end
    end
    if State.FruitESP then
        for _, f in ipairs(getFruits()) do
            drawBox(cam, f.part, Color3.fromRGB(255,215,0), f.name, active)
        end
    end
    if State.BossESP then
        for _, b in ipairs(getAllBosses()) do
            local r = b.model:FindFirstChild("HumanoidRootPart")
            if r then drawBox(cam, r, Color3.fromRGB(200,80,255), b.name, active) end
        end
    end
    if State.AutoMerchant then
        local m = findModelByKeyword("merchant")
        if m then
            local r = m:FindFirstChild("HumanoidRootPart") or (m:IsA("BasePart") and m)
            if r then drawBox(cam, r, Color3.fromRGB(255,140,0), "Merchant", active) end
        end
    end
    if State.AutoQuestPro then
        local q = findQuestNPC()
        if q then
            local r = q:FindFirstChild("HumanoidRootPart") or q.PrimaryPart
            if r then drawBox(cam, r, Color3.fromRGB(80,255,140), "Quest", active) end
        end
    end
    for obj, d in pairs(espCache) do
        if not active[obj] then d.box.Visible = false; d.lbl.Visible = false end
    end
end

--============ LOOPS ============
task.spawn(function() while true do updateESP(); task.wait() end end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if State.AutoFarm and isAlive() then
            local e = nearestEnemy()
            if e then
                if (e.root.Position - hrp().Position).Magnitude > 8 then
                    moveTo(e.root.Position, 1.5)
                else
                    attackEnemy(e)
                    if State.Jitter then task.wait(math.random()*60/1000) end
                end
            end
        end
        if State.FruitSniper and isAlive() then
            local fruits = getFruits()
            if #fruits > 0 then
                local best, bd = nil, math.huge
                for _, f in ipairs(fruits) do
                    local d = (f.part.Position - hrp().Position).Magnitude
                    if d < bd then best, bd = f, d end
                end
                if best then
                    if bd > 6 then moveTo(best.part.Position, 1.5)
                    else firePrompt(best.prompt) end
                end
            end
        end
        if State.AutoPrompt and isAlive() then
            for _, pr in ipairs(getNearbyPrompts()) do
                firePrompt(pr); task.wait(0.05)
            end
        end
    end
end)

-- Auto recommended quests (loop quest NPCs: accept -> kill -> turn in)
local questNPC, questStart, questLastPrompt = nil, 0, 0
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.AutoQuestPro and isAlive() then
            if not questNPC or not questNPC.Parent then
                questNPC = findQuestNPC(); questStart = tick(); questLastPrompt = 0
            end
            local nr = questNPC and (questNPC:FindFirstChild("HumanoidRootPart") or questNPC.PrimaryPart)
            if nr then
                local d = (nr.Position - hrp().Position).Magnitude
                if d > 14 then
                    moveTo(nr.Position, 3)
                else
                    if tick() - questLastPrompt > 4 then
                        firePromptsOn(questNPC); questLastPrompt = tick()
                    end
                end
                -- farm only enemies near the NPC so we don't wander off
                local e = nearestEnemy()
                if e then
                    if (e.root.Position - nr.Position).Magnitude < 90 then
                        if (e.root.Position - hrp().Position).Magnitude > 10 then
                            moveTo(e.root.Position, 2)
                        else
                            attackEnemy(e)
                            if State.Jitter then task.wait(math.random()*60/1000) end
                        end
                    elseif d < 14 then
                        moveTo(nr.Position, 3)
                    end
                end
                -- move to next quest NPC after the cycle
                if tick() - questStart > State.QuestCycle then
                    questNPC = nil
                end
            else
                questNPC = nil
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.AutoQuest and isAlive() then Invoke("getQuest") end
        if State.AutoStats and hum() then
            Invoke("BuyHaki", "Geppo"); Invoke("Stats", "Melee")
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        local h = hum()
        if h then
            if State.Speed then h.WalkSpeed = State.SpeedVal end
            if State.Jump then h.UseJumpPower = true; h.JumpPower = State.JumpVal end
        end
    end
end)

-- Hitbox Expander
local hitboxOrig = {}
task.spawn(function()
    while true do
        task.wait(0.15)
        if State.Hitbox and isAlive() then
            for _, e in ipairs(getEnemies()) do
                local r = e.root
                if r then
                    if not hitboxOrig[r] then hitboxOrig[r] = r.Size end
                    r.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                end
            end
        elseif next(hitboxOrig) then
            for r, sz in pairs(hitboxOrig) do
                if r and r.Parent then r.Size = sz end
                hitboxOrig[r] = nil
            end
        end
    end
end)

-- Network ownership
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.NetOwn and isAlive() then
            for _, e in ipairs(getEnemies()) do
                pcall(function() e.root:SetNetworkOwner(LP) end)
            end
        end
    end
end)

-- Fly
local Fly = {conn=nil, bv=nil, bg=nil}
local function startFly()
    local h, r = hum(), hrp(); if not h or not r then return end
    Fly.bv = Instance.new("BodyVelocity")
    Fly.bv.MaxForce = Vector3.new(9e9,9e9,9e9); Fly.bv.Velocity = Vector3.zero; Fly.bv.Parent = r
    Fly.bg = Instance.new("BodyGyro")
    Fly.bg.MaxTorque = Vector3.new(9e9,9e9,9e9); Fly.bg.P = 9e4; Fly.bg.Parent = r
    h.PlatformStand = true
    Fly.conn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        Fly.bv.Velocity = dir * State.FlySpeed
        Fly.bg.CFrame = cam.CFrame
    end)
end
local function stopFly()
    if Fly.conn then Fly.conn:Disconnect() end
    if Fly.bv then Fly.bv:Destroy() end
    if Fly.bg then Fly.bg:Destroy() end
    local h = hum(); if h then h.PlatformStand = false end
end
local function setFly(on) if on then startFly() else stopFly() end end

local noclipConn
local function setNoclip(on)
    if on then
        noclipConn = RunService.Stepped:Connect(function()
            if char() then
                for _, p in ipairs(char():GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() end
        if char() then
            for _, p in ipairs(char():GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

UserInputService.JumpRequest:Connect(function()
    if State.InfJump and hum() then
        hum():ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local fbConn
local function setFullbright(on)
    if on then
        Lighting.Brightness = 3; Lighting.GlobalShadows = false
        fbConn = RunService.RenderStepped:Connect(function() Lighting.FogEnd = 100000 end)
    else
        if fbConn then fbConn:Disconnect() end
    end
end

LP.Idled:Connect(function()
    if State.AntiAFK then
        VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
    end
end)

local function setFOV(v) pcall(function() workspace.CurrentCamera.FieldOfView = v end) end
local function setZoom(v) pcall(function() LP.CameraMaxZoomDistance = v end) end
local function setFPS(v) pcall(function() setfpscap(v) end) end
local function setClock(v) pcall(function() Lighting.ClockTime = v end) end
local function killAtmosphere()
    pcall(function()
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") or a:IsA("Sky") then a.Parent = nil end
        end
        Lighting.FogEnd = 100000
    end)
end
local function setHideHUD(on)
    pcall(function()
        for _, g in ipairs(LP.PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name ~= "VeniceGPO" then g.Enabled = not on end
        end
    end)
end
local function setLowGfx(on)
    pcall(function()
        if on then
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                    v.Enabled = false
                end
            end
        end
    end)
end

--============ ISLANDS ============
local Islands = {
    FirstSea = {
        ["Start Island"]=Vector3.new(15,15,15), ["Shells Town"]=Vector3.new(1100,20,3000),
        ["Orange Town"]=Vector3.new(-200,20,-2500), ["Syrup Village"]=Vector3.new(2000,20,-1800),
        ["Baratie"]=Vector3.new(-3000,20,-1500), ["Arlong Park"]=Vector3.new(3400,20,-2500),
        ["Loguetown"]=Vector3.new(-500,20,4500), ["Reverse Mountain"]=Vector3.new(200,20,7000),
        ["Drum Island"]=Vector3.new(-4000,20,6000), ["Alabasta"]=Vector3.new(3500,20,7500),
        ["Jaya"]=Vector3.new(5000,20,9500), ["Skypiea"]=Vector3.new(-6000,900,9000),
        ["Long Ring Long Land"]=Vector3.new(-7000,20,12000), ["Water 7"]=Vector3.new(7000,20,13000),
        ["Enies Lobby"]=Vector3.new(-8000,20,15000), ["Thriller Bark"]=Vector3.new(8000,20,16500),
        ["Sabaody"]=Vector3.new(-9000,20,19000), ["Impel Base"]=Vector3.new(-11000,20,20500),
    },
    SecondSea = {
        ["Fishman Island"]=Vector3.new(0,-200,500), ["Punk Hazard"]=Vector3.new(0,30,-3000),
        ["Dressrosa"]=Vector3.new(3000,30,4000), ["Zou"]=Vector3.new(-3500,30,5000),
        ["Blossom Falls"]=Vector3.new(-5000,30,6500), ["Whole Cake"]=Vector3.new(5000,30,7000),
        ["Wano"]=Vector3.new(-6000,30,9000), ["Egghead"]=Vector3.new(7000,30,11000),
        ["Fishing Hub"]=Vector3.new(-2000,30,-4500),
    },
    Events = {
        ["Spooksville"]=Vector3.new(-6500,30,8000), ["Spooksville Alt"]=Vector3.new(-9000,30,9500),
    },
}
local function tpIsland(pos) moveTarget = pos; moveAlpha = 5 end
local function islandCoord(name)
    for _, sea in ipairs({Islands.FirstSea, Islands.SecondSea, Islands.Events}) do
        if sea[name] then return sea[name] end
    end
end

--============ BOSSES ============
local BossIslands = {
    ["Bandit Boss"]="Start Island", ["Mohawk"]="Reverse Mountain",
    ["Crocodile"]="Alabasta", ["Eneru"]="Skypiea",
    ["Rob Lucci"]="Enies Lobby", ["Gecko Moria"]="Thriller Bark",
    ["Vice Admiral"]="Loguetown", ["Radiant Admiral"]="Loguetown",
    ["Ice Admiral"]="Punk Hazard", ["Wisteria"]="Dressrosa",
    ["Diamond"]="Dressrosa", ["Don Swan"]="Dressrosa",
    ["Vander Decken"]="Fishman Island", ["Fukaboshi"]="Fishman Island",
    ["Doflamingo"]="Dressrosa", ["Pedro"]="Whole Cake",
    ["Cake Queen"]="Whole Cake", ["Katakuri"]="Whole Cake",
    ["Biscuit Commander"]="Whole Cake", ["Brook"]="Fishman Island",
    ["Kaido"]="Blossom Falls", ["Roger"]="Wano",
}
local BossOrder = {}
for k in pairs(BossIslands) do table.insert(BossOrder, k) end
table.sort(BossOrder)

local function scanFor(predicate)
    local out, seen = {}, {}
    local folders = {workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Bosses"), workspace}
    for _, f in ipairs(folders) do
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if m:IsA("Model") and not seen[m] and m:FindFirstChildOfClass("Humanoid") then
                    if predicate(m) then seen[m]=true; table.insert(out, m) end
                end
            end
        end
    end
    return out
end
local function findBossModel(name)
    local list = scanFor(function(m)
        return m.Name:lower():find(name:lower(), 1, true) ~= nil
    end)
    return list[1]
end
function getAllBosses()
    local list = scanFor(function(m)
        for nm in pairs(BossIslands) do
            if m.Name:lower():find(nm:lower(), 1, true) then return true end
        end
        return false
    end)
    local out = {}
    for _, m in ipairs(list) do table.insert(out, {model=m, name=m.Name}) end
    return out
end

local bossIndex = 1
local lastSeen = 0
task.spawn(function()
    while true do
        task.wait(0.4)
        if State.BossFarm and isAlive() then
            local name = State.RotateBoss and BossOrder[bossIndex] or CurrentBoss
            if name then
                local m = findBossModel(name)
                if m then
                    lastSeen = tick()
                    local mr = m:FindFirstChild("HumanoidRootPart")
                    if mr then
                        if (mr.Position - hrp().Position).Magnitude > 12 then
                            moveTo(mr.Position, 2)
                        else
                            attackModel(m)
                            if State.Jitter then task.wait(math.random()*60/1000) end
                        end
                    end
                else
                    local coord = islandCoord(BossIslands[name])
                    if coord then moveTo(coord, 2) end
                    if tick() - lastSeen > 4 and State.RotateBoss then
                        bossIndex = bossIndex % #BossOrder + 1
                        lastSeen = tick()
                    end
                end
            end
        end
    end
end)

--============ DUNGEONS ============
local Dungeons = {
    ["Impel Down"]      = {island="Impel Base",   keys={"enter","raid","impel"}},
    ["Kaido Dungeon"]   = {island="Blossom Falls",keys={"enter","dungeon","dragon","kaido"}},
    ["Factory Stage"]   = {island="Blossom Falls",keys={"enter","dungeon","factory"}},
    ["Big Mom Dungeon"] = {island="Whole Cake",   keys={"enter","dungeon","raid","cake"}},
}
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.DungeonAuto and isAlive() then
            local d = Dungeons[DungeonTarget]
            if d then
                for _, p in ipairs(findPromptsByText(d.keys)) do
                    if p.Parent and p.Parent:IsA("BasePart") and hrp()
                    and (p.Parent.Position - hrp().Position).Magnitude < 40 then
                        firePrompt(p)
                    end
                end
            end
            local e = nearestEnemy()
            if e then
                if (e.root.Position - hrp().Position).Magnitude > 8 then
                    moveTo(e.root.Position, 2)
                else
                    attackEnemy(e)
                    if State.Jitter then task.wait(math.random()*60/1000) end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(3)
        if State.AutoReenter and State.DungeonAuto and isAlive() then
            local d = Dungeons[DungeonTarget]
            if d then
                local coord = islandCoord(d.island)
                if coord and hrp() and (hrp().Position - coord).Magnitude > 600 then
                    moveTo(coord, 3)
                end
            end
        end
    end
end)

--============ AUTO FISH / MERCHANT / HOP ============
task.spawn(function()
    while true do
        task.wait(0.4)
        if State.AutoFish and isAlive() then
            for _, p in ipairs(findPromptsByText({"fish","cast","reel","catch"})) do
                if p.Parent and p.Parent:IsA("BasePart") and hrp()
                and (p.Parent.Position - hrp().Position).Magnitude < 25 then
                    firePrompt(p)
                end
            end
        end
        if State.AutoBait and isAlive() then
            for _, p in ipairs(findPromptsByText({"bait"})) do
                if p.Parent and p.Parent:IsA("BasePart") and hrp()
                and (p.Parent.Position - hrp().Position).Magnitude < 25 then
                    firePrompt(p)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.AutoMerchant and isAlive() then
            local m = findModelByKeyword("merchant")
            if m then
                local r = m:FindFirstChild("HumanoidRootPart") or (m:IsA("BasePart") and m)
                if r then
                    if (r.Position - hrp().Position).Magnitude > 12 then
                        moveTo(r.Position, 3)
                    else
                        for _, p in ipairs(findPromptsByText({"talk","shop","merchant","buy","trade"})) do
                            firePrompt(p)
                        end
                        Invoke("Buy", MerchantItem)
                    end
                end
            end
        end
    end
end)

local function hopToSmaller()
    task.spawn(function()
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                "https://games.roblox.com/v1/games/" .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        if ok and res and res.data then
            for _, s in ipairs(res.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                    end)
                    return
                end
            end
        end
    end)
end

local hopCooldown = 0
task.spawn(function()
    while true do
        task.wait(2)
        if State.HopForBoss and CurrentBoss and tick() > hopCooldown then
            if not findBossModel(CurrentBoss) then
                hopCooldown = tick() + 25
                notify("Hop", "Boss not up - hopping for " .. CurrentBoss)
                hopToSmaller()
            end
        end
    end
end)

--============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = "VeniceGPO"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
pcall(function() if gethui then gui.Parent = gethui() end end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0,520,0,360)
main.Position = UDim2.new(0.5,-260,0.5,-180)
main.BackgroundColor3 = Color3.fromRGB(16,16,24)
main.BorderSizePixel = 0; main.Active = true; main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(150,90,255); stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,32); title.BackgroundColor3 = Color3.fromRGB(26,22,40)
title.Text = "VENICE | GPO | FULL AUTO SUITE"
title.TextColor3 = Color3.fromRGB(190,130,255)
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.BorderSizePixel = 0; title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0,10)

do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = main.Position
        end
    end)
    title.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                      startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,-16,0,26); tabBar.Position = UDim2.new(0,8,0,36)
tabBar.BackgroundTransparency = 1; tabBar.Parent = main
local tl = Instance.new("UIListLayout", tabBar)
tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0,4)

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-16,1,-74); content.Position = UDim2.new(0,8,0,66)
content.BackgroundTransparency = 1; content.Parent = main

local pages = {}
local function makePage(name)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1,0,1,0); s.BackgroundTransparency = 1; s.BorderSizePixel = 0
    s.ScrollBarThickness = 4; s.Visible = false; s.Parent = content
    local l = Instance.new("UIListLayout", s); l.Padding = UDim.new(0,6)
    pages[name] = s
end
local function selectTab(name) for n,p in pairs(pages) do p.Visible = (n==name) end end

local TABS = {"Farm","Boss","Dungeon","Auto","ESP","Stealth","Teleport","Player","Misc"}
for _, tn in ipairs(TABS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,50,1,0); b.BackgroundColor3 = Color3.fromRGB(30,30,46)
    b.Text = tn; b.TextColor3 = Color3.fromRGB(200,210,230)
    b.Font = Enum.Font.Gotham; b.TextSize = 11; b.BorderSizePixel = 0; b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        selectTab(tn); b.BackgroundColor3 = Color3.fromRGB(90,50,180)
    end)
    if tn == "Farm" then b.BackgroundColor3 = Color3.fromRGB(90,50,180) end
end
for _, p in ipairs(TABS) do makePage(p) end
selectTab("Farm")

local ToggleRefs = {}
local function setToggle(key, val)
    State[key] = val
    local r = ToggleRefs[key]
    if r then
        r.btn.Text = val and "ON" or "OFF"
        r.btn.BackgroundColor3 = val and Color3.fromRGB(50,170,90) or Color3.fromRGB(70,70,90)
        if r.cb then pcall(r.cb, val) end
    end
end
local function toggle(parent, label, key, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-8,0,30); f.BackgroundColor3 = Color3.fromRGB(24,24,36)
    f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,6)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0.72,0,1,0); t.Position = UDim2.new(0,10,0,0)
    t.BackgroundTransparency = 1; t.Text = label
    t.TextColor3 = Color3.fromRGB(210,215,235); t.Font = Enum.Font.Gotham
    t.TextSize = 12; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = f
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,50,0,20); btn.Position = UDim2.new(1,-58,0.5,-10)
    btn.BackgroundColor3 = Color3.fromRGB(70,70,90); btn.Text = "OFF"
    btn.TextColor3 = Color3.fromRGB(255,255,255); btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11; btn.BorderSizePixel = 0; btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)
    ToggleRefs[key] = {btn=btn, cb=cb}
    btn.MouseButton1Click:Connect(function() setToggle(key, not State[key]) end)
end
local function button(parent, label, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-8,0,26); b.BackgroundColor3 = Color3.fromRGB(58,38,118)
    b.Text = label; b.TextColor3 = Color3.fromRGB(220,230,255)
    b.Font = Enum.Font.Gotham; b.TextSize = 12; b.BorderSizePixel = 0; b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
end
local function slider(parent, label, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-8,0,40); f.BackgroundColor3 = Color3.fromRGB(24,24,36)
    f.BorderSizePixel = 0; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,6)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,-10,0,16); t.Position = UDim2.new(0,8,0,2)
    t.BackgroundTransparency = 1; t.Text = label .. ": " .. default
    t.TextColor3 = Color3.fromRGB(210,215,235); t.Font = Enum.Font.Gotham
    t.TextSize = 12; t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,-20,0,8); bar.Position = UDim2.new(0,10,0,24)
    bar.BackgroundColor3 = Color3.fromRGB(50,50,70); bar.BorderSizePixel = 0; bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(130,80,255); fill.BorderSizePixel = 0; fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,4)
    local function set(v)
        v = math.clamp(v,min,max)
        fill.Size = UDim2.new((v-min)/(max-min),0,1,0)
        t.Text = label .. ": " .. math.floor(v); cb(v)
    end
    bar.InputBegan:Connect(function()
        local c = UserInputService.InputChanged:Connect(function(m)
            if m.UserInputType == Enum.UserInputType.MouseMovement
            or m.UserInputType == Enum.UserInputType.Touch then
                local rel = (m.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
                set(min + rel*(max-min))
            end
        end)
        local e = UserInputService.InputEnded:Connect(function()
            if c then c:Disconnect() end; if e then e:Disconnect() end
        end)
    end)
end

--==== FARM ====
local farm = pages["Farm"]
button(farm, ">> ONE-CLICK: SPOOKSVILLE CANDY FARM <<", function()
    task.spawn(function()
        tpIsland(Islands.Events["Spooksville"]); notify("Preset","TP to Spooksville...")
        task.wait(2.5)
        SelectedEnemy = "Skeleton"
        setToggle("AutoFarm", true); setToggle("AutoPrompt", true); setToggle("Speed", true)
        State.SpeedVal = math.max(State.SpeedVal, 120)
        notify("Preset","Candy Skeleton farm running")
    end)
end)
button(farm, ">> AUTO RECOMMENDED QUESTS (loop) <<", function()
    setToggle("AutoQuestPro", true); setToggle("Speed", true)
    notify("Quests","Auto recommended quests running")
end)
toggle(farm, "Auto Recommended Quests", "AutoQuestPro")
slider(farm, "Quest cycle (sec)", 15, 180, 45, function(v) State.QuestCycle = v end)
toggle(farm, "Auto Farm (nearest enemy)", "AutoFarm")
toggle(farm, "Auto Trick-or-Treat / Prompts", "AutoPrompt")
toggle(farm, "Auto Quest (accept)", "AutoQuest")
toggle(farm, "Auto Stats", "AutoStats")
button(farm, "Filter: AUTO", function() SelectedEnemy="Auto"; notify("Farm","AUTO") end)
button(farm, "Filter: Candy Skeleton", function() SelectedEnemy="Skeleton"; notify("Farm","Skeleton") end)
button(farm, "Filter: Wandering Soul", function() SelectedEnemy="Soul"; notify("Farm","Soul") end)
button(farm, "Filter: Bandit", function() SelectedEnemy="Bandit"; notify("Farm","Bandit") end)
button(farm, "Filter: Marine", function() SelectedEnemy="Marine"; notify("Farm","Marine") end)

--==== BOSS ====
local boss = pages["Boss"]
button(boss, ">> AUTO BOSS FARM: ROTATE ALL <<", function()
    setToggle("RotateBoss", true); setToggle("BossFarm", true); setToggle("Speed", true)
    notify("Boss","Rotating all bosses")
end)
toggle(boss, "Auto Boss Farm (current target)", "BossFarm")
toggle(boss, "Rotate Through All Bosses", "RotateBoss")
toggle(boss, "Server Hop for Boss if not up", "HopForBoss")
button(boss, ">> Next Boss <<", function()
    bossIndex = bossIndex % #BossOrder + 1
    CurrentBoss = BossOrder[bossIndex]
    notify("Boss","Next: " .. CurrentBoss)
end)
local bh = Instance.new("TextLabel")
bh.Size = UDim2.new(1,-8,0,20); bh.BackgroundTransparency = 1
bh.Text = "— Select Boss —"; bh.TextColor3 = Color3.fromRGB(170,130,255)
bh.Font = Enum.Font.GothamBold; bh.TextSize = 12; bh.Parent = boss
for _, nm in ipairs(BossOrder) do
    button(boss, nm .. "  (" .. BossIslands[nm] .. ")", function()
        CurrentBoss = nm; setToggle("RotateBoss", false); setToggle("BossFarm", true)
        local coord = islandCoord(BossIslands[nm])
        if coord then tpIsland(coord) end
        notify("Boss","Target: " .. nm)
    end)
end

--==== DUNGEON ====
local dun = pages["Dungeon"]
button(dun, ">> AUTO DUNGEON: ENTER + CLEAR <<", function()
    setToggle("DungeonAuto", true); setToggle("Speed", true)
    notify("Dungeon","Entering + clearing " .. DungeonTarget)
end)
toggle(dun, "Auto Enter + Clear Dungeon", "DungeonAuto")
toggle(dun, "Auto Re-enter on death", "AutoReenter")
local dh = Instance.new("TextLabel")
dh.Size = UDim2.new(1,-8,0,20); dh.BackgroundTransparency = 1
dh.Text = "— Select Dungeon —"; dh.TextColor3 = Color3.fromRGB(170,130,255)
dh.Font = Enum.Font.GothamBold; dh.TextSize = 12; dh.Parent = dun
for name, d in pairs(Dungeons) do
    button(dun, name .. "  (" .. d.island .. ")", function()
        DungeonTarget = name
        local coord = islandCoord(d.island)
        if coord then tpIsland(coord) end
        setToggle("DungeonAuto", true)
        notify("Dungeon","Target: " .. name)
    end)
end
button(dun, "Enter Fishing Hub (docks)", function()
    tpIsland(Islands.SecondSea["Fishing Hub"]); notify("Dungeon","Fishing Hub")
end)

--==== AUTO ====
local au = pages["Auto"]
toggle(au, "Auto Fish (cast/reel)", "AutoFish")
toggle(au, "Auto Buy Fish Bait", "AutoBait")
toggle(au, "Auto Merchant (find + buy)", "AutoMerchant")
button(au, "Merchant Item: Mythical Fruit Chest", function()
    MerchantItem = "Mythical Fruit Chest"; notify("Auto","Merchant item: Mythical Fruit Chest")
end)
button(au, "Merchant Item: Karoo Mount", function()
    MerchantItem = "Karoo Mount"; notify("Auto","Merchant item: Karoo Mount")
end)
button(au, "Merchant Item: Legendary Fruit Chest", function()
    MerchantItem = "Legendary Fruit Chest"; notify("Auto","Merchant item: Legendary")
end)
button(au, ">> Server Hop Now <<", function() hopToSmaller() end)

--==== ESP ====
local esp = pages["ESP"]
if not HAS_DRAWING then
    local w = Instance.new("TextLabel")
    w.Size = UDim2.new(1,-8,0,20); w.BackgroundTransparency = 1
    w.Text = "Drawing API not detected - ESP off"
    w.TextColor3 = Color3.fromRGB(255,160,160); w.Font = Enum.Font.Gotham
    w.TextSize = 12; w.Parent = esp
end
toggle(esp, "Devil Fruit ESP", "FruitESP")
toggle(esp, "Auto Fruit Sniper (TP + grab)", "FruitSniper")
toggle(esp, "Player ESP", "PlayerESP")
toggle(esp, "Boss ESP (purple)", "BossESP")

--==== STEALTH ====
local st = pages["Stealth"]
button(st, "STEALTH MASTER (legit profile)", function()
    State.SpeedVal = 32; State.JumpVal = 60
    setToggle("Jitter", true); setToggle("NetOwn", true); setToggle("Hitbox", false)
    notify("Stealth","Conservative legit profile applied")
end)
toggle(st, "Hitbox Expander (client-side)", "Hitbox")
slider(st, "Hitbox Size", 4, 40, 12, function(v) State.HitboxSize = v end)
toggle(st, "Fly (WASD / Space / Ctrl)", "Fly", setFly)
slider(st, "Fly Speed", 20, 300, 60, function(v) State.FlySpeed = v end)
toggle(st, "Human-like Attack Jitter", "Jitter")
toggle(st, "Network Ownership (smooth motion)", "NetOwn")
slider(st, "Camera FOV", 40, 120, 70, setFOV)
slider(st, "Max Zoom Distance", 100, 2000, 400, setZoom)
slider(st, "Clock Time (Lighting)", 0, 24, 14, setClock)
button(st, "Unlock FPS (240)", function() setFPS(240); notify("Stealth","FPS cap -> 240") end)
button(st, "Remove Atmosphere / Fog", function() killAtmosphere(); notify("Stealth","Atmosphere removed") end)
toggle(st, "Hide HUD / Other GUIs", "HideHUD", setHideHUD)
toggle(st, "Low Graphics (kill particles)", "LowGfx", setLowGfx)

--==== TELEPORT ====
local tp = pages["Teleport"]
local function buildTP(name, tbl)
    local h2 = Instance.new("TextLabel")
    h2.Size = UDim2.new(1,-8,0,22); h2.BackgroundTransparency = 1
    h2.Text = "— " .. name .. " —"; h2.TextColor3 = Color3.fromRGB(170,130,255)
    h2.Font = Enum.Font.GothamBold; h2.TextSize = 13; h2.Parent = tp
    for isl, pos in pairs(tbl) do
        button(tp, isl, function() tpIsland(pos); notify("Teleport", isl) end)
    end
end
buildTP("First Sea", Islands.FirstSea)
buildTP("Second Sea", Islands.SecondSea)
buildTP("Events", Islands.Events)

--==== PLAYER ====
local pl = pages["Player"]
toggle(pl, "Speed Hack", "Speed")
slider(pl, "WalkSpeed", 16, 300, 90, function(v) State.SpeedVal = v end)
toggle(pl, "Jump Boost", "Jump")
slider(pl, "JumpPower", 50, 500, 120, function(v) State.JumpVal = v end)
toggle(pl, "Noclip", "Noclip", setNoclip)
toggle(pl, "Infinite Jump", "InfJump")

--==== MISC ====
local misc = pages["Misc"]
toggle(misc, "Fullbright / No Fog", "Fullbright", setFullbright)
toggle(misc, "Anti-AFK", "AntiAFK")
button(misc, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LP) end)
button(misc, "Server Hop (smaller)", function() hopToSmaller() end)

UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

notify("VENICE | GPO","Loaded. RightShift toggles the menu.")
print("[VENICE | GPO] Loaded on " .. tostring(LP.Name) .. " | Full auto suite | Xeno-safe")

add script
