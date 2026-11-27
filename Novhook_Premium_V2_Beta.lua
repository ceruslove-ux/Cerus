-- Novhook premiumV2 (beta)
-- [ 통합 ] Linoria Hub v3 | 크로스헤어 간격/스핀/애니메이션 + 우측 정확한 내 대미지 힛로그 (블럭 현상 제거본)
-- ==========================================
--==========================================================================
--  Anti-Cheat (Kicia portable + Rivals shield)
--  참고: Kicia rebuild 원본은 b7 전체 바이패스를 제외함.
--  이식 가능 부분만 + Rivals Kick/CameraSecurity/weaktable
--==========================================================================
pcall(function()
    local function safeCclosure(fn)
        return (newcclosure and newcclosure(fn)) or fn
    end
    local function getExFn(name)
        local v
        pcall(function() v = getfenv(0)[name] end)
        if type(v) ~= "function" then pcall(function() v = getgenv()[name] end) end
        if type(v) ~= "function" then pcall(function() v = getfenv()[name] end) end
        return type(v) == "function" and v or nil
    end

    -- Kicia: thread identity
    local setthreadidentity_ = getExFn("setthreadidentity") or getExFn("setidentity")
    if setthreadidentity_ then
        pcall(setthreadidentity_, 8)
    end

    -- Kicia: clonefunction FireServer (훅 탐지 완화)
    local clonefunction_ = getExFn("clonefunction")
    local function clonefn(f)
        if clonefunction_ and f then
            local ok, r = pcall(clonefunction_, f)
            if ok and r then return r end
        end
        return f
    end
    pcall(function()
        local re = Instance.new("RemoteEvent")
        local ure = Instance.new("UnreliableRemoteEvent")
        getgenv().__NH_UseSleepyCore = true
getgenv().HeadStuds = getgenv().HeadStuds or 3
getgenv().DesyncDist = getgenv().DesyncDist or 3 -- pure packet rage only
getgenv().__NH_FireServer = clonefn(re.FireServer)
        getgenv().__NH_UFireServer = clonefn(ure.FireServer)
        re:Destroy()
        ure:Destroy()
    end)

    local plr = game:GetService("Players").LocalPlayer

    -- Kick 차단
    if hookfunction and plr then
        pcall(function()
            local oldKick
            oldKick = hookfunction(plr.Kick, safeCclosure(function(self, ...)
                if self == plr then return end
                return oldKick(self, ...)
            end))
        end)
    end

    if hookmetamethod then
        pcall(function()
            local oldNc
            oldNc = hookmetamethod(game, "__namecall", safeCclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" or method == "kick" then
                    if self == plr then return end
                end
                return oldNc(self, ...)
            end))
        end)
        -- Kicia/Lion: weak table AC (CameraSecurity / Misc / Analytics)
        pcall(function()
            local okEnv, renv = pcall(getrenv)
            local sm = okEnv and renv and renv.setmetatable
            if sm and hookfunction then
                local oldSm
                oldSm = hookfunction(sm, safeCclosure(function(Table, Metatable)
                    if type(Metatable) == "table" and rawget(Metatable, "__mode") then
                        local mode = rawget(Metatable, "__mode")
                        if mode == "kv" or mode == "v" or mode == "k" then
                            local okT, trace = pcall(debug.traceback)
                            trace = okT and trace or ""
                            if trace:find("MiscellaneousController", 1, true)
                                or trace:find("CameraSecurity", 1, true)
                                or trace:find("AnalyticsPipeline", 1, true) then
                                return oldSm({1, 2, 3}, {})
                            end
                        end
                    end
                    return oldSm(Table, Metatable)
                end))
            end
        end)
    end

    -- CameraSecurity 무력화
    pcall(function()
        local ps = plr:FindFirstChild("PlayerScripts")
        local mod = ps and ps:FindFirstChild("Modules") and ps.Modules:FindFirstChild("CameraSecurity")
        if mod then
            local cs = require(mod)
            local mt = getrawmetatable and getrawmetatable(cs) or getmetatable(cs)
            if mt then
                if setreadonly then pcall(setreadonly, mt, false) end
                mt.__index = function() return nil end
                mt.__tostring = function() return "LocalPlayer = nil" end
            end
        end
    end)

    getgenv().__NH_AC = getgenv().__NH_AC or {
        lastRemote = 0,
        minRemoteGap = 0.004,
        underJitter = true,
        voidSafe = true,
    }

    -- Rivals void/OOB soft shield: kill floor 위 유지 + 공허 체류 시 낙사/킥 완화
    pcall(function()
        local RS = game:GetService("RunService")
        local LP = game:GetService("Players").LocalPlayer
        local lastSafe = CFrame.new(0, 50, 0)
        RS.Heartbeat:Connect(function()
            if getgenv().__NH_AC and getgenv().__NH_AC.voidSafe == false then return end
            local char = LP and LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end
            local killY = -500
            pcall(function()
                local h = workspace.FallenPartsDestroyHeight
                if typeof(h) == "number" then killY = h end
            end)
            local minY = killY + 40
            local p = hrp.Position
            -- 정상 맵 높이면 세이브
            if p.Y > minY + 5 and p.Y < 400 then
                lastSafe = hrp.CFrame
            end
            -- 보이드/낙사 직전 보정 (밴 트리거 완화)
            if p.Y < minY then
                local ny = minY + 8 + math.random() * 6
                hrp.CFrame = CFrame.new(p.X, ny, p.Z)
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            end
            -- 공허 스팸 중이면 서버에 과도한 낙하 상태 안 남기게 속도 클램프
            if getgenv().VoidSpamEnabled == true or getgenv().__NH_VoidActive == true then
                local v = hrp.AssemblyLinearVelocity
                if v.Y < -90 then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X, -20, v.Z)
                end
            end
        end)
    end)
end)

getgenv().__NH_CanFireRemote = function()
    local ac = getgenv().__NH_AC
    if not ac then return true end
    local now = os.clock()
    local gap = tonumber(ac.minRemoteGap) or 0.012
    if now - (ac.lastRemote or 0) < gap then return false end
    ac.lastRemote = now
    return true
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = workspace
local Camera = Workspace.CurrentCamera
local Player = Players.LocalPlayer

-- Lobby / Immune
local function NH_isLobby()
    local lobby = false
    pcall(function()
        if getgenv().ForceInMatch then return end
        local fc
        pcall(function()
            local ps = Player:FindFirstChild("PlayerScripts")
            local c = ps and ps:FindFirstChild("Controllers")
            local mod = c and c:FindFirstChild("FighterController")
            if mod then fc = require(mod) end
        end)
        if not fc or not fc.LocalFighter then
            lobby = true
            return
        end
        local st = Player:GetAttribute("GameState") or Player:GetAttribute("State")
        if st then
            local t = tostring(st):lower()
            if t:find("lobby") or t:find("menu") or t:find("queue") then
                lobby = true
            end
        end
        if workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("LobbyMap") then
            if not fc.LocalFighter then lobby = true end
        end
    end)
    return lobby
end

-- Immune: 진짜 무적만 (일반 적은 발사)
-- 면역 체크 (경량 + 캐시) Lion식 ForceField + HitboxHead
-- 면역: 파란 돔 있으면 타격 금지, 돔이 사라진 뒤에만 타격
local NH_immCache = {}
local NH_IMM_TTL_YES = 0.04
local NH_IMM_TTL_NO = 0.06

local function NH_getFC()
    return nil
end
local function NH_getFighter(_plr)
    return nil
end

local function NH_hasDome(char)
    if not char then return true end

    -- 1) ForceField (재귀)
    if char:FindFirstChildWhichIsA("ForceField", true) then
        return true
    end

    -- 2) 자손 전체 검사
    for _, d in ipairs(char:GetDescendants()) do
        if d.ClassName == "ForceField" then
            return true
        end
        local n = d.Name
        if n == "ForceField" or n == "ForceField" or n == "ForceShield"
            or n == "Protection" or n == "SpawnProtection" then
            return true
        end
        -- 파란 돔 비주얼 (Part/Mesh 이름)
        local nl = string.lower(n)
        if nl:find("forcefield") or nl:find("spawnshield") or nl:find("spawn_protect") then
            return true
        end
        -- ForceField material bubble
        if d:IsA("BasePart") then
            local ok, mat = pcall(function() return d.Material end)
            if ok and mat == Enum.Material.ForceField then
                -- 몸 전체가 아닌 보호 이펙트만 (이름에 shield/dome/protect/ff)
                if nl:find("shield") or nl:find("dome") or nl:find("protect")
                    or nl:find("bubble") or nl:find("ff") or nl:find("spawn") then
                    return true 
                end
            end
        end
    end

    -- 3) 속성
    local v
    pcall(function()
        v = char:GetAttribute("ForceField")
            or char:GetAttribute("Immune")
            or char:GetAttribute("Invulnerable")
    end)
    if v == true then return true end
    return false
end

local function NH_isImmune(plr)
    if not plr or plr == Player then return true end
    local now = os.clock()
    local c = NH_immCache[plr]
    if c then
        local ttl = c.v and NH_IMM_TTL_YES or NH_IMM_TTL_NO
        if (now - c.t) < ttl then
            return c.v
        end
    end

    local immune = true
    pcall(function()
        local char = plr.Character
        if not char then
            immune = true
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            immune = true
            return
        end
        -- 파란 돔 있으면 면역 (타격 금지)
        if NH_hasDome(char) then
            immune = true
            return
        end
        immune = nil
    end)

    NH_immCache[plr] = { t = now, v = immune }
    return immune
end

local function NH_justUnlocked(_plr)
    return false
end

getgenv().NH_isImmune = NH_isImmune
getgenv().NH_getFighter = NH_getFighter
getgenv().NH_hasDome = NH_hasDome
getgenv().NH_invalidateImmune = function(plr)
    if plr then NH_immCache[plr] = nil end
end
getgenv().NH_justUnlocked = NH_justUnlocked

pcall(function()
    Players.PlayerRemoving:Connect(function(p)
        NH_immCache[p] = nil
    end)
    local function watch(p)
        if p == Player then return end
        local function hook(char)
            if not char then return end
            NH_immCache[p] = nil
            char.DescendantAdded:Connect(function(d)
                if d.ClassName == "ForceField"
                    or d.Name == "ForceField"
                    or d.Name == "SpawnForceField" then
                    NH_immCache[p] = { t = os.clock(), v = true }
                end
            end)
            char.DescendantRemoving:Connect(function(d)
                if d.ClassName == "ForceField"
                    or d.Name == "ForceField"
                    or d.Name == "SpawnForceField" then
                    -- 돔 사라짐 → 다음 검사부터 타격 가능
                    NH_immCache[p] = { t = 0, v = false }
                end
            end)
        end
        if p.Character then hook(p.Character) end
        p.CharacterAdded:Connect(hook)
    end
    for _, p in ipairs(Players:GetPlayers()) do watch(p) end
    Players.PlayerAdded:Connect(watch)
end)





local playerScripts = Player:FindFirstChild("PlayerScripts") or Player:WaitForChild("PlayerScripts", 5)
local controllers = playerScripts and playerScripts:FindFirstChild("Controllers")
local PlayerGui = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    warn('[Novhook] PlayerGui missing')
    PlayerGui = Instance.new('ScreenGui')
    PlayerGui.Name = 'PlayerGuiFallback'
end

-- Remove duplicate GUIs
for _, v in pairs(PlayerGui:GetChildren()) do
    if v.Name == "LuminousPureHub" or v.Name == "" or v.Name == "VoidSpamGui" or v.Name == "Melee" or v.Name == "RageUI" or v.Name == "SilentFOV" or v.Name == "CustomUI" then
        v:Destroy()
    end
end

-- 내가 최근에 공격했는지 체크하는 변수 및 헬스 트래킹
local lastAttackTime = 0
local function markMyAttack()
    lastAttackTime = tick()
end
getgenv().NH_MarkAttack = markMyAttack

local playerHealths = {}
local addHitLog -- forward

-- Hit log queue (UI 생기기 전 대비)
getgenv().HitLogEnabled = getgenv().HitLogEnabled or false
getgenv().NH_HitLogQueue = getgenv().NH_HitLogQueue or {}
local function queueOrShowHit(name, dmg)
    dmg = math.floor((tonumber(dmg) or 0) + 0.5)
    if dmg <= 0 then return end
    if type(addHitLog) == "function" then
        addHitLog(name, dmg)
    else
        table.insert(getgenv().NH_HitLogQueue, { name = name, dmg = dmg, t = tick() })
    end
end


-- audio (defined early so HealthChanged can use)
getgenv().KillSoundEnabled = true
getgenv().HitSoundEnabled = true
getgenv().KillSoundId = getgenv().KillSoundId or "4764109000"
getgenv().HitSoundId = getgenv().HitSoundId or "4764109000"
local _lastHitSnd, _lastKillSnd = 0, 0

local function playCheatSound(id, vol)
    if not id then return end
    pcall(function()
        local pure = tostring(id):gsub("%D", "")
        if pure == "" then return end
        local parent = Player:FindFirstChild("PlayerGui") or workspace.CurrentCamera or workspace
        local snd = Instance.new("Sound")
        snd.Name = "NH_SFX"
        snd.SoundId = "rbxassetid://" .. pure
        snd.Volume = vol or tonumber(getgenv().NH_SoundVol) or 3
        snd.PlaybackSpeed = 1
        snd.Looped = false
        snd.Parent = parent
        snd:Play()
        snd.Ended:Connect(function()
            pcall(function() snd:Destroy() end)
        end)
        task.delay(4, function() pcall(function() if snd and snd.Parent then snd:Destroy() end end) end)
    end)
end
getgenv().NH_PlaySound = playCheatSound


local function trackPlayerHealth(plr)
    if plr == Player then return end
    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            playerHealths[plr] = hum.Health
            hum.HealthChanged:Connect(function(newHp)
                local oldHp = playerHealths[plr]
                if oldHp == nil then
                    playerHealths[plr] = newHp
                    return
                end
                local diff = oldHp - newHp
                playerHealths[plr] = newHp
                -- 내가 최근 공격했을 때만 (본인 딜)
                local myHit = (tick() - lastAttackTime) < 1.0 and diff > 0.3
                if not myHit then return end

                if getgenv().HitLogEnabled then
                    queueOrShowHit(plr.Name, diff)
                end
                local now = tick()
                if getgenv().HitSoundEnabled and newHp > 0 and (now - _lastHitSnd) > 0.05 then
                    _lastHitSnd = now
                    playCheatSound(getgenv().HitSoundId, 2)
                end
                if getgenv().KillSoundEnabled and oldHp > 0 and newHp <= 0 and (now - _lastKillSnd) > 0.1 then
                    _lastKillSnd = now
                    playCheatSound(getgenv().KillSoundId, 3.5)
                end
            end)
        end
    end
    plr.CharacterAdded:Connect(onChar)
    if plr.Character then onChar(plr.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do trackPlayerHealth(p) end
Players.PlayerAdded:Connect(trackPlayerHealth)

-- 1. Load Linoria Library (multi-mirror, Delta/PC safe)
local Library, ThemeManager, SaveManager
local LINORIA_MIRRORS = {
    'https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/',
    'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/',
    'https://cdn.jsdelivr.net/gh/mstudio45/LinoriaLib@main/',
    'https://cdn.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/',
}

local function httpGet(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(res) == 'string' and #res > 100 then
        return res
    end
    ok, res = pcall(function()
        return game:HttpGetAsync(url)
    end)
    if ok and type(res) == 'string' and #res > 100 then
        return res
    end
    return nil
end

local function loadFromRepo(base, file)
    local body = httpGet(base .. file)
    if not body then return nil end
    local fn, err = loadstring(body)
    if not fn then
        warn('[Novhook] compile fail', file, err)
        return nil
    end
    local ok, res = pcall(fn)
    if ok then return res end
    warn('[Novhook] run fail', file, res)
    return nil
end

do
    local loaded = false
    for _, repo in ipairs(LINORIA_MIRRORS) do
        Library = loadFromRepo(repo, 'Library.lua')
        if Library and type(Library) == 'table' and Library.CreateWindow then
            pcall(function()
                ThemeManager = loadFromRepo(repo, 'addons/ThemeManager.lua')
            end)
            pcall(function()
                SaveManager = loadFromRepo(repo, 'addons/SaveManager.lua')
            end)
            loaded = true
                        break
        end
        Library = nil
    end
    if not loaded or not Library then
        warn('[Novhook] Linoria load FAIL — retry once...')
        task.wait(0.5)
        for _, repo in ipairs(LINORIA_MIRRORS) do
            Library = loadFromRepo(repo, 'Library.lua')
            if Library and type(Library) == 'table' and Library.CreateWindow then
                loaded = true
                pcall(function() ThemeManager = loadFromRepo(repo, 'addons/ThemeManager.lua') end)
                pcall(function() SaveManager = loadFromRepo(repo, 'addons/SaveManager.lua') end)
                break
            end
            Library = nil
        end
    end
    if not loaded or not Library then
        warn('[Novhook] Linoria still FAIL — building fallback UI')
        -- minimal fallback menu so user still sees something
        local sg = Instance.new('ScreenGui')
        sg.Name = 'NovhookFallback'
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 9999
        pcall(function()
            sg.Parent = (gethui and gethui()) or game:GetService('CoreGui')
        end)
        if not sg.Parent then
            pcall(function()
                sg.Parent = game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')
            end)
        end
        local fr = Instance.new('Frame')
        fr.Size = UDim2.fromOffset(320, 160)
        fr.Position = UDim2.fromScale(0.5, 0.5)
        fr.AnchorPoint = Vector2.new(0.5, 0.5)
        fr.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        fr.Parent = sg
        local c = Instance.new('UICorner', fr)
        c.CornerRadius = UDim.new(0, 10)
        local t = Instance.new('TextLabel')
        t.Size = UDim2.new(1, -16, 1, -16)
        t.Position = UDim2.fromOffset(8, 8)
        t.BackgroundTransparency = 1
        t.TextColor3 = Color3.fromRGB(255, 120, 120)
        t.TextWrapped = true
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        t.Text = 'Novhook: Linoria library failed to load.\nEnable HTTP requests in executor.\nRejoin and run again.'
        t.Parent = fr
        return
    end
end
print('[Novhook premiumV2] Linoria Library OK')
if getgenv then getgenv().__NH_LOADED = true end

-- stubs so nil Theme/Save never crash UI build
if type(ThemeManager) ~= 'table' then
    ThemeManager = {
        SetLibrary = function() end,
        SetFolder = function() end,
        ApplyToTab = function() end,
        ApplyToGroupbox = function() end,
    }
end
if type(SaveManager) ~= 'table' then
    SaveManager = {
        SetLibrary = function() end,
        SetFolder = function() end,
        IgnoreThemeSettings = function() end,
        SetIgnoreIndexes = function() end,
        BuildConfigSection = function() end,
        LoadAutoloadConfig = function() end,
    }
end

pcall(function() 
-- [OPT] 플레이어 목록 캐시 (0.1s)
do
    local _plrList, _plrAt = {}, 0
    getgenv().__NH_GetPlayers = function()
        local n = os.clock()
        if n - _plrAt > 0.1 then
            _plrList = game:GetService("Players"):GetPlayers()
            _plrAt = n
        end
        return _plrList
    end
end

getgenv().__NH_UseSleepyCore = true -- 구형 레이지 루프 비활성


-- Force all major features OFF until user enables (manual toggle)
do
    local off = {
        'AimbotEnabled','SilentAimEnabled','TriggerbotEnabled','RagebotEnabled',
        'VoidSpamEnabled','OrbitEnabled','GhostEnabled','AntiAimEnabled','FlickBotEnabled',
        'FlyEnabled','ESPEnabled','BaitingEnabled','KnifeModeEnabled',
        'UnnamedCounter','KiciaRageCounter','LionRageCounter','DeviceSpoofEnabled',
    }
    for _,k in ipairs(off) do
        if getgenv()[k] == nil then getgenv()[k] = false end
    end
    getgenv().VoidSpamEnabled = false
    getgenv().OrbitEnabled = false
    getgenv().GhostEnabled = false
    getgenv().AntiAimEnabled = false
end

Library.ShowCustomCursor = false
getgenv().SilentFOVShow = false
getgenv().CustomCrosshairEnabled = false
getgenv().FOVShowEnabled = getgenv().FOVShowEnabled or false
    pcall(function() Library.ToggleKeybind = Library.ToggleKeybind end)
end)

-- ========== PLAY 클릭: 오버레이 PlayerGui에 안 올림 ==========
task.spawn(function()
    while true do
        pcall(function()
            for _, n in ipairs({"aimbot FOV", "SilentFOV", "CustomUI", "NovhookPremiumFlyButtons"}) do
                local g = PlayerGui:FindFirstChild(n)
                if g then
                    local need = false
                    if n == "aimbot FOV" then
                        need = getgenv().FOVShowEnabled == true and getgenv().AimbotEnabled == true
                    elseif n == "SilentFOV" then
                        need = getgenv().SilentFOVShow == true
                    elseif n == "CustomUI" then
                        need = getgenv().CustomCrosshairEnabled == true
                    elseif n == "NovhookPremiumFlyButtons" then
                        need = getgenv().FlyEnabled == true
                    end
                    if not need then
                        g.Enabled = false
                        g.Parent = nil
                    end
                end
            end
            -- Linoria 메뉴가 로비를 가리면 닫기 (Toggled)
            if Library and Library.Unloaded ~= true then
                pcall(function()
                    if Library.Toggled == true and getgenv().__NH_ForceMenuClosed then
                        -- only if we set flag
                    end
                end)
            end
        end)
        task.wait(1)
    end
end)

-- 실행 직후 FOV만 정리 (메뉴는 열어둠)
task.defer(function()
    task.wait(0.2)
    pcall(function()
        for _, n in ipairs({"aimbot FOV", "SilentFOV", "CustomUI"}) do
            local g = PlayerGui and PlayerGui:FindFirstChild(n)
            if g then g.Enabled = false end
        end
        if Library then
            Library.Toggled = true
        end
    end)
end)

local Window
local okWin, winErr = pcall(function()
    Window = Library:CreateWindow({
        Title = 'Novhook premiumV2 (beta)',
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.15,
    })
end)
if not okWin or not Window then
    warn('[Novhook premium] CreateWindow failed:', winErr)
    -- retry minimal
    pcall(function()
        Window = Library:CreateWindow({ Title = 'Novhook premiumV2 (beta)', AutoShow = true })
    end)
end
if not Window then
    warn('[Novhook] UI window could not be created')
    return
end
print('[Novhook premiumV2] Window created OK')

-- Force ScreenGui visible on Delta / mobile
task.spawn(function()
    for i = 1, 30 do
        pcall(function()
            Library.Toggled = true
            if type(Library.Toggle) == 'function' and not Library.Toggled then
                Library:Toggle()
            end
            local parents = {}
            pcall(function()
                if gethui then table.insert(parents, gethui()) end
            end)
            pcall(function() table.insert(parents, game:GetService('CoreGui')) end)
            pcall(function() table.insert(parents, Player:FindFirstChild('PlayerGui')) end)
            for _, parent in ipairs(parents) do
                if not parent then continue end
                for _, g in ipairs(parent:GetChildren()) do
                    if g:IsA('ScreenGui') then
                        local n = string.lower(g.Name)
                        if n:find('linoria', 1, true) or n:find('novhook', 1, true) or n:find('library', 1, true) then
                            g.Enabled = true
                            g.DisplayOrder = 999
                            pcall(function() g.IgnoreGuiInset = true end)
                        end
                        for _, d in ipairs(g:GetDescendants()) do
                            if d:IsA('Frame') and (d.Name == 'Main' or d.Name == 'Window' or d.Name == 'Holder') then
                                d.Visible = true
                            end
                        end
                    end
                end
            end
            if Library.ScreenGui then
                Library.ScreenGui.Enabled = true
                Library.ScreenGui.DisplayOrder = 999
            end
        end)
        task.wait(0.25)
    end
    print('[Novhook premium] UI force-visible loop done')
end)

-- Continuous UI watchdog (Delta / mobile / PC)
task.spawn(function()
    local tries = 0
    while tries < 60 do
        tries = tries + 1
        pcall(function()
            if not Library then return end
            Library.Toggled = true
            if Library.ScreenGui then
                Library.ScreenGui.Enabled = true
                Library.ScreenGui.DisplayOrder = 10000
                pcall(function() Library.ScreenGui.IgnoreGuiInset = true end)
                pcall(function()
                    local parent = (gethui and gethui()) or game:GetService("CoreGui")
                    if Library.ScreenGui.Parent ~= parent then
                        Library.ScreenGui.Parent = parent
                    end
                end)
            end
            if type(Library.Toggle) == "function" and Library.Toggled == false then
                pcall(function() Library:Toggle() end)
            end
        end)
        task.wait(0.2)
    end
end)

-- CLICK FIX: only hide FOV overlays, do NOT close Linoria menu
task.spawn(function()
    local t0 = tick()
    while tick() - t0 < 3 do
        pcall(function()
            for _, n in ipairs({"aimbot FOV","SilentFOV","CustomUI","NovhookPremiumFlyButtons"}) do
                local g = PlayerGui and PlayerGui:FindFirstChild(n)
                if g and n ~= "NovhookPremiumFlyButtons" then
                    if not (n == "aimbot FOV" and getgenv().FOVShowEnabled) then
                        g.Enabled = false
                    end
                end
            end
        end)
        task.wait(0.5)
    end
end)


-- Linoria/오버레이가 로비 Play를 가리지 않게
task.defer(function()
    task.wait(0.5)
    pcall(function()
        -- FOV 확실히 끔
        for _, n in ipairs({"aimbot FOV", "SilentFOV", "CustomUI", "NovhookPremiumFlyButtons"}) do
            local g = PlayerGui:FindFirstChild(n)
            if g then
                if n == "NovhookPremiumFlyButtons" then
                    -- fly 꺼져 있으면 제거
                    if not getgenv().FlyEnabled then g:Destroy() end
                else
                    g.Enabled = false
                end
            end
        end
        -- CoreGui 쪽 Linoria 외 풀스크린 Active 프레임 완화
        local cg = game:GetService("CoreGui")
        for _, g in ipairs(cg:GetChildren()) do
            if g:IsA("ScreenGui") then
                local nm = string.lower(g.Name)
                if string.find(nm, "fov", 1, true) or string.find(nm, "novhook", 1, true) then
                    for _, d in ipairs(g:GetDescendants()) do
                        if d:IsA("GuiObject") and d.Active and d:IsA("Frame") then
                            local sz = d.Size
                            if sz.X.Scale >= 0.95 and sz.Y.Scale >= 0.95 then
                                d.Active = false
                            end
                        end
                    end
                end
            end
        end
    end)
end)




-- 2. Integrate existing skin changer and logic
local EnumLibrary, CosmeticLibrary, ItemLibrary, DataController
pcall(function()
    EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
    if EnumLibrary and EnumLibrary.WaitForEnumBuilder then
        EnumLibrary:WaitForEnumBuilder()
    end
end)
pcall(function()
    CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
end)
pcall(function()
    ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
end)
pcall(function()
    DataController = require(controllers:WaitForChild("PlayerDataController", 10))
end)

local equipped, favorites = {}, {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil

local function cloneCosmetic(name, cosmeticType, options)
    if not (CosmeticLibrary and CosmeticLibrary.Cosmetics) then return nil end
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for key, value in pairs(base) do data[key] = value end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary then
        local success, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
        if success and enumId then data.Enum, data.ObjectID = enumId, data.ObjectID or enumId end
    end
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end

local saveFile = "unlockall/config.json"
local function saveConfig()
    if not writefile then return end
    pcall(function()
        local config = {equipped = {}, favorites = favorites}
        for weapon, cosmetics in pairs(equipped) do
            config.equipped[weapon] = {}
            for cosmeticType, cosmeticData in pairs(cosmetics) do
                if cosmeticData and cosmeticData.Name then
                    config.equipped[weapon][cosmeticType] = {
                        name = cosmeticData.Name, seed = cosmeticData.Seed, inverted = cosmeticData.Inverted
                    }
                end
            end
        end
        makefolder("unlockall")
        writefile(saveFile, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    if not readfile or not isfile or not isfile(saveFile) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(saveFile))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cosmeticType, cosmeticData in pairs(cosmetics) do
                    local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                    if cloned then cloned.Seed = cosmeticData.seed equipped[weapon][cosmeticType] = cloned end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end

local originalOwnsCosmetic = nil
if CosmeticLibrary and type(CosmeticLibrary) == "table" then
originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    local function orig(...)
        if type(originalOwnsCosmetic) == "function" then
            return originalOwnsCosmetic(...)
        end
        return true
    end
    if type(name) == "string" and name:find("MISSING_") then return orig(self, inventory, name, weapon) end
    local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
    if cosmetic then
        local cType = cosmetic.Type
        if cType == "Skin" or cType == "Charm" or cType == "Dance" or cType == "Emote" or cType == "Wrap" or cType == "Wrapping" or (type(name)=="string" and (name:lower():find("charm") or name:lower():find("dance") or name:lower():find("emote") or name:lower():find("wrap"))) then
            return true
        end
    end
    return orig(self, inventory, name, weapon)
end

CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end

CosmeticLibrary.OwnsCosmeticUniversally = function(self, inventory, name, weapon)
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end

CosmeticLibrary.OwnsCosmeticForWeapon = function(self, inventory, name, weapon)
    local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end
end -- CosmeticLibrary guard

if DataController and type(DataController) == "table" then
local originalGet = DataController.Get
DataController.Get = function(self, key)
    local data = nil
    if type(originalGet) == "function" then
        local ok, res = pcall(originalGet, self, key)
        if ok then data = res end
    end
    if key == "CosmeticInventory" then
        local proxy = {}
        if data then for k, v in pairs(data) do 
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then proxy[k] = v end
        end end
        return setmetatable(proxy, {__index = function(t, k)
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then return true end
            return nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and table.clone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do 
                result[weapon][name] = isFav
            end
        end
        return result
    end

    -- Level / WinStreak / Tier spoof (클라 표시)
    if getgenv().LevelSpoofEnabled then
        local lv = tonumber(getgenv().SpoofLevel) or 999
        if key == "Level" or key == "PlayerLevel" or key == "AccountLevel" then
            return lv
        end
        if type(data) == "table" then
            local copy = table.clone(data)
            for _, k in ipairs({ "Level", "PlayerLevel", "AccountLevel", "XPLevel" }) do
                if copy[k] ~= nil then copy[k] = lv end
            end
            if key == "Stats" or key == "PlayerStats" or key == "Profile" then
                return copy
            end
        end
    end
    if getgenv().WinStreakSpoofEnabled then
        local ws = tonumber(getgenv().SpoofWinStreak) or 999
        if key == "WinStreak" or key == "CurrentWinStreak" or key == "WinsStreak" or key == "Streak" then
            return ws
        end
        if type(data) == "table" then
            local copy = table.clone(data)
            for _, k in ipairs({ "WinStreak", "CurrentWinStreak", "WinsStreak", "Streak", "BestWinStreak" }) do
                if copy[k] ~= nil then copy[k] = ws end
            end
            if key == "Stats" or key == "PlayerStats" or key == "Profile" then
                return copy
            end
        end
    end
    if getgenv().TierSpoofEnabled then
        local tier = getgenv().SpoofTier or "Champion"
        if key == "Tier" or key == "Rank" or key == "RankTier" or key == "RankName" then
            return tier
        end
        if type(data) == "table" then
            local copy = table.clone(data)
            for _, k in ipairs({ "Tier", "Rank", "RankTier", "RankName", "Division" }) do
                if copy[k] ~= nil then copy[k] = tier end
            end
            if key == "Stats" or key == "PlayerStats" or key == "Profile" or key == "Ranked" then
                return copy
            end
        end
    end

    return data
end

local originalGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponData(self, weaponName)
    if not data then return nil end
    local merged = {}
    for key, value in pairs(data) do merged[key] = value end
    merged.Name = weaponName
    local pack = equipped[weaponName]
    if not pack then
        for k, v in pairs(equipped) do
            if type(k) == "string" and type(weaponName) == "string"
                and k:lower() == weaponName:lower() then
                pack = v
                break
            end
        end
    end
    if pack then
        for cosmeticType, cosmeticData in pairs(pack) do
            merged[cosmeticType] = cosmeticData
            -- 게임이 Skin 필드만 읽는 경우
            if tostring(cosmeticType):lower() == "skin" then
                merged.Skin = cosmeticData
                merged.WeaponSkin = cosmeticData
            end
        end
    end
    return merged
end

local FighterController
pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)

if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
    local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
    local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
        local args = {...}
        
        if useItemRemote and self == useItemRemote then
            markMyAttack()
            local objectID = args[1]
            if FighterController then
                pcall(function()
                    local fighter = FighterController:GetFighter(Player)
                    if fighter and fighter.Items then
                        for _, item in pairs(fighter.Items) do
                            if item:Get("ObjectID") == objectID then lastUsedWeapon = item.Name break end
                        end
                    end
                end)
            end
        end
        
        if self == equipRemote then
            local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
            
            if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                local inventory = originalGet(DataController, "CosmeticInventory")
                if inventory and rawget(inventory, cosmeticName) then 
                    return oldNamecall(self, ...) 
                end
            end
            
            if cosmeticType == "Dance" or cosmeticType == "Emote" or (cosmeticName and (cosmeticName:lower():find("dance") or cosmeticName:lower():find("emote"))) then
                equipped.Dances = equipped.Dances or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped.Dances[cosmeticType] = nil
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped.Dances[cosmeticType] = cloned end
                end
                task.defer(function()
                    pcall(function() DataController.CurrentData:Replicate("CosmeticInventory") end)
                    task.wait(0.1)
                    saveConfig()
                end)
                return
            end
            
            equipped[weaponName] = equipped[weaponName] or {}
            if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                equipped[weaponName][cosmeticType] = nil
                if not next(equipped[weaponName]) then equipped[weaponName] = nil end
            else
                local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                if cloned then equipped[weaponName][cosmeticType] = cloned end
            end
            
            task.defer(function()
                pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                task.wait(0.1)
                saveConfig()
            end)
            return
        end
        
        if self == favoriteRemote then
            local wName, cName, isFav = args[1], args[2], args[3]
            local cosmetic = CosmeticLibrary.Cosmetics[cName]
            if cosmetic then
                favorites[wName] = favorites[wName] or {}
                favorites[wName][cName] = isFav or nil
                saveConfig()
                task.spawn(function() pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end) end)
            end
            return
        end
        
        return oldNamecall(self, ...)
    end)
end

local ClientItem
pcall(function() ClientItem = require(playerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)

if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == Player) and weaponName or nil
        
        if weaponPlayer == Player and equipped[weaponName] and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local targetTable = viewmodelRef[dataKey] or viewmodelRef.Data
            
            if targetTable then
                if equipped[weaponName].Skin then
                    targetTable[self:ToEnum("Skin") or "Skin"] = equipped[weaponName].Skin
                    targetTable[self:ToEnum("Name") or "Name"] = equipped[weaponName].Skin.Name
                end
                if equipped[weaponName].Charm then
                    targetTable[self:ToEnum("Charm") or "Charm"] = equipped[weaponName].Charm
                end
                if equipped[weaponName].Wrap then
                    targetTable[self:ToEnum("Wrap") or "Wrap"] = equipped[weaponName].Wrap
                end
            end
        end
        
        local result = originalCreateViewModel(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end

local viewModelModule = playerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    
    if ClientViewModel.GetCharm then
        local originalGetCharmFunc = ClientViewModel.GetCharm
        ClientViewModel.GetCharm = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == Player and equipped[weaponName] and equipped[weaponName].Charm then
                return equipped[weaponName].Charm
            end
            return originalGetCharmFunc(self)
        end
    end
    
    if ClientViewModel.GetWrap then
        local originalGetWrapFunc = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == Player and equipped[weaponName] and equipped[weaponName].Wrap then
                return equipped[weaponName].Wrap
            end
            return originalGetWrapFunc(self)
        end
    end

    local originalNew = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if weaponPlayer == Player and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
        end
        
        local result = originalNew(replicatedData, clientItem)
        
        if weaponPlayer == Player and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end

end -- DataController guard

if ItemLibrary and type(ItemLibrary) == "table" then
ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
    if not weaponData then return nil end
    local weaponName = weaponData.Name
    local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == Player and equipped[weaponName] and equipped[weaponName].Skin)
    if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
        local skinInfo = self.ViewModels[equipped[weaponName].Skin.Name]
        if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
    end
    return nil
end
end -- ItemLibrary guard

local EmoteController
pcall(function() 
    EmoteController = require(controllers:WaitForChild("EmoteController", 10))
    if EmoteController and EmoteController.GetEmotes then
        local originalGetEmotes = EmoteController.GetEmotes
        EmoteController.GetEmotes = function(self)
            local emotes = originalGetEmotes(self)
            for name, cosmetic in pairs((CosmeticLibrary and CosmeticLibrary.Cosmetics) or {}) do
                if cosmetic and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote" or name:lower():find("dance") or name:lower():find("emote")) then
                    if not emotes[name] then
                        emotes[name] = { Name = name, Type = cosmetic.Type, ObjectID = cosmetic.ObjectID, Enum = cosmetic.Enum }
                    end
                end
            end
            return emotes
        end
    end
end)

pcall(function()
    local ViewProfile = require(playerScripts.Modules.Pages.ViewProfile)
    if ViewProfile and ViewProfile.Fetch then
        local originalFetch = ViewProfile.Fetch
        ViewProfile.Fetch = function(self, targetPlayer)
            viewingProfile = targetPlayer
            return originalFetch(self, targetPlayer)
        end
    end
end)

loadConfig()

-- 3. Linoria Library Tabs and Groupboxes setup
pcall(function() ThemeManager:SetLibrary(Library) end)
pcall(function() SaveManager:SetLibrary(Library) end)
pcall(function() SaveManager:IgnoreThemeSettings() end)
pcall(function() SaveManager:SetIgnoreIndexes({}) end)
pcall(function() ThemeManager:SetFolder('NovHook') end)
pcall(function() SaveManager:SetFolder('NovHook') end)

local Tabs = {
    Legit = Window:AddTab('Legit'),
    Visuals = Window:AddTab('Visuals'),
    Cosmetics = Window:AddTab('Skin Changer'),
    Move = Window:AddTab('Move'),
    Farm = Window:AddTab('Farm'),
    Emotes = Window:AddTab('Emotes'),
    Skybox = Window:AddTab('Skybox'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Legit 탭: Aimbot / Silent Aim / Ragebot / Anti-Aim 분리
print('[Novhook premiumV2] Tabs ready')
local AimbotGroup = Tabs.Legit:AddLeftGroupbox('Aimbot')
local SilentAimGroup = Tabs.Legit:AddLeftGroupbox('Silent Aim')
local RagebotGroup = Tabs.Legit:AddRightGroupbox('Ragebot')
local AntiAimGroup = Tabs.Legit:AddRightGroupbox('Anti-Aim')
-- 하위 호환 별칭 (기존 코드가 LegitGroup/VoidSpamGroup/WeaponGroup 참조)
local LegitGroup = AimbotGroup
local VoidSpamGroup = RagebotGroup
local WeaponGroup = RagebotGroup

local VisualsGroup = Tabs.Visuals:AddLeftGroupbox('ESP & Map')
local CustomVisGroup = Tabs.Visuals:AddRightGroupbox('Visual Customization')
local MoveGroup = Tabs.Move:AddLeftGroupbox('Movement')
local DeviceGroup = Tabs.Move:AddRightGroupbox('Device Spoofer')
DeviceGroup:AddToggle('DeviceSpoofToggle', {
    Text = 'Device Spoofer',
    Default = false,
    Callback = function(v)
        getgenv().DeviceSpoofEnabled = v and true or false
    end
})
getgenv().DeviceSpoofEnabled = false
DeviceGroup:AddDropdown('DeviceSpoofType', {
    Values = { 'vr', 'touch', 'gamepad', 'mousekeyboard', 'random' },
    Default = 1,
    Multi = false,
    Text = 'Device Type',
    Callback = function(Value)
        getgenv().DeviceSpoofType = tostring(Value)
    end
})
DeviceGroup:AddSlider('DeviceSpoofInterval', {
    Text = 'Random Interval',
    Default = 1,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        getgenv().DeviceSpoofInterval = v
    end
})
getgenv().DeviceSpoofInterval = 1
DeviceGroup:AddToggle('DeviceIconColorToggle', {
    Text = 'Custom Icon Color',
    Default = false,
    Callback = function(v)
        getgenv().DeviceIconColorEnabled = v and true or false
    end
}):AddColorPicker('DeviceIconColorPicker', {
    Title = 'Icon Color',
    Default = Color3.fromRGB(0, 255, 255),
    Callback = function(c)
        getgenv().DeviceIconColor = c
    end
})
getgenv().DeviceIconColorEnabled = false
getgenv().DeviceIconColor = Color3.fromRGB(0, 255, 255)

local SpoofGroup = Tabs.Move:AddRightGroupbox('Stat Spoofer')
SpoofGroup:AddToggle('LevelSpoofToggle', {
    Text = 'Level Spoofer',
    Default = false,
    Callback = function(v)
        getgenv().LevelSpoofEnabled = v and true or false
    end
})
getgenv().LevelSpoofEnabled = false
SpoofGroup:AddSlider('SpoofLevelSlider', {
    Text = 'Spoof Level',
    Default = 999,
    Min = 1,
    Max = 9999,
    Rounding = 0,
    Callback = function(v)
        getgenv().SpoofLevel = v
    end
})
getgenv().SpoofLevel = 999

SpoofGroup:AddToggle('WinStreakSpoofToggle', {
    Text = 'Win Streak Spoofer',
    Default = false,
    Callback = function(v)
        getgenv().WinStreakSpoofEnabled = v and true or false
    end
})
getgenv().WinStreakSpoofEnabled = false
SpoofGroup:AddSlider('SpoofWinStreakSlider', {
    Text = 'Spoof Win Streak',
    Default = 999,
    Min = 0,
    Max = 9999,
    Rounding = 0,
    Callback = function(v)
        getgenv().SpoofWinStreak = v
    end
})
getgenv().SpoofWinStreak = 999

SpoofGroup:AddToggle('TierSpoofToggle', {
    Text = 'Tier Spoofer',
    Default = false,
    Callback = function(v)
        getgenv().TierSpoofEnabled = v and true or false
    end
})
getgenv().TierSpoofEnabled = false
SpoofGroup:AddDropdown('SpoofTierDropdown', {
    Values = {
        'Bronze',
        'Silver',
        'Gold',
        'Platinum',
        'Diamond',
        'Onyx',
        'Nemesis',
        'Arch Nemesis',
    },
    Default = 8,
    Multi = false,
    Text = 'Spoof Tier (Rivals)',
    Callback = function(v)
        getgenv().SpoofTier = tostring(v)
    end
})
getgenv().SpoofTier = 'Arch Nemesis'

-- 속성/텍스트 라벨 강제 (HUD에 Level 등 표시될 때)
task.spawn(function()
    local function applyAttrs()
        pcall(function()
            if getgenv().LevelSpoofEnabled then
                Player:SetAttribute("Level", tonumber(getgenv().SpoofLevel) or 999)
                Player:SetAttribute("PlayerLevel", tonumber(getgenv().SpoofLevel) or 999)
            end
            if getgenv().WinStreakSpoofEnabled then
                Player:SetAttribute("WinStreak", tonumber(getgenv().SpoofWinStreak) or 999)
                Player:SetAttribute("CurrentWinStreak", tonumber(getgenv().SpoofWinStreak) or 999)
            end
            if getgenv().TierSpoofEnabled then
                local t = getgenv().SpoofTier or "Champion"
                Player:SetAttribute("Tier", t)
                Player:SetAttribute("Rank", t)
                Player:SetAttribute("RankTier", t)
            end
        end)
    end
    while true do
        applyAttrs()
        task.wait(1)
    end
end)


getgenv().DeviceSpoofType = 'vr'

local FarmGroup = Tabs.Farm:AddLeftGroupbox('Arcade Auto Farm')
local EmotesGroup = Tabs.Emotes:AddLeftGroupbox('Emote Options')
local SkyboxGroup = Tabs.Skybox:AddLeftGroupbox('Skybox Options')


-- =====================================================================
-- Cosmic Changer: 메인 메뉴 버튼 → 전용 UI 오픈 (스킨은 UI 안에서만 변경)
-- =====================================================================
local CosmeticsGroup = Tabs.Cosmetics:AddLeftGroupbox('Cosmic Changer')

getgenv().NH_UnlockAllCosmetics = getgenv().NH_UnlockAllCosmetics or false
getgenv().NH_CosWeapon = getgenv().NH_CosWeapon or nil
getgenv().NH_CosType = getgenv().NH_CosType or "Skin"
getgenv().NH_CosName = getgenv().NH_CosName or nil

local CosmicGui
local function NH_DestroyCosmicUI()
    if CosmicGui then
        pcall(function() CosmicGui:Destroy() end)
        CosmicGui = nil
    end
    pcall(function()
        local pg = Player:FindFirstChild("PlayerGui")
        local o = pg and pg:FindFirstChild("NovhookPremiumCosmicUI")
        if o then o:Destroy() end
        local cg = game:GetService("CoreGui"):FindFirstChild("NovhookPremiumCosmicUI")
        if cg then cg:Destroy() end
    end)
end

local function NH_cosSort(a, b)
    return tostring(a):lower() < tostring(b):lower()
end

local function NH_cosTypeOf(data)
    if type(data) ~= "table" then return "skin" end
    local t = tostring(data.Type or data.CosmeticType or data.Category or ""):lower()
    if t == "" then
        -- name-based fallback
        return "skin"
    end
    if t:find("wrap", 1, true) or t:find("camo", 1, true) then return "wrap" end
    if t:find("charm", 1, true) then return "charm" end
    if t:find("finish", 1, true) then return "finisher" end
    if t:find("skin", 1, true) or t:find("weapon", 1, true) then return "skin" end
    return t
end

local function NH_cosWeaponsFor(data)
    if type(data) ~= "table" then return {} end
    local list = {}
    local function add(v)
        if type(v) == "string" and v ~= "" then
            table.insert(list, v)
        end
    end
    add(data.Weapon)
    add(data.WeaponName)
    add(data.Item)
    add(data.ItemName)
    add(data.CompatibleWeapon)
    if type(data.Weapons) == "table" then
        for k, v in pairs(data.Weapons) do
            if type(k) == "string" and v == true then add(k)
            elseif type(v) == "string" then add(v) end
        end
    end
    if type(data.CompatibleWeapons) == "table" then
        for _, v in pairs(data.CompatibleWeapons) do add(v) end
    end
    return list
end

local function NH_CosWeapons()
    local list, seen = {}, {}
    local function push(name)
        if type(name) ~= "string" then return end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if #name < 2 or seen[name] then return end
        -- 메타/내부 키 제외
        local l = name:lower()
        if l:find("http") or l == "name" or l == "type" or l == "id" then return end
        seen[name] = true
        table.insert(list, name)
    end
    pcall(function()
        if not ItemLibrary then return end
        for _, bag in ipairs({
            ItemLibrary.Items,
            ItemLibrary.Weapons,
            ItemLibrary.Guns,
            ItemLibrary.Melees,
        }) do
            if type(bag) == "table" then
                for name, data in pairs(bag) do
                    if type(name) == "string" then
                        push(name)
                    elseif type(data) == "table" and type(data.Name) == "string" then
                        push(data.Name)
                    end
                end
            end
        end
        -- Cosmetics 쪽 Weapon 필드에서도 수집
        if CosmeticLibrary and CosmeticLibrary.Cosmetics then
            for _, data in pairs(CosmeticLibrary.Cosmetics) do
                for _, w in ipairs(NH_cosWeaponsFor(data)) do
                    if w ~= "All" and w ~= "Global" then push(w) end
                end
            end
        end
    end)
    table.sort(list, NH_cosSort)
    if #list == 0 then
        list = {
            "Assault Rifle", "SMG", "Shotgun", "Sniper", "Pistol",
            "Knife", "Minigun", "Crossbow", "RPG", "Flamethrower"
        }
    end
    return list
end

-- 무기 + 타입에 맞는 스킨만, 가나다/ABC 정렬
local function NH_CosNames(weapon, cosType)
    local out, seen = {}, {}
    cosType = tostring(cosType or "Skin"):lower()
    pcall(function()
        if not CosmeticLibrary or not CosmeticLibrary.Cosmetics then return end
        for name, data in pairs(CosmeticLibrary.Cosmetics) do
            if type(name) == "string" and type(data) == "table" and not seen[name] then
                local ty = NH_cosTypeOf(data)
                local typeOk = (ty == cosType)
                    or (cosType == "skin" and (ty == "skin" or ty == ""))
                    or (cosType == "wrap" and ty == "wrap")
                    or (cosType == "charm" and ty == "charm")
                    or (cosType == "finisher" and ty == "finisher")
                -- Skin일 때 wrap/charm/finisher 절대 섞지 않음
                if cosType == "skin" and (ty == "wrap" or ty == "charm" or ty == "finisher") then
                    typeOk = false
                end
                if typeOk then
                    local weapons = NH_cosWeaponsFor(data)
                    local weaponOk = false
                    if cosType == "charm" or cosType == "finisher" then
                        -- 글로벌 장식은 무기 무관 목록 (정렬만)
                        weaponOk = true
                    elseif not weapon or weapon == "" then
                        weaponOk = true
                    elseif #weapons == 0 then
                        -- 무기 필드 없으면 이름에 무기 포함 여부로 필터
                        weaponOk = name:lower():find(weapon:lower(), 1, true) ~= nil
                    else
                        for _, w in ipairs(weapons) do
                            if w == weapon or w == "All" or w == "Global" then
                                weaponOk = true
                                break
                            end
                            if w:lower() == weapon:lower() then
                                weaponOk = true
                                break
                            end
                        end
                    end
                    if weaponOk then
                        seen[name] = true
                        table.insert(out, name)
                    end
                end
            end
        end
    end)
    table.sort(out, NH_cosSort)
    -- UI 렉 방지: 최대 150개
    if #out > 150 then
        local trimmed = {}
        for i = 1, 150 do trimmed[i] = out[i] end
        out = trimmed
    end
    return out
end

local function NH_weaponKeys(weapon)
    local keys, seen = {}, {}
    local function add(k)
        if type(k) ~= "string" or k == "" or seen[k] then return end
        seen[k] = true
        table.insert(keys, k)
    end
    add(weapon)
    -- 현재 들고 있는 무기 이름도 같이
    pcall(function()
        local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
        if tool then add(tool.Name) end
    end)
    pcall(function()
        if not FighterController then return end
        local f = FighterController.LocalFighter or FighterController:GetFighter(Player)
        local item = f and f.EquippedItem
        if item then
            if type(item.Get) == "function" then
                add(item:Get("Name"))
                add(item:Get("ItemName"))
            end
            add(item.Name)
        end
        if f and f.Items then
            for name, _ in pairs(f.Items) do
                if type(name) == "string" and name:lower():find(weapon:lower(), 1, true) then
                    add(name)
                end
            end
        end
    end)
    return keys
end

-- Local-only cosmetic preview. This does not grant ownership or change server inventory.
local function NH_EquipCosmetic(weapon, cosType, cosName)
    if type(weapon) ~= "string" or weapon == "" or type(cosName) ~= "string" or cosName == "" then
        return false
    end

    cosType = tostring(cosType or "Skin")
    local cosmeticData
    pcall(function()
        if CosmeticLibrary and type(CosmeticLibrary.Cosmetics) == "table" then
            cosmeticData = CosmeticLibrary.Cosmetics[cosName]
        end
    end)
    if not cosmeticData then
        warn("[Cosmic Changer] Cosmetic not found in the current client library: " .. cosName)
        return false
    end

    local cloned
    pcall(function()
        if type(cloneCosmetic) == "function" then
            cloned = cloneCosmetic(cosName, cosType, {})
        end
    end)
    if type(cloned) ~= "table" then
        cloned = table.clone(cosmeticData)
        cloned.Name = cosName
        cloned.Type = cosType
    end

    equipped[weapon] = equipped[weapon] or {}
    equipped[weapon][cosType] = cloned
    if cosType:lower() == "skin" then
        equipped[weapon].Skin = cloned
        equipped[weapon].WeaponSkin = cloned
    end

    pcall(saveConfig)
    pcall(function()
        if type(NH_ApplyEquippedToHeld) == "function" then
            NH_ApplyEquippedToHeld()
        end
    end)
    return true
end

local function NH_ApplyEquippedToHeld()
    local ok, err = pcall(function()
        if type(equipped) ~= "table" or not next(equipped) then return end

        local FC = FighterController
        if not FC then
            local ps = Player:FindFirstChild("PlayerScripts")
            local controllersFolder = ps and ps:FindFirstChild("Controllers")
            local mod = controllersFolder and controllersFolder:FindFirstChild("FighterController")
            if mod then
                FC = require(mod)
                FighterController = FC
            end
        end
        if not FC then return end

        local fighter = FC.LocalFighter
        local item = fighter and fighter.EquippedItem
        if not item then return end

        local candidates = {}
        local function add(value)
            if type(value) == "string" and value ~= "" then
                for _, old in ipairs(candidates) do
                    if old:lower() == value:lower() then return end
                end
                candidates[#candidates + 1] = value
            end
        end

        pcall(function()
            if type(item.Get) == "function" then
                add(item:Get("Name"))
                add(item:Get("ItemName"))
            end
        end)
        pcall(function() add(item.Name) end)
        pcall(function()
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            if tool then add(tool.Name) end
        end)

        local pack
        for _, candidate in ipairs(candidates) do
            pack = equipped[candidate]
            if not pack then
                local lower = candidate:lower()
                for key, value in pairs(equipped) do
                    if type(key) == "string" and key:lower() == lower then
                        pack = value
                        break
                    end
                end
            end
            if pack then break end
        end
        if not pack then return end

        local skin = pack.Skin or pack.skin or pack.WeaponSkin
        if skin then
            pcall(function()
                if type(item.Set) == "function" then
                    item:Set("Skin", skin)
                    item:Set("WeaponSkin", skin)
                end
                item.Skin = skin
                item.WeaponSkin = skin
            end)
        end
    end)
    if not ok then
        warn("[Cosmic Changer] Apply failed: " .. tostring(err))
    end
end

task.spawn(function()
    local lastTool
    while true do
        task.wait(1.5)
        pcall(function()
            local tool = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
            local name = tool and tool.Name
            if name and name ~= lastTool then
                lastTool = name
                NH_ApplyEquippedToHeld()
            end
        end)
    end
end)

local function NH_OpenCosmicUI()
    NH_DestroyCosmicUI()

    local parent = nil
    pcall(function()
        parent = game:GetService("CoreGui")
    end)
    if not parent then
        parent = Player:WaitForChild("PlayerGui")
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NovhookPremiumCosmicUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 200
    gui.Parent = parent
    CosmicGui = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 520, 0, 420)
    main.Position = UDim2.new(0.5, -260, 0.5, -210)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 1.5

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 0, 36)
    title.Position = UDim2.new(0, 14, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Cosmic Changer"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 32, 0, 32)
    close.Position = UDim2.new(1, -40, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 16
    close.Parent = main
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    close.MouseButton1Click:Connect(function()
        NH_DestroyCosmicUI()
    end)

    -- drag
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -28, 0, 22)
    status.Position = UDim2.new(0, 14, 1, -28)
    status.BackgroundTransparency = 1
    status.Text = "Weapon → Type → Skin → Equip"
    status.TextColor3 = Color3.fromRGB(160, 160, 170)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = main

    -- columns
    local function makeScroll(x, titleText)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 150, 0, 22)
        lbl.Position = UDim2.new(0, x, 0, 44)
        lbl.BackgroundTransparency = 1
        lbl.Text = titleText
        lbl.TextColor3 = Color3.fromRGB(0, 200, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = main

        local sc = Instance.new("ScrollingFrame")
        sc.Size = UDim2.new(0, 156, 0, 300)
        sc.Position = UDim2.new(0, x, 0, 68)
        sc.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 4
        sc.CanvasSize = UDim2.new(0, 0, 0, 0)
        sc.Parent = main
        Instance.new("UICorner", sc).CornerRadius = UDim.new(0, 6)
        local lay = Instance.new("UIListLayout", sc)
        lay.Padding = UDim.new(0, 3)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        return sc, lay
    end

    local weaponScroll, weaponLay = makeScroll(14, "WEAPON")
    local typeScroll, typeLay = makeScroll(180, "TYPE")
    local skinScroll, skinLay = makeScroll(346, "COSMETIC")

    local selectedWeapon, selectedType, selectedSkin = nil, "Skin", nil

    local function clearScroll(sc)
        for _, c in ipairs(sc:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    local function addBtn(sc, text, onClick, selected)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -8, 0, 28)
        b.BackgroundColor3 = selected and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(40, 40, 48)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextTruncate = Enum.TextTruncate.AtEnd
        b.Parent = sc
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(onClick)
        return b
    end

    local function refreshSkins()
        clearScroll(skinScroll)
        local names = NH_CosNames(selectedWeapon, selectedType or "Skin")
        if #names == 0 then
            names = { "(empty)" }
        end
        for _, name in ipairs(names) do
            if name ~= "(empty)" then
                addBtn(skinScroll, name, function()
                    selectedSkin = name
                    getgenv().NH_CosName = name
                    status.Text = string.format("%s | %s | %s", tostring(selectedWeapon), tostring(selectedType), name)
                    refreshSkins()
                end, selectedSkin == name)
            end
        end
        task.defer(function()
            skinScroll.CanvasSize = UDim2.new(0, 0, 0, skinLay.AbsoluteContentSize.Y + 8)
        end)
    end

    local function refreshTypes()
        clearScroll(typeScroll)
        for _, t in ipairs({ "Skin", "Wrap", "Charm", "Finisher" }) do
            addBtn(typeScroll, t, function()
                selectedType = t
                getgenv().NH_CosType = t
                selectedSkin = nil
                refreshTypes()
                refreshSkins()
            end, selectedType == t)
        end
        task.defer(function()
            typeScroll.CanvasSize = UDim2.new(0, 0, 0, typeLay.AbsoluteContentSize.Y + 8)
        end)
    end

    local function refreshWeapons()
        clearScroll(weaponScroll)
        for _, w in ipairs(NH_CosWeapons()) do
            addBtn(weaponScroll, w, function()
                selectedWeapon = w
                getgenv().NH_CosWeapon = w
                selectedSkin = nil
                refreshWeapons()
                refreshSkins()
            end, selectedWeapon == w)
        end
        task.defer(function()
            weaponScroll.CanvasSize = UDim2.new(0, 0, 0, weaponLay.AbsoluteContentSize.Y + 8)
        end)
    end

    local equipBtn = Instance.new("TextButton")
    equipBtn.Size = UDim2.new(0, 150, 0, 32)
    equipBtn.Position = UDim2.new(0, 346, 0, 374)
    equipBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 90)
    equipBtn.Text = "Equip"
    equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    equipBtn.Font = Enum.Font.GothamBold
    equipBtn.TextSize = 14
    equipBtn.Parent = main
    Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0, 6)
    equipBtn.MouseButton1Click:Connect(function()
        if not selectedSkin then
            status.Text = "Select cosmetic first"
            return
        end
        local w = selectedWeapon
        -- Keep the weapon selected in the UI. Tool.Name is not always the
        -- internal ItemLibrary weapon key used by Rivals.
        if not w then
            status.Text = "Select weapon or hold a weapon"
            return
        end
        selectedWeapon = w
        getgenv().NH_CosWeapon = w
        local ok = NH_EquipCosmetic(w, selectedType or "Skin", selectedSkin)
        status.Text = ok and ("Equipped: " .. selectedSkin .. " → " .. tostring(w)) or "Equip failed"
        
    end)

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0, 150, 0, 32)
    unlockBtn.Position = UDim2.new(0, 180, 0, 374)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 140)
    unlockBtn.Text = "Unlock All"
    unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 14
    unlockBtn.Parent = main
    Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 6)
    unlockBtn.MouseButton1Click:Connect(function()
        getgenv().NH_UnlockAllCosmetics = true
        getgenv().SkinChangerLoaded = true
        pcall(function()
            if CosmeticLibrary then
                CosmeticLibrary.OwnsCosmeticNormally = function() return true end
                CosmeticLibrary.OwnsCosmeticUniversally = function() return true end
                CosmeticLibrary.OwnsCosmeticForWeapon = function() return true end
            end
        end)
        status.Text = "Unlock All ON"
    end)

    refreshWeapons()
    refreshTypes()
    refreshSkins()
end

CosmeticsGroup:AddButton('Open Cosmic Changer', function()
    NH_OpenCosmicUI()
end)

CosmeticsGroup:AddToggle('CosmicUIToggle', {
    Text = 'Cosmic Changer UI',
    Default = false,
    Callback = function(v)
        if v then
            NH_OpenCosmicUI()
        else
            NH_DestroyCosmicUI()
        end
    end
})

CosmeticsGroup:AddLabel('버튼/토글 → Cosmic 전용 창')
CosmeticsGroup:AddLabel('창 안에서만 스킨 변경')


-- =====================================================================

-- =====================================================================
-- [COSMIC APPLY LOOP] 장착 스킨을 들고 있는 무기에 지속 적용
-- =====================================================================
task.spawn(function()
    local function getFC()
        local fc
        pcall(function()
            local ps = Player:FindFirstChild("PlayerScripts")
            local c = ps and ps:FindFirstChild("Controllers")
            local mod = c and c:FindFirstChild("FighterController")
            if mod then fc = require(mod) end
        end)
        return fc
    end
    while true do
        task.wait(0.35)
        pcall(function()
            if type(NH_ApplyEquippedToHeld) == "function" then
                NH_ApplyEquippedToHeld()
            end
            -- 언락 유지
            if getgenv().NH_UnlockAllCosmetics and CosmeticLibrary then
                CosmeticLibrary.OwnsCosmeticNormally = function() return true end
                CosmeticLibrary.OwnsCosmeticUniversally = function() return true end
                CosmeticLibrary.OwnsCosmeticForWeapon = function() return true end
            end
        end)
    end
end)

-- [VIEWMODEL] Valorant arms + Skin Changer groups
-- Custom Arms = Valorant OBJ/EditableMesh + MeshId fallback
-- Rivals: FighterController.ViewModel.Model + workspace.ViewModels fallback
-- =====================================================================
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local AssetService = game:GetService("AssetService")
    local LP = Players.LocalPlayer

    local VM = getgenv().NH_ViewModel or {}
    getgenv().NH_ViewModel = VM

    VM.CustomArms = VM.CustomArms == true
    VM.ArmChams = VM.ArmChams or {
        Enabled = false, Color = Color3.fromRGB(255, 0, 255), Material = "Neon",
        Transparency = 0, NoTextures = true, Above = false,
    }
    VM.ArmsHighlight = VM.ArmsHighlight or {
        Enabled = false, FillColor = Color3.fromRGB(255, 0, 255), FillTransparency = 0.5,
        OutlineColor = Color3.fromRGB(255, 255, 0), OutlineTransparency = 0,
    }
    VM.ArmWireframe = VM.ArmWireframe or { Enabled = false, Color = Color3.fromRGB(188, 168, 211), Transparency = 0 }
    VM.WireFrame = VM.WireFrame or { Enabled = false, Color = Color3.fromRGB(255, 255, 255), Transparency = 0 }
    VM.GunMaterial = VM.GunMaterial or { Enabled = false, Color = Color3.fromRGB(255, 255, 255), Material = "Neon", NoTextures = true }
    VM.GunGlow = VM.GunGlow or { Enabled = false, Color = Color3.fromRGB(255, 255, 255), Intensity = 1.2, Size = 32 }
    VM.ArmGlow = VM.ArmGlow or { Enabled = false, Color = Color3.fromRGB(255, 255, 255), Intensity = 2, Size = 32 }
    VM.NoHands = VM.NoHands == true
    VM.DisableClothes = VM.DisableClothes == true
    VM.Offsets = VM.Offsets or { Enabled = false, X = 0, Y = 0, Z = 0 }
    VM.GunSize = VM.GunSize or { Enabled = false, Scale = 1 }
    VM.DisableAnim = VM.DisableAnim or {
        Enabled = false,
        Select = { Bobbing = false, Sway = false, Equip = false, Inspect = false, Shoot = false, Sprint = false },
    }

    local MATS = {
        Neon = Enum.Material.Neon, ForceField = Enum.Material.ForceField, Glass = Enum.Material.Glass,
        SmoothPlastic = Enum.Material.SmoothPlastic, Plastic = Enum.Material.Plastic,
        Metal = Enum.Material.Metal, Foil = Enum.Material.Foil, Chrome = Enum.Material.DiamondPlate,
    }

    local function isArmName(n)
        n = string.lower(tostring(n or ""))
        return n:find("arm", 1, true) or n:find("hand", 1, true) or n:find("glove", 1, true)
            or n:find("sleeve", 1, true) or n:find("finger", 1, true)
            or n == "leftarm" or n == "rightarm" or n == "leftarmwrapped" or n == "rightarmwrapped"
    end
    local function isArmPart(part)
        return part and part:IsA("BasePart") and isArmName(part.Name)
    end
    local function isGunPart(part)
        if not part or not part:IsA("BasePart") or isArmPart(part) then return false end
        local n = string.lower(part.Name)
        return not (n:find("camera", 1, true) or n:find("muzzle", 1, true))
    end

    -- Rivals viewmodel model
    local function getEquippedViewModel()
        local model
        pcall(function()
            local ps = LP:FindFirstChild("PlayerScripts")
            local controllers = ps and ps:FindFirstChild("Controllers")
            local mod = controllers and controllers:FindFirstChild("FighterController")
            if not mod then return end
            local fc = require(mod)
            local item = fc and fc.LocalFighter and fc.LocalFighter.EquippedItem
            model = item and item.ViewModel and item.ViewModel.Model
        end)
        return model
    end

    local function getViewModelRoots()
        local roots, seen = {}, {}
        local function add(x)
            if x and not seen[x] then seen[x] = true; roots[#roots+1] = x end
        end
        add(getEquippedViewModel())
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then
                for _, ch in ipairs(cam:GetChildren()) do
                    if ch:IsA("Model") or ch:IsA("Folder") then add(ch) end
                end
            end
        end)
        pcall(function()
            local vmFolder = workspace:FindFirstChild("ViewModels")
            if vmFolder then
                add(vmFolder)
                local fp = vmFolder:FindFirstChild("FirstPerson", true)
                if fp then add(fp) end
            end
        end)
        return roots
    end

    ----------------------------------------------------------------
    -- ValorantArms loader (Novhook)
    ----------------------------------------------------------------
    local function createValorantArms()
        local arms = { Enabled = false, Records = {}, Meshes = {}, Loading = false, Unloaded = false, Ready = false }

        local armMeshes = {
            LeftArm = { File = "valorant-leftV2.obj", Id = "12307734932" },
            RightArm = { File = "valorant-rightV2.obj", Id = "12307583853" },
        }
        for _, mesh in pairs(armMeshes) do
            mesh.Url = "https://raw.githubusercontent.com/engnyg/123f1/refs/heads/main/valorant/arm/" .. mesh.File
        end

        arms.BuildMesh = function(self, mesh)
            local path = "NetworkV2/Assets/ValorantArms/" .. mesh.File
            local objText = (isfile and isfile(path)) and readfile(path) or nil
            if not objText then
                objText = game:HttpGet(mesh.Url)
                assert(objText:find("\nv ") and objText:find("\nf "), "invalid OBJ download")
                if writefile then pcall(writefile, path, objText) end
            end

            local positions, uvs, normals, triangles = {}, {}, {}, {}

            local function resolveIndex(text, count)
                local parsed = tonumber(text)
                if not parsed then return nil end
                local resolved = parsed < 0 and (count + parsed + 1) or parsed
                assert(resolved >= 1 and resolved <= count and resolved % 1 == 0, "invalid OBJ index")
                return resolved
            end

            local lineNumber = 0
            for line in objText:gmatch("[^\r\n]+") do
                lineNumber += 1
                if lineNumber % 512 == 0 then
                    task.wait()
                    assert(not self.Unloaded, "mesh load cancelled")
                end
                local kind, rest = line:match("^%s*(%S+)%s+(.+)$")
                if kind == "v" or kind == "vn" or kind == "vt" then
                    local xText, yText, zText = rest:match("^(%S+)%s+(%S+)%s*(%S*)")
                    local x, y, z = tonumber(xText), tonumber(yText), tonumber(zText)
                    assert(x and y and (kind == "vt" or z), "invalid OBJ coordinate")
                    if kind == "v" then
                        positions[#positions + 1] = Vector3.new(x, y, z)
                    elseif kind == "vn" then
                        normals[#normals + 1] = Vector3.new(x, y, z)
                    else
                        uvs[#uvs + 1] = Vector2.new(x, 1 - y)
                    end
                elseif kind == "f" then
                    local corners = {}
                    for token in rest:gmatch("%S+") do
                        if token:sub(1, 1) == "#" then break end
                        local positionIndex, uvIndex, normalIndex = token:match("^(%-?%d+)/?(%-?%d*)/?(%-?%d*)$")
                        assert(positionIndex, "invalid OBJ face")
                        corners[#corners + 1] = {
                            resolveIndex(positionIndex, #positions),
                            resolveIndex(uvIndex, #uvs),
                            resolveIndex(normalIndex, #normals),
                        }
                    end
                    assert(#corners >= 3, "OBJ face needs 3+ corners")
                    for i = 2, #corners - 1 do
                        triangles[#triangles + 1] = { corners[1], corners[i], corners[i + 1] }
                    end
                end
            end

            assert(#positions > 0 and #triangles > 0, "empty OBJ")
            assert(#positions <= 60000 and #triangles <= 20000, "OBJ exceeds limit")

            local minimum, maximum = positions[1], positions[1]
            for _, position in ipairs(positions) do
                minimum = minimum:Min(position)
                maximum = maximum:Max(position)
            end
            local center = (minimum + maximum) * 0.5

            local editable = AssetService:CreateEditableMesh()
            assert(editable, "editable mesh memory budget unavailable")
            local meshPart = nil

            local ok, result = pcall(function()
                local positionIds, uvIds, normalIds = {}, {}, {}
                for k, position in ipairs(positions) do
                    positionIds[k] = editable:AddVertex(position - center)
                    if k % 512 == 0 then
                        task.wait()
                        assert(not self.Unloaded, "mesh load cancelled")
                    end
                end
                for k, uv in ipairs(uvs) do
                    uvIds[k] = editable:AddUV(uv)
                end
                for k, normal in ipairs(normals) do
                    normalIds[k] = editable:AddNormal(normal)
                end
                for k, triangle in ipairs(triangles) do
                    local a, b, c = triangle[1], triangle[2], triangle[3]
                    local face = editable:AddTriangle(positionIds[a[1]], positionIds[b[1]], positionIds[c[1]])
                    if a[2] and b[2] and c[2] then
                        editable:SetFaceUVs(face, { uvIds[a[2]], uvIds[b[2]], uvIds[c[2]] })
                    end
                    if a[3] and b[3] and c[3] then
                        editable:SetFaceNormals(face, { normalIds[a[3]], normalIds[b[3]], normalIds[c[3]] })
                    end
                    if k % 512 == 0 then
                        task.wait()
                        assert(not self.Unloaded, "mesh load cancelled")
                    end
                end
                meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editable), {
                    CollisionFidelity = Enum.CollisionFidelity.Box,
                })
                assert(not self.Unloaded, "mesh load cancelled")
            end)

            if not ok then
                if meshPart then meshPart:Destroy() end
                editable:Destroy()
                error(result, 0)
            end
            return { Template = meshPart, Editable = editable, Center = center, Size = maximum - minimum }
        end

        arms.Remove = function(self, part)
            local record = self.Records[part]
            if not record then return end
            self.Records[part] = nil
            pcall(function() record.Connection:Disconnect() end)
            if part.Parent and part.LocalTransparencyModifier == 1 then
                part.LocalTransparencyModifier = record.Visibility or 0
            end
            pcall(function() record.Visual:Destroy() end)
        end

        arms.Clear = function(self)
            for k in pairs(self.Records) do
                self:Remove(k)
            end
        end

        arms.Update = function(self)
            if not self.Enabled or not self.Ready then return end
            local camera = workspace.CurrentCamera
            local model = getEquippedViewModel()
            if not model then
                -- fallback: any root that has LeftArm/RightArm
                for _, root in ipairs(getViewModelRoots()) do
                    if root:FindFirstChild("LeftArm") or root:FindFirstChild("RightArm") then
                        model = root
                        break
                    end
                    local la = root:FindFirstChild("LeftArm", true)
                    if la then model = la.Parent break end
                end
            end
            if not model or not model:IsDescendantOf(workspace) or not camera then
                self:Clear()
                return
            end

            for k, record in pairs(self.Records) do
                if k.Parent ~= model then
                    self:Remove(k)
                end
            end

            for k, info in pairs(armMeshes) do
                local armPart = model:FindFirstChild(k) or model:FindFirstChild(k, true)
                if not armPart or not armPart:IsA("BasePart") then continue end

                local record = self.Records[armPart]
                if not record then
                    local asset = self.Meshes[k]
                    if not asset or not asset.Template then continue end
                    local clone = asset.Template:Clone()
                    clone.Name = "NetworkValorant" .. k
                    clone.Anchored = true
                    clone.CanCollide = false
                    clone.CanTouch = false
                    clone.CanQuery = false
                    clone.CastShadow = false
                    clone.Color = Color3.new(1, 1, 1)
                    clone.Material = Enum.Material.SmoothPlastic
                    if self.Texture then
                        pcall(function() clone.TextureID = self.Texture end)
                    end

                    local specialMesh = armPart:FindFirstChildWhichIsA("SpecialMesh")
                    record = {
                        Visual = clone,
                        Mesh = specialMesh,
                        Asset = asset,
                        Visibility = armPart.LocalTransparencyModifier,
                    }
                    self.Records[armPart] = record
                    record.Connection = armPart:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                        if record.Writing or armPart.LocalTransparencyModifier == 1 then return end
                        record.Visibility = armPart.LocalTransparencyModifier
                        record.Writing = true
                        armPart.LocalTransparencyModifier = 1
                        record.Writing = false
                    end)
                end

                local visual = record.Visual
                local asset = record.Asset
                local mesh = record.Mesh
                local scale = (mesh and mesh.Scale) or Vector3.new(1, 1, 1)
                local offset = (mesh and mesh.Offset) or Vector3.zero
                local size = asset.Size * scale
                if visual.Size ~= size then visual.Size = size end
                visual.CFrame = armPart.CFrame * CFrame.new(offset + asset.Center * scale)
                visual.Transparency = armPart.Transparency
                visual.LocalTransparencyModifier = VM.NoHands and 1 or (record.Visibility or 0)
                if visual.Parent ~= camera then
                    visual.Parent = camera
                end
                record.Writing = true
                armPart.LocalTransparencyModifier = 1
                record.Writing = false
            end
        end

        arms.SetEnabled = function(self, enabled)
            enabled = enabled and true or false
            self.Enabled = enabled
            if not enabled then
                self:Clear()
                return
            end
            if self.Ready or self.Loading then return end
            self.Loading = true
            task.spawn(function()
                local ok, result = pcall(function()
                    local toAsset = getcustomasset or getsynasset
                    assert(type(toAsset) == "function", "getcustomasset/getsynasset required")
                    assert(type(writefile) == "function" and type(readfile) == "function", "file APIs required")
                    assert(type(isfile) == "function" and type(makefolder) == "function", "folder APIs required")

                    for _, folder in ipairs({ "NetworkV2", "NetworkV2/Assets", "NetworkV2/Assets/ValorantArms" }) do
                        if not (isfolder and isfolder(folder)) then
                            pcall(makefolder, folder)
                        end
                    end

                    local texPath = "NetworkV2/Assets/ValorantArms/FP_Wushu_S0_DF.png"
                    if not isfile(texPath) then
                        local png = game:HttpGet("https://raw.githubusercontent.com/engnyg/123f1/refs/heads/main/valorant/arm/FP_Wushu_S0_DF.png")
                        assert(png:sub(1, 8) == "\137PNG\r\n\26\n", "invalid arm texture download")
                        writefile(texPath, png)
                    end
                    self.Texture = toAsset(texPath)

                    for k, mesh in pairs(armMeshes) do
                        assert(not self.Unloaded, "arm loading cancelled")
                        if not self.Meshes[k] then
                            self.Meshes[k] = self:BuildMesh(mesh)
                        end
                    end
                    assert(not self.Unloaded, "arm loading cancelled")
                    self.Ready = true
                end)
                self.Loading = false
                if not ok then
                    -- Fallback: catalog MeshId overlay (works without EditableMesh)
                    local fok, ferr = pcall(function()
                        self.UseMeshFallback = true
                        self.Meshes = self.Meshes or {}
                        for k, mesh in pairs(armMeshes) do
                            local part = Instance.new("Part")
                            part.Name = "NH_ValTemplate_" .. k
                            part.Anchored = true
                            part.CanCollide = false
                            part.CanTouch = false
                            part.CanQuery = false
                            part.CastShadow = false
                            part.Size = Vector3.new(1, 2, 1)
                            part.Transparency = 0
                            part.Color = Color3.fromRGB(255, 220, 200)
                            part.Material = Enum.Material.SmoothPlastic
                            local sm = Instance.new("SpecialMesh")
                            sm.MeshType = Enum.MeshType.FileMesh
                            sm.MeshId = "rbxassetid://" .. tostring(mesh.Id)
                            sm.TextureId = ""
                            sm.Scale = Vector3.new(1, 1, 1)
                            sm.Parent = part
                            self.Meshes[k] = {
                                Template = part,
                                Editable = nil,
                                Center = Vector3.new(0, 0, 0),
                                Size = Vector3.new(1, 2, 1),
                                Fallback = true,
                            }
                        end
                        self.Ready = true
                        self.Enabled = true
                    end)
                    if not fok then
                        self.Enabled = false
                        self:Clear()
                        if not self.Unloaded then
                            warn("[Novhook premium] Valorant arms fail: " .. tostring(result) .. " / " .. tostring(ferr))
                        end
                    else
                        print("[Novhook premium] Valorant arms ready (MeshId fallback)")
                    end
                else
                    print("[Novhook premium] Valorant arms ready")
                end
            end)
        end

        arms.Unload = function(self)
            self.Unloaded = true
            self.Enabled = false
            self:Clear()
            for k, asset in pairs(self.Meshes) do
                pcall(function() asset.Template:Destroy() end)
                pcall(function() asset.Editable:Destroy() end)
                self.Meshes[k] = nil
            end
        end

        return arms
    end

    local ValorantArms = createValorantArms()
    getgenv().__NH_ValorantArms = ValorantArms

    pcall(function()
        RunService:UnbindFromRenderStep("NH_ValorantArms")
    end)
    RunService:BindToRenderStep("NH_ValorantArms", Enum.RenderPriority.Last.Value + 2, function()
        pcall(function() ValorantArms:Update() end)
    end)

    ----------------------------------------------------------------
    -- Arm/Gun chams, glow, highlight, offsets (Skin Changer effects)
    ----------------------------------------------------------------
    local function ensureGlow(part, name, color, intensity, size)
        local light = part:FindFirstChild(name)
        if not light then
            light = Instance.new("PointLight")
            light.Name = name
            light.Shadows = false
            light.Parent = part
        end
        light.Enabled = true
        light.Color = color
        light.Brightness = intensity
        light.Range = size
    end
    local function clearGlow(part, name)
        local light = part:FindFirstChild(name)
        if light then light:Destroy() end
    end
    local function ensureHighlight(model, name)
        local h = model:FindFirstChild(name)
        if not h then
            h = Instance.new("Highlight")
            h.Name = name
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = model
        end
        return h
    end

    local originalProps = setmetatable({}, { __mode = "k" })
    local function saveProp(part, key, value)
        local t = originalProps[part]
        if not t then t = {}; originalProps[part] = t end
        if t[key] == nil then t[key] = value end
    end

    local function applyEffects()
        for _, root in ipairs(getViewModelRoots()) do
            for _, part in ipairs(root:GetDescendants()) do
                if not part:IsA("BasePart") then continue end
                local arm = isArmPart(part)
                local gun = (not arm) and isGunPart(part)

                if arm and (VM.NoHands or VM.DisableClothes) and not ValorantArms.Enabled then
                    pcall(function()
                        saveProp(part, "LTM", part.LocalTransparencyModifier)
                        part.LocalTransparencyModifier = 1
                    end)
                end
                if arm and VM.ArmChams.Enabled then
                    pcall(function()
                        saveProp(part, "Color", part.Color)
                        saveProp(part, "Material", part.Material)
                        part.Color = VM.ArmChams.Color
                        part.Material = MATS[VM.ArmChams.Material] or Enum.Material.Neon
                        part.Transparency = VM.ArmChams.Transparency
                        if VM.ArmChams.NoTextures and part:IsA("MeshPart") then
                            saveProp(part, "TextureID", part.TextureID)
                            part.TextureID = ""
                        end
                    end)
                end
                if gun and VM.GunMaterial.Enabled then
                    pcall(function()
                        saveProp(part, "Color", part.Color)
                        saveProp(part, "Material", part.Material)
                        part.Color = VM.GunMaterial.Color
                        part.Material = MATS[VM.GunMaterial.Material] or Enum.Material.Neon
                        if VM.GunMaterial.NoTextures and part:IsA("MeshPart") then
                            saveProp(part, "TextureID", part.TextureID)
                            part.TextureID = ""
                        end
                    end)
                end
                if arm and VM.ArmWireframe.Enabled then
                    pcall(function()
                        part.Material = Enum.Material.ForceField
                        part.Color = VM.ArmWireframe.Color
                        part.Transparency = VM.ArmWireframe.Transparency
                    end)
                end
                if gun and VM.WireFrame.Enabled then
                    pcall(function()
                        part.Material = Enum.Material.ForceField
                        part.Color = VM.WireFrame.Color
                        part.Transparency = VM.WireFrame.Transparency
                    end)
                end
                if gun and VM.GunGlow.Enabled then
                    ensureGlow(part, "NH_GunGlow", VM.GunGlow.Color, VM.GunGlow.Intensity, VM.GunGlow.Size)
                else
                    clearGlow(part, "NH_GunGlow")
                end
                if arm and VM.ArmGlow.Enabled then
                    ensureGlow(part, "NH_ArmGlow", VM.ArmGlow.Color, VM.ArmGlow.Intensity, VM.ArmGlow.Size)
                else
                    clearGlow(part, "NH_ArmGlow")
                end
                if gun and VM.GunSize.Enabled then
                    pcall(function()
                        saveProp(part, "Size", part.Size)
                        local base = originalProps[part] and originalProps[part].Size
                        if typeof(base) == "Vector3" then
                            part.Size = base * (tonumber(VM.GunSize.Scale) or 1)
                        end
                    end)
                end
            end
            if VM.ArmsHighlight.Enabled then
                pcall(function()
                    local h = ensureHighlight(root, "NH_ArmsHighlight")
                    h.Enabled = true
                    h.FillColor = VM.ArmsHighlight.FillColor
                    h.FillTransparency = VM.ArmsHighlight.FillTransparency
                    h.OutlineColor = VM.ArmsHighlight.OutlineColor
                    h.OutlineTransparency = VM.ArmsHighlight.OutlineTransparency
                end)
            else
                local h = root:FindFirstChild("NH_ArmsHighlight")
                if h then h.Enabled = false end
            end
        end
    end

    -- glow on valorant overlay parts
    local function glowValorantClones()
        if not VM.ArmGlow.Enabled then return end
        for _, rec in pairs(ValorantArms.Records or {}) do
            local vis = rec.Visual
            if vis and vis.Parent then
                ensureGlow(vis, "NH_ArmGlow", VM.ArmGlow.Color, VM.ArmGlow.Intensity, VM.ArmGlow.Size)
            end
        end
    end

    local acc = 0
    RunService.RenderStepped:Connect(function(dt)
        acc += (dt or 0.016)
        if acc < 0.05 then return end
        acc = 0
        pcall(applyEffects)
        pcall(glowValorantClones)
        if VM.DisableAnim.Enabled then
            pcall(function()
                local cam = workspace.CurrentCamera
                if not cam then return end
                local sel = VM.DisableAnim.Select or {}
                for _, d in ipairs(cam:GetDescendants()) do
                    if d:IsA("AnimationTrack") and d.IsPlaying then
                        local n = string.lower(d.Name)
                        if (sel.Bobbing and n:find("bob")) or (sel.Sway and n:find("sway"))
                            or (sel.Equip and n:find("equip")) or (sel.Inspect and n:find("inspect"))
                            or (sel.Shoot and (n:find("shoot") or n:find("fire")))
                            or (sel.Sprint and n:find("sprint")) then
                            d:Stop(0)
                        end
                    end
                end
            end)
        end
    end)

    ----------------------------------------------------------------
    -- UI: Left + Right under Skin Changer (Cosmetics tab)
    ----------------------------------------------------------------
    local LeftVM = Tabs.Cosmetics:AddLeftGroupbox('ViewModel Gun')
    local RightVM = Tabs.Cosmetics:AddRightGroupbox('ViewModel Arms')

    RightVM:AddToggle('NH_CustomArms', {
        Text = 'Custom Arms (Valorant)',
        Default = false,
        Callback = function(v)
            VM.CustomArms = v and true or false
            ValorantArms:SetEnabled(VM.CustomArms)
        end,
    })
    RightVM:AddLabel('Valorant arms (mesh + texture)')
    RightVM:AddLabel('Needs getcustomasset + writefile')

    RightVM:AddToggle('NH_ArmChams', {
        Text = 'Arm Chams', Default = false,
        Callback = function(v) VM.ArmChams.Enabled = v and true or false end,
    }):AddColorPicker('NH_ArmChamsColor', {
        Default = Color3.fromRGB(255, 0, 255), Title = 'Arm Chams Color',
        Callback = function(c) VM.ArmChams.Color = c end,
    })
    RightVM:AddDropdown('NH_ArmChamsMat', {
        Text = 'Arm Chams Material',
        Values = { 'Neon', 'ForceField', 'Glass', 'SmoothPlastic', 'Plastic', 'Metal', 'Foil', 'Chrome' },
        Default = 1, Callback = function(v) VM.ArmChams.Material = v end,
    })
    RightVM:AddSlider('NH_ArmChamsTrans', {
        Text = 'Arm Chams Transparency', Default = 0, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) VM.ArmChams.Transparency = v end,
    })
    RightVM:AddToggle('NH_ArmNoTex', {
        Text = 'Arm Chams Strip Textures', Default = false,
        Callback = function(v) VM.ArmChams.NoTextures = v and true or false end,
    })
    RightVM:AddToggle('NH_ArmsHighlight', {
        Text = 'Arms Highlight', Default = false,
        Callback = function(v) VM.ArmsHighlight.Enabled = v and true or false end,
    }):AddColorPicker('NH_ArmsHLFill', {
        Default = Color3.fromRGB(255, 0, 255), Title = 'Fill',
        Callback = function(c) VM.ArmsHighlight.FillColor = c end,
    }):AddColorPicker('NH_ArmsHLOut', {
        Default = Color3.fromRGB(255, 255, 0), Title = 'Outline',
        Callback = function(c) VM.ArmsHighlight.OutlineColor = c end,
    })
    RightVM:AddToggle('NH_ArmWire', {
        Text = 'Arm Wireframe', Default = false,
        Callback = function(v) VM.ArmWireframe.Enabled = v and true or false end,
    }):AddColorPicker('NH_ArmWireColor', {
        Default = Color3.fromRGB(188, 168, 211), Title = 'Arm Wire Color',
        Callback = function(c) VM.ArmWireframe.Color = c end,
    })
    RightVM:AddToggle('NH_ArmGlow', {
        Text = 'Arm Glow', Default = false,
        Callback = function(v) VM.ArmGlow.Enabled = v and true or false end,
    }):AddColorPicker('NH_ArmGlowColor', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Arm Glow Color',
        Callback = function(c) VM.ArmGlow.Color = c end,
    })
    RightVM:AddSlider('NH_ArmGlowInt', {
        Text = 'Arm Glow Intensity', Default = 2, Min = 0, Max = 8, Rounding = 1,
        Callback = function(v) VM.ArmGlow.Intensity = v end,
    })

    LeftVM:AddToggle('NH_GunMat', {
        Text = 'Gun Material', Default = false,
        Callback = function(v) VM.GunMaterial.Enabled = v and true or false end,
    }):AddColorPicker('NH_GunMatColor', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Gun Color',
        Callback = function(c) VM.GunMaterial.Color = c end,
    })
    LeftVM:AddDropdown('NH_GunMatType', {
        Text = 'Gun Material Type',
        Values = { 'Neon', 'ForceField', 'Glass', 'SmoothPlastic', 'Plastic', 'Metal', 'Foil', 'Chrome' },
        Default = 1, Callback = function(v) VM.GunMaterial.Material = v end,
    })
    LeftVM:AddToggle('NH_GunNoTex', {
        Text = 'Gun Strip Textures', Default = false,
        Callback = function(v) VM.GunMaterial.NoTextures = v and true or false end,
    })
    LeftVM:AddToggle('NH_GunWire', {
        Text = 'Gun Wireframe', Default = false,
        Callback = function(v) VM.WireFrame.Enabled = v and true or false end,
    }):AddColorPicker('NH_GunWireColor', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Gun Wire Color',
        Callback = function(c) VM.WireFrame.Color = c end,
    })
    LeftVM:AddToggle('NH_GunGlow', {
        Text = 'Gun Glow', Default = false,
        Callback = function(v) VM.GunGlow.Enabled = v and true or false end,
    }):AddColorPicker('NH_GunGlowColor', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Gun Glow Color',
        Callback = function(c) VM.GunGlow.Color = c end,
    })
    LeftVM:AddSlider('NH_GunGlowInt', {
        Text = 'Gun Glow Intensity', Default = 1.2, Min = 0, Max = 8, Rounding = 1,
        Callback = function(v) VM.GunGlow.Intensity = v end,
    })
    LeftVM:AddToggle('NH_NoHands', {
        Text = 'No Hands (Removals)', Default = false,
        Callback = function(v) VM.NoHands = v and true or false end,
    })
    LeftVM:AddToggle('NH_DisableClothes', {
        Text = 'Disable Clothes', Default = false,
        Callback = function(v) VM.DisableClothes = v and true or false end,
    })
    LeftVM:AddToggle('NH_VMOffset', {
        Text = 'Viewmodel Offsets', Default = false,
        Callback = function(v) VM.Offsets.Enabled = v and true or false end,
    })
    LeftVM:AddSlider('NH_VMOffX', { Text = 'Offset X', Default = 0, Min = -5, Max = 5, Rounding = 2, Callback = function(v) VM.Offsets.X = v end })
    LeftVM:AddSlider('NH_VMOffY', { Text = 'Offset Y', Default = 0, Min = -5, Max = 5, Rounding = 2, Callback = function(v) VM.Offsets.Y = v end })
    LeftVM:AddSlider('NH_VMOffZ', { Text = 'Offset Z', Default = 0, Min = -5, Max = 5, Rounding = 2, Callback = function(v) VM.Offsets.Z = v end })
    LeftVM:AddToggle('NH_GunSize', {
        Text = 'Gun Size', Default = false,
        Callback = function(v) VM.GunSize.Enabled = v and true or false end,
    })
    LeftVM:AddSlider('NH_GunSizeScale', {
        Text = 'Gun Scale', Default = 1, Min = 0.3, Max = 3, Rounding = 2,
        Callback = function(v) VM.GunSize.Scale = v end,
    })
    LeftVM:AddToggle('NH_DisableAnim', {
        Text = 'Disable Animations', Default = false,
        Callback = function(v) VM.DisableAnim.Enabled = v and true or false end,
    })
    LeftVM:AddToggle('NH_AnimBob', { Text = 'Disable Bobbing', Default = false, Callback = function(v) VM.DisableAnim.Select.Bobbing = v and true or false end })
    LeftVM:AddToggle('NH_AnimSway', { Text = 'Disable Sway', Default = false, Callback = function(v) VM.DisableAnim.Select.Sway = v and true or false end })
    LeftVM:AddToggle('NH_AnimEquip', { Text = 'Disable Equip', Default = false, Callback = function(v) VM.DisableAnim.Select.Equip = v and true or false end })
    LeftVM:AddToggle('NH_AnimInspect', { Text = 'Disable Inspect', Default = false, Callback = function(v) VM.DisableAnim.Select.Inspect = v and true or false end })
    LeftVM:AddToggle('NH_AnimShoot', { Text = 'Disable Shoot Anim', Default = false, Callback = function(v) VM.DisableAnim.Select.Shoot = v and true or false end })
    LeftVM:AddToggle('NH_AnimSprint', { Text = 'Disable Sprint Anim', Default = false, Callback = function(v) VM.DisableAnim.Select.Sprint = v and true or false end })
    LeftVM:AddLabel('Gun Glow / Arm Glow default ON')

    print('[Novhook premium] ViewModel Arms/Gun groups ready')
end







local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

-- [Feature Porting Area]

-- 1. 기존 에임봇 FOV GUI
local FOV = 150
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "aimbot FOV"
FOVGui.ResetOnSpawn = false
FOVGui.DisplayOrder = 1000
FOVGui.IgnoreGuiInset = true
FOVGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FOVGui.Enabled = false
FOVGui.Parent = nil -- 로비 Play 안 막음 (Show 켤 때만 PlayerGui)
pcall(function() FOVGui.ClipToDeviceSafeArea = false end)
pcall(function() FOVGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None end)

local FOVFrame = Instance.new("Frame", FOVGui)
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.new(0, FOV * 2, 0, FOV * 2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Visible = false
FOVFrame.Active = false
FOVFrame.Selectable = false
pcall(function() FOVFrame.Interactable = false end)

local UICorner = Instance.new("UICorner", FOVFrame)
UICorner.CornerRadius = UDim.new(1, 0)

local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Thickness = 1
FOVStroke.Color = Color3.fromRGB(255, 140, 0)

local FOVGradient = Instance.new("UIGradient", FOVFrame)
FOVGradient.Rotation = 45

-- Separate target-follow ring: tracks the selected opposing player's screen position.
local TargetFOVFrame = Instance.new("Frame", FOVGui)
TargetFOVFrame.Name = "GunTargetFOV"
TargetFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
TargetFOVFrame.Position = UDim2.fromScale(0.5, 0.5)
-- TargetFOV removed
TargetFOVFrame.BackgroundTransparency = 1
TargetFOVFrame.Visible = false
TargetFOVFrame.Active = false
TargetFOVFrame.Selectable = false
TargetFOVFrame.ZIndex = 3
local TargetFOVCorner = Instance.new("UICorner", TargetFOVFrame)
TargetFOVCorner.CornerRadius = UDim.new(1, 0)
local TargetFOVStroke = Instance.new("UIStroke", TargetFOVFrame)
TargetFOVStroke.Thickness = 1.5
TargetFOVStroke.Color = Color3.fromRGB(255, 140, 0)
local TargetFOVGradient = Instance.new("UIGradient", TargetFOVFrame)
TargetFOVGradient.Rotation = 0

-- 2. 사일런트 에임 전용 FOV GUI 생성
local silentAimFovRadius = 300

-- FOV overlays must never steal clicks (lobby Start button)
pcall(function()
    FOVFrame.Active = false
    FOVFrame.Selectable = false
    if FOVStroke then FOVStroke.Enabled = FOVStroke.Enabled end
end)
pcall(function()
    SilentFOVFrame.Active = false
    SilentFOVFrame.Selectable = false
end)

SilentFOVGui = Instance.new("ScreenGui")
SilentFOVGui.Name = "SilentFOV"
SilentFOVGui.ResetOnSpawn = false
SilentFOVGui.DisplayOrder = 1000
SilentFOVGui.IgnoreGuiInset = true
SilentFOVGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SilentFOVGui.Enabled = false
SilentFOVGui.Parent = nil
pcall(function() SilentFOVGui.ClipToDeviceSafeArea = false end)
pcall(function() SilentFOVGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None end)

local SilentFOVFrame = Instance.new("Frame", SilentFOVGui)
SilentFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
SilentFOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
SilentFOVFrame.Size = UDim2.new(0, silentAimFovRadius * 2, 0, silentAimFovRadius * 2)
SilentFOVFrame.BackgroundTransparency = 1
SilentFOVFrame.Visible = false
SilentFOVFrame.Active = false
SilentFOVFrame.Selectable = false

local SilentUICorner = Instance.new("UICorner", SilentFOVFrame)
SilentUICorner.CornerRadius = UDim.new(1, 0)

local SilentFOVStroke = Instance.new("UIStroke", SilentFOVFrame)
SilentFOVStroke.Thickness = 1
SilentFOVStroke.Color = Color3.fromRGB(0, 255, 255)

local SilentFOVGradient = Instance.new("UIGradient", SilentFOVFrame)
SilentFOVGradient.Rotation = 45

-- [커스텀 크로스헤어 및 UI 요소 생성]
local CustomUIGui = Instance.new("ScreenGui")
CustomUIGui.Name = "CustomUI"
CustomUIGui.ResetOnSpawn = false
CustomUIGui.DisplayOrder = -100
CustomUIGui.IgnoreGuiInset = true
CustomUIGui.Enabled = false
CustomUIGui.Parent = nil

local CustomCrosshairContainer = Instance.new("Frame", CustomUIGui)
CustomCrosshairContainer.AnchorPoint = Vector2.new(0.5, 0.5)
CustomCrosshairContainer.Position = UDim2.new(0.5, 0, 0.5, -25)
CustomCrosshairContainer.Size = UDim2.new(0, 100, 0, 100)
CustomCrosshairContainer.BackgroundTransparency = 1
CustomCrosshairContainer.Visible = false
CustomCrosshairContainer.Active = false
CustomCrosshairContainer.Selectable = false
pcall(function() CustomCrosshairContainer.Interactable = false end)

-- 기본 크로스헤어 라인 생성
local ccLines = {
    {Name = "Left", Size = UDim2.new(0, 10, 0, 2), BasePos = -15},
    {Name = "Right", Size = UDim2.new(0, 10, 0, 2), BasePos = 5},
    {Name = "Up", Size = UDim2.new(0, 2, 0, 10), BasePos = -15},
    {Name = "Down", Size = UDim2.new(0, 2, 0, 10), BasePos = 5}
}

local ccFrames = {}
local ccData = {}

for i, info in ipairs(ccLines) do
    local line = Instance.new("Frame", CustomCrosshairContainer)
    line.Size = info.Size
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BorderSizePixel = 0
    table.insert(ccFrames, line)
    table.insert(ccData, info)
end

-- 크로스헤어 간격 적용 함수
getgenv().CrosshairGap = 5
getgenv().CrosshairSize = 10
local function updateCrosshairLayout()
    local gap = getgenv().CrosshairGap or 5
    local sz = getgenv().CrosshairSize or 10
    
    ccFrames[1].Size = UDim2.new(0, sz, 0, 2)
    ccFrames[1].Position = UDim2.new(0.5, -gap - sz, 0.5, -1)
    
    ccFrames[2].Size = UDim2.new(0, sz, 0, 2)
    ccFrames[2].Position = UDim2.new(0.5, gap, 0.5, -1)
    
    ccFrames[3].Size = UDim2.new(0, 2, 0, sz)
    ccFrames[3].Position = UDim2.new(0.5, -1, 0.5, -gap - sz)
    
    ccFrames[4].Size = UDim2.new(0, 2, 0, sz)
    ccFrames[4].Position = UDim2.new(0.5, -1, 0.5, gap)
end
updateCrosshairLayout()

local RageTextLabel = Instance.new("TextLabel", CustomUIGui)
RageTextLabel.AnchorPoint = Vector2.new(0.3, 0.3)
RageTextLabel.Position = UDim2.new(0.5, 0, 0.5, 35)
RageTextLabel.Size = UDim2.new(0, 255, 0, 25)
RageTextLabel.BackgroundTransparency = 1

RageTextLabel.TextColor3 = Color3.fromRGB(213, 215, 214)
RageTextLabel.TextStrokeTransparency = 0
RageTextLabel.Font = Enum.Font.GothamBold
RageTextLabel.TextSize = 13
RageTextLabel.TextXAlignment = Enum.TextXAlignment.Center
RageTextLabel.Visible = false

-- 대미지 로그 UI 생성 (우측 배치)
local HitLogContainer = Instance.new("Frame", CustomUIGui)
HitLogContainer.AnchorPoint = Vector2.new(1, 0.5)
HitLogContainer.Position = UDim2.new(0.98, 0, 0.4, 0)
HitLogContainer.Size = UDim2.new(0, 300, 0, 200)
HitLogContainer.BackgroundTransparency = 1
HitLogContainer.Visible = false

local HitLogList = Instance.new("UIListLayout", HitLogContainer)
HitLogList.SortOrder = Enum.SortOrder.LayoutOrder
HitLogList.VerticalAlignment = Enum.VerticalAlignment.Bottom
HitLogList.HorizontalAlignment = Enum.HorizontalAlignment.Right
HitLogList.Padding = UDim.new(0, 4)

function addHitLog(targetName, damage)
    if not getgenv().HitLogEnabled then return end
    if not damage or damage <= 0 then return end
    
    local msg = string.format("HIT %s  -%d", tostring(targetName), math.floor(damage))
    local lbl = Instance.new("TextLabel", HitLogContainer)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = msg
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    
    task.spawn(function()
        task.wait(3.5)
        if lbl then lbl:Destroy() end
    end)
end

-- 크로스헤어 스핀 및 숨쉬기(안팎으로 펼쳐짐) 애니메이션 로직
local ccAngle = 0
local animTimer = 0
RunService.RenderStepped:Connect(function(dt)
    if not getgenv().CustomCrosshairEnabled then return end
    
    if getgenv().CrosshairSpinEnabled then
        ccAngle = (ccAngle + ((getgenv().CrosshairSpinSpeed or 2) * dt * 50)) % 360
        CustomCrosshairContainer.Rotation = ccAngle
    else
        CustomCrosshairContainer.Rotation = 0
    end

    if getgenv().CrosshairPulseEnabled then
        animTimer = animTimer + (dt * (getgenv().CrosshairPulseSpeed or 3))
        local pulseOffset = math.sin(animTimer) * (getgenv().CrosshairPulseIntensity or 5)
        local baseGap = getgenv().CrosshairGap or 5
        local sz = getgenv().CrosshairSize or 10
        local dynamicGap = math.max(1, baseGap + pulseOffset)
        
        ccFrames[1].Size = UDim2.new(0, sz, 0, 2)
        ccFrames[1].Position = UDim2.new(0.5, -dynamicGap - sz, 0.5, -1)
        ccFrames[2].Size = UDim2.new(0, sz, 0, 2)
        ccFrames[2].Position = UDim2.new(0.5, dynamicGap, 0.5, -1)
        ccFrames[3].Size = UDim2.new(0, 2, 0, sz)
        ccFrames[3].Position = UDim2.new(0.5, -1, 0.5, -dynamicGap - sz)
        ccFrames[4].Size = UDim2.new(0, 2, 0, sz)
        ccFrames[4].Position = UDim2.new(0.5, -1, 0.5, dynamicGap)
    end
end)

-- [Aimbot 그룹박스]
LegitGroup:AddToggle('AimbotToggle', {
    Text = 'Aimbot (Players & NPCs)',
    Default = false,
    Callback = function(Value)
        getgenv().AimbotEnabled = Value
        local _sh = Value and (getgenv().FOVShowEnabled or false)
        FOVFrame.Visible = _sh
        FOVFrame.Active = false
        FOVFrame.Selectable = false
        if FOVGui then
            if _sh and PlayerGui then
                FOVGui.Parent = PlayerGui
                FOVGui.Enabled = true
            else
                FOVGui.Enabled = false
                FOVGui.Parent = nil
            end
        end
    end
})

LegitGroup:AddToggle('WallCheckToggle', {
    Text = 'Wall Check',
    Default = false,
    Callback = function(Value)
        getgenv().WallCheckEnabled = Value
    end
})

LegitGroup:AddSlider('FOVSizeSlider', {
    Text = 'FOV Size',
    Default = 150,
    Min = 1,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        FOV = Value
        FOVFrame.Size = UDim2.new(0, FOV * 2, 0, FOV * 2)
        -- TargetFOV removed
    end
})

LegitGroup:AddToggle('FOVShowToggle', {
    Text = 'Show FOV Circle',
    Default = false,
    Callback = function(Value)
        getgenv().FOVShowEnabled = Value
        local _sh2 = Value and (getgenv().AimbotEnabled or false)
        FOVFrame.Visible = _sh2
        FOVFrame.Active = false
        FOVFrame.Selectable = false
        if FOVGui then
            if _sh2 and FOVFrame.Visible then
                FOVGui.Parent = PlayerGui
                FOVGui.Enabled = true
            else
                FOVGui.Enabled = false
                FOVGui.Parent = nil
            end
        end
    end
})

LegitGroup:AddLabel('FOV Color'):AddColorPicker('FOVColorPicker', {
    Default = Color3.fromRGB(255, 140, 0),
    Callback = function(Value)
        getgenv().AimbotFOVColor1 = Value
        local c2 = getgenv().AimbotFOVColor2 or Color3.fromRGB(0, 220, 255)
        FOVStroke.Color = Value
        FOVGradient.Rotation = 0
        FOVGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Value),
            ColorSequenceKeypoint.new(0.499, Value),
            ColorSequenceKeypoint.new(0.501, c2),
            ColorSequenceKeypoint.new(1, c2)
        })
        -- TargetFOV removed
    end
})

LegitGroup:AddLabel('FOV Second Color'):AddColorPicker('FOVSecondColorPicker', {
    Default = Color3.fromRGB(0, 220, 255),
    Callback = function(Value)
        getgenv().AimbotFOVColor2 = Value
        local c1 = getgenv().AimbotFOVColor1 or Color3.fromRGB(255, 140, 0)
        local seq = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c1),
            ColorSequenceKeypoint.new(0.499, c1),
            ColorSequenceKeypoint.new(0.501, Value),
            ColorSequenceKeypoint.new(1, Value)
        })
        FOVGradient.Rotation = 0
        FOVGradient.Color = seq
        -- TargetFOV removed
    end
})

LegitGroup:AddToggle('FOVFillToggle', {
    Text = 'FOV Filled',
    Default = false,
    Callback = function(Value)
        getgenv().FOVFillEnabled = Value
        if Value then
            FOVFrame.BackgroundTransparency = getgenv().FOVFillTransparency or 0.5
        else
            FOVFrame.BackgroundTransparency = 1
        end
    end
})

LegitGroup:AddSlider('FOVFillTransparencySlider', {
    Text = 'Fill Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        getgenv().FOVFillTransparency = Value
        if getgenv().FOVFillEnabled then
            FOVFrame.BackgroundTransparency = Value
        end
    end
})

LegitGroup:AddSlider('FOVStrokeTransparencySlider', {
    Text = 'Stroke Transparency',
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        FOVStroke.Transparency = Value
    end
})

LegitGroup:AddToggle('FOVSpinToggle', {
    Text = 'FOV Spin',
    Default = true,
    Callback = function(Value)
        getgenv().FOVSpinEnabled = Value
    end
})
getgenv().FOVSpinEnabled = true

LegitGroup:AddSlider('FOVSpinSpeedSlider', {
    Text = 'FOV Spin Speed',
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        getgenv().FOVSpinSpeed = Value
    end
})

LegitGroup:AddToggle('GunFOVFollowToggle', {
    Text = 'Gun Model FOV Follow',
    Default = false,
    Tooltip = 'Follow the equipped viewmodel AimPoint / Muzzle / Handle',
    Callback = function(Value)
        getgenv().GunFOVFollow = Value == true
    end
})

-- [NovHook Void Spam — 땅밑 ↔ 하늘 (혼자 안 죽음)]
-- 낙사 높이 이하로 절대 안 감 / 맵 밖 Y 클램프
local VoidSpamSettings = {
    on = false,
    voidHideTime = 0.25,
    attackTime = 0.03,
    voidRange = 8000,    -- X/Z 범위 (50 ~ 500000)
    voidRangeY = 3000,
    voidBaseY = -12000,
    backstepDelay = 0.02,
    orbitRadius = 14,
    pulseAmp = 12.0,
    chaos = 3.5,
    skyHeight = 55,
    underDepth = 18,
}
getgenv().VoidSpamCFG = {
    hideTime = VoidSpamSettings.voidHideTime,
    attackTime = VoidSpamSettings.attackTime,
    voidRangeX = VoidSpamSettings.voidRange,
    voidRangeY = VoidSpamSettings.voidRangeY,
    voidRangeZ = VoidSpamSettings.voidRange,
    voidBaseY = VoidSpamSettings.voidBaseY,
}

local rbTgtT = 0
local respawnTime = 0

Player.CharacterAdded:Connect(function()
    respawnTime = tick()
end)

-- old complex void removed (void at EOF)

-- ===== Ragebot: Void Spam =====
VoidSpamGroup:AddLabel('— Void Spam —')
VoidSpamGroup:AddToggle('VoidSpamEnable', {
    Text = 'Void Spam',
    Default = false,
    Callback = function(val)
        VoidSpamSettings.on = val
        getgenv().VoidSpamEnabled = val
    end
})

VoidSpamGroup:AddSlider('VoidHideTime', {
    Text = 'Hide Time',
    Default = 0.25,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(v)
        VoidSpamSettings.voidHideTime = v
        getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {}
        getgenv().VoidSpamCFG.hideTime = v
    end
})

VoidSpamGroup:AddSlider('VoidAttackTime', {
    Text = 'Attack Time',
    Default = 0.03,
    Min = 0.01,
    Max = 1,
    Rounding = 2,
    Callback = function(v)
        VoidSpamSettings.attackTime = v
        getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {}
        getgenv().VoidSpamCFG.attackTime = v
    end
})

VoidSpamGroup:AddSlider('VoidRange', {
    Text = 'Void Range',
    Default = 8000,
    Min = 50,
    Max = 500000,
    Rounding = 0,
    Callback = function(v)
        VoidSpamSettings.voidRange = v
        getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {}
        getgenv().VoidSpamCFG.voidRangeX = v
        getgenv().VoidSpamCFG.voidRangeZ = v
    end
})

VoidSpamGroup:AddSlider('VoidRangeY', {
    Text = 'Void Range Y',
    Default = 3000,
    Min = 50,
    Max = 500000,
    Rounding = 0,
    Callback = function(v)
        VoidSpamSettings.voidRangeY = v
        getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {}
        getgenv().VoidSpamCFG.voidRangeY = v
    end
})

VoidSpamGroup:AddSlider('VoidBaseY', {
    Text = 'Void Base Y',
    Default = -12000,
    Min = -500000,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        VoidSpamSettings.voidBaseY = v
        getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {}
        getgenv().VoidSpamCFG.voidBaseY = v
    end
})


VoidSpamGroup:AddToggle('VoidShakeX', {
    Text = 'X Shake',
    Default = true,
    Callback = function(v)
        getgenv().VoidShakeX = v ~= false
    end
})
getgenv().VoidShakeX = true
VoidSpamGroup:AddToggle('VoidShakeY', {
    Text = 'Y Shake',
    Default = true,
    Callback = function(v)
        getgenv().VoidShakeY = v ~= false
    end
})
getgenv().VoidShakeY = true
VoidSpamGroup:AddToggle('VoidShakeZ', {
    Text = 'Z Shake',
    Default = true,
    Callback = function(v)
        getgenv().VoidShakeZ = v ~= false
    end
})
getgenv().VoidShakeZ = true
VoidSpamGroup:AddToggle('VoidSkyFly', {
    Text = 'Sky Random TP (공허 비행)',
    Default = true,
    Callback = function(v)
        getgenv().VoidSkyFly = v ~= false
    end
})
getgenv().VoidSkyFly = true

VoidSpamGroup:AddToggle('BaitingEnable', {
    Text = 'Baiting (낙사 유도)',
    Default = false,
    Callback = function(val)
        getgenv().BaitingEnabled = val and true or false
    end
})
getgenv().BaitingEnabled = false
getgenv().BaitAmp = getgenv().BaitAmp or 220
getgenv().BaitDepth = getgenv().BaitDepth or 35

-- [Silent Aim 그룹박스]
SilentAimGroup:AddToggle('SilentAimToggle', {
    Text = 'Silent Aim Enabled',
    Default = false,
    Callback = function(Value)
        silentAimEnabled = Value
        local _ssh = Value and (silentAimShowEnabled or false)
        SilentFOVFrame.Visible = _ssh
        SilentFOVFrame.Active = false
        SilentFOVFrame.Selectable = false
        if SilentFOVGui then
            if _ssh then
                SilentFOVGui.Parent = PlayerGui
                SilentFOVGui.Enabled = true
            else
                SilentFOVGui.Enabled = false
                SilentFOVGui.Parent = nil
            end
        end
    end
})



SilentAimGroup:AddToggle('SilentWallCheckToggle', {
    Text = 'Wall Check',
    Default = false,
    Callback = function(Value)
        silentWallCheck = Value
    end
})

SilentAimGroup:AddToggle('AllHeadToggle', {
    Text = 'Hitbox Head Priority',
    Default = true,
    Callback = function(Value)
        allHeadEnabled = Value
    end
})

SilentAimGroup:AddDropdown('SilentAimHitPartDropdown', {
    Values = { 'Head', 'HumanoidRootPart', 'Torso' },
    Default = 'Head',
    Multi = false,
    Text = 'Hit Part',
    Callback = function(Value)
        silentAimHitPart = Value
    end
})

SilentAimGroup:AddSlider('SilentFOVSizeSlider', {
    Text = 'FOV Size',
    Default = 300,
    Min = 1,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        silentAimFovRadius = Value
        SilentFOVFrame.Size = UDim2.new(0, silentAimFovRadius * 2, 0, silentAimFovRadius * 2)
    end
})

SilentAimGroup:AddToggle('SilentFOVShowToggle', {
    Text = 'Show FOV Circle',
    Default = false,
    Callback = function(Value)
        silentAimShowEnabled = Value
        local _ssh2 = Value and (silentAimEnabled or false)
        SilentFOVFrame.Visible = _ssh2
        SilentFOVFrame.Active = false
        SilentFOVFrame.Selectable = false
        if SilentFOVGui then
            if _ssh2 and SilentFOVFrame.Visible then
                SilentFOVGui.Parent = PlayerGui
                SilentFOVGui.Enabled = true
            else
                SilentFOVGui.Enabled = false
                SilentFOVGui.Parent = nil
            end
        end
    end
})

SilentAimGroup:AddLabel('FOV Color'):AddColorPicker('SilentFOVColorPicker', {
    Default = Color3.fromRGB(0, 255, 255),
    Callback = function(Value)
        SilentFOVStroke.Color = Value
        local h, s, v = Value:ToHSV()
        local darkerColor = Color3.fromHSV(h, math.clamp(s + 0.1, 0, 1), math.clamp(v * 0.7, 0, 1))
        local lighterColor = Color3.fromHSV(h, math.clamp(s - 0.1, 0, 1), math.clamp(v * 1.2, 0, 1))
        SilentFOVGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, darkerColor),
            ColorSequenceKeypoint.new(0.5, Value),
            ColorSequenceKeypoint.new(1, lighterColor)
        })
    end
})

SilentAimGroup:AddToggle('SilentFOVFillToggle', {
    Text = 'FOV Filled',
    Default = false,
    Callback = function(Value)
        silentAimFOVFillEnabled = Value
        if Value then
            SilentFOVFrame.BackgroundTransparency = silentAimFOVFillTransparency or 0.5
        else
            SilentFOVFrame.BackgroundTransparency = 1
        end
    end
})

SilentAimGroup:AddSlider('SilentFOVFillTransparencySlider', {
    Text = 'Fill Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        silentAimFOVFillTransparency = Value
        if silentAimFOVFillEnabled then
            SilentFOVFrame.BackgroundTransparency = Value
        end
    end
})

SilentAimGroup:AddSlider('SilentFOVStrokeTransparencySlider', {
    Text = 'Stroke Transparency',
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        SilentFOVStroke.Transparency = Value
    end
})

SilentAimGroup:AddToggle('SilentFOVSpinToggle', {
    Text = 'FOV Spin',
    Default = false,
    Callback = function(Value)
        silentAimFOVSpinEnabled = Value
    end
})

SilentAimGroup:AddSlider('SilentFOVSpinSpeedSlider', {
    Text = 'FOV Spin Speed',
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        silentAimFOVSpinSpeed = Value
    end
})

SilentAimGroup:AddToggle('SilentGunFOVFollowToggle', {
    Text = 'Gun Model FOV Follow',
    Default = false,
    Tooltip = 'Follow the equipped viewmodel AimPoint / Muzzle / Handle',
    Callback = function(Value)
        getgenv().SilentGunFOVFollow = Value == true
    end
})

SilentAimGroup:AddToggle('SilentFOVTargetMarkerToggle', {
    Text = 'Show FOV Target',
    Default = false,
    Callback = function(Value)
        getgenv().SilentFOVTargetMarker = Value == true
    end
})
getgenv().SilentFOVTargetMarker = false

-- Gun-model FOV anchor: prefer named attachments, then muzzle/handle parts.
-- This is a local visual anchor; it does not modify server weapon state.
local function NH_getGunAimWorldPosition()
    local cam = Workspace.CurrentCamera
    local char = Player and Player.Character
    if not cam then return nil end

    local function findAnchor(root)
        if not root then return nil end
        local ok, desc = pcall(function() return root:GetDescendants() end)
        if not ok or type(desc) ~= "table" then return nil end
        local priorities = {
            aimpoint = 1, aim_point = 1, aim = 2, sights = 2, ironsight = 2,
            muzzle = 3, muzzleattachment = 3, muzzle_flash = 3, flash = 3,
            barrel = 4, tip = 4, firepoint = 3, fire_point = 3,
        }
        local best, bestRank = nil, math.huge
        for _, inst in ipairs(desc) do
            if inst:IsA("Attachment") then
                local rank = priorities[string.lower(inst.Name)]
                if rank and rank < bestRank then best, bestRank = inst, rank end
            end
        end
        if best then
            local okp, wp = pcall(function() return best.WorldPosition end)
            if okp and typeof(wp) == "Vector3" then return wp end
        end
        local partNames = {
            muzzle = 1, barrel = 2, tip = 2, gun = 3, handle = 4,
            weapon = 3, viewmodel = 5, slide = 6, receiver = 6,
        }
        best, bestRank = nil, math.huge
        for _, inst in ipairs(desc) do
            if inst:IsA("BasePart") and inst.Transparency < 1 then
                local n = string.lower(inst.Name)
                local rank = partNames[n]
                if not rank then
                    for k, r in pairs(partNames) do
                        if n:find(k, 1, true) then rank = r break end
                    end
                end
                if rank and rank < bestRank then best, bestRank = inst, rank end
            end
        end
        if best then return best.Position end
        if root:IsA("Model") then
            local pp = root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
            if pp then return pp.Position end
        elseif root:IsA("BasePart") then
            return root.Position
        end
        return nil
    end

    local roots = {}
    local function pushRoot(obj, front)
        if not obj then return end
        if front then table.insert(roots, 1, obj) else table.insert(roots, obj) end
    end

    -- 1) FighterController.ViewModel (Rivals 정식 경로)
    pcall(function()
        local ps = Player:FindFirstChild("PlayerScripts")
        local c = ps and ps:FindFirstChild("Controllers")
        local mod = c and c:FindFirstChild("FighterController")
        if not mod then return end
        local fc = require(mod)
        local vm = fc and (fc.ViewModel or (fc.LocalFighter and fc.LocalFighter.ViewModel))
        if typeof(vm) == "Instance" then
            pushRoot(vm, true)
            if vm:IsA("Model") then
                local m = vm:FindFirstChild("Model") or vm:FindFirstChild("Gun") or vm:FindFirstChildWhichIsA("Model")
                if m then pushRoot(m, true) end
            elseif type(vm) == "table" and vm.Model then
                pushRoot(vm.Model, true)
            end
        elseif type(vm) == "table" then
            if typeof(vm.Model) == "Instance" then pushRoot(vm.Model, true) end
            if typeof(vm.Instance) == "Instance" then pushRoot(vm.Instance, true) end
        end
    end)

    -- 2) Camera children (ViewModel / Gun)
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            local n = string.lower(child.Name)
            if n:find("gun", 1, true) or n:find("viewmodel", 1, true) or n:find("weapon", 1, true)
                or n:find("item", 1, true) or n:find("arms", 1, true) then
                pushRoot(child, true)
            else
                pushRoot(child, false)
            end
        end
    end

    -- 3) workspace.ViewModels (플레이어 이름 포함)
    pcall(function()
        local folder = workspace:FindFirstChild("ViewModels") or workspace:FindFirstChild("Viewmodels")
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            local n = string.lower(child.Name)
            if n:find(string.lower(Player.Name), 1, true) or n:find("viewmodel", 1, true) or n:find("gun", 1, true) then
                pushRoot(child, true)
            end
        end
    end)

    if #roots == 0 then pushRoot(cam, false) end

    for _, root in ipairs(roots) do
        local pos = findAnchor(root)
        if pos then return pos end
    end

    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        local pos = findAnchor(tool)
        if pos then return pos end
    end
    return nil
end

local function NH_getGunScreenPoint()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local worldPos = NH_getGunAimWorldPosition()
    if worldPos then
        -- 총구(입구) 쪽으로 약간 전방 보정
        local look = cam.CFrame.LookVector
        worldPos = worldPos + look * 0.35
        local screen, visible = cam:WorldToViewportPoint(worldPos)
        if screen.Z > 0 then
            -- visible이 false여도 화면 안에 있으면 사용 (총구가 가장자리일 때)
            local vp = cam.ViewportSize
            local x, y = screen.X, screen.Y
            if x > -80 and y > -80 and x < vp.X + 80 and y < vp.Y + 80 then
                return Vector2.new(x, y)
            end
        end
    end
    -- 폴백: 화면 중앙 하단(총 조준선 근처)
    local vp = cam.ViewportSize
    return Vector2.new(vp.X * 0.5, vp.Y * 0.58)
end

local function NH_makeTargetDot(parent, name, color)
    local dot = Instance.new('Frame')
    dot.Name = name
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Size = UDim2.fromOffset(7, 7)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.Visible = false
    dot.Active = false
    dot.Selectable = false
    dot.ZIndex = 20
    dot.Parent = parent
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot
    local stroke = Instance.new('UIStroke')
    stroke.Thickness = 1
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = dot
    return dot
end

local AimbotFOVTargetDot = NH_makeTargetDot(FOVGui, 'FOVTargetDot', Color3.fromRGB(255, 140, 0))
local SilentFOVTargetDot = NH_makeTargetDot(SilentFOVGui, 'SilentFOVTargetDot', Color3.fromRGB(0, 255, 255))

getgenv().AimbotFOVTargetMarker = false
getgenv().SilentFOVTargetMarker = false
getgenv().GunTargetFOVEnabled = false
getgenv().GunFOVFollow = getgenv().GunFOVFollow or false
getgenv().SilentGunFOVFollow = getgenv().SilentGunFOVFollow or false
pcall(function()
    if AimbotFOVTargetDot then AimbotFOVTargetDot.Visible = false end
    if SilentFOVTargetDot then SilentFOVTargetDot.Visible = false end
    if TargetFOVFrame then TargetFOVFrame.Visible = false end
end)

local fovCurrentSpin = 0
local silentFovCurrentSpin = 0

local function NH_setFOVGuiState(gui, frame, shouldShow)
    if not gui or not frame then return end
    frame.Visible = shouldShow == true
    frame.Active = false
    frame.Selectable = false
    if shouldShow and PlayerGui then
        if gui.Parent ~= PlayerGui then gui.Parent = PlayerGui end
        gui.Enabled = true
    else
        gui.Enabled = false
        gui.Parent = nil
    end
end

-- Visual-only target selector for the Aimbot FOV marker. It does not move the camera
-- or send input; it only marks the nearest valid opposing player inside the circle.
local function NH_getVisualAimbotTarget(cam, center, radius)
    if not cam then return nil end
    local myTeam = Player:GetAttribute('TeamID')
    local bestPart, bestDistance = nil, math.huge
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= Player then
            local otherTeam = other:GetAttribute('TeamID')
            if not (myTeam ~= nil and otherTeam ~= nil and myTeam == otherTeam) then
                local char = other.Character
                local hum = char and char:FindFirstChildOfClass('Humanoid')
                if hum and hum.Health > 0 then
                    local part = char:FindFirstChild('HitboxHead') or char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart')
                    if part and part:IsA('BasePart') then
                        local screen, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen and screen.Z > 0 then
                            local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                            if distance <= radius and distance < bestDistance then
                                bestDistance = distance
                                bestPart = part
                            end
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

RunService.RenderStepped:Connect(function(dt)
    local cam = Workspace.CurrentCamera
    if not cam then
        AimbotFOVTargetDot.Visible = false
        SilentFOVTargetDot.Visible = false
        TargetFOVFrame.Visible = false
        return
    end

    local vp = cam.ViewportSize
    local screenCenter = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local gunPoint = NH_getGunScreenPoint()
    if gunPoint then
        local last = getgenv().__NH_LastGunFOVPoint
        if last then
            -- 부드럽게 총구 추적 (깜빡임 방지)
            gunPoint = Vector2.new(last.X + (gunPoint.X - last.X) * 0.55, last.Y + (gunPoint.Y - last.Y) * 0.55)
        end
        getgenv().__NH_LastGunFOVPoint = gunPoint
    end
    local stableGunPoint = getgenv().__NH_LastGunFOVPoint or screenCenter
    local aimbotFollow = getgenv().GunFOVFollow == true
    local silentFollow = getgenv().SilentGunFOVFollow == true
    local aCenter = aimbotFollow and stableGunPoint or screenCenter
    local sCenter = silentFollow and stableGunPoint or screenCenter

    FOVFrame.Position = UDim2.fromOffset(aCenter.X, aCenter.Y)
    FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    SilentFOVFrame.Position = UDim2.fromOffset(sCenter.X, sCenter.Y)
    SilentFOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)

    local showAimbotFOV = getgenv().AimbotEnabled == true and getgenv().FOVShowEnabled == true
    local showSilentFOV = silentAimEnabled == true and silentAimShowEnabled == true
    NH_setFOVGuiState(FOVGui, FOVFrame, showAimbotFOV)
    NH_setFOVGuiState(SilentFOVGui, SilentFOVFrame, showSilentFOV)

    -- 그라데이션 회전 (항상) + 프레임 스핀(옵션)
    local spinSpd = tonumber(getgenv().FOVSpinSpeed) or 2
    fovCurrentSpin = (fovCurrentSpin + (spinSpd * dt * 60)) % 360
    if FOVGradient then FOVGradient.Rotation = fovCurrentSpin end
    if showAimbotFOV and getgenv().FOVSpinEnabled then
        FOVFrame.Rotation = fovCurrentSpin
    else
        FOVFrame.Rotation = 0
    end

    silentFovCurrentSpin = (silentFovCurrentSpin + ((silentAimFOVSpinSpeed or 2) * dt * 60)) % 360
    if SilentFOVGradient then SilentFOVGradient.Rotation = silentFovCurrentSpin end
    if silentAimFOVSpinEnabled and showSilentFOV then
        SilentFOVFrame.Rotation = silentFovCurrentSpin
    else
        SilentFOVFrame.Rotation = 0
    end

    -- Guns Target FOV fully removed
    AimbotFOVTargetDot.Visible = false
    SilentFOVTargetDot.Visible = false
    if TargetFOVFrame then TargetFOVFrame.Visible = false end

    -- 헤드 점 마커: 명시적으로 켠 경우만 (기본 OFF)
    if showSilentFOV and getgenv().SilentFOVTargetMarker == true then
        local silentTarget = rawget(getgenv(), 'silentAimTarget') or silentAimTarget
        if silentTarget and silentTarget.Parent then
            local point, onScreen = cam:WorldToViewportPoint(silentTarget.Position)
            SilentFOVTargetDot.Visible = onScreen and point.Z > 0
            if SilentFOVTargetDot.Visible then
                SilentFOVTargetDot.Position = UDim2.fromOffset(point.X, point.Y)
            end
        end
    end
end)

silentAimEnabled = false
silentWallCheck = false
allHeadEnabled = true
silentAimHitPart = "Head"
silentAimShowEnabled = false
silentAimFOVFillEnabled = false
silentAimFOVFillTransparency = 0.5
silentAimFOVSpinEnabled = false
silentAimFOVSpinSpeed = 2

local LocalPlayer = Players.LocalPlayer

local function is_teammate(player)
    local pTeam = player:GetAttribute("TeamID")
    local lTeam = LocalPlayer:GetAttribute("TeamID")
    if pTeam and lTeam then return pTeam == lTeam end
    return false
end

local function get_character_valid(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if char:FindFirstChildOfClass("ForceField") or (tick() - (player:GetAttribute("SpawnTime") or 0) < 1.5) then return false end
    return true
end

local function get_hit_part(char, hitboxName)
    if not char then return nil end
    if allHeadEnabled then
        return char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    local partName = string.lower(tostring(hitboxName or "head"))
    if partName == "humanoidrootpart" then
        return char:FindFirstChild("HumanoidRootPart")
    elseif partName == "torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function has_line_of_sight(targetPart, myChar)
    if not targetPart then return false end
    local shootPos = Camera.CFrame.Position
    local dir = targetPart.Position - shootPos
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, Camera }
    params.IgnoreWater = true
    local result = Workspace:Raycast(shootPos, dir, params)
    if not result then return true end
    local model = result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
    return model == targetPart:FindFirstAncestorOfClass("Model")
end

-- STRONG SILENT: 360, head priority, no wall required by default
-- ========== Silent Aim (Kicia: UseItem cameradata → Head) ==========
-- FOV 안 적만. 360 없음.
silentAimTarget = nil
silentAimTargetPos = nil

local function getHeadPart(char)
    if not char then return nil end
    return char:FindFirstChild("HitboxHead")
        or char:FindFirstChild("HitboxHeadSmall")
        or char:FindFirstChild("Head")
end

local function silentPredict(hitPart, char)
    local pos = hitPart.Position
    local vel = Vector3.zero
    pcall(function()
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if r then vel = r.AssemblyLinearVelocity end
    end)
    return pos + vel * 0.07
end

local function refreshSilentTarget()
    silentAimTarget = nil
    silentAimTargetPos = nil
    if not silentAimEnabled then return end
    local myChar = Player.Character
    if not myChar then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    local center = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
    if getgenv().SilentGunFOVFollow == true then
        center = (NH_getGunScreenPoint() or center) + Vector2.new(0, -25)
    end
    local maxFov = tonumber(silentAimFovRadius) or 300
    local best, bestScore = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == Player then continue end
        if is_teammate(plr) then continue end
        if not get_character_valid(plr) then continue end
        local char = plr.Character
        local hit = getHeadPart(char)
        if not hit then continue end
        if silentWallCheck and not has_line_of_sight(hit, myChar) then continue end
        local pred = silentPredict(hit, char)
        local sp, onScreen = cam:WorldToViewportPoint(pred)
        if not onScreen or sp.Z <= 0 then continue end
        local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if sd > maxFov then continue end
        if sd < bestScore then
            bestScore = sd
            best = { part = hit, pred = pred }
        end
    end
    if best then
        silentAimTarget = best.part
        silentAimTargetPos = best.pred
    end
end

RunService.RenderStepped:Connect(function()
    if silentAimEnabled then refreshSilentTarget() end
end)

local function buildSilentCameraData(fromPos, targetPart)
    if not targetPart or not fromPos then return nil end
    local ok, util = pcall(function()
        return require(ReplicatedStorage.Modules.Utility)
    end)
    if not ok or not util then return nil end
    local look = CFram0.lookAt(fromPos, targetPart.Position)
    local data = {}
    data[utf8.char(1)] = {
        [utf8.char(0)] = util:EncodeCFrame(look),
        [utf8.char(1)] = util:EncodeCFrame(look),
        [utf8.char(2)] = targetPart,
        [utf8.char(3)] = util:EncodeCFrame(targetPart.CFrame0:ToObjectSpace(CFrame0.new(targetPart.Position))),
    }
    return data
end

-- Kicia 경로: FireServer cameradata 헤드 교체
pcall(function()
    if getgenv().__NH_SilentFS then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local useItem = remotes and remotes.Replication and remotes.Replication.Fighter and remotes.Replication.Fighter:FindFirstChild("UseItem")
    if not (useItem and hookfunction) then return end
    local enumShoot
    pcall(function()
        if EnumLibrary then enumShoot = EnumLibrary:ToEnum("StartShooting") end
    end)
    local oldFire
    oldFire = hookfunction(useItem.FireServer, newcclosure(function(self, obj, action, cameradata, ...)
        pcall(function()
            local isShoot = false
            if enumShoot and action == enumShoot then isShoot = true end
            if type(action) == "string" then
                local a = action:lower()
                if a:find("shoot") or a:find("fire") then isShoot = true end
            end
            if isShoot then getgenv().__NH_LastGunShot = os.clock() end
        end)
        -- 레이지 중이면 패킷 건드리지 않음 (레이지 자체 cameradata 사용)
        if self == useItem and silentAimEnabled and not getgenv().MeleeRageBotEnabled then
            local actOk = true
            if enumShoot then actOk = (action == enumShoot) end
            if actOk then
                refreshSilentTarget()
                local part = silentAimTarget
                if part and part.Parent then
                    local fromPos = silentAimTargetPos or part.Position
                    local built = buildSilentCameraData(fromPos, part)
                    if built then
                        cameradata = built
                        pcall(Attack)
                    end
                end
            end
        end
        return oldFire(self, obj, action, cameradata, ...)
    end))
    getgenv().__NH_SilentFS = true
end)


task.spawn(function()
    while true do
        task.wait(5)
        if getgenv().FastMeleeEnabled then
            pcall(function()
                local it = __FighterController and __FighterController.LocalFighter and __FighterController.LocalFighter.EquippedItem
                if it then
                    pcall(function() it._attack_cooldown = 0 end)
                end
                -- getgc 제거 (렉)
                
                local char = Player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        for _, track in pairs(hum:GetPlayingAnimationTracks()) do
                            local animName = string.lower(track.Animation.AnimationId)
                            if animName:find("sword") or animName:find("melee") or animName:find("knife") or animName:find("slash") or animName:find("punch") or animName:find("attack") then
                                track:AdjustSpeed(8.0)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

local __repS = cloneref(game:GetService("ReplicatedStorage"))
local __plrs = cloneref(game:GetService("Players"))
local __runS = cloneref(game:GetService("RunService"))
local __ws = cloneref(game:GetService("Workspace"))
local __lplr = __plrs.LocalPlayer
local __util, __enum, __FighterController, __SpectateController
pcall(function() __util = require(__repS.Modules.Utility) end)
pcall(function() __enum = require(__repS.Modules.EnumLibrary) end)
pcall(function() __FighterController = require(__lplr.PlayerScripts.Controllers.FighterController) end)
pcall(function() __SpectateController = require(__lplr.PlayerScripts.Controllers:WaitForChild("SpectateController", 5)) end)

getgenv().Config = {
    Enabled = false,
    FireRate = 0,
    WeaponSlot = "Melee",
    ForceEquip = true,
    AutoSwap = false
}




task.spawn(function()
    local localFighter = __FighterController.LocalFighter
    while not localFighter do
        task.wait(0.1)
        localFighter = __FighterController.LocalFighter
    end
    pcall(function() 
        if getgenv().Config.ForceEquip and getgenv().Config.WeaponSlot ~= "Swap" then
            localFighter:EquipItem(__getSlotNumber()) 
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(5)
        if not getgenv().Config.Enabled then continue end
        local localFighter = __FighterController.LocalFighter
        if localFighter then
            pcall(function() 
                if getgenv().Config.ForceEquip and getgenv().Config.WeaponSlot ~= "Swap" then
                    localFighter:EquipItem(__getSlotNumber()) 
                elseif getgenv().Config.AutoSwap or getgenv().Config.WeaponSlot == "Swap" then
                    localFighter:EquipItem(math.random(1, 3))
                end
            end)
        end
    end
end)

local __lastFire = 0
local __deflecting = {}
__plrs.PlayerRemoving:Connect(function(player) __deflecting[player] = nil end)

local function __updateDeflection()
    if not __FighterController or not __FighterController.Objects then return end
    for _, fighterObj in __FighterController.Objects do
        local player = fighterObj.Player
        if not player then continue end
        if not fighterObj.Entity or not fighterObj.Entity:IsAlive() or fighterObj:Get("IsSpectating") then
            __deflecting[player] = false
            continue
        end
        local equipped = fighterObj.EquippedItem
        local isKatana = equipped and equipped.ViewModel and equipped.ViewModel.Name == "Katana"
        local isDeflecting = false
        if isKatana then
            isDeflecting = (equipped._attack_cooldown and equipped._attack_cooldown > tick()) or false
        end
        __deflecting[player] = isDeflecting
    end
end

local function __isEnemy(player)
    if not player or player == __lplr then return false end
    if getgenv().ArcadeFarm then return true end
    local ok, result = pcall(function()
        if __SpectateController then
            local duel = __SpectateController.CurrentDuelSubject
            local localDueler = duel and duel:GetDueler(__lplr)
            local localTeam = localDueler and localDueler:Get("TeamID") or nil
            if localTeam and duel and duel.Duelers then
                for _, dueler in duel.Duelers do
                    if dueler.Player == player then
                        local team = dueler:Get("TeamID")
                        return team ~= localTeam
                    end
                end
            end
        end
        local pTeam = player:GetAttribute("TeamID")
        local lTeam = __lplr:GetAttribute("TeamID")
        if pTeam ~= nil and lTeam ~= nil then return pTeam ~= lTeam end
        if __lplr.Team and player.Team then return __lplr.Team ~= player.Team end
        return true
    end)
    if ok then return result end
    return true -- 오류 시 적으로 취급 (타격 우선)
end

-- 낙사/맵밖 방지: 위치 클램프
local function __safePos(pos, anchor)
    if typeof(pos) ~= "Vector3" then return pos end
    local a = anchor or pos
    local y = pos.Y
    local minY = (a.Y - 2)
    local maxY = (a.Y + 8)
    if y < minY then y = minY end
    if y > maxY then y = maxY end
    local flat = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
    if flat.Magnitude > 12 then
        flat = flat.Unit * 12
        pos = Vector3.new(a.X + flat.X, y, a.Z + flat.Z)
    else
        pos = Vector3.new(pos.X, y, pos.Z)
    end
    return pos
end

-- 낙사 방지: FallenPartsDestroyHeight 위로만
local function __underSafeY(desiredY)
    local killY = -500
    pcall(function()
        local h = workspace.FallenPartsDestroyHeight
        if typeof(h) == "number" and h == h then -- not NaN
            killY = h
        end
    end)
    local minY = killY + 20
    if desiredY < minY then return minY end
    return desiredY
end

local function __underShootPos(targetRoot, depth)
    depth = math.clamp(tonumber(depth) or 20, 1, 30)
    -- 레이캐스트 없음 → Y 떨림 제거, rootY - depth 만
    local y = __underSafeY(targetRoot.Position.Y - depth)
    return Vector3.new(targetRoot.Position.X, y, targetRoot.Position.Z)
end


local function __getClosestTarget()
    -- HVH: 가까운 적 + 체력 낮은 적 우선, 헤드 필수
    local char = __lplr.Character
    if not char then return nil, nil, nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil, nil, nil end
    local bestP, bestRoot, bestHead = nil, nil, nil
    local bestScore = math.huge
    for _, player in __plrs:GetPlayers() do
        if not __isEnemy(player) then continue end
        local pChar = player.Character
        if not pChar then continue end
        local pRoot = pChar:FindFirstChild("Head")
        local pHum = pChar:FindFirstChildOfClass("Humanoid")
        local pHead = pChar:FindFirstChild("HitboxHead")
            or pChar:FindFirstChild("HitboxHeadSmall")
            or pChar:FindFirstChild("Head")
        if not pRoot or not pHum or pHum.Health <= 0 or not pHead then continue end
        if pChar:FindFirstChildOfClass("ForceField") then continue end
        local dist
        if getgenv().UndergroundEnabled then
            -- 땅밑일 때 Y 차이로 거리 왜곡 방지
            local a, b = myRoot.Position, pRoot.Position
            dist = Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
        else
            dist = (myRoot.Position - pRoot.Position).Magnitude
        end
        if dist > 800 then continue end
        -- score: distance primary, low HP secondary (finish weak targets)
        local score = dist - (math.max(0, 100 - pHum.Health) * 0.35)
        if score < bestScore then
            bestScore = score
            bestP, bestRoot, bestHead = player, pRoot, pHead
        end
    end
    return bestP, bestRoot, bestHead
end


local lastRandomChange = 0
local currentRandomOffset = Vector3.zero
local togglePositionState = false

getgenv().RageStyle = getgenv().RageStyle or "Attack"
getgenv().HeadStuds = 5
getgenv().BackStuds = 3
getgenv().RageSpeed = 0.5

-- old body-lookAt rage removed (syntax-safe)
-- active rage = [RAGE] pure head packet section below



-- Underground UI 연결용 (Heartbeat 밖)
do
    getgenv().__NH_StartUnder = function()
        getgenv().UndergroundDepth = tonumber(getgenv().UndergroundDepth) or 20
    end
    getgenv().__NH_StopUnder = function()
        pcall(function() RunService:UnbindFromRenderStep("__restore") end)
        pcall(function() RunService:UnbindFromRenderStep("__NH_UNDER_R") end)
    end
    getgenv().__NH_ApplyUnder = function() end
end

WeaponGroup:AddLabel('— Core Rage —')
WeaponGroup:AddToggle('RageBotToggle', {
    Text = 'RageBot (Universal)',
    Default = false,
    Callback = function(Value)
        getgenv().MeleeRageBotEnabled = Value and true or false
        if getgenv().Config then getgenv().Config.Enabled = Value and true or false end
        if Value then
            getgenv().__NH_RageInstant = true
        else
            -- 다른 레이지 토글도 꺼져 있으면 완전 정지
            if not getgenv().HVHRageEnabled and not getgenv().KnifeModeEnabled then
                getgenv().ragebotOrKillAura = false
                getgenv().__NH_RageInstant = false
                getgenv().__NH_StopRage = true
            end
        end
    end
})
getgenv().MeleeRageBotEnabled = false

WeaponGroup:AddToggle('HVHRageToggle', {
    Text = 'RageBot (HVH)',
    Default = false,
    Callback = function(Value)
        getgenv().HVHRageEnabled = Value and true or false
        if Value then
            getgenv().__NH_RageInstant = true
            getgenv().ragebotOrKillAura = true
        else
            getgenv().ragebotOrKillAura = false
            if not getgenv().MeleeRageBotEnabled and not getgenv().KnifeModeEnabled then
                getgenv().__NH_RageInstant = false
                getgenv().__NH_StopRage = true
                if getgenv().Config then getgenv().Config.Enabled = false end
            end
        end
    end
})
getgenv().HVHRageEnabled = false

WeaponGroup:AddToggle('KnifeModeToggle', {
    Text = 'Knife Mode (등뒤 우클릭)',
    Default = false,
    Callback = function(Value)
        getgenv().KnifeModeEnabled = Value and true or false
        if not Value then
            if not getgenv().MeleeRageBotEnabled and not getgenv().HVHRageEnabled then
                getgenv().ragebotOrKillAura = false
                getgenv().__NH_RageInstant = false
                getgenv().__NH_StopRage = true
            end
        end
    end
})
getgenv().KnifeModeEnabled = false

WeaponGroup:AddLabel('— Orbit —')
WeaponGroup:AddToggle('OrbitToggle', {
    Text = 'Orbit (오르빗)',
    Default = false,
    Callback = function(Value)
        getgenv().OrbitEnabled = Value and true or false
    end
})
getgenv().OrbitEnabled = false

WeaponGroup:AddSlider('OrbitRadiusSlider', {
    Text = 'Orbit Radius',
    Default = 0,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Callback = function(Value)
        getgenv().OrbitRadius = Value
    end
})
getgenv().OrbitRadius = 0

WeaponGroup:AddSlider('OrbitSpeedSlider', {
    Text = 'Orbit Speed',
    Default = 12,
    Min = 1,
    Max = 40,
    Rounding = 1,
    Callback = function(Value)
        getgenv().OrbitSpeed = Value
    end
})
getgenv().OrbitSpeed = 8

WeaponGroup:AddLabel('— GHOST Matrix —')
WeaponGroup:AddToggle('GhostToggle', {
    Text = 'GHOST (예측 매트릭스)',
    Default = false,
    Callback = function(Value)
        getgenv().GhostEnabled = Value and true or false
    end
})
getgenv().GhostEnabled = false

WeaponGroup:AddSlider('GhostMatrixSlider', {
    Text = 'GHOST Matrix Size',
    Default = 12,
    Min = 6,
    Max = 24,
    Rounding = 0,
    Callback = function(Value)
        getgenv().GhostMatrix = Value
    end
})
getgenv().GhostMatrix = 12

WeaponGroup:AddDropdown('GhostCounterMode', {
    Text = 'GHOST Counter Mode',
    Values = { 'Auto', 'HeadAbove', 'SideOrbit', 'Under', 'Behind', 'EvadeShoot' },
    Default = 1,
    Multi = false,
    Callback = function(Value)
        if type(Value) == "table" then
            for k, v in pairs(Value) do if v then getgenv().GhostCounterMode = k break end end
        else
            getgenv().GhostCounterMode = Value
        end
    end
})
getgenv().GhostCounterMode = 'Auto'

WeaponGroup:AddToggle('GhostExecuteToggle', {
    Text = 'GHOST Execute Counter',
    Default = false,
    Callback = function(Value)
        getgenv().GhostExecute = Value and true or false
    end
})
getgenv().GhostExecute = false

WeaponGroup:AddToggle('CounterToggle', {
    Text = 'Counter (레이지 카운터 회피)',
    Default = false,
    Callback = function(Value)
        getgenv().CounterEnabled = Value and true or false
    end
})
getgenv().CounterEnabled = false

WeaponGroup:AddToggle('BaitToggle', {
    Text = 'Bait (짧게 노출)',
    Default = false,
    Callback = function(Value)
        getgenv().BaitEnabled = Value and true or false
    end
})
getgenv().BaitEnabled = false

WeaponGroup:AddSlider('BaitAttackSlider', {
    Text = 'Bait Attack (sec)',
    Default = 0.05,
    Min = 0.01,
    Max = 0.25,
    Rounding = 2,
    Callback = function(Value)
        getgenv().BaitAttack = Value
    end
})
getgenv().BaitAttack = 0.05

WeaponGroup:AddSlider('BaitHideSlider', {
    Text = 'Bait Hide (sec)',
    Default = 0.15,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2,
    Callback = function(Value)
        getgenv().BaitHide = Value
    end
})
getgenv().BaitHide = 0.15

WeaponGroup:AddDropdown('RageStyleDropdown', {
    Values = { 'Attack', 'Evasive', 'Hybrid', 'Orbit', 'Translocate' },
    Default = 1,
    Multi = false,
    Text = 'Rage Style',
    Callback = function(Value)
        getgenv().RageStyle = tostring(Value)
    end
})
getgenv().RageStyle = getgenv().RageStyle or "Attack"

WeaponGroup:AddToggle('UndergroundToggle', {
    Text = 'Underground (땅밑 공격)',
    Default = false,
    Callback = function(Value)
        getgenv().UndergroundEnabled = Value and true or false
        getgenv().__NH_UnderSurfaceY = nil
        if Value then
            getgenv().UndergroundDepth = tonumber(getgenv().UndergroundDepth) or 20
            pcall(function()
                if Library then
                    
                end
            end)
        else
            -- 언더 끄면 앵커/고정 해제
            pcall(function()
                local r = game.Players.LocalPlayer.Character
                r = r and r:FindFirstChild("HumanoidRootPart")
                if r then r.Anchored = false end
            end)
        end
    end
})
getgenv().UndergroundEnabled = false
getgenv().UndergroundDepth = getgenv().UndergroundDepth or 8

WeaponGroup:AddSlider('UndergroundDepthSlider', {
    Text = 'Underground Depth',
    Default = 8,
    Min = 2,
    Max = 25,
    Rounding = 0,
    Callback = function(Value)
        getgenv().UndergroundDepth = Value
    end
})

WeaponGroup:AddToggle('WeaponSpeedToggle', {
    Text = 'Weapon Speed (모든 무기 연사)',
    Default = false,
    Callback = function(Value)
        getgenv().WeaponSpeedEnabled = Value and true or false
        pcall(function()
            if Library then
                
            end
        end)
    end
})
getgenv().WeaponSpeedEnabled = false

WeaponGroup:AddToggle('AutoReloadToggle', {
    Text = 'Auto Reload (재장전만)',
    Default = false,
    Callback = function(Value)
        getgenv().AutoReloadEnabled = Value and true or false
    end
})
getgenv().AutoReloadEnabled = false

-- 연사/쿨다운 제거 (Weapon Speed)
task.spawn(function()
    local function stripCD()
        if not getgenv().WeaponSpeedEnabled then return end
        pcall(function()
            local char = Player.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                tool:SetAttribute("Cooldown", 0)
                tool:SetAttribute("ShootCooldown", 0)
                tool:SetAttribute("FireRate", 0)
            end
        end)
        pcall(function()
            for _, t in pairs(getgc(true)) do
                if type(t) == "table" then
                    if type(rawget(t, "ShootCooldown")) == "number" then
                        rawset(t, "ShootCooldown", 0)
                    end
                    if type(rawget(t, "AttackCooldown")) == "number" then
                        rawset(t, "AttackCooldown", 0)
                    end
                    if type(rawget(t, "FireCooldown")) == "number" then
                        rawset(t, "FireCooldown", 0)
                    end
                end
            end
        end)
    end
    while true do
        task.wait(0.15)
        stripCD()
    end
end)

WeaponGroup:AddLabel('— Rage Counter —')
WeaponGroup:AddToggle('LionRageCounterToggle', {
    Text = 'Unnamed Counter',
    Default = false,
    Callback = function(Value)
        getgenv().UnnamedCounter = Value and true or false
        getgenv().LionRageCounter = getgenv().UnnamedCounter
        pcall(function()
            if Library then  end
        end)
    end
})
getgenv().UnnamedCounter = false
getgenv().LionRageCounter = false

WeaponGroup:AddToggle('KiciaRageCounterToggle', {
    Text = 'Kicia Rage Counter',
    Default = false,
    Callback = function(Value)
        getgenv().KiciaRageCounter = Value and true or false
        pcall(function()
            if Library then  end
        end)
    end
})
getgenv().KiciaRageCounter = false


WeaponGroup:AddToggle('FakePositionToggle', {
    Text = 'Fake Position (Remote 지하)',
    Default = false,
    Callback = function(Value)
        getgenv().FakePositionEnabled = Value and true or false
        -- 연동: Fake Position = 지하 공격 위치
        if Value then
            getgenv().UndergroundEnabled = true
        end
    end
})
getgenv().FakePositionEnabled = false





WeaponGroup:AddLabel('— Baiting —')
WeaponGroup:AddToggle('BaitingToggle', {
    Text = 'Baiting (짧게 노출)',
    Default = false,
    Callback = function(Value)
        getgenv().BaitingEnabled = Value
    end
})
getgenv().BaitingEnabled = false


WeaponGroup:AddDropdown('RageStyleDropdown', {
    Values = { 'Attack', 'Evasive', 'Hybrid', 'Orbit', 'Translocate' },
    Default = 1,
    Multi = false,
    Text = 'Rage Style (HVH)',
    Callback = function(Value)
        getgenv().RageStyle = tostring(Value)
    end
})
getgenv().RageStyle = getgenv().RageStyle or "Attack"

-- rage detail sliders removed


AntiAimGroup:AddToggle('AntiAimToggle', {
    Text = 'Anti-Aim Enabled',
    Default = false,
    Callback = function(Value)
        getgenv().AntiAimEnabled = Value
    end
})

AntiAimGroup:AddDropdown('AntiAimModeDropdown', {
    Values = { 'Random', 'Jitter', 'Shooter', 'Spin', 'FastSpin', 'Freestanding', 'Fake Head', 'Sideways', 'Backwards', 'Opposite', 'JitterPitch', 'OrbitAA', 'Underground', 'SkyFlick', 'MicroJitter' },
    Default = 1,
    Multi = false,
    Text = 'Anti-Aim Mode',
    Callback = function(Value)
        getgenv().AntiAimMode = Value
    end
})
getgenv().AntiAimMode = getgenv().AntiAimMode or 'Jitter'

AntiAimGroup:AddSlider('AntiAimAngleSlider', {
    Text = 'Anti-Aim Angle',
    Default = 180,
    Min = 1,
    Max = 360,
    Rounding = 0,
    Callback = function(Value)
        getgenv().AntiAimAngle = Value
    end
})

AntiAimGroup:AddToggle('AA_PitchDown', {
    Text = 'Pitch Down',
    Default = false,
    Callback = function(Value)
        getgenv().AA_PitchDown = Value and true or false
    end
})
AntiAimGroup:AddToggle('AA_YawJitter', {
    Text = 'Extra Yaw Jitter',
    Default = false,
    Callback = function(Value)
        getgenv().AA_YawJitter = Value and true or false
    end
})
AntiAimGroup:AddToggle('AA_SpinBody', {
    Text = 'Body Spin',
    Default = false,
    Callback = function(Value)
        getgenv().AA_SpinBody = Value and true or false
    end
})
AntiAimGroup:AddToggle('AA_DesyncHint', {
    Text = 'Desync Hint',
    Default = false,
    Callback = function(Value)
        getgenv().AA_DesyncHint = Value and true or false
    end
})
AntiAimGroup:AddSlider('AA_SpinSpeed', {
    Text = 'Spin Speed',
    Default = 12,
    Min = 1,
    Max = 40,
    Rounding = 0,
    Callback = function(Value)
        getgenv().AA_SpinSpeed = Value
    end
})
getgenv().AA_SpinSpeed = 12

-- Flick Bot (보조)
AntiAimGroup:AddToggle('FlickBotToggle', {
    Text = 'Flick Bot',
    Default = false,
    Callback = function(Value)
        getgenv().FlickBotEnabled = Value and true or false
    end
})
getgenv().FlickBotEnabled = false
AntiAimGroup:AddSlider('FlickBotSpeed', {
    Text = 'Flick Speed',
    Default = 1,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        getgenv().FlickBotSpeed = Value
    end
})
getgenv().FlickBotSpeed = 1
AntiAimGroup:AddSlider('FlickBotFOV', {
    Text = 'Flick FOV',
    Default = 180,
    Min = 30,
    Max = 360,
    Rounding = 0,
    Callback = function(Value)
        getgenv().FlickBotFOV = Value
    end
})
getgenv().FlickBotFOV = 180
AntiAimGroup:AddToggle('FlickBotHeadOnly', {
    Text = 'Flick Head Only',
    Default = true,
    Callback = function(Value)
        getgenv().FlickBotHeadOnly = Value ~= false
    end
})
getgenv().FlickBotHeadOnly = true



-- Aimbot: hard lock head inside FOV (no soft spray)
getgenv().AimbotEnabled = getgenv().AimbotEnabled or false
getgenv().WallCheckEnabled = getgenv().WallCheckEnabled or false

RunService:BindToRenderStep("Nova Aimbot", Enum.RenderPriority.Camera.Value + 1, function()
    if not getgenv().AimbotEnabled then return end
    -- 사일런트와 동시면 카메라 흔들림으로 총알 튐 → 사일런트 우선
    if silentAimEnabled then return end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local nearest = nil
    local best = math.huge
    local fov = tonumber(FOV) or 150
    local mousePos = UserInputService:GetMouseLocation()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char }
    rayParams.IgnoreWater = true

    for _, player in ipairs(Players:GetPlayers()) do
        if player == Player then continue end
        if is_teammate and is_teammate(player) then continue end
        local echar = player.Character
        if not echar then continue end
        local hum = echar:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if echar:FindFirstChildOfClass("ForceField") then continue end
        local head = echar:FindFirstChild("HitboxHead") or echar:FindFirstChild("Head")
        if not head then continue end

        local sp, onScreen = cam:WorldToViewportPoint(head.Position)
        if not onScreen or sp.Z <= 0 then continue end
        local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
        if dist > fov or dist >= best then continue end

        if getgenv().WallCheckEnabled then
            local shootPos = cam.CFrame.Position
            local dir = head.Position - shootPos
            local hit = workspace:Raycast(shootPos, dir, rayParams)
            if hit and not hit.Instance:IsDescendantOf(echar) then continue end
        end
        best = dist
        nearest = head
    end

    if nearest then
        -- 즉시 헤드 고정 (Lerp 없음 = 발사 중 카메라 흔들림 X)
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, nearest.Position)
    end
end)

VisualsGroup:AddToggle('EspMasterToggle', {
    Text = 'ESP Enabled',
    Default = false,
    Callback = function(Value) getgenv().ESPEnabled = Value end
})
getgenv().ESPEnabled = false

VisualsGroup:AddToggle('NameEspToggle', {
    Text = 'Name ESP',
    Default = false,
    Callback = function(Value)
        getgenv().NameEnabled = Value
        if Value then getgenv().ESPEnabled = true end
    end
})

VisualsGroup:AddToggle('BoxEspToggle', {
    Text = 'Box ESP',
    Default = false,
    Callback = function(Value)
        getgenv().ESPBox = Value
        if Value then getgenv().ESPEnabled = true end
    end
})
getgenv().ESPBox = false

VisualsGroup:AddToggle('SkeletonEspToggle', {
    Text = 'Skeleton ESP',
    Default = false,
    Callback = function(Value)
        getgenv().ESPSkeleton = Value
        if Value then getgenv().ESPEnabled = true end
    end
})
getgenv().ESPSkeleton = false

VisualsGroup:AddToggle('HealthEspToggle', {
    Text = 'Health Bar ESP',
    Default = false,
    Callback = function(Value)
        getgenv().HealthEnabled = Value
        if Value then getgenv().ESPEnabled = true end
    end
})
getgenv().HealthEnabled = false

VisualsGroup:AddToggle('DistanceEspToggle', {
    Text = 'Distance ESP',
    Default = false,
    Callback = function(Value)
        getgenv().ESPDistance = Value
        if Value then getgenv().ESPEnabled = true end
    end
})
getgenv().ESPDistance = false

local function NH_setEspColor(name)
    local map = {
        Red = Color3.fromRGB(255, 60, 60),
        Orange = Color3.fromRGB(255, 140, 40),
        Yellow = Color3.fromRGB(255, 220, 60),
        Green = Color3.fromRGB(60, 255, 100),
        Cyan = Color3.fromRGB(60, 220, 255),
        Blue = Color3.fromRGB(60, 120, 255),
        Purple = Color3.fromRGB(160, 80, 255),
        White = Color3.fromRGB(255, 255, 255),
        Pink = Color3.fromRGB(255, 80, 180),
    }
    getgenv().ESPColor = map[tostring(name)] or map.Red
end
VisualsGroup:AddDropdown('ESPColorDropdown', {
    Values = { 'Red', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple', 'White', 'Pink' },
    Default = 1,
    Multi = false,
    Text = 'ESP Color',
    Callback = function(Value)
        NH_setEspColor(Value)
    end
})
NH_setEspColor('Red')

VisualsGroup:AddToggle('BulletTrajToggle', {
    Text = 'Bullet Trajectory',
    Default = false,
    Callback = function(Value)
        getgenv().BulletTrajectory = Value
        local Vis = getgenv().NH_NovhookVis
        if Vis and Vis.BulletTracers then
            -- keep independent; trajectory still works alone
        end
    end
})
getgenv().BulletTrajectory = false

VisualsGroup:AddSlider('BulletTrajLife', {
    Text = 'Trajectory Lifetime',
    Default = 0.35,
    Min = 0.1,
    Max = 1.5,
    Rounding = 2,
    Callback = function(Value)
        getgenv().BulletTrajLife = Value
    end
})
getgenv().BulletTrajLife = 0.35

VisualsGroup:AddDropdown('BulletTrajColor', {
    Values = { 'Red', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue', 'Purple', 'White', 'Pink' },
    Default = 1,
    Multi = false,
    Text = 'Trajectory Color',
    Callback = function(Value)
        local map = {
            Red = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 80) },
            Orange = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 220, 100) },
            Yellow = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 255, 180) },
            Green = { Color3.fromRGB(60, 255, 100), Color3.fromRGB(180, 255, 160) },
            Cyan = { Color3.fromRGB(60, 220, 255), Color3.fromRGB(160, 255, 255) },
            Blue = { Color3.fromRGB(60, 120, 255), Color3.fromRGB(140, 180, 255) },
            Purple = { Color3.fromRGB(160, 80, 255), Color3.fromRGB(220, 160, 255) },
            White = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220) },
            Pink = { Color3.fromRGB(255, 80, 180), Color3.fromRGB(255, 180, 220) },
        }
        local c = map[tostring(Value)] or map.Red
        getgenv().BulletTrajColor0 = c[1]
        getgenv().BulletTrajColor1 = c[2]
        local Vis = getgenv().NH_NovhookVis
        if Vis and Vis.BulletTracers then
            Vis.BulletTracers.ColorStart = c[1]
            Vis.BulletTracers.ColorEnd = c[2]
        end
    end
})
getgenv().BulletTrajColor0 = Color3.fromRGB(255, 60, 60)
getgenv().BulletTrajColor1 = Color3.fromRGB(255, 160, 80)

VisualsGroup:AddToggle('MapTransparencyToggle', {
    Text = 'Map Transparency',
    Default = false,
    Callback = function(Value)
        getgenv().MapTransparency = Value
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local isPlayerPart = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character and obj:IsDescendantOf(p.Character) then isPlayerPart = true break end
                end
                if not isPlayerPart then
                    if Value then
                        if not obj:GetAttribute("OriginalTransparency") then obj:SetAttribute("OriginalTransparency", obj.Transparency) end
                        obj.Transparency = 0.6
                    else
                        local orig = obj:GetAttribute("OriginalTransparency")
                        obj.Transparency = orig or 0
                    end
                end
            end
        end
    end
})

VisualsGroup:AddLabel('Skin Changer → Cosmetics 탭')

-- ===== Angel Wings (천사 날개) =====
local AngelGroup = Tabs.Visuals:AddLeftGroupbox('Angel Wings')
getgenv().AngelWingsEnabled = false
getgenv().AngelWingsScale = getgenv().AngelWingsScale or 1.0
getgenv().AngelWingsColor = getgenv().AngelWingsColor or Color3.fromRGB(80, 255, 255)

AngelGroup:AddToggle('AngelWingsToggle', {
    Text = 'Angel Wings',
    Default = false,
    Callback = function(Value)
        getgenv().AngelWingsEnabled = Value and true or false
        if not Value and getgenv().NH_DestroyAngelWings then
            pcall(getgenv().NH_DestroyAngelWings)
        end
    end
})
AngelGroup:AddSlider('AngelWingsScale', {
    Text = 'Wings Size',
    Default = 1.0,
    Min = 0.5,
    Max = 2.5,
    Rounding = 2,
    Callback = function(Value)
        getgenv().AngelWingsScale = tonumber(Value) or 1
    end
})
AngelGroup:AddDropdown('AngelWingsColor', {
    Values = { 'Cyan', 'White', 'Gold', 'Pink', 'Purple', 'Blue', 'Red' },
    Default = 1,
    Multi = false,
    Text = 'Wings Color',
    Callback = function(Value)
        local map = {
            Cyan = Color3.fromRGB(80, 255, 255),
            White = Color3.fromRGB(255, 255, 255),
            Gold = Color3.fromRGB(255, 220, 100),
            Pink = Color3.fromRGB(255, 140, 200),
            Purple = Color3.fromRGB(180, 120, 255),
            Blue = Color3.fromRGB(100, 160, 255),
            Red = Color3.fromRGB(255, 90, 90),
        }
        getgenv().AngelWingsColor = map[tostring(Value)] or map.Cyan
    end
})
AngelGroup:AddLabel('Local aura wings + glow ring')

CustomVisGroup:AddToggle('KillSoundToggle', {
    Text = 'Kill Sound',
    Default = false,
    Callback = function(Value) getgenv().KillSoundEnabled = Value end
})
CustomVisGroup:AddDropdown('KillSoundSelect', {
    Values = {
        'rust hs', 'neverlose', 'sparkle', 'minecraft hit', 'bonk',
        'osu', 'among us', 'bruh', 'vine', 'gamesense'
    },
    Default = 1,
    Multi = false,
    Text = 'Kill Sound Type',
    Callback = function(Value)
        local map = {
            ['rust hs'] = '4764109000',
            ['neverlose'] = '97643101798871',
            ['sparkle'] = '110241936966089',
            ['minecraft hit'] = '8766809464',
            ['bonk'] = '5766898159',
            ['osu'] = '7149255551',
            ['among us'] = '5700183626',
            ['bruh'] = '4578740568',
            ['vine'] = '5332680810',
            ['gamesense'] = '4817809188',
        }
        getgenv().KillSoundId = map[tostring(Value)] or '4764109000'
    end
})
CustomVisGroup:AddToggle('HitSoundToggle', {
    Text = 'Hit Sound',
    Default = true,
    Callback = function(Value) getgenv().HitSoundEnabled = Value end
})
CustomVisGroup:AddDropdown('HitSoundSelect', {
    Values = {
        'rust hs', 'neverlose', 'sparkle', 'minecraft hit', 'bonk',
        'osu', 'among us', 'bruh', 'vine', 'gamesense'
    },
    Default = 1,
    Multi = false,
    Text = 'Hit Sound Type',
    Callback = function(Value)
        local map = {
            ['rust hs'] = '4764109000',
            ['neverlose'] = '97643101798871',
            ['sparkle'] = '110241936966089',
            ['minecraft hit'] = '8766809464',
            ['bonk'] = '5766898159',
            ['osu'] = '7149255551',
            ['among us'] = '5700183626',
            ['bruh'] = '4578740568',
            ['vine'] = '5332680810',
            ['gamesense'] = '4817809188',
        }
        getgenv().HitSoundId = map[tostring(Value)] or '4764109000'
    end
})

CustomVisGroup:AddSlider('KillHitVolume', {
    Text = 'Sound Volume',
    Default = 3,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Callback = function(v) getgenv().NH_SoundVol = v end
})
getgenv().NH_SoundVol = 3




CustomVisGroup:AddToggle('HitLogToggle', {
    Text = 'Show Hit Damage Log',
    Default = true,
    Callback = function(Value)
        getgenv().HitLogEnabled = Value
        HitLogContainer.Visible = Value
        if Value and getgenv().NH_HitLogQueue then
            for _, e in ipairs(getgenv().NH_HitLogQueue) do
                if tick() - (e.t or 0) < 5 then
                    pcall(addHitLog, e.name, e.dmg)
                end
            end
            getgenv().NH_HitLogQueue = {}
        end
    end
})
getgenv().HitLogEnabled = true
if HitLogContainer then HitLogContainer.Visible = true end

-- =====================================================================
-- [VISUALS] Combat Visuals + HUD Visuals
-- =====================================================================
do
    local Vis = getgenv().NH_NovhookVis or {}
    getgenv().NH_NovhookVis = Vis

    Vis.WeaponStatus = Vis.WeaponStatus or { Enabled = false, Status = "Default" }
    Vis.RageManip = Vis.RageManip or { Enabled = false, Font = "SmallestPixel", OffsetX = 0, OffsetY = 0 }
    Vis.BulletTracers = Vis.BulletTracers or {
        Enabled = false, Texture = "beam", PositionLerp = 0, LifeTime = 1,
        ColorStart = Color3.fromRGB(0, 0, 255), ColorEnd = Color3.fromRGB(0, 255, 255), AnimSpeed = 2,
        Width0 = 0.4, Width1 = 0.2,
    }
    Vis.ShootSound = Vis.ShootSound or { Enabled = false, Sound = "hitmarker" }
    Vis.DamageNumbers = Vis.DamageNumbers or {
        Enabled = false, DisableIngame = false,
        Color = Color3.fromRGB(255, 170, 0), HeadColor = Color3.fromRGB(0, 220, 20),
    }
    Vis.GameHealthbar = Vis.GameHealthbar or {
        Hidden = false, CustomColor = false, Color = Color3.fromRGB(100, 255, 50),
        CustomSize = false, Width = 100, Height = 100,
        CustomText = false, Text = "Novhook", HideHeart = false,
        CustomPosition = false, X = 50, Y = 90,
    }
    Vis.IngameHit = Vis.IngameHit or {
        DmgColor = Color3.fromRGB(255, 255, 255), DmgHeadColor = Color3.fromRGB(255, 50, 50),
        HitColor = Color3.fromRGB(255, 255, 255), HitHeadColor = Color3.fromRGB(255, 50, 50),
    }
    Vis.HitOverlay = Vis.HitOverlay or {
        Enabled = false, Color = Color3.fromRGB(255, 60, 60), HeadColor = Color3.fromRGB(255, 210, 90),
        Strength = 0.55, Lifetime = 0.35,
    }
    Vis.ElimSpoof = Vis.ElimSpoof or {
        Show = true, Text = "Eliminated", Font = "Minecraftia",
        NamePlacement = "after text", NameColorEnabled = false,
        NameColor = Color3.fromRGB(255, 220, 90),
        CustomPos = false, X = 50, Y = 70, CustomSize = false, TextSize = 24,
        Gradient = false, GradStart = Color3.fromRGB(255, 0, 0), GradEnd = Color3.fromRGB(255, 170, 50),
        GradAngle = 0, GradAnim = "static", GradSpeed = 0.5,
        Entrance = "none", AnimDuration = 0.3,
    }

    local LeftEV = Tabs.Visuals:AddLeftGroupbox('Combat Visuals')
    local RightEV = Tabs.Visuals:AddRightGroupbox('HUD Visuals')

    -- LEFT: Weapon Status
    LeftEV:AddToggle('NH_WepStatus', {
        Text = 'Override Weapon Status', Default = false,
        Callback = function(v) Vis.WeaponStatus.Enabled = v and true or false end,
    })
    LeftEV:AddDropdown('NH_WepStatusVal', {
        Text = 'Status', Values = { 'Default', 'Prime', 'Elite', 'Mythic', 'Legendary' },
        Default = 1, Callback = function(v) Vis.WeaponStatus.Status = tostring(v) end,
    })

    -- LEFT: Ragebot Manipulation indicator
    LeftEV:AddToggle('NH_RageManip', {
        Text = 'Ragebot Manipulation', Default = false,
        Callback = function(v) Vis.RageManip.Enabled = v and true or false end,
    })
    LeftEV:AddDropdown('NH_RageManipFont', {
        Text = 'Manip Font', Values = { 'SmallestPixel', 'Gotham', 'SourceSans', 'Arcade' },
        Default = 1, Callback = function(v) Vis.RageManip.Font = tostring(v) end,
    })
    LeftEV:AddSlider('NH_RageManipX', {
        Text = 'Offset X', Default = 0, Min = -500, Max = 500, Rounding = 0,
        Callback = function(v) Vis.RageManip.OffsetX = v end,
    })
    LeftEV:AddSlider('NH_RageManipY', {
        Text = 'Offset Y', Default = 0, Min = -500, Max = 500, Rounding = 0,
        Callback = function(v) Vis.RageManip.OffsetY = v end,
    })

    -- LEFT: Bullet Tracers
    LeftEV:AddToggle('NH_BulletTracers', {
        Text = 'Bullet Tracers', Default = false,
        Callback = function(v) Vis.BulletTracers.Enabled = v and true or false end,
    })
    LeftEV:AddDropdown('NH_BT_Texture', {
        Text = 'Texture', Values = { 'beam', 'laser', 'smoke', 'lightning' },
        Default = 1, Callback = function(v) Vis.BulletTracers.Texture = tostring(v) end,
    })
    LeftEV:AddSlider('NH_BT_Lerp', {
        Text = 'Position Lerp', Default = 0, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) Vis.BulletTracers.PositionLerp = v end,
    })
    LeftEV:AddSlider('NH_BT_Life', {
        Text = 'Lifetime', Default = 1, Min = 0.1, Max = 5, Rounding = 1,
        Callback = function(v) Vis.BulletTracers.LifeTime = v end,
    })
    LeftEV:AddLabel('Tracer Start'):AddColorPicker('NH_BT_Start', {
        Default = Color3.fromRGB(0, 0, 255), Title = 'Start',
        Callback = function(c)
            Vis.BulletTracers.ColorStart = c
            getgenv().BulletTrajColor0 = c
        end,
    })
    LeftEV:AddLabel('Tracer End'):AddColorPicker('NH_BT_End', {
        Default = Color3.fromRGB(0, 255, 255), Title = 'End',
        Callback = function(c)
            Vis.BulletTracers.ColorEnd = c
            getgenv().BulletTrajColor1 = c
        end,
    })
    LeftEV:AddSlider('NH_BT_Anim', {
        Text = 'Animation Speed', Default = 2, Min = 0, Max = 10, Rounding = 1,
        Callback = function(v) Vis.BulletTracers.AnimSpeed = v end,
    })

    -- LEFT: Shoot Sound
    LeftEV:AddToggle('NH_ShootSound', {
        Text = 'Shoot Sound', Default = false,
        Callback = function(v) Vis.ShootSound.Enabled = v and true or false end,
    })
    LeftEV:AddDropdown('NH_ShootSoundType', {
        Text = 'Sound', Values = { 'hitmarker', 'rust hs', 'neverlose', 'gamesense', 'osu' },
        Default = 1, Callback = function(v) Vis.ShootSound.Sound = tostring(v) end,
    })

    -- LEFT: Damage Numbers
    LeftEV:AddToggle('NH_DmgNum', {
        Text = 'Damage Numbers', Default = false,
        Callback = function(v) Vis.DamageNumbers.Enabled = v and true or false end,
    })
    LeftEV:AddToggle('NH_DmgNumDisableIngame', {
        Text = 'Disable Ingame Damage Numbers', Default = false,
        Callback = function(v) Vis.DamageNumbers.DisableIngame = v and true or false end,
    })
    LeftEV:AddLabel('Dmg Color'):AddColorPicker('NH_DmgNumColor', {
        Default = Color3.fromRGB(255, 170, 0), Title = 'Damage',
        Callback = function(c) Vis.DamageNumbers.Color = c end,
    })
    LeftEV:AddLabel('Head Dmg Color'):AddColorPicker('NH_DmgNumHead', {
        Default = Color3.fromRGB(0, 220, 20), Title = 'Headshot',
        Callback = function(c) Vis.DamageNumbers.HeadColor = c end,
    })

    -- RIGHT: Game Healthbar
    RightEV:AddToggle('NH_HB_Hide', {
        Text = 'Hide Healthbar', Default = false,
        Callback = function(v) Vis.GameHealthbar.Hidden = v and true or false end,
    })
    RightEV:AddToggle('NH_HB_CustomColor', {
        Text = 'Custom Color', Default = false,
        Callback = function(v) Vis.GameHealthbar.CustomColor = v and true or false end,
    }):AddColorPicker('NH_HB_Color', {
        Default = Color3.fromRGB(100, 255, 50), Title = 'Healthbar Color',
        Callback = function(c) Vis.GameHealthbar.Color = c end,
    })
    RightEV:AddToggle('NH_HB_CustomSize', {
        Text = 'Custom Size', Default = false,
        Callback = function(v) Vis.GameHealthbar.CustomSize = v and true or false end,
    })
    RightEV:AddSlider('NH_HB_W', {
        Text = 'Width', Default = 100, Min = 20, Max = 400, Rounding = 0,
        Callback = function(v) Vis.GameHealthbar.Width = v end,
    })
    RightEV:AddSlider('NH_HB_H', {
        Text = 'Height', Default = 100, Min = 10, Max = 200, Rounding = 0,
        Callback = function(v) Vis.GameHealthbar.Height = v end,
    })
    RightEV:AddToggle('NH_HB_CustomText', {
        Text = 'Replace Health Number', Default = false,
        Callback = function(v) Vis.GameHealthbar.CustomText = v and true or false end,
    })
    RightEV:AddInput('NH_HB_Text', {
        Text = 'Health Text', Default = 'Novhook',
        Callback = function(v) Vis.GameHealthbar.Text = tostring(v) end,
    })
    RightEV:AddToggle('NH_HB_HideHeart', {
        Text = 'Hide Heart Icon', Default = false,
        Callback = function(v) Vis.GameHealthbar.HideHeart = v and true or false end,
    })
    RightEV:AddToggle('NH_HB_CustomPos', {
        Text = 'Custom Position', Default = false,
        Callback = function(v) Vis.GameHealthbar.CustomPosition = v and true or false end,
    })
    RightEV:AddSlider('NH_HB_X', {
        Text = 'Horizontal Position', Default = 50, Min = 0, Max = 100, Rounding = 0,
        Callback = function(v) Vis.GameHealthbar.X = v end,
    })
    RightEV:AddSlider('NH_HB_Y', {
        Text = 'Vertical Position', Default = 90, Min = 0, Max = 100, Rounding = 0,
        Callback = function(v) Vis.GameHealthbar.Y = v end,
    })

    -- RIGHT: Ingame Hit Effects
    RightEV:AddLabel('Ingame Hit Effects')
    RightEV:AddLabel('Dmg Number Color'):AddColorPicker('NH_IH_Dmg', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Dmg',
        Callback = function(c) Vis.IngameHit.DmgColor = c end,
    })
    RightEV:AddLabel('Dmg Head Color'):AddColorPicker('NH_IH_DmgH', {
        Default = Color3.fromRGB(255, 50, 50), Title = 'Dmg Head',
        Callback = function(c) Vis.IngameHit.DmgHeadColor = c end,
    })
    RightEV:AddLabel('Hitmarker Color'):AddColorPicker('NH_IH_Hit', {
        Default = Color3.fromRGB(255, 255, 255), Title = 'Hitmarker',
        Callback = function(c) Vis.IngameHit.HitColor = c end,
    })
    RightEV:AddLabel('Hitmarker Head'):AddColorPicker('NH_IH_HitH', {
        Default = Color3.fromRGB(255, 50, 50), Title = 'Hit Head',
        Callback = function(c) Vis.IngameHit.HitHeadColor = c end,
    })

    -- RIGHT: Hit Overlay
    RightEV:AddToggle('NH_HitOverlay', {
        Text = 'Hit Overlay', Default = false,
        Callback = function(v) Vis.HitOverlay.Enabled = v and true or false end,
    }):AddColorPicker('NH_HO_Color', {
        Default = Color3.fromRGB(255, 60, 60), Title = 'Overlay',
        Callback = function(c) Vis.HitOverlay.Color = c end,
    })
    RightEV:AddSlider('NH_HO_Str', {
        Text = 'Strength', Default = 0.55, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) Vis.HitOverlay.Strength = v end,
    })
    RightEV:AddSlider('NH_HO_Life', {
        Text = 'Lifetime', Default = 0.35, Min = 0.05, Max = 2, Rounding = 2,
        Callback = function(v) Vis.HitOverlay.Lifetime = v end,
    })

    -- RIGHT: Eliminated Spoofer
    RightEV:AddToggle('NH_ElimShow', {
        Text = 'Show Eliminated Text', Default = true,
        Callback = function(v) Vis.ElimSpoof.Show = v and true or false end,
    })
    RightEV:AddInput('NH_ElimText', {
        Text = 'Eliminated Text', Default = 'Eliminated',
        Callback = function(v) Vis.ElimSpoof.Text = tostring(v) end,
    })
    RightEV:AddDropdown('NH_ElimFont', {
        Text = 'Font', Values = { 'Minecraftia', 'Gotham', 'SourceSans', 'Arcade', 'SmallestPixel' },
        Default = 1, Callback = function(v) Vis.ElimSpoof.Font = tostring(v) end,
    })
    RightEV:AddDropdown('NH_ElimNamePlace', {
        Text = 'Name Placement', Values = { 'after text', 'before text', 'hidden' },
        Default = 1, Callback = function(v) Vis.ElimSpoof.NamePlacement = tostring(v) end,
    })
    RightEV:AddToggle('NH_ElimNameColor', {
        Text = 'Custom Name Color', Default = false,
        Callback = function(v) Vis.ElimSpoof.NameColorEnabled = v and true or false end,
    }):AddColorPicker('NH_ElimNameCol', {
        Default = Color3.fromRGB(255, 220, 90), Title = 'Name Color',
        Callback = function(c) Vis.ElimSpoof.NameColor = c end,
    })
    RightEV:AddToggle('NH_ElimPos', {
        Text = 'Custom Screen Position', Default = false,
        Callback = function(v) Vis.ElimSpoof.CustomPos = v and true or false end,
    })
    RightEV:AddSlider('NH_ElimX', {
        Text = 'Screen X', Default = 50, Min = 0, Max = 100, Rounding = 0,
        Callback = function(v) Vis.ElimSpoof.X = v end,
    })
    RightEV:AddSlider('NH_ElimY', {
        Text = 'Screen Y', Default = 70, Min = 0, Max = 100, Rounding = 0,
        Callback = function(v) Vis.ElimSpoof.Y = v end,
    })
    RightEV:AddToggle('NH_ElimSize', {
        Text = 'Custom Text Size', Default = false,
        Callback = function(v) Vis.ElimSpoof.CustomSize = v and true or false end,
    })
    RightEV:AddSlider('NH_ElimTS', {
        Text = 'Text Size', Default = 24, Min = 8, Max = 72, Rounding = 0,
        Callback = function(v) Vis.ElimSpoof.TextSize = v end,
    })
    RightEV:AddToggle('NH_ElimGrad', {
        Text = 'Text and Name Gradient', Default = false,
        Callback = function(v) Vis.ElimSpoof.Gradient = v and true or false end,
    })
    RightEV:AddLabel('Grad Start'):AddColorPicker('NH_ElimGS', {
        Default = Color3.fromRGB(255, 0, 0), Title = 'Grad Start',
        Callback = function(c) Vis.ElimSpoof.GradStart = c end,
    })
    RightEV:AddLabel('Grad End'):AddColorPicker('NH_ElimGE', {
        Default = Color3.fromRGB(255, 170, 50), Title = 'Grad End',
        Callback = function(c) Vis.ElimSpoof.GradEnd = c end,
    })
    RightEV:AddSlider('NH_ElimGA', {
        Text = 'Gradient Angle', Default = 0, Min = 0, Max = 360, Rounding = 0,
        Callback = function(v) Vis.ElimSpoof.GradAngle = v end,
    })
    RightEV:AddDropdown('NH_ElimGAnim', {
        Text = 'Gradient Animation', Values = { 'static', 'rotate', 'pulse' },
        Default = 1, Callback = function(v) Vis.ElimSpoof.GradAnim = tostring(v) end,
    })
    RightEV:AddSlider('NH_ElimGSpd', {
        Text = 'Gradient Speed', Default = 0.5, Min = 0, Max = 5, Rounding = 1,
        Callback = function(v) Vis.ElimSpoof.GradSpeed = v end,
    })
    RightEV:AddDropdown('NH_ElimEntrance', {
        Text = 'Entrance Animation', Values = { 'none', 'fade', 'scale', 'slide' },
        Default = 1, Callback = function(v) Vis.ElimSpoof.Entrance = tostring(v) end,
    })
    RightEV:AddSlider('NH_ElimAnimDur', {
        Text = 'Animation Duration', Default = 0.3, Min = 0.05, Max = 2, Rounding = 2,
        Callback = function(v) Vis.ElimSpoof.AnimDuration = v end,
    })

    -- Runtime: healthbar / elim / overlay / tracers (lightweight)
    local CoreGui = game:GetService("CoreGui")
    local visGui = Instance.new("ScreenGui")
    visGui.Name = "NH_NovhookVisuals"
    visGui.ResetOnSpawn = false
    visGui.IgnoreGuiInset = true
    visGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() visGui.Parent = gethui and gethui() or CoreGui end)
    if not visGui.Parent then visGui.Parent = Player:WaitForChild("PlayerGui") end

    local overlay = Instance.new("Frame")
    overlay.Name = "HitOverlay"
    overlay.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 50
    overlay.Parent = visGui

    local elimLabel = Instance.new("TextLabel")
    elimLabel.Name = "ElimText"
    elimLabel.BackgroundTransparency = 1
    elimLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    elimLabel.Position = UDim2.fromScale(0.5, 0.7)
    elimLabel.Size = UDim2.new(0, 420, 0, 40)
    elimLabel.Font = Enum.Font.GothamBold
    elimLabel.TextSize = 24
    elimLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    elimLabel.TextStrokeTransparency = 0.4
    elimLabel.Text = ""
    elimLabel.Visible = false
    elimLabel.ZIndex = 60
    elimLabel.Parent = visGui

    local manipLabel = Instance.new("TextLabel")
    manipLabel.Name = "RageManip"
    manipLabel.BackgroundTransparency = 1
    manipLabel.AnchorPoint = Vector2.new(0.5, 0)
    manipLabel.Position = UDim2.new(0.5, 0, 0, 8)
    manipLabel.Size = UDim2.new(0, 280, 0, 22)
    manipLabel.Font = Enum.Font.Code
    manipLabel.TextSize = 14
    manipLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
    manipLabel.TextStrokeTransparency = 0.5
    manipLabel.Text = ""
    manipLabel.Visible = false
    manipLabel.ZIndex = 55
    manipLabel.Parent = visGui

    local function showElim(name)
        if not Vis.ElimSpoof.Show then return end
        local base = tostring(Vis.ElimSpoof.Text or "Eliminated")
        local place = Vis.ElimSpoof.NamePlacement or "after text"
        local shown
        if place == "hidden" or not name or name == "" then
            shown = base
        elseif place == "before text" then
            shown = tostring(name) .. " " .. base
        else
            shown = base .. " " .. tostring(name)
        end
        elimLabel.Text = shown
        elimLabel.TextSize = Vis.ElimSpoof.CustomSize and (Vis.ElimSpoof.TextSize or 24) or 24
        if Vis.ElimSpoof.CustomPos then
            elimLabel.Position = UDim2.fromScale((Vis.ElimSpoof.X or 50) / 100, (Vis.ElimSpoof.Y or 70) / 100)
        else
            elimLabel.Position = UDim2.fromScale(0.5, 0.7)
        end
        if Vis.ElimSpoof.NameColorEnabled then
            elimLabel.TextColor3 = Vis.ElimSpoof.NameColor
        else
            elimLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end
        elimLabel.Visible = true
        elimLabel.TextTransparency = 0
        local dur = tonumber(Vis.ElimSpoof.AnimDuration) or 0.3
        task.delay(math.max(dur, 0.8), function()
            for i = 0, 10 do
                elimLabel.TextTransparency = i / 10
                task.wait(0.03)
            end
            elimLabel.Visible = false
        end)
    end
    getgenv().NH_ShowEliminated = showElim

    local function flashOverlay(headshot)
        if not Vis.HitOverlay.Enabled then return end
        local c = headshot and Vis.HitOverlay.HeadColor or Vis.HitOverlay.Color
        local str = tonumber(Vis.HitOverlay.Strength) or 0.55
        local life = tonumber(Vis.HitOverlay.Lifetime) or 0.35
        overlay.BackgroundColor3 = c
        overlay.BackgroundTransparency = 1 - str
        task.spawn(function()
            local t0 = os.clock()
            while os.clock() - t0 < life do
                local a = (os.clock() - t0) / life
                overlay.BackgroundTransparency = (1 - str) + str * a
                RunService.RenderStepped:Wait()
            end
            overlay.BackgroundTransparency = 1
        end)
    end
    getgenv().NH_FlashHitOverlay = flashOverlay

    -- damage / kill -> elim + overlay
    pcall(function()
        local oldMark = getgenv().NH_MarkAttack
        -- health track already exists; hook via queueOrShowHit path when kill
    end)

    -- spawn tracer beam helper
    local textureIds = {
        beam = "rbxassetid://446111271",
        laser = "rbxassetid://446111271",
        smoke = "rbxassetid://446111271",
        lightning = "rbxassetid://446111271",
    }
    -- Elisium-style animated bullet tracer (colors from UI pickers)
    getgenv().NH_SpawnBulletTracer = function(fromPos, toPos, force)
        local bt = Vis.BulletTracers
        local on = (bt and bt.Enabled) or getgenv().BulletTrajectory == true
        if not on then return end
        -- 실제 총 발사 직후만 (조이스틱/화면 회전 차단)
        local shotAt = tonumber(getgenv().__NH_LastGunShot) or 0
        if (os.clock() - shotAt) > 0.3 then return end
        if typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then return end
        if (toPos - fromPos).Magnitude < 0.5 then return end
        pcall(function()
            local TS = game:GetService("TweenService")
            local c0 = (bt and bt.ColorStart) or getgenv().BulletTrajColor0 or Color3.fromRGB(0, 180, 255)
            local c1 = (bt and bt.ColorEnd) or getgenv().BulletTrajColor1 or Color3.fromRGB(255, 80, 255)
            local life = tonumber((bt and bt.LifeTime) or getgenv().BulletTrajLife) or 1
            local lerpT = math.max(tonumber(bt and bt.PositionLerp) or 0.15, 0.05)
            local w0 = tonumber(bt and bt.Width0) or 0.45
            local w1 = tonumber(bt and bt.Width1) or 0.2
            local spd = tonumber(bt and bt.AnimSpeed) or 2
            local tex = textureIds[(bt and bt.Texture) or "beam"] or textureIds.beam

            local folder = workspace:FindFirstChild("NH_TracerFolder")
            if not folder then
                folder = Instance.new("Folder")
                folder.Name = "NH_TracerFolder"
                folder.Parent = workspace
            end

            local delta = toPos - fromPos
            local mag = delta.Magnitude
            local unit = mag > 0 and delta.Unit or Vector3.new(0, 0, -1)

            local p0 = Instance.new("Part")
            p0.Name = "NH_TracerA"
            p0.Anchored = true
            p0.CanCollide = false
            p0.CanTouch = false
            p0.CanQuery = false
            p0.Transparency = 1
            p0.Size = Vector3.one * 0.05
            p0.CFrame = CFrame.new(fromPos)
            p0.Parent = folder

            local p1 = Instance.new("Part")
            p1.Name = "NH_TracerB"
            p1.Anchored = true
            p1.CanCollide = false
            p1.CanTouch = false
            p1.CanQuery = false
            p1.Transparency = 1
            p1.Size = Vector3.one * 0.05
            p1.CFrame = CFrame.new(fromPos) -- starts at muzzle, flies to hit
            p1.Parent = folder

            local a0 = Instance.new("Attachment")
            a0.Parent = p0
            local a1 = Instance.new("Attachment")
            a1.Parent = p1

            local beam = Instance.new("Beam")
            beam.Attachment0 = a0
            beam.Attachment1 = a1
            beam.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, c0),
                ColorSequenceKeypoint.new(0.5, c1),
                ColorSequenceKeypoint.new(1, c0),
            })
            beam.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.7, 0.15),
                NumberSequenceKeypoint.new(1, 0.85),
            })
            beam.Width0 = w0
            beam.Width1 = w1
            beam.FaceCamera = true
            beam.LightEmission = 1
            beam.LightInfluence = 0
            beam.Texture = tex
            beam.TextureMode = Enum.TextureMode.Stretch
            beam.TextureSpeed = spd
            beam.TextureLength = 3
            beam.Parent = folder

            local t0 = os.clock()
            local conn
            conn = RunService.PreRender:Connect(function(dt)
                local elapsed = os.clock() - t0
                local fly = math.min(elapsed / lerpT, 1)
                p1.CFrame = CFrame.new(fromPos + unit * mag * fly)
                local fade = math.clamp(elapsed / life, 0, 1)
                local a = fade * 0.95
                beam.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, a * 0.3),
                    NumberSequenceKeypoint.new(0.5, a),
                    NumberSequenceKeypoint.new(1, math.min(1, a + 0.2)),
                })
                if elapsed >= life then
                    if conn then conn:Disconnect() end
                    pcall(function() p0:Destroy() end)
                    pcall(function() p1:Destroy() end)
                    pcall(function() beam:Destroy() end)
                end
            end)
        end)
    end

    -- Sync legacy Bullet Trajectory toggle with Elisium-style tracers
    pcall(function()
        -- when either is on, both systems share colors
        getgenv().__NH_SyncTracerColors = function()
            local bt = Vis.BulletTracers
            if bt then
                if getgenv().BulletTrajColor0 then bt.ColorStart = getgenv().BulletTrajColor0 end
                if getgenv().BulletTrajColor1 then bt.ColorEnd = getgenv().BulletTrajColor1 end
            end
        end
    end)

    -- Rivals: hook TracerEffect.Play when module exists (Elisium method)
    task.spawn(function()
        for _ = 1, 40 do
            local ok = pcall(function()
                local effects = ReplicatedStorage:FindFirstChild("Effects")
                    or ReplicatedStorage:FindFirstChild("Modules")
                if not effects then
                    -- search Controllers / shared
                    local ps = Player:FindFirstChild("PlayerScripts")
                    effects = ps and ps:FindFirstChild("Effects")
                end
                local function tryHook(mod)
                    if not mod then return false end
                    local ok2, tbl = pcall(require, mod)
                    if not ok2 or type(tbl) ~= "table" then return false end
                    if type(tbl.Play) ~= "function" then return false end
                    if tbl.__NH_Hooked then return true end
                    local old = tbl.Play
                    tbl.Play = function(...)
                        local args = { ... }
                        local isLocal = false
                        local muzzle, results
                        pcall(function()
                            local info = args[2]
                            if type(info) == "table" then
                                isLocal = info.IsLocal == true
                                results = info.RaycastResults
                            end
                            local m = args[4]
                            if type(m) == "table" then
                                muzzle = m.MuzzlePosition
                            elseif typeof(m) == "Vector3" then
                                muzzle = m
                            end
                        end)
                        local btOn = (Vis.BulletTracers and Vis.BulletTracers.Enabled) or getgenv().BulletTrajectory
                        if isLocal and btOn and muzzle and type(results) == "table" and #results > 0 then
                            getgenv().__NH_LastGunShot = os.clock()
                            for _, r in pairs(results) do
                                local pos = type(r) == "table" and r.Position or (typeof(r) == "RaycastResult" and r.Position)
                                if typeof(pos) == "Vector3" then
                                    getgenv().NH_SpawnBulletTracer(muzzle, pos, true)
                                end
                            end
                            return -- replace default local tracer with ours
                        end
                        return old(...)
                    end
                    tbl.__NH_Hooked = true
                    return true
                end
                local hooked = false
                for _, name in ipairs({"TracerEffect", "BulletTracer", "Tracers", "GunTracer"}) do
                    local m = effects and effects:FindFirstChild(name)
                    if tryHook(m) then hooked = true end
                end
                -- deep search
                if not hooked then
                    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
                        if d.Name == "TracerEffect" and d:IsA("ModuleScript") then
                            if tryHook(d) then hooked = true break end
                        end
                    end
                end
                if hooked then return true end
            end)
            if ok then break end
            task.wait(0.5)
        end
    end)

    -- Muzzle helper for manual tracers
    getgenv().NH_GetMuzzlePos = function()
        local cam = workspace.CurrentCamera
        local char = Player.Character
        local origin = cam and cam.CFrame.Position or Vector3.zero
        pcall(function()
            local ps = Player:FindFirstChild("PlayerScripts")
            local c = ps and ps:FindFirstChild("Controllers")
            local mod = c and c:FindFirstChild("FighterController")
            if mod then
                local fc = require(mod)
                local item = fc and fc.LocalFighter and fc.LocalFighter.EquippedItem
                local vm = item and item.ViewModel
                local model = vm and (vm.Model or vm.ItemModel)
                if model then
                    local muz = model:FindFirstChild("Muzzle", true)
                        or model:FindFirstChild("Fire", true)
                        or model:FindFirstChild("Barrel", true)
                    if muz and muz:IsA("BasePart") then
                        origin = muz.Position
                        return
                    end
                    if muz and muz:IsA("Attachment") then
                        origin = muz.WorldPosition
                        return
                    end
                end
            end
            if char then
                local head = char:FindFirstChild("Head")
                if head then origin = head.Position + (cam and cam.CFrame.LookVector or Vector3.zAxis) * 0.5 end
            end
        end)
        return origin
    end

    -- healthbar restyle loop
    RunService.Heartbeat:Connect(function()
        pcall(function()
            local hb = Vis.GameHealthbar
            local pg = Player:FindFirstChild("PlayerGui")
            if not pg then return end
            for _, d in ipairs(pg:GetDescendants()) do
                local n = string.lower(d.Name)
                if n:find("health", 1, true) or n:find("hpbar", 1, true) or n:find("healthbar", 1, true) then
                    if d:IsA("GuiObject") then
                        if hb.Hidden then
                            d.Visible = false
                        else
                            d.Visible = true
                            if hb.CustomColor and (d:IsA("Frame") or d:IsA("ImageLabel") or d:IsA("TextLabel")) then
                                if d:IsA("TextLabel") then
                                    d.TextColor3 = hb.Color
                                else
                                    d.BackgroundColor3 = hb.Color
                                    if d:IsA("ImageLabel") then d.ImageColor3 = hb.Color end
                                end
                            end
                            if hb.CustomSize and d:IsA("GuiObject") and (n == "healthbar" or n:find("bar", 1, true)) then
                                d.Size = UDim2.fromOffset(hb.Width or 100, hb.Height or 20)
                            end
                            if hb.CustomPosition and d:IsA("GuiObject") and (n == "healthbar" or n:find("healthbar", 1, true)) then
                                d.Position = UDim2.fromScale((hb.X or 50) / 100, (hb.Y or 90) / 100)
                            end
                            if hb.CustomText and d:IsA("TextLabel") and n:find("health", 1, true) then
                                d.Text = tostring(hb.Text or "Novhook")
                            end
                            if hb.HideHeart and (n:find("heart", 1, true) or n:find("icon", 1, true)) then
                                d.Visible = false
                            end
                        end
                    end
                end
            end
        end)

        -- rage manip indicator
        pcall(function()
            if Vis.RageManip.Enabled and (getgenv().RagebotEnabled or getgenv().NH_RageEnabled) then
                manipLabel.Visible = true
                manipLabel.Text = "manipulation"
                manipLabel.Position = UDim2.new(0.5, Vis.RageManip.OffsetX or 0, 0, 8 + (Vis.RageManip.OffsetY or 0))
            else
                manipLabel.Visible = false
            end
        end)

        -- weapon status attribute spoof
        pcall(function()
            if Vis.WeaponStatus.Enabled then
                Player:SetAttribute("WeaponStatus", Vis.WeaponStatus.Status)
                Player:SetAttribute("PlayerStatus", Vis.WeaponStatus.Status)
            end
        end)
    end)

    -- wire kill -> elim text
    pcall(function()
        local lastKillCheck = {}
        Players.PlayerAdded:Connect(function() end)
        task.spawn(function()
            while true do
                task.wait(0.15)
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= Player and plr.Character then
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if hum then
                            local prev = lastKillCheck[plr]
                            if prev and prev > 0 and hum.Health <= 0 then
                                if (tick() - (getgenv()._nhLastAttack or 0)) < 2.5 then
                                    showElim(plr.Name)
                                    flashOverlay(true)
                                end
                            end
                            lastKillCheck[plr] = hum.Health
                        end
                    end
                end
            end
        end)
    end)

    -- expose attack time for elim detect
    do
        local old = getgenv().NH_MarkAttack
        getgenv().NH_MarkAttack = function(...)
            getgenv()._nhLastAttack = tick()
            if type(old) == "function" then return old(...) end
        end
    end

    print("[Novhook premium] Combat Visuals/R + Device Icon Color added")
end

local espCounter = 0
RunService.RenderStepped:Connect(function()
    espCounter = (espCounter + 1) % 6
    if espCounter ~= 0 then return end
    for _, p in ipairs(getgenv().__NH_GetPlayers and getgenv().__NH_GetPlayers() or Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local char = p.Character
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildOfClass("Humanoid")
            local isAlive = hum and hum.Health > 0
            local highlight = char:FindFirstChild("NH_ESP_HL")
            local wantHL = getgenv().ESPEnabled and isAlive and (getgenv().ESPBox == true or getgenv().ESPSkeleton == true)
            if wantHL then
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "NH_ESP_HL"
                    highlight.Adornee = char
                    highlight.Parent = char
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
                highlight.Enabled = true
                highlight.FillTransparency = 0.85
                highlight.OutlineTransparency = 0
                highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
                highlight.FillColor = Color3.fromRGB(255, 40, 40)
            else
                if highlight then highlight.Enabled = false end
            end
        end
    end
end)


-- ESP — Billboard + Highlight (Delta/모바일 Drawing 없이도 동작)
local NH_ESP_REF = {}
local function NH_espColor()
    return getgenv().ESPColor or Color3.fromRGB(255, 60, 60)
end

local function NH_espClear(plr)
    local bag = NH_ESP_REF[plr]
    if bag then
        pcall(function()
            if bag.bb and bag.bb.Parent then bag.bb:Destroy() end
        end)
        pcall(function()
            if bag.hl and bag.hl.Parent then bag.hl:Destroy() end
        end)
    end
    NH_ESP_REF[plr] = nil
    pcall(function()
        local c = plr.Character
        if c then
            local hl = c:FindFirstChild("NH_ESP_HL")
            if hl then hl:Destroy() end
            local bb = c:FindFirstChild("NH_ESP_BB")
            if bb then bb:Destroy() end
        end
    end)
end

local function NH_espEnsure(plr, char)
    local bag = NH_ESP_REF[plr]
    if bag and bag.bb and bag.bb.Parent and bag.hl and bag.hl.Parent then
        return bag
    end
    NH_espClear(plr)
    bag = {}

    local hl = Instance.new("Highlight")
    hl.Name = "NH_ESP_HL"
    hl.Adornee = char
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.75
    hl.OutlineTransparency = 0
    hl.Enabled = false
    hl.Parent = char
    bag.hl = hl

    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    local bb = Instance.new("BillboardGui")
    bb.Name = "NH_ESP_BB"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 120, 0, 50)
    bb.StudsOffset = Vector3.new(0, 2.6, 0)
    bb.MaxDistance = 2000
    bb.Adornee = head
    bb.Parent = char

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextColor3 = NH_espColor()
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.Text = plr.Name
    nameLbl.Visible = false
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Dist"
    distLbl.BackgroundTransparency = 1
    distLbl.Size = UDim2.new(1, 0, 0, 14)
    distLbl.Position = UDim2.new(0, 0, 0, 14)
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLbl.TextStrokeTransparency = 0.4
    distLbl.Text = ""
    distLbl.Visible = false
    distLbl.Parent = bb

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HpBg"
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel = 0
    hpBg.Size = UDim2.new(0.8, 0, 0, 4)
    hpBg.Position = UDim2.new(0.1, 0, 0, 30)
    hpBg.Visible = false
    hpBg.Parent = bb
    local hpFill = Instance.new("Frame")
    hpFill.Name = "HpFill"
    hpFill.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Parent = hpBg

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 2
    box.BorderColor3 = NH_espColor()
    box.Size = UDim2.new(0, 40, 0, 55)
    box.AnchorPoint = Vector2.new(0.5, 1)
    box.Position = UDim2.new(0.5, 0, 1, 8)
    box.Visible = false
    box.Parent = bb

    bag.bb = bb
    bag.name = nameLbl
    bag.dist = distLbl
    bag.hpBg = hpBg
    bag.hp = hpFill
    bag.box = box
    NH_ESP_REF[plr] = bag
    return bag
end

RunService.RenderStepped:Connect(function()
    local nameOn = getgenv().NameEnabled == true
    local boxOn = getgenv().ESPBox == true
    local hpOn = getgenv().HealthEnabled == true
    local distOn = getgenv().ESPDistance == true
    local skelOn = getgenv().ESPSkeleton == true
    local master = getgenv().ESPEnabled == true
    if not (master or nameOn or boxOn or hpOn or distOn or skelOn) then
        for p in pairs(NH_ESP_REF) do NH_espClear(p) end
        return
    end
    -- sub-toggles alone still show; master enables default set
    if master and not (nameOn or boxOn or hpOn or distOn or skelOn) then
        nameOn, boxOn, hpOn = true, true, true
    end

    local me = Player
    local myRoot = me and me.Character and me.Character:FindFirstChild("HumanoidRootPart")
    local col = NH_espColor()
    local seen = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == me or not plr.Character then continue end
        local char = plr.Character
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then
            NH_espClear(plr)
            continue
        end
        seen[plr] = true
        local bag = NH_espEnsure(plr, char)
        if not bag then continue end

        -- re-bind adornee if respawned parts
        local head = char:FindFirstChild("Head") or root
        if bag.bb and bag.bb.Adornee ~= head then
            bag.bb.Adornee = head
        end
        if bag.hl and bag.hl.Adornee ~= char then
            bag.hl.Adornee = char
        end

        if bag.name then
            bag.name.Visible = nameOn
            bag.name.Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " @" .. plr.Name) or plr.Name
            bag.name.TextColor3 = col
        end
        if bag.dist then
            bag.dist.Visible = distOn and myRoot ~= nil
            if distOn and myRoot then
                bag.dist.Text = string.format("%dm", math.floor((myRoot.Position - root.Position).Magnitude))
            end
        end
        if bag.hpBg and bag.hp then
            bag.hpBg.Visible = hpOn
            if hpOn then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                bag.hp.Size = UDim2.new(ratio, 0, 1, 0)
                bag.hp.BackgroundColor3 = Color3.fromRGB(80, 255, 80):Lerp(Color3.fromRGB(255, 50, 50), 1 - ratio)
            end
        end
        if bag.box then
            bag.box.Visible = boxOn
            bag.box.BorderColor3 = col
        end
        if bag.hl then
            local showHl = skelOn or boxOn
            bag.hl.Enabled = showHl
            if showHl then
                bag.hl.OutlineColor = col
                bag.hl.FillColor = col
                bag.hl.FillTransparency = skelOn and 0.7 or 0.85
            end
        end
        if bag.bb then
            bag.bb.Enabled = nameOn or distOn or hpOn or boxOn
        end
    end
    for p in pairs(NH_ESP_REF) do
        if not seen[p] then NH_espClear(p) end
    end
end)

-- Map transparency continuous apply
task.spawn(function()
    local last = false
    while true do
        task.wait(1.5)
        local on = getgenv().MapTransparency == true
        if on ~= last or on then
            last = on
            pcall(function()
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local isPlayer = false
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Character and obj:IsDescendantOf(p.Character) then
                                isPlayer = true
                                break
                            end
                        end
                        if not isPlayer then
                            if on then
                                if obj:GetAttribute("OriginalTransparency") == nil then
                                    obj:SetAttribute("OriginalTransparency", obj.Transparency)
                                end
                                if obj.Transparency < 0.55 then
                                    obj.Transparency = 0.55
                                end
                            else
                                local orig = obj:GetAttribute("OriginalTransparency")
                                if orig ~= nil then
                                    obj.Transparency = orig
                                    obj:SetAttribute("OriginalTransparency", nil)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Damage numbers + overlay + elim wired to my hits
do
    local dmgFolder = Instance.new("Folder")
    dmgFolder.Name = "NH_DmgNums"
    pcall(function()
        dmgFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not dmgFolder.Parent then
        dmgFolder.Parent = Player:WaitForChild("PlayerGui")
    end

    getgenv().NH_ShowDamageNumber = function(worldPos, amount, headshot)
        local Vis = getgenv().NH_NovhookVis
        if not Vis or not Vis.DamageNumbers or not Vis.DamageNumbers.Enabled then return end
        pcall(function()
            local part = Instance.new("Part")
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 1
            part.Size = Vector3.one * 0.2
            part.CFrame = CFrame.new(worldPos + Vector3.new(0, 1.5, 0))
            part.Parent = workspace
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 80, 0, 30)
            bb.AlwaysOnTop = true
            bb.Adornee = part
            bb.Parent = dmgFolder
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 18
            lbl.TextStrokeTransparency = 0.3
            lbl.Text = tostring(math.floor(amount + 0.5))
            local col = headshot and (Vis.DamageNumbers.HeadColor or Color3.fromRGB(0, 220, 20))
                or (Vis.DamageNumbers.Color or Color3.fromRGB(255, 170, 0))
            lbl.TextColor3 = col
            lbl.Parent = bb
            task.spawn(function()
                for i = 1, 20 do
                    part.CFrame = part.CFrame + Vector3.new(0, 0.08, 0)
                    lbl.TextTransparency = i / 20
                    lbl.TextStrokeTransparency = 0.3 + i / 25
                    task.wait(0.03)
                end
                bb:Destroy()
                part:Destroy()
            end)
        end)
    end

    -- patch existing health tracker path: when my hit lands
    local oldQueue = queueOrShowHit
    if type(oldQueue) == "function" or true then
        local function enhancedHit(name, dmg)
            dmg = tonumber(dmg) or 0
            if type(addHitLog) == "function" then
                pcall(addHitLog, name, dmg)
            elseif type(queueOrShowHit) == "function" then
                -- avoid recursion - call original body via globals
            end
            pcall(function()
                if getgenv().HitLogEnabled and type(addHitLog) == "function" then
                    addHitLog(name, dmg)
                end
            end)
            local Vis = getgenv().NH_NovhookVis
            local plr = Players:FindFirstChild(name)
            local pos = Vector3.new()
            if plr and plr.Character then
                local h = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                if h then pos = h.Position end
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health <= 0 and getgenv().NH_ShowEliminated then
                    getgenv().NH_ShowEliminated(name)
                end
            end
            if getgenv().NH_ShowDamageNumber then
                getgenv().NH_ShowDamageNumber(pos, dmg, dmg >= 40)
            end
            if getgenv().NH_FlashHitOverlay then
                getgenv().NH_FlashHitOverlay(dmg >= 40)
            end
        end
        -- replace queueOrShowHit used by health tracker
        queueOrShowHit = function(name, dmg)
            dmg = math.floor((tonumber(dmg) or 0) + 0.5)
            if dmg <= 0 then return end
            if getgenv().HitLogEnabled and type(addHitLog) == "function" then
                pcall(addHitLog, name, dmg)
            else
                table.insert(getgenv().NH_HitLogQueue, { name = name, dmg = dmg, t = tick() })
            end
            pcall(function()
                local Vis = getgenv().NH_NovhookVis
                local plr = Players:FindFirstChild(name)
                local pos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 10 or Vector3.zero
                local headshot = dmg >= 45
                if plr and plr.Character then
                    local h = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                    if h then pos = h.Position end
                    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health <= 0 and getgenv().NH_ShowEliminated then
                        getgenv().NH_ShowEliminated(plr.DisplayName or name)
                    end
                end
                if Vis and Vis.DamageNumbers and Vis.DamageNumbers.Enabled and getgenv().NH_ShowDamageNumber then
                    getgenv().NH_ShowDamageNumber(pos, dmg, headshot)
                end
                if Vis and Vis.HitOverlay and Vis.HitOverlay.Enabled and getgenv().NH_FlashHitOverlay then
                    getgenv().NH_FlashHitOverlay(headshot)
                end
            end)
        end
        getgenv().NH_QueueHit = queueOrShowHit
    end
end

-- Bullet Trajectory: 화면 위에 1발=1줄 (Drawing + Beam)
getgenv().BulletTrajectory = getgenv().BulletTrajectory or false
getgenv().BulletTrajLife = getgenv().BulletTrajLife or 0.45
getgenv().BulletTrajColor0 = getgenv().BulletTrajColor0 or Color3.fromRGB(255, 60, 60)
getgenv().BulletTrajColor1 = getgenv().BulletTrajColor1 or Color3.fromRGB(255, 200, 80)

local NH_trajLines = {}
local NH_trajLast = 0

local function NH_trajPush(fromPos, toPos)
    local Vis = getgenv().NH_NovhookVis
    local on = getgenv().BulletTrajectory == true
        or (Vis and Vis.BulletTracers and Vis.BulletTracers.Enabled == true)
    if not on then return end
    local shotAt = tonumber(getgenv().__NH_LastGunShot) or 0
    if (os.clock() - shotAt) > 0.3 then return end
    if typeof(fromPos) ~= "Vector3" or typeof(toPos) ~= "Vector3" then return end
    if (toPos - fromPos).Magnitude < 1 then return end
    if tick() - NH_trajLast < 0.12 then return end
    NH_trajLast = tick()

    -- Combat Visuals / Elisium tracers share this path
    pcall(function()
        local Vis = getgenv().NH_NovhookVis
        if Vis and Vis.BulletTracers and Vis.BulletTracers.Enabled then
            if getgenv().NH_SpawnBulletTracer then
                getgenv().NH_SpawnBulletTracer(fromPos, toPos, true)
            end
        elseif getgenv().BulletTrajectory and getgenv().NH_SpawnBulletTracer then
            getgenv().NH_SpawnBulletTracer(fromPos, toPos, true)
        end
    end)

    local life = tonumber(getgenv().BulletTrajLife) or 0.45
    local c0 = getgenv().BulletTrajColor0 or Color3.fromRGB(255, 60, 60)
    local die = tick() + life

    -- Drawing 라인 (가장 잘 보임)
    local drawn = false
    pcall(function()
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = c0
        line.Transparency = 0
        line.Visible = true
        table.insert(NH_trajLines, {
            die = die,
            kind = "draw",
            line = line,
            from = fromPos,
            to = toPos,
        })
        drawn = true
    end)

    -- Beam 백업
    pcall(function()
        local folder = workspace:FindFirstChild("NH_TrajFolder")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "NH_TrajFolder"
            folder.Parent = workspace
        end
        local p0 = Instance.new("Part")
        p0.Anchored = true
        p0.CanCollide = false
        p0.CanQuery = false
        p0.CanTouch = false
        p0.Transparency = 1
        p0.Size = Vector3.one * 0.05
        p0.CFrame = CFrame.new(fromPos)
        p0.Parent = folder
        local p1 = Instance.new("Part")
        p1.Anchored = true
        p1.CanCollide = false
        p1.CanQuery = false
        p1.CanTouch = false
        p1.Transparency = 1
        p1.Size = Vector3.one * 0.05
        p1.CFrame = CFrame.new(toPos)
        p1.Parent = folder
        local a0 = Instance.new("Attachment", p0)
        local a1 = Instance.new("Attachment", p1)
        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.2
        beam.Width1 = 0.05
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new(
            getgenv().BulletTrajColor0 or Color3.fromRGB(255, 60, 60),
            getgenv().BulletTrajColor1 or Color3.fromRGB(255, 200, 80)
        )
        beam.Transparency = NumberSequence.new(0.1, 0.7)
        beam.Parent = p0
        table.insert(NH_trajLines, {
            die = die,
            kind = "beam",
            p0 = p0,
            p1 = p1,
        })
    end)
end

-- 매 프레임 Drawing 월드→스크린 갱신 + 만료 삭제
RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    local now = tick()
    for i = #NH_trajLines, 1, -1 do
        local t = NH_trajLines[i]
        if now >= t.die then
            if t.kind == "draw" and t.line then
                pcall(function() t.line:Remove() end)
            elseif t.kind == "beam" then
                pcall(function() t.p0:Destroy() end)
                pcall(function() t.p1:Destroy() end)
            end
            table.remove(NH_trajLines, i)
        elseif t.kind == "draw" and t.line and cam then
            local a, oa = cam:WorldToViewportPoint(t.from)
            local b, ob = cam:WorldToViewportPoint(t.to)
            if a.Z > 0 and b.Z > 0 then
                t.line.From = Vector2.new(a.X, a.Y)
                t.line.To = Vector2.new(b.X, b.Y)
                t.line.Visible = true
                local fade = math.clamp((t.die - now) / (tonumber(getgenv().BulletTrajLife) or 0.45), 0, 1)
                t.line.Transparency = 1 - fade
            else
                t.line.Visible = false
            end
        end
    end
end)

function NH_ShowBulletTrajectory(fromPos, toPos)
    NH_trajPush(fromPos, toPos)
end
getgenv().NH_ShowBulletTrajectory = NH_ShowBulletTrajectory

local function NH_getGunMuzzleWorld()
    local origin = nil
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        -- Rivals ViewModel gun muzzle
        for _, m in ipairs(cam:GetChildren()) do
            if m:IsA("Model") or m:IsA("Folder") then
                local n = string.lower(m.Name)
                if n:find("view") or n:find("gun") or n:find("weapon") or n:find("item") or true then
                    for _, d in ipairs(m:GetDescendants()) do
                        local dn = string.lower(d.Name)
                        if (dn:find("muzzle") or dn:find("flash") or dn:find("fire") or dn == "tip" or dn:find("barrel")) then
                            if d:IsA("Attachment") then origin = d.WorldPosition return end
                            if d:IsA("BasePart") then origin = d.Position return end
                        end
                    end
                    local pp = m:IsA("Model") and m.PrimaryPart
                    if pp then origin = pp.Position return end
                end
            end
        end
        -- character tool
        local char = Player.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then
                    for _, d in ipairs(t:GetDescendants()) do
                        local dn = string.lower(d.Name)
                        if dn:find("muzzle") or dn:find("flash") then
                            if d:IsA("Attachment") then origin = d.WorldPosition return end
                            if d:IsA("BasePart") then origin = d.Position return end
                        end
                    end
                    local h = t:FindFirstChild("Handle")
                    if h then origin = h.Position return end
                end
            end
        end
    end)
    return origin
end
getgenv().NH_getGunMuzzleWorld = NH_getGunMuzzleWorld

local function NH_autoTraj()
    local Vis = getgenv().NH_NovhookVis
    local on = getgenv().BulletTrajectory == true
        or (Vis and Vis.BulletTracers and Vis.BulletTracers.Enabled == true)
    if not on then return end
    -- 최근 실제 발사만
    local shotAt = tonumber(getgenv().__NH_LastGunShot) or 0
    if (os.clock() - shotAt) > 0.25 then return end
    -- 카메라/헤드 금지 → 총 머즐만
    local origin = NH_getGunMuzzleWorld()
    if not origin then return end
    local cam = workspace.CurrentCamera
    local char = Player.Character
    if not cam or not char then return end
    local dir = cam.CFrame.LookVector
    local to = origin + dir * 400
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char, cam }
    local hit = workspace:Raycast(origin, dir * 400, params)
    if hit then to = hit.Position end
    pcall(function()
        if not (getgenv().RagebotEnabled or getgenv().MeleeRageBotEnabled or getgenv().ragebotOrKillAura) then return end
        local best, bd = nil, 120
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Player and plr.Character then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local h = plr.Character:FindFirstChild("HitboxHead") or plr.Character:FindFirstChild("Head")
                if hum and h and hum.Health > 0 then
                    local d = (origin - h.Position).Magnitude
                    if d < bd then best, bd = h, d end
                end
            end
        end
        if best then to = best.Position end
    end)
    NH_trajPush(origin, to)
end
getgenv().NH_autoTraj = NH_autoTraj

-- 발사 감지 여러 경로
task.spawn(function()
    local function hookTool(tool)
        if not tool:IsA("Tool") then return end
        if tool:GetAttribute("NH_TrajH") then return end
        tool:SetAttribute("NH_TrajH", true)
        tool.Activated:Connect(function()
            getgenv().__NH_LastGunShot = os.clock()
            task.defer(NH_autoTraj)
        end)
    end
    local function hookChar(char)
        for _, c in ipairs(char:GetChildren()) do hookTool(c) end
        char.ChildAdded:Connect(hookTool)
    end
    if Player.Character then hookChar(Player.Character) end
    Player.CharacterAdded:Connect(hookChar)

    -- Input: PC 좌클릭만 (터치/조이스틱/화면 드래그 제외 → 궤적 스팸 방지)
    local lastClickTraj = 0
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local Vis = getgenv().NH_NovhookVis
        local want = getgenv().BulletTrajectory == true
            or (Vis and Vis.BulletTracers and Vis.BulletTracers.Enabled == true)
        if not want then return end
        -- Touch 완전 제외 (모바일 조이스틱/화면 전환 시 궤적 안 나감)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if os.clock() - lastClickTraj < 0.15 then return end
        lastClickTraj = os.clock()
        -- 총 머즐 있을 때만
        if not NH_getGunMuzzleWorld or not NH_getGunMuzzleWorld() then return end
        getgenv().__NH_LastGunShot = os.clock()
        task.defer(function()
            pcall(NH_autoTraj)
        end)
    end)
end)

-- 레이지 패킷 발사 시 궤도
task.spawn(function()
    while true do
        task.wait(0.05)
        local Vis = getgenv().NH_NovhookVis
        local want = getgenv().BulletTrajectory
            or (Vis and Vis.BulletTracers and Vis.BulletTracers.Enabled)
        if want and (getgenv().MeleeRageBotEnabled or getgenv().ragebotOrKillAura or getgenv().RageBotEnabled) then
            if getgenv().__NH_RageDidShoot then
                getgenv().__NH_RageDidShoot = false
                getgenv().__NH_LastGunShot = os.clock()
                local prev = getgenv().BulletTrajectory
                getgenv().BulletTrajectory = true
                pcall(NH_autoTraj)
                getgenv().BulletTrajectory = prev
            end
        end
    end
end)

getgenv().FlySpeed = 50

local bv, bg, flyConn
-- Fly: PC / Mobile 안정화 (모바일 스틱+UP/DN)
getgenv().FlyEnabled = false
getgenv().FlySpeed = getgenv().FlySpeed or 50
getgenv()._flyMobileUp = false
getgenv()._flyMobileDown = false

local function flyIsMobile()
    return UserInputService.TouchEnabled
end

local function getMobileMoveVector()
    -- PlatformStand여도 스틱 입력 읽기
    local ok, vec = pcall(function()
        local ps = Player:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local mod = require(pm)
            if mod and mod.GetControls then
                local c = mod:GetControls()
                if c and c.GetMoveVector then
                    return c:GetMoveVector()
                end
            end
        end
        return nil
    end)
    if ok and vec and typeof(vec) == "Vector3" and vec.Magnitude > 0.05 then
        return vec
    end
    return nil
end

local function destroyFlyButtons()
    pcall(function()
        local pg = Player:FindFirstChild("PlayerGui")
        local g = pg and pg:FindFirstChild("NovhookPremiumFlyButtons")
        if g then g:Destroy() end
    end)
end

local function createFlyButtons()
    destroyFlyButtons()
    if not flyIsMobile() then return end
    local pg = Player:FindFirstChild("PlayerGui") or Player:WaitForChild("PlayerGui", 5)
    if not pg then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NovhookPremiumFlyButtons"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 5
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true -- fly ON일 때만 생성됨
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protectgui then protectgui(gui) end
    end)
    gui.Parent = pg

    local function mkBtn(text, anchor, color, flagName)
        local b = Instance.new("TextButton")
        b.Name = flagName
        b.Size = UDim2.new(0, 88, 0, 88)
        b.AnchorPoint = Vector2.new(1, 1)
        b.Position = anchor
        b.BackgroundColor3 = color
        b.BackgroundTransparency = 0.25
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 28
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = true
        b.Parent = gui
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 16)
        local stroke = Instance.new("UIStroke", b)
        stroke.Thickness = 2
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Transparency = 0.5

        local function down()
            getgenv()[flagName] = true
            b.BackgroundTransparency = 0.05
        end
        local function up()
            getgenv()[flagName] = false
            b.BackgroundTransparency = 0.25
        end
                b.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                down()
            end
        end)
        b.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                up()
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                -- 터치 끊기면 버튼 상태 리셋은 개별 플래그로 유지
            end
        end)
        return b
    end

    -- 우측 하단 큰 버튼
    mkBtn("▲", UDim2.new(1, -24, 1, -220), Color3.fromRGB(30, 140, 255), "_flyMobileUp")
    mkBtn("▼", UDim2.new(1, -24, 1, -110), Color3.fromRGB(220, 60, 60), "_flyMobileDown")
end

local function flyCleanup(hrp, hum)
    if getgenv()._flyConn then
        pcall(function() getgenv()._flyConn:Disconnect() end)
        getgenv()._flyConn = nil
    end
    getgenv()._flyMobileUp = false
    getgenv()._flyMobileDown = false
    destroyFlyButtons()
    if hrp then
        for _, n in ipairs({ "FlyBV", "FlyBG", "FlyLV", "HoNyangFlyBV", "HoNyangFlyBG", "DEvFlyBV", "DEvFlyBG" }) do
            local o = hrp:FindFirstChild(n)
            if o then pcall(function() o:Destroy() end) end
        end
    end
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
end

local function flyStart()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    flyCleanup(hrp, hum)
    if not getgenv().FlyEnabled then return end
    if not hrp then return end

    local mobile = flyIsMobile()
    if mobile then
        createFlyButtons()
        -- 모바일: PlatformStand 끄면 스틱 유지, 중력만 상쇄
        if hum then
            hum.PlatformStand = false
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            pcall(function() hum.JumpHeight = 0 end)
        end
    else
        if hum then hum.PlatformStand = true end
    end

    getgenv()._flyConn = RunService.RenderStepped:Connect(function(dt)
        if not getgenv().FlyEnabled then return end
        local c = Player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not r then return end

        local speed = tonumber(getgenv().FlySpeed) or 50
        local cam = workspace.CurrentCamera
        if not cam then return end
        local cf = cam.CFrame
        local dir = Vector3.zero
        local y = 0

        if mobile then
            -- 1) PlayerModule 스틱
            local mv = getMobileMoveVector()
            if mv then
                local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
                local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
                if look.Magnitude > 0.01 then look = look.Unit end
                if right.Magnitude > 0.01 then right = right.Unit end
                dir = dir + look * (-mv.Z) + right * mv.X
            elseif h and h.MoveDirection.Magnitude > 0.05 then
                dir = dir + Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z)
            end
            if getgenv()._flyMobileUp then y = y + 1 end
            if getgenv()._flyMobileDown then y = y - 1 end
        else
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then y = y + 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                y = y - 1
            end
        end

        local move = dir
        if move.Magnitude > 0.05 then
            move = Vector3.new(move.X, 0, move.Z)
            if move.Magnitude > 0.05 then move = move.Unit * speed else move = Vector3.zero end
        else
            move = Vector3.zero
        end
        move = move + Vector3.new(0, y * speed, 0)

        -- 위치 기반 이동 (모바일에서 가장 안정)
        if move.Magnitude > 0.05 then
            r.CFrame = r.CFrame + move * math.clamp(dt, 0, 0.05)
            r.AssemblyLinearVelocity = Vector3.new(move.X, move.Y, move.Z)
        else
            -- 공중 정지 (중력 상쇄)
            r.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

Player.CharacterAdded:Connect(function(char)
    task.delay(0.5, function()
        if getgenv().FlyEnabled then
            flyStart()
        end
    end)
end)

MoveGroup:AddToggle('FlyToggle', {
    Text = 'Fly (PC / Mobile)',
    Default = false,
    Callback = function(Value)
        getgenv().FlyEnabled = Value
        if Value then
            flyStart()
            
        else
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            flyCleanup(hrp, hum)
            if hum then
                pcall(function()
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                end)
            end
        end
    end
})

MoveGroup:AddSlider('FlySpeedSlider', {
    Text = 'Fly Speed',
    Default = 50,
    Min = 1,
    Max = 1000,
    Rounding = 0,
    Callback = function(Value)
        getgenv().FlySpeed = Value
    end
})

MoveGroup:AddToggle('NoclipToggle', {
    Text = 'Noclip',
    Default = false,
    Callback = function(Value)
        getgenv().NoclipEnabled = Value
        task.spawn(function()
             while getgenv().NoclipEnabled do
                RunService.Stepped:Wait()
                local char = Player.Character
                if char then
                   for _, v in pairs(char:GetDescendants()) do
                      if v:IsA("BasePart") then v.CanCollide = false end
                   end
                end
                task.wait(0.5)
             end
        end)
    end
})

MoveGroup:AddToggle('InfiniteJumpToggle', {
    Text = 'Infinite Jump',
    Default = false,
    Callback = function(Value)
        getgenv().InfiniteJumpEnabled = Value
    end
})

UserInputService.JumpRequest:Connect(function()
    if getgenv().InfiniteJumpEnabled then
        local char = Player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://92281817840531"


-- Arcade Auto Farm (FFA / TDM / Gun Game)
getgenv().ArcadeFarm = false
FarmGroup:AddToggle('ArcadeFarmToggle', {
    Text = 'Arcade Auto Farm',
    Default = false,
    Callback = function(Value)
        getgenv().ArcadeFarm = Value
        if Value then
            getgenv().MeleeRageBotEnabled = true
            if getgenv().Config then getgenv().Config.Enabled = true end
            pcall(function()
                if Toggles and Toggles.RageBotToggle then
                    Toggles.RageBotToggle:SetValue(true)
                end
            end)
            
        else
            
        end
    end
})
FarmGroup:AddToggle('ArcadeFarmVoidToggle', {
    Text = 'Farm + Void Spam',
    Default = false,
    Callback = function(Value)
        getgenv().ArcadeFarmVoid = Value
        if Value and VoidSpamSettings then
            VoidSpamSettings.on = true
            pcall(function()
                if Toggles and Toggles.VoidSpamEnable then
                    Toggles.VoidSpamEnable:SetValue(true)
                end
            end)
        end
    end
})
FarmGroup:AddLabel('아케이드(FFA/TDM)에서 사용')
FarmGroup:AddLabel('레이지로 전원 타격 루프')

task.spawn(function()
    while true do
        task.wait(1)
        if not getgenv().ArcadeFarm then continue end
        -- 레이지 강제 유지
        getgenv().MeleeRageBotEnabled = true
        if getgenv().Config then getgenv().Config.Enabled = true end
        if getgenv().ArcadeFarmVoid and VoidSpamSettings then
            VoidSpamSettings.on = true
        end
        -- 죽으면 대기 / 캐릭터 복구 후 계속
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            task.wait(1)
        end
    end
end)


-- Emotes (catalog + custom)
local NH_EMOTES = {
    ["Bodybuilder"] = "3994130516",
    ["Crawling in a Circle"] = "116935126100338",
    ["Dolphin Dance"] = "5938365243",
    ["Dance"] = "507771019",
    ["Dance Break"] = "94258912028011",
    ["French Confidence"] = "116968182519797",
    ["Floss"] = "72174079036035",
    ["Frosty Flair"] = "10214406616",
    ["Full Wiggle"] = "86520127496722",
    ["Ghost Floating"] = "75911227509248",
    ["Gun"] = "81100102810594",
    ["Gangnam Style"] = "78801539668900",
    ["Hip Bounce"] = "123602332785269",
    ["Hype Dance"] = "93079641847306",
    ["Kicking Feet"] = "109814083870185",
    ["Line Dance"] = "4049646104",
    ["Lay Floating"] = "126579240140537",
    ["Let's Drive"] = "17360720445",
    ["Long Legs"] = "82416741608012",
    ["Rock Out"] = "18225077553",
    ["Samba"] = "6869813008",
    ["Still Standing"] = "11435177473",
    ["Spiral"] = "81926730031709",
    ["Solar System"] = "118314972618293",
    ["Twirl"] = "3716633898",
    ["Take Me Under"] = "6797938823",
    ["The Worm"] = "99563207397301",
    ["Take the L"] = "110664723286332",
    ["Zesty"] = "102901317133934",
}
local NH_EMOTE_LIST = {
    "Off", "Custom",
    "Bodybuilder", "Crawling in a Circle", "Dolphin Dance", "Dance",
    "Dance Break", "French Confidence", "Floss", "Frosty Flair", "Full Wiggle",
    "Ghost Floating", "Gun", "Gangnam Style", "Hip Bounce", "Hype Dance",
    "Kicking Feet", "Line Dance", "Lay Floating", "Let's Drive", "Long Legs",
    "Rock Out", "Samba", "Still Standing", "Spiral", "Solar System", "Twirl",
    "Take Me Under", "The Worm", "Take the L", "Zesty",
}
getgenv().NH_EmoteName = getgenv().NH_EmoteName or "Off"
getgenv().NH_EmoteCustomId = getgenv().NH_EmoteCustomId or "92281817840531"

local function NH_StopEmote()
    pcall(function()
        if getgenv()._novEmote then
            getgenv()._novEmote:Stop(0.1)
            getgenv()._novEmote:Destroy()
            getgenv()._novEmote = nil
        end
    end)
end

local function NH_PlayEmote(id)
    NH_StopEmote()
    id = tostring(id or ""):match("%d+")
    if not id then return end
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    -- catalog emote
    local desc = hum:FindFirstChildOfClass("HumanoidDescription")
    if desc and animator then
        local captured
        local conn
        conn = animator.AnimationPlayed:Connect(function(track)
            captured = track
        end)
        local ok = pcall(function()
            pcall(desc.RemoveEmote, desc, "NovHookEmote")
            desc:AddEmote("NovHookEmote", tonumber(id))
            hum:PlayEmote("NovHookEmote")
        end)
        local t0 = os.clock()
        while ok and not captured and os.clock() - t0 < 1.5 do
            task.wait()
        end
        pcall(function() conn:Disconnect() end)
        if captured then
            getgenv()._novEmote = captured
            return
        end
    end
    -- fallback Animation
    pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. id
        local track = hum:LoadAnimation(a)
        track.Looped = true
        track:Play(0.1, 1, 1)
        getgenv()._novEmote = track
        if animation then animation.AnimationId = a.AnimationId end
    end)
end

EmotesGroup:AddDropdown('EmoteSelect', {
    Values = NH_EMOTE_LIST,
    Default = 1,
    Multi = false,
    Text = 'Emote',
    Callback = function(Value)
        getgenv().NH_EmoteName = tostring(Value)
        if Value == "Off" then
            getgenv().CustomEmoteEnabled = false
            NH_StopEmote()
            return
        end
        local id
        if Value == "Custom" then
            id = getgenv().NH_EmoteCustomId
        else
            id = NH_EMOTES[Value]
        end
        if id then
            getgenv().CustomEmoteEnabled = true
            NH_PlayEmote(id)
        end
    end
})

EmotesGroup:AddInput('EmoteIdInput', {
    Default = '92281817840531',
    Numeric = false,
    Finished = true,
    Text = 'Custom Emote Id',
    Callback = function(Value)
        local id = tostring(Value):match("%d+") or tostring(Value)
        getgenv().NH_EmoteCustomId = id
        if animation then
            animation.AnimationId = "rbxassetid://" .. id
        end
        if getgenv().NH_EmoteName == "Custom" and getgenv().CustomEmoteEnabled then
            NH_PlayEmote(id)
        end
    end
})

EmotesGroup:AddToggle('CustomEmoteToggle', {
    Text = 'Play Emote',
    Default = false,
    Callback = function(Value)
        getgenv().CustomEmoteEnabled = Value
        if not Value then
            NH_StopEmote()
            return
        end
        local name = getgenv().NH_EmoteName or "Off"
        if name == "Off" then return end
        local id = (name == "Custom") and getgenv().NH_EmoteCustomId or NH_EMOTES[name]
        if id then NH_PlayEmote(id) end
    end
})

Player.CharacterAdded:Connect(function()
    task.wait(1)
    if getgenv().CustomEmoteEnabled then
        local name = getgenv().NH_EmoteName or "Off"
        if name == "Off" then return end
        local id = (name == "Custom") and getgenv().NH_EmoteCustomId or NH_EMOTES[name]
        if id then NH_PlayEmote(id) end
    end
end)


local function setSkybox(skyId)
    local existingSky = Lighting:FindFirstChild("NovHook Sky")
    if existingSky then existingSky:Destroy() end
    local sky = Instance.new("Sky")
    sky.Name = "Nov Sky"
    sky.SkyboxBk = skyId sky.SkyboxDn = skyId sky.SkyboxFt = skyId
    sky.SkyboxLf = skyId sky.SkyboxRt = skyId sky.SkyboxUp = skyId
    sky.Parent = Lighting
end

local function removeSkybox()
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Sky") then c:Destroy() end
    end
end

local function clearSky()
    for _, n in ipairs({ "NovHook Sky", "Nov Sky", "DEvSky" }) do
        local e = Lighting:FindFirstChild(n)
        if e then e:Destroy() end
    end
end
getgenv().NovHookSkyId = getgenv().NovHookSkyId or nil

local function applySky(skyId, save)
    if save ~= false then
        getgenv().NovHookSkyId = skyId
    end
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Sky") then c:Destroy() end
    end
    if not skyId then return end
    local sky = Instance.new("Sky")
    sky.Name = "NovHook Sky"
    sky.SkyboxBk = skyId
    sky.SkyboxDn = skyId
    sky.SkyboxFt = skyId
    sky.SkyboxLf = skyId
    sky.SkyboxRt = skyId
    sky.SkyboxUp = skyId
    sky.CelestialBodiesShown = true
    sky.Parent = Lighting
end

-- 다음 판 / Lighting 리셋 후에도 스카이박스 유지
task.spawn(function()
    while true do
        task.wait(3)
        local want = getgenv().NovHookSkyId
        if want then
            local cur = Lighting:FindFirstChild("NovHook Sky")
            if not cur or not cur:IsA("Sky") then
                applySky(want, false)
            end
        end
    end
end)
Lighting.ChildRemoved:Connect(function(child)
    if child.Name == "NovHook Sky" and getgenv().NovHookSkyId then
        task.defer(function()
            if getgenv().NovHookSkyId and not Lighting:FindFirstChild("NovHook Sky") then
                applySky(getgenv().NovHookSkyId, false)
            end
        end)
    end
end)
SkyboxGroup:AddDropdown('SkyboxSelect', {
    Values = { 'Off', 'Galaxy', 'Nebula', 'Night', 'Pink', 'Cloudy', 'Sunset', 'Space' },
    Default = 1,
    Multi = false,
    Text = 'Skybox',
    Callback = function(Value)
        local map = {
            Off = nil,
            Galaxy = "rbxassetid://159454299",
            Nebula = "rbxassetid://159454286",
            Night = "rbxassetid://12064107",
            Pink = "rbxassetid://271042516",
            Cloudy = "rbxassetid://591058823",
            Sunset = "rbxassetid://150739273",
            Space = "rbxassetid://159454286",
        }
        local id = map[tostring(Value)]
        if tostring(Value) == "Off" then
            getgenv().NovHookSkyId = nil
            applySky(nil)
        else
            applySky(id, true)
        end
    end
})

SkyboxGroup:AddToggle('LockTimeToggle', {
    Text = 'Lock Custom Time',
    Default = false,
    Callback = function(Value)
        getgenv().LockTimeEnabled = Value
    end
})

SkyboxGroup:AddSlider('ClockTimeSlider', {
    Text = 'Clock Time (0 - 24)',
    Default = 12,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Callback = function(Value)
        getgenv().CustomClockTime = Value
    end
})

RunService.RenderStepped:Connect(function()
    if getgenv().LockTimeEnabled and getgenv().CustomClockTime then
        Lighting.ClockTime = getgenv().CustomClockTime
    end
end)


-- Kill/Hit sounds handled in trackPlayerHealth (my damage only)
-- UI toggles below still control getgenv().KillSoundEnabled / HitSoundEnabled

MenuGroup:AddLabel('Config Folder: workspace/NovHook')
MenuGroup:AddButton('Unload', function() 
    FOVGui:Destroy()
    SilentFOVGui:Destroy()
    CustomUIGui:Destroy()
    Library:Unload() 
end)

Library:OnUnload(function()
    FOVGui:Destroy()
    SilentFOVGui:Destroy()
    CustomUIGui:Destroy()
    Library.Unloaded = true
end)

pcall(function() ThemeManager:ApplyToTab(Tabs['UI Settings']) end)
pcall(function() SaveManager:BuildConfigSection(Tabs['UI Settings']) end)










































-- =====================================================================
-- [RAGE] head shootPos ONLY — never camera / never view
-- desync body + encodeShot from head+0.12
-- =====================================================================
getgenv().__NH_UseSleepyCore = true
getgenv().HeadStuds = getgenv().HeadStuds or 3
getgenv().DesyncDist = getgenv().DesyncDist or 3

task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local RS = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer

    local Utility, EnumLibrary, FC, UseItem
    local lastShot, lastBootAt, lastFireOkAt = 0, 0, 0
    local clientCF, clientLV, clientAV
    local cachedOID, cachedOIDAt = nil, 0

    local function req(x)
        if not x then return nil end
        local ok, m = pcall(require, x)
        return ok and m or nil
    end

    local function boot(force)
        if not force and UseItem and FC and (os.clock() - lastBootAt) < 0.2 then
            return true
        end
        lastBootAt = os.clock()
        pcall(function()
            local M = RS:FindFirstChild("Modules")
            Utility = req(M and M:FindFirstChild("Utility")) or Utility
            EnumLibrary = req(M and M:FindFirstChild("EnumLibrary")) or EnumLibrary
            local ps = LP:FindFirstChild("PlayerScripts")
            local c = ps and ps:FindFirstChild("Controllers")
            FC = req(c and c:FindFirstChild("FighterController")) or FC
            local a = RS:FindFirstChild("Remotes")
            a = a and a:FindFirstChild("Replication")
            a = a and a:FindFirstChild("Fighter")
            UseItem = (a and a:FindFirstChild("UseItem")) or UseItem
            if EnumLibrary and EnumLibrary.WaitForEnumBuilder then
                pcall(function() EnumLibrary:WaitForEnumBuilder() end)
            end
        end)
        return UseItem ~= nil
    end
    boot(true)

    pcall(function()
        LP.CharacterAdded:Connect(function()
            cachedOID, cachedOIDAt = nil, 0
            lastFireOkAt = 0
            UseItem, FC = nil, nil
            task.defer(function() boot(true) end)
        end)
    end)

    -- 워치독: 레이지 켜져 있는데 발사가 멈추면 강제 재연결
    task.spawn(function()
        while true do
            task.wait(0.35)
            local rageOn = getgenv().MeleeRageBotEnabled or getgenv().HVHRageEnabled
                or getgenv().KnifeModeEnabled or getgenv().ragebotOrKillAura
            if not rageOn then continue end
            if lastFireOkAt == 0 or (os.clock() - lastFireOkAt) > 1.0 then
                cachedOID, cachedOIDAt = nil, 0
                UseItem, FC = nil, nil
                boot(true)
            end
        end
    end)

    local function hrp()
        local c = LP.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function setVel(part, lv, av)
        if not part then return end
        if typeof(lv) == "Vector3" then
            part.AssemblyLinearVelocity = lv
            pcall(function() part.Velocity = lv end)
        end
        if typeof(av) == "Vector3" then
            part.AssemblyAngularVelocity = av
            pcall(function() part.RotVelocity = av end)
        end
    end
    local function team(p)
        if not p or p == LP then return true end
        local ok, r = pcall(function()
            local a, b = p:GetAttribute("TeamID"), LP:GetAttribute("TeamID")
            if a ~= nil and b ~= nil then return a == b end
            if LP.Team and p.Team and LP.Team == p.Team then
                return LP.Team.Name ~= "Neutral"
            end
            return false
        end)
        return ok and r
    end
    local function isKnife()
        local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if not t then return false end
        local n = string.lower(t.Name)
        return n:find("knife") or n:find("melee") or n:find("dagger") or n:find("blade")
    end
    local function onUniversal()
        if NH_isLobby and NH_isLobby() then return false end
        return getgenv().MeleeRageBotEnabled == true
    end
    local function onHVH()
        if NH_isLobby and NH_isLobby() then return false end
        return getgenv().HVHRageEnabled == true or getgenv().ragebotOrKillAura == true
    end
    local function onKnifeMode()
        if NH_isLobby and NH_isLobby() then return false end
        return getgenv().KnifeModeEnabled == true
    end
    local function on()
        return onUniversal() or onHVH() or onKnifeMode()
    end

    local function targetParts()
        local me = hrp()
        if not me then return nil, nil end
        if getgenv().GhostEnabled == true then
            local gp, gh = getgenv().__NH_GhostTarget, getgenv().__NH_GhostAimPart
            if gp and gh and gh.Parent and not (NH_isImmune and NH_isImmune(gp)) then
                local r = gp.Character and gp.Character:FindFirstChild("HumanoidRootPart")
                if r then return gh, r end
            end
        end
        local bestH, bestR, bd = nil, nil, 1e9
        for _, p in ipairs(Players:GetPlayers()) do
            if not team(p) and p.Character and not (NH_isImmune and NH_isImmune(p)) then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if hum and r and hum.Health > 0 then
                    local d = (me.Position - r.Position).Magnitude
                    if d < bd and d < 4000 then
                        local h = p.Character:FindFirstChild("HitboxHead")
                            or p.Character:FindFirstChild("HitboxHeadSmall")
                            or p.Character:FindFirstChild("Head")
                        if h then bestH, bestR, bd = h, r, d end
                    end
                end
            end
        end
        return bestH, bestR
    end

    local function fireEnum(name)
        local se
        pcall(function()
            if EnumLibrary then se = EnumLibrary:ToEnum(name) end
        end)
        return se
    end

    local function oid()
        boot(false)
        local id
        pcall(function()
            local lf = FC and FC.LocalFighter
            local item = lf and (lf.EquippedItem or lf.Item)
            if item then
                if type(item.Get) == "function" then
                    id = item:Get("ObjectID") or item:Get("Id") or item:Get("ObjectId")
                end
                id = id or item.ObjectID or item.ObjectId or item.Id
                if not id and type(item.Data) == "table" then
                    id = item.Data.ObjectID or item.Data.Id
                end
            end
        end)
        if not id then
            pcall(function()
                local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if t then
                    id = t:GetAttribute("ObjectID") or t:GetAttribute("Id")
                end
            end)
        end
        if id then
            cachedOID, cachedOIDAt = id, os.clock()
            return id
        end
        if cachedOID and (os.clock() - cachedOIDAt) < 1.25 then
            return cachedOID
        end
        return nil
    end

    local function packet(from, to, part)
        if not part or typeof(from) ~= "Vector3" then return nil end
        if typeof(to) ~= "Vector3" then to = part.Position end
        if Utility and type(Utility.EncodeCFrame) == "function" then
            local ok, data = pcall(function()
                local e = Utility:EncodeCFrame(CFrame.lookAt(from, to))
                local hit = Utility:EncodeCFrame(CFrame.new(0.43, 0.25, 0.42))
                return {
                    [utf8.char(1)] = {
                        [utf8.char(0)] = e, [utf8.char(1)] = e,
                        [utf8.char(2)] = part, [utf8.char(3)] = hit,
                    },
                }
            end)
            if ok and data then return data end
        end
        local cf = CFrame.lookAt(from, to)
        local rx, ry, rz = cf:ToOrientation()
        local pos = {
            [utf8.char(0)] = from.X, [utf8.char(1)] = from.Y, [utf8.char(2)] = from.Z,
            [utf8.char(3)] = rx, [utf8.char(4)] = ry, [utf8.char(5)] = rz,
        }
        local rel = part.CFrame:ToObjectSpace(CFrame.new(to))
        local rrx, rry, rrz = rel:ToOrientation()
        return {
            [utf8.char(1)] = {
                [utf8.char(0)] = pos, [utf8.char(1)] = pos, [utf8.char(2)] = part,
                [utf8.char(3)] = {
                    [utf8.char(0)] = rel.X, [utf8.char(1)] = rel.Y, [utf8.char(2)] = rel.Z,
                    [utf8.char(3)] = rrx, [utf8.char(4)] = rry, [utf8.char(5)] = rrz,
                },
            },
        }
    end

    local function fireUse(id, se, data)
        if not UseItem then boot(true) end
        if not UseItem or not id or not data then return false end
        local ok = false
        pcall(function()
            if se ~= nil then UseItem:FireServer(id, se, data, nil) ok = true end
        end)
        if not ok then
            pcall(function() UseItem:FireServer(id, "StartShooting", data, nil) ok = true end)
        end
        if not ok then
            pcall(function() UseItem:FireServer(id, se or "StartShooting", data) ok = true end)
        end
        if ok then
            lastFireOkAt = os.clock()
            getgenv().__NH_RageDidShoot = true
        else
            cachedOID, UseItem = nil, nil
            lastBootAt = 0
        end
        return ok
    end

    local function remoteHead(head)
        if not head or not head.Parent then return end
        local me = hrp()
        if not me then return end
        -- 면역이면 패킷 스킵 (타겟 선정에서 대부분 걸러짐)
        pcall(function()
            local plr = Players:GetPlayerFromCharacter(head.Parent)
            if plr and NH_isImmune and NH_isImmune(plr) then
                head = nil
            end
        end)
        if not head then return end
        boot(false)
        local id = oid() or (boot(true) and oid())
        local se = fireEnum("StartShooting")
        local char = head.Parent
        local headPart = char:FindFirstChild("HitboxHead")
            or char:FindFirstChild("HitboxHeadSmall")
            or char:FindFirstChild("Head")
            or head
        local from, headPos = me.Position, headPart.Position
        local fired = false
        if UseItem and id then
            for _, off in ipairs({
                Vector3.zero, Vector3.new(0, 0.05, 0), Vector3.new(0, 0.1, 0),
                Vector3.new(0.04, 0.06, 0), Vector3.new(-0.04, 0.06, 0),
            }) do
                local data = packet(from, headPos + off, headPart)
                if data and fireUse(id, se, data) then fired = true end
            end
        end
        pcall(function()
            local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if t then t:Activate() end
        end)
        if fired then lastFireOkAt = os.clock() end
    end

    local function remoteBackstab(head, root)
        boot(false)
        if not root then return end
        local id = oid() or (boot(true) and oid())
        local me = hrp()
        if not id or not me or not UseItem then return end
        local hitPart = head or root
        local data = packet(me.Position, (head and head.Position or root.Position + Vector3.new(0, 1, 0)), hitPart)
        if not data then return end
        local fired = false
        for _, name in ipairs({"AltFire", "SecondaryFire", "RightClick", "MeleeAttack", "Backstab"}) do
            local e = fireEnum(name)
            if e ~= nil then
                pcall(function() UseItem:FireServer(id, e, data, nil) fired = true end)
            end
        end
        if not fired then
            fireUse(id, fireEnum("StartShooting"), data)
        else
            lastFireOkAt = os.clock()
        end
    end


    pcall(function() RunService:UnbindFromRenderStep("NH_RageDesync") end)

    -- 디싱크: 서버만 머리 위 고정, 클라는 제자리 (위치 이상 없음)
    RunService:BindToRenderStep("NH_RageDesync", Enum.RenderPriority.First.Value, function()
        if not clientCF then return end
        local me = hrp()
        if me then
            me.CFrame = clientCF
            setVel(me, clientLV, clientAV)
        end
        clientCF, clientLV, clientAV = nil, nil, nil
    end)

    RunService.Heartbeat:Connect(function()
        if not on() or getgenv().__NH_StopRage then
            if clientCF then
                local me = hrp()
                if me then
                    me.CFrame = clientCF
                    setVel(me, clientLV, clientAV)
                end
            end
            clientCF, clientLV, clientAV = nil, nil, nil
            getgenv().__NH_StopRage = false
            return
        end

        local me = hrp()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if not me or not hum or hum.Health <= 0 then return end

        local head, root = targetParts()
        if not head or not root then return end

        -- 내 실제 위치 스냅샷
        local bodyCF = me.CFrame
        local bodyLV = me.AssemblyLinearVelocity
        local bodyAV = me.AssemblyAngularVelocity
        pcall(function()
            if typeof(me.Velocity) == "Vector3" then bodyLV = me.Velocity end
            if typeof(me.RotVelocity) == "Vector3" then bodyAV = me.RotVelocity end
        end)
        if typeof(bodyLV) ~= "Vector3" then bodyLV = Vector3.zero end
        if typeof(bodyAV) ~= "Vector3" then bodyAV = Vector3.zero end

        local knifeMode = onKnifeMode()
        local under = getgenv().UndergroundEnabled == true
            or getgenv().FakePositionEnabled == true
        local hvh = onHVH()

        -- ===== 서버 TP 위치 (단순·고정) =====
        if knifeMode then
            -- 등 뒤
            local look = root.CFrame.LookVector
            local pos = root.Position - look * 3.2 + Vector3.new(0, 0.5, 0)
            me.CFrame = CFrame.lookAt(pos, head.Position)
        elseif under then
            -- 땅밑: 머리 XZ 그대로, Y만 아래
            local depth = math.clamp(tonumber(getgenv().UndergroundDepth) or 20, 2, 25)
            local y = head.Position.Y - depth
            pcall(function()
                local f = workspace.FallenPartsDestroyHeight
                if typeof(f) == "number" and y < f + 55 then
                    y = f + 55
                end
            end)
            local pos = Vector3.new(head.Position.X, y, head.Position.Z)
            me.CFrame = CFrame.lookAt(pos, head.Position)
            clientCF = nil -- 언더: 디싱크 복원 없음
        else
            -- 기본: 머리 바로 위 N 스터드 (rot 섞지 않음)
            local studs = math.clamp(
                tonumber(getgenv().HeadStuds) or tonumber(getgenv().DesyncDist) or 3,
                1, 12
            )
            if hvh then studs = math.max(studs, 3) end
            local pos = head.Position + Vector3.new(0, studs, 0)
            -- GHOST Execute일 때만 힌트 사용 (기본 레이지는 머리 위 고정)
            if getgenv().GhostEnabled and getgenv().GhostExecute ~= false then
                local hint = getgenv().__NH_GhostServerHint
                if typeof(hint) == "Vector3" and (hint - head.Position).Magnitude < 40 then
                    pos = hint
                end
            end
            me.CFrame = CFrame.lookAt(pos, head.Position)
        end

        setVel(me, bodyLV, bodyAV)

        if not under then
            clientCF, clientLV, clientAV = bodyCF, bodyLV, bodyAV
        end

        -- 발사 직전: 돔 있으면 이번 프레임 공격 스킵 (풀린 뒤에만 타격)
        local targetPlr
        pcall(function()
            targetPlr = Players:GetPlayerFromCharacter(head.Parent)
        end)
        if targetPlr and NH_isImmune(targetPlr) then
            return
        end
        if targetPlr and targetPlr.Character and NH_hasDome and NH_hasDome(targetPlr.Character) then
            return
        end

        local gap = knifeMode and 0.03
            or (hvh and (getgenv().WeaponSpeedEnabled and 0.01 or 0.015) or 0.04)
        if tick() - lastShot >= gap then
            lastShot = tick()
            -- 한 번 더 확인 (돔 생기는 프레임 방지)
            if targetPlr and NH_isImmune(targetPlr) then
                return
            end
            if knifeMode then
                remoteBackstab(head, root)
                remoteBackstab(head, root)
            else
                remoteHead(head)
                remoteHead(head)
                if hvh then remoteHead(head) end
            end
        end
    end)
end)



task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer

    getgenv().VoidSpamCFG = getgenv().VoidSpamCFG or {
        hideTime = 0.45,
        attackTime = 0.03,
        voidRangeX = 12000,
        voidRangeY = 4000,
        voidRangeZ = 12000,
        voidBaseY = -15000,
    }

    local S = {
        on = false,
        mode = "hide",
        modeT = 0,
        target = nil,
        savedCF = CFrame.identity,
        savedLV = Vector3.zero,
        savedAV = Vector3.zero,
        hb = nil,
        lastVoid = 0,
        phase = 0,
    }

    local function CFG()
        local c = getgenv().VoidSpamCFG or {}
        if type(VoidSpamSettings) == "table" then
            if VoidSpamSettings.voidHideTime then c.hideTime = VoidSpamSettings.voidHideTime end
            if VoidSpamSettings.attackTime then c.attackTime = VoidSpamSettings.attackTime end
            if VoidSpamSettings.voidRange then
                c.voidRangeX = VoidSpamSettings.voidRange
                c.voidRangeZ = VoidSpamSettings.voidRange
            end
            if VoidSpamSettings.voidRangeY then c.voidRangeY = VoidSpamSettings.voidRangeY end
            if VoidSpamSettings.voidBaseY then c.voidBaseY = VoidSpamSettings.voidBaseY end
        end
        -- 생존 기본: hide >= attack
        c.hideTime = math.clamp(tonumber(c.hideTime) or 0.25, 0.01, 1)
        c.attackTime = math.clamp(tonumber(c.attackTime) or 0.03, 0.01, 1)
        c.voidRangeX = math.clamp(tonumber(c.voidRangeX) or 12000, 50, 500000)
        c.voidRangeY = math.clamp(tonumber(c.voidRangeY) or 4000, 50, 500000)
        c.voidRangeZ = math.clamp(tonumber(c.voidRangeZ) or 12000, 50, 500000)
        c.voidBaseY = tonumber(c.voidBaseY) or -15000
        getgenv().VoidSpamCFG = c
        return c
    end

    local function voidOn()
        if NH_isLobby() then return false end
        if getgenv().VoidSpamEnabled == true then return true end
        if type(VoidSpamSettings) == "table" and VoidSpamSettings.on then return true end
        return false
    end

    local function HRP()
        return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    end

    local function isAlive(p)
        if not p or not p.Character then return false end
        local hum = p.Character:FindFirstChildWhichIsA("Humanoid")
        return hum and hum.Health > 0
    end

    local function isTeam(p)
        if not p or p == LP then return true end
        local ok, r = pcall(function()
            local a, b = p:GetAttribute("TeamID"), LP:GetAttribute("TeamID")
            if a ~= nil and b ~= nil then return a == b end
            if LP.Team and p.Team and LP.Team == p.Team then
                return LP.Team.Name ~= "Neutral"
            end
            return false
        end)
        return ok and r
    end

    local function nearest()
        local me = HRP()
        if not me then return nil end
        local best, bd = nil, 9e9
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and not isTeam(p) and isAlive(p) then
                local th = p.Character:FindFirstChild("HumanoidRootPart")
                if th then
                    local d = (me.Position - th.Position).Magnitude
                    if d < bd then bd, best = d, p end
                end
            end
        end
        return best
    end

    local function doVoid(hrp)
        local c = CFG()
        S.phase = S.phase + 1
        local base = hrp.Position
        if S.target and isAlive(S.target) then
            local th = S.target.Character:FindFirstChild("HumanoidRootPart")
            if th then base = th.Position end
        end
        -- 하늘 랜덤 TP + 공허 비행 + XYZ 흔들기 (Z 기본 ON)
        local shakeX = getgenv().VoidShakeX ~= false
        local shakeY = getgenv().VoidShakeY ~= false
        local shakeZ = getgenv().VoidShakeZ ~= false
        local skyFly = getgenv().VoidSkyFly ~= false
        local dirs = {
            {1,1},{-1,1},{1,-1},{-1,-1},
            {1,0},{-1,0},{0,1},{0,-1},
            {0.7,0.7},{-0.7,0.7},{0.7,-0.7},{-0.7,-0.7},
            {0.3,0.9},{-0.3,0.9},{0.9,0.3},{-0.9,-0.3}
        }
        local d = dirs[(S.phase % #dirs) + 1]
        local chaos = 1.8 + (math.random() * 3.2)
        local rx = base.X + d[1] * (c.voidRangeX * (0.3 + math.random() * 0.95)) * chaos
        local rz = base.Z + d[2] * (c.voidRangeZ * (0.3 + math.random() * 0.95)) * chaos
        local ry
        if skyFly then
            local skyY = 60 + math.random() * 420 + math.sin(os.clock() * 22) * 90
            local deepY = c.voidBaseY + (math.random() - 0.5) * 2 * c.voidRangeY * 0.7
            -- 3틱 중 2는 하늘, 1은 공허 딥
            ry = (S.phase % 3 == 0) and deepY or skyY
        else
            ry = c.voidBaseY + (math.random() - 0.5) * 2 * c.voidRangeY * chaos
        end
        local t = os.clock()
        if shakeX then rx = rx + math.sin(t * 55 + S.phase) * (400 + math.random() * 900) end
        if shakeY then ry = ry + math.cos(t * 48 + S.phase * 0.7) * (500 + math.random() * 1100) end
        if shakeZ then rz = rz + math.sin(t * 62 + S.phase * 1.3) * (450 + math.random() * 1000) end
        -- 낙사/밴 완화: kill floor 위
        local killY = -500
        pcall(function()
            local h = workspace.FallenPartsDestroyHeight
            if typeof(h) == "number" then killY = h end
        end)
        if ry < killY + 50 then ry = killY + 50 + math.random() * 25 end
        -- 거리 유지
        if S.target and isAlive(S.target) then
            local th = S.target.Character and S.target.Character:FindFirstChild("HumanoidRootPart")
            if th then
                local dist = (Vector3.new(rx, base.Y, rz) - th.Position).Magnitude
                if dist < 55 then
                    local away = (Vector3.new(rx, 0, rz) - Vector3.new(th.Position.X, 0, th.Position.Z))
                    if away.Magnitude > 1 then
                        away = away.Unit * (110 + math.random() * 200)
                        rx = th.Position.X + away.X
                        rz = th.Position.Z + away.Z
                    end
                end
            end
        end

        if tick() - S.lastVoid > 0.008 then
            if math.abs(hrp.Position.Y - c.voidBaseY) > 4000 then
                -- keep saved
            else
                S.savedCF = hrp.CFrame
                S.savedLV = hrp.AssemblyLinearVelocity
                S.savedAV = hrp.AssemblyAngularVelocity
            end
            S.lastVoid = tick()
        end

        pcall(function()
            hrp.CFrame = CFrame.new(rx, ry, rz)
            -- X/Y/Z 흔들기 자동 (특히 Z 강하게)
            local zx = math.random(-12000, 12000)
            local zy = math.random(-7000, 7000)
            local zz = math.random(-15000, 15000) -- Z 좌표 흔들기 강화
            hrp.AssemblyLinearVelocity = Vector3.new(zx, zy, zz)
            -- 추가 Z 오프셋 텔레포트 지터
            hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, (math.random() - 0.5) * math.min(800, (c.voidRangeZ or 1000) * 0.08))

            hrp.AssemblyAngularVelocity = Vector3.new(
                math.random(-150, 150),
                math.random(-150, 150),
                math.random(-150, 150)
            )
        end)
        getgenv().__NH_VoidActive = true
    end

    local function doAttack(hrp)
        if not S.target or not isAlive(S.target) then return end
        local th = S.target.Character:FindFirstChild("HumanoidRootPart")
        local head = S.target.Character:FindFirstChild("HitboxHead")
            or S.target.Character:FindFirstChild("Head")
        if not th then return end
        pcall(function()
            if head then
                hrp.CFrame = CFrame.new(head.Position + Vector3.new(0, 2.5, 0))
            else
                hrp.CFrame = th.CFrame
            end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        getgenv().__NH_VoidPauseUntil = os.clock() + 0.18
        getgenv().__NH_VoidActive = false
    end

    local function stop()
        S.on = false
        getgenv().__NH_VoidActive = false
        if S.hb then pcall(function() S.hb:Disconnect() end) S.hb = nil end
        pcall(function() RunService:UnbindFromRenderStep("_vs_sync") end)
        local h = HRP()
        if h and S.savedCF then
            pcall(function()
                h.CFrame = S.savedCF
                h.AssemblyLinearVelocity = Vector3.zero
                h.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    local function start()
        stop()
        S.on = true
        S.mode = "hide"
        S.modeT = tick()
        S.target = nearest()
        S.lastVoid = 0
        local h0 = HRP()
        if h0 then
            S.savedCF = h0.CFrame
            S.savedLV = h0.AssemblyLinearVelocity
            S.savedAV = h0.AssemblyAngularVelocity
        end

        -- 클라만 맵에 보이기 (hide 중)
        RunService:BindToRenderStep("_vs_sync", Enum.RenderPriority.Camera.Value + 1, function()
            if not S.on or S.mode ~= "hide" then return end
            local h = HRP()
            if not h then return end
            pcall(function()
                h.CFrame = S.savedCF
                h.AssemblyLinearVelocity = S.savedLV
                h.AssemblyAngularVelocity = S.savedAV
            end)
        end)

        S.hb = RunService.Heartbeat:Connect(function()
            if not S.on then return end
            local h = HRP()
            if not h then return end

            if not isAlive(S.target) then
                S.target = nearest()
            end

            local c = CFG()
            local elapsed = tick() - S.modeT
            if S.mode == "hide" then
                if elapsed >= (c.hideTime or 0.45) then
                    S.mode = "attack"
                    S.modeT = tick()
                else
                    doVoid(h)
                end
            else
                if elapsed >= (c.attackTime or 0.08) then
                    S.mode = "hide"
                    S.modeT = tick()
                else
                    if isAlive(S.target) then
                        doAttack(h)
                    else
                        S.mode = "hide"
                        doVoid(h)
                    end
                end
            end
        end)
    end

    task.spawn(function()
        local was = false
        while true do
            task.wait(0.06)
            local on = voidOn()
            if on and not was then start()
            elseif (not on) and was then stop() end
            was = on
        end
    end)
end)





-- =====================================================================
-- [BAIT] 내 화면 안정 / 상대만 광란
-- 서버: 왕복 + 거꾸로 + 상하 폭주 (남이 보는 나)
-- 클라: 안전 위치 완전 복원 (내 화면 꿀렁 X, 낙사 X)
-- 레이지 ON이면 그 프레임은 레이지 서버 포즈 우선 (베이팅 중 타격 가능)
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer

    local safeCF, safeLV, safeAV
    local hb, on = nil, false
    local phase, seed = 0, math.random() * 100

    local function baitOn()
        return getgenv().BaitingEnabled == true
    end

    local function rageOn()
        return getgenv().MeleeRageBotEnabled == true
            or getgenv().HVHRageEnabled == true
            or getgenv().KnifeModeEnabled == true
            or getgenv().ragebotOrKillAura == true
    end

    local function getRoot()
        local c = LP.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function killFloor()
        local y = -500
        pcall(function()
            local v = workspace.FallenPartsDestroyHeight
            if typeof(v) == "number" then y = v end
        end)
        return y
    end

    local function stop()
        on = false
        if hb then pcall(function() hb:Disconnect() end) hb = nil end
        pcall(function() RunService:UnbindFromRenderStep("NH_BaitRestore") end)
        pcall(function() RunService:UnbindFromRenderStep("NH_BaitCam") end)
        local root = getRoot()
        if root and safeCF then
            pcall(function()
                root.CFrame = safeCF
                if safeLV then root.AssemblyLinearVelocity = safeLV end
                if safeAV then root.AssemblyAngularVelocity = safeAV end
            end)
        end
        safeCF, safeLV, safeAV = nil, nil, nil
    end

    local function start()
        if on then return end
        on = true
        phase = 0
        seed = math.random() * 100

        hb = RunService.Heartbeat:Connect(function(dt)
            if not baitOn() then stop() return end
            if NH_isLobby and NH_isLobby() then return end
            local root = getRoot()
            if not root then return end

            -- 내 실제 위치 스냅샷 (복원용)
            safeCF = root.CFrame
            safeLV = root.AssemblyLinearVelocity
            safeAV = root.AssemblyAngularVelocity
            pcall(function()
                if typeof(root.Velocity) == "Vector3" then safeLV = root.Velocity end
            end)

            -- 레이지 공격 프레임은 서버 포즈를 레이지에게 양보
            if rageOn() then
                return
            end

            local kf = killFloor()
            phase = phase + (dt or 0.016) * 16
            local t = phase + seed
            local amp = tonumber(getgenv().BaitAmp) or 240

            -- XZ 왕복
            local bx = math.sin(t * 1.8) * amp + math.cos(t * 0.85) * (amp * 0.5)
            local bz = math.cos(t * 1.6) * amp + math.sin(t * 1.05) * (amp * 0.5)

            -- 상하 폭주
            local yWave = math.sin(t * 5.5)
            local by = kf + 6 + math.abs(yWave) * 90 + math.cos(t * 3.2) * 40
            if yWave > 0.85 then
                by = kf + 2
            elseif yWave < -0.85 then
                by = kf + 120
            end

            -- 몸 거꾸로 + 회전 (상대 화면만)
            local pos = Vector3.new(bx, by, bz)
            local flip = CFrame.Angles(math.pi, 0, 0)
            local spin = CFrame.Angles(
                math.sin(t * 3) * 0.9,
                t * 3.5,
                math.cos(t * 2.4) * 0.9
            )
            root.CFrame = CFrame.new(pos) * flip * spin
            root.AssemblyLinearVelocity = Vector3.new(
                math.sin(t * 6) * 140,
                yWave * -100,
                math.cos(t * 6) * 140
            )
            pcall(function()
                root.Velocity = root.AssemblyLinearVelocity
                root.RotVelocity = Vector3.new(t % 20, 50, -t % 20)
            end)
        end)

        pcall(function() RunService:UnbindFromRenderStep("NH_BaitRestore") end)
        pcall(function() RunService:UnbindFromRenderStep("NH_BaitCam") end)

        -- 내 화면: 꿀렁 X — 몸만 안전 좌표로 복원
        RunService:BindToRenderStep("NH_BaitRestore", Enum.RenderPriority.First.Value, function()
            if not on or not baitOn() then return end
            local root = getRoot()
            if not root or not safeCF then return end
            root.CFrame = safeCF
            if typeof(safeLV) == "Vector3" then
                local y = safeLV.Y
                if y < -40 then y = -15 end
                root.AssemblyLinearVelocity = Vector3.new(safeLV.X, y, safeLV.Z)
            end
            if typeof(safeAV) == "Vector3" then
                root.AssemblyAngularVelocity = safeAV
            end
        end)
    end

    task.spawn(function()
        local was = false
        while true do
            task.wait(0.08)
            local a = baitOn()
            if a and not was then start()
            elseif (not a) and was then stop() end
            was = a
        end
    end)
end)

-- =====================================================================
-- [AUTO RELOAD] 탄 없으면 재장전만 (무기 스왑 없음)
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local LP = Players.LocalPlayer

    local FC, EnumLibrary, UseItem
    local lastReload = 0

    local function boot()
        pcall(function()
            local ps = LP:FindFirstChild("PlayerScripts")
            local c = ps and ps:FindFirstChild("Controllers")
            local mod = c and c:FindFirstChild("FighterController")
            if mod then FC = require(mod) end
        end)
        pcall(function()
            local M = RS:FindFirstChild("Modules")
            local e = M and M:FindFirstChild("EnumLibrary")
            if e then EnumLibrary = require(e) end
        end)
        pcall(function()
            local a = RS:FindFirstChild("Remotes")
            a = a and a:FindFirstChild("Replication")
            a = a and a:FindFirstChild("Fighter")
            UseItem = a and a:FindFirstChild("UseItem")
        end)
    end
    boot()

    local function oid()
        local id
        pcall(function()
            local lf = FC and FC.LocalFighter
            local item = lf and (lf.EquippedItem or lf.Item)
            if not item then return end
            if type(item.Get) == "function" then
                id = item:Get("ObjectID") or item:Get("Id")
            end
            id = id or item.ObjectID or item.Id
        end)
        if not id then
            pcall(function()
                local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
                if t then id = t:GetAttribute("ObjectID") or t:GetAttribute("Id") end
            end)
        end
        return id
    end

    local function ammoEmpty()
        local empty = false
        pcall(function()
            local lf = FC and FC.LocalFighter
            local item = lf and (lf.EquippedItem or lf.Item)
            if not item then return end
            local mag, ammo
            if type(item.Get) == "function" then
                mag = item:Get("Mag") or item:Get("Ammo") or item:Get("Clip")
                ammo = item:Get("AmmoInClip") or item:Get("CurrentAmmo")
            end
            mag = mag or item.Mag or item.Ammo or item.Clip
            ammo = ammo or item.AmmoInClip or item.CurrentAmmo
            if type(ammo) == "number" and ammo <= 0 then empty = true end
            if type(mag) == "number" and mag <= 0 then empty = true end
        end)
        pcall(function()
            local t = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if not t then return end
            local a = t:GetAttribute("Ammo") or t:GetAttribute("Mag") or t:GetAttribute("Clip")
            if type(a) == "number" and a <= 0 then empty = true end
        end)
        return empty
    end

    local function doReload()
        boot()
        local id = oid()
        local done = false
        -- 1) UseItem Reload enum
        if UseItem and id and EnumLibrary then
            for _, name in ipairs({"Reload", "StartReload", "BeginReload", "WeaponReload"}) do
                local se
                pcall(function() se = EnumLibrary:ToEnum(name) end)
                if se ~= nil then
                    pcall(function()
                        UseItem:FireServer(id, se, nil, nil)
                        done = true
                    end)
                    if done then break end
                end
            end
            if not done then
                pcall(function()
                    UseItem:FireServer(id, "Reload", nil, nil)
                    done = true
                end)
            end
        end
        -- 2) Fighter method
        if not done then
            pcall(function()
                local lf = FC and FC.LocalFighter
                if lf and type(lf.Reload) == "function" then
                    lf:Reload()
                    done = true
                elseif lf and type(lf.StartReload) == "function" then
                    lf:StartReload()
                    done = true
                end
            end)
        end
        -- 3) R 키 (스왑 아님, 재장전 키만)
        if not done then
            pcall(function()
                VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                done = true
            end)
        end
        return done
    end

    while true do
        task.wait(0.15)
        if getgenv().AutoReloadEnabled ~= true then continue end
        if NH_isLobby and NH_isLobby() then continue end
        if tick() - lastReload < 0.8 then continue end
        if ammoEmpty() then
            if doReload() then
                lastReload = tick()
            end
        end
    end
end)

-- =====================================================================
-- [GHOST] 예측 매트릭스 + 카운터 방법 탐색/실행
-- Mode: Auto | HeadAbove | SideOrbit | Under | Behind | EvadeShoot
-- Execute ON 이면 선택된 카운터를 서버 포즈·회피에 실제 적용
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer

    getgenv().GhostMatrix = tonumber(getgenv().GhostMatrix) or 12
    getgenv().GhostCounterMode = getgenv().GhostCounterMode or "Auto"
    getgenv().GhostExecute = getgenv().GhostExecute == true

    getgenv().__NH_GhostTarget = nil
    getgenv().__NH_GhostAimPart = nil
    getgenv().__NH_GhostServerHint = nil
    getgenv().__NH_GhostThreat = 0
    getgenv().__NH_GhostMethod = nil
    getgenv().__NH_GhostEvade = nil

    local hist = {}

    local function rootOf(p)
        local c = p and p.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function headOf(p)
        local c = p and p.Character
        if not c then return nil end
        return c:FindFirstChild("HitboxHead")
            or c:FindFirstChild("HitboxHeadSmall")
            or c:FindFirstChild("Head")
    end
    local function meRoot()
        return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    end

    local function sample()
        local now = os.clock()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local r = rootOf(p)
                if r then
                    local vel = r.AssemblyLinearVelocity
                    if typeof(vel) ~= "Vector3" then
                        pcall(function() vel = r.Velocity end)
                    end
                    if typeof(vel) ~= "Vector3" then vel = Vector3.zero end
                    local h = hist[p]
                    if not h then h = {} hist[p] = h end
                    h[#h + 1] = { t = now, pos = r.Position, vel = vel, y = r.Position.Y }
                    while #h > 28 do table.remove(h, 1) end
                end
            end
        end
    end

    local function velOf(p)
        local h = hist[p]
        local r = rootOf(p)
        if h and #h >= 2 then
            local a, b = h[#h - 1], h[#h]
            local dt = math.max(b.t - a.t, 1e-3)
            return (b.pos - a.pos) / dt
        end
        if r then
            local v = r.AssemblyLinearVelocity
            if typeof(v) == "Vector3" then return v end
        end
        return Vector3.zero
    end

    -- 적 레이지 패턴 분류
    local function classify(p)
        local h = hist[p]
        if not h or #h < 4 then return "unknown", 0 end
        local a, b = h[1], h[#h]
        local dt = math.max(b.t - a.t, 1e-3)
        local speed = (b.pos - a.pos).Magnitude / dt
        local dy = (b.y - a.y) / dt
        local maxDy = 0
        for i = 2, #h do
            maxDy = math.max(maxDy, math.abs(h[i].y - h[i-1].y) / math.max(h[i].t - h[i-1].t, 1e-3))
        end
        -- 패턴
        if maxDy > 90 and speed > 100 then return "head_tp", 5 end
        if b.y < a.y - 15 and speed > 60 then return "under", 4 end
        if speed > 200 then return "blink", 5 end
        if speed > 80 and math.abs(dy) < 20 then return "orbit", 3 end
        if speed > 50 then return "push", 2 end
        return "unknown", 1
    end

    -- 카운터 방법 후보 생성
    local function buildCounters(p, head, pred, vel, pattern)
        local me = meRoot()
        if not me or not head then return {} end
        local look = rootOf(p) and rootOf(p).CFrame.LookVector or Vector3.new(0, 0, -1)
        local right = rootOf(p) and rootOf(p).CFrame.RightVector or Vector3.new(1, 0, 0)
        local list = {}

        local function add(name, pos, evade, score)
            list[#list + 1] = {
                name = name,
                pos = pos,
                evade = evade,
                score = score or 1,
            }
        end

        -- HeadAbove: 상대 머리 위에서 헤드 조준 (정면 카운터)
        add("HeadAbove", pred + Vector3.new(0, 5, 0), nil, pattern == "head_tp" and 8 or 5)

        -- SideOrbit: 측면 — 헤드온 레이지 회피
        add("SideOrbit", pred + right * 8 + Vector3.new(0, 3, 0), pred + right * 12, pattern == "orbit" and 9 or 6)
        add("SideOrbit", pred - right * 8 + Vector3.new(0, 3, 0), pred - right * 12, pattern == "push" and 7 or 5)

        -- Under: 아래로 — 헤드 레이지 빗나감
        local depth = tonumber(getgenv().UndergroundDepth) or 14
        add("Under", Vector3.new(pred.X, head.Position.Y - depth * 0.6, pred.Z), nil, pattern == "under" and 3 or 7)

        -- Behind: 등 뒤 — 나이프/정면 TP 카운터
        add("Behind", pred - look * 4 + Vector3.new(0, 1, 0), nil, pattern == "blink" and 6 or 5)

        -- EvadeShoot: 나와 적 사이 수직 회피 후 사격
        local away = (me.Position - pred)
        if away.Magnitude < 1 then away = right end
        local evadePos = me.Position + away.Unit * 10 + Vector3.new(0, 6, 0)
        add("EvadeShoot", pred + Vector3.new(0, 4.5, 0), evadePos, pattern == "push" and 9 or 6)

        return list
    end

    local function pickMethod(list, mode)
        mode = tostring(mode or "Auto")
        if mode ~= "Auto" then
            local best
            for _, c in ipairs(list) do
                if c.name == mode then
                    if not best or c.score > best.score then best = c end
                end
            end
            if best then return best end
        end
        table.sort(list, function(a, b) return a.score > b.score end)
        return list[1]
    end

    local function pickGhost()
        local me = meRoot()
        if not me then return end
        local n = math.clamp(tonumber(getgenv().GhostMatrix) or 12, 6, 24)
        local mode = getgenv().GhostCounterMode or "Auto"
        local bestP, bestHead, bestMethod, bestScore = nil, nil, nil, -1e9

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            if NH_isImmune and NH_isImmune(p) then continue end
            local head = headOf(p)
            local r = rootOf(p)
            if not head or not r then continue end
            local pattern, pScore = classify(p)
            local vel = velOf(p)
            local pred = head.Position + vel * 0.1
            -- V2 matrix: 더 긴 리드 + 가속도 + 거리 보정
            pcall(function()
                local predFn = rawget(getgenv(), "NH_GhostPredictPos")
                if type(predFn) == "function" then
                    local p2 = predFn(head)
                    if typeof(p2) == "Vector3" then pred = p2 end
                else
                    local boost = tonumber(getgenv().NH_GHOST_LEAD_BOOST) or 1.75
                    local dist = (head.Position - me.Position).Magnitude
                    local lead = (0.1 + math.clamp(dist / 800, 0, 0.14)) * boost
                    if vel.Magnitude > 90 then lead = lead * 1.3 end
                    pred = head.Position + vel * lead
                end
            end)
            local counters = buildCounters(p, head, pred, vel, pattern)
            local method = pickMethod(counters, mode)
            if not method then continue end

            local dist = (me.Position - head.Position).Magnitude
            local score = method.score * 10 + pScore * 5 - dist * 0.02
            local toward = 0
            if vel.Magnitude > 3 then
                toward = (me.Position - pred).Unit:Dot(vel.Unit)
                if toward > 0.35 then score = score + 12 end
            end
            if score > bestScore then
                bestScore = score
                bestP = p
                bestHead = head
                bestMethod = method
            end
        end

        if bestP and bestMethod then
            getgenv().__NH_GhostTarget = bestP
            getgenv().__NH_GhostAimPart = bestHead
            getgenv().__NH_GhostThreat = bestScore
            getgenv().__NH_GhostMethod = bestMethod.name
            if getgenv().GhostExecute ~= false then
                getgenv().__NH_GhostServerHint = bestMethod.pos
                getgenv().__NH_GhostEvade = bestMethod.evade
            else
                getgenv().__NH_GhostServerHint = nil
                getgenv().__NH_GhostEvade = nil
            end
        else
            getgenv().__NH_GhostTarget = nil
            getgenv().__NH_GhostAimPart = nil
            getgenv().__NH_GhostServerHint = nil
            getgenv().__NH_GhostMethod = nil
            getgenv().__NH_GhostEvade = nil
            getgenv().__NH_GhostThreat = 0
        end
    end

    -- 실행: 회피 좌표가 있으면 클라 몸도 짧게 이동 (카운터 회피)
    local evadeUntil = 0
    RunService.Heartbeat:Connect(function()
        if getgenv().GhostEnabled ~= true then
            getgenv().__NH_GhostTarget = nil
            getgenv().__NH_GhostAimPart = nil
            getgenv().__NH_GhostServerHint = nil
            getgenv().__NH_GhostMethod = nil
            getgenv().__NH_GhostEvade = nil
            return
        end
        if NH_isLobby and NH_isLobby() then return end

        sample()
        pickGhost()

        if getgenv().GhostExecute == false then return end
        local evade = getgenv().__NH_GhostEvade
        local method = getgenv().__NH_GhostMethod
        if method == "EvadeShoot" and typeof(evade) == "Vector3" then
            local me = meRoot()
            if me and os.clock() > evadeUntil then
                -- 짧은 회피 (상시 고정 아님)
                local cur = me.CFrame
                me.CFrame = CFrame.new(evade, getgenv().__NH_GhostAimPart and getgenv().__NH_GhostAimPart.Position or evade)
                evadeUntil = os.clock() + 0.08
                task.defer(function()
                    if me and me.Parent then
                        -- 물리 복귀는 레이지 디싱크/이동에 맡김
                    end
                end)
            end
        end
    end)
end)

-- =====================================================================
-- [SURVIVAL COUNTER] 안 맞게 — Unnamed+Kicia 통합 강화
-- 근접/피격 시 강제 도약 + Y고정 + 풀림 저항
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer

    local lastHp, evadeUntil, resistUntil = 100, 0, 0
    local lastPos, anchor, lockY = nil, nil, nil
    local phase, burstLeft = 0, 0

    local function lionOn()
        return getgenv().UnnamedCounter == true or getgenv().LionRageCounter == true
    end
    local function kiciaOn()
        return getgenv().KiciaRageCounter == true
    end
    local function anyOn()
        return lionOn() or kiciaOn()
    end
    -- 보이드 켜져 있어도 보조 카운터 가능
    local function voidOn()
        if NH_isLobby and NH_isLobby() then return false end
        return getgenv().VoidSpamEnabled == true
            or (type(VoidSpamSettings) == "table" and VoidSpamSettings.on)
    end

    local function root()
        return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    end
    local function hum()
        return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    end

    local function killFloor()
        local f = -200
        pcall(function()
            local v = workspace.FallenPartsDestroyHeight
            if typeof(v) == "number" then f = v end
        end)
        return f
    end

    local function minSafeY()
        return killFloor() + 95
    end

    local function safeY(y)
        local m = minSafeY()
        if y < m then return m + 8 end
        if y > 280 then return 90 end
        return y
    end

    local function antiFall(r)
        if not r then return end
        local p = r.Position
        local m = minSafeY()
        if p.Y < m then
            r.CFrame = CFrame.new(p.X, m + 12, p.Z)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if lockY then lockY = math.max(lockY, m + 12) end
            if anchor then
                local a = anchor.Position
                anchor = CFrame.new(a.X, m + 12, a.Z)
            end
        end
        local v = r.AssemblyLinearVelocity
        if v.Y < -40 then
            r.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
    end

    local function threat()
        local r = root()
        if not r then return nil, 1e9 end
        local best, bd = nil, 1e9
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local c = p.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local hr = c and c:FindFirstChild("HumanoidRootPart")
                if h and hr and h.Health > 0 then
                    local d = (r.Position - hr.Position).Magnitude
                    if d < bd then bd, best = d, hr end
                end
            end
        end
        return best, bd
    end

    local function hardHop(r)
        antiFall(r)
        local p = r.Position
        local ang = math.random() * math.pi * 2
        local dist = 90 + math.random() * 140
        local ny = safeY(p.Y + 8 + math.random() * 15)
        r.CFrame = CFrame.new(p.X + math.cos(ang) * dist, ny, p.Z + math.sin(ang) * dist)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        lockY = ny
        anchor = r.CFrame
        antiFall(r)
    end

    LP.CharacterAdded:Connect(function(ch)
        task.delay(0.25, function()
            local h = ch:FindFirstChildOfClass("Humanoid")
            local r = ch:FindFirstChild("HumanoidRootPart")
            if h then lastHp = h.Health end
            if r then lastPos = r.Position end
            evadeUntil, resistUntil, burstLeft = 0, 0, 0
            anchor, lockY = nil, nil
        end)
    end)

    RunService.Heartbeat:Connect(function()
        if not anyOn() and not voidOn() then
            evadeUntil, resistUntil, burstLeft = 0, 0, 0
            return
        end
        -- void hide 중엔 카운터 몸 싸움 최소화
        if voidOn() and getgenv().__NH_VoidActive == true then
            return
        end

        local h, r = hum(), root()
        if not h or not r or h.Health <= 0 then return end
        antiFall(r)

        local hp = h.Health
        local dmg = lastHp - hp
        lastHp = hp
        local _, dist = threat()
        local pos = r.Position

        -- 피격 / 초근접 → 즉시 도약
        if dmg > 0.4 or dist < 18 then
            evadeUntil = os.clock() + 1.1
            resistUntil = os.clock() + 1.2
            burstLeft = 8
            hardHop(r)
            getgenv().__NH_VoidPauseUntil = 0
        end

        -- 끌림 감지 (Kicia)
        if lastPos and kiciaOn() then
            if (pos - lastPos).Magnitude > 16 then
                resistUntil = math.max(resistUntil, os.clock() + 1.0)
                if anchor then
                    local ap = anchor.Position
                    r.CFrame = CFrame.new(ap.X, safeY(lockY or ap.Y), ap.Z)
                    r.AssemblyLinearVelocity = Vector3.zero
                    pos = r.Position
                else
                    hardHop(r)
                end
            end
            if math.abs(pos.Y - lastPos.Y) > 16 then
                resistUntil = math.max(resistUntil, os.clock() + 1.0)
                r.CFrame = CFrame.new(pos.X, safeY(lockY or pos.Y), pos.Z)
            end
        end

        local now = os.clock()
        if now < evadeUntil and lionOn() then
            phase = phase + 0.85
            local p = r.Position
            local jx = math.sin(phase * 5.2) * 32 + math.cos(phase * 2.1) * 18
            local jz = math.cos(phase * 4.6) * 32 + math.sin(phase * 2.6) * 18
            r.CFrame = CFrame.new(p.X + jx, safeY(lockY or p.Y), p.Z + jz)
            r.AssemblyLinearVelocity = Vector3.new(jx * 3, 0, jz * 3)
            antiFall(r)
            if burstLeft > 0 then
                burstLeft = burstLeft - 1
                if burstLeft % 2 == 0 then hardHop(r) end
            end
        end

        if now < resistUntil and kiciaOn() then
            local base = anchor and anchor.Position or pos
            local jx = (math.random() - 0.5) * 28
            local jz = (math.random() - 0.5) * 28
            r.CFrame = CFrame.new(base.X + jx, safeY(lockY or base.Y), base.Z + jz)
            r.AssemblyAngularVelocity = Vector3.zero
            antiFall(r)
            if not anchor then anchor = r.CFrame end
        elseif kiciaOn() then
            anchor = r.CFrame
            lockY = safeY(r.Position.Y)
        end

        lastPos = r.Position
        antiFall(r)
    end)

    RunService.Stepped:Connect(function()
        if not anyOn() then return end
        if voidOn() and getgenv().__NH_VoidActive == true then return end
        local r = root()
        antiFall(r)
        if not r then return end
        if os.clock() < resistUntil and anchor and kiciaOn() then
            local p, a = r.Position, anchor.Position
            if (p - a).Magnitude > 22 then
                r.CFrame = CFrame.new(a.X, safeY(lockY or a.Y), a.Z)
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)

    pcall(function() RunService:UnbindFromRenderStep("NH_LionCounter") end)
    pcall(function() RunService:UnbindFromRenderStep("NH_KiciaCounter") end)
    RunService:BindToRenderStep("NH_SurviveCounter", 299, function()
        if not anyOn() then return end
        if voidOn() and getgenv().__NH_VoidActive == true then return end
        local r = root()
        antiFall(r)
        if not r then return end
        local now = os.clock()
        if now < evadeUntil and lionOn() then
            local p = r.Position
            local t = now * 18
            r.CFrame = CFrame.new(p.X + math.sin(t) * 11, safeY(lockY or p.Y), p.Z + math.cos(t) * 11)
            r.AssemblyAngularVelocity = Vector3.zero
        end
        if now < resistUntil and kiciaOn() and anchor then
            local p = r.Position
            r.CFrame = CFrame.new(p.X, safeY(lockY or anchor.Position.Y), p.Z)
        end
        antiFall(r)
    end)
end)




-- =====================================================================
-- [ORBIT] 적 주회 (AA 스크립트 스타일)
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer
    local angle = 0

    local function isTeam(p)
        if not p or p == LP then return true end
        local ok, r = pcall(function()
            local a, b = p:GetAttribute("TeamID"), LP:GetAttribute("TeamID")
            if a ~= nil and b ~= nil then return a == b end
            if LP.Team and p.Team and LP.Team == p.Team then
                return LP.Team.Name ~= "Neutral"
            end
            return false
        end)
        return ok and r
    end

    -- Orbit slots: Left / Left-Center / Right / Right-Center / Center / Center-Left / Center-Right
    local ORBIT_SLOTS = {
        { -1.00, 0.00 }, -- Left
        { -0.70, 0.35 }, -- Left-Center
        {  1.00, 0.00 }, -- Right
        {  0.70, 0.35 }, -- Right-Center
        {  0.00, 0.00 }, -- Center
        { -0.50, 0.00 }, -- Center-Left
        {  0.50, 0.00 }, -- Center-Right
        {  0.00, 0.55 }, -- Center-Front
        {  0.00,-0.55 }, -- Center-Back
    }
    local slotIdx, slotTimer = 1, 0
    RunService.Heartbeat:Connect(function(dt)
        if not getgenv().OrbitEnabled then return end
        if NH_isLobby and NH_isLobby() then return end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local best, bd = nil, 1e9
        for _, p in ipairs(Players:GetPlayers()) do
            if not isTeam(p) and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if r and h and h.Health > 0 then
                    local d = (hrp.Position - r.Position).Magnitude
                    if d < bd then bd, best = d, r end
                end
            end
        end
        if not best then return end
        local rad = math.max(0, tonumber(getgenv().OrbitRadius) or 0)
        local spd = tonumber(getgenv().OrbitSpeed) or 8
        -- 빠른 슬롯 전환 (랜덤 방향 패턴)
        slotTimer = slotTimer + (dt or 0.016)
        local switchEvery = math.max(0.04, 0.22 - (spd * 0.006))
        if slotTimer >= switchEvery then
            slotTimer = 0
            slotIdx = math.random(1, #ORBIT_SLOTS)
        end
        local slot = ORBIT_SLOTS[slotIdx]
        -- 상대가 맞추기 어렵게: 큰 지터 + 빠른 높이/좌우 전환
        local amp = math.clamp(rad * 0.18 + 6, 6, 120)
        local jx = (math.random() - 0.5) * amp * 2
        local jz = (math.random() - 0.5) * amp * 2
        local t = os.clock()
        local jy = 3 + math.sin(t * (10 + spd)) * math.min(18, 4 + rad * 0.02)
        jy = jy + (math.random() - 0.5) * 8
        -- 가끔 반대편으로 순간 점프
        if math.random() < 0.12 then
            slotIdx = math.random(1, #ORBIT_SLOTS)
            slot = ORBIT_SLOTS[slotIdx]
            jx = jx * 1.8
            jz = jz * 1.8
        end
        local offset = Vector3.new(slot[1] * rad + jx, jy, slot[2] * rad + jz)
        hrp.CFrame = CFrame.new(best.Position + offset, best.Position)
        hrp.AssemblyLinearVelocity = Vector3.new(jx * 2, 0, jz * 2)
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end)

-- =====================================================================

-- =====================================================================

-- GHOST prediction matrix V2 (multi-sample + accel + distance lead)
getgenv().NH_GHOST_LEAD_BOOST = 1.85
getgenv().NH_GHOST_SAMPLES = getgenv().NH_GHOST_SAMPLES or {}
local function NH_GhostPredictPos(part)
    if not part or not part.Parent then return nil end
    local pos = part.Position
    local vel = Vector3.zero
    pcall(function() vel = part.AssemblyLinearVelocity end)
    local boost = tonumber(getgenv().NH_GHOST_LEAD_BOOST) or 1.85
    local samples = getgenv().NH_GHOST_SAMPLES
    local key = tostring(part)
    local now = os.clock()
    local list = samples[key]
    if type(list) ~= "table" then list = {} samples[key] = list end
    table.insert(list, { t = now, p = pos, v = vel })
    while #list > 10 do table.remove(list, 1) end
    local avgV = vel
    if #list >= 2 then
        local a, b = list[1], list[#list]
        local dt = math.max(b.t - a.t, 0.001)
        avgV = (b.p - a.p) / dt
        avgV = avgV:Lerp(vel, 0.3)
    end
    local accel = Vector3.zero
    if #list >= 3 then
        local mid = list[math.floor(#list / 2)]
        local dt2 = math.max(list[#list].t - mid.t, 0.001)
        accel = (list[#list].v - mid.v) / dt2
    end
    local dist = 50
    local cam = workspace.CurrentCamera
    if cam then dist = (pos - cam.CFrame.Position).Magnitude end
    local leadT = (0.06 + math.clamp(dist / 850, 0, 0.15)) * boost
    if avgV.Magnitude > 80 then leadT = leadT * 1.25 end
    if avgV.Magnitude > 160 then leadT = leadT * 1.2 end
    return pos + avgV * leadT + accel * (leadT * leadT * 0.5)
end
getgenv().NH_GhostPredictPos = NH_GhostPredictPos

-- [FLICK BOT] 헤드 순간 조준 → 복귀 (사격 타이밍 맞춤)
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local LP = Players.LocalPlayer
    local lastFlick = 0
    local restoring = false

    local function isTeam(p)
        if not p or p == LP then return true end
        local ok, r = pcall(function()
            local a, b = p:GetAttribute("TeamID"), LP:GetAttribute("TeamID")
            if a ~= nil and b ~= nil then return a == b end
            if LP.Team and p.Team and LP.Team == p.Team then
                return LP.Team.Name ~= "Neutral"
            end
            return false
        end)
        return ok and r
    end

    local function pickTarget()
        local cam = workspace.CurrentCamera
        if not cam then return nil, nil end
        local fov = tonumber(getgenv().FlickBotFOV) or 180
        local best, bd, part = nil, fov, nil
        local mpos = UIS:GetMouseLocation()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and not isTeam(p) and p.Character then
                if getgenv().NH_isImmune and getgenv().NH_isImmune(p) then continue end
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local head = p.Character:FindFirstChild("Head")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                local aim = head or hrp
                if hum and hum.Health > 0 and aim then
                    local sp, on = cam:WorldToViewportPoint(aim.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(mpos.X, mpos.Y)).Magnitude
                        if d < bd then
                            bd, best, part = d, p, aim
                        end
                    end
                end
            end
        end
        return best, part
    end

    RunService.RenderStepped:Connect(function()
        if getgenv().FlickBotEnabled ~= true then return end
        if NH_isLobby and NH_isLobby() then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local spd = math.clamp(tonumber(getgenv().FlickBotSpeed) or 1, 0.05, 1)
        -- 더 빠른 쿨다운 (공격적)
        local gap = 0.02 + (1 - spd) * 0.08
        if os.clock() - lastFlick < gap then return end
        local firing = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            or UIS:IsKeyDown(Enum.KeyCode.ButtonR2)
            or getgenv().RagebotEnabled == true
            or getgenv().GhostEnabled == true
            or getgenv().__NH_ForceFlick == true
            or true -- 상시 플릭 (가까운 적 헤드)
        local _, aimPart = pickTarget()
        if not aimPart then return end
        lastFlick = os.clock()
        local from = cam.CFrame
                local toPos = aimPart.Position
        -- GHOST 예측 매트릭스 리드
        pcall(function()
            local predFn = rawget(getgenv(), "NH_GhostPredictPos")
            if type(predFn) == "function" then
                local pred = predFn(aimPart)
                if typeof(pred) == "Vector3" then toPos = pred end
            else
                local v = aimPart.AssemblyLinearVelocity
                if typeof(v) == "Vector3" then
                    toPos = toPos + v * ((0.09 + (1 - spd) * 0.1) * (tonumber(getgenv().NH_GHOST_LEAD_BOOST) or 1.75))
                end
            end
            local hint = getgenv().__NH_GhostAimPart
            if hint and hint.Parent and type(predFn) == "function" then
                local pred2 = predFn(hint)
                if typeof(pred2) == "Vector3" then toPos = pred2 end
            end
        end)
        local look = CFrame.new(cam.CFrame.Position, toPos)
        local alpha = math.clamp(0.75 + spd * 0.25, 0.75, 1)
        cam.CFrame = from:Lerp(look, alpha)
        if getgenv().NH_MarkAttack then pcall(getgenv().NH_MarkAttack) end
        if not restoring then
            restoring = true
            task.delay(0.02 + (1 - spd) * 0.04, function()
                pcall(function()
                    if cam then
                        cam.CFrame = cam.CFrame:Lerp(from, 0.25)
                    end
                end)
                restoring = false
            end)
        end
    end)
end)

-- [DEVICE SPOOF] SetControls + custom icon color (Nametag Controls)
-- =====================================================================
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    local types = { "VR", "Touch", "Gamepad", "MouseKeyboard" }
    local typeMap = {
        vr = "VR", touch = "Touch", gamepad = "Gamepad",
        mousekeyboard = "MouseKeyboard", random = "Random",
    }
    local lastRandom, lastType, lastSend = 0, nil, 0
    local controlsIcon, originalIconColor, originalIconImage
    local nextIconSearch, nextConstantsSearch = 0, 0
    local gameConstants

    local function findControlsIcon(nametagGui)
        if not nametagGui then return nil end
        local elements = nametagGui:FindFirstChild("Elements")
        local controlsFrame = elements and elements:FindFirstChild("Controls")
        if not controlsFrame then
            controlsFrame = nametagGui:FindFirstChild("Controls", true)
        end
        if not controlsFrame then return nil end
        if controlsFrame:IsA("ImageLabel") or controlsFrame:IsA("ImageButton") then
            return controlsFrame
        end
        local icon = controlsFrame:FindFirstChild("Icon")
        if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
            return icon
        end
        return controlsFrame:FindFirstChildWhichIsA("ImageLabel", true)
            or controlsFrame:FindFirstChildWhichIsA("ImageButton", true)
    end

    local function restoreIcon()
        if controlsIcon and controlsIcon.Parent then
            pcall(function()
                if originalIconColor then controlsIcon.ImageColor3 = originalIconColor end
                if originalIconImage then controlsIcon.Image = originalIconImage end
            end)
        end
        controlsIcon, originalIconColor, originalIconImage = nil, nil, nil
    end

    local function resolveIcon(now)
        if controlsIcon and not controlsIcon.Parent then restoreIcon() end
        if controlsIcon or now < nextIconSearch then return controlsIcon end
        nextIconSearch = now + 0.35
        local char = LP.Character
        if char then
            controlsIcon = findControlsIcon(char:FindFirstChild("NametagGui", true))
        end
        if not controlsIcon then
            local pg = LP:FindFirstChildOfClass("PlayerGui")
            if pg then
                for _, d in ipairs(pg:GetDescendants()) do
                    if d.Name == "NametagGui" then
                        controlsIcon = findControlsIcon(d)
                        if controlsIcon then break end
                    end
                end
            end
        end
        if controlsIcon then
            originalIconColor = controlsIcon.ImageColor3
            originalIconImage = controlsIcon.Image
        end
        return controlsIcon
    end

    local function loadConstants(now)
        if gameConstants or now < nextConstantsSearch then return gameConstants end
        nextConstantsSearch = now + 0.5
        pcall(function()
            local mod = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("CONSTANTS")
            if mod then
                local ok, result = pcall(require, mod)
                if ok and type(result) == "table" then gameConstants = result end
            end
        end)
        return gameConstants
    end

    local function applyIconColor(sendType)
        -- 내 디바이스 아이콘만 색 변경 (다른 플레이어/전체 UI 건드리지 않음)
        if not getgenv().DeviceIconColorEnabled then
            if controlsIcon and originalIconColor then
                pcall(function() controlsIcon.ImageColor3 = originalIconColor end)
            end
            return
        end
        local col = getgenv().DeviceIconColor
        if typeof(col) ~= "Color3" then
            col = Color3.fromRGB(0, 255, 255)
            getgenv().DeviceIconColor = col
        end
        local now = os.clock()
        local icon = resolveIcon(now)
        loadConstants(now)
        if icon and icon.Parent then
            if sendType and gameConstants then
                local images = gameConstants.CONTROLS_IMAGES_CENTERED or gameConstants.CONTROLS_IMAGES
                if type(images) == "table" then
                    local img = images[sendType]
                    if type(img) == "string" then pcall(function() icon.Image = img end) end
                end
            end
            pcall(function() icon.ImageColor3 = col end)
        end
        -- Character NametagGui (월드에 떠 있는 내 이름표 아이콘)
        pcall(function()
            local char = LP.Character
            if not char then return end
            local nt = char:FindFirstChild("NametagGui", true)
            if not nt then return end
            local ic = findControlsIcon(nt)
            if ic then
                if sendType and gameConstants then
                    local images = gameConstants.CONTROLS_IMAGES_CENTERED or gameConstants.CONTROLS_IMAGES
                    if type(images) == "table" then
                        local img = images[sendType]
                        if type(img) == "string" then pcall(function() ic.Image = img end) end
                    end
                end
                ic.ImageColor3 = col
            end
        end)
    end

    while true do
        task.wait(0.15)
        local spoofOn = getgenv().DeviceSpoofEnabled == true
        local colorOn = getgenv().DeviceIconColorEnabled == true
        if not spoofOn and not colorOn then
            if controlsIcon then restoreIcon() end
            continue
        end
        local send
        pcall(function()
            if spoofOn then
                local rem = RS:FindFirstChild("Remotes")
                rem = rem and (rem:FindFirstChild("Replication") or rem)
                local fighter = rem and rem:FindFirstChild("Fighter")
                local setc = fighter and fighter:FindFirstChild("SetControls")
                if setc and setc:IsA("RemoteEvent") then
                    local t = string.lower(tostring(getgenv().DeviceSpoofType or "vr"))
                    if t == "random" then
                        local interval = tonumber(getgenv().DeviceSpoofInterval) or 1
                        if os.clock() - lastRandom >= math.clamp(interval, 0.1, 10) then
                            lastType = types[math.random(1, #types)]
                            lastRandom = os.clock()
                        end
                        send = lastType or types[1]
                    else
                        send = typeMap[t] or "VR"
                    end
                    if os.clock() - lastSend > 0.2 then
                        lastSend = os.clock()
                        setc:FireServer(send)
                    end
                end
            end
        end)
        pcall(applyIconColor, send)
    end
end)


-- =====================================================================
-- [ANGEL WINGS] 천사 날개 비주얼 (로컬 캐릭터)
-- =====================================================================
task.spawn(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer
    local wingFolder = nil
    local flapT = 0

    local function destroyWings()
        if wingFolder then
            pcall(function() wingFolder:Destroy() end)
            wingFolder = nil
        end
        local char = LP.Character
        if char then
            local old = char:FindFirstChild("NH_AngelWings")
            if old then pcall(function() old:Destroy() end) end
        end
    end
    getgenv().NH_DestroyAngelWings = destroyWings

    local function makeFeather(parent, name, size, cframe, color, trans)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = false
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Massless = true
        p.Material = Enum.Material.Neon
        p.Color = color
        p.Transparency = trans or 0.25
        p.Size = size
        p.CFrame = cframe
        p.CastShadow = false
        p.Parent = parent
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Sphere
        mesh.Scale = Vector3.new(1, 0.15, 1)
        mesh.Parent = p
        return p
    end

    local function buildWings(char)
        destroyWings()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp
        if not hrp or not torso then return end

        local scale = math.clamp(tonumber(getgenv().AngelWingsScale) or 1, 0.5, 2.5)
        local col = getgenv().AngelWingsColor or Color3.fromRGB(80, 255, 255)
        local col2 = Color3.new(
            math.clamp(col.R * 0.7 + 0.3, 0, 1),
            math.clamp(col.G * 0.9 + 0.1, 0, 1),
            math.clamp(col.B * 1.0, 0, 1)
        )

        wingFolder = Instance.new("Folder")
        wingFolder.Name = "NH_AngelWings"
        wingFolder.Parent = char

        local attach = Instance.new("Attachment")
        attach.Name = "NH_WingRoot"
        attach.Position = Vector3.new(0, 0.4, 0.35)
        attach.Parent = torso

        -- core glow ball
        local core = Instance.new("Part")
        core.Name = "WingCore"
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(1.2, 1.2, 1.2) * scale
        core.Material = Enum.Material.Neon
        core.Color = Color3.fromRGB(255, 255, 255)
        core.Transparency = 0.35
        core.CanCollide = false
        core.CanQuery = false
        core.Massless = true
        core.CastShadow = false
        core.Parent = wingFolder
        local weldCore = Instance.new("Weld")
        weldCore.Part0 = torso
        weldCore.Part1 = core
        weldCore.C0 = CFrame.new(0, 0.3, 0.5)
        weldCore.Parent = core

        local light = Instance.new("PointLight")
        light.Brightness = 3
        light.Range = 18 * scale
        light.Color = col
        light.Parent = core

        -- particle aura
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "Aura"
        pe.Texture = "rbxassetid://243660364"
        pe.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.5 * scale),
            NumberSequenceKeypoint.new(1, 0.2 * scale)
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        pe.Lifetime = NumberRange.new(0.4, 0.9)
        pe.Rate = 40
        pe.Speed = NumberRange.new(1, 4)
        pe.SpreadAngle = Vector2.new(40, 40)
        pe.LightEmission = 1
        pe.Parent = core

        -- ground ring under character
        local ring = Instance.new("Part")
        ring.Name = "GroundRing"
        ring.Anchored = false
        ring.CanCollide = false
        ring.CanQuery = false
        ring.Massless = true
        ring.Material = Enum.Material.Neon
        ring.Color = col
        ring.Transparency = 0.45
        ring.Size = Vector3.new(6 * scale, 0.12, 6 * scale)
        ring.CastShadow = false
        ring.Parent = wingFolder
        local ringMesh = Instance.new("SpecialMesh")
        ringMesh.MeshType = Enum.MeshType.Cylinder
        ringMesh.Parent = ring
        local weldRing = Instance.new("Weld")
        weldRing.Part0 = hrp
        weldRing.Part1 = ring
        weldRing.C0 = CFrame.new(0, -2.9, 0) * CFrame.Angles(0, 0, math.rad(90))
        weldRing.Parent = ring

        local ringPe = Instance.new("ParticleEmitter")
        ringPe.Texture = "rbxassetid://243660364"
        ringPe.Color = ColorSequence.new(col)
        ringPe.Size = NumberSequence.new(0.3, 0.05)
        ringPe.Transparency = NumberSequence.new(0.2, 1)
        ringPe.Lifetime = NumberRange.new(0.5, 1.0)
        ringPe.Rate = 25
        ringPe.Speed = NumberRange.new(0.5, 2)
        ringPe.SpreadAngle = Vector2.new(180, 180)
        ringPe.LightEmission = 0.9
        ringPe.Parent = ring

        -- build layered wings L/R
        local function wingSide(sign, sideName)
            local base = Instance.new("Part")
            base.Name = sideName .. "Base"
            base.Size = Vector3.new(0.2, 0.2, 0.2)
            base.Transparency = 1
            base.CanCollide = false
            base.CanQuery = false
            base.Massless = true
            base.Parent = wingFolder
            local weld = Instance.new("Weld")
            weld.Name = "WingWeld"
            weld.Part0 = torso
            weld.Part1 = base
            weld.C0 = CFrame.new(sign * 0.4, 0.5, 0.6)
            weld.Parent = base

            -- main wing panels (fan shape)
            local layers = {
                { sz = Vector3.new(0.15, 2.8, 1.4), off = CFrame.new(sign * 1.2, 0.8, -0.2) * CFrame.Angles(0, sign * 0.35, sign * 0.5), t = 0.2 },
                { sz = Vector3.new(0.12, 2.4, 1.2), off = CFrame.new(sign * 1.8, 1.1, -0.1) * CFrame.Angles(0, sign * 0.5, sign * 0.65), t = 0.28 },
                { sz = Vector3.new(0.1, 2.0, 1.0), off = CFrame.new(sign * 2.4, 1.3, 0.05) * CFrame.Angles(0, sign * 0.65, sign * 0.8), t = 0.35 },
                { sz = Vector3.new(0.08, 1.5, 0.8), off = CFrame.new(sign * 2.9, 1.5, 0.15) * CFrame.Angles(0, sign * 0.8, sign * 0.95), t = 0.42 },
                { sz = Vector3.new(0.1, 1.8, 0.9), off = CFrame.new(sign * 1.5, 0.2, -0.3) * CFrame.Angles(0.2, sign * 0.3, sign * 0.4), t = 0.3 },
                { sz = Vector3.new(0.08, 1.4, 0.7), off = CFrame.new(sign * 2.1, -0.1, -0.2) * CFrame.Angles(0.25, sign * 0.45, sign * 0.55), t = 0.38 },
            }
            for i, L in ipairs(layers) do
                local feather = Instance.new("Part")
                feather.Name = sideName .. "F" .. i
                feather.Size = L.sz * scale
                feather.Material = Enum.Material.Neon
                feather.Color = (i % 2 == 0) and col2 or col
                feather.Transparency = L.t
                feather.CanCollide = false
                feather.CanQuery = false
                feather.Massless = true
                feather.CastShadow = false
                feather.Parent = wingFolder
                local sm = Instance.new("SpecialMesh")
                sm.MeshType = Enum.MeshType.Sphere
                sm.Scale = Vector3.new(0.35, 1, 1)
                sm.Parent = feather
                local fw = Instance.new("Weld")
                fw.Part0 = base
                fw.Part1 = feather
                fw.C0 = L.off
                fw.Parent = feather
            end
            return base
        end

        local leftBase = wingSide(-1, "L")
        local rightBase = wingSide(1, "R")
        wingFolder:SetAttribute("Built", true)
    end

    local function ensure()
        if getgenv().AngelWingsEnabled ~= true then
            destroyWings()
            return
        end
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            destroyWings()
            return
        end
        if not wingFolder or not wingFolder.Parent then
            buildWings(char)
        end
    end

    LP.CharacterAdded:Connect(function()
        destroyWings()
        task.wait(0.6)
        if getgenv().AngelWingsEnabled then ensure() end
    end)

    RunService.Heartbeat:Connect(function(dt)
        if getgenv().AngelWingsEnabled ~= true then
            if wingFolder then destroyWings() end
            return
        end
        ensure()
        if not wingFolder or not wingFolder.Parent then return end
        -- gentle flap animation
        flapT = flapT + (dt or 0.016) * 3.2
        local flap = math.sin(flapT) * 0.12
        for _, ch in ipairs(wingFolder:GetChildren()) do
            if ch.Name == "LBase" or ch.Name == "RBase" then
                local w = ch:FindFirstChild("WingWeld")
                if w then
                    local sign = (ch.Name == "LBase") and -1 or 1
                    w.C0 = CFrame.new(sign * 0.4, 0.5 + flap * 0.2, 0.6)
                        * CFrame.Angles(0, 0, sign * flap)
                end
            end
        end
        -- update color live
        local col = getgenv().AngelWingsColor or Color3.fromRGB(80, 255, 255)
        for _, ch in ipairs(wingFolder:GetDescendants()) do
            if ch:IsA("PointLight") then
                ch.Color = col
            elseif ch:IsA("ParticleEmitter") then
                ch.Color = ColorSequence.new(col, Color3.new(1, 1, 1))
            elseif ch:IsA("BasePart") and ch.Name ~= "WingCore" and ch.Transparency < 1 then
                if ch.Name:find("F") or ch.Name == "GroundRing" then
                    ch.Color = col
                end
            end
        end
    end)
end)


pcall(function()
    if Library and Library.Notify then
        -- Library:Notify muted
    end
end)
