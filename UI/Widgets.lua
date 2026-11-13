-- UI Widgets: reusable widget factory functions for GoblinFlip.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.Widgets = {}

local Widgets = GF.UI.Widgets

--- Create a standard button with consistent styling.
---@param parent Frame
---@param text string
---@param width number|nil
---@param height number|nil
---@return Button
function Widgets.CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetText(text)
    if width then btn:SetWidth(width) end
    if height then btn:SetHeight(height) end
    return btn
end

--- Create a standard check button.
---@param parent Frame
---@param label string
---@param tooltip string|nil
---@return CheckButton
function Widgets.CreateCheckButton(parent, label, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return cb
end

--- Create a standard dropdown menu.
---@param parent Frame
---@param width number
---@param items table array of {value, text}
---@param onSelect function(value, text)
---@return Frame
function Widgets.CreateDropdown(parent, width, items, onSelect)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetWidth(width)
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.func = function(self2)
                UIDropDownMenu_SetSelectedValue(dd, self2.value)
                if onSelect then onSelect(self2.value, self2:GetText()) end
            end
            info.checked = (UIDropDownMenu_GetSelectedValue(dd) == item.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dd
end

--- Create an edit box with numeric input validation.
---@param parent Frame
---@param width number
---@param height number
---@param maxLetters number|nil
---@param numeric boolean|nil
---@return EditBox
function Widgets.CreateEditBox(parent, width, height, maxLetters, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetWidth(width)
    eb:SetHeight(height)
    eb:SetAutoFocus(false)
    if maxLetters then eb:SetMaxLetters(maxLetters) end
    if numeric then eb:SetNumeric(true) end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

--- Create a font string with standard styling.
---@param parent Frame
---@param text string
---@param fontObject FontObject|nil
---@param color table|nil {r,g,b}
---@return FontString
function Widgets.CreateFontString(parent, text, fontObject, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
    fs:SetText(text)
    if color then fs:SetTextColor(color.r, color.g, color.b) end
    return fs
end

--- Create a horizontal line separator.
---@param parent Frame
---@param width number|nil
---@param color table|nil {r,g,b,a}
---@return Texture
function Widgets.CreateSeparator(parent, width, color)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(color and color.r or 0.5, color and color.g or 0.5, color and color.b or 0.5, color and color.a or 0.3)
    tex:SetHeight(1)
    if width then tex:SetWidth(width) else tex:SetPoint("LEFT", 4, 0); tex:SetPoint("RIGHT", -4, 0) end
    return tex
end

--- Create a scroll frame with a content child.
---@param parent Frame
---@param width number|nil
---@param height number|nil
---@return ScrollFrame, Frame content
function Widgets.CreateScrollFrame(parent, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    if width then scroll:SetWidth(width) end
    if height then scroll:SetHeight(height) end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(width or 1)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    return scroll, content
end

--- Create a simple tooltip anchor helper.
---@param frame Frame
---@param text string
---@param anchor string|nil
function Widgets.SetTooltip(frame, text, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

--- Format copper as gold/silver/copper string.
---@param copper number
---@return string
function Widgets.FormatMoney(copper)
    if not copper or copper < 0 then return "0c" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if gold > 0 then
        return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, c)
    elseif silver > 0 then
        return string.format("|cffc7c7cf%ds|r |cffeda55f%dc|r", silver, c)
    else
        return string.format("|cffeda55f%dc|r", c)
    end
end

--- Format ROI percentage.
---@param roi number
---@return string
function Widgets.FormatROI(roi)
    if not roi then return "0%" end
    local color = roi >= 50 and "|cff00ff00" or (roi >= 20 and "|cffffff00" or "|cffffffff")
    return string.format("%s%.1f%%|r", color, roi)
end

--- Create a money display (read-only).
---@param parent Frame
---@param copper number
---@param fontObject FontObject|nil
---@return FontString
function Widgets.CreateMoneyDisplay(parent, copper, fontObject)
    local fs = Widgets.CreateFontString(parent, Widgets.FormatMoney(copper), fontObject or "GameFontHighlight")
    fs:SetJustifyH("RIGHT")
    return fs
end

--- Color quality text by item quality.
---@param text string
---@param quality number
---@return string
function Widgets.ColorQuality(text, quality)
    local colors = {
        [0] = "|cff9d9d9d", -- Poor
        [1] = "|cffffffff", -- Common
        [2] = "|cff1eff00", -- Uncommon
        [3] = "|cff0070dd", -- Rare
        [4] = "|cffa335ee", -- Epic
        [5] = "|cffff8000", -- Legendary
    }
    local c = colors[quality] or "|cffffffff"
    return c .. text .. "|r"
end

--- Safe callback wrapper.
---@param fn function|nil
---@param ... any
---@return boolean success
function Widgets.SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, ...)
    if not ok then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("Widget callback error:", err) end
    end
    return ok
end

return Widgets