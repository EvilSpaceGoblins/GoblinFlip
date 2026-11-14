-- Deliberately non-fluent widget methods: invalid SetPoint chains must fail.
local M = {frames = {}, messages = {}, now = 1000, money = 1000000}
local methods = {}
local function object(kind, name, parent)
    local o = {kind = kind, name = name, parent = parent, shown = true, scripts = {}, events = {}, width = 800, height = 500}
    setmetatable(o, {__index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key:match("^RegisterFor") or key:match("^EnableMouse") or key:match("^Clear")
            or key:match("^Lock") or key:match("^Unlock") or key:match("^StartMoving") or key:match("^StopMoving") then
            return function(self) assert(type(self) == "table", key .. " requires self") end
        end
    end})
    if name then _G[name] = o end
    return o
end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end; fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetText(text)
    self.text = tostring(text or "")
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:GetText() return self.text or "" end
function methods:SetPoint(...) assert(type(self) == "table", "SetPoint requires self"); self.point = {...} end
function methods:SetParent(parent) self.parent = parent end
function methods:GetParent() return self.parent end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(scale) self.scale = scale end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetCenter() return 500, 400 end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:Hide()
    local was = self.shown; self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show()
    local was = self.shown; self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:CreateTexture() return object("Texture", nil, self) end
function methods:CreateFontString() return object("FontString", nil, self) end
function methods:GetFontString() self.font = self.font or object("FontString", nil, self); return self.font end
function methods:SetChecked(value) self.checked = value == true end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:Click(button) if self.enabled ~= false and self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
function methods:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end
function methods:AddDoubleLine(a, b) self:AddLine(a .. " " .. tostring(b)) end
function methods:SetFocus() end
function methods:GetItem() return nil end
function methods:AddMessage(text) M.messages[#M.messages + 1] = text end
function M.Install()
    _G.unpack = _G.unpack or table.unpack
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
    _G.securecallfunction = function(fn, ...) return fn(...) end
    _G.CreateFrame = function(kind, name, parent, template)
        local f = object(kind, name, parent)
        if template and template:find("BasicFrameTemplate") then
            f.CloseButton, f.TitleText = object("Button", nil, f), object("FontString", nil, f)
        end
        if kind == "CheckButton" then f.Text = object("FontString", nil, f) end
        M.frames[#M.frames + 1] = f
        return f
    end
    _G.UIParent = object("Frame"); UIParent:SetSize(1920, 1080)
    _G.Minimap = object("Frame", nil, UIParent)
    _G.GameTooltip = object("GameTooltip")
    _G.ItemRefTooltip = object("GameTooltip")
    _G.DEFAULT_CHAT_FRAME = object("Frame")
    _G.GetLocale = function() return os.getenv("GF_TEST_LOCALE") or "enUS" end
    _G.GetBuildInfo = function() return "1.60.1", "16001", "", 16001 end
    _G.GetMoney = function() return M.money end
    _G.GetRealmName = function() return "TestRealm" end
    _G.UnitName = function() return "Tester" end
    _G.UnitFactionGroup = function() return "Horde" end
    _G.GetZoneText = function() return "Orgrimmar" end
    _G.GetSubZoneText = function() return "" end
    _G.GetCurrentRegion = function() return 3 end
    _G.time = function() return math.floor(M.now) end
    _G.date = os.date
    _G.WOW_PROJECT_ID, _G.WOW_PROJECT_MAINLINE = 1, 1
    _G.C_Item = {GetItemInfo = function(id) return "Test item", "item:123", 2, 20, nil, nil, nil, nil, nil, 1, 375, 2, 1 end}
    _G.C_AuctionHouse = {
        MakeItemKey = function(id, level, suffix, pet) return {itemID = id, itemLevel = level, itemSuffix = suffix, battlePetSpeciesID = pet} end,
        GetItemKeyInfo = function(key) assert(key.itemID); return {isCommodity = key.itemID == 99} end,
        SendSearchQuery = function() end, GetNumItemSearchResults = function() return 0 end,
        GetItemSearchResultInfo = function() end, PlaceBid = function() end,
        ReplicateItems = function() end, GetNumReplicateItems = function() return 0 end,
        GetReplicateItemInfo = function() end, GetReplicateItemLink = function() end,
        GetReplicateItemTimeLeft = function() end,
    }
    for _, name in ipairs({"UIDropDownMenu_SetWidth", "UIDropDownMenu_AddButton", "PanelTemplates_TabResize", "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "ToggleDropDownMenu", "GameTooltip_Hide"}) do _G[name] = function() end end
    _G.UIDropDownMenu_Initialize = function(frame, fn) frame.initialize = fn end
    _G.UIDropDownMenu_CreateInfo = function() return {} end
    _G.UIDropDownMenu_SetSelectedValue = function(frame, value) frame.selected = value end
    _G.UIDropDownMenu_GetSelectedValue = function(frame) return frame.selected end
    _G.StaticPopupDialogs, _G.SlashCmdList = {}, {}
    _G.StaticPopup_Show = function(name)
        local f = object("Frame"); f.editBox = object("EditBox"); f.button1 = object("Button")
        local d = StaticPopupDialogs[name]; M.popup = {frame = f, dialog = d}
        if d.OnShow then d.OnShow(f) end
        return f
    end
    _G.hooksecurefunc = function(target, key, fn)
        local old = target[key]
        target[key] = function(...) if old then old(...) end; fn(...) end
    end
end
function M.Event(event, ...)
    local frames = {}; for i, f in ipairs(M.frames) do frames[i] = f end
    for _, f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end
end
function M.Advance(seconds)
    M.now = M.now + seconds
    local frames = {}; for i, f in ipairs(M.frames) do frames[i] = f end
    for _, f in ipairs(frames) do if f:IsVisible() and f.scripts.OnUpdate then f.scripts.OnUpdate(f, seconds) end end
end
return M
