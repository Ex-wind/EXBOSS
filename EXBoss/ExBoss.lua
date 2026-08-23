---@diagnostic disable: undefined-global
-- =============================================================
-- ExBoss — 全局命名空间初始化（最先加载）
-- 测试 4:08
-- =============================================================

ExBoss = ExBoss or {}
if not _G.UnitDisplayID then _G.UnitDisplayID = function() return 0 end end
local meta = _G.ExBoss_MetaData or { version = "DEV-Build" }
ExBoss.MetaData = meta
ExBoss.VERSION  = tostring(meta.version or "DEV-Build")

-- 子模块挂载点（预建，防止子模块因顺序问题拿到 nil）
ExBoss.Voice    = ExBoss.Voice    or {}
ExBoss.Voice.Engine = ExBoss.Voice.Engine or {}
ExBoss.Voice.OtherSounds = ExBoss.Voice.OtherSounds or {}
ExBoss.Voice.Profiles = ExBoss.Voice.Profiles or {}
ExBoss.Voice.ImportExport = ExBoss.Voice.ImportExport or {}
ExBoss.Timeline = ExBoss.Timeline or {}
ExBoss.MDT      = ExBoss.MDT      or {}
ExBoss.UI       = ExBoss.UI       or {}
ExBoss.UI.TimerBar   = ExBoss.UI.TimerBar   or {}
ExBoss.UI.BunBar     = ExBoss.UI.BunBar     or {}
ExBoss.UI.RingProgress = ExBoss.UI.RingProgress or {}
ExBoss.UI.IconAlert = ExBoss.UI.IconAlert or {}
ExBoss.UI.CastProgressBar = ExBoss.UI.CastProgressBar or {}
ExBoss.UI.Countdown  = ExBoss.UI.Countdown  or {}
ExBoss.UI.FlashTextMedium = ExBoss.UI.FlashTextMedium or {}
ExBoss.UI.HeadAlert  = ExBoss.UI.HeadAlert  or {}
ExBoss.UI.Panel      = ExBoss.UI.Panel      or {}
ExBoss.UI.Panel.MDTPage = ExBoss.UI.Panel.MDTPage or {}
ExBoss.UI.Panel.OtherVoicePage = ExBoss.UI.Panel.OtherVoicePage or {}
ExBoss.UI.Panel.ImportExportPage = ExBoss.UI.Panel.ImportExportPage or {}
ExBoss.UI.Panel.ToolsPage = ExBoss.UI.Panel.ToolsPage or {}
ExBoss.Data     = ExBoss.Data     or {}
ExBoss.DB       = ExBoss.DB       or {}
ExBoss.Export   = ExBoss.Export   or {}
ExBoss.Modules  = ExBoss.Modules  or {}
ExBoss.Modules.Boss = ExBoss.Modules.Boss or {}
ExBoss.BossEncounters = ExBoss.BossEncounters or {}
ExBoss.BossConfig = ExBoss.BossConfig or {}
ExBoss.TrashCD = ExBoss.TrashCD or {}
ExBoss.TargetAlert = ExBoss.TargetAlert or {}
ExBoss._initLoaded = ExBoss._initLoaded or false

-- 时间轴注册入口必须在 Boss 数据文件加载前可用；
-- toc 中 Bosses/*.lua 早于 Scheduler.lua，因此在这里先提供稳定 stub。
ExBoss.Timeline._bosses = ExBoss.Timeline._bosses or {}
if type(ExBoss.Timeline.RegisterBoss) ~= "function" then
    function ExBoss.Timeline:RegisterBoss(encounterID, def)
        if type(encounterID) ~= "number" or type(def) ~= "table" then
            return
        end
        self._bosses[encounterID] = def
    end
end

-- Init.lua 异常时的兜底：仍可通过 ExwindTools 虚拟事件驱动计时器。
do
    local ET = _G.ExwindTools
    if ET and ET.RegisterEvent then
        ET:RegisterEvent("ENCOUNTER_START", "ExBoss_Bootstrap_EncStart", function(_, encounterID)
            if ExBoss._initLoaded then return end
            if ExBoss.Timeline and ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.StartBoss then
                ExBoss.Timeline.Scheduler:StartBoss(encounterID)
            end
        end)
        ET:RegisterEvent("ENCOUNTER_END", "ExBoss_Bootstrap_EncEnd", function()
            if ExBoss._initLoaded then return end
            if ExBoss.Timeline and ExBoss.Timeline.Scheduler and ExBoss.Timeline.Scheduler.EndBoss then
                ExBoss.Timeline.Scheduler:EndBoss()
            end
        end)
    end
end

-- /exboss 与 /exb 由 ExwindCore\Core\ExwindPanelRouter.lua 唯一注册并路由。
