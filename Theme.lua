-- Kindle: looks. One palette per theme; every Kindle frame registers a styling function and Theme.Apply()
-- re-runs them all, so switching theme is live and fully reversible.
--
--   blizzard  the normal WoW look: tooltip borders, gold titles, action-slot buttons.
--   dark      flat near-black panels with grey 1px borders.
--   class     flat dark panels, borders and titles in your class colour.
--   eui       EllesmereUI's look (only when EllesmereUI is loaded): its panel colour, accent and font, read through
--             its skinning API (EllesmereUI/SKINNING_API.md) and kept in sync with live accent changes.
--   naowh     the NaowhUI look (only when NaowhUI is loaded): EllesmereUI's flat style with Naowh blue (#00CFFF)
--             and the Naowh font from NaowhUI_Media.
--
-- We never skin with EUI's primitives: they fade art for good, so switching away again would need a /reload.

local _, Kindle = ...

local Theme = { styled = {} }
Kindle.Theme = Theme

local WHITE = "Interface\\Buttons\\WHITE8x8"
local NAOWH_FONT = "Interface\\AddOns\\NaowhUI_Media\\Shared\\Fonts\\Naowh.ttf"
local NAOWH_BLUE = { 0, 0xCF / 255, 1 }

local eui -- the S table from EllesmereUI.RegisterSkin, when EUI runs our skin callback

local function Loaded(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(addon) end
    return IsAddOnLoaded and IsAddOnLoaded(addon)
end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return { c.r, c.g, c.b } end
    return { 1, 0.82, 0 }
end

local function EuiAccent()
    if eui and eui.GetAccentColor then return { eui.GetAccentColor() } end
    local g = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if g then return { g.r, g.g, g.b } end
    return { 12 / 255, 210 / 255, 157 / 255 }
end

local function EuiPanel()
    if eui and eui.GetPanelColor then
        local r, g, b, a = eui.GetPanelColor()
        return { r, g, b, a or 0.95 }
    end
    return { 0.05, 0.05, 0.05, 0.95 }
end

local function EuiFont()
    if eui and eui.GetFont then
        local path = eui.GetFont()
        if path then return path end
    end
    return EllesmereUI and EllesmereUI.EXPRESSWAY
end

---------------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------------

-- A palette: flat (1px borders) or not; bg, border, accent, text colours; font path (nil: the game's font).
Theme.list = {
    { key = "blizzard", name = "WoW", palette = function()
        return { flat = false, bg = { 0, 0, 0, 0.8 }, border = { 0.8, 0.8, 0.8, 1 }, accent = { 1, 0.82, 0 },
            text = { 1, 1, 1 }, muted = { 0.7, 0.7, 0.7 } }
    end },
    { key = "dark", name = "Dark", palette = function()
        return { flat = true, bg = { 0.06, 0.06, 0.07, 0.92 }, border = { 0.22, 0.22, 0.24, 1 },
            accent = { 0.9, 0.9, 0.9 }, text = { 0.92, 0.92, 0.92 }, muted = { 0.55, 0.55, 0.58 },
            font = "Fonts\\ARIALN.TTF" }
    end },
    { key = "class", name = "Class colour", palette = function()
        local c = ClassColor()
        return { flat = true, bg = { 0.06, 0.06, 0.07, 0.92 }, border = { c[1], c[2], c[3], 1 }, accent = c,
            text = { 0.95, 0.95, 0.95 }, muted = { 0.6, 0.6, 0.6 }, font = "Fonts\\ARIALN.TTF" }
    end },
    { key = "eui", name = "EllesmereUI", needs = "EllesmereUI",
        available = function() return Loaded("EllesmereUI") end,
        palette = function()
            local a = EuiAccent()
            return { flat = true, bg = EuiPanel(), border = { 0, 0, 0, 1 }, accent = a, hover = a,
                text = { 1, 1, 1 }, muted = { 0.6, 0.6, 0.6 }, font = EuiFont() }
        end },
    { key = "naowh", name = "NaowhUI", needs = "NaowhUI",
        available = function() return Loaded("NaowhUI_EUI") or Loaded("NaowhUI_Media") or Loaded("NaowhUI") end,
        palette = function()
            return { flat = true, bg = { 0.04, 0.045, 0.05, 0.95 }, border = { 0, 0, 0, 1 }, accent = NAOWH_BLUE,
                hover = NAOWH_BLUE, text = { 1, 1, 1 }, muted = { 0.6, 0.6, 0.6 },
                font = Loaded("NaowhUI_Media") and NAOWH_FONT or EuiFont() }
        end },
}
Theme.byKey = {}
for _, t in ipairs(Theme.list) do Theme.byKey[t.key] = t end

function Theme.Available(key)
    local t = Theme.byKey[key]
    return t ~= nil and (not t.available or t.available() and true or false)
end

-- The theme in use: the saved one if it's available. With none saved: NaowhUI, else EllesmereUI, if loaded,
-- so Kindle matches your UI out of the box; else WoW.
function Theme.Current()
    local key = Kindle.db and Kindle.db.theme
    if key and Theme.Available(key) then return key end
    if not key then
        if Theme.Available("naowh") then return "naowh" end
        if Theme.Available("eui") then return "eui" end
    end
    return "blizzard"
end

-- The current palette. Built once and kept until Theme.Apply (theme change, EUI accent change) builds it again.
local palette
local function Build()
    palette = Theme.byKey[Theme.Current()].palette()
    palette.hover = palette.hover or palette.accent
    return palette
end

function Theme.Palette()
    return palette or Build()
end

---------------------------------------------------------------------------
-- Styling
---------------------------------------------------------------------------

-- Registers fn(palette) to style obj now and on every theme change.
function Theme.Register(obj, fn)
    Theme.styled[#Theme.styled + 1] = fn
    fn(Theme.Palette())
    return obj
end

-- The bar holds secure buttons, so restyling (sizes, backdrops) waits for combat to end.
local waiting
function Theme.Apply()
    if InCombatLockdown() then
        if not waiting then
            waiting = CreateFrame("Frame")
            waiting:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                Theme.Apply()
            end)
        end
        waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local p = Build()
    for _, fn in ipairs(Theme.styled) do fn(p) end
end

-- Panel backdrop on a BackdropTemplate frame.
function Theme.Backdrop(frame, p, bg)
    if not frame.SetBackdrop then return end
    if p.flat then
        frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    local c = bg or p.bg
    frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    frame:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], p.border[4] or 1)
end

-- Sets a FontString's font to the theme's at this size. flags: e.g. "OUTLINE".
function Theme.Font(fs, p, size, flags, color)
    local path = p.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if not fs:SetFont(path, size, flags or "") then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags or "")
    end
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
end

-- 1px border made of four textures, for frames that can't take a backdrop (secure buttons).
function Theme.AddEdges(frame, layer)
    local e = {}
    for i = 1, 4 do
        e[i] = frame:CreateTexture(nil, layer or "OVERLAY", nil, 7)
        e[i]:SetTexture(WHITE)
    end
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
    function e:SetColor(r, g, b, a) for i = 1, 4 do self[i]:SetVertexColor(r, g, b, a or 1) end end
    function e:SetShown(shown) for i = 1, 4 do self[i]:SetShown(shown) end end
    return e
end

---------------------------------------------------------------------------
-- EllesmereUI hookup
---------------------------------------------------------------------------

-- EUI runs this at login when its third-party skinning is on for Kindle. We only keep S for its colour and
-- font getters, and restyle when the user changes their EUI accent.
if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin("Kindle", function(S)
        eui = S
        if S.OnLooksChanged then S.OnLooksChanged(function() Theme.Apply() end) end
        Theme.Apply()
    end)
end
