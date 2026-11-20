-- SavedVariables.
--
-- TheTerminalListDB      (account)        the list itself + every setting, so a
--                                          name added on one character shows on all
-- TheTerminalListCharDB  (per character)  window state only
local _, ns = ...

local DB = {}
ns.DB = DB

DB.SCHEMA = 1

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
    debug = false,
}

DB.accountDefaults = {
    schema = DB.SCHEMA,
    entries = {},             -- key ("name-realm", lower case) -> entry, see Modules/List.lua
    settings = DB.settingsDefaults,
    minimap = { angle = 200, hide = false },
    sort = "recent",          -- list window: recent | kills | name
    filter = "all",           -- list window: all | pvp | manual
}

DB.charDefaults = {
    schema = DB.SCHEMA,
    window = { tab = "list" },
}

-- Wire up (or create) the saved tables. Pure function of its inputs so tests
-- can drive it without a client.
function DB.Init(account, char)
    account = deepDefaults(account or {}, DB.accountDefaults)
    char = deepDefaults(char or {}, DB.charDefaults)
    DB.global, DB.char = account, char
    ns.db = { global = account, char = char }
    return account, char
end

function DB.Settings()
    return ns.db.global.settings
end
