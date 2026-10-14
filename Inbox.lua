-- The whisper inbox: while private mode is on and Hide whispers keeps
-- whispers out of chat, each whisper and Battle.net whisper you get waits
-- here instead of being lost ("Keep hidden whispers in an inbox", Chat's row,
-- on by default: it only keeps what's already being hidden). Chat says only
-- how many ("2 whispers waiting. Type /privacy inbox to read them."), one
-- line for a burst and at most one a minute; the minimap button and the eye
-- show a small count. Never a name or a word of a whisper anywhere but the
-- window. The window (/privacy inbox, the Chat page's button or a shift-click
-- on the minimap button) lists them newest first; while private mode is on it
-- names nobody until you click a whisper (and forgets the clicks when it
-- closes), else it shows real names and says to open it off stream: click
-- one to reply from its own box, mark them all
-- read, delete one or clear them all. At most 50 are kept (read ones go
-- first), in the saved variables, so a /reload keeps the unread ones (read
-- ones go at the next login or /reload); Reset all settings keeps them too.
-- The saved variables are the whole account's, so a player's whisper is
-- kept with the character it came to and only shown, counted and answered
-- there (a reply from another character would tie the two together); a
-- Battle.net whisper came to the account and shows on any. Your own whispers
-- out are never kept.
--
-- Nothing of Blizzard's is touched. Whispers are read from our own event
-- frame, never from the chat frames. A reply goes out the way the chat box
-- sends one (C_ChatInfo.SendChatMessage, C_BattleNet.SendWhisper, as in
-- Forever's ChatFrameEditBox.lua), from a box of our own, so the game's chat
-- box, its text, tell target and chat type are never changed (the game's own
-- reply helpers would set those from our code). In dungeons, raids and
-- battlegrounds the game locks whispers (secret values) and Hide whispers
-- takes them out of chat: such a whisper is kept as its time with "(hidden)"
-- for whatever the game wouldn't say, so you still know one came; nothing
-- secret is ever read, compared or kept. A Battle.net friend's name is a
-- protected string that only works this session: it's held in memory with
-- the account id (for a reply) and never saved, so after a /reload the
-- whisper says "Battle.net friend" and can't be answered here.
local _, P = ...

local T = P.Theme
local C = T.C

local Inbox = {}
P.Inbox = Inbox

local NAME = "whisper inbox" -- for an error, said once
-- What an error means for you (the core's own ending is about names).
local KEEP_ERROR = "so a whisper may not be kept. Hide whispers still keeps it out of chat."
local WINDOW_ERROR = "so its window may not show your whispers right. They're still kept."
local MOST = 50 -- whispers kept; read ones go first
local TEXT_MOST = 1024 -- bytes of a kept whisper's text (the game sends at most 255)
local NAME_MOST = 100 -- bytes of a kept sender's name
local HIDDEN = "(hidden)"
local BN_FRIEND = "Battle.net friend"
local BURST, GAP = 2, 60 -- seconds: a burst of whispers gives one line in chat, at most one a minute
local WIDTH, HEIGHT = 440, 480
local LIST_TOP, LIST_FOOT = 70, 156 -- the list's room: below the title, above the reply
local LIST_W = WIDTH - 16 - 22
local CLEAR_WAIT = .5 -- seconds Clear ignores clicks after the question shows
local FRAME_NAME = "ForeverEnhancedPrivacyInbox"
local IsSecret = P.IsSecret

-- Kept whispers ---------------------------------------------------------------------------------

-- The saved list, oldest first (made with make; nil before the first whisper).
local function List(make)
    return P:Store("inbox", make)
end

-- A Battle.net friend's name and account id, this session only: never saved.
local friends = setmetatable({}, { __mode = "k" })

-- A plain string the addon may read and keep (not too long), else nil.
local function Plain(value, most)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    if most and #value > most then return nil end
    return value
end

-- A class file, as the game names them ("WARRIOR"), else nil.
local function ClassFile(value)
    value = Plain(value, 20)
    return value and value:find("^%u+$") and value or nil
end

-- A sender's name worth keeping: plain, never a Battle.net name's code.
local function SenderName(value)
    value = Plain(value, NAME_MOST)
    return value and not value:find("|", 1, true) and value or nil
end

-- A saved whisper checked as it loads: only what the addon writes, else
-- nothing. A player's whisper with no character it came to is dropped: it
-- couldn't be shown anywhere safely.
local function Clean(entry)
    if type(entry) ~= "table" then return nil end
    local at = entry.at
    if type(at) ~= "number" or at ~= at or at < 0 or at > 4e9 then return nil end
    local bn = entry.bn == true
    local to = not bn and SenderName(entry.to) or nil
    if not bn and not to then return nil end
    return { at = math.floor(at), bn = bn or nil, from = not bn and SenderName(entry.from) or nil, to = to,
        class = not bn and ClassFile(entry.class) or nil, text = Plain(entry.text, TEXT_MOST), read = entry.read == true or nil }
end

-- At most MOST: the oldest read one goes first, else the oldest.
local function Trim(list)
    while #list > MOST do
        local drop = 1
        for i, entry in ipairs(list) do
            if entry.read then
                drop = i
                break
            end
        end
        table.remove(list, drop)
    end
end

-- The saved list put right at login: anything that isn't a kept whisper
-- dropped, and the ones already read ("kept until read": a read whisper
-- lasts the session it was read in).
local function Tidy()
    local list = List(false)
    if not list then return end
    local good = {}
    for _, entry in ipairs(list) do
        entry = Clean(entry)
        if entry and not entry.read then good[#good + 1] = entry end
    end
    for key in pairs(list) do list[key] = nil end
    for i, entry in ipairs(good) do list[i] = entry end
    Trim(list)
end

-- Whispers kept this session before the game said who you are: this
-- character's, and given its name once the game says it.
local unsure = setmetatable({}, { __mode = "k" })

-- The character you're on ("First Surname"), kept once the game has said it
-- (asked at login, while it plainly can).
local me
local function Me()
    if me then return me end
    local _, full = P:MyNames()
    me = SenderName(full)
    if me then
        -- Clearing a key while going through the table is allowed in Lua.
        for entry in pairs(unsure) do
            entry.to = me
            unsure[entry] = nil
        end
    end
    return me
end

-- Whether a kept whisper is for the character you're on: a player's whisper
-- only shows, counts and can be answered on the character it came to, as the
-- saved settings are the whole account's; a Battle.net whisper came to your
-- account, so it shows on any.
local function Mine(entry)
    if type(entry) ~= "table" then return false end
    local who = Me() -- first: whispers kept before it was known get it now
    if entry.bn or unsure[entry] then return true end
    return entry.to ~= nil and entry.to == who
end

function Inbox:Count()
    local count = 0
    for _, entry in ipairs(List(false) or {}) do
        if Mine(entry) then count = count + 1 end
    end
    return count
end

function Inbox:Unread()
    local count = 0
    for _, entry in ipairs(List(false) or {}) do
        if not entry.read and Mine(entry) then count = count + 1 end
    end
    return count
end

-- This character's, newest first.
function Inbox:Entries()
    local list, out = List(false) or {}, {}
    for i = #list, 1, -1 do
        if Mine(list[i]) then out[#out + 1] = list[i] end
    end
    return out
end

-- Where a reply goes: a player's name, a Battle.net friend's account id
-- (this session only), or nil when it can't be answered here (never another
-- character's whisper).
function Inbox:Target(entry)
    if not Mine(entry) then return nil end
    if entry.bn then
        local friend = friends[entry]
        return friend and friend.id
    end
    return entry.from
end

-- Who sent it, as the window shows it, and its colour.
function Inbox:Sender(entry)
    if entry.bn then
        local friend = friends[entry]
        return friend and friend.name or BN_FRIEND, C.text
    end
    if not entry.from then return HIDDEN, C.dim end
    local r, g, b = P:ClassColour(entry.class)
    return entry.from, r and { r, g, b } or C.text
end

-- Chat's line ------------------------------------------------------------------------------------
-- How many whispers wait, never who or what: one line for a burst, then at
-- most one a minute, and none while the window is open.

local frame -- the window, made the first time it opens
local saidAt, due = -math.huge, false

local function CountLine(count)
    if count == 1 then return "1 whisper waiting. Type " .. P.SLASH .. " inbox to read it." end
    return count .. " whispers waiting. Type " .. P.SLASH .. " inbox to read them."
end

local SayCount = P:Guard(NAME, function()
    due = false
    local count = Inbox:Unread()
    if count == 0 or (frame and frame:IsShown()) then return end
    saidAt = GetTime()
    P:Print(CountLine(count))
end, KEEP_ERROR)

local function Remind()
    if due then return end
    due = true
    C_Timer.After(math.max(BURST, saidAt + GAP - GetTime()), SayCount)
end

-- Every listener hears (the eye's and the minimap button's counts, this window).
local function Changed()
    P:Notify("inbox")
end

-- Keeping ----------------------------------------------------------------------------------------

local function Keeping()
    return P:IsOn("whispers") and P:IsOn("whisperInbox")
end

local function AnySecret(...)
    for i = 1, select("#", ...) do
        if IsSecret((select(i, ...))) then return true end
    end
    return false
end

local function Now()
    local ok, now = pcall(time)
    if ok and type(now) == "number" and not IsSecret(now) then return now end
    return 0
end

local function IsMe(sender, guid)
    if sender and P:IsMyName(sender) then return true end
    guid = Plain(guid)
    if not guid or type(UnitGUID) ~= "function" then return false end
    local ok, mine = pcall(UnitGUID, "player")
    return ok and Plain(mine) == guid
end

local function ClassOf(guid)
    guid = Plain(guid)
    if not guid or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
    return ok and ClassFile(classFile) or nil
end

-- A whisper (or Battle.net whisper) just came in: the event's own values
-- (text, sender, ..., flags 6th, GUID 12th, account id 13th, hidden from
-- chat 16th). Kept only while Hide whispers is taking it out of chat: never
-- a GM's (the game shows those in its own window, before any filter), never
-- one the game shows nowhere, and a locked one only when Chat takes it out
-- (not while private mode is on just for a screenshot, unless Clean lines
-- already in chat is ticked, as Chat's own rule is).
local function Keep(event, ...)
    if not Keeping() then return end
    local flags, unseen = select(6, ...), select(16, ...)
    if not IsSecret(flags) and flags == "GM" then return end
    if not IsSecret(unseen) and unseen then return end
    if AnySecret(...) and P:ShotOnly() and not P:IsOn("cleanOld") then return end
    local text = Plain((...), TEXT_MOST)
    local entry = { at = Now(), text = text }
    if event == "CHAT_MSG_BN_WHISPER" then
        entry.bn = true
        local id = select(13, ...)
        id = not IsSecret(id) and type(id) == "number" and id or nil
        friends[entry] = { name = Plain((select(2, ...)), NAME_MOST), id = id }
    else
        local sender, guid = Plain((select(2, ...))), select(12, ...)
        if IsMe(sender, guid) then return end
        entry.from, entry.class = SenderName(sender), ClassOf(guid)
        -- The character it came to: only shown, counted and answered there.
        entry.to = Me()
        if not entry.to then unsure[entry] = true end
    end
    local list = List(true)
    list[#list + 1] = entry
    Trim(list)
    Remind()
    Changed()
end

-- What the window does ------------------------------------------------------------------------------

local selected -- the whisper clicked, for a reply
local named = setmetatable({}, { __mode = "k" }) -- whispers clicked while private, so named

-- Who sent it as the window shows it: while private mode is on, nobody is
-- named until you click their whisper (their class label, Player or
-- Battle.net friend instead), and the window forgets the clicks when it
-- closes, so opening it on stream shows no one.
function Inbox:Shown(entry)
    if not P:Private() or named[entry] or not (entry.bn or entry.from) then return self:Sender(entry) end
    if entry.bn then return BN_FRIEND, C.text end
    local label, r, g, b = P:StyleLabel(entry.class)
    if label == "" then label = "Player" end
    return label, { r, g, b }
end

-- Where this character's whisper is in the list (never another's).
local function Find(entry)
    if not Mine(entry) then return nil end
    for i, kept in ipairs(List(false) or {}) do
        if kept == entry then return i end
    end
end

-- Marks it read and gets the reply box ready for it.
function Inbox:Select(entry)
    if not Find(entry) then return end
    selected = entry
    named[entry] = true
    entry.read = true
    if frame then
        frame.status:SetText("")
        frame.box:SetText("")
    end
    Changed()
    if frame and self:Target(entry) then frame.box:SetFocus() end
end

function Inbox:Selected()
    return selected
end

-- Mark all read and Clear all are this character's (and Battle.net's): the
-- ones the window shows. Another character's wait for it.
function Inbox:MarkAllRead()
    for _, entry in ipairs(List(false) or {}) do
        if Mine(entry) then entry.read = true end
    end
    Changed()
end

function Inbox:Delete(entry)
    local i = Find(entry)
    if not i then return false end
    table.remove(List(false), i)
    if selected == entry then selected = nil end
    Changed()
    return true
end

function Inbox:Clear()
    local list = List(false)
    if list then
        for i = #list, 1, -1 do
            if Mine(list[i]) then table.remove(list, i) end
        end
    end
    selected = nil
    Changed()
end

-- Whether the game is keeping addons from sending chat (dungeons, raids,
-- battlegrounds).
local function Locked()
    local info = C_ChatInfo
    local check = type(info) == "table" and info.InChatMessagingLockdown
    if type(check) ~= "function" then return false end
    local ok, locked = pcall(check)
    return ok and not IsSecret(locked) and locked == true
end

-- Sends a reply the way the chat box would, from our own box. Returns
-- what to say under it.
function Inbox:Reply(entry, text)
    local target = self:Target(entry)
    text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if not target or text == "" then return nil end
    if Locked() then return "The game won't let addons send whispers here. Reply from chat." end
    local ok, sent
    if entry.bn then
        local send = type(C_BattleNet) == "table" and C_BattleNet.SendWhisper or BNSendWhisper
        if type(send) == "function" then ok, sent = pcall(send, target, text) end
    else
        local send = type(C_ChatInfo) == "table" and C_ChatInfo.SendChatMessage or SendChatMessage
        if type(send) == "function" then ok = pcall(send, text, "WHISPER", nil, target) end
    end
    if ok and sent ~= false then return "Sent.", true end
    return "That whisper couldn't be sent. Reply from chat."
end

-- The window -------------------------------------------------------------------------------------------

local rows = {} -- the list's rows, reused

local function Date(format, at)
    if type(date) ~= "function" then return nil end
    local ok, text
    if at then ok, text = pcall(date, format, at) else ok, text = pcall(date, format) end
    if ok and type(text) == "string" then return text end
end

-- "14:32" today, else "13 Oct, 14:32" (your own clock: the window is for off stream).
local function When(at)
    local day = Date("%Y%m%d", at)
    if not day then return "" end
    if day == Date("%Y%m%d") then return Date("%H:%M", at) or "" end
    return Date("%d %b, %H:%M", at) or ""
end

local function Edge(row)
    local edge = (row.entry and row.entry == selected) and T.ACCENT or (row.hovered and C.rowHoverEdge or C.rowEdge)
    local fill = row.hovered and C.rowHover or C.row
    row:SetBackdropColor(fill[1], fill[2], fill[3], 1)
    row:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

local function Row(content, i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, content, "BackdropTemplate")
    row:SetSize(LIST_W, 40)
    T:Flat(row, C.row, C.rowEdge)
    row.mark = T:Block(row, T.ACCENT, "ARTWORK")
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(3)
    row.from = T:Text(row, "GameFontHighlight")
    row.from:SetPoint("TOPLEFT", 12, -8)
    row.from:SetWordWrap(false)
    row.tag = T:Text(row, "GameFontHighlightSmall", C.tag)
    row.tag:SetPoint("LEFT", row.from, "RIGHT", 5, 0)
    row.when = T:Text(row, "GameFontHighlightSmall", C.dim)
    row.when:SetPoint("TOPRIGHT", -10, -9)
    row.when:SetJustifyH("RIGHT")
    row.text = T:Text(row, "GameFontHighlightSmall", C.soft)
    row.text:SetPoint("TOPLEFT", 12, -26)
    row.text:SetWidth(LIST_W - 24)
    row.text:SetWordWrap(true)
    row:SetScript("OnClick", function(self) if self.entry then Inbox:Select(self.entry) end end)
    row:SetScript("OnEnter", function(self)
        self.hovered = true
        Edge(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hovered = nil
        Edge(self)
    end)
    rows[i] = row
    return row
end

-- One whisper in its row, y down the list; returns the row's height.
local function Fill(row, entry, y)
    row.entry = entry
    local who, colour = Inbox:Shown(entry)
    row.from:SetText(who)
    row.from:SetTextColor(colour[1], colour[2], colour[3])
    -- The quiet tag only beside a friend's own name (not "Battle.net friend").
    local friend = entry.bn and friends[entry]
    row.tag:SetText(friend and friend.name and who ~= BN_FRIEND and "battle.net" or "")
    row.when:SetText(When(entry.at))
    row.text:SetText(entry.text or HIDDEN)
    local tone = entry.read and C.soft or C.text
    row.text:SetTextColor(tone[1], tone[2], tone[3])
    row.mark:SetShown(not entry.read)
    local height = 26 + math.ceil(row.text:GetStringHeight() or 12) + 10
    row:SetHeight(height)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    Edge(row)
    row:Show()
    return height
end

local function RefreshList()
    local scroll, y, shown = frame.scroll, 0, 0
    for _, entry in ipairs(Inbox:Entries()) do
        shown = shown + 1
        y = y + Fill(Row(scroll.content, shown), entry, y) + 6
    end
    for i = shown + 1, #rows do
        rows[i].entry = nil
        rows[i]:Hide()
    end
    scroll.content:SetHeight(math.max(1, y - 6))
    scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
    frame.empty:SetShown(shown == 0)
end

-- Who a reply goes to, and the box only when it can go.
local function RefreshReply()
    local entry = selected
    local target = Inbox:Target(entry)
    local about
    if not entry then
        about = "Click a whisper to reply to it."
    elseif target then
        about = "Reply to " .. (Inbox:Shown(entry))
    elseif entry.bn then
        about = "After a /reload, reply to this one from your friends list."
    else
        about = "The game hid who sent this one, so it can't be answered here."
    end
    frame.replyTo:SetText(about)
    if not target and frame.box:HasFocus() then frame.box:ClearFocus() end
    frame.box:SetShown(target ~= nil)
end

local function Refresh()
    if selected and not Find(selected) then selected = nil end
    local unread = Inbox:Unread()
    frame.count:SetText(unread > 0 and (unread .. " unread") or "")
    frame.warning:SetText(P:Private() and "Names stay hidden while private mode is on. Click a whisper to see who sent it."
        or "Real names show here, so open it off stream.")
    RefreshList()
    RefreshReply()
end

local function BuildFrame()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 30)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    T:Flat(frame, C.window, C.edge)
    local accent = T:Block(frame, T.ACCENT, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(3)
    frame.title = T:Text(frame, "GameFontNormalLarge", T.ACCENT)
    frame.title:SetPoint("TOPLEFT", 18, -18)
    frame.title:SetText("Whisper inbox")
    frame.warning = T:Text(frame, "GameFontHighlightSmall", C.gold)
    frame.warning:SetPoint("TOPLEFT", 18, -44)
    frame.warning:SetText("Real names show here, so open it off stream.")
    frame.count = T:Text(frame, "GameFontHighlightSmall", C.soft)
    frame.count:SetPoint("TOPRIGHT", -42, -18)
    frame.count:SetJustifyH("RIGHT")
    frame.close = T:Square(frame, "x")
    frame.close:SetPoint("TOPRIGHT", -10, -12)
    frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame:Hide()
    -- Escape closes it, through the game's own list of windows it closes.
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, FRAME_NAME) end
end

local function BuildList()
    local scroll = T:Scroll(frame, { 16, LIST_TOP, 22, LIST_FOOT }, LIST_W)
    frame.scroll = scroll
    frame.empty = T:Text(frame, "GameFontHighlight", C.dim)
    frame.empty:SetPoint("TOP", 0, -(LIST_TOP + 40))
    frame.empty:SetWidth(LIST_W - 40)
    frame.empty:SetJustifyH("CENTER")
    frame.empty:SetText("No whispers kept for this character. While private mode hides whispers from chat, they wait here. "
        .. "Read ones go at your next login or /reload.")
end

local function BuildReply()
    frame.replyTo = T:Text(frame, "GameFontHighlight")
    frame.replyTo:SetPoint("BOTTOMLEFT", 18, 120)
    frame.replyTo:SetWidth(WIDTH - 36)
    frame.replyTo:SetWordWrap(false)
    local box = T:Input(frame, WIDTH - 36, "Type a reply, then press Enter")
    box:SetPoint("BOTTOMLEFT", 18, 80)
    box:SetMaxLetters(255)
    box:SetScript("OnEnterPressed", function(self)
        local said, sent = Inbox:Reply(selected, self:GetText())
        if said then frame.status:SetText(said) end
        if sent then self:SetText("") end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) self:ShowPlaceholder() end)
    frame.box = box
    frame.status = T:Text(frame, "GameFontHighlightSmall", C.soft)
    frame.status:SetPoint("BOTTOMLEFT", 18, 60)
    frame.status:SetWidth(WIDTH - 36)
end

-- Clear all asks first, in its own row, as Reset all settings does: Clear
-- ignores clicks for a moment, so a double click can't empty the inbox.
local function Ask(asking)
    local bar = frame.bar
    bar.asking = asking and true or false
    if asking then bar.askedAt = GetTime() end
    for _, button in ipairs(bar.plain) do button:SetShown(not asking) end
    bar.ask:SetShown(asking)
    bar.yes:SetShown(asking)
    bar.no:SetShown(asking)
end

local function BuildButtons()
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("BOTTOMLEFT", 18, 16)
    bar:SetSize(WIDTH - 36, 30)
    frame.bar = bar
    bar.read = T:Button(bar, "Mark all read")
    bar.read:SetPoint("LEFT")
    bar.read:SetScript("OnClick", function() Inbox:MarkAllRead() end)
    bar.delete = T:Button(bar, "Delete")
    bar.delete:SetPoint("LEFT", bar.read, "RIGHT", 6, 0)
    bar.delete:SetScript("OnClick", function()
        if not Inbox:Delete(selected) then frame.status:SetText("Click a whisper first, then Delete.") end
    end)
    bar.clear = T:Button(bar, "Clear all")
    bar.clear:SetPoint("RIGHT")
    bar.clear:SetScript("OnClick", function() Ask(true) end)
    bar.plain = { bar.read, bar.delete, bar.clear }
    bar.no = T:Button(bar, "Cancel")
    bar.no:SetPoint("RIGHT")
    bar.no:SetScript("OnClick", function() Ask(false) end)
    bar.yes = T:Button(bar, "Clear", true)
    bar.yes:SetPoint("RIGHT", bar.no, "LEFT", -6, 0)
    bar.yes:SetScript("OnClick", function()
        if GetTime() - (bar.askedAt or 0) < CLEAR_WAIT then return end
        Ask(false)
        Inbox:Clear()
    end)
    bar.ask = T:Text(bar, "GameFontHighlight")
    bar.ask:SetPoint("RIGHT", bar.yes, "LEFT", -12, 0)
    bar.ask:SetText("Clear every whisper?")
end

local function Build()
    BuildFrame()
    BuildList()
    BuildReply()
    BuildButtons()
    Ask(false)
    frame:SetScript("OnShow", P:Guard(NAME, function()
        frame:SetAlpha(P:Shooting() and 0 or 1)
        Refresh()
        -- Pinned again a moment after it shows (see Theme.lua's T:Scroll).
        C_Timer.After(0, function() frame.scroll:Pin() end)
    end, WINDOW_ERROR))
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        Ask(false)
        if frame.box:HasFocus() then frame.box:ClearFocus() end
        -- Closing forgets which whispers were clicked, so they're hidden again.
        for entry in pairs(named) do named[entry] = nil end
        selected = nil
    end)
end

function Inbox:Open()
    if not frame then Build() end
    frame:Show()
end

function Inbox:Close()
    if frame then frame:Hide() end
end

function Inbox:Toggle()
    if frame and frame:IsShown() then return self:Close() end
    return self:Open()
end

function Inbox:Frame()
    return frame
end

function Inbox:Rows()
    return rows
end

-- Events ------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
local watching = false

-- Whispers are only listened for once private mode has been on this session.
local function Watch()
    if watching then return end
    watching = true
    events:RegisterEvent("CHAT_MSG_WHISPER")
    events:RegisterEvent("CHAT_MSG_BN_WHISPER")
end

local OnWhisper = P:Guard(NAME, Keep, KEEP_ERROR)

-- At login: the saved list put right, who you are asked while the game
-- plainly says, and whispers still waiting said once.
local Login = P:Guard(NAME, function()
    Tidy()
    Me()
    if Inbox:Count() > 0 then Changed() end
    if Inbox:Unread() > 0 then Remind() end
end, KEEP_ERROR)

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        Login()
    else
        OnWhisper(event, ...)
    end
end)

-- Private mode coming on starts the listening; a screenshot hides the window
-- (it shows real names) as the eye hides; anything else, the window follows.
P:Listen(P:Guard(NAME, function(what)
    if P:Private() then Watch() end
    if not frame then return end
    if what == "shot" then frame:SetAlpha(P:Shooting() and 0 or 1) end
    if frame:IsShown() then Refresh() end
end, WINDOW_ERROR))
