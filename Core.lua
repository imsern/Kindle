-- Kindle: core (saved variables, events, slash commands).

local ADDON_NAME, Kindle = ...

local DEFAULTS = {
    locked = true, -- new players get a clean bar; the welcome guide says how to unlock and move it
    shown = true,
    -- What to do with the campfire button when the player has neither a kit nor the mats: "hide" or "grey".
    noKitMode = "grey",
    -- How "in camp" is detected: a key of Kindle.Detect.methods.
    detect = "aura",
    point = nil, -- { point, relativePoint, x, y } once the bar has been moved
    role = nil,  -- a key of Kindle.Data.roles for camp advice; nil: from your class
    theme = nil, -- a key of Kindle.Theme.list; nil: auto (NaowhUI, else EllesmereUI, else WoW)
    buttonSize = 40,
    barBackground = true,
    showAdvice = true,
    sitGlow = true,       -- Sit glows when sitting would help
    expiryWarning = 5,    -- minutes before camp bonuses run out to warn; 0: off
    expirySound = "raid", -- a key of Kindle.Alerts.sounds
    share = true,         -- share camp info with your party or raid
    welcomed = false,     -- the welcome guide has been seen
}

-- Not settings: /kindle reset keeps these.
local KEEP = { "recipes", "debugLog", "myTiers", "welcomed", "warnedFor" }

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8c1aKindle|r: " .. tostring(msg))
end
Kindle.Print = Print

local function ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        KindleDB = KindleDB or {}
        ApplyDefaults(KindleDB, DEFAULTS)
        Kindle.db = KindleDB
        Kindle.Recipes.Init()
        Kindle.Advice.Init()
        Kindle.Detect.Init() -- after Advice: it watches the bonus auras Advice indexes
        Kindle.Share.Init()
        Kindle.UI.Init()
        Kindle.Settings.RegisterBlizzard()
        Kindle.Welcome.Init()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local function Help()
    Print("commands:")
    Print("  /kindle - open the settings window")
    Print("  /kindle welcome - show the welcome guide")
    Print("  /kindle lock | unlock - lock or unlock the button bar")
    Print("  /kindle show | hide - show or hide the button bar")
    Print("  /kindle reset - reset position and settings")
    Print("  /kindle nokit hide | grey - campfire button when you have no kit and can't craft one")
    Print("  /kindle detect [method] - how Kindle knows you're in camp (no method: list them)")
    Print("  /kindle role melee | ranged | caster | healer | tank | auto - what camp advice rates for")
    Print("  /kindle debug - tools to find item/spell IDs and camp detection (/kindle debug for the list)")
end

SLASH_KINDLE1 = "/kindle"
SlashCmdList.KINDLE = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    local UI = Kindle.UI
    local db = Kindle.db
    -- The bar holds secure buttons, so changes wait for combat to end (UI.ApplySettings queues them).
    local later = InCombatLockdown() and " (after combat)" or ""
    if cmd == "" or cmd == "config" or cmd == "settings" or cmd == "options" then
        Kindle.Settings.Toggle()
    elseif cmd == "welcome" then
        Kindle.Welcome.Show()
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        UI.ApplySettings()
        Print((db.locked and "bar locked." or "bar unlocked.") .. later)
    elseif cmd == "show" or cmd == "hide" then
        db.shown = (cmd == "show")
        UI.ApplySettings()
        Print((db.shown and "bar shown." or "bar hidden.") .. later)
    elseif cmd == "reset" then
        local kept = {}
        for _, k in ipairs(KEEP) do kept[k] = db[k] end
        wipe(db)
        ApplyDefaults(db, DEFAULTS)
        for k, v in pairs(kept) do db[k] = v end
        UI.ResetPosition()
        Print("position and settings reset." .. later)
    elseif cmd == "nokit" and (rest == "hide" or rest == "grey") then
        db.noKitMode = rest
        UI.ApplySettings()
        Print("campfire button with nothing to do: " .. rest .. "." .. later)
    elseif cmd == "detect" then
        local methods = Kindle.Detect.methods
        if methods[rest] then
            db.detect = rest
            Kindle.Detect.Refresh()
            UI.ApplySettings()
            Print("camp detection: " .. methods[rest].desc .. "." .. later)
        else
            Print("camp detection now: " .. tostring(db.detect) .. ". Methods:")
            for name, m in pairs(methods) do Print("  " .. name .. " - " .. m.desc) end
        end
    elseif cmd == "role" then
        rest = strlower(rest)
        if rest == "auto" then
            db.role = nil
        elseif Kindle.Data.roles[rest] then
            db.role = rest
        elseif rest ~= "" then
            Print("unknown role \"" .. rest .. "\". Use melee, ranged, caster, healer, tank or auto.")
            return
        end
        Print("camp advice rates for " .. Kindle.Advice.Role() .. (db.role and "." or " (from your class)."))
        UI.RefreshAuras()
    elseif cmd == "debug" then
        Kindle.Debug.Run(rest)
    else
        Help()
    end
end
