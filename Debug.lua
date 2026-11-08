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
-- Client compatibility (Forever may have either the old globals or the C_ namespaces)
---------------------------------------------------------------------------

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetBagItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

local function GetBagItemCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.stackCount or 0
    end
    local _, count = GetContainerItemInfo(bag, slot)
    return count or 0
end

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function SpellIDFromLink(link)
    return link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
end

-- Calls fn(name, spellID, duration, expirationTime, sourceUnit) for each aura on unit.
local function ForEachAura(unit, filter, fn)
    for i = 1, 40 do
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if not a then return end
            fn(a.name, a.spellId, a.duration, a.expirationTime, a.sourceUnit)
        else
            local name, _, _, _, duration, expires, source, _, _, spellID = UnitAura(unit, i, filter)
            if not name then return end
            fn(name, spellID, duration, expires, source)
        end
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
        ForEachAura("player", filter, function(name, spellID, duration, _, source)
            snap[spellID or name] = format("%s (spell %s, %s, %ss, from %s)",
                name, tostring(spellID), filter == "HELPFUL" and "buff" or "debuff",
                tostring(duration or 0), tostring(source or "?"))
        end)
    end
    return snap
end

local function BagSnapshot()
    local snap = {}
    for bag = 0, 4 do
        for slot = 1, (GetNumSlots(bag) or 0) do
            local id = ItemIDFromLink(GetBagItemLink(bag, slot))
            if id then
                snap[id] = (snap[id] or 0) + GetBagItemCount(bag, slot)
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

local WATCH_EVENTS = {
    "UNIT_AURA",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "UNIT_SPELLCAST_SUCCEEDED",
    "BAG_UPDATE_DELAYED",
    "UI_ERROR_MESSAGE",
    "UI_INFO_MESSAGE",
    "CHAT_MSG_SYSTEM",
}

watcher:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_AURA" then
        if ... ~= "player" then return end
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
        if unit ~= "player" then return end
        Out(format("cast %s (spell %s)  @ %s", GetSpellInfo(spellID) or "?", tostring(spellID), PosString()))
    elseif event == "BAG_UPDATE_DELAYED" then
        local now = BagSnapshot()
        for id, count in pairs(now) do
            local diff = count - (lastBags[id] or 0)
            if diff ~= 0 then Out(format("bag %+d %s (item %d)", diff, GetItemInfo(id) or "?", id)) end
        end
        for id, count in pairs(lastBags) do
            if not now[id] then Out(format("bag %+d %s (item %d)", -count, GetItemInfo(id) or "?", id)) end
        end
        lastBags = now
    elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
        -- Newer clients pass (messageType, message), older ones only (message).
        local a, b = ...
        local msg = type(b) == "string" and b or a
        Out(format("%s: %s", event == "UI_ERROR_MESSAGE" and "error" or "info", tostring(msg)))
    elseif event == "CHAT_MSG_SYSTEM" then
        Out("system: " .. tostring((...)))
    else
        Out(event .. "  @ " .. PosString())
    end
end)

-- World objects (campfires, profession objects) have no unit, so their name only shows up in the tooltip.
local tooltipHooked = false
local function HookTooltip()
    if tooltipHooked then return end
    tooltipHooked = true
    GameTooltip:HookScript("OnShow", function(tt)
        if not watching or tt:GetUnit() then return end
        local owner = tt:GetOwner()
        if owner ~= UIParent and owner ~= WorldFrame then return end
        local line1 = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
        if not line1 or seenTooltips[line1] then return end
        seenTooltips[line1] = true
        local line2 = GameTooltipTextLeft2 and GameTooltipTextLeft2:GetText()
        Out(format("object tooltip \"%s\"%s  @ %s", line1, line2 and (" / \"" .. line2 .. "\"") or "", PosString()))
    end)
end

local function ToggleWatch()
    watching = not watching
    if watching then
        lastAuras, lastBags, seenTooltips = AuraSnapshot(), BagSnapshot(), {}
        for _, e in ipairs(WATCH_EVENTS) do watcher:RegisterEvent(e) end
        HookTooltip()
        Out("watch ON. Walk up to a campsite, place a fire, mouse over objects, sit down. "
            .. "Type /kindle debug watch again to stop.")
        Out("start @ " .. PosString())
    else
        watcher:UnregisterAllEvents()
        Out("watch OFF. /reload or log out to save the log to SavedVariables\\Kindle.lua.")
    end
end

---------------------------------------------------------------------------
-- One-shot commands
---------------------------------------------------------------------------

local function DumpAuras()
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
        local name = GetItemInfo(id) or "?"
        if not filter or strlower(name):find(filter, 1, true) then
            local _, spellID = GetItemSpell(id)
            Out(format("  %s x%d (item %d%s)", name, count, id, spellID and (", use spell " .. spellID) or ""))
        end
    end
end

local function DumpSkills()
    Out("skills:")
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if isHeader then
            Out("  [" .. tostring(name) .. "]")
        else
            Out(format("    %s %d/%d", tostring(name), rank or 0, maxRank or 0))
        end
    end
end

local function DumpRecipe(name, itemLink, recipeLink, numReagents, getReagent, getReagentLink)
    Out(format("  %s -> item %s, spell %s",
        name, tostring(ItemIDFromLink(itemLink)), tostring(SpellIDFromLink(recipeLink) or SpellIDFromLink(itemLink))))
    for r = 1, numReagents do
        local rName, _, need, have = getReagent(r)
        Out(format("      %dx %s (item %s, have %d)", need or 0, tostring(rName),
            tostring(ItemIDFromLink(getReagentLink(r))), have or 0))
    end
end

local function DumpTrade(filter)
    filter = filter ~= "" and strlower(filter) or nil
    local found = false

    if GetNumTradeSkills and (TradeSkillFrame and TradeSkillFrame:IsShown()) then
        found = true
        Out("trade skill: " .. tostring(GetTradeSkillLine()))
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if name and kind ~= "header" and (not filter or strlower(name):find(filter, 1, true)) then
                DumpRecipe(name, GetTradeSkillItemLink(i), GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i),
                    GetTradeSkillNumReagents(i),
                    function(r) return GetTradeSkillReagentInfo(i, r) end,
                    function(r) return GetTradeSkillReagentItemLink(i, r) end)
            end
        end
    end

    -- Enchanting (and pet training) use the separate Craft API in Classic.
    if GetNumCrafts and (CraftFrame and CraftFrame:IsShown()) then
        found = true
        Out("craft: " .. tostring(GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() or "?"))
        for i = 1, GetNumCrafts() do
            local name, _, kind = GetCraftInfo(i)
            if name and kind ~= "header" and (not filter or strlower(name):find(filter, 1, true)) then
                DumpRecipe(name, GetCraftItemLink(i), GetCraftRecipeLink and GetCraftRecipeLink(i),
                    GetCraftNumReagents(i),
                    function(r) return GetCraftReagentInfo(i, r) end,
                    function(r) return GetCraftReagentItemLink(i, r) end)
            end
        end
    end

    if not found then
        Out("open a profession window first, then run /kindle debug trade [filter].")
    end
end

local function DumpItem(arg)
    local id = ItemIDFromLink(arg) or tonumber(arg)
    if not id then return Out("usage: /kindle debug item <itemID or shift-clicked link>") end
    local name, link, _, _, reqLevel, itemType, subType = GetItemInfo(id)
    if not name then return Out("item " .. id .. " not cached yet, try again in a moment.") end
    local spellName, spellID = GetItemSpell(id)
    Out(format("item %d: %s  type %s/%s  req level %s  in bags %d  usable %s",
        id, link or name, tostring(itemType), tostring(subType), tostring(reqLevel),
        GetItemCount(id), tostring(IsUsableItem(id) and true or false)))
    Out(format("  use spell: %s (spell %s)", tostring(spellName), tostring(spellID)))
end

local function DumpSpell(arg)
    if arg == "" then return Out("usage: /kindle debug spell <spellID or name>") end
    local name, _, _, _, _, _, spellID = GetSpellInfo(tonumber(arg) or arg)
    if not name then return Out("no spell found for \"" .. arg .. "\".") end
    local usable, noMana = IsUsableSpell(name)
    Out(format("spell %s: %s  known %s  usable %s%s", tostring(spellID), name,
        tostring(spellID and IsSpellKnown and IsSpellKnown(spellID) or false),
        tostring(usable and true or false), noMana and " (no mana)" or ""))
end

---------------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------------

local function Help()
    Kindle.Print("debug commands:")
    Kindle.Print("  watch - toggle logging of auras, zone changes, casts, bag changes, messages and object tooltips")
    Kindle.Print("  auras - list your current buffs and debuffs with spell IDs")
    Kindle.Print("  bags [filter] - list bag items with item IDs")
    Kindle.Print("  skills - list your skills and ranks")
    Kindle.Print("  trade [filter] - list recipes in the open profession window with IDs and reagents")
    Kindle.Print("  pos - show map, coordinates and zone texts")
    Kindle.Print("  item <id|link> - item details and the spell it uses")
    Kindle.Print("  spell <id|name> - spell details")
    Kindle.Print("  clear - empty the saved debug log")
end

function Debug.Run(input)
    local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "watch" then ToggleWatch()
    elseif cmd == "auras" then DumpAuras()
    elseif cmd == "bags" then DumpBags(rest)
    elseif cmd == "skills" then DumpSkills()
    elseif cmd == "trade" then DumpTrade(rest)
    elseif cmd == "pos" then Out(PosString())
    elseif cmd == "item" then DumpItem(rest)
    elseif cmd == "spell" then DumpSpell(rest)
    elseif cmd == "clear" then
        Kindle.db.debugLog = {}
        Kindle.Print("debug log cleared.")
    else
        Help()
    end
end
