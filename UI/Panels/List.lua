-- The List: browse, search (sidebar box), sort, filter, edit notes, remove.
-- The "Good Folk" filter shows the second list (hearts) instead; All / PvP /
-- Manual are The Terminal List only.
local _, ns = ...
local UI = ns.UI

local SHOW_MAX = 300 -- rows drawn at once; search narrows the rest

local SORTS = { { "recent", "Newest" }, { "kills", "Most kills" }, { "name", "Name" } }
local FILTERS = { { "all", "All" }, { "pvp", "PvP kills" }, { "manual", "Manual" }, { "good", "Good Folk" } }

local function factionText(f)
    if f == "Alliance" then return "|cff4a90e2Alliance|r" end
    if f == "Horde" then return "|cffe24a4aHorde|r" end
    return nil
end

local function className(token)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return token and ((names and names[token]) or (token:sub(1, 1) .. token:sub(2):lower())) or nil
end

-- Lines for one entry (tests read these through M.texts).
function UI.EntryRow(e)
    local who = UI.ClassHex(e.class) .. ns.Escape(ns.List.Display(e)) .. "|r"
    local facts = {}
    for _, v in ipairs({ e.race, className(e.class), factionText(e.faction) }) do
        if v and v ~= "" then table.insert(facts, v) end
    end
    local sub = {}
    if #facts > 0 then table.insert(sub, table.concat(facts, " ")) end
    if e.note and e.note ~= "" then
        table.insert(sub, "|cffffffff\"" .. ns.Escape(e.note) .. "\"|r")
    else
        table.insert(sub, UI.Hex(UI.C.dim) .. "No note|r")
    end
    local where = {}
    table.insert(where, "Added " .. ns.List.DateText(e.added) .. (e.zone and (" in " .. e.zone) or ""))
    if e.lastSeen then table.insert(where, "seen " .. ns.List.DateText(e.lastSeen) .. (e.seenZone and (" in " .. e.seenZone) or "")) end
    table.insert(sub, table.concat(where, " · "))
    local right = {}
    if (e.kills or 0) > 0 then table.insert(right, ns.MARK_HEX .. e.kills .. "|r kill" .. (e.kills == 1 and "" or "s")) end
    if (e.assists or 0) > 0 then table.insert(right, e.assists .. " assist" .. (e.assists == 1 and "" or "s")) end
    return {
        title = ns.Icon(14) .. " " .. who,
        sub = table.concat(sub, "\n"),
        right = table.concat(right, " · "),
        chip = { text = ns.List.SourceLabel(e), kind = e.source == "pvp" and "bad" or "neutral" },
        buttons = {
            { label = "Note", onClick = function() UI.EditNote(e.key) end, tip = "Edit the note" },
            { label = "Remove", onClick = function() UI.ConfirmRemove(e.key) end },
        },
    }
end

-- A Good Folk row: heart, who, note, when. No PvP facts.
function UI.GoodRow(e)
    local who = UI.ClassHex(e.class) .. ns.Escape(ns.List.Display(e)) .. "|r"
    local facts = {}
    for _, v in ipairs({ e.race, className(e.class), factionText(e.faction) }) do
        if v and v ~= "" then table.insert(facts, v) end
    end
    local sub = {}
    if #facts > 0 then table.insert(sub, table.concat(facts, " ")) end
    if e.note and e.note ~= "" then
        table.insert(sub, "|cffffffff\"" .. ns.Escape(e.note) .. "\"|r")
    else
        table.insert(sub, UI.Hex(UI.C.dim) .. "No note|r")
    end
    local where = {}
    table.insert(where, "Added " .. ns.List.DateText(e.added) .. (e.zone and (" in " .. e.zone) or ""))
    if e.lastSeen then table.insert(where, "seen " .. ns.List.DateText(e.lastSeen) .. (e.seenZone and (" in " .. e.seenZone) or "")) end
    table.insert(sub, table.concat(where, " · "))
    return {
        title = ns.HeartIcon(14) .. " " .. who,
        sub = table.concat(sub, "\n"),
        chip = { text = "Good Folk", kind = "good" },
        buttons = {
            { label = "Note", onClick = function() UI.EditGoodNote(e.key) end, tip = "Edit the Good Folk note" },
            { label = "Remove", onClick = function() UI.ConfirmRemoveGood(e.key) end },
        },
    }
end

local function render(L)
    local g = ns.db.global
    local good = g.filter == "good"
    local total = good and ns.Good.Count() or ns.List.Count()
    if good then
        L:Title("The List", "The Good Folk: people you want to remember kindly. They get a heart " .. ns.HeartIcon(14) .. ", never the crosshair, and are never added by PvP.")
        L:Buttons({
            { label = "Add a good one...", onClick = function() UI.PromptAddGood() end, tip = "Type a name (Name or Name-Realm). Same as /tlist good Name." },
            { label = "Add my target", onClick = function() ns.Slash("good") end, tip = "Your current target, to the Good Folk (/tlist good)." },
        })
    else
        L:Title("The List", "Players who crossed you, were rude, or don't play nice. Both factions. Shared by all your characters.")
        L:Buttons({
            { label = "Add a player...", onClick = function() UI.PromptAdd() end, tip = "Type a name (Name or Name-Realm)." },
            { label = "Add my target", onClick = function() ns.Slash("add") end, tip = "Your current target, if it's another player. For a friend, use /tlist good." },
        })
    end

    local sorts = {}
    for _, s in ipairs(SORTS) do
        table.insert(sorts, { label = s[2], active = g.sort == s[1], onClick = function() g.sort = s[1] UI.Refresh() end })
    end
    local filters = {}
    for _, f in ipairs(FILTERS) do
        table.insert(filters, { label = f[2], active = g.filter == f[1], onClick = function() g.filter = f[1] UI.Refresh() end })
    end
    L:Tabs(filters)
    L:Text(UI.Hex(UI.C.label) .. "SORT|r", { size = 11, gap = 4 })
    L:Buttons(sorts)

    local rows = ns.List.Query(UI.filterText, g.sort, g.filter)
    if good and total == 0 then
        L:Space(6)
        L:Text("No Good Folk yet.", { size = 15 })
        L:Text(UI.Hex(UI.C.dim) .. "Right-click a player's portrait or name in chat and choose Add to the Good Folk, or type /tlist good Name (no name: your target). They get a heart instead of the crosshair. Nobody is ever added here automatically.|r", { size = 12 })
        return
    end
    if total == 0 then
        L:Space(6)
        L:Text("The list is empty.", { size = 15 })
        L:Text(UI.Hex(UI.C.dim) .. "Right-click a player's portrait or name in chat and choose Add to The Terminal List, type /tlist add Name, or target them and type /tlist add. A player who kills you in open-world PvP is added on their own (battlegrounds, arenas, dungeons and duels never count).|r", { size = 12 })
        L:Text(UI.Hex(UI.C.dim) .. "People you like go on the Good Folk instead (" .. ns.HeartIcon(12) .. " /tlist good Name, or the Good Folk filter above).|r", { size = 12 })
        return
    end
    if UI.filterText ~= "" then
        L:Text(("%d match%s for \"%s\""):format(#rows, #rows == 1 and "" or "es", ns.Escape(UI.filterText)), { color = UI.C.dim, size = 12 })
    end
    if #rows == 0 then
        L:Text(UI.Hex(UI.C.dim) .. "Nobody matches.|r")
        return
    end
    for i, e in ipairs(rows) do
        if i > SHOW_MAX then
            L:Text(UI.Hex(UI.C.dim) .. ("%d more: search to narrow the list."):format(#rows - SHOW_MAX) .. "|r", { size = 12 })
            break
        end
        L:Row(good and UI.GoodRow(e) or UI.EntryRow(e))
    end
end

UI.RegisterPanel({
    key = "list", label = "The List",
    badge = function() return ns.List.Count() end,
    render = render,
})
