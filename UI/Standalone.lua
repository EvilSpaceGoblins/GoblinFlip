local _, GF = ...
local Window = {}
GF.UI.Standalone = Window
function Window.Create()
    if Window.frame then return Window.frame end
    local f = CreateFrame("Frame", "GoblinFlipStandalone", UIParent, "BasicFrameTemplateWithInset")
    Window.frame = f
    f:SetSize(1080, 700)
    f:SetPoint("CENTER")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.TitleText then f.TitleText:SetText("GoblinFlip " .. GF.version) end
    f:Hide()
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 10, -30)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    Window.content = content
    f:SetScript("OnShow", function()
        f:SetScale(math.min(1, (UIParent:GetWidth() - 30) / 1080, (UIParent:GetHeight() - 30) / 700))
        GF.UI.Mount(content)
    end)
    f.CloseButton:SetScript("OnClick", function() f:Hide() end)
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "GoblinFlipStandalone")
    return f
end
function Window.Show()
    Window.Create():Show()
    GF.UI.Mount(Window.content)
end
function Window.Hide() if Window.frame then Window.frame:Hide() end end
function Window.IsVisible() return Window.frame and Window.frame:IsShown() or false end
function Window.Toggle() if Window.IsVisible() then Window.Hide() else Window.Show() end end
function Window.GetFrame() return Window.frame end
