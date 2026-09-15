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
local CARD_GUI = {
    version = 1,
    title = L["副本额外设置"],
    description = L["已接管副本提示的开关、统一位置与血量条外观。"],
    cards = {
        { id = "general", title = L["已接管的副本提示"], content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = COMMON_OPTS } },
        { id = "anchor", title = L["统一锚点"], content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = Mod:GetStandardAnchorGroupOptions() } },
        { id = "layout", title = L["血量条排列"], content = { kind = "composite", component = "widgetlayout", key = "layout", opts = { allowedDirections = { "UP", "DOWN" }, includeMaxPerRow = false, maxVisibleMin = 1, maxVisibleMax = 6, defaultMaxVisible = 6 } } },
        { id = "bar", title = L["血量条外观"], content = { kind = "composite", component = "timerbargroup", key = "timerGroup" } },
        { id = "name", title = L["单位名称"], content = { kind = "composite", component = "fontgroup", key = "font_spell" } },
        { id = "value", title = L["血量百分比"], content = { kind = "composite", component = "fontgroup", key = "font_timer" } },
    },
}
local standardPage = EXUI:CreateStandardModulePage({
    moduleKey = KEY, page = Page, binding = Mod.StandardConfigBinding, gui = CARD_GUI, getColumns = 200,
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
