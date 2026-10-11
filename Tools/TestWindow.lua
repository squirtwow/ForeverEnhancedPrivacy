-- The /privacy window against a mock game (Tools/Harness.lua): its pages
-- in order, a row for every setting (ticks and choices, from Core.lua's one
-- table), ticks and choices saving and telling the owner while private, the
-- Overview's big button, modes, name styles, your name and made-up BattleTag
-- boxes (and the left column still fitting), name colours, the eye's and the
-- minimap button's ticks side by side, the live preview, the footer's notes
-- and credit, quiet tags, Good to know,
-- Escape, Options > AddOns, sizes given at creation, scroll frames pinned by
-- two corners, no em dash anywhere shown, and Blizzard's frames untouched.
-- Run with fengari: Tools/TestWindow.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True

H.Environment()
local P = H.Load(nil)
local w

local function Hover(control) H.Script(control, "OnEnter") end
local function Leave(control) H.Script(control, "OnLeave") end
local function Note() return H.Text(w.note) end
local CREDIT = "Made with |TInterface\\AddOns\\ForeverEnhancedPrivacy\\Media\\Heart.tga:0:0:0:0:32:32:0:32:0:32:176:125:240|t"
    .. " by |cffb07df0Squirt|r"
local WHITE = "|cffe8e6e1"

-- Opening ------------------------------------------------------------------------------------------------

SlashCmdList.FEPRIVACY("")
w = ForeverEnhancedPrivacyFrame
True(w and w:IsShown(), "/privacy opens the window")
Equal(P.window, w, "the addon keeps it")
Equal(S[w].width .. "x" .. S[w].height, "900x580", "sized as it's made")
Equal(S[w].strata, "DIALOG", "over the game's windows")
Equal(UISpecialFrames[1], "ForeverEnhancedPrivacyFrame", "Escape closes it, through the game's own list")
Equal(#UISpecialFrames, 1, "listed once")
Equal(H.Text(w.title), "Forever Enhanced Privacy", "its name at the top of the list")
Equal(S[w.title].colour[1] .. " " .. S[w.title].colour[3], P.ACCENT[1] .. " " .. P.ACCENT[3], "in the accent")
Equal(H.Text(w.status), "Private mode: off", "saying private mode is off")
Equal(Note(), CREDIT, "the footer at rest: Made with a heart by Squirt, in the accent")
True(H.Find("/privacy to open"), "the command at the foot of the list")

-- The pages.
do
    local labels = {}
    for _, page in ipairs(P.PAGES) do
        labels[#labels + 1] = H.Text(w.nav[page.key].label)
        Equal(S[w.nav[page.key]].points[1][3], -(88 + (#labels - 1) * 32), page.key .. " listed in order")
    end
    Equal(table.concat(labels, "|"), "Overview|Names|Chat|Friends and guild|Windows and pop-ups|World and location|Good to know",
        "seven pages, as the mockup")
end
Equal(w.selected, "overview", "opening on the Overview")
for _, page in ipairs(P.PAGES) do
    w:Select(page.key)
    local shown = {}
    for key, frame in pairs(w.pages) do if frame:IsShown() then shown[#shown + 1] = key end end
    Equal(table.concat(shown, ","), page.key, page.key .. " shown alone")
    Equal(w.nav[page.key].fill:IsShown() and w.nav[page.key].mark:IsShown(), true, page.key .. " lit in the list")
    Equal(H.Text(w.pages[page.key].title) .. " / " .. H.Text(w.pages[page.key].about), page.label .. " / " .. page.about,
        page.key .. "'s title and what it's for")
    Equal(S[w.pages[page.key]].width .. "x" .. S[w.pages[page.key]].height, "698x529", page.key .. " sized as it's made")
    local scroll = w.pages[page.key].scroll
    if scroll then
        Equal(S[scroll].points[1][1] .. " " .. S[scroll].points[2][1], "TOPLEFT BOTTOMRIGHT", page.key .. ": its list pinned by two corners")
        H.RunTimers()
        Equal(#S[scroll].points, 2, page.key .. ": and pinned again once shown")
    end
end
w:Select("nowhere")
Equal(w.selected, "limits", "an unknown page changes nothing")

-- Every setting's row ---------------------------------------------------------------------------------------

do
    local count = 0
    for _, key in ipairs(P.KEYS) do
        local row, control = P.ROWS[key], w.controls[key]
        True(control, key .. " has a row")
        count = count + 1
        True(H.Under(control, w.pages[row.page]), key .. " on its own page")
        True(S[control].width > 0 and S[control].height > 0, key .. " sized as it's made")
        if row.options then
            Equal(S[control].width, 650, key .. ": a choice runs the full width")
            local labels = {}
            for _, button in ipairs(control.options.order) do labels[#labels + 1] = H.Text(button.label) end
            local expected = {}
            for _, option in ipairs(row.options) do expected[#expected + 1] = option.label end
            Equal(table.concat(labels, "|"), table.concat(expected, "|"), key .. "'s options")
        else
            Equal(S[control].width, 320, key .. ": a tick takes one of two columns")
            Equal(H.Text(control.label), row.label, key .. "'s label")
            if row.tag then
                Equal(H.Text(control.tag), row.tag, key .. "'s tag, a quiet word")
                Equal(H.Text(control.tag), row.tag:lower(), key .. "'s tag in lower case")
                Equal(S[control.tag].kind, "FontString", key .. "'s tag is plain text, never a box")
                Equal(S[control.tag].points[1][2], control.label, key .. "'s tag sits after the label")
            else
                Equal(control.tag, nil, key .. " has no tag")
            end
            -- Box, label and tag fit the row, with a little to spare (the
            -- harness reckons six units a letter; the game's font is close).
            local used = 32 + control.label:GetStringWidth() + (control.tag and (5 + control.tag:GetStringWidth()) or 0)
            True(used <= 320 - 8, key .. "'s label and tag fit its row (" .. used .. ")")
        end
    end
    Equal(count, 42, "every setting has its row")
end
-- The Overview's left column stays clear of the preview.
do
    local right = 0
    for _, button in ipairs(w.modes.order) do right = right + S[button].width + 6 end
    True(right - 6 <= 372 - 20, "the mode buttons fit beside the preview")
    Equal(S[w.modeTag].points[1][2], H.Find("HOW IT TURNS ON"), "the experimental word sits after the heading")
end
-- Two columns, wide rows on their own.
local function X(control) return S[control].points[1][2] end
local function Y(control) return S[control].points[1][3] end
Equal(X(w.controls.playerFrame) .. " " .. X(w.controls.charTitles) .. " " .. X(w.controls.questText), "0 330 0", "ticks fill two columns")
Equal(Y(w.controls.playerFrame) .. " " .. Y(w.controls.charTitles) .. " " .. Y(w.controls.questText), "-20 -20 -54", "row by row")
-- The Chat page: "Leave public channels as they are" right under "Swap names
-- in chat", the other two ticks beside them, the dungeon choice below.
do
    local c = w.controls
    Equal(X(c.chatNames) .. " " .. Y(c.chatNames) .. " / " .. X(c.publicChannels) .. " " .. Y(c.publicChannels), "0 -20 / 0 -54",
        "Leave public channels as they are: right under Swap names in chat")
    Equal(X(c.whispers) .. " " .. Y(c.whispers) .. " / " .. X(c.cleanOld) .. " " .. Y(c.cleanOld), "330 -20 / 330 -54",
        "Hide whispers and Clean lines beside them")
    Equal(X(c.instChat) .. " " .. Y(c.instChat), "0 -88", "a choice starts its own row, below the ticks")
    Equal(S[H.Find("GIVEAWAYS")].points[1][3] .. " " .. Y(c.channels), "-140 -160", "and the next section starts below it")
    Equal(H.Text(c.publicChannels.label) .. " " .. tostring(c.publicChannels.tag), "Leave public channels as they are nil",
        "its label, no tag")
end

-- Ticks and choices save, and tell the owner while private.
w:Select("chat")
local whispers = w.controls.whispers
Equal(whispers:GetChecked(), false, "Hide whispers starts off")
whispers:Click()
Equal(tostring(P:Get("whispers")) .. " " .. tostring(whispers:GetChecked()), "true true", "a click ticks it and saves it")
whispers:Click()
Equal(P:Get("whispers"), false, "and back")
local told = {}
P:Module("Chat").Apply = function(_, on, key) told[#told + 1] = tostring(on) .. "," .. tostring(key) end
w.controls.instChat.options.buttons.chat:Click()
Equal(P:Get("instChat"), "chat", "a choice saves")
Equal(w.controls.instChat.options.buttons.chat.selected and not w.controls.instChat.options.buttons.names.selected, true,
    "the chosen option filled")
Equal(#told, 0, "while off, no module hears")
P:SetPrivate(true)
told = {}
whispers:Click()
Equal(table.concat(told, " "), "true,whispers", "while private, its owner hears at once")
whispers:Click()
w.controls.instChat.options.buttons.names:Click()
Equal(table.concat(told, " "), "true,whispers true,whispers true,instChat", "for each change")
-- Leave public channels as they are.
do
    local public = w.controls.publicChannels
    told = {}
    Equal(public:GetChecked(), false, "Leave public channels as they are starts off")
    public:Click()
    Equal(tostring(P:Get("publicChannels")) .. " " .. tostring(public:GetChecked()) .. " " .. table.concat(told, " "),
        "true true true,publicChannels", "a click ticks it, saves it, and Chat hears")
    public:Click()
    Equal(P:Get("publicChannels"), false, "and back")
    Hover(public)
    Equal(Note(), WHITE .. "Leave public channels as they are|r  Names in Trade, General and Looking for Group show as normal, so "
        .. "you can read who's selling and chatting. Your own name is still swapped.", "its note, short and plain")
    Leave(public)
end
P:SetPrivate(false)

-- The footer explains what's under the mouse.
local nameplates = w.controls.nameplates
w:Select("names")
Hover(nameplates)
Equal(Note(), WHITE .. "Nameplates|r  A few plates in dungeons are locked by the game and keep their names. (experimental)",
    "a row's note, its tag after")
Leave(nameplates)
Equal(Note(), CREDIT, "and back to the credit")
Hover(w.controls.playerFrame)
Leave(nameplates)
True(Note():find("Player and pet frames", 1, true), "only the row whose note is up can take it down")
Leave(w.controls.playerFrame)
Hover(w.nav.chat)
Equal(Note(), WHITE .. "Chat|r  Names and giveaways in chat.", "a page's note")
Leave(w.nav.chat)
w:Select("world")
Hover(w.controls.worldMap.options.buttons.hide)
True(Note():find("World map: Keep closed", 1, true), "a choice's option")
Leave(w.controls.worldMap.options.buttons.hide)

-- The Overview ---------------------------------------------------------------------------------------------------

w:Select("overview")
local big = w.privateButton
Equal(H.Text(big.label), "Turn private mode on", "the big button")
big:Click()
Equal(P:Private(), true, "turns private mode on")
Equal(H.Text(big.label) .. " / " .. H.Text(w.status), "Private mode is on. Turn it off / Private mode: |cffb07df0on|r",
    "and says so, on in the accent")
Equal(S[big].backdrop[1], P.ACCENT[1], "filled with the accent while on")
Hover(big)
Equal(Note(), WHITE .. "Private mode|r  Hides or swaps everything ticked on these pages. Turn it off and it all comes back, "
    .. "apart from chat lines that were cleaned or hidden.", "its note")
Leave(big)
big:Click()
Equal(P:Private(), false, "and off")

-- How it turns on.
local modes = w.modes.buttons
Equal(H.Text(modes.key.label) .. "|" .. H.Text(modes.shots.label) .. "|" .. H.Text(modes.always.label),
    "With its key|For screenshots|Always, from login", "three ways it turns on")
Equal(modes.key.selected, true, "with its key, to begin with")
Equal(w.modeTag:IsShown(), false, "no experimental note for it")
modes.shots:Click()
Equal(P:Get("mode") .. " " .. tostring(modes.shots.selected) .. " " .. tostring(modes.key.selected), "shots true false", "for screenshots")
Equal(tostring(w.modeTag:IsShown()) .. " " .. H.Text(w.modeTag), "true experimental", "a quiet experimental after it")
Hover(modes.shots)
Equal(Note(), WHITE .. "For screenshots|r  Everything hides for the moment you press Print Screen, then comes straight back. (experimental)",
    "what it does")
Leave(modes.shots)
modes.always:Click()
Equal(P:Get("mode") .. " " .. tostring(w.modeTag:IsShown()), "always false", "always")
Hover(modes.always)
Equal(Note(), WHITE .. "Always, from login|r  On every time you log in. For streaming.", "for streaming")
Leave(modes.always)
modes.key:Click()

-- Names become.
local styles = w.styles.buttons
Equal(H.Text(styles.class.label) .. "|" .. H.Text(styles.player.label) .. "|" .. H.Text(styles.hidden.label), "Class name|Player|Hidden",
    "three name styles")
Equal(styles.class.selected, true, "class names to begin with")
styles.player:Click()
Equal(P:Get("nameStyle") .. " " .. tostring(styles.player.selected), "player true", "Player")
Hover(styles.hidden)
Equal(Note(), WHITE .. "Hidden|r  Names are left blank.", "each says what it does")
Leave(styles.hidden)
styles.class:Click()

-- Your name becomes.
local box = w.nameBox
Equal(S[box].maxLetters, 24, "at most 24 letters")
Equal(H.Text(box.placeholder), "Leave empty to use the setting above", "a grey hint while empty")
Equal(box.placeholder:IsShown(), true, "shown")
box:SetFocus()
Equal(box.placeholder:IsShown(), false, "gone while typing")
box:SetText("  Shade   Walker ")
H.Script(box, "OnEnterPressed")
Equal(P:Get("myName") .. "|" .. box:GetText(), "Shade Walker|Shade Walker", "Enter saves it, tidied")
Equal(box.placeholder:IsShown(), false, "no hint over a name")
box:SetFocus()
box:SetText("Oops")
H.Script(box, "OnEscapePressed")
Equal(P:Get("myName") .. "|" .. box:GetText(), "Shade Walker|Shade Walker", "Escape puts it back")
box:SetFocus()
box:SetText("")
box:ClearFocus()
Equal(P:Get("myName") .. "|" .. tostring(box.placeholder:IsShown()), "|true", "emptied: back to the name style, the hint back")
Hover(box)
True(Note():find("Empty: your name follows the setting above.", 1, true), "its note")
Leave(box)

-- Your BattleTag becomes, right under your name and styled the same.
local tagBox = w.tagBox
do
    local heading = H.Find("YOUR BATTLETAG BECOMES")
    True(heading and H.Under(heading, w.pages.overview), "a made-up BattleTag, under its own heading on the Overview")
    Equal(S[heading].points[1][3] .. " " .. S[tagBox].points[1][3], "-234 -252", "right under the name box (it ends at 220)")
    Equal(S[heading].points[1][2] .. " " .. S[tagBox].points[1][2] .. " " .. S[box].points[1][2], "0 0 0", "lined up with it")
    Equal(S[tagBox].parent, S[box].parent, "in the same column")
    Equal(S[tagBox].kind .. " " .. S[tagBox].width .. "x" .. S[tagBox].height, "EditBox 350x30", "a text box as wide as the column")
    Equal(table.concat(S[tagBox].backdrop, " ") .. " / " .. table.concat(S[tagBox].border, " "),
        table.concat(S[box].backdrop, " ") .. " / " .. table.concat(S[box].border, " "), "the name box's look")
    Equal(S[tagBox.placeholder].colour[1], S[box.placeholder].colour[1], "and its grey hint")
end
Equal(S[tagBox].maxLetters, 24, "a BattleTag of at most 24 letters")
Equal(H.Text(tagBox.placeholder), "Leave empty to use your name above", "a grey hint while empty")
Equal(tagBox.placeholder:IsShown(), true, "shown")
tagBox:SetFocus()
Equal(tagBox.placeholder:IsShown(), false, "gone while typing")
tagBox:SetText("  Fake   Tag#9999 ")
H.Script(tagBox, "OnEnterPressed")
Equal(P:Get("myTag") .. "|" .. tagBox:GetText() .. "|" .. P:Get("myName") .. "|" .. box:GetText(), "Fake Tag#9999|Fake Tag#9999||",
    "Enter saves it, tidied, and leaves your name alone")
Equal(tostring(tagBox.placeholder:IsShown()) .. " " .. tostring(box.placeholder:IsShown()), "false true",
    "no hint over it; the empty name box keeps its own")
tagBox:SetFocus()
tagBox:SetText("Oops#1")
H.Script(tagBox, "OnEscapePressed")
Equal(P:Get("myTag") .. "|" .. tagBox:GetText(), "Fake Tag#9999|Fake Tag#9999", "Escape puts it back")
box:SetFocus()
box:SetText("Shade")
box:ClearFocus()
Equal(P:Get("myName") .. "|" .. P:Get("myTag") .. "|" .. tagBox:GetText(), "Shade|Fake Tag#9999|Fake Tag#9999", "a name typed leaves it alone")
P:Set("myTag", "Other#42")
Equal(tagBox:GetText(), "Other#42", "a change from elsewhere shows at once")
tagBox:SetFocus()
tagBox:SetText("Half#1")
w:Hide()
Equal(P:Get("myTag") .. " " .. tostring(tagBox:HasFocus()), "Half#1 false", "closing the window while typing saves it, as the name box does")
P.ShowWindow()
tagBox:SetFocus()
tagBox:SetText("")
tagBox:ClearFocus()
Equal(P:Get("myTag") .. "|" .. tostring(tagBox.placeholder:IsShown()), "|true", "emptied: off, the hint back")
box:SetFocus()
box:SetText("")
box:ClearFocus()
Hover(tagBox)
Equal(Note(), WHITE .. "Your BattleTag becomes|r  A made-up BattleTag shown instead of yours in the friends windows. Empty: your name "
    .. "above, or \"Battle.net\".", "its note, short and plain")
Leave(tagBox)

-- Name colour, right under your name and BattleTag (it colours both).
local colours = w.colours.buttons
do
    local labels = {}
    for _, button in ipairs(w.colours.order) do labels[#labels + 1] = H.Text(button.label) end
    Equal(table.concat(labels, "|"), "Game's own|Purple|Your class colour|White", "four name colours")
    local heading = H.Find("NAME COLOUR")
    True(heading and H.Under(heading, w.pages.overview), "under its own heading on the Overview")
    Equal(S[heading].points[1][3] .. " " .. S[w.colours].points[1][3], "-296 -314", "right under the BattleTag box (it ends at 282)")
    local right = 0
    for _, button in ipairs(w.colours.order) do right = right + S[button].width + 6 end
    True(right - 6 <= 372 - 20, "the colour buttons fit beside the preview (" .. (right - 6) .. ")")
    Equal(S[H.Find("EXTRAS")].points[1][3] .. " " .. S[w.eyeRow].points[1][3] .. " " .. S[w.keyNote].points[1][3], "-352 -370 -412",
        "Extras moved down to make room")
    -- The eye and the minimap button side by side (no room for another row
    -- above the key note): the column's width between them, a gap apart,
    -- each label fitting its tick with a little to spare.
    local eye, minimap = w.eyeRow, w.minimapRow
    Equal(S[minimap].points[1][3] .. " " .. S[minimap].points[1][2] .. " " .. tostring(S[minimap].parent == S[eye].parent),
        "-370 " .. (S[eye].width + 10) .. " true", "the minimap button's tick beside the eye's, 10 apart (as the list pages' columns)")
    Equal(S[eye].width + 10 + S[minimap].width, 350, "the two filling the column, clear of the preview")
    Equal(S[eye].height .. " " .. S[minimap].height, "30 30", "as tall as every tick")
    for _, tick in ipairs({ eye, minimap }) do
        local used = 32 + tick.label:GetStringWidth()
        True(used <= S[tick].width - 8, H.Text(tick.label) .. ": fits its tick (" .. used .. " of " .. S[tick].width .. ")")
    end
    -- In the game a label runs nearer seven units a letter: both still fit.
    True(32 + #P.EYE_ROW.label * 7 <= S[eye].width and 32 + #P.MINIMAP_ROW.label * 7 <= S[minimap].width,
        "and at seven units a letter")
end
-- The whole left column still fits: each control below the one before
-- (with a little room), and the last line above the footer.
do
    local column, page = w.column, w.pages.overview
    local stack = { { w.privateButton, 44 }, { w.modes, 24 }, { w.styles, 24 }, { box, 30 }, { tagBox, 30 }, { w.colours, 24 },
        { w.eyeRow, 30 }, { w.keyNote, w.keyNote:GetStringHeight() } }
    local bottom = 0
    for i, item in ipairs(stack) do
        local top = -(S[item[1]].points[1][3] or 0)
        True(S[item[1]].parent == column, "control " .. i .. " in the left column")
        True(top >= bottom + (i > 1 and 10 or 0), "control " .. i .. " starts below the one before (" .. top .. ")")
        bottom = top + item[2]
    end
    True(bottom <= S[column].height, "the key note ends inside the column (" .. bottom .. " of " .. S[column].height .. ")")
    Equal(S[column].points[1][3], -82, "the column starts under the page's title")
    True(82 + S[column].height <= S[page].height, "and ends above the footer (" .. (82 + S[column].height) .. " of " .. S[page].height .. ")")
    local columnRight, previewLeft = S[column].points[1][2] + S[column].width, S[w.preview.panel].points[1][2]
    True(columnRight + 20 <= previewLeft, "and clear of the preview (" .. columnRight .. " to " .. previewLeft .. ")")
end
Equal(colours.game.selected and not colours.accent.selected, true, "the game's own to begin with")
colours.accent:Click()
Equal(P:Get("myColour") .. " " .. tostring(colours.accent.selected) .. " " .. tostring(colours.game.selected), "accent true false",
    "Purple saves and fills")
colours.class:Click()
Equal(P:Get("myColour"), "class", "your class colour")
colours.white:Click()
Equal(P:Get("myColour"), "white", "white")
colours.game:Click()
Equal(P:Get("myColour") .. " " .. tostring(colours.game.selected), "game true", "and back to the game's own")
Hover(colours.class)
Equal(Note(), WHITE .. "Name colour: Your class colour|r  The colour of your name and BattleTag while private. Game's own keeps "
    .. "whatever colour the game gives it in each place.", "its note, short and plain")
Leave(colours.class)
Hover(colours.game)
True(Note():find("Name colour: Game's own", 1, true), "each option says which it is")
Leave(colours.game)

-- Extras.
local eyeRow = w.eyeRow
Equal(H.Text(eyeRow.label) .. " " .. tostring(eyeRow:GetChecked()), "Show a small eye true", "the eye, on")
eyeRow:Click()
Equal(P:Get("eye"), false, "a click turns it off")
eyeRow:Click()
Equal(P:Get("eye"), true, "and on")
Hover(eyeRow)
Equal(Note(), WHITE .. "Show a small eye|r  A small eye at the top of the screen while private mode is on, so you know it's working. "
    .. "It hides itself in screenshots, but stream viewers can see it, so you can turn it off.", "its note says when it shows")
Leave(eyeRow)
local minimapRow = w.minimapRow
Equal(H.Text(minimapRow.label) .. " " .. tostring(minimapRow:GetChecked()) .. " " .. tostring(minimapRow.tag),
    "Show a minimap button true nil", "the minimap button, on, no tag")
minimapRow:Click()
Equal(tostring(P:Get("minimap")) .. " " .. tostring(minimapRow:GetChecked()) .. " " .. tostring(P.MinimapButton:Button():IsShown()),
    "false false false", "a click hides the button")
minimapRow:Click()
Equal(tostring(P:Get("minimap")) .. " " .. tostring(minimapRow:GetChecked()) .. " " .. tostring(P.MinimapButton:Button():IsShown()),
    "true true true", "and shows it")
Hover(minimapRow)
Equal(Note(), WHITE .. "Show a minimap button|r  Left-click turns private mode on or off, right-click opens these settings, and you "
    .. "can drag it round the minimap. It hides itself in screenshots.", "its note says what the button does")
Leave(minimapRow)
SlashCmdList.FEPRIVACY("minimap")
Equal(minimapRow:GetChecked(), false, "/privacy minimap unticks it at once")
SlashCmdList.FEPRIVACY("minimap")
Equal(minimapRow:GetChecked(), true, "and ticks it again")
H.Clear()
Equal(H.Text(w.keyNote), "Set its key in the game's Key Bindings, under AddOns.", "where its key is set")

-- The preview ------------------------------------------------------------------------------------------------------

local view = w.preview
local function Party(i) return H.Text(view.party[i]) end
local function Chat(i) return H.Text(view.chat[i]) end
Equal(H.Text(view.target), "Brannoc Stonehelm", "off: the sample target's name")
Equal(Party(1) .. "|" .. Party(2) .. "|" .. Party(3), "Merrin Lightfoot|Kaelis Dawnbrook|Zriel Gustbellow", "the party, you last")
Equal(Chat(1), "|cff40ff40[Guild]|r |cffe8e6e1[Zriel Gustbellow]|r|cff40ff40: anyone up for Deadmines?|r", "guild chat")
Equal(Chat(2), "|cffffc0c0[1. General - Stormwind]|r |cffe8e6e1[Merrin Lightfoot]|r|cffffc0c0: LF tank for Stockades|r", "a channel")
Equal(Chat(4), "|cff00ccffBeatrix (Bea#2231) has come online.|r", "a friend coming online")
Equal(H.Text(view.zone) .. " " .. H.Text(view.coords), "Stormwind City 48.2, 61.7", "where you are")
Equal(view.eye:IsShown(), false, "no eye while off")
P:SetPrivate(true)
Equal(H.Text(view.target), "Warrior", "on: the class name")
Equal(S[view.target].colour[1], H.CLASS_COLOURS.WARRIOR.r, "in its colour")
Equal(Party(1) .. "|" .. Party(2) .. "|" .. Party(3), "Priest|Mage|Druid", "the party, you as your class")
Equal(Chat(1), "|cff40ff40[Guild]|r |cffff7d0a[Druid]|r|cff40ff40: anyone up for Deadmines?|r", "names swapped in chat")
Equal(Chat(2), "|cffffc0c0[1. General]|r |cffffffff[Priest]|r|cffffc0c0: LF tank for Stockades|r", "the zone gone from the channel")
P:Set("publicChannels", true)
Equal(Chat(2), "|cffffc0c0[1. General]|r |cffe8e6e1[Merrin Lightfoot]|r|cffffc0c0: LF tank for Stockades|r",
    "public channels left: General shows who's talking, its zone still gone")
Equal(Chat(1), "|cff40ff40[Guild]|r |cffff7d0a[Druid]|r|cff40ff40: anyone up for Deadmines?|r", "guild chat still swapped")
P:Set("channels", false)
Equal(Chat(2), "|cffffc0c0[1. General - Stormwind]|r |cffe8e6e1[Merrin Lightfoot]|r|cffffc0c0: LF tank for Stockades|r",
    "the zone follows Channel names alone")
P:Set("channels", true)
P:Set("publicChannels", false)
Equal(Chat(4), "", "a friend coming online: left out of chat, as chat really does")
P:Set("chatNames", false)
Equal(Chat(4), "", "still left out with only the pop-ups ticked")
P:Set("bnToasts", false)
Equal(Chat(4), "|cff00ccffBeatrix (Bea#2231) has come online.|r", "neither ticked: shown")
P:Set("chatNames", true)
P:Set("bnToasts", true)
Equal(H.Text(view.zone) .. "|" .. H.Text(view.coords), "|", "no zone, no coordinates")
Equal(view.eye:IsShown(), true, "the eye")
P:Set("myName", "Shade")
Equal(Party(3), "Shade", "your typed name")
True(Chat(1):find("[Shade]", 1, true), "in chat too")
-- Its colour, in the preview: the game's own looks as your real name does here.
do
    local function Rgb(region)
        local c = S[region].colour
        return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3])
    end
    local real = ("%.2f %.2f %.2f"):format(P.Theme.C.text[1], P.Theme.C.text[2], P.Theme.C.text[3])
    local cases = {
        { "accent", "0.69 0.49 0.94", "b07df0" }, { "class", "1.00 0.49 0.04", "ff7d0a" }, { "white", "1.00 1.00 1.00", "ffffff" },
        { "game", real, "e8e6e1" },
    }
    for _, case in ipairs(cases) do
        colours[case[1]]:Click()
        Equal(Party(3) .. " / " .. Rgb(view.party[3]), "Shade / " .. case[2], case[1] .. ": your frame in the preview")
        True(Chat(1):find("|cff" .. case[3] .. "[Shade]|r", 1, true), case[1] .. ": your name in the preview's chat")
        Equal(H.Text(view.target) .. " / " .. Rgb(view.target), "Warrior / 0.78 0.61 0.43", case[1] .. ": others as before")
    end
    Equal(colours.game.selected, true, "the game's own chosen again")
end
P:Set("nameStyle", "player")
Equal(H.Text(view.target) .. "|" .. Party(1) .. "|" .. Party(3), "Player|Player|Shade", "the Player style")
P:Set("nameStyle", "hidden")
Equal(H.Text(view.target) .. "|" .. Party(1), "|", "the Hidden style")
Equal(Chat(2), "|cffffc0c0[1. General]|r|cffffc0c0: LF tank for Stockades|r", "no empty brackets in chat")
P:Set("nameStyle", "class")
P:Set("myName", "")
P:Set("targetFrames", false)
Equal(H.Text(view.target), "Brannoc Stonehelm", "an unticked row shows the real name")
P:Set("targetFrames", true)
P:Set("eye", false)
Equal(view.eye:IsShown(), false, "the eye only with its tick")
P:Set("eye", true)
P:SetPrivate(false)
Equal(H.Text(view.target), "Brannoc Stonehelm", "off again: real names")

-- Good to know --------------------------------------------------------------------------------------------------------

w:Select("limits")
Equal(#w.limits, 7, "seven notes")
for i, limit in ipairs(P.LIMITS) do
    True(H.Find(limit.title), limit.title)
    True(H.Under(H.Find(limit.text), w.limits[i]), limit.title .. ": its text in its card")
end
True(H.Find("Not in Forever yet. Covered when they arrive."), "arenas: room left for them")
True(H.Find("Untick friendly healer names in the game's Combat options", true), "healer names: how to hide them by hand")
for _, hover in ipairs({ "group dots on the world map", "the mail icon", "calendar days", "\"Waiting on\" line" }) do
    True(H.Find(hover, true), "a hover to avoid: " .. hover)
end
True(H.Find("\"[Party] (hidden)\"", true), "what a locked chat line becomes, and that it doesn't come back")

-- Reset all settings, at the bottom right of the Overview ------------------------------------------------------------------

local reset = w.reset
w:Select("overview")
do
    local page = w.pages.overview
    True(reset and S[reset].parent == page, "a reset row on the Overview, where it's easy to find")
    Equal(S[reset].points[1][1] .. " " .. S[reset].points[1][2] .. " " .. S[reset].points[1][3], "BOTTOMRIGHT -24 12",
        "at its bottom right")
    local panel = S[w.preview.panel]
    local panelBottom = -panel.points[1][3] + panel.height
    local rowTop = S[page].height - 12 - S[reset].height
    True(rowTop >= panelBottom + 8, "under the preview, clear of it (" .. rowTop .. " vs " .. panelBottom .. ")")
    Equal(S[reset].width .. "x" .. S[reset].height, panel.width .. "x30", "as wide as the preview, one button high")
    local content = w.pages.limits.scroll.content
    local last = w.limits[#w.limits]
    Equal(S[content].height, -S[last].points[1][3] + S[last].height + 10, "Good to know ends with its last note again")
    local button = reset.button
    Equal(H.Text(button.label) .. " " .. S[button].kind, "Reset all settings Button", "Reset all settings")
    Equal(S[button].points[1][1] .. " " .. S[button].height, "RIGHT 30", "at the right, as tall as the window's rows")
    local C = P.Theme.C
    Equal(table.concat(S[button].backdrop, " ") .. " / " .. table.concat(S[button].border, " "),
        table.concat({ C.button[1], C.button[2], C.button[3], 1 }, " ") .. " / " .. table.concat({ C.buttonEdge[1], C.buttonEdge[2],
        C.buttonEdge[3], 1 }, " "), "styled like the window's own buttons")
    Equal(S[w.privateButton].backdrop[1] .. " " .. S[w.privateButton].border[1], C.button[1] .. " " .. C.buttonEdge[1],
        "the big button's look while off")
    True(S[button].width <= S[reset].width, "the button fits the row")
    local asking = reset.ask:GetStringWidth() + 12 + S[reset.yes].width + 6 + S[reset.no].width
    True(asking <= S[reset].width, "the question and its two buttons fit too (" .. asking .. ")")
    Equal(S[reset.no].points[1][1] .. " " .. S[reset.yes].points[1][1] .. " " .. tostring(rawequal(S[reset.yes].points[1][2], reset.no))
        .. " " .. S[reset.ask].points[1][1] .. " " .. tostring(rawequal(S[reset.ask].points[1][2], reset.yes)),
        "RIGHT RIGHT true RIGHT true", "Cancel at the right, Reset left of it, the question left of that")
    Equal(tostring(button:IsShown()) .. " " .. tostring(reset.ask:IsShown()) .. " " .. tostring(reset.yes:IsShown()) .. " "
        .. tostring(reset.no:IsShown()), "true false false false", "at rest: the button alone")
    Hover(button)
    Equal(Note(), WHITE .. "Reset all settings|r  Every option goes back to how it started, your name and BattleTag boxes are emptied, "
        .. "and private mode turns off. Your key binding stays.", "its note says what it does")
end
-- It asks first, inside the window.
local function Asking()
    return tostring(reset.button:IsShown()) .. " " .. tostring(reset.ask:IsShown()) .. " " .. tostring(reset.yes:IsShown()) .. " "
        .. tostring(reset.no:IsShown())
end
P:Set("gold", true)
reset.button:Click()
Equal(Asking(), "false true true true", "a click: the question, Reset and Cancel")
Equal(H.Text(reset.ask) .. " / " .. H.Text(reset.yes.label) .. " / " .. H.Text(reset.no.label), "Are you sure? / Reset / Cancel",
    "short and plain")
Equal(S[reset.yes].backdrop[1] .. " " .. S[reset.no].backdrop[1], P.ACCENT[1] .. " " .. P.Theme.C.button[1],
    "Reset in the accent, Cancel plain")
-- A double click on the button: its second click, a moment later, does nothing.
reset.yes:Click()
Equal(Asking() .. " " .. tostring(P:Get("gold")), "false true true true true", "Reset straight after the question: ignored")
H.clock = H.clock + .3
reset.yes:Click()
Equal(Asking() .. " " .. tostring(P:Get("gold")), "false true true true true", "still ignored a moment later")
H.clock = H.clock + 1
Equal(Note(), CREDIT, "the button's note gone with it")
Hover(reset.yes)
True(Note():find(WHITE .. "Reset|r  Every option goes back to how it started", 1, true), "Reset's note says what it does")
Leave(reset.yes)
Hover(reset.no)
Equal(Note(), WHITE .. "Cancel|r  Keeps your settings as they are.", "and Cancel's")
Leave(reset.no)
Equal(P:Get("gold"), true, "nothing reset yet")
P:Set("eye", false)
Equal(Asking(), "false true true true", "a setting changing meanwhile doesn't take the question away")
P:Set("eye", true)
reset.no:Click()
Equal(Asking(), "true false false false", "Cancel: the button back")
Equal(P:Get("gold"), true, "and nothing reset")
reset.button:Click()
w:Select("overview")
Equal(Asking(), "false true true true", "choosing the same page again keeps the question")
w:Select("chat")
w:Select("overview")
Equal(Asking(), "true false false false", "leaving the page: the button back")
reset.button:Click()
w:Hide()
P.ShowWindow()
Equal(tostring(w.selected) .. " " .. Asking(), "overview true false false false", "closing the window: the button back")
Equal(P:Get("gold"), true, "and still nothing reset")
Equal(#H.printed, 0, "and nothing said")
-- Reset: everything back as it started, every control showing it.
do
    P:SetPrivate(true)
    w.modes.buttons.always:Click()
    w.styles.buttons.hidden:Click()
    w.colours.buttons.white:Click()
    P:Set("myName", "Shade")
    P:Set("myTag", "Fake#9999")
    P:Set("eye", false)
    w.minimapRow:Click()
    P:Set("chatNames", false)
    P:Set("publicChannels", true)
    P:Set("instChat", "chat")
    P:Set("worldMap", "hide")
    -- A name half typed on the Overview: saved first, then emptied with the rest.
    w:Select("overview")
    box:SetFocus()
    box:SetText("Half")
    Equal(H.Text(w.status), "Private mode: |cffb07df0on|r", "private mode on before")
    reset.button:Click()
    H.clock = H.clock + 1
    reset.yes:Click()
    Equal(P:Private(), false, "Reset: private mode off")
    Equal(Asking(), "true false false false", "the button back")
    Equal(box:HasFocus(), false, "the name box let go")
    local wrong = {}
    for _, key in ipairs(P.KEYS) do
        if P:Get(key) ~= P.DEFAULTS[key] then wrong[#wrong + 1] = key end
        local control = w.controls[key]
        if P.ROWS[key].options then
            if not control.options.buttons[P.DEFAULTS[key]].selected then wrong[#wrong + 1] = key .. "'s choice" end
        elseif control:GetChecked() ~= P.DEFAULTS[key] then
            wrong[#wrong + 1] = key .. "'s tick"
        end
    end
    Equal(table.concat(wrong, " "), "", "every setting and every row back to how it started")
    Equal(P:Get("mode") .. " " .. P:Get("nameStyle") .. " " .. P:Get("myColour") .. " [" .. P:Get("myName") .. "][" .. P:Get("myTag")
        .. "] " .. tostring(P:Get("eye")), "key class game [][] true", "the Overview's settings too")
    Equal(tostring(w.modes.buttons.key.selected) .. " " .. tostring(w.styles.buttons.class.selected) .. " "
        .. tostring(w.colours.buttons.game.selected) .. " " .. tostring(w.eyeRow:GetChecked()) .. " " .. tostring(w.modeTag:IsShown()),
        "true true true true false", "and its controls")
    Equal(tostring(P:Get("minimap")) .. " " .. tostring(w.minimapRow:GetChecked()) .. " " .. tostring(P.MinimapButton:Button():IsShown()),
        "true true true", "the minimap button back, its tick ticked")
    Equal(box:GetText() .. "|" .. tagBox:GetText() .. "|" .. tostring(box.placeholder:IsShown()) .. " "
        .. tostring(tagBox.placeholder:IsShown()), "||true true", "both boxes emptied, their hints back")
    Equal(H.Text(w.status) .. " / " .. H.Text(w.privateButton.label), "Private mode: off / Turn private mode on", "saying it's off")
    Equal(H.Text(view.target) .. " / " .. Chat(2), "Brannoc Stonehelm / |cffffc0c0[1. General - Stormwind]|r |cffe8e6e1[Merrin "
        .. "Lightfoot]|r|cffffc0c0: LF tank for Stockades|r", "the preview with real names again")
    Equal(tostring(view.eye:IsShown()) .. " " .. tostring(P.Eye:Frame() ~= nil and P.Eye:Frame():IsShown()), "false false",
        "no eye in the preview or on screen")
    local left = {}
    for key in pairs(ForeverEnhancedPrivacyDB) do left[#left + 1] = key end
    table.sort(left)
    Equal(table.concat(left, " "), "cvarBackup wasOn", "nothing else left saved")
    Equal(table.concat(H.printed, " | "), "|cffb07df0Forever Enhanced Privacy|r: Settings reset.", "one line in chat")
    H.Clear()
end

-- Closing, Escape and Options > AddOns -------------------------------------------------------------------------------------

w.close:Click()
Equal(w:IsShown(), false, "the close button")
local open
for _, obj in ipairs(H.objects) do
    if S[obj].kind == "Button" and S[obj].text == "Open settings" and H.Under(obj, H.category.canvas) then open = obj end
end
True(open, "Options > AddOns has an Open settings button")
open:Click()
Equal(w:IsShown(), true, "which opens the window")
SlashCmdList.FEPRIVACY("")
Equal(w:IsShown(), false, "/privacy closes it")
P.ShowWindow()
P.ShowWindow()
Equal(w:IsShown(), true, "opening twice is fine")
Equal(#UISpecialFrames, 1, "and listed for Escape once")

-- Nothing shown has an em dash; nothing of Blizzard's was touched ----------------------------------------------------------

do
    local dashes = {}
    for _, obj in ipairs(H.objects) do
        local text = S[obj].text
        if type(text) == "string" and text:find(string.char(226, 128, 148), 1, true) then dashes[#dashes + 1] = text end
    end
    Equal(table.concat(dashes, " | "), "", "no em dash anywhere shown")
end
Equal(H.Writes(), 0, "nothing of Blizzard's touched")
Equal(H.Problems(), "", "nothing wrong")

io.stdout:write("TestWindow: " .. H.checks .. " checks passed\n")
