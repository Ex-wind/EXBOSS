---@diagnostic disable: undefined-global

ExBoss = ExBoss or {}
ExBoss.Trash = ExBoss.Trash or {}
ExBoss.TrashCD = ExBoss.TrashCD or {}

local Mod = ExBoss.TrashCD.Output or {}
ExBoss.TrashCD.Output = Mod
ExBoss.Trash.Output = Mod

local SCRIPT_EVENT_MIN_DELAY = 0.20
local CAST_START_VOICE_TARGET_DELAY = 0.12
local CAST_START_VOICE_TARGET_CLEAR_DELAY = 0.12
local CAST_START_VOICE_TARGET_SWITCH_DELAY = 0.12
local Data = ExBoss.TrashCD and ExBoss.TrashCD.Data or nil
local RuntimeConfig = ExBoss.TrashCD and ExBoss.TrashCD.RuntimeConfig or nil
local State = ExBoss.TrashCD and ExBoss.TrashCD.State or nil
local GetRuntimeMobData

local function GetScheduler()
    return ExBoss and ExBoss.Timeline and ExBoss.Timeline.Scheduler or nil
end

local function HasPositiveDurationValue(value)
    if type(value) == "table" then
        for _, item in pairs(value) do
            if HasPositiveDurationValue(item) then
                return true
            end
        end
        return false
    end
    if type(value) == "string" then
        for item in string.gmatch(value, "[^,;/|%s]+") do
            if (tonumber(item) or 0) > 0 then
                return true
            end
        end
        return false
    end
    local n = tonumber(value)
    return n ~= nil and n > 0
end

local function SpellMatchesStartKind(spellData, kind)
    if type(spellData) ~= "table" then
        return false
    end
    kind = tostring(kind or "")
    local hasCast = HasPositiveDurationValue(spellData.castTime)
        or HasPositiveDurationValue(spellData.castTimeExtra)
        or HasPositiveDurationValue(spellData.castTimeSet)
    local hasChannel = HasPositiveDurationValue(spellData.channelTime)
        or HasPositiveDurationValue(spellData.channelDuration)
        or HasPositiveDurationValue(spellData.channelTimeSet)
    if kind == "cast" then
        return hasCast == true
    end
    if kind == "channel" then
        return hasChannel == true and hasCast ~= true
    end
    return false
end

local function GetSpellOpeningCastOrder(spellData)
    local value = type(spellData) == "table" and tonumber(spellData.openingCastOrder or spellData.castOrder) or nil
    if value and value > 0 then
        return math.floor(value + 0.5)
    end
    return nil
end

local function GetRuntimeActiveOpeningCastOrder(runtime)
    local value = type(runtime) == "table" and tonumber(runtime.activeCastObservedOrder or runtime.observedOpeningCastCount) or nil
    if value and value > 0 then
        return math.floor(value + 0.5)
    end
    return nil
end

local function CollectRelevantRuntimeStartSpells(runtime, kind)
    local mobData = GetRuntimeMobData(runtime)
    local spells = type(mobData) == "table" and type(mobData.spells) == "table" and mobData.spells or nil
    if not spells then
        return {}
    end
    local currentOrder = GetRuntimeActiveOpeningCastOrder(runtime)
    local matched = {}
    if currentOrder then
        for _, spellData in pairs(spells) do
            if type(spellData) == "table"
                and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind)
                and GetSpellOpeningCastOrder(spellData) == currentOrder then
                matched[#matched + 1] = spellData
            end
        end
    end
    if #matched > 0 then
        return matched
    end
    local out = {}
    for _, spellData in pairs(spells) do
        if type(spellData) == "table" and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            out[#out + 1] = spellData
        end
    end
    return out
end

local function CurrentStartSpellListContains(spellList, spellData)
    if type(spellList) ~= "table" or type(spellData) ~= "table" then
        return false
    end
    for i = 1, #spellList do
        if spellList[i] == spellData then
            return true
        end
    end
    return false
end

local function SpellHasTargetClearFingerprint(spellData)
    --[[
    12.1 弃用旧施法开始指纹，先行注释保留。
    return type(spellData) == "table" and type(spellData.targetClearOnCastStart) == "boolean"
    ]]
    return false
end

GetRuntimeMobData = function(runtime)
    if type(runtime) ~= "table" then
        return nil
    end
    local root = Data and type(Data.GetTrashCDDataRoot) == "function" and Data.GetTrashCDDataRoot() or nil
    local mapID = tonumber(runtime.matchedMapID)
    local npcID = tonumber(runtime.matchedNPCID)
    local mapData = mapID and type(root) == "table" and type(root[mapID]) == "table" and root[mapID] or nil
    local mobs = mapData and type(mapData.mobs) == "table" and mapData.mobs or nil
    return npcID and mobs and mobs[npcID] or nil
end

local function GetCurrentTrashResolveContext()
    if not (Data and type(Data.GetCurrentInstanceContext) == "function" and type(Data.NormalizeNameKey) == "function") then
        return nil, nil
    end
    local _instanceID, dungeonName = Data.GetCurrentInstanceContext()
    local dungeonKey = Data.NormalizeNameKey(dungeonName)
    if dungeonKey == "" then
        return nil, nil
    end
    local calibration = ExBoss and ExBoss.TrashCD and ExBoss.TrashCD.Calibration or nil
    local mapID = calibration and type(calibration.GetCurrentTrashMapID) == "function"
        and tonumber(calibration.GetCurrentTrashMapID(dungeonKey))
        or nil
    if not mapID then
        return nil, nil
    end
    return dungeonKey, mapID
end

local function TryResolveRuntimeStartCandidate(runtime)
    if type(runtime) ~= "table" then
        return nil
    end
    -- 输出层没有身份判定权。它只能读取 Runtime 已接受的 L2 身份锁，
    -- 绝不能重新采样并用优先级结果覆写当前读条的归因。
    local npcID = tonumber(runtime.identityLockedNPCID)
    if not npcID then
        return nil
    end
    local candidate = type(runtime.identityLockedCandidate) == "table" and runtime.identityLockedCandidate or nil
    if candidate and tonumber(candidate.npcID) == npcID then
        return candidate
    end
    return {
        npcID = npcID,
        name = runtime.lastResolvedName,
    }
end

local function RuntimeNeedsTargetFingerprint(runtime, kind)
    local spells = CollectRelevantRuntimeStartSpells(runtime, kind)
    for i = 1, #spells do
        local spellData = spells[i]
        if type(spellData) == "table" and type(spellData.targetExists) == "boolean" and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            return true
        end
    end
    return false
end

local function RuntimeNeedsTargetAPIFingerprint(runtime, kind)
    local spells = CollectRelevantRuntimeStartSpells(runtime, kind)
    for i = 1, #spells do
        local spellData = spells[i]
        if type(spellData) == "table" and type(spellData.targetAPIExists) == "boolean" and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            return true
        end
    end
    return false
end

local function RuntimeNeedsTargetUnitFingerprint(runtime, kind)
    --[[
    12.1 弃用旧施法开始指纹，先行注释保留。
    local mobData = GetRuntimeMobData(runtime)
    local spells = type(mobData) == "table" and type(mobData.spells) == "table" and mobData.spells or nil
    if not spells then
        return false
    end
    for _, spellData in pairs(spells) do
        if type(spellData) == "table"
            and type(spellData.castStartTargetUnitExists) == "boolean"
            and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            return true
        end
    end
    ]]
    return false
end

local function RuntimeNeedsTargetClearFingerprint(runtime, kind)
    --[[
    12.1 弃用旧施法开始指纹，先行注释保留。
    local mobData = GetRuntimeMobData(runtime)
    local spells = type(mobData) == "table" and type(mobData.spells) == "table" and mobData.spells or nil
    if not spells then
        return false
    end
    for _, spellData in pairs(spells) do
        if SpellHasTargetClearFingerprint(spellData) and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            return true
        end
    end
    ]]
    return false
end

local function RuntimeNeedsTargetSwitchFingerprint(runtime, kind)
    --[[
    12.1 弃用旧施法开始指纹，先行注释保留。
    local mobData = GetRuntimeMobData(runtime)
    local spells = type(mobData) == "table" and type(mobData.spells) == "table" and mobData.spells or nil
    if not spells then
        return false
    end
    for _, spellData in pairs(spells) do
        if type(spellData) == "table"
            and type(spellData.castStartChangeTarget) == "boolean"
            and SpellMatchesStartKind(spellData, kind or runtime.activeCastKind) then
            return true
        end
    end
    ]]
    return false
end

local function SpellMatchesRuntimeFingerprints(spellData, runtime)
    if type(spellData) ~= "table" or type(runtime) ~= "table" then
        return true
    end
    if type(runtime.activeCastTargetExists) == "boolean"
        and type(spellData.targetExists) == "boolean"
        and spellData.targetExists ~= runtime.activeCastTargetExists then
        return false
    end
    if type(runtime.activeCastTargetAPIExists) == "boolean"
        and type(spellData.targetAPIExists) == "boolean"
        and spellData.targetAPIExists ~= runtime.activeCastTargetAPIExists then
        return false
    end
    --[[
    12.1 弃用旧施法开始指纹，先行注释保留。
    if type(runtime.activeCastTargetUnitExists) == "boolean"
        and type(spellData.castStartTargetUnitExists) == "boolean"
        and spellData.castStartTargetUnitExists ~= runtime.activeCastTargetUnitExists then
        return false
    end
    if runtime.activeCastTargetClearResolved == true
        and type(spellData.targetClearOnCastStart) == "boolean"
        and spellData.targetClearOnCastStart ~= (runtime.activeCastTargetClearedOnStart == true) then
        return false
    end
    if runtime.activeCastTargetSwitchResolved == true
        and type(spellData.castStartChangeTarget) == "boolean"
        and spellData.castStartChangeTarget ~= (runtime.activeCastTargetSwitched == true) then
        return false
    end
    ]]
    return true
end

local function ResolveRuntimeSpellForStartVoice(runtime)
    local customResolver = ExBoss and ExBoss.TrashCD and ExBoss.TrashCD.ResolveObservedStartSpellID or nil
    if type(customResolver) == "function" and type(runtime) == "table" then
        local ok, forcedSpellID = pcall(customResolver, runtime, tostring(runtime.activeCastKind or ""))
        local forcedID = ok and tonumber(forcedSpellID) or nil
        if forcedID and forcedID > 0 then
            runtime.activeSpellID = forcedID
            runtime.activeSpellAmbiguous = false
            return forcedID
        end
    end

    TryResolveRuntimeStartCandidate(runtime)

    local fallbackID = tonumber(runtime and runtime.activeSpellID)
    local mobData = GetRuntimeMobData(runtime)
    local spells = type(mobData) == "table" and type(mobData.spells) == "table" and mobData.spells or nil
    if not spells then
        if runtime and runtime.activeSpellAmbiguous == true then
            return nil
        end
        return fallbackID
    end

    local activeKind = tostring(runtime.activeCastKind or "")
    local relevantSpells = CollectRelevantRuntimeStartSpells(runtime, activeKind)
    local startAt = tonumber(runtime.activeCastStartAt)
    local observedID = tonumber(runtime and runtime.activeObservedSpellID)
    if observedID then
        local observedSpell = spells[observedID]
        if type(observedSpell) == "table"
            and CurrentStartSpellListContains(relevantSpells, observedSpell)
            and SpellMatchesStartKind(observedSpell, activeKind)
            and SpellMatchesRuntimeFingerprints(observedSpell, runtime) then
            runtime.activeSpellID = observedID
            runtime.activeSpellAmbiguous = false
            return observedID
        end
    end
    if fallbackID then
        local fallbackSpell = spells[fallbackID]
        if type(fallbackSpell) == "table"
            and CurrentStartSpellListContains(relevantSpells, fallbackSpell)
            and SpellMatchesStartKind(fallbackSpell, activeKind)
            and SpellMatchesRuntimeFingerprints(fallbackSpell, runtime) then
            runtime.activeSpellAmbiguous = false
            return fallbackID
        end
    end
    local bestSpellID, bestScore, tieCount = nil, math.huge, 0
    for i = 1, #relevantSpells do
        local spellData = relevantSpells[i]
        local spellID = tonumber(spellData and spellData.spellID)
        if type(spellData) == "table"
            and SpellMatchesRuntimeFingerprints(spellData, runtime)
            and SpellMatchesStartKind(spellData, activeKind) then
            local sid = tonumber(spellData.spellID) or tonumber(spellID)
            local predictedAt = sid and runtime.nextSpellStartAt and tonumber(runtime.nextSpellStartAt[sid]) or nil
            local score = predictedAt and startAt and math.abs(startAt - predictedAt) or 9999
            if fallbackID and sid == fallbackID then
                score = score - 0.01
            end
            if sid and score < (bestScore - 0.05) then
                bestSpellID, bestScore, tieCount = sid, score, 1
            elseif sid and math.abs(score - bestScore) <= 0.05 then
                tieCount = tieCount + 1
            end
        end
    end
    if bestSpellID and tieCount <= 1 then
        runtime.activeSpellID = bestSpellID
        runtime.activeSpellAmbiguous = false
        return bestSpellID
    end
    return nil
end

local function HasRuntimeTimerIDs(runtime)
    if type(runtime) ~= "table" then
        return false
    end
    local bySpell = type(runtime.localTimerIDsBySpellID) == "table" and runtime.localTimerIDsBySpellID or nil
    if bySpell and next(bySpell) ~= nil then
        return true
    end
    local ids = type(runtime.scriptEventIDs) == "table" and runtime.scriptEventIDs or nil
    if ids and #ids > 0 then
        return true
    end
    local byScriptSpell = type(runtime.scriptEventIDsBySpellID) == "table" and runtime.scriptEventIDsBySpellID or nil
    return byScriptSpell and next(byScriptSpell) ~= nil
end

function Mod.CancelRuntimeScriptEvents(runtime)
    if not runtime or type(runtime) ~= "table" then
        return
    end
    if runtime._trashCachePendingRecovery == true then
        return
    end
    if not HasRuntimeTimerIDs(runtime) then
        return
    end
    local scheduler = GetScheduler()
    if scheduler and type(scheduler.CancelTrashLocalTimers) == "function" then
        scheduler:CancelTrashLocalTimers(runtime)
    end
    if not (C_EncounterTimeline and C_EncounterTimeline.CancelScriptEvent) then
        runtime.scriptEventIDs = {}
        return
    end
    local ids = runtime.scriptEventIDs
    if type(ids) ~= "table" then
        runtime.scriptEventIDs = {}
        return
    end
    for i = #ids, 1, -1 do
        local eventID = tonumber(ids[i])
        if eventID and eventID > 0 then
            if RuntimeConfig and type(RuntimeConfig.ClearEncounterEventSettings) == "function" then
                RuntimeConfig.ClearEncounterEventSettings(eventID)
            end
            if RuntimeConfig and type(RuntimeConfig.ClearTimelineEventMeta) == "function" then
                RuntimeConfig.ClearTimelineEventMeta(eventID)
            end
            pcall(C_EncounterTimeline.CancelScriptEvent, eventID)
        end
    end
    wipe(ids)
    if type(runtime.scriptEventIDsBySpellID) == "table" then
        wipe(runtime.scriptEventIDsBySpellID)
    end
end

function Mod.CancelRuntimeSpellScriptEvents(runtime, spellID)
    if not runtime or type(runtime) ~= "table" then
        return
    end
    if runtime._trashCachePendingRecovery == true then
        return
    end
    local sid = tonumber(spellID)
    if not sid then
        return
    end
    local scheduler = GetScheduler()
    if scheduler and type(scheduler.CancelTrashLocalTimer) == "function" then
        scheduler:CancelTrashLocalTimer(runtime, sid)
    end
    local bySpell = type(runtime.scriptEventIDsBySpellID) == "table" and runtime.scriptEventIDsBySpellID or nil
    local ids = bySpell and bySpell[sid] or nil
    if type(ids) ~= "table" then
        return
    end
    local flat = type(runtime.scriptEventIDs) == "table" and runtime.scriptEventIDs or nil
    for i = #ids, 1, -1 do
        local eventID = tonumber(ids[i])
        if eventID and eventID > 0 then
            if RuntimeConfig and type(RuntimeConfig.ClearEncounterEventSettings) == "function" then
                RuntimeConfig.ClearEncounterEventSettings(eventID)
            end
            if RuntimeConfig and type(RuntimeConfig.ClearTimelineEventMeta) == "function" then
                RuntimeConfig.ClearTimelineEventMeta(eventID)
            end
            pcall(C_EncounterTimeline.CancelScriptEvent, eventID)
            if type(flat) == "table" then
                for j = #flat, 1, -1 do
                    if tonumber(flat[j]) == eventID then
                        table.remove(flat, j)
                    end
                end
            end
        end
    end
    bySpell[sid] = nil
end

function Mod.AddRuntimeScriptEvent(runtime, mobData, spellData, remaining, fallbackIcon)
    if not runtime or not mobData or not spellData then
        return
    end
    if RuntimeConfig and type(RuntimeConfig.IsDisabledInCurrentEncounter) == "function"
        and RuntimeConfig.IsDisabledInCurrentEncounter() == true then
        return
    end
    local scheduler = GetScheduler()
    if not (scheduler and type(scheduler.RegisterTrashLocalTimer) == "function") then
        return
    end
    local delay = tonumber(remaining)
    if not delay or delay < SCRIPT_EVENT_MIN_DELAY then
        return
    end

    local spellID = tonumber(spellData.spellID)
    if not spellID or spellID <= 0 then
        return
    end
    local runtimeNPCID = tonumber(runtime.matchedNPCID)
    local mobNPCID = tonumber(mobData.npcID)
    if not runtimeNPCID or not mobNPCID or runtimeNPCID ~= mobNPCID then
        return
    end

    local info = nil
    if C_Spell and C_Spell.GetSpellInfo then
        info = C_Spell.GetSpellInfo(spellID)
    end

    local meta = RuntimeConfig and type(RuntimeConfig.BuildResolvedMeta) == "function"
        and RuntimeConfig.BuildResolvedMeta(runtime, mobData, spellData, tonumber(spellData.iconFileID) or (info and tonumber(info.iconID)) or tonumber(fallbackIcon) or 136243)
        or nil
    if type(meta) ~= "table" then
        return
    end

    local ok, result = pcall(scheduler.RegisterTrashLocalTimer, scheduler, runtime, mobData, spellData, delay, meta)
    local timerID = tonumber(result)
    if not (ok and timerID and timerID > 0) then
        return
    end
end

local function TryPlayRuntimeSpellStartVoice(runtime)
    local scheduler = GetScheduler()
    if not (scheduler and type(scheduler.PlayTrashObservedCastStartVoice) == "function") then
        return false
    end
    if type(runtime) ~= "table" then
        return false
    end
    if not tonumber(runtime.identityLockedNPCID) then
        return false
    end
    local seq = tonumber(runtime.activeCastSeq)
    if seq and tonumber(runtime._voicePlayedForSeq) == seq then
        return false
    end
    local sid = ResolveRuntimeSpellForStartVoice(runtime)
    if not sid then
        return false
    end
    local ok, err = scheduler:PlayTrashObservedCastStartVoice(runtime, sid)
    if ok then
        runtime._voicePlayedForSeq = tonumber(runtime.activeCastSeq)
    end
    return ok, err
end

local function DelayRuntimeCastStartVoice(runtime, kind)
    if not (C_Timer and C_Timer.After) then
        return false
    end
    local seq = tonumber(runtime and runtime.activeCastSeq)
    if not seq then
        return false
    end
    if runtime._castStartVoiceDelaySeq == seq then
        return false
    end
    runtime._castStartVoiceDelaySeq = seq
    C_Timer.After(CAST_START_VOICE_TARGET_DELAY, function()
        if type(runtime) ~= "table" or tonumber(runtime.activeCastSeq) ~= seq then
            return
        end
        if tostring(runtime.activeCastKind or "") ~= tostring(kind or "") then
            return
        end
        TryPlayRuntimeSpellStartVoice(runtime)
    end)
    return true
end

local function DelayRuntimeTargetSwitchCastStartVoice(runtime, kind)
    if not (C_Timer and C_Timer.After) then
        return false
    end
    local seq = tonumber(runtime and runtime.activeCastSeq)
    if not seq then
        return false
    end
    if runtime._castStartTargetSwitchDelaySeq == seq then
        return false
    end
    runtime._castStartTargetSwitchDelaySeq = seq
    C_Timer.After(CAST_START_VOICE_TARGET_SWITCH_DELAY, function()
        if type(runtime) ~= "table" or tonumber(runtime.activeCastSeq) ~= seq then
            return
        end
        if tostring(runtime.activeCastKind or "") ~= tostring(kind or "") then
            return
        end
        Mod.PlayRuntimeCastStartVoice(runtime, kind)
    end)
    return true
end

local function DelayRuntimeTargetClearCastStartVoice(runtime, kind)
    if not (C_Timer and C_Timer.After) then
        return false
    end
    local seq = tonumber(runtime and runtime.activeCastSeq)
    if not seq then
        return false
    end
    if runtime._castStartTargetClearDelaySeq == seq then
        return false
    end
    runtime._castStartTargetClearDelaySeq = seq
    C_Timer.After(CAST_START_VOICE_TARGET_CLEAR_DELAY, function()
        if type(runtime) ~= "table" or tonumber(runtime.activeCastSeq) ~= seq then
            return
        end
        if tostring(runtime.activeCastKind or "") ~= tostring(kind or "") then
            return
        end
        Mod.PlayRuntimeCastStartVoice(runtime, kind)
    end)
    return true
end

function Mod.PlayRuntimeCastStartVoice(runtime, kind)
    if type(runtime) ~= "table" then
        return false
    end
    if not tonumber(runtime.identityLockedNPCID) then
        return false
    end
    local seq = tonumber(runtime.activeCastSeq)
    if seq and tonumber(runtime._voicePlayedForSeq) == seq then
        return false
    end
    local castKind = tostring(kind or runtime.activeCastKind or "")
    TryResolveRuntimeStartCandidate(runtime)
    if castKind == "channel"
        and runtime.transitionCastKind == "cast"
        and runtime.transitionIntoKind == castKind then
        return false
    end

    if RuntimeNeedsTargetFingerprint(runtime, castKind) and type(runtime.activeCastTargetExists) ~= "boolean" then
        return DelayRuntimeCastStartVoice(runtime, castKind)
    end

    if RuntimeNeedsTargetAPIFingerprint(runtime, castKind) and type(runtime.activeCastTargetAPIExists) ~= "boolean" then
        return DelayRuntimeCastStartVoice(runtime, castKind)
    end

    if RuntimeNeedsTargetUnitFingerprint(runtime, castKind) and type(runtime.activeCastTargetUnitExists) ~= "boolean" then
        return DelayRuntimeCastStartVoice(runtime, castKind)
    end

    if RuntimeNeedsTargetClearFingerprint(runtime, castKind) and runtime.activeCastTargetClearResolved ~= true then
        return DelayRuntimeTargetClearCastStartVoice(runtime, castKind)
    end

    if RuntimeNeedsTargetSwitchFingerprint(runtime, castKind) and runtime.activeCastTargetSwitchResolved ~= true then
        return DelayRuntimeTargetSwitchCastStartVoice(runtime, castKind)
    end

    return TryPlayRuntimeSpellStartVoice(runtime)
end
