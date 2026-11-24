-- The Terminal List: namespace, client guard, tiny event bus, helpers.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "The Terminal List"
local meta = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
-- An unpackaged checkout still carries the packager token.
ns.VERSION = tostring(meta):find("@", 1, true) and "dev" or meta

-- Forever only. WOW_PROJECT_CAMELOT (= 18) is the Forever project id per the
-- wow-ui-source forever branch; refuse to run anywhere else.
ns.FOREVER_PROJECT_ID = WOW_PROJECT_CAMELOT or 18
ns.disabled = (WOW_PROJECT_ID ~= ns.FOREVER_PROJECT_ID)

-- The list marker. Tim chose a crosshair (2026-11-20); Media/Crosshair.tga is
-- drawn by tools/make-crosshair.py.
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
ns.CROSSHAIR = ns.MEDIA .. "Crosshair"
ns.MARK_COLOR = { 0.92, 0.19, 0.19 }
ns.MARK_HEX = "|cffeb3030"

function ns.Icon(size)
    size = size or 14
    return ("|T%s:%d:%d:0:0|t"):format(ns.CROSSHAIR, size, size)
end

-- The Good Folk mark (Tim, 2026-11-24: "a heart next to their name instead of
-- the target icon"). Media/Heart.tga is drawn by tools/make-heart.py.
ns.HEART = ns.MEDIA .. "Heart"
ns.GOOD_COLOR = { 1.0, 0.47, 0.71 }

function ns.HeartIcon(size)
    size = size or 14
    return ("|T%s:%d:%d:0:0|t"):format(ns.HEART, size, size)
end

local listeners = {}
function ns.On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok and ns.Debug then ns.Debug("listener error for " .. event .. ": " .. tostring(err)) end
    end
end

function ns.Print(msg)
    print(ns.MARK_HEX .. "The Terminal List|r: " .. tostring(msg))
end

function ns.Debug(msg)
    if ns.db and ns.db.global and ns.db.global.settings.debug then
        print("|cff888888[TTL debug]|r " .. tostring(msg))
    end
end

-- Forever hides some values from addons ("secret values"): they can be passed
-- around but not compared. True if any argument is one, so callers back off.
function ns.Secret(...)
    local isSecret = issecretvalue
    if not isSecret then return false end
    for i = 1, select("#", ...) do
        if isSecret((select(i, ...))) then return true end
    end
    return false
end

-- Call fn safely; returns its results, or nothing when it errors or is missing.
function ns.Try(fn, ...)
    if type(fn) ~= "function" then return end
    local res = { pcall(fn, ...) }
    if not res[1] then return end
    return unpack(res, 2)
end

function ns.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Player-written text must never be read as colour or link codes.
function ns.Escape(s)
    return (tostring(s or ""):gsub("|", "||"))
end
