-- Kindle: small themed widgets for Kindle's own windows (settings, welcome). Every widget restyles itself through
-- Theme.Register, so a theme change repaints open windows live. None of them are secure frames.

local _, Kindle = ...

local W = {}
Kindle.Widgets = W

local Theme -- Kindle.Theme, set on first use (Theme.lua loads after this file's definitions are read)

local function T()
    Theme = Theme or Kindle.Theme
    return Theme
end

local function Lighter(c, by)
    return { math.min(1, c[1] + by), math.min(1, c[2] + by), math.min(1, c[3] + by), 1 }
end

-- Background and border of a clickable box (button, checkbox, segment) for a state.
local function PaintBox(f, p, state)
    T().Backdrop(f, p, p.flat and Lighter(p.bg, 0.06) or { 0.12, 0.12, 0.12, 0.95 })
    if state == "selected" then
        local a = p.accent
        f:SetBackdropColor(a[1] * 0.35, a[2] * 0.35, a[3] * 0.35, 1)
        f:SetBackdropBorderColor(a[1], a[2], a[3], 1)
    elseif state == "hover" then
        local h = p.hover
        f:SetBackdropBorderColor(h[1], h[2], h[3], 1)
    end
end

local function Hoverable(f)
    f:HookScript("OnEnter", function(self)
        if self:IsEnabled() and not self.selected then PaintBox(self, T().Palette(), "hover") end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    f:HookScript("OnLeave", function(self)
        PaintBox(self, T().Palette(), self.selected and "selected" or nil)
        GameTooltip:Hide()
    end)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- A movable, ESC-closable window with a title and a close button. Content goes in window.content.
function W.Window(name, title, width)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, 200)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, name)

    f.titleBar = f:CreateTexture(nil, "BORDER")
    f.titleBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.titleBar:SetPoint("TOPLEFT", 1, -1)
    f.titleBar:SetPoint("TOPRIGHT", -1, -1)
    f.titleBar:SetHeight(32)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("LEFT", f.titleBar, "LEFT", 14, 0)
    f.title:SetText(title)
    f.flame = f:CreateTexture(nil, "OVERLAY")
    f.flame:SetSize(18, 18)
    f.flame:SetPoint("RIGHT", f.title, "LEFT", -6, 0)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", 0, 0)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() close.text:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() local p = T().Palette() close.text:SetTextColor(unpack(p.muted)) end)

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", 18, -46)
    f.content:SetPoint("BOTTOMRIGHT", -18, 14)

    T().Register(f, function(p)
        T().Backdrop(f, p)
        f.titleBar:SetShown(p.flat)
        f.titleBar:SetVertexColor(0, 0, 0, 0.35)
        if p.flat then
            f.title:ClearAllPoints()
            f.title:SetPoint("LEFT", f.titleBar, "LEFT", 14 + 22, 0)
        else
            f.title:ClearAllPoints()
            f.title:SetPoint("TOPLEFT", 14 + 22, -14)
        end
        T().Font(f.title, p, 15, nil, p.accent)
        T().Font(close.text, p, 14, nil, p.muted)
        f.flame:SetTexture(C_Spell and C_Spell.GetSpellTexture and
            C_Spell.GetSpellTexture(Kindle.Data.auras.welcoming) or 134400)
    end)
    return f
end

---------------------------------------------------------------------------
-- Layout helper: widgets stacked top to bottom in a parent
---------------------------------------------------------------------------

-- Returns a stacker: s:Add(widget, height, gapBefore) places widgets downwards; s.y is the used height.
function W.Stack(parent)
    local s = { parent = parent, y = 0, widgets = {} }
    function s:Add(w, height, gap)
        self.y = self.y + (gap or 8)
        w:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, -self.y)
        w:SetPoint("RIGHT", self.parent, "RIGHT", 0, 0)
        self.y = self.y + height
        self.widgets[#self.widgets + 1] = w
        return w
    end
    function s:Refresh()
        for _, w in ipairs(self.widgets) do if w.Refresh then w:Refresh() end end
    end
    return s
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

-- A section title with a thin rule under it.
function W.Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("BOTTOMLEFT", 0, 5)
    f.text:SetText(text)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.rule:SetPoint("BOTTOMLEFT")
    f.rule:SetPoint("BOTTOMRIGHT")
    f.rule:SetHeight(1)
    T().Register(f, function(p)
        T().Font(f.text, p, 13, nil, p.accent)
        f.rule:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 0.35)
    end)
    return f, 22
end

-- A wrapping paragraph. width: the parent's content width. Returns the frame and its height.
function W.Paragraph(parent, text, width, muted)
    local f = CreateFrame("Frame", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT")
    f.text:SetWidth(width)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(2)
    f.text:SetText(text)
    T().Register(f, function(p)
        T().Font(f.text, p, 12, nil, muted and p.muted or p.text)
        f:SetHeight(f.text:GetStringHeight())
    end)
    local h = f.text:GetStringHeight()
    f:SetHeight(h)
    return f, h
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

function W.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 26)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) onClick() end)
    Hoverable(b)
    T().Register(b, function(p)
        PaintBox(b, p)
        T().Font(b.text, p, 12, nil, p.flat and p.text or { 1, 0.82, 0 })
    end)
    return b
end

-- A checkbox row. get() returns the state; set(v) stores it.
function W.Checkbox(parent, label, get, set, tip)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(22)
    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT")
    box.check = box:CreateTexture(nil, "OVERLAY")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    row.text:SetText(label)
    row.tip = tip

    function row:Refresh() box.check:SetShown(get() and true or false) end
    row:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        set(not get())
        row:Refresh()
    end)
    row:SetScript("OnEnter", function()
        local p = T().Palette()
        box:SetBackdropBorderColor(p.hover[1], p.hover[2], p.hover[3], 1)
        if tip then
            GameTooltip:SetOwner(row, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        PaintBox(box, T().Palette())
        GameTooltip:Hide()
    end)
    T().Register(row, function(p)
        PaintBox(box, p)
        box.check:ClearAllPoints()
        if p.flat then
            box.check:SetTexture("Interface\\Buttons\\WHITE8x8")
            box.check:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1)
            box.check:SetPoint("TOPLEFT", 4, -4)
            box.check:SetPoint("BOTTOMRIGHT", -4, 4)
        else
            box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            box.check:SetVertexColor(1, 1, 1, 1)
            box.check:SetPoint("TOPLEFT", -4, 4)
            box.check:SetPoint("BOTTOMRIGHT", 4, -4)
        end
        T().Font(row.text, p, 12, nil, p.text)
    end)
    row:Refresh()
    return row, 22
end

-- A labelled slider. fmt(v) formats the value shown next to it.
function W.Slider(parent, label, min, max, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(40)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT")
    f.text:SetText(label)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.value:SetPoint("TOPRIGHT")

    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(12)
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 16)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * step) end)

    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        f.value:SetText(fmt and fmt(v) or tostring(v))
        if not updating and v ~= get() then set(v) end
    end)
    function f:Refresh()
        updating = true
        s:SetValue(get())
        updating = false
        f.value:SetText(fmt and fmt(get()) or tostring(get()))
    end
    T().Register(f, function(p)
        PaintBox(s, p)
        thumb:SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1)
        T().Font(f.text, p, 12, nil, p.text)
        T().Font(f.value, p, 12, nil, p.accent)
    end)
    f:Refresh()
    return f, 40
end

-- A label and a row of choice buttons (wrapping). options: { { value, text, disabled, tip } }.
function W.Choice(parent, label, options, width, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT")
    f.text:SetText(label)
    f.buttons = {}

    local x, y, rowH = 0, 20, 26
    for _, o in ipairs(options) do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("CENTER")
        b.text:SetText(o.text)
        local w = math.max(56, math.ceil(b.text:GetStringWidth()) + 22)
        if x > 0 and x + w > width then x, y = 0, y + rowH + 6 end
        b:SetSize(w, rowH)
        b:SetPoint("TOPLEFT", x, -y)
        x = x + w + 6
        b.option, b.tip = o, o.tip
        b:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            set(o.value)
            f:Refresh()
        end)
        Hoverable(b)
        f.buttons[#f.buttons + 1] = b
    end
    local height = y + rowH
    f:SetHeight(height)

    function f:Refresh()
        local p, current = T().Palette(), get()
        for _, b in ipairs(f.buttons) do
            local o = b.option
            local disabled = o.disabled and o.disabled()
            b.selected = (o.value == current)
            b:SetEnabled(not disabled)
            PaintBox(b, p, b.selected and "selected" or nil)
            local c = disabled and p.muted or (b.selected and { 1, 1, 1 } or p.text)
            T().Font(b.text, p, 12, nil, c)
            b:SetAlpha(disabled and 0.5 or 1)
        end
    end
    T().Register(f, function(p)
        T().Font(f.text, p, 12, nil, p.text)
        f:Refresh()
    end)
    return f, height
end
