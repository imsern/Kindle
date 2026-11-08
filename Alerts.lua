-- Kindle: a warning (sound, centre-screen text and a chat line) a few minutes before your camp bonuses run out.
--
-- No polling: when the camp auras change, one timer is set for the moment to warn. Each bonus period warns once,
-- also across /reload (KindleDB.warnedFor holds the expiry it warned about; GetTime() survives a reload).

local _, Kindle = ...

local Alerts = {}
Kindle.Alerts = Alerts

-- Warning sounds. SOUNDKIT names with their usual IDs as a fallback.
Alerts.sounds = {
    { key = "raid",  name = "Raid warning", id = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959 },
    { key = "ready", name = "Ready check",  id = SOUNDKIT and SOUNDKIT.READY_CHECK or 8960 },
    { key = "alarm", name = "Alarm clock",  id = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889 },
    { key = "none",  name = "No sound" },
}

local timer

local function SoundID(key)
    for _, s in ipairs(Alerts.sounds) do
        if s.key == key then return s.id end
    end
end

function Alerts.PlaySound(key)
    local id = SoundID(key or Kindle.db.expirySound)
    -- "Master" so it's heard even with sound effects turned down.
    if id then PlaySound(id, "Master") end
end

local function Warn(expires)
    timer = nil
    Kindle.db.warnedFor = math.floor(expires)
    local left = math.max(1, math.floor((expires - GetTime()) / 60 + 0.5))
    local text = format("Your camp bonuses run out in %d minute%s.", left, left == 1 and "" or "s")
    Alerts.PlaySound()
    Kindle.Print(text)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.55, 0.1) end
end

-- (Re)sets the timer from the current bonuses. Call when camp auras or the setting change.
function Alerts.Schedule()
    if timer then timer:Cancel(); timer = nil end
    local minutes = Kindle.db.expiryWarning or 0
    if minutes <= 0 then return end
    local expires = Kindle.Detect.BonusExpires()
    local now = GetTime()
    if expires <= now or Kindle.db.warnedFor == math.floor(expires) then return end
    -- Already inside the warning window (e.g. logging in with 3 minutes left): warn now.
    timer = C_Timer.NewTimer(math.max(0.5, expires - minutes * 60 - now), function() Warn(expires) end)
end
