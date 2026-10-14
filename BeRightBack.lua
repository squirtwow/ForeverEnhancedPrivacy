-- The be right back screen: a full-screen card of our own for breaks, with
-- your message (the Overview's box; "Be right back" while it's empty), the
-- addon's eye, and how long you've been away, counted each second. Its key
-- (Key Bindings > AddOns), /privacy brb or the Overview's Show button bring
-- it up; Escape or the key again take it down. It works with private mode on
-- or off. The game shows everyone the same picture, so it covers the game
-- for you too: it's for breaks, not for playing behind.
--
-- Nothing of Blizzard's is changed. The card is our own frame over the whole
-- screen at the top strata. It takes the mouse (clicks and the wheel stop at
-- it) but never the keyboard, so every key still reaches the game: moving
-- and the rest still work under it, and Escape stays the game's (a frame
-- that takes keys can swallow Escape, and changing that in a fight is
-- blocked). Escape reaches the card through the game's own list of windows
-- it closes (UISpecialFrames). The card itself isn't on that list: the game
-- also closes those windows on a stun, a death or a loading screen, which
-- would drop the cover mid-break. A small empty frame of ours stands in for
-- it there. When the game closes the stand-in, a post-hook on ToggleGameMenu
-- (the Escape key's own function) says it was Escape, and the card goes;
-- anything else that closed it, it's back on the list a frame later. The
-- game menu is never under the card: the card goes whenever the game menu
-- shows (a HookScript on GameMenuFrame).
--
-- Screenshots leave it alone: shown, it's in the picture on purpose (that's
-- the point while streaming), and "For screenshots" never brings it up. It
-- only ever shows your own message, never a name.
local _, P = ...

local T = P.Theme
local C = T.C

local BRB = {}
P.BeRightBack = BRB

local NAME = "be right back screen" -- for an error, said once
-- What an error in one of its hooks means for you (the core's own ending is
-- about names, and this part has none).
local ESCAPE_ERROR = "so Escape may not take it down. Its key still does."
local MENU_ERROR = "so it may stay over the game menu. Escape or its key still take it down."
local CHANGE_ERROR = "so it may not show a new message at once."
local STAND_IN = "ForeverEnhancedPrivacyBeRightBackEscape"
-- The top strata, so the game's windows that sit there (an item link window,
-- the Lua error window, the queue status box, tooltips) go under it too, and
-- the low health glow (FULLSCREEN_DIALOG) below that; over the rest of its
-- strata.
local STRATA, LEVEL = "TOOLTIP", 5000
local MESSAGE_SIZE = 40
local HINT_TIME = 4 -- seconds "Press Escape to come back." shows after a click

local card, stand
local openedAt = 0 -- GetTime() when it came up
local wait = 0 -- seconds till the count next changes
local hintUntil
local dropped = false -- the stand-in was just closed (by Escape, or a stun, death or loading screen)

-- How long you've been away, in short words: seconds for the first minute,
-- then minutes, then hours and minutes.
function BRB:Away(seconds)
    seconds = math.floor(math.max(0, tonumber(seconds) or 0))
    if seconds < 60 then return ("Away for %d sec"):format(seconds) end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return ("Away for %d min"):format(minutes) end
    local hours, left = math.floor(minutes / 60), minutes % 60
    if left == 0 then return ("Away for %d hr"):format(hours) end
    return ("Away for %d hr %d min"):format(hours, left)
end

-- Your message and the count, and the hint gone once its time is up.
function BRB:Refresh()
    if not (card and card:IsShown()) then return end
    card.message:SetText(P:BrbText())
    card.away:SetText(self:Away(GetTime() - openedAt))
    if hintUntil and GetTime() >= hintUntil then
        hintUntil = nil
        card.hint:Hide()
    end
end

-- Counted each second while it shows (only then: it's the card's own OnUpdate).
local function Tick(_, elapsed)
    wait = wait - (tonumber(elapsed) or 0)
    if wait > 0 then return end
    wait = 1
    BRB:Refresh()
end

-- A click on the card: how to come back, for a moment.
local function ShowHint()
    hintUntil = GetTime() + HINT_TIME
    card.hint:Show()
end

-- Escape ------------------------------------------------------------------------------------------

-- The stand-in is back on the game's list, unless Escape took the card away.
local function Recatch()
    if not dropped then return end
    dropped = false
    if card and card:IsShown() then stand:Show() end
end

-- The stand-in was closed: by Escape (ToggleGameMenu's post-hook follows at
-- once), by the game closing every window for some other reason, or by us
-- (Close, which clears this straight after).
local function Dropped()
    dropped = true
    C_Timer.After(0, Recatch)
end

local function AfterEscape()
    if not dropped then return end
    dropped = false
    BRB:Close()
end

-- The card -----------------------------------------------------------------------------------------

-- The message in the game's own font, bigger.
local function BigFont(text)
    local font = GameFontNormalHuge
    if type(font) ~= "table" or type(font.GetFont) ~= "function" then return end
    local file, _, flags = font:GetFont()
    if type(file) == "string" then text:SetFont(file, MESSAGE_SIZE, type(flags) == "string" and flags or "") end
end

local function Build()
    card = CreateFrame("Frame", "ForeverEnhancedPrivacyBeRightBack", UIParent)
    card:SetSize(UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768)
    card:SetAllPoints(UIParent)
    card:SetFrameStrata(STRATA)
    card:SetFrameLevel(LEVEL)
    card:EnableMouse(true)
    card:EnableMouseWheel(true)
    card:Hide()
    local back = T:Block(card, C.window)
    back:SetAllPoints(card)
    -- The window's accent line, along the top of the screen.
    local line = T:Block(card, T.ACCENT, "ARTWORK")
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(3)
    local eye = card:CreateTexture(nil, "ARTWORK")
    eye:SetSize(64, 40)
    eye:SetPoint("BOTTOM", card, "CENTER", 0, 44)
    eye:SetTexture(P.MEDIA .. "Eye.tga")
    -- The eye sits in rows 12 to 52 of its 64 by 64 picture, as Eye.lua has it.
    eye:SetTexCoord(0, 1, 12 / 64, 52 / 64)
    eye:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3])
    card.eye = eye
    -- The message wraps between the screen's sides if it must.
    local message = T:Text(card, "GameFontNormalHuge", C.text)
    BigFont(message)
    message:SetPoint("TOPLEFT", card, "LEFT", 80, 20)
    message:SetPoint("TOPRIGHT", card, "RIGHT", -80, 20)
    message:SetJustifyH("CENTER")
    message:SetWordWrap(true)
    card.message = message
    local away = T:Text(card, "GameFontHighlightLarge", C.soft)
    away:SetPoint("TOP", message, "BOTTOM", 0, -18)
    away:SetJustifyH("CENTER")
    card.away = away
    local hint = T:Text(card, "GameFontHighlight", C.dim)
    hint:SetPoint("BOTTOM", card, "BOTTOM", 0, 48)
    hint:SetJustifyH("CENTER")
    hint:SetText("Press Escape to come back.")
    hint:Hide()
    card.hint = hint
    card:SetScript("OnMouseDown", ShowHint)
    card:SetScript("OnUpdate", Tick)
    -- Its stand-in on the game's list of windows Escape closes.
    stand = CreateFrame("Frame", STAND_IN, card)
    stand:SetSize(1, 1)
    stand:Hide()
    stand:SetScript("OnHide", Dropped)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, STAND_IN) end
    if type(ToggleGameMenu) == "function" then hooksecurefunc("ToggleGameMenu", P:Guard(NAME, AfterEscape, ESCAPE_ERROR)) end
    if GameMenuFrame and GameMenuFrame.HookScript then
        GameMenuFrame:HookScript("OnShow", P:Guard(NAME, function() BRB:Close() end, MENU_ERROR))
    end
end

-- Brings it up (made the first time), counting from now.
function BRB:Open()
    if not card then Build() end
    if card:IsShown() then return false end
    openedAt, wait, hintUntil, dropped = GetTime(), 1, nil, false
    card.hint:Hide()
    card:Show()
    stand:Show()
    self:Refresh()
    return true
end

-- Takes it down, and its stand-in off the game's list.
function BRB:Close()
    if not (card and card:IsShown()) then return false end
    stand:Hide()
    dropped = false
    card:Hide()
    return true
end

function BRB:Toggle()
    if card and card:IsShown() then return self:Close() end
    return self:Open()
end

function BRB:Shown()
    return card ~= nil and card:IsShown()
end

function BRB:Frame()
    return card
end

function BRB:StandIn()
    return stand
end

-- A new message (or Reset all settings) shows at once.
P:Listen(P:Guard(NAME, function() BRB:Refresh() end, CHANGE_ERROR))
