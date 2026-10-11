-- The minimap button against a mock game (Tools/Harness.lua): made at login,
-- named and on the minimap in the family's look with the addon's eye (in the
-- accent while private, grey while not, and after a reset), left-click
-- turning private mode on and off quietly, right-click opening and closing
-- the window, a click just after a drag ignored, dragging round the edge
-- (placed while dragging, saved once let go, a hidden button letting go), a
-- bad saved angle put right at load, the minimap changing size, the
-- Overview's tick and /privacy minimap, Reset all settings, its own hover box
-- (its words inside it, never a name, never the game's tooltip), hidden for screenshots as the eye
-- is, and Blizzard's frames only read and hooked.
-- Run with fengari: Tools/TestMinimap.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local P, button
local cursor = { 900, 650 }

-- A fresh game: the minimap's middle at 900, 650 on the screen, the cursor
-- wherever the test puts it.
local function Fresh(saved, opts)
    H.Environment()
    rawset(Minimap, "GetCenter", function() return 900, 650 end)
    _G.GetCursorPosition = function() return cursor[1], cursor[2] end
    P = H.Load(saved, opts)
    button = P.MinimapButton:Button()
    return P
end
local DB = function() return ForeverEnhancedPrivacyDB end

-- Where the button sits, and where it should at an angle round a minimap
-- this wide.
local function Spot()
    local p = S[button].points[1]
    return ("%s %s %s %.1f %.1f"):format(p[1], tostring(rawequal(p[2], Minimap)), p[3], p[4], p[5])
end
local function At(angle, width)
    local radius, a = (width or 140) / 2 + 4, math.rad(angle)
    return ("CENTER true CENTER %.1f %.1f"):format(math.cos(a) * radius, math.sin(a) * radius)
end
local function Rgb(c) return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) end
local function Tint() return Rgb(S[button.eye].tint) end
local function Drag(x, y)
    cursor[1], cursor[2] = x, y
    H.Script(button, "OnDragStart")
    H.Script(button, "OnUpdate", .01)
    H.Script(button, "OnDragStop")
    H.clock = H.clock + 1
end

-- Made at login ----------------------------------------------------------------------------------------

Fresh(nil, { beforeLogin = true })
local ACCENT, GREY = Rgb(P.ACCENT), Rgb(P.Theme.C.soft)
Equal(P.MinimapButton:Button(), nil, "not made before login")
H.Fire("PLAYER_LOGIN")
button = P.MinimapButton:Button()
True(button, "made at login")
Equal(ForeverEnhancedPrivacyMinimapButton, button, "named ForeverEnhancedPrivacyMinimapButton, so minimap tidiers can list it")
Equal(S[button].kind .. " " .. tostring(S[button].parent == Minimap), "Button true", "a button on the minimap")
Equal(S[button].width .. "x" .. S[button].height .. " " .. S[button].strata .. " " .. S[button].level, "32x32 MEDIUM 9",
    "the family's size, just above the minimap")
P.MinimapButton:Start()
Equal(P.MinimapButton:Button(), button, "made once")
do
    local textures = {}
    for _, child in ipairs(S[button].children) do
        local s = S[child]
        textures[#textures + 1] = ("%s %s %dx%d"):format(s.layer, s.texture, s.width, s.height)
    end
    Equal(table.concat(textures, " | "), "BACKGROUND Interface\\CharacterFrame\\TempPortraitAlphaMask 20x20 | ARTWORK "
        .. "Interface\\AddOns\\ForeverEnhancedPrivacy\\Media\\Eye.tga 16x10 | OVERLAY Interface\\Minimap\\MiniMap-TrackingBorder 54x54",
        "a dark circle, the addon's eye and the minimap's gold ring, as its siblings")
    Equal(table.concat(S[button.eye].texCoord, " "), table.concat({ 0, 1, 12 / 64, 52 / 64 }, " "), "the eye cropped as the on-screen eye is")
    Equal(H.Last(button, "SetHighlightTexture"), "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "lit on hover")
    Equal(H.Last(button, "RegisterForClicks", 1) .. " " .. H.Last(button, "RegisterForClicks", 2) .. " "
        .. H.Last(button, "RegisterForDrag"), "LeftButtonUp RightButtonUp LeftButton", "both clicks, and dragged with the left")
end
Equal(P:Get("minimapAngle") .. " " .. tostring(DB().minimapAngle), "165 nil", "its first spot (nothing saved till it moves)")
Equal(Spot(), At(165), "on the minimap's left edge, a little above the middle")
Equal(tostring(button:IsShown()) .. " " .. tostring(H.Shown(button)), "true true", "shown")
Equal(Tint(), GREY, "the eye grey while private mode is off")
Equal(S[button].scripts.OnUpdate, nil, "nothing running every frame")
True(S[Minimap].scripts.OnSizeChanged, "the minimap's size followed (a hook)")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Left-click: private mode; right-click: the settings ------------------------------------------------------

Fresh(nil)
button:Click("LeftButton")
Equal(P:Private(), true, "left-click turns private mode on")
Equal(Tint(), ACCENT, "the eye in the accent at once")
Equal(DB().wasOn, true, "kept over a /reload, as the key's is")
Equal(#H.printed, 0, "quietly, as the key")
button:Click("LeftButton")
Equal(P:Private() and "on" or "off", "off", "and off")
Equal(Tint(), GREY, "the eye grey again")
ForeverEnhancedPrivacy_Toggle()
Equal(Tint(), ACCENT, "the key: the eye follows")
SlashCmdList.FEPRIVACY("off")
Equal(Tint(), GREY, "and /privacy off")
H.Clear()
button:Click("RightButton")
True(ForeverEnhancedPrivacyFrame and ForeverEnhancedPrivacyFrame:IsShown(), "right-click opens the settings")
Equal(P:Private(), false, "and leaves private mode alone")
ForeverEnhancedPrivacyFrame.privateButton:Click()
Equal(Tint(), ACCENT, "the window's big button: the eye follows")
ForeverEnhancedPrivacyFrame.privateButton:Click()
button:Click("RightButton")
Equal(ForeverEnhancedPrivacyFrame:IsShown(), false, "right-click again closes them")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")
Fresh({ mode = "always" })
Equal(tostring(P:Private()) .. " " .. Tint(), "true " .. ACCENT, "on from login (always): in the accent from the start")

-- Dragging round the edge --------------------------------------------------------------------------------------

Fresh(nil)
cursor[1], cursor[2] = 800, 650
H.Script(button, "OnDragStart")
Equal(tostring(button.isMoving) .. " " .. tostring(S[button].scripts.OnUpdate ~= nil), "true true",
    "dragging: flagged for minimap tidiers, following the cursor")
H.Script(button, "OnUpdate", .01)
Equal(Spot(), At(180), "follows the cursor round the edge (the left)")
cursor[1], cursor[2] = 900, 750
H.Script(button, "OnUpdate", .01)
Equal(Spot(), At(90), "to the top")
Equal(tostring(DB().minimapAngle) .. " " .. P:Get("minimapAngle"), "nil 165", "nothing saved while dragging")
H.Script(button, "OnDragStop")
Equal(DB().minimapAngle, 90, "saved where it was let go")
Equal(tostring(button.isMoving) .. " " .. tostring(S[button].scripts.OnUpdate), "nil nil", "no longer following")
Equal(Spot(), At(90), "and stays there")
button:Click()
Equal(P:Private(), false, "a click as the drag lets go is the drag's, not a click")
H.clock = H.clock + 1
button:Click()
Equal(P:Private(), true, "a moment later, clicks work again")
button:Click()
Drag(1000, 550)
Equal(P:Get("minimapAngle") .. " / " .. Spot(), "315 / " .. At(315), "below right: angles go round from the right, anticlockwise")
Drag(1000, 651)
Equal(P:Get("minimapAngle"), 1, "whole degrees")
Drag(1000, 649)
Equal(P:Get("minimapAngle"), 359, "just below the right: 359, never below 0")
-- The cursor's pixels are taken at the minimap's scale.
rawset(Minimap, "GetEffectiveScale", function() return 2 end)
Drag(1600, 1300)
Equal(P:Get("minimapAngle"), 180, "at the minimap's own scale")
rawset(Minimap, "GetEffectiveScale", function() return 1 end)
-- The minimap changing size: still on its edge.
S[Minimap].width = 200
H.Script(Minimap, "OnSizeChanged")
Equal(Spot(), At(180, 200), "a bigger minimap: still on its edge")
S[Minimap].width = 140
H.Script(Minimap, "OnSizeChanged")
Equal(Spot(), At(180), "and back")
-- Hidden mid-drag (a screenshot): let go where it was.
cursor[1], cursor[2] = 900, 550
H.Script(button, "OnDragStart")
H.Script(button, "OnUpdate", .01)
H.Screenshot("start")
Equal(tostring(button:IsShown()) .. " " .. P:Get("minimapAngle") .. " " .. tostring(button.isMoving) .. " "
    .. tostring(S[button].scripts.OnUpdate), "false 270 nil nil", "a screenshot mid-drag: hidden, and let go where it was")
H.Screenshot("done")
Equal(tostring(button:IsShown()) .. " / " .. Spot(), "true / " .. At(270), "back after, where it was let go")
-- Nothing to follow (the game won't say where the minimap is): it stays put.
rawset(Minimap, "GetCenter", function() return nil end)
H.clock = H.clock + 1
Drag(800, 650)
Equal(P:Get("minimapAngle") .. " / " .. Spot(), "270 / " .. At(270), "no minimap position: left where it was")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Saved settings checked at load ------------------------------------------------------------------------------------

for _, bad in ipairs({ 360, 400, -5, "90", true, 0 / 0, math.huge, -math.huge }) do
    Fresh({ minimapAngle = bad })
    Equal(P:Get("minimapAngle") .. " " .. tostring(DB().minimapAngle), "165 nil",
        "a bad saved angle (" .. tostring(bad) .. ") goes back to its first spot")
    Equal(Spot(), At(165), "and the button starts there (" .. tostring(bad) .. ")")
end
Fresh({ minimapAngle = 0 })
Equal(P:Get("minimapAngle") .. " / " .. Spot(), "0 / " .. At(0), "0 is a good angle (the right)")
Fresh({ minimapAngle = 271.5 })
Equal(P:Get("minimapAngle"), 271.5, "any angle round the circle is kept")
Equal(tostring(P:Set("minimapAngle", 360)) .. " " .. tostring(P:Set("minimapAngle", "x")) .. " " .. P:Get("minimapAngle"),
    "false false 271.5", "and only those are taken")
Fresh({ minimap = "yes" })
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()), "true true", "a bad saved tick: shown, as it starts")
Fresh({ minimap = false })
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()), "false false", "hidden from login when its tick is off")
Equal(H.Problems(), "", "nothing wrong loading")

-- The Overview's tick, /privacy minimap and Reset all settings --------------------------------------------------------

Fresh(nil)
SlashCmdList.FEPRIVACY("minimap")
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()), "false false", "/privacy minimap hides it")
Equal(H.printed[#H.printed], "|cffb07df0Forever Enhanced Privacy|r: The minimap button is hidden. /privacy minimap brings it back.",
    "and says how to bring it back")
SlashCmdList.FEPRIVACY("  MiniMap ")
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()), "true true", "and shows it again, any case")
Equal(H.printed[#H.printed], "|cffb07df0Forever Enhanced Privacy|r: The minimap button is back.", "saying so")
Equal(P:Private(), false, "private mode left alone")
H.Clear()
P.ShowWindow()
local tick = ForeverEnhancedPrivacyFrame.minimapRow
Equal(tick:GetChecked(), true, "the Overview's tick, ticked")
tick:Click()
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()) .. " " .. tostring(tick:GetChecked()), "false false false",
    "unticked: the button hidden")
H.Screenshot("start")
H.Screenshot("done")
Equal(button:IsShown(), false, "a screenshot ending doesn't bring it back")
tick:Click()
Equal(tostring(P:Get("minimap")) .. " " .. tostring(button:IsShown()), "true true", "ticked: shown")
P.ToggleWindow()
-- Reset all settings: shown again, at its first spot, grey with private mode off.
Drag(900, 750)
P:Set("minimap", false)
P:SetPrivate(true)
Equal(tostring(DB().minimapAngle) .. " " .. tostring(button:IsShown()) .. " " .. Tint(), "90 false " .. ACCENT, "moved, hidden, private")
P:Reset()
Equal(tostring(P:Private()) .. " " .. tostring(button:IsShown()) .. " " .. Tint(), "false true " .. GREY,
    "Reset: shown again, grey with private mode off")
Equal(tostring(DB().minimapAngle) .. " " .. tostring(DB().minimap) .. " / " .. Spot(), "nil nil / " .. At(165), "back at its first spot")
H.Clear()
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Its own hover box, never with a name -----------------------------------------------------------------------------

Fresh(nil)
H.units.target = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true, guid = "Player-1-0002" }
P:Set("myName", "Shade")
P:Set("myTag", "Fake#9999")
local tip
local function TipText()
    local parts = { H.Text(tip.title) }
    for _, line in ipairs(tip.lines) do parts[#parts + 1] = H.Text(line) end
    return table.concat(parts, " / ")
end
local function NoNames(label)
    local text = TipText()
    for _, name in ipairs({ "Zriel", "Gustbellow", "Shade", "Fake", "Brannoc", "Druid" }) do
        True(not text:find(name, 1, true), label .. ": no " .. name .. " in the hover box")
    end
end
Equal(P.MinimapButton:Tip(), nil, "no hover box until it's needed")
H.Script(button, "OnEnter")
tip = P.MinimapButton:Tip()
True(tip and tip:IsShown(), "hovering shows a box of its own")
Equal(S[tip].kind .. " " .. tostring(S[tip].parent == UIParent) .. " " .. S[tip].strata .. " " .. tostring(S[tip].mouse) .. " "
    .. S[tip].width .. "x" .. S[tip].height, "Frame true TOOLTIP false 220x84", "on top of everything, never taking the mouse")
Equal(TipText(), "Forever Enhanced Privacy / Private mode: off / Left-click: turn it on / Right-click: settings / "
    .. "Drag: move it round the minimap", "its name, private mode's state and what the mouse does")
Equal(Rgb(S[tip.title].colour) .. " " .. Rgb(S[tip].border), ACCENT .. " " .. ACCENT, "its name and edge in the accent")
-- Every line inside the box, 10 in from each side, the last above its bottom.
for _, text in ipairs({ tip.title, (table.unpack or unpack)(tip.lines) }) do
    local p = S[text].points[1]
    True(p[2] + text:GetStringWidth() <= S[tip].width - 10, H.Text(text) .. ": fits the box (" .. p[2] .. " + " .. text:GetStringWidth() .. ")")
    True(-p[3] + 12 <= S[tip].height - 4, H.Text(text) .. ": above the box's bottom (" .. -p[3] .. ")")
end
Equal(table.concat({ S[tip].points[1][1], tostring(S[tip].points[1][2] == button), S[tip].points[1][3] }, " "),
    "TOPRIGHT true BOTTOMLEFT", "below and left of the button (the minimap's usual corner)")
NoNames("off")
button:Click()
Equal(TipText(), "Forever Enhanced Privacy / Private mode: |cffb07df0on|r / Left-click: turn it off / Right-click: settings / "
    .. "Drag: move it round the minimap", "a click while hovering: it says so at once")
NoNames("on")
for _, style in ipairs({ "player", "hidden", "class" }) do
    P:Set("nameStyle", style)
    NoNames(style)
end
P:Set("myColour", "accent")
NoNames("in purple")
H.Script(button, "OnLeave")
Equal(tip:IsShown(), false, "gone when the mouse leaves")
-- Toward the middle of the screen: a button at the bottom left opens it up and right.
rawset(UIParent, "GetCenter", function() return 512, 384 end)
button.GetCenter = function() return 100, 100 end
H.Script(button, "OnEnter")
Equal(table.concat({ S[tip].points[1][1], S[tip].points[1][3] }, " "), "BOTTOMLEFT TOPRIGHT", "a button low on the left: up and right")
button.GetCenter = nil
H.Script(button, "OnDragStart")
Equal(tip:IsShown(), false, "a drag takes it away")
H.Script(button, "OnEnter")
Equal(tip:IsShown(), false, "and it stays away while dragging")
H.Script(button, "OnDragStop")
H.clock = H.clock + 1
H.Script(button, "OnEnter")
H.Screenshot("start")
Equal(tostring(button:IsShown()) .. " " .. tostring(tip:IsShown()), "false false", "a screenshot: the button and its box both gone")
H.Screenshot("done")
Equal(tostring(button:IsShown()) .. " " .. tostring(tip:IsShown()), "true false", "the button back, the box only on the next hover")
P:SetPrivate(false)
Equal(H.Text(GameTooltipTextLeft1), nil, "the game's tooltip never touched")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Screenshots, as the eye -----------------------------------------------------------------------------------------------

Fresh(nil)
H.Screenshot("start")
Equal(tostring(P:Private()) .. " " .. tostring(button:IsShown()), "false false", "hidden for every screenshot, as the eye")
H.Screenshot("done")
Equal(button:IsShown(), true, "and back once it's taken")
H.Screenshot("start")
H.Screenshot("fail")
Equal(button:IsShown(), true, "or once it fails")
P:SetPrivate(true)
H.Screenshot("start")
Equal(tostring(P:Private()) .. " " .. tostring(button:IsShown()) .. " " .. tostring(P.Eye:Frame():IsShown()), "true false false",
    "private: hidden, as the eye is")
H.Screenshot("done")
Equal(tostring(button:IsShown()) .. " " .. Tint(), "true " .. ACCENT, "back after, still in the accent")
P:SetPrivate(false)
-- For screenshots: already gone as private mode comes on for the picture.
P:Set("mode", "shots")
local shownAsItCameOn
P:Listen(function(what)
    if what == "private" and P:Private() then shownAsItCameOn = button:IsShown() end
end)
H.Screenshot("start")
Equal(tostring(P:Private()) .. " " .. tostring(shownAsItCameOn), "true false", "For screenshots: already hidden as it comes on")
H.Screenshot("done")
Equal(tostring(P:Private()) .. " " .. tostring(button:IsShown()) .. " " .. Tint(), "false true " .. GREY, "then back, grey, as it goes off")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- The minimap is only read and hooked ---------------------------------------------------------------------------------

do
    local scripts = {}
    for key in pairs(S[Minimap].scripts) do scripts[#scripts + 1] = key end
    Equal(table.concat(scripts, " "), "OnSizeChanged", "the minimap: only its size followed, through a hook")
    Equal(#H.violations, 0, "and nothing done to it but reads and that hook (no key written, nothing moved)")
end

io.stdout:write("TestMinimap: " .. H.checks .. " checks passed\n")
