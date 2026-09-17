---@diagnostic disable: undefined-global, undefined-field, need-check-nil
local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, key) return key end })

ExBoss.UI.Panel.FlashTextMediumPage = ExBoss.UI.Panel.FlashTextMediumPage or {}
local Page = ExBoss.UI.Panel.FlashTextMediumPage
local MODULE_KEY = "ExBoss.FlashTextMedium"

local function GetFlashText()
    local module = ExBoss.UI and ExBoss.UI.FlashTextMedium
    if not module or type(module.ShowPanelPreview) ~= "function" then
        error("FlashTextMediumPage requires FlashTextMedium unified renderer API", 2)
    end
    return module
end

local function TestFlashText()
    GetFlashText():Show({ text = L["中字提示测试文字"], duration = 1.5 })
end

local COMMON_OPTS = {
    bindRoot = true, poolType = "FlashTextMediumModuleCommonSettingsGroup",
    fixedLayout = { logicalWidth = 200, controlW = 46, controlH = 6, slotX = { 3, 53, 103, 153 }, firstY = 0, rowStep = 14 },
    presentation = "settings-list",
    fields = {
        { path = "enabled", type = "checkbox", label = L["启用"], row = 1, presentation = "switch" },
        { path = "flashDuration", type = "slider", label = L["持续时间(秒)"], min = 0.5, max = 6, step = 0.5, row = 2 },
        { key = "test", type = "button", label = L["测试文字公告"], onClick = TestFlashText, row = 2 },
    },
}
local ANCHOR_OPTS = GetFlashText():GetStandardAnchorGroupOptions()
if type(ANCHOR_OPTS) ~= "table" then
    error("FlashTextMediumPage requires standard AnchorController group options", 2)
end
-- [卡片/Grid 迁移边界：FlashTextMedium 设置页]
-- 允许：只按共享规范调整下列声明的 x/y/w/h 与外层卡片分组。
-- 禁止：修改 key/type/path/opts、测试按钮回调、预览、Slider 或释放合同。
-- modulecommonsettings/anchorgroup/fontgroup 是完整组合，不能拆成原子控件重拼。
local LAYOUT = {
    version = 1,
    title = L["文字公告(中)"],
    cards = {
        { id = "module-common", title = L["通用设置"], collapsible = true,
            placement = { target = "$container", point = "TOPLEFT", relativePoint = "TOPLEFT" },
            content = { kind = "composite", component = "modulecommonsettings", key = "moduleCommon", opts = COMMON_OPTS },
            settingsList = { preserveHeader = true, rows = { { key = "moduleCommon", fullWidth = true } } } },
        { id = "anchor", title = L["锚点设置"], collapsible = true,
            placement = { target = "module-common", side = "below", align = "start" },
            content = { kind = "composite", component = "anchorgroup", key = "anchor", opts = ANCHOR_OPTS },
            settingsList = { preserveHeader = true, rows = { { key = "anchor", fullWidth = true } } } },
        { id = "text-font", title = L["文字公告(中)"], collapsible = true,
            placement = { target = "anchor", side = "below", align = "start" },
            content = { kind = "composite", component = "fontgroup", key = "font_text", opts = { unboundedWidth = true } },
            settingsList = { preserveHeader = true, title = L["外观"], rows = { { key = "font_text", fullWidth = true } } } },
    },
}
ExwindTools:RegisterModuleLayout(MODULE_KEY, LAYOUT)

-- 页面只声明既有布局、样本入口和 Slider 合同；Dock、Scroll、Watch、延迟
-- Render、ActivePage 所有权与 OnHide/release 均由 StandardModulePage 统一拥有。
local function RenderStandardPreview(dock)
    GetFlashText():ShowPanelPreview(dock)
end

local function ReleaseStandardPreview()
    local module = ExBoss.UI and ExBoss.UI.FlashTextMedium
    if module and type(module.ReleasePanelPreview) == "function" then module:ReleasePanelPreview() end
end

-- [生命周期边界] StandardModulePage 继续拥有 Scroll、Watch、预览与 release；布局迁移不得另建页面外壳。
local StandardPage = EXUI:CreateStandardModulePage({
    moduleKey = MODULE_KEY,
    page = Page,
    layout = LAYOUT,
    preview = {
        height = 160,
        render = RenderStandardPreview,
        refresh = RenderStandardPreview,
        release = ReleaseStandardPreview,
    },
    applyScrollSkin = function(scrollFrame)
        if ExBoss.UI and type(ExBoss.UI.ApplyModernScrollBarSkin) == "function" then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
    end,
    sliderContract = function()
        local module = GetFlashText()
        local contract = module.StandardSliderContract
        if type(contract) ~= "table" then error("FlashTextMedium standard Slider contract is unavailable", 2) end
        return {
            groupPaths = contract.groupPaths,
        }
    end,
})

function Page:Render(contentFrame)
    return StandardPage:Render(contentFrame)
end

function Page:Hide()
    return StandardPage:Hide()
end
