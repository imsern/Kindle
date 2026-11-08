-- Kindle: learns the recipe that makes each camp item, from the profession window.
--
-- Forever uses the retail profession window (ProfessionsFrame, C_TradeSkillUI), and GetAllRecipeIDs only answers
-- for the profession that is open. So whenever a profession window opens, Kindle reads its recipes, matches each
-- recipe's output item against the camp items in Data.lua, and saves recipe ID and profession in
-- KindleDB.recipes[itemID]. Recipe IDs are the same for every character; whether a character knows a recipe is
-- checked at runtime with IsPlayerSpell.

local _, Kindle = ...

local Recipes = {}
Kindle.Recipes = Recipes

-- itemID -> the Data.lua entry for that camp item, with kind ("campfire", "profession"), line (the professions
-- key) and tier filled in.
local byItem = {}
Recipes.byItem = byItem

local outputCache = {} -- recipeID -> itemID or false, for this session

local function Index()
    local D = Kindle.Data
    for i, e in ipairs(D.campfire) do
        e.kind, e.rank = "campfire", i
        byItem[e.item] = e
    end
    for line, p in pairs(D.professions) do
        for tier, e in ipairs(p.tiers) do
            e.kind, e.line, e.tier = "profession", line, tier
            byItem[e.item] = e
        end
    end
end

-- What the client told us beats what Data.lua guessed.
local function Apply(itemID, saved)
    local e = byItem[itemID]
    if not e or type(saved) ~= "table" then return end
    if saved.recipe then e.craft = saved.recipe end
    if saved.profession then e.profession = saved.profession end
end

function Recipes.OutputItem(recipeID)
    local cached = outputCache[recipeID]
    if cached ~= nil then return cached or nil end
    local T = C_TradeSkillUI
    local itemID
    local ok, schematic = pcall(T.GetRecipeSchematic, recipeID, false)
    if ok and type(schematic) == "table" and (schematic.outputItemID or 0) > 0 then
        itemID = schematic.outputItemID
    elseif T.GetRecipeOutputItemData then
        local ok2, data = pcall(T.GetRecipeOutputItemData, recipeID)
        if ok2 and type(data) == "table" and (data.itemID or 0) > 0 then itemID = data.itemID end
    end
    outputCache[recipeID] = itemID or false
    return itemID
end

-- Required reagents of a recipe: { { itemID = n, need = n }, ... }. Works without the profession open.
-- A recipe's reagents never change, so they're cached (a schematic is a big table to build on every bag update).
-- An empty answer isn't cached: the data may not have loaded yet. Callers must not change the returned table.
local reagentCache = {}

function Recipes.Reagents(recipeID)
    if reagentCache[recipeID] then return reagentCache[recipeID] end
    local out = {}
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return out end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not (ok and type(schematic) == "table" and schematic.reagentSlotSchematics) then return out end
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local reagent = slot.reagents and slot.reagents[1]
        if slot.required ~= false and reagent and reagent.itemID then
            out[#out + 1] = { itemID = reagent.itemID, need = slot.quantityRequired or 1 }
        end
    end
    if #out > 0 then reagentCache[recipeID] = out end
    return out
end

function Recipes.ProfessionName()
    local T = C_TradeSkillUI
    for _, get in ipairs({ T.GetBaseProfessionInfo, T.GetChildProfessionInfo }) do
        local ok, info = pcall(get)
        if ok and type(info) == "table" and info.professionName and info.professionName ~= "" then
            return info.professionName
        end
    end
end

local pending = false

function Recipes.Scan()
    pending = false
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs) then return end
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return end
    local profession = Recipes.ProfessionName()
    local saved = Kindle.db.recipes
    local changed = false
    for _, recipeID in ipairs(ids) do
        local itemID = Recipes.OutputItem(recipeID)
        local e = itemID and byItem[itemID]
        if e then
            local old = saved[itemID]
            if not old or old.recipe ~= recipeID or (profession and old.profession ~= profession) then
                saved[itemID] = { recipe = recipeID, profession = profession or (old and old.profession) }
                Apply(itemID, saved[itemID])
                Kindle.Print(format("learned %s: recipe %d (%s).", e.name, recipeID, tostring(profession)))
                changed = true
            end
        end
    end
    if changed and Kindle.OnDataChanged then Kindle.OnDataChanged() end
end

-- The recipe list fills in over several events after the window opens, so wait a moment and scan once.
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.5, Recipes.Scan)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", Schedule)

function Recipes.Init()
    Kindle.db.recipes = Kindle.db.recipes or {}
    Index()
    for itemID, saved in pairs(Kindle.db.recipes) do
        Apply(itemID, saved)
    end
    if not C_TradeSkillUI then return end
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(events.RegisterEvent, events, e)
    end
end
