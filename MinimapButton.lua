-- The minimap button: left-click turns private mode on or off (the same way
-- as the key and the window's big button), right-click opens or closes the
-- settings, and dragging moves it round the minimap's edge. A sibling of
-- Squirt's other addons' buttons: a dark circle in the minimap's gold ring,
-- here with this addon's eye, purple while private mode is on and grey while
-- it's off, so the state shows at a glance. Its hover box is its own (the
-- game's tooltip is never touched) and never shows your name. Like the eye,
-- it steps aside the moment a screenshot starts and comes back once it's
-- taken. The Overview's Extras tick (or /privacy minimap) hides it. Named
-- (ForeverEnhancedPrivacyMinimapButton) so minimap tidiers can find it.
local _, P = ...

local T = P.Theme
local C = T.C

local MB = {}
P.MinimapButton = MB

local RING_GAP = 4 -- how far out from the minimap's edge it sits
local AFTER_DRAG = .2 -- a click this soon after a drag is the drag letting go
local TIP_W, TIP_LINES = 220, 4
local atan2 = math.atan2 or math.atan

local button, tip, dragAngle
local dropped = -math.huge

-- Round the minimap's edge at the saved angle (degrees anticlockwise from
-- the right, so 180 is the left), or, while dragging, where the cursor is.
-- A circle, as the sibling buttons have it.
function MB:Place()
    if not button then return end
    local width = Minimap:GetWidth()
    if type(width) ~= "number" then width = 140 end
    local angle = math.rad(dragAngle or P:Get("minimapAngle"))
    local radius = width / 2 + RING_GAP
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Follow()
    local x, y = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    if type(x) ~= "number" or type(y) ~= "number" or type(cursorX) ~= "number" or type(cursorY) ~= "number" then return end
    local scale = Minimap:GetEffectiveScale() or 1
    dragAngle = math.floor(math.deg(atan2(cursorY / scale - y, cursorX / scale - x)) + .5) % 360
    MB:Place()
end

-- Saved once, where it was let go.
local function Drop(self)
    self:SetScript("OnUpdate", nil)
    self.isMoving = nil
    dropped = GetTime()
    local angle = dragAngle
    dragAngle = nil
    if angle then P:Set("minimapAngle", angle) end
    MB:Place()
end

-- The hover box ------------------------------------------------------------------------------

-- What it says: private mode's state, then what the mouse does. Never a
-- name of any kind.
local function TipLines()
    local on = P:Private()
    return {
        "Private mode: " .. (on and T:Paint("on", T.ACCENT) or "off"),
        on and "Left-click: turn it off" or "Left-click: turn it on",
        "Right-click: settings",
        "Drag: move it round the minimap",
    }
end

local function BuildTip()
    tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    tip:SetSize(TIP_W, 28 + TIP_LINES * 14)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    tip:EnableMouse(false)
    T:Flat(tip, C.window, T.ACCENT)
    tip.title = T:Text(tip, "GameFontHighlight", T.ACCENT)
    tip.title:SetPoint("TOPLEFT", 10, -8)
    tip.title:SetText(P.TITLE)
    tip.lines = {}
    for i = 1, TIP_LINES do
        local line = T:Text(tip, "GameFontHighlightSmall", i == 1 and C.text or C.soft)
        line:SetPoint("TOPLEFT", 10, -12 - i * 14)
        tip.lines[i] = line
    end
    tip:Hide()
end

local function FillTip()
    for i, text in ipairs(TipLines()) do tip.lines[i]:SetText(text) end
end

-- Toward the middle of the screen from the button, so it's never cut off.
local function ShowTip()
    if not tip then BuildTip() end
    FillTip()
    local right, top = true, true
    local x, y = button:GetCenter()
    local midX, midY = UIParent:GetCenter()
    if type(x) == "number" and type(y) == "number" and type(midX) == "number" and type(midY) == "number" then
        local scale = (button:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        right, top = x * scale > midX, y * scale > midY
    end
    tip:ClearAllPoints()
    tip:SetPoint((top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), button,
        (top and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT"), 0, 0)
    tip:Show()
end

local function HideTip()
    if tip then tip:Hide() end
end

-- The button ---------------------------------------------------------------------------------

local function Build()
    button = CreateFrame("Button", "ForeverEnhancedPrivacyMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    back:SetSize(20, 20)
    back:SetPoint("CENTER")
    back:SetVertexColor(.067, .071, .082)
    -- The eye sits in rows 12 to 52 of its 64 by 64 picture, as Eye.lua has it.
    local eye = button:CreateTexture(nil, "ARTWORK")
    eye:SetTexture(P.MEDIA .. "Eye.tga")
    eye:SetTexCoord(0, 1, 12 / 64, 52 / 64)
    eye:SetSize(16, 10)
    eye:SetPoint("CENTER")
    button.eye = eye
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, click)
        if GetTime() - dropped < AFTER_DRAG then return end
        if click == "RightButton" then
            if P.ToggleWindow then P.ToggleWindow() end
        else
            P:SetPrivate(not P:Private(), "minimap")
        end
    end)
    -- isMoving tells minimap tidiers not to fade it mid-drag, when the
    -- cursor can be well off the button.
    button:SetScript("OnDragStart", function(self)
        HideTip()
        self.isMoving = true
        self:SetScript("OnUpdate", Follow)
    end)
    button:SetScript("OnDragStop", Drop)
    -- Hidden mid-drag (a screenshot, say): let go there, so it doesn't trail
    -- the cursor later.
    button:SetScript("OnHide", function(self)
        HideTip()
        if self.isMoving then Drop(self) end
    end)
    button:SetScript("OnEnter", function(self)
        if not self.isMoving then ShowTip() end
    end)
    button:SetScript("OnLeave", HideTip)
end

-- Shown with its tick, unless a screenshot is being taken.
function MB:Wanted()
    return P:Get("minimap") == true and not P:Shooting()
end

-- The eye in the accent while private mode is on, grey while it's off.
function MB:Refresh()
    if not button then return end
    local tint = P:Private() and T.ACCENT or C.soft
    button.eye:SetVertexColor(tint[1], tint[2], tint[3])
    button:SetShown(self:Wanted())
    self:Place()
    if tip and tip:IsShown() then FillTip() end
end

function MB:Button()
    return button
end

function MB:Tip()
    return tip
end

-- Made once, when you log in (the saved settings have loaded by then).
function MB:Start()
    if button or not Minimap then return end
    Build()
    -- The minimap can change size: stay on its edge.
    Minimap:HookScript("OnSizeChanged", function() MB:Place() end)
    self:Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    MB:Start()
end)

P:Listen(function() MB:Refresh() end)
