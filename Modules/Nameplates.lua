-- Crosshair beside a listed player's nameplate (Tim chose the crosshair, 2026-11-20),
-- a heart beside one of the Good Folk, and a number badge (times grouped
-- together) for anyone with past groups: alone, beside the heart, or (only
-- with groupBadgeList on) beside the crosshair.
--
-- Uses Blizzard's own nameplates through C_NamePlate.GetNamePlateForUnit (the
-- same route installed Forever addons take); no Plater or BetterBlizzPlates.
-- Forbidden plates (the game can lock some) are skipped quietly. Nameplates
-- only exist at fairly close range, so this is a "nearby" mark.
local _, ns = ...

local Plates = {}
ns.Nameplates = Plates

function Plates.Available()
    return C_NamePlate ~= nil and type(C_NamePlate.GetNamePlateForUnit) == "function"
end

local function plateFor(unit)
    if not Plates.Available() then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or ns.Secret(plate) then return nil end
    if plate.IsForbidden and plate:IsForbidden() then return nil end
    return plate
end

local function nameOf(plate)
    local uf = plate.UnitFrame
    return uf and (uf.name or uf.Name)
end

local function markFor(plate)
    if plate.ttlMark then return plate.ttlMark end
    local m = CreateFrame("Frame", nil, plate)
    m:SetSize(22, 22)
    m:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 1) + 10)
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    m:Hide()
    plate.ttlMark = m
    return m
end

local function badgeFor(plate)
    if plate.ttlCount then return plate.ttlCount end
    local b = ns.Groups.MakeBadge(plate, 16)
    b:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 1) + 10)
    plate.ttlCount = b
    return b
end

-- Right to left from the name: [mark] [count] Name. Either can be missing.
local function place(plate, m, b)
    local name = nameOf(plate)
    local anchor, point = name, "LEFT"
    if b then
        b:ClearAllPoints()
        if name then b:SetPoint("RIGHT", name, "LEFT", -3, 0) else b:SetPoint("BOTTOM", plate, "TOP", 0, 2) end
        anchor, point = b, "LEFT"
    end
    if m then
        m:ClearAllPoints()
        if anchor then m:SetPoint("RIGHT", anchor, point, -2, 0) else m:SetPoint("BOTTOM", plate, "TOP", 0, 2) end
    end
end

-- Returns markShown, count (the number badge shown, or nil).
function Plates.Update(unit)
    local plate = plateFor(unit)
    if not plate then return false end
    local e, which, key
    if ns.db then e, which, key = ns.Alert.Check(unit, "nameplate") end
    local on = ns.db and ns.DB.Settings().nameplate
    local show = e ~= nil and on and true or false
    local count = on and key and ns.Groups.BadgeCount(key, which) or nil
    local m = show and markFor(plate) or nil
    local b = count and badgeFor(plate) or nil
    if m then
        m.tex:SetTexture(which == "good" and ns.HEART or ns.CROSSHAIR)
        m:Show()
    elseif plate.ttlMark then
        plate.ttlMark:Hide()
    end
    if b then
        b:SetCount(count)
        b:Show()
    elseif plate.ttlCount then
        plate.ttlCount:Hide()
    end
    place(plate, m, b)
    return show, count
end

function Plates.Removed(unit)
    local plate = plateFor(unit)
    if plate and plate.ttlMark then plate.ttlMark:Hide() end
    if plate and plate.ttlCount then plate.ttlCount:Hide() end
end

function Plates.UpdateAll()
    if not (Plates.Available() and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and not ns.Secret(unit) then pcall(Plates.Update, unit) end
    end
end
