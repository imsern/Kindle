-- Kindle: button bar UI.
-- Secure buttons arrive in Step 2. Secure frames can't be shown, hidden or changed in combat,
-- so every change to them must go through a queue that runs on PLAYER_REGEN_ENABLED.

local _, Kindle = ...

local UI = {}
Kindle.UI = UI

local bar

function UI.Init()
    -- Created in Step 2.
end

function UI.ApplySettings()
    -- Applied in Step 2.
end

function UI.ResetPosition()
    -- Applied in Step 2.
end
