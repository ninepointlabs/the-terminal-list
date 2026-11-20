-- A small crosshair on the target frame's portrait when the target is listed.
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
        GameTooltip:SetText(ns.TITLE, ns.MARK_COLOR[1], ns.MARK_COLOR[2], ns.MARK_COLOR[3])
        ns.Tooltip.AddEntryLines(GameTooltip, e)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:Hide()
    mark = m
    return mark
end

function Target.Update()
    local m = build()
    local e = ns.db and ns.Alert.Check("target", "target")
    local show = e ~= nil and ns.DB.Settings().target
    if m then
        m.entry = e
        m:SetShown(show and true or false)
    end
    return show
end

function Target.Mark() return build() end
