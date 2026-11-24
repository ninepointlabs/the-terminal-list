-- The list: identity (Name-Realm), add/remove/note, kill counts, lookups.
--
-- Entry fields (BRIEF §3.1). Unknown facts stay nil, never guessed:
--   key       "name-realm", lower case: the identity
--   name      "Name" as the game spells it (the first name)
--   last      optional Forever last name, display only (nil when none)
--   realm     "Realm" (no spaces, the game's normalized form)
--   class     class token ("WARRIOR"), race (localized), faction ("Alliance"/"Horde")
--   added     time() when first listed; updated: time() of the last change
--   lastSeen  time() a listed player was last seen (target, mouseover, nameplate)
--   zone      where they were added or last updated; seenZone: where last seen
--   note      free text
--   source    "manual" or "pvp" (how they were first added)
--   kills     open-world PvP killing blows on me (1 for a PvP auto-add, 0 manual)
--   assists   times they hit me just before a PvP death without the killing blow
--             (only with "also add recent damagers" on)
-- A rename or realm transfer makes a new identity; the old entry stays as is.
--
-- The Good Folk (ns.Good, saved in db.global.good) use the same keys and the
-- same fields minus kills/assists/lastKill; their source is always "manual".
-- Nobody is ever added to them automatically. A player is on one list at most:
-- adding them to one moves them off the other, with a chat notice.
local _, ns = ...

local List = {}
ns.List = List
local Good = {}
ns.Good = Good

local function entries() return ns.db.global.entries end
local function goods() return ns.db.global.good end

-- Classic race tokens -> faction. Anything else (new Forever races) stays nil
-- until a unit tells us its faction.
List.RACE_FACTION = {
    Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
    Orc = "Horde", Scourge = "Horde", Undead = "Horde", Tauren = "Horde", Troll = "Horde",
}

function List.MyRealm()
    local r = ns.Try(GetNormalizedRealmName)
    if not r or r == "" then r = ns.Try(GetRealmName) end
    if type(r) ~= "string" or ns.Secret(r) then return nil end
    return (r:gsub("[%s%-]", ""))
end

local function letters(s)
    -- Character names are letters only: no spaces, digits or punctuation
    -- (accented letters are multi-byte and pass).
    return type(s) == "string" and #s >= 2 and not s:find("[%s%d%p]")
end

local function cap(s) return s:sub(1, 1):upper() .. s:sub(2):lower() end

-- Forever characters can have an optional last name ("Eugene Snorkel"); the
-- first name is still the unique one on a realm (it's what /whisper takes),
-- so identity is first name + realm and the last name is kept for display.
--
-- "Name", "Name-Realm", "First Last", "First Last-Realm" (any case)
--   -> name (first), realm, last. nil when it can't be a character name.
function List.Parse(text, realm)
    if type(text) ~= "string" or ns.Secret(text) then return nil end
    text = ns.Trim(text)
    local namePart, r = text:match("^(.-)%-([^%-]+)$")
    if not namePart or namePart == "" then namePart, r = text, nil end
    local first, last = namePart:match("^(%S+)%s+(%S+)$")
    if not first then first = namePart end
    if not letters(first) or (last and not letters(last)) then return nil end
    r = r and (r:gsub("[%s%-]", "")) or realm or List.MyRealm()
    if not r or r == "" then return nil end
    return cap(first), r, last and cap(last) or nil
end

function List.Key(name, realm)
    if not name or not realm then return nil end
    return (name .. "-" .. realm):lower()
end

function List.Get(key) return key and entries()[key] end
function Good.Get(key) return key and goods()[key] end

-- Which list a key is on: entry, "list" | "good" (nil when on neither).
function List.Which(key)
    if not key then return nil end
    local e = entries()[key]
    if e then return e, "list" end
    local g = goods()[key]
    if g then return g, "good" end
    return nil
end

local function onAny(key) return entries()[key] ~= nil or goods()[key] ~= nil end

local function knownRealm(r)
    if r == List.MyRealm() then return true end
    for _, t in ipairs({ entries(), goods() }) do
        for _, e in pairs(t) do
            if e.realm == r then return true end
        end
    end
    return false
end

-- The key a name refers to: the listed entry's key when there is one (on
-- either list). "First-X" where X isn't a realm we know is tried as First on
-- my realm too (a Forever last name can arrive joined with a dash).
function List.ResolveKey(name, realm)
    local key = List.Key(name, realm)
    if not key or onAny(key) or knownRealm(realm) then return key end
    local alt = List.Key(name, List.MyRealm())
    if alt and onAny(alt) then return alt end
    return key
end

-- Key from free text ("Name", "Name-Realm", "First Last").
function List.KeyFor(text)
    local name, realm, last = List.Parse(text)
    return List.ResolveKey(name, realm), name, realm, last
end

function List.Count()
    local n = 0
    for _ in pairs(entries()) do n = n + 1 end
    return n
end

function Good.Count()
    local n = 0
    for _ in pairs(goods()) do n = n + 1 end
    return n
end

-- Works for entries and for info tables (name, last?, realm).
function List.Display(e)
    if not e or not e.name then return "?" end
    local s = e.last and (e.name .. " " .. e.last) or e.name
    if e.realm and e.realm ~= List.MyRealm() then s = s .. "-" .. e.realm end
    return s
end

local function zoneNow()
    local z = ns.Try(GetZoneText)
    if type(z) ~= "string" or z == "" or ns.Secret(z) then z = ns.Try(GetRealZoneText) end
    if type(z) ~= "string" or z == "" or ns.Secret(z) then return nil end
    return z
end
List.Zone = zoneNow

-- Merge known facts (class/race/faction/guid) into an entry; never overwrite with nil.
local function absorb(e, info)
    if not info then return end
    for _, k in ipairs({ "last", "class", "race", "faction", "guid" }) do
        local v = info[k]
        if v ~= nil and v ~= "" and not ns.Secret(v) then e[k] = v end
    end
    if not e.faction and info.raceToken then e.faction = List.RACE_FACTION[info.raceToken] end
end

-- A new entry; `from` is their entry on the other list when this is a move
-- (identity facts and sightings carry over, and the note unless a new one is given).
local function newEntry(key, info, opts, from)
    local now = time()
    local note = opts.note and ns.Trim(opts.note) or ""
    local e = {
        key = key, name = info.name, last = info.last, realm = info.realm,
        added = now, updated = now,
        zone = opts.zone or zoneNow(),
        note = note,
        source = opts.source or "manual",
    }
    if from then
        for _, k in ipairs({ "last", "class", "race", "faction", "guid", "lastSeen", "seenZone" }) do
            if e[k] == nil then e[k] = from[k] end
        end
        if note == "" then e.note = from.note or "" end
    end
    absorb(e, info)
    return e
end

-- info: { name, realm, class?, race?, raceToken?, faction?, guid? }
-- opts: { note?, source? ("manual"|"pvp"), zone? }
-- Returns entry, created (false when they were already listed: nothing is duplicated).
-- Someone on the Good Folk is moved here (with a notice) for a manual add, and
-- never for a PvP add: that returns nil, false, "good".
function List.Add(info, opts)
    opts = opts or {}
    local key = List.ResolveKey(info.name, info.realm)
    if not key then return nil, false end
    local list = entries()
    local e = list[key]
    if e then
        absorb(e, info)
        return e, false
    end
    local g = goods()[key]
    if g and opts.source == "pvp" then return nil, false, "good" end
    e = newEntry(key, info, opts, g)
    e.kills, e.assists = 0, 0
    if g then goods()[key] = nil end
    list[key] = e
    -- Just added by hand while looking at them: no "is here" alert this session.
    if e.source == "manual" and ns.Alert then ns.Alert.session[key] = true end
    if g then
        ns.Print(("%s %s was on the Good Folk and has been moved to The Terminal List."):format(ns.Icon(), List.Display(e)))
    end
    ns.Fire("LIST_CHANGED", key)
    return e, true
end

function List.Remove(key)
    local e = entries()[key]
    if not e then return nil end
    entries()[key] = nil
    ns.Fire("LIST_CHANGED", key)
    return e
end

function List.SetNote(key, note)
    local e = entries()[key]
    if not e then return nil end
    e.note = ns.Trim(note)
    e.updated = time()
    ns.Fire("LIST_CHANGED", key)
    return e
end

-- The Good Folk. Only ever added by hand (slash, right-click, the window);
-- source is always "manual". Someone on The List is moved here, with a notice.
-- Returns entry, created.
function Good.Add(info, opts)
    opts = opts or {}
    if opts.source and opts.source ~= "manual" then return nil, false end
    local key = List.ResolveKey(info.name, info.realm)
    if not key then return nil, false end
    local list = goods()
    local g = list[key]
    if g then
        absorb(g, info)
        return g, false
    end
    local old = entries()[key]
    g = newEntry(key, info, { note = opts.note, zone = opts.zone, source = "manual" }, old)
    if old then entries()[key] = nil end
    list[key] = g
    if old then
        local kills = (old.kills or 0) + (old.assists or 0)
        ns.Print(("%s %s was on The Terminal List and has been moved to the Good Folk.%s"):format(ns.HeartIcon(), List.Display(g),
            kills > 0 and (" Their PvP record there (%d kill%s, %d assist%s) was not carried over."):format(
                old.kills or 0, (old.kills or 0) == 1 and "" or "s", old.assists or 0, (old.assists or 0) == 1 and "" or "s") or ""))
    end
    ns.Fire("LIST_CHANGED", key)
    return g, true
end

function Good.Remove(key)
    local g = goods()[key]
    if not g then return nil end
    goods()[key] = nil
    ns.Fire("LIST_CHANGED", key)
    return g
end

function Good.SetNote(key, note)
    local g = goods()[key]
    if not g then return nil end
    g.note = ns.Trim(note)
    g.updated = time()
    ns.Fire("LIST_CHANGED", key)
    return g
end

-- An open-world PvP death: add them (source pvp) or bump the counter.
-- kind: "kill" (killing blow) or "assist" (hit me inside the damage window).
-- Someone on the Good Folk is left alone: returns nil, false, "good".
function List.RecordPvP(info, kind, zone)
    local e, created, why = List.Add(info, { source = "pvp", zone = zone })
    if not e then return nil, false, why end
    if kind == "assist" then e.assists = (e.assists or 0) + 1 else e.kills = (e.kills or 0) + 1 end
    e.updated = time()
    e.zone = zone or zoneNow() or e.zone
    e.lastKill = kind ~= "assist" and e.updated or e.lastKill
    if not created then ns.Fire("LIST_CHANGED", e.key) end
    return e, created
end

-- Seen in the world: refresh last-seen and any facts the unit reveals.
function List.Seen(key, info)
    local e = entries()[key] or goods()[key]
    if not e then return nil end
    absorb(e, info)
    e.lastSeen = time()
    e.seenZone = zoneNow() or e.seenZone
    return e
end

----------------------------------------------------------------------------
-- Units and GUIDs -> info
----------------------------------------------------------------------------

-- Info for a unit token, or nil when it isn't another player (or is secret).
-- UnitName's second value is the realm elsewhere but can be a last name on
-- Forever, so the realm comes from the unit's GUID when the client says.
function List.FromUnit(unit)
    if not unit or ns.Secret(unit) then return nil end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or ns.Secret(isPlayer) or not isPlayer then return nil end
    local okSelf, isSelf = pcall(UnitIsUnit, unit, "player")
    if okSelf and not ns.Secret(isSelf) and isSelf then return nil end
    local first, second = UnitName(unit)
    if ns.Secret(first, second) or type(first) ~= "string" or first == "" or first == UNKNOWNOBJECT then return nil end
    local guid = ns.Try(UnitGUID, unit)
    if ns.Secret(guid) then guid = nil end
    local guidRealm
    if List.IsPlayerGUID(guid) then
        local _, _, _, _, _, _, r = ns.Try(GetPlayerInfoByGUID, guid)
        if type(r) == "string" and not ns.Secret(r) then guidRealm = r end
    end
    local name, last = first:match("^(%S+)%s+(%S+)$")
    name = name or first
    local realm
    second = type(second) == "string" and second ~= "" and second or nil
    if guidRealm then
        realm = guidRealm ~= "" and (guidRealm:gsub("[%s%-]", "")) or List.MyRealm()
        if second and (second:gsub("[%s%-]", "")) ~= realm then last = last or second end
    else
        realm = second and (second:gsub("[%s%-]", "")) or List.MyRealm()
    end
    if not realm then return nil end
    local info = { name = name, last = last, realm = realm, guid = guid }
    local _, class = ns.Try(UnitClass, unit)
    local race, raceToken = ns.Try(UnitRace, unit)
    local faction = ns.Try(UnitFactionGroup, unit)
    info.class = not ns.Secret(class) and class or nil
    info.race = not ns.Secret(race) and race or nil
    info.raceToken = not ns.Secret(raceToken) and raceToken or nil
    info.faction = not ns.Secret(faction) and faction or nil
    return info
end

function List.KeyForUnit(unit)
    local info = List.FromUnit(unit)
    return info and List.ResolveKey(info.name, info.realm), info
end

function List.IsPlayerGUID(guid)
    return type(guid) == "string" and not ns.Secret(guid) and guid:sub(1, 7) == "Player-"
end

-- Info for a player GUID (combat log); fallbackName is the log's "Name-Realm".
function List.FromGUID(guid, fallbackName)
    if not List.IsPlayerGUID(guid) then return nil end
    local _, class, race, raceToken, _, name, realm = ns.Try(GetPlayerInfoByGUID, guid)
    if ns.Secret(name, realm, class, race, raceToken) then name, realm, class, race, raceToken = nil, nil, nil, nil, nil end
    local first, last, r
    if type(name) == "string" and name ~= "" then
        first, last = name:match("^(%S+)%s+(%S+)$")
        first = first or name
        r = (type(realm) == "string" and realm ~= "") and (realm:gsub("[%s%-]", "")) or List.MyRealm()
    else
        first, r, last = List.Parse(fallbackName)
    end
    if not first or not r then return nil end
    return { name = first, last = last, realm = r, class = class, race = race, raceToken = raceToken, guid = guid,
        faction = raceToken and List.RACE_FACTION[raceToken] or nil }
end

----------------------------------------------------------------------------
-- Views
----------------------------------------------------------------------------

-- Sorted, filtered entries. sort: recent | kills | name; filter: all | pvp |
-- manual (The List only) or good (the Good Folk).
function List.Query(text, sort, filter)
    text = ns.Trim(text):lower()
    local out = {}
    local from = filter == "good" and goods() or entries()
    for _, e in pairs(from) do
        local ok = (filter == nil or filter == "all" or filter == "good" or e.source == filter)
        if ok and text ~= "" then
            local hay = table.concat({ e.name or "", e.last or "", e.realm or "", e.note or "", e.zone or "", e.race or "", e.faction or "", e.class or "" }, " "):lower()
            ok = hay:find(text, 1, true) ~= nil
        end
        if ok then table.insert(out, e) end
    end
    table.sort(out, function(a, b)
        if sort == "name" then return a.key < b.key end
        if sort == "kills" and (a.kills or 0) ~= (b.kills or 0) then return (a.kills or 0) > (b.kills or 0) end
        local ta, tb = a.updated or a.added or 0, b.updated or b.added or 0
        if ta ~= tb then return ta > tb end
        return a.key < b.key
    end)
    return out
end

-- Lower-case bare names on the list (for chat text), rebuilt on change.
local nameIndex
function List.NameIndex()
    if nameIndex then return nameIndex end
    nameIndex = {}
    for _, e in pairs(entries()) do
        if e.name then nameIndex[e.name:lower()] = true end
    end
    return nameIndex
end
ns.On("LIST_CHANGED", function() nameIndex = nil end)
function List.ResetIndex() nameIndex = nil end

function List.SourceLabel(e)
    return e and e.source == "pvp" and "PvP kill" or "Manual"
end

function List.DateText(t)
    if not t then return "?" end
    return date("%Y-%m-%d", t)
end
