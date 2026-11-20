-- Theme + widget kit + a pooled layout, slimmed from the sister addons
-- (their UI/Widgets.lua): same colours, type and cards; no spec accent,
-- columns, item/spell rows or "Sources & notes" (this addon has no research data).
local _, ns = ...

local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8x8"
UI.WHITE = WHITE

UI.C = {
    bg = { 0.051, 0.051, 0.078, 0.98 },
    head = { 0.063, 0.063, 0.094, 1 },
    side = { 0.059, 0.059, 0.090, 1 },
    card = { 0.086, 0.086, 0.122, 1 },
    cardHover = { 0.122, 0.122, 0.169, 1 },
    border = { 0.165, 0.165, 0.220, 1 },
    softBorder = { 0.137, 0.137, 0.184, 1 },
    text = { 0.925, 0.925, 0.953 },
    dim = { 0.640, 0.640, 0.722 },
    label = { 0.608, 0.608, 0.690 },
    good = { 0.431, 0.906, 0.627 },
    goodBg = { 0.071, 0.196, 0.110, 1 },
    bad = { 1.00, 0.40, 0.40 },
    badge = { 0.898, 0.282, 0.302, 1 },
    warn = { 1.00, 0.757, 0.302 },
    warnBg = { 0.227, 0.165, 0.063, 1 },
    info = { 0.620, 0.773, 1.00 },
    infoBg = { 0.114, 0.145, 0.251, 1 },
    neutralBg = { 0.137, 0.137, 0.184, 1 },
    -- The list's accent: the crosshair's red.
    accent = { 0.92, 0.19, 0.19, 1 },
}

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Accent()
    return UI.C.accent
end

-- Class colour for a class token, or the normal text colour.
function UI.ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return UI.Hex({ c.r, c.g, c.b }) end
    return UI.Hex(UI.C.text)
end

function UI.Backdrop(frame, bg, border)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(bg or UI.C.card))
    frame:SetBackdropBorderColor(unpack(border or UI.C.border))
end

local FONT = "Fonts\\FRIZQT__.TTF"
function UI.Font(fs, size, flags)
    fs:SetFont(FONT, size or 13, flags or "")
    return fs
end

function UI.Text(parent, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    UI.Font(fs, size or 13)
    fs:SetTextColor(unpack(color or UI.C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

-- Flat button with hover + optional accent.
function UI.Button(parent, label, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 28)
    UI.Backdrop(b, { 0.125, 0.125, 0.169, 1 }, { 0.227, 0.227, 0.298, 1 })
    b.label = UI.Text(b, 12)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetWordWrap(false)
    b.label:SetText(label or "")
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(UI.C.cardHover))
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.active and UI.C.cardHover or { 0.125, 0.125, 0.169, 1 }))
        GameTooltip:Hide()
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:SetActive(on)
        self.active = on
        self:SetBackdropColor(unpack(on and UI.C.cardHover or { 0.125, 0.125, 0.169, 1 }))
        self:SetBackdropBorderColor(unpack(on and UI.Accent() or { 0.227, 0.227, 0.298, 1 }))
        self.label:SetTextColor(unpack(on and { 1, 1, 1 } or UI.C.text))
    end
    return b
end

-- Small pill (text with a coloured background).
local CHIP = {
    good = { UI.C.goodBg, UI.C.good }, warn = { UI.C.warnBg, UI.C.warn },
    info = { UI.C.infoBg, UI.C.info }, neutral = { UI.C.neutralBg, UI.C.dim },
    bad = { { 0.24, 0.07, 0.08, 1 }, UI.C.bad },
}
UI.CHIP = CHIP

----------------------------------------------------------------------------
-- Layout: pooled flow inside a scroll child.
----------------------------------------------------------------------------
local Layout = {}
Layout.__index = Layout
UI.Layout = Layout

function UI.NewLayout(content, width)
    return setmetatable({ content = content, width = width, x = 0, y = 0, pools = {}, used = {} }, Layout)
end

function Layout:Acquire(kind, make)
    self.pools[kind] = self.pools[kind] or {}
    self.used[kind] = (self.used[kind] or 0) + 1
    local obj = self.pools[kind][self.used[kind]]
    if not obj then
        obj = make()
        self.pools[kind][self.used[kind]] = obj
    end
    obj:ClearAllPoints()
    obj:Show()
    return obj
end

function Layout:Reset(width)
    for _, pool in pairs(self.pools) do
        for _, obj in ipairs(pool) do obj:Hide() end
    end
    self.used = {}
    self.y, self.x = 0, 0
    if width then self.width = width end
end

function Layout:Finish()
    self.content:SetHeight(math.max(1, self.y + 16))
end

function Layout:Space(h)
    self.y = self.y + (h or 8)
end

local GAP = 6

-- Plain paragraph. opts: size, color, indent, gap
function Layout:Text(text, opts)
    opts = opts or {}
    local fs = self:Acquire("text", function() return UI.Text(self.content, 13) end)
    UI.Font(fs, opts.size or 13)
    fs:SetTextColor(unpack(opts.color or UI.C.text))
    local indent = opts.indent or 0
    fs:SetWidth(self.width - indent)
    fs:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + indent, -self.y)
    fs:SetText(text or "")
    self.y = self.y + fs:GetStringHeight() + (opts.gap or GAP)
    return fs
end

-- Section label: small uppercase dim text.
function Layout:Label(text, color)
    self:Space(4)
    return self:Text((text or ""):upper(), { size = 11, color = color or UI.C.label, gap = 8 })
end

function Layout:Title(text, sub)
    local fs = self:Text(text, { size = 20, gap = 4 })
    if sub then self:Text(sub, { color = UI.C.dim, size = 13 }) end
    self:Space(4)
    return fs
end

-- Inline warning (only for things the player must know right here).
function Layout:Flag(text)
    return self:Text(UI.Hex(UI.C.warn) .. "!|r  " .. UI.Hex(UI.C.warn) .. text .. "|r", { size = 12 })
end

-- Sub-tab bar. items: { {label, active, onClick, badge} }
function Layout:Tabs(items)
    local x, h = 0, 28
    for _, it in ipairs(items) do
        local b = self:Acquire("tab", function()
            local t = CreateFrame("Button", nil, self.content, "BackdropTemplate")
            UI.Backdrop(t, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
            t.label = UI.Text(t, 12)
            t.label:SetPoint("CENTER")
            t.label:SetWordWrap(false)
            t:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropColor(0.11, 0.11, 0.15, 1) s.label:SetTextColor(1, 1, 1) end end)
            t:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropColor(0, 0, 0, 0) s.label:SetTextColor(unpack(UI.C.dim)) end end)
            return t
        end)
        b.active = it.active
        b.label:SetText(it.label .. (it.badge and it.badge > 0 and ("  " .. UI.Hex(UI.C.bad) .. it.badge .. "|r") or ""))
        local w = b.label:GetStringWidth() + 28
        b:SetSize(w, h)
        b:SetBackdropColor(unpack(it.active and { 0.122, 0.122, 0.169, 1 } or { 0, 0, 0, 0 }))
        b.label:SetTextColor(unpack(it.active and { 1, 1, 1 } or UI.C.dim))
        b:SetScript("OnClick", it.onClick)
        if x + w > self.width then
            x = 0
            self.y = self.y + h + 4
        end
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + x, -self.y)
        x = x + w + 4
    end
    self.y = self.y + h + 6
    local line = self:Acquire("rule", function()
        local t = self.content:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE)
        return t
    end)
    line:SetColorTexture(unpack(UI.C.softBorder))
    line:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, -self.y)
    line:SetSize(self.width, 1)
    self.y = self.y + 14
end

-- Row: chip, icon, title, subtitle, right text, up to two buttons.
-- opts: icon, title, sub, right, chip={text,kind}, buttons={{label,onClick,tip}}, button={...},
--       onClick, onEnter, tint
function Layout:Row(opts)
    local row = self:Acquire("row", function()
        local f = CreateFrame("Button", nil, self.content, "BackdropTemplate")
        UI.Backdrop(f, UI.C.card, UI.C.softBorder)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(30, 30)
        f.chip = CreateFrame("Frame", nil, f, "BackdropTemplate")
        UI.Backdrop(f.chip, UI.C.neutralBg, { 0, 0, 0, 0 })
        f.chip:SetHeight(18)
        f.chip.text = UI.Text(f.chip, 11)
        f.chip.text:SetPoint("CENTER")
        f.chip.text:SetWordWrap(false)
        f.title = UI.Text(f, 13)
        f.sub = UI.Text(f, 12, UI.C.dim)
        f.right = UI.Text(f, 12)
        f.right:SetJustifyH("RIGHT")
        f.right:SetWordWrap(false)
        f.btns = { UI.Button(f, "", 80, 24), UI.Button(f, "", 80, 24) }
        f:SetScript("OnEnter", function(s)
            if s.onClick then s:SetBackdropColor(unpack(UI.C.cardHover)) end
            if s.onEnter then s.onEnter(s) end
        end)
        f:SetScript("OnLeave", function(s)
            s:SetBackdropColor(unpack(UI.C.card))
            GameTooltip:Hide()
        end)
        f:SetScript("OnClick", function(s) if s.onClick then s.onClick(s) end end)
        return f
    end)
    local width = opts.width or self.width
    row.onClick, row.onEnter = opts.onClick, opts.onEnter
    row:SetBackdropBorderColor(unpack(opts.tint or UI.C.softBorder))
    local left = 12
    if opts.chip then
        local kind = CHIP[opts.chip.kind or "neutral"] or CHIP.neutral
        row.chip:SetBackdropColor(unpack(kind[1]))
        row.chip.text:SetTextColor(unpack(kind[2]))
        row.chip.text:SetText(opts.chip.text)
        row.chip:SetWidth(row.chip.text:GetStringWidth() + 16)
        row.chip:ClearAllPoints()
        row.chip:SetPoint("TOPLEFT", row, "TOPLEFT", left, -9)
        row.chip:Show()
        left = left + row.chip:GetWidth() + 10
    else
        row.chip:Hide()
    end
    if opts.icon then
        row.icon:SetTexture(opts.icon)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", left, -7)
        row.icon:Show()
        left = left + 40
    else
        row.icon:Hide()
    end
    local buttons = opts.buttons or (opts.button and { opts.button }) or {}
    local rightW, anchor = 0, nil
    for i, b in ipairs(row.btns) do
        local spec = buttons[#buttons - i + 1] -- right to left
        if spec then
            b.label:SetText(spec.label)
            b:SetWidth(b.label:GetStringWidth() + 24)
            b:SetScript("OnClick", spec.onClick)
            b.tip = spec.tip
            b:ClearAllPoints()
            if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) else b:SetPoint("RIGHT", row, "RIGHT", -10, 0) end
            b:Show()
            anchor = b
            rightW = rightW + b:GetWidth() + (i == 1 and 14 or 6)
        else
            b:Hide()
        end
    end
    row.right:SetText(opts.right or "")
    row.right:ClearAllPoints()
    row.right:SetPoint("TOPRIGHT", -(10 + rightW), -10)
    if opts.right and opts.right ~= "" then rightW = rightW + math.min(row.right:GetStringWidth() + 14, 220) end
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", left, -9)
    row.title:SetWidth(width - left - 10 - rightW)
    row.title:SetText(opts.title or "")
    row.sub:ClearAllPoints()
    row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.sub:SetWidth(width - left - 10 - rightW)
    row.sub:SetText(opts.sub or "")
    local h = 9 + row.title:GetStringHeight() + (opts.sub and opts.sub ~= "" and (3 + row.sub:GetStringHeight()) or 0) + 9
    h = math.max(h, opts.icon and 44 or 34, #buttons > 0 and 38 or 0)
    row:SetSize(width, h)
    row:SetPoint("TOPLEFT", self.content, "TOPLEFT", opts.x or self.x, -(opts.y or self.y))
    if not opts.y then self.y = self.y + h + GAP end
    return row, h
end

-- A row of buttons. items: { {label, active, onClick, tip} }
function Layout:Buttons(items, width)
    local x, h = 0, 28
    for _, it in ipairs(items) do
        local b = self:Acquire("btn", function() return UI.Button(self.content, "", 100, 28) end)
        b.label:SetText(it.label)
        local w = width or (b.label:GetStringWidth() + 28)
        b:SetSize(w, h)
        b.tip = it.tip
        b:SetScript("OnClick", it.onClick)
        b:SetActive(it.active)
        if x + w > self.width then
            x = 0
            self.y = self.y + h + GAP
        end
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x + x, -self.y)
        x = x + w + 8
    end
    self.y = self.y + h + GAP + 2
end

-- Checkbox line for settings.
function Layout:Check(label, checked, onToggle, tip)
    local cb = self:Acquire("check", function()
        local c = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
        c:SetSize(24, 24)
        c.text = UI.Text(c, 13)
        c.text:SetPoint("LEFT", c, "RIGHT", 6, 0)
        c.text:SetWordWrap(false)
        c:SetScript("OnEnter", function(s)
            if s.tip then
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.tip, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return c
    end)
    cb:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.x, -self.y)
    cb.text:SetText(label)
    cb:SetChecked(checked and true or false)
    if cb.Enable then cb:Enable() end
    cb.tip = tip
    cb:SetScript("OnClick", function(s) onToggle(s:GetChecked() and true or false) end)
    self.y = self.y + 28
    return cb
end

function Layout:Link(title, url, sub)
    return self:Row({
        title = title, sub = sub or url,
        button = { label = "Copy link", onClick = function() UI.CopyURL(url) end },
    })
end
