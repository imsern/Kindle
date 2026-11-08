-- Kindle: share what a camp has with your party or raid, so groupmates with Kindle get the camp rating without
-- hovering every object themselves.
--
-- Hidden addon messages (prefix "Kindle"), never chat. Two messages:
--   C|<where>|<bonus>=<tier>,...   what I know about the camp I'm at
--   Q|<where>                      I just arrived at a camp: anyone there, tell me what it has
-- <where> is my position, so a receiver only takes camp info for the camp it's at itself:
--   w<instance>,<x>,<y>   world position in yards (UnitPosition), within RANGE yards counts as the same camp;
--   m<mapID>,<x>,<y>      map position (0-1) where UnitPosition isn't available, within MAP_RANGE.
-- Incoming data is checked: only known camp bonuses with tier 1-3 are taken. Sending is throttled, and skipped in
-- instances, outside a group and while the game locks addon messages.

local _, Kindle = ...

local Share = {}
Kindle.Share = Share

local PREFIX = "Kindle"
local RANGE = 40         -- yards
local MAP_RANGE = 0.01   -- map units
local SEND_DELAY = 2     -- seconds: learning several objects in a row sends once
local ASK_COOLDOWN = 15  -- seconds between "what does this camp have?" questions
local REPLY_COOLDOWN = 5

local sendQueued, lastAsk, lastReply = false, 0, 0

---------------------------------------------------------------------------
-- Where am I
---------------------------------------------------------------------------

local IsSecret = Kindle.IsSecret

local function Position()
    local y, x, _, instance = UnitPosition("player")
    if y and x and instance and not (IsSecret(y) or IsSecret(x) or IsSecret(instance)) then
        return format("w%d,%d,%d", instance, x, y)
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local mx, my = pos:GetXY()
        if mx and not (IsSecret(mx) or IsSecret(my)) then return format("m%d,%.4f,%.4f", mapID, mx, my) end
    end
end

-- Is the sender's position <where> at the same camp as me?
local function Near(where)
    local mine = Position()
    if not (mine and where) then return false end
    local k1, a1, x1, y1 = mine:match("^(%a)(%d+),([%d%.%-]+),([%d%.%-]+)$")
    local k2, a2, x2, y2 = where:match("^(%a)(%d+),([%d%.%-]+),([%d%.%-]+)$")
    if not k1 or k1 ~= k2 or a1 ~= a2 then return false end
    local dx, dy = tonumber(x1) - tonumber(x2), tonumber(y1) - tonumber(y2)
    local range = k1 == "w" and RANGE or MAP_RANGE
    return dx * dx + dy * dy <= range * range
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function Channel()
    if not Kindle.db.share or IsInInstance() then return nil end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Send(msg)
    local channel = Channel()
    if not channel then return end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
end

local function SendCamp()
    sendQueued = false
    if not Kindle.Detect.inCamp then return end
    local parts = {}
    for id, tier in pairs(Kindle.Advice.camp) do parts[#parts + 1] = id .. "=" .. tier end
    local where = Position()
    if #parts == 0 or not where then return end
    Send("C|" .. where .. "|" .. table.concat(parts, ","))
end

-- Called when Kindle learns something about the camp you're at.
function Share.QueueSend()
    if sendQueued or not Channel() then return end
    sendQueued = true
    C_Timer.After(SEND_DELAY, SendCamp)
end

-- Called on arriving at a camp: ask groupmates already there.
function Share.Ask()
    local now = GetTime()
    if now - lastAsk < ASK_COOLDOWN or not Channel() then return end
    lastAsk = now
    -- A moment after arriving, so our position is settled inside the camp.
    C_Timer.After(1, function()
        local where = Kindle.Detect.inCamp and Position()
        if where then Send("Q|" .. where) end
    end)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local function FromMe(sender)
    return Ambiguate(sender, "none") == UnitName("player")
end

local function OnMessage(text, sender)
    if not Kindle.db.share or not Kindle.Detect.inCamp then return end
    local kind, where, data = strsplit("|", text, 3)
    if not Near(where) then return end
    if kind == "Q" then
        local now = GetTime()
        if now - lastReply >= REPLY_COOLDOWN and next(Kindle.Advice.camp) then
            lastReply = now
            Share.QueueSend()
        end
    elseif kind == "C" and data then
        local name = Ambiguate(sender, "short")
        for pair in data:gmatch("[^,]+") do
            local id, tier = pair:match("^(%d+)=(%d)$")
            id, tier = tonumber(id), tonumber(tier)
            if id and tier and tier >= 1 and tier <= 3 then
                Kindle.Advice.LearnShared(id, tier, name)
            end
        end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
    if IsSecret(prefix) or prefix ~= PREFIX or IsSecret(text) or IsSecret(sender) then return end
    if type(text) ~= "string" or type(sender) ~= "string" or FromMe(sender) then return end
    OnMessage(text, sender)
end)

function Share.Init()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage) then return end
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    events:RegisterEvent("CHAT_MSG_ADDON")
end
