-- Events, slash command, startup. Loaded last.
local ADDON, ns = ...

local f = CreateFrame("Frame")
ns.EventFrame = f

local function RefreshMarks()
    pcall(ns.Target.Update)
    pcall(ns.Nameplates.UpdateAll)
end
ns.RefreshMarks = RefreshMarks

local refreshPending
local function SoftRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.2, function()
        refreshPending = false
        ns.UI.Refresh()
    end)
end

local function OnLogin()
    if ns.disabled then
        ns.Print(("This addon is for WoW Forever only (needs WOW_PROJECT_ID %d, this client reports %s). It will stay off."):format(
            ns.FOREVER_PROJECT_ID, tostring(WOW_PROJECT_ID)))
        return
    end
    TheTerminalListDB, TheTerminalListCharDB = ns.DB.Init(TheTerminalListDB, TheTerminalListCharDB)
    ns.UI.MinimapButton()
    ns.UI.RegisterSettings()
    ns.Tooltip.Install()
    ns.Chat.Install()
    ns.Menus.Install()
    ns.Combat.HookDuels()

    for _, ev in ipairs({ "PLAYER_DEAD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_DISABLED",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_ENTERING_WORLD",
        "DUEL_REQUESTED", "DUEL_INBOUNDS", "DUEL_OUTOFBOUNDS", "DUEL_FINISHED" }) do
        pcall(f.RegisterEvent, f, ev)
    end
    -- Only when this client hands the combat log to addons (see Modules/Combat.lua).
    if ns.Combat.HasCombatLog() then pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED") end
    RefreshMarks()
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then f:UnregisterEvent("ADDON_LOADED") end
        return
    end
    if event == "PLAYER_LOGIN" then
        OnLogin()
        return
    end
    if ns.disabled or not ns.db then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        ns.Combat.OnCombatLog(CombatLogGetCurrentEventInfo())
    elseif event == "PLAYER_DEAD" then
        ns.Combat.OnPlayerDead()
    elseif event == "PLAYER_TARGET_CHANGED" then
        pcall(ns.Combat.NoteHostile, "target")
        pcall(ns.Target.Update)
    elseif event == "PLAYER_REGEN_DISABLED" then
        pcall(ns.Combat.NoteHostile, "target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        pcall(ns.Alert.Check, "mouseover", "mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if unit then pcall(ns.Nameplates.Update, unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if unit then pcall(ns.Nameplates.Removed, unit) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshMarks()
    elseif event:match("^DUEL_") then
        ns.Combat.OnDuel(event, ...)
    end
end)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

ns.On("LIST_CHANGED", function()
    RefreshMarks()
    SoftRefresh()
end)
ns.On("RECOGNITION_CHANGED", RefreshMarks)
ns.On("MINIMAP_TOGGLE", function() ns.UI.MinimapButton() end)

----------------------------------------------------------------------------
-- /tlist
----------------------------------------------------------------------------
local Cmd = {}
ns.Commands = Cmd

local function isMe(name, realm)
    local me = ns.Try(UnitName, "player")
    return type(me) == "string" and not ns.Secret(me) and me:lower() == name:lower() and realm == ns.List.MyRealm()
end

-- "Name[-Realm]" -> info, or the current target when text is empty.
local function who(text)
    if text and text ~= "" then
        local name, realm, last = ns.List.Parse(text)
        if not name then return nil, "\"" .. ns.Escape(text) .. "\" doesn't look like a character name. Use Name or Name-Realm." end
        if isMe(name, realm) then return nil, "That's you." end
        local tKey, tInfo = ns.List.KeyForUnit("target")
        if tKey and tKey == ns.List.ResolveKey(name, realm) then return tInfo end
        return { name = name, realm = realm, last = last }
    end
    local _, info = ns.List.KeyForUnit("target")
    if not info then return nil, "Target another player, or give a name: /tlist add Name[-Realm] [note]" end
    return info
end

function Cmd.Add(rest)
    local first, note = (rest or ""):match("^(%S*)%s*(.-)$")
    local info, err = who(first)
    if not info then ns.Print(err) return nil end
    local e, created = ns.List.Add(info, { source = "manual", note = note ~= "" and note or nil })
    if not e then return nil end
    if created then
        ns.Print(("%s %s added%s."):format(ns.Icon(), ns.List.Display(e), e.note ~= "" and (": \"" .. ns.Escape(e.note) .. "\"") or ""))
        if e.note == "" then ns.Print("Add a reason any time: /tlist note " .. ns.List.Display(e) .. " <text>") end
    elseif note ~= "" then
        -- Already listed: never a duplicate; offer the new text as the note.
        ns.Print(("%s is already on the list. Update the note?"):format(ns.List.Display(e)))
        ns.UI.EditNote(e.key, note)
    else
        ns.Print(("%s is already on the list. /tlist note %s <text> changes the note."):format(ns.List.Display(e), ns.List.Display(e)))
    end
    return e, created
end

function Cmd.Remove(rest)
    local info, err = who(ns.Trim(rest))
    if not info then ns.Print(err) return nil end
    local key = ns.List.ResolveKey(info.name, info.realm)
    local e = ns.List.Remove(key)
    if e then ns.Print(ns.List.Display(e) .. " removed from the list.")
    else ns.Print(info.name .. " isn't on the list.") end
    return e
end

function Cmd.Note(rest)
    rest = ns.Trim(rest)
    local first, text = rest:match("^(%S*)%s*(.-)$")
    local key = first ~= "" and ns.List.KeyFor(first)
    if not (key and ns.List.Get(key)) then
        -- No listed name first: the whole text is the note for my target.
        key = ns.List.KeyForUnit("target")
        text = rest
        if not (key and ns.List.Get(key)) then
            ns.Print("Not on the list. Use /tlist note Name[-Realm] <text>, or target a listed player.")
            return nil
        end
    end
    if text == "" then
        ns.UI.EditNote(key)
        return ns.List.Get(key)
    end
    local e = ns.List.SetNote(key, text)
    ns.Print(("Note for %s: \"%s\""):format(ns.List.Display(e), ns.Escape(e.note)))
    return e
end

function Cmd.Help()
    ns.Print("/tlist  open or close the window")
    ns.Print("/tlist add [Name[-Realm]] [note]  add (no name: your target)")
    ns.Print("/tlist remove [Name[-Realm]]  remove (no name: your target)")
    ns.Print("/tlist note [Name[-Realm]] [text]  set the reason note")
    ns.Print("/tlist search <text> · /tlist settings · /tlist help")
end

function ns.Slash(msg)
    if ns.disabled then
        ns.Print("Disabled: WoW Forever only.")
        return
    end
    if not ns.db then return end
    msg = ns.Trim(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "list" or cmd == "show" then
        ns.UI.Toggle()
    elseif cmd == "add" then
        return Cmd.Add(rest)
    elseif cmd == "remove" or cmd == "rm" or cmd == "del" or cmd == "delete" then
        return Cmd.Remove(rest)
    elseif cmd == "note" then
        return Cmd.Note(rest)
    elseif cmd == "search" or cmd == "find" then
        ns.UI.SetFilter(rest)
        ns.UI.Open("list")
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        ns.UI.Open("settings")
    elseif cmd == "about" then
        ns.UI.Open("settings", "About")
    else
        Cmd.Help()
    end
end

SLASH_THETERMINALLIST1 = "/tlist"
SlashCmdList.THETERMINALLIST = function(msg) ns.Slash(msg) end
