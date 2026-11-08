-- Kindle: the settings window (/kindle). Also listed in the game's AddOns options with a button that opens it.

local _, Kindle = ...

local Settings_ = {}
Kindle.Settings = Settings_

-- Two columns: the bar and its look on the left; camp advice, reminders and group on the right.
local WIDTH, COL_GAP = 780, 28
local COL = (WIDTH - 36 - COL_GAP) / 2
local window, left, right

local function db() return Kindle.db end

local function Refresh()
    if left then left:Refresh(); right:Refresh() end
end

local function Apply()
    Kindle.UI.ApplySettings()
    Refresh()
end

local function Build()
    local W, Theme, D = Kindle.Widgets, Kindle.Theme, Kindle.Data
    window = W.Window("KindleSettings", "Kindle", WIDTH)
    local inner = COL
    local leftCol = CreateFrame("Frame", nil, window.content)
    leftCol:SetPoint("TOPLEFT")
    leftCol:SetSize(COL, 10)
    local rightCol = CreateFrame("Frame", nil, window.content)
    rightCol:SetPoint("TOPRIGHT")
    rightCol:SetSize(COL, 10)
    left, right = W.Stack(leftCol), W.Stack(rightCol)

    -- Left column ---------------------------------------------------------
    local c, stack = leftCol, left

    -- Bar
    stack:Add(W.Header(c, "Bar"), 22, 0)
    stack:Add(W.Checkbox(c, "Show the bar",
        function() return db().shown end,
        function(v) db().shown = v; Apply() end), 22)
    stack:Add(W.Checkbox(c, "Lock the bar",
        function() return db().locked end,
        function(v) db().locked = v; Apply() end,
        "Unlocked, the bar shows a background and title so you can drag it."), 22, 4)
    stack:Add(W.Checkbox(c, "Background behind the buttons",
        function() return db().barBackground end,
        function(v) db().barBackground = v; Apply() end), 22, 4)
    stack:Add(W.Slider(c, "Button size", 24, 72, 2,
        function() return db().buttonSize end,
        function(v) db().buttonSize = v; Apply() end,
        function(v) return v .. " px" end), 40, 10)
    local choice, h = W.Choice(c, "Campfire button when you have no kit and can't craft one",
        { { value = "grey", text = "Grey it out" }, { value = "hide", text = "Hide it" } }, inner,
        function() return db().noKitMode end,
        function(v) db().noKitMode = v; Apply() end)
    stack:Add(choice, h, 10)

    -- Look
    stack:Add(W.Header(c, "Look"), 22, 18)
    local themes = { { value = false, text = "Auto",
        tip = "NaowhUI or EllesmereUI when installed, else the normal WoW look." } }
    for _, t in ipairs(Theme.list) do
        themes[#themes + 1] = {
            value = t.key, text = t.name,
            disabled = t.available and function() return not t.available() end,
            tip = t.needs and ("Needs " .. t.needs .. " installed and enabled.") or nil,
        }
    end
    choice, h = W.Choice(c, "Theme", themes, inner,
        function() return db().theme or false end,
        function(v) db().theme = v or nil; Apply() end)
    stack:Add(choice, h, 10)

    -- Right column --------------------------------------------------------
    c, stack = rightCol, right

    -- Camp advice
    stack:Add(W.Header(c, "Camp advice"), 22, 0)
    stack:Add(W.Checkbox(c, "Rate camps for me under the bar",
        function() return db().showAdvice end,
        function(v) db().showAdvice = v; Kindle.UI.RefreshAuras() end,
        "At a camp, compares its bonuses with yours. Hover the camp's objects so Kindle knows what it has."), 22)
    local _, class = UnitClass("player")
    local classRole = D.roles[D.classRole[class or ""] or "melee"].name
    local roles = { { value = false, text = "From class (" .. classRole .. ")",
        tip = "Your class's usual role. Hybrids (druid, shaman, paladin) may want to pick one." } }
    for _, key in ipairs({ "melee", "ranged", "caster", "healer", "tank" }) do
        roles[#roles + 1] = { value = key, text = (key:gsub("^%l", string.upper)) }
    end
    choice, h = W.Choice(c, "Rate camps for", roles, inner,
        function() return db().role or false end,
        function(v) db().role = v or nil; Kindle.UI.RefreshAuras() end)
    stack:Add(choice, h, 10)

    -- Reminders
    stack:Add(W.Header(c, "Reminders"), 22, 18)
    choice, h = W.Choice(c, "Warn before your camp bonuses run out",
        { { value = 0, text = "Off" }, { value = 2, text = "2 min" }, { value = 5, text = "5 min" },
          { value = 10, text = "10 min" } }, inner,
        function() return db().expiryWarning end,
        function(v) db().expiryWarning = v; Kindle.Alerts.Schedule() end)
    stack:Add(choice, h, 8)
    local sounds = {}
    for _, s in ipairs(Kindle.Alerts.sounds) do
        sounds[#sounds + 1] = { value = s.key, text = s.name, tip = s.id and "Click to hear it." or nil }
    end
    choice, h = W.Choice(c, "Warning sound", sounds, inner,
        function() return db().expirySound end,
        function(v) db().expirySound = v; Kindle.Alerts.PlaySound(v) end)
    stack:Add(choice, h, 10)
    stack:Add(W.Checkbox(c, "Make Sit glow when sitting would help",
        function() return db().sitGlow end,
        function(v) db().sitGlow = v; Kindle.UI.RefreshAuras() end,
        "At a camp: when you have no camp bonuses, or this camp is better for you than yours."), 22, 10)

    -- Group
    stack:Add(W.Header(c, "Group"), 22, 18)
    stack:Add(W.Checkbox(c, "Share camp info with my party or raid",
        function() return db().share end,
        function(v) db().share = v end,
        "Groupmates with Kindle at the same camp see what it has without hovering every object. "
        .. "Uses hidden addon messages, never chat. Not in instances."), 22)

    -- Footer, across both columns, under the taller one.
    local columns = math.max(left.y, right.y)
    local footer = CreateFrame("Frame", nil, window.content)
    footer:SetHeight(26)
    footer:SetPoint("TOPLEFT", 0, -(columns + 22))
    footer:SetPoint("RIGHT")
    local reset = W.Button(footer, "Reset position", 130, function() Kindle.UI.ResetPosition() end)
    reset:SetPoint("LEFT")
    local welcome = W.Button(footer, "Welcome guide", 130, function() Kindle.Welcome.Show() end)
    welcome:SetPoint("LEFT", reset, "RIGHT", 8, 0)
    local close = W.Button(footer, "Close", 90, function() window:Hide() end)
    close:SetPoint("RIGHT")

    window:SetHeight(columns + 22 + 26 + 46 + 18)
    window:SetScript("OnShow", Refresh)
end

function Settings_.Show()
    if not window then Build() end
    window:Show()
    window:Raise()
end

function Settings_.Toggle()
    if window and window:IsShown() then window:Hide() else Settings_.Show() end
end

-- A page in the game's options (Esc > Options > AddOns) that opens Kindle's own window.
function Settings_.RegisterBlizzard()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Kindle")
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetText("Kindle has its own settings window. You can also open it with /kindle.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    open:SetText("Open Kindle settings")
    -- Kindle's window opens on top. Closing the game's options panel from addon code could taint it, so we don't.
    open:SetScript("OnClick", function() Settings_.Show() end)
    pcall(function()
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Kindle")
        Settings.RegisterAddOnCategory(category)
    end)
end
