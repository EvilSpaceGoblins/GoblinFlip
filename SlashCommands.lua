-- Slash command handler for GoblinFlip.

local _, GF = ...

GF.SlashCommands = {}

local Slash = GF.SlashCommands

local COMMANDS = {
    scan = {
        func = function()
            if GF.App and GF.App.RequestScan then
                local ok, reason = GF.App:RequestScan()
                if not ok then
                    print("|cffff0000" .. GF.L["Scan failed: "] .. tostring(reason) .. "|r")
                end
            end
        end,
        help = GF.L["Start a new auction house scan"],
    },
    help = {
        func = function()
            print("|cffFFD700GoblinFlip Commands:|r")
            print("  /gf scan        - " .. GF.L["Start a new scan"])
            print("  /gf help        - " .. GF.L["Show this help"])
            print("  /gf settings    - " .. GF.L["Open settings panel"])
            print("  /gf budget      - " .. GF.L["Reset session budget"])
            print("  /gf reset       - " .. GF.L["Reset all data (DANGEROUS)"])
            print("  /gf standalone  - " .. GF.L["Toggle standalone window"])
            print("  /gf diagnostics - " .. GF.L["Print diagnostics"])
        end,
        help = GF.L["Show help"],
    },
    settings = {
        func = function()
            if GF.UI and GF.UI.Options and GF.UI.Options.GetFrame then
                local frame = GF.UI.Options.GetFrame()
                if frame then frame:Show() end
            end
        end,
        help = GF.L["Open settings panel"],
    },
    budget = {
        func = function()
            if GF.App and GF.App.ResetSessionBudget then
                GF.App:ResetSessionBudget()
                print("|cff00ff00" .. GF.L["Session budget reset"] .. "|r")
            end
        end,
        help = GF.L["Reset session budget"],
    },
    reset = {
        func = function()
            StaticPopup_Show("GOBLINFLIP_RESET_ALL")
        end,
        help = GF.L["Reset all GoblinFlip data (irreversible)"],
    },
    standalone = {
        func = function()
            if GF.UI and GF.UI.Standalone then
                GF.UI.Standalone.Toggle()
            end
        end,
        help = GF.L["Toggle standalone window"],
    },
    diagnostics = {
        func = function()
            if GF.App and GF.App.PrintDiagnostics then
                GF.App:PrintDiagnostics()
            end
        end,
        help = GF.L["Print diagnostic information"],
    },
    de = {
        func = function()
            local status = GF.App and GF.App.GetDisenchantStatus and GF.App:GetDisenchantStatus()
            if status then
                print("|cffFFD700Disenchant Status:|r")
                print("  Available: " .. tostring(status.available))
                print("  Provider: " .. tostring(status.provider))
                print("  Standalone: " .. tostring(status.standaloneMode))
                if status.skill then
                    print("  Skill Verified: " .. tostring(status.skill.verified))
                    print("  Evidence: " .. tostring(status.skill.evidence))
                end
            end
        end,
        help = GF.L["Show disenchant status"],
    },
    market = {
        func = function()
            local identity = GF.App and GF.App.identity
            if identity then
                print("|cffFFD700Market:|r")
                print("  Key: " .. tostring(identity.key))
                print("  House: " .. tostring(identity.house))
                print("  Label: " .. tostring(identity.houseLabel))
                print("  Region: " .. tostring(identity.region))
                print("  Realm: " .. tostring(identity.realm))
                print("  Verified: " .. tostring(identity.verified))
            else
                print("|cffff0000Market not detected|r")
            end
        end,
        help = GF.L["Show current market info"],
    },
}

--- Initialize slash commands.
function Slash.Initialize()
    _G.SLASH_GOBLINFLIP1 = "/gf"
    _G.SLASH_GOBLINFLIP2 = "/goblinflip"

    _G.hash_SlashCmdList["GOBLINFLIP"] = function(msg)
        msg = msg and msg:lower():trim() or ""
        local cmd, args = msg:match("^(%S+)%s*(.*)$")
        cmd = cmd or "help"

        local handler = COMMANDS[cmd]
        if handler and handler.func then
            handler.func(args)
        else
            print("|cffff0000Unknown command:|r " .. cmd)
            COMMANDS.help.func()
        end
    end

    -- Register reset confirmation popup
    StaticPopupDialogs["GOBLINFLIP_RESET_ALL"] = {
        text = GF.L["Reset all GoblinFlip data? This cannot be undone."],
        button1 = GF.L["Yes"],
        button2 = GF.L["No"],
        OnAccept = function()
            if GF.App and GF.App.ResetAllData then
                GF.App:ResetAllData()
                print("|cff00ff00" .. GF.L["All data reset"] .. "|r")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    print("|cff00ff00GoblinFlip|r slash commands loaded. Type /gf help")
end

--- Get command help text.
---@param cmd string
---@return string|nil
function Slash.GetHelp(cmd)
    local handler = COMMANDS[cmd]
    return handler and handler.help
end

--- List all commands.
---@return table
function Slash.ListCommands()
    local list = {}
    for cmd, handler in pairs(COMMANDS) do
        table.insert(list, { cmd = cmd, help = handler.help })
    end
    table.sort(list, function(a, b) return a.cmd < b.cmd end)
    return list
end

return Slash