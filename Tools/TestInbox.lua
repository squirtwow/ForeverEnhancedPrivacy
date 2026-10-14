-- The whisper inbox against a mock game (Tools/Harness.lua): nothing listened
-- for until private mode has been on; a whisper kept only while Hide whispers
-- takes it out of chat and its own tick is on (never a GM's, one the game
-- shows nowhere, your own, or your whispers out); chat told only how many,
-- one line for a burst and at most one a minute, never while the window is
-- open, never a name; locked whispers (secrets) kept as "(hidden)" with
-- nothing secret read or saved, and not during a screenshot-only moment;
-- Battle.net names held this session only, never saved; at most 50, read ones
-- dropped first; the saved list checked at login and kept over a /reload and
-- Reset all settings; the window (rows newest first, real names, the off
-- stream warning, select and reply the way the chat box sends, lockdown,
-- delete, mark all read, clear all after asking, Escape, screenshots); the
-- minimap button's and the eye's counts, its hover box and shift-click; and
-- Blizzard's frames untouched.
-- Run with fengari: Tools/TestInbox.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local P, Inbox
local sent, delays, shift, lockdown, failSend
local NOW = 1700000000 -- the harness's time()
local PREFIX = "|cffb07df0Forever Enhanced Privacy|r: "

-- The game's side for this test: sending whispers (recorded), the chat
-- lockdown, the shift key, the clock's dates, and timers with their delays.
-- opts.player: who you log in as (another character on the account).
local function Fresh(saved, opts)
    H.Environment()
    for key, value in pairs(opts and opts.player or {}) do H.units.player[key] = value end
    sent, delays, shift, lockdown, failSend = {}, {}, false, false, false
    _G.date = function(format, at) return os.date(format, at or NOW) end
    _G.C_ChatInfo = {
        SendChatMessage = function(text, kind, language, target)
            if failSend then error("blocked") end
            sent[#sent + 1] = table.concat({ text, kind, tostring(language), tostring(target) }, "|")
        end,
        InChatMessagingLockdown = function() return lockdown end,
    }
    _G.C_BattleNet = { SendWhisper = function(id, text)
        sent[#sent + 1] = "bn|" .. tostring(id) .. "|" .. text
        return true
    end }
    _G.IsShiftKeyDown = function() return shift end
    _G.C_Timer.After = function(delay, fn)
        delays[#delays + 1] = delay
        H.timers[#H.timers + 1] = fn
    end
    H.units.target = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
        guid = "Player-1-0002" }
    H.units.party1 = { name = "Merrin", surname = "Lightfoot", class = "Priest", classFile = "PRIEST", player = true,
        guid = "Player-1-0003" }
    P = H.Load(saved, opts)
    Inbox = P.Inbox
    return P
end
local DB = function() return ForeverEnhancedPrivacyDB end

-- A whisper as the game sends it: text, sender, language, channel, target,
-- flags (6th), zone, channel index, base name, language id, line id, GUID
-- (12th), account id (13th), mobile, subtitle, hidden from chat (16th).
local line = 0
local function Values(text, sender, guid, flags, id, unseen)
    line = line + 1
    return text, sender, "Common", "", "", flags or "", 0, 0, "", 0, line, guid or "", id or 0, false, false, unseen or false
end
local function Whisper(text, sender, guid, flags, unseen)
    H.Fire("CHAT_MSG_WHISPER", Values(text, sender, guid, flags, 0, unseen))
end
local function Brannoc(text) Whisper(text or "on my way", "Brannoc Stonehelm", "Player-1-0002") end
local function Friend(text, id) H.Fire("CHAT_MSG_BN_WHISPER", Values(text or "u there?", "|Kq1|k", "", "", id or 101)) end
local function Said() return table.concat(H.printed, " | ") end
local function Kept(i) return Inbox:Entries()[i] end
local function Watched()
    for _, frame in ipairs(H.frames) do
        if S[frame].events.CHAT_MSG_WHISPER and S[frame].events.CHAT_MSG_BN_WHISPER then return true end
    end
    return false
end
-- What's saved, as text: every key and value of every kept whisper.
local function Saved()
    local parts = {}
    for i, entry in ipairs(DB().inbox or {}) do
        local keys = {}
        for key, value in pairs(entry) do keys[#keys + 1] = key .. "=" .. tostring(value) end
        table.sort(keys)
        parts[#parts + 1] = i .. ":" .. table.concat(keys, ",")
    end
    return table.concat(parts, " ")
end

-- Nothing until private mode has been on ---------------------------------------------------------------

Fresh(nil)
Equal(Inbox:Count() .. " " .. Inbox:Unread() .. " " .. tostring(DB().inbox), "0 0 nil", "nothing kept, nothing saved")
Equal(Watched(), false, "whispers not even listened for before private mode is on")
Equal(Inbox:Frame(), nil, "no window until it's asked for")
P:Set("whispers", true)
Brannoc()
Equal(Inbox:Count(), 0, "a whisper with private mode off: left to chat")
P:SetPrivate(true)
Equal(Watched(), true, "private mode on: listened for")
P:SetPrivate(false)
Brannoc()
Equal(Inbox:Count() .. " " .. tostring(DB().inbox), "0 nil", "off again: still left to chat, nothing kept")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- Kept while Hide whispers hides it ------------------------------------------------------------------------

Fresh(nil)
P:SetPrivate(true)
Brannoc()
Equal(Inbox:Count(), 0, "Hide whispers unticked (as it starts): the whisper stays in chat, so nothing is kept")
P:Set("whispers", true)
Equal(H.Chat("CHAT_MSG_WHISPER", Values("on my way", "Brannoc Stonehelm", "Player-1-0002")), true, "Hide whispers takes it out of chat")
Brannoc()
Equal(Inbox:Count() .. " " .. Inbox:Unread(), "1 1", "and the inbox keeps it, unread")
do
    local entry = Kept(1)
    Equal(table.concat({ entry.from, entry.class, entry.text, entry.at, tostring(entry.read), tostring(entry.bn), entry.to }, " / "),
        "Brannoc Stonehelm / WARRIOR / on my way / " .. NOW .. " / nil / nil / Zriel Gustbellow",
        "who (and their class, by GUID), what, when, and the character it came to")
    Equal(rawequal(DB().inbox[1], entry), true, "in the saved settings, so a /reload keeps it")
end
Equal(#H.printed .. " " .. #delays .. " " .. tostring(delays[1]), "0 1 2", "chat waits a moment, for a burst")
Whisper("inv pls", "Merrin Lightfoot", "Player-1-0003")
Whisper("hello", "Kaelis Dawnbrook", "Player-1-0009")
Equal(#delays, 1, "a burst: still one line waiting")
H.RunTimers()
Equal(Said(), PREFIX .. "3 whispers waiting. Type /privacy inbox to read them.", "one line, a count and how to read them")
for _, name in ipairs({ "Brannoc", "Merrin", "Kaelis", "on my way", "inv" }) do
    True(not Said():find(name, 1, true), "chat never shows who or what: no " .. name)
end
Equal(Kept(1).text .. " / " .. Kept(2).text .. " / " .. Kept(3).text, "hello / inv pls / on my way", "newest first")
Equal(tostring(Kept(2).class) .. " " .. tostring(Kept(1).class), "PRIEST nil", "a class the game won't say is left out")
H.Clear()
-- More soon after: one more line, a minute after the last.
H.clock = H.clock + 10
Brannoc("still there?")
Equal(#delays .. " " .. delays[2], "2 50", "the next line waits till a minute after the last")
Brannoc("hello?")
Equal(#delays, 2, "whispers meanwhile join it")
H.clock = H.clock + 50
H.RunTimers()
Equal(Said(), PREFIX .. "5 whispers waiting. Type /privacy inbox to read them.", "then says how many wait now")
H.Clear()
-- Read before the line is due: nothing said.
H.clock = H.clock + 100
Brannoc("last one")
Inbox:MarkAllRead()
H.RunTimers()
Equal(#H.printed .. " " .. Inbox:Unread(), "0 0", "all read meanwhile: nothing to say")
-- One whisper: the singular.
Brannoc("one more")
H.clock = H.clock + 100
H.RunTimers()
Equal(Said(), PREFIX .. "1 whisper waiting. Type /privacy inbox to read it.", "one whisper, said so")
H.Clear()
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- What's never kept -------------------------------------------------------------------------------------------

Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
P:Set("whisperInbox", false)
Brannoc()
Equal(tostring(H.Chat("CHAT_MSG_WHISPER", Values("x", "Brannoc Stonehelm"))) .. " " .. Inbox:Count(), "true 0",
    "its tick off: hidden from chat as before, nothing kept")
P:Set("whisperInbox", true)
Whisper("a GM here", "Brannoc Stonehelm", "Player-1-0002", "GM")
Equal(Inbox:Count(), 0, "a GM's whisper: the game shows it in its own window, past any filter, so it isn't hidden or kept")
Whisper("letterbox", "Brannoc Stonehelm", "Player-1-0002", "", true)
Equal(Inbox:Count(), 0, "a whisper the game shows nowhere: not kept")
Whisper("note to self", "Zriel Gustbellow", "Player-1-0001")
Whisper("note to self", "Zriel", "Player-1-0001")
Whisper("note to self", "Someone Else", "Player-1-0001")
Equal(Inbox:Count(), 0, "your own whispers (by name or GUID): not kept")
for _, event in ipairs({ "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_AFK", "CHAT_MSG_DND" }) do
    H.Fire(event, Values("brb", "Brannoc Stonehelm", "Player-1-0002"))
    Equal(Inbox:Count(), 0, event .. ": not kept (your whispers out, and away replies)")
end
Whisper("away", "Brannoc Stonehelm", "Player-1-0002", "AFK")
Equal(Inbox:Count(), 1, "someone who's away still whispered you: kept")
Equal(#H.printed .. " " .. H.Problems(), "0 ", "nothing said at once, nothing wrong")

-- Locked whispers (dungeons, raids, battlegrounds) -------------------------------------------------------------

Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
H.Fire("CHAT_MSG_WHISPER", H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET,
    H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET, H.SECRET)
Equal(Inbox:Count() .. " " .. Inbox:Unread(), "1 1", "a locked whisper: kept, so you know one came")
Equal(Saved(), "1:at=" .. NOW .. ",to=Zriel Gustbellow", "only its time and your character: nothing secret saved")
Equal(Inbox:Sender(Kept(1)) .. " / " .. tostring(Inbox:Target(Kept(1))), "(hidden) / nil", "who is \"(hidden)\", with no reply")
Inbox:Open()
Inbox:Rows()[1]:Click()
do
    local reply = Inbox:Frame().replyTo
    Equal(H.Text(reply) .. " " .. tostring(Inbox:Frame().box:IsShown()), "The game hid who sent this one, so it can't be answered "
        .. "here. false", "the window says why, no reply box")
    True(reply:GetStringWidth() <= S[reply].width, "and that fits its one line")
end
Inbox:Close()
Equal(H.Problems(), "", "no secret read, compared or joined")
H.Fire("CHAT_MSG_WHISPER", H.SECRET, "Brannoc Stonehelm", "Common", "", "", "", 0, 0, "", 0, 7, "Player-1-0002", 0, false, false, false)
Equal(table.concat({ Kept(1).from, tostring(Kept(1).text), Kept(1).class }, " / "), "Brannoc Stonehelm / nil / WARRIOR",
    "only the words locked: who is kept, the words \"(hidden)\"")
-- Private mode on only for a screenshot: a locked line stays in chat then (Chat takes nothing out), so it isn't kept.
P:SetPrivate(false)
P:Set("mode", "shots")
H.Screenshot("start")
Equal(P:ShotOnly(), true, "a screenshot-only moment")
H.Fire("CHAT_MSG_WHISPER", H.SECRET, H.SECRET, "", "", "", "", 0, 0, "", 0, 8, H.SECRET, 0, false, false, false)
Equal(Inbox:Count(), 2, "a locked whisper then: left in chat, not kept")
Brannoc("during the shot")
Equal(Inbox:Count(), 3, "a plain one is hidden by the filter even then: kept")
P:Set("cleanOld", true)
H.Fire("CHAT_MSG_WHISPER", H.SECRET, H.SECRET, "", "", "", "", 0, 0, "", 0, 9, H.SECRET, 0, false, false, false)
Equal(Inbox:Count(), 4, "with Clean lines already in chat, Chat takes it out then too: kept")
H.Screenshot("done")
Equal(H.Problems(), "", "nothing secret touched")

-- Battle.net whispers -----------------------------------------------------------------------------------------

Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
Friend("u there?", 101)
Equal(Inbox:Count(), 1, "a Battle.net whisper: kept")
Equal(tostring(Kept(1).bn) .. " " .. tostring(Kept(1).from) .. " " .. Kept(1).text, "true nil u there?", "a friend, no name saved")
Equal(Saved(), "1:at=" .. NOW .. ",bn=true,text=u there?", "never their name (a protected string) or account id in the saved settings")
Equal(Inbox:Sender(Kept(1)) .. " " .. tostring(Inbox:Target(Kept(1))), "|Kq1|k 101", "this session: their name shown, their account for a reply")
Inbox:Open()
local frame = Inbox:Frame()
local rows = Inbox:Rows()
Equal(H.Text(rows[1].from) .. " [" .. H.Text(rows[1].tag) .. "]", "Battle.net friend []", "private: a friend isn't named until clicked")
rows[1]:Click()
Equal(H.Text(rows[1].from) .. " " .. H.Text(rows[1].tag), "|Kq1|k battle.net", "clicked: the game's name code (it draws the name) and a quiet tag")
Equal(H.Text(frame.replyTo) .. " " .. tostring(frame.box:IsShown()), "Reply to |Kq1|k true", "a reply to them")
True(frame.replyTo:GetStringWidth() <= S[frame.replyTo].width, "that fits its line")
frame.box:SetText("  yes!  ")
H.Script(frame.box, "OnEnterPressed")
Equal(table.concat(sent, " ") .. " / " .. H.Text(frame.status), "bn|101|yes! / Sent.", "sent to their account, as the chat box sends one")
-- After a /reload: their name and account are gone, the whisper stays.
local copy = { inbox = { { at = NOW, bn = true, text = "u there?" } } }
Fresh(copy, { reload = true })
Equal(Inbox:Count() .. " " .. Inbox:Sender(Kept(1)) .. " " .. tostring(Inbox:Target(Kept(1))), "1 Battle.net friend nil",
    "after a /reload: \"Battle.net friend\", and no reply")
Inbox:Open()
frame = Inbox:Frame()
Equal(H.Text(Inbox:Rows()[1].from) .. " [" .. H.Text(Inbox:Rows()[1].tag) .. "]", "Battle.net friend []",
    "the row: \"Battle.net friend\", no second \"battle.net\" after it")
Inbox:Rows()[1]:Click()
Equal(H.Text(frame.replyTo) .. " " .. tostring(frame.box:IsShown()), "After a /reload, reply to this one from your friends list. false",
    "says how to answer it, no reply box")
True(frame.replyTo:GetStringWidth() <= S[frame.replyTo].width, "and that fits its one line (it doesn't wrap)")
Equal(H.Problems(), "", "nothing wrong")

-- At most 50, read ones dropped first --------------------------------------------------------------------------

Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
for i = 1, 50 do Brannoc("w" .. i) end
Equal(Inbox:Count(), 50, "50 kept")
DB().inbox[3].read, DB().inbox[7].read = true, true
Brannoc("w51")
Equal(Inbox:Count() .. " " .. DB().inbox[1].text .. " " .. DB().inbox[3].text .. " " .. DB().inbox[50].text, "50 w1 w4 w51",
    "one more: the oldest read one goes, the unread kept")
Brannoc("w52")
Brannoc("w53")
Equal(Inbox:Count() .. " " .. DB().inbox[1].text .. " " .. DB().inbox[50].text, "50 w2 w53",
    "no read ones left: the oldest goes")
H.Clear()

-- The saved list, checked at login ------------------------------------------------------------------------------

Fresh({ inbox = {
    { at = 100, from = "Brannoc Stonehelm", class = "WARRIOR", text = "hi", to = "Zriel Gustbellow", extra = "x" },
    "nope",
    { from = "No Time", to = "Zriel Gustbellow" },
    { at = 0 / 0, text = "nan", to = "Zriel Gustbellow" },
    { at = 200, from = "|Kq9|k", class = "warrior", text = string.rep("y", 2000), to = "Zriel Gustbellow" },
    { at = 300, bn = true, from = "|Kq2|k", class = "MAGE", text = "bn", to = "Zriel Gustbellow" },
    { at = 400.7, bn = "yes", read = "no", text = 5, to = "Tamsin Oakvale" },
    { at = 500, from = "Merrin Lightfoot", text = "seen it", read = true, to = "Zriel Gustbellow" },
    { at = 600, from = "Merrin Lightfoot", text = "whose?" },
    { at = 700, from = "Merrin Lightfoot", text = "bad name", to = "|Kq3|k" },
} })
Equal(Saved(), "1:at=100,class=WARRIOR,from=Brannoc Stonehelm,text=hi,to=Zriel Gustbellow 2:at=200,to=Zriel Gustbellow "
    .. "3:at=300,bn=true,text=bn 4:at=400,to=Tamsin Oakvale", "bad ones dropped; a name code, a bad class, too long a text, a "
    .. "friend's name or character, anything else: left out")
True(not Saved():find("seen it", 1, true), "one already read: gone at login (kept until read)")
True(not Saved():find("whose?", 1, true) and not Saved():find("bad name", 1, true),
    "a player's whisper with no character, or a bad one: dropped (it couldn't be shown anywhere safely)")
Equal(Inbox:Count() .. " " .. Inbox:Unread() .. " " .. H.Problems(), "3 3 ", "this character's and the Battle.net one counted")
do
    local many = {}
    for i = 1, 60 do many[i] = { at = i, text = "w" .. i, to = "Zriel Gustbellow" } end
    Fresh({ inbox = many })
    Equal(Inbox:Count() .. " " .. DB().inbox[1].text, "50 w11", "too many saved: cut to 50 at login")
    H.RunTimers()
    Equal(Said(), PREFIX .. "50 whispers waiting. Type /privacy inbox to read them.", "and whispers still waiting are said once")
    H.Clear()
end
-- Kept over a /reload and a reset.
Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
Brannoc()
H.RunTimers()
H.Clear()
local saved = DB()
Fresh(saved, { reload = true })
Equal(Inbox:Count() .. " " .. Kept(1).from .. " " .. tostring(P:Private()), "1 Brannoc Stonehelm true", "a /reload keeps it")
H.RunTimers()
Equal(Said(), PREFIX .. "1 whisper waiting. Type /privacy inbox to read it.", "and says it's waiting")
H.Clear()
P:Reset()
Equal(Inbox:Count() .. " " .. Kept(1).text .. " " .. tostring(P:Get("whispers")), "1 on my way false", "Reset all settings keeps it")
H.Clear()
-- Read: it lasts the session, then goes at the next login or /reload.
Inbox:Select(Kept(1))
Equal(Inbox:Count() .. " " .. Inbox:Unread() .. " " .. tostring(DB().inbox[1].read), "1 0 true", "read: still there this session")
saved = DB()
Fresh(saved, { reload = true })
Equal(Inbox:Count() .. " " .. #DB().inbox, "0 0", "a /reload: the read one gone from the saved settings")
H.RunTimers()
Equal(#H.printed, 0, "and nothing to say")

-- Each character its own -----------------------------------------------------------------------------------------------
-- The saved settings are the whole account's: a player's whisper is kept with
-- the character it came to and only shown, counted and answered there (a
-- reply from another character would tie the two together). A Battle.net
-- whisper came to the account, so it shows on any.

local TAMSIN = { name = "Tamsin", surname = "Oakvale", class = "Mage", classFile = "MAGE", guid = "Player-1-0005" }
Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
Brannoc("for Zriel")
H.RunTimers()
H.Clear()
saved = DB()
Fresh(saved, { player = TAMSIN })
local zriels = DB().inbox[1]
H.RunTimers()
Equal(table.concat({ Inbox:Count(), Inbox:Unread(), #Inbox:Entries(), #H.printed }, " "), "0 0 0 0",
    "on another character: not counted, not listed, nothing said in chat")
Equal(tostring(P.MinimapButton:Badge()) .. " " .. tostring(P.Eye:Badge()), "nil nil", "no count on the minimap button or the eye")
Equal(#DB().inbox .. " " .. zriels.from .. " " .. zriels.to, "1 Brannoc Stonehelm Zriel Gustbellow", "still kept, for Zriel")
Equal(tostring(Inbox:Target(zriels)) .. " " .. tostring(Inbox:Reply(zriels, "hello")) .. " " .. #sent, "nil nil 0",
    "never answered from here: nothing sent")
Inbox:Select(zriels)
Inbox:MarkAllRead()
Equal(tostring(Inbox:Selected()) .. " " .. tostring(zriels.read) .. " " .. tostring(Inbox:Delete(zriels)), "nil nil false",
    "never chosen, marked read or deleted from here")
Inbox:Clear()
Equal(#DB().inbox, 1, "Clear all leaves another character's whispers alone")
Inbox:Open()
frame = Inbox:Frame()
Equal(tostring(Inbox:Rows()[1]) .. " " .. tostring(frame.empty:IsShown()) .. " [" .. H.Text(frame.count) .. "]", "nil true []",
    "the window: no row for it, the empty note")
-- This character's own whisper, and a Battle.net one, show here.
P:Set("whispers", true)
P:SetPrivate(true)
Whisper("for Tamsin", "Merrin Lightfoot", "Player-1-0003")
Friend("bn here", 102)
Equal(Inbox:Count() .. " " .. Kept(1).text .. " / " .. Kept(2).text .. " " .. Kept(2).to, "2 bn here / for Tamsin Tamsin Oakvale",
    "its own whisper and a Battle.net one show")
Inbox:Close()
H.RunTimers()
H.Clear()
-- Back on Zriel: the Battle.net one too (it came to the account), never Tamsin's.
saved = DB()
Fresh(saved)
Equal(Inbox:Count() .. " " .. Inbox:Unread() .. " " .. Kept(1).text .. " / " .. Kept(2).text, "2 2 bn here / for Zriel",
    "back on Zriel: Zriel's whisper and the Battle.net one")
H.RunTimers()
Equal(Said(), PREFIX .. "2 whispers waiting. Type /privacy inbox to read them.", "and chat counts only those")
H.Clear()
Inbox:Clear()
Equal(#DB().inbox .. " " .. DB().inbox[1].to, "1 Tamsin Oakvale", "Clear all here: Tamsin's still waits for Tamsin")
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")
-- Your name is asked at login: a whisper later, while the game won't say it
-- (a dungeon), still gets your character.
Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
H.units.player.secretName = true
Brannoc("in a dungeon")
Equal(tostring(DB().inbox[1].to) .. " " .. H.Problems(), "Zriel Gustbellow ", "known since login, so the whisper has it")
H.Clear()
-- The game not saying who you are yet (it plainly does at login, so a corner
-- case): kept as this character's for the session, given its name once the
-- game says it, never shown on another.
Fresh(nil, { player = { secretName = true } })
P:Set("whispers", true)
P:SetPrivate(true)
Brannoc("before your name")
Equal(Inbox:Count() .. " " .. Inbox:Unread() .. " " .. tostring(DB().inbox[1].to), "1 1 nil",
    "kept and shown this session, no character saved yet")
H.units.player.secretName = nil
Equal(Inbox:Unread() .. " " .. tostring(DB().inbox[1].to), "1 Zriel Gustbellow", "the game says your name: the whisper gets it")
saved = DB()
Fresh(saved, { reload = true })
Equal(Inbox:Count() .. " " .. Kept(1).text, "1 before your name", "so a /reload keeps it")
H.Clear()
Fresh(nil, { player = { secretName = true } })
P:Set("whispers", true)
P:SetPrivate(true)
Brannoc("never named")
saved = DB()
Fresh(saved, { reload = true, player = TAMSIN })
Equal(Inbox:Count() .. " " .. #DB().inbox, "0 0", "never said all session: dropped at the next login, never shown anywhere")
Equal(H.Problems(), "", "nothing secret touched")
H.Clear()

-- The window ----------------------------------------------------------------------------------------------------------

Fresh(nil)
P:Set("whispers", true)
P:SetPrivate(true)
Brannoc("on my way")
H.clock = H.clock + 1
Whisper("can you tank Stockades tonight? we need one more and you know the place well", "Merrin Lightfoot", "Player-1-0003")
SlashCmdList.FEPRIVACY("inbox")
frame = Inbox:Frame()
True(frame and frame:IsShown(), "/privacy inbox opens it")
Equal(rawequal(ForeverEnhancedPrivacyInbox, frame) and S[frame].strata .. " " .. S[frame].width .. "x" .. S[frame].height,
    "DIALOG 440x480", "a window of its own, sized as it's made")
Equal(UISpecialFrames[#UISpecialFrames], "ForeverEnhancedPrivacyInbox", "Escape closes it, through the game's own list")
Equal(H.Text(frame.title) .. " / " .. H.Text(frame.warning),
    "Whisper inbox / Names stay hidden while private mode is on. Click a whisper to see who sent it.",
    "its name, and that names stay hidden while private")
Equal(H.Text(frame.count), "2 unread", "how many are unread")
rows = Inbox:Rows()
Equal(H.Text(rows[1].from) .. " / " .. H.Text(rows[1].text) .. " / " .. H.Text(rows[2].from), "Priest / can you tank Stockades "
    .. "tonight? we need one more and you know the place well / Warrior", "newest first, the words, and nobody named while private")
P:Set("nameStyle", "hidden")
Equal(H.Text(rows[1].from) .. " / " .. H.Text(rows[2].from), "Player / Player", "under Hidden: Player, never a blank")
P:Set("nameStyle", "class")
-- Private off: real names, and the window says so.
P:SetPrivate(false)
Equal(H.Text(rows[1].from) .. " / " .. H.Text(rows[2].from) .. " / " .. H.Text(frame.warning),
    "Merrin Lightfoot / Brannoc Stonehelm / Real names show here, so open it off stream.", "private off: real names")
P:SetPrivate(true)
Equal(H.Text(rows[1].from) .. " / " .. H.Text(rows[2].from), "Priest / Warrior", "private again: hidden again")
Equal(H.Text(rows[1].when) .. " / " .. H.Text(rows[1].tag), os.date("%H:%M", NOW) .. " / ", "today: the time alone; no tag for a player")
do
    local c = S[rows[2].from].colour
    Equal(("%.2f %.2f %.2f"):format(c[1], c[2], c[3]), "0.78 0.61 0.43", "a sender in their class colour")
    Equal(tostring(rows[1].mark:IsShown()) .. " " .. tostring(rows[2].mark:IsShown()), "true true", "unread ones marked")
    True(S[rows[1]].height > S[rows[2]].height, "a long whisper wraps, its row taller")
    Equal(S[rows[2]].points[1][3], -(S[rows[1]].height + 6), "rows one under another")
    True(S[rows[1].text].width + 12 <= S[rows[1]].width, "the words inside the row")
    Equal(frame.empty:IsShown(), false, "no empty note")
    Equal(tostring(frame.box:IsShown()) .. " / " .. H.Text(frame.replyTo), "false / Click a whisper to reply to it.",
        "no reply box till one is clicked")
end
-- Click one: read, and the reply box ready.
rows[2]:Click()
Equal(tostring(Inbox:Selected() == Kept(2)) .. " " .. tostring(Kept(2).read) .. " " .. Inbox:Unread() .. " " .. H.Text(frame.count),
    "true true 1 1 unread", "clicked: chosen and read")
Equal(tostring(rows[2].mark:IsShown()) .. " " .. table.concat(S[rows[2]].border, " ", 1, 3), "false " .. table.concat(P.ACCENT, " "),
    "its mark gone, its edge in the accent")
Equal(H.Text(frame.replyTo) .. " / " .. tostring(frame.box:IsShown()) .. " " .. tostring(frame.box:HasFocus()),
    "Reply to Brannoc Stonehelm / true true", "the reply box shows, ready to type")
Equal(H.Text(rows[2].from) .. " / " .. H.Text(rows[1].from), "Brannoc Stonehelm / Priest", "only the clicked one is named")
frame:Hide()
Inbox:Open()
Equal(H.Text(rows[2].from) .. " " .. tostring(Inbox:Selected()) .. " / " .. H.Text(frame.replyTo), "Warrior nil / Click a whisper to reply to it.",
    "closed and opened again: nobody named, nothing chosen")
rows[2]:Click()
frame.box:SetText("   ")
H.Script(frame.box, "OnEnterPressed")
Equal(#sent, 0, "nothing typed: nothing sent")
frame.box:SetText("omw, 2 min")
H.Script(frame.box, "OnEnterPressed")
Equal(table.concat(sent, " "), "omw, 2 min|WHISPER|nil|Brannoc Stonehelm", "sent as the chat box sends a whisper, to who sent it")
Equal(H.Text(frame.status) .. " [" .. frame.box:GetText() .. "] " .. tostring(frame.box:HasFocus()), "Sent. [] false",
    "said so, the box emptied and let go")
-- The game's chat lockdown: the addon may not send.
lockdown = true
frame.box:SetText("again")
H.Script(frame.box, "OnEnterPressed")
Equal(#sent .. " " .. H.Text(frame.status) .. " [" .. frame.box:GetText() .. "]", "1 The game won't let addons send whispers here. Reply "
    .. "from chat. [again]", "locked: nothing sent, says why, the words kept")
lockdown = false
failSend = true
H.Script(frame.box, "OnEnterPressed")
Equal(#sent .. " " .. H.Text(frame.status), "1 That whisper couldn't be sent. Reply from chat.", "a send the game refuses: said so")
failSend = false
-- Escape in the box only lets go of it.
frame.box:SetFocus()
H.Script(frame.box, "OnEscapePressed")
Equal(tostring(frame.box:HasFocus()) .. " " .. tostring(frame:IsShown()), "false true", "Escape in the box: lets go, the window stays")
-- Mark all read, delete, clear all.
H.Script(frame.bar.read, "OnClick")
Equal(Inbox:Unread() .. " [" .. H.Text(frame.count) .. "] " .. tostring(rows[1].mark:IsShown()), "0 [] false", "Mark all read")
Equal(tostring(Inbox:Delete(nil)), "false", "nothing to delete")
Inbox:Select(Kept(1))
H.Script(frame.bar.delete, "OnClick")
Equal(Inbox:Count() .. " " .. Kept(1).from .. " " .. tostring(Inbox:Selected()), "1 Brannoc Stonehelm nil", "Delete: the chosen one goes")
Equal(tostring(rows[2]:IsShown()) .. " " .. H.Text(frame.replyTo), "false Click a whisper to reply to it.", "its row gone, no reply")
H.Script(frame.bar.delete, "OnClick")
Equal(Inbox:Count() .. " " .. H.Text(frame.status), "1 Click a whisper first, then Delete.", "nothing chosen: says how")
local function Asking()
    local bar = frame.bar
    return tostring(bar.clear:IsShown()) .. " " .. tostring(bar.ask:IsShown()) .. " " .. tostring(bar.yes:IsShown()) .. " "
        .. tostring(bar.no:IsShown())
end
Equal(Asking(), "true false false false", "Clear all, not asking")
H.Script(frame.bar.clear, "OnClick")
Equal(Asking() .. " " .. H.Text(frame.bar.ask), "false true true true Clear every whisper?", "Clear all asks first")
H.Script(frame.bar.yes, "OnClick")
Equal(Inbox:Count() .. " " .. Asking(), "1 false true true true", "a double click can't clear")
H.Script(frame.bar.no, "OnClick")
Equal(Inbox:Count() .. " " .. Asking(), "1 true false false false", "Cancel: kept")
H.Script(frame.bar.clear, "OnClick")
H.clock = H.clock + 1
H.Script(frame.bar.yes, "OnClick")
Equal(Inbox:Count() .. " " .. Asking() .. " " .. tostring(frame.empty:IsShown()), "0 true false false false true",
    "Clear: every whisper gone, the empty note showing")
Equal(H.Text(frame.empty), "No whispers kept for this character. While private mode hides whispers from chat, they wait here. Read "
    .. "ones go at your next login or /reload.", "what it says")
Equal(rawequal(DB().inbox, P:Store("inbox", false)) and #DB().inbox, 0, "emptied in the saved settings")
-- Older whispers show their day.
Brannoc("yesterday")
Kept(1).at = NOW - 86400 * 2
Inbox:MarkAllRead()
Equal(H.Text(Inbox:Rows()[1].when), os.date("%d %b, %H:%M", NOW - 86400 * 2), "an older whisper: its day and time")
-- No line in chat while the window is open; a screenshot hides it.
Brannoc("while open")
H.RunTimers()
Equal(#H.printed, 0, "with the window open, chat says nothing (you can see it)")
H.Screenshot("start")
Equal(H.Alpha(frame), 0, "a screenshot: the window steps aside (it shows real names)")
H.Screenshot("done")
Equal(H.Alpha(frame), 1, "and comes back")
-- A long first name and surname still fit "Reply to" on its one line.
Whisper("hi", "Thalendrassa Brightmantle", "Player-1-0010")
Inbox:Select(Kept(1))
Equal(H.Text(frame.replyTo), "Reply to Thalendrassa Brightmantle", "a long name")
True(frame.replyTo:GetStringWidth() <= S[frame.replyTo].width, "fits its line")
frame.close:Click()
Equal(frame:IsShown(), false, "the close button")
SlashCmdList.FEPRIVACY("inbox")
SlashCmdList.FEPRIVACY("INBOX ")
Equal(frame:IsShown(), false, "/privacy inbox again closes it")
do
    local listed = 0
    for _, name in ipairs(UISpecialFrames) do
        if name == "ForeverEnhancedPrivacyInbox" then listed = listed + 1 end
    end
    Equal(listed, 1, "listed for Escape once")
end
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

-- The minimap button's and the eye's counts ---------------------------------------------------------------------------

Fresh(nil)
_G.GetCursorPosition = function() return 0, 0 end
local button = P.MinimapButton:Button()
P:Set("whispers", true)
P:SetPrivate(true)
Equal(tostring(P.MinimapButton:Badge()) .. " " .. tostring(P.Eye:Badge()), "nil nil", "no count until there are whispers")
Brannoc()
local badge, eyeBadge = P.MinimapButton:Badge(), P.Eye:Badge()
Equal(tostring(H.Shown(badge)) .. " " .. H.Text(badge.count) .. " / " .. tostring(H.Shown(eyeBadge)) .. " " .. H.Text(eyeBadge.count),
    "true 1 / true 1", "a whisper: a count on the minimap button and beside the eye")
Equal(tostring(S[badge].parent == button) .. " " .. tostring(S[eyeBadge].parent == P.Eye:Frame()) .. " " .. tostring(S[badge].mouse)
    .. " " .. tostring(S[eyeBadge].mouse), "true true false false", "theirs, never taking the mouse")
for i = 2, 10 do Brannoc("w" .. i) end
Equal(H.Text(badge.count) .. " " .. S[badge].width .. " / " .. H.Text(eyeBadge.count), "9+ 20 / 9+", "past nine: 9+, a little wider")
-- Its hover box: how many, and the shift-click.
H.Script(button, "OnEnter")
local tip = P.MinimapButton:Tip()
local function TipLines()
    local parts = {}
    for _, text in ipairs(tip.lines) do
        if text:IsShown() then parts[#parts + 1] = H.Text(text) end
    end
    return table.concat(parts, " / ")
end
Equal(TipLines(), "Private mode: |cffb07df0on|r / |cffb07df010 whispers waiting|r / Left-click: turn it off / Right-click: settings / "
    .. "Shift-click: whisper inbox / Drag: move it round the minimap", "its hover box says how many wait, and how to open them")
Equal(S[tip].height, 28 + 6 * 14, "taller for the two lines")
for _, text in ipairs(tip.lines) do
    local p = S[text].points[1]
    True(p[2] + text:GetStringWidth() <= S[tip].width - 10, H.Text(text) .. ": fits the box")
    True(-p[3] + 12 <= S[tip].height - 4, H.Text(text) .. ": above the box's bottom")
end
True(not TipLines():find("Brannoc", 1, true), "never a name in it")
-- Shift-click: the inbox, private mode left alone; a plain click still toggles.
H.clock = H.clock + 1
shift = true
button:Click("LeftButton")
Equal(tostring(Inbox:Frame():IsShown()) .. " " .. tostring(P:Private()), "true true", "shift-click opens the inbox, private mode left alone")
button:Click("RightButton")
Equal(tostring(Inbox:Frame():IsShown()) .. " " .. tostring(ForeverEnhancedPrivacyFrame), "false nil", "and closes it, any button")
shift = false
Inbox:MarkAllRead()
Equal(tostring(H.Shown(badge)) .. " " .. tostring(H.Shown(eyeBadge)), "false false", "all read: both counts gone")
Equal(TipLines(), "Private mode: |cffb07df0on|r / Left-click: turn it off / Right-click: settings / Shift-click: whisper inbox / "
    .. "Drag: move it round the minimap", "kept but read: no count line, the shift-click still said")
Equal(S[tip].height, 28 + 5 * 14, "the box one line shorter")
Inbox:Clear()
Equal(TipLines(), "Private mode: |cffb07df0on|r / Left-click: turn it off / Right-click: settings / Drag: move it round the minimap",
    "none kept: the hover box as before")
Equal(S[tip].height, 84, "as tall as before")
H.Script(button, "OnLeave")
-- The eye's count follows the eye: gone in a screenshot, gone with private mode.
Brannoc()
H.Screenshot("start")
Equal(tostring(H.Shown(eyeBadge)) .. " " .. tostring(H.Shown(badge)), "false false", "a screenshot: both counts gone with the eye and button")
H.Screenshot("done")
Equal(tostring(H.Shown(eyeBadge)) .. " " .. tostring(H.Shown(badge)), "true true", "and back")
P:SetPrivate(false)
Equal(tostring(H.Shown(eyeBadge)) .. " " .. tostring(H.Shown(badge)) .. " " .. H.Text(badge.count), "false true 1",
    "private mode off: the eye goes, the minimap button keeps its count till they're read")
H.RunTimers()
H.Clear()
Equal(H.Writes() .. " " .. H.Problems(), "0 ", "nothing of Blizzard's touched, nothing wrong")

io.stdout:write("TestInbox: " .. H.checks .. " checks passed\n")
