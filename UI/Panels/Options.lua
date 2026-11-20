-- Settings: List & PvP · Recognition · About (the sister addons' Options style).
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}
local S = UI.SettingsSections

local TABS = { "List & PvP", "Recognition", "About" }
local tab = TABS[1]

local function dim(text) return UI.Hex(UI.C.dim) .. text .. "|r" end

S["List & PvP"] = function(L)
    local s, g = ns.DB.Settings(), ns.db.global
    L:Label("Open-world PvP")
    L:Check("Add a player who kills me in open-world PvP", s.autoAdd, function(v) s.autoAdd = v UI.Refresh() end,
        "Only in the open world. Battlegrounds, arenas, dungeons, raids, other instances and duels never count.")
    L:Text(dim("Battlegrounds, arenas, dungeons, raids, scenarios and duels never count: that's PvP you chose. A second death to the same player adds to their kill count instead of a new row."), { size = 12, indent = 30 })
    L:Check("Also add everyone who hit me in the last few seconds", s.addRecentDamagers, function(v) s.addRecentDamagers = v UI.Refresh() end,
        "Off by default. Only other players' damage counts, and only when the death itself counts.")
    local steps = { 4, 6, 8, 10, 12 }
    L:Row({ title = "Damage window", sub = "How many seconds before the killing blow count as \"hit me just before\".",
        right = s.damageWindow .. " s",
        button = { label = "Change", onClick = function()
            local nextV = steps[1]
            for i, v in ipairs(steps) do if v == s.damageWindow then nextV = steps[i + 1] or steps[1] end end
            s.damageWindow = nextV
            UI.Refresh()
        end } })
    L:Check("If the killer can't be read, ask about the hostile player I was fighting", s.askWhenUnknown,
        function(v) s.askWhenUnknown = v end,
        "Some clients don't give addons the combat log. Then the addon can't know who killed you; it asks instead of guessing.")
    if not ns.Combat.HasCombatLog() then
        L:Flag("This client doesn't give addons the combat log, so killers can't be read. After an open-world death the addon asks about the hostile player you had targeted instead.")
    end

    L:Label("Window")
    L:Check("Show minimap button", not g.minimap.hide, function(v) g.minimap.hide = not v ns.Fire("MINIMAP_TOGGLE") end)
    L:Check("Debug messages", s.debug, function(v) s.debug = v end)
    L:Text(dim("Slash: /tlist · /tlist add [Name[-Realm]] [note] · /tlist remove [Name] · /tlist note [Name] [text] · /tlist search <text> · /tlist settings · /tlist help"), { size = 12 })
end

S.Recognition = function(L)
    local s = ns.DB.Settings()
    L:Text("How you spot listed players again. Every mark is the red crosshair " .. ns.Icon(16) .. ".", { size = 13 })
    L:Label("Marks")
    local cb = L:Check("Crosshair beside their nameplate", s.nameplate, function(v) s.nameplate = v ns.Fire("RECOGNITION_CHANGED") end,
        "Nameplates only show at fairly close range, so this is a 'nearby' mark.")
    if not ns.Nameplates.Available() then
        if cb.Disable then cb:Disable() end
        L:Text(dim("This client doesn't expose nameplates to addons."), { size = 12, indent = 30 })
    else
        L:Text(dim("Nameplates only show at fairly close range; turn on enemy/friendly player nameplates in the game's options."), { size = 12, indent = 30 })
    end
    L:Check("Crosshair on the target frame", s.target, function(v) s.target = v ns.Fire("RECOGNITION_CHANGED") end)
    L:Check("Tooltip line (note and kill count)", s.tooltip, function(v) s.tooltip = v end)
    L:Check("Mark their chat lines and colour their name in messages", s.chat, function(v) s.chat = v end,
        "A crosshair in front of their lines; their name inside messages turns red.")
    L:Label("Alert")
    L:Check("Alert me the first time I see a listed player each session", s.alert, function(v) s.alert = v UI.Refresh() end,
        "Off by default. A chat line and a raid-warning message, once per player per session.")
    local snd = L:Check("...with a short sound", s.alertSound, function(v) s.alertSound = v end)
    if not s.alert and snd.Disable then snd:Disable() end
end

S.About = function(L)
    local version = tostring(ns.VERSION)
    if not version:match("^v") then version = "v" .. version end
    L:Row({ icon = ns.CROSSHAIR, title = ns.TITLE .. " " .. version,
        sub = "A personal watch list for WoW Forever: players who crossed you, were rude, or don't play nice." })
    L:Label("Your list")
    L:Text("The list is stored on this computer only, in your account's saved variables, so every character on the account sees the same list. Nothing is uploaded or shared with anyone.", { size = 12 })
    L:Text(dim("Identity is Name-Realm. A player who renames or transfers realms shows up as someone new; their old entry stays as it was."), { size = 12 })
    L:Label("Commands")
    L:Text("/tlist  open or close the window\n/tlist add [Name[-Realm]] [note]  add (no name: your target)\n/tlist remove [Name[-Realm]]  remove (no name: your target)\n/tlist note [Name[-Realm]] [text]  set the note\n/tlist search <text>  search the list\n/tlist settings  these settings\n/tlist help", { size = 12 })
    L:Label("Links")
    L:Link("Source and issues", "https://github.com/ninepointlabs/the-terminal-list", "github.com/ninepointlabs/the-terminal-list (not public yet)")
    L:Label("Sister addons")
    L:Link("Andric's Addon", "https://andricsaddon.myazerothlife.com")
    L:Link("Parzelle's Addon", "https://parzelles-addon.myazerothlife.com")
    L:Link("Tristan's Addon", "https://tristans-addon.myazerothlife.com")
    L:Link("Tazu's Addon", "https://github.com/ninepointlabs/tazus-addon")
    L:Link("Forever Rogue", "https://github.com/ninepointlabs/forever-rogue")
    L:Label("Credits")
    L:Row({ title = "Made by Nine Point Labs", sub = "Free and open source, MIT licence." })
    L:Text(dim("The Terminal List is an unofficial fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc."), { size = 11 })
end

UI.RegisterPanel({
    key = "settings", label = "Settings",
    setSub = function(sub) for _, t in ipairs(TABS) do if t == sub then tab = sub end end end,
    render = function(L)
        L:Title("Settings")
        local items = {}
        for _, t in ipairs(TABS) do
            table.insert(items, { label = t, active = tab == t, onClick = function() tab = t UI.Refresh() end })
        end
        L:Tabs(items)
        local fn = S[tab] or S["List & PvP"]
        fn(L)
    end,
})
