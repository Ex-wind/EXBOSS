---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/RingProgressPage.lua
-- 圆环进度设置页：页面外壳、Dock、watch、Grid 生命周期均由 StandardModulePage 拥有。
-- =============================================================

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
local L = ExBoss and ExBoss.GetLocale and ExBoss:GetLocale() or {}

ExBoss.UI.Panel.RingProgressPage = ExBoss.UI.Panel.RingProgressPage or {}
local Page = ExBoss.UI.Panel.RingProgressPage
local MODULE_KEY = "ExBoss.RingProgress"

local function GetRingProgress()
    local module = ExBoss.UI and ExBoss.UI.RingProgress
    if not module
        or type(module.GetDB) ~= "function"
        or type(module.GetAnchorGroupOptions) ~= "function"
        or type(module.StandardSliderContract) ~= "table"
        or type(module.StandardSliderContract.groupPaths) ~= "table"
        or type(module.ShowPanelPreview) ~= "function"
        or type(module.RefreshPanelPreview) ~= "function"
        or type(module.ReleasePanelPreview) ~= "function"
        or type(module.ShowTestCast) ~= "function"
        or type(module.ShowTestChannel) ~= "function" then
        error("RingProgressPage requires RingProgress standard display contract", 2)
    end
    return module
end

local ANCHOR_OPTS = GetRingProgress():GetAnchorGroupOptions()

-- 页面只保留真实配置字段与 Grid 几何；不再自行管理 PreviewDock、watch、onHide、
-- private focus callback 或 Slider 生命周期。
-- [卡片/Grid 迁移边界：RingProgress 设置页]
-- 允许：只按共享规范调整下列声明的 x/y/w/h 与外层卡片分组。
-- 禁止：修改 key/type/path/opts、测试施法/引导回调、动态背景启用逻辑、预览或释放合同。
-- fontgroup 必须整体引用；旧 header/divider/背景项只绘制与定位，不自动成为内容/回收容器。
local LAYOUT = {
    version = 1,
    title = L["圆环进度设置"] or "圆环进度设置",
    cards = {
        { id = "general", title = L["通用设置"] or "通用设置", collapsible = true,
            placement = { target = "$container", point = "TOPLEFT", relativePoint = "TOPLEFT" },
            content = { kind = "grid", items = {
                { key = "desc", type = "description", x = 1, y = 1, w = 200, h = 3, label = L["屏幕中央显示圆环进度"] or "屏幕中央显示圆环进度", labelSize = 18 },
                { key = "enabled", type = "checkbox", x = 1, y = 6, w = 46, h = 6, label = L["启用"] or "启用" },
            } },
            settingsList = { preserveHeader = true, rows = {
                { key = "desc", fullWidth = true },
                { key = "enabled", label = L["启用"] or "启用", presentation = "switch" },
            } } },
        { id = "anchor", title = L["锚点设置"] or "锚点设置", collapsible = true,
            placement = { target = "general", side = "below", align = "start" },
            content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = ANCHOR_OPTS },
            settingsList = { preserveHeader = true, rows = {
                { key = "anchor", fullWidth = true },
            } } },
        { id = "ring-appearance", title = L["圆环外观"] or "圆环外观", collapsible = true,
            placement = { target = "anchor", side = "below", align = "start" },
            content = { kind = "grid", items = {
                { key = "castFillMode", type = "dropdown", x = 1, y = 1, w = 46, h = 6, label = L["施法填充方式"] or "施法填充方式", items = {
                    { L["顺时针填满"] or "顺时针填满", "cw_fill" }, { L["顺时针消退"] or "顺时针消退", "cw_decay" },
                    { L["逆时针填满"] or "逆时针填满", "ccw_fill" }, { L["逆时针消退"] or "逆时针消退", "ccw_decay" },
                }, labelPos = "top" },
                { key = "channelFillMode", type = "dropdown", x = 51, y = 1, w = 46, h = 6, label = L["引导填充方式"] or "引导填充方式", items = {
                    { L["顺时针填满"] or "顺时针填满", "cw_fill" }, { L["顺时针消退"] or "顺时针消退", "cw_decay" },
                    { L["逆时针填满"] or "逆时针填满", "ccw_fill" }, { L["逆时针消退"] or "逆时针消退", "ccw_decay" },
                }, labelPos = "top" },
                { key = "style", type = "dropdown", x = 101, y = 1, w = 46, h = 6, label = L["圆环样式"] or "圆环样式", items = {
                    { L["细环 1"] or "细环 1", "thin1" }, { L["细环 2"] or "细环 2", "thin2" }, { L["标准环"] or "标准环", "classic" },
                }, labelPos = "top" },
                { key = "size", type = "slider", x = 151, y = 1, w = 46, h = 6, label = L["圆环尺寸"] or "圆环尺寸", min = 20, max = 360, step = 2 },
                { key = "ringColor", type = "color", x = 1, y = 9, w = 46, h = 6, label = L["颜色"] or "颜色" },
                { key = "alpha", type = "slider", x = 51, y = 9, w = 46, h = 6, label = L["透明度"] or "透明度", min = 0.1, max = 1, step = 0.05 },
                { key = "testCast", type = "button", x = 101, y = 9, w = 46, h = 6, label = L["测试施法"] or "测试施法", func = function()
                    GetRingProgress():ShowTestCast()
                end },
                { key = "testChannel", type = "button", x = 151, y = 9, w = 46, h = 6, label = L["测试引导"] or "测试引导", func = function()
                    GetRingProgress():ShowTestChannel()
                end },
            } },
            settingsList = { title = L["外观"] or "外观", preserveHeader = true, rows = {
                { key = "castFillMode", label = L["施法填充方式"] or "施法填充方式" },
                { key = "channelFillMode", label = L["引导填充方式"] or "引导填充方式" },
                { key = "style", label = L["圆环样式"] or "圆环样式" },
                { key = "size", label = L["圆环尺寸"] or "圆环尺寸" },
                { key = "ringColor", label = L["颜色"] or "颜色" },
                { key = "alpha", label = L["透明度"] or "透明度" },
                { key = "testCast", label = L["测试施法"] or "测试施法" },
                { key = "testChannel", label = L["测试引导"] or "测试引导" },
            } } },
        { id = "background", title = L["背景圆环"] or "背景圆环", collapsible = true,
            placement = { target = "ring-appearance", side = "below", align = "start" },
            content = { kind = "grid", items = {
                { key = "bgEnabled", type = "checkbox", x = 1, y = 1, w = 46, h = 6, label = L["启用背景圆环"] or "启用背景圆环" },
                { key = "bgColor", type = "color", x = 51, y = 1, w = 46, h = 6, label = L["背景颜色"] or "背景颜色" },
                { key = "bgAlpha", type = "slider", x = 101, y = 1, w = 46, h = 6, label = L["背景透明度"] or "背景透明度", min = 0.05, max = 1, step = 0.05 },
            } },
            settingsList = { preserveHeader = true, rows = {
                { key = "bgEnabled", label = L["启用背景圆环"] or "启用背景圆环", presentation = "switch" },
                { key = "bgColor", label = L["背景颜色"] or "背景颜色" },
                { key = "bgAlpha", label = L["背景透明度"] or "背景透明度" },
            } } },
        { id = "spell-font", title = L["法术名称"] or "法术名称", collapsible = true,
            placement = { target = "background", side = "below", align = "start" },
            content = { kind = "composite", component = "fontgroup", key = "font_spell" },
            settingsList = { preserveHeader = true, rows = {
                { key = "font_spell", fullWidth = true },
            } } },
        { id = "timer-font", title = L["时间文本"] or "时间文本", collapsible = true,
            placement = { target = "spell-font", side = "below", align = "start" },
            content = { kind = "composite", component = "fontgroup", key = "font_timer" },
            settingsList = { preserveHeader = true, rows = {
                { key = "font_timer", fullWidth = true },
            } } },
    },
}

ExwindTools:RegisterModuleLayout(MODULE_KEY, LAYOUT)

local function RenderRingProgressPanelPreview(dock)
    GetRingProgress():ShowPanelPreview(dock)
end

local function RefreshRingProgressPanelPreview()
    GetRingProgress():RefreshPanelPreview()
end

local function ReleaseRingProgressPanelPreview()
    GetRingProgress():ReleasePanelPreview()
end

local function ApplyScrollSkin(scrollFrame)
    if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
        ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
    end
end

-- [生命周期边界] StandardModulePage 继续拥有 Scroll、preview surface、Slider 与 release；布局迁移不得改其回调。
local StandardPage = EXUI:CreateStandardModulePage({
    moduleKey = MODULE_KEY,
    page = Page,
    layout = LAYOUT,
    getColumns = 200,
    preview = {
        height = 260,
        render = RenderRingProgressPanelPreview,
        refresh = RefreshRingProgressPanelPreview,
        release = ReleaseRingProgressPanelPreview,
    },
    applyScrollSkin = ApplyScrollSkin,
    sliderContract = function()
        local contract = GetRingProgress().StandardSliderContract
        if type(contract) ~= "table" then error("RingProgress standard Slider contract is unavailable", 2) end
        return { groupPaths = contract.groupPaths }
    end,
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
