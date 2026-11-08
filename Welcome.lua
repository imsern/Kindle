-- Kindle: the welcome guide. Opens once on your first login with Kindle, and any time from the settings window or
-- /kindle welcome.

local _, Kindle = ...

local Welcome = {}
Kindle.Welcome = Welcome

local WIDTH = 540
local window

local SECTIONS = {
    { "What Kindle does",
        "Kindle puts the camping buttons you need right now on one small bar, and hides the rest." },
    { "Away from a campfire",
        "The |cffffd100Campfire|r button places your best campfire kit, or crafts one if you know the recipe and "
        .. "have the materials. Once you have camp bonuses, the bar stays out of your way until you reach a "
        .. "campfire again." },
    { "At a campfire",
        "You get a button for each profession's camp object: the highest tier you can use. It places the object "
        .. "if it's in your bags, or crafts it (it opens the profession window for that). Hover a button to see the "
        .. "bonus and any missing materials. A green check means that bonus is on you.\n"
        .. "|cffffd100Sit|r sits you down by the fire. Stay seated for 60 seconds to get the camp's bonuses." },
    { "Is this camp better for you?",
        "Sitting at a camp replaces your bonuses with that camp's; they don't stack. Hover the camp's objects and "
        .. "Kindle rates the camp for your role under the bar: |cff66ff66better|r, |cffff6666worse|r or the same "
        .. "as what you have. Higher tiers give more of the same stat, so a tier II of your bonus is an upgrade. "
        .. "Stats are coloured by how much they matter to you, from green to grey." },
    { "Good to know",
        "Open each of your professions once so Kindle learns your camp recipes. Unlock the bar in the settings to "
        .. "move it. Kindle can't change its buttons in combat; it catches up when combat ends.\n"
        .. "Type |cffffd100/kindle|r any time for the settings: role, button size, theme and more." },
}

local function Build()
    local W = Kindle.Widgets
    window = W.Window("KindleWelcome", "Welcome to Kindle", WIDTH)
    local c = window.content
    local inner = WIDTH - 36
    local stack = W.Stack(c)

    for i, s in ipairs(SECTIONS) do
        stack:Add(W.Header(c, s[1]), 22, i == 1 and 0 or 14)
        local p, h = W.Paragraph(c, s[2], inner)
        stack:Add(p, h, 6)
    end

    local footer = CreateFrame("Frame", nil, c)
    footer:SetHeight(26)
    local settings = W.Button(footer, "Open settings", 140, function()
        window:Hide()
        Kindle.Settings.Show()
    end)
    settings:SetPoint("LEFT")
    local done = W.Button(footer, "Let's camp", 120, function() window:Hide() end)
    done:SetPoint("RIGHT")
    stack:Add(footer, 26, 20)

    window:SetHeight(stack.y + 46 + 18)
    window:SetScript("OnHide", function() Kindle.db.welcomed = true end)
end

function Welcome.Show()
    if not window then Build() end
    window:Show()
    window:Raise()
end

-- First login with Kindle: show the guide once things have loaded.
function Welcome.Init()
    if Kindle.db.welcomed then return end
    C_Timer.After(3, function()
        if not Kindle.db.welcomed then Welcome.Show() end
    end)
end
