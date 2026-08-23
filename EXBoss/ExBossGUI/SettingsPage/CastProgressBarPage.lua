---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/CastProgressBarPage.lua
-- 设置页只承载 Grid 与 EXUI 唯一标准预览面板。
-- =============================================================

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
if not EXUI then return end

local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, key) return key end })
ExBoss.UI.Panel.CastProgressBarPage = ExBoss.UI.Panel.CastProgressBarPage or {}
local Page = ExBoss.UI.Panel.CastProgressBarPage

local MODULE_KEY = "ExBoss.CastProgressBar"

local function GetCastProgressBar()
    return ExBoss.UI and ExBoss.UI.CastProgressBar
end

local function GetDB()
    local module = GetCastProgressBar()
    if not module or type(module.GetDB) ~= "function" then
        error("CastProgressBarPage requires CastProgressBar:GetDB", 2)
    end
    return module:GetDB()
end

local function GetAnchorGroupOptions()
    local module = GetCastProgressBar()
    if not module or type(module.GetAnchorGroupOptions) ~= "function" then
        error("CastProgressBarPage requires CastProgressBar:GetAnchorGroupOptions", 2)
    end
    return module:GetAnchorGroupOptions()
end

local ANCHOR_GROUP_OPTS = GetAnchorGroupOptions()

local LAYOUT_OPTS = {
    allowedDirections = { "UP", "DOWN" },
    includeMaxPerRow = false,
    maxVisibleMin = 1,
    maxVisibleMax = 5,
    defaultMaxVisible = 3,
}

local SLIDER_GROUP_PATHS = {
    layout = "layout",
    timerGroup = "timerGroup",
    font_spell = "font_spell",
    font_timer = "font_timer",
}

local GRID_LAYOUT = {
    { key = "header", type = "header", x = 1, y = 1, w = 200, h = 6, label = L["施法进度条设置"], labelSize = 25 },
    { key = "anchor", type = "anchorgroup", x = 1, y = 9, w = 200, h = 18, label = L["锚点设置"], opts = ANCHOR_GROUP_OPTS },
    { key = "layout", type = "widgetlayout", x = 1, y = 29, w = 200, h = 17, measure = true, label = L["排列设置"], opts = LAYOUT_OPTS },
    { key = "timerGroup", type = "timerBarGroup", x = 1, y = 48, w = 200, h = 50, label = L["计时条外观"], labelSize = 20 },
    { key = "font_spell", type = "fontgroup", x = 1, y = 101, w = 200, h = 50, label = L["法术名称"], labelSize = 20 },
    { key = "font_timer", type = "fontgroup", x = 1, y = 154, w = 200, h = 50, label = L["时间文本"], labelSize = 20 },
}

ExwindTools:RegisterModuleLayout(MODULE_KEY, GRID_LAYOUT)

local function RenderCastProgressPanelPreview(dock)
    local module = GetCastProgressBar()
    if module and type(module.ShowPanelPreview) == "function" then
        module:ShowPanelPreview(dock)
    end
end

local function RefreshCastProgressPanelPreview(dock)
    local module = GetCastProgressBar()
    if module and type(module.RefreshPanelPreview) == "function" then
        module:RefreshPanelPreview(dock)
    end
end

local function ReleaseCastProgressPanelPreview()
    local module = GetCastProgressBar()
    if module and type(module.ReleasePanelPreview) == "function" then
        module:ReleasePanelPreview()
    end
end

local StandardPage = EXUI:CreateStandardModulePage({
    moduleKey = MODULE_KEY,
    page = Page,
    layout = GRID_LAYOUT,
    getColumns = 200,
    preview = {
        height = 172,
        render = RenderCastProgressPanelPreview,
        refresh = RefreshCastProgressPanelPreview,
        release = ReleaseCastProgressPanelPreview,
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
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
