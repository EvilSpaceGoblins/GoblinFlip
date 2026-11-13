-- Minimap Icon: LDB launcher with dropdown menu and status tooltip.

local _, GF = ...

GF.UI = GF.UI or {}
GF.UI.MinimapIcon = {}

local MinimapIcon = GF.UI.MinimapIcon

MinimapIcon.initialized = false
MinimapIcon.ldb = nil
MinimapIcon.icon = nil

local function CreateLDBObject()
    local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("LibDataBroker not available, minimap icon disabled") end
        return nil
    end

    local dataObj = ldb:NewDataObject("GoblinFlip", {
        type = "launcher",
        label = "GoblinFlip",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        OnClick = function(_, button)
            if button == "LeftButton" then
                MinimapIcon.ToggleMainWindow()
            elseif button == "RightButton" then
                MinimapIcon.ShowDropdown()
            end
        end,
        OnTooltipShow = function(tt)
            MinimapIcon.BuildTooltip(tt)
        end,
    })
    return dataObj
end

function MinimapIcon.Initialize()
    if MinimapIcon.initialized then return end
    MinimapIcon.initialized = true

    -- Check if LibDBIcon is available
    local libDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if not libDBIcon then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("LibDBIcon not available, minimap icon disabled") end
        return
    end

    -- Create LDB object
    MinimapIcon.ldb = CreateLDBObject()
    if not MinimapIcon.ldb then
        if GF.Debug and GF.Debug.Log then GF.Debug:Log("LibDataBroker not available, minimap icon disabled") end
        return
    end

    -- Initialize saved variables
    if not GF.Settings.db.minimapIcon then
        GF.Settings.db.minimapIcon = {
            hide = false,
            minimapPos = 225,
            radius = 80,
            lock = false,
        }
    end

    -- Register with LibDBIcon
    libDBIcon:Register("GoblinFlip", MinimapIcon.ldb, GF.Settings.db.minimapIcon)
    MinimapIcon.icon = libDBIcon:GetMinimapButton("GoblinFlip")

    if GF.Debug and GF.Debug.Log then GF.Debug:Log("Minimap icon initialized") end
end

function MinimapIcon.BuildTooltip(tt)
    local view = GF.App and GF.App.GetView and GF.App:GetView() or {}
    local identity = view.identity
    local metrics = view.metrics or {}
    local budget = view.budget or 0
    local spent = view.sessionSpent or 0

    tt:AddLine("|cffFFD700GoblinFlip|r")
    tt:AddLine(" ")

    if identity then
        tt:AddDoubleLine("Market:", identity.houseLabel or "?", 1, 1, 1, 1, 1, 1)
    end

    local vendorCount = 0
    local deCount = 0
    if view.rows then
        for _, row in ipairs(view.rows) do
            if row.strategy == GF.STRATEGY_VENDOR then vendorCount = vendorCount + 1
            elseif row.strategy == GF.STRATEGY_DISENCHANT then deCount = deCount + 1 end
        end
    end
    tt:AddDoubleLine("Vendor Flips:", vendorCount, 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine("DE Estimates:", deCount, 1, 1, 1, 1, 1, 1)
    tt:AddDoubleLine("Avg ROI:", string.format("%.1f%%", metrics.avgRoi or 0), 1, 1, 1, 1, 1, 1)

    if budget > 0 then
        local remaining = budget - spent
        tt:AddLine(" ")
        tt:AddDoubleLine("Budget:", GF.UI.Widgets.FormatMoney(spent) .. " / " .. GF.UI.Widgets.FormatMoney(budget), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("Remaining:", GF.UI.Widgets.FormatMoney(math.max(0, remaining)), 1, 1, 1, 1, 1, 1)
    end

    local lastScan = view.lastScanAt or 0
    if lastScan > 0 then
        tt:AddLine(" ")
        tt:AddDoubleLine("Last Scan:", date("%H:%M:%S", lastScan), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    end

    tt:AddLine(" ")
    tt:AddLine("|cffffff00Left-click|r: Toggle Window")
    tt:AddLine("|cffffff00Right-click|r: Menu")
end

function MinimapIcon.ShowDropdown()
    if not MinimapIcon.icon then return end

    local menu = {
        { text = "GoblinFlip", isTitle = true, notCheckable = true },
        { text = "Open Window", notCheckable = true, func = function() MinimapIcon.ToggleMainWindow() end },
        { text = " ", disabled = true, notCheckable = true },
        { text = "Scan", notCheckable = true, func = function() if GF.App and GF.App.RequestScan then GF.App:RequestScan() end end },
        { text = "Ledger", notCheckable = true, func = function() MinimapIcon.ShowLedger() end },
        { text = "History", notCheckable = true, func = function() MinimapIcon.ShowHistory() end },
        { text = "Settings", notCheckable = true, func = function() if GF.UI.Options and GF.UI.Options.GetFrame then GF.UI.Options.GetFrame():Show() end end },
        { text = " ", disabled = true, notCheckable = true },
        { text = "Standalone Mode", checked = function() return GF.Settings.Get("standaloneMode") end, func = function()
            GF.Settings.Set("standaloneMode", not GF.Settings.Get("standaloneMode"))
            if GF.App and GF.App.CheckDependencies then GF.App:CheckDependencies() end
        end },
        { text = "Minimap Icon", checked = function() return not GF.Settings.db.minimapIcon.hide end, func = function()
            GF.Settings.db.minimapIcon.hide = not GF.Settings.db.minimapIcon.hide
            local libDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
            if libDBIcon then
                if GF.Settings.db.minimapIcon.hide then libDBIcon:Hide("GoblinFlip") else libDBIcon:Show("GoblinFlip") end
            end
        end },
        { text = "Lock Position", checked = function() return GF.Settings.db.minimapIcon.lock end, func = function()
            GF.Settings.db.minimapIcon.lock = not GF.Settings.db.minimapIcon.lock
        end },
        { text = " ", disabled = true, notCheckable = true },
        { text = "Help", notCheckable = true, func = function() print("|cffFFD700/gf help|r") end },
        { text = "Close", notCheckable = true },
    }

    -- Use UIDropDownMenu
    local dropdown = CreateFrame("Frame", "GoblinFlipMinimapDropdown", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, item in ipairs(menu) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.isTitle = item.isTitle
            info.disabled = item.disabled
            info.notCheckable = item.notCheckable ~= false
            if item.checked then
                info.checked = type(item.checked) == "function" and item.checked() or item.checked
                info.isNotRadio = true
            end
            info.func = item.func
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Show at cursor
    UIDropDownMenu_Show(dropdown, "cursor")
end

function MinimapIcon.ToggleMainWindow()
    -- Try AH tab first
    if GF.UI.MainTab and GF.UI.MainTab.IsCreated and GF.UI.MainTab:IsCreated() then
        local libAHTab = LibStub:GetLibrary("LibAHTab-1.0", true)
        if libAHTab and libAHTab.GetButton then
            local btn = libAHTab:GetButton(GF.UI.MainTab.tabId)
            if btn then btn:Click() return end
        end
    end

    -- Fallback to standalone window
    if GF.UI.Standalone then
        GF.UI.Standalone.Toggle()
    end
end

function MinimapIcon.ShowLedger()
    -- Try to show ledger view in AH tab
    if GF.UI.MainTab and GF.UI.MainTab.IsCreated and GF.UI.MainTab:IsCreated() then
        local libAHTab = LibStub:GetLibrary("LibAHTab-1.0", true)
        if libAHTab and libAHTab.GetButton then
            local btn = libAHTab:GetButton(GF.UI.MainTab.tabId)
            if btn then btn:Click() end
        end
        -- TODO: Switch to ledger tab if we have sub-tabs
    end
    if GF.UI.Standalone and GF.UI.Standalone.IsVisible then
        GF.UI.Standalone.Show()
        -- TODO: Switch to ledger view
    end
end

function MinimapIcon.ShowHistory()
    if GF.UI.Standalone then
        GF.UI.Standalone.Show()
    end
end

function MinimapIcon.IsVisible()
    if MinimapIcon.icon then
        return MinimapIcon.icon:IsVisible()
    end
    return false
end

function MinimapIcon.Show()
    local libDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if libDBIcon then libDBIcon:Show("GoblinFlip") end
end

function MinimapIcon.Hide()
    local libDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    if libDBIcon then libDBIcon:Hide("GoblinFlip") end
end

return MinimapIcon