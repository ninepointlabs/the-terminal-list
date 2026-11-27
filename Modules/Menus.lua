-- Right-click menus: "Add to The Terminal List" / "Remove" / "Edit note" on
-- player portraits (target, focus, party, raid) and names in chat, plus
-- separate Good Folk entries ("Add to the Good Folk", "Edit Good Folk note",
-- "Remove from the Good Folk"). For someone on one list, the other list's
-- entry reads "Move to ..." (adding moves them). Anyone with recorded past
-- groups (on a list or not) also gets "Group history".
--
-- Uses the client's Menu.ModifyMenu("MENU_UNIT_*") hooks, built for addons to
-- extend (installed Forever addons use the same). Tags this client doesn't
-- have are skipped quietly. Without the Menu API, /tlist add still works.
local _, ns = ...

local Menus = {}
ns.Menus = Menus

Menus.TAGS = {
    "PLAYER", "ENEMY_PLAYER", "TARGET", "FOCUS", "PARTY", "RAID_PLAYER", "RAID", "FRIEND",
    "CHAT_ROSTER", "GUILD", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
}

-- Who the menu is about: from its unit, else from name + server (chat names).
function Menus.InfoFromContext(context)
    if type(context) ~= "table" then return nil end
    local unit = context.unit
    if unit and not ns.Secret(unit) and ns.Try(UnitExists, unit) then
        return ns.List.FromUnit(unit)
    end
    local name = context.name
    if type(name) ~= "string" or ns.Secret(name) or name == "" then return nil end
    local server = context.server
    local full = name
    if type(server) == "string" and server ~= "" and not ns.Secret(server) and not name:find("-", 1, true) then
        full = name .. "-" .. server
    end
    local n, realm, last = ns.List.Parse(full)
    if not n then return nil end
    local me = ns.Try(UnitName, "player")
    if me and not ns.Secret(me) and n:lower() == me:lower() and realm == ns.List.MyRealm() then return nil end
    return { name = n, realm = realm, last = last }
end

function Menus.Build(_, root, context)
    if not ns.db or ns.disabled or not root or not root.CreateButton then return end
    local info = Menus.InfoFromContext(context)
    if not info then return end
    local key = ns.List.ResolveKey(info.name, info.realm)
    local e, g = ns.List.Get(key), ns.Good.Get(key)
    if root.CreateDivider then root:CreateDivider() end
    if root.CreateTitle then root:CreateTitle(ns.TITLE) end
    -- The Terminal List
    if e then
        root:CreateButton("Edit note", function() ns.UI.EditNote(key) end)
        root:CreateButton("Remove from The Terminal List", function() ns.UI.ConfirmRemove(key) end)
    else
        root:CreateButton(g and "Move to The Terminal List" or "Add to The Terminal List", function()
            local added = ns.List.Add(info, { source = "manual" })
            if added then
                ns.Print(("%s %s added. Add a note?"):format(ns.Icon(), ns.List.Display(added)))
                ns.UI.EditNote(added.key)
            end
        end)
    end
    -- The Good Folk
    if g then
        root:CreateButton("Edit Good Folk note", function() ns.UI.EditGoodNote(key) end)
        root:CreateButton("Remove from the Good Folk", function() ns.UI.ConfirmRemoveGood(key) end)
    else
        root:CreateButton(e and "Move to the Good Folk" or "Add to the Good Folk", function()
            local added = ns.Good.Add(info)
            if added then
                ns.Print(("%s %s added to the Good Folk. Add a note?"):format(ns.HeartIcon(), ns.List.Display(added)))
                ns.UI.EditGoodNote(added.key)
            end
        end)
    end
    -- Past groups (only when there are some: never an empty item)
    if ns.Groups.Count(key) > 0 then
        root:CreateButton("Group history", function() ns.UI.ShowGroupHistory(key) end)
    end
end

function Menus.Install()
    if Menus.installed then return Menus.hooked end
    Menus.installed = true
    Menus.hooked = 0
    if not (Menu and Menu.ModifyMenu) then return 0 end
    for _, tag in ipairs(Menus.TAGS) do
        local ok = pcall(Menu.ModifyMenu, "MENU_UNIT_" .. tag, function(owner, root, context)
            pcall(Menus.Build, owner, root, context)
        end)
        if ok then Menus.hooked = Menus.hooked + 1 end
    end
    return Menus.hooked
end
