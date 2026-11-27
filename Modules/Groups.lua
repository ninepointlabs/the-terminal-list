-- Past groups: who I've grouped with, when, where, and on what.
--
-- Tim (2026-11-27): "add possibly being able to write click on their name an
-- pull the details on all the times we grouped" / "and what dungeon or quest
-- it was on maybe".
--
-- Forward-looking only: nothing before this feature was installed can be
-- known. Group history is separate from The Terminal List and the Good Folk:
-- grouping with someone never adds them to either list, and anyone can have
-- history whether or not they're on one.
--
-- Saved in db.global.groups (account-wide), keyed like the lists
-- ("name-realm", lower case, via List.ResolveKey):
--   key, name, last?, realm, class?, race?, faction?
--   count     separate times grouped (stays right when old sessions are trimmed)
--   first     time() of the first recorded session
--   seen      time() last seen in a group together
--   sessions  oldest first, at most Groups.MAX_SESSIONS:
--     start     time() the session began
--     seen      time() last seen together in this session
--     type      "party" | "raid" (the latest; a party turned raid is one session)
--     zone      where it started, if readable
--     instances { "The Deadmines", ... } entered together, if readable (nil when none)
--     quests    { { title, status = "accepted"|"progressed"|"completed" } } (nil when none)
--     char      { name, last?, realm? } the character I was playing
--
-- Session rule: a teammate seen in my group again within Groups.COOLDOWN
-- seconds (15 min) of the last time I saw them in a group, on the same
-- character, continues the same session (same group, a disconnect, a reload,
-- a brief drop and re-invite, a party converted to raid). Later than that is a
-- new session: count + 1. While grouped, sessions are kept fresh every
-- Groups.TICK seconds, so a long group never times out.
--
-- Never guessed: secret or unreadable names are skipped; an instance or quest
-- name that isn't cleanly readable is left out (and filled in later in the
-- same session if it becomes readable). Battlegrounds and arenas never start
-- a session (their raid is strangers the game put together), but friends
-- already in a session stay in it.
local _, ns = ...

local Groups = {}
ns.Groups = Groups

Groups.COOLDOWN = 15 * 60
Groups.TICK = 60
Groups.MAX_SESSIONS = 50
Groups.MAX_QUESTS = 20

Groups.current = {}   -- key -> true: other players in my group at the last scan
Groups.kind = nil     -- "party" | "raid" | nil
Groups.questCache = {} -- questID -> title, from the quest log while grouped

local STATUS_RANK = { accepted = 1, progressed = 2, completed = 3 }

local function store() return ns.db.global.groups end

local function readable(v)
    if type(v) ~= "string" or v == "" or ns.Secret(v) then return nil end
    return v
end

----------------------------------------------------------------------------
-- Lookups
----------------------------------------------------------------------------

function Groups.Get(key)
    if not key or not ns.db then return nil end
    return store()[key]
end

function Groups.Count(key)
    local r = Groups.Get(key)
    return r and r.count or 0
end

-- Record for typed text ("Name", "Name-Realm"): the key the lists would use,
-- else the same first name on my realm.
function Groups.KeyFor(text)
    local key, name = ns.List.KeyFor(text)
    if key and Groups.Get(key) then return key end
    local alt = name and ns.List.Key(name, ns.List.MyRealm())
    if alt and Groups.Get(alt) then return alt end
    return key
end

function Groups.Total()
    local n = 0
    for _ in pairs(store()) do n = n + 1 end
    return n
end

-- Everyone with history, most recently grouped first.
function Groups.All()
    local out = {}
    for _, r in pairs(store()) do table.insert(out, r) end
    table.sort(out, function(a, b)
        if (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
        return a.key < b.key
    end)
    return out
end

function Groups.LastSession(r)
    return r and r.sessions and r.sessions[#r.sessions]
end

----------------------------------------------------------------------------
-- Reading the client (all feature-detected)
----------------------------------------------------------------------------

-- The character I'm playing: { name, last?, realm? }, or nil when unreadable.
function Groups.Me()
    local full = readable(ns.Try(UnitName, "player"))
    if not full then return nil end
    local name, last = full:match("^(%S+)%s+(%S+)$")
    return { name = name or full, last = last, realm = ns.List.MyRealm() }
end

local function sameChar(a, b)
    if not a or not b then return a == b end
    return (a.name or ""):lower() == (b.name or ""):lower() and (a.realm or "") == (b.realm or "")
end

-- "party" | "raid" | nil (not grouped), and false when it can't be read.
function Groups.GroupKind()
    local raid = IsInRaid and ns.Try(IsInRaid)
    if ns.Secret(raid) then return nil, false end
    if raid then return "raid", true end
    local inGroup
    if IsInGroup then
        inGroup = ns.Try(IsInGroup)
        if ns.Secret(inGroup) then return nil, false end
    elseif GetNumSubgroupMembers then
        local n = ns.Try(GetNumSubgroupMembers)
        if ns.Secret(n) then return nil, false end
        inGroup = type(n) == "number" and n > 0
    elseif GetNumPartyMembers then
        local n = ns.Try(GetNumPartyMembers)
        if ns.Secret(n) then return nil, false end
        inGroup = type(n) == "number" and n > 0
    else
        return nil, false
    end
    return inGroup and "party" or nil, true
end

-- Unit tokens for the other people in my group.
local function rosterUnits(kind)
    local units = {}
    if kind == "raid" then
        local n = GetNumGroupMembers and ns.Try(GetNumGroupMembers)
        if ns.Secret(n) or type(n) ~= "number" then n = 40 end
        for i = 1, math.min(n, 40) do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Inside an instance: name (or nil when it isn't readable), kind. Not inside: nil.
function Groups.Instance()
    if not IsInInstance then return nil end
    local ok, inside, kind = pcall(IsInInstance)
    if not ok or ns.Secret(inside, kind) or not inside then return nil end
    local name
    if GetInstanceInfo then
        local ok2, n = pcall(GetInstanceInfo)
        if ok2 then name = readable(n) end
    end
    if not name then name = readable(ns.Try(GetRealZoneText)) end
    return name, kind, true
end

local function pvpInstance()
    local _, kind, inside = Groups.Instance()
    return inside and (kind == "pvp" or kind == "arena")
end

----------------------------------------------------------------------------
-- Sessions
----------------------------------------------------------------------------

-- The open session for a record: the last one, if seen within the cooldown
-- on the same character.
local function openSession(r, now, me)
    local s = Groups.LastSession(r)
    if s and now - (s.seen or s.start or 0) <= Groups.COOLDOWN and sameChar(s.char, me) then return s end
    return nil
end

local function trim(r)
    while #r.sessions > Groups.MAX_SESSIONS do table.remove(r.sessions, 1) end
end

local function absorb(r, info)
    for _, k in ipairs({ "last", "class", "race", "faction" }) do
        local v = info[k]
        if v ~= nil and v ~= "" and not ns.Secret(v) then r[k] = v end
    end
end

-- A teammate seen in my group now. Returns record, started (a new session).
function Groups.Saw(info, kind, now, me, allowNew)
    local key = ns.List.ResolveKey(info.name, info.realm)
    if not key then return nil end
    local all = store()
    local r = all[key]
    local s = r and openSession(r, now, me)
    if s then
        s.seen = now
        s.type = kind or s.type
        if not s.zone then s.zone = ns.List.Zone() end
        r.seen = now
        absorb(r, info)
        return r, false
    end
    if not allowNew then return r, false end
    if not r then
        r = { key = key, name = info.name, realm = info.realm, count = 0, first = now, sessions = {} }
        all[key] = r
    end
    absorb(r, info)
    r.count = (r.count or 0) + 1
    r.seen = now
    table.insert(r.sessions, { start = now, seen = now, type = kind, zone = ns.List.Zone(), char = me })
    trim(r)
    return r, true
end

-- Open sessions of everyone in my group right now.
local function currentSessions()
    local out, now, me = {}, time(), Groups.Me()
    for key in pairs(Groups.current) do
        local r = store()[key]
        local s = r and openSession(r, now, me)
        if s then out[#out + 1] = s end
    end
    return out
end

-- Note the instance I'm in on the current sessions (when its name is readable).
function Groups.NoteInstance()
    if not ns.db or not next(Groups.current) then return false end
    local name = Groups.Instance()
    if not name then return false end
    local added = false
    for _, s in ipairs(currentSessions()) do
        s.instances = s.instances or {}
        local have = false
        for _, n in ipairs(s.instances) do if n == name then have = true break end end
        if not have then
            table.insert(s.instances, name)
            added = true
        end
    end
    return added
end

-- A quest title on the current sessions; status only ever moves up
-- (accepted -> progressed -> completed).
function Groups.NoteQuest(title, status)
    title = readable(title)
    if not title or not ns.db or not next(Groups.current) then return false end
    local added = false
    for _, s in ipairs(currentSessions()) do
        s.quests = s.quests or {}
        local q
        for _, x in ipairs(s.quests) do if x.title == title then q = x break end end
        if q then
            if (STATUS_RANK[status] or 0) > (STATUS_RANK[q.status] or 0) then q.status = status added = true end
        elseif #s.quests < Groups.MAX_QUESTS then
            table.insert(s.quests, { title = title, status = status })
            added = true
        end
    end
    return added
end

-- Read the roster and record everyone in it. Returns the number of teammates
-- seen, and whether any new session started.
function Groups.Scan()
    if not ns.db or ns.disabled then return 0 end
    local kind, ok = Groups.GroupKind()
    if ok == false then return 0 end -- unreadable: change nothing
    local cur = {}
    Groups.kind = kind
    if not kind then
        Groups.current = cur
        return 0
    end
    local now, me = time(), Groups.Me()
    local allowNew = not pvpInstance()
    local n, started = 0, false
    for _, unit in ipairs(rosterUnits(kind)) do
        local exists = ns.Try(UnitExists, unit)
        if exists and not ns.Secret(exists) then
            local info = ns.List.FromUnit(unit)
            if info then
                local r, new = Groups.Saw(info, kind, now, me, allowNew)
                if new then started = true end
                if r and openSession(r, now, me) then
                    cur[r.key] = true
                    n = n + 1
                end
            end
        end
    end
    Groups.current = cur
    if n > 0 then
        Groups.NoteInstance()
        Groups.KeepFresh()
    end
    return n, started
end

-- While grouped, rescan every TICK seconds so a long quiet group stays one session.
function Groups.KeepFresh()
    if Groups.tickPending or not (C_Timer and C_Timer.After) then return end
    Groups.tickPending = true
    C_Timer.After(Groups.TICK, function()
        Groups.tickPending = false
        if next(Groups.current) then pcall(Groups.Scan) end
    end)
end

-- Roster events come in bursts: scan once, shortly after.
function Groups.ScanSoon()
    if Groups.scanPending then return end
    if not (C_Timer and C_Timer.After) then pcall(Groups.Scan) return end
    Groups.scanPending = true
    C_Timer.After(0.5, function()
        Groups.scanPending = false
        local ok, _, started = pcall(Groups.Scan)
        if ok and started then ns.Fire("GROUPS_CHANGED") end
    end)
end

----------------------------------------------------------------------------
-- Quests (feature-detected; Classic quest log first, C_QuestLog if present)
----------------------------------------------------------------------------

-- Title of a quest-log line (nil for headers and unreadable lines), questID.
function Groups.LogTitle(index)
    if type(index) ~= "number" or ns.Secret(index) then return nil end
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = ns.Try(C_QuestLog.GetInfo, index)
        if type(info) == "table" and not ns.Secret(info) then
            if ns.Secret(info.isHeader) or info.isHeader or info.isHidden then return nil end
            return readable(info.title), info.questID
        end
    end
    if GetQuestLogTitle then
        local title, _, _, isHeader, _, _, _, questID = ns.Try(GetQuestLogTitle, index)
        if ns.Secret(isHeader) or isHeader then return nil end
        if ns.Secret(questID) then questID = nil end
        return readable(title), questID
    end
    return nil
end

local function numLogEntries()
    local n
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then n = ns.Try(C_QuestLog.GetNumQuestLogEntries) end
    if (type(n) ~= "number" or ns.Secret(n)) and GetNumQuestLogEntries then n = ns.Try(GetNumQuestLogEntries) end
    if type(n) ~= "number" or ns.Secret(n) then return 0 end
    return math.min(n, 100)
end

-- Remember questID -> title for everything in the log (a turn-in may arrive
-- after the quest left the log).
function Groups.ScanLog()
    if not next(Groups.current) then return end
    for i = 1, numLogEntries() do
        local title, id = Groups.LogTitle(i)
        if title and type(id) == "number" then Groups.questCache[id] = title end
    end
end

function Groups.TitleForID(questID)
    if type(questID) ~= "number" or ns.Secret(questID) then return nil end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local t = readable(ns.Try(C_QuestLog.GetTitleForQuestID, questID))
        if t then return t end
    end
    if Groups.questCache[questID] then return Groups.questCache[questID] end
    for i = 1, numLogEntries() do
        local title, id = Groups.LogTitle(i)
        if id == questID and title then return title end
    end
    return nil
end

function Groups.OnQuestEvent(event, a1, a2)
    if not next(Groups.current) then return end
    if event == "QUEST_ACCEPTED" then
        -- Classic passes (questLogIndex, questID); newer clients pass (questID).
        local title
        if a2 ~= nil then title = Groups.LogTitle(a1) or Groups.TitleForID(a2)
        else title = Groups.TitleForID(a1) end
        Groups.NoteQuest(title, "accepted")
    elseif event == "QUEST_WATCH_UPDATE" then
        Groups.NoteQuest((Groups.LogTitle(a1)), "progressed")
    elseif event == "QUEST_COMPLETE" then
        Groups.completingTitle = GetTitleText and readable(ns.Try(GetTitleText)) or nil
    elseif event == "QUEST_TURNED_IN" then
        local title = Groups.TitleForID(a1) or Groups.completingTitle
        Groups.completingTitle = nil
        Groups.NoteQuest(title, "completed")
    elseif event == "QUEST_LOG_UPDATE" then
        Groups.ScanLog()
    end
end

----------------------------------------------------------------------------
-- Text
----------------------------------------------------------------------------

function Groups.TimesText(n)
    return ("Grouped together %d time%s"):format(n, n == 1 and "" or "s")
end

local STATUS_TEXT = { accepted = "accepted", progressed = "progressed", completed = "turned in" }

function Groups.QuestText(q)
    local st = STATUS_TEXT[q.status]
    return ns.Escape(q.title) .. (st and (" (" .. st .. ")") or "")
end

-- "2026-11-27 in Westfall · The Deadmines" for a session.
function Groups.WhereText(s)
    if not s then return "" end
    local parts = { ns.List.DateText(s.start) .. (s.zone and (" in " .. ns.Escape(s.zone)) or "") }
    local inst = {}
    for _, n in ipairs(s.instances or {}) do
        if n ~= s.zone then inst[#inst + 1] = ns.Escape(n) end
    end
    if #inst > 0 then parts[#parts + 1] = table.concat(inst, ", ") end
    return table.concat(parts, " · ")
end

function Groups.CharText(c)
    if not c or not c.name then return nil end
    return ns.List.Display(c)
end

----------------------------------------------------------------------------
-- The number badge (nameplates, target frame)
----------------------------------------------------------------------------
-- Badge colour: a calm blue, so it never reads as the red crosshair or the
-- pink heart.
ns.GROUP_COLOR = { 0.62, 0.77, 1.0 }

-- The number to show beside someone, or nil. which: their list ("list" |
-- "good" | nil). The Terminal List keeps the crosshair alone unless
-- groupBadgeList is on. The caller checks its own surface toggle
-- (nameplate / target).
function Groups.BadgeCount(key, which)
    if not ns.db then return nil end
    local s = ns.DB.Settings()
    if not s.groupBadge then return nil end
    if which == "list" and not s.groupBadgeList then return nil end
    local n = Groups.Count(key)
    if n <= 0 then return nil end
    return n
end

function Groups.BadgeText(n)
    return n > 99 and "99+" or tostring(n)
end

-- A small dark pill with the count in it.
function Groups.MakeBadge(parent, height)
    height = height or 16
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(height, height)
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetAllPoints()
    b.edge:SetColorTexture(ns.GROUP_COLOR[1] * 0.55, ns.GROUP_COLOR[2] * 0.55, ns.GROUP_COLOR[3] * 0.55, 0.95)
    b.bg = b:CreateTexture(nil, "BORDER")
    b.bg:SetPoint("TOPLEFT", 1, -1)
    b.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    b.bg:SetColorTexture(0.06, 0.07, 0.12, 0.92)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont("Fonts\\FRIZQT__.TTF", math.max(9, height - 5), "OUTLINE")
    b.text:SetTextColor(ns.GROUP_COLOR[1], ns.GROUP_COLOR[2], ns.GROUP_COLOR[3])
    b.text:SetPoint("CENTER", 0, 0)
    b.height = height
    function b:SetCount(n)
        self.text:SetText(Groups.BadgeText(n))
        self.count = n
        local w = (self.text.GetStringWidth and self.text:GetStringWidth()) or 0
        self:SetWidth(math.max(self.height, w + 8))
    end
    b:Hide()
    return b
end
