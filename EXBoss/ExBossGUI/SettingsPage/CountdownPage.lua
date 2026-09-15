---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/CountdownPage.lua
-- Countdown 只声明既有 Grid 布局；Dock、Scroll、Watch、延迟 Render、释放和
-- Slider 生命周期均由 EXUI 标准合同拥有。Secret runtime 值绝不进入此页面。
-- =============================================================

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
if not EXUI then return end

local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, key) return key end })
ExBoss.UI.Panel.CountdownPage = ExBoss.UI.Panel.CountdownPage or {}
local Page = ExBoss.UI.Panel.CountdownPage

local MODULE_KEY = "ExBoss.Countdown"

local function GetCountdown()
    local countdown = ExBoss.UI and ExBoss.UI.Countdown
    if not countdown
        or type(countdown.GetDB) ~= "function"
        or type(countdown.ShowPanelPreview) ~= "function"
        or type(countdown.RefreshPanelPreview) ~= "function"
        or type(countdown.ReleasePanelPreview) ~= "function" then
        error("CountdownPage requires Countdown standard renderer API", 2)
    end
    return countdown
end

-- 此对象由 Countdown View 的唯一 ANCHOR_SCHEMA 创建。Page 不得复制正式
-- *_1205 key、默认位置或 picker 映射；否则世界整体拖动与 AnchorGroup 会再次
-- 变成两份合同。
local countdown = GetCountdown()
if type(countdown.GetStandardAnchorGroupOptions) ~= "function" then
    error("CountdownPage requires Countdown standard anchor contract", 2)
end
local ANCHOR_OPTS = countdown:GetStandardAnchorGroupOptions()

local function TestCountdown()
    local countdown = ExBoss.UI and ExBoss.UI.Countdown
    if countdown and type(countdown.Show) == "function" then
        -- 固定普通样本；不读取或替换任何 runtime Secret 文本/图标。
        countdown:Show({
            displayName = L["坦克尖刺"],
            spellID = 46968,
            duration = 5,
            textMode = "NORMAL",
            iconMode = "NORMAL",
        })
    end
end

local COMMON_OPTS = {
    bindRoot = true,
    poolType = "CountdownModuleCommonSettingsGroup",
    fixedLayout = { logicalWidth = 200, controlW = 46, controlH = 6, slotX = { 3, 53, 103, 153 }, firstY = 0, rowStep = 14 },
    fields = {
        { path = "enabled", type = "checkbox", label = L["启用"], row = 1 },
        { path = "showDecimal", type = "checkbox", label = L["显示小数点"], row = 1 },
        { path = "stackMax_1205", type = "slider", label = L["最大条数"], min = 1, max = 3, step = 1, row = 2 },
        { path = "stackGap", type = "slider", label = L["上下间距"], min = 0, max = 20, step = 1, row = 2 },
        { path = "growDir", type = "dropdown", label = L["生长方向"], items = { { L["向上生长"], "UP" }, { L["向下生长"], "DOWN" } }, row = 2 },
        { key = "test", type = "button", label = L["测试倒计时"], onClick = TestCountdown, row = 2 },
    },
}

-- 页面只保留卡片声明；原测试按钮、配置路径与组合控件合同不变。
local CARD_GUI = {
    version = 1,
    title = L["屏幕倒计时"],
    description = L["屏幕中央倒计时的功能、锚点、图标与文字。"],
    cards = {
        { id = "general", title = L["模块通用设置"], content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = COMMON_OPTS } },
        { id = "anchor", title = L["锚点设置"], content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = ANCHOR_OPTS } },
        { id = "icon", title = L["图标外观"], content = { kind = "composite", component = "icongroup", key = "icon" } },
        { id = "text", title = L["提示文字"], content = { kind = "composite", component = "fontgroup", key = "font_text" } },
        { id = "time", title = L["倒计时数字"], content = { kind = "composite", component = "fontgroup", key = "font_time" } },
    },
}
local function RebindCountdownModuleCommon(context)
    local common = context.grid:GetSessionWidget(context.cardSession, "moduleCommon", "general")
    if common and type(common.RebindDB) == "function" then common:RebindDB(context.config) end
end

local function RenderStandardPreview(dock)
    GetCountdown():ShowPanelPreview(dock)
end

local function RefreshStandardPreview(dock)
    GetCountdown():RefreshPanelPreview(dock)
end

local function ReleaseStandardPreview()
    GetCountdown():ReleasePanelPreview()
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
        local contract = GetCountdown().StandardSliderContract
        if type(contract) ~= "table" then error("Countdown standard Slider contract is unavailable", 2) end
        return {
            groupPaths = contract.groupPaths,
        }
    end,
    afterGridLayout = function(context)
        RebindCountdownModuleCommon(context)
    end,
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
