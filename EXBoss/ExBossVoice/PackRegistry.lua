---@diagnostic disable: undefined-global

-- 标准语音包只提供 .toc 元数据与 Sounds 文件，不执行 Lua，也不注册 LibSharedMedia。
ExBoss.Voice = ExBoss.Voice or {}
ExBoss.Voice.PackRegistry = ExBoss.Voice.PackRegistry or {}
local Registry = ExBoss.Voice.PackRegistry

local MARKER = "X-EXBoss-VoicePack"
local NAME_KEY = "X-EXBoss-VoicePackName"
local _cachedPacks = nil
local _cachedPackByDisplay = nil

local function GetPerfMonitor()
    local perf = ExwindTools and ExwindTools.PerfMonitor or nil
    if perf and type(perf.IsCaptureActive) == "function" and perf:IsCaptureActive() then
        return perf
    end
    return nil
end

local function RecordPerfTiming(perf, key, startedAt)
    if perf and startedAt and type(debugprofilestop) == "function" then
        perf:RecordTiming(key, debugprofilestop() - startedAt)
    end
end

local function IncrementPerf(perf, key, amount)
    if perf and type(perf.IncrementCounter) == "function" then
        perf:IncrementCounter(key, amount)
    end
end

local function ReadMetadata(addon, key)
    if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(addon, key)
    end
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(addon, key)
    end
    return nil
end

local function GetAddonName(index)
    if type(C_AddOns) == "table" and type(C_AddOns.GetAddOnInfo) == "function" then
        return C_AddOns.GetAddOnInfo(index)
    end
    if type(GetAddOnInfo) == "function" then
        return GetAddOnInfo(index)
    end
    return nil
end

local function BuildPackCache(perf)
    local out, seen = {}, {}
    local byDisplay = {}
    local count = type(C_AddOns) == "table" and type(C_AddOns.GetNumAddOns) == "function"
        and C_AddOns.GetNumAddOns() or 0
    local scanStartedAt = perf and debugprofilestop()
    for index = 1, count do
        local addon = tostring(GetAddonName(index) or "")
        if addon ~= "" and tostring(ReadMetadata(index, MARKER) or "") == "1" then
            local display = tostring(ReadMetadata(index, NAME_KEY) or addon)
            if display ~= "" and not seen[display] then
                seen[display] = true
                local pack = {
                    addon = addon,
                    display = display,
                    title = tostring(ReadMetadata(index, "Title") or display),
                    notes = tostring(ReadMetadata(index, "Notes") or ""),
                    author = tostring(ReadMetadata(index, "Author") or ""),
                    version = tostring(ReadMetadata(index, "Version") or ""),
                }
                out[#out + 1] = pack
                byDisplay[display] = pack
            end
        end
    end
    RecordPerfTiming(perf, "TrashCD.Calibration.Voice.PackRegistry.ScanAddons", scanStartedAt)
    IncrementPerf(perf, "TrashCD.Counter.Calibration.Voice.PackRegistry.AddonsScanned", count)
    local sortStartedAt = perf and debugprofilestop()
    table.sort(out, function(a, b) return a.display < b.display end)
    RecordPerfTiming(perf, "TrashCD.Calibration.Voice.PackRegistry.Sort", sortStartedAt)

    _cachedPacks = out
    _cachedPackByDisplay = byDisplay
    IncrementPerf(perf, "TrashCD.Counter.Calibration.Voice.PackRegistry.CacheBuilds")
    return out, byDisplay
end

local function EnsurePackCache(perf)
    if type(_cachedPacks) == "table" and type(_cachedPackByDisplay) == "table" then
        IncrementPerf(perf, "TrashCD.Counter.Calibration.Voice.PackRegistry.CacheHits")
        return _cachedPacks, _cachedPackByDisplay
    end
    return BuildPackCache(perf)
end

function Registry.InvalidateCache()
    _cachedPacks = nil
    _cachedPackByDisplay = nil
end

function Registry.GetPacks()
    local perf = GetPerfMonitor()
    local totalStartedAt = perf and debugprofilestop()
    local packs = EnsurePackCache(perf)
    RecordPerfTiming(perf, "TrashCD.Calibration.Voice.PackRegistry.GetPacks", totalStartedAt)
    return packs
end

function Registry.GetPackDirectory(displayName)
    local perf = GetPerfMonitor()
    local startedAt = perf and debugprofilestop()
    local target = tostring(displayName or "")
    local _, byDisplay = EnsurePackCache(perf)
    local pack = byDisplay[target]
    RecordPerfTiming(perf, "TrashCD.Calibration.Voice.PackRegistry.GetPackDirectory", startedAt)
    return pack and pack.addon or nil
end

function Registry.GetPack(displayName)
    local target = tostring(displayName or "")
    local _, byDisplay = EnsurePackCache(GetPerfMonitor())
    return byDisplay[target]
end
