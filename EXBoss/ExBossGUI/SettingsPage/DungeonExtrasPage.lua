---@diagnostic disable: undefined-global
local Tools = _G.ExwindTools
local EXUI = Tools.UI
local L = ExBoss.L
local Mod = ExBoss.UI.DungeonExtras
local KEY = "ExBoss.DungeonExtras"
local Page = {}
ExBoss.UI.Panel.DungeonExtrasPage = Page

local COMMON_OPTS = {
    bindRoot = true, poolType = "DungeonExtrasCommonSettingsGroup",
    fixedLayout = { logicalWidth = 200, controlW = 190, controlH = 6, slotX = { 3 }, firstY = 0, rowStep = 14 },
    fields = {
        { path = "enabled", type = "checkbox", label = L["启用副本额外提示"], row = 1 },
        { path = "rubyWindFire", type = "checkbox", label = L["红玉新生法池：尾王风火图"], row = 2 },
        { path = "altarTrashHealth", type = "checkbox", label = L["毒牙祭坛：指定小怪血量"], row = 3 },
        { path = "healthColor", type = "checkbox", label = L["血量条随剩余血量染色"], row = 4 },
    },
}
-- [卡片/Grid 迁移边界：DungeonExtras 设置页]
-- 允许：只按共享规范调整下列声明的 x/y/w/h 与外层卡片分组。
-- 禁止：修改业务开关 path/key、增长方向、StandardConfigBinding、预览或释放合同。
-- modulecommonsettings/anchorgroup/widgetlayout/timerBarGroup/fontgroup 必须整体引用；风火图业务样式不并入血量条卡片。
local LAYOUT = {
    version = 1,
    title = L["副本额外设置"],
    cards = {
        { id = "module-common", title = L["通用设置"], collapsible = true,
            placement = { target = "$container", point = "TOPLEFT", relativePoint = "TOPLEFT" },
            content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = COMMON_OPTS } },
        { id = "anchor", title = L["统一锚点"], collapsible = true,
            placement = { target = "module-common", side = "below", align = "start" },
            content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = Mod:GetStandardAnchorGroupOptions() } },
        { id = "layout", title = L["血量条排列"], collapsible = true,
            placement = { target = "anchor", side = "below", align = "start" },
            content = { kind = "composite", component = "widgetlayout", key = "layout",
                opts = { allowedDirections = { "UP", "DOWN" }, includeMaxPerRow = false, maxVisibleMin = 1, maxVisibleMax = 6, defaultMaxVisible = 6 } } },
        { id = "timer-bar", title = L["血量条外观"], collapsible = true,
            placement = { target = "layout", side = "below", align = "start" },
            content = { kind = "composite", component = "timerbargroup", key = "timerGroup" } },
        { id = "spell-font", title = L["单位名称"], collapsible = true,
            placement = { target = "timer-bar", side = "below", align = "start" },
            content = { kind = "composite", component = "fontgroup", key = "font_spell" } },
        { id = "timer-font", title = L["血量百分比"], collapsible = true,
            placement = { target = "spell-font", side = "below", align = "start" },
            content = { kind = "composite", component = "fontgroup", key = "font_timer" } },
    },
}
Tools:RegisterModuleLayout(KEY, LAYOUT)
-- [生命周期边界] StandardModulePage 继续拥有 Scroll、preview 与 release；布局迁移不得另建页面生命周期。
local standardPage = EXUI:CreateStandardModulePage({
    moduleKey = KEY, page = Page, binding = Mod.StandardConfigBinding, layout = LAYOUT, getColumns = 200,
    preview = { height = 202,
        render = function(dock) Mod:ShowPanelPreview(dock) end,
        refresh = function() Mod:RefreshPanelPreview() end,
        release = function() Mod:ReleasePanelPreview() end },
    applyScrollSkin = function(scrollFrame) ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame) end,
    sliderContract = function()
        return { groupPaths = { moduleCommon = "", layout = "layout", timerGroup = "timerGroup", font_spell = "font_spell", font_timer = "font_timer" } }
    end,
})
function Page:Render(contentFrame) return standardPage:Render(contentFrame) end
function Page:Hide() return standardPage:Hide() end
