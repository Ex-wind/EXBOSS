---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/TimerBarPage.lua
-- 计时条设置页（ExwindGrid 渲染）
--
-- 标准接入：页面外壳由 EXUI:CreateStandardModulePage 统一拥有；本文件只声明
-- 既有布局、标准 Slider 生命周期和 TimerBar 的 Preview Surface 调用。
-- =============================================================

-- =============================================================
-- 模块引导与常量
-- =============================================================
local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, k) return k end })

ExBoss.UI.Panel.TimerBarPage = ExBoss.UI.Panel.TimerBarPage or {}
local Page = ExBoss.UI.Panel.TimerBarPage

local MODULE_KEY = "ExBoss.TimerBar"

-- =============================================================
-- 模块控件规格
-- =============================================================
local TIMER_BAR_COMMON_FIELDS = {
    { path = "enabled", type = "checkbox", label = L["启用"], row = 1 },
    { path = "hideLongTimersSeconds", type = "slider", label = L["只显示最后几秒"], min = 1, max = 60, step = 1, row = 2 },
}

local TIMER_BAR_COMMON_OPTS = {
    bindRoot = true,
    poolType = "TimerBarModuleCommonSettingsGroup",
    fixedLayout = { logicalWidth = 200, controlW = 46, controlH = 6, slotX = { 3, 53, 103, 153 }, firstY = 0, rowStep = 14 },
    fields = TIMER_BAR_COMMON_FIELDS,
}

local TIMER_BAR_EXTRA_TEXTURE_OPTS = ExwindTools:BuildStandardTimerBarAlertIconsGroupOptions({
    timerBarKey = "timerGroup",
}, {
    paths = {
        show = "elements.alertIcons.texture.enabled",
        width = "elements.alertIcons.texture.width",
        height = "elements.alertIcons.texture.height",
        x = "elements.alertIcons.texture.x",
        y = "elements.alertIcons.texture.y",
    },
    ranges = {
        width = { min = 8, max = 128, step = 1 }, height = { min = 8, max = 128, step = 1 },
        x = { min = -1000, max = 1000, step = 1 }, y = { min = -1000, max = 1000, step = 1 },
    },
})

-- 此对象由 TimerBar View 的唯一 ANCHOR_SCHEMA 创建。Page 不得复制 key、默认
-- 位置或 picker 映射；否则世界整体拖动与 AnchorGroup 会再次变成两份合同。
local timerBar = ExBoss.UI and ExBoss.UI.TimerBar
if not timerBar or type(timerBar.GetStandardAnchorGroupOptions) ~= "function" then
    error("TimerBarPage requires TimerBar standard anchor contract", 2)
end
local TIMER_BAR_ANCHOR_OPTS = timerBar:GetStandardAnchorGroupOptions()

local TIMER_BAR_LAYOUT_OPTS = {
    -- TimerBar is a vertical semantic collection.  Do not expose horizontal
    -- directions merely because the generic Grid widget can render them.
    allowedDirections = { "UP", "DOWN" },
    includeMaxPerRow = false,
    maxVisibleMin = 1,
    maxVisibleMax = 6,
    defaultMaxVisible = 6,
}

local SLIDER_GROUP_PATHS = {
    moduleCommon = "",
    extraTexture = "",
    layout = "layout",
    timerGroup = "timerGroup",
    font_spell = "font_spell",
    font_timer = "font_timer",
}

-- 页面只保留卡片声明；标准页固定使用 200 逻辑列，不再维护整页缩放缓存。
local CARD_GUI = {
    version = 1,
    title = L["计时条设置"],
    description = L["计时条的通用行为、额外材质、锚点、排列与文字。"],
    cards = {
        { id = "general", title = L["模块通用设置"], content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = TIMER_BAR_COMMON_OPTS } },
        { id = "alert_texture", title = L["额外子元素－材质"], content = { kind = "composite", component = "modulecommonsettings", key = "extraTexture", opts = TIMER_BAR_EXTRA_TEXTURE_OPTS } },
        { id = "anchor", title = L["锚点设置"], content = { kind = "composite", component = "anchorgroup", key = "anchorGroup", opts = TIMER_BAR_ANCHOR_OPTS } },
        { id = "layout", title = L["排列设置"], content = { kind = "composite", component = "widgetlayout", key = "layout", opts = TIMER_BAR_LAYOUT_OPTS } },
        { id = "bar", title = L["计时条外观"], content = { kind = "composite", component = "timerbargroup", key = "timerGroup" } },
        { id = "name", title = L["法术名称"], content = { kind = "composite", component = "fontgroup", key = "font_spell" } },
        { id = "time", title = L["时间文本"], content = { kind = "composite", component = "fontgroup", key = "font_timer" } },
    },
}

-- =============================================================
-- 标准页面合同
-- =============================================================
local function GetTimerBar()
    return ExBoss.UI and ExBoss.UI.TimerBar
end

local function RebindTimerBarModuleCommon(context)
    for _, ref in ipairs({
        { "moduleCommon", "general" },
        { "extraTexture", "alert_texture" },
    }) do
        local group = context.grid:GetSessionWidget(context.cardSession, ref[1], ref[2])
        if group and type(group.RebindDB) == "function" then
            group:RebindDB(context.config)
        end
    end
end

local function RenderTimerBarPanelPreview(dock)
    local timerBar = GetTimerBar()
    if timerBar and type(timerBar.ShowPanelPreview) == "function" then
        timerBar:ShowPanelPreview(dock)
    end
end

local function ReleaseTimerBarPanelPreview()
    local timerBar = GetTimerBar()
    if timerBar and type(timerBar.ReleasePanelPreview) == "function" then
        timerBar:ReleasePanelPreview()
    end
end

local StandardPage = ExwindTools.UI:CreateStandardModulePage({
    moduleKey = MODULE_KEY,
    page = Page,
    gui = CARD_GUI,
    preview = {
        -- 模块合同下限：TimerBar 预览至少显示两条，不能从 1px Dock 开始。
        height = 120,
        render = RenderTimerBarPanelPreview,
        release = ReleaseTimerBarPanelPreview,
    },
    applyScrollSkin = function(scrollFrame)
        if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
    end,
    sliderContract = function()
        return {
            groupPaths = SLIDER_GROUP_PATHS,
        }
    end,
    afterGridLayout = function(context)
        RebindTimerBarModuleCommon(context)
    end,
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
