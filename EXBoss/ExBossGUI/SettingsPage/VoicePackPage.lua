---@diagnostic disable: undefined-global, undefined-field, need-check-nil
-- =============================================================
-- ExBossGUI/SettingsPage/VoicePackPage.lua
-- 语音包选择页
-- =============================================================

ExBoss.UI.Panel.VoicePackPage             = ExBoss.UI.Panel.VoicePackPage or {}
local Page                                = ExBoss.UI.Panel.VoicePackPage
local EXUI                                = _G.ExwindTools and _G.ExwindTools.UI
local GC                                  = _G.ExwindTools and _G.ExwindTools.GUIColors
local L                                   = (ExBoss and ExBoss.L) or
    setmetatable({}, { __index = function(_, k) return k end })

local root                                = nil
local packDropdown                        = nil
local ui                                  = {}
local RefreshPage                         = nil
local UpdateConfigurationManagerButtonState = nil
local DEFAULT_VOICE_PACK                  = "EXWIND(默认)"
local ENGLISH_VOICE_PACK                  = "英文(ENG)"

-- ─── 帮助函数 ─────────────────────────────────────────────────

local function Bg(parent, r, g, b, a)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    if r ~= nil and g ~= nil and b ~= nil then
        f:SetBackdropColor(r, g, b, a or 0.92)
    else
        f:SetBackdropColor(unpack(GC.card))
    end
    f:SetBackdropBorderColor(unpack(GC.panelBorder))
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
    t:SetColorTexture(unpack(GC.popupDivider))
    t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offY or -10)
    t:SetPoint("TOPRIGHT", parent, "RIGHT", -16, 0)
    return t
end

local function Chip(parent, r, g, b)
    local chip = Bg(parent, r * 0.18, g * 0.18, b * 0.18, 0.88)
    chip:SetBackdropBorderColor(r * 0.6, g * 0.6, b * 0.6, 0.90)
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
    StaticPopup_Show(dialogKey, nil, nil, {
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
local GRID_COLS = 200
local scrollFrame = nil
local scrollChild = nil
local missingDepsText = nil
local pageSyncLock = false
local pageLayoutData = nil
local lastSyncedConfigurationRef = nil
-- 这里的表只承载当前页面控件值/实体管理器的临时选中项。它绝不能使用
-- ModuleDB：语音包、职责 Author 选择和 User 实体本身各有自己的 authority，
-- 持久 ModuleDB 会在重新打开页面时拿旧镜像覆盖这些真实状态。
local pageDraft = nil

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

local function IsGridEditActive()
    local Grid = _G.ExwindGrid
    return Grid and Grid.IsLiveEditing == true and Grid.LiveContainer == scrollChild
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

local function SetStatus(text, ok)
    local message = ApplyStatusColor(text, ok, ok == false)
    if message ~= "" then
        if ExBoss.Print and type(ExBoss.Print.Say) == "function" then
            ExBoss.Print.Say(message)
        else
            print(message)
        end
    end
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
    StaticPopup_Show(dialogKey, tostring(slotLabel or L["当前槽位"]), nil, intent)
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
        StaticPopup_Show(dialogKey, tostring(db.configurationName or configID), nil, DeleteNow)
    else
        DeleteNow()
    end
end

local function FindLayoutEntry(items, key)
    if type(items) == "table" and type(items.cards) == "table" then
        for _, card in ipairs(items.cards) do
            local found = FindLayoutEntry(card.content and card.content.items, key)
            if found then return found end
        end
    end
    if type(items) == "table" and type(items.sections) == "table" then
        for i = 1, #items.sections do
            local section = items.sections[i]
            if section.id == key then return section end
            if type(section.description) == "table" and section.description.key == key then return section.description end
            if section.footerDescription and section.footerDescription.key == key then return section.footerDescription end
            local found = FindLayoutEntry(section.items, key)
            if found then return found end
        end
    end
    for i = 1, #(items or {}) do
        local item = items[i]
        if type(item) == "table" then
            if item.key == key then
                return item
            end
            if type(item.description) == "table" and item.description.key == key then return item.description end
            if type(item.children) == "table" then
                local found = FindLayoutEntry(item.children, key)
                if found then
                    return found
                end
            end
        end
    end
    return nil
end

-- Choice and management cards share the existing draft; documentation is display-only.
local DOCUMENTATION_URL = "https://exwind.net/exboss/config"
local DOCUMENTATION_RENDERER = "ExBoss.VoicePackDocumentation"

local function RegisterDocumentationRenderer(Grid)
    if Grid:GetCustomRenderer(DOCUMENTATION_RENDERER) then return end
    Grid:RegisterCustomRenderer(DOCUMENTATION_RENDERER, {
        mount = function(host)
            local input = EXUI:CreateEditBox(host, DOCUMENTATION_URL, 280, 28, nil, {})
            input:SetPoint("TOPLEFT", 0, 0)
            input:SetPoint("TOPRIGHT", 0, 0)
            local edit = input.editBox or input
            edit:SetScript("OnTextChanged", function(self)
                if self:GetText() ~= DOCUMENTATION_URL then
                    self:SetText(DOCUMENTATION_URL)
                    self:HighlightText()
                end
            end)
            edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
            edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
            host.documentationInput = input
        end,
        layout = function() return 28 end,
        release = function(host)
            local input = host.documentationInput
            if input then
                local edit = input.editBox or input
                edit:SetScript("OnMouseUp", nil)
                edit:SetScript("OnEditFocusGained", nil)
                edit:ClearFocus()
                if input._fromPool and _G.ExwindFactory then
                    _G.ExwindFactory:Release(input._fromPool, input)
                else
                    input:Hide()
                    input:SetParent(nil)
                end
            end
            host.documentationInput = nil
        end,
    })
end

local function BuildConfigurationLayout()
    local function Card(id, title, placement, items)
        local rows = {}
        local actions
        for index, item in ipairs(items) do
            item.x, item.y, item.w, item.h = 1, index, 200, 1
            item.measure = { preferredHeight = 28, minHeight = 28 }
            if item.type == "select" then
                item.items, item.originalOptions = item.originalOptions, nil
            end
            if item.type == "select" or item.type == "input" then
                rows[#rows + 1] = { key = item.key, label = item.label }
            elseif item.type == "button" then
                if not actions then
                    actions = { controls = {} }
                    rows[#rows + 1] = actions
                end
                local width = item.key == "btn_copy_configuration" and 140
                    or item.key == "btn_rename_configuration" and 100 or 80
                actions.controls[#actions.controls + 1] = { key = item.key, width = width }
            else
                rows[#rows + 1] = { controls = { { key = item.key } } }
            end
        end
        return { id = id, title = title, placement = placement,
            content = { kind = "grid", items = items },
            settingsList = { title = title, preserveHeader = false, rows = rows } }
    end
    local halfWidth = { ratio = 0.5, offset = -8 }
    local choices = {
        { key = "appearanceProfileID", type = "select", label = L["外观配置"], originalOptions = BuildAppearanceProfileItems(), search = true },
        { key = "author_mplus_tank", type = "select", label = L["大秘境 · 坦克"], originalOptions = BuildAuthorPresetItems("mplus_tank"), search = true },
        { key = "author_mplus_dps", type = "select", label = L["大秘境 · 输出"], originalOptions = BuildAuthorPresetItems("mplus_dps"), search = true },
        { key = "author_mplus_heal", type = "select", label = L["大秘境 · 治疗"], originalOptions = BuildAuthorPresetItems("mplus_heal"), search = true },
        { key = "author_raid_tank", type = "select", label = L["团本 · 坦克"], originalOptions = BuildAuthorPresetItems("raid_tank"), search = true },
        { key = "author_raid_dps", type = "select", label = L["团本 · 输出"], originalOptions = BuildAuthorPresetItems("raid_dps"), search = true },
        { key = "author_raid_heal", type = "select", label = L["团本 · 治疗"], originalOptions = BuildAuthorPresetItems("raid_heal"), search = true },
        { key = "selectedVoicePack", type = "select", label = L["当前语音包"], originalOptions = BuildPackItemsForGrid(), search = true },
    }
    local manager = {
        { key = "selectedConfiguration", type = "select", label = L["选择配置"], originalOptions = BuildAllConfigurationItems(), search = true },
        { key = "configurationName", type = "input", label = L["新名称"] },
        { key = "btn_copy_configuration", type = "button", label = L["复制为新配置"], variant = "primary", func = CopyManagedConfiguration },
        { key = "btn_rename_configuration", type = "button", label = L["重命名"], func = RenameManagedConfiguration },
        { key = "btn_delete_configuration", type = "button", label = L["删除"], variant = "danger", func = DeleteManagedConfiguration },
    }
    return { version = 1, title = L["语音 / 配置"], settingsListWidthPercent = 100, cards = {
        Card("active-configurations", L["配置与语音选择"], { target = "$container", point = "TOPLEFT", relativePoint = "TOPLEFT", width = halfWidth }, choices),
        Card("configuration-manager", L["配置管理"], { target = "active-configurations", side = "right", align = "start", gap = 16, width = halfWidth }, manager),
        Card("configuration-documentation", L["配置说明"], { target = "configuration-manager", side = "below", align = "end", gap = 16, width = halfWidth }, {
            { key = "config_documentation", type = "custom", renderer = DOCUMENTATION_RENDERER },
        }),
    } }
end

local function BuildLayout()
    return BuildConfigurationLayout()
end

local function UpdateLayoutData(layout)
    if type(layout) ~= "table" then
        return
    end

    local updates = {
        selectedVoicePack = { items = BuildPackItemsForGrid() },
        appearanceProfileID = { items = BuildAppearanceProfileItems() },
        author_mplus_tank = { items = BuildAuthorPresetItems("mplus_tank") },
        author_mplus_dps = { items = BuildAuthorPresetItems("mplus_dps") },
        author_mplus_heal = { items = BuildAuthorPresetItems("mplus_heal") },
        author_raid_tank = { items = BuildAuthorPresetItems("raid_tank") },
        author_raid_dps = { items = BuildAuthorPresetItems("raid_dps") },
        author_raid_heal = { items = BuildAuthorPresetItems("raid_heal") },
    }

    for key, fields in pairs(updates) do
        local item = FindLayoutEntry(layout, key)
        if item then
            for field, value in pairs(fields) do
                item[field] = value
            end
        end
    end
end

local function GetOrBuildLayout()
    -- 专精规则与配置卡片数量会动态变化，每次刷新重新生成布局。
    pageLayoutData = BuildLayout()
    UpdateLayoutData(pageLayoutData)
    return pageLayoutData
end

-- [混合函数边界] RenderGrid 内只可调整 Scroll/Grid 几何；动态重建布局、RegisterModuleLayout、编辑状态和延迟 guard 禁止修改。
local function RenderGrid(contentFrame, resetScroll)
    local Grid = _G.ExwindGrid
    if not Grid then
        return
    end

    RegisterDocumentationRenderer(Grid)
    local layout = GetOrBuildLayout()
    ExwindTools:RegisterModuleLayout(MODULE_KEY, layout)

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
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -18, 4)
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
        if Page._cardSession and type(Page._cardSession.Release) == "function" then
            Page._cardSession:Release()
            Page._cardSession = nil
        end
        Page._cardSession = Grid:MountCards(scrollChild, layout, {
            pageId = MODULE_KEY,
            regionId = "voice-pack",
            config = GetPageDB(),
            moduleKey = MODULE_KEY,
            scrollFrame = scrollFrame,
        })
        UpdateConfigurationManagerButtonState(Grid)
    end)
end

UpdateConfigurationManagerButtonState = function(Grid)
    if not (Grid and Grid.FindMountedWidget and scrollChild) then
        return
    end
    -- Keep these controls clickable.  The action itself validates whether the
    -- selected Author was imported and shows the precise reason for built-ins.
    -- Grid's disabled-state handling was leaving the rename button inert even
    -- after an imported Author had been selected.
    local copyButton = Grid:FindMountedWidget(scrollChild, "btn_copy_configuration")
    if copyButton and copyButton.SetEnabled then
        copyButton:SetEnabled(true)
    elseif copyButton and copyButton.Enable then
        copyButton:Enable()
    end
    local renameButton = Grid:FindMountedWidget(scrollChild, "btn_rename_configuration")
    if renameButton and renameButton.SetEnabled then
        renameButton:SetEnabled(true)
    elseif renameButton and renameButton.Enable then
        renameButton:Enable()
    end
    local deleteButton = Grid:FindMountedWidget(scrollChild, "btn_delete_configuration")
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
