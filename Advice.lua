-- Kindle: is this camp worth sitting at for your class?
--
-- Sitting at a camp replaces your camp bonuses with that camp's, so the question is "are this camp's bonuses
-- better for me than the ones I have?". The game doesn't tell addons what a camp has: Campfire Nearby's tooltip is
-- just its name (checked 2026-11-08). So Kindle learns a camp's objects two ways:
--   * hovering them: a placed object's world tooltip is its item name ("Camp Tent"), looked up in Data.lua, which
--     also gives its tier;
--   * bonuses you gain while at the camp come from it.
-- What it learned is kept until you've been away from the camp (no Campfire Nearby) for GRACE seconds.
--
-- Every tier of a line gives the same stat, higher tiers more of it (owner, 2026-11-08), so a bonus is worth
-- (role weight x tier). The tooltips carry no amounts, so the tier of your own bonuses is remembered from the camp
-- you got them at (KindleDB.myTiers); a bonus Kindle didn't see you get counts as tier 1.
--
-- Each bonus has a stat key (Data.lua); Data.roles says what each key is worth to a role, and the role comes from
-- your class (Data.classRole) unless set with /kindle role. Only hovered objects count, so the camp's score is a
-- lower bound until you've hovered all of them.

local _, Kindle = ...

-- camp: [bonus aura ID] = tier. sharedBy: [bonus aura ID] = name of the groupmate who told us.
local Advice = { camp = {}, sharedBy = {} }
Kindle.Advice = Advice

local GRACE = 30
local ROMAN = { "", " II", " III", " IV" }

local D
local bonuses = {}   -- [aura spell ID] = { id, key, stat, line }
local byObject = {}  -- [object name] = { bonus, tier }
local enteredAt, leftAt

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

local function BuildIndex()
    for line, p in pairs(D.professions) do
        for tier, e in ipairs(p.tiers) do
            local id = e.bonus or p.bonus
            local key = e.bonus and e.key or p.key
            if id and key then
                local b = bonuses[id]
                if not b then
                    b = { id = id, key = key, stat = e.bonus and e.stat or p.stat, line = line }
                    bonuses[id] = b
                end
                -- A tier with its own bonus (Arcane Salvager) is tier 1 of that bonus.
                byObject[e.name] = { bonus = b, tier = e.bonus and 1 or tier }
            end
        end
    end
end

-- Every known camp bonus aura: [spell ID] = bonus.
function Advice.Bonuses() return bonuses end

function Advice.Role()
    local r = Kindle.db and Kindle.db.role
    if r and D.roles[r] then return r end
    local _, class = UnitClass("player")
    return D.classRole[class or ""] or "melee"
end

local function Weight(id, role)
    return (D.roles[role] or {})[bonuses[id].key] or 0
end

---------------------------------------------------------------------------
-- Your bonuses' tiers
---------------------------------------------------------------------------

local function MyTiers()
    Kindle.db.myTiers = Kindle.db.myTiers or {}
    return Kindle.db.myTiers
end

local function MyTier(id)
    local t = MyTiers()[id]
    if t and t.expires > time() then return t.tier end
    return 1
end

local function RememberMyTier(id, tier, aura)
    local saved = MyTiers()[id]
    local expires = time() + math.floor(aura.expirationTime - GetTime())
    -- Only write when it changes: this runs on every refresh while in camp.
    if expires > time() and not (saved and saved.tier == tier and math.abs(saved.expires - expires) < 5) then
        MyTiers()[id] = { tier = tier, expires = expires }
    end
end

local function PruneMyTiers()
    local now = time()
    for id, t in pairs(MyTiers()) do
        if type(t) ~= "table" or (t.expires or 0) <= now then MyTiers()[id] = nil end
    end
end

---------------------------------------------------------------------------
-- Learning the camp
---------------------------------------------------------------------------

local function Changed()
    if Kindle.OnAdviceChanged then Kindle.OnAdviceChanged() end
end

-- quiet: the caller is already refreshing the advice, so don't ask for another refresh.
-- from: the groupmate who shared it (Share.lua); what you learn yourself is shared with your group.
local function Learn(id, tier, quiet, from)
    if (Advice.camp[id] or 0) < tier then
        Advice.camp[id] = tier
        Advice.sharedBy[id] = from
        if not from then Kindle.Share.QueueSend() end
        if not quiet then Changed() end
    end
end

-- A groupmate at the same camp told us it has this bonus at this tier.
function Advice.LearnShared(id, tier, from)
    if bonuses[id] then Learn(id, tier, false, from) end
end

-- Called by Detect.Refresh when Campfire Nearby comes or goes.
function Advice.OnCamp(inCamp)
    local now = GetTime()
    if inCamp then
        if not leftAt or now - leftAt > GRACE then
            wipe(Advice.camp)
            wipe(Advice.sharedBy)
            enteredAt = now
        end
        leftAt = nil
        -- Groupmates already here may know what this camp has.
        if next(Advice.camp) == nil then Kindle.Share.Ask() end
    else
        leftAt = now
    end
end

-- Bonuses gained since arriving at the camp came from it, at the tier we saw there. Needs visible auras.
local function LearnFromAuras()
    if not Kindle.Detect.inCamp or not enteredAt then return end
    for id in pairs(bonuses) do
        local a = Kindle.PlayerAura(id)
        local exp, dur = a and a.expirationTime, a and a.duration
        if exp and dur and not Kindle.IsSecret(exp) and not Kindle.IsSecret(dur) and dur > 0
            and exp - dur >= enteredAt - 1 then
            Learn(id, 1, true)
            RememberMyTier(id, Advice.camp[id], a)
        end
    end
end

-- Runs for every GameTooltip; away from a camp it returns at once.
local function OnTooltipShow(tt)
    if not Kindle.Detect.inCamp then return end
    local name = Kindle.WorldObjectName(tt)
    local o = name and byObject[name]
    if o then Learn(o.bonus.id, o.tier) end
end

---------------------------------------------------------------------------
-- Rating
---------------------------------------------------------------------------

-- Your current camp bonuses: [spell ID] = tier. Needs visible auras.
local function Mine()
    local mine = {}
    for id in pairs(bonuses) do
        if Kindle.PlayerAura(id) then mine[id] = MyTier(id) end
    end
    return mine
end

local function Score(set, role)
    local s = 0
    for id, tier in pairs(set) do s = s + Weight(id, role) * tier end
    return s
end

local function SameSet(a, b)
    for id, t in pairs(a) do if b[id] ~= t then return false end end
    for id, t in pairs(b) do if a[id] ~= t then return false end end
    return true
end

local WEIGHT_COLOR = { [0] = "808080", [1] = "c0c0c0", [2] = "ffffff", [3] = "66ff66" }

-- "Critical Strike II, Attack Power" with each stat coloured by what it's worth to the role, best first.
local function StatList(set, role, plain)
    local list = {}
    for id, tier in pairs(set) do list[#list + 1] = { id = id, tier = tier } end
    table.sort(list, function(x, y)
        local wx, wy = Weight(x.id, role) * x.tier, Weight(y.id, role) * y.tier
        if wx ~= wy then return wx > wy end
        return bonuses[x.id].stat < bonuses[y.id].stat
    end)
    for i, s in ipairs(list) do
        local text = bonuses[s.id].stat .. (ROMAN[s.tier] or (" T" .. s.tier))
        list[i] = plain and text or format("|cff%s%s|r", WEIGHT_COLOR[Weight(s.id, role)] or "ffffff", text)
    end
    return table.concat(list, ", ")
end

-- Works out the verdict. Needs visible auras. Returns a table:
--   verdict: "unknown" (no objects learned), "new" (you have no bonuses), "same", "better", "worse", "equal"
function Advice.Evaluate()
    LearnFromAuras()
    local role = Advice.Role()
    local mine, camp = Mine(), Advice.camp
    local r = { role = role, mine = mine, camp = camp, myScore = Score(mine, role), campScore = Score(camp, role) }
    if next(camp) == nil then
        r.verdict = "unknown"
    elseif next(mine) == nil then
        r.verdict = "new"
    elseif SameSet(mine, camp) then
        r.verdict = "same"
    elseif r.campScore > r.myScore then
        r.verdict = "better"
    elseif r.campScore < r.myScore then
        r.verdict = "worse"
    else
        r.verdict = "equal"
    end
    return r
end

-- The advice line under the bar for a rating from Advice.Evaluate() (made while in camp).
function Advice.Line(r)
    local role = D.roles[r.role].name
    if r.verdict == "unknown" then
        return "|cff999999Hover the camp's objects to rate it|r"
    end
    local text = "This camp: " .. StatList(r.camp, r.role)
    if r.verdict == "new" then
        return text
    elseif r.verdict == "same" then
        return text .. "  |cff999999(you have these)|r"
    elseif r.verdict == "better" then
        return text .. "  |cff66ff66better for " .. role .. " than yours|r"
    elseif r.verdict == "worse" then
        return text .. "  |cffff6666worse for " .. role .. ": keep yours|r"
    end
    return text .. "  |cffffd100as good as yours|r"
end

-- Details for the Sit button's tooltip. Needs visible auras.
function Advice.AddTooltip(tt)
    if not Kindle.Detect.inCamp then return end
    local r = Advice.Evaluate()
    tt:AddLine(" ")
    tt:AddLine(format("Rated for %s (change it in /kindle)", D.roles[r.role].name), 0.8, 0.8, 0.8)
    if next(r.camp) then
        tt:AddDoubleLine("This camp:", StatList(r.camp, r.role), 1, 1, 1)
        local names, seen = {}, {}
        for _, name in pairs(Advice.sharedBy) do
            if not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
        if #names > 0 then
            tt:AddLine("Shared by " .. table.concat(names, ", "), 0.6, 0.6, 0.6, true)
        end
    else
        tt:AddLine("This camp: hover its objects to see what it gives.", 0.6, 0.6, 0.6, true)
    end
    tt:AddDoubleLine("Your bonuses:", next(r.mine) and StatList(r.mine, r.role) or "none", 1, 1, 1, 0.6, 0.6, 0.6)
    tt:AddLine("Sitting here replaces your bonuses with this camp's. Higher tiers give more of the same stat.",
        0.6, 0.6, 0.6, true)
end

-- Lines for /kindle debug advice.
function Advice.Report()
    if Kindle.AurasHidden() then return { "auras are hidden right now (combat)." } end
    local r = Advice.Evaluate()
    return {
        format("role %s (%s), in camp %s, verdict %s", r.role, Kindle.db.role and "set" or "from class",
            tostring(Kindle.Detect.inCamp), r.verdict),
        format("camp (score %d): %s", r.campScore, StatList(r.camp, r.role, true)),
        format("yours (score %d): %s", r.myScore, StatList(r.mine, r.role, true)),
    }
end

function Advice.Init()
    D = Kindle.Data
    BuildIndex()
    PruneMyTiers()
    GameTooltip:HookScript("OnShow", OnTooltipShow)
end
