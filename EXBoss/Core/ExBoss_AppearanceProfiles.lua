---@diagnostic disable: undefined-global

-- Appearance profiles deliberately own only EXBoss display/module settings.
-- Boss data, Author/User layers and unrelated global preferences must never
-- cross this boundary.

local ExwindTools = _G.ExwindTools
if not ExwindTools then
    return
end

ExBoss = ExBoss or {}
ExBoss.AppearanceProfiles = ExBoss.AppearanceProfiles or {}
local Profiles = ExBoss.AppearanceProfiles
local L = ExBoss.L or setmetatable({}, { __index = function(_, key) return key end })

local PROFILE_SCHEMA = 1
local TRANSFER_VERSION = 1
local TRANSFER_PREFIX = "!EXBOSSAP1!"
local MAX_TRANSFER_LENGTH = 250000
local MAX_VALUE_DEPTH = 40
local MAX_VALUE_COUNT = 30000

-- This is intentionally an explicit allow-list.  Do not replace it with a
-- walk over ModuleDB: ModuleDB also contains page mirrors and non-appearance
-- state which must remain private to their own systems.
local MODULE_KEYS = {
    "ExBoss.BunBar",
    "ExBoss.TimerBar",
    "ExBoss.RingProgress",
    "ExBoss.IconAlert",
    "ExBoss.CastProgressBar",
    "ExBoss.ExtraShieldBar",
    "ExBoss.Countdown",
    "ExBoss.FlashTextMedium",
    "ExBoss.Tools.MythicCast",
    "ExBoss.Tools.InterruptTracker",
}

local MODULE_KEY_SET = {}
for _, key in ipairs(MODULE_KEYS) do
    MODULE_KEY_SET[key] = true
end

local UI_GENERAL_KEYS = {
    barDisplayMode = true,
    showSpellOccurrenceCount = true,
    panelScale = true,
}

local VOICE_COLOR_KEYS = {
    colorSchemes = true,
    customColors = true,
    extraCustomColors = true,
}

local function Trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Root()
    local root = _G.EXBOSS12S2
    if type(root) ~= "table" then
        return nil, "EXBoss settings storage is unavailable"
    end
    if type(root.ModuleDB) ~= "table" then
        root.ModuleDB = {}
    end
    return root
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function Copy(value, seen)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "string" then
        return value
    end
    if kind == "number" then
        if not IsFiniteNumber(value) then
            return nil, "unsupported numeric value"
        end
        return value
    end
    if kind ~= "table" then
        return nil, "unsupported value type: " .. kind
    end

    seen = seen or {}
    if seen[value] then
        return nil, "cyclic configuration table"
    end
    seen[value] = true

    local out = {}
    for key, child in pairs(value) do
        local keyKind = type(key)
        if keyKind ~= "string" and keyKind ~= "number" then
            seen[value] = nil
            return nil, "unsupported configuration key"
        end
        if keyKind == "number" and not IsFiniteNumber(key) then
            seen[value] = nil
            return nil, "unsupported numeric key"
        end
        local copied, reason = Copy(child, seen)
        if reason then
            seen[value] = nil
            return nil, reason
        end
        out[key] = copied
    end

    seen[value] = nil
    return out
end

local function ValidateValue(value, state, depth)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "string" then
        return true
    end
    if kind == "number" then
        return IsFiniteNumber(value), "unsupported numeric value"
    end
    if kind ~= "table" then
        return false, "unsupported value type: " .. kind
    end
    if depth >= MAX_VALUE_DEPTH then
        return false, "configuration nesting is too deep"
    end
    if state.seen[value] then
        return false, "cyclic configuration table"
    end
    state.count = state.count + 1
    if state.count > MAX_VALUE_COUNT then
        return false, "configuration contains too many values"
    end

    state.seen[value] = true
    for key, child in pairs(value) do
        local keyKind = type(key)
        if keyKind ~= "string" and keyKind ~= "number" then
            state.seen[value] = nil
            return false, "unsupported configuration key"
        end
        if keyKind == "number" and not IsFiniteNumber(key) then
            state.seen[value] = nil
            return false, "unsupported numeric key"
        end
        local ok, reason = ValidateValue(child, state, depth + 1)
        if not ok then
            state.seen[value] = nil
            return false, reason
        end
    end
    state.seen[value] = nil
    return true
end

local function Only(tableValue, allowed)
    if type(tableValue) ~= "table" then
        return false
    end
    for key in pairs(tableValue) do
        if allowed[key] ~= true then
            return false
        end
    end
    return true
end

local function CopyKnownFields(source, allowed)
    local out = {}
    source = type(source) == "table" and source or {}
    for key in pairs(allowed) do
        if source[key] ~= nil then
            local copied, reason = Copy(source[key])
            if reason then
                return nil, reason
            end
            out[key] = copied
        end
    end
    return out
end

-- ModuleDB can contain transient runtime fields (for example FlashText's
-- temporary duration override).  The declared module schema is the only
-- trustworthy boundary for a transferable module configuration.
local function ProjectDeclaredModule(moduleKey)
    local declarations = ExwindTools.ModuleDefaultDeclarations
    local registered = type(declarations) == "table" and declarations[moduleKey] or nil
    if type(registered) ~= "table" or type(registered.schema) ~= "table"
        or type(ExwindTools.ExportModuleDefaults) ~= "function" then
        return nil, "module has no declared export schema"
    end

    local ok, projected = pcall(ExwindTools.ExportModuleDefaults, ExwindTools, moduleKey)
    if not ok or type(projected) ~= "table" then
        return nil, tostring(projected or "module projection failed")
    end

    local out = {}
    for _, rule in ipairs(registered.schema) do
        local group = projected[rule.group]
        if type(group) ~= "table" then
            return nil, "module projection is missing group: " .. tostring(rule.group)
        end
        if rule.root == true then
            for field, value in pairs(group) do
                out[field] = value
            end
        else
            out[rule.target or rule.group] = group
        end
    end
    return Copy(out)
end

local function CaptureAppearance()
    local root, rootReason = Root()
    if not root then
        return nil, rootReason
    end

    local modules = {}
    for _, key in ipairs(MODULE_KEYS) do
        local value = root.ModuleDB[key]
        if type(value) == "table" then
            local copied, reason = ProjectDeclaredModule(key)
            -- A module may have a SavedVariables table before its schema has
            -- registered (or may be disabled for this login).  That must not
            -- make the whole default appearance profile disappear.  It is
            -- simply omitted until it can be exported through its declared
            -- schema; omitted fields are deliberately non-destructive when a
            -- profile is later enabled.
            if copied and not reason then
                modules[key] = copied
            end
        end
    end

    local ui = type(root.ui) == "table" and root.ui or {}
    local uiGeneral, uiReason = CopyKnownFields(ui.general, UI_GENERAL_KEYS)
    if not uiGeneral then
        return nil, "ui.general: " .. tostring(uiReason)
    end

    local voice = type(root.voice) == "table" and root.voice or {}
    local voiceColors, voiceReason = CopyKnownFields(voice, VOICE_COLOR_KEYS)
    if not voiceColors then
        return nil, "voice colors: " .. tostring(voiceReason)
    end

    local kyrakkaPosition = nil
    if root.kyrakkaWindFirePosition ~= nil then
        kyrakkaPosition, rootReason = Copy(root.kyrakkaWindFirePosition)
        if rootReason then
            return nil, "Kyrakka position: " .. tostring(rootReason)
        end
    end

    return {
        modules = modules,
        root = {
            uiGeneral = uiGeneral,
            voiceColors = voiceColors,
            kyrakkaWindFirePosition = kyrakkaPosition,
        },
    }
end

local function ValidateAppearance(value)
    if type(value) ~= "table" or not Only(value, { modules = true, root = true })
        or type(value.modules) ~= "table" or type(value.root) ~= "table" then
        return false, "invalid appearance configuration"
    end
    if not Only(value.modules, MODULE_KEY_SET) then
        return false, "appearance configuration contains an unknown module"
    end
    if not Only(value.root, { uiGeneral = true, voiceColors = true, kyrakkaWindFirePosition = true })
        or type(value.root.uiGeneral) ~= "table" or type(value.root.voiceColors) ~= "table" then
        return false, "invalid appearance root configuration"
    end
    if not Only(value.root.uiGeneral, UI_GENERAL_KEYS) or not Only(value.root.voiceColors, VOICE_COLOR_KEYS) then
        return false, "appearance configuration contains an unknown global setting"
    end

    local state = { seen = {}, count = 0 }
    for key, moduleDB in pairs(value.modules) do
        if MODULE_KEY_SET[key] ~= true or type(moduleDB) ~= "table" then
            return false, "invalid module configuration"
        end
        local ok, reason = ValidateValue(moduleDB, state, 0)
        if not ok then
            return false, key .. ": " .. tostring(reason)
        end
    end
    local ok, reason = ValidateValue(value.root.uiGeneral, state, 0)
    if not ok then
        return false, "ui.general: " .. tostring(reason)
    end
    ok, reason = ValidateValue(value.root.voiceColors, state, 0)
    if not ok then
        return false, "voice colors: " .. tostring(reason)
    end
    if value.root.kyrakkaWindFirePosition ~= nil then
        ok, reason = ValidateValue(value.root.kyrakkaWindFirePosition, state, 0)
        if not ok then
            return false, "Kyrakka position: " .. tostring(reason)
        end
    end
    return true
end

local function NewDefaultProfile()
    local appearance, reason = CaptureAppearance()
    if not appearance then
        return nil, reason
    end
    return {
        id = "default",
        name = L["默认外观"],
        appearance = appearance,
    }
end

local function EnsureStore()
    local root, rootReason = Root()
    if not root then
        return nil, rootReason
    end
    if type(root.appearanceProfiles) ~= "table" then
        root.appearanceProfiles = {}
    end
    local store = root.appearanceProfiles
    store.schema = PROFILE_SCHEMA
    if type(store.profiles) ~= "table" then
        store.profiles = {}
    end
    if type(store.profiles.default) ~= "table" then
        local profile, reason = NewDefaultProfile()
        if not profile then
            return nil, reason
        end
        store.profiles.default = profile
    end
    local activeID = Trim(store.activeProfileID)
    if type(store.profiles[activeID]) ~= "table" then
        activeID = "default"
    end
    store.activeProfileID = activeID
    return store
end

local function ProfileName(profile, fallback)
    local name = Trim(type(profile) == "table" and profile.name or "")
    if name == "" then
        name = fallback or L["外观配置"]
    end
    -- Default names created before locale support were persisted in the
    -- SavedVariables as Chinese.  They are system labels rather than user
    -- names, so resolve their display value at render/export/import time.
    -- Any other profile name stays exactly as the user entered it.
    if name == "默认外观" or name == "Default Appearance" then
        name = L["默认外观"]
    elseif name == "导入的外观" or name == "Imported Appearance" then
        name = L["导入的外观"]
    end
    return name:sub(1, 80)
end

local function SaveActiveProfile()
    local store, storeReason = EnsureStore()
    if not store then
        return false, storeReason
    end
    local appearance, reason = CaptureAppearance()
    if not appearance then
        return false, reason
    end
    local profile = store.profiles[store.activeProfileID]
    if type(profile) ~= "table" then
        return false, "active appearance profile is unavailable"
    end
    profile.id = store.activeProfileID
    profile.name = ProfileName(profile, store.activeProfileID)
    profile.appearance = appearance
    return true
end

local function ReplaceKnownFields(target, source, allowed)
    for key in pairs(allowed) do
        if source[key] ~= nil then
            local copied, reason = Copy(source[key])
            if reason then
                return false, reason
            end
            target[key] = copied
        end
    end
    return true
end

local function ApplyAppearance(appearance)
    local valid, reason = ValidateAppearance(appearance)
    if not valid then
        return false, reason
    end
    local root, rootReason = Root()
    if not root then
        return false, rootReason
    end

    -- Copy every selected value before touching live settings.  A malformed
    -- profile therefore cannot leave a partly-applied visual setup behind.
    local prepared, copyReason = Copy(appearance)
    if not prepared then
        return false, copyReason
    end

    for _, key in ipairs(MODULE_KEYS) do
        local source = prepared.modules[key]
        local target = root.ModuleDB[key]
        if source ~= nil and type(target) == "table" then
            for childKey in pairs(target) do
                target[childKey] = nil
            end
            for childKey, childValue in pairs(source) do
                target[childKey] = childValue
            end
        elseif source ~= nil then
            root.ModuleDB[key] = source
        end
    end

    root.ui = type(root.ui) == "table" and root.ui or {}
    root.ui.general = type(root.ui.general) == "table" and root.ui.general or {}
    local ok, fieldReason = ReplaceKnownFields(root.ui.general, prepared.root.uiGeneral, UI_GENERAL_KEYS)
    if not ok then
        return false, fieldReason
    end

    root.voice = type(root.voice) == "table" and root.voice or {}
    ok, fieldReason = ReplaceKnownFields(root.voice, prepared.root.voiceColors, VOICE_COLOR_KEYS)
    if not ok then
        return false, fieldReason
    end
    if prepared.root.kyrakkaWindFirePosition ~= nil then
        root.kyrakkaWindFirePosition = prepared.root.kyrakkaWindFirePosition
    end
    return true
end

local function Libs()
    return LibStub and LibStub("LibSerialize", true), LibStub and LibStub("LibDeflate", true)
end

local function Encode(payload)
    local serialize, deflate = Libs()
    if not serialize or not deflate then
        return nil, "missing LibSerialize/LibDeflate"
    end
    local packed = serialize:Serialize(payload)
    if type(packed) ~= "string" then
        return nil, "serialize failed"
    end
    packed = deflate:CompressDeflate(packed)
    if type(packed) ~= "string" then
        return nil, "compress failed"
    end
    packed = deflate:EncodeForPrint(packed)
    if type(packed) ~= "string" or packed == "" then
        return nil, "encode failed"
    end
    return TRANSFER_PREFIX .. packed
end

local function Decode(raw)
    local text = Trim(raw)
    if text:sub(1, #TRANSFER_PREFIX) ~= TRANSFER_PREFIX then
        return nil, "unsupported appearance configuration prefix"
    end
    if #text > MAX_TRANSFER_LENGTH then
        return nil, "appearance configuration is too large"
    end
    local body = text:sub(#TRANSFER_PREFIX + 1)
    if body == "" then
        return nil, "empty appearance configuration"
    end
    local serialize, deflate = Libs()
    if not serialize or not deflate then
        return nil, "missing LibSerialize/LibDeflate"
    end
    local packed = deflate:DecodeForPrint(body)
    if type(packed) ~= "string" then
        return nil, "decode failed"
    end
    packed = deflate:DecompressDeflate(packed)
    if type(packed) ~= "string" then
        return nil, "decompress failed"
    end
    local ok, payload = serialize:Deserialize(packed)
    if ok ~= true or type(payload) ~= "table" then
        return nil, "deserialize failed"
    end
    return payload
end

local function ValidateTransfer(payload)
    if type(payload) ~= "table"
        or not Only(payload, { version = true, payloadType = true, profile = true })
        or tonumber(payload.version) ~= TRANSFER_VERSION
        or payload.payloadType ~= "exboss_appearance_modules"
        or type(payload.profile) ~= "table"
        or not Only(payload.profile, { name = true, appearance = true })
        or type(payload.profile.name) ~= "string" then
        return nil, "unsupported appearance configuration payload"
    end
    local valid, reason = ValidateAppearance(payload.profile.appearance)
    if not valid then
        return nil, reason
    end
    local copied, copyReason = Copy(payload.profile.appearance)
    if not copied then
        return nil, copyReason
    end
    return { name = ProfileName({ name = payload.profile.name }, L["导入的外观"]), appearance = copied }
end

function Profiles:GetModuleKeys()
    local out = {}
    for i, key in ipairs(MODULE_KEYS) do
        out[i] = key
    end
    return out
end

function Profiles:GetProfileItems()
    local store = EnsureStore()
    if not store then
        return {}
    end
    local out = {}
    for id, profile in pairs(store.profiles) do
        if type(profile) == "table" and type(profile.appearance) == "table" then
            out[#out + 1] = { ProfileName(profile, id), id }
        end
    end
    table.sort(out, function(left, right)
        if left[2] == "default" then return true end
        if right[2] == "default" then return false end
        return tostring(left[1]) < tostring(right[1])
    end)
    return out
end

function Profiles:GetActiveProfileID()
    local store = EnsureStore()
    return store and store.activeProfileID or nil
end

function Profiles:GetActiveProfileName()
    local store = EnsureStore()
    local profile = store and store.profiles[store.activeProfileID] or nil
    return profile and ProfileName(profile, store.activeProfileID) or nil
end

function Profiles:IsProfileNameAvailable(name, exceptID)
    local store = EnsureStore()
    local requested = Trim(name)
    if not store or requested == "" then return false end
    local ignoredID = Trim(exceptID)
    for id, profile in pairs(store.profiles) do
        if id ~= ignoredID and ProfileName(profile, id) == requested then
            return false
        end
    end
    return true
end

function Profiles:ExportActiveProfileString()
    local profile, reason = self:GetActiveProfilePayload()
    if not profile then return nil, reason end
    return Encode({
        version = TRANSFER_VERSION,
        payloadType = "exboss_appearance_modules",
        profile = profile,
    })
end

-- The combined Boss transfer uses this typed payload directly.  Keeping the
-- codec here private means it cannot accidentally package unrelated settings.
function Profiles:GetProfilePayload(profileID)
    local store = EnsureStore()
    if not store then return nil, "appearance profile store is unavailable" end
    local id = profileID == nil and store.activeProfileID or Trim(profileID)
    if id == store.activeProfileID then
        local ok, reason = SaveActiveProfile()
        if not ok then return nil, reason end
        store = EnsureStore()
    end
    local profile = store and store.profiles[id] or nil
    if type(profile) ~= "table" then return nil, "active appearance profile is unavailable" end
    local appearance, copyReason = Copy(profile.appearance)
    if not appearance then return nil, copyReason end
    return { name = ProfileName(profile, id), appearance = appearance }
end

function Profiles:GetActiveProfilePayload()
    return self:GetProfilePayload(nil)
end

function Profiles:DecodeImportString(raw)
    local payload, reason = Decode(raw)
    if not payload then
        return nil, reason
    end
    return ValidateTransfer(payload)
end

function Profiles:GetImportSummary(decoded)
    if type(decoded) ~= "table" or type(decoded.appearance) ~= "table" then
        return nil
    end
    local moduleCount = 0
    for key in pairs(decoded.appearance.modules or {}) do
        if MODULE_KEY_SET[key] then
            moduleCount = moduleCount + 1
        end
    end
    return { name = ProfileName(decoded, L["导入的外观"]), moduleCount = moduleCount }
end

function Profiles:ValidateProfilePayload(decoded)
    if type(decoded) ~= "table" or type(decoded.name) ~= "string" then
        return nil, "invalid appearance configuration"
    end
    local valid, reason = ValidateAppearance(decoded.appearance)
    if not valid then
        return nil, reason
    end
    local copied, copyReason = Copy(decoded.appearance)
    if not copied then
        return nil, copyReason
    end
    return { name = ProfileName(decoded, L["导入的外观"]), appearance = copied }
end

function Profiles:ImportProfilePayload(decoded)
    local normalized, validationReason = self:ValidateProfilePayload(decoded)
    if not normalized then return false, validationReason end
    local copied = normalized.appearance
    local store, storeReason = EnsureStore()
    if not store then
        return false, storeReason
    end
    if not self:IsProfileNameAvailable(normalized.name) then
        return false, "appearance profile name already exists"
    end
    local index, id = 1, "imported-appearance-1"
    while store.profiles[id] ~= nil do
        index = index + 1
        id = "imported-appearance-" .. index
    end
    store.profiles[id] = {
        id = id,
        name = normalized.name,
        appearance = copied,
    }
    return true, id
end

function Profiles:ImportDecodedProfile(decoded)
    return self:ImportProfilePayload(decoded)
end

function Profiles:ActivateProfile(profileID)
    local id = Trim(profileID)
    local store, storeReason = EnsureStore()
    if not store then
        return false, storeReason
    end
    local profile = store.profiles[id]
    if type(profile) ~= "table" then
        return false, "appearance profile not found"
    end
    local valid, reason = ValidateAppearance(profile.appearance)
    if not valid then
        return false, reason
    end
    if id == store.activeProfileID then
        return true, false
    end
    local saved, saveReason = SaveActiveProfile()
    if not saved then
        return false, saveReason
    end
    local applied, applyReason = ApplyAppearance(profile.appearance)
    if not applied then
        return false, applyReason
    end
    store.activeProfileID = id
    return true, true
end
