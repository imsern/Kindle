-- Kindle: camp auras and "is the player in camp?", swappable with /kindle detect <method>.
--
-- UNIT_AURA fires constantly (every buff, every tick), so Kindle keeps its own small cache of only the camp auras
-- it cares about and updates it from the event's change list: an aura that isn't a camp aura costs one table
-- lookup. Detect.OnAuraUpdate returns whether a camp aura changed; everything else reads Kindle.PlayerAura, which
-- only reads the cache.
--
-- In combat Forever hides auras from addons (C_Secrets.ShouldAurasBeSecret); the cache keeps its last state and
-- is rebuilt once auras are visible again.
--
-- A method is { desc = "...", Check = function() return true/false end }. Detect.Refresh() runs the chosen
-- method and remembers the answer in Detect.inCamp. To add a method, add it to Detect.methods.

local _, Kindle = ...

-- inCamp: a campfire is in range. hasBenefits: Camp Benefits or a camp bonus is on the player.
local Detect = { inCamp = false, hasBenefits = false, methods = {} }
Kindle.Detect = Detect

local watched = {}    -- [spellID] = true for every camp aura
local cache = {}      -- [spellID] = aura data
local byInstance = {} -- [auraInstanceID] = spellID
local stale = true    -- the cache missed changes (auras were hidden) and needs a full rebuild

---------------------------------------------------------------------------
-- Aura helpers
---------------------------------------------------------------------------

function Kindle.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end
local IsSecret = Kindle.IsSecret

-- In combat Forever hides the player's auras from addons; reading them then errors or returns nothing.
function Kindle.AurasHidden()
    return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() and true or false
end

-- The player's camp aura with this spell ID, or nil. Only camp auras (Detect.Init) are tracked.
function Kindle.PlayerAura(spellID)
    return cache[spellID]
end

local function Fetch(spellID)
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if ok and type(aura) == "table" then return aura end
end

local function Rebuild()
    wipe(cache)
    wipe(byInstance)
    for id in pairs(watched) do
        local a = Fetch(id)
        if a then
            cache[id] = a
            if a.auraInstanceID and not IsSecret(a.auraInstanceID) then byInstance[a.auraInstanceID] = id end
        end
    end
    stale = false
end

-- Feeds a UNIT_AURA change list (may be nil) into the cache. Returns true when a camp aura changed.
function Detect.OnAuraUpdate(info)
    if Kindle.AurasHidden() then
        stale = true
        return false
    end
    if stale or not info or info.isFullUpdate then
        Rebuild()
        return true
    end
    local changed = false
    if info.addedAuras then
        for _, a in ipairs(info.addedAuras) do
            local id, inst = a.spellId, a.auraInstanceID
            if IsSecret(id) or IsSecret(inst) then Rebuild() return true end
            if watched[id] then
                cache[id], byInstance[inst], changed = a, id, true
            end
        end
    end
    if info.updatedAuraInstanceIDs then
        for _, inst in ipairs(info.updatedAuraInstanceIDs) do
            local id = not IsSecret(inst) and byInstance[inst]
            if id then
                cache[id], changed = Fetch(id), true
            end
        end
    end
    if info.removedAuraInstanceIDs then
        for _, inst in ipairs(info.removedAuraInstanceIDs) do
            local id = not IsSecret(inst) and byInstance[inst]
            if id then
                byInstance[inst] = nil
                cache[id], changed = nil, true
            end
        end
    end
    return changed
end

---------------------------------------------------------------------------
-- Methods
---------------------------------------------------------------------------

-- "Campfire Nearby" (1283391): an area aura you have while in range of a placed campfire. Seen in game 2026-11-08.
Detect.methods.aura = {
    desc = "the Campfire Nearby aura (default)",
    Check = function()
        return cache[Kindle.Data.auras.campfireNearby] ~= nil
    end,
}

-- For testing the bar anywhere.
Detect.methods.always = {
    desc = "always in camp (testing)",
    Check = function() return true end,
}

Detect.methods.never = {
    desc = "never in camp (testing)",
    Check = function() return false end,
}

Detect.DEFAULT = "aura"

function Detect.Method()
    return Detect.methods[Kindle.db.detect] or Detect.methods[Detect.DEFAULT]
end

-- Re-checks the camp state and camp bonuses from the cache. Returns true when either changed. While auras are
-- hidden the last answers are kept.
function Detect.Refresh()
    if Kindle.AurasHidden() then return false end
    if stale then Rebuild() end
    local changed = false
    local ok, inCamp = pcall(Detect.Method().Check)
    if ok then
        inCamp = inCamp and true or false
        if inCamp ~= Detect.inCamp then
            Detect.inCamp, changed = inCamp, true
            Kindle.Advice.OnCamp(inCamp)
        end
    end
    -- Camp Benefits, or any camp bonus: a tent alone gives Boosted Rest without Camp Benefits (owner, 2026-11-08).
    local hasBenefits = cache[Kindle.Data.auras.campBenefits] ~= nil
    if not hasBenefits then
        for id in pairs(Kindle.Advice.Bonuses()) do
            if cache[id] then hasBenefits = true; break end
        end
    end
    if hasBenefits ~= Detect.hasBenefits then
        Detect.hasBenefits, changed = hasBenefits, true
    end
    return changed
end

-- When your camp bonuses run out (GetTime() based), or 0 without any: Camp Benefits or the longest bonus (a tent
-- alone gives Boosted Rest without Camp Benefits). Reads the cache, so it also works while auras are hidden.
function Detect.BonusExpires()
    local function Exp(a)
        local e = a and a.expirationTime
        if not e or IsSecret(e) then return 0 end
        return e
    end
    local expires = Exp(cache[Kindle.Data.auras.campBenefits])
    for id in pairs(Kindle.Advice.Bonuses()) do
        local e = Exp(cache[id])
        if e > expires then expires = e end
    end
    return expires
end

-- What the bar is for right now:
--   "camp"   a campfire is in range: camp objects and sit, no campfire button (the fire is there).
--   "nofire" no campfire in range and no camp bonuses: the campfire button, to place or craft one.
--   "done"   camp bonuses are up and no campfire in range: nothing to do, the bar hides.
function Detect.State()
    if Detect.inCamp then return "camp" end
    if Detect.hasBenefits then return "done" end
    return "nofire"
end

-- After Advice.Init: watch every camp aura in Data.lua plus every bonus.
function Detect.Init()
    for _, id in pairs(Kindle.Data.auras) do watched[id] = true end
    for id in pairs(Kindle.Advice.Bonuses()) do watched[id] = true end
    stale = true
end

---------------------------------------------------------------------------
-- World-object tooltips (shared by Advice and the debug watch)
---------------------------------------------------------------------------

-- The name on a GameTooltip when it's for a thing in the 3D world (campfire, camp object), else nil. World
-- objects have no unit, so their name only shows up in the tooltip.
function Kindle.WorldObjectName(tt)
    local ok, unit = pcall(tt.GetUnit, tt)
    if ok and unit then return nil end
    local owner = tt:GetOwner()
    if owner ~= UIParent and owner ~= WorldFrame then return nil end
    -- Not minimap buttons or minimap quest blips.
    local focus
    if GetMouseFoci then focus = GetMouseFoci()[1] elseif GetMouseFocus then focus = GetMouseFocus() end
    if focus and focus ~= WorldFrame then return nil end
    local name = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    -- Multi-line first lines are quest objective lists, not object names.
    if not name or IsSecret(name) or name:find("\n", 1, true) then return nil end
    return name
end
