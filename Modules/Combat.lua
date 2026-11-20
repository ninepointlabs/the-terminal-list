-- Auto-add on an open-world PvP death (BRIEF §3.3).
--
-- Tim: "PVP adding should ignore battle grounds and so on where I choose to PVP."
-- So a death only counts in the open world: never in a battleground, arena or
-- any other instance (party, raid, scenario...), and never during a duel.
--
-- Who killed me:
--   1. Combat log, when the client gives it to addons (CombatLogGetCurrentEventInfo):
--      the hit on me with overkill > 0 is the killing blow. A player GUID is
--      added; a player's pet is credited to its owner when the owner can be
--      found among target/focus/mouseover/nameplates; NPCs, environment
--      (falling, drowning, lava, fatigue) and unresolvable pets are ignored.
--   2. No combat log (sister-addon research says Forever removed it for
--      addons; verify in game): the killer can't be read, so nothing is added
--      automatically. If a hostile player was my target in the last 30 s the
--      addon asks whether to add them (setting, on by default); otherwise it
--      explains once per session how to add someone by hand.
local _, ns = ...

local Combat = {}
ns.Combat = Combat

Combat.recent = {}      -- hits on me: { t, guid, name, flags, env, killing }
Combat.duel = { active = false, opponent = nil, since = 0, graceUntil = 0, endedAt = -1000 }
Combat.lastDeathAt = -1000
Combat.lastHostile = nil -- { info, t } (fallback when there is no combat log)
Combat.ASK_WINDOW = 30
Combat.KEEP = 30         -- seconds of hits kept
Combat.DUEL_STALE = 300  -- a duel request with no DUEL_FINISHED stops counting after this

local function settings() return ns.DB.Settings() end

function Combat.HasCombatLog()
    return type(CombatLogGetCurrentEventInfo) == "function"
end

----------------------------------------------------------------------------
-- Where am I? Only the open world counts.
----------------------------------------------------------------------------
local function truthy(v) return ns.Secret(v) or (v and v ~= 0) end

-- true, or false + reason. Unreadable (secret/erroring) answers count as "not open world".
function Combat.IsOpenWorld()
    if C_PvP then
        for _, fn in ipairs({ "IsBattleground", "IsArena", "IsRatedBattleground", "IsInBrawl" }) do
            if C_PvP[fn] and truthy(ns.Try(C_PvP[fn])) then return false, "pvp:" .. fn end
        end
    end
    if IsActiveBattlefieldArena and truthy(ns.Try(IsActiveBattlefieldArena)) then return false, "arena" end
    if UnitInBattleground and truthy(ns.Try(UnitInBattleground, "player")) then return false, "battleground" end
    local readable = false
    if IsInInstance then
        local ok, inside, kind = pcall(IsInInstance)
        if not ok or ns.Secret(inside, kind) then return false, "unreadable" end
        if inside then return false, kind or "instance" end
        if kind and kind ~= "none" then return false, kind end
        readable = true
    end
    if GetInstanceInfo then
        local ok, _, kind = pcall(GetInstanceInfo)
        if not ok or ns.Secret(kind) then return false, "unreadable" end
        if kind and kind ~= "none" and kind ~= "" then return false, kind end
        readable = true
    end
    if not readable then return false, "unreadable" end
    return true
end

----------------------------------------------------------------------------
-- Duels
----------------------------------------------------------------------------
function Combat.OnDuel(event, who)
    local d, t = Combat.duel, GetTime()
    if event == "DUEL_REQUESTED" or event == "START_DUEL" then
        d.active, d.since = true, t
        if type(who) == "string" and not ns.Secret(who) then d.opponent = who end
    elseif event == "DUEL_INBOUNDS" or event == "DUEL_OUTOFBOUNDS" then
        if not d.active then d.active, d.since = true, t end
    elseif event == "DUEL_FINISHED" then
        d.active = false
        d.graceUntil = t + 10 -- a DoT from the duel can still tick
        d.endedAt = t
    end
end

function Combat.InDuel()
    local d, t = Combat.duel, GetTime()
    if d.active and t - d.since > Combat.DUEL_STALE then d.active = false end
    return d.active or t < d.graceUntil
end

-- The duel opponent (recent duel only) never counts as a PvP killer.
local function isDuelOpponent(info)
    local d = Combat.duel
    if not d.opponent or not info then return false end
    if GetTime() - d.endedAt > 60 and not d.active then return false end
    local name = d.opponent:match("^([^%-]+)")
    return name and name:lower() == info.name:lower()
end

function Combat.HookDuels()
    if type(StartDuel) == "function" and hooksecurefunc then
        pcall(hooksecurefunc, "StartDuel", function(unitOrName)
            local name = unitOrName
            if type(unitOrName) == "string" and ns.Try(UnitExists, unitOrName) then name = ns.Try(UnitName, unitOrName) end
            Combat.OnDuel("START_DUEL", name)
        end)
    end
end

----------------------------------------------------------------------------
-- Combat log (only when the client provides it)
----------------------------------------------------------------------------
-- Damage subevents -> payload position of `overkill`.
Combat.OVERKILL_ARG = {
    SWING_DAMAGE = 13, RANGE_DAMAGE = 16, SPELL_DAMAGE = 16, SPELL_PERIODIC_DAMAGE = 16,
    SPELL_BUILDING_DAMAGE = 16, DAMAGE_SHIELD = 16, DAMAGE_SPLIT = 16, ENVIRONMENTAL_DAMAGE = 14,
}

local function prune(t)
    local keep = {}
    for _, h in ipairs(Combat.recent) do
        if t - h.t <= Combat.KEEP then table.insert(keep, h) end
    end
    Combat.recent = keep
end

-- Takes CombatLogGetCurrentEventInfo()'s returns.
function Combat.OnCombatLog(...)
    local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID = ...
    if ns.Secret(sub, dstGUID) then return end
    local me = ns.Try(UnitGUID, "player")
    if not me or ns.Secret(me) or dstGUID ~= me then return end
    if sub == "UNIT_DIED" then
        Combat.Resolve()
        return
    end
    local idx = Combat.OVERKILL_ARG[sub]
    if not idx then return end
    local t = GetTime()
    prune(t)
    local hit = { t = t, env = (sub == "ENVIRONMENTAL_DAMAGE") }
    if not hit.env and not ns.Secret(srcGUID, srcName, srcFlags) then
        hit.guid, hit.name, hit.flags = srcGUID, srcName, srcFlags
    end
    table.insert(Combat.recent, hit)
    local overkill = select(idx, ...)
    if type(overkill) == "number" and not ns.Secret(overkill) and overkill > 0 then
        hit.killing = true
        Combat.Resolve()
    end
end

local function playerControlled(flags)
    -- COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
    return type(flags) == "number" and math.floor(flags / 256) % 2 == 1
end

-- Find the player who owns a pet/guardian GUID among units we can see.
function Combat.OwnerOf(petGUID)
    if type(petGUID) ~= "string" then return nil end
    local tokens = { "target", "focus", "mouseover" }
    for i = 1, 40 do tokens[#tokens + 1] = "nameplate" .. i end
    local petToken = UnitTokenFromGUID and ns.Try(UnitTokenFromGUID, petGUID)
    if ns.Secret(petToken) then petToken = nil end
    for _, tok in ipairs(tokens) do
        local exists = ns.Try(UnitExists, tok)
        if exists and not ns.Secret(exists) then
            local pg = ns.Try(UnitGUID, tok .. "pet")
            if pg and not ns.Secret(pg) and pg == petGUID then return ns.List.FromUnit(tok) end
            if petToken and UnitIsOwnerOrControllerOfUnit then
                local v = ns.Try(UnitIsOwnerOrControllerOfUnit, tok, petToken)
                if v == true then return ns.List.FromUnit(tok) end
            end
        end
    end
    return nil
end

-- A hit -> player info (or nil for NPCs, environment, unresolvable pets).
function Combat.ResolvePlayer(hit)
    if not hit or hit.env or not hit.guid then return nil end
    if ns.List.IsPlayerGUID(hit.guid) then return ns.List.FromGUID(hit.guid, hit.name) end
    if playerControlled(hit.flags) then return Combat.OwnerOf(hit.guid) end
    return nil
end

----------------------------------------------------------------------------
-- A death
----------------------------------------------------------------------------
local function announce(e, created, kind)
    local who = ns.List.Display(e)
    local where = e.zone and (" in " .. e.zone) or ""
    if kind == "assist" then
        ns.Print(("%s %s added (hit you just before you died%s)."):format(ns.Icon(), who, where))
    elseif created then
        ns.Print(("%s %s killed you%s. Added to the list."):format(ns.Icon(), who, where))
    else
        ns.Print(("%s %s killed you again%s (%d times now)."):format(ns.Icon(), who, where, e.kills or 0))
    end
end

-- PLAYER_DEAD: give the combat log a moment to deliver the killing blow.
function Combat.OnPlayerDead()
    C_Timer.After(0.3, function() Combat.Resolve() end)
end

-- Decide what this death means. Returns a status string (tests read it).
function Combat.Resolve()
    local t = GetTime()
    if t - Combat.lastDeathAt < 5 then return "dup" end
    Combat.lastDeathAt = t
    local s = settings()
    local recent = Combat.recent
    Combat.recent = {}
    if not s.autoAdd then return "off" end
    local open, why = Combat.IsOpenWorld()
    if not open then
        ns.Debug("death not counted: " .. tostring(why))
        return "instance"
    end
    if Combat.InDuel() then
        ns.Debug("death not counted: duel")
        return "duel"
    end
    if not Combat.HasCombatLog() then return Combat.AskFallback() end

    local killing
    for i = #recent, 1, -1 do
        if recent[i].killing then killing = recent[i] break end
    end
    if not killing then
        local last = recent[#recent]
        if last and t - last.t <= 3 then killing = last end
    end
    if not killing then return "unknown" end
    if killing.env then return "environment" end
    local info = Combat.ResolvePlayer(killing)
    if not info then return "npc" end
    if isDuelOpponent(info) then return "duel" end

    local zone = ns.List.Zone()
    local e, created = ns.List.RecordPvP(info, "kill", zone)
    if not e then return "unknown" end
    announce(e, created, "kill")
    local added = { e.key }
    if s.addRecentDamagers then
        local seen = { [e.key] = true }
        local window = tonumber(s.damageWindow) or 8
        for _, h in ipairs(recent) do
            if h ~= killing and not h.env and killing.t - h.t <= window then
                local other = Combat.ResolvePlayer(h)
                local key = other and ns.List.ResolveKey(other.name, other.realm)
                if key and not seen[key] and not isDuelOpponent(other) then
                    seen[key] = true
                    local e2, created2 = ns.List.RecordPvP(other, "assist", zone)
                    if e2 then
                        announce(e2, created2, "assist")
                        table.insert(added, e2.key)
                    end
                end
            end
        end
    end
    return "added", added
end

----------------------------------------------------------------------------
-- No combat log: ask about the hostile player I was fighting.
----------------------------------------------------------------------------
function Combat.NoteHostile(unit)
    local info = ns.List.FromUnit(unit or "target")
    if not info then return end
    local can = ns.Try(UnitCanAttack, "player", unit or "target")
    if ns.Secret(can) or not can then return end
    Combat.lastHostile = { info = info, t = GetTime() }
end

function Combat.AskFallback()
    pcall(Combat.NoteHostile, "target")
    local h = Combat.lastHostile
    if settings().askWhenUnknown and h and GetTime() - h.t <= Combat.ASK_WINDOW then
        Combat.pending = { info = h.info, zone = ns.List.Zone() }
        if ns.UI and ns.UI.AskAddKiller then ns.UI.AskAddKiller(h.info) end
        return "asked"
    end
    if not Combat.explained then
        Combat.explained = true
        ns.Print("You died in the open world, but this client doesn't tell addons who landed the killing blow. Target them and type /tlist add, or right-click their portrait.")
    end
    return "unknown"
end

-- "Yes" on the ask popup.
function Combat.ConfirmPending()
    local p = Combat.pending
    Combat.pending = nil
    if not p then return nil end
    local e, created = ns.List.RecordPvP(p.info, "kill", p.zone)
    if e then announce(e, created, "kill") end
    return e
end
