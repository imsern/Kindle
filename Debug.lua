-- Kindle: /kindle debug tools.
-- Helps find the real item/spell IDs and figure out how to detect that the player is near a campsite.
-- Everything printed here is also saved to KindleDB.debugLog, which the game writes to
-- WTF\Account\<ACCOUNT>\SavedVariables\Kindle.lua on /reload or logout.

local _, Kindle = ...

local Debug = {}
Kindle.Debug = Debug

local LOG_MAX = 1000

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

local function StripCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    return s
end

local function Out(msg)
    msg = tostring(msg)
    Kindle.Print(msg)
    local db = Kindle.db
    if db then
        db.debugLog = db.debugLog or {}
        local log = db.debugLog
        log[#log + 1] = date("%Y-%m-%d %H:%M:%S") .. "  " .. StripCodes(msg)
        while #log > LOG_MAX do
            table.remove(log, 1)
        end
    end
end

---------------------------------------------------------------------------
-- Helpers. Forever runs the modern API (C_Spell, C_Item, C_Container, C_UnitAuras); the old globals are gone.
---------------------------------------------------------------------------

local IsSecret, AurasHidden = Kindle.IsSecret, Kindle.AurasHidden

local function SpellName(id) return C_Spell.GetSpellName(id) end
local function ItemName(id) return C_Item.GetItemNameByID(id) end
local function ItemCount(id) return C_Item.GetItemCount(id) or 0 end

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- Calls fn(aura) for each of the player's auras with this filter. All auras, not just Kindle's camp cache.
local function ForEachAura(filter, fn)
    for i = 1, 40 do
        local a = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
        if not a then return end
        fn(a)
    end
end

local function PosString()
    local parts = {}
    if C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local info = C_Map.GetMapInfo(mapID)
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            local x, y = 0, 0
            if pos then x, y = pos:GetXY() end
            parts[#parts + 1] = format("map %s (%d) %.2f, %.2f", info and info.name or "?", mapID, x * 100, y * 100)
        else
            parts[#parts + 1] = "map ?"
        end
    end
    parts[#parts + 1] = format("zone \"%s\" / sub \"%s\" / minimap \"%s\"",
        GetRealZoneText() or "", GetSubZoneText() or "", GetMinimapZoneText() or "")
    return table.concat(parts, "  |  ")
end

---------------------------------------------------------------------------
-- Snapshots for the watch mode
---------------------------------------------------------------------------

local function AuraSnapshot()
    local snap = {}
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        ForEachAura(filter, function(a)
            snap[a.spellId or a.name] = format("%s (spell %s, %s, %ss, from %s)",
                tostring(a.name), tostring(a.spellId), filter == "HELPFUL" and "buff" or "debuff",
                tostring(a.duration or 0), tostring(a.sourceUnit or "?"))
        end)
    end
    return snap
end

local function BagSnapshot()
    local snap = {}
    for bag = 0, 4 do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                snap[info.itemID] = (snap[info.itemID] or 0) + (info.stackCount or 0)
            end
        end
    end
    return snap
end

---------------------------------------------------------------------------
-- Watch mode: log everything that might tell us we're at a campsite
---------------------------------------------------------------------------

local watcher = CreateFrame("Frame")
local watching = false
local lastAuras, lastBags, seenTooltips = {}, {}, {}

-- Collapses runs of the same message (e.g. a spammed system line) into one line plus a repeat count.
local REPEAT_WINDOW = 10
local lastMsg, lastMsgTime, repeats = nil, 0, 0

local function FlushRepeats()
    if repeats > 0 then
        Out(format("  (previous line repeated %d more times)", repeats))
    end
    lastMsg, repeats = nil, 0
end

local function WatchMessage(text)
    local now = GetTime()
    if text == lastMsg and now - lastMsgTime <= REPEAT_WINDOW then
        repeats = repeats + 1
        lastMsgTime = now
        return
    end
    FlushRepeats()
    lastMsg, lastMsgTime = text, now
    Out(text .. "  @ " .. PosString())
end

-- UNIT_AURA and UNIT_SPELLCAST_SUCCEEDED are registered for the player only, in ToggleWatch.
local WATCH_EVENTS = {
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "BAG_UPDATE_DELAYED",
    "UI_ERROR_MESSAGE",
    "UI_INFO_MESSAGE",
    "CHAT_MSG_SYSTEM",
}

watcher:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        local unit = ...
        if IsSecret(unit) or unit ~= "player" or AurasHidden() then return end
        local now = AuraSnapshot()
        for key, desc in pairs(now) do
            if not lastAuras[key] then Out("|cff00ff00+ aura|r " .. desc .. "  @ " .. PosString()) end
        end
        for key, desc in pairs(lastAuras) do
            if not now[key] then Out("|cffff4040- aura|r " .. desc .. "  @ " .. PosString()) end
        end
        lastAuras = now
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if IsSecret(unit) or unit ~= "player" or IsSecret(spellID) then return end
        Out(format("cast %s (spell %s)  @ %s", SpellName(spellID) or "?", tostring(spellID), PosString()))
    elseif event == "BAG_UPDATE_DELAYED" then
        local now = BagSnapshot()
        for id, count in pairs(now) do
            local diff = count - (lastBags[id] or 0)
            if diff ~= 0 then Out(format("bag %+d %s (item %d)", diff, ItemName(id) or "?", id)) end
        end
        for id, count in pairs(lastBags) do
            if not now[id] then Out(format("bag %+d %s (item %d)", -count, ItemName(id) or "?", id)) end
        end
        lastBags = now
    elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
        -- Newer clients pass (messageType, message), older ones only (message).
        local a, b = ...
        local msg = type(b) == "string" and b or a
        WatchMessage(format("%s: %s", event == "UI_ERROR_MESSAGE" and "error" or "info", tostring(msg)))
    elseif event == "CHAT_MSG_SYSTEM" then
        WatchMessage("system: " .. tostring((...)))
    else
        Out(event .. "  @ " .. PosString())
    end
end)

-- World objects (campfires, profession objects) have no unit, so their name only shows up in the tooltip.
-- Hooked the first time watch is turned on; it does nothing while watch is off.
local tooltipHooked = false
local function HookTooltip()
    if tooltipHooked then return end
    tooltipHooked = true
    GameTooltip:HookScript("OnShow", function(tt)
        if not watching then return end
        local line1 = Kindle.WorldObjectName(tt)
        if not line1 or seenTooltips[line1] then return end
        seenTooltips[line1] = true
        local line2 = GameTooltipTextLeft2 and GameTooltipTextLeft2:GetText()
        if line2 and IsSecret(line2) then line2 = nil end
        Out(format("object tooltip \"%s\"%s  @ %s", line1, line2 and (" / \"" .. line2 .. "\"") or "", PosString()))
    end)
end

local function ToggleWatch()
    watching = not watching
    if watching then
        lastAuras = AurasHidden() and {} or AuraSnapshot()
        lastBags, seenTooltips = BagSnapshot(), {}
        for _, e in ipairs(WATCH_EVENTS) do watcher:RegisterEvent(e) end
        -- Only the player's auras and casts, not every nameplate's.
        watcher:RegisterUnitEvent("UNIT_AURA", "player")
        watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        HookTooltip()
        Out("watch ON. Walk up to a campsite, place a fire, mouse over objects, sit down. "
            .. "Type /kindle debug watch again to stop.")
        Out("start @ " .. PosString())
    else
        watcher:UnregisterAllEvents()
        FlushRepeats()
        Out("watch OFF. /reload or log out to save the log to SavedVariables\\Kindle.lua.")
    end
end

---------------------------------------------------------------------------
-- One-shot commands
---------------------------------------------------------------------------

local function DumpAuras()
    if AurasHidden() then return Out("auras are hidden from addons right now (combat). Try again after combat.") end
    Out("auras on player @ " .. PosString())
    local any = false
    for _, desc in pairs(AuraSnapshot()) do
        Out("  " .. desc)
        any = true
    end
    if not any then Out("  (none)") end
end

local function DumpBags(filter)
    filter = filter ~= "" and strlower(filter) or nil
    Out("bag items" .. (filter and (" matching \"" .. filter .. "\"") or "") .. ":")
    for id, count in pairs(BagSnapshot()) do
        local name = ItemName(id) or "?"
        if not filter or strlower(name):find(filter, 1, true) then
            local _, spellID = C_Item.GetItemSpell(id)
            Out(format("  %s x%d (item %d%s)", name, count, id, spellID and (", use spell " .. spellID) or ""))
        end
    end
end

-- Forever uses the retail profession window: C_TradeSkillUI answers for the profession that is open.
local function DumpTrade(filter)
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs) then return Out("C_TradeSkillUI.GetAllRecipeIDs doesn't exist on this client.") end
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" or #ids == 0 then
        return Out("open a profession window first, then run /kindle debug trade [filter].")
    end
    filter = filter ~= "" and strlower(filter) or nil
    local R = Kindle.Recipes
    Out(format("profession %s: %d recipes", tostring(R.ProfessionName()), #ids))
    for _, recipeID in ipairs(ids) do
        local info = T.GetRecipeInfo and T.GetRecipeInfo(recipeID)
        local name = (info and info.name) or SpellName(recipeID) or "?"
        if not filter or strlower(name):find(filter, 1, true) then
            local itemID = R.OutputItem(recipeID)
            Out(format("  %s (recipe %d) -> item %s%s, learned %s", name, recipeID, tostring(itemID),
                (itemID and R.byItem[itemID]) and " [camp]" or "", tostring(info and info.learned)))
            for _, r in ipairs(R.Reagents(recipeID)) do
                Out(format("      %dx %s (item %d, have %d)", r.need, ItemName(r.itemID) or "?", r.itemID,
                    ItemCount(r.itemID)))
            end
        end
    end
end

local function DumpItem(arg)
    local id = ItemIDFromLink(arg) or tonumber(arg)
    if not id then return Out("usage: /kindle debug item <itemID or shift-clicked link>") end
    local name, link, _, _, reqLevel, itemType, subType = C_Item.GetItemInfo(id)
    if not name then return Out("item " .. id .. " not cached yet, try again in a moment.") end
    local spellName, spellID = C_Item.GetItemSpell(id)
    Out(format("item %d: %s  type %s/%s  req level %s  in bags %d  usable %s",
        id, link or name, tostring(itemType), tostring(subType), tostring(reqLevel),
        ItemCount(id), tostring(C_Item.IsUsableItem(id) and true or false)))
    Out(format("  use spell: %s (spell %s)", tostring(spellName), tostring(spellID)))
end

local function DumpSpell(arg)
    if arg == "" then return Out("usage: /kindle debug spell <spellID or name>") end
    local info = C_Spell.GetSpellInfo(tonumber(arg) or arg)
    if not info then return Out("no spell found for \"" .. arg .. "\".") end
    local usable, noMana = C_Spell.IsSpellUsable(info.spellID)
    Out(format("spell %d: %s  known %s  usable %s%s", info.spellID, info.name,
        tostring(IsPlayerSpell(info.spellID) and true or false),
        tostring(usable and true or false), noMana and " (no mana)" or ""))
end

-- Checks every ID in Data.lua against the client: the client's own name, how many you carry, recipe known.
local function CheckEntry(prefix, e)
    local name = ItemName(e.item)
    local mark = (name == e.name) and "ok" or ("|cffff4040client says \"" .. tostring(name) .. "\"|r")
    local line = format("%s%s (item %d) %s, have %d", prefix, e.name, e.item, mark, ItemCount(e.item))
    if e.craft then
        local known = IsPlayerSpell(e.craft)
        line = line .. format(", craft %s (spell %d) known %s", tostring(SpellName(e.craft)), e.craft, tostring(known and true or false))
    end
    local saved = Kindle.db.recipes and Kindle.db.recipes[e.item]
    if saved then
        line = line .. format(" |cff00ff00[learned from %s]|r", tostring(saved.profession))
    end
    Out(line)
end

local function DumpData()
    local D = Kindle.Data
    for name, id in pairs(D.auras) do
        Out(format("aura %s = %d \"%s\"", name, id, tostring(SpellName(id))))
    end
    for _, e in ipairs(D.campfire) do CheckEntry("campfire: ", e) end
    for prof, p in pairs(D.professions) do
        Out(format("%s (bonus %s \"%s\"):", prof, tostring(p.bonus), tostring(p.bonus and SpellName(p.bonus))))
        for i, e in ipairs(p.tiers) do CheckEntry(format("  T%d ", i), e) end
    end
    Out("names showing \"nil\" aren't cached yet: run it again in a moment.")
end

-- Camp aura tooltips: what the game tells about the camp you're at and the bonuses you have. This is what a
-- class-based "is this camp better for me?" check would have to read.
local function TooltipLines(data)
    local out = {}
    if type(data) ~= "table" or type(data.lines) ~= "table" then return out end
    for _, l in ipairs(data.lines) do
        local left, right = l.leftText, l.rightText
        if left and not IsSecret(left) and left ~= "" then
            if right and not IsSecret(right) and right ~= "" then left = left .. "  |  " .. right end
            out[#out + 1] = left
        end
    end
    return out
end

local function CampSpellIDs()
    local set = {}
    local D = Kindle.Data
    for name, id in pairs(D.auras) do set[id] = name end
    for line, p in pairs(D.professions) do
        if p.bonus then set[p.bonus] = line .. " bonus" end
        for _, e in ipairs(p.tiers) do
            if e.bonus then set[e.bonus] = e.name .. " bonus" end
        end
    end
    return set
end

local CAMP_WORDS = { "camp", "boost", "extra", "rest", "welcom", "attuned" }

local function DumpTips(arg)
    if not C_TooltipInfo then return Out("C_TooltipInfo doesn't exist on this client.") end
    local known = CampSpellIDs()

    if arg == "all" then
        -- Every bonus in Data.lua, as its spell tooltip: the description and amounts, without needing the aura.
        for id, label in pairs(known) do
            local ok, data = pcall(C_TooltipInfo.GetSpellByID, id)
            Out(format("spell %d (%s):", id, label))
            for _, l in ipairs(ok and TooltipLines(data) or {}) do Out("    " .. l) end
        end
        return
    end

    if AurasHidden() then return Out("auras are hidden from addons right now (combat). Try again after combat.") end
    local found = 0
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
            if not a then break end
            local match = known[a.spellId]
            if not match then
                local lower = strlower(a.name or "")
                for _, word in ipairs(CAMP_WORDS) do
                    if lower:find(word, 1, true) then match = "name match"; break end
                end
            end
            if match then
                found = found + 1
                Out(format("%s (spell %s, %s, %s) @ %s", tostring(a.name), tostring(a.spellId),
                    filter == "HELPFUL" and "buff" or "debuff", match, PosString()))
                local get = filter == "HELPFUL" and C_TooltipInfo.GetUnitBuffByAuraInstanceID
                    or C_TooltipInfo.GetUnitDebuffByAuraInstanceID
                local ok, data = pcall(get, "player", a.auraInstanceID)
                for _, l in ipairs(ok and TooltipLines(data) or {}) do Out("    " .. l) end
                -- The numbers the aura carries (NaowhForever_Combat reads bonus amounts from these).
                if type(a.points) == "table" and #a.points > 0 then
                    local p = {}
                    for k, v in ipairs(a.points) do p[k] = IsSecret(v) and "?" or tostring(v) end
                    Out("    points: " .. table.concat(p, ", "))
                end
            end
        end
    end
    if found == 0 then Out("no camp auras on you right now.") end
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------

local function Help()
    Kindle.Print("debug commands:")
    Kindle.Print("  watch - toggle logging of auras, zone changes, casts, bag changes, messages and object tooltips")
    Kindle.Print("  auras - list your current buffs and debuffs with spell IDs")
    Kindle.Print("  bags [filter] - list bag items with item IDs")
    Kindle.Print("  trade [filter] - list recipes in the open profession window with IDs and reagents")
    Kindle.Print("  pos - show map, coordinates and zone texts")
    Kindle.Print("  item <id|link> - item details and the spell it uses")
    Kindle.Print("  spell <id|name> - spell details")
    Kindle.Print("  data - check every ID in Data.lua against the client")
    Kindle.Print("  tips - tooltip text of the camp auras on you; tips all - every camp bonus's spell tooltip")
    Kindle.Print("  advice - your role, what Kindle knows about this camp and your bonuses, with scores")
    Kindle.Print("  clear - empty the saved debug log")
end

function Debug.Run(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "watch" then ToggleWatch()
    elseif cmd == "auras" then DumpAuras()
    elseif cmd == "bags" then DumpBags(rest)
    elseif cmd == "trade" then DumpTrade(rest)
    elseif cmd == "pos" then Out(PosString())
    elseif cmd == "item" then DumpItem(rest)
    elseif cmd == "spell" then DumpSpell(rest)
    elseif cmd == "data" then DumpData()
    elseif cmd == "tips" then DumpTips(strlower(rest))
    elseif cmd == "advice" then
        for _, l in ipairs(Kindle.Advice.Report()) do Out(l) end
    elseif cmd == "clear" then
        Kindle.db.debugLog = {}
        Kindle.Print("debug log cleared.")
    else
        Help()
    end
end
