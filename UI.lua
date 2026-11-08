-- Kindle: the button bar.
--
-- What shows depends on Detect.State():
--   "camp"   (a campfire in range): one button per camp object line you have (a known recipe or an item in your
--            bags) for the highest tier: place it, or craft it. A green check means its bonus is on you. Then Sit:
--            /sit, with a 60s swipe while Welcoming Campfire runs.
--   "nofire" (no fire, no camp bonuses): the Campfire button. Places the best kit in your bags, or crafts the best
--            kit you can make; with neither it's greyed or hidden (/kindle nokit).
--   "done"   (camp bonuses up, no fire): nothing; the bar hides.
-- Under the bar a status line shows the camp state and how long your camp bonuses last, and in camp a second line
-- rates the camp for your class (Advice.lua).
--
-- Every button is a SecureActionButtonTemplate. "Place" is type="item"; "sit" is type="macro". Crafting on Forever
-- can't be cast as a spell (/cast does nothing), so "craft" leaves the secure type empty and the click runs
-- C_TradeSkillUI.OpenRecipe / CraftRecipe, which other Forever addons call from normal code.
--
-- Secure frames can't be shown, hidden, moved or have attributes changed in combat. UI.Update only runs out of
-- combat; in combat it marks the bar dirty and PLAYER_REGEN_ENABLED catches up. Textures, text and cooldown swipes
-- aren't protected, so UI.RefreshAuras may run any time.

local _, Kindle = ...

local UI = {}
Kindle.UI = UI

local QUESTION_MARK = 134400
local SLOT = "Interface\\Buttons\\UI-Quickslot2"

-- Button size comes from the settings (/kindle); gaps and padding grow with it.
local function Size() return Kindle.db.buttonSize or 40 end
local function Gap() return math.max(3, math.floor(Size() / 10)) end

local D
local bar, status, advice, campBtn, sitBtn
local profBtns, lines = {}, {}
local dirty, initialized = false, false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function ItemCount(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    return GetItemCount and GetItemCount(id) or 0
end

local function ItemIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return icon or QUESTION_MARK
end

local function ItemName(id)
    return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
end

local function Known(recipe)
    return recipe ~= nil and IsPlayerSpell ~= nil and IsPlayerSpell(recipe) and true or false
end

local function HasReagents(recipe)
    for _, r in ipairs(Kindle.Recipes.Reagents(recipe)) do
        if ItemCount(r.itemID) < r.need then return false end
    end
    return true
end

-- entries: best first. Returns mode ("place", "craft", "missing", "none") and the entry it applies to.
local function Resolve(entries)
    for _, e in ipairs(entries) do
        if ItemCount(e.item) > 0 then return "place", e end
    end
    local knownButMissing
    for _, e in ipairs(entries) do
        if Known(e.craft) then
            if HasReagents(e.craft) then return "craft", e end
            knownButMissing = knownButMissing or e
        end
    end
    if knownButMissing then return "missing", knownButMissing end
    return "none", entries[#entries]
end

local function FormatTime(seconds)
    local floor = math.floor
    if seconds >= 3600 then return format("%dh %dm", floor(seconds / 3600), floor((seconds % 3600) / 60)) end
    if seconds >= 60 then return format("%dm", floor(seconds / 60)) end
    return format("%ds", floor(seconds))
end

---------------------------------------------------------------------------
-- Crafting
---------------------------------------------------------------------------

local tradeOpen = false
local craft = { recipe = nil, opened = false, deadline = nil }

local function RecipeInOpenProfession(recipe)
    if not tradeOpen then return false end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return false end
    for _, id in ipairs(ids) do
        if id == recipe then return true end
    end
    return false
end

local function DoCraft(recipe)
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, recipe, 1)
    if not ok then Kindle.Print("couldn't craft: " .. tostring(err)) end
end

-- One click: craft right away if the profession is open, else open it on the recipe and craft once it's loaded.
-- If the game only crafts from a click, the window is now open and the next click crafts.
local function StartCraft(e)
    local recipe = e.craft
    if not (recipe and C_TradeSkillUI) then return end
    craft.recipe = recipe
    if RecipeInOpenProfession(recipe) then
        craft.deadline = nil
        DoCraft(recipe)
        return
    end
    if not C_TradeSkillUI.OpenRecipe then
        Kindle.Print("open your profession window, then click again to craft " .. e.name .. ".")
        return
    end
    craft.opened, craft.deadline = true, GetTime() + 5
    C_TradeSkillUI.OpenRecipe(recipe)
end

local function OnTradeSkillReady()
    if craft.deadline and GetTime() <= craft.deadline and RecipeInOpenProfession(craft.recipe) then
        craft.deadline = nil
        local recipe = craft.recipe
        C_Timer.After(0.1, function() DoCraft(recipe) end)
    end
end

local function OnCraftDone(spellID)
    if spellID ~= craft.recipe then return end
    if craft.opened and C_TradeSkillUI.CloseTradeSkill then C_TradeSkillUI.CloseTradeSkill() end
    craft.recipe, craft.opened, craft.deadline = nil, false, nil
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

local function AddReagents(tt, recipe)
    local reagents = Kindle.Recipes.Reagents(recipe)
    if #reagents == 0 then
        tt:AddLine("Materials unknown: open the profession window once.", 0.6, 0.6, 0.6)
        return
    end
    tt:AddLine("Materials:")
    for _, r in ipairs(reagents) do
        local have = ItemCount(r.itemID)
        local enough = have >= r.need
        tt:AddDoubleLine("  " .. (ItemName(r.itemID) or ("item " .. r.itemID)), have .. "/" .. r.need,
            1, 1, 1, enough and 0.3 or 1, enough and 1 or 0.3, 0.3)
    end
end

local function ShowTooltip(b)
    local tt = GameTooltip
    tt:SetOwner(b, "ANCHOR_RIGHT")
    if b == sitBtn then
        tt:SetText("Sit at the campfire", 1, 1, 1)
        tt:AddLine("Stay seated for 60 seconds to get the camp's bonuses.", nil, nil, nil, true)
        if not Kindle.AurasHidden() then Kindle.Advice.AddTooltip(tt) end
        tt:Show()
        return
    end
    local e, mode = b.entry, b.mode
    if not e then return end
    if mode == "place" then
        tt:SetItemByID(e.item)
    else
        tt:SetText(ItemName(e.item) or e.name, 1, 1, 1)
    end
    local line = b.line and D.professions[b.line]
    if line then
        tt:AddLine(format("%s camp object, tier %d", e.profession or b.line, e.tier), 0.8, 0.8, 0.8)
        if line.stat then tt:AddLine("Camp bonus: " .. line.stat, 0.4, 0.8, 1) end
    end
    if mode == "place" then
        tt:AddLine("Click to place it.", 0.3, 1, 0.3)
    elseif mode == "craft" then
        tt:AddLine("Click to craft it (opens the profession window if needed).", 0.3, 1, 0.3, true)
        AddReagents(tt, e.craft)
    elseif mode == "missing" then
        tt:AddLine("Missing materials.", 1, 0.3, 0.3)
        AddReagents(tt, e.craft)
    else
        tt:AddLine("Nothing to place, and no recipe you know.", 1, 0.3, 0.3, true)
    end
    tt:Show()
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local function OnPostClick(b, _, down)
    if down then return end -- the button takes both down and up; act once
    if b.mode == "craft" and not InCombatLockdown() then StartCraft(b.entry) end
end

local function OnDragStart()
    if not Kindle.db.locked and not InCombatLockdown() then bar:StartMoving() end
end

local function OnDragStop()
    bar:StopMovingOrSizing()
    local point, _, relativePoint, x, y = bar:GetPoint()
    Kindle.db.point = { point, relativePoint, x, y }
end

-- Look and size of one button for the current theme. Size changes only out of combat (secure frame).
local function StyleButton(b, p)
    local size = Size()
    if not InCombatLockdown() then b:SetSize(size, size) end
    -- WoW: the action-slot frame around the icon. Flat themes: a 1px border that lights up on hover.
    b.slot:SetShown(not p.flat)
    b.slot:SetSize(size * 64 / 36, size * 64 / 36)
    b.edges:SetShown(p.flat)
    b.edges:SetColor(p.border[1], p.border[2], p.border[3], 1)
    if p.flat then
        b.hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        b.hl:SetVertexColor(1, 1, 1, 0.12)
    else
        b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        b.hl:SetVertexColor(1, 1, 1, 1)
    end
    local inset = p.flat and 1 or 0
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", inset, -inset)
    b.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    Kindle.Theme.Font(b.count, p, math.max(10, math.floor(size * 0.32)), "OUTLINE", { 1, 1, 1 })
    Kindle.Theme.Font(b.label, p, math.max(9, math.floor(size * 0.26)), "OUTLINE")
    local check = math.max(12, math.floor(size * 0.4))
    b.check:SetSize(check, check)
end

local function CreateButton(name)
    local b = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:RegisterForDrag("LeftButton")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.slot = b:CreateTexture(nil, "OVERLAY", nil, -1)
    b.slot:SetTexture(SLOT)
    b.slot:SetPoint("CENTER")
    b.edges = Kindle.Theme.AddEdges(b)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.hl = b:GetHighlightTexture()
    b.hl:SetAllPoints()
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("BOTTOM", 0, 2)
    b.check = b:CreateTexture(nil, "OVERLAY", nil, 7)
    b.check:SetPoint("TOPRIGHT", 3, 3)
    b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    b.check:Hide()
    Kindle.Theme.Register(b, function(p) StyleButton(b, p) end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("PostClick", OnPostClick)
    b:SetScript("OnDragStart", OnDragStart)
    b:SetScript("OnDragStop", OnDragStop)
    b:Hide()
    return b
end

-- Out of combat only. Attributes and textures are only touched when the action changes.
local function SetMode(b, mode, e)
    b.count:SetText(mode == "place" and ItemCount(e.item) or "")
    if b.mode == mode and b.entry == e then return end
    b.mode, b.entry = mode, e
    if mode == "place" then
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. e.item)
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("item", nil)
    end
    b.icon:SetTexture(ItemIcon(e.item))
    local grey = mode == "missing" or mode == "none"
    b.icon:SetDesaturated(grey)
    b.icon:SetAlpha(grey and 0.5 or 1)
    b.label:SetText(mode == "craft" and "|cffffd100craft|r" or "")
end

local function ApplyPosition()
    bar:ClearAllPoints()
    local p = Kindle.db.point
    if p then
        bar:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

local function CreateFrames()
    bar = CreateFrame("Frame", "KindleBar", UIParent, "BackdropTemplate")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", OnDragStart)
    bar:SetScript("OnDragStop", OnDragStop)
    bar.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.title:SetPoint("BOTTOM", bar, "TOP", 0, 3)
    bar.title:SetText("Kindle: drag to move, /kindle to lock")
    status = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOP", bar, "BOTTOM", 0, -3)
    advice = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    advice:SetPoint("TOP", status, "BOTTOM", 0, -2)
    Kindle.Theme.Register(bar, function(p)
        Kindle.Theme.Backdrop(bar, p)
        -- The background shows when unlocked (something to grab) or when the setting asks for it.
        local showBg = Kindle.db.barBackground or not Kindle.db.locked
        bar:SetBackdropColor(p.bg[1], p.bg[2], p.bg[3], showBg and (p.bg[4] or 1) or 0)
        bar:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], showBg and (p.border[4] or 1) or 0)
        Kindle.Theme.Font(bar.title, p, 11, nil, p.accent)
        Kindle.Theme.Font(status, p, 11, "OUTLINE", p.text)
        Kindle.Theme.Font(advice, p, 11, "OUTLINE", p.text)
    end)
    bar:Hide()

    campBtn = CreateButton("KindleCampfireButton")
    for line in pairs(D.professions) do lines[#lines + 1] = line end
    table.sort(lines)
    for _, line in ipairs(lines) do
        local b = CreateButton("KindleButton" .. line:gsub("%W", ""))
        b.line = line
        profBtns[line] = b
    end
    sitBtn = CreateButton("KindleSitButton")
    sitBtn:SetAttribute("type", "macro")
    sitBtn:SetAttribute("macrotext", "/sit")
    sitBtn.icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(D.auras.welcoming))
        or QUESTION_MARK)
    sitBtn.mode = "sit"

    -- A pulsing glow, in the theme's accent, when sitting would help. Plain textures: fine on a secure button.
    local glow = sitBtn:CreateTexture(nil, "OVERLAY", nil, 6)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:Hide()
    sitBtn.glow = glow
    local anim = glow:CreateAnimationGroup()
    anim:SetLooping("BOUNCE")
    local fade = anim:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.7)
    sitBtn.glowAnim = anim
    Kindle.Theme.Register(glow, function(p)
        local s = Size() * 1.9
        glow:SetSize(s, s)
        glow:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1)
    end)
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------

-- Combat-safe: status line, sit swipe and bonus checks. Reads only Kindle's aura cache.
function UI.RefreshAuras()
    if not initialized or not bar:IsShown() or Kindle.AurasHidden() then return end
    local A = D.auras
    local welcoming = Kindle.PlayerAura(A.welcoming) or Kindle.PlayerAura(A.welcomingCraft)

    if welcoming and (welcoming.duration or 0) > 0 and welcoming.expirationTime then
        sitBtn.cd:SetCooldown(welcoming.expirationTime - welcoming.duration, welcoming.duration)
    elseif sitBtn.cd.Clear then
        sitBtn.cd:Clear()
    end

    local expires = Kindle.Detect.BonusExpires()
    local inCamp = Kindle.Detect.inCamp
    local rating = inCamp and Kindle.Advice.Evaluate()

    -- Sit glows when sitting would help: no camp bonuses yet, or this camp is better for you.
    local glow = Kindle.db.sitGlow and inCamp and not welcoming
        and (expires == 0 or rating.verdict == "better" or rating.verdict == "new")
    sitBtn.glow:SetShown(glow and true or false)
    if glow then sitBtn.glowAnim:Play() else sitBtn.glowAnim:Stop() end

    local parts = {}
    if welcoming then
        parts[#parts + 1] = "|cffffd100Sitting: camp bonuses soon|r"
    elseif expires > 0 then
        parts[#parts + 1] = "Camp bonuses: " .. FormatTime(math.max(0, expires - GetTime()))
    end
    if inCamp and not welcoming then
        parts[#parts + 1] = expires > 0 and "|cff66ff66Campfire nearby|r"
            or "|cff66ff66Campfire nearby|r: sit for camp bonuses"
    end
    status:SetText(table.concat(parts, "  ·  "))
    advice:SetText(Kindle.db.showAdvice and rating and Kindle.Advice.Line(rating) or "")

    for line, b in pairs(profBtns) do
        local bonus = D.professions[line].bonus
        b.check:SetShown(bonus ~= nil and Kindle.PlayerAura(bonus) ~= nil)
    end
end

-- Out of combat only: which buttons show, their actions, layout and bar visibility.
function UI.Update()
    if not initialized then return end
    if InCombatLockdown() then
        dirty = true
        return
    end
    dirty = false
    local db = Kindle.db
    Kindle.Detect.Refresh()
    local state = Kindle.Detect.State()
    local inCamp = state == "camp"

    local order = {}
    -- The campfire button is for when there's no fire. Unlocked, it also stands in so there's something to drag.
    -- Buttons that won't show aren't resolved: that's bag, spell and recipe lookups on every loot.
    local showCamp = false
    if state == "nofire" or (not db.locked and state ~= "camp") then
        local campMode, campEntry = Resolve(D.campfire)
        SetMode(campBtn, campMode, campEntry)
        showCamp = not db.locked or campMode ~= "none" or db.noKitMode ~= "hide"
    end
    if showCamp then order[#order + 1] = campBtn else campBtn:Hide() end

    for _, line in ipairs(lines) do
        local b = profBtns[line]
        local mode, e
        if inCamp then mode, e = Resolve(D.professions[line].best) end
        if inCamp and mode ~= "none" then
            SetMode(b, mode, e)
            order[#order + 1] = b
        else
            b:Hide()
        end
    end

    if inCamp then order[#order + 1] = sitBtn else sitBtn:Hide() end

    -- WoW's tooltip border is thicker than the flat 1px one, and its action-slot frames stick out further.
    local size, gap = Size(), Gap()
    local flat = Kindle.Theme.Palette().flat
    local pad = flat and gap or gap + 6
    if not flat then gap = gap + math.floor(size * 0.2) end
    for i, b in ipairs(order) do
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("LEFT", bar, "LEFT", pad + (i - 1) * (size + gap), 0)
        b:Show()
    end
    local n = math.max(#order, 1)
    bar:SetSize(pad * 2 + n * size + (n - 1) * gap, size + pad * 2)

    local inInstance = IsInInstance()
    bar:SetShown(db.shown and (not inInstance or not db.locked) and #order > 0)
    UI.RefreshAuras()
end

-- Out of combat only: lock state, position, then a full update.
function UI.ApplySettings()
    if not initialized then return end
    if InCombatLockdown() then
        dirty = true
        return
    end
    local unlocked = not Kindle.db.locked
    bar:EnableMouse(unlocked)
    bar.title:SetShown(unlocked)
    ApplyPosition()
    -- Re-styles every Kindle frame: theme, button size and bar background all land here.
    Kindle.Theme.Apply()
    UI.Update()
end

function UI.ResetPosition()
    Kindle.db.point = nil
    UI.ApplySettings()
end

-- Several events often fire together (looting: BAG_UPDATE_DELAYED, then SPELLS_CHANGED...): update once, on the
-- next frame.
local updateQueued = false
local function RunQueuedUpdate()
    updateQueued = false
    UI.Update()
end

function UI.RequestUpdate()
    if updateQueued then return end
    updateQueued = true
    C_Timer.After(0, RunQueuedUpdate)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        -- Registered for the player only. Most aura changes aren't camp auras: stop after one table lookup.
        local _, info = ...
        if not Kindle.Detect.OnAuraUpdate(info) then return end
        Kindle.Alerts.Schedule()
        -- Camp in range or camp bonuses gained/lost changes which buttons show.
        if Kindle.Detect.Refresh() then UI.RequestUpdate() end
        UI.RefreshAuras()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Auras were hidden in combat, so the camp may have changed: rebuild and catch up.
        Kindle.Detect.OnAuraUpdate(nil)
        Kindle.Alerts.Schedule()
        if dirty then UI.ApplySettings() else UI.Update() end
    elseif event == "TRADE_SKILL_SHOW" then
        tradeOpen = true
        OnTradeSkillReady()
    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        OnTradeSkillReady()
    elseif event == "TRADE_SKILL_CLOSE" then
        tradeOpen = false
        craft.opened, craft.deadline = false, nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if Kindle.IsSecret(unit) or unit ~= "player" or Kindle.IsSecret(spellID) then return end
        OnCraftDone(spellID)
    else
        UI.RequestUpdate()
    end
end)

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "TRADE_SKILL_UPDATE", "NEW_RECIPE_LEARNED", "SPELLS_CHANGED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE",
}

local function Init()
    D = Kindle.Data
    for _, p in pairs(D.professions) do
        p.best = {}
        for i = #p.tiers, 1, -1 do p.best[#p.best + 1] = p.tiers[i] end
    end
    CreateFrames()
    initialized = true
    -- Some events may not exist on every client; registering an unknown one errors.
    for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    Kindle.OnDataChanged = UI.RequestUpdate
    Kindle.OnAdviceChanged = UI.RefreshAuras
    -- Camp bonuses' time left: no event fires as it runs down. Skipped while the bar is hidden.
    C_Timer.NewTicker(30, UI.RefreshAuras)
    Kindle.Detect.OnAuraUpdate(nil)
    Kindle.Alerts.Schedule()
    UI.ApplySettings()
end

function UI.Init()
    -- Secure buttons can't be set up in combat (e.g. a /reload mid-fight): wait for it to end.
    if InCombatLockdown() then
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("PLAYER_REGEN_ENABLED")
        wait:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            Init()
        end)
        return
    end
    Init()
end
