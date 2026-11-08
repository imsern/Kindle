-- Kindle: static camping data.
--
-- Sources (2026-11-08):
--   [log]   our own /kindle debug watch log in game.
--   [EUI]   EllesmereUIBags_Categories.lua: the camp item IDs with names, from a Forever addon.
--   [Naowh] NaowhForever_Combat AuraBuffs/Data/Campfire.lua: the bonus aura and Tier 1 craft spell per camp
--           object, and the Tier 1-3 object names in each line, probed on the client (build 1.60.1).
--
--   [learn] Kindle's own recipe auto-learn (Recipes.lua) on 2026-11-08: recipe ID and profession per item.
--           Learned values replace these at runtime, so a wrong guess here fixes itself once you open the profession.
--
-- Camping rules seen in game:
--   * Crafting and placing are separate spells (Basic Campfire: craft 1229737, place 1307227; Camp Tent: craft
--     1229432, place 1307230). Crafting can't be started with /cast.
--   * Each camp object gives its own bonus aura (listed as a debuff) for 1 hour after sitting 60s at the fire.
--   * Sitting at another camp replaces your camp bonuses; they don't stack (owner, 2026-11-08).
--
-- Not known yet, marked "-- TODO verify": the profession of lines nobody here has, their Tier 2-3 recipes, and the
-- skill needed for each tier.

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

    -- Campfire kits, best first. Item IDs [EUI]. Cooking recipes [learn]. Skill needed: TODO verify.
    campfire = {
        { item = 279974, name = "Expert Campfire Kit",     craft = 1291341 },
        { item = 279961, name = "Journeyman Campfire Kit", craft = 1283400 },
        { item = 279981, name = "Basic Campfire Kit",      craft = 1229737 },
    },

    -- Profession camp objects. [profession skill line name] = { bonus aura, key, stat, tiers lowest first }.
    -- key: the stat the bonus gives, scored per role in roles below. Bonus names ("Boosted Critical Chance" etc.)
    -- checked with /kindle debug tips all on 2026-11-08; the tooltips have no amounts.
    -- A placed object's name in the world is its item name ("Camp Tent", "Basic Campfire" [log]); Advice.lua relies
    -- on that to know which objects a camp has. Every tier gives the line's bonus; higher tiers give more of the same
    -- stat (owner, 2026-11-08).
    -- Item IDs [EUI]. Tier order and Tier 1 craft spells [Naowh]. Lines without a [learn] note: profession TODO verify.
    professions = {
        -- Profession and recipes [learn].
        ["First Aid"] = { bonus = 1230124, key = "sta", stat = "Stamina", tiers = {
            { item = 279968, name = "First Aid Kit",              craft = 1230117 },
            { item = 279940, name = "Toxin Study",                craft = 1262996 },
            { item = 279951, name = "Plague Doctor's Laboratory", craft = 1263001 },
        } },
        ["Alchemy"] = { bonus = 1230587, key = "mp5", stat = "Mana every 5 sec", tiers = {
            { item = 279956, name = "Mana Well",          craft = 1230564 },
            { item = 279970, name = "Fermenter" },
            { item = 279990, name = "Alchemy Laboratory" },
        } },
        ["Blacksmithing"] = { bonus = 1230172, key = "str", stat = "Strength", tiers = {
            { item = 279944, name = "Sharpening Wheel", craft = 1230171 },
            { item = 279988, name = "Anvil" },
            { item = 279955, name = "Master Forge" },
        } },
        ["Herbalism"] = { bonus = 1229513, key = "int", stat = "Intellect", tiers = {
            { item = 279962, name = "Incense Candle",  craft = 1229705 },
            { item = 279964, name = "Greenhouse" },
            { item = 279947, name = "Seed Hybridizer" },
        } },
        ["Mining"] = { bonus = 1230164, key = "ap", stat = "Attack Power", tiers = {
            { item = 279960, name = "Lodestone",      craft = 1230161 },
            { item = 279948, name = "Rock Garden" },
            { item = 279952, name = "Molten Foundry" },
        } },
        -- Profession and recipes [learn].
        ["Skinning"] = { bonus = 1229519, key = "crit", stat = "Critical Strike", tiers = {
            { item = 279979, name = "Camp Chair",          craft = 1229517 },
            { item = 279938, name = "Trapper's Workbench", craft = 1262982 },
            { item = 279969, name = "Field Guide",         craft = 1262985 },
        } },
        -- Profession and recipes [learn]. Bonus "Boosted Rest" seen in game.
        ["Leatherworking"] = { bonus = 1229451, key = "rest", stat = "Rested experience", tiers = {
            { item = 279978, name = "Camp Tent",      craft = 1229432 },
            { item = 279941, name = "Tanning Rack",   craft = 1263031 },
            { item = 279945, name = "Sewing Machine", craft = 1263079 },
        } },
        -- Cooking [learn]: both are Cooking recipes besides the campfire kits. TODO verify: tier order, bonus aura.
        ["Cooking"] = { tiers = {
            { item = 279957, name = "Cookie's Feast", craft = 1262978 },
            { item = 279982, name = "Iron Oven",      craft = 1263067 },
        } },
        ["Tailoring"] = { bonus = 1229718, key = "spi", stat = "Spirit", tiers = {
            { item = 279973, name = "Faction Banner", craft = 1229504 },
            { item = 279943, name = "Spinning Wheel" },
            { item = 279959, name = "Loom" },
        } },
        ["Fishing"] = { bonus = 1230098, key = "stats", stat = "All stats (%)", tiers = {
            { item = 279967, name = "Fish Bowl",    craft = 1229745 },
            { item = 279965, name = "Fishing Rack" },
            { item = 279966, name = "Fishing Hut" },
        } },
        -- TODO verify: Naowh lists the Lute (+armor/stats/resist) and Salvager (better disenchanting) as two
        -- separate bonuses, so these may not be three tiers of one line.
        ["Enchanting"] = { bonus = 1230653, key = "armor", stat = "Armor, all stats and resistances", tiers = {
            { item = 279976, name = "Enchanted Lute", craft = 1230643 },
            { item = 279985, name = "Arcane Salvager", bonus = 1283701, key = "disenchant", stat = "Disenchanting" },
            { item = 279987, name = "Arcane Forge" },
        } },
        -- TODO verify: no bonus aura known. Tier order is a guess.
        ["Engineering"] = { tiers = {
            { item = 279950, name = "Reagent Bot" },
            { item = 279949, name = "Repair Bot" },
            { item = 279989, name = "Anarchist's Workbench" },
        } },
    },

    -- How much each camp bonus is worth to a role, 0-3. Keys not listed are worth 0. "rest" (rested XP) and
    -- "disenchant" aren't combat stats, so they never count either way. Rough Classic stat priorities, not sims.
    roles = {
        melee  = { name = "melee",  ap = 3, crit = 3, str = 2, stats = 2, armor = 1, sta = 1 },
        tank   = { name = "tank",   sta = 3, armor = 3, str = 2, stats = 2, ap = 1, crit = 1 },
        ranged = { name = "ranged", crit = 3, stats = 2, ap = 1, int = 1, mp5 = 1, sta = 1, armor = 1 },
        caster = { name = "caster", int = 3, crit = 2, mp5 = 2, stats = 2, spi = 1, sta = 1, armor = 1 },
        healer = { name = "healer", int = 3, mp5 = 3, spi = 2, stats = 2, sta = 1, armor = 1, crit = 1 },
    },
    -- Default role per class (UnitClass's file name). Hybrids can pick another in the settings.
    classRole = {
        WARRIOR = "melee", ROGUE = "melee", PALADIN = "melee", HUNTER = "ranged",
        MAGE = "caster", WARLOCK = "caster", SHAMAN = "caster", DRUID = "caster", PRIEST = "healer",
    },
}
