---@diagnostic disable: undefined-global

-- Cross-nameplate L1 evidence. A companion NPC only helps after that
-- companion has already received a Runtime identity lock; absence is never
-- treated as evidence.
ExBoss = ExBoss or {}
ExBoss.Trash = ExBoss.Trash or {}
ExBoss.TrashCD = ExBoss.TrashCD or {}

local Mod = ExBoss.TrashCD.CoPresence or {}
ExBoss.TrashCD.CoPresence = Mod
ExBoss.Trash.CoPresence = Mod

Mod._byMap = Mod._byMap or {}

local function WipeTable(t)
    if type(t) ~= "table" then
        return
    end
    for key in pairs(t) do
        t[key] = nil
    end
end

local function GetMapBucket(mapID, create)
    local mid = tonumber(mapID)
    if not mid then
        return nil
    end
    local bucket = Mod._byMap[mid]
    if type(bucket) ~= "table" and create == true then
        bucket = {}
        Mod._byMap[mid] = bucket
    end
    return type(bucket) == "table" and bucket or nil
end

function Mod.Reset()
    WipeTable(Mod._byMap)
end

function Mod.UnregisterRuntime(runtime)
    if type(runtime) ~= "table" then
        return
    end
    local mapID = tonumber(runtime._coPresenceMapID)
    local npcID = tonumber(runtime._coPresenceNPCID)
    if mapID and npcID then
        local bucket = GetMapBucket(mapID, false)
        local runtimes = bucket and bucket[npcID]
        if type(runtimes) == "table" then
            runtimes[runtime] = nil
            if next(runtimes) == nil then
                bucket[npcID] = nil
            end
        end
        if bucket and next(bucket) == nil then
            Mod._byMap[mapID] = nil
        end
    end
    runtime._coPresenceMapID = nil
    runtime._coPresenceNPCID = nil
end

function Mod.MarkRuntimeLocked(runtime, mapID, npcID)
    if type(runtime) ~= "table" then
        return false
    end
    local mid = tonumber(mapID)
    local nid = tonumber(npcID)
    if not (mid and nid) then
        Mod.UnregisterRuntime(runtime)
        return false
    end
    if tonumber(runtime._coPresenceMapID) == mid and tonumber(runtime._coPresenceNPCID) == nid then
        return false
    end
    Mod.UnregisterRuntime(runtime)
    local bucket = GetMapBucket(mid, true)
    bucket[nid] = type(bucket[nid]) == "table" and bucket[nid] or {}
    bucket[nid][runtime] = true
    runtime._coPresenceMapID = mid
    runtime._coPresenceNPCID = nid
    return true
end

local function CandidateMatchesPresentCompanion(candidate, presentByNPCID)
    local row = type(candidate) == "table" and candidate.row or nil
    local companions = type(candidate) == "table" and candidate.coPresenceNPCIDs or nil
    if type(companions) ~= "table" then
        companions = type(row) == "table" and row.coPresenceNPCIDs or nil
    end
    if type(companions) ~= "table" then
        return false
    end
    for npcID in pairs(companions) do
        if presentByNPCID[tonumber(npcID)] == true then
            return true
        end
    end
    return false
end

function Mod.FilterCandidates(candidates, runtime, mapID)
    if type(candidates) ~= "table" or #candidates <= 1 then
        return candidates, false
    end
    local bucket = GetMapBucket(mapID, false)
    if type(bucket) ~= "table" then
        return candidates, false
    end

    local presentByNPCID = {}
    for npcID, runtimes in pairs(bucket) do
        if type(runtimes) == "table" then
            for lockedRuntime in pairs(runtimes) do
                if lockedRuntime ~= runtime then
                    presentByNPCID[tonumber(npcID)] = true
                    break
                end
            end
        end
    end
    if next(presentByNPCID) == nil then
        return candidates, false
    end

    local matched = {}
    for i = 1, #candidates do
        local candidate = candidates[i]
        if CandidateMatchesPresentCompanion(candidate, presentByNPCID) then
            matched[#matched + 1] = candidate
        end
    end

    -- Only a positive companion match may narrow the list. A missing
    -- companion, or a list with no matching relation, leaves every candidate
    -- intact and can never imply a different NPC identity.
    if #matched == 0 then
        return candidates, false
    end
    return matched, #matched < #candidates
end
