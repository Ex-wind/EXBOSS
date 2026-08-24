-- =============================================================
-- EXBoss 更新日志源：拥有 EXBoss 正文与 EXBOSS12S2 已读状态。
-- 窗口、TAB 与切换行为由 ExwindCore 的统一查看器负责。
-- =============================================================

local ExBoss = _G.ExBoss
if not ExBoss then return end

local ExwindTools = _G.ExwindTools
local Viewer = ExwindTools and ExwindTools.ChangelogViewer
if not Viewer then return end

local L = ExBoss.L or setmetatable({}, { __index = function(_, key) return key end })

local function GetChangelogDB()
    EXBOSS12S2 = EXBOSS12S2 or {}
    EXBOSS12S2.Changelog = type(EXBOSS12S2.Changelog) == "table" and EXBOSS12S2.Changelog or {}
    return EXBOSS12S2.Changelog
end

local function GetData()
    local metadata = _G.ExBoss_MetaData
    return type(metadata) == "table" and metadata.changelog or nil
end

local function GetVersion()
    local data = GetData()
    return type(data) == "table" and tostring(data.version or "") or ""
end

local function GetContent()
    local data = GetData()
    return type(data) == "table" and tostring(data.content or "") or ""
end

local function GetFontSize()
    local data = GetData()
    return type(data) == "table" and data.fontSize or 14
end

local function GetChangelogLocale()
    if type(ExBoss.GetEffectiveLocale) == "function" and type(ExBoss.GetLocaleMode) == "function" then
        local locale = tostring(ExBoss:GetEffectiveLocale(ExBoss:GetLocaleMode()) or ""):gsub("%s+", "")
        if locale ~= "" then
            return locale == "enGB" and "enUS" or locale
        end
    end
    local locale = ExwindTools and ExwindTools.GetEffectiveLocale and ExwindTools:GetEffectiveLocale()
    if not locale or locale == "" then
        locale = (GetLocale and GetLocale()) or "zhCN"
    end
    return locale == "enGB" and "enUS" or locale
end

local function IsChineseLocale()
    local locale = GetChangelogLocale()
    return locale == "zhCN" or locale == "zhTW"
end

local function ResolveLocalizedName(metadata, fallback)
    if not metadata then return fallback end
    local locale = GetChangelogLocale()
    local name = metadata[locale]
    if name and name ~= "" then return name end
    if IsChineseLocale() then return metadata.zhCN or metadata.name or fallback end
    return metadata.enUS or metadata.nameEN or metadata.name or fallback
end

local function ResolveSpellToken(idText)
    local spellID = tonumber(idText)
    if not spellID then return "%s:" .. tostring(idText or "") end
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    local iconMarkup = icon and string.format("|T%s:0|t ", tostring(icon)) or ""
    local link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)
    if type(link) == "string" and link ~= "" then return iconMarkup .. link end
    return string.format("%s|cffff7d0a[spell:%d]|r", iconMarkup, spellID)
end

local function ResolveInstanceToken(idText)
    local mapID = tonumber(idText)
    local database = ExwindTools and ExwindTools.DB_Static
    if not mapID or not database then return "%i:" .. tostring(idText or "") end
    return string.format("|cffffb84d%s|r", ResolveLocalizedName(database:GetInstanceNoteMetaByMapID(mapID), "%i:" .. idText))
end

local function ResolveEncounterToken(idText)
    local encounterID = tonumber(idText)
    local database = ExwindTools and ExwindTools.DB_Static
    if not encounterID or not database then return "%e:" .. tostring(idText or "") end
    return string.format("|cffffb84d%s|r", ResolveLocalizedName(database:GetEncounterNoteMeta(encounterID), "%e:" .. idText))
end

local function ResolveNPCToken(idText)
    local npcID = tonumber(idText)
    if not npcID then return "%n:" .. tostring(idText or "") end
    local entries = rawget(_G, "EXBOSS_TRASH_CD_LOCALE")
    local entry = entries and entries[npcID]
    local name = entry and (entry[GetChangelogLocale()] or entry.enUS or entry.zhCN)
    return name and string.format("|cffffb84d%s|r", name) or ("%n:" .. idText)
end

local function TransformLine(line)
    line = tostring(line or "")
    line = line:gsub("%%s:(%d+)", ResolveSpellToken)
    line = line:gsub("%%i:(%d+)", ResolveInstanceToken)
    line = line:gsub("%%e:(%d+)", ResolveEncounterToken)
    line = line:gsub("%%n:(%d+)", ResolveNPCToken)
    return line:gsub("%%(%d+)", ResolveSpellToken)
end

local function VersionScore(versionText)
    local y, m, d, hm = tostring(versionText or ""):lower():gsub("^v", ""):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not y then return nil end
    return (tonumber(y) or 0) * 100000000 + (tonumber(m) or 0) * 1000000 + (tonumber(d) or 0) * 10000 + (tonumber(hm) or 0)
end

local function IsVersionNewer(newVersion, oldVersion)
    if not oldVersion or oldVersion == "" then return true end
    local newScore, oldScore = VersionScore(newVersion), VersionScore(oldVersion)
    if newScore and oldScore then return newScore > oldScore end
    return tostring(newVersion) ~= tostring(oldVersion)
end

local function HasContent()
    return GetContent():match("%S") ~= nil
end

local function MarkSeen()
    local db = GetChangelogDB()
    db.LastSeenVersion = tostring(ExBoss.VERSION or "")
    db.LastSeenAt = date("%Y-%m-%d %H:%M:%S")
end

local function MarkPopupShown()
    local db = GetChangelogDB()
    db.LastPopupVersion = GetVersion()
    db.LastPopupAt = date("%Y-%m-%d %H:%M:%S")
end

Viewer:RegisterSource("boss", {
    title = "EXBoss",
    GetVersion = GetVersion,
    GetContent = GetContent,
    GetFontSize = GetFontSize,
    IsChineseLocale = IsChineseLocale,
    TransformLine = TransformLine,
    MarkSeen = MarkSeen,
    MarkPopupShown = MarkPopupShown,
})

function ExBoss:ShowChangelog(options)
    options = options or {}
    return Viewer:Show("boss", {
        markSeen = options.markSeen ~= false,
        markShown = options.markShown ~= false,
    })
end

function ExBoss:ShouldPopupChangelog()
    if not HasContent() then return false end
    return IsVersionNewer(GetVersion(), GetChangelogDB().LastPopupVersion)
end

function ExBoss:HandleChangelogPopupOnUIOpen()
    MarkSeen()
    if self:ShouldPopupChangelog() then
        Viewer:Show("boss", { markShown = true })
    end
end

MarkSeen()
