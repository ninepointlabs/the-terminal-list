-- Dialogs: add by name, edit a note, confirm remove (The List and the Good
-- Folk each have their own), "were you killed by...?", copy a link. Blizzard StaticPopups, so they look like the game's own.
local _, ns = ...
local UI = ns.UI

local function editBox(self)
    return self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
end

local function hide(self) self:GetParent():Hide() end

StaticPopupDialogs.THETERMINALLIST_COPY_URL = {
    text = "The Terminal List: press Ctrl+C to copy this link.",
    button1 = CLOSE or "Close",
    hasEditBox = true, editBoxWidth = 380,
    OnShow = function(self, data)
        local eb = editBox(self)
        if eb then eb:SetText(data or "") eb:HighlightText() eb:SetFocus() end
    end,
    EditBoxOnEscapePressed = hide, EditBoxOnEnterPressed = hide,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.CopyURL(url)
    if url and url ~= "" then StaticPopup_Show("THETERMINALLIST_COPY_URL", nil, nil, url) end
end

-- Add by name ------------------------------------------------------------
function UI.AddByName(text)
    local name, realm, last = ns.List.Parse(text)
    if not name then
        ns.Print("That doesn't look like a character name. Use Name or Name-Realm.")
        return nil
    end
    local e, created = ns.List.Add({ name = name, realm = realm, last = last }, { source = "manual" })
    if not e then return nil end
    if created then
        ns.Print(("%s %s added."):format(ns.Icon(), ns.List.Display(e)))
    else
        ns.Print(("%s is already on the list. Edit the note instead?"):format(ns.List.Display(e)))
    end
    UI.EditNote(e.key)
    return e, created
end

StaticPopupDialogs.THETERMINALLIST_ADD = {
    text = "Add a player to The Terminal List.\nName or Name-Realm:",
    button1 = ADD or "Add", button2 = CANCEL or "Cancel",
    hasEditBox = true, editBoxWidth = 260, maxLetters = 64,
    OnAccept = function(self) local eb = editBox(self) UI.AddByName(eb and eb:GetText()) end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        UI.AddByName(self:GetText())
        p:Hide()
    end,
    EditBoxOnEscapePressed = hide,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.PromptAdd()
    StaticPopup_Show("THETERMINALLIST_ADD")
end

function UI.AddGoodByName(text)
    local name, realm, last = ns.List.Parse(text)
    if not name then
        ns.Print("That doesn't look like a character name. Use Name or Name-Realm.")
        return nil
    end
    local g, created = ns.Good.Add({ name = name, realm = realm, last = last })
    if not g then return nil end
    if created then
        ns.Print(("%s %s added to the Good Folk."):format(ns.HeartIcon(), ns.List.Display(g)))
    else
        ns.Print(("%s is already one of the Good Folk. Edit the note instead?"):format(ns.List.Display(g)))
    end
    UI.EditGoodNote(g.key)
    return g, created
end

StaticPopupDialogs.THETERMINALLIST_GOOD_ADD = {
    text = "Add a player to the Good Folk.\nName or Name-Realm:",
    button1 = ADD or "Add", button2 = CANCEL or "Cancel",
    hasEditBox = true, editBoxWidth = 260, maxLetters = 64,
    OnAccept = function(self) local eb = editBox(self) UI.AddGoodByName(eb and eb:GetText()) end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        UI.AddGoodByName(self:GetText())
        p:Hide()
    end,
    EditBoxOnEscapePressed = hide,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.PromptAddGood()
    StaticPopup_Show("THETERMINALLIST_GOOD_ADD")
end

-- Edit note ----------------------------------------------------------------
-- One dialog per list; store is ns.List or ns.Good.
local function noteDialog(text, store)
    return {
        text = text,
        button1 = SAVE or "Save", button2 = CANCEL or "Cancel",
        hasEditBox = true, editBoxWidth = 380, maxLetters = 250,
        OnShow = function(self, data)
            local eb = editBox(self)
            local e = data and store.Get(data.key)
            if eb then
                eb:SetText((data and data.suggest) or (e and e.note) or "")
                eb:HighlightText()
                eb:SetFocus()
            end
        end,
        OnAccept = function(self, data)
            local eb = editBox(self)
            if data and eb then store.SetNote(data.key, eb:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self, data)
            local p = self:GetParent()
            data = data or p.data
            if data then store.SetNote(data.key, self:GetText()) end
            p:Hide()
        end,
        EditBoxOnEscapePressed = hide,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end
StaticPopupDialogs.THETERMINALLIST_NOTE = noteDialog("Note for %s:", ns.List)
StaticPopupDialogs.THETERMINALLIST_GOOD_NOTE = noteDialog("Good Folk note for %s:", ns.Good)

-- suggest: text to prefill instead of the current note (e.g. a new note
-- typed in /tlist add for someone already listed).
function UI.EditNote(key, suggest)
    local e = ns.List.Get(key)
    if not e then return end
    StaticPopup_Show("THETERMINALLIST_NOTE", ns.List.Display(e), nil, { key = key, suggest = suggest })
end

function UI.EditGoodNote(key, suggest)
    local g = ns.Good.Get(key)
    if not g then return end
    StaticPopup_Show("THETERMINALLIST_GOOD_NOTE", ns.List.Display(g), nil, { key = key, suggest = suggest })
end

-- Remove ---------------------------------------------------------------------
StaticPopupDialogs.THETERMINALLIST_REMOVE = {
    text = "Remove %s from The Terminal List?",
    button1 = REMOVE or "Remove", button2 = CANCEL or "Cancel",
    OnAccept = function(_, data)
        local e = data and ns.List.Remove(data.key)
        if e then ns.Print(ns.List.Display(e) .. " removed.") end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.ConfirmRemove(key)
    local e = ns.List.Get(key)
    if not e then return end
    StaticPopup_Show("THETERMINALLIST_REMOVE", ns.List.Display(e), nil, { key = key })
end

StaticPopupDialogs.THETERMINALLIST_GOOD_REMOVE = {
    text = "Remove %s from the Good Folk?",
    button1 = REMOVE or "Remove", button2 = CANCEL or "Cancel",
    OnAccept = function(_, data)
        local g = data and ns.Good.Remove(data.key)
        if g then ns.Print(ns.List.Display(g) .. " removed from the Good Folk.") end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.ConfirmRemoveGood(key)
    local g = ns.Good.Get(key)
    if not g then return end
    StaticPopup_Show("THETERMINALLIST_GOOD_REMOVE", ns.List.Display(g), nil, { key = key })
end

-- No combat log: "were you killed by...?" -------------------------------------
StaticPopupDialogs.THETERMINALLIST_ASK_KILLER = {
    text = "You died in the open world. The game doesn't tell addons who landed the killing blow.\n\nYou were fighting %s. Add them to The Terminal List?",
    button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function() ns.Combat.ConfirmPending() end,
    OnCancel = function() ns.Combat.pending = nil end,
    timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function UI.AskAddKiller(info)
    StaticPopup_Show("THETERMINALLIST_ASK_KILLER", ns.List.Display(info))
end
