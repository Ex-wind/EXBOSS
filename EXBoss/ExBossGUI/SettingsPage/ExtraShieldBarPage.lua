---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- ExtraShieldBar 设置页：只声明既有 Grid 布局与标准合同入口。Dock、Scroll、
-- Watch、OnHide/release、Grid 回读均由 EXUI:CreateStandardModulePage 统一拥有。

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
if not EXUI then return end
local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, key) return key end })

ExBoss.UI = ExBoss.UI or {}
ExBoss.UI.Panel = ExBoss.UI.Panel or {}
ExBoss.UI.Panel.ExtraShieldBarPage = ExBoss.UI.Panel.ExtraShieldBarPage or {}
local Page = ExBoss.UI.Panel.ExtraShieldBarPage
local MODULE_KEY = "ExBoss.ExtraShieldBar"

local function GetExtraShieldBar()
    local module = ExBoss.UI and ExBoss.UI.ExtraShieldBar
    if not module or type(module.GetStandardAnchorGroupOptions) ~= "function"
        or type(module.ShowPanelPreview) ~= "function" then
        error("ExtraShieldBarPage requires ExtraShieldBar standard display contract", 2)
    end
    return module
end

local SHIELD_COMMON_OPTS = {
    bindRoot = true,
    poolType = "ExtraShieldBarModuleCommonSettingsGroup",
    fixedLayout = { logicalWidth = 200, controlW = 46, controlH = 6, slotX = { 3, 53, 103, 153 }, firstY = 0, rowStep = 14 },
    fields = {
        { path = "enabled", type = "checkbox", label = L["启用"], row = 1 },
    },
}

-- 锚点字段、默认位置、FramePicker 与整体拖动全部由 Display 的唯一
-- ANCHOR_SCHEMA 返回；Page 不复制任何 DB key 或默认值。
local SHIELD_ANCHOR_OPTS = GetExtraShieldBar():GetStandardAnchorGroupOptions()
if type(SHIELD_ANCHOR_OPTS) ~= "table" then
    error("ExtraShieldBarPage requires standard AnchorGroup options", 2)
end

-- ExtraShield 是固定单条 Body；没有第二条可排列，故不凭空显示 layout 卡。
local CARD_GUI = {
    version = 1,
    title = L["额外护盾条设置"],
    description = L["单体护盾监控条的启用、锚点、条体和文字。"],
    cards = {
        { id = "general", title = L["模块通用设置"], content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = SHIELD_COMMON_OPTS } },
        { id = "anchor", title = L["锚点设置"], content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = SHIELD_ANCHOR_OPTS } },
        { id = "bar", title = L["计时条外观"], content = { kind = "composite", component = "timerbargroup", key = "timerGroup" } },
        { id = "name", title = L["法术名称"], content = { kind = "composite", component = "fontgroup", key = "font_spell" } },
        { id = "value", title = L["数值文本"], content = { kind = "composite", component = "fontgroup", key = "font_timer" } },
    },
}

local function RenderStandardPreview(dock)
    GetExtraShieldBar():ShowPanelPreview(dock)
end

local function RefreshStandardPreview(dock)
    local module = GetExtraShieldBar()
    if type(module.RefreshPanelPreview) == "function" then
        module:RefreshPanelPreview(dock)
    else
        module:ShowPanelPreview(dock)
    end
end

local function ReleaseStandardPreview()
    local module = ExBoss.UI and ExBoss.UI.ExtraShieldBar
    if module and type(module.ReleasePanelPreview) == "function" then
        module:ReleasePanelPreview()
    end
end

local function RebindModuleCommon(context)
    local group = context.grid:GetSessionWidget(context.cardSession, "moduleCommon", "general")
    if group and type(group.RebindDB) == "function" then group:RebindDB(context.config) end
end

local StandardPage = EXUI:CreateStandardModulePage({
    moduleKey = MODULE_KEY,
    page = Page,
    gui = CARD_GUI,
    preview = {
        height = 160,
        render = RenderStandardPreview,
        refresh = RefreshStandardPreview,
        release = ReleaseStandardPreview,
    },
    applyScrollSkin = function(scrollFrame)
        if ExBoss.UI and type(ExBoss.UI.ApplyModernScrollBarSkin) == "function" then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
    end,
    sliderContract = function()
        local module = GetExtraShieldBar()
        local contract = module.StandardSliderContract
        if type(contract) ~= "table" then error("ExtraShieldBar standard Slider contract is unavailable", 2) end
        return {
            groupPaths = contract.groupPaths,
        }
    end,
    afterGridLayout = function(context)
        RebindModuleCommon(context)
    end,
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
