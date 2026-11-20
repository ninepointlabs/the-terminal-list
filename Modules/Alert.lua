-- Sightings: refresh last-seen, and (optional, off by default) alert once per
-- session the first time a listed player shows up on a nameplate, as my target
-- or under the mouse.
local _, ns = ...

local Alert = {}
ns.Alert = Alert

Alert.session = {} -- key -> true once alerted this session (not saved)

-- A short built-in sound; no audio files ship with the addon.
local function playSound()
    local kit = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK)
    if kit and PlaySound then pcall(PlaySound, kit, "Master") end
end

-- unit: a token that may be a listed player. Returns the entry when listed.
function Alert.Check(unit, how)
    if not ns.db then return nil end
    local key, info = ns.List.KeyForUnit(unit)
    local e = key and ns.List.Get(key)
    if not e then return nil end
    ns.List.Seen(key, info)
    local s = ns.DB.Settings()
    if s.alert and not Alert.session[key] then
        Alert.session[key] = true
        local note = (e.note and e.note ~= "") and (": " .. ns.Escape(e.note)) or ""
        ns.Print(("%s %s is here (%s)%s"):format(ns.Icon(16), ns.MARK_HEX .. ns.List.Display(e) .. "|r", how or "seen", note))
        if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
            pcall(RaidNotice_AddMessage, RaidWarningFrame, "The Terminal List: " .. ns.List.Display(e), ChatTypeInfo.RAID_WARNING)
        end
        if s.alertSound then playSound() end
    end
    return e
end
