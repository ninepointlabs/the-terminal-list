-- A small crosshair on the target frame's portrait when the target is listed,
-- a heart when they're one of the Good Folk.
local _, ns = ...

local Target = {}
ns.Target = Target

local mark -- false = no target frame on this client

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
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:Hide()
    mark = m
    return mark
end

function Target.Update()
    local m = build()
    local e, which
    if ns.db then e, which = ns.Alert.Check("target", "target") end
    local show = e ~= nil and ns.DB.Settings().target
    if m then
        m.entry, m.which = e, which
        m.tex:SetTexture(which == "good" and ns.HEART or ns.CROSSHAIR)
        m:SetShown(show and true or false)
    end
    return show
end

function Target.Mark() return build() end
