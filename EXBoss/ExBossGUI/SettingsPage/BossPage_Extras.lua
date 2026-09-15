---@diagnostic disable: undefined-global

local Tools = _G.ExwindTools
local Page = ExBoss.UI.Panel.BossPage
local EXUI = Tools.UI
local Extras = { MODULE_KEY = "ExBoss.BossPage.ExtrasEditor" }
Page.Extras = Extras
local context
local cardSession

local function BuildExtraGUI(extra)
    local cards, current = {}, nil
    for _, row in ipairs(extra.layout or {}) do
        if row.type == "card" then
            current = { id = tostring(row.key or "extra"), title = row.label, originX = row.x, originY = row.y, items = {} }
            cards[#cards + 1] = current
        else
            if not current then error("Boss extra GUI requires an explicit card before controls", 2) end
            local item = {}
            for key, value in pairs(row) do item[key] = value end
            item.x = row.x - current.originX + 1
            item.y = row.y - current.originY + 1
            current.items[#current.items + 1] = item
        end
    end
    if #cards == 0 then error("Boss extra GUI has no cards", 2) end
    local gui = { version = 1, title = extra.label, description = extra.description, cards = {} }
    for _, card in ipairs(cards) do
        gui.cards[#gui.cards + 1] = { id = card.id, title = card.title, content = { kind = "grid", items = card.items } }
    end
    return gui
end

function Extras:Hide()
    if EXUI.ActiveCardSession == cardSession then EXUI.ActiveCardSession = nil end
    if cardSession then cardSession:Release(); cardSession = nil end
    context = nil
end

function Extras:Render(container, scene, slot, encounterID, extraKey, isCurrent)
    self:Hide()
    local Grid = _G.ExwindGrid
    local cfg = ExBoss.BossConfig
    local api = _G.EXBossData
    local extra = ExBoss.BossEncounters:GetExtra(encounterID, extraKey)
    if not (Grid and extra and cfg:GetRuntimeConfig(scene, slot)) then return false end
    local draft = cfg:GetExtraConfig(scene, encounterID, extraKey)
    local binding = {
        scene = scene, slot = slot, encounterID = encounterID, extraKey = extraKey,
        draft = draft, saved = cfg:GetExtraConfig(scene, encounterID, extraKey),
        identity = api.GetCurrentConfiguration(scene), isCurrent = isCurrent,
    }
    local pageId = table.concat({ self.MODULE_KEY, tostring(encounterID), tostring(extraKey) }, ".")
    local gui = BuildExtraGUI(extra)
    if not EXUI:GetSettingsPage(pageId) then
        EXUI:RegisterSettingsPage(pageId, gui, { addon = "EXBoss", region = "boss-extra" })
    else
        gui = EXUI:GetSettingsPage(pageId)
    end
    local pageBinding = { moduleKey = self.MODULE_KEY, getConfig = function() return draft end }
    cardSession = Grid:MountCards(container, gui, {
        pageId = pageId,
        regionId = "boss-extra",
        moduleKey = self.MODULE_KEY,
        defaultBinding = pageBinding,
        onContentHeightChanged = function(height) container:SetHeight(math.max(1, tonumber(height) or 1)) end,
    })
    EXUI.ActiveCardSession = cardSession
    context = binding
    return true
end

EXUI:RegisterModuleValueController(Extras.MODULE_KEY, {
    RefreshActiveSurfaces = function(_, changedPath, phase)
        local current = context
        if not (current and Page._visible and current.isCurrent()) then return end
        if phase == "changing" then return end
        local key = changedPath
        if current.saved[key] == nil or current.saved[key] == current.draft[key] then return end
        local ok, reason = ExBoss.BossConfig:SetExtraValue(current.scene, current.slot,
            current.encounterID, current.extraKey, key, current.draft[key], current.identity)
        if ok then
            current.saved[key] = current.draft[key]
        else
            current.draft[key] = current.saved[key]
            context = nil
            Page:RefreshSpellUI()
            if ExBoss.Print and ExBoss.Print.Say then ExBoss.Print.Say(tostring(reason)) end
        end
    end,
})
