---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI
if not EXUI then return end

local Grid = _G.ExwindGrid
if not Grid then return end

local L = (ExBoss and ExBoss.L) or setmetatable({}, { __index = function(_, k) return k end })

ExBoss.UI.Panel.CountdownVoicePage = ExBoss.UI.Panel.CountdownVoicePage or {}
local Page = ExBoss.UI.Panel.CountdownVoicePage

local Runtime = ExBoss and ExBoss.Voice and ExBoss.Voice.Countdown
if not Runtime then return end

local MODULE_KEY = "ExBoss.CountdownVoiceSettings"
local MAX_COUNTDOWN_DIGIT = tonumber(Runtime.GetMaxCountdownDigit and Runtime:GetMaxCountdownDigit()) or 5

local SOURCE_ITEMS = {
    { L["语音包"], "pack" },
    { L["LSM音效"], "lsm" },
}

local root
local scrollFrame
local scrollChild
local cardSession

local function ApplyDefaults(dst, defaults)
    if type(dst) ~= "table" or type(defaults) ~= "table" then
        return
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function BuildDigitItems()
    local rows = {}
    local baseY = 1
    for i = 1, MAX_COUNTDOWN_DIGIT do
        rows[#rows + 1] = {
            key = "digitEnabled" .. tostring(i),
            type = "checkbox",
            x = 4,
            y = baseY + ((i - 1) * 8),
            w = 28,
            h = 5,
            label = string.format(L["数字 %d"], i),
        }
        rows[#rows + 1] = {
            key = "digitSource" .. tostring(i),
            type = "dropdown",
            x = 40,
            y = baseY + ((i - 1) * 8),
            w = 38,
            h = 5,
            label = L["来源"],
            items = SOURCE_ITEMS,
            labelPos = "left",
        }
        rows[#rows + 1] = {
            key = "digitLSM" .. tostring(i),
            type = "lsm_sound",
            x = 88,
            y = baseY + ((i - 1) * 8),
            w = 72,
            h = 5,
            label = L["LSM音效"],
            labelPos = "left",
        }
        rows[#rows + 1] = {
            key = "preview" .. tostring(i),
            type = "button",
            x = 168,
            y = baseY + ((i - 1) * 8),
            w = 24,
            h = 5,
            label = L["试听"],
        }
    end
    return rows
end

local function NormalizeDigitSource(value)
    local source = tostring(value or "pack"):lower()
    if source ~= "lsm" then
        source = "pack"
    end
    return source
end

local function GetPageDB()
    local db = ExwindTools:GetModuleDB(MODULE_KEY, Runtime:GetDefaults())
    ApplyDefaults(db, Runtime:GetDefaults())
    return db
end

local function CopyRuntimeDBToPageDB()
    local runtimeDB = Runtime:GetDB()
    local pageDB = GetPageDB()
    for k in pairs(pageDB) do
        pageDB[k] = nil
    end
    ApplyDefaults(pageDB, runtimeDB)
    pageDB.pullCountdownEnabled      = runtimeDB.pullCountdownEnabled ~= false
    pageDB.pullCountdownVoiceEnabled = runtimeDB.pullCountdownVoiceEnabled == true
    for i = 1, MAX_COUNTDOWN_DIGIT do
        pageDB["digitEnabled" .. tostring(i)] = runtimeDB.digits and runtimeDB.digits[i] and runtimeDB.digits[i].enabled == true or false
        pageDB["digitSource" .. tostring(i)] = NormalizeDigitSource(runtimeDB.digits and runtimeDB.digits[i] and runtimeDB.digits[i].sourceType or "pack")
        pageDB["digitLSM" .. tostring(i)] = tostring(runtimeDB.digits and runtimeDB.digits[i] and runtimeDB.digits[i].customLSM or "")
    end
end

local function SyncPageDBToRuntimeDB()
    local pageDB = GetPageDB()
    local runtimeDB = Runtime:GetDB()
    runtimeDB.pullCountdownEnabled      = (pageDB.pullCountdownEnabled ~= false)
    runtimeDB.pullCountdownVoiceEnabled = (pageDB.pullCountdownVoiceEnabled == true)
    runtimeDB.digits = type(runtimeDB.digits) == "table" and runtimeDB.digits or {}
    for i = 1, MAX_COUNTDOWN_DIGIT do
        runtimeDB.digits[i] = type(runtimeDB.digits[i]) == "table" and runtimeDB.digits[i] or {}
        runtimeDB.digits[i].enabled = (pageDB["digitEnabled" .. tostring(i)] == true)
        runtimeDB.digits[i].sourceType = NormalizeDigitSource(pageDB["digitSource" .. tostring(i)])
        runtimeDB.digits[i].customLSM = tostring(pageDB["digitLSM" .. tostring(i)] or "")
    end
end

local function GetEditorWidgets()
    local widgets = {}
    if not cardSession then return widgets end
    for i = 1, MAX_COUNTDOWN_DIGIT do
        local key = "digitLSM" .. tostring(i)
        widgets[key] = Grid:GetSessionWidget(cardSession, key, "digits")
    end
    return widgets
end

local function SetWidgetShown(widget, shown)
    if not widget then return end
    if shown then widget:Show() else widget:Hide() end
end

local function SetWidgetUsable(widget, usable)
    if not widget then return end
    local isInput = widget._gridType == "GridInput" or (widget.IsObjectType and widget:IsObjectType("EditBox"))
    if isInput then
        if widget.Enable then widget:Enable() end
        if widget.EnableMouse then widget:EnableMouse(true) end
    elseif widget.SetEnabled then
        widget:SetEnabled(usable == true)
    elseif widget.Enable and widget.Disable then
        if usable then widget:Enable() else widget:Disable() end
    end
    widget:SetAlpha(usable and 1 or 0.45)
    if widget._exLabel then
        widget._exLabel:SetAlpha(usable and 1 or 0.45)
    elseif widget.labelText then
        widget.labelText:SetAlpha(usable and 1 or 0.45)
    end
end

local function RefreshDynamicWidgets()
    local widgets = GetEditorWidgets()
    local pageDB = GetPageDB()
    for i = 1, MAX_COUNTDOWN_DIGIT do
        local source = NormalizeDigitSource(pageDB["digitSource" .. tostring(i)])
        local lsmWidget = widgets["digitLSM" .. tostring(i)]
        local enabled = pageDB["digitEnabled" .. tostring(i)] == true
        SetWidgetShown(lsmWidget, source == "lsm")
        SetWidgetUsable(lsmWidget, enabled and source == "lsm")
    end
end

local CARD_GUI = {
    version = 1,
    title = L["语音设置"],
    description = L["开怪倒数与逐位数字语音来源。"],
    cards = {
        { id = "pull", title = L["开怪倒数"], content = { kind = "grid", items = {
            { key = "pullCountdownEnabled", type = "checkbox", x = 4, y = 1, w = 70, h = 5, label = L["启用开怪倒数"] },
            { key = "pullCountdownVoiceEnabled", type = "checkbox", x = 4, y = 8, w = 70, h = 5, label = L["为开怪倒数播放语音"] },
        } } },
        { id = "digits", title = L["数字语音"], content = { kind = "grid", items = BuildDigitItems() } },
    },
}

local PAGE_BINDING = { moduleKey = MODULE_KEY, getConfig = GetPageDB }
EXUI:RegisterSettingsPage(MODULE_KEY, CARD_GUI, { addon = "EXBoss" })

function Page:Render(contentFrame)
    if not contentFrame then
        return
    end

    CopyRuntimeDBToPageDB()

    if not scrollFrame then
        scrollFrame = CreateFrame("ScrollFrame", "ExBoss_CountdownVoiceSettingsScroll", contentFrame, "ScrollFrameTemplate")
        if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
        scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        Page._scrollFrame = scrollFrame
        Page._scrollChild = scrollChild
    end

    scrollFrame:SetParent(contentFrame)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -24, 4)
    scrollFrame:SetVerticalScroll(0)
    scrollFrame:Show()

    C_Timer.After(0, function()
        if not (scrollFrame and scrollFrame:IsShown() and scrollChild) then
            return
        end
        local width = contentFrame:GetWidth()
        if width < 100 then
            width = 820
        end
        scrollChild:SetWidth(width - 16)
        scrollChild:SetHeight(980)
        scrollChild:SetParent(scrollFrame)
        scrollChild:ClearAllPoints()
        scrollChild:SetPoint("TOPLEFT", 0, 0)
        scrollChild:Show()
        if ExwindTools.UI then
            ExwindTools.UI.ActivePageFrame = scrollChild
            ExwindTools.UI.CurrentModule = MODULE_KEY
        end
        if cardSession then cardSession:Release() end
        cardSession = Grid:MountCards(scrollChild, EXUI:GetSettingsPage(MODULE_KEY), {
            pageId = MODULE_KEY,
            regionId = "main",
            moduleKey = MODULE_KEY,
            defaultBinding = PAGE_BINDING,
            scrollFrame = scrollFrame,
            onContentHeightChanged = function(height)
                if scrollChild then scrollChild:SetHeight(math.max(1, tonumber(height) or 1)) end
            end,
        })
        EXUI.ActiveCardSession = cardSession
        RefreshDynamicWidgets()
    end)
end

function Page:Hide()
    if EXUI.ActiveCardSession == cardSession then EXUI.ActiveCardSession = nil end
    if cardSession then cardSession:Release(); cardSession = nil end
    if scrollFrame then
        scrollFrame:Hide()
    end
end

if not Page._eventsRegistered then
    ExwindTools:WatchState(MODULE_KEY .. ".ButtonClicked", MODULE_KEY .. "_btn", function(info)
        local key = type(info) == "table" and tostring(info.key or "") or ""
        local digit = tonumber(key:match("^preview(%d)$"))
        if digit then
            Runtime:PreviewDigit(digit)
        end
    end)
    Page._eventsRegistered = true
end

local function RefreshActiveSurfaces()
    SyncPageDBToRuntimeDB()
    RefreshDynamicWidgets()
end

EXUI:RegisterModuleValueController(MODULE_KEY, {
    RefreshActiveSurfaces = RefreshActiveSurfaces,
})
