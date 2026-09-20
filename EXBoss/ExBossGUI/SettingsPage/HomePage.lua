---@diagnostic disable: undefined-global, undefined-field, need-check-nil

ExBoss.UI.Panel.HomePage = ExBoss.UI.Panel.HomePage or {}
local Page = ExBoss.UI.Panel.HomePage
local L = ExBoss.L or setmetatable({}, { __index = function(_, key) return key end })
local EXUI = _G.ExwindTools and _G.ExwindTools.UI

do
    local zhCN = ExBoss.NewLocale and ExBoss:NewLocale("zhCN")
    if zhCN then
        zhCN["隐藏 EXBoss 小地图按钮"] = true
    end
    local enUS = ExBoss.NewLocale and ExBoss:NewLocale("enUS")
    if enUS then
        enUS["隐藏 EXBoss 小地图按钮"] = "Hide EXBoss Minimap Button"
    end
end

local MODULE_KEY = "ExBoss.HomePage"
local INFORMATION_RENDERER = "ExBoss.HomePage.Information"
local CARD_GAP = 16

local scrollFrame = nil
local scrollChild = nil
local missingDepsText = nil
local RefreshPage = nil
local pageLayoutData = nil
local cardSession = nil

local LOCALE_LABELS = {
    AUTO = L["自动跟随客户端"],
    zhCN = L["强制 zhCN"],
    zhTW = L["强制 zhTW"],
    enUS = L["强制 enUS"],
    koKR = L["强制 koKR"],
    deDE = L["强制 deDE"],
    esES = L["强制 esES"],
    esMX = L["强制 esMX"],
    itIT = L["强制 itIT"],
    ptBR = L["强制 ptBR"],
    frFR = L["强制 frFR"],
    ruRU = L["强制 ruRU"],
}

local LOCALE_ITEMS = {
    { L["自动跟随客户端"], "AUTO" },
    { L["强制 zhCN"], "zhCN" },
    { L["强制 zhTW"], "zhTW" },
    { L["强制 enUS"], "enUS" },
    { L["强制 koKR"], "koKR" },
    { L["强制 deDE"], "deDE" },
    { L["强制 esES"], "esES" },
    { L["强制 esMX"], "esMX" },
    { L["强制 itIT"], "itIT" },
    { L["强制 ptBR"], "ptBR" },
    { L["强制 frFR"], "frFR" },
    { L["强制 ruRU"], "ruRU" },
}

-- 首页资料只用于本次绘制，不参与配置、默认值、保存或通知通道。
local HOME_INFORMATION = {
    official = {
        { kind = "link", label = "实时追踪蓝帖网站（中文）", value = "https://exwind.net" },
        { kind = "link", label = "插件常见问题", value = "https://exwind.net/faq/general" },
        { kind = "link", label = "LSM语音包打包（上传你的音频后自动打包成插件，能在游戏内所有选择音频的地方使用）", value = "https://exwind.net/lsm" },
        { kind = "link", label = "EXBOSS配置原理说明", value = "https://exwind.net/exboss/config" },
        { kind = "link", label = "EXBOSS语音包说明", value = "https://exwind.net/exboss/voices" },
        { kind = "link", label = "EXBOSS语音包制作", value = "https://exwind.net/exboss" },
    },
    contact = {
        { kind = "link", label = "赞助支持", value = "https://afdian.com/a/Exwind" },
        { kind = "link", label = "DC", value = "https://discord.gg/6fwVhRHyg9" },
        { kind = "link", label = "QQ（群）", value = "2168036546" },
        { kind = "link", label = "Bilibili（私信）：EX-WIND", value = "https://space.bilibili.com/3494364483422992" },
    },
    thirdParty = {
        { kind = "text", span = 2, text = "声明：仅仅对以下人员对插件发展过程中给予的协助表示感谢，排名不分先后。并不代表本插件支持/反对任何立场，请勿过度解读。如有遗漏请私聊我提醒。" },
        { kind = "person", span = 2, name = "技术交流合作：@神秘地瓜", value = "https://space.bilibili.com/242463801" },
        { kind = "person", name = "DC群组所有反馈的小伙伴" },
        { kind = "person", name = "QQ群组所有反馈的小伙伴" },
        { kind = "text", span = 2, text = "声明：可能还有很多英语/外语主播介绍并协助人们了解插件，我并没有长期活跃于英语主播圈子，所以很可能遗漏，这点非常抱歉。如果发生该情况可以随时私信我（不一定要主播本人，也可以是任何人提醒我）。" },
    },
    specialThanks = {
        { kind = "person", name = "MusclebrahTV", value = "https://www.instagram.com/musclebrahtv/", description = "他提供了非常多的测试反馈以及DC用户的问答，以及后续会协助我们制作介绍视频。" },
        { kind = "person", name = "tettles", value = "https://youtube.com/@tettles", description = "他制作了一个协助我们介绍插件的视频。" },
        { kind = "person", name = "露露緹婭", description = "在生病期间他给予了很多测试协助支持。" },
        { kind = "person", name = "叶落初冬", description = "协助反馈并优化插件，提出了多个更为细致的功能。" },
        { kind = "person", span = 2, name = "子梦", description = "提供了腿毛照片支持。" },
    },
}

local function GetLocaleModeLabel(mode)
    local value = tostring(mode or ""):gsub("%s+", "")
    return LOCALE_LABELS[value] or L["自动跟随客户端"]
end

local function BuildLocaleStatusText()
    local localeMode = ExBoss.GetLocaleMode and ExBoss:GetLocaleMode() or "AUTO"
    local clientLocale = ExBoss.Locale and ExBoss.Locale.GetClientLocale and ExBoss.Locale:GetClientLocale() or GetLocale()
    local effectiveLocale = ExBoss.GetEffectiveLocale and ExBoss:GetEffectiveLocale(localeMode) or clientLocale
    return string.format(
        L["当前设置：%s | 客户端：%s | 当前生效：%s\n仅影响 EXBoss 自身本地化文本，切换后建议重载界面。"],
        GetLocaleModeLabel(localeMode),
        tostring(clientLocale or "zhCN"),
        tostring(effectiveLocale or "zhCN")
    )
end

local function GetPageDBDefaults()
    return {
        localeMode = "AUTO",
    }
end

local function GetPageDB()
    if not (ExwindTools and ExwindTools.GetModuleDB) then
        return GetPageDBDefaults()
    end
    return ExwindTools:GetModuleDB(MODULE_KEY, GetPageDBDefaults())
end

local function SyncPageDBFromRuntime()
    local db = GetPageDB()
    if ExBoss.GetLocaleMode then
        db.localeMode = tostring(ExBoss:GetLocaleMode() or "AUTO")
    end
    return db
end

local function ReleaseInformationControl(control)
    if not control then return end
    local factory = _G.ExwindFactory
    if factory and factory.ReleaseGridWidget then
        factory:ReleaseGridWidget(control)
    else
        control:Hide()
        control:SetParent(nil)
    end
end

local HOME_TEXT_COLOR = { 0.91, 0.93, 0.96, 1 }
local HOME_NAME_COLOR = { 0.42, 0.76, 1, 1 }
local HOME_LINK_COLOR = { 0.82, 0.87, 0.93, 1 }

local function GetHomeFontPath()
    local tools = _G.ExwindTools
    if tools and type(tools.MAIN_FONT) == "string" and tools.MAIN_FONT ~= "" then
        return tools.MAIN_FONT
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function StyleInformationText(control, size, color)
    local text = control and (control.text or control.labelText or control)
    if not text then return end
    if text.SetFont then text:SetFont(GetHomeFontPath(), size, "") end
    if text.SetTextColor then text:SetTextColor(unpack(color or HOME_TEXT_COLOR)) end
    if text.SetWordWrap then text:SetWordWrap(true) end
    if text.SetJustifyH then text:SetJustifyH("LEFT") end
    if text.SetJustifyV then text:SetJustifyV("TOP") end
end

local function ResolveInformationColumns(pixelWidth, opts)
    local desired = math.max(1, math.floor(tonumber(opts.columns) or 1))
    local minimum = math.max(180, tonumber(opts.minColumnWidth) or 280)
    local gap = math.max(12, tonumber(opts.columnGap) or 24)
    local available = math.max(1, tonumber(pixelWidth) or 1)
    local fit = math.max(1, math.floor((available + gap) / (minimum + gap)))
    return math.min(desired, fit), gap
end

local function EstimateInformationHeight(pixelWidth, opts)
    local columns = ResolveInformationColumns(pixelWidth, opts)
    local rowGap = math.max(12, tonumber(opts.rowGap) or 18)
    local total, rowHeight, used = 0, 0, 0
    for _, entry in ipairs(opts.entries or {}) do
        local span = math.min(columns, math.max(1, math.floor(tonumber(entry.span) or 1)))
        if used > 0 and used + span > columns then
            total, rowHeight, used = total + rowHeight + rowGap, 0, 0
        end
        local height
        if entry.kind == "text" then
            height = columns == 1 and 58 or 42
        elseif entry.description and entry.value then
            height = 88
        elseif entry.description then
            height = 58
        elseif entry.value then
            height = 56
        else
            height = 24
        end
        rowHeight = math.max(rowHeight, height)
        used = used + span
        if used >= columns then
            total, rowHeight, used = total + rowHeight + rowGap, 0, 0
        end
    end
    if used > 0 then total = total + rowHeight end
    return math.max(28, total - (used == 0 and rowGap or 0))
end

local function SetInformationControlWidth(control, width)
    control:SetWidth(width)
    local text = control.text or control.labelText
    if text and text.SetWidth then text:SetWidth(width) end
end

local function MeasureInformationText(control, width)
    SetInformationControlWidth(control, width)
    local text = control.text or control.labelText
    local height = text and text.GetStringHeight and text:GetStringHeight() or 18
    height = math.max(18, math.ceil(tonumber(height) or 18))
    control:SetHeight(height)
    return height
end

local function RegisterInformationRenderer(Grid)
    if Grid:GetCustomRenderer(INFORMATION_RENDERER) then return end

    Grid:RegisterCustomRenderer(INFORMATION_RENDERER, {
        measure = function(pixelWidth, opts)
            return EstimateInformationHeight(pixelWidth, opts)
        end,
        mount = function(host, ctx)
            local controls = {}
            local opts = ctx.element.opts or {}
            host._exHomeInformationControls = controls

            for _, entry in ipairs(opts.entries or {}) do
                local item = { entry = entry }
                controls[#controls + 1] = item
                if entry.kind == "text" then
                    item.body = EXUI:CreateDescription(host, entry.text or "", 1)
                    StyleInformationText(item.body, 15, HOME_TEXT_COLOR)
                else
                    item.name = EXUI:CreateDescription(host, entry.name or entry.label or "", 1)
                    StyleInformationText(item.name, entry.kind == "person" and 16 or 15,
                        entry.kind == "person" and HOME_NAME_COLOR or HOME_TEXT_COLOR)
                    if entry.description then
                        item.body = EXUI:CreateDescription(host, entry.description, 1)
                        StyleInformationText(item.body, 15, HOME_TEXT_COLOR)
                    end
                end
                if entry.value then
                    local input = EXUI:CreateEditBox(host, entry.value, 1, 26, nil, {})
                    local edit = input.editBox or input
                    local value = tostring(entry.value or "")
                    if edit.SetFont then edit:SetFont(GetHomeFontPath(), 14, "") end
                    if edit.SetTextColor then edit:SetTextColor(unpack(HOME_LINK_COLOR)) end
                    if edit.SetTextInsets then edit:SetTextInsets(9, 9, 0, 0) end
                    edit:SetScript("OnTextChanged", function(self)
                        if self:GetText() ~= value then
                            self:SetText(value)
                            self:HighlightText()
                        end
                    end)
                    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
                    edit:SetScript("OnMouseUp", function(self) self:HighlightText() end)
                    item.input = input
                end
            end
        end,
        layout = function(host, ctx, layoutWidth)
            local width = math.max(1, tonumber(layoutWidth) or ctx:GetContentWidth())
            local opts = ctx.element.opts or {}
            local columns, columnGap = ResolveInformationColumns(width, opts)
            local rowGap = math.max(12, tonumber(opts.rowGap) or 18)
            local unitWidth = math.max(1, (width - columnGap * (columns - 1)) / columns)
            local rows, current = {}, { used = 0, items = {}, height = 0 }

            for _, item in ipairs(host._exHomeInformationControls or {}) do
                local entry = item.entry
                local span = math.min(columns, math.max(1, math.floor(tonumber(entry.span) or 1)))
                if current.used > 0 and current.used + span > columns then
                    rows[#rows + 1] = current
                    current = { used = 0, items = {}, height = 0 }
                end
                local itemWidth = unitWidth * span + columnGap * (span - 1)
                local itemHeight = 0
                if item.name then
                    local nameHeight = MeasureInformationText(item.name, itemWidth)
                    itemHeight = nameHeight
                end
                if item.body then
                    local bodyGap = item.name and 6 or 0
                    local bodyHeight = MeasureInformationText(item.body, itemWidth)
                    itemHeight = itemHeight + bodyGap + bodyHeight
                end
                if item.input then
                    local inputGap = (item.name or item.body) and 8 or 0
                    item.input:SetSize(math.min(itemWidth, tonumber(opts.linkWidth) or 340), 26)
                    itemHeight = itemHeight + inputGap + 26
                end
                item._homeHeight = math.max(18, itemHeight)
                item._homeColumn = current.used
                current.items[#current.items + 1] = item
                current.used = current.used + span
                current.height = math.max(current.height, item._homeHeight)
                if current.used >= columns then
                    rows[#rows + 1] = current
                    current = { used = 0, items = {}, height = 0 }
                end
            end
            if #current.items > 0 then rows[#rows + 1] = current end

            local y = 0
            for _, row in ipairs(rows) do
                for _, item in ipairs(row.items) do
                    local x = item._homeColumn * (unitWidth + columnGap)
                    local localY = y
                    if item.name then
                        item.name:ClearAllPoints()
                        item.name:SetPoint("TOPLEFT", host, "TOPLEFT", x, -localY)
                        localY = localY + item.name:GetHeight()
                    end
                    if item.body then
                        if item.name then localY = localY + 6 end
                        item.body:ClearAllPoints()
                        item.body:SetPoint("TOPLEFT", host, "TOPLEFT", x, -localY)
                        localY = localY + item.body:GetHeight()
                    end
                    if item.input then
                        if item.name or item.body then localY = localY + 8 end
                        item.input:ClearAllPoints()
                        item.input:SetPoint("TOPLEFT", host, "TOPLEFT", x, -localY)
                    end
                end
                y = y + row.height + rowGap
            end
            y = math.max(28, y - (#rows > 0 and rowGap or 0))
            ctx:SetContentHeight(y)
            return y
        end,
        release = function(host)
            for index = #(host._exHomeInformationControls or {}), 1, -1 do
                local item = host._exHomeInformationControls[index]
                if item.input then
                    local edit = item.input.editBox or item.input
                    edit:SetScript("OnTextChanged", nil)
                    edit:SetScript("OnEditFocusGained", nil)
                    edit:SetScript("OnMouseUp", nil)
                    edit:ClearFocus()
                    ReleaseInformationControl(item.input)
                end
                ReleaseInformationControl(item.name)
                ReleaseInformationControl(item.body)
            end
            host._exHomeInformationControls = nil
        end,
    })
end

-- [卡片/Grid 迁移边界：首页]
-- 允许：首页静态资料卡与既有语言设置的 x/y/w/h、相对跨度及外观。
-- 禁止：修改 localeMode、ReloadUI 回调、key/type、页面 DB 或 ValueController。
-- 分区标题使用共享 SettingsList 外置标题；卡片正文保持无内置标题栏、无图标、不可折叠。
local function BuildLayout()
    local fullWidth = { ratio = 1 }
    local function InformationCard(id, title, target, entries, opts)
        local contentKey = id .. "_content"
        local placement
        if target then
            placement = { target = target, side = "below", align = "start", gap = CARD_GAP, width = fullWidth }
        else
            placement = { target = "$container", point = "TOPLEFT", relativePoint = "TOPLEFT", width = fullWidth }
        end
        opts = opts or {}
        opts.entries = entries
        return {
            id = id,
            title = title,
            placement = placement,
            content = { kind = "grid", items = {
                { key = contentKey, type = "custom", renderer = INFORMATION_RENDERER,
                    opts = opts, measure = true, x = 1, y = 1, w = 198, h = 1 },
            } },
            settingsList = {
                title = title,
                preserveHeader = false,
                rows = { { key = contentKey, fullWidth = true } },
            },
        }
    end

    return {
        version = 1,
        settingsListWidthPercent = 100,
        cards = {
            InformationCard("official", "官方资源", nil, HOME_INFORMATION.official, {
                columns = 3, minColumnWidth = 320, columnGap = 28, rowGap = 20, linkWidth = 340,
            }),
            InformationCard("contact", "联系与支持", "official", HOME_INFORMATION.contact, {
                columns = 4, minColumnWidth = 250, columnGap = 28, rowGap = 18, linkWidth = 300,
            }),
            InformationCard("third-party", "第三方人员感谢", "contact", HOME_INFORMATION.thirdParty, {
                columns = 2, minColumnWidth = 430, columnGap = 36, rowGap = 22, linkWidth = 360,
            }),
            InformationCard("special-thanks", "特别感谢", "third-party", HOME_INFORMATION.specialThanks, {
                columns = 2, minColumnWidth = 430, columnGap = 36, rowGap = 24, linkWidth = 360,
            }),
            {
                id = "locale",
                title = L["界面语言"],
                placement = { target = "special-thanks", side = "below", align = "start",
                    gap = CARD_GAP, width = fullWidth },
                content = { kind = "grid", items = {
                    { key = "localeMode", type = "select", label = L["界面语言"], items = LOCALE_ITEMS,
                        search = true, x = 1, y = 1, w = 120, h = 10 },
                    { key = "btn_reload_ui", type = "button", label = L["立即重载界面"],
                        func = function() ReloadUI() end, x = 125, y = 1, w = 74, h = 10 },
                    { key = "desc_locale_status", type = "custom", renderer = INFORMATION_RENDERER,
                        opts = { columns = 1, entries = {
                            { kind = "text", text = BuildLocaleStatusText() },
                        } }, measure = true, x = 1, y = 13, w = 198, h = 1 },
                } },
                settingsList = {
                    title = L["界面语言"],
                    preserveHeader = false,
                    rows = {
                        { key = "localeMode", label = L["界面语言"] },
                        { controls = { { key = "btn_reload_ui", width = 140 } } },
                        { key = "desc_locale_status", fullWidth = true },
                    },
                },
            },
        },
    }
end

local function FindLayoutEntry(layout, key)
    if type(layout) ~= "table" then
        return nil
    end
    local function FindItems(items)
        if type(items) ~= "table" then
            return nil
        end
        for i = 1, #items do
            local item = items[i]
            if item and item.key == key then
                return item
            end
            local found = item and FindItems(item.children)
            if found then
                return found
            end
        end
    end
    if type(layout.cards) == "table" then
        for i = 1, #layout.cards do
            local card = layout.cards[i]
            local found = FindItems(card.content and card.content.items)
            if found then return found end
        end
    end
    return FindItems(layout)
end

local function UpdateLayoutData(layout)
    local db = SyncPageDBFromRuntime()
    local updates = {
        desc_locale_status = { opts = { columns = 1, entries = {
            { kind = "text", text = BuildLocaleStatusText() },
        } } },
        localeMode = { items = LOCALE_ITEMS },
    }

    db.localeMode = tostring(ExBoss.GetLocaleMode and ExBoss:GetLocaleMode() or db.localeMode or "AUTO")

    for key, fields in pairs(updates) do
        local item = FindLayoutEntry(layout, key)
        if item then
            for field, value in pairs(fields) do
                item[field] = value
            end
        end
    end
end

local function GetOrBuildLayout()
    if type(pageLayoutData) ~= "table" then
        pageLayoutData = BuildLayout()
    end
    UpdateLayoutData(pageLayoutData)
    return pageLayoutData
end

-- [混合函数边界] RenderGrid 内只可替换 Scroll/Grid 的几何挂载语句；RegisterModuleLayout、CurrentModule、DB 与延迟 guard 禁止修改。
local function RenderGrid(contentFrame, resetScroll)
    local Grid = _G.ExwindGrid
    local EXUI = ExwindTools and ExwindTools.UI
    if not (Grid and EXUI and ExwindTools) then
        return false
    end

    RegisterInformationRenderer(Grid)
    local layout = GetOrBuildLayout()
    ExwindTools:RegisterModuleLayout(MODULE_KEY, layout)

    if not scrollFrame then
        scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "ScrollFrameTemplate")
        if ExBoss.UI and ExBoss.UI.ApplyModernScrollBarSkin then
            ExBoss.UI.ApplyModernScrollBarSkin(scrollFrame)
        end
        scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)
    end

    if missingDepsText then
        missingDepsText:Hide()
    end

    scrollFrame:SetParent(contentFrame)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -18, 4)
    if resetScroll == true then
        scrollFrame:SetVerticalScroll(0)
    end
    scrollFrame:Show()

    C_Timer.After(0, function()
        if not (scrollFrame and scrollFrame:IsShown() and scrollChild) then
            return
        end
        local width = contentFrame:GetWidth()
        if width < 100 then
            width = 1400
        end
        scrollChild:SetWidth(width - 16)
        scrollChild:SetHeight(1)
        scrollChild:SetParent(scrollFrame)
        scrollChild:ClearAllPoints()
        scrollChild:SetPoint("TOPLEFT", 0, 0)
        scrollChild:Show()

        if ExwindTools.UI then
            ExwindTools.UI.ActivePageFrame = scrollChild
            ExwindTools.UI.CurrentModule = MODULE_KEY
        end
        if cardSession and type(cardSession.Release) == "function" then
            cardSession:Release()
            cardSession = nil
        end
        cardSession = Grid:MountCards(scrollChild, layout, {
            pageId = MODULE_KEY,
            regionId = "home",
            config = GetPageDB(),
            moduleKey = MODULE_KEY,
            scrollFrame = scrollFrame,
        })
    end)

    return true
end

RefreshPage = function(resetScroll)
    local contentFrame = Page._contentFrame
    if not contentFrame then
        return
    end

    if RenderGrid(contentFrame, resetScroll) then
        return
    end

    if scrollFrame then
        scrollFrame:Hide()
    end
    if not missingDepsText then
        missingDepsText = EXUI:CreateVisualFontString(contentFrame, EXFONTFRAME, "GameFontHighlight")
        missingDepsText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 20, -20)
        missingDepsText:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -20, 0)
        missingDepsText:SetJustifyH("LEFT")
        missingDepsText:SetJustifyV("TOP")
    end
    missingDepsText:SetText(L["首页依赖 ExwindTools.UI 与 ExwindGrid，当前未就绪。请确认 ExwindCore 已正确加载后重开面板。"])
    missingDepsText:Show()
end

local function RefreshActiveSurfaces()
    local db = GetPageDB()
    local mode = tostring(db.localeMode or "AUTO")
    if ExBoss.SetLocaleMode then
        ExBoss:SetLocaleMode(mode)
    end
end

function Page:Render(contentFrame)
    Page._contentFrame = contentFrame
    SyncPageDBFromRuntime()
    RefreshPage(true)
end

function Page:Hide()
    if scrollFrame then
        scrollFrame:Hide()
    end
    if missingDepsText then
        missingDepsText:Hide()
    end
end

if EXUI then
    EXUI:RegisterModuleValueController(MODULE_KEY, {
        RefreshActiveSurfaces = RefreshActiveSurfaces,
    })
end
