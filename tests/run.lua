-- Headless tests. Run from the repo root:  lua5.1 tests/run.lua
package.path = "./tests/?.lua;" .. package.path
local M = require("wow_mock")
M.Install()
local S = M.state

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else
        failed = failed + 1
        io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
    end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function has(list, pattern)
    for _, t in ipairs(list) do if tostring(t):find(pattern, 1, true) then return true end end
    return false
end
local function textHas(pattern) return has(M.texts, pattern) end
local function printed(pattern) return has(M.printed, pattern) end
local function lastPopup() return M.popups[#M.popups] end

local function tocFiles(path)
    local out = {}
    for line in io.lines(path) do
        if not line:match("^##") and line:match("%S") then table.insert(out, (line:gsub("\\", "/"):gsub("%s+$", ""))) end
    end
    return out
end

----------------------------------------------------------------------------
-- Forever-only guard: load once as a non-Forever client, in its own event list.
----------------------------------------------------------------------------
do
    rawset(_G, "WOW_PROJECT_ID", 2)
    local ns2 = M.LoadAddon("TheTerminalList_Forever.toc", ".")
    M.Fire("ADDON_LOADED", "TheTerminalList")
    M.Fire("PLAYER_LOGIN")
    test("Forever-only guard: off when WOW_PROJECT_ID is not 18", function()
        eq(ns2.disabled, true)
        eq(ns2.db, nil, "no saved variables wired")
        eq(TheTerminalListDB, nil, "no account DB created")
        truthy(printed("WoW Forever only"), "explains why")
        M.printed = {}
        SlashCmdList.THETERMINALLIST("add Somebody")
        truthy(printed("Disabled: WoW Forever only"), "slash refuses")
        eq(next(M.menus), nil, "no menus hooked")
        eq(next(M.chatFilters), nil, "no chat filters")
    end)
    -- Fresh start for the real load.
    M.events, M.printed, M.texts, M.timers = {}, {}, {}, {}
    rawset(_G, "WOW_PROJECT_ID", 18)
end

local ns = M.LoadAddon("TheTerminalList_Forever.toc", ".")

test("toc files match between plain and _Forever", function()
    local a, b = io.open("TheTerminalList.toc"):read("*a"), io.open("TheTerminalList_Forever.toc"):read("*a")
    eq(a, b)
    truthy(a:find("## Interface: 16001", 1, true), "interface")
    truthy(a:find("## Title: The Terminal List", 1, true), "title")
    truthy(a:find("## Author: Nine Point Labs", 1, true), "author")
    truthy(a:find("## Version: @project-version@", 1, true), "version token")
    truthy(a:find("## X-Website: https://github.com/ninepointlabs/the-terminal-list", 1, true), "website")
    truthy(a:find("## Category: PvP", 1, true), "category")
    truthy(not a:find("## Category: Class", 1, true), "not a class addon")
    truthy(a:find("## IconTexture: Interface\\AddOns\\TheTerminalList\\Media\\Crosshair", 1, true), "icon")
    truthy(a:find("## AddonCompartmentFunc: TheTerminalList_OnCompartmentClick", 1, true), "compartment")
    truthy(a:find("## SavedVariables: TheTerminalListDB", 1, true), "saved variables")
    truthy(a:find("## SavedVariablesPerCharacter: TheTerminalListCharDB", 1, true), "per-character saved variables")
    for _, f in ipairs(tocFiles("TheTerminalList.toc")) do truthy(io.open(f), "missing " .. f) end
    truthy(io.open("Media/Crosshair.tga"), "crosshair texture")
    eq(io.open("Bindings.xml"), nil, "no Bindings.xml")
end)

test("crosshair texture is a 64x64 32-bit TGA with alpha", function()
    local d = io.open("Media/Crosshair.tga", "rb"):read("*a")
    eq(d:byte(3), 2, "uncompressed true colour")
    eq(d:byte(13) + d:byte(14) * 256, 64, "width")
    eq(d:byte(15) + d:byte(16) * 256, 64, "height")
    eq(d:byte(17), 32, "bpp")
    eq(#d, 18 + 64 * 64 * 4, "size")
end)

test("no leftover class-addon copy and no skull marker", function()
    local files = tocFiles("TheTerminalList.toc")
    for _, f in ipairs(files) do
        local s = io.open(f):read("*a")
        for _, bad in ipairs({ "Shaman", "Paladin", "Priest", "Mage", "Tazu", "Andric", "Parzelle", "Tristan", "Rogue",
            "ActiveSpec", "SpecAccent", "DualSpec", "Rotation", "Talent", "ns.Data" }) do
            -- The only allowed mention: the sister-addon links in Settings › About.
            local allowed = f == "UI/Panels/Options.lua" and (bad == "Tazu" or bad == "Andric" or bad == "Parzelle" or bad == "Tristan" or bad == "Rogue")
            if not allowed then truthy(not s:find(bad, 1, true), f .. " mentions " .. bad) end
        end
        truthy(not s:lower():find("skull", 1, true), f .. " mentions a skull")
        truthy(not s:find("RaidTargetingIcon", 1, true), f .. " uses a raid-target icon")
    end
    truthy(ns.CROSSHAIR:find("Media\\Crosshair", 1, true), "marker is the crosshair")
end)

-- Login: Rip, Human Rogue, Alliance, open world (Elwynn Forest), no combat log.
M.Fire("ADDON_LOADED", "TheTerminalList")
M.Fire("PLAYER_LOGIN")
M.RunTimers()

test("login wires DB, slash, menus, chat, tooltip; no combat log on this client", function()
    truthy(ns.db and TheTerminalListDB and TheTerminalListCharDB, "saved variables")
    eq(ns.db.global, TheTerminalListDB)
    eq(SLASH_THETERMINALLIST1, "/tlist")
    truthy(SlashCmdList.THETERMINALLIST, "slash handler")
    truthy(M.menus.MENU_UNIT_TARGET and M.menus.MENU_UNIT_PLAYER and M.menus.MENU_UNIT_FRIEND, "unit menus hooked")
    truthy(M.chatFilters.CHAT_MSG_SAY and #M.chatFilters.CHAT_MSG_SAY == 1, "one chat filter per event")
    truthy(M.tooltipHooks and M.tooltipHooks[2], "unit tooltip hook")
    eq(M.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "combat log not registered without the API")
    eq(ns.VERSION, "dev", "packager token reads as dev")
end)

test("defaults (BRIEF §6)", function()
    local s = ns.DB.Settings()
    eq(s.autoAdd, true); eq(s.addRecentDamagers, false); eq(s.damageWindow, 8)
    eq(s.nameplate, true); eq(s.target, true); eq(s.tooltip, true); eq(s.chat, true)
    eq(s.alert, false, "alert off by default")
    eq(ns.List.Count(), 0)
end)

local function renderAll(label)
    for _, key in ipairs(ns.PanelOrder) do
        M.texts = {}
        ns.UI.Open(key)
        truthy(not textHas("This panel hit an error"), label .. "/" .. key .. ": " .. table.concat(M.texts, " | "))
    end
    for _, sub in ipairs({ "List & PvP", "Recognition", "About" }) do
        M.texts = {}
        ns.UI.Open("settings", sub)
        truthy(not textHas("This panel hit an error"), label .. "/settings/" .. sub)
    end
end

test("/tlist toggles the window; empty list explains how to add", function()
    SlashCmdList.THETERMINALLIST("")
    truthy(ns.UI.IsShown(), "opened")
    M.texts = {}
    ns.UI.Open("list")
    truthy(textHas("The list is empty."), "empty state")
    truthy(textHas("battlegrounds, arenas, dungeons and duels never count"), "open-world rule explained")
    SlashCmdList.THETERMINALLIST("")
    truthy(not ns.UI.IsShown(), "closed")
    renderAll("empty")
end)

-- A hostile Horde player as target.
S.units.target = { guid = "Player-1-0000BEEF", name = "Gankalot", realm = nil, class = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde", hostile = true }

test("/tlist add by current target, with note; facts from the unit", function()
    M.printed = {}
    SlashCmdList.THETERMINALLIST("add")
    local e = ns.List.Get("gankalot-camwowus2realm1pve")
    truthy(e, "added")
    eq(e.name, "Gankalot"); eq(e.realm, "CAMWOWUS2Realm1PvE")
    eq(e.class, "WARRIOR"); eq(e.race, "Orc"); eq(e.faction, "Horde")
    eq(e.source, "manual"); eq(e.kills, 0); eq(e.zone, "Elwynn Forest")
    eq(e.added, S.now)
    truthy(printed("Gankalot added"), "confirmation")
end)

test("adding someone already listed never duplicates; offers the note instead", function()
    M.popups = {}
    ns.Slash("add Gankalot camped the flight master")
    eq(ns.List.Count(), 1, "still one entry")
    local p = lastPopup()
    eq(p.which, "THETERMINALLIST_NOTE", "note editor offered")
    eq(p.data.key, "gankalot-camwowus2realm1pve")
    eq(p.data.suggest, "camped the flight master", "new text prefilled")
    truthy(printed("already on the list"), "says so")
    -- Accepting the dialog sets the note.
    local dlg = StaticPopupDialogs.THETERMINALLIST_NOTE
    local eb = M.newObject("EditBox")
    eb:SetText(p.data.suggest)
    dlg.OnAccept({ editBox = eb }, p.data)
    eq(ns.List.Get("gankalot-camwowus2realm1pve").note, "camped the flight master")
end)

test("/tlist add by name (with and without realm), bad names refused, self refused", function()
    ns.Slash("add rudeguy ninja-looted the chest")
    local e = ns.List.Get("rudeguy-camwowus2realm1pve")
    truthy(e, "added by name")
    eq(e.name, "Rudeguy", "name cased like the game")
    eq(e.note, "ninja-looted the chest")
    eq(e.class, nil, "unknown class stays nil")
    eq(e.faction, nil, "unknown faction stays nil")
    ns.Slash("add Farguy-Other Realm")
    truthy(ns.List.Get("farguy-other"), "realm parsed (first word only after the dash)")
    ns.List.Remove("farguy-other")
    ns.Slash("add Far-OtherRealm griefer")
    local f = ns.List.Get("far-otherrealm")
    truthy(f, "cross-realm key")
    eq(ns.List.Display(f), "Far-OtherRealm", "other realms shown")
    eq(ns.List.Display(e), "Rudeguy", "own realm hidden")
    M.printed = {}
    local before = ns.List.Count()
    ns.Slash("add 1337")
    truthy(printed("doesn't look like a character name"), "digits refused")
    ns.Slash("add Rip")
    truthy(printed("That's you."), "self refused")
    eq(ns.List.Count(), before)
end)

test("/tlist note by name and for the target; empty note opens the editor", function()
    ns.Slash("note Rudeguy spammed trade all night")
    eq(ns.List.Get("rudeguy-camwowus2realm1pve").note, "spammed trade all night")
    ns.Slash("note killed me at the inn twice")
    eq(ns.List.Get("gankalot-camwowus2realm1pve").note, "killed me at the inn twice", "whole text for the listed target")
    M.popups = {}
    ns.Slash("note Rudeguy")
    eq(lastPopup().which, "THETERMINALLIST_NOTE")
    M.printed = {}
    ns.Slash("note Nobody hi")
    truthy(not printed("Note for Nobody"), "unlisted name not created")
end)

test("/tlist search filters the list window", function()
    M.texts = {}
    ns.Slash("search spammed")
    truthy(ns.UI.IsShown())
    eq(ns.UI.filterText, "spammed")
    truthy(textHas("1 match for"), "match count")
    truthy(textHas("Rudeguy"), "match shown")
    truthy(not textHas("Gankalot"), "non-match hidden")
    ns.UI.SetFilter("")
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("Gankalot") and textHas("Rudeguy"), "both after clearing")
    truthy(textHas("Orc Warrior"), "race and class shown")
    truthy(textHas("Horde"), "faction shown")
    truthy(textHas("Added " .. os.date("%Y-%m-%d", S.now) .. " in Elwynn Forest"), "date and zone")
end)

test("/tlist settings, about, help", function()
    M.texts = {}
    ns.UI.Open("settings", "List & PvP")
    ns.Slash("settings")
    eq(ns.db.char.window.tab, "settings")
    truthy(textHas("Add a player who kills me in open-world PvP"), "settings page")
    M.texts = {}
    ns.Slash("about")
    truthy(textHas("stored on this computer only"), "local, account-wide note")
    truthy(textHas("MIT"), "licence")
    M.printed = {}
    ns.Slash("help")
    truthy(printed("/tlist add [Name[-Realm]] [note]"), "help lists add")
    truthy(printed("/tlist remove"), "help lists remove")
end)

test("the list is account-wide: a second character sees the same entries", function()
    local account = TheTerminalListDB
    local acc2, char2 = ns.DB.Init(account, nil)
    eq(acc2, account, "same account table")
    truthy(ns.List.Get("rudeguy-camwowus2realm1pve"), "second character sees Rudeguy")
    eq(char2.window.tab, "list", "own window state")
    -- An add on character 2 is there for character 1.
    ns.List.Add({ name = "Alt", realm = "CAMWOWUS2Realm1PvE" }, { note = "from Tazu" })
    TheTerminalListDB, TheTerminalListCharDB = ns.DB.Init(account, TheTerminalListCharDB)
    eq(ns.List.Get("alt-camwowus2realm1pve").note, "from Tazu")
    ns.List.Remove("alt-camwowus2realm1pve")
end)

test("/tlist remove by name and by target", function()
    ns.Slash("remove Far-OtherRealm")
    eq(ns.List.Get("far-otherrealm"), nil)
    ns.Slash("add Temp")
    ns.Slash("rm temp")
    eq(ns.List.Get("temp-camwowus2realm1pve"), nil, "case-insensitive")
    M.printed = {}
    ns.Slash("remove Ghost")
    truthy(printed("isn't on the list"))
end)

----------------------------------------------------------------------------
-- Auto-add on open-world PvP death (combat log available)
----------------------------------------------------------------------------
local ME = S.me.guid
local cleu
rawset(_G, "CombatLogGetCurrentEventInfo", function() return unpack(cleu) end)
ns.EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local function log(...) cleu = { ... } M.Fire("COMBAT_LOG_EVENT_UNFILTERED") end
-- A hit on me. overkill > 0 = the killing blow.
local function swing(srcGUID, srcName, overkill, flags)
    log(S.time, "SWING_DAMAGE", false, srcGUID, srcName, flags or 0x548, 0, ME, "Rip", 0x511, 0, 120, overkill or -1)
end
local function spell(srcGUID, srcName, overkill, flags)
    log(S.time, "SPELL_DAMAGE", false, srcGUID, srcName, flags or 0x548, 0, ME, "Rip", 0x511, 0, 133, "Fireball", 4, 200, overkill or -1)
end
local function die() S.time = S.time + 0.1 M.Fire("PLAYER_DEAD") M.RunTimers() S.time = S.time + 60 end
local function player(guid, name, realm, class, race)
    S.guids[guid] = { name = name, realm = realm, class = class or "MAGE", race = race or "Undead", raceToken = race == "Orc" and "Orc" or "Scourge" }
end

player("Player-1-00000001", "Killer", nil, "MAGE", "Undead")
player("Player-1-00000002", "Helper", nil, "WARRIOR", "Orc")
player("Player-1-00000003", "Farhelper", "OtherRealm", "WARRIOR", "Orc")

test("a player's killing blow in the open world adds them (source pvp, 1 kill)", function()
    eq(ns.Combat.HasCombatLog(), true)
    M.printed = {}
    S.time = S.time + 60
    spell("Player-1-00000001", "Killer", 55)
    die()
    local e = ns.List.Get("killer-camwowus2realm1pve")
    truthy(e, "added")
    eq(e.source, "pvp"); eq(e.kills, 1); eq(e.zone, "Elwynn Forest")
    eq(e.class, "MAGE"); eq(e.race, "Undead"); eq(e.faction, "Horde", "faction from the race")
    truthy(printed("Killer killed you in Elwynn Forest. Added to the list."))
end)

test("a second death to the same player bumps the counter, no duplicate", function()
    local n = ns.List.Count()
    S.zone = "Westfall"
    swing("Player-1-00000001", "Killer", 10)
    die()
    local e = ns.List.Get("killer-camwowus2realm1pve")
    eq(e.kills, 2)
    eq(e.zone, "Westfall", "zone refreshed")
    eq(ns.List.Count(), n, "no new row")
    truthy(printed("killed you again in Westfall (2 times now)"))
    S.zone = "Elwynn Forest"
end)

test("a manual entry who later kills me keeps source manual and gets a kill", function()
    spell("Player-1-0000BEEF", "Gankalot", 5)
    die()
    local e = ns.List.Get("gankalot-camwowus2realm1pve")
    eq(e.source, "manual"); eq(e.kills, 1)
end)

local function noneAdded(label, setup, teardown)
    local n = ns.List.Count()
    setup()
    spell("Player-1-0000F00D", "Newguy", 30)
    die()
    if teardown then teardown() end
    eq(ns.List.Count(), n, label .. ": nobody added")
    eq(ns.List.Get("newguy-camwowus2realm1pve"), nil, label)
end
player("Player-1-0000F00D", "Newguy")

test("never in battlegrounds, arenas, dungeons, raids or scenarios", function()
    for _, kind in ipairs({ "pvp", "arena", "party", "raid", "scenario" }) do
        noneAdded(kind, function() S.instanceType = kind end, function() S.instanceType = nil end)
    end
end)

test("never when C_PvP says battleground/arena, or the instance type is secret", function()
    noneAdded("C_PvP.IsBattleground", function() rawset(_G, "C_PvP", { IsBattleground = function() return true end }) end,
        function() rawset(_G, "C_PvP", nil) end)
    noneAdded("IsActiveBattlefieldArena", function() rawset(_G, "IsActiveBattlefieldArena", function() return true, true end) end,
        function() rawset(_G, "IsActiveBattlefieldArena", nil) end)
    M.InstallSecrets()
    local orig = IsInInstance
    noneAdded("secret instance type", function() rawset(_G, "IsInInstance", function() return M.SECRET, M.SECRET end) end,
        function() rawset(_G, "IsInInstance", orig) end)
    M.RemoveSecrets()
end)

test("world PvP flag is not a reason to skip", function()
    rawset(_G, "C_PvP", { IsBattleground = function() return false end, IsArena = function() return false end })
    eq(ns.Combat.IsOpenWorld(), true)
    rawset(_G, "C_PvP", nil)
end)

test("never during a duel (incoming or outgoing), counts again after it ends", function()
    noneAdded("duel requested", function() M.Fire("DUEL_REQUESTED", "Newguy") end)
    -- still in the duel (no DUEL_FINISHED yet)
    noneAdded("duel running", function() end)
    M.Fire("DUEL_FINISHED")
    noneAdded("duel grace", function() end) -- DoT ticks right after
    S.time = S.time + 120
    noneAdded("outgoing duel", function() StartDuel("target") end, function() M.Fire("DUEL_FINISHED") S.time = S.time + 120 end)
    spell("Player-1-0000F00D", "Newguy", 30)
    die()
    truthy(ns.List.Get("newguy-camwowus2realm1pve"), "counts after the duel")
    ns.List.Remove("newguy-camwowus2realm1pve")
end)

test("no auto-add for NPCs, environment, or a pet whose owner can't be found", function()
    local n = ns.List.Count()
    swing("Creature-0-1-2-3-299-0000", "Defias Bandit", 12, 0xa48)
    die()
    log(S.time, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, ME, "Rip", 0x511, 0, "Falling", 500, 100)
    die()
    log(S.time, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, ME, "Rip", 0x511, 0, "Drowning", 50, 5)
    die()
    swing("Pet-0-1-2-3-4-0000AAAA", "Wolfie", 7, 0x1148) -- player-controlled pet, owner nowhere in sight
    die()
    eq(ns.List.Count(), n)
end)

test("a player's pet killing blow is credited to its owner when the owner is visible", function()
    S.units.nameplate1 = { guid = "Player-1-0000CAFE", name = "Hunterguy", class = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde", hostile = true, pet = "Pet-0-1-2-3-4-0000BBBB" }
    swing("Pet-0-1-2-3-4-0000BBBB", "Cat", 7, 0x1148)
    die()
    local e = ns.List.Get("hunterguy-camwowus2realm1pve")
    truthy(e, "owner added")
    eq(e.kills, 1); eq(e.source, "pvp")
    S.units.nameplate1 = nil
    -- Owner found through UnitTokenFromGUID + UnitIsOwnerOrControllerOfUnit.
    S.units.focus = { guid = "Player-1-0000D00D", name = "Lockguy", hostile = true }
    S.units.pettoken = { guid = "Pet-0-1-2-3-4-0000CCCC", player = false }
    rawset(_G, "UnitTokenFromGUID", function(g) if g == "Pet-0-1-2-3-4-0000CCCC" then return "pettoken" end end)
    rawset(_G, "UnitIsOwnerOrControllerOfUnit", function(owner, pet) return owner == "focus" and pet == "pettoken" end)
    spell("Pet-0-1-2-3-4-0000CCCC", "Imp", 3, 0x1148)
    die()
    truthy(ns.List.Get("lockguy-camwowus2realm1pve"), "owner via controller API")
    rawset(_G, "UnitTokenFromGUID", nil)
    rawset(_G, "UnitIsOwnerOrControllerOfUnit", nil)
    S.units.focus, S.units.pettoken = nil, nil
end)

test("recent damagers: off by default, only the killing blow is added", function()
    eq(ns.DB.Settings().addRecentDamagers, false)
    swing("Player-1-00000002", "Helper", -1)
    S.time = S.time + 2
    spell("Player-1-00000001", "Killer", 20)
    die()
    eq(ns.List.Get("helper-camwowus2realm1pve"), nil, "helper not added")
    eq(ns.List.Get("killer-camwowus2realm1pve").kills, 3)
end)

test("recent damagers on: adds players who hit me inside the window, as pvp assists", function()
    local s = ns.DB.Settings()
    s.addRecentDamagers = true
    swing("Player-1-00000003", "Farhelper", -1)  -- 10 s before: outside the 8 s window
    S.time = S.time + 10
    swing("Player-1-00000002", "Helper", -1)     -- 2 s before
    swing("Creature-0-1-2-3-299-0000", "Defias Bandit", -1, 0xa48)
    S.time = S.time + 2
    spell("Player-1-00000001", "Killer", 20)
    die()
    local h = ns.List.Get("helper-camwowus2realm1pve")
    truthy(h, "helper added")
    eq(h.source, "pvp"); eq(h.kills, 0); eq(h.assists, 1)
    eq(ns.List.Get("farhelper-otherrealm"), nil, "outside the window")
    eq(ns.List.Get("killer-camwowus2realm1pve").kills, 4)
    -- Wider window catches the far one.
    s.damageWindow = 12
    swing("Player-1-00000003", "Farhelper", -1)
    S.time = S.time + 10
    spell("Player-1-00000001", "Killer", 20)
    die()
    truthy(ns.List.Get("farhelper-otherrealm"), "inside a 12 s window")
    -- Still ignored inside instances and duels.
    local n = ns.List.Count()
    S.instanceType = "pvp"
    swing("Player-1-0000F00D", "Newguy", -1)
    spell("Player-1-00000001", "Killer", 20)
    die()
    S.instanceType = nil
    M.Fire("DUEL_REQUESTED", "Killer")
    swing("Player-1-0000F00D", "Newguy", -1)
    spell("Player-1-00000001", "Killer", 20)
    die()
    M.Fire("DUEL_FINISHED")
    S.time = S.time + 120
    eq(ns.List.Count(), n, "nothing added in a battleground or duel")
    eq(ns.List.Get("killer-camwowus2realm1pve").kills, 5, "no kill counted there either")
    s.addRecentDamagers, s.damageWindow = false, 8
end)

test("auto-add off: nothing is added", function()
    local s = ns.DB.Settings()
    s.autoAdd = false
    local k = ns.List.Get("killer-camwowus2realm1pve").kills
    spell("Player-1-00000001", "Killer", 20)
    die()
    eq(ns.List.Get("killer-camwowus2realm1pve").kills, k)
    s.autoAdd = true
end)

test("PLAYER_DEAD with no overkill seen: the last hit within 3 s is the killer", function()
    spell("Player-1-00000002", "Helper", -1)
    die()
    eq(ns.List.Get("helper-camwowus2realm1pve").kills, 1)
end)

----------------------------------------------------------------------------
-- No combat log (what Forever is believed to do): ask, never guess.
----------------------------------------------------------------------------
rawset(_G, "CombatLogGetCurrentEventInfo", nil)

test("no combat log: asks about the hostile target, adds only on Yes", function()
    eq(ns.Combat.HasCombatLog(), false)
    S.units.target = { guid = "Player-1-0000ABCD", name = "Sneaky", class = "ROGUE", race = "Troll", raceToken = "Troll", faction = "Horde", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    M.popups = {}
    S.time = S.time + 5
    die()
    local p = lastPopup()
    truthy(p and p.which == "THETERMINALLIST_ASK_KILLER", "asked")
    eq(p.a1, "Sneaky")
    eq(ns.List.Get("sneaky-camwowus2realm1pve"), nil, "not added before Yes")
    StaticPopupDialogs.THETERMINALLIST_ASK_KILLER.OnAccept()
    local e = ns.List.Get("sneaky-camwowus2realm1pve")
    truthy(e, "added on Yes")
    eq(e.source, "pvp"); eq(e.kills, 1)
    -- No: nothing.
    S.units.target = { guid = "Player-1-0000ABCE", name = "Maybe", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    die()
    StaticPopupDialogs.THETERMINALLIST_ASK_KILLER.OnCancel()
    eq(ns.List.Get("maybe-camwowus2realm1pve"), nil)
end)

test("no combat log: no hostile target -> explains once; never asks in instances or duels", function()
    S.units.target = nil
    ns.Combat.lastHostile = nil
    M.popups, M.printed = {}, {}
    die()
    eq(#M.popups, 0, "no popup")
    truthy(printed("doesn't tell addons who landed the killing blow"), "explained")
    S.units.target = { guid = "Player-1-0000ABCF", name = "Bgguy", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    S.instanceType = "pvp"
    die()
    S.instanceType = nil
    M.Fire("DUEL_REQUESTED", "Bgguy")
    die()
    M.Fire("DUEL_FINISHED")
    S.time = S.time + 120
    eq(#M.popups, 0, "never asked in a battleground or duel")
    -- A friendly (non-attackable) target isn't offered.
    S.units.target = { guid = "Player-1-0000ABD0", name = "Friend", hostile = false }
    ns.Combat.lastHostile = nil
    M.Fire("PLAYER_TARGET_CHANGED")
    die()
    eq(#M.popups, 0, "friendly target not offered")
end)

----------------------------------------------------------------------------
-- Recognition
----------------------------------------------------------------------------
S.units.target = { guid = "Player-1-0000BEEF", name = "Gankalot", class = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde", hostile = true }

test("target frame: crosshair on a listed target, hidden otherwise or when off", function()
    M.Fire("PLAYER_TARGET_CHANGED")
    local mark = ns.Target.Mark()
    truthy(mark, "mark built on the target portrait")
    eq(mark.tex.__texture, ns.CROSSHAIR, "crosshair texture")
    eq(mark:IsShown(), true, "shown for a listed target")
    S.units.target = { guid = "Player-1-00009999", name = "Stranger", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    eq(mark:IsShown(), false, "hidden for an unlisted target")
    S.units.target = { guid = "Player-1-0000BEEF", name = "Gankalot", hostile = true }
    ns.DB.Settings().target = false
    ns.Fire("RECOGNITION_CHANGED")
    eq(mark:IsShown(), false, "hidden when turned off")
    ns.DB.Settings().target = true
    ns.Fire("RECOGNITION_CHANGED")
    eq(mark:IsShown(), true)
    -- Removing them hides it right away.
    ns.List.Remove("gankalot-camwowus2realm1pve")
    eq(mark:IsShown(), false, "hidden after remove")
    ns.Slash("add")
end)

test("nameplates: crosshair beside a listed player's plate", function()
    eq(ns.Nameplates.Available(), true)
    S.units.nameplate2 = { guid = "Player-1-00000001", name = "Killer", hostile = true }
    S.units.nameplate3 = { guid = "Player-1-00008888", name = "Nobodyhere", hostile = true }
    local p2, p3 = M.AddPlate("nameplate2"), M.AddPlate("nameplate3")
    M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    truthy(p2.ttlMark and p2.ttlMark:IsShown(), "listed plate marked")
    eq(p2.ttlMark.tex.__texture, ns.CROSSHAIR)
    eq(p3.ttlMark, nil, "unlisted plate untouched")
    truthy(ns.List.Get("killer-camwowus2realm1pve").lastSeen, "last seen recorded")
    ns.DB.Settings().nameplate = false
    ns.Fire("RECOGNITION_CHANGED")
    eq(p2.ttlMark:IsShown(), false, "off hides it")
    ns.DB.Settings().nameplate = true
    ns.Fire("RECOGNITION_CHANGED")
    eq(p2.ttlMark:IsShown(), true)
    M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    eq(p2.ttlMark:IsShown(), false, "hidden when the plate goes")
    -- Forbidden plates are skipped.
    p2.IsForbidden = function() return true end
    eq(ns.Nameplates.Update("nameplate2"), false)
    M.plates, S.units.nameplate2, S.units.nameplate3 = {}, nil, nil
end)

test("tooltip: note, kill count and how they were added", function()
    S.units.mouseover = { guid = "Player-1-00000001", name = "Killer", hostile = true }
    ns.List.SetNote("killer-camwowus2realm1pve", "camps the Goldshire inn")
    GameTooltip.__lines = {}
    GameTooltip.GetUnit = function() return "Killer", "mouseover" end
    M.tooltipHooks[2](GameTooltip)
    local lines = table.concat(GameTooltip.__lines, "\n")
    truthy(lines:find("On The Terminal List", 1, true), "header")
    truthy(lines:find("camps the Goldshire inn", 1, true), "note")
    truthy(lines:find("Killed you 5 times", 1, true), "kill count: " .. lines)
    truthy(lines:find("PvP kill", 1, true), "how added")
    -- Unlisted / off: nothing.
    GameTooltip.__lines = {}
    S.units.mouseover = { guid = "Player-1-00007777", name = "Clean" }
    M.tooltipHooks[2](GameTooltip)
    eq(#GameTooltip.__lines, 0)
    S.units.mouseover = { guid = "Player-1-00000001", name = "Killer" }
    ns.DB.Settings().tooltip = false
    M.tooltipHooks[2](GameTooltip)
    eq(#GameTooltip.__lines, 0, "off")
    ns.DB.Settings().tooltip = true
end)

test("chat: listed sender's lines get the crosshair; listed names in text turn red", function()
    local filter = M.chatFilters.CHAT_MSG_SAY[1]
    local hide, msg, author = filter(nil, "CHAT_MSG_SAY", "lol get rekt", "Killer-CAMWOWUS2Realm1PvE")
    eq(hide, false)
    truthy(msg:find(ns.CROSSHAIR, 1, true), "crosshair in front")
    truthy(msg:find("lol get rekt", 1, true))
    eq(author, "Killer-CAMWOWUS2Realm1PvE", "sender untouched")
    hide, msg = filter(nil, "CHAT_MSG_CHANNEL", "watch out, killer is at the docks", "Friendly-CAMWOWUS2Realm1PvE")
    truthy(msg:find(ns.MARK_HEX .. "killer|r", 1, true), "name in text coloured")
    truthy(not msg:find(ns.CROSSHAIR, 1, true), "no crosshair for an unlisted sender")
    eq(select("#", filter(nil, "CHAT_MSG_SAY", "hello there", "Friendly")), 1, "untouched line: just false")
    -- Links are never rewritten.
    eq(select(2, filter(nil, "CHAT_MSG_SAY", "|cff|Hitem:1|h[Killer]|h|r", "Friendly")), nil)
    -- Secret chat (instances) is left alone.
    M.InstallSecrets()
    eq(select("#", filter(nil, "CHAT_MSG_SAY", M.SECRET, M.SECRET)), 1)
    M.RemoveSecrets()
    ns.DB.Settings().chat = false
    eq(select("#", filter(nil, "CHAT_MSG_SAY", "lol", "Killer")), 1, "off")
    ns.DB.Settings().chat = true
end)

test("alert: off by default; on = once per session per player, with sound", function()
    M.printed, M.sounds = {}, {}
    ns.Alert.session = {}
    S.units.mouseover = { guid = "Player-1-00000001", name = "Killer" }
    M.Fire("UPDATE_MOUSEOVER_UNIT")
    truthy(not printed("is here"), "silent by default")
    ns.DB.Settings().alert = true
    M.Fire("UPDATE_MOUSEOVER_UNIT")
    truthy(printed("Killer|r is here (mouseover)"), "alerted")
    eq(#M.sounds, 1, "one sound")
    truthy(M.raidNotice, "raid-warning message")
    M.printed = {}
    local target = S.units.target
    S.units.target = nil
    M.Fire("UPDATE_MOUSEOVER_UNIT")
    M.Fire("PLAYER_TARGET_CHANGED")
    S.units.target = target
    truthy(not printed("Killer|r is here"), "once per session")
    eq(#M.sounds, 1)
    ns.DB.Settings().alert = false
end)

----------------------------------------------------------------------------
-- Right-click menus
----------------------------------------------------------------------------
test("unit menu: Add for an unlisted player, Remove/Edit note for a listed one", function()
    S.units.target = { guid = "Player-1-00004444", name = "Rudester", class = "MAGE", race = "Gnome", raceToken = "Gnome", faction = "Alliance" }
    local root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    local add = root:Button("Add to The Terminal List")
    truthy(add, "add offered")
    M.popups = {}
    add.fn()
    local e = ns.List.Get("rudester-camwowus2realm1pve")
    truthy(e, "added from the menu")
    eq(e.faction, "Alliance", "same-faction players can be listed")
    eq(lastPopup().which, "THETERMINALLIST_NOTE", "asks for a note")
    root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    truthy(root:Button("Remove from The Terminal List"), "remove offered")
    truthy(root:Button("Edit note"), "edit offered")
    eq(root:Button("Add to The Terminal List"), nil)
    M.popups = {}
    root:Button("Remove from The Terminal List").fn()
    eq(lastPopup().which, "THETERMINALLIST_REMOVE", "remove asks first")
    StaticPopupDialogs.THETERMINALLIST_REMOVE.OnAccept(nil, lastPopup().data)
    eq(ns.List.Get("rudester-camwowus2realm1pve"), nil, "removed")
end)

test("chat-name menu (name + server), NPCs and yourself get nothing", function()
    local root = M.MenuRoot()
    M.menus.MENU_UNIT_FRIEND(nil, root, { name = "Chatjerk", server = "OtherRealm" })
    root:Button("Add to The Terminal List").fn()
    truthy(ns.List.Get("chatjerk-otherrealm"), "added from a chat name")
    S.units.target = { guid = "Creature-0-1-2-3-299-0000", name = "Hogger", player = false }
    root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    eq(#root.items, 0, "nothing on NPCs")
    root = M.MenuRoot()
    M.menus.MENU_UNIT_SELF = M.menus.MENU_UNIT_PLAYER
    M.menus.MENU_UNIT_PLAYER(nil, root, { unit = "player" })
    eq(#root.items, 0, "nothing on yourself")
    root = M.MenuRoot()
    M.menus.MENU_UNIT_FRIEND(nil, root, { name = "Rip" })
    eq(#root.items, 0, "nothing on your own chat name")
end)

----------------------------------------------------------------------------
-- Forever last names ("Eugene Snorkel"): identity is first name + realm
----------------------------------------------------------------------------
test("last names: unit, chat and typed spellings all find the same entry", function()
    -- UnitName hands over first + last; the GUID says same realm.
    S.units.target = { guid = "Player-1-0000E0E0", name = "Eugene", realm = "Snorkel", class = "MAGE", race = "Gnome", raceToken = "Gnome", faction = "Alliance" }
    S.guids["Player-1-0000E0E0"] = { name = "Eugene", realm = "", class = "MAGE", race = "Gnome", raceToken = "Gnome" }
    ns.Slash("add")
    local e = ns.List.Get("eugene-camwowus2realm1pve")
    truthy(e, "keyed by first name + my realm")
    eq(e.last, "Snorkel", "last name kept")
    eq(e.realm, "CAMWOWUS2Realm1PvE", "last name not taken for a realm")
    eq(ns.List.Display(e), "Eugene Snorkel")
    local n = ns.List.Count()
    ns.Slash("add Eugene Snorkel")      -- typed with a space: first token only, still the same person
    ns.Slash("add Eugene-Snorkel")      -- joined with a dash, "Snorkel" isn't a realm we know
    eq(ns.List.Count(), n, "no duplicates")
    eq(ns.List.KeyFor("Eugene Snorkel"), "eugene-camwowus2realm1pve")
    eq(ns.List.KeyFor("Eugene-Snorkel"), "eugene-camwowus2realm1pve")
    -- Chat line from "Eugene Snorkel" is marked.
    local _, msg = M.chatFilters.CHAT_MSG_SAY[1](nil, "CHAT_MSG_SAY", "hi", "Eugene Snorkel")
    truthy(msg and msg:find(ns.CROSSHAIR, 1, true), "chat sender with a last name")
    -- The target frame finds them too.
    M.Fire("PLAYER_TARGET_CHANGED")
    eq(ns.Target.Mark():IsShown(), true)
    -- A real other-realm name on a realm we know stays separate.
    ns.Slash("add Eugene-OtherRealm")
    truthy(ns.List.Get("eugene-otherrealm"), "known realm: separate person")
    ns.List.Remove("eugene-otherrealm")
    ns.List.Remove("eugene-camwowus2realm1pve")
end)

test("a player added by hand doesn't trigger the session alert right away", function()
    ns.DB.Settings().alert = true
    M.printed = {}
    S.units.target = { guid = "Player-1-0000F1F1", name = "Freshjerk", hostile = true }
    ns.Slash("add")
    M.Fire("PLAYER_TARGET_CHANGED")
    truthy(not printed("is here"), "no alert for the person you just added")
    ns.DB.Settings().alert = false
    ns.List.Remove("freshjerk-camwowus2realm1pve")
end)

----------------------------------------------------------------------------
-- Window, settings, persistence
----------------------------------------------------------------------------
test("list window shows every column; notes are escaped", function()
    ns.List.SetNote("chatjerk-otherrealm", "said |cffff0000rude|r things")
    ns.UI.SetFilter("")
    M.texts = {}
    ns.UI.Open("list")
    truthy(textHas("Chatjerk-OtherRealm"), "name-realm")
    truthy(textHas("said ||cffff0000rude||r things"), "note escaped, never run as colour codes")
    truthy(textHas("PvP kill") and textHas("Manual"), "source chips")
    truthy(textHas("kills"), "kill count")
    truthy(textHas("Undead Mage"), "race and class")
    -- Filters and sorts.
    ns.db.global.filter = "pvp"
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("Killer") and not textHas("Chatjerk"), "pvp filter")
    ns.db.global.filter, ns.db.global.sort = "all", "kills"
    local rows = ns.List.Query("", "kills", "all")
    eq(rows[1].name, "Killer", "most kills first")
    rows = ns.List.Query("", "name", "all")
    truthy(rows[1].key < rows[2].key, "name order")
    renderAll("full")
end)

local function settingsCheck(label)
    local frame = rawget(_G, "TheTerminalListFrame")
    for _, cb in ipairs(frame.views.settings.layout.pools.check) do
        if cb.__shown and cb.text.__text == label then return cb end
    end
    error("no checkbox " .. label)
end

test("settings toggles change and persist in the account saved variables", function()
    ns.UI.Open("settings", "List & PvP")
    local cb = settingsCheck("Also add everyone who hit me in the last few seconds")
    cb:SetChecked(true)
    cb.__scripts.OnClick(cb)
    eq(TheTerminalListDB.settings.addRecentDamagers, true)
    ns.UI.Open("settings", "Recognition")
    cb = settingsCheck("Crosshair beside their nameplate")
    cb:SetChecked(false)
    cb.__scripts.OnClick(cb)
    eq(TheTerminalListDB.settings.nameplate, false)
    -- Reload: same values come back.
    local acc = ns.DB.Init(TheTerminalListDB, TheTerminalListCharDB)
    eq(acc.settings.addRecentDamagers, true)
    eq(acc.settings.nameplate, false)
    acc.settings.addRecentDamagers, acc.settings.nameplate = false, true
end)

test("minimap button and compartment toggle the window", function()
    local b = rawget(_G, "TheTerminalListMinimapButton")
    truthy(b, "minimap button")
    eq(b.icon.__texture, ns.CROSSHAIR)
    local was = ns.UI.IsShown()
    b.__scripts.OnClick(b, "LeftButton")
    eq(ns.UI.IsShown(), not was)
    TheTerminalList_OnCompartmentClick()
    eq(ns.UI.IsShown(), was)
    b.__scripts.OnClick(b, "RightButton")
    eq(ns.db.char.window.tab, "settings", "right-click opens settings")
end)

test("no macros, keybinds or /click anywhere", function()
    for _, f in ipairs(tocFiles("TheTerminalList.toc")) do
        local s = io.open(f):read("*a")
        for _, bad in ipairs({ "CreateMacro", "SetBinding", "SetOverrideBinding", "/click", "SecureActionButton" }) do
            truthy(not s:find(bad, 1, true), f .. " uses " .. bad)
        end
    end
end)

----------------------------------------------------------------------------
-- The Good Folk (second list, heart mark, never auto-added)
----------------------------------------------------------------------------
local function goodKey(name) return name:lower() .. "-camwowus2realm1pve" end
local function noneOnBoth()
    for k in pairs(TheTerminalListDB.good) do
        if TheTerminalListDB.entries[k] then error(k .. " is on both lists", 2) end
    end
end

test("heart texture: 64x64 32-bit TGA, not the crosshair, no raid-target art", function()
    local d = io.open("Media/Heart.tga", "rb"):read("*a")
    eq(d:byte(3), 2, "uncompressed true colour")
    eq(d:byte(13) + d:byte(14) * 256, 64, "width")
    eq(d:byte(15) + d:byte(16) * 256, 64, "height")
    eq(d:byte(17), 32, "bpp")
    eq(#d, 18 + 64 * 64 * 4, "size")
    truthy(d ~= io.open("Media/Crosshair.tga", "rb"):read("*a"), "a different image from the crosshair")
    truthy(io.open("tools/make-heart.py"), "generator committed")
    truthy(ns.HEART:find("Media\\Heart", 1, true), "heart path")
    truthy(ns.HEART ~= ns.CROSSHAIR)
    truthy(ns.HeartIcon(12):find(ns.HEART, 1, true) and not ns.HeartIcon(12):find(ns.CROSSHAIR, 1, true), "HeartIcon is the heart")
    truthy(ns.Icon(12):find(ns.CROSSHAIR, 1, true), "Icon is still the crosshair")
    for _, f in ipairs(tocFiles("TheTerminalList.toc")) do
        local s = io.open(f):read("*a")
        for _, bad in ipairs({ "RaidTarget", "TargetingFrame", "UI-Raid", "skull" }) do
            truthy(not s:find(bad, 1, true), f .. " uses " .. bad)
        end
    end
end)

test("migration: schema 1 saved variables keep The List and every setting; Good Folk starts empty", function()
    local old = {
        schema = 1,
        entries = {
            ["meanie-camwowus2realm1pve"] = { key = "meanie-camwowus2realm1pve", name = "Meanie", realm = "CAMWOWUS2Realm1PvE",
                added = 1700000000, updated = 1700000100, note = "camped me", source = "pvp", kills = 3, assists = 1, class = "MAGE" },
            ["rude-otherrealm"] = { key = "rude-otherrealm", name = "Rude", realm = "OtherRealm", added = 1700000200,
                updated = 1700000200, note = "", source = "manual", kills = 0, assists = 0 },
        },
        settings = { autoAdd = false, addRecentDamagers = true, damageWindow = 12, nameplate = false, alert = true, alertSound = false,
            target = true, tooltip = false, chat = true, askWhenUnknown = false, debug = false },
        minimap = { angle = 42, hide = true },
        sort = "kills", filter = "pvp",
    }
    local function copy(t)
        if type(t) ~= "table" then return t end
        local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o
    end
    local function same(a, b, path)
        if type(a) ~= type(b) then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end
        if type(a) ~= "table" then if a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b)) end return end
        for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
        for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " added") end end
    end
    local before = copy(old)
    local acc, char = ns.DB.Init(old, { schema = 1, window = { tab = "settings" } })
    same(acc.entries, before.entries, "entries")
    for k, v in pairs(before.settings) do eq(acc.settings[k], v, "setting " .. k) end
    same(acc.minimap, before.minimap, "minimap")
    eq(acc.sort, "kills"); eq(acc.filter, "pvp")
    eq(type(acc.good), "table", "good table created")
    eq(next(acc.good), nil, "Good Folk empty")
    eq(acc.schema, 2, "schema written"); eq(ns.DB.SCHEMA, 2)
    eq(char.schema, 2); eq(char.window.tab, "settings", "window state kept")
    eq(ns.List.Count(), 2); eq(ns.Good.Count(), 0)
    eq(ns.List.Get("meanie-camwowus2realm1pve").kills, 3)
    -- Running Init again changes nothing.
    local again = copy(acc)
    same(ns.DB.Init(acc, char), again, "second login")
    -- Fresh install: schema 2 with an empty Good Folk list.
    local fresh = ns.DB.Init(nil, nil)
    eq(fresh.schema, 2); eq(next(fresh.good), nil); eq(next(fresh.entries), nil)
    -- Back to the test session's saved variables.
    TheTerminalListDB, TheTerminalListCharDB = ns.DB.Init(TheTerminalListDB, TheTerminalListCharDB)
    eq(TheTerminalListDB.schema, 2)
    eq(type(TheTerminalListDB.good), "table")
end)

test("/tlist good: add by target, by Name and Name-Realm, with note; self and bad names refused", function()
    S.units.target = { guid = "Player-1-00006001", name = "Kindsoul", class = "MAGE", race = "Gnome", raceToken = "Gnome", faction = "Alliance" }
    M.printed = {}
    local listBefore = ns.List.Count()
    ns.Slash("good")
    local g = ns.Good.Get(goodKey("Kindsoul"))
    truthy(g, "added by target")
    eq(g.source, "manual"); eq(g.class, "MAGE"); eq(g.faction, "Alliance"); eq(g.kills, nil, "no kill counter")
    eq(ns.List.Get(goodKey("Kindsoul")), nil, "not on The List")
    eq(ns.List.Count(), listBefore, "The List unchanged")
    truthy(printed("Kindsoul added to the Good Folk"), "confirmation")
    truthy(printed(ns.HEART), "with the heart")
    ns.Slash("good Healbot rezzed me in Duskwood")
    eq(ns.Good.Get(goodKey("Healbot")).note, "rezzed me in Duskwood", "by name with note")
    ns.Slash("good Pal-OtherRealm")
    truthy(ns.Good.Get("pal-otherrealm"), "Name-Realm")
    eq(ns.List.Display(ns.Good.Get("pal-otherrealm")), "Pal-OtherRealm")
    local n = ns.Good.Count()
    M.printed = {}
    ns.Slash("good Rip")
    truthy(printed("That's you."), "self refused")
    ns.Slash("good 1337")
    truthy(printed("doesn't look like a character name"), "bad name refused")
    ns.Slash("good Healbot")
    truthy(printed("already one of the Good Folk"), "no duplicate")
    eq(ns.Good.Count(), n)
    M.popups = {}
    ns.Slash("good Healbot also bought me a drink")
    eq(lastPopup().which, "THETERMINALLIST_GOOD_NOTE", "re-add with a note offers the Good Folk note editor")
    eq(lastPopup().data.suggest, "also bought me a drink")
    S.units.target = nil
    M.printed = {}
    ns.Slash("good")
    truthy(printed("/tlist good Name"), "no target: says how")
    noneOnBoth()
end)

test("/tlist goodnote and /tlist good note; empty text opens the editor", function()
    ns.Slash("goodnote Pal-OtherRealm always shares quests")
    eq(ns.Good.Get("pal-otherrealm").note, "always shares quests")
    ns.Slash("good note Healbot best healer around")
    eq(ns.Good.Get(goodKey("Healbot")).note, "best healer around")
    S.units.target = { guid = "Player-1-00006001", name = "Kindsoul", hostile = false }
    ns.Slash("goodnote gave me 10 silver")
    eq(ns.Good.Get(goodKey("Kindsoul")).note, "gave me 10 silver", "whole text for the targeted Good Folk")
    M.popups = {}
    ns.Slash("goodnote Healbot")
    eq(lastPopup().which, "THETERMINALLIST_GOOD_NOTE")
    StaticPopupDialogs.THETERMINALLIST_GOOD_NOTE.OnAccept({ editBox = (function() local eb = M.newObject("EditBox") eb:SetText("saved via dialog") return eb end)() }, lastPopup().data)
    eq(ns.Good.Get(goodKey("Healbot")).note, "saved via dialog")
    S.units.target = nil
    M.printed = {}
    ns.Slash("goodnote Gankalot hi")
    truthy(printed("Not one of the Good Folk"), "a Terminal List player isn't given a Good Folk note")
    eq(ns.List.Get("gankalot-camwowus2realm1pve").note ~= "hi", true)
    -- /tlist note stays The List only.
    M.printed = {}
    ns.Slash("note Healbot hello")
    truthy(printed("Not on the list"), "/tlist note ignores the Good Folk")
end)

test("/tlist ungood and /tlist good remove (by name and target)", function()
    ns.Slash("good Tempfriend")
    ns.Slash("ungood tempfriend")
    eq(ns.Good.Get(goodKey("Tempfriend")), nil, "ungood by name, any case")
    ns.Slash("good Tempfriend")
    ns.Slash("good remove Tempfriend")
    eq(ns.Good.Get(goodKey("Tempfriend")), nil, "good remove")
    S.units.target = { guid = "Player-1-00006002", name = "Tempfriend" }
    ns.Slash("good")
    truthy(ns.Good.Get(goodKey("Tempfriend")))
    ns.Slash("ungood")
    eq(ns.Good.Get(goodKey("Tempfriend")), nil, "ungood the target")
    M.printed = {}
    ns.Slash("ungood Nobodyatall")
    truthy(printed("isn't one of the Good Folk"))
    -- /tlist remove on a Good Folk name leaves them alone and points at ungood.
    M.printed = {}
    ns.Slash("remove Healbot")
    truthy(ns.Good.Get(goodKey("Healbot")), "still Good Folk")
    truthy(printed("/tlist ungood Healbot"), "hint")
    S.units.target = nil
end)

test("one list at a time: adding to one moves them off the other, with a notice", function()
    -- The List -> Good Folk, keeping the note.
    ns.Slash("add Turncoat stole my node")
    ns.List.Get(goodKey("Turncoat")).kills = 2
    M.printed = {}
    ns.Slash("good Turncoat")
    local g = ns.Good.Get(goodKey("Turncoat"))
    truthy(g, "on the Good Folk")
    eq(ns.List.Get(goodKey("Turncoat")), nil, "off The List")
    eq(g.note, "stole my node", "note kept")
    eq(g.kills, nil, "no PvP record on the Good Folk")
    truthy(printed("Turncoat was on The Terminal List and has been moved to the Good Folk"), "notice")
    truthy(printed("2 kills"), "says what wasn't carried over")
    noneOnBoth()
    -- Good Folk -> The List with a new note.
    M.printed = {}
    ns.Slash("add Turncoat betrayed me after all")
    local e = ns.List.Get(goodKey("Turncoat"))
    truthy(e, "back on The List")
    eq(ns.Good.Get(goodKey("Turncoat")), nil, "off the Good Folk")
    eq(e.note, "betrayed me after all", "a new note replaces the old one")
    eq(e.source, "manual"); eq(e.kills, 0)
    truthy(printed("Turncoat was on the Good Folk and has been moved to The Terminal List"), "notice")
    noneOnBoth()
    -- Data layer: the Get lookups never agree.
    ns.Good.Add({ name = "Turncoat", realm = "CAMWOWUS2Realm1PvE" })
    truthy(ns.Good.Get(goodKey("Turncoat")) and not ns.List.Get(goodKey("Turncoat")))
    ns.List.Add({ name = "Turncoat", realm = "CAMWOWUS2Realm1PvE" }, { source = "manual" })
    truthy(ns.List.Get(goodKey("Turncoat")) and not ns.Good.Get(goodKey("Turncoat")))
    eq(ns.List.Get(goodKey("Turncoat")).note, "betrayed me after all", "note carried both ways")
    -- Nothing can make a Good Folk entry with source pvp.
    eq(ns.Good.Add({ name = "Pvpfriend", realm = "CAMWOWUS2Realm1PvE" }, { source = "pvp" }), nil, "Good.Add refuses source pvp")
    ns.List.Remove(goodKey("Turncoat"))
    noneOnBoth()
end)

test("right-click menu: separate Good Folk entries, reflecting the player's list", function()
    S.units.target = { guid = "Player-1-00006003", name = "Menufriend", class = "MAGE", hostile = false }
    local root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    truthy(root:Button("Add to The Terminal List"), "Terminal List add")
    truthy(root:Button("Add to the Good Folk"), "separate Good Folk add")
    M.popups = {}
    root:Button("Add to the Good Folk").fn()
    truthy(ns.Good.Get(goodKey("Menufriend")), "added from the menu")
    eq(ns.List.Get(goodKey("Menufriend")), nil)
    eq(lastPopup().which, "THETERMINALLIST_GOOD_NOTE", "asks for a Good Folk note")
    root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    truthy(root:Button("Edit Good Folk note"), "edit Good Folk note")
    truthy(root:Button("Remove from the Good Folk"), "remove from Good Folk")
    truthy(root:Button("Move to The Terminal List"), "Terminal List entry reads Move")
    eq(root:Button("Add to The Terminal List"), nil)
    eq(root:Button("Add to the Good Folk"), nil)
    eq(root:Button("Edit note"), nil, "no Terminal List note for a Good Folk player")
    -- Move them over from the menu, then back.
    M.printed = {}
    root:Button("Move to The Terminal List").fn()
    truthy(ns.List.Get(goodKey("Menufriend")) and not ns.Good.Get(goodKey("Menufriend")), "moved to The List")
    truthy(printed("has been moved to The Terminal List"))
    root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    truthy(root:Button("Edit note") and root:Button("Remove from The Terminal List"), "Terminal List items")
    truthy(root:Button("Move to the Good Folk"), "Good Folk entry reads Move")
    root:Button("Move to the Good Folk").fn()
    truthy(ns.Good.Get(goodKey("Menufriend")) and not ns.List.Get(goodKey("Menufriend")), "moved back")
    -- Remove asks first.
    root = M.MenuRoot()
    M.menus.MENU_UNIT_TARGET(nil, root, { unit = "target" })
    M.popups = {}
    root:Button("Remove from the Good Folk").fn()
    eq(lastPopup().which, "THETERMINALLIST_GOOD_REMOVE")
    StaticPopupDialogs.THETERMINALLIST_GOOD_REMOVE.OnAccept(nil, lastPopup().data)
    eq(ns.Good.Get(goodKey("Menufriend")), nil, "removed")
    -- Chat-name menu works too.
    root = M.MenuRoot()
    M.menus.MENU_UNIT_FRIEND(nil, root, { name = "Chatpal", server = "OtherRealm" })
    root:Button("Add to the Good Folk").fn()
    truthy(ns.Good.Get("chatpal-otherrealm"))
    S.units.target = nil
    noneOnBoth()
end)

test("marks: heart (not crosshair) on target frame, nameplate, tooltip and chat; no alert", function()
    ns.DB.Settings().alert = true
    ns.Alert.session = {}
    M.printed, M.sounds, M.raidNotice = {}, {}, nil
    -- Target frame.
    S.units.target = { guid = "Player-1-00006001", name = "Kindsoul", hostile = false }
    M.Fire("PLAYER_TARGET_CHANGED")
    local mark = ns.Target.Mark()
    eq(mark:IsShown(), true, "shown for a Good Folk target")
    eq(mark.tex.__texture, ns.HEART, "heart on the target frame")
    eq(mark.which, "good")
    -- Target frame tooltip.
    GameTooltip.__lines = {}
    mark.__scripts.OnEnter(mark)
    truthy(GameTooltip.__text == "Good Folk", "target mark tooltip title")
    -- A Terminal List target swaps back to the crosshair.
    S.units.target = { guid = "Player-1-0000BEEF", name = "Gankalot", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    eq(mark.tex.__texture, ns.CROSSHAIR, "crosshair for The List")
    -- Nameplates: same plate token, heart then crosshair.
    S.units.nameplate4 = { guid = "Player-1-00006001", name = "Kindsoul" }
    local p4 = M.AddPlate("nameplate4")
    M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    truthy(p4.ttlMark and p4.ttlMark:IsShown(), "Good Folk plate marked")
    eq(p4.ttlMark.tex.__texture, ns.HEART, "heart on the nameplate")
    truthy(ns.Good.Get(goodKey("Kindsoul")).lastSeen, "last seen recorded")
    S.units.nameplate4 = { guid = "Player-1-00000001", name = "Killer", hostile = true }
    M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    eq(p4.ttlMark.tex.__texture, ns.CROSSHAIR, "recycled plate shows the crosshair for The List")
    M.plates, S.units.nameplate4 = {}, nil
    -- Tooltip.
    S.units.mouseover = { guid = "Player-1-00006001", name = "Kindsoul" }
    GameTooltip.__lines = {}
    GameTooltip.GetUnit = function() return "Kindsoul", "mouseover" end
    M.tooltipHooks[2](GameTooltip)
    local lines = table.concat(GameTooltip.__lines, "\n")
    truthy(lines:find("Good Folk", 1, true), "says Good Folk: " .. lines)
    truthy(lines:find("gave me 10 silver", 1, true), "with the note")
    truthy(lines:find(ns.HEART, 1, true), "heart")
    truthy(not lines:find("Terminal List", 1, true), "not 'On The Terminal List'")
    truthy(not lines:find(ns.CROSSHAIR, 1, true), "no crosshair")
    truthy(not lines:find("Killed you", 1, true) and not lines:find("PvP kill", 1, true) and not lines:find("Manual", 1, true), "no PvP lines")
    -- Chat: heart in front, name never painted red.
    local filter = M.chatFilters.CHAT_MSG_SAY[1]
    local _, msg = filter(nil, "CHAT_MSG_SAY", "hi friend", "Kindsoul-CAMWOWUS2Realm1PvE")
    truthy(msg:find(ns.HEART, 1, true), "heart in chat")
    truthy(not msg:find(ns.CROSSHAIR, 1, true), "no crosshair in chat")
    eq(select("#", filter(nil, "CHAT_MSG_SAY", "kindsoul is great", "Somebody")), 1, "Good Folk name in text not recoloured")
    local _, msg2 = filter(nil, "CHAT_MSG_SAY", "lol", "Killer")
    truthy(msg2:find(ns.CROSSHAIR, 1, true) and not msg2:find(ns.HEART, 1, true), "The List still gets the crosshair")
    -- No alert for the Good Folk (Gankalot/Killer were seen above; reset and look at a friend only).
    ns.Alert.session, M.printed, M.sounds, M.raidNotice = {}, {}, {}, nil
    S.units.target = { guid = "Player-1-00006001", name = "Kindsoul" }
    M.Fire("PLAYER_TARGET_CHANGED")
    M.Fire("UPDATE_MOUSEOVER_UNIT")
    truthy(not printed("is here"), "no 'is here' for the Good Folk")
    eq(#M.sounds, 0, "no sound"); eq(M.raidNotice, nil, "no raid warning")
    ns.DB.Settings().alert = false
    S.units.target, S.units.mouseover = nil, nil
end)

test("PvP auto-add: Good Folk killers and assists are left alone; others added as before", function()
    rawset(_G, "CombatLogGetCurrentEventInfo", function() return unpack(cleu) end)
    player("Player-1-00006001", "Kindsoul", nil, "MAGE", "Gnome")
    player("Player-1-00006010", "Strangerkill", nil, "WARRIOR", "Orc")
    local goodBefore, listBefore = ns.Good.Count(), ns.List.Count()
    local kills = ns.List.Get("killer-camwowus2realm1pve").kills
    -- A Good Folk killer.
    M.printed = {}
    S.time = S.time + 60
    spell("Player-1-00006001", "Kindsoul", 40)
    die()
    eq(ns.List.Get(goodKey("Kindsoul")), nil, "not added to The List")
    truthy(ns.Good.Get(goodKey("Kindsoul")), "still Good Folk (not moved)")
    eq(ns.Good.Get(goodKey("Kindsoul")).kills, nil, "no kill counted")
    truthy(printed("Kindsoul killed you, but they're on the Good Folk (\"gave me 10 silver\"), so they weren't added to The Terminal List."), "note printed")
    eq(ns.List.Count(), listBefore)
    -- A Terminal List killer still counts; an unknown killer is still added.
    spell("Player-1-00000001", "Killer", 20)
    die()
    eq(ns.List.Get("killer-camwowus2realm1pve").kills, kills + 1, "Terminal List killer bumped")
    spell("Player-1-00006010", "Strangerkill", 20)
    die()
    local st = ns.List.Get(goodKey("Strangerkill"))
    truthy(st and st.source == "pvp" and st.kills == 1, "unknown killer added as before")
    -- Assists: a Good Folk damager is skipped, others added.
    local s = ns.DB.Settings()
    s.addRecentDamagers = true
    M.printed = {}
    swing("Player-1-00006001", "Kindsoul", -1)
    swing("Player-1-00000002", "Helper", -1)
    S.time = S.time + 2
    spell("Player-1-00000001", "Killer", 20)
    die()
    eq(ns.List.Get(goodKey("Kindsoul")), nil, "Good Folk assist not added")
    truthy(printed("Kindsoul hit you just before you died, but they're on the Good Folk"), "assist note")
    eq(ns.List.Get("helper-camwowus2realm1pve").assists, 2, "other assist counted")
    -- Good Folk killer + a normal assist: the assist is still recorded.
    swing("Player-1-00000002", "Helper", -1)
    S.time = S.time + 1
    spell("Player-1-00006001", "Kindsoul", 20) -- the killing blow resolves the death right away
    die()
    eq(ns.List.Get("helper-camwowus2realm1pve").assists, 3, "assist recorded alongside a Good Folk killer")
    ns.Combat.recent = { { t = S.time, guid = "Player-1-00006001", name = "Kindsoul", flags = 0x548, killing = true } }
    eq(ns.Combat.Resolve(), "good", "Resolve reports a Good Folk killer")
    S.time = S.time + 60
    s.addRecentDamagers = false
    -- Nobody was ever put on the Good Folk by any of this.
    eq(ns.Good.Count(), goodBefore, "nobody auto-added to the Good Folk")
    for _, g in pairs(TheTerminalListDB.good) do truthy(g.source ~= "pvp", g.key .. " has source pvp") end
    noneOnBoth()
    ns.List.Remove(goodKey("Strangerkill"))
    rawset(_G, "CombatLogGetCurrentEventInfo", nil)
end)

test("no combat log: Yes on the ask popup for a Good Folk target adds nobody", function()
    S.units.target = { guid = "Player-1-00006001", name = "Kindsoul", hostile = true }
    M.Fire("PLAYER_TARGET_CHANGED")
    M.popups, M.printed = {}, {}
    S.time = S.time + 5
    die()
    truthy(lastPopup() and lastPopup().which == "THETERMINALLIST_ASK_KILLER", "asked")
    StaticPopupDialogs.THETERMINALLIST_ASK_KILLER.OnAccept()
    eq(ns.List.Get(goodKey("Kindsoul")), nil, "not added")
    truthy(ns.Good.Get(goodKey("Kindsoul")), "still Good Folk")
    truthy(printed("on the Good Folk"), "note printed")
    S.units.target = nil
    ns.Combat.lastHostile = nil
end)

test("list window: Good Folk filter shows hearts; All/PvP/Manual are The List only", function()
    ns.UI.SetFilter("")
    ns.db.global.filter = "good"
    M.texts = {}
    ns.UI.Open("list")
    truthy(textHas("Kindsoul") and textHas("Healbot"), "Good Folk listed")
    truthy(textHas(ns.HEART), "heart rows")
    truthy(textHas("Good Folk"), "chip / title")
    truthy(not textHas("Gankalot"), "no Terminal List players")
    truthy(not textHas("|r kill"), "no kill counts")
    ns.db.global.filter = "all"
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("Gankalot"), "The List")
    truthy(not textHas("Kindsoul") and not textHas("Healbot"), "'all' doesn't include the Good Folk")
    eq(#ns.List.Query("", "recent", "good"), ns.Good.Count())
    for _, e in ipairs(ns.List.Query("", "recent", "all")) do truthy(not ns.Good.Get(e.key), "all = The List only") end
    -- Empty states mention the Good Folk commands.
    local saved = TheTerminalListDB.good
    TheTerminalListDB.good = {}
    ns.db.global.filter = "good"
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("No Good Folk yet."), "Good Folk empty state")
    truthy(textHas("/tlist good Name"), "how to add")
    TheTerminalListDB.good = saved
    local savedEntries = TheTerminalListDB.entries
    TheTerminalListDB.entries = {}
    ns.db.global.filter = "all"
    M.texts = {}
    ns.UI.Refresh()
    truthy(textHas("The list is empty.") and textHas("/tlist good Name"), "Terminal List empty state mentions the Good Folk")
    TheTerminalListDB.entries = savedEntries
    ns.List.ResetIndex()
    M.texts = {}
    ns.Slash("about")
    truthy(textHas("/tlist good [Name[-Realm]] [note]"), "About lists the Good Folk commands")
    M.texts = {}
    ns.UI.Open("settings", "Recognition")
    truthy(textHas(ns.HEART), "Recognition mentions the heart")
    M.printed = {}
    ns.Slash("help")
    truthy(printed("/tlist good [Name[-Realm]] [note]") and printed("/tlist ungood") and printed("/tlist goodnote"), "help")
    renderAll("good folk")
end)

io.write(("%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
