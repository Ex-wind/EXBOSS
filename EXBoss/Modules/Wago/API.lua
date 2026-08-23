---@diagnostic disable: undefined-global
-- Wago profiles expose complete Author + bound-User pairs. User overrides are
-- intentionally never listed or selected on their own.

EXBossWagoAPI = EXBossWagoAPI or {}
local PREFIX = "[EXBoss Author] "

local function IE() return ExBoss and ExBoss.Voice and ExBoss.Voice.ImportExport end

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
    return ie:ImportUserConfigurationString(text)
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
