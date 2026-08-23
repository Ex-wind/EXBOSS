---@diagnostic disable: undefined-global

do
    local ExwindTools = _G.ExwindTools
    local ENCOUNTER_ID = 3101
    local VULNERABILITY_SEVERITY = 1
    local MAX_VULNERABILITY_TIMES = 4
    local INITIAL_DAMAGE_REDUCTION = 80
    local DAMAGE_REDUCTION_PER_LAYER = 20
    local VULNERABILITY_KEY = "exboss:3101:vulnerability"
    local EFFECTIVE_HEALTH_BAR_KEY = "exboss:3101:effective-health"
    local PRIMARY_BOSS_UNIT = "boss1"
    local SECONDARY_BOSS_UNIT = "boss2"
    local SECONDARY_HEALTH_SHARE = 0.80
    local DISPLAY_MAX_PERCENT = 150
    local encounterActive = false
    local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, key) return key end })

    local function GetExtraShieldBar()
        return ExBoss and ExBoss.UI and ExBoss.UI.ExtraShieldBar or nil
    end

    local function GetDamageReduction()
        local state = ExwindTools and ExwindTools.State or nil
        return math.max(0, math.min(80, tonumber(state and state["3101dmgtaken"]) or 0))
    end

    local function HideEffectiveHealthBar()
        local bar = GetExtraShieldBar()
        if bar and type(bar.Hide) == "function" then
            bar:Hide(EFFECTIVE_HEALTH_BAR_KEY)
        end
    end

    local function RefreshEffectiveHealthBar()
        if not encounterActive or not (UnitExists and UnitExists(PRIMARY_BOSS_UNIT) and UnitExists(SECONDARY_BOSS_UNIT)) then
            HideEffectiveHealthBar()
            return
        end

        local bar = GetExtraShieldBar()
        if not (bar and type(bar.Update) == "function" and UnitHealth and UnitHealthMax) then
            return
        end

        local reduction = GetDamageReduction()
        -- 临时额外信息条：未来由正式的 BOSS 额外显示面板接管。
        -- 原生 StatusBar 直接计算 boss1当前血量 / boss2最大血量；布局宽度乘以
        -- 1 / (80% * (1 - 减伤))，因此可视值严格等于「首领有效生命 / (小Boss最大生命*80%)」。
        -- boss1/boss2 的秘密生命值仅直传给 StatusBar，Lua 不读取、比较或运算它们。
        bar:Update(EFFECTIVE_HEALTH_BAR_KEY, {
            name = L["有效血量对比"],
            icon = 136197,
            value = UnitHealth(PRIMARY_BOSS_UNIT),
            maxValue = UnitHealthMax(SECONDARY_BOSS_UNIT),
            secretComparison = true,
            hasNativeValue = true,
            fillScale = 1 / (SECONDARY_HEALTH_SHARE * (1 - reduction / 100)),
            displayMaximum = DISPLAY_MAX_PERCENT,
            text = "100% / 110%",
        })
    end

    local function SetVulnerabilityState(times, damageTaken)
        if not (ExwindTools and type(ExwindTools.UpdateState) == "function") then
            return
        end
        ExwindTools:UpdateState("3101dmgtimes", tonumber(times) or 0)
        ExwindTools:UpdateState("3101dmgtaken", tonumber(damageTaken) or 0)
    end

    local function StopVulnerability()
        if ExBoss and type(ExBoss.StopVulnerability) == "function" then
            ExBoss:StopVulnerability(VULNERABILITY_KEY)
        end
    end

    local function EnterVulnerability()
        if not encounterActive then
            return
        end

        local state = ExwindTools and ExwindTools.State or nil
        local currentTimes = tonumber(state and state["3101dmgtimes"]) or 0
        if currentTimes >= MAX_VULNERABILITY_TIMES then
            return
        end

        local nextTimes = currentTimes + 1
        local nextDamageTaken = math.max(0, INITIAL_DAMAGE_REDUCTION - nextTimes * DAMAGE_REDUCTION_PER_LAYER)
        SetVulnerabilityState(nextTimes, nextDamageTaken)
        RefreshEffectiveHealthBar()

        if ExBoss and type(ExBoss.ShowVulnerability) == "function" then
            ExBoss:ShowVulnerability(100, 1.7, 20, {
                key = VULNERABILITY_KEY,
                channel = "central_medium",
            })
        end
    end

    local function OnEncounterWarning(_, encounterWarningInfo)
        -- 此处只允许读取 severity；不访问 encounterWarningInfo 的任何其他字段。
        local severity = encounterWarningInfo and encounterWarningInfo.severity
        if severity == VULNERABILITY_SEVERITY then
            EnterVulnerability()
        end
    end

    if ExwindTools and type(ExwindTools.RegisterEvent) == "function" then
        ExwindTools:RegisterEvent("ENCOUNTER_START", "ExBoss_3101_Vulnerability_Start", function(_, encounterID)
            if tonumber(encounterID) ~= ENCOUNTER_ID then
                return
            end
            encounterActive = true
            StopVulnerability()
            SetVulnerabilityState(0, INITIAL_DAMAGE_REDUCTION)
            RefreshEffectiveHealthBar()
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.2, RefreshEffectiveHealthBar)
            end
        end)

        ExwindTools:RegisterEvent("ENCOUNTER_END", "ExBoss_3101_Vulnerability_End", function(_, encounterID)
            if tonumber(encounterID) ~= ENCOUNTER_ID then
                return
            end
            encounterActive = false
            StopVulnerability()
            SetVulnerabilityState(0, 0)
            HideEffectiveHealthBar()
        end)

        ExwindTools:RegisterEvent("ENCOUNTER_WARNING", "ExBoss_3101_Vulnerability_Warning", OnEncounterWarning)
        ExwindTools:RegisterEvent("UNIT_HEALTH_FREQUENT", "ExBoss_3101_EffectiveHealth_Refresh", function(_, unit)
            if unit == PRIMARY_BOSS_UNIT or unit == SECONDARY_BOSS_UNIT then
                RefreshEffectiveHealthBar()
            end
        end)
        ExwindTools:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "ExBoss_3101_EffectiveHealth_Engage", RefreshEffectiveHealthBar)
    end
end

local R = ExBoss and ExBoss.BossEncounters
if not R then return end

R:Register({
    encounterID = 3101,
    dungeon = { key = "murder_row", name = "Murder Row", zhCN = "密谋小径" },
    boss = { key = "kystia_manaheart", name = "Kystia Manaheart", zhCN = "凯斯媞亚·魔力之心" },
    healthThresholds = {
        -- 此战的阶段目标是 boss2（咬咬），不是主首领 boss1。
        { unit = "boss2", threshold = 20, preset = "phase_transition" },
    },
    phaseAlerts = {},
    vulnerability = {},
    extras = {},
})
