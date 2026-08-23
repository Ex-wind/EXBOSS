---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- Countdown display migration.
-- Business only supplies Countdown:Show(spec).  This file owns one IconCollection
-- presentation for runtime, world edit and panel; no business event owns visuals.

local ExwindTools = _G.ExwindTools
if not ExwindTools then return end
local EXUI = ExwindTools.UI or _G.ExwindToolsUI
if not EXUI then return end

ExBoss.UI.Countdown = ExBoss.UI.Countdown or {}
local Countdown = ExBoss.UI.Countdown
local MODULE_KEY = "ExBoss.Countdown"
local L = ExBoss.L or setmetatable({}, { __index = function(_, key) return key end })
local function TraceColor(stage, timer, color, note)
    local trace = ExBoss and ExBoss.ColorTrace
    if trace and type(trace.Record) == "function" then trace:Record(stage, timer, color, note) end
end

local anchorController, anchorGroupOptions, anchorFrame
local runtimeCollection, worldCollection, panelSurface, panelPreview, panelDock
local worldEditing, sequence = false, 0
local active = {}
local ReapplyAll = nil
local RemoveActive, ScheduleActiveExpiry, CancelActiveExpiry = nil, nil, nil

local BODY_WIDTH, BODY_HEIGHT = 420, 54
local LABEL_WIDTH, TIME_WIDTH, SIDE_GAP = 180, 64, 4
local PREVIEW_COUNT = 3

local function SafeNum(value, fallback) return tonumber(value) or fallback end
local function DB()
    local db = ExwindTools:GetModuleDB(MODULE_KEY)
    local icon = type(db.icon) == "table" and db.icon or {}
    db.icon = icon
    return db
end
local function CopyStyle(style, x, y)
    local copy = {}
    for key, value in pairs(type(style) == "table" and style or {}) do copy[key] = value end
    if x ~= nil then copy.x = x end
    if y ~= nil then copy.y = y end
    return copy
end
local function ApplyEventColor(style, color)
    if type(color) ~= "table" then return style end
    local r, g, b, a
    if type(color.GetRGBA) == "function" then
        r, g, b, a = color:GetRGBA()
    elseif type(color.GetRGB) == "function" then
        r, g, b = color:GetRGB()
    else
        r, g, b, a = color.r, color.g, color.b, color.a
    end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not (r and g and b) then return style end
    style.r, style.g, style.b, style.a = r, g, b, tonumber(a) or 1
    return style
end
local function GetRowHeight(db)
    local icon = type(db.icon) == "table" and db.icon or {}
    local text = type(db.font_text) == "table" and db.font_text or {}
    -- The collection Body is the actual row, not the historical 54px edit
    -- hitbox.  This makes stackGap, maxVisible and UP/DOWN one direct layout
    -- contract with no hidden conversion layer.
    local iconHeight = math.max(1, SafeNum(icon.height, 30))
    local textHeight = math.max(1, SafeNum(text.size, 24))
    local textY = SafeNum(text.y, 0)
    local lower = math.min(-iconHeight * .5, textY - textHeight * .5)
    local upper = math.max(iconHeight * .5, textY + textHeight * .5)
    return math.max(1, upper - lower)
end

local EX_DEFAULTS = {
    module = {
        enabled = true, showDecimal = true, stackMax_1205 = 2, stackGap = 4, growDir = "UP",
        anchorX_1205 = 0, anchorY_1205 = 40, attachToCustom = false, customAttachTarget = "",
    },
    icon = {
        showIcon = true, iconID = nil, reverse = false, width = 30, height = 30, x = 2, y = 2,
        showBorder = true, borderTexture = "EX_WhiteBorder", borderColorR = 0, borderColorG = 0, borderColorB = 0,
        borderColorA = 1, borderSize = 1, borderPadding = 1, enableCrop = true, cropLeft = .1, cropTop = .09,
        showCooldown = false, cooldown = { edgeAlpha = 1, showBling = false, showEdge = true, showSwipe = true, swipeAlpha = .65 },
    },
    font_text = {
        font = "默认", size = 24, r = 1, g = 1, b = 1, a = 1, enabled = true, autoWidth = false, fixedWidth = 200, maxWidth = 0,
        justifyH = "CENTER", justifyV = "MIDDLE", outline = "OUTLINE", shadow = true, shadowColorR = 0, shadowColorG = 0,
        shadowColorB = 0, shadowColorA = 1, shadowX = 2, shadowY = -2, rotation = 0, gradientEnabled = false,
        gradientStart = 0, gradientLength = 0, x = 0, y = -7.197392933818,
    },
}
local FONT_FIELDS = { "font", "size", "r", "g", "b", "a", "enabled", "autoWidth", "fixedWidth", "maxWidth", "justifyH", "justifyV",
    "outline", "shadow", "shadowColorR", "shadowColorG", "shadowColorB", "shadowColorA", "shadowX", "shadowY", "rotation",
    "gradientEnabled", "gradientStart", "gradientLength", "x", "y" }
ExwindTools:DeclareModuleDefaults(MODULE_KEY, EX_DEFAULTS, {
    { group = "module", root = true, fields = { "enabled", "showDecimal", "stackMax_1205", "stackGap", "growDir", "anchorX_1205", "anchorY_1205", "attachToCustom", "customAttachTarget" } },
    { group = "icon", fields = { "showIcon", "iconID", "reverse", "width", "height", "x", "y", "showBorder", "borderTexture", "borderColorR", "borderColorG", "borderColorB", "borderColorA", "borderSize", "borderPadding", "enableCrop", "cropLeft", "cropTop", "showCooldown", cooldown = { "edgeAlpha", "showBling", "showEdge", "showSwipe", "swipeAlpha" } } },
    { group = "font_text", fields = FONT_FIELDS },
})

local ANCHOR_SCHEMA = {
    moduleKey = MODULE_KEY, frameName = "ExBoss_CountdownAnchor", frameTemplate = "BackdropTemplate", title = L["倒计时"], getDB = DB,
    offsetXKey = "anchorX_1205", offsetYKey = "anchorY_1205", defaultOffsetX = EX_DEFAULTS.module.anchorX_1205,
    defaultOffsetY = EX_DEFAULTS.module.anchorY_1205, syncWidgets = { "anchorX_1205", "anchorY_1205", "attachToCustom", "customAttachTarget" },
    attachEnabledKey = "attachToCustom", attachTargetKey = "customAttachTarget", initialWidth = BODY_WIDTH, initialHeight = BODY_HEIGHT,
    clampedToScreen = false, frameStrata = "FULLSCREEN_DIALOG", fixedFrameStrata = true, frameLevel = 100,
    anchorPoint = "CENTER", relativePoint = "CENTER", onCreateFrame = function(_, frame) frame:Hide() end,
}
local function EnsureAnchorController()
    if not anchorController then anchorController, anchorGroupOptions = EXUI:CreateStandardModuleAnchor(ANCHOR_SCHEMA) end
    return anchorController
end
function Countdown:GetStandardAnchorGroupOptions() EnsureAnchorController(); return anchorGroupOptions end

-- 文本区域是倒数整体的唯一坐标原点；图标永远固定在它的左侧。
local function GetSpellNameStartAnchor(db)
    local text = type(db.font_text) == "table" and db.font_text or {}
    local textWidth = math.max(1, SafeNum(text.fixedWidth, LABEL_WIDTH))
    return -textWidth * .5, 0
end

local function IconBaseAnchor(db)
    local icon = db.icon or {}
    local startX, startY = GetSpellNameStartAnchor(db)
    return startX - SIDE_GAP - math.max(8, SafeNum(icon.width, 30)) * .5, startY
end
local INTERACTION_SCHEMA = {
    ["core.icon"] = {
        guiKey = "icon", movable = false, tooltip = L["倒计时图标"],
        anchor = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    ["core.label"] = { guiKey = "font_text", movable = false, tooltip = L["提示文字"], textRole = "label" },
}
local CONFIG_SCHEMA_PATHS = {
    ["stackMax_1205"] = true, ["stackGap"] = true, ["growDir"] = true,
    ["icon.width"] = true, ["icon.height"] = true, ["icon.alpha"] = true, ["icon.rotation"] = true,
    ["icon.cropLeft"] = true, ["icon.cropRight"] = true, ["icon.cropTop"] = true, ["icon.cropBottom"] = true, ["icon.borderSize"] = true, ["icon.borderPadding"] = true,
    ["icon.cooldown.swipeAlpha"] = true, ["icon.cooldown.edgeAlpha"] = true,
    ["font_text.size"] = true, ["font_text.shadowX"] = true, ["font_text.shadowY"] = true, ["font_text.fixedWidth"] = true, ["font_text.maxWidth"] = true,
    ["font_text.gradientStart"] = true, ["font_text.gradientLength"] = true, ["font_text.rotation"] = true, ["font_text.autoWidth"] = true,
}
Countdown.StandardSliderContract = { groupPaths = { moduleCommon = "", icon = "icon", font_text = "font_text" } }

local function BuildInteraction(db)
    local interaction = EXUI:BuildStandardPreviewInteraction("Icon", db, INTERACTION_SCHEMA)
    local x, y = IconBaseAnchor(db)
    local slot = interaction.slots["core.icon"]
    slot.positionMode, slot.relativeSlot = "anchor", "core.root"
    slot.anchor = { point = "CENTER", relativePoint = "CENTER", x = x, y = y }
    return interaction
end
local function BuildLayout(db)
    return {
        direction = db.growDir == "DOWN" and "DOWN" or "UP",
        spacing = math.max(0, SafeNum(db.stackGap, 4)),
        maxVisible = math.min(3, math.max(1, math.floor(SafeNum(db.stackMax_1205, 2)))),
    }
end
local function BuildPresentation(record, mode)
    local db, icon = DB(), DB().icon or {}
    local iconX, iconY = IconBaseAnchor(db)
    local static = mode ~= "runtime"
    -- 普通名称可作为原生 DurationTextBinding 的固定前缀。暴雪时间轴的
    -- Secret 名称不能在 tainted 回调内传给 SetTextFormat，故保留为独立的
    -- 原生标签；两者都使用同一组固定槽位，绝不测量名称宽度。
    local label = record.text
    if record.textMode ~= "SECRET" then label = label or "" end
    local isSecret = record.textMode == "SECRET"
    local prefix = not isSecret and (label ~= "" and (label .. " ") or "") or nil
    local remaining = math.max(0, SafeNum(record.remaining, 5))
    local staticTime = db.showDecimal == false and tostring(math.ceil(remaining)) or string.format("%.1f", remaining)
    -- Static preview records are normally non-secret.  Keep this branch safe
    -- as well if a secret record is ever supplied by a future preview caller.
    local staticText = isSecret and staticTime or (prefix .. staticTime)
    local cooldown = static and { static = true, remaining = remaining, duration = math.max(remaining, SafeNum(record.duration, 5)), text = staticText }
        or { mode = "DURATION", duration = record.durationObject, clearIfZero = true }
    local textWidth = math.max(1, SafeNum((db.font_text or {}).fixedWidth, LABEL_WIDTH))
    local secretTimeWidth = math.max(48, math.min(TIME_WIDTH, math.floor(textWidth * .36)))
    local secretLabelWidth = math.max(1, textWidth - secretTimeWidth - SIDE_GAP)
    local labelStyle = ApplyEventColor(CopyStyle(db.font_text, 0, 0), record.color)
    local countdownStyle = ApplyEventColor(CopyStyle(db.font_text, 0, 0), record.color)
    if isSecret then
        -- 固定槽位的宽度只来自用户配置，不能也不需要从 Secret 名称读取。
        labelStyle.autoWidth, labelStyle.fixedWidth, labelStyle.justifyH = false, secretLabelWidth, "LEFT"
        countdownStyle.autoWidth, countdownStyle.fixedWidth, countdownStyle.justifyH = false, secretTimeWidth, "CENTER"
    end
    return {
        style = { icon = icon, text = { label = labelStyle, countdown = countdownStyle } },
        icon = record.icon, label = isSecret and label or "", countdownTextPrefix = prefix, cooldown = cooldown,
        countdownTextVisible = true, cooldownDone = not static, bodySize = { width = BODY_WIDTH, height = GetRowHeight(db) },
        declaredBounds = { left = -BODY_WIDTH * .5, right = BODY_WIDTH * .5, bottom = -GetRowHeight(db) * .5, top = GetRowHeight(db) * .5 },
        coreLayout = {
            icon = { anchor = { point = "CENTER", relativeElement = "core.root", relativePoint = "CENTER", x = iconX, y = iconY } },
            time = {
                bounds = { width = isSecret and secretTimeWidth or textWidth, height = GetRowHeight(db) },
                anchor = isSecret
                    and { point = "LEFT", relativeElement = "core.label", relativePoint = "RIGHT", x = SIDE_GAP, y = 0 }
                    or { point = "LEFT", relativeElement = "core.icon", relativePoint = "RIGHT", x = SIDE_GAP, y = 0 },
            },
            label = isSecret and {
                bounds = { width = secretLabelWidth, height = GetRowHeight(db) },
                anchor = { point = "LEFT", relativeElement = "core.icon", relativePoint = "RIGHT", x = SIDE_GAP, y = 0 },
            } or nil,
        },
        interaction = BuildInteraction(db), runtimeTooltip = (not static and record.spellID) and { spellID = record.spellID } or nil,
    }
end

local PREVIEW_SPELL_IDS = { 1311923, 1310025, 1300372, 1248112, 1227247, 1227197 }
local function BuildPreviewRecords()
    local records = {}
    -- Preview reads top-to-bottom as 5 / 4 / 3 in either growth mode.  For
    -- UP the first semantic item is the bottom/root item, so its source order
    -- is reversed; DOWN keeps the natural source order.  Runtime event order
    -- is intentionally not changed here.
    local growingUp = DB().growDir ~= "DOWN"
    for index = 1, PREVIEW_COUNT do
        local spellID = PREVIEW_SPELL_IDS[((index - 1) % #PREVIEW_SPELL_IDS) + 1]
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID) or nil
        records[index] = { id = "countdown-preview:" .. index, spellID = spellID, text = (info and info.name) or L["测试倒计时"],
            icon = (info and info.iconID) or 134400,
            remaining = growingUp and (2 + index) or (6 - index), duration = 5 }
    end
    return records
end
local function ReplaceTable(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
end
local function RenderCollection(collection, records, mode)
    if not collection then return end
    local items = {}
    for index, record in ipairs(records or {}) do
        local item = collection:AcquireItem(tostring(record.id or index))
        collection:ApplyItem(item, BuildPresentation(record, mode))
        items[#items + 1] = item
    end
    collection:SetItems(items, BuildLayout(DB()))
end
local function EnsureRuntime()
    if anchorFrame then return end
    anchorFrame = EnsureAnchorController():Ensure()
    runtimeCollection = EXUI:CreateIconCollection(anchorFrame, "runtime", MODULE_KEY, {
        onCooldownDone = function(content)
            RemoveActive(content and content.itemID)
        end,
    })
end
local function RenderRuntime()
    EnsureRuntime()
    if worldEditing then return end
    RenderCollection(runtimeCollection, active, "runtime")
    if #active > 0 then anchorFrame:Show() else anchorFrame:Hide() end
end

-- Native Cooldown completion is the immediate display signal.  The record's
-- one-shot expiry remains the authoritative fallback, exactly as before the
-- migration, so a missing native callback cannot leave a stale countdown.
CancelActiveExpiry = function(record)
    if type(record) ~= "table" then return end
    record.expiryGeneration = (tonumber(record.expiryGeneration) or 0) + 1
    local timer = record.expiryTimer; record.expiryTimer = nil
    if timer and type(timer.Cancel) == "function" then timer:Cancel() end
end
RemoveActive = function(id)
    local wanted = tostring(id or "")
    if wanted == "" then return false end
    for index = #active, 1, -1 do
        if tostring(active[index] and active[index].id or "") == wanted then
            CancelActiveExpiry(active[index]); table.remove(active, index)
            if not worldEditing then RenderRuntime() end
            return true
        end
    end
    return false
end
ScheduleActiveExpiry = function(record, now)
    local timers = _G.C_Timer
    if not (timers and type(timers.NewTimer) == "function") then error("Countdown requires C_Timer.NewTimer for one-shot record expiry", 2) end
    CancelActiveExpiry(record)
    local generation = record.expiryGeneration
    record.expiryTimer = timers.NewTimer(math.max(0, SafeNum(record.expirationTime, now) - now), function()
        if record.expiryGeneration == generation then RemoveActive(record.id) end
    end)
end

local function BuildPanelPresentation(_, mode)
    if mode ~= "panel" then error("Countdown only supports panel presentation", 2) end
    local entries = {}
    for _, record in ipairs(BuildPreviewRecords()) do entries[#entries + 1] = { itemID = record.id, presentation = BuildPresentation(record, "panel") } end
    return { entries = entries, layout = BuildLayout(DB()) }
end
local function EnsurePanelSurface()
    if not panelSurface then panelSurface = EXUI:CreateStandardPreviewSurface({ moduleKey = MODULE_KEY, kind = "icon", buildPresentation = BuildPanelPresentation,
        interactionSchema = INTERACTION_SCHEMA }) end
    return panelSurface
end
local function ResizePanelDock()
    if panelDock and panelPreview then local _, height = panelPreview:GetBounds(); panelDock:SetHeight(math.max(160, (height or 0) + 28)) end
end
function Countdown:ShowPanelPreview(dock)
    if not dock then return end
    panelDock = dock; panelPreview = EnsurePanelSurface():Render({ dock = dock, ruleKey = MODULE_KEY, state = true }); ResizePanelDock()
end
function Countdown:RefreshPanelPreview(dock) if dock then panelDock = dock end; if panelDock then self:ShowPanelPreview(panelDock) end end
function Countdown:ReleasePanelPreview() if panelSurface then panelSurface:Release() end; panelPreview, panelDock = nil, nil end
function Countdown:RenderWorld(host)
    if not host then return end
    if worldCollection then worldCollection:Release() end
    EnsureRuntime(); worldEditing = true; runtimeCollection:SetItems({}, BuildLayout(DB()))
    -- The shared runtime anchor is hidden when no live countdown exists.
    -- World edit renders into that same anchor, so it must be shown explicitly.
    anchorFrame:Show()
    worldCollection = EXUI:CreateIconCollection(host, "world", MODULE_KEY); RenderCollection(worldCollection, BuildPreviewRecords(), "world")
end
function Countdown:GetWorldBounds() return worldCollection and worldCollection:GetWorldBounds() or nil end
function Countdown:ReleaseWorld()
    if worldCollection then worldCollection:Release(); worldCollection = nil end
    worldEditing = false; RenderRuntime()
end

local function CreateDuration(endAt, duration, modRate)
    if not (C_DurationUtil and C_DurationUtil.CreateDuration) then error("Countdown requires C_DurationUtil.CreateDuration", 2) end
    local object = C_DurationUtil.CreateDuration(); object:SetTimeFromEnd(endAt, duration, modRate); return object
end
function Countdown:GetDB() return DB() end
function Countdown:Show(spec)
    local db = DB(); if db.enabled == false then return end
    spec = type(spec) == "table" and spec or {}; sequence = sequence + 1
    TraceColor("Countdown.Show", { id = spec.traceTimerID, eventID = spec.traceEventID }, spec.color,
        "duration=" .. tostring(spec.duration))
    local duration, now = math.max(.1, SafeNum(spec.duration, 5)), GetTime()
    local endAt = SafeNum(spec.expirationTime, now + duration)
    local icon = spec.iconFileID
    if spec.iconMode ~= "SECRET" and icon == nil and spec.spellID and C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spec.spellID) end
    if icon == nil then
        local configured = tonumber((db.icon or {}).iconID)
        if configured and configured > 0 then icon = configured end
    end
    local text = spec.displayName
    -- EncounterTimeline may pass spellName as a secret string without an
    -- explicit textMode marker. Detect that official value at the boundary;
    -- it must stay on the dedicated native label path in tainted execution.
    local isSecretText = spec.textMode == "SECRET"
        or (type(issecretvalue) == "function" and issecretvalue(text) == true)
    local textMode = isSecretText and "SECRET" or "NORMAL"
    if textMode == "NORMAL" then
        text = type(text) == "string" and text or ""
    end
    local record = { id = "countdown:" .. sequence, spellID = spec.spellID, text = text, textMode = textMode,
        icon = spec.iconMode == "SECRET" and { mode = "SECRET", value = icon } or icon, durationObject = CreateDuration(endAt, duration, SafeNum(spec.modRate, 1)),
        duration = duration, remaining = math.max(0, endAt - now), expirationTime = endAt, modRate = SafeNum(spec.modRate, 1),
        color = spec.color, disableIconBorder = spec.disableIconBorder == true }
    table.insert(active, 1, record); ScheduleActiveExpiry(record, now)
    while #active > math.min(3, math.max(1, math.floor(SafeNum(db.stackMax_1205, 2)))) do CancelActiveExpiry(active[#active]); table.remove(active) end
    RenderRuntime()
end
function Countdown:Stop() for index = #active, 1, -1 do CancelActiveExpiry(active[index]); active[index] = nil end; if runtimeCollection then runtimeCollection:SetItems({}, BuildLayout(DB())) end; if anchorFrame and not worldEditing then anchorFrame:Hide() end end
function Countdown:RefreshVisuals() EnsureRuntime(); EnsureAnchorController():ApplyPosition(); ReapplyAll() end
function Countdown:StartFramePicker() return EnsureAnchorController():StartFramePicker() end

ExwindTools.UI:RegisterEditableModule({ addon = "EXBoss", key = "countdown", name = L["倒计时"], settingsPage = "countdown", appearanceProfile = "basicIcon",
    orientation = "HORIZONTAL", worldAnchorMode = "semantic-root", editOverlay = { titleFontSize = 30 }, getAnchor = function() EnsureRuntime(); return anchorFrame end,
    GetWorldBounds = function() return Countdown:GetWorldBounds() end, RenderWorld = function(host) return Countdown:RenderWorld(host) end, ReleaseWorld = function() return Countdown:ReleaseWorld() end })

for _, path in ipairs({ "anchorX_1205", "anchorY_1205", "attachToCustom", "customAttachTarget" }) do CONFIG_SCHEMA_PATHS[path] = true end
local function ReapplyCollection(collection, records, mode)
    if not collection then return end
    local byID = {}; for _, record in ipairs(records or {}) do byID[tostring(record.id)] = record end
    collection:ReapplyCurrentItems(function(presentation, item)
        local record = byID[tostring(item.id)]
        if record then ReplaceTable(presentation, BuildPresentation(record, mode)) end
    end)
    collection:ReapplyCurrentLayout(BuildLayout(DB()))
end
ReapplyAll = function()
    if panelSurface and type(panelSurface.ReapplyPanelPresentation) == "function" then panelSurface:ReapplyPanelPresentation() end
    ResizePanelDock()
    ReapplyCollection(worldCollection, BuildPreviewRecords(), "world")
    ReapplyCollection(runtimeCollection, active, "runtime")
end
local STANDARD_CONFIG_BINDING = EXUI:RegisterStandardConfigBinding({ moduleKey = MODULE_KEY, getConfig = DB, reapplyExisting = ReapplyAll, schemaPaths = CONFIG_SCHEMA_PATHS })
EXUI:RegisterModuleValueController(MODULE_KEY, { RefreshActiveSurfaces = function() return STANDARD_CONFIG_BINDING.reapplyExisting() end })
ExwindTools:RegisterEvent("PLAYER_ENTERING_WORLD", MODULE_KEY .. "_init", function() C_Timer.After(.5, function() EnsureRuntime(); EnsureAnchorController():ApplyPosition() end) end)
