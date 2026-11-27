-- SavedVariables.
--
-- TheTerminalListDB      (account)        the list itself, the Good Folk, past
--                                          groups + every setting, so a name added
--                                          on one character shows on all
-- TheTerminalListCharDB  (per character)  window state only
local _, ns = ...

local DB = {}
ns.DB = DB

-- 1: v0.1.0 (entries + settings)
-- 2: adds `good`, the Good Folk list (same entry shape, never source "pvp")
-- 3: adds `groups`, past-group history (see Modules/Groups.lua) and the
--    groupBadge / groupBadgeList settings
DB.SCHEMA = 3

local function deepDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            deepDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end
DB.deepDefaults = deepDefaults

-- Defaults (BRIEF §6). Tim decided the crosshair marker and open-world-only
-- PvP; the on/off values below are the brief's defaults, his to change.
DB.settingsDefaults = {
    autoAdd = true,           -- add a player who kills me in open-world PvP
    addRecentDamagers = false, -- also add players who hit me just before (off by default)
    damageWindow = 8,         -- seconds before the killing blow that count
    askWhenUnknown = true,    -- no killer readable: offer to add my hostile target
    nameplate = true,
    target = true,
    tooltip = true,
    chat = true,
    alert = false,            -- once-per-session alert when a listed player shows up
    alertSound = true,        -- ...with a short built-in sound (only if alert is on)
    groupBadge = true,        -- number badge (times grouped) on nameplates and the target frame
    groupBadgeList = false,   -- ...also beside The Terminal List's crosshair (off: crosshair only)
    debug = false,
}

DB.accountDefaults = {
    schema = DB.SCHEMA,
    entries = {},             -- key ("name-realm", lower case) -> entry, see Modules/List.lua
    good = {},                -- the Good Folk: same keys and entry shape, see Modules/List.lua
    groups = {},              -- past groups: same keys, see Modules/Groups.lua
    settings = DB.settingsDefaults,
    minimap = { angle = 200, hide = false },
    sort = "recent",          -- list window: recent | kills | name
    filter = "all",           -- list window: all | pvp | manual (The List) | good (the Good Folk)
}

DB.charDefaults = {
    schema = DB.SCHEMA,
    window = { tab = "list" },
}

-- Bring older saved variables up to DB.SCHEMA. Only adds what's missing:
-- existing entries and settings are never rewritten.
function DB.Migrate(account, char)
    if (tonumber(account.schema) or 1) < 2 then
        if type(account.good) ~= "table" then account.good = {} end
    end
    if (tonumber(account.schema) or 1) < 3 then
        if type(account.groups) ~= "table" then account.groups = {} end
    end
    if (tonumber(account.schema) or 1) < DB.SCHEMA then account.schema = DB.SCHEMA end
    if (tonumber(char.schema) or 1) < DB.SCHEMA then char.schema = DB.SCHEMA end
end

-- Wire up (or create) the saved tables. Pure function of its inputs so tests
-- can drive it without a client.
function DB.Init(account, char)
    account = account or {}
    char = char or {}
    DB.Migrate(account, char)
    account = deepDefaults(account, DB.accountDefaults)
    char = deepDefaults(char, DB.charDefaults)
    DB.global, DB.char = account, char
    ns.db = { global = account, char = char }
    return account, char
end

function DB.Settings()
    return ns.db.global.settings
end
