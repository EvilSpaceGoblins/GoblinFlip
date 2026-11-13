-- Localization: German (deDE)
-- Generated for GoblinFlip v0.4

if GetLocale() ~= "deDE" then return end

local _, GF = ...

GF.locale = "deDE"

local deDE = {
    ["GoblinFlip"] = "GoblinFlip",
    ["Every copper counts."] = "Jedes Kupfer zählt.",

    -- Main Tabs
    ["Vendor Flips"] = "Händler-Flips",
    ["Disenchant"] = "Entzaubern",
    ["History"] = "Verlauf",
    ["Ledger"] = "Buchhaltung",
    ["Settings"] = "Einstellungen",
    ["Dashboard"] = "Übersicht",
    ["Scan"] = "Scannen",
    ["Scanning"] = "Scannen...",
    ["Refresh selected"] = "Ausgewählte aktualisieren",
    ["Buy Next"] = "Nächsten kaufen",
    ["Buy"] = "Kaufen",
    ["Confirm"] = "Bestätigen",
    ["Cancel"] = "Abbrechen",
    ["Close"] = "Schließen",
    ["Apply"] = "Anwenden",
    ["Reset"] = "Zurücksetzen",
    ["Reset filters"] = "Filter zurücksetzen",
    ["Reset budget"] = "Budget zurücksetzen",
    ["Export"] = "Exportieren",
    ["Clear"] = "Löschen",
    ["Retry"] = "Wiederholen",
    ["Blacklist"] = "Blacklist",
    ["Blacklisted"] = "Auf Blacklist",
    ["Remove"] = "Entfernen",
    ["Save"] = "Speichern",

    -- Status
    ["Current"] = "Aktuell",
    ["Last scan"] = "Letzter Scan",
    ["Snapshot only until validated."] = "Nur Schnappschuss bis validiert.",
    ["Snapshot"] = "Schnappschuss",
    ["Live"] = "Live",
    ["Stale"] = "Veraltet",
    ["Unavailable"] = "Nicht verfügbar",
    ["Unknown"] = "Unbekannt",
    ["Read-only"] = "Schreibgeschützt",
    ["Estimated"] = "Geschätzt",
    ["Verified"] = "Verifiziert",
    ["Pending"] = "Ausstehend",

    -- Opportunity columns
    ["Opportunities"] = "Gelegenheiten",
    ["Investment"] = "Investition",
    ["Profit"] = "Gewinn",
    ["ROI"] = "ROI",
    ["Quantity"] = "Menge",
    ["Buyout"] = "Sofortkauf",
    ["Item"] = "Gegenstand",
    ["Type"] = "Typ",

    -- Filters
    ["Search"] = "Suche",
    ["Strategy"] = "Strategie",
    ["Min Profit"] = "Min. Gewinn",
    ["Min ROI %"] = "Min. ROI %",
    ["Max Buyout"] = "Max. Sofortkauf",
    ["Quality"] = "Qualität",
    ["Min Quantity"] = "Min. Menge",
    ["Max Quantity"] = "Max. Menge",
    ["Show Owned"] = "Eigene anzeigen",
    ["Grouped view"] = "Gruppierte Ansicht",
    ["Default Sort"] = "Standard-Sortierung",
    ["Default Sort Direction"] = "Sortierrichtung",
    ["minProfit"] = "Min. Gewinn",
    ["minRoi"] = "Min. ROI",
    ["maxBuyout"] = "Max. Sofortkauf",
    ["sessionBudget"] = "Sitzungsbudget",
    ["disenchantEnabled"] = "Entzaubern aktivieren",
    ["requireDisenchantSkill"] = "Entzaubern-Skill voraussetzen",
    ["assumeDisenchantSkill"] = "Entzaubern-Skill annehmen",
    ["marketHouseOverride"] = "Markt-Haus Override",
    ["groupedView"] = "Gruppierte Ansicht",
    ["showOwned"] = "Eigene anzeigen",
    ["experimentalNativeScan"] = "Experimenteller Native-Scan",
    ["allowCommodityPurchase"] = "Waren-Direktkauf erlauben",
    ["quoteFreshness"] = "Zitat-Frische (Sekunden)",
    ["historyDays"] = "Verlauf-Tage",
    ["historySnapshots"] = "Verlauf-Schnappschüsse/Markt",
    ["cooldownHint"] = "Cooldown-Hinweis (Sekunden)",
    ["soundFile"] = "Sound-Datei",
    ["soundAlerts"] = "Sound-Alarme",
    ["alertMinProfit"] = "Alarm Min. Gewinn",
    ["alertMinRoi"] = "Alarm Min. ROI",
    ["showFlipTooltip"] = "Flip-Tooltip anzeigen",
    ["showFlipContextMenu"] = "Flip-Kontextmenü anzeigen",
    ["standaloneMode"] = "Eigenständiger Modus",

    -- Quality
    ["Poor"] = "Schlecht",
    ["Common"] = "Gewöhnlich",
    ["Uncommon"] = "Ungewöhnlich",
    ["Rare"] = "Selten",
    ["Epic"] = "Episch",

    -- Market
    ["Market"] = "Markt",
    ["House"] = "Haus",
    ["Region"] = "Region",
    ["Realm"] = "Realm",
    ["Automatic"] = "Automatisch",
    ["Horde"] = "Horde",
    ["Alliance"] = "Allianz",
    ["Neutral (Blackwater)"] = "Neutral (Schwarzmeerküste)",

    -- Scan states
    ["IDLE"] = "BEREIT",
    ["REQUESTED"] = "ANGEFORDERT",
    ["RECEIVING"] = "EMPFANGE",
    ["NORMALIZING"] = "NORMALISIERE",
    ["RESOLVING_ITEMS"] = "ARTIKEL AUFLÖSEN",
    ["READY"] = "BEREIT",
    ["COOLDOWN"] = "ABKLINGZEIT",
    ["ERROR"] = "FEHLER",
    ["CANCELLED"] = "ABBROCHEN",
    ["PARTIAL"] = "TEILWEISE",

    -- Ledger status
    ["Submitted"] = "Abgeschickt",
    ["Confirmed"] = "Bestätigt",
    ["Awaiting Mail"] = "Warte auf Post",
    ["Partially Received"] = "Teilweise erhalten",
    ["Received"] = "Erhalten",
    ["Partially Disposed"] = "Teilweise verwertet",
    ["Disposed"] = "Verwertet",
    ["Failed"] = "Fehlgeschlagen",
    ["Cancelled"] = "Abgebrochen",
    ["Uncertain"] = "Unsicher",
    ["Manual"] = "Manuell",

    -- Buttons / Actions
    ["Scan"] = "Scannen",
    ["Refresh Selected"] = "Ausgewählte aktualisieren",
    ["Buy Next"] = "Nächsten kaufen",
    ["Mark Received"] = "Als erhalten markieren",
    ["Add Proceeds"] = "Erlöse hinzufügen",
    ["Mark Uncertain"] = "Als unsicher markieren",
    ["Add Manual Entry"] = "Manuellen Eintrag hinzufügen",
    ["View Snapshot"] = "Schnappschuss anzeigen",
    ["Clear View"] = "Ansicht löschen",
    ["Reset"] = "Zurücksetzen",
    ["Reset all data"] = "Alle Daten zurücksetzen",
    ["Reset session budget"] = "Sitzungsbudget zurücksetzen",
    ["Print Diagnostics"] = "Diagnose ausgeben",

    -- Ledger Summary
    ["Transactions"] = "Transaktionen",
    ["Invested"] = "Investiert",
    ["Proceeds"] = "Erlöse",
    ["Realized Profit"] = "Realisierter Gewinn",
    ["Pending"] = "Ausstehend",

    -- Tooltip
    ["Tooltip: Vendor flip"] = "Tooltip: Händler-Flip",
    ["Tooltip: Disenchant estimate"] = "Tooltip: Entzauber-Schätzung",
    ["Expected materials"] = "Erwartete Materialien",
    ["Avg value"] = "Ø Wert",
    ["Gross (pre-fee)"] = "Brutto (vor Gebühr)",
    ["Vendor price"] = "Händlerpreis",
    ["Quote fresh"] = "Zitat frisch",
    ["Quote stale"] = "Zitat veraltet",
    ["Flip"] = "Flip",
    ["No opportunity selected"] = "Keine Gelegenheit ausgewählt",
    ["Context menu disabled in settings"] = "Kontextmenü in Einstellungen deaktiviert",
    ["Open Auction House scan for this item"] = "AH-Scan für diesen Artikel öffnen",
    ["Toggle tooltip"] = "Tooltip umschalten",
    ["Copy item link"] = "Artikellink kopieren",
    ["No item link available"] = "Kein Artikellink verfügbar",
    ["Enable tooltip"] = "Tooltip aktivieren",
    ["Disable tooltip"] = "Tooltip deaktivieren",
    ["Tooltip toggle"] = "Tooltip umschalten",

    -- Context Menu
    ["Open AH scan for item"] = "AH-Scan für Item öffnen",
    ["Copy item link"] = "Artikellink kopieren",
    ["No opportunity selected"] = "Keine Gelegenheit ausgewählt",
    ["Context menu disabled in settings"] = "Kontextmenü in Einstellungen deaktiviert",

    -- Settings Tabs
    ["General"] = "Allgemein",
    ["Scanning"] = "Scannen",
    ["Alerts"] = "Alarme",
    ["Advanced"] = "Erweitert",

    -- Standalone
    ["GoblinFlip"] = "GoblinFlip",

    -- Slash Commands
    ["Start a new scan"] = "Neuen Scan starten",
    ["Show all commands"] = "Alle Befehle anzeigen",
    ["Open settings panel"] = "Einstellungen öffnen",
    ["Reset session budget"] = "Sitzungsbudget zurücksetzen",
    ["Reset all data (irreversible)"] = "Alle Daten zurücksetzen (unwiderruflich)",
    ["Toggle standalone window"] = "Eigenständiges Fenster umschalten",
    ["Print diagnostic information"] = "Diagnoseinformationen ausgeben",
    ["Show disenchant status"] = "Entzauber-Status anzeigen",
    ["Show current market info"] = "Aktuelle Marktinfos anzeigen",

    -- General Settings
    ["Session Budget"] = "Sitzungsbudget",
    ["Max Buyout per Purchase"] = "Max. Sofortkauf pro Kauf",
    ["Quote Freshness (seconds)"] = "Zitat-Frische (Sekunden)",
    ["Allow Commodity Direct Purchase"] = "Waren-Direktkauf erlauben",
    ["Standalone Mode (Zero Dependencies)"] = "Eigenständiger Modus (null Abhängigkeiten)",
    ["Use native scan and internal DE data. No Auctionator or DisenchantBuddy required."] = "Native Scan und interne DE-Daten nutzen. Kein Auctionator oder DisenchantBuddy nötig.",
    ["Tooltip Integration"] = "Tooltip-Integration",
    ["Show Flip Tooltip"] = "Flip-Tooltip anzeigen",
    ["Show GoblinFlip info on item tooltips (vendor price, DE estimate)"] = "GoblinFlip-Info in Item-Tooltips anzeigen (Händlerpreis, DE-Schätzung)",
    ["Show Flip Context Menu"] = "Flip-Kontextmenü anzeigen",
    ["Right-click opportunities for context menu"] = "Rechtsklick auf Gelegenheiten für Kontextmenü",
    ["Debug Logging"] = "Debug-Logging",
    ["Enable debug output to chat"] = "Debug-Ausgabe im Chat aktivieren",

    -- Scanning Settings
    ["Scan Provider"] = "Scan-Anbieter",
    ["Auctionator (Fast)"] = "Auctionator (Schnell)",
    ["Native Replicate (Standalone)"] = "Native Replikation (Eigenständig)",
    ["Enable Native Scan (Experimental)"] = "Nativen Scan aktivieren (Experimentell)",
    ["Allow native replicate scan without Auctionator"] = "Nativen Replikations-Scan ohne Auctionator erlauben",
    ["Market House Override"] = "Markt-Haus Override",
    ["Disenchant Settings"] = "Entzauber-Einstellungen",
    ["Enable Disenchant Estimates"] = "Entzauber-Schätzungen aktivieren",
    ["Show disenchant flip opportunities"] = "Entzauber-Flip-Gelegenheiten anzeigen",
    ["Require Enchanting Skill"] = "Verzauberkunst-Skill voraussetzen",
    ["Only show DE flips if you have Enchanting profession"] = "Nur DE-Flips anzeigen, wenn du Verzauberkunst hast",
    ["Assume I Can Disenchant"] = "Annehmen, ich kann entzaubern",
    ["Override skill check - show all DE flips"] = "Skill-Prüfung überschreiben - alle DE-Flips anzeigen",
    ["History Retention"] = "Verlaufs-Aufbewahrung",
    ["Days"] = "Tage",
    ["Snapshots/Market"] = "Schnappschüsse/Markt",

    -- Alerts Settings
    ["Sound Alerts"] = "Sound-Alarme",
    ["Enable Sound Alerts"] = "Sound-Alarme aktivieren",
    ["Play sound when new opportunities found"] = "Sound abspielen, wenn neue Gelegenheiten gefunden werden",
    ["Sound File"] = "Sound-Datei",
    ["Test Sound"] = "Sound testen",
    ["Alert Thresholds"] = "Alarm-Schwellenwerte",
    ["Min Profit"] = "Min. Gewinn",
    ["Min ROI %"] = "Min. ROI %",

    -- Advanced Settings
    ["Grouped View"] = "Gruppierte Ansicht",
    ["Group similar items together"] = "Ähnliche Items gruppieren",
    ["Default Sort"] = "Standard-Sortierung",
    ["Profit"] = "Gewinn",
    ["ROI"] = "ROI",
    ["Buyout"] = "Sofortkauf",
    ["Quantity"] = "Menge",
    ["Sort Direction"] = "Sortierrichtung",
    ["Descending"] = "Absteigend",
    ["Ascending"] = "Aufsteigend",
    ["Show Owned Listings"] = "Eigene Auktionen anzeigen",
    ["Include items you have listed on AH"] = "Eigene AH-Auktionen einbeziehen",
    ["Quality Filter"] = "Qualitätsfilter",
    ["Min Qty"] = "Min. Menge",
    ["Max Qty"] = "Max. Menge",
    ["Print Diagnostics"] = "Diagnose ausgeben",

    -- Scan States (for display)
    ["Scan"] = "Scan",
    ["Scanning"] = "Scannen...",

    -- Market
    ["Market unknown - select override in Settings"] = "Markt unbekannt - Override in Einstellungen wählen",
    ["Other market history is read-only"] = "Andere Markt-Historien sind schreibgeschützt",
    ["Auctionator is missing. GoblinFlip needs Auctionator for full scans."] = "Auctionator fehlt. GoblinFlip braucht Auctionator für Komplettscans.",
    ["This client does not expose the modern auction house APIs."] = "Dieser Client stellt die modernen AH-APIs nicht bereit.",
    ["GoblinFlip is ready."] = "GoblinFlip ist bereit.",

    -- Messages
    ["No opportunities detected in this scan."] = "Keine Gelegenheiten in diesem Scan erkannt.",
    ["New opportunity"] = "Neue Gelegenheit",
    ["new opportunities"] = "neue Gelegenheiten",
    ["Scan complete: %d vendor flips, %d disenchant estimates."] = "Scan abgeschlossen: %d Händler-Flips, %d Entzauber-Schätzungen.",
    ["Purchase submitted."] = "Kauf abgeschickt.",
    ["Purchase confirmed."] = "Kauf bestätigt.",
    ["Purchase failed."] = "Kauf fehlgeschlagen.",
    ["Purchase outcome is uncertain."] = "Kaufergebnis ist ungewiss.",
    ["Quote expired."] = "Zitat abgelaufen.",
    ["Not enough gold."] = "Nicht genug Gold.",
    ["Session budget exceeded."] = "Sitzungsbudget überschritten.",
    ["Per-purchase limit exceeded."] = "Pro-Kauf-Limit überschritten.",
    ["Commodity direct purchase is disabled in this build."] = "Waren-Direktkauf in diesem Build deaktiviert.",
    ["Own listing."] = "Eigene Auktion.",
    ["Not profitable at the live price."] = "Bei Live-Preis nicht profitabel.",
    ["No live offers matched this item."] = "Keine Live-Angebote passten zu diesem Item.",
    ["Purchase outcome is uncertain."] = "Kaufergebnis ist ungewiss.",
    ["New opportunity: %s (%s)"] = "Neue Gelegenheit: %s (%s)",
    ["No transaction selected"] = "Keine Transaktion ausgewählt",
    ["Not yet implemented"] = "Noch nicht implementiert",
    ["All data reset"] = "Alle Daten zurückgesetzt",
    ["Session budget reset"] = "Sitzungsbudget zurückgesetzt",
    ["Purchase outcome is uncertain."] = "Kaufergebnis ist ungewiss.",
    ["Every copper counts."] = "Jedes Kupfer zählt.",

    -- Minimap
    ["Open Window"] = "Fenster öffnen",
    ["Scan"] = "Scannen",
    ["Ledger"] = "Buchhaltung",
    ["History"] = "Verlauf",
    ["Settings"] = "Einstellungen",
    ["Standalone Mode"] = "Eigenständiger Modus",
    ["Minimap Icon"] = "Minikarten-Symbol",
    ["Lock Position"] = "Position sperren",
    ["Help"] = "Hilfe",
    ["Close"] = "Schließen",
    ["Toggle tooltip"] = "Tooltip umschalten",
    ["Copy item link"] = "Artikellink kopieren",
    ["No item link available"] = "Kein Artikellink verfügbar",

    -- Misc
    ["Reset all GoblinFlip data? This cannot be undone."] = "Alle GoblinFlip-Daten zurücksetzen? Nicht rückgängig machbar.",
    ["Export saved data"] = "Gespeicherte Daten exportieren",
    ["Add item from selected row"] = "Artikel aus gewählter Reihe hinzufügen",
    ["Blacklist"] = "Blacklist",
    ["Blacklisted"] = "Auf Blacklist",
    ["Add item from selected row"] = "Artikel aus gewählter Reihe hinzufügen",
}

-- Apply translations
for key, value in pairs(deDE) do
    if GF.L and GF.L[key] then
        GF.L[key] = value
    end
end

-- Add to GF if not exists
if not GF.L then GF.L = {} end
for key, value in pairs(deDE) do
    GF.L[key] = value
end

return deDE