-- Localization. English is the source language; deDE entries are provided for
-- the main workflow and may lag behind newly added strings (fallback is English).

local _, GF = ...

local locale = "enUS"
if type(GetLocale) == "function" then
    local ok, value = pcall(GetLocale)
    if ok and type(value) == "string" then
        locale = value
    end
end

GF.locale = locale

local enUS = {
    ["GoblinFlip"] = "GoblinFlip",
    ["Every copper counts."] = "Every copper counts.",

    ["Vendor Flips"] = "Vendor Flips",
    ["Disenchant"] = "Disenchant",
    ["History"] = "History",
    ["Ledger"] = "Ledger",
    ["Settings"] = "Settings",

    ["Scan"] = "Scan",
    ["Scanning"] = "Scanning",
    ["Refresh selected"] = "Refresh selected",
    ["Buy Next"] = "Buy Next",
    ["Buy"] = "Buy",
    ["Confirm"] = "Confirm",
    ["Cancel"] = "Cancel",
    ["Close"] = "Close",
    ["Apply"] = "Apply",
    ["Reset"] = "Reset",
    ["Reset filters"] = "Reset filters",
    ["Reset budget"] = "Reset budget",
    ["Export"] = "Export",
    ["Clear"] = "Clear",
    ["Retry"] = "Retry",
    ["Blacklist"] = "Blacklist",
    ["Blacklisted"] = "Blacklisted",
    ["Remove"] = "Remove",
    ["Save"] = "Save",

    ["Current"] = "Current",
    ["Last scan"] = "Last scan",
    ["Snapshot only until validated."] = "Snapshot only until validated.",
    ["Snapshot"] = "Snapshot",
    ["Live"] = "Live",
    ["Stale"] = "Stale",
    ["Unavailable"] = "Unavailable",
    ["Unknown"] = "Unknown",
    ["Read-only"] = "Read-only",
    ["Estimated"] = "Estimated",
    ["Verified"] = "Verified",
    ["Pending"] = "Pending",

    ["Opportunities"] = "Opportunities",
    ["Investment"] = "Investment",
    ["Proceeds"] = "Proceeds",
    ["Potential profit"] = "Potential profit",
    ["Session spent"] = "Session spent",
    ["Budget"] = "Budget",
    ["Remaining budget"] = "Remaining budget",
    ["Search"] = "Search",
    ["Min profit"] = "Min profit",
    ["Min ROI"] = "Min ROI",
    ["Max buy"] = "Max buy",
    ["Stack min"] = "Stack min",
    ["Stack max"] = "Stack max",
    ["Show"] = "Show",
    ["Individual lots"] = "Individual lots",
    ["Grouped"] = "Grouped",
    ["Sort"] = "Sort",
    ["Profit"] = "Profit",
    ["ROI"] = "ROI",
    ["Item"] = "Item",
    ["Qty"] = "Qty",
    ["Buyout"] = "Buyout",
    ["Unit"] = "Unit",
    ["Vendor"] = "Vendor",
    ["Expected"] = "Expected",
    ["Age"] = "Age",
    ["Status"] = "Status",
    ["Action"] = "Action",

    ["Selected item and live offers"] = "Selected item and live offers",
    ["Select an opportunity to validate a live price."] = "Select an opportunity to validate a live price.",
    ["Verifying live price..."] = "Verifying live price...",
    ["No live offers matched this item."] = "No live offers matched this item.",
    ["Live price changed."] = "Live price changed. Confirm the new quote.",
    ["Quote expired."] = "Quote expired. Refresh the quote.",
    ["Quote is only valid for %d seconds."] = "Quote is only valid for %d seconds.",
    ["Max spend"] = "Max spend",
    ["Vendor proceeds"] = "Vendor proceeds",
    ["Expected proceeds"] = "Expected proceeds",
    ["Margin"] = "Margin",
    ["Market"] = "Market",
    ["Quote"] = "Quote",
    ["Last verified"] = "Last verified",
    ["just now"] = "just now",

    ["Changes the price after you select it?"] = "Changes the price after you select it?",
    ["Purchase confirmed."] = "Purchase confirmed.",
    ["Purchase submitted."] = "Purchase submitted.",
    ["Purchase failed."] = "Purchase failed.",
    ["Purchase outcome is uncertain."] = "Purchase outcome is uncertain. Do not retry automatically.",
    ["At most one purchase is submitted at a time."] = "At most one purchase is submitted at a time.",
    ["This quote is no longer valid."] = "This quote is no longer valid.",
    ["Not enough gold."] = "Not enough gold.",
    ["Session budget exceeded."] = "Session budget exceeded.",
    ["Per-purchase limit exceeded."] = "Per-purchase limit exceeded.",
    ["Commodity direct purchase is disabled in this build."] = "Commodity direct purchase is disabled in this build. Use the native auction house flow.",
    ["Own listing."] = "Own listing.",
    ["Not profitable at the live price."] = "Not profitable at the live price.",

    ["Scanning is not available yet."] = "Scanning is not available yet.",
    ["Open Auctionator's Buy tab and click Get All."] = "Open Auctionator's Buy tab and click Get All.",
    ["Waiting for Auctionator's full scan..."] = "Waiting for Auctionator's full scan...",
    ["Auctionator full scan received."] = "Auctionator full scan received.",
    ["No Auctionator full-scan event is registered."] = "No Auctionator full-scan event is registered. Is Auctionator loaded?",
    ["No profitable vendor flips found."] = "No profitable vendor flips found.",
    ["No disenchant opportunities found."] = "No disenchant opportunities found.",
    ["Disenchant estimates are unavailable."] = "Disenchant estimates are unavailable.",
    ["DisenchantBuddy is not installed or its API is unavailable."] = "DisenchantBuddy is not installed or its API is unavailable.",
    ["Enchanting skill was not detected."] = "Enchanting skill was not detected. Enable the manual override in Settings if you can disenchant.",
    ["Disenchant values are estimates, not completed sales."] = "Disenchant values are estimates, not completed sales.",

    ["Market"] = "Market",
    ["Horde"] = "Horde",
    ["Alliance"] = "Alliance",
    ["Neutral / Blackwater"] = "Neutral / Blackwater",
    ["Unknown market"] = "Unknown market",
    ["Market unknown - select a house override in Settings."] = "Market unknown - select a house override in Settings.",
    ["Other market history is read-only."] = "Other market history is read-only.",

    ["History for"] = "History for",
    ["Snapshots"] = "Snapshots",
    ["No history stored for this market."] = "No history stored for this market.",
    ["View"] = "View",
    ["Showing saved snapshot."] = "Showing saved snapshot.",
    ["Return to current market"] = "Return to current market",

    ["Transactions"] = "Transactions",
    ["Pending spend"] = "Pending spend",
    ["Confirmed spend"] = "Confirmed spend",
    ["Realized proceeds"] = "Realized proceeds",
    ["Realized profit"] = "Realized profit",
    ["Realized ROI"] = "Realized ROI",
    ["Inventory cost"] = "Inventory cost",
    ["Estimated resale"] = "Estimated resale",
    ["Awaiting mail"] = "Awaiting mail",
    ["Unmatched"] = "Unmatched",
    ["No transactions recorded."] = "No transactions recorded.",
    ["Mark received"] = "Mark received",
    ["Add proceeds"] = "Add proceeds",
    ["Mark uncertain"] = "Mark uncertain",
    ["Mark failed"] = "Mark failed",
    ["Mail observations"] = "Mail observations",
    ["Vendor observations"] = "Vendor observations",
    ["No mailbox data observed."] = "No mailbox data observed.",
    ["No merchant observations."] = "No merchant observations.",

    ["Minimum profit"] = "Minimum profit",
    ["Minimum ROI"] = "Minimum ROI",
    ["Maximum investment per purchase"] = "Maximum investment per purchase",
    ["Session budget"] = "Session budget",
    ["Quote freshness"] = "Quote freshness",
    ["History retention"] = "History retention",
    ["Sound alerts"] = "Sound alerts",
    ["Allow sound alerts after a scan"] = "Allow sound alerts after a scan",
    ["Disenchant strategy"] = "Disenchant strategy",
    ["Require detected Enchanting"] = "Require detected Enchanting",
    ["I can disenchant"] = "I can disenchant",
    ["Grouped view"] = "Grouped view",
    ["Debug logging"] = "Debug logging",
    ["Experimental native scan"] = "Experimental native scan",
    ["Commodity direct purchase"] = "Commodity direct purchase",
    ["Show flip tooltip"] = "Show flip tooltip",
    ["Show flip context menu"] = "Show flip context menu",
    ["Tooltip toggle"] = "Tooltip toggle",
    ["Enable tooltip"] = "Enable tooltip",
    ["Disable tooltip"] = "Disable tooltip",
    ["Toggle tooltip"] = "Toggle tooltip",
    ["Open AH scan for item"] = "Open AH scan for item",
    ["Copy item link"] = "Copy item link",
    ["No item link available"] = "No item link available",
    ["No opportunity selected"] = "No opportunity selected",
    ["Context menu disabled in settings"] = "Context menu disabled in settings",
    ["Tooltip: Vendor flip"] = "Tooltip: Vendor flip",
    ["Tooltip: Disenchant estimate"] = "Tooltip: Disenchant estimate",
    ["Expected materials"] = "Expected materials",
    ["Avg value"] = "Avg value",
    ["Quote fresh"] = "Quote fresh",
    ["Quote stale"] = "Quote stale",
    ["Market house override"] = "Market house override",
    ["Automatic"] = "Automatic",
    ["Blacklist"] = "Blacklist",
    ["Add item from selected row"] = "Add item from selected row",
    ["Reset all data"] = "Reset all data",
    ["Reset all GoblinFlip data? This cannot be undone."] = "Reset all GoblinFlip data? This cannot be undone.",
    ["Export saved data"] = "Export saved data",
    ["Copy the text below."] = "Copy the text below.",
    ["Settings saved."] = "Settings saved.",
    ["Invalid value."] = "Invalid value.",

    ["Diagnostics"] = "Diagnostics",
    ["Client"] = "Client",
    ["Build"] = "Build",
    ["Interface"] = "Interface",
    ["Dependencies"] = "Dependencies",
    ["Auctionator"] = "Auctionator",
    ["Auctionator scan contract"] = "Auctionator scan contract",
    ["DisenchantBuddy"] = "DisenchantBuddy",
    ["LibAHTab"] = "LibAHTab",
    ["Auction house APIs"] = "Auction house APIs",
    ["Saved variables"] = "Saved variables",
    ["Supported"] = "Supported",
    ["Not supported"] = "Not supported",
    ["Missing"] = "Missing",
    ["Available"] = "Available",
    ["Unverified"] = "Unverified",

    ["Use /gf help for commands."] = "Use /gf help for commands.",
    ["Unknown command"] = "Unknown command",
    ["No auction house is open."] = "No auction house is open.",
    ["Open the auction house first."] = "Open the auction house first.",
    ["This client does not expose the modern auction house APIs."] = "This client does not expose the modern auction house APIs.",
    ["Auctionator is missing. GoblinFlip needs Auctionator for full scans."] = "Auctionator is missing. GoblinFlip needs Auctionator for full scans.",
    ["GoblinFlip is ready."] = "GoblinFlip is ready.",
    ["Session budget reset."] = "Session budget reset.",
    ["Filters reset."] = "Filters reset.",
    ["Data reset."] = "Data reset.",
    ["No opportunities detected in this scan."] = "No opportunities detected in this scan.",
    ["New opportunity"] = "New opportunity",
    ["new opportunities"] = "new opportunities",
}

local deDE = {
    ["Vendor Flips"] = "Händler-Flips",
    ["Disenchant"] = "Entzaubern",
    ["History"] = "Verlauf",
    ["Ledger"] = "Kassenbuch",
    ["Settings"] = "Einstellungen",
    ["Scan"] = "Scannen",
    ["Buy"] = "Kaufen",
    ["Confirm"] = "Bestätigen",
    ["Cancel"] = "Abbrechen",
    ["Profit"] = "Gewinn",
    ["ROI"] = "Rendite",
    ["Item"] = "Gegenstand",
    ["Qty"] = "Menge",
    ["Buyout"] = "Sofortkauf",
    ["Vendor"] = "Händler",
    ["Expected"] = "Erwartet",
    ["Status"] = "Status",
    ["Market"] = "Markt",
    ["Horde"] = "Horde",
    ["Alliance"] = "Allianz",
    ["Neutral / Blackwater"] = "Neutral / Blackwater",
    ["Search"] = "Suchen",
    ["Min profit"] = "Min. Gewinn",
    ["Min ROI"] = "Min. Rendite",
    ["Max buy"] = "Max. Kauf",
    ["Session budget"] = "Sitzungsbudget",
    ["Remaining budget"] = "Restbudget",
    ["Session spent"] = "Sitzungsausgaben",
    ["No profitable vendor flips found."] = "Keine profitablen Händler-Flips gefunden.",
    ["Purchase confirmed."] = "Kauf bestätigt.",
    ["Purchase submitted."] = "Kauf übermittelt.",
    ["Purchase failed."] = "Kauf fehlgeschlagen.",
    ["Open Auctionator's Buy tab and click Get All."] = "Öffne Auctionators Kaufen-Tab und klicke auf Alles abrufen.",
    ["Enchanting skill was not detected."] = "Entzauberkunst wurde nicht erkannt. Aktiviere die manuelle Ausnahme in den Einstellungen, wenn du entzaubern kannst.",
    ["DisenchantBuddy is not installed or its API is unavailable."] = "DisenchantBuddy ist nicht installiert oder seine API ist nicht verfügbar.",
}

local strings = enUS
if locale == "deDE" then
    strings = {}
    for key, value in pairs(enUS) do
        strings[key] = value
    end
    for key, value in pairs(deDE) do
        strings[key] = value
    end
end

GF.L = setmetatable({}, {
    __index = function(_, key)
        return strings[key] or key
    end,
})

function GF.L.Format(key, ...)
    local template = GF.L[key]
    if select("#", ...) == 0 then
        return template
    end
    local ok, formatted = pcall(string.format, template, ...)
    if ok then
        return formatted
    end
    return template
end
