---@diagnostic disable: undefined-global

-- 标准语音包只提供 .toc 元数据与 Sounds 文件，不执行 Lua，也不注册 LibSharedMedia。
ExBoss.Voice = ExBoss.Voice or {}
ExBoss.Voice.PackRegistry = ExBoss.Voice.PackRegistry or {}
local Registry = ExBoss.Voice.PackRegistry

local MARKER = "X-EXBoss-VoicePack"
local NAME_KEY = "X-EXBoss-VoicePackName"

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

function Registry.GetPacks()
    local out, seen = {}, {}
    local count = type(C_AddOns) == "table" and type(C_AddOns.GetNumAddOns) == "function"
        and C_AddOns.GetNumAddOns() or 0
    for index = 1, count do
        local addon = tostring(GetAddonName(index) or "")
        if addon ~= "" and tostring(ReadMetadata(index, MARKER) or "") == "1" then
            local display = tostring(ReadMetadata(index, NAME_KEY) or addon)
            if display ~= "" and not seen[display] then
                seen[display] = true
                out[#out + 1] = {
                    addon = addon,
                    display = display,
                    title = tostring(ReadMetadata(index, "Title") or display),
                    notes = tostring(ReadMetadata(index, "Notes") or ""),
                    author = tostring(ReadMetadata(index, "Author") or ""),
                    version = tostring(ReadMetadata(index, "Version") or ""),
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.display < b.display end)
    return out
end

function Registry.GetPackDirectory(displayName)
    local target = tostring(displayName or "")
    for _, pack in ipairs(Registry.GetPacks()) do
        if pack.display == target then
            return pack.addon
        end
    end
    return nil
end

function Registry.GetPack(displayName)
    local target = tostring(displayName or "")
    for _, pack in ipairs(Registry.GetPacks()) do
        if pack.display == target then
            return pack
        end
    end
    return nil
end
