-- Crosshair beside a listed player's nameplate (Tim chose the crosshair, 2026-11-20),
-- a heart beside one of the Good Folk.
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

local function markFor(plate)
    if plate.ttlMark then return plate.ttlMark end
    local m = CreateFrame("Frame", nil, plate)
    m:SetSize(22, 22)
    m:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 1) + 10)
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    local uf = plate.UnitFrame
    local name = uf and (uf.name or uf.Name)
    if name then m:SetPoint("RIGHT", name, "LEFT", -2, 0) else m:SetPoint("BOTTOM", plate, "TOP", 0, 2) end
    m:Hide()
    plate.ttlMark = m
    return m
end

function Plates.Update(unit)
    local plate = plateFor(unit)
    if not plate then return false end
    local e, which
    if ns.db then e, which = ns.Alert.Check(unit, "nameplate") end
    local show = e ~= nil and ns.DB.Settings().nameplate
    if show then
        local m = markFor(plate)
        m.tex:SetTexture(which == "good" and ns.HEART or ns.CROSSHAIR)
        m:Show()
    elseif plate.ttlMark then
        plate.ttlMark:Hide()
    end
    return show
end

function Plates.Removed(unit)
    local plate = plateFor(unit)
    if plate and plate.ttlMark then plate.ttlMark:Hide() end
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
