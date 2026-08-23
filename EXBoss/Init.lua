---@diagnostic disable: undefined-global
-- =============================================================
-- Init.lua — 启动序列（最后加载）
-- =============================================================

local ExwindTools = _G.ExwindTools
if not ExwindTools then
    return
end

ExBoss._initLoaded = true

local _autoCAAWasForced = false
local _autoCAAPrevValue = nil
local _autoCAAVolumeMuted = false
local _autoCAAPrevVolumes = {}
local _autoCAACurrentEncounterID = nil

local function EnsureGeneralDB()
    EXBOSS12S2 = EXBOSS12S2 or {}
    EXBOSS12S2.ui = EXBOSS12S2.ui or {}
    EXBOSS12S2.ui.general = EXBOSS12S2.ui.general or {}
    local g = EXBOSS12S2.ui.general
    if g.bossAlertsEnabledMplus == nil then
        g.bossAlertsEnabledMplus = true
    else
        g.bossAlertsEnabledMplus = (g.bossAlertsEnabledMplus == true)
    end
    if g.bossAlertsEnabledRaid == nil then
        g.bossAlertsEnabledRaid = false
    else
        g.bossAlertsEnabledRaid = (g.bossAlertsEnabledRaid == true)
    end
    if g.autoDisableCAAInBoss == nil then
        g.autoDisableCAAInBoss = false
    else
        g.autoDisableCAAInBoss = (g.autoDisableCAAInBoss == true)
    end
    if g.hideTankBossAlertsForDps == nil then
        g.hideTankBossAlertsForDps = true
    else
        g.hideTankBossAlertsForDps = (g.hideTankBossAlertsForDps == true)
    end
    if g.hideTankBossAlertsForHeal == nil then
        g.hideTankBossAlertsForHeal = false
    else
        g.hideTankBossAlertsForHeal = (g.hideTankBossAlertsForHeal == true)
    end
    if g.encounterWarningsEnabled == nil then
        g.encounterWarningsEnabled = true
    else
        g.encounterWarningsEnabled = (g.encounterWarningsEnabled == true)
    end
    if g.encounterWarningSoundsEnabled == nil then
        g.encounterWarningSoundsEnabled = true
    else
        g.encounterWarningSoundsEnabled = (g.encounterWarningSoundsEnabled == true)
    end
    if g.disableBlizzardEncounterTimeline == nil then
        g.disableBlizzardEncounterTimeline = false
    else
        g.disableBlizzardEncounterTimeline = (g.disableBlizzardEncounterTimeline == true)
    end
    return g
end

local function IsFixedTimelineEncounterForCAA(encounterID)
    local id = tonumber(encounterID)
    local fixed = _G.EXBOSS_FIXED_TIMELINE_ENCOUNTERS
    if type(fixed) ~= "table" then
        return false, "no fixed table"
    end
    if id and fixed[id] == true then
        return true, "fixed=true(id)"
    end
    if encounterID ~= nil and fixed[encounterID] == true then
        return true, "fixed=true(raw)"
    end
    return false, "fixed=false"
end

local function ReadCAAEnabled()
    local ok, value
    if C_CVar and C_CVar.GetCVar then
        ok, value = pcall(C_CVar.GetCVar, "CAAEnabled")
    end
    if (not ok or value == nil) and type(GetCVar) == "function" then
        ok, value = pcall(GetCVar, "CAAEnabled")
    end
    if not ok then return nil end
    if value == nil then return nil end
    local s = tostring(value)
    if s == "" then return nil end
    return s
end

local function WriteCAAEnabled(value)
    local s = tostring(value or "")
    if s == "" then return false end
    local ok = false
    if C_CVar and C_CVar.SetCVar then
        ok = pcall(C_CVar.SetCVar, "CAAEnabled", s)
        if ok then
            return true
        end
    end
    if type(SetCVar) == "function" then
        ok = pcall(SetCVar, "CAAEnabled", s)
        if ok then
            return true
        end
    end
    return false
end

local function ReadGenericCVar(name)
    local key = tostring(name or "")
    if key == "" then return nil end
    local ok, value
    if C_CVar and C_CVar.GetCVar then
        ok, value = pcall(C_CVar.GetCVar, key)
    end
    if (not ok or value == nil) and type(GetCVar) == "function" then
        ok, value = pcall(GetCVar, key)
    end
    if not ok or value == nil then return nil end
    local s = tostring(value)
    if s == "" then return nil end
    return s
end

local function WriteGenericCVar(name, value)
    local key = tostring(name or "")
    local s = tostring(value or "")
    if key == "" or s == "" then return false end
    local ok = false
    if C_CVar and C_CVar.SetCVar then
        ok = pcall(C_CVar.SetCVar, key, s)
        if ok then return true end
    end
    if type(SetCVar) == "function" then
        ok = pcall(SetCVar, key, s)
        if ok then return true end
    end
    return false
end


-- 用户保存的预警选择是唯一真源。监听三个 CVar 并在 DBM 等外部插件
-- 改动后恢复它们，不能反过来用外部 CVar 覆盖用户的选择。
local PROTECTED_ENCOUNTER_CVARS = {
    encounterWarningsEnabled = true,
    encounterTimelineEnabled = true,
    Sound_EnableEncounterWarningsSounds = true,
}

local function ApplySoundNumChannels128()
    local current = ReadGenericCVar("Sound_NumChannels")
    if current ~= "128" then
        WriteGenericCVar("Sound_NumChannels", "128")
    end
end

local function GetDesiredEncounterCVarValue(name)
    local key = tostring(name or "")
    local g = EnsureGeneralDB()
    if key == "encounterWarningsEnabled" then
        return (g.encounterWarningsEnabled ~= false) and "1" or "0"
    end
    if key == "encounterTimelineEnabled" then
        return (g.disableBlizzardEncounterTimeline == true) and "0" or "1"
    end
    if key == "Sound_EnableEncounterWarningsSounds" then
        return (g.encounterWarningSoundsEnabled ~= false) and "1" or "2"
    end
    return nil
end

local function ApplyProtectedEncounterCVar(name)
    local key = tostring(name or "")
    if not PROTECTED_ENCOUNTER_CVARS[key] then
        return
    end
    local desired = GetDesiredEncounterCVarValue(key)
    if not desired then
        return
    end
    local current = ReadGenericCVar(key)
    if current ~= desired then
        WriteGenericCVar(key, desired)
    end
end

local function ScheduleProtectedEncounterCVarRepair(name)
    local key = tostring(name or "")
    if not PROTECTED_ENCOUNTER_CVARS[key] then
        return
    end
    C_Timer.After(0.1, function()
        ApplyProtectedEncounterCVar(key)
    end)
    C_Timer.After(0.5, function()
        ApplyProtectedEncounterCVar(key)
    end)
end

local function ScheduleAllProtectedEncounterCVarRepairs()
    ScheduleProtectedEncounterCVarRepair("encounterWarningsEnabled")
    ScheduleProtectedEncounterCVarRepair("encounterTimelineEnabled")
    ScheduleProtectedEncounterCVarRepair("Sound_EnableEncounterWarningsSounds")
end

local function GetCAACategoryRange()
    local minValue, maxValue = 0, 8
    local meta = Enum and Enum.CombatAudioAlertCategoryMeta
    if type(meta) == "table" then
        minValue = tonumber(meta.MinValue) or minValue
        maxValue = tonumber(meta.MaxValue) or maxValue
    end
    return minValue, maxValue
end

local function CanUseCAAApi()
    return C_CombatAudioAlert
        and type(C_CombatAudioAlert.GetCategoryVolume) == "function"
        and type(C_CombatAudioAlert.SetCategoryVolume) == "function"
end

local function MuteCAAByCategoryVolumes()
    if _autoCAAVolumeMuted then
        return true
    end
    if not CanUseCAAApi() then
        return false
    end

    wipe(_autoCAAPrevVolumes)
    local minValue, maxValue = GetCAACategoryRange()
    for category = minValue, maxValue do
        local okGet, vol = pcall(C_CombatAudioAlert.GetCategoryVolume, category)
        if okGet and tonumber(vol) ~= nil then
            _autoCAAPrevVolumes[category] = tonumber(vol)
        end
        pcall(C_CombatAudioAlert.SetCategoryVolume, category, 0)
    end
    _autoCAAVolumeMuted = true
    return true
end

local function RestoreCAAByCategoryVolumes()
    if not _autoCAAVolumeMuted then
        return true
    end
    if not CanUseCAAApi() then
        return false
    end

    local minValue, maxValue = GetCAACategoryRange()
    for category = minValue, maxValue do
        local restoreVol = tonumber(_autoCAAPrevVolumes[category])
        if restoreVol == nil then
            local okGet, currentVol = pcall(C_CombatAudioAlert.GetCategoryVolume, category)
            if okGet and tonumber(currentVol) ~= nil then
                restoreVol = tonumber(currentVol)
            else
                restoreVol = 100
            end
        end
        pcall(C_CombatAudioAlert.SetCategoryVolume, category, restoreVol)
    end
    wipe(_autoCAAPrevVolumes)
    _autoCAAVolumeMuted = false
    return true
end

function ExBoss.ApplyBossAutoCAASetting(forceIsBossEncounter)
    local g = EnsureGeneralDB()
    local enabled = (g.autoDisableCAAInBoss == true)
    local isBoss = (forceIsBossEncounter == true)
    if forceIsBossEncounter == nil and ExwindTools and ExwindTools.State then
        isBoss = (ExwindTools.State.IsBossEncounter == true)
    end
    local shouldMuteBecauseFixed = false
    local muteReason = "n/a"
    if isBoss then
        shouldMuteBecauseFixed, muteReason = IsFixedTimelineEncounterForCAA(_autoCAACurrentEncounterID)
    end

    if not enabled then
        if _autoCAAVolumeMuted then
            RestoreCAAByCategoryVolumes()
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        elseif _autoCAAWasForced then
            WriteCAAEnabled(_autoCAAPrevValue or "1")
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        end
        return
    end

    if isBoss and not shouldMuteBecauseFixed then
        if _autoCAAVolumeMuted then
            RestoreCAAByCategoryVolumes()
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        elseif _autoCAAWasForced then
            WriteCAAEnabled(_autoCAAPrevValue or "1")
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        end
        return
    end

    if isBoss then
        local muted = MuteCAAByCategoryVolumes()
        if muted then
            _autoCAAWasForced = true
            return
        end
        if not _autoCAAWasForced then
            _autoCAAPrevValue = ReadCAAEnabled()
        end
        WriteCAAEnabled("0")
        _autoCAAWasForced = true
    else
        if _autoCAAVolumeMuted then
            RestoreCAAByCategoryVolumes()
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        elseif _autoCAAWasForced then
            WriteCAAEnabled(_autoCAAPrevValue or "1")
            _autoCAAWasForced = false
            _autoCAAPrevValue = nil
        end
    end
end

if ExwindTools and ExwindTools.WatchState then
    ExwindTools:WatchState("IsBossEncounter", "ExBoss_AutoCAA_Toggle", function(newValue)
        if ExBoss and ExBoss.ApplyBossAutoCAASetting then
            ExBoss.ApplyBossAutoCAASetting(newValue == true)
        end
    end)
    C_Timer.After(0.2, function()
        if ExBoss and ExBoss.ApplyBossAutoCAASetting then
            ExBoss.ApplyBossAutoCAASetting()
        end
    end)
end

-- ── ADDON_LOADED：初始化 DB ───────────────────────────────────
ExwindTools:RegisterEvent("ADDON_LOADED", "ExBoss_Init_Loaded", function(event, addonName)
    local name = tostring(addonName or ""):lower()
    if name ~= "exboss" then return end

    if ExBoss.DB and ExBoss.DB.Init then
        ExBoss.DB:Init()
    end

    -- DB 已经初始化后，强制审计全部标准显示合同。PreviewSurface 是页面首次
    -- mount 时按 Dock 懒创建的对象，加载期不得要求它已存在；页面在完成
    -- preview mount 后再以 requireSurface=true 审计当前模块。
    -- 每个页面首次 Grid Render 还会由 StandardModulePage 校验实际 Slider 控件。
    local ui = ExwindTools.UI
    if not ui or type(ui.AssertRegisteredDisplayModules) ~= "function" then
        error("EXBoss requires EXUI standard display contract auditor", 2)
    end
    ui:AssertRegisteredDisplayModules({
        "ExBoss.TimerBar",
        "ExBoss.IconAlert",
        "ExBoss.Countdown",
        "ExBoss.FlashTextMedium",
        "ExBoss.CastProgressBar",
        "ExBoss.ExtraShieldBar",
        "ExBoss.RingProgress",
        "ExBoss.BunBar",
        "ExBoss.Tools.MythicCast",
        "ExBoss.Tools.InterruptTracker",
    }, {
        requirePage = true,
        requireSlider = true,
    })

    -- EXBOSS12S2 is now loaded; re-apply the saved locale mode so _currentLocale
    -- reflects the user's choice instead of the load-time default.
    if type(EXBOSS12S2) == "table" and type(EXBOSS12S2.locale) == "table" then
        ExBoss:SetLocaleMode(EXBOSS12S2.locale.mode)
    end

    if ReadGenericCVar("encounterWarningsEnabled") == nil then
        WriteGenericCVar("encounterWarningsEnabled", "1")
    end
    if ReadGenericCVar("encounterTimelineEnabled") == nil then
        WriteGenericCVar("encounterTimelineEnabled", "1")
    end
    if ReadGenericCVar("Sound_EnableEncounterWarningsSounds") == nil then
        WriteGenericCVar("Sound_EnableEncounterWarningsSounds", "1")
    end
    ApplySoundNumChannels128()
    ScheduleAllProtectedEncounterCVarRepairs()
    C_Timer.After(0.1, ApplySoundNumChannels128)
    C_Timer.After(1.0, ApplySoundNumChannels128)

end)

ExwindTools:RegisterEvent("CVAR_UPDATE", "ExBoss_EncounterCVarGuard", function(event, cvarName)
    local key = tostring(cvarName or "")
    if PROTECTED_ENCOUNTER_CVARS[key] then
        ScheduleProtectedEncounterCVarRepair(key)
    end
end)

ExwindTools:RegisterEvent("PLAYER_ENTERING_WORLD", "ExBoss_EncounterCVarGuardPEW", function()
    ScheduleAllProtectedEncounterCVarRepairs()
    ApplySoundNumChannels128()
    C_Timer.After(0.5, ApplySoundNumChannels128)
end)

-- ── 进本预热：提前算好当前副本内所有 boss 的静态配置缓存 ────────
ExwindTools:RegisterEvent("PLAYER_ENTERING_WORLD", "ExBoss_PrewarmEncounterConfigs", function()
    local scheduler = ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if not (scheduler and scheduler.PrewarmEncounterConfigs) then
        return
    end
    local instanceID = select(8, GetInstanceInfo())
    scheduler:PrewarmEncounterConfigs(instanceID)
end)

ExwindTools:RegisterEvent("ADDON_LOADED", "ExBoss_EncounterCVarGuardDBM", function(event, addonName)
    local name = tostring(addonName or ""):lower()
    if name == "dbm-core" or name == "dbm-gui" then
        ScheduleAllProtectedEncounterCVarRepairs()
    end
end)

-- ── ENCOUNTER_START：启动计时引擎 ────────────────────────────
ExwindTools:RegisterEvent("ENCOUNTER_START", "ExBoss_Init_EncStart", function(_, encounterID)
    _autoCAACurrentEncounterID = tonumber(encounterID) or encounterID
    if ExBoss and ExBoss.ApplyBossAutoCAASetting then
        ExBoss.ApplyBossAutoCAASetting(true)
    end
    if ExBoss.Timeline and ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.HandleEncounterStart then
        ExBoss.Timeline.Scheduler:HandleEncounterStart(encounterID, "exwind")
        return
    end
    if ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.StartBoss then
        ExBoss.Timeline.Scheduler:StartBoss(encounterID)
    end
end)

-- ── ENCOUNTER_END：停止计时引擎 ──────────────────────────────
ExwindTools:RegisterEvent("ENCOUNTER_END", "ExBoss_Init_EncEnd", function()
    _autoCAACurrentEncounterID = nil
    if ExBoss and ExBoss.ApplyBossAutoCAASetting then
        ExBoss.ApplyBossAutoCAASetting(false)
    end
    if ExBoss.Timeline and ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.HandleEncounterEnd then
        ExBoss.Timeline.Scheduler:HandleEncounterEnd("exwind")
        return
    end
    if ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.EndBoss then
        ExBoss.Timeline.Scheduler:EndBoss()
    end
end)
