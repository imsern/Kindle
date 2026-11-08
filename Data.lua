-- Kindle: static camping data.
--
-- Sources (2026-11-08):
--   [log]   our own /kindle debug watch log in game.
--   [EUI]   EllesmereUIBags_Categories.lua: the camp item IDs with names, from a Forever addon.
--   [Naowh] NaowhForever_Combat AuraBuffs/Data/Campfire.lua: the bonus aura and Tier 1 craft spell per camp
--           object, and the Tier 1-3 object names in each line, probed on the client (build 1.60.1).
--
-- Not known yet, marked "-- TODO verify":
--   * which profession makes each line (inferred from the object names and the "Camping 101: <profession>" quests),
--   * craft spells for Tier 2 and 3 and for the campfire kits,
--   * the skill needed for each tier.
-- Use /kindle debug trade with the profession window open to fill these in.

local _, Kindle = ...

Kindle.Data = {
    -- Camp auras on the player. [log] and [Naowh] agree on all of these.
    auras = {
        -- "Campfire Nearby": no duration, no caster. On while in range of a placed campfire. Used to detect "in camp".
        campfireNearby = 1283391,
        -- "Welcoming Campfire": 60s while sitting at the fire. Standing up removes it.
        welcoming = 1229739,
        -- Welcoming Campfire's variant while crafting at the fire [Naowh].
        welcomingCraft = 1289723,
        -- "Camp Benefits": 1 hour, granted when Welcoming Campfire runs its full 60s.
        campBenefits = 1229741,
        -- "Attuned": 1 hour, dropped while sitting at the fire. TODO verify: role in camping unknown.
        attuned = 1259691,
    },

    -- Campfire kits, best first. Item IDs [EUI]. Made with Cooking? TODO verify.
    campfire = {
        { item = 279974, name = "Expert Campfire Kit",     craft = nil, skill = nil }, -- TODO verify craft, skill
        { item = 279961, name = "Journeyman Campfire Kit", craft = nil, skill = nil }, -- TODO verify craft, skill
        { item = 279981, name = "Basic Campfire Kit",      craft = nil, skill = nil }, -- TODO verify craft, skill
    },

    -- Profession camp objects. [profession skill line name] = { bonus aura, tiers lowest first }.
    -- Item IDs [EUI]. Tier order and Tier 1 craft spells [Naowh]. Profession per line: TODO verify.
    professions = {
        ["First Aid"] = { bonus = 1230124, stat = "Stamina", tiers = {
            { item = 279968, name = "First Aid Kit",              craft = 1230117 },
            { item = 279940, name = "Toxin Study" },
            { item = 279951, name = "Plague Doctor's Laboratory" },
        } },
        ["Alchemy"] = { bonus = 1230587, stat = "Mana every 5 sec", tiers = {
            { item = 279956, name = "Mana Well",          craft = 1230564 },
            { item = 279970, name = "Fermenter" },
            { item = 279990, name = "Alchemy Laboratory" },
        } },
        ["Blacksmithing"] = { bonus = 1230172, stat = "Strength", tiers = {
            { item = 279944, name = "Sharpening Wheel", craft = 1230171 },
            { item = 279988, name = "Anvil" },
            { item = 279955, name = "Master Forge" },
        } },
        ["Herbalism"] = { bonus = 1229513, stat = "Intellect", tiers = {
            { item = 279962, name = "Incense Candle",  craft = 1229705 },
            { item = 279964, name = "Greenhouse" },
            { item = 279947, name = "Seed Hybridizer" },
        } },
        ["Mining"] = { bonus = 1230164, stat = "Melee Attack Power", tiers = {
            { item = 279960, name = "Lodestone",      craft = 1230161 },
            { item = 279948, name = "Rock Garden" },
            { item = 279952, name = "Molten Foundry" },
        } },
        -- TODO verify: Skinning or Leatherworking? The Camp Chair was crafted right after learning Leatherworking.
        ["Skinning"] = { bonus = 1229519, stat = "Critical Strike", tiers = {
            { item = 279979, name = "Camp Chair",          craft = 1229517 },
            { item = 279938, name = "Trapper's Workbench" },
            { item = 279969, name = "Field Guide" },
        } },
        -- TODO verify: Leatherworking? The +Rested line. Sewing Machine sounds like Tailoring.
        ["Leatherworking"] = { bonus = 1229451, stat = "Rested experience", tiers = {
            { item = 279978, name = "Camp Tent" },
            { item = 279941, name = "Tanning Rack" },
            { item = 279945, name = "Sewing Machine" },
        } },
        ["Tailoring"] = { bonus = 1229718, stat = "Spirit", tiers = {
            { item = 279973, name = "Faction Banner", craft = 1229504 },
            { item = 279943, name = "Spinning Wheel" },
            { item = 279959, name = "Loom" },
        } },
        ["Fishing"] = { bonus = 1230098, stat = "All stats (%)", tiers = {
            { item = 279967, name = "Fish Bowl",    craft = 1229745 },
            { item = 279965, name = "Fishing Rack" },
            { item = 279966, name = "Fishing Hut" },
        } },
        -- TODO verify: Naowh lists the Lute (+armor/stats/resist) and Salvager (better disenchanting) as two
        -- separate bonuses, so these may not be three tiers of one line.
        ["Enchanting"] = { bonus = 1230653, stat = "Armor, all stats and resistances", tiers = {
            { item = 279976, name = "Enchanted Lute", craft = 1230643 },
            { item = 279985, name = "Arcane Salvager", bonus = 1283701 },
            { item = 279987, name = "Arcane Forge" },
        } },
        -- TODO verify: no bonus aura known. Tier order is a guess.
        ["Engineering"] = { tiers = {
            { item = 279950, name = "Reagent Bot" },
            { item = 279949, name = "Repair Bot" },
            { item = 279989, name = "Anarchist's Workbench" },
        } },
    },

    -- Other camp items [EUI] whose place is unknown. TODO verify: Cooking extras?
    other = {
        { item = 279957, name = "Cookie's Feast" },
        { item = 279982, name = "Iron Oven" },
    },
}
