-- Past groups: everyone I've grouped with (newest first), and one player's
-- group history: every recorded session with its date, zone, dungeon,
-- quests, my character and party/raid. Empty facts are left out, never
-- filled with guesses. Opened from the sidebar, the "Group history"
-- right-click entry, or /tlist groups [Name[-Realm]].
local _, ns = ...
local UI = ns.UI

local SHOW_MAX = 300

UI.groupKey = nil -- whose history is open (nil: everyone)

local function dim(text) return UI.Hex(UI.C.dim) .. text .. "|r" end

local function markFor(key)
    local _, which = ns.List.Which(key)
    if which == "list" then return ns.Icon(14) .. " " end
    if which == "good" then return ns.HeartIcon(14) .. " " end
    return ""
end

local function who(r)
    return UI.ClassHex(r.class) .. ns.Escape(ns.List.Display(r)) .. "|r"
end

local function duration(s)
    local mins = math.floor(((s.seen or s.start) - s.start) / 60)
    if mins < 1 then return "" end
    if mins < 60 then return mins .. " min" end
    return ("%dh %02dm"):format(math.floor(mins / 60), mins % 60)
end

-- Row options for one session (tests read the text through M.texts).
function UI.GroupSessionRow(s)
    local lines = {}
    if s.zone then lines[#lines + 1] = "Zone: " .. ns.Escape(s.zone) end
    if s.instances and #s.instances > 0 then
        local names = {}
        for _, n in ipairs(s.instances) do names[#names + 1] = ns.Escape(n) end
        lines[#lines + 1] = "Dungeon / instance: |cffffffff" .. table.concat(names, ", ") .. "|r"
    end
    if s.quests and #s.quests > 0 then
        local qs = {}
        for _, q in ipairs(s.quests) do qs[#qs + 1] = ns.Groups.QuestText(q) end
        lines[#lines + 1] = "Quests: |cffffffff" .. table.concat(qs, "; ") .. "|r"
    end
    local char = ns.Groups.CharText(s.char)
    if char then lines[#lines + 1] = "You were on " .. ns.Escape(char) end
    return {
        title = date("%Y-%m-%d %H:%M", s.start),
        chip = { text = s.type == "raid" and "Raid" or "Party", kind = s.type == "raid" and "warn" or "info" },
        sub = table.concat(lines, "\n"),
        right = duration(s),
    }
end

local function detail(L, r)
    L:Title("Group history", markFor(r.key) .. who(r))
    L:Buttons({ { label = "All past groups", onClick = function() UI.groupKey = nil UI.Refresh() end } })
    local _, which = ns.List.Which(r.key)
    local facts = { ns.Groups.TimesText(r.count or 0) }
    if r.first then facts[#facts + 1] = "first " .. ns.List.DateText(r.first) end
    if which == "list" then facts[#facts + 1] = ns.MARK_HEX .. "on The Terminal List|r"
    elseif which == "good" then facts[#facts + 1] = "|cffff78b5one of the Good Folk|r" end
    L:Text(table.concat(facts, " · "), { size = 13 })
    local sessions = r.sessions or {}
    if #sessions < (r.count or 0) then
        L:Text(dim(("Showing the last %d sessions; older ones were trimmed to keep the saved file small. The count still includes them."):format(#sessions)), { size = 12 })
    end
    L:Space(4)
    for i = #sessions, 1, -1 do
        L:Row(UI.GroupSessionRow(sessions[i]))
    end
end

local function overview(L)
    L:Title("Past groups", "Everyone you've grouped with, on any of your characters. Recording started when this feature was installed: earlier groups can't be known.")
    local all = ns.Groups.All()
    if #all == 0 then
        L:Space(6)
        L:Text("No past groups yet.", { size = 15 })
        L:Text(dim("Join a party or raid and everyone in it is remembered here, with the zone, any dungeon you enter together and quests you do while grouped. Grouping never adds anyone to The Terminal List or the Good Folk."), { size = 12 })
        return
    end
    for i, r in ipairs(all) do
        if i > SHOW_MAX then
            L:Text(dim(("%d more not shown."):format(#all - SHOW_MAX)), { size = 12 })
            break
        end
        local key = r.key
        L:Row({
            title = markFor(key) .. who(r),
            sub = ns.Groups.TimesText(r.count or 0) .. "\nLast: " .. ns.Groups.WhereText(ns.Groups.LastSession(r)),
            button = { label = "History", onClick = function() UI.ShowGroupHistory(key) end, tip = "Every recorded session" },
            onClick = function() UI.ShowGroupHistory(key) end,
        })
    end
end

-- Open someone's history (nil: everyone).
function UI.ShowGroupHistory(key)
    UI.groupKey = key
    UI.Open("groups")
end

UI.RegisterPanel({
    key = "groups", label = "Past groups",
    setSub = function(sub) if sub == "all" then UI.groupKey = nil end end,
    render = function(L)
        local r = UI.groupKey and ns.Groups.Get(UI.groupKey)
        if r then detail(L, r) else overview(L) end
    end,
})
