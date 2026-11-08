-- Kindle: core (saved variables, events, slash commands).

local ADDON_NAME, Kindle = ...

local DEFAULTS = {
    locked = false,
    shown = true,
    -- What to do with the campfire button when the player has neither a kit nor the mats: "hide" or "grey".
    noKitMode = "grey",
    point = nil, -- { point, relativePoint, x, y } once the bar has been moved
}

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
        if Kindle.UI and Kindle.UI.Init then
            Kindle.UI.Init()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local function Help()
    Print("commands:")
    Print("  /kindle lock | unlock - lock or unlock the button bar")
    Print("  /kindle show | hide - show or hide the button bar")
    Print("  /kindle reset - reset position and settings")
    Print("  /kindle debug - tools to find item/spell IDs and camp detection (/kindle debug for the list)")
end

SLASH_KINDLE1 = "/kindle"
SlashCmdList.KINDLE = function(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    local UI = Kindle.UI
    if cmd == "lock" or cmd == "unlock" then
        Kindle.db.locked = (cmd == "lock")
        if UI and UI.ApplySettings then UI.ApplySettings() end
        Print(Kindle.db.locked and "bar locked." or "bar unlocked.")
    elseif cmd == "show" or cmd == "hide" then
        Kindle.db.shown = (cmd == "show")
        if UI and UI.ApplySettings then UI.ApplySettings() end
        Print(Kindle.db.shown and "bar shown." or "bar hidden.")
    elseif cmd == "reset" then
        wipe(Kindle.db)
        ApplyDefaults(Kindle.db, DEFAULTS)
        if UI and UI.ResetPosition then UI.ResetPosition() end
        if UI and UI.ApplySettings then UI.ApplySettings() end
        Print("position and settings reset.")
    elseif cmd == "debug" then
        Kindle.Debug.Run(rest)
    else
        Help()
    end
end
