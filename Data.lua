-- Kindle: static camping data.
-- Every item/spell ID here must be verified in-game. Unverified values are marked "-- TODO verify".
-- Use /kindle debug to find the real IDs.

local _, Kindle = ...

Kindle.Data = {
    -- Campfire kits, best first. Filled in during Step 2.
    campfire = {},

    -- Profession objects: [profession key] = { tiers, best first }. Filled in during Step 2.
    professions = {},
}
