-- LibDBIcon-1.0
-- Minimap icon library
-- Originally by Nexus, licensed MIT

local MAJOR, MINOR = "LibDBIcon-1.0", 44
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbacks = lib.callbacks or LibStub:GetLibrary("CallbackHandler-1.0"):New(lib)
lib.notCreated = lib.notCreated or {}

local function GetMinimapShape()
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    return shape
end

local function UpdatePosition(button, db)
    local radius = db.radius or 80
    local angle = math.rad(db.minimapPos or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape()
    if shape == "SQUARE" then
        local mx, my = math.abs(x), math.abs(y)
        if mx > my then y = y * mx / my else x = x * mx / my end
    end
    button:SetPoint("CENTER", Minimap, "CENTER", radius * x, radius * y)
end

local function OnDragStart(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.atan2(py - my, px - mx)
        if angle < 0 then angle = angle + 2 * math.pi end
        self.db.minimapPos = math.deg(angle)
        UpdatePosition(self, self.db)
    end)
    self.isMoving = true
    GameTooltip:Hide()
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
    self.isMoving = false
    lib.callbacks:Fire("LibDBIcon_OnDragStop", self.name)
end

local function OnEnter(self)
    if self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.tooltip, 1, 1, 1)
        GameTooltip:Show()
    end
    lib.callbacks:Fire("LibDBIcon_OnEnter", self.name)
end

local function OnLeave(self)
    GameTooltip:Hide()
    lib.callbacks:Fire("LibDBIcon_OnLeave", self.name)
end

local function OnClick(self, button)
    lib.callbacks:Fire("LibDBIcon_OnClick", self.name, button)
end

local function OnMouseDown(self)
    if IsAltKeyDown() and not self.db.lock then
        self:SetScript("OnUpdate", OnDragStart)
    end
end

local function OnMouseUp(self)
    self:SetScript("OnUpdate", nil)
    if self.isMoving then
        OnDragStop(self)
    end
end

function lib:Register(name, object, db)
    assert(type(name) == "string", "Name must be a string")
    assert(type(object) == "table", "Object must be a table")
    assert(type(db) == "table", "DB must be a table")
    assert(not lib.objects[name], "Object already registered")

    if not db.minimapPos then db.minimapPos = 225 end
    if db.radius == nil then db.radius = 80 end

    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetToplevel(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.overlay = overlay

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 1, -1)
    icon:SetTexture(object.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon = icon

    if object.iconCoords then
        icon:SetTexCoord(unpack(object.iconCoords))
    end

    button.name = name
    button.db = db
    button.object = object
    button.tooltip = object.tooltip

    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnMouseDown", OnMouseDown)
    button:SetScript("OnMouseUp", OnMouseUp)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)

    UpdatePosition(button, db)
    lib.objects[name] = button

    if db.hide then
        button:Hide()
    else
        button:Show()
    end

    lib.notCreated[name] = nil
end

function lib:GetMinimapButton(name)
    return lib.objects[name]
end

function lib:Show(name)
    local button = lib.objects[name]
    if button then
        button.db.hide = false
        button:Show()
    end
end

function lib:Hide(name)
    local button = lib.objects[name]
    if button then
        button.db.hide = true
        button:Hide()
    end
end

function lib:IsRegistered(name)
    return lib.objects[name] ~= nil
end

function lib:Refresh(name, db)
    local button = lib.objects[name]
    if button then
        button.db = db
        UpdatePosition(button, db)
        if db.hide then
            button:Hide()
        else
            button:Show()
        end
    end
end

function lib:GetButtonList()
    local list = {}
    for name in pairs(lib.objects) do
        table.insert(list, name)
    end
    return list
end

function lib:OnTooltipShow(tt, name)
    local button = lib.objects[name]
    if button and button.tooltip then
        tt:SetText(button.tooltip, 1, 1, 1)
    end
end