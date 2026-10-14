-- The be right back screen against a mock game (Tools/Harness.lua): nothing
-- made until it's asked for; its key and /privacy brb bringing it up and
-- taking it down quietly, private mode on or off and never changed; a
-- full-screen card of our own over everything, taking the mouse but never the
-- keyboard, in the addon's look (the eye, the accent line); your message
-- (tidied as the name box is, "Be right back" while empty, changing at once)
-- and how long you've been away, counted each second; a click saying how to
-- come back; Escape through the game's own list, by a stand-in the game's
-- closing every window (a stun, a death, a loading screen) never takes the
-- card down with; the game menu never under it; screenshots leaving it as it
-- is and "For screenshots" never bringing it up; fights; Reset all settings;
-- never a name on it; Blizzard's frames only read and hooked.
-- Run with fengari: Tools/TestBeRightBack.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local P, BRB, original

-- Font sizes, kept for this test (the harness keeps only the font's file).
do
    local setFont = H.Proto.SetFont
    H.Proto.SetFont = function(self, file, size, flags)
        S[self].fontSize, S[self].fontFlags = size, flags
        return setFont(self, file)
    end
end

-- Blizzard's side: the game menu, and Escape's own function as Forever has it
-- (Blizzard_GameMenuEsc's ToggleGameMenu): a pop-up is closed first, then the
-- game menu if it's open, then every window on the game's list
-- (CloseAllWindows, which hides each one shown); with nothing to close, the
-- game menu opens.
local popup -- a pop-up showing (StaticPopup)
local function CloseSpecialWindows()
    local found = false
    for _, name in pairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:Hide()
            found = true
        end
    end
    return found
end
local function Game()
    H.Environment()
    _G.GameMenuFrame = H.BlizzardFrame("Frame", "GameMenuFrame", UIParent)
    H.Blizzard(function() GameMenuFrame:Hide() end)
    popup = nil
    _G.ToggleGameMenu = function()
        if popup then
            popup = nil
        elseif GameMenuFrame:IsShown() then
            GameMenuFrame:Hide()
        elseif not CloseSpecialWindows() then
            GameMenuFrame:Show()
        end
    end
    original = ToggleGameMenu
end
local function Fresh(saved, opts)
    Game()
    P = H.Load(saved, opts)
    BRB = P.BeRightBack
    return P
end
local DB = function() return ForeverEnhancedPrivacyDB end
-- Pressing Escape.
local function Escape() H.Blizzard(ToggleGameMenu) end
-- The game closing every window on its list for something else (a stun, a
-- death, a loading screen: CloseAllWindows without Escape).
local function CloseAll() H.Blizzard(CloseSpecialWindows) end
local function Menu() return GameMenuFrame:IsShown() end
local function Card() return BRB:Frame() end
local function Stand() return BRB:StandIn() end
-- Time passing while it shows, the game's frame update telling it so.
local function Tick(seconds)
    H.clock = H.clock + seconds
    H.Script(Card(), "OnUpdate", seconds)
end
local function Message() return H.Text(Card().message) end
local function Away() return H.Text(Card().away) end
local function Rgb(c) return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) end
local function Listed()
    local count = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "ForeverEnhancedPrivacyBeRightBackEscape" then count = count + 1 end
    end
    return count
end
local function Hooked(key)
    local count = 0
    for _, hook in ipairs(H.hooks) do
        if hook.t == _G and hook.key == key then count = count + 1 end
    end
    return count
end

-- Nothing until it's asked for ----------------------------------------------------------------------------------------

Fresh(nil)
Equal(tostring(BRB:Frame()) .. " " .. tostring(BRB:Shown()), "nil false", "nothing made at load")
Equal(ForeverEnhancedPrivacyBeRightBack, nil, "no frame named yet")
Equal(#UISpecialFrames .. " " .. tostring(rawequal(ToggleGameMenu, original)) .. " " .. tostring(S[GameMenuFrame].scripts.OnShow),
    "0 true nil", "nothing on the game's Escape list, Escape's function and the game menu not hooked")
Equal(P:Get("brbText") .. " / " .. P:BrbText(), " / Be right back", "no message typed: \"Be right back\"")
Escape()
Equal(Menu(), true, "Escape opens the game menu as ever")
Escape()
Equal(Menu(), false, "and closes it")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Its key and /privacy brb --------------------------------------------------------------------------------------------

Fresh(nil)
Equal(BINDING_NAME_FEPRIVACY_BRB, "Toggle be right back screen", "its key's name in Key Bindings")
ForeverEnhancedPrivacy_BeRightBack()
local card = Card()
True(card and card:IsShown(), "its key brings it up")
Equal(ForeverEnhancedPrivacyBeRightBack, card, "named ForeverEnhancedPrivacyBeRightBack")
Equal(tostring(P:Private()) .. " " .. #H.printed, "false 0", "quietly, private mode left off")
ForeverEnhancedPrivacy_BeRightBack()
Equal(card:IsShown(), false, "the key again takes it down")
SlashCmdList.FEPRIVACY("brb")
Equal(card:IsShown(), true, "/privacy brb brings it up")
SlashCmdList.FEPRIVACY("  BRB ")
Equal(card:IsShown(), false, "and takes it down, any case")
Equal(Card(), card, "made once")
Equal(#H.printed, 0, "never a word in chat")
Equal(tostring(BRB:Close()) .. " " .. tostring(BRB:Open()) .. " " .. tostring(BRB:Open()) .. " " .. tostring(BRB:Close()),
    "false true false true", "opening or closing twice changes nothing")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- The card: over everything, in the addon's look ----------------------------------------------------------------------

Fresh(nil)
BRB:Open()
card = Card()
do
    local s, C = S[card], P.Theme.C
    Equal(s.kind .. " " .. tostring(s.parent == UIParent) .. " " .. s.points[1][1] .. " " .. tostring(s.points[1][2] == UIParent),
        "Frame true ALL true", "a frame of our own over the whole screen")
    Equal(s.width .. "x" .. s.height, "1024x768", "sized as it's made")
    Equal(s.strata .. " " .. s.level, "TOOLTIP 5000",
        "the top strata: over the game's windows, menus, pop-ups, the low health glow, an item link or Lua error window")
    Equal(tostring(s.mouse) .. " " .. tostring(H.Last(card, "EnableMouseWheel")), "true true", "clicks and the wheel stop at it")
    Equal(H.Calls(card, "EnableKeyboard") + H.Calls(card, "SetPropagateKeyboardInput"), 0,
        "never the keyboard: every key still reaches the game")
    local back, line
    for _, child in ipairs(s.children) do
        local c = S[child]
        if c.kind == "Texture" and c.layer == "BACKGROUND" then back = child end
        if c.kind == "Texture" and c.color and c.height == 3 then line = child end
    end
    Equal(Rgb(S[back].color) .. " " .. S[back].color[4] .. " " .. S[back].points[1][1], Rgb(C.window) .. " 1 ALL",
        "the window's dark fill, solid, from edge to edge")
    Equal(Rgb(S[line].color) .. " " .. S[line].points[1][1] .. " " .. S[line].points[2][1], Rgb(P.ACCENT) .. " TOPLEFT TOPRIGHT",
        "the window's accent line along the top")
    local eye = S[card.eye]
    Equal(eye.texture .. " " .. eye.width .. "x" .. eye.height .. " " .. Rgb(eye.tint), P.MEDIA .. "Eye.tga 64x40 " .. Rgb(P.ACCENT),
        "the addon's eye, in the accent")
    Equal(table.concat(eye.texCoord, " "), table.concat({ 0, 1, 12 / 64, 52 / 64 }, " "), "cropped as the on-screen eye is")
    Equal(table.concat({ eye.points[1][1], tostring(eye.points[1][2] == card), eye.points[1][3], eye.points[1][4], eye.points[1][5] }, " "),
        "BOTTOM true CENTER 0 44", "above the middle")
    local m = S[card.message]
    Equal(m.template .. " " .. m.fontFile .. " " .. m.fontSize .. " [" .. m.fontFlags .. "] " .. Rgb(m.colour),
        "GameFontNormalHuge font 40 [] " .. Rgb(C.text), "the message big, in the game's own font, in the window's text colour")
    Equal(table.concat({ m.points[1][1], m.points[1][3], m.points[1][4], m.points[1][5], m.points[2][1], m.points[2][3], m.points[2][4],
        m.points[2][5] }, " "), "TOPLEFT LEFT 80 20 TOPRIGHT RIGHT -80 20", "across the middle, 80 in from each side")
    Equal(H.Last(card.message, "SetJustifyH") .. " " .. tostring(H.Last(card.message, "SetWordWrap")), "CENTER true",
        "centred, wrapping if it must")
    local a = S[card.away]
    Equal(tostring(a.points[1][2] == card.message) .. " " .. a.points[1][1] .. " " .. a.points[1][3] .. " " .. Rgb(a.colour),
        "true TOP BOTTOM " .. Rgb(C.soft), "how long you've been away under it, quieter")
    local hint = card.hint
    Equal(H.Text(hint) .. " " .. tostring(hint:IsShown()) .. " " .. S[hint].points[1][1], "Press Escape to come back. false BOTTOM",
        "how to come back, at the bottom, hidden till a click")
end
Equal(Message() .. " / " .. Away(), "Be right back / Away for 0 sec", "\"Be right back\", away for no time yet")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Your message ----------------------------------------------------------------------------------------------------------

Equal(tostring(P:Set("brbText", "  Back   in 5  ")) .. " " .. P:Get("brbText") .. " " .. DB().brbText, "true Back in 5 Back in 5",
    "a message saves, tidied as the name box is")
Equal(Message(), "Back in 5", "the card shows it at once")
Equal(tostring(P:Set("brbText", "Back in 5")), "false", "the same again changes nothing")
Equal(P:Get("myName") .. "|" .. P:Get("myTag") .. "|" .. P:Get("myGuild"), "||", "your name, BattleTag and guild are their own settings")
Equal(P.BRB_MAX, 40, "at most 40 letters")
Equal(P:CleanBrb(string.rep("a", 45)), string.rep("a", 40), "cut to 40")
Equal(P:CleanBrb("Zr\195\175el " .. string.rep("b", 40)), "Zr\195\175el " .. string.rep("b", 34), "letters, not bytes, counted")
Equal(P:CleanBrb("|cffff0000Red|r Two\nLines"), "cffff0000Redr Two Lines", "no escape codes or control characters")
Equal(P:CleanBrb(H.SECRET) .. "|" .. P:CleanBrb(nil) .. "|" .. P:CleanBrb(42), "||", "a secret never read, only text taken")
P:Set("brbText", "   ")
Equal("[" .. P:Get("brbText") .. "] " .. Message(), "[] Be right back", "spaces alone: emptied, \"Be right back\" again")
P:Set("brbText", "Gone for food")
Equal(tostring(P:Set("brbText", 7)) .. " [" .. P:Get("brbText") .. "] " .. Message(), "true [] Be right back",
    "anything but text counts as nothing typed")
Fresh({ brbText = "  Back|r   soon  " })
Equal(P:Get("brbText"), "Backr soon", "a saved message is cleaned as it loads")
Fresh({ brbText = string.rep("y", 50) })
Equal(P:Get("brbText"), string.rep("y", 40), "and cut to 40 letters")
Fresh({ brbText = 12 })
Equal("[" .. P:Get("brbText") .. "] " .. tostring(DB().brbText), "[] nil", "a saved one that isn't text goes back to none")
Fresh({ brbText = string.rep("z", 200) })
Equal("[" .. P:Get("brbText") .. "] " .. tostring(DB().brbText), "[] nil", "and one far too long to be typed")
Equal(H.Problems(), "", "nothing wrong with the message")

-- How long you've been away, counted each second --------------------------------------------------------------------------

Fresh(nil)
do
    local cases = { { 0, "Away for 0 sec" }, { 1.9, "Away for 1 sec" }, { 59, "Away for 59 sec" }, { 60, "Away for 1 min" },
        { 179, "Away for 2 min" }, { 3599, "Away for 59 min" }, { 3600, "Away for 1 hr" }, { 3660, "Away for 1 hr 1 min" },
        { 7325, "Away for 2 hr 2 min" }, { -5, "Away for 0 sec" }, { nil, "Away for 0 sec" }, { "x", "Away for 0 sec" } }
    for _, case in ipairs(cases) do Equal(BRB:Away(case[1]), case[2], tostring(case[1]) .. " seconds") end
end
BRB:Open()
Equal(Away(), "Away for 0 sec", "counting from when it came up")
local redrawn = H.Calls(Card().away, "SetText")
Tick(.5)
Equal(Away() .. " " .. H.Calls(Card().away, "SetText") - redrawn, "Away for 0 sec 0", "half a second: not counted yet, nothing redrawn")
Tick(.5)
Equal(Away() .. " " .. H.Calls(Card().away, "SetText") - redrawn, "Away for 1 sec 1", "a second later: one second, redrawn once")
Tick(1)
Equal(Away(), "Away for 2 sec", "and each second after")
Tick(57)
Equal(Away(), "Away for 59 sec", "a long frame: caught up at once")
Tick(1)
Equal(Away(), "Away for 1 min", "a minute")
Tick(120)
Equal(Away(), "Away for 3 min", "three")
Equal(S[Card()].scripts.OnUpdate ~= nil, true, "the count is the card's own (the game only runs it while the card shows)")
BRB:Close()
H.clock = H.clock + 600
BRB:Open()
Equal(Away(), "Away for 0 sec", "brought up again: counting from then")
BRB:Close()

-- A click: how to come back -------------------------------------------------------------------------------------------------

BRB:Open()
local hint = Card().hint
H.Script(Card(), "OnMouseDown", "LeftButton")
Equal(hint:IsShown(), true, "a click shows how to come back")
Equal(Card():IsShown(), true, "and the card stays")
Tick(2)
Equal(hint:IsShown(), true, "for a moment")
Tick(2)
Equal(hint:IsShown(), false, "then it's gone again")
H.Script(Card(), "OnMouseDown", "RightButton")
BRB:Close()
BRB:Open()
Equal(hint:IsShown(), false, "brought up again: gone")
BRB:Close()
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Escape, through the game's own list ---------------------------------------------------------------------------------------

Fresh(nil)
ForeverEnhancedPrivacy_BeRightBack()
card = Card()
local stand = Stand()
do
    local s = S[stand]
    Equal(s.name .. " " .. tostring(s.parent == card) .. " " .. s.width .. "x" .. s.height .. " " .. tostring(s.mouse) .. " " .. #s.children,
        "ForeverEnhancedPrivacyBeRightBackEscape true 1x1 nil 0", "a stand-in of our own: tiny, empty, never taking the mouse")
end
Equal(Listed() .. " " .. tostring(stand:IsShown()), "1 true", "on the game's Escape list while the card shows")
Equal(Hooked("ToggleGameMenu") .. " " .. tostring(S[GameMenuFrame].scripts.OnShow ~= nil), "1 true",
    "Escape's function post-hooked, the game menu's showing hooked")
Escape()
Equal(tostring(card:IsShown()) .. " " .. tostring(Menu()) .. " " .. tostring(stand:IsShown()), "false false false",
    "Escape takes it down, without the game menu")
Escape()
Equal(Menu(), true, "the next Escape opens the game menu as ever")
Escape()
Equal(Menu(), false, "and closes it")
BRB:Open()
ForeverEnhancedPrivacy_BeRightBack()
Equal(tostring(card:IsShown()) .. " " .. tostring(stand:IsShown()), "false false", "its key takes it down, the stand-in off the list")
Escape()
Equal(Menu(), true, "so Escape opens the game menu, nothing swallowed")
Escape()
BRB:Open()
Equal(Listed() .. " " .. Hooked("ToggleGameMenu"), "1 1", "brought up again: listed and hooked once")
-- The game closing every window for something else: the card stays.
CloseAll()
Equal(tostring(card:IsShown()) .. " " .. tostring(stand:IsShown()), "true false",
    "a stun, a death or a loading screen closing every window: the card stays")
H.RunTimers()
Equal(stand:IsShown(), true, "its stand-in back on the list a moment later")
Escape()
Equal(tostring(card:IsShown()) .. " " .. tostring(Menu()), "false false", "so Escape still takes it down")
-- Escape in that same moment, before the stand-in is back: down, and the game menu up.
BRB:Open()
CloseAll()
Escape()
Equal(tostring(card:IsShown()) .. " " .. tostring(Menu()), "false true", "Escape at that moment: the card down, the game menu up")
H.RunTimers()
Equal(tostring(stand:IsShown()) .. " " .. tostring(card:IsShown()), "false false", "and nothing brought back after")
Escape()
-- Its key taking it down while the stand-in is due back: it stays off the list.
BRB:Open()
CloseAll()
ForeverEnhancedPrivacy_BeRightBack()
H.RunTimers()
Equal(tostring(card:IsShown()) .. " " .. tostring(stand:IsShown()), "false false", "the key: the stand-in stays off the list")
Escape()
Equal(Menu(), true, "so Escape opens the game menu, nothing swallowed")
Escape()
-- A pop-up under the card closes first, as Escape always does; the card next.
BRB:Open()
popup = true
Escape()
Equal(tostring(popup) .. " " .. tostring(card:IsShown()), "nil true", "Escape closes a pop-up first, as the game does")
Escape()
Equal(tostring(card:IsShown()) .. " " .. tostring(Menu()), "false false", "then the card")
-- The settings window open under it: Escape closes both, as it closes every listed window.
P.ShowWindow()
BRB:Open()
Escape()
Equal(tostring(card:IsShown()) .. " " .. tostring(ForeverEnhancedPrivacyFrame:IsShown()) .. " " .. tostring(Menu()), "false false false",
    "with the settings open: both closed, no game menu")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- The game menu is never under it -----------------------------------------------------------------------------------------------

BRB:Open()
H.Blizzard(function() GameMenuFrame:Show() end)
Equal(tostring(Menu()) .. " " .. tostring(card:IsShown()) .. " " .. tostring(stand:IsShown()), "true false false",
    "the game menu showing (by any route): the card steps aside")
Escape()
Equal(Menu(), false, "Escape closes the game menu")
-- Brought up over an open game menu: Escape closes the menu first, then the card.
H.Blizzard(function() GameMenuFrame:Show() end)
ForeverEnhancedPrivacy_BeRightBack()
Equal(tostring(Menu()) .. " " .. tostring(card:IsShown()), "true true", "brought up with the game menu open")
Escape()
Equal(tostring(Menu()) .. " " .. tostring(card:IsShown()), "false true", "Escape closes the game menu first, as it always does")
Escape()
Equal(tostring(Menu()) .. " " .. tostring(card:IsShown()), "false false", "then the card")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- With no Escape function or game menu (another client): its key still works ----------------------------------------------------

H.Environment()
_G.ToggleGameMenu, _G.GameMenuFrame = nil, nil
P = H.Load(nil)
BRB = P.BeRightBack
ForeverEnhancedPrivacy_BeRightBack()
Equal(tostring(BRB:Shown()) .. " " .. Listed(), "true 1", "up, its stand-in listed")
ForeverEnhancedPrivacy_BeRightBack()
Equal(BRB:Shown(), false, "and down")
Equal(H.Problems(), "", "nothing wrong")

-- Private mode on or off, never changed --------------------------------------------------------------------------------------------

Fresh(nil)
BRB:Open()
card = Card()
P:SetPrivate(true)
Equal(tostring(card:IsShown()) .. " " .. tostring(P:Private()), "true true", "private mode coming on leaves it up")
local eye = P.Eye:Frame()
Equal(tostring(eye:IsShown()) .. " " .. S[eye].strata, "true HIGH", "the eye under it, at a lower strata")
P:SetPrivate(false)
Equal(card:IsShown(), true, "and going off too")
BRB:Close()
P:SetPrivate(true)
BRB:Open()
Equal(tostring(card:IsShown()) .. " " .. tostring(P:Private()), "true true", "brought up while private")
BRB:Close()
Equal(P:Private(), true, "taken down: private mode still on")
P:SetPrivate(false)
Fresh({ mode = "always" })
ForeverEnhancedPrivacy_BeRightBack()
Equal(tostring(BRB:Shown()) .. " " .. tostring(P:Private()), "true true", "always, from login: works the same")
ForeverEnhancedPrivacy_BeRightBack()
Equal(P:Private(), true, "and leaves it on")

-- Screenshots leave it as it is -------------------------------------------------------------------------------------------------------

Fresh(nil)
P:Set("mode", "shots")
H.Screenshot("start")
Equal(tostring(P:Private()) .. " " .. tostring(BRB:Frame()), "true nil", "For screenshots: private mode on for the picture, the screen never made")
H.Screenshot("done")
Equal(tostring(P:Private()) .. " " .. tostring(BRB:Shown()), "false false", "nor after")
BRB:Open()
card = Card()
Tick(5)
H.Screenshot("start")
Equal(tostring(card:IsShown()) .. " " .. tostring(P:Private()), "true true", "shown on purpose: still up for the picture")
H.Screenshot("done")
Equal(tostring(card:IsShown()) .. " " .. tostring(P:Private()) .. " " .. Away(), "true false Away for 5 sec",
    "and after, still counting")
P:Set("mode", "key")
H.Screenshot("start")
Equal(card:IsShown(), true, "with its key too")
H.Screenshot("fail")
Equal(card:IsShown(), true, "a failed one too")
BRB:Close()
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- In a fight: nothing protected, so it works the same ---------------------------------------------------------------------------------

Fresh(nil)
H.Combat(true)
ForeverEnhancedPrivacy_BeRightBack()
Equal(BRB:Shown(), true, "up in a fight (made then too)")
CloseAll()
H.RunTimers()
Escape()
Equal(BRB:Shown(), false, "Escape in a fight")
SlashCmdList.FEPRIVACY("brb")
SlashCmdList.FEPRIVACY("brb")
Equal(BRB:Shown(), false, "/privacy brb in a fight")
H.Combat(false)
Equal(H.Writes() .. " " .. #H.cvarWrites .. " " .. H.Problems(), "0 0 ", "nothing of Blizzard's touched, no game setting, nothing wrong")

-- Reset all settings: the message goes, the screen stays as it is -------------------------------------------------------------------------

Fresh(nil)
P:Set("brbText", "Back in 5")
BRB:Open()
Equal(Message(), "Back in 5", "your message")
P:Reset()
Equal(tostring(BRB:Shown()) .. " " .. Message() .. " [" .. P:Get("brbText") .. "]", "true Be right back []",
    "Reset: \"Be right back\" again at once, the screen still up (it isn't a setting)")
H.Clear()
BRB:Close()

-- An error in one of its hooks: said once, in words about this screen (not names) ------------------------------------------------

local function Broken(method, run)
    local kept = BRB[method]
    BRB[method] = function() error("BeRightBack.lua:1: kaboom", 0) end
    run()
    BRB[method] = kept
end
Fresh(nil)
BRB:Open()
Broken("Close", Escape)
Equal(#H.printed .. " " .. tostring(BRB:Shown()) .. " " .. #H.hookErrors, "1 true 0", "Escape's hook failing: said once, swallowed")
Equal(H.printed[1]:match(": (.*)$"), "The be right back screen part hit an error, so Escape may not take it down. Its key still does. "
    .. "BeRightBack.lua:1: kaboom", "saying what it means for you")
ForeverEnhancedPrivacy_BeRightBack()
Equal(BRB:Shown(), false, "and its key does")
H.Clear()
Fresh(nil)
BRB:Open()
Broken("Close", function() H.Blizzard(function() GameMenuFrame:Show() end) end)
Equal(#H.printed .. " " .. tostring(BRB:Shown()) .. " " .. #H.hookErrors, "1 true 0", "the game menu's hook failing: said once")
Equal(H.printed[1]:match(": (.*)$"), "The be right back screen part hit an error, so it may stay over the game menu. Escape or its "
    .. "key still take it down. BeRightBack.lua:1: kaboom", "in its own words")
Escape()
Escape()
Equal(tostring(Menu()) .. " " .. tostring(BRB:Shown()), "false false", "and Escape does: the menu first, then the card")
H.Clear()
Fresh(nil)
BRB:Open()
Broken("Refresh", function() P:Set("brbText", "Back in 5") end)
Equal(#H.printed, 1, "a new message failing to show: said once")
Equal(H.printed[1]:match(": (.*)$"), "The be right back screen part hit an error, so it may not show a new message at once. "
    .. "BeRightBack.lua:1: kaboom", "as this screen's, not the window's")
Tick(1)
Equal(Message(), "Back in 5", "it shows a second later")
H.Clear()
BRB:Close()

-- Never a name ------------------------------------------------------------------------------------------------------------------------------

Fresh(nil)
H.guild = { { name = "Brannoc Stonehelm", classFile = "WARRIOR" } }
P:Set("myName", "Shade")
P:Set("myTag", "Fake#9999")
P:Set("myGuild", "Lancers of Elwynn")
P:SetPrivate(true)
BRB:Open()
H.Script(Card(), "OnMouseDown", "LeftButton")
Tick(75)
do
    local shown = {}
    for _, region in ipairs({ Card().message, Card().away, Card().hint }) do shown[#shown + 1] = H.Text(region) end
    local text = table.concat(shown, " / ")
    Equal(text, "Be right back / Away for 1 min / Press Escape to come back.", "only its own words")
    for _, name in ipairs({ "Zriel", "Gustbellow", "Shade", "Fake", "Lancers", "Brannoc", "Druid" }) do
        True(not text:find(name, 1, true), "no " .. name .. " on it")
    end
end
P:SetPrivate(false)
Equal(H.Text(GameTooltipTextLeft1), nil, "the game's tooltip never touched")
Equal(H.Writes() .. " " .. #H.violations .. " " .. H.Problems(), "0 0 ", "nothing of Blizzard's touched, nothing wrong")

io.stdout:write("TestBeRightBack: " .. H.checks .. " checks passed\n")
