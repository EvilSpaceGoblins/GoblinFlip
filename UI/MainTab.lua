local _, GF = ...
local Tab = {tabId = "GoblinFlipMainTab"}
GF.UI.MainTab = Tab
function Tab.Create()
    if Tab.attached then return Tab.frame end
    local lib = LibStub:GetLibrary("LibAHTab-1-0", true)
    if not lib or not AuctionHouseFrame or not AuctionHouseFrame.Tabs or #AuctionHouseFrame.Tabs == 0 then return end
    local frame = Tab.frame or CreateFrame("Frame", "GoblinFlipMainTabFrame", AuctionHouseFrame)
    Tab.frame = frame
    frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 0, -60)
    frame:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -5, 35)
    frame:Hide()
    frame:SetScript("OnShow", function() GF.UI.Mount(frame) end)
    local ok, err = pcall(lib.CreateTab, lib, Tab.tabId, frame, "GoblinFlip", "GoblinFlip")
    if not ok then GF.Util.Print("AH tab: " .. tostring(err)); return end
    Tab.attached = true
    return frame
end
function Tab.Show()
    if not Tab.Create() then return GF.UI.Standalone.Show() end
    LibStub:GetLibrary("LibAHTab-1-0"):SetSelected(Tab.tabId)
end
function Tab.IsCreated() return Tab.attached == true end
function Tab.GetFrame() return Tab.frame end
GF.UI.AttachToAuctionHouse = Tab.Create
