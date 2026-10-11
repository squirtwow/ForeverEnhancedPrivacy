-- The Chat module against a mock game (Tools/Harness.lua), with Blizzard's
-- chat stood in for below: chat frames with their history (and the secure
-- mixin's TransformMessages and RemoveMessagesByPredicate), the message
-- handler (filters, sender names, then the line as the game builds it, a
-- format string where the game uses one), edit boxes and their headers,
-- whisper windows and their tabs. Covers: nothing while off; sender names,
-- names in text, emotes, NPC lines, the game's own lines (rolls, joins, ready
-- checks, duels, loot and rolls), links and Battle.net names; whispers;
-- channel names; locked lines in dungeons (Hide names, Hide chat, Leave as
-- is); lines already in chat; the edit box header; whisper tabs; timestamps
-- and bubbles; each tick putting back only its own; secrets; and a bare game
-- with none of the chat stand-ins.
-- Run with fengari: Tools/TestChat.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpack = table.unpack or unpack
local SECRET = H.SECRET

-- Blizzard's chat, stood in for ----------------------------------------------------------------------------------

local STRINGS = {
    CHAT_WHISPER_SEND = "Tell %s: ", CHAT_BN_WHISPER_SEND = "Tell %s: ", CHAT_EMOTE_SEND = "%s ", CHAT_CHANNEL_SEND = "[%d. %s]: ",
    CHAT_SAY_SEND = "Say: ", CHAT_IGNORED = "%s is ignoring you.", PLAYER_LIST_DELIMITER = ", ",
    ERR_JOINED_GROUP_S = "%s joins the party.", ERR_FRIEND_OFFLINE_S = "%s has gone offline.", RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)",
    ERR_RAID_LEADER_READY_CHECK_START_S = "%s has initiated a ready check.", RAID_MEMBER_NOT_READY = "%s is not ready",
    RAID_MEMBERS_AFK = "The following players are Away: %s", DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel",
    DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel", ERR_GUILD_PROMOTE_SSS = "%s has promoted %s to %s.",
    LOOT_ITEM = "%s receives loot: %s.", LOOT_ROLL_PASSED = "%s passed on: %s",
    LOOT_ROLL_PASSED_AUTO = "%s automatically passed on: %s because he cannot loot that item.",
    LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s", LOOT_ROLL_WON_NO_SPAM_NEED = "%1$s won: %3$s |cff818181(Need - %2$d)|r",
    GUILD_MOTD_TEMPLATE = "Guild Message of the Day: %s",
}
local CHANNELS = { [1] = "General - Elwynn Forest", [2] = "Trade - City", [5] = "mychannel" }

-- The frame's message history, as the game keeps it (newest last here).
local function History(frame) return S[frame].history end
local function Last(frame) local list = History(frame); local entry = list[#list]; return entry and entry[1] end
local function Count(frame) return #History(frame) end

-- The chat frame's own methods: Blizzard's secure mixin copies them onto
-- the frame, so they're its own keys. Run as the game runs them: a failing
-- predicate counts as no, and a failing transform leaves a hole (counted as
-- a violation here).
local function GiveHistory(frame)
    S[frame].history = {}
    rawset(frame, "AddMessage", function(self, ...) table.insert(S[self].history, pack(...)) end)
    rawset(frame, "GetNumMessages", function(self) return #S[self].history end)
    rawset(frame, "GetMessageInfo", function(self, index) -- 1 is the oldest, as the game's
        local entry = S[self].history[index]
        if entry then return unpack(entry, 1, entry.n) end
    end)
    rawset(frame, "TransformMessages", function(self, predicate, transform)
        for i, entry in ipairs(S[self].history) do
            local ok, hit = pcall(predicate, unpack(entry, 1, entry.n))
            if not ok then
                H.hookErrors[#H.hookErrors + 1] = tostring(hit)
            elseif hit then
                local results = pack(pcall(transform, unpack(entry, 1, entry.n)))
                if not results[1] or results.n < 2 then
                    H.Violation("a chat line transform failed: " .. tostring(results[2]))
                end
                S[self].history[i] = pack(unpack(results, 2, results.n))
            end
        end
    end)
    rawset(frame, "RemoveMessagesByPredicate", function(self, predicate)
        local kept = {}
        for _, entry in ipairs(S[self].history) do
            local ok, hit = pcall(predicate, unpack(entry, 1, entry.n))
            if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(hit) end
            if not (ok and hit) then kept[#kept + 1] = entry end
        end
        S[self].history = kept
    end)
end

local SYSTEM_LIKE = { SYSTEM = true, LOOT = true, TARGETICONS = true, OPENING = true, TRADESKILLS = true, BN_WHISPER_PLAYER_OFFLINE = true }

-- ChatFrameUtil.ResolvePrefixedChannelName: fails like the game's if the number is gone.
local function Resolve(channel)
    local prefix, name = channel:match("(%d+. )(.*)")
    return prefix .. name
end

-- The line the game builds from the values the filters hand back.
local function Line(event, a)
    local kind = event:sub(10)
    if SYSTEM_LIKE[kind] then return a[1] end
    if kind == "CHANNEL_NOTICE" then return ("Changed Channel: |Hchannel:CHANNEL:%d|h[%s]|h"):format(a[8], Resolve(a[4])) end
    if kind == "CHANNEL_NOTICE_USER" then return ("[%s] %s left the channel."):format(Resolve(a[4]), a[2]) end
    if kind == "CHANNEL_LIST" then return ("[%s] " .. a[1]):format(Resolve(a[4])) end
    if kind == "IGNORED" then return CHAT_IGNORED:format(a[2]) end
    if kind == "BN_INLINE_TOAST_ALERT" then
        return a[1] == "FRIEND_REQUEST" and "You have a new friend request." or ("[%s] has come online."):format(a[2])
    end
    if kind:find("^MONSTER") then return ("%s says: " .. a[1]):format(a[2], a[2]) end
    local name = H.SenderName(event, a[2], unpack(a, 1, 14))
    local emote = kind == "EMOTE" or kind == "TEXT_EMOTE"
    local link = "|Hplayer:" .. a[2] .. "|h" .. (emote and name or ("[" .. name .. "]")) .. "|h"
    if kind == "TEXT_EMOTE" then return (a[1]:gsub(a[2], link, 1)) end
    local message = a[1]:gsub("%%", "%%%%")
    if kind == "EMOTE" then return ("%s " .. message):format(link) end
    local channel = a[4] ~= "" and ("|Hchannel:channel:" .. a[8] .. "|h[" .. Resolve(a[4]) .. "]|h ") or ""
    return channel .. ("%s: " .. message):format(link)
end

-- ChatFrameMixin:MessageEventHandler, cut down: the message filters (skipped
-- by the game when a value is secret), then the line. The guild message of
-- the day goes straight in (ChatFrameUtil.DisplayGMOTD), past every filter.
local function Handler(frame, event, ...)
    if event == "GUILD_MOTD" then
        local motd = ...
        if motd and motd ~= "" then frame:AddMessage(GUILD_MOTD_TEMPLATE:format(motd), 1, 1, 1, 1) end
        return
    end
    if type(event) ~= "string" or event:sub(1, 9) ~= "CHAT_MSG_" then return end
    local results = pack(H.Chat(event, ...))
    if results[1] then return end
    local a = pack(unpack(results, 2, results.n))
    for i = 1, a.n do
        if H.IsSecret(a[i]) then
            frame:AddMessage(SECRET, 1, 1, 1, 1, 0, 0, event, a)
            return
        end
    end
    frame:AddMessage(Line(event, a), 1, 1, 1, 1, 0, 0, event, a)
end

-- ChatFrameEditBoxMixin:UpdateHeader, cut down: the game measures the header
-- straight after setting it.
local function UpdateHeader(box)
    local s = S[box]
    local header = _G[s.name .. "Header"]
    if s.chatType == "WHISPER" then
        header:SetFormattedText(CHAT_WHISPER_SEND, s.tellTarget)
    elseif s.chatType == "BN_WHISPER" then
        header:SetFormattedText(CHAT_BN_WHISPER_SEND, s.tellTarget)
    elseif s.chatType == "EMOTE" then
        header:SetFormattedText(CHAT_EMOTE_SEND, (UnitName("player")))
    elseif s.chatType == "CHANNEL" then
        local id, name = GetChannelName(s.channelTarget)
        header:SetFormattedText(CHAT_CHANNEL_SEND, id, name)
    else
        header:SetText(_G["CHAT_" .. s.chatType .. "_SEND"])
    end
    s.measured = header:GetText()
end

local function MakeChatFrame(i)
    local name = "ChatFrame" .. i
    local frame = i == 1 and H.chatFrame or H.BlizzardFrame("ScrollingMessageFrame", name, UIParent)
    GiveHistory(frame)
    S[frame].scripts.OnEvent = Handler
    local tab = H.BlizzardFrame("Button", name .. "Tab", UIParent)
    S[tab].text = i == 1 and "General" or ("Chat " .. i)
    local box = H.BlizzardFrame("EditBox", name .. "EditBox", frame)
    H.BlizzardText(name .. "EditBoxHeader", box, "")
    rawset(box, "GetChatType", function(self) return S[self].chatType end)
    rawset(box, "GetTellTarget", function(self) return S[self].tellTarget end)
    rawset(box, "GetChannelTarget", function(self) return S[self].channelTarget end)
    return frame
end

-- The floating chat frame functions the module hooks.
local function FloatingChat()
    local temporary = 10
    _G.CHAT_FRAMES, _G.NUM_CHAT_WINDOWS = { "ChatFrame1", "ChatFrame2" }, 2
    _G.FCF_SetWindowName = function(frame, name)
        frame.name = name
        _G[S[frame].name .. "Tab"]:SetText(name)
        local minimised = _G[S[frame].name .. "Minimized"]
        if minimised then minimised:SetText(name) end
    end
    _G.FCF_OpenTemporaryWindow = function(chatType, target)
        temporary = temporary + 1
        local frame = MakeChatFrame(temporary)
        table.insert(CHAT_FRAMES, S[frame].name)
        frame.isTemporary, frame.chatType, frame.chatTarget = true, chatType, target
        FCF_SetWindowName(frame, target)
        return frame
    end
    _G.FCF_CreateMinimizedFrame = function(frame)
        local minimised = H.BlizzardFrame("Button", S[frame].name .. "Minimized", UIParent)
        minimised:SetText(frame.name)
        return minimised
    end
    _G.FCFDockOverflowListButton_SetValue = function(button, frame)
        button.chatFrame = frame
        button:SetText(frame.name)
    end
    _G.GetChannelName = function(id)
        if CHANNELS[id] then return id, CHANNELS[id], 0, false end
        return 0, nil, 0, false
    end
end

-- Clears the stand-ins from the game before (H.Environment leaves globals
-- that aren't the addon's).
local function Clear()
    for key in pairs(STRINGS) do _G[key] = nil end
    local old = {}
    for key in pairs(_G) do
        if type(key) == "string" and (key:find("^ChatFrame%d") or key:find("^FCF")) then old[#old + 1] = key end
    end
    for _, key in ipairs(old) do _G[key] = nil end
    _G.CHAT_FRAMES, _G.NUM_CHAT_WINDOWS, _G.GetChannelName = nil, nil, nil
end

local P
-- A fresh game with Blizzard's chat and a party: Brannoc (warrior) and
-- Kaelis (mage); Merrin (priest) is a stranger nearby.
local function Game(saved, opts)
    Clear()
    H.Environment()
    for key, value in pairs(STRINGS) do _G[key] = value end
    MakeChatFrame(1)
    MakeChatFrame(2)
    FloatingChat()
    H.units.party1 = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true, guid = "Player-1-0002" }
    H.units.party2 = { name = "Kaelis", surname = "Dawnbrook", class = "Mage", classFile = "MAGE", player = true, guid = "Player-1-0003" }
    H.units.target = { name = "Merrin", surname = "Lightfoot", class = "Priest", classFile = "PRIEST", player = true, guid = "Player-1-0004" }
    H.cvars.showTimestamps = "%H:%M "
    P = H.Load(saved, opts)
    return P
end

-- A chat event's values, as the game sends them.
local function Msg(text, sender, o)
    o = o or {}
    return text, sender or "", "", o.channel or "", o.name2 or "", "", 0, o.number or 0, o.base or "", 0, 1, o.guid or "", o.bn or 0, false
end

-- The game hands a chat frame an event: its handler, then any hook.
local function Event(frame, event, ...)
    H.Blizzard(H.Script, frame, "OnEvent", event, ...)
end

local function Type(box, chatType, target)
    S[box].chatType = chatType
    if chatType == "CHANNEL" then S[box].channelTarget = target else S[box].tellTarget = target end
    H.Blizzard(UpdateHeader, box)
end

local function Filters()
    local n = #H.senderFilters
    for _, list in pairs(H.messageFilters) do n = n + #list end
    return n
end

local function Label(classFile) return P:Colourise(P:StyleLabel(classFile)) end
local GENERAL = { channel = "1. General - Elwynn Forest", base = "General", number = 1 }
local BRANNOC = { guid = "Player-1-0002" }
local KAELIS = { guid = "Player-1-0003" }
local MERRIN = { guid = "Player-1-0004" }

-- Off: nothing at all ---------------------------------------------------------------------------------------------

Game(nil)
local chat1, chat2 = ChatFrame1, ChatFrame2
Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel, meet Kaelis Dawnbrook", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h: hi Zriel, meet Kaelis Dawnbrook", "off: as the game says it")
Event(chat1, "CHAT_MSG_CHANNEL", Msg("LF tank", "Merrin Lightfoot", { channel = GENERAL.channel, base = "General", number = 1, guid = MERRIN.guid }))
Equal(Last(chat1), "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h |Hplayer:Merrin Lightfoot|h[Merrin Lightfoot]|h: LF tank",
    "off: the zone in the channel name")
Event(chat1, "CHAT_MSG_WHISPER", Msg("psst", "Kaelis Dawnbrook", KAELIS))
Equal(Count(chat1), 3, "off: whispers shown")
Event(chat1, "CHAT_MSG_PARTY", SECRET, SECRET, "", "", "", "", 0, 0, "", 0, 1, SECRET, 0, false)
True(rawequal(Last(chat1), SECRET), "off: a locked line left alone")
Equal(Filters(), 0, "off: no filter added")
Equal(H.Writes() .. " " .. #H.cvarWrites, "0 0", "off: nothing of Blizzard's touched, no CVar")
Equal(H.Problems(), "", "nothing wrong while off")

-- On: sender names and names in text --------------------------------------------------------------------------------

P:SetPrivate(true)
local ME, WARRIOR, MAGE, PRIEST, PLAYER = Label("DRUID"), Label("WARRIOR"), Label("MAGE"), Label("PRIEST"), Label(nil)
True(Filters() > 0 and #H.senderFilters == 1, "on: the filters added")
Equal(H.cvars.chatBubbles .. H.cvars.chatBubblesParty .. " " .. H.cvars.showTimestamps, "00 none", "bubbles and timestamps off")
Equal(ForeverEnhancedPrivacyDB.cvarBackup.showTimestamps, "%H:%M ", "the timestamp setting kept to put back")
True(rawequal(Last(chat1), SECRET), "a locked line from before is left: changing it is one way, so only with cleanOld")
Equal(History(chat1)[3][1], "|Hplayer:Kaelis Dawnbrook|h[Kaelis Dawnbrook]|h: psst", "other lines already there left (cleanOld is off)")

Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel, meet Kaelis Dawnbrook", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[" .. WARRIOR .. "]|h: hi " .. ME .. ", meet " .. MAGE,
    "the sender's class in its colour, your name and theirs in the text; the link keeps the real name")
Event(chat1, "CHAT_MSG_SAY", Msg("hello", "Zriel Gustbellow", { guid = "Player-1-0001" }))
Equal(Last(chat1), "|Hplayer:Zriel Gustbellow|h[" .. ME .. "]|h: hello", "you talking")
Event(chat1, "CHAT_MSG_CHANNEL", Msg("LF tank", "Merrin Lightfoot", { channel = GENERAL.channel, base = "General", number = 1, guid = MERRIN.guid }))
Equal(Last(chat1), "|Hchannel:channel:1|h[1. General]|h |Hplayer:Merrin Lightfoot|h[" .. PRIEST .. "]|h: LF tank",
    "a stranger by their GUID; the zone gone from the channel")
Equal(P:ClassOf("Merrin Lightfoot"), "PRIEST", "and noted, for their name in later lines")
Event(chat1, "CHAT_MSG_SYSTEM", Msg("Merrin Lightfoot has gone offline."))
Equal(Last(chat1), PRIEST .. " has gone offline.", "so the game's lines name them by class")
Event(chat1, "CHAT_MSG_TEXT_EMOTE", Msg("Brannoc Stonehelm waves at Kaelis Dawnbrook.", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h" .. WARRIOR .. "|h waves at " .. MAGE .. ".",
    "an emote: the sender left for the game to link, the other name swapped")
Event(chat1, "CHAT_MSG_EMOTE", Msg("dances with Zriel", "Kaelis Dawnbrook", KAELIS))
Equal(Last(chat1), "|Hplayer:Kaelis Dawnbrook|h" .. MAGE .. "|h dances with " .. ME, "a typed emote")
Event(chat1, "CHAT_MSG_MONSTER_SAY", Msg("Well met, Zriel Gustbellow!", "Marshal Dughan"))
Equal(Last(chat1), "Marshal Dughan says: Well met, " .. ME .. "!", "an NPC saying your name; the NPC's own left")
Event(chat1, "CHAT_MSG_WHISPER", Msg("psst Zriel", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[" .. WARRIOR .. "]|h: psst " .. ME, "whispers swapped while they're shown")
Event(chat1, "CHAT_MSG_IGNORED", Msg("", "Brannoc Stonehelm"))
Equal(Last(chat1), "Warrior is ignoring you.", "a name the game puts into its line")

-- The game's own lines.
local function System(text, event)
    Event(chat1, event or "CHAT_MSG_SYSTEM", Msg(text))
    return Last(chat1)
end
Equal(System("Brannoc Stonehelm rolls 42 (1-100)"), WARRIOR .. " rolls 42 (1-100)", "a roll")
Equal(System("|Hplayer:Kaelis Dawnbrook|h[Kaelis Dawnbrook]|h has come online."),
    "|Hplayer:Kaelis Dawnbrook|h[" .. MAGE .. "]|h has come online.", "a player link: shown as a label, its data kept")
Equal(System("Brannoc Stonehelm has initiated a ready check."), WARRIOR .. " has initiated a ready check.", "a ready check")
Equal(System("The following players are Away: Brannoc Stonehelm, Kaelis Dawnbrook"),
    "The following players are Away: " .. WARRIOR .. ", " .. MAGE, "and who's away")
Equal(System("Brannoc Stonehelm has defeated Kaelis Dawnbrook in a duel"), WARRIOR .. " has defeated " .. MAGE .. " in a duel",
    "a duel")
Equal(System("Kaelis Dawnbrook has fled from Brannoc Stonehelm in a duel"), MAGE .. " has fled from " .. WARRIOR .. " in a duel",
    "values out of order")
Equal(System("Brannoc Stonehelm has promoted Kaelis Dawnbrook to Officer."), WARRIOR .. " has promoted " .. MAGE .. " to Officer.",
    "only the values that are names")
Equal(System("Thoren Ashfall joins the party."), PLAYER .. " joins the party.", "a stranger the game names: Player")
Equal(P:ClassOf("Thoren Ashfall"), nil, "and not noted (a line's words aren't proof of a player)")
Equal(System("Zriel Gustbellow joins the party."), ME .. " joins the party.", "you")
Equal(System("Your pet is not ready"), "Your pet is not ready", "words that aren't a name left alone")
Equal(System("You have learned a new spell."), "You have learned a new spell.", "and lines with none")
-- Loot and rolls follow the loot tick.
local ITEM = "|Hitem:2589|h[Linen Cloth]|h"
Equal(System("Brannoc Stonehelm receives loot: " .. ITEM .. ".", "CHAT_MSG_LOOT"), WARRIOR .. " receives loot: " .. ITEM .. ".", "loot")
Equal(System("Need Roll - 45 for " .. ITEM .. " by Kaelis Dawnbrook", "CHAT_MSG_LOOT"), "Need Roll - 45 for " .. ITEM .. " by " .. MAGE,
    "a roll for loot")
Equal(System("Brannoc Stonehelm automatically passed on: " .. ITEM .. " because he cannot loot that item.", "CHAT_MSG_LOOT"),
    WARRIOR .. " automatically passed on: " .. ITEM .. " because he cannot loot that item.", "the longer line wins over its shorter twin")
Equal(System("Kaelis Dawnbrook won: " .. ITEM .. " |cff818181(Need - 45)|r", "CHAT_MSG_LOOT"),
    MAGE .. " won: " .. ITEM .. " |cff818181(Need - 45)|r", "a win")
P:Set("loot", false)
Equal(System("Brannoc Stonehelm receives loot: " .. ITEM .. ".", "CHAT_MSG_LOOT"), "Brannoc Stonehelm receives loot: " .. ITEM .. ".",
    "loot unticked: loot lines left")
Equal(System("Brannoc Stonehelm rolls 2 (1-100)"), WARRIOR .. " rolls 2 (1-100)", "but not the rest")
P:Set("loot", true)

-- Channels.
Event(chat1, "CHAT_MSG_CHANNEL_NOTICE", Msg("YOU_CHANGED", "", { channel = "1. General - Westfall", base = "General", number = 1 }))
Equal(Last(chat1), "Changed Channel: |Hchannel:CHANNEL:1|h[1. General]|h", "the notice on every zone change")
Event(chat1, "CHAT_MSG_CHANNEL", Msg("WTS", "Kaelis Dawnbrook", { channel = "2. Trade - City", base = "Trade", number = 2, guid = KAELIS.guid }))
Equal(Last(chat1), "|Hchannel:channel:2|h[2. Trade]|h |Hplayer:Kaelis Dawnbrook|h[" .. MAGE .. "]|h: WTS", "Trade too")
Event(chat1, "CHAT_MSG_CHANNEL", Msg("yo", "Kaelis Dawnbrook", { channel = "5. mychannel", base = "mychannel", number = 5, guid = KAELIS.guid }))
Equal(Last(chat1), "|Hchannel:channel:5|h[5. mychannel]|h |Hplayer:Kaelis Dawnbrook|h[" .. MAGE .. "]|h: yo", "a channel with no zone")
Event(chat1, "CHAT_MSG_CHANNEL_NOTICE_USER", Msg("PLAYER_LEFT", "Brannoc Stonehelm", GENERAL))
Equal(Last(chat1), "[1. General] Warrior left the channel.", "someone leaving a channel")
Event(chat1, "CHAT_MSG_CHANNEL_LIST", Msg("Brannoc Stonehelm, *Kaelis Dawnbrook", "", GENERAL))
Equal(Last(chat1), "[1. General] " .. WARRIOR .. ", *" .. MAGE, "/chatlist")
do
    local before = Count(chat1)
    Event(chat1, "CHAT_MSG_CHANNEL", Msg("Goldshire is under attack!", "", { channel = "3. LocalDefense - Elwynn Forest",
        base = "LocalDefense", number = 3 }))
    Equal(Count(chat1), before, "LocalDefense, which says where you are, stays out")
end

-- Battle.net.
do
    local before = Count(chat1)
    Event(chat1, "CHAT_MSG_BN_INLINE_TOAST_ALERT", Msg("FRIEND_ONLINE", "|Kq1|k", { bn = 7 }))
    Event(chat1, "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", Msg("Streaming now!", "|Kq1|k", { bn = 7 }))
    Equal(Count(chat1), before, "a friend coming online and their broadcast stay out")
    Event(chat1, "CHAT_MSG_BN_INLINE_TOAST_ALERT", Msg("FRIEND_REQUEST", "", { bn = 7 }))
    Equal(Last(chat1), "You have a new friend request.", "a friend request names no one: shown")
    P:Set("chatNames", false)
    local count = Count(chat1)
    Event(chat1, "CHAT_MSG_BN_INLINE_TOAST_ALERT", Msg("FRIEND_ONLINE", "|Kq1|k", { bn = 7 }))
    Equal(Count(chat1), count, "with only the came-online pop-ups ticked, the chat line stays out too")
    P:Set("bnToasts", false)
    Event(chat1, "CHAT_MSG_BN_INLINE_TOAST_ALERT", Msg("FRIEND_ONLINE", "|Kq1|k", { bn = 7 }))
    Equal(Last(chat1), "[|Kq1|k] has come online.", "neither ticked: shown")
    P:Set("bnToasts", true)
    P:Set("chatNames", true)
end
Event(chat1, "CHAT_MSG_BN_WHISPER", Msg("hey", "|Kq1|k", { bn = 7 }))
Equal(Last(chat1), "|Hplayer:|Kq1|k|h[" .. PLAYER .. "]|h: hey", "a Battle.net whisper: their name never shown")
Event(chat1, "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", Msg("|Kq1|k is offline.", "|Kq1|k", { bn = 7 }))
Equal(Last(chat1), PLAYER .. " is offline.", "a Battle.net name in the text")
Equal(H.Problems(), "", "nothing wrong swapping")

-- Each tick: its own surface only.
P:Set("whispers", true)
do
    local before = Count(chat1)
    Event(chat1, "CHAT_MSG_WHISPER", Msg("psst", "Brannoc Stonehelm", BRANNOC))
    Event(chat1, "CHAT_MSG_WHISPER_INFORM", Msg("hi", "Brannoc Stonehelm", BRANNOC))
    Event(chat1, "CHAT_MSG_BN_WHISPER", Msg("hey", "|Kq1|k", { bn = 7 }))
    Event(chat1, "CHAT_MSG_AFK", Msg("brb", "Brannoc Stonehelm", BRANNOC))
    Equal(Count(chat1), before, "Hide whispers: every kind stays out")
end
P:Set("whispers", false)
P:Set("chatNames", false)
Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h: hi Zriel", "names unticked: names left")
Equal(System("Brannoc Stonehelm rolls 5 (1-100)"), "Brannoc Stonehelm rolls 5 (1-100)", "in the game's lines too")
Event(chat1, "CHAT_MSG_CHANNEL", Msg("LF tank", "Merrin Lightfoot", { channel = GENERAL.channel, base = "General", number = 1, guid = MERRIN.guid }))
Equal(Last(chat1), "|Hchannel:channel:1|h[1. General]|h |Hplayer:Merrin Lightfoot|h[Merrin Lightfoot]|h: LF tank",
    "but channel names still go")
P:Set("chatNames", true)
P:Set("channels", false)
Event(chat1, "CHAT_MSG_CHANNEL", Msg("LF tank", "Merrin Lightfoot", { channel = GENERAL.channel, base = "General", number = 1, guid = MERRIN.guid }))
Equal(Last(chat1), "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h |Hplayer:Merrin Lightfoot|h[" .. PRIEST .. "]|h: LF tank",
    "channel names unticked: the zone shows, names still swapped")
P:Set("channels", true)

-- Name styles and your typed name.
P:Set("nameStyle", "player")
local GREY_PLAYER = Label(nil)
Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[" .. GREY_PLAYER .. "]|h: hi " .. GREY_PLAYER, "the Player style")
P:Set("nameStyle", "hidden")
Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[]|h: hi ", "the Hidden style")
P:Set("nameStyle", "class")
P:Set("myName", "100% Squirt")
-- Your typed name in each colour, everywhere chat shows you. The game's own:
-- no colour of ours, so the line's colour shows, or the colour the game gave
-- your name as the sender (class colours in chat).
do
    local CODES = { accent = "|cffb07df0", class = "|cffff7d0a", white = "|cffffffff" }
    for _, choice in ipairs({ "accent", "class", "white", "game", "accent", "game" }) do
        P:Set("myColour", choice)
        local code = CODES[choice]
        local mine = code and (code .. "100 Squirt|r") or "100 Squirt"
        Event(chat1, "CHAT_MSG_MONSTER_SAY", Msg("Well met, Zriel!", "Marshal Dughan"))
        Equal(Last(chat1), "Marshal Dughan says: Well met, " .. mine .. "!",
            choice .. ": your typed name, with no % to break the game's format string")
        Event(chat1, "CHAT_MSG_TEXT_EMOTE", Msg("Zriel Gustbellow dances.", "Zriel Gustbellow", { guid = "Player-1-0001" }))
        Equal(Last(chat1), "|Hplayer:Zriel Gustbellow|h" .. mine .. "|h dances.", choice .. ": nor the game's emote swap")
        Event(chat1, "CHAT_MSG_SAY", Msg("hello", "Zriel Gustbellow", { guid = "Player-1-0001" }))
        Equal(Last(chat1), "|Hplayer:Zriel Gustbellow|h[" .. mine .. "]|h: hello", choice .. ": you talking")
        Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
        Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[" .. WARRIOR .. "]|h: hi " .. mine,
            choice .. ": your name in someone's line, theirs as before")
        Equal(System("Zriel Gustbellow joins the party."), mine .. " joins the party.", choice .. ": the game's own lines")
        Equal(System("|Hplayer:Zriel Gustbellow|h[Zriel Gustbellow]|h has come online."),
            "|Hplayer:Zriel Gustbellow|h[" .. mine .. "]|h has come online.", choice .. ": a link to you")
        Equal(H.SenderName("CHAT_MSG_GUILD", "|cffff7c0aZriel Gustbellow|r", Msg("hi", "Zriel Gustbellow", { guid = "Player-1-0001" })),
            code and mine or "|cffff7c0a100 Squirt|r", choice .. ": the sender's name as the game coloured it")
        Equal(H.SenderName("CHAT_MSG_GUILD", "|cffc69b6dBrannoc Stonehelm|r", Msg("hi", "Brannoc Stonehelm", BRANNOC)), WARRIOR,
            choice .. ": anyone else's, their class as before")
    end
end
P:Set("myName", "")
Equal(H.SenderName("CHAT_MSG_GUILD", "|cffff7c0aZriel Gustbellow|r", Msg("hi", "Zriel Gustbellow", { guid = "Player-1-0001" })), ME,
    "no typed name: the name style, whatever the colour")
Equal(H.Problems(), "", "nothing wrong with the ticks and styles")

-- Lines the game locks (dungeons, raids, battlegrounds) ----------------------------------------------------------------

local function Locked(frame, event)
    Event(frame, event or "CHAT_MSG_PARTY", SECRET, SECRET, "", "", "", "", 0, 0, "", 0, 1, SECRET, 0, false)
end
Locked(chat1)
Equal(Last(chat1), "[Party] (hidden)", "Hide names: a locked line can't be swapped, so it's hidden")
Equal(History(chat1)[4][1], "[Party] (hidden)", "and the older one with it (the game can't say which line is new)")
Locked(chat2, "CHAT_MSG_SYSTEM")
Equal(Last(chat2), "(hidden)", "in every chat frame, system lines too")
P:Set("instChat", "chat")
do
    local before = Count(chat1)
    Locked(chat1, "CHAT_MSG_RAID")
    Equal(Count(chat1), before, "Hide chat: taken out")
end
P:Set("instChat", "leave")
Locked(chat1)
True(rawequal(Last(chat1), SECRET), "Leave as is: left")
P:Set("whispers", true)
do
    local before = Count(chat1)
    Locked(chat1, "CHAT_MSG_WHISPER")
    Equal(Count(chat1), before, "Hide whispers: a locked whisper taken out, even with Leave as is")
    Locked(chat1, "CHAT_MSG_PARTY")
    True(rawequal(Last(chat1), SECRET) and rawequal(History(chat1)[before][1], SECRET), "other locked lines still left")
    History(chat1)[before + 1] = nil
end
P:Set("whispers", false)
P:Set("instChat", "names")
True(rawequal(Last(chat1), SECRET), "Hide names again: the one left stays (cleanOld is off)")
Locked(chat1)
Equal(Last(chat1) .. "|" .. History(chat1)[#History(chat1) - 1][1], "[Party] (hidden)|[Party] (hidden)",
    "until the next locked line, which hides both")
Event(chat1, "CHAT_MSG_LOOT", Msg("Brannoc Stonehelm receives loot: " .. ITEM .. "."))
Equal(Last(chat1), WARRIOR .. " receives loot: " .. ITEM .. ".", "lines the game doesn't lock are still swapped")
Equal(H.Problems(), "", "no secret read")

-- Off: everything put back, nothing more done --------------------------------------------------------------------------

P:SetPrivate(false)
Equal(Filters(), 0, "off: the filters taken away")
Equal(H.cvars.chatBubbles .. H.cvars.chatBubblesParty .. " " .. H.cvars.showTimestamps, "11 %H:%M ", "bubbles and timestamps back")
Equal(next(ForeverEnhancedPrivacyDB.cvarBackup), nil, "nothing left to put back")
H.ResetWrites()
Event(chat1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h: hi Zriel", "off again: as the game says it")
Locked(chat1)
True(rawequal(Last(chat1), SECRET), "a locked line left alone")
Event(chat1, "CHAT_MSG_WHISPER", Msg("psst", "Brannoc Stonehelm", BRANNOC))
Equal(H.Writes(), 0, "the hooks left do nothing")
P:SetPrivate(true)
Equal(Last(chat1), "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h: psst", "on again: old lines left (cleanOld is off)")
True(rawequal(History(chat1)[#History(chat1) - 1][1], SECRET), "a locked one too")
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing wrong turning off")

-- The edit box header ---------------------------------------------------------------------------------------------------

Game(nil)
local box, header = ChatFrame1EditBox, ChatFrame1EditBoxHeader
Type(box, "WHISPER", "Brannoc Stonehelm")
Equal(H.Text(header) .. "|" .. H.Writes(), "Tell Brannoc Stonehelm: |0", "off: the game's own")
P:SetPrivate(true)
Equal(H.Text(header), "Tell Warrior: ", "on: swapped where it shows")
Type(box, "WHISPER", "Brannoc Stonehelm")
Equal(H.Text(header) .. "|" .. S[box].measured, "Tell Warrior: |Tell Warrior: ", "and as the game sets it, before it's measured")
Type(box, "EMOTE")
Equal(H.Text(header), "Druid ", "your own name on /e")
P:Set("myName", "Shade")
for _, choice in ipairs({ "accent", "class", "white", "game" }) do
    P:Set("myColour", choice)
    Equal(H.Text(header) .. "|" .. tostring(S[header].colour), "Shade |nil", choice .. ": your typed name on /e, in the header's own colour")
end
P:Set("myName", "")
Equal(H.Text(header), "Druid ", "cleared: the name style")
Type(box, "CHANNEL", 1)
Equal(H.Text(header), "[1. General]: ", "a channel's zone")
Type(box, "CHANNEL", 5)
Equal(H.Text(header), "[5. mychannel]: ", "a channel with none left as it is")
Type(box, "SAY")
Equal(H.Text(header), "Say: ", "Say left")
Type(box, "WHISPER", SECRET)
Equal(H.Text(header), "Tell Player: ", "a name the game won't say: Player, never read")
Type(box, "BN_WHISPER", "|Kq1|k")
Equal(H.Text(header), "Tell Player: ", "a Battle.net friend")
Type(box, "WHISPER", "Brannoc Stonehelm")
P:Set("nameStyle", "player")
Equal(H.Text(header), "Tell Player: ", "the name style changing: at once")
P:Set("nameStyle", "class")
Equal(H.Text(header), "Tell Warrior: ", "and back")
P:Set("chatNames", false)
Equal(H.Text(header), "Tell Brannoc Stonehelm: ", "names unticked: put back")
P:Set("chatNames", true)
Equal(H.Text(header), "Tell Warrior: ", "ticked: swapped")
Type(box, "CHANNEL", 1)
P:Set("channels", false)
Equal(H.Text(header), "[1. General - Elwynn Forest]: ", "channel names unticked: put back")
P:Set("channels", true)
Equal(H.Text(header), "[1. General]: ", "ticked: swapped")
P:SetPrivate(false)
Equal(H.Text(header), "[1. General - Elwynn Forest]: ", "off: put back")
H.ResetWrites()
Type(box, "WHISPER", "Brannoc Stonehelm")
Equal(H.Text(header) .. "|" .. H.Writes(), "Tell Brannoc Stonehelm: |0", "off: the hook does nothing")
Equal(H.Problems(), "", "nothing wrong with the header")

-- Whisper windows -----------------------------------------------------------------------------------------------------------

Game(nil)
local window = H.Blizzard(FCF_OpenTemporaryWindow, "WHISPER", "Brannoc Stonehelm")
local tab = ChatFrame11Tab
Equal(H.Text(tab), "Brannoc Stonehelm", "off: the tab names who you're whispering")
P:SetPrivate(true)
Equal(H.Text(tab), "Warrior", "on: swapped")
local minimised = H.Blizzard(FCF_CreateMinimizedFrame, window)
Equal(H.Text(minimised), "Warrior", "its minimised button")
local overflow = H.BlizzardFrame("Button", nil, UIParent)
H.Blizzard(FCFDockOverflowListButton_SetValue, overflow, window)
Equal(H.Text(overflow), "Warrior", "its line in the dock's list")
H.Blizzard(FCF_OpenTemporaryWindow, "WHISPER", "Merrin Lightfoot")
Equal(H.Text(ChatFrame12Tab), "Player", "a new one: a stranger")
H.Blizzard(FCF_OpenTemporaryWindow, "BN_WHISPER", "|Kq1|k")
Equal(H.Text(ChatFrame13Tab), "Player", "a Battle.net friend")
Locked(ChatFrame12, "CHAT_MSG_WHISPER")
Equal(Last(ChatFrame12), "[Whisper] (hidden)", "a new window's locked lines hidden too")
P:Set("whispers", true)
P:Set("chatNames", false)
Equal(H.Text(tab), "Warrior", "either tick keeps it swapped")
P:Set("whispers", false)
Equal(H.Text(tab), "Brannoc Stonehelm", "neither: put back")
P:Set("chatNames", true)
Equal(H.Text(tab), "Warrior", "swapped again")
P:Set("nameStyle", "hidden")
Equal(H.Text(tab), "Whisper", "the Hidden style: never a blank tab")
P:Set("nameStyle", "class")
H.Blizzard(FCF_SetWindowName, window, "Brannoc Stonehelm")
Equal(H.Text(tab), "Warrior", "the game naming it again")
P:SetPrivate(false)
Equal(H.Text(tab) .. "|" .. H.Text(minimised) .. "|" .. H.Text(overflow), "Brannoc Stonehelm|Brannoc Stonehelm|Brannoc Stonehelm",
    "off: all put back")
H.ResetWrites()
H.Blizzard(FCF_OpenTemporaryWindow, "WHISPER", "Kaelis Dawnbrook")
Equal(H.Text(ChatFrame14Tab) .. "|" .. H.Writes(), "Kaelis Dawnbrook|0", "off: a new window left alone")
Equal(H.Problems(), "", "nothing wrong with whisper windows")
-- A whisper in a dungeon opens its window with a name the game keeps secret.
P:SetPrivate(true)
H.Blizzard(FCF_OpenTemporaryWindow, "WHISPER", SECRET)
Equal(H.Text(ChatFrame15Tab), "Player", "a secret name: Player, never read")
P:SetPrivate(false)
Equal(H.Text(ChatFrame15Tab), "Player", "it can't be put back...")
Equal(table.concat(H.printed, " | "), "|cffb07df0Forever Enhanced Privacy|r: " .. P.RELOAD_NOTE, "...so a /reload is suggested once")
H.Clear()
Equal(H.Problems(), "", "no secret read")

-- Lines already in chat ---------------------------------------------------------------------------------------------------

local function OldLines()
    Event(ChatFrame1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
    Event(ChatFrame1, "CHAT_MSG_CHANNEL", Msg("LF tank", "Merrin Lightfoot", { channel = GENERAL.channel, base = "General", number = 1,
        guid = MERRIN.guid }))
    Event(ChatFrame1, "CHAT_MSG_WHISPER", Msg("psst", "Kaelis Dawnbrook", KAELIS))
    Event(ChatFrame1, "CHAT_MSG_SYSTEM", Msg("Brannoc Stonehelm rolls 3 (1-100)"))
end
local function Messages(frame)
    local list = {}
    for _, entry in ipairs(History(frame)) do list[#list + 1] = entry[1] end
    return table.concat(list, "\n")
end

Game({ cleanOld = true, whispers = true })
OldLines()
P:SetPrivate(true)
ME, WARRIOR, PLAYER = Label("DRUID"), Label("WARRIOR"), Label(nil)
Equal(Messages(ChatFrame1), "|Hplayer:Brannoc Stonehelm|h[" .. WARRIOR .. "]|h: hi " .. ME .. "\n"
    .. "|Hchannel:channel:1|h[1. General]|h |Hplayer:Merrin Lightfoot|h[" .. PLAYER .. "]|h: LF tank\n"
    .. WARRIOR .. " rolls 3 (1-100)", "cleaned when it turns on: names, the zone, and whispers taken out")
P:SetPrivate(false)
True(Messages(ChatFrame1):find(WARRIOR, 1, true) ~= nil, "one way: they stay cleaned")
Equal(H.Problems(), "", "nothing wrong cleaning")
-- Your typed name in lines already there, in each colour.
for choice, mine in pairs({ accent = "|cffb07df0Shade|r", class = "|cffff7d0aShade|r", white = "|cffffffffShade|r", game = "Shade" }) do
    Game({ cleanOld = true, myName = "Shade", myColour = choice })
    OldLines()
    P:SetPrivate(true)
    Equal(History(ChatFrame1)[1][1], "|Hplayer:Brannoc Stonehelm|h[" .. Label("WARRIOR") .. "]|h: hi " .. mine,
        choice .. ": your typed name in a line already there")
    P:SetPrivate(false)
end
Equal(H.Problems(), "", "nothing wrong cleaning your name")

Game(nil)
OldLines()
local before = Messages(ChatFrame1)
P:SetPrivate(true)
Equal(Messages(ChatFrame1), before, "unticked (as it starts): lines already there left")
P:Set("cleanOld", true)
True(Messages(ChatFrame1):find("[1. General]", 1, true) ~= nil, "ticked while private: cleaned then")
True(Messages(ChatFrame1):find("psst", 1, true) ~= nil, "whispers kept, with Hide whispers off")
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing wrong")

-- CVars: each tick its own, never in combat -------------------------------------------------------------------------------

Game(nil)
P:SetPrivate(true)
P:Set("bubbles", false)
Equal(H.cvars.chatBubbles .. H.cvars.chatBubblesParty .. " " .. H.cvars.showTimestamps, "11 none", "bubbles unticked: theirs back")
P:Set("bubbles", true)
P:Set("timestamps", false)
Equal(H.cvars.chatBubbles .. H.cvars.chatBubblesParty .. " " .. H.cvars.showTimestamps, "00 %H:%M ", "timestamps unticked: theirs back")
P:SetPrivate(false)
H.Combat(true)
P:SetPrivate(true)
Equal(H.cvars.chatBubbles, "1", "in combat: waits")
H.Combat(false)
Equal(H.cvars.chatBubbles, "0", "until it ends")
P:SetPrivate(false)
Equal(H.cvars.chatBubbles, "1", "and back")
Equal(H.Problems(), "", "no CVar changed in combat")

-- A /reload while private: back on, and still working ----------------------------------------------------------------------

Game({ wasOn = true }, { reload = true })
Equal(P:Private(), true, "on after the /reload")
Event(ChatFrame1, "CHAT_MSG_SAY", Msg("hi", "Brannoc Stonehelm", BRANNOC))
Equal(Last(ChatFrame1), "|Hplayer:Brannoc Stonehelm|h[" .. Label("WARRIOR") .. "]|h: hi", "swapping")
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing wrong after a /reload")

-- For screenshots, in a dungeon: nothing that can't be put back ---------------------------------------------------------------

Game({ mode = "shots" })
Locked(ChatFrame1)
Event(ChatFrame1, "CHAT_MSG_SAY", Msg("hi Zriel", "Brannoc Stonehelm", BRANNOC))
H.Screenshot("start")
Equal(P:Private(), true, "a screenshot turns it on")
True(rawequal(History(ChatFrame1)[1][1], SECRET), "a locked line already in chat is left")
Locked(ChatFrame1)
True(rawequal(Last(ChatFrame1), SECRET) and rawequal(History(ChatFrame1)[1][1], SECRET), "and one arriving during it")
H.Screenshot("done")
Equal(P:Private(), false, "off straight after")
Equal(Count(ChatFrame1), 3, "every line still there")
Equal(History(ChatFrame1)[2][1], "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h: hi Zriel", "as it was")
True(rawequal(History(ChatFrame1)[3][1], SECRET), "the locked ones too: chat history survives every screenshot")
P:Set("cleanOld", true)
H.Screenshot("start")
Equal(History(ChatFrame1)[1][1], "[Party] (hidden)", "with Clean lines already in chat ticked, you asked for it: hidden")
H.Screenshot("done")
Equal(H.Problems(), "", "nothing wrong with screenshots")

-- Only Hide whispers ticked: a whisper's own new window -------------------------------------------------------------------------

Game({ whispers = true, chatNames = false, channels = false, instChat = "leave" })
P:SetPrivate(true)
local popout = H.Blizzard(FCF_OpenTemporaryWindow, "WHISPER", "Brannoc Stonehelm")
Locked(popout, "CHAT_MSG_WHISPER")
Equal(Count(popout), 0, "the game sends the locked whisper into its new window: taken out there too")
-- If the game's resend skips the window's hooks, it goes a moment later.
H.Blizzard(function() popout:AddMessage(SECRET, 1, 1, 1, 1, 0, 0, "CHAT_MSG_WHISPER") end)
Equal(Count(popout), 1, "a locked whisper the hook didn't see...")
H.RunTimers()
Equal(Count(popout), 0, "...taken out a moment later")
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing wrong")

-- The guild message of the day (printed with no chat event) ------------------------------------------------------------------

Game(nil)
Event(ChatFrame1, "GUILD_MOTD", "Raid at 8, ask Brannoc")
Equal(Last(ChatFrame1), "Guild Message of the Day: Raid at 8, ask Brannoc", "off: the game's message of the day")
P:SetPrivate(true)
Equal(Last(ChatFrame1), "Guild Message of the Day: (hidden)", "on, with guild news ticked: the one in chat hidden")
Event(ChatFrame1, "GUILD_MOTD", "Officers: new rules")
Equal(Last(ChatFrame1), "Guild Message of the Day: (hidden)", "a new one hidden as it arrives")
P:Set("news", false)
Event(ChatFrame1, "GUILD_MOTD", "Bank is open")
Equal(Last(ChatFrame1), "Guild Message of the Day: Bank is open", "news unticked: shown")
P:Set("news", true)
P:SetPrivate(false)
Event(ChatFrame1, "GUILD_MOTD", "See you tonight")
Equal(Last(ChatFrame1), "Guild Message of the Day: See you tonight", "off: shown")
Equal(History(ChatFrame1)[1][1], "Guild Message of the Day: (hidden)", "the hidden ones stay hidden (one way)")
Equal(H.Problems(), "", "nothing wrong")

-- One step failing never stops the rest ----------------------------------------------------------------------------------------

Game(nil)
rawset(ChatFrame1, "HookScript", function() error("the chat frame broke") end)
P:SetPrivate(true)
Equal(H.cvars.chatBubbles .. " " .. H.cvars.showTimestamps, "0 none", "bubbles and timestamps off although a chat frame failed first")
Event(ChatFrame2, "CHAT_MSG_SAY", Msg("hi", "Brannoc Stonehelm", BRANNOC))
Equal(Last(ChatFrame2), "|Hplayer:Brannoc Stonehelm|h[" .. Label("WARRIOR") .. "]|h: hi", "names still swapped")
Equal(#H.printed, 1, "the error said once")
True(H.printed[1]:find("The Chat part hit an error", 1, true), "as the Chat part's")
H.Clear()
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing else wrong")

-- A bare game: none of the chat stand-ins, nothing goes wrong ----------------------------------------------------------------

Clear()
H.Environment()
P = H.Load({ cleanOld = true, whispers = true })
P:SetPrivate(true)
P:Set("instChat", "chat")
P:Set("nameStyle", "player")
P:Set("cleanOld", false)
P:Set("cleanOld", true)
P:SetPrivate(false)
Equal(H.Writes(), 0, "nothing of Blizzard's touched")
Equal(H.Problems(), "", "no violation, error or print")

io.stdout:write("TestChat: " .. H.checks .. " checks passed\n")
