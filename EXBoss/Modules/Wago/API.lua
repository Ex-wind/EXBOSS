---@diagnostic disable: undefined-global
-- Wago profiles expose complete Author + bound-User pairs. User overrides are
-- intentionally never listed or selected on their own. ImportProfile also
-- accepts the current EXBXC v7 bundle format from EXBoss's Import/Export page.

EXBossWagoAPI = EXBossWagoAPI or {}
local PREFIX = "[EXBoss Author] "

local function IE() return ExBoss and ExBoss.Voice and ExBoss.Voice.ImportExport end

local function SelectAllAssignedSlots(scene)
    local selected = {}
    for slot in pairs(type(scene) == "table" and scene.assignments or {}) do
        selected[slot] = true
    end
    return selected
end

local function ImportBundleAndActivate(bundle)
    local profiles = ExBoss and ExBoss.AppearanceProfiles
    local bossCfg = ExBoss and ExBoss.BossConfig
    local result = { appearance = false, mplus = nil, raid = nil }
    local switched = false

    if bundle.appearance ~= nil then
        if type(profiles) ~= "table" or type(profiles.ImportProfilePayload) ~= "function"
            or type(profiles.ActivateProfile) ~= "function" then
            return false, "appearance profile import unavailable"
        end
        local ok, profileID = profiles:ImportProfilePayload(bundle.appearance)
        if not ok then return false, profileID end
        local activated, reason = profiles:ActivateProfile(profileID)
        if not activated then return false, reason end
        result.appearance, switched = true, true
    end

    for _, category in ipairs({ "mplus", "raid" }) do
        local scene = type(bundle.scenes) == "table" and bundle.scenes[category] or nil
        if scene ~= nil then
            if type(bossCfg) ~= "table" or type(bossCfg.ImportSelectedScene) ~= "function" then
                return false, "Boss configuration import unavailable"
            end
            local selectedSlots = SelectAllAssignedSlots(scene)
            local ok, importResult = bossCfg:ImportSelectedScene(
                category, scene.pairs, scene.assignments, selectedSlots, {}
            )
            if not ok then return false, importResult end
            result[category] = importResult
            switched = switched or (tonumber(importResult.assignments) or 0) > 0
        end
    end

    if switched and type(bossCfg) == "table" and type(bossCfg.PublishRuntimeSelection) == "function" then
        local ok, reason = bossCfg:PublishRuntimeSelection()
        if not ok then return false, reason end
    end
    return true, result, switched
end

local function Refs()
    local bossCfg, refs, used = ExBoss and ExBoss.BossConfig, {}, {}
    if type(bossCfg) ~= "table" or type(bossCfg.GetAuthorConfigurationItems) ~= "function" then return refs end
    for _, category in ipairs({ "mplus", "raid" }) do
        for _, row in ipairs(bossCfg:GetAuthorConfigurationItems(category) or {}) do
            local id = tostring(row.id or "")
            if id ~= "" then
                local key = PREFIX .. category .. ":" .. id
                if not used[key] then refs[key], used[key] = { category = category, authorID = id }, true end
            end
        end
    end
    return refs
end

function EXBossWagoAPI:ExportProfile(key)
    local ref, ie = type(key) == "string" and Refs()[key] or nil, IE()
    local bossCfg = ExBoss and ExBoss.BossConfig
    if not (ref and ie and bossCfg and bossCfg.ExportAuthorUserPair and ie.ExportAuthorUserPairString) then return nil end
    local pair = bossCfg:ExportAuthorUserPair(ref.category, ref.authorID)
    return pair and ie:ExportAuthorUserPairString(ref.category, pair) or nil
end

function EXBossWagoAPI:ImportProfile(text)
    local ie = IE()
    if not ie then return false, "user configuration import unavailable" end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return false, "cannot import configuration in combat"
    end

    -- DecodeTransfer accepts both legacy v6 Author + User payloads and v7
    -- bundles emitted by EXBoss's own Import/Export page.
    local transfer, reason = ie:DecodeTransfer(text)
    if not transfer then return false, reason end
    if transfer.kind == "legacyBoss" then
        return ie:ImportUserConfigurationPayload({
            version = 6,
            payloadType = "exboss_author_user_values",
            profile = transfer.profile,
        })
    end
    if transfer.kind ~= "bundle" or type(transfer.bundle) ~= "table" then
        return false, "unsupported configuration payload"
    end

    local ok, result, switched = ImportBundleAndActivate(transfer.bundle)
    if not ok then return false, result end
    -- A v7 bundle restores its appearance and role assignments by default.
    -- Wago Creator owns the single reload after its whole import batch; this
    -- API must not interrupt that batch with its own ReloadUI call.
    -- Direct consumers can use this flag to reload after their own batch.
    result.reloadRequired = switched == true
    return true, result
end

function EXBossWagoAPI:DecodeProfileString(text)
    local ie = IE()
    return ie and ie:DecodeUserConfigurationPayload(text) or nil
end

function EXBossWagoAPI:GetProfileKeys()
    local keys = {}
    for key in pairs(Refs()) do keys[key] = true end
    return keys
end

function EXBossWagoAPI:GetCurrentProfileKey() return nil end
function EXBossWagoAPI:GetProfileAssignments() return nil end
function EXBossWagoAPI:SetProfile() return false end
function EXBossWagoAPI:OpenConfig()
    local router = _G.ExwindTools and _G.ExwindTools.PanelRouter
    if router and router.Open then router:Open("importexport") end
end
function EXBossWagoAPI:CloseConfig()
    local router = _G.ExwindTools and _G.ExwindTools.PanelRouter
    if router and router.Close then router:Close("importexport") end
end
