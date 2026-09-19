-- Temporary, user-authorized color comparison. No configuration or CVar access.
-- Remove this file and its single EXBoss.toc entry to remove the tool.
local EXUI = ExwindTools.UI
local panel
local samples = {
    { name = "Boss 面板", hex = "#171A1F", r = 23 / 255, g = 26 / 255, b = 31 / 255 },
    { name = "外卡", hex = "#1C1F24", r = 28 / 255, g = 31 / 255, b = 36 / 255 },
    { name = "子卡", hex = "#1F2328", r = 31 / 255, g = 35 / 255, b = 40 / 255 },
}

local function Label(parent, text, size, x, y, width)
    local label = EXUI:CreateVisualFontString(parent, EXFONTFRAME, "GameFontHighlight")
    label:SetFont(ExwindTools.MAIN_FONT, size, "")
    label:SetTextColor(1, 1, 1, 1)
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetText(text)
    return label
end

local function ShowComparison()
    if panel then panel:Show(); return end
    panel = CreateFrame("Frame", "EXBossTemporaryColorComparison", UIParent)
    panel:SetSize(690, 580)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetAlpha(1)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)

    -- The diagnostic host and native samples intentionally bypass GUI skins.
    local backdrop = EXUI:CreateVisualTexture(panel, EXBACKGROUNDFRAME)
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(19 / 255, 22 / 255, 25 / 255, 1)
    Label(panel, "临时颜色对照 · 拖动标题移动", 18, 20, -16, 530)
    Label(panel, "色块固定 RGB、alpha=1，不跟随正式色表。请自行调整游戏显示设置对照。", 12, 20, -49, 650)
    Label(panel, "左：原生纯色纹理", 14, 20, -83, 310)
    Label(panel, "右：现有 EXUI surface", 14, 360, -83, 310)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT")
    drag:SetPoint("TOPRIGHT", -100, 0)
    drag:SetHeight(43)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    drag:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local close = EXUI:CreateButton(panel, 72, 28, "关闭", function() panel:Hide() end)
    close:SetPoint("TOPRIGHT", -14, -12)

    local detail = Label(panel, "鼠标移到色块可查看 API 读值。\n这些数值不是屏幕最终像素；关闭后重登或 /reload 可再次显示。", 12, 20, -520, 650)
    detail:SetHeight(48)

    for index, sample in ipairs(samples) do
        local top = -113 - (index - 1) * 132
        Label(panel, sample.name .. "  " .. sample.hex .. "  alpha=1", 14, 20, top, 650)
        for column = 1, 2 do
            local swatch = CreateFrame("Frame", nil, panel)
            swatch:SetSize(310, 96)
            swatch:SetPoint("TOPLEFT", column == 1 and 20 or 360, top - 25)
            swatch:SetAlpha(1)
            swatch:EnableMouse(true)
            local texture
            if column == 1 then
                texture = EXUI:CreateVisualTexture(swatch, EXBACKGROUNDFRAME)
                texture:SetAllPoints()
                texture:SetColorTexture(1, 1, 1, 1)
                texture:SetVertexColor(sample.r, sample.g, sample.b, 1)
            else
                local color = { sample.r, sample.g, sample.b, 1 }
                EXUI:SetControlSurface(swatch, 10, color, color)
                for _, piece in ipairs(swatch._exModernSurfaces[10].pieces) do
                    if piece.layer == 2 and piece.row == 2 and piece.col == 2 then
                        texture = piece.texture
                        break
                    end
                end
            end
            local path = column == 1 and "原生纯色" or "EXUI 中心填充纹理"
            swatch:SetScript("OnEnter", function()
                local r, g, b, a = texture:GetVertexColor()
                detail:SetText(string.format(
                    "%s · %s %s  设定 RGBA=(%.6f, %.6f, %.6f, 1)\nAPI 顶点=(%.6f, %.6f, %.6f, %.6f)  纹理 alpha=%.3f  宿主有效 alpha=%.3f（非最终像素）",
                    path, sample.name, sample.hex, sample.r, sample.g, sample.b,
                    r, g, b, a, texture:GetAlpha(), swatch:GetEffectiveAlpha()))
            end)
        end
    end
    panel:Show()
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ShowComparison()
end)
if IsLoggedIn() then
    login:UnregisterEvent("PLAYER_LOGIN")
    ShowComparison()
end
