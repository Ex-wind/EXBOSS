---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI
if not EXUI then return end
local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, k) return k end })

ExBoss.UI.Panel.GeneralOverviewPage = ExBoss.UI.Panel.GeneralOverviewPage or {}
local Page = ExBoss.UI.Panel.GeneralOverviewPage

local MODULE_KEY = "ExBoss.GeneralOverview"

local CHANNEL_OPTIONS = {
    { "Master",   "Master" },
    { "SFX",      "SFX" },
    { "Dialog",   "Dialog" },
    { "Music",    "Music" },
    { "Ambience", "Ambience" },
}

local BAR_MODE_OPTIONS = {
    { L["仅束状条"], "bun" },
    { L["两者都启用"], "both" },
    { L["仅计时条"], "timer" },
    { L["两者都隐藏"], "none" },
}

local BAR_SOURCE_OPTIONS = {
    { L["Boss 技能"], "boss" },
    { L["小怪技能"], "trash" },
}

local function ReadCVarValue(name)
    local key = tostring(name or "")
    if key == "" then
        return nil
    end

    local ok, value
    if C_CVar and C_CVar.GetCVar then
        ok, value = pcall(C_CVar.GetCVar, key)
    end
    if (not ok or value == nil) and type(GetCVar) == "function" then
        ok, value = pcall(GetCVar, key)
    end
    if not ok or value == nil then
        return nil
    end
    local s = tostring(value)
    if s == "" then
        return nil
    end
    return s
end

local function WriteCVarValue(name, value)
    local key = tostring(name or "")
    local s = tostring(value or "")
    if key == "" or s == "" then
        return false
    end

    local ok = false
    if C_CVar and C_CVar.SetCVar then
        ok = pcall(C_CVar.SetCVar, key, s)
        if ok then
            return true
        end
    end
    if type(SetCVar) == "function" then
        ok = pcall(SetCVar, key, s)
        if ok then
            return true
        end
    end
    return false
end

local function IsEncounterWarningsEnabled()
    local value = ReadCVarValue("encounterWarningsEnabled")
    if value == nil then
        WriteCVarValue("encounterWarningsEnabled", "1")
        return true
    end
    return value ~= "0"
end

local function IsEncounterTimelineEnabled()
    local value = ReadCVarValue("encounterTimelineEnabled")
    if value == nil then
        WriteCVarValue("encounterTimelineEnabled", "1")
        return true
    end
    return value ~= "0"
end

local function IsEncounterWarningSoundsEnabled()
    local value = ReadCVarValue("Sound_EnableEncounterWarningsSounds")
    if value == nil then
        return true
    end
    return value ~= "2"
end

local CARD_GUI = {
    version = 1,
    title = L["通用设置"],
    description = L["时间轴显示、音频输出和自动对话。"],
    cards = {
        { id = "general", title = L["通用设置"], content = { kind = "grid", items = {
            { key = "barDisplayMode", type = "dropdown", x = 1, y = 1, w = 63, h = 6, label = L["时间轴样式选择"], items = BAR_MODE_OPTIONS, parentKey = "ui.general" },
            { key = "bunBarSources", type = "multiselect", x = 68, y = 1, w = 63, h = 6, label = L["束状条显示"], items = BAR_SOURCE_OPTIONS, parentKey = "ui.general" },
            { key = "timerBarSources", type = "multiselect", x = 135, y = 1, w = 63, h = 6, label = L["计时条显示"], items = BAR_SOURCE_OPTIONS, parentKey = "ui.general" },
            { key = "disableBlizzardEncounterTimeline", type = "checkbox", x = 1, y = 8, w = 76, h = 6, label = L["关闭暴雪原生计时条"], parentKey = "ui.general" },
            { key = "disableEXBossInRaid", type = "checkbox", x = 1, y = 15, w = 76, h = 6, label = L["团本中禁用 EXBoss"], parentKey = "ui.general" },
            { key = "disableAuraSoundRegistration", type = "checkbox", x = 1, y = 22, w = 90, h = 6, label = L["关闭光环语音注册（重载后生效）"], parentKey = "voice.global" },
            { key = "hideTankBossAlertsForDps", type = "checkbox", x = 1, y = 29, w = 76, h = 6, label = L["DPS职责下不提示坦克技能"], parentKey = "ui.general" },
            { key = "hideTankBossAlertsForHeal", type = "checkbox", x = 1, y = 36, w = 76, h = 6, label = L["治疗职责下不提示坦克技能"], parentKey = "ui.general" },
            { key = "showSpellOccurrenceCount", type = "checkbox", x = 1, y = 43, w = 73, h = 6, label = L["法术名称显示次数"], parentKey = "ui.general" },
            { key = "encounterWarningsEnabled", type = "checkbox", x = 1, y = 50, w = 86, h = 6, label = L["开启暴雪中央文字预警（注意：如果关闭会导致语音不工作）"], parentKey = "ui.general" },
            { key = "encounterWarningSoundsEnabled", type = "checkbox", x = 1, y = 57, w = 127, h = 6, label = L["开启中央文字预警提示音（预设叮一声）"], parentKey = "ui.general" },
            { key = "enableBlizzardHintCountdown", type = "checkbox", x = 1, y = 64, w = 80, h = 6, label = L["暴雪时间轴模式启用5秒倒数"], parentKey = "ui.general" },
        } } },
        { id = "audio", title = L["音频输出选项"], content = { kind = "grid", items = {
            { key = "channel", type = "dropdown", x = 1, y = 1, w = 48, h = 6, label = L["输出通道"], items = CHANNEL_OPTIONS, parentKey = "voice.global" },
            { key = "volume", type = "slider", x = 55, y = 1, w = 44, h = 6, label = L["全局音量"], min = 0, max = 1, step = 0.01, parentKey = "voice.global" },
            { key = "label_5567", type = "label", x = 1, y = 13, w = 190, h = 6, label = L["注意:声音大小请勿在此修改,若要调整声音大小请在ESC的设置面板修改"] },
        } } },
        { id = "auto_gossip", title = L["自动对话"], content = { kind = "grid", items = {
            { key = "autoGossipEnabled", type = "checkbox", x = 1, y = 1, w = 76, h = 6, label = L["启用自动对话"], parentKey = "autoGossip", subKey = "enabled" },
            { key = "autoGossipAcademyBuff", type = "checkbox", x = 1, y = 8, w = 102, h = 6, label = L["[大秘境] 自动对话学院(AA)BUFF"], parentKey = "autoGossip", subKey = "academyBuff" },
            { key = "autoGossipCaveCauldron", type = "checkbox", x = 1, y = 15, w = 102, h = 6, label = L["[大秘境] 自动对话洞窟(MC)大锅BUFF"], parentKey = "autoGossip", subKey = "caveCauldron" },
            { key = "autoGossipPosRescue", type = "checkbox", x = 1, y = 22, w = 102, h = 6, label = L["[大秘境] 自动对话萨隆矿坑救人(POS)"], parentKey = "autoGossip", subKey = "posRescue" },
            { key = "autoGossipNpxBuff", type = "checkbox", x = 1, y = 29, w = 102, h = 6, label = L["[大秘境] 自动对话节点(NPX)BUFF"], parentKey = "autoGossip", subKey = "npxBuff" },
        } } },
    },
}

local function NormalizeBarDisplayMode(mode)
    local m = tostring(mode or ""):lower()
    if m == "timer" or m == "bun" or m == "both" or m == "none" then
        return m
    end
    return "bun"
end

local function EnsureBarSourceSelections(selections)
    if type(selections) ~= "table" then
        return { boss = true, trash = true }
    end
    selections.boss = (selections.boss == true)
    selections.trash = (selections.trash == true)
    return selections
end

local function EnsureRootDB()
    EXBOSS12S2 = EXBOSS12S2 or {}
    EXBOSS12S2.ui = EXBOSS12S2.ui or {}
    EXBOSS12S2.ui.general = EXBOSS12S2.ui.general or {}
    EXBOSS12S2.voice = EXBOSS12S2.voice or {}
    EXBOSS12S2.voice.global = EXBOSS12S2.voice.global or {}
    EXBOSS12S2.autoGossip = EXBOSS12S2.autoGossip or {}

    local general = EXBOSS12S2.ui.general
    general.barDisplayMode = NormalizeBarDisplayMode(general.barDisplayMode)
    general.bunBarSources = EnsureBarSourceSelections(general.bunBarSources)
    general.timerBarSources = EnsureBarSourceSelections(general.timerBarSources)
    if general.bossAlertsEnabledMplus == nil then
        general.bossAlertsEnabledMplus = true
    else
        general.bossAlertsEnabledMplus = (general.bossAlertsEnabledMplus == true)
    end
    -- The visible checkbox is deliberately named as the user's action
    -- (disable in raid).  Preserve the old positive flag for one-time
    -- migration only, without deleting or rewriting it.
    if general.disableEXBossInRaid == nil then
        general.disableEXBossInRaid = (general.bossAlertsEnabledRaid ~= true)
    else
        general.disableEXBossInRaid = (general.disableEXBossInRaid == true)
    end
    if general.hideTankBossAlertsForDps == nil then
        general.hideTankBossAlertsForDps = true
    else
        general.hideTankBossAlertsForDps = (general.hideTankBossAlertsForDps == true)
    end
    if general.hideTankBossAlertsForHeal == nil then
        general.hideTankBossAlertsForHeal = false
    else
        general.hideTankBossAlertsForHeal = (general.hideTankBossAlertsForHeal == true)
    end
    if general.showSpellOccurrenceCount == nil then
        general.showSpellOccurrenceCount = true
    else
        general.showSpellOccurrenceCount = (general.showSpellOccurrenceCount == true)
    end
    if general.enableBlizzardHintCountdown == nil then
        general.enableBlizzardHintCountdown = true
    else
        general.enableBlizzardHintCountdown = (general.enableBlizzardHintCountdown == true)
    end
    -- These saved choices are the authority.  Read the live CVar only once
    -- for a brand-new setting; afterwards Init.lua restores this value when
    -- another addon changes the CVar.  Reading it every UI refresh would
    -- overwrite a click with the CVar's old value before we can apply it.
    if general.encounterWarningsEnabled == nil then
        general.encounterWarningsEnabled = IsEncounterWarningsEnabled()
    else
        general.encounterWarningsEnabled = (general.encounterWarningsEnabled == true)
    end
    if general.encounterWarningSoundsEnabled == nil then
        general.encounterWarningSoundsEnabled = IsEncounterWarningSoundsEnabled()
    else
        general.encounterWarningSoundsEnabled = (general.encounterWarningSoundsEnabled == true)
    end
    if general.disableBlizzardEncounterTimeline == nil then
        general.disableBlizzardEncounterTimeline = not IsEncounterTimelineEnabled()
    else
        general.disableBlizzardEncounterTimeline = (general.disableBlizzardEncounterTimeline == true)
    end

    local voice = EXBOSS12S2.voice.global
    voice.channel = tostring(voice.channel or "Master")
    voice.volume = tonumber(voice.volume) or 1.0
    voice.disableAuraSoundRegistration = (voice.disableAuraSoundRegistration == true)
    if voice.volume < 0 then voice.volume = 0 end
    if voice.volume > 1 then voice.volume = 1 end

    local autoGossip = EXBOSS12S2.autoGossip
    if autoGossip.enabled == nil then
        autoGossip.enabled = true
    else
        autoGossip.enabled = (autoGossip.enabled == true)
    end
    if autoGossip.academyBuff == nil then
        autoGossip.academyBuff = true
    else
        autoGossip.academyBuff = (autoGossip.academyBuff == true)
    end
    if autoGossip.caveCauldron == nil then
        autoGossip.caveCauldron = true
    else
        autoGossip.caveCauldron = (autoGossip.caveCauldron == true)
    end
    if autoGossip.posRescue == nil then
        autoGossip.posRescue = true
    else
        autoGossip.posRescue = (autoGossip.posRescue == true)
    end
    if autoGossip.npxBuff == nil then
        autoGossip.npxBuff = true
    else
        autoGossip.npxBuff = (autoGossip.npxBuff == true)
    end

    return EXBOSS12S2
end

local function IsTimerBarEnabledByGlobal()
    local root = EnsureRootDB()
    local mode = NormalizeBarDisplayMode(root.ui.general.barDisplayMode)
    return mode == "both" or mode == "timer"
end

local function IsBunBarEnabledByGlobal()
    local root = EnsureRootDB()
    local mode = NormalizeBarDisplayMode(root.ui.general.barDisplayMode)
    return mode == "both" or mode == "bun"
end

local function ApplyBarModeChange()
    if not IsBunBarEnabledByGlobal() and ExBoss and ExBoss.UI and ExBoss.UI.BunBar and ExBoss.UI.BunBar.ReleaseAll then
        ExBoss.UI.BunBar:ReleaseAll()
    end
    if not IsTimerBarEnabledByGlobal() and ExBoss and ExBoss.UI and ExBoss.UI.TimerBar and ExBoss.UI.TimerBar.ReleaseAll then
        ExBoss.UI.TimerBar:ReleaseAll()
    end

    local sched = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if sched and sched._running and sched.StartBoss and sched._encounterID then
        sched:StartBoss(sched._encounterID)
    end
end

local function ApplyVoiceOverrides()
    if ExBoss and ExBoss.Voice and ExBoss.Voice.Engine and ExBoss.Voice.Engine.ApplyEventOverridesToAPI then
        ExBoss.Voice.Engine:ApplyEventOverridesToAPI()
    end
end

local function ApplySpellCountDisplayChange()
    local sched = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if sched and sched._running and sched.StartBoss and sched._encounterID then
        sched:StartBoss(sched._encounterID)
    end
end

local function ApplyBlizzardHintCountdownChange()
    local sched = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    if sched and sched._running and sched.StartBoss and sched._encounterID then
        sched:StartBoss(sched._encounterID)
    end
end

local function ApplyBossSceneToggleChange()
    local sched = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler
    local bossCfg = ExBoss and ExBoss.BossConfig
    local sceneEnabled = true
    if bossCfg and type(bossCfg.IsCurrentSceneEnabled) == "function" then
        local ok, enabled = pcall(bossCfg.IsCurrentSceneEnabled, bossCfg)
        if ok then
            sceneEnabled = (enabled ~= false)
        end
    end

    if sceneEnabled == false then
        if sched and sched.EndBoss then
            sched:EndBoss()
        end
        if ExBoss and ExBoss.Voice and ExBoss.Voice.Engine and ExBoss.Voice.Engine.ClearEventOverridesInMemory then
            ExBoss.Voice.Engine:ClearEventOverridesInMemory("boss scene disabled")
        end
    elseif sched and sched._running and sched.StartBoss and sched._encounterID then
        sched:StartBoss(sched._encounterID)
    end

    if ExBoss and ExBoss.Voice and ExBoss.Voice.Engine and ExBoss.Voice.Engine.ApplyEventOverridesToAPI then
        ExBoss.Voice.Engine:ApplyEventOverridesToAPI()
    end
end

local PAGE_BINDING = { moduleKey = MODULE_KEY, getConfig = EnsureRootDB }
EXUI:RegisterSettingsPage(MODULE_KEY, CARD_GUI, { addon = "EXBoss" })

local function RefreshActiveSurfaces(changedPath)
    local rootDB = EnsureRootDB()
    if changedPath == "voice.global.disableAuraSoundRegistration" then
        -- 这个开关只保存下次加载要采用的值；当前会话不刷新或移除注册。
        return
    end
    if changedPath == "ui.general.bunBarSources" or changedPath == "ui.general.timerBarSources" then
        -- Scheduler 在每个既有分发点读取该选择；不需要也不能重启当前 Boss 时间轴。
        return
    end
    local general = rootDB.ui and rootDB.ui.general or {}
    WriteCVarValue("encounterWarningsEnabled", general.encounterWarningsEnabled == true and "1" or "0")
    WriteCVarValue("Sound_EnableEncounterWarningsSounds", general.encounterWarningSoundsEnabled == true and "1" or "2")
    WriteCVarValue("encounterTimelineEnabled", general.disableBlizzardEncounterTimeline == true and "0" or "1")
    ApplySpellCountDisplayChange()
    ApplyBlizzardHintCountdownChange()
    ApplyBarModeChange()
    ApplyBossSceneToggleChange()
    local mod = ExBoss and ExBoss.AutoGossip
    if mod and type(mod.NotifySettingsChanged) == "function" then mod.NotifySettingsChanged() end
    ApplyVoiceOverrides()
end

EXUI:RegisterModuleValueController(MODULE_KEY, {
    RefreshActiveSurfaces = RefreshActiveSurfaces,
})

function Page:Render(contentFrame)
    local Grid = _G.ExwindGrid
    if not Grid or not contentFrame then
        return
    end

    EnsureRootDB()

    if not Page._scrollFrame then
        local sf = CreateFrame("ScrollFrame", "ExBoss_GeneralOverviewScroll", contentFrame, "ScrollFrameTemplate")
        if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
            ExBoss.UI.ApplyModernScrollBarSkin(sf)
        end

        local sc = CreateFrame("Frame", nil, sf)
        sc:SetHeight(1)
        sf:SetScrollChild(sc)

        Page._scrollFrame = sf
        Page._scrollChild = sc
    end

    local sf = Page._scrollFrame
    local sc = Page._scrollChild

    sf:SetParent(contentFrame)
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    sf:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -24, 4)
    sf:SetVerticalScroll(0)
    sf:Show()

    C_Timer.After(0, function()
        if not sf:IsShown() then return end
        local w = contentFrame:GetWidth()
        if w < 100 then w = 820 end
        sc:SetWidth(w - 16)
        sc:SetParent(sf)
        sc:ClearAllPoints()
        sc:SetPoint("TOPLEFT", 0, 0)
        sc:Show()
        if ExwindTools.UI then
            ExwindTools.UI.ActivePageFrame = sc
            ExwindTools.UI.CurrentModule = MODULE_KEY
        end
        if Page._cardSession then Page._cardSession:Release() end
        Page._cardSession = Grid:MountCards(sc, EXUI:GetSettingsPage(MODULE_KEY), {
            pageId = MODULE_KEY,
            regionId = "main",
            moduleKey = MODULE_KEY,
            defaultBinding = PAGE_BINDING,
            scrollFrame = sf,
            onContentHeightChanged = function(height)
                if sc then sc:SetHeight(math.max(1, tonumber(height) or 1)) end
            end,
        })
        EXUI.ActiveCardSession = Page._cardSession
    end)
end

function Page:Hide()
    if EXUI.ActiveCardSession == Page._cardSession then EXUI.ActiveCardSession = nil end
    if Page._cardSession then Page._cardSession:Release(); Page._cardSession = nil end
    if Page._scrollFrame then Page._scrollFrame:Hide() end
end
