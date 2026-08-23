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
local GRID_COLS = 200
local MAX_COUNTDOWN_DIGIT = tonumber(Runtime.GetMaxCountdownDigit and Runtime:GetMaxCountdownDigit()) or 5

local SOURCE_ITEMS = {
    { L["语音包"], "pack" },
    { L["LSM音效"], "lsm" },
}
local FLOOR_WARNING_SOURCE_ITEMS = {
    { L["语音包"], "pack" },
    { L["LSM音效"], "lsm" },
    { L["自定义路径"], "file" },
}

local LAYOUT = {
    { key = "header", type = "header", x = 1, y = 1, w = 200, h = 6, label = L["语音设置"], labelSize = 24 },
    { key = "header_pull", type = "header", x = 1, y = 11, w = 200, h = 5, label = L["开怪倒数"], labelSize = 20 },
    { key = "pullCountdownEnabled",      type = "checkbox", x = 4, y = 20, w = 70, h = 5, label = L["启用开怪倒数"] },
    { key = "pullCountdownVoiceEnabled", type = "checkbox", x = 4, y = 27, w = 70, h = 5, label = L["为开怪倒数播放语音"] },
    { key = "header_digits", type = "header", x = 1, y = 37, w = 200, h = 5, label = L["数字语音"], labelSize = 20 },
    { key = "header_floor_warning", type = "header", x = 1, y = 91, w = 200, h = 5, label = L["踩地板提示（GTFO）"], labelSize = 20 },
    { key = "floorWarningSource", type = "dropdown", x = 4, y = 101, w = 34, h = 5, label = L["来源"], items = FLOOR_WARNING_SOURCE_ITEMS, labelPos = "left" },
    { key = "floorWarningPack", type = "dropdown", x = 46, y = 101, w = 72, h = 5, label = L["声音"], items = {}, labelPos = "left", search = true },
    { key = "floorWarningLSM", type = "lsm_sound", x = 46, y = 101, w = 72, h = 5, label = L["声音"], labelPos = "left" },
    { key = "floorWarningPath", type = "input", x = 46, y = 101, w = 72, h = 5, label = L["路径"], labelPos = "left" },
    { key = "previewFloorWarning", type = "button", x = 128, y = 101, w = 26, h = 5, label = L["试听"] },
    { key = "applyFloorWarning", type = "button", x = 160, y = 101, w = 32, h = 5, label = L["应用到全部"] },
    { key = "floorWarningHint", type = "description", x = 4, y = 110, w = 188, h = 5, label = L["应用会把当前大米角色配置内所有 GTFO 提示逐条写入；之后单独修改任一条，不会影响其他条目。"] },
}

local root
local scrollFrame
local scrollChild

local function DeepCopy(v)
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, x in pairs(v) do
        out[k] = DeepCopy(x)
    end
    return out
end

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

local function GetVoicePackLabelItems()
    local catalog = ExBoss and ExBoss.Voice and ExBoss.Voice.LabelCatalog
    if catalog and type(catalog.GetDropdownItems) == "function" then
        local items = catalog.GetDropdownItems()
        if type(items) == "table" then return items end
    end
    return {}
end

local function BuildLayout()
    local rows = DeepCopy(LAYOUT)
    for _, row in ipairs(rows) do
        if row.key == "floorWarningPack" then row.items = GetVoicePackLabelItems() end
    end
    local baseY = 47
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

local function NormalizeFloorWarningSource(value)
    local source = tostring(value or "pack"):lower()
    if source ~= "lsm" and source ~= "file" then source = "pack" end
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
    local floorDraft = {
        source = pageDB.floorWarningSource,
        pack = pageDB.floorWarningPack,
        lsm = pageDB.floorWarningLSM,
        path = pageDB.floorWarningPath,
    }
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
    pageDB.floorWarningSource = NormalizeFloorWarningSource(floorDraft.source)
    pageDB.floorWarningPack = tostring(floorDraft.pack or "GTFO")
    pageDB.floorWarningLSM = tostring(floorDraft.lsm or "")
    pageDB.floorWarningPath = tostring(floorDraft.path or "")
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
    local state = Grid.ContainerStates and Grid.ContainerStates[scrollChild] or nil
    return state and state.widgets or {}
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
    local floorSource = NormalizeFloorWarningSource(pageDB.floorWarningSource)
    local floorPack = widgets.floorWarningPack
    local floorLSM = widgets.floorWarningLSM
    local floorPath = widgets.floorWarningPath
    SetWidgetShown(floorPack, floorSource == "pack")
    SetWidgetShown(floorLSM, floorSource == "lsm")
    SetWidgetShown(floorPath, floorSource == "file")
    SetWidgetUsable(floorPack, floorSource == "pack")
    SetWidgetUsable(floorLSM, floorSource == "lsm")
    SetWidgetUsable(floorPath, floorSource == "file")
end

local function BuildFloorWarningTrigger()
    local db = GetPageDB()
    local sourceType = NormalizeFloorWarningSource(db.floorWarningSource)
    local trigger = { enabled = true, sourceType = sourceType }
    if sourceType == "pack" then
        trigger.label = tostring(db.floorWarningPack or "")
        if trigger.label == "" then return nil, L["请选择语音包声音"] end
    elseif sourceType == "lsm" then
        trigger.customLSM = tostring(db.floorWarningLSM or "")
        if trigger.customLSM == "" then return nil, L["请选择 LSM 音效"] end
    else
        trigger.customPath = tostring(db.floorWarningPath or "")
        if trigger.customPath == "" then return nil, L["请输入自定义路径"] end
    end
    return trigger
end

local function NotifyFloorWarningResult(text)
    if ExBoss and ExBoss.Print and type(ExBoss.Print.Say) == "function" then
        ExBoss.Print.Say(text)
    else
        print("|cff00ffff<EXBOSS>|r " .. tostring(text or ""))
    end
end

local function PreviewFloorWarning()
    local trigger, reason = BuildFloorWarningTrigger()
    if not trigger then
        NotifyFloorWarningResult(reason)
        return
    end
    local engine = ExBoss and ExBoss.Voice and ExBoss.Voice.Engine
    if not (engine and type(engine.TryPlayStandaloneSound) == "function") then
        NotifyFloorWarningResult(L["语音播放模块未就绪"])
        return
    end
    local ok, err = engine:TryPlayStandaloneSound(trigger, "exboss:floor-warning:preview", { triggerIndex = 0, throttle = false })
    if not ok then NotifyFloorWarningResult(L["试听失败："] .. tostring(err or "")) end
end

local function ApplyFloorWarning()
    local trigger, reason = BuildFloorWarningTrigger()
    if not trigger then
        NotifyFloorWarningResult(reason)
        return
    end
    local bossConfig = ExBoss and ExBoss.BossConfig
    if not (bossConfig and type(bossConfig.ApplyMplusFloorWarningSound) == "function") then
        NotifyFloorWarningResult(L["光环配置模块未就绪"])
        return
    end
    local ok, changedOrReason = bossConfig:ApplyMplusFloorWarningSound(trigger)
    if ok then
        NotifyFloorWarningResult(string.format(L["已应用到 %d 条踩地板提示。"], tonumber(changedOrReason) or 0))
    else
        NotifyFloorWarningResult(L["应用失败："] .. tostring(changedOrReason or ""))
    end
end

local function RegisterLayout()
    ExwindTools:RegisterModuleLayout(MODULE_KEY, BuildLayout())
end

function Page:Render(contentFrame)
    if not contentFrame then
        return
    end

    CopyRuntimeDBToPageDB()
    RegisterLayout()

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
        if Grid.SetContainerCols then
            Grid:SetContainerCols(scrollChild, GRID_COLS)
        end
        Grid:Render(scrollChild, BuildLayout(), GetPageDB(), MODULE_KEY)
        RefreshDynamicWidgets()
    end)
end

function Page:Hide()
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
        elseif key == "previewFloorWarning" then
            PreviewFloorWarning()
        elseif key == "applyFloorWarning" then
            ApplyFloorWarning()
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
