-- Minimap button (no LibDBIcon dependency), addon compartment, Blizzard Settings entry.
local _, ns = ...
local UI = ns.UI

local btn

local function position()
    local angle = math.rad(ns.db.global.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 10
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function UI.MinimapButton()
    if btn then
        btn:SetShown(not ns.db.global.minimap.hide)
        return btn
    end
    btn = CreateFrame("Button", "TheTerminalListMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(18, 18)
    btn.icon:SetPoint("TOPLEFT", 7, -6)
    btn.icon:SetTexture(ns.CROSSHAIR)
    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then UI.Open("settings") else UI.Toggle() end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.global.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            position()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.TITLE)
        GameTooltip:AddLine(ns.List.Count() .. " on the list", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open · Right-click: settings · Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    position()
    btn:SetShown(not ns.db.global.minimap.hide)
    return btn
end

-- Addon compartment (TOC: AddonCompartmentFunc).
function TheTerminalList_OnCompartmentClick()
    if ns.disabled or not ns.db then return end
    UI.Toggle()
end

-- Blizzard Settings: a small page that opens the main window's Settings.
function UI.RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    local title = UI.Text(panel, 20, { 1, 0.82, 0.3 })
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ns.TITLE)
    local text = UI.Text(panel, 12)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetWidth(560)
    text:SetText("Your watch list of players who crossed you. All options live in the main window. Type /tlist.")
    local b = UI.Button(panel, "Open The Terminal List", 200, 26, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        UI.Open("settings")
    end)
    b:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, ns.TITLE)
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        UI.settingsCategory = category
    end
end
