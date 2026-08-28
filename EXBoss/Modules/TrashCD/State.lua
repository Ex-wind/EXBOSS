---@diagnostic disable: undefined-global

ExBoss = ExBoss or {}
ExBoss.Trash = ExBoss.Trash or {}
ExBoss.TrashCD = ExBoss.TrashCD or {}

local Mod = ExBoss.TrashCD.State or {}
ExBoss.TrashCD.State = Mod
ExBoss.Trash.State = Mod

Mod._units = Mod._units or {}
Mod._lastCombatLogUnitDiedAt = tonumber(Mod._lastCombatLogUnitDiedAt) or 0
Mod._pollIndex = tonumber(Mod._pollIndex) or 1

local MAX_NAMEPLATES = 40
local POLL_INTERVAL = 0.10
local POLL_BATCH = 10

local function NormalizeNameplateUnit(unit)
    if type(unit) ~= "string" then
        return nil
    end
    local index = unit:match("^nameplate(%d+)$")
    if not index then
        return nil
    end
    return "nameplate" .. index
end

local function EnsureUnitRow(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return nil
    end
    local row = Mod._units[unit]
    if type(row) ~= "table" then
        row = { unit = unit }
        Mod._units[unit] = row
    end
    row.unit = unit
    return row
end

local function ResetUnitRow(row, unit, now)
    for key in pairs(row) do
        row[key] = nil
    end
    row.unit = unit
    row.active = true
    row.addedAt = now
    row.lastSeenAt = now
    row.lastUpdateAt = now
end

local function IsEliteClassification(classification)
    return tostring(classification or "") == "elite"
end

local function UnitExistsSafe(unit)
    if type(UnitExists) ~= "function" then
        return false
    end
    return UnitExists(unit) == true
end

local function UnitAffectingCombatSafe(unit)
    if type(UnitAffectingCombat) ~= "function" then
        return false
    end
    return UnitAffectingCombat(unit) == true
end

-- 生命周期追踪只在 Runtime 调试已开启时直接输出；不参与任何判断。
local function DebugTrace(msg)
    local runtime = ExBoss.TrashCD and ExBoss.TrashCD.Runtime or nil
    if runtime and type(runtime.AppendExternalDebug) == "function" then
        runtime.AppendExternalDebug("TrashCD State", msg, true)
    end
end

function Mod.Reset()
    wipe(Mod._units)
    Mod._lastCombatLogUnitDiedAt = 0
    Mod._pollIndex = 1
end

function Mod.GetUnit(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return nil
    end
    return Mod._units[unit]
end

function Mod.GetUnits()
    return Mod._units
end

function Mod.OnNameplateAdded(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return nil
    end
    local now = GetTime()
    local row = EnsureUnitRow(unit)
    if not row then
        return nil
    end
    if row.active ~= true or row.removedAt ~= nil or row.deadAt ~= nil then
        ResetUnitRow(row, unit, now)
        return row
    end
    row.active = true
    row.lastSeenAt = now
    row.lastUpdateAt = now
    return row
end

function Mod.OnNameplateRemoved(unit)
    local row = EnsureUnitRow(unit)
    if not row then
        return nil
    end
    local now = GetTime()
    local wasInCombat = row.inCombat == true
    row.active = false
    -- 姓名板移除由 Runtime 的缓存流程处理，不把它当作“脱战回调”。
    -- 否则下一次轮询会对已移除的 token 再刷新一次，并可能提前清掉 5 秒恢复缓存。
    row.inCombat = false
    row.removedAt = now
    row.lastUpdateAt = now
    DebugTrace(string.format("removed unit=%s wasCombat=%s (no combat-leave callback)",
        tostring(unit), tostring(wasInCombat)))
    return row
end

-- State 只检测状态变化；实际刷新、计时建立和清理由 Runtime 接手。
function Mod.SetCombatStateCallback(callback)
    Mod._combatStateCallback = type(callback) == "function" and callback or nil
end

local function NotifyCombatStateChanged(unit, inCombat, row)
    local callback = Mod._combatStateCallback
    if type(callback) == "function" then
        callback(unit, inCombat == true, row)
    end
end

function Mod.RefreshUnitCombat(unit, now)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return nil, nil
    end
    now = tonumber(now) or GetTime()

    local exists = UnitExistsSafe(unit)
    local row = exists and EnsureUnitRow(unit) or Mod._units[unit]
    if type(row) ~= "table" then
        return nil, nil
    end

    local wasActive = row.active == true
    local wasInCombat = row.inCombat == true
    row.unit = unit
    row.exists = exists
    row.lastCombatCheckedAt = now
    row.lastUpdateAt = now

    local combatStateChanged = false
    if exists then
        if row.deadAt ~= nil then
            row.active = false
            row.inCombat = false
            row.lastSeenAt = now
            if wasInCombat == true then
                row.lastCombatLeftAt = now
                combatStateChanged = true
            end
            if combatStateChanged then
                NotifyCombatStateChanged(unit, false, row)
            end
            return false, row
        end
        row.active = true
        row.removedAt = nil
        row.lastSeenAt = now
        if row.addedAt == nil then
            row.addedAt = now
        end
        row.inCombat = UnitAffectingCombatSafe(unit)
        if row.inCombat == true and wasInCombat ~= true then
            row.engagedAt = row.engagedAt or now
            row.lastCombatEnteredAt = now
            combatStateChanged = true
        elseif row.inCombat ~= true and wasInCombat == true then
            row.lastCombatLeftAt = now
            combatStateChanged = true
        end
    else
        row.active = false
        row.inCombat = false
        if wasActive and row.removedAt == nil then
            row.removedAt = now
        end
        if wasInCombat == true then
            row.lastCombatLeftAt = now
            combatStateChanged = true
        end
    end

    if combatStateChanged then
        DebugTrace(string.format("combat-transition unit=%s %s->%s active=%s dead=%s",
            tostring(unit), tostring(wasInCombat), tostring(row.inCombat == true),
            tostring(row.active == true), tostring(row.deadAt ~= nil)))
        NotifyCombatStateChanged(unit, row.inCombat == true, row)
    end

    return row.inCombat == true, row
end

function Mod.IsUnitInCombat(unit, refresh)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return false
    end
    if refresh ~= false then
        local inCombat = Mod.RefreshUnitCombat(unit)
        return inCombat == true
    end
    local row = Mod._units[unit]
    return type(row) == "table" and row.inCombat == true
end

function Mod.PollNameplateCombat(now, batchSize)
    now = tonumber(now) or GetTime()
    batchSize = tonumber(batchSize) or POLL_BATCH
    if batchSize < 1 then
        batchSize = POLL_BATCH
    end
    for _ = 1, batchSize do
        local index = tonumber(Mod._pollIndex) or 1
        if index < 1 or index > MAX_NAMEPLATES then
            index = 1
        end
        Mod.RefreshUnitCombat("nameplate" .. index, now)
        index = index + 1
        if index > MAX_NAMEPLATES then
            index = 1
        end
        Mod._pollIndex = index
    end
end

function Mod.OnUnitDead(unit)
    local row = EnsureUnitRow(unit)
    if not row then
        return nil
    end
    local now = GetTime()
    row.active = false
    row.inCombat = false
    row.deadAt = now
    row.lastUpdateAt = now
    DebugTrace(string.format("unit-dead unit=%s", tostring(unit)))
    return row
end

function Mod.OnCombatLogUnitDied()
    Mod._lastCombatLogUnitDiedAt = GetTime()
    return Mod._lastCombatLogUnitDiedAt
end

function Mod.SyncUnit(unit, runtime, obs, resolved, mapID)
    local row = EnsureUnitRow(unit)
    if not row then
        return nil
    end

    local now = GetTime()
    row.active = true
    row.lastSeenAt = now
    row.lastUpdateAt = now

    if type(obs) == "table" then
        row.level = tonumber(obs.level) or nil
        row.power = obs.power
        row.unitClassification = obs.unitClassification
        if type(obs.inCombat) == "boolean" then
            row.inCombat = obs.inCombat == true
        else
            row.inCombat = Mod.IsUnitInCombat(unit, false)
        end
        if type(obs.preCombatChanneling) == "boolean" then
            row.preCombatChanneling = obs.preCombatChanneling
        else
            row.preCombatChanneling = nil
        end
        row.firstSeenAt = tonumber(obs.firstSeenAt) or row.firstSeenAt
        row.isElite = IsEliteClassification(obs.unitClassification)
    elseif row.inCombat == nil then
        row.inCombat = Mod.IsUnitInCombat(unit, false)
    end

    local lockedNPCID = tonumber(type(runtime) == "table" and runtime.identityLockedNPCID or nil)
    row.identityLocked = lockedNPCID ~= nil
    row.identityLockedNPCID = lockedNPCID
    row.identityLockedMapID = tonumber(type(runtime) == "table" and runtime.identityLockedMapID or nil)
    row.identityLockedAt = tonumber(type(runtime) == "table" and runtime.identityLockedAt or nil)
    row.identityLockSource = type(runtime) == "table" and runtime.identityLockSource or nil

    local runtimeMapID = tonumber(type(runtime) == "table" and runtime.matchedMapID or nil)
    local resolvedMapID = tonumber(mapID)
    row.matchedMapID = runtimeMapID or resolvedMapID or row.matchedMapID

    local runtimeNPCID = tonumber(type(runtime) == "table" and runtime.matchedNPCID or nil)
    local resolvedNPCID = tonumber(type(resolved) == "table" and resolved.npcID or nil)
    local npcID = lockedNPCID or runtimeNPCID or resolvedNPCID
    if npcID then
        row.npcID = npcID
        row.resolved = true
        row.lastResolvedAt = now
    else
        row.npcID = nil
        row.resolved = false
    end

    if type(runtime) == "table" then
        row.engagedAt = tonumber(runtime.engagedAt) or row.engagedAt
        row.lastResolvedName = tostring(runtime.lastResolvedName or row.lastResolvedName or "")
    end
    if type(resolved) == "table" and resolved.name ~= nil then
        row.lastResolvedName = tostring(resolved.name)
    end
    if row.lastResolvedName == "" then
        row.lastResolvedName = nil
    end

    row.lastCombatLogUnitDiedAt = tonumber(Mod._lastCombatLogUnitDiedAt) or 0
    return row
end

if not Mod._pollFrame and type(CreateFrame) == "function" then
    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (tonumber(self.elapsed) or 0) + (tonumber(elapsed) or 0)
        if self.elapsed < POLL_INTERVAL then
            return
        end
        self.elapsed = 0
        Mod.PollNameplateCombat(GetTime(), POLL_BATCH)
    end)
    Mod._pollFrame = frame
end
