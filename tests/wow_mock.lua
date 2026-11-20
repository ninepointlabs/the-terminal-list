-- Minimal, strict WoW API mock for headless tests (Lua 5.1), in the style of
-- the sister addons' mocks. Undefined globals raise an error so typos and
-- unmocked APIs surface here instead of in the client. Optional APIs the addon
-- feature-tests are listed in OPTIONAL and read as nil.
local M = {}

M.texts = {}       -- every SetText call, for assertions
M.printed = {}     -- every print() line
M.events = {}      -- frames registered per event
M.timers = {}
M.popups = {}      -- StaticPopup_Show calls: { which, a1, a2, data }
M.menus = {}       -- Menu.ModifyMenu tag -> callback
M.chatFilters = {} -- event -> { filter, ... }
M.plates = {}      -- nameplate unit -> plate object
M.sounds = {}

M.state = {
    projectId = 18, combat = false, time = 1000, now = 1795190400, -- now: 2026-11-20
    zone = "Elwynn Forest", realm = "CAMWOWUS2Realm1PvE",
    instanceType = nil, -- nil = open world; "pvp" | "arena" | "party" | "raid" | "scenario"
    me = { guid = "Player-1-0000000A", name = "Rip", class = "ROGUE", race = "Human", raceToken = "Human", faction = "Alliance" },
    units = {},        -- token -> { guid, name, realm, player, class, race, raceToken, faction, hostile, pet = guid }
    guids = {},        -- guid -> { name, realm, class, race, raceToken } (GetPlayerInfoByGUID)
}
local S = M.state

local function newObject(kind)
    local o = { __kind = kind, __shown = true, __scripts = {}, __w = 100, __h = 20 }
    return setmetatable(o, {
        __index = function(t, k)
            if k == "SetText" then
                return function(self, s) self.__text = s table.insert(M.texts, tostring(s or "")) end
            elseif k == "GetText" then
                return function(self) return self.__text end
            elseif k == "SetScript" then
                return function(self, ev, fn) self.__scripts[ev] = fn end
            elseif k == "GetScript" then
                return function(self, ev) return self.__scripts[ev] end
            elseif k == "HookScript" then
                return function(self, ev, fn) self.__scripts[ev] = fn end
            elseif k == "RegisterEvent" or k == "RegisterUnitEvent" then
                return function(self, ev) M.events[ev] = M.events[ev] or {} table.insert(M.events[ev], self) end
            elseif k == "UnregisterEvent" then
                return function() end
            elseif k == "Show" then
                return function(self) self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
            elseif k == "Hide" then
                return function(self) self.__shown = false end
            elseif k == "SetShown" then
                return function(self, v) if v then self:Show() else self:Hide() end end
            elseif k == "IsShown" or k == "IsVisible" then
                return function(self) return self.__shown end
            elseif k == "SetWidth" then
                return function(self, w) self.__w = w end
            elseif k == "SetHeight" then
                return function(self, h) self.__h = h end
            elseif k == "SetSize" then
                return function(self, w, h) self.__w, self.__h = w, h end
            elseif k == "GetWidth" then
                return function(self) return self.__w end
            elseif k == "GetHeight" then
                return function(self) return self.__h end
            elseif k == "GetStringHeight" then
                return function() return 14 end
            elseif k == "GetStringWidth" then
                return function(self) return #(tostring(self.__text or "")) * 6 end
            elseif k == "GetChecked" then
                return function(self) return self.__checked end
            elseif k == "SetChecked" then
                return function(self, v) self.__checked = v end
            elseif k == "SetTexture" then
                return function(self, tex) self.__texture = tex end
            elseif k == "GetFrameLevel" then
                return function() return 1 end
            elseif k == "GetCenter" then
                return function() return 0, 0 end
            elseif k == "GetEffectiveScale" then
                return function() return 1 end
            elseif k == "Disable" then
                return function(self) self.__disabled = true end
            elseif k == "Enable" then
                return function(self) self.__disabled = false end
            elseif k == "AddLine" then
                return function(self, s) self.__lines = self.__lines or {} table.insert(self.__lines, tostring(s)) end
            elseif k:match("^%l") then
                return nil -- plain fields (frame.someField) are nil until set, as in the client
            elseif k:match("^Create") then
                return function() return newObject(k) end
            elseif k:match("^Is") or k:match("^Can") then
                return function() return false end
            else
                return function() return nil end
            end
        end,
    })
end
M.newObject = newObject

function M.Fire(event, ...)
    for _, f in ipairs(M.events[event] or {}) do
        local fn = f.__scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

function M.RunTimers()
    local list = M.timers
    M.timers = {}
    for _, t in ipairs(list) do if not t.cancelled then t.fn() end end
end

local function U(u)
    if u == "player" then return S.me end
    return S.units[u]
end
M.U = U

local G = {}

G.CreateFrame = function(kind, name) local f = newObject(kind) if name then rawset(_G, name, f) end return f end
G.UIParent = newObject("UIParent")
G.ChatFontNormal = newObject("Font")
G.Minimap = newObject("Minimap")
G.GameTooltip = newObject("GameTooltip")
G.TargetFrame = newObject("TargetFrame")
G.TargetFrame.portrait = newObject("Texture")
G.UISpecialFrames = {}
G.StaticPopupDialogs = {}
G.StaticPopup_Show = function(which, a1, a2, data) table.insert(M.popups, { which = which, a1 = a1, a2 = a2, data = data }) end
G.SlashCmdList = {}
G.CLOSE, G.ADD, G.CANCEL, G.SAVE, G.REMOVE, G.YES, G.NO = "Close", "Add", "Cancel", "Save", "Remove", "Yes", "No"
G.UNKNOWNOBJECT = "Unknown"
G.Mixin = function(o, m) for k, v in pairs(m) do o[k] = v end return o end
G.BackdropTemplateMixin = {}
G.Settings = { RegisterCanvasLayoutCategory = function() return {} end, RegisterAddOnCategory = function() end }
G.SettingsPanel = newObject("SettingsPanel")
G.HideUIPanel = function() end
G.Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) M.tooltipHooks = M.tooltipHooks or {} M.tooltipHooks[kind] = fn end }
G.C_Timer = {
    After = function(_, fn) table.insert(M.timers, { fn = fn }) end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.cancelled = true end } table.insert(M.timers, t) return t end,
}
G.C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
G.RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
G.LOCALIZED_CLASS_NAMES_MALE = { ROGUE = "Rogue", WARRIOR = "Warrior", MAGE = "Mage" }
G.SOUNDKIT = { RAID_WARNING = 8959 }
G.PlaySound = function(id) table.insert(M.sounds, id) end
G.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0 } }
G.RaidWarningFrame = newObject("RaidWarningFrame")
G.RaidNotice_AddMessage = function(_, msg) M.raidNotice = msg end
G.time = function() return S.now end
G.date = os.date
G.GetTime = function() return S.time end
G.GetCursorPosition = function() return 0, 0 end
G.InCombatLockdown = function() return S.combat end
G.hooksecurefunc = function(a, b, c)
    -- hooksecurefunc(table, "method", fn) or hooksecurefunc("global", fn)
    if type(a) == "table" then
        local orig = a[b]
        a[b] = function(...) local r = orig and orig(...) c(...) return r end
    else
        local orig = rawget(_G, a)
        rawset(_G, a, function(...) local r = orig and orig(...) b(...) return r end)
    end
end
G.StartDuel = function() end
G.GetNormalizedRealmName = function() return S.realm end
G.GetRealmName = function() return S.realm end
G.GetZoneText = function() return S.zone end
G.GetRealZoneText = function() return S.zone end

-- Units
G.UnitExists = function(u) return U(u) ~= nil end
G.UnitIsPlayer = function(u) return U(u) and (U(u).player ~= false) or false end
G.UnitIsUnit = function(a, b) return U(a) and U(b) and U(a).guid == U(b).guid or false end
G.UnitGUID = function(u)
    local base, pet = u:match("^(.-)pet$")
    if base and base ~= "" and U(base) then return U(base).pet end
    return U(u) and U(u).guid
end
G.UnitName = function(u)
    local x = U(u)
    if not x then return nil end
    if u == "player" then return x.name end
    return x.name, x.realm
end
G.UnitClass = function(u) local x = U(u) if not x then return nil end return x.class, x.class end
G.UnitRace = function(u) local x = U(u) if not x then return nil end return x.race, x.raceToken end
G.UnitFactionGroup = function(u) local x = U(u) if not x then return nil end return x.faction, x.faction end
G.UnitCanAttack = function(_, u) local x = U(u) return x and x.hostile or false end
G.GetPlayerInfoByGUID = function(guid)
    local x = S.guids[guid]
    if not x then return nil end
    return x.class, x.class, x.race, x.raceToken, 2, x.name, x.realm or ""
end
G.IsInInstance = function() if S.instanceType then return true, S.instanceType end return false, "none" end
G.GetInstanceInfo = function() local t = S.instanceType or "none" return "Somewhere", t end
G.C_NamePlate = {
    GetNamePlateForUnit = function(u) return M.plates[u] end,
    GetNamePlates = function() local out = {} for _, p in pairs(M.plates) do table.insert(out, p) end return out end,
}
G.Menu = { ModifyMenu = function(tag, fn) M.menus[tag] = fn end }
G.ChatFrameUtil = { AddMessageEventFilter = function(ev, fn) M.chatFilters[ev] = M.chatFilters[ev] or {} table.insert(M.chatFilters[ev], fn) end }

-- A nameplate for a unit token (the plate's UnitFrame has a name FontString).
function M.AddPlate(unit)
    local p = newObject("NamePlate")
    p.namePlateUnitToken = unit
    p.UnitFrame = { name = newObject("FontString"), unit = unit }
    M.plates[unit] = p
    return p
end

-- A fake Menu root that records what the addon adds.
function M.MenuRoot()
    local root = { items = {} }
    function root:CreateDivider() table.insert(self.items, { kind = "divider" }) end
    function root:CreateTitle(t) table.insert(self.items, { kind = "title", text = t }) end
    function root:CreateButton(t, fn) table.insert(self.items, { kind = "button", text = t, fn = fn }) return {} end
    function root:Button(text)
        for _, it in ipairs(self.items) do if it.kind == "button" and it.text == text then return it end end
    end
    return root
end

-- Secret values (Forever's addon restrictions): an opaque sentinel that
-- issecretvalue() recognises once a test installs it.
M.SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function M.InstallSecrets() rawset(_G, "issecretvalue", function(v) return v == M.SECRET end) end
function M.RemoveSecrets() rawset(_G, "issecretvalue", nil) end

local OPTIONAL = {
    issecretvalue = true, WOW_PROJECT_CAMELOT = true,
    CombatLogGetCurrentEventInfo = true, -- Forever: believed absent; tests install it to cover both paths
    C_PvP = true, IsActiveBattlefieldArena = true, UnitInBattleground = true,
    UnitTokenFromGUID = true, UnitIsOwnerOrControllerOfUnit = true,
    ChatFrame_AddMessageEventFilter = true, TargetFramePortrait = true,
    TheTerminalListDB = true, TheTerminalListCharDB = true, TheTerminalListFrame = true,
    TheTerminalListMinimapButton = true, TheTerminalListSearch = true, TheTerminalListTargetMark = true,
    SLASH_THETERMINALLIST1 = true, TheTerminalList_OnCompartmentClick = true,
}

function M.Install()
    for k, v in pairs(G) do rawset(_G, k, v) end
    rawset(_G, "WOW_PROJECT_ID", S.projectId)
    rawset(_G, "print", function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        table.insert(M.printed, table.concat(parts, " "))
    end)
    setmetatable(_G, {
        __index = function(_, k)
            if OPTIONAL[k] then return nil end
            error("undefined global: " .. tostring(k), 2)
        end,
    })
end

-- Load every file listed in the TOC with (addonName, ns) varargs.
function M.LoadAddon(tocPath, root)
    local ns = {}
    for line in io.lines(tocPath) do
        if not line:match("^##") and line:match("%S") then
            local path = root .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
            local chunk = assert(loadfile(path))
            chunk("TheTerminalList", ns)
        end
    end
    return ns
end

return M
