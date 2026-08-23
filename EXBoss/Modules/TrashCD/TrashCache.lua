---@diagnostic disable: undefined-global

ExBoss = ExBoss or {}
ExBoss.TrashCD = ExBoss.TrashCD or {}

local Mod = ExBoss.TrashCD.TrashCache or {}
ExBoss.TrashCD.TrashCache = Mod
local State = ExBoss.TrashCD and ExBoss.TrashCD.State or nil

local RESTORE_WINDOW = 5.0
local NEW_COMBAT_BLOCK_WINDOW = 1.0
local RECENT_DEAD_WINDOW = 1.0
local MAX_PENDING = 24

Mod._active = Mod._active or {}
Mod._pending = Mod._pending or {}
Mod._recentDeadByUnit = Mod._recentDeadByUnit or {}
Mod._lastCombatDeathAt = tonumber(Mod._lastCombatDeathAt) or 0

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

local function CleanupExpired(now)
    now = tonumber(now) or GetTime()
    for i = #Mod._pending, 1, -1 do
        local row = Mod._pending[i]
        if type(row) ~= "table" or now >= (tonumber(row.expiresAt) or 0) then
            table.remove(Mod._pending, i)
        end
    end
    for unit, deadAt in pairs(Mod._recentDeadByUnit) do
        if now - (tonumber(deadAt) or 0) > RECENT_DEAD_WINDOW then
            Mod._recentDeadByUnit[unit] = nil
        end
    end
end

local function HasMeaningfulRuntime(runtime)
    if type(runtime) ~= "table" then
        return false
    end
    if tonumber(runtime.matchedNPCID) then
        return true
    end
    if runtime.scheduleInitialized == true or runtime.scheduleSignature ~= nil then
        return true
    end
    if runtime.activeCastStartAt ~= nil or runtime.activeSpellID ~= nil then
        return true
    end
    if runtime.nextSpellStartAt ~= nil or runtime.lastSucceededSpellID ~= nil then
        return true
    end
    return false
end

local function SnapshotRuntime(runtime)
    if type(runtime) ~= "table" then
        return nil
    end
    local out = DeepCopy(runtime)
    out._nameplateUnit = nil
    out._trashCacheRestoredAt = nil
    out._trashCacheRestoredFrom = nil
    return out
end

function Mod.Reset()
    wipe(Mod._active)
    wipe(Mod._pending)
    wipe(Mod._recentDeadByUnit)
    Mod._lastCombatDeathAt = 0
end

function Mod.OnNameplateAdded(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return
    end
    local now = GetTime()
    CleanupExpired(now)
    Mod._recentDeadByUnit[unit] = nil
    local row = Mod._active[unit] or {}
    row.addedAt = now
    row.firstCombatFlagAt = nil
    row.lastFlagsAt = nil
    Mod._active[unit] = row
end

function Mod.OnUnitFlags(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return
    end
    local now = GetTime()
    local row = Mod._active[unit] or { addedAt = now }
    row.lastFlagsAt = now
    local inCombat = State and type(State.IsUnitInCombat) == "function" and State.IsUnitInCombat(unit) == true or false
    if row.firstCombatFlagAt == nil and inCombat == true then
        row.firstCombatFlagAt = now
    end
    Mod._active[unit] = row
end

function Mod.OnCombatLogUnitDied()
    Mod._lastCombatDeathAt = GetTime()
end

function Mod.OnUnitDead(unit)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return
    end
    local now = GetTime()
    Mod._recentDeadByUnit[unit] = now
    Mod._active[unit] = nil
    for i = #Mod._pending, 1, -1 do
        local row = Mod._pending[i]
        if type(row) == "table" and tostring(row.sourceUnit or "") == unit then
            table.remove(Mod._pending, i)
        end
    end
end

function Mod.OnNameplateRemoved(unit, runtime, cancelFn)
    unit = NormalizeNameplateUnit(unit)
    if not unit then
        return
    end
    if ExwindTools and type(ExwindTools.SendEvent) == "function" then
        local isDead = Mod._recentDeadByUnit[unit] ~= nil
        ExwindTools:SendEvent("EXBOSS_MOB_RESET", {
            unit   = unit,
            npcID  = tonumber(runtime and runtime.matchedNPCID),
            mapID  = tonumber(runtime and runtime.matchedMapID),
            reason = isDead and "died" or "removed",
        })
    end
    local now = GetTime()
    CleanupExpired(now)

    local removedMeta = Mod._active[unit]
    Mod._active[unit] = nil

    if Mod._recentDeadByUnit[unit] and (now - Mod._recentDeadByUnit[unit]) <= RECENT_DEAD_WINDOW then
        return false
    end
    if HasMeaningfulRuntime(runtime) ~= true then
        return false
    end

    local npcID = tonumber(runtime and runtime.matchedNPCID)
    if not npcID then
        return false
    end

    local snapshot = SnapshotRuntime(runtime)
    if type(snapshot) ~= "table" then
        return false
    end

    local pendingRow = {
        npcID = npcID,
        runtimeRef = runtime,
        sourceUnit = unit,
        removedAt = now,
        expiresAt = now + RESTORE_WINDOW,
        addedAt = removedMeta and tonumber(removedMeta.addedAt) or nil,
        firstCombatFlagAt = removedMeta and tonumber(removedMeta.firstCombatFlagAt) or nil,
        lastFlagsAt = removedMeta and tonumber(removedMeta.lastFlagsAt) or nil,
        lastResolvedName = tostring(runtime.lastResolvedName or ""),
        activeSpellID = tonumber(runtime.activeSpellID),
        lastSucceededSpellID = tonumber(runtime.lastSucceededSpellID),
        snapshot = snapshot,
    }
    Mod._pending[#Mod._pending + 1] = pendingRow
    runtime._trashCachePendingRecovery = true

    while #Mod._pending > MAX_PENDING do
        table.remove(Mod._pending, 1)
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(RESTORE_WINDOW, function()
            for i = #Mod._pending, 1, -1 do
                if Mod._pending[i] == pendingRow then
                    table.remove(Mod._pending, i)
                    runtime._trashCachePendingRecovery = nil
                    if type(cancelFn) == "function" then
                        cancelFn(runtime)
                    end
                    break
                end
            end
        end)
    end
    return true
end

local function IsFreshCombatUnit(unit)
    local row = Mod._active[unit]
    if type(row) ~= "table" then
        return false
    end
    local addedAt = tonumber(row.addedAt)
    local combatAt = tonumber(row.firstCombatFlagAt)
    if not addedAt or not combatAt then
        return false
    end
    return combatAt >= addedAt and (combatAt - addedAt) <= NEW_COMBAT_BLOCK_WINDOW
end

function Mod.TryRestoreRuntime(unit, runtime, resolved)
    unit = NormalizeNameplateUnit(unit)
    if not unit or type(runtime) ~= "table" or type(resolved) ~= "table" then
        return false
    end
    CleanupExpired(GetTime())

    if runtime._trashCacheRestoredAt ~= nil or tonumber(runtime.matchedNPCID) ~= nil then
        return false
    end

    local npcID = tonumber(resolved.npcID)
    if not npcID then
        return false
    end
    if IsFreshCombatUnit(unit) then
        return false
    end

    local bestIndex = nil
    local bestRemovedAt = -math.huge
    for i = 1, #Mod._pending do
        local row = Mod._pending[i]
        if type(row) == "table" and tonumber(row.npcID) == npcID then
            local removedAt = tonumber(row.removedAt) or 0
            if removedAt > bestRemovedAt then
                bestRemovedAt = removedAt
                bestIndex = i
            end
        end
    end

    if not bestIndex then
        return false
    end

    local row = Mod._pending[bestIndex]
    table.remove(Mod._pending, bestIndex)
    local snapshot = type(row) == "table" and type(row.snapshot) == "table" and row.snapshot or nil
    if not snapshot then
        return false
    end
    local oldRuntime = type(row) == "table" and type(row.runtimeRef) == "table" and row.runtimeRef or nil

    wipe(runtime)
    for k, v in pairs(snapshot) do
        runtime[k] = DeepCopy(v)
    end
    runtime._trashCachePendingRecovery = nil
    runtime._nameplateUnit = unit
    runtime._trashCacheRestoredAt = GetTime()
    runtime._trashCacheRestoredFrom = tostring(row.sourceUnit or "")
    runtime.lastResolvedName = tostring(resolved.name or runtime.lastResolvedName or row.lastResolvedName or "")

    local active = Mod._active[unit] or {}
    active.restoredFrom = runtime._trashCacheRestoredFrom
    active.addedAt = active.addedAt or GetTime()
    Mod._active[unit] = active
    local scheduler = ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler or nil
    local rebound = 0
    if scheduler and type(scheduler.RebindTrashRuntime) == "function" and oldRuntime then
        rebound = tonumber(scheduler:RebindTrashRuntime(oldRuntime, runtime)) or 0
    end
    return true
end
