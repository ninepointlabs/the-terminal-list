-- Chat: a red crosshair in front of lines from a listed player, and listed
-- names inside message text coloured red.
--
-- The sender's clickable [Name] is built by Blizzard's chat code after
-- filters run, so a filter can't recolour it; replacing Blizzard's name
-- functions would risk taint, so the line is marked instead.
-- In instances chat reaches addons as secret values; those lines are left alone.
local _, ns = ...

local Chat = {}
ns.Chat = Chat

Chat.EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_SYSTEM",
}

local function authorKey(author)
    if type(author) ~= "string" or author == "" then return nil end
    return (ns.List.KeyFor(author))
end

-- Colour whole-word mentions of listed names (skips lines with links so they
-- never break).
function Chat.ColorNames(msg)
    if type(msg) ~= "string" or msg:find("|", 1, true) then return msg, false end
    local idx = ns.List.NameIndex()
    if not next(idx) then return msg, false end
    local changed = false
    local out = msg:gsub("[^%s%p%c%d]+", function(word)
        if idx[word:lower()] then
            changed = true
            return ns.MARK_HEX .. word .. "|r"
        end
    end)
    return out, changed
end

-- ChatFrame message filter: return false, newMsg, ... to change the line.
function Chat.Filter(_, event, msg, author, ...)
    if not ns.db or not ns.DB.Settings().chat then return false end
    if ns.Secret(msg, author) or type(msg) ~= "string" then return false end
    local listed = event ~= "CHAT_MSG_SYSTEM" and authorKey(author) and ns.List.Get(authorKey(author))
    local newMsg, changed = Chat.ColorNames(msg)
    if listed then
        newMsg = ns.Icon(12) .. " " .. newMsg
        changed = true
    end
    if not changed then return false end
    return false, newMsg, author, ...
end

function Chat.Install()
    if Chat.installed then return end
    Chat.installed = true
    -- The newer registry (ChatFrameUtil) where it exists, else the old global.
    -- Only one, so a line is never marked twice.
    local util = ChatFrameUtil
    local add = (util and util.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if not add then return end
    for _, ev in ipairs(Chat.EVENTS) do pcall(add, ev, Chat.Filter) end
end
