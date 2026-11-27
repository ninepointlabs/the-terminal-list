-- A tooltip line on a listed player: crosshair, note, kill count, how added.
-- The Good Folk get a heart, "Good Folk" and their note, nothing about PvP.
-- Anyone with past groups (on a list or not) also gets "Grouped together N
-- times" and the last session's date, zone and dungeon.
local _, ns = ...

local Tip = {}
ns.Tooltip = Tip

-- which: "list" (default) or "good".
function Tip.AddEntryLines(tt, e, which)
    if which == "good" then
        local c = ns.GOOD_COLOR
        tt:AddLine(ns.HeartIcon(14) .. " Good Folk", c[1], c[2], c[3])
        if e.note and e.note ~= "" then tt:AddLine("\"" .. ns.Escape(e.note) .. "\"", 1, 1, 1, true) end
        tt:AddLine("Added " .. ns.List.DateText(e.added), 0.75, 0.75, 0.8, true)
        return
    end
    local r, g, b = ns.MARK_COLOR[1], ns.MARK_COLOR[2], ns.MARK_COLOR[3]
    tt:AddLine(ns.Icon(14) .. " On The Terminal List", r, g, b)
    if e.note and e.note ~= "" then tt:AddLine("\"" .. ns.Escape(e.note) .. "\"", 1, 1, 1, true) end
    local parts = {}
    if (e.kills or 0) > 0 then table.insert(parts, ("Killed you %d time%s"):format(e.kills, e.kills == 1 and "" or "s")) end
    if (e.assists or 0) > 0 then table.insert(parts, ("helped %d time%s"):format(e.assists, e.assists == 1 and "" or "s")) end
    table.insert(parts, ns.List.SourceLabel(e) .. ", " .. ns.List.DateText(e.added))
    tt:AddLine(table.concat(parts, " · "), 0.75, 0.75, 0.8, true)
end

-- Past-group lines for a key; false when there's no history.
function Tip.AddGroupLines(tt, key)
    local r = ns.Groups.Get(key)
    if not r or (r.count or 0) <= 0 then return false end
    local c = ns.GROUP_COLOR
    tt:AddLine(ns.Groups.TimesText(r.count), c[1], c[2], c[3])
    local s = ns.Groups.LastSession(r)
    if s then tt:AddLine("Last: " .. ns.Groups.WhereText(s), 0.75, 0.75, 0.8, true) end
    return true
end

-- Returns true when lines were added (tests read it).
function Tip.OnUnit(tt)
    if not ns.db or not ns.DB.Settings().tooltip then return false end
    if not tt or not tt.GetUnit then return false end
    local ok, _, unit = pcall(tt.GetUnit, tt)
    if not ok or not unit or ns.Secret(unit) then return false end
    local e, which, key = ns.Alert.Check(unit, "mouseover")
    if e then Tip.AddEntryLines(tt, e, which) end
    local grouped = key and Tip.AddGroupLines(tt, key)
    if not e and not grouped then return false end
    if tt.Show then tt:Show() end
    return true
end

function Tip.Install()
    if Tip.installed then return end
    Tip.installed = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
            if tt == GameTooltip then pcall(Tip.OnUnit, tt) end
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(Tip.OnUnit, tt) end)
    end
end
