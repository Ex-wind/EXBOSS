---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/VoicePackPage.lua
-- 语音包选择页
-- =============================================================

ExBoss.UI.Panel.VoicePackPage             = ExBoss.UI.Panel.VoicePackPage or {}
local Page                                = ExBoss.UI.Panel.VoicePackPage
local EXUI                                = _G.ExwindTools and _G.ExwindTools.UI
local L                                   = (ExBoss and ExBoss.L) or
    setmetatable({}, { __index = function(_, k) return k end })

local root                                = nil
local packDropdown                        = nil
local ui                                  = {}
local RefreshInfo                         = nil
local RefreshPage                         = nil
local UpdateConfigurationManagerButtonState = nil
local DEFAULT_VOICE_PACK                  = "EXWIND(默认)"
local ENGLISH_VOICE_PACK                  = "英文(ENG)"

local THEME                               = {
    accent = { 1.00, 0.82, 0.22 },
    cyan   = { 0.24, 0.78, 1.00 },
    ok     = { 0.20, 0.95, 0.50 },
    muted  = { 0.55, 0.60, 0.68 },
    border = { 0.18, 0.22, 0.28 },
    cardBg = { 0.03, 0.04, 0.07 },
}

local function ShowEXBossStaticPopup(which, textArg1, textArg2, data)
    local popup = StaticPopup_Show(which, textArg1, textArg2, data)
    local panelTheme = _G.ExwindTools and _G.ExwindTools.PanelTheme
    if popup and panelTheme and panelTheme.ApplyWindowChrome then
        panelTheme.ApplyWindowChrome(popup, {
            radius = 10,
            suppressNative = true,
            restoreOnHide = true,
        })
    end
    if popup and EXUI and EXUI.ApplyPopupChildControls then
        EXUI:ApplyPopupChildControls(popup, { restoreOnHide = true })
    end
    return popup
end

-- ─── 帮助函数 ─────────────────────────────────────────────────

local function Bg(parent, r, g, b, a)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(r or 0.03, g or 0.04, b or 0.07, a or 0.92)
    f:SetBackdropBorderColor(
        THEME.border[1], THEME.border[2], THEME.border[3], 0.95)
    local panelTheme = _G.ExwindTools and _G.ExwindTools.PanelTheme
    if panelTheme and panelTheme.ApplySettingsCardStyle then
        panelTheme.ApplySettingsCardStyle(f, false)
    end
    return f
end

local function TopBar(parent, r, g, b)
    local t = EXUI:CreateVisualTexture(parent, EXBORDERFRAME)
    t:SetColorTexture(r, g, b, 0.95)
    t:SetHeight(2)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -6)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
    return t
end

local function Divider(parent, anchor, offY)
    local t = EXUI:CreateVisualTexture(parent, EXBORDERFRAME)
    t:SetHeight(1)
    t:SetColorTexture(0.22, 0.26, 0.32, 0.85)
    t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offY or -10)
    t:SetPoint("TOPRIGHT", parent, "RIGHT", -16, 0)
    return t
end

local function Chip(parent, r, g, b)
    local chip = Bg(parent, r * 0.18, g * 0.18, b * 0.18, 0.88)
    local fs = EXUI:CreateVisualFontString(chip, EXFONTFRAME, "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetTextColor(r, g, b)
    chip.label = fs
    return chip
end

-- ─── DB / 语音包工具 ──────────────────────────────────────────

local function GetClientLocaleTag()
    if ExBoss and ExBoss.Locale and type(ExBoss.Locale.GetCurrentLocale) == "function" then
        local locale = tostring(ExBoss.Locale:GetCurrentLocale() or ""):gsub("%s+", "")
        if locale ~= "" then
            if locale == "enGB" then
                return "enUS"
            end
            return locale
        end
    end
    if ExBoss and type(ExBoss.GetEffectiveLocale) == "function" and type(ExBoss.GetLocaleMode) == "function" then
        local locale = tostring(ExBoss:GetEffectiveLocale(ExBoss:GetLocaleMode()) or ""):gsub("%s+", "")
        if locale ~= "" then
            if locale == "enGB" then
                return "enUS"
            end
            return locale
        end
    end
    if type(GetLocale) == "function" then
        local locale = tostring(GetLocale() or ""):gsub("%s+", "")
        if locale == "enGB" then
            return "enUS"
        end
        return locale
    end
    return ""
end

local function IsEnglishClientLocale(locale)
    locale = tostring(locale or "")
    return locale == "enUS" or locale == "enGB"
end

local function ResolveDefaultVoicePack()
    if IsEnglishClientLocale(GetClientLocaleTag()) then
        return ENGLISH_VOICE_PACK
    end
    return DEFAULT_VOICE_PACK
end

local function ShouldForceEnglishVoicePack(globalCfg)
    if type(globalCfg) ~= "table" then
        return false
    end
    if not IsEnglishClientLocale(GetClientLocaleTag()) then
        return false
    end
    return globalCfg.allowNonEnglishVoicePackOnEnglishLocale ~= true
end

local function EnsureDB()
    EXBOSS12S2 = EXBOSS12S2 or {}
    EXBOSS12S2.voice = EXBOSS12S2.voice or {}
    EXBOSS12S2.voice.global = EXBOSS12S2.voice.global or {}
    local g = EXBOSS12S2.voice.global
    g.selectedVoicePack = g.selectedVoicePack or ResolveDefaultVoicePack()
    return g
end

local function GetVoicePacks()
    local Registry = ExBoss and ExBoss.Voice and ExBoss.Voice.PackRegistry
    local list = {}
    if Registry and type(Registry.GetPacks) == "function" then
        for _, pack in ipairs(Registry.GetPacks()) do
            list[#list + 1] = pack.display
        end
    end
    if #list == 0 then list[1] = ResolveDefaultVoicePack() end
    table.sort(list)
    return list
end

local function RefreshPackDropdownText()
    if not packDropdown then
        return
    end
    local g = EnsureDB()
    packDropdown._currentValue = g.selectedVoicePack
    if packDropdown.SetText then
        packDropdown:SetText(g.selectedVoicePack or L["请选择..."])
    end
end

local function FinalizePackSelection(g, packName)
    local prev = g.selectedVoicePack
    g.selectedVoicePack = packName
    if packName ~= prev then
        local Eng = ExBoss and ExBoss.Voice and ExBoss.Voice.Engine
        if Eng and Eng.InvalidateLabelCache then Eng:InvalidateLabelCache() end
        if Eng and Eng.ApplyEventOverridesToAPI then
            local _, t = GetInstanceInfo()
            if t == "raid" or t == "party" then
                C_Timer.After(0, function() Eng:ApplyEventOverridesToAPI() end)
            end
        end
    end
    RefreshPackDropdownText()
end

local function ShowNonEnglishVoicePackConfirm(packName, onChanged)
    if not StaticPopupDialogs or not StaticPopup_Show then
        return false
    end
    local dialogKey = "EXBOSS_CONFIRM_NON_ENGLISH_VOICE_PACK"
    if not StaticPopupDialogs[dialogKey] then
        StaticPopupDialogs[dialogKey] = {
            text = L["这是非英文语音包。\n确认后将停止英文环境下的自动强制切换。"],
            button1 = L["确定"],
            button2 = CANCEL,
            OnAccept = function(_, data)
                if type(data) ~= "table" then
                    return
                end
                local g = EnsureDB()
                g.allowNonEnglishVoicePackOnEnglishLocale = true
                FinalizePackSelection(g, data.packName)
                if type(data.onChanged) == "function" then
                    data.onChanged()
                end
            end,
            OnCancel = function()
                RefreshPackDropdownText()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    ShowEXBossStaticPopup(dialogKey, nil, nil, {
        packName = packName,
        onChanged = onChanged,
    })
    return true
end

local function SetPack(packName)
    local g = EnsureDB()
    if ShouldForceEnglishVoicePack(g) and tostring(packName or "") ~= ENGLISH_VOICE_PACK then
        local shown = ShowNonEnglishVoicePackConfirm(packName, function()
            if type(RefreshPage) == "function" then
                C_Timer.After(0, function()
                    RefreshPage(false)
                end)
            end
        end)
        if shown then
            return false
        end
    end
    FinalizePackSelection(g, packName)
    return true
end

local PACK_META = {
    ["英文(ENG)"] = {
        displayName = "English (ENG)",
        subtitle    = "English Voice Pack",
        description = "English voice pack with the same standard labels and filenames.",
        addonName   = "EXBOSS-ENG",
    },
    ["EXWIND(默认)"] = {
        displayName = "EXWIND (Default)",
        subtitle    = L["ExBoss 官方默认语音包"],
        description = L["覆盖常见首领与大秘境语音标签，标准参考实现。"],
        addonName   = "EXBOSS-EXWIND",
    },
    ["忘忧景久"] = {
        displayName = "忘忧景久",
        subtitle    = L["中文配音语音包"],
        description = L["忘忧景久语音包，标签与默认包兼容，可直接替换全局语音。"],
        addonName   = "EXBOSS-WYJJ",
    },
    ["顾衣衿-少女音"] = {
        displayName = "顾衣衿 · 少女音",
        subtitle    = L["中文配音语音包"],
        description = L["顾衣衿少女音版本，保留同一套标签结构，便于统一切换。"],
        addonName   = "EXBOSS-GUYIJIN-GIRL",
    },
    ["顾衣衿-御姐音"] = {
        displayName = "顾衣衿 · 御姐音",
        subtitle    = L["中文配音语音包"],
        description = L["顾衣衿御姐音版本，保持标签兼容，适配现有副本方案。"],
        addonName   = "EXBOSS-GUYIJIN-LADY",
    },
    ["Kele"] = {
        displayName = "Kele",
        subtitle    = L["中文配音语音包"],
        description = L["Kele 语音包，标签兼容默认方案，可直接用于副本配置。"],
        addonName   = "EXBOSS-KELE",
    },
    ["夏一可"] = {
        displayName = "夏一可",
        subtitle    = L["中文配音语音包"],
        description = L["夏一可语音包，保持标准标签兼容，可直接切换使用。"],
        addonName   = "EXBOSS-XIAYIKE",
    },
    ["然然"] = {
        displayName = "然然",
        subtitle    = L["中文配音语音包"],
        description = L["然然语音包，包含标准标签与倒数语音。"],
        addonName   = "EXBOSS-RANRAN",
    },
    ["糖糖酱"] = {
        displayName = "糖糖酱",
        subtitle    = L["中文配音语音包"],
        description = L["糖糖酱语音包，标签结构与默认包兼容。"],
        addonName   = "EXBOSS-TANGTANGJIANG",
    },
    ["小羊(Yagi)"] = {
        displayName = "小羊 (Yagi)",
        subtitle    = L["中文配音语音包"],
        description = L["小羊 Yagi 语音包，包含标准标签与倒数语音。"],
        addonName   = "EXBOSS-YAGI",
    },
    ["你好牛(niuniu)"] = {
        displayName = "你好牛 (niuniu)",
        subtitle    = L["中文配音语音包"],
        description = L["你好牛语音包，来源目录为牛师傅，包含标准标签与倒数语音。"],
        addonName   = "EXBOSS-NIUNIU",
    },
    ["绫零(Ayarei)"] = {
        displayName = "绫零 (Ayarei)",
        subtitle    = L["中文配音语音包"],
        description = L["绫零语音包，使用标准标签结构，兼容默认包配置。"],
        addonName   = "EXBOSS-AYAREI",
    },
    ["露露緹婭"] = {
        displayName = "露露緹婭",
        subtitle    = L["中文配音语音包"],
        description = L["露露緹婭语音包，标签结构与默认包兼容。"],
        addonName   = "EXBOSS-RURU",
    },
}

local function NormalizePackKey(name)
    name = tostring(name or "")
    if PACK_META[name] then return name end
    local u = name:upper()
    if name:find("英文", 1, true) or u:find("EXBOSS%-ENG", 1, true) or u:find("%(ENG%)", 1, true) then return "英文(ENG)" end
    if name:find("忘忧景久", 1, true) or u:find("WYJJ", 1, true) then return "忘忧景久" end
    if name:find("少女音", 1, true) or u:find("GUYIJIN%-GIRL", 1, true) then return "顾衣衿-少女音" end
    if name:find("御姐音", 1, true) or u:find("GUYIJIN%-LADY", 1, true) then return "顾衣衿-御姐音" end
    if u:find("KELE", 1, true) then return "Kele" end
    if name:find("夏一可", 1, true) or u:find("XIAYIKE", 1, true) then return "夏一可" end
    if name:find("然然", 1, true) or u:find("RANRAN", 1, true) then return "然然" end
    if name:find("糖糖酱", 1, true) or u:find("TANGTANGJIANG", 1, true) then return "糖糖酱" end
    if name:find("小羊", 1, true) or u:find("YAGI", 1, true) then return "小羊(Yagi)" end
    if name:find("你好牛", 1, true) or name:find("牛师傅", 1, true) or u:find("NIUNIU", 1, true) then return "你好牛(niuniu)" end
    if name:find("绫零", 1, true) or u:find("AYAREI", 1, true) then return "绫零(Ayarei)" end
    if name:find("露露", 1, true) or name:find("緹婭", 1, true) or u:find("RURU", 1, true) or u:find("RURUTIA", 1, true) then
        return
        "露露緹婭"
    end
    if u:find("EXWIND", 1, true) then return "EXWIND(默认)" end
    return name
end

local function GetPackInfo(packName)
    local Registry = ExBoss and ExBoss.Voice and ExBoss.Voice.PackRegistry
    local registered = Registry and Registry.GetPack and Registry.GetPack(packName)
    local key   = NormalizePackKey(packName)
    local base  = PACK_META[key] or {}
    local addon = (registered and registered.addon) or base.addonName
    local title, notes, author, version
    if addon and GetAddOnMetadata then
        title   = GetAddOnMetadata(addon, "Title")
        notes   = GetAddOnMetadata(addon, "Notes")
        author  = GetAddOnMetadata(addon, "Author")
        version = GetAddOnMetadata(addon, "Version")
    end
    local labelCount = 0
    local Catalog = ExBoss and ExBoss.Voice and ExBoss.Voice.LabelCatalog
    if Catalog and Catalog.GetPackLabels then
        local t = Catalog.GetPackLabels(packName)
        if type(t) == "table" then labelCount = #t end
    end
    return {
        displayName = (registered and registered.displayName) or (title ~= "" and title) or base.displayName or key,
        subtitle    = base.subtitle or "Voice Pack",
        description = (notes ~= "" and notes) or base.description or L["暂无描述"],
        author      = (author ~= "" and author) or L["—"],
        version     = version or L["—"],
        labelCount  = labelCount,
    }
end

local function BuildLabelSet(labels)
    local set = {}
    for i = 1, #(labels or {}) do
        local label = tostring(labels[i] or "")
        if label ~= "" then
            set[label] = true
        end
    end
    return set
end

local MISSING_LABEL_IGNORE = {
    ["54321"] = true,
    ["准备跑圈"] = true,
    ["准备追人"] = true,
    ["召唤小怪"] = true,
    ["坦克击退"] = true,
    ["注意击飞"] = true,
    ["集合放圈"] = true,
}

local function GetMissingLabelsForPack(packName)
    local Catalog = ExBoss and ExBoss.Voice and ExBoss.Voice.LabelCatalog
    if not (Catalog and Catalog.GetPackLabels) then
        return nil, L["标签目录未加载"]
    end

    local baseline = Catalog.GetPackLabels("EXWIND(默认)") or {}
    local current = Catalog.GetPackLabels(packName) or {}
    local currentSet = BuildLabelSet(current)

    local missing, seen = {}, {}
    for i = 1, #baseline do
        local label = tostring(baseline[i] or "")
        if label ~= "" and not MISSING_LABEL_IGNORE[label] and not currentSet[label] and not seen[label] then
            seen[label] = true
            missing[#missing + 1] = label
        end
    end
    return missing, nil
end

local function GetProfiles()
    return ExBoss and ExBoss.Voice and ExBoss.Voice.Profiles
end

local function GetBossConfig()
    local cfg = ExBoss and ExBoss.BossConfig
    if type(cfg) == "table" and type(cfg.Ensure) == "function" then
        cfg:Ensure()
        return cfg
    end
    return nil
end

local function GetAppearanceProfiles()
    local profiles = ExBoss and ExBoss.AppearanceProfiles
    return type(profiles) == "table" and profiles or nil
end

local function BuildAppearanceProfileItems()
    local profiles = GetAppearanceProfiles()
    if not profiles or type(profiles.GetProfileItems) ~= "function" then return {} end
    return profiles:GetProfileItems()
end

local function BuildAuthorItems(slotKey)
    local bossCfg = GetBossConfig()
    if bossCfg and bossCfg.GetAuthorItems then
        return bossCfg:GetAuthorItems(slotKey)
    end
    return {}
end

local function BuildAuthorPresetItems(slotKey)
    local bossCfg = GetBossConfig()
    if bossCfg and bossCfg.GetAuthorPresetItems then
        return bossCfg:GetAuthorPresetItems(slotKey)
    end
    return {}
end

local CONFIG_CATEGORY_LABELS = { mplus = L["大秘境"], raid = L["团本"] }

local function BuildAllConfigurationItems()
    local bossCfg = GetBossConfig()
    local items = {}
    for _, category in ipairs({ "mplus", "raid" }) do
        local rows = bossCfg and bossCfg.GetAuthorConfigurationItems and bossCfg:GetAuthorConfigurationItems(category) or {}
        for i = 1, #(rows or {}) do
            local row = rows[i]
            local id = tostring(row.id or "")
            if id ~= "" then
                local name = tostring(row.name or row.id or "")
                local kind = row.imported == true and L["导入 Author"] or L["内置 Author"]
                items[#items + 1] = { string.format("%s · %s：%s", CONFIG_CATEGORY_LABELS[category], kind, name), category .. ":" .. id, row.imported == true, name }
            end
        end
    end
    return items
end

local function BuildGeneralConfigurationItems()
    return {}
end

local function GetLocalizedStaticName(row)
    if type(row) ~= "table" then
        return ""
    end
    local locale = type(GetLocale) == "function" and GetLocale() or ""
    local names = type(row.names) == "table" and row.names or nil
    return tostring(names and names[locale] or row.name or row.nameEN or "")
end

local function BuildSpecDisplayName(specID)
    local db = _G.EXDB
    local row = db and db.SpecByID and db.SpecByID[tonumber(specID)] or nil
    if type(row) ~= "table" then
        return tostring(specID or "")
    end
    local classRow = db and db.Classes and db.Classes[tonumber(row.classID)] or nil
    local icons = {}
    if tonumber(classRow and classRow.icon) then
        icons[#icons + 1] = string.format("|T%d:16:16:0:0|t", tonumber(classRow.icon))
    end
    if tonumber(row.icon) then
        icons[#icons + 1] = string.format("|T%d:16:16:0:0|t", tonumber(row.icon))
    end
    local prefix = #icons > 0 and table.concat(icons, " ") .. " " or ""
    return prefix .. GetLocalizedStaticName(row)
end

local function BuildSpecItems()
    local out = {}
    local specs = _G.EXDB and _G.EXDB.SpecByID or {}
    for specID, row in pairs(specs) do
        local id = tonumber(specID)
        if id and type(row) == "table" then
            out[#out + 1] = { BuildSpecDisplayName(id), tostring(id) }
        end
    end
    table.sort(out, function(a, b)
        return tostring(a[1]) < tostring(b[1])
    end)
    return out
end

local function GetSpecDisplayName(specID)
    return BuildSpecDisplayName(specID)
end

local function FindConfigurationRow(configurationRef)
    local target = tostring(configurationRef or "")
    for _, item in ipairs(BuildAllConfigurationItems()) do
        if tostring(item[2] or "") == target then
            local category, id = target:match("^(mplus|raid):(.+)$")
            return { category = category, id = id, name = tostring(item[4] or id), ref = target,
                builtIn = item[3] ~= true }
        end
    end
    return nil
end

local MODULE_KEY = "ExBoss.VoicePackPage"
local scrollFrame = nil
local scrollChild = nil
local cardSession = nil
local missingDepsText = nil
local pageSyncLock = false
local lastSyncedConfigurationRef = nil
-- 这里的表只承载当前页面控件值/实体管理器的临时选中项。它绝不能使用
-- ModuleDB：语音包、职责 Author 选择和 User 实体本身各有自己的 authority，
-- 持久 ModuleDB 会在重新打开页面时拿旧镜像覆盖这些真实状态。
local pageDraft = nil
local pageStatus = {
    configText = "",
    configOk = nil,
}

local function GetPageDBDefaults()
    return {
        selectedVoicePack = "",
        appearanceProfileID = "",
        author_mplus_tank = "",
        author_mplus_dps = "",
        author_mplus_heal = "",
        author_raid_tank = "",
        author_raid_dps = "",
        author_raid_heal = "",
        specDraftID = "",
        selectedConfiguration = "",
        configurationName = "",
    }
end

local function GetPageDB()
    if type(pageDraft) ~= "table" then
        pageDraft = GetPageDBDefaults()
    end
    return pageDraft
end

local function ApplyStatusColor(text, ok, isError)
    local value = tostring(text or "")
    if value == "" then
        return ""
    end
    if isError == true or ok == false then
        return "|cffff6666" .. value .. "|r"
    end
    if ok == true then
        return "|cff33ee77" .. value .. "|r"
    end
    return "|cffbfc8d6" .. value .. "|r"
end

local function BuildPackItemsForGrid()
    local items = {}
    local packs = GetVoicePacks()
    for i = 1, #packs do
        local pack = tostring(packs[i] or "")
        items[#items + 1] = { pack, pack }
    end
    return items
end

local function GetCurrentPackName()
    local db = GetPageDB()
    local value = tostring(db.selectedVoicePack or "")
    if value == "" then
        value = tostring(EnsureDB().selectedVoicePack or ResolveDefaultVoicePack())
    end
    return value
end

local function GetCurrentPackInfo()
    return GetPackInfo(GetCurrentPackName())
end

local function BuildMissingVoiceText()
    local missing, err = GetMissingLabelsForPack(GetCurrentPackName())
    if err then
        return string.format("|cffff6666%s|r\n%s", L["缺少语音：?"], tostring(err))
    end
    if type(missing) == "table" and #missing > 0 then
        return string.format("|cffffaa55%s|r\n%s", string.format(L["缺少语音：%d"], #missing), table.concat(missing, L["、"]))
    end
    return "|cff33dd88" .. L["缺少语音：0"] .. "|r\n" .. L["已覆盖默认语音标签"]
end

local function BuildDefaultConfigStatusText()
    local bossCfg = GetBossConfig()
    if not bossCfg then
        return L["Boss 配置模块未加载"], false
    end
    return L["各职责只选择 Author；对应的 User 覆盖始终自动绑定该 Author，不能独立选择。"], nil
end

local function SetStatus(text, ok)
    pageStatus.configText = tostring(text or "")
    pageStatus.configOk = ok
    if type(RefreshPage) == "function" then
        RefreshPage(false)
    end
end

local function ShowReloadAfterAuthorSwitchConfirm(slotLabel, intent)
    if not StaticPopupDialogs or not StaticPopup_Show then
        return false
    end
    local dialogKey = "EXBOSS_AUTHOR_SWITCH_RELOAD_CONFIRM"
    if not StaticPopupDialogs[dialogKey] then
        StaticPopupDialogs[dialogKey] = {
            text = L["切换配置：%s\n是否现在重载界面以完整生效？"],
            button1 = L["确定"],
            button2 = L["取消"],
            OnAccept = function(_, data)
                if type(data) ~= "table" or type(data.commit) ~= "function" then
                    return
                end
                data.commit(data)
            end,
            OnCancel = function(_, data)
                if type(data) == "table" and type(data.cancel) == "function" then
                    data.cancel()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    ShowEXBossStaticPopup(dialogKey, tostring(slotLabel or L["当前槽位"]), nil, intent)
    return true
end

local SLOT_ROWS = {
    { slot = "mplus_tank", label = L["大米坦克"] },
    { slot = "mplus_dps", label = L["大米DPS"] },
    { slot = "mplus_heal", label = L["大米治疗"] },
    { slot = "raid_tank", label = L["团本坦克"] },
    { slot = "raid_dps", label = L["团本DPS"] },
    { slot = "raid_heal", label = L["团本治疗"] },
}

-- Grid controller notifications are module-wide. Keep a per-control snapshot
-- so changing one Author dropdown never replays the other five selections.
local lastAuthorPresetValues = {}
local lastAppearanceProfileID = ""

local function ApplyAuthorPresetSelection(slotKey, value)
    local bossCfg = GetBossConfig()
    if not bossCfg then
        SetStatus(L["Boss 配置模块未加载"], false)
        return false
    end
    local slotLabel = tostring(bossCfg:GetSlotLabel(slotKey))
    local function RestorePersistedSelection()
        if type(RefreshPage) == "function" then RefreshPage(false) end
    end
    local shown = ShowReloadAfterAuthorSwitchConfirm(slotLabel, {
        slot = slotKey,
        authorID = value,
        commit = function(data)
            if type(ReloadUI) ~= "function" then
                SetStatus(L["无法重载界面，未切换配置"], false)
                return
            end
            local config = GetBossConfig()
            local ok, err = config and config.SetSelectedAuthorPreset and config:SetSelectedAuthorPreset(data.slot, data.authorID)
            if not ok then
                SetStatus(L["应用失败："] .. tostring(err), false)
                return
            end
            ReloadUI()
        end,
        cancel = RestorePersistedSelection,
    })
    if not shown then
        SetStatus(L["无法显示重载确认，未切换配置"], false)
        return false
    end
    return true
end

local function ApplyAppearanceProfileSelection(value)
    local profiles = GetAppearanceProfiles()
    local profileID = tostring(value or "")
    if not profiles or type(profiles.ActivateProfile) ~= "function" or profileID == "" then
        SetStatus(L["外观配置系统不可用"], false)
        return false
    end
    local shown = ShowReloadAfterAuthorSwitchConfirm(L["外观配置"], {
        profileID = profileID,
        commit = function(data)
            if type(InCombatLockdown) == "function" and InCombatLockdown() then
                SetStatus(L["战斗中不能切换外观配置"], false)
                return
            end
            if type(ReloadUI) ~= "function" then
                SetStatus(L["无法重载界面，未切换配置"], false)
                return
            end
            local currentProfiles = GetAppearanceProfiles()
            if not currentProfiles or type(currentProfiles.ActivateProfile) ~= "function" then
                SetStatus(L["外观配置系统不可用"], false)
                return
            end
            local ok, changedOrReason = currentProfiles:ActivateProfile(data.profileID)
            if not ok then
                SetStatus(L["切换失败："] .. tostring(changedOrReason), false)
                return
            end
            if changedOrReason == true then
                ReloadUI()
            elseif type(RefreshPage) == "function" then
                RefreshPage(false)
            end
        end,
        cancel = function()
            if type(RefreshPage) == "function" then RefreshPage(false) end
        end,
    })
    if not shown then
        SetStatus(L["无法显示重载确认，未切换配置"], false)
        return false
    end
    return true
end

local function SyncRuntimeToPageDB()
    local db = GetPageDB()
    pageSyncLock = true
    db.selectedVoicePack = tostring(EnsureDB().selectedVoicePack or ResolveDefaultVoicePack())

    local profiles = GetAppearanceProfiles()
    local appearanceID = profiles and type(profiles.GetActiveProfileID) == "function" and profiles:GetActiveProfileID() or ""
    db.appearanceProfileID = tostring(appearanceID or "")
    lastAppearanceProfileID = db.appearanceProfileID

    local bossCfg = GetBossConfig()
    for _, row in ipairs(SLOT_ROWS) do
        local author = bossCfg and bossCfg.GetSelectedAuthor and bossCfg:GetSelectedAuthor(row.slot) or ""
        db["author_" .. tostring(row.slot)] = tostring(author or "")
        lastAuthorPresetValues["author_" .. tostring(row.slot)] = db["author_" .. tostring(row.slot)]
    end

    local selectedRef = tostring(db.selectedConfiguration or "")
    local selected = FindConfigurationRow(selectedRef)
    if selected then
        if lastSyncedConfigurationRef ~= selectedRef then
            db.configurationName = tostring(selected.name or "")
        end
        lastSyncedConfigurationRef = selectedRef
    elseif selectedRef ~= "" then
        db.selectedConfiguration = ""
        db.configurationName = ""
        lastSyncedConfigurationRef = nil
    end

    pageSyncLock = false
end

local function SelectConfiguration(configurationRef)
    local db = GetPageDB()
    local row = FindConfigurationRow(configurationRef)
    if not row then
        return
    end
    db.selectedConfiguration = tostring(row.ref or "")
    db.configurationName = tostring(row.name or "")
    lastSyncedConfigurationRef = tostring(row.ref or "")
    if type(RefreshPage) == "function" then
        RefreshPage(false)
    end
end

local function ParseConfigurationRef(configurationRef)
    local category, configID = tostring(configurationRef or ""):match("^([^:]+):(.+)$")
    if category ~= "mplus" and category ~= "raid" then
        return nil, nil
    end
    return category, configID
end

local function RefreshBossConfigurationUI()
    local BossPage = ExBoss and ExBoss.UI and ExBoss.UI.Panel and ExBoss.UI.Panel.BossPage
    if BossPage and BossPage.RefreshSpellUI then
        BossPage:RefreshSpellUI()
    end
end

local function RenameManagedConfiguration()
    local db = GetPageDB()
    local category, configID = ParseConfigurationRef(db.selectedConfiguration)
    local bossCfg = GetBossConfig()
    local name = tostring(db.configurationName or "")
    if not category or not configID or name == "" or not (bossCfg and bossCfg.RenameAuthorConfiguration) then
        SetStatus(L["请选择 Author 配置并输入名称"], false)
        return
    end
    local ok, err = bossCfg:RenameAuthorConfiguration(category, configID, name)
    SetStatus(ok and (L["已重命名："] .. name) or (L["重命名失败："] .. tostring(err)), ok)
    if type(RefreshPage) == "function" then
        RefreshPage(false)
    end
end

local function CopyManagedConfiguration()
    local db = GetPageDB()
    local category, configID = ParseConfigurationRef(db.selectedConfiguration)
    local bossCfg = GetBossConfig()
    local name = tostring(db.configurationName or "")
    if not category or not configID or name == "" or not (bossCfg and bossCfg.DuplicateAuthorConfiguration) then
        SetStatus(L["请选择 Author 配置并输入新名称"], false)
        return
    end

    local ok, result = bossCfg:DuplicateAuthorConfiguration(category, configID, name)
    if not ok then
        SetStatus(L["复制失败："] .. tostring(result), false)
        return
    end

    local copiedID = type(result) == "table" and result.authorID or nil
    if not copiedID then
        SetStatus(L["复制失败：未返回新配置"], false)
        return
    end
    db.selectedConfiguration = category .. ":" .. tostring(copiedID)
    db.configurationName = name
    lastSyncedConfigurationRef = db.selectedConfiguration
    RefreshBossConfigurationUI()
    SetStatus(L["已复制为新配置："] .. name, true)
end

local function DeleteManagedConfiguration()
    local db = GetPageDB()
    local category, configID = ParseConfigurationRef(db.selectedConfiguration)
    local bossCfg = GetBossConfig()
    if not category or not configID or not (bossCfg and bossCfg.DeleteAuthorConfiguration) then
        SetStatus(L["请选择要删除的 Author 配置"], false)
        return
    end
    local selected = FindConfigurationRow(db.selectedConfiguration)
    if selected and selected.builtIn == true then
        SetStatus(L["内置 Author 无法删除"], false)
        return
    end
    local function DeleteNow()
        local ok, err = bossCfg:DeleteAuthorConfiguration(category, configID)
        if ok then
            db.selectedConfiguration = ""
            db.configurationName = ""
            RefreshBossConfigurationUI()
        end
        SetStatus(ok and L["已删除配置"] or (L["删除失败："] .. tostring(err)), ok)
        if type(RefreshPage) == "function" then
            RefreshPage(false)
        end
    end
    local dialogKey = "EXBOSS_CONFIGURATION_DELETE_CONFIRM"
    if StaticPopupDialogs and StaticPopup_Show then
        if not StaticPopupDialogs[dialogKey] then
            StaticPopupDialogs[dialogKey] = {
                text = L["确认删除方案：%s ？"],
                button1 = L["删除"],
                button2 = L["取消"],
                OnAccept = function(_, data)
                    if type(data) == "function" then data() end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end
        ShowEXBossStaticPopup(dialogKey, tostring(db.configurationName or configID), nil, DeleteNow)
    else
        DeleteNow()
    end
end

local function BuildVoicePackInfoBody()
    local info = GetCurrentPackInfo()
    local lines = {
        string.format("|cff66d0ff%s|r", tostring(info.description or "")),
        "",
        string.format("|cffffd16d%s|r  %s", L["标签"], string.format(L["%d 标签"], tonumber(info.labelCount) or 0)),
        string.format("|cffffd16d%s|r  %s", L["作者"], tostring(info.author or L["—"])),
        string.format("|cffffd16d%s|r  %s", L["版本"], tostring(info.version or L["—"])),
        "",
        BuildMissingVoiceText(),
    }
    return table.concat(lines, "\n")
end

local function ToggleCardEdit(cardId)
    if not cardSession then return end
    cardSession:ToggleLiveEdit(cardId)
end

local function BuildCardGUI()
    local info = GetCurrentPackInfo()
    local db = GetPageDB()
    local allConfigurations = BuildAllConfigurationItems()
    local managedConfiguration = FindConfigurationRow(db.selectedConfiguration)
    local builtInDeleteHint = managedConfiguration and managedConfiguration.builtIn == true
        and ApplyStatusColor(L["内置 Author 无法重命名或删除"], false, true) or ""
    local configStatusText, configStatusOk = BuildDefaultConfigStatusText()
    if pageStatus.configText ~= "" then
        configStatusText = pageStatus.configText
        configStatusOk = pageStatus.configOk
    end
    local packSummary = table.concat({
        tostring(info.displayName or ""),
        tostring(info.subtitle or ""),
        BuildVoicePackInfoBody(),
    }, "\n")
    return {
        version = 1,
        title = L["语音 / 配置"],
        description = L["选择语音包、外观配置与各职责 Author。"],
        cards = {
            { id = "layout_tools", title = L["布局编辑"], content = { kind = "grid", items = {
                { key = "btn_edit_pack", type = "button", x = 1, y = 1, w = 46, h = 5, label = L["编辑语音包卡"], func = function() ToggleCardEdit("pack") end },
                { key = "btn_edit_active", type = "button", x = 51, y = 1, w = 46, h = 5, label = L["编辑当前配置卡"], func = function() ToggleCardEdit("active") end },
                { key = "btn_edit_manager", type = "button", x = 101, y = 1, w = 46, h = 5, label = L["编辑 Author 卡"], func = function() ToggleCardEdit("manager") end },
            } } },
            { id = "pack", title = L["语音包"], content = { kind = "grid", items = {
                { key = "selectedVoicePack", type = "dropdown", x = 1, y = 1, w = 80, h = 5, label = L["当前语音包"], items = BuildPackItemsForGrid(), labelPos = "top", labelWrap = true, labelMaxLines = 2, search = true },
                { key = "desc_pack_info", type = "description", x = 1, y = 11, w = 196, h = 30, label = packSummary },
            } } },
            { id = "active", title = L["当前配置选择"], content = { kind = "grid", items = {
                { key = "appearanceProfileID", type = "dropdown", x = 1, y = 1, w = 80, h = 5, label = L["外观配置"], items = BuildAppearanceProfileItems(), labelPos = "top", search = true },
                { key = "author_mplus_tank", type = "dropdown", x = 1, y = 13, w = 80, h = 5, label = L["大秘境坦克 Author"], items = BuildAuthorPresetItems("mplus_tank"), labelPos = "top", search = true },
                { key = "author_mplus_dps", type = "dropdown", x = 101, y = 13, w = 80, h = 5, label = L["大秘境 DPS Author"], items = BuildAuthorPresetItems("mplus_dps"), labelPos = "top", search = true },
                { key = "author_mplus_heal", type = "dropdown", x = 1, y = 25, w = 80, h = 5, label = L["大秘境治疗 Author"], items = BuildAuthorPresetItems("mplus_heal"), labelPos = "top", search = true },
                { key = "author_raid_tank", type = "dropdown", x = 101, y = 25, w = 80, h = 5, label = L["团本坦克 Author"], items = BuildAuthorPresetItems("raid_tank"), labelPos = "top", search = true },
                { key = "author_raid_dps", type = "dropdown", x = 1, y = 37, w = 80, h = 5, label = L["团本 DPS Author"], items = BuildAuthorPresetItems("raid_dps"), labelPos = "top", search = true },
                { key = "author_raid_heal", type = "dropdown", x = 101, y = 37, w = 80, h = 5, label = L["团本治疗 Author"], items = BuildAuthorPresetItems("raid_heal"), labelPos = "top", search = true },
            } } },
            { id = "manager", title = L["Author 配置管理"], content = { kind = "grid", items = {
                { key = "selectedConfiguration", type = "dropdown", x = 1, y = 1, w = 90, h = 5, label = L["选择 Author 配置"], items = allConfigurations, labelPos = "top", search = true },
                { key = "configurationName", type = "input", x = 101, y = 1, w = 90, h = 5, label = L["Author 名称"], labelPos = "top" },
                { key = "btn_copy_configuration", type = "button", x = 1, y = 13, w = 46, h = 5, label = L["复制配置"], func = CopyManagedConfiguration },
                { key = "btn_rename_configuration", type = "button", x = 51, y = 13, w = 46, h = 5, label = L["重命名"], func = RenameManagedConfiguration },
                { key = "btn_delete_configuration", type = "button", x = 101, y = 13, w = 46, h = 5, label = L["删除"], func = DeleteManagedConfiguration },
                { key = "desc_builtin_delete_hint", type = "description", x = 1, y = 21, w = 196, h = 3, label = builtInDeleteHint },
                { key = "desc_config_status", type = "description", x = 1, y = 26, w = 196, h = 4, label = ApplyStatusColor(configStatusText, configStatusOk, configStatusOk == false) },
            } } },
        },
    }
end

local CARD_GUI = BuildCardGUI()
local PAGE_BINDING = { moduleKey = MODULE_KEY, getConfig = GetPageDB }
EXUI:RegisterSettingsPage(MODULE_KEY, CARD_GUI, { addon = "EXBoss" })

local function RenderGrid(contentFrame, resetScroll)
    local Grid = _G.ExwindGrid
    if not Grid then
        return
    end

    if not scrollFrame then
        scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "ScrollFrameTemplate")
        if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
        scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
        root = scrollFrame
    end

    missingDepsText = nil
    scrollFrame:SetParent(contentFrame)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -24, 4)
    if resetScroll == true then
        scrollFrame:SetVerticalScroll(0)
    end
    scrollFrame:Show()

    C_Timer.After(0, function()
        if Page._visible ~= true or not (scrollFrame and scrollFrame:IsShown() and scrollChild) then
            return
        end
        local width = contentFrame:GetWidth()
        if width < 100 then
            width = 1160
        end
        scrollChild:SetWidth(width - 16)
        scrollChild:SetHeight(1)
        scrollChild:SetParent(scrollFrame)
        scrollChild:ClearAllPoints()
        scrollChild:SetPoint("TOPLEFT", 0, 0)
        scrollChild:Show()
        if ExwindTools.UI then
            ExwindTools.UI.ActivePageFrame = scrollChild
            ExwindTools.UI.CurrentModule = MODULE_KEY
        end
        local declaration = EXUI:GetSettingsPage(MODULE_KEY)
        local dynamic = BuildCardGUI()
        for index, card in ipairs(dynamic.cards) do
            declaration.cards[index].content = card.content
        end
        if cardSession then cardSession:Release() end
        cardSession = Grid:MountCards(scrollChild, declaration, {
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
        UpdateConfigurationManagerButtonState(Grid)
    end)
end

UpdateConfigurationManagerButtonState = function(Grid)
    if not Grid or not cardSession then
        return
    end
    -- Keep these controls clickable.  The action itself validates whether the
    -- selected Author was imported and shows the precise reason for built-ins.
    -- Grid's disabled-state handling was leaving the rename button inert even
    -- after an imported Author had been selected.
    local copyButton = Grid:GetSessionWidget(cardSession, "btn_copy_configuration", "manager")
    if copyButton and copyButton.SetEnabled then
        copyButton:SetEnabled(true)
    elseif copyButton and copyButton.Enable then
        copyButton:Enable()
    end
    local renameButton = Grid:GetSessionWidget(cardSession, "btn_rename_configuration", "manager")
    if renameButton and renameButton.SetEnabled then
        renameButton:SetEnabled(true)
    elseif renameButton and renameButton.Enable then
        renameButton:Enable()
    end
    local deleteButton = Grid:GetSessionWidget(cardSession, "btn_delete_configuration", "manager")
    if deleteButton and deleteButton.SetEnabled then
        deleteButton:SetEnabled(true)
    elseif deleteButton and deleteButton.Enable then
        deleteButton:Enable()
    end
end

RefreshPage = function(resetScroll)
    SyncRuntimeToPageDB()
    local contentFrame = Page._contentFrame
    if not contentFrame then
        return
    end
    local EXUI = _G.ExwindTools and _G.ExwindTools.UI
    local Grid = _G.ExwindGrid
    if not (ExwindTools and EXUI and EXUI.CreateDropdown and Grid) then
        if scrollFrame then
            scrollFrame:Hide()
        end
        if not missingDepsText then
            missingDepsText = EXUI:CreateVisualFontString(contentFrame, EXFONTFRAME, "GameFontHighlight")
            missingDepsText:SetPoint("TOPLEFT", 24, -24)
            missingDepsText:SetPoint("RIGHT", contentFrame, "RIGHT", -24, 0)
            missingDepsText:SetJustifyH("LEFT")
            missingDepsText:SetTextColor(1, 0.4, 0.4)
        end
        missingDepsText:SetText(L["语音/配置页面依赖 ExwindTools.UI 与 ExwindGrid，当前未就绪。请确认 ExwindCore 已正确加载后重开面板。"])
        missingDepsText:Show()
        return
    end
    if missingDepsText then
        missingDepsText:Hide()
    end
    RenderGrid(contentFrame, resetScroll == true)
end

local function RefreshActiveSurfaces()
    if pageSyncLock then
        return
    end
    local db = GetPageDB()
    local changed = SetPack(db.selectedVoicePack)
    if changed == false then
        SyncRuntimeToPageDB()
    end
    local appearanceID = tostring(db.appearanceProfileID or "")
    if lastAppearanceProfileID ~= appearanceID then
        lastAppearanceProfileID = appearanceID
        ApplyAppearanceProfileSelection(appearanceID)
    end
    for key, value in pairs(db) do
        if type(key) == "string" and key:sub(1, 7) == "author_" then
            local selected = tostring(value or "")
            if lastAuthorPresetValues[key] ~= selected then
                lastAuthorPresetValues[key] = selected
                ApplyAuthorPresetSelection(key:sub(8), selected)
            end
        end
    end

end

function Page:Render(contentFrame)
    Page._contentFrame = contentFrame
    Page._visible = true
    RefreshPage(true)
end

function Page:Hide()
    Page._visible = false
    if EXUI.ActiveCardSession == cardSession then EXUI.ActiveCardSession = nil end
    if cardSession then cardSession:Release(); cardSession = nil end
    if scrollFrame then
        scrollFrame:Hide()
    end
    if missingDepsText then
        missingDepsText:Hide()
    end
end

if EXUI then
    EXUI:RegisterModuleValueController(MODULE_KEY, {
        RefreshActiveSurfaces = function()
            if Page._visible == true then
                RefreshActiveSurfaces()
            end
        end,
    })
end
