-- A small crosshair on the target frame's portrait when the target is listed,
-- a heart when they're one of the Good Folk, and a number badge (times grouped
-- together) beside it, or on its own for someone on neither list.
local _, ns = ...

local Target = {}
ns.Target = Target

local mark -- false = no target frame on this client
local badge

local function build()
    if mark ~= nil then return mark end
    local frame = TargetFrame
    local portrait = frame and (frame.portrait or TargetFramePortrait
        or (frame.TargetFrameContainer and frame.TargetFrameContainer.Portrait))
    if not portrait then
        mark = false
        return mark
    end
    local m = CreateFrame("Frame", "TheTerminalListTargetMark", frame)
    m:SetSize(26, 26)
    m:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 6)
    m:SetPoint("TOPLEFT", portrait, "TOPLEFT", -4, 4)
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    m.tex:SetTexture(ns.CROSSHAIR)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.which == "good" then
            GameTooltip:SetText("Good Folk", ns.GOOD_COLOR[1], ns.GOOD_COLOR[2], ns.GOOD_COLOR[3])
        else
            GameTooltip:SetText(ns.TITLE, ns.MARK_COLOR[1], ns.MARK_COLOR[2], ns.MARK_COLOR[3])
        end
        ns.Tooltip.AddEntryLines(GameTooltip, e, self.which)
        if self.key then ns.Tooltip.AddGroupLines(GameTooltip, self.key) end
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:Hide()
    mark = m

    badge = ns.Groups.MakeBadge(frame, 18)
    badge:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 6)
    badge.portrait = portrait
    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(self)
        if not self.key then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Past groups", ns.GROUP_COLOR[1], ns.GROUP_COLOR[2], ns.GROUP_COLOR[3])
        ns.Tooltip.AddGroupLines(GameTooltip, self.key)
        GameTooltip:AddLine("Right-click their portrait: Group history", 0.75, 0.75, 0.8, true)
        GameTooltip:Show()
    end)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return mark
end

-- Returns markShown, count (the number badge shown, or nil).
function Target.Update()
    local m = build()
    local e, which, key
    if ns.db then e, which, key = ns.Alert.Check("target", "target") end
    local on = ns.db and ns.DB.Settings().target
    local show = e ~= nil and on and true or false
    local count = on and key and ns.Groups.BadgeCount(key, which) or nil
    if m then
        m.entry, m.which, m.key = e, which, key
        m.tex:SetTexture(which == "good" and ns.HEART or ns.CROSSHAIR)
        m:SetShown(show)
        badge.key = count and key or nil
        if count then
            badge:SetCount(count)
            badge:ClearAllPoints()
            -- Beside the mark when there is one, else where the mark would sit.
            if show then badge:SetPoint("LEFT", m, "RIGHT", 1, 0)
            else badge:SetPoint("TOPLEFT", badge.portrait, "TOPLEFT", -4, 2) end
            badge:Show()
        else
            badge:Hide()
        end
    end
    return show, count
end

function Target.Mark() return build() end
function Target.Badge() build() return badge or nil end
