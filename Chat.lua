-- Chat: names and giveaways in chat. Owns chatNames, publicChannels,
-- instChat, whispers, cleanOld, channels, timestamps and bubbles. It also
-- does the chat side of rows owned elsewhere: loot and roll lines follow the
-- loot tick, ready check lines follow chatNames, as the readyCheck row says,
-- the guild message of the day in chat follows the news tick, and Battle.net
-- "came online" lines follow chatNames or bnToasts.
--
-- How, from Forever's own chat code (the feasibility notes):
-- - Sender names: Blizzard's sender name filter. The link keeps the real
--   name, so whisper, invite and reply still work.
-- - Names in text, system, loot and roll lines, channel names, whispers and
--   Battle.net lines: message event filters, added when private mode turns
--   on and taken away when it turns off.
-- - Dungeons, raids and battlegrounds: the game makes those lines secret and
--   skips every addon filter, so a hook after each chat frame's OnEvent
--   swaps each locked line for "(hidden)" (Hide names) or takes it out (Hide
--   chat), through the frame's own TransformMessages and
--   RemoveMessagesByPredicate; Hide whispers takes locked whispers out
--   whatever the choice. Only issecretvalue is ever asked of those lines.
-- - Lines already in chat (cleanOld): the same two, when private mode turns
--   on, and only with cleanOld ticked. One way: they don't come back. While
--   private mode is on just for a screenshot, nothing one-way happens at all.
-- - Public channels (publicChannels): in General, Trade and LookingForGroup,
--   told apart by the game's own channel id or base name in the event's
--   values (never by the name shown), other players' names are left as the
--   game sends them, new lines and old; your own name is still swapped.
-- - The edit box header ("Tell Name:", your name on /e, "[1. General -
--   Zone]:"): a post-hook on each header's SetFormattedText, so the box
--   measures our text. Whisper tabs: post-hooks on the floating chat frame
--   functions that name them.
-- - Timestamps and bubbles: CVars, through P:SetCVar.
local _, P = ...

local M = P:Module("Chat")

local IsSecret = P.IsSecret
local HIDDEN = "(hidden)"
local WHISPER = "Whisper"
local LOCAL_DEFENCE = "LocalDefense" -- the game's channel name

-- Events -------------------------------------------------------------------------------------

local function Events(list, value, into)
    into = into or {}
    for _, kind in ipairs(list) do into["CHAT_MSG_" .. kind] = value end
    return into
end

-- Players talking: the sender name filter gives these their label.
local SPEAKERS = Events({ "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
    "CHANNEL", "AFK", "DND", "COMMUNITIES_CHANNEL", "ACHIEVEMENT", "GUILD_ACHIEVEMENT", "GUILD_ITEM_LOOTED" }, true)

-- Whispers and what comes with them, hidden by the whispers tick.
local WHISPERS = Events({ "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM", "AFK", "DND",
    "BN_WHISPER_PLAYER_OFFLINE" }, true)

-- Battle.net lines that name a friend.
local NAMED_TOASTS = { FRIEND_ONLINE = true, FRIEND_OFFLINE = true, FRIEND_REMOVED = true, BATTLETAG_FRIEND_REMOVED = true }

-- What a locked line says instead, by its chat type.
local TAGS = Events({ "SAY" }, "Say")
Events({ "YELL" }, "Yell", TAGS)
Events({ "EMOTE", "TEXT_EMOTE" }, "Emote", TAGS)
Events({ "PARTY", "PARTY_LEADER" }, "Party", TAGS)
Events({ "RAID", "RAID_LEADER" }, "Raid", TAGS)
Events({ "RAID_WARNING" }, "Raid Warning", TAGS)
Events({ "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }, "Instance", TAGS)
Events({ "GUILD" }, "Guild", TAGS)
Events({ "OFFICER" }, "Officer", TAGS)
Events({ "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM" }, WHISPER, TAGS)
Events({ "CHANNEL" }, "Channel", TAGS)

-- The game's lines that name players: the global string that makes each,
-- and which of its values are names (list: a list of names).
local TEMPLATES = {
    { "ERR_JOINED_GROUP_S", 1 }, { "ERR_LEFT_GROUP_S", 1 }, { "ERR_RAID_MEMBER_ADDED_S", 1 }, { "ERR_RAID_MEMBER_REMOVED_S", 1 },
    { "ERR_NEW_LEADER_S", 1 }, { "ERR_INVITE_PLAYER_S", 1 }, { "ERR_DECLINE_GROUP_S", 1 }, { "ERR_ALREADY_IN_GROUP_S", 1 },
    { "ERR_FRIEND_OFFLINE_S", 1 }, { "ERR_FRIEND_ADDED_S", 1 }, { "ERR_FRIEND_REMOVED_S", 1 }, { "ERR_IGNORE_ADDED_S", 1 },
    { "ERR_IGNORE_REMOVED_S", 1 }, { "ERR_CHAT_PLAYER_NOT_FOUND_S", 1 }, { "ERR_GUILD_JOIN_S", 1 }, { "ERR_GUILD_LEAVE_S", 1 },
    { "ERR_GUILD_REMOVE_SS", 1, 2 }, { "ERR_GUILD_PROMOTE_SSS", 1, 2 }, { "ERR_GUILD_DEMOTE_SSS", 1, 2 },
    { "ERR_GUILD_LEADER_CHANGED_SS", 1, 2 }, { "ERR_GUILD_INVITE_S", 1 }, { "ERR_GUILD_DECLINE_S", 1 }, { "ERR_BG_PLAYER_LEFT_S", 1 },
    { "ERR_RAID_LEADER_READY_CHECK_START_S", 1 }, { "RAID_MEMBER_NOT_READY", 1 }, { "RAID_MEMBERS_AFK", list = 1 },
    { "RANDOM_ROLL_RESULT", 1 }, { "DUEL_WINNER_KNOCKOUT", 1, 2 }, { "DUEL_WINNER_RETREAT", 1, 2 },
    { "TRADESKILL_LOG_THIRDPERSON", 1 }, { "OPEN_LOCK_OTHER", 1 }, { "COMBATLOG_HONORGAIN", 1 }, { "COMBATLOG_HONORGAIN_NO_RANK", 1 },
    { "LOOT_ITEM", 1 }, { "LOOT_ITEM_MULTIPLE", 1 }, { "LOOT_ITEM_PUSHED", 1 }, { "LOOT_ITEM_PUSHED_MULTIPLE", 1 },
    { "CREATED_ITEM", 1 }, { "CREATED_ITEM_MULTIPLE", 1 }, { "LOOT_ROLL_NEED", 1 }, { "LOOT_ROLL_GREED", 1 },
    { "LOOT_ROLL_DISENCHANT", 1 }, { "LOOT_ROLL_PASSED", 1 }, { "LOOT_ROLL_PASSED_AUTO", 1 }, { "LOOT_ROLL_PASSED_AUTO_FEMALE", 1 },
    { "LOOT_ROLL_WON", 1 }, { "LOOT_ROLL_ROLLED_NEED", 3 }, { "LOOT_ROLL_ROLLED_GREED", 3 }, { "LOOT_ROLL_ROLLED_DE", 3 },
    { "LOOT_ROLL_WON_NO_SPAM_NEED", 1 }, { "LOOT_ROLL_WON_NO_SPAM_GREED", 1 }, { "LOOT_ROLL_WON_NO_SPAM_DE", 1 },
}

-- Small helpers ------------------------------------------------------------------------------

-- A plain string the addon may read, else nil.
local function Text(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

-- A method's answer, or nil when there's none, it fails or it's a secret.
local function Ask(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if not ok or IsSecret(value) then return nil end
    return value
end

-- A field Blizzard keeps on one of its frames, only read.
local function Field(object, key)
    local value = object[key]
    if IsSecret(value) then return nil end
    return value
end

-- The global named after an object, plus a suffix ("ChatFrame1" .. "Tab").
local function Named(object, suffix)
    local name = Ask(object, "GetName")
    if type(name) ~= "string" then return nil end
    return _G[name .. suffix]
end

local function Format(fmt, fallback, ...)
    if type(fmt) ~= "string" or IsSecret(fmt) then fmt = fallback end
    local ok, text = pcall(string.format, fmt, ...)
    if ok then return text end
    return (string.format(fallback, ...))
end

-- Labels ---------------------------------------------------------------------------------------
-- In chat text, labels come in their colour and never hold a "%": some of
-- the game's lines are format strings, and an emote's link is a gsub's
-- replacement.

local function Coloured(label, r, g, b)
    return P:Colourise((tostring(label or ""):gsub("%%", "")), r, g, b)
end

-- Your label. In the game's own colour there's none of ours: the line's own
-- colour shows, or, for the sender's name (decorated: as the game coloured
-- it, class colours in chat), the colour the game gave your name.
local function MyText(decorated)
    local label, r, g, b = P:MyLabel()
    label = Coloured(label, r, g, b)
    if r or label == "" then return label end
    decorated = Text(decorated)
    local code = decorated and (decorated:match("|c%x%x%x%x%x%x%x%x") or decorated:match("|cn[^:|]+:"))
    if code then return code .. label .. "|r" end
    return label
end

-- A Battle.net friend (the game never lets an addon read their name).
local function FriendText()
    return Coloured(P:StyleLabel(nil))
end

-- The class of someone in your group by name, if they are.
local function GroupClass(name)
    local raid = IsInRaid and IsInRaid()
    if IsSecret(raid) then return nil end
    local unit, count = raid and "raid" or "party", raid and 40 or 4
    for i = 1, count do
        local ok, first, surname = pcall(UnitName, unit .. i)
        first = ok and Text(first)
        if first then
            surname = Text(surname)
            if first == name or (surname and first .. " " .. surname == name) then
                local found, _, classFile = pcall(UnitClass, unit .. i)
                return found and Text(classFile) or nil
            end
        end
    end
end

local function ClassFor(name)
    return P:ClassOf(name) or GroupClass(name)
end

-- What a name in chat text becomes. learn: note it, for names the game
-- itself says are players (a player link).
local function LabelFor(name, learn)
    if P:IsMyName(name) then return MyText() end
    local classFile = ClassFor(name)
    if learn then P:Learn(name, classFile) end
    return Coloured(P:StyleLabel(classFile))
end

-- The same with no colour, for a name the game puts into a link itself.
local function PlainLabel(name)
    if P:IsMyName(name) then return (P:MyLabel():gsub("%%", "")) end
    return (P:StyleLabel(ClassFor(name)))
end

-- Whether a value caught by a template looks like a name: one or two
-- capitalised words (Forever names are "First Surname").
local function Plausible(name)
    if type(name) ~= "string" or #name > 48 then return false end
    return name:find("^[%u\128-\255][^%s|]*$") ~= nil or name:find("^[%u\128-\255][^%s|]* [%u\128-\255][^%s|]*$") ~= nil
end

local function Delimiter()
    local delimiter = PLAYER_LIST_DELIMITER
    if type(delimiter) ~= "string" or IsSecret(delimiter) or delimiter == "" then return ", " end
    return delimiter
end

-- "Name, *Name, Name": each name swapped (mineOnly: yours alone), marks kept.
local function SwapList(list, mineOnly)
    local delimiter, parts, start = Delimiter(), {}, 1
    repeat
        local s, e = list:find(delimiter, start, true)
        local entry = list:sub(start, s and s - 1 or #list)
        local lead, mark, name, tail = entry:match("^(%s*)([%*@%+]*)(.-)(%s*)$")
        if Plausible(name) and (not mineOnly or P:IsMyName(name)) then entry = lead .. mark .. LabelFor(name) .. tail end
        parts[#parts + 1] = entry
        start = e and e + 1
    until not s
    return table.concat(parts, delimiter)
end

-- The game's own lines -------------------------------------------------------------------------
-- Each template becomes an anchored pattern with a position capture around
-- every value, so the names can be cut out and labelled.

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local compiled -- the templates as patterns, the most specific first

local function ToPattern(fmt)
    local parts, order, literal, auto, i = { "^" }, {}, 0, 0, 1
    while i <= #fmt do
        local s, e, position, kind = fmt:find("^%%(%d+)%$[%-%d%.]*(%a)", i)
        if not s then s, e, kind = fmt:find("^%%[%-%d%.]*([%a%%])", i) end
        if s then
            if kind == "%" then
                parts[#parts + 1] = "%%"
            else
                if not position then auto = auto + 1 end
                order[#order + 1] = tonumber(position) or auto
                parts[#parts + 1] = "()(.-)()"
            end
            i = e + 1
        else
            local c = fmt:sub(i, i)
            parts[#parts + 1] = c:find(MAGIC) and ("%" .. c) or c
            literal, i = literal + 1, i + 1
        end
    end
    if #order == 0 or #order > 10 then return nil end
    parts[#parts + 1] = "$"
    return table.concat(parts), order, literal
end

local function Compile()
    compiled = {}
    for _, entry in ipairs(TEMPLATES) do
        local fmt = Text(_G[entry[1]])
        local pattern, order, literal
        if fmt then pattern, order, literal = ToPattern(fmt) end
        if pattern then
            local names = {}
            for i = 2, #entry do names[entry[i]] = "name" end
            if entry.list then names[entry.list] = "list" end
            compiled[#compiled + 1] = { pattern = pattern, order = order, names = names, weight = literal }
        end
    end
    table.sort(compiled, function(a, b) return a.weight > b.weight end)
end

-- Labels cut into a matched line, last first so the places stay right.
local function Splice(text, caps, template)
    for i = #template.order, 1, -1 do
        local kind = template.names[template.order[i]]
        if kind then
            local s, value, e = caps[i * 3 - 2], caps[i * 3 - 1], caps[i * 3]
            local label
            if kind == "list" then
                if value:find("|", 1, true) then return nil end
                label = SwapList(value)
            elseif Plausible(value) then
                label = LabelFor(value)
            else
                return nil
            end
            text = text:sub(1, s - 1) .. label .. text:sub(e)
        end
    end
    return text
end

local function MatchTemplate(text)
    if not compiled then return nil end
    for _, template in ipairs(compiled) do
        local caps = { text:match(template.pattern) }
        if caps[1] then
            local out = Splice(text, caps, template)
            if out then return out end
        end
    end
end

-- Links and Battle.net names ------------------------------------------------------------------

local function Bracketed(shown, label)
    if shown:sub(1, 1) == "[" and shown:sub(-1) == "]" then return "[" .. label .. "]" end
    return label
end

local function SwapPlayerLink(head, data, shown)
    local name = Text(data:match("^([^:]+)"))
    if not name then return nil end
    return head .. Bracketed(shown, LabelFor(name, true)) .. "|h"
end

local function SwapFriendLink(head, shown)
    return head .. Bracketed(shown, FriendText()) .. "|h"
end

-- A player link shows a label (its data, the real name, is kept);
-- a Battle.net link the friend label.
local function SwapLinks(text)
    text = text:gsub("(|HBN[pP]layer%a*:.-|h)(.-)|h", SwapFriendLink)
    text = text:gsub("(|H[pP]layer%a*:([^|]*)|h)(.-)|h", SwapPlayerLink)
    return text
end

-- Battle.net names (|K...|k) outside a link's data become the friend label.
local function SwapKStrings(text)
    if not text:find("|K", 1, true) then return text end
    local out, i, label = {}, 1, FriendText()
    while true do
        local s = text:find("|[HK]", i)
        if not s then break end
        local closer = text:sub(s + 1, s + 1) == "H" and "|h" or "|k"
        local e = text:find(closer, s + 2, true)
        if not e then break end
        if closer == "|h" then
            out[#out + 1] = text:sub(i, e + 1)
        else
            out[#out + 1] = text:sub(i, s - 1)
            out[#out + 1] = label
        end
        i = e + 2
    end
    out[#out + 1] = text:sub(i)
    return table.concat(out)
end

-- Every name in a line of chat: the game's own lines (templates: asked),
-- player and Battle.net links, the names it knows, Battle.net names.
-- Returns the new text, or nil when nothing changed.
local function SwapChat(text, templates)
    if not Text(text) then return nil end
    local out = templates and MatchTemplate(text) or nil
    local matched = out ~= nil
    out = SwapLinks(out or text)
    if not matched then out = (P:ReplaceNames(out, MyText(), true)) end
    out = SwapKStrings(out)
    if out ~= text then return out end
end

-- A public channel's line: your own name alone, as a player link or in the
-- text (and Battle.net names, which are your friends'); everyone else's is
-- left. Returns the new text, or nil when nothing changed.
local function SwapMyLink(head, data, shown)
    local name = Text(data:match("^([^:]+)"))
    if not name or not P:IsMyName(name) then return nil end
    return head .. Bracketed(shown, MyText()) .. "|h"
end

local function SwapMine(text)
    if not Text(text) then return nil end
    local out = text:gsub("(|HBN[pP]layer%a*:.-|h)(.-)|h", SwapFriendLink)
    out = out:gsub("(|H[pP]layer%a*:([^|]*)|h)(.-)|h", SwapMyLink)
    out = SwapKStrings((P:ReplaceNames(out, MyText(), true, true)))
    if out ~= text then return out end
end

-- Channels ---------------------------------------------------------------------------------------

-- Public channels ("Leave public channels as they are"): General, Trade and
-- LookingForGroup. Told apart by the channel's base name (the event's 9th
-- value), never the name shown. Forever sends the base name with the zone on
-- the end ("General - Darkshore", seen in game 2026-10-11, where its channel
-- id didn't match the game's list), so the part before " - " counts. Only
-- when the game gives no base name, by the channel id (the 7th; the game's
-- list: General 1, Trade 2, LookingForGroup 26 (24 on Classic Era), Trade
-- (Services) 42 (Services 45 on Classic Era), Trade (Local) 46). Custom
-- channels, LocalDefense and every other channel stay private.
local PUBLIC_IDS = { [1] = true, [2] = true, [24] = true, [26] = true, [42] = true, [45] = true, [46] = true }
local PUBLIC_NAMES = { General = true, Trade = true, LookingForGroup = true, ["Trade (Services)"] = true, ["Trade (Local)"] = true }

-- A channel's base name without the zone Forever adds ("General - Darkshore"
-- is "General"), or nil.
local function BaseOf(base)
    base = Text(base)
    return base and (base:match("^(.-) %- ") or base)
end

local function IsPublic(id, base)
    base = BaseOf(base)
    if base then return PUBLIC_NAMES[base] == true end
    if IsSecret(id) then return false end
    return type(id) == "number" and PUBLIC_IDS[id] == true
end

-- Whether a chat event's values are a public channel's, with its tick on.
local function PublicLine(a)
    return P:IsOn("publicChannels") and IsPublic(a[7], a[9])
end

-- "1. General - Elwynn Forest" becomes "1. General" (the number stays: the
-- game needs it). base: the channel's own name, when the game gives it.
local function StripZone(name, base)
    name = Text(name)
    if not name then return nil end
    local prefix, rest = name:match("^(%d+%. )(.+)$")
    if not prefix then return nil end
    base = Text(base)
    local stripped
    if base and rest:sub(1, #base + 3) == base .. " - " then
        stripped = base
    else
        stripped = rest:match("^(.-) %- .+$")
    end
    if not stripped or stripped == "" then return nil end
    return prefix .. stripped
end

-- The same inside lines already printed: "|h[1. General - Zone]|h".
local function StripChannelTags(text)
    return (text:gsub("(|h%[%d+%. [^%]|]-) %- [^%]|]+%]", "%1]"))
end

-- The message filters ------------------------------------------------------------------------------
-- Each route gets the event's values (a) to change in place, and answers
-- "discard", true when it changed something, or nothing.

local function Put(a, i, value)
    if value == nil or (not IsSecret(a[i]) and value == a[i]) then return nil end
    a[i] = value
    return true
end

local function Speech(a)
    if not P:IsOn("chatNames") then return end
    return Put(a, 1, SwapChat(a[1]))
end

-- A /wave: the sender's own name stays in the text, since the game swaps it
-- for their link (which the sender filter labels).
local function Emote(a)
    if not P:IsOn("chatNames") then return end
    local text, sender = Text(a[1]), Text(a[2])
    if not text then return end
    local s, e
    if sender then s, e = text:find(sender, 1, true) end
    if not s then return Put(a, 1, SwapChat(text)) end
    local before, after = text:sub(1, s - 1), text:sub(e + 1)
    return Put(a, 1, (SwapChat(before) or before) .. sender .. (SwapChat(after) or after))
end

local function Lines(a, event)
    if not P:IsOn(event == "CHAT_MSG_LOOT" and "loot" or "chatNames") then return end
    return Put(a, 1, SwapChat(a[1], true))
end

local function Whisper(a, event)
    if P:IsOn("whispers") then return "discard" end
    if event == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then return Lines(a, event) end
    return Speech(a)
end

-- Battle.net "came online" and broadcast lines: the game builds the name
-- from the friend's account, so they can't be renamed, only left out.
local function Toast(a, event)
    if not (P:IsOn("chatNames") or P:IsOn("bnToasts")) then return end
    if event == "CHAT_MSG_BN_INLINE_TOAST_BROADCAST" then return "discard" end
    local kind = Text(a[1])
    if kind and NAMED_TOASTS[kind] then return "discard" end
end

-- A public channel's line (with its tick on): your own name alone.
local function Mine(a)
    if not P:IsOn("chatNames") then return end
    return Put(a, 1, SwapMine(a[1]))
end

local function Channel(a, event)
    local changed
    if P:IsOn("channels") then
        if event == "CHAT_MSG_CHANNEL" and BaseOf(a[9]) == LOCAL_DEFENCE then return "discard" end
        changed = Put(a, 4, StripZone(a[4], a[9]))
    end
    if event == "CHAT_MSG_CHANNEL" then
        local swap = PublicLine(a) and Mine or Speech
        if swap(a) then changed = true end
    end
    return changed
end

-- "[1. General] Name joined": the names are values of their own (in a public
-- channel, with its tick on, only yours).
local function NoticeUser(a)
    local changed = Channel(a, "CHAT_MSG_CHANNEL_NOTICE_USER")
    if P:IsOn("chatNames") then
        local public = PublicLine(a)
        for _, i in ipairs({ 2, 5 }) do
            local name = Text(a[i])
            if name and (not public or P:IsMyName(name)) and Put(a, i, PlainLabel(name)) then changed = true end
        end
    end
    return changed
end

-- /chatlist: a list of names (in a public channel, with its tick on, only
-- yours is swapped).
local function ChannelList(a)
    local changed = Channel(a, "CHAT_MSG_CHANNEL_LIST")
    local list = Text(a[1])
    if list and P:IsOn("chatNames") and Put(a, 1, SwapList(list, PublicLine(a))) then changed = true end
    return changed
end

local function Ignored(a)
    if not P:IsOn("chatNames") then return end
    local name = Text(a[2])
    return name and Put(a, 2, PlainLabel(name))
end

local ROUTES = Events({ "SAY", "YELL", "EMOTE", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT",
    "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "COMMUNITIES_CHANNEL", "GUILD_ITEM_LOOTED", "MONSTER_SAY", "MONSTER_YELL",
    "MONSTER_EMOTE", "MONSTER_WHISPER", "MONSTER_PARTY", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" }, Speech)
Events({ "SYSTEM", "TARGETICONS", "OPENING", "TRADESKILLS", "COMBAT_HONOR_GAIN", "BG_SYSTEM_ALLIANCE", "BG_SYSTEM_HORDE",
    "BG_SYSTEM_NEUTRAL", "LOOT" }, Lines, ROUTES)
for event in pairs(WHISPERS) do ROUTES[event] = Whisper end
Events({ "BN_INLINE_TOAST_ALERT", "BN_INLINE_TOAST_BROADCAST" }, Toast, ROUTES)
Events({ "CHANNEL", "CHANNEL_NOTICE" }, Channel, ROUTES)
Events({ "TEXT_EMOTE" }, Emote, ROUTES)
Events({ "CHANNEL_NOTICE_USER" }, NoticeUser, ROUTES)
Events({ "CHANNEL_LIST" }, ChannelList, ROUTES)
Events({ "IGNORED", "FILTERED" }, Ignored, ROUTES)

-- One filter for every event above: false and every value back when
-- something changed, true to drop the line. The game never calls it with a
-- secret (it skips addon filters then).
local Filter = P:Guard(M, function(_, event, ...)
    if not P:Private() then return end
    local route = not IsSecret(event) and ROUTES[event]
    if not route then return end
    local count = select("#", ...)
    local a = { ... }
    local result = route(a, event)
    if result == "discard" then return true end
    if result then return false, unpack(a, 1, count) end
end)

local function ClassFromGUID(guid)
    guid = Text(guid)
    if not guid or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
    return ok and Text(classFile) or nil
end

local function IsMyGUID(guid)
    guid = Text(guid)
    if not guid or type(UnitGUID) ~= "function" then return false end
    local ok, mine = pcall(UnitGUID, "player")
    return ok and Text(mine) == guid
end

-- The name shown for whoever is talking. The values after the sender are
-- the event's third onwards, so its GUID (the 12th) comes 10th, and its
-- channel id and base name (the 7th and 9th) 5th and 7th. In a public
-- channel, with its tick on, only you are swapped (the others still noted,
-- for their names in lines that stay private).
local SenderFilter = P:Guard(M, function(event, decorated, _, sender, ...)
    if not P:IsOn("chatNames") then return nil end
    if IsSecret(event) or not SPEAKERS[event] then return nil end
    sender = Text(sender)
    if not sender then return nil end
    if event:find("^CHAT_MSG_BN_") then return FriendText() end
    local guid = select(10, ...)
    if P:IsMyName(sender) or IsMyGUID(guid) then return MyText(decorated) end
    local classFile = ClassFromGUID(guid) or ClassFor(sender)
    P:Learn(sender, classFile)
    if event == "CHAT_MSG_CHANNEL" and P:IsOn("publicChannels") and IsPublic((select(5, ...)), (select(7, ...))) then
        return nil
    end
    return Coloured(P:StyleLabel(classFile))
end)

local function AddFilters()
    local util = ChatFrameUtil
    if type(util) ~= "table" then return end
    if type(util.AddMessageEventFilter) == "function" then
        for event in pairs(ROUTES) do util.AddMessageEventFilter(event, Filter) end
    end
    if type(util.AddSenderNameFilter) == "function" then util.AddSenderNameFilter(SenderFilter) end
end

local function RemoveFilters()
    local util = ChatFrameUtil
    if type(util) ~= "table" then return end
    if type(util.RemoveMessageEventFilter) == "function" then
        for event in pairs(ROUTES) do util.RemoveMessageEventFilter(event, Filter) end
    end
    if type(util.RemoveSenderNameFilter) == "function" then util.RemoveSenderNameFilter(SenderFilter) end
end

-- Lines the game locks ------------------------------------------------------------------------------
-- These two run inside the chat frame's own TransformMessages and
-- RemoveMessagesByPredicate; neither reads the line, and the stand-in can't
-- fail (a failed one would leave a hole in the frame's history).

local function IsLocked(message)
    return IsSecret(message)
end

local function StandIn(message, r, g, b, infoID, accessID, typeID, event)
    local tag = not IsSecret(event) and type(event) == "string" and TAGS[event]
    if tag then return "[" .. tag .. "] " .. HIDDEN, r, g, b, infoID, accessID, typeID end
    return HIDDEN, r, g, b, infoID, accessID, typeID
end

-- A locked whisper: Hide whispers takes it out whatever the dungeon choice.
local function IsLockedWhisper(message, _, _, _, _, _, _, event)
    return IsSecret(message) and not IsSecret(event) and type(event) == "string" and WHISPERS[event] == true
end

local function HideLocked(frame)
    if P:IsOn("whispers") and type(frame.RemoveMessagesByPredicate) == "function" then
        frame:RemoveMessagesByPredicate(IsLockedWhisper)
    end
    local mode = P:IsOn("instChat") and P:Get("instChat")
    if mode == "chat" and type(frame.RemoveMessagesByPredicate) == "function" then
        frame:RemoveMessagesByPredicate(IsLocked)
    elseif mode == "names" and type(frame.TransformMessages) == "function" then
        frame:TransformMessages(IsLocked, StandIn)
    end
end

local function HasLocked(frame)
    local count = Ask(frame, "GetNumMessages")
    if type(count) ~= "number" then return false end
    for i = 1, count do
        if IsSecret((frame:GetMessageInfo(i))) then return true end
    end
    return false
end

-- Locked lines already there, when private mode or a setting turns on (only
-- with cleanOld ticked: they don't come back).
local function HideOld(frame)
    if HasLocked(frame) then HideLocked(frame) end
end

local function AnySecret(...)
    for i = 1, select("#", ...) do
        if IsSecret((select(i, ...))) then return true end
    end
    return false
end

-- Whether a change that can't be put back may happen now: never while
-- private mode is on just for a screenshot, unless cleanOld asks for it.
local function OneWayAllowed()
    return not P:ShotOnly() or P:IsOn("cleanOld")
end

-- The guild message of the day ------------------------------------------------------------------------
-- The game prints it straight into chat (at login, and whenever an officer
-- changes it), with no chat event, so no filter sees it. With news ticked
-- the line becomes "Guild Message of the Day: (hidden)". One way.

local function MotdPrefix()
    local template = Text(GUILD_MOTD_TEMPLATE)
    local prefix = template and template:match("^(.-)%%s")
    if prefix and prefix ~= "" then return prefix end
    return "Guild Message of the Day: "
end

-- The hidden line for a message of the day, or nil when it isn't one (or
-- is hidden already).
local function HiddenMotdLine(message)
    local text, prefix = Text(message), MotdPrefix()
    local s = text and text:find(prefix, 1, true)
    if not s then return nil end
    local hidden = text:sub(1, s - 1) .. prefix .. HIDDEN
    if hidden == text then return nil end
    return hidden
end

local motdPending -- what the predicate just worked out, for the transform that follows it
local IsMotd = P:Guard(M, function(message)
    motdPending = HiddenMotdLine(message)
    return motdPending ~= nil
end)

local function HiddenMotd(message, ...)
    local hidden = motdPending
    motdPending = nil
    if type(hidden) ~= "string" then return message, ... end
    return hidden, ...
end

local function HideMotd(frame)
    local count = Ask(frame, "GetNumMessages")
    if type(count) ~= "number" or type(frame.TransformMessages) ~= "function" then return end
    for i = 1, count do
        if HiddenMotdLine((frame:GetMessageInfo(i))) then
            frame:TransformMessages(IsMotd, HiddenMotd)
            return
        end
    end
end

-- Events after which the game may have printed the message of the day.
local MOTD_EVENTS = { GUILD_MOTD = true, UPDATE_CHAT_WINDOWS = true }

-- After each event a chat frame handles: a secret value in a chat event
-- means the line it just printed went past every filter; the message of
-- the day is printed with no chat event at all.
local AfterEvent = P:Guard(M, function(frame, event, ...)
    if not P:Private() or IsSecret(event) or type(event) ~= "string" or not OneWayAllowed() then return end
    if MOTD_EVENTS[event] then
        if P:IsOn("news") then HideMotd(frame) end
        return
    end
    if not (P:IsOn("instChat") or P:IsOn("whispers")) or event:sub(1, 9) ~= "CHAT_MSG_" then return end
    if AnySecret(...) then HideLocked(frame) end
end)

-- Lines already in chat (cleanOld) -------------------------------------------------------------------

-- Whether a line already in chat is a public channel's, with its tick on, by
-- the event and values the game keeps with a player's line (GetMessageInfo's
-- 8th and 9th; only read). Join and /chatlist lines are kept with neither,
-- so an old one is cleaned in full.
local function OldPublic(event, args)
    if not P:IsOn("publicChannels") or IsSecret(event) or IsSecret(args) or type(args) ~= "table" then return false end
    if event ~= "CHAT_MSG_CHANNEL" then return false end
    return IsPublic(Field(args, 7), Field(args, 9))
end

-- public: a public channel's line, so only your own name goes.
local function CleanLine(text, public)
    if P:IsOn("chatNames") then
        local swapped
        if public then swapped = SwapMine(text) else swapped = SwapChat(text) end
        text = swapped or text
    end
    if P:IsOn("channels") then text = StripChannelTags(text) end
    return text
end

local function OldWhisper(_, _, _, _, _, _, _, event)
    return not IsSecret(event) and type(event) == "string" and WHISPERS[event] == true
end

local pending -- what the predicate just worked out, for the transform that follows it
local Changed = P:Guard(M, function(message, _, _, _, _, _, _, event, args)
    pending = nil
    if not Text(message) then return false end
    local clean = CleanLine(message, OldPublic(event, args))
    if clean == message then return false end
    pending = clean
    return true
end)

local function Cleaned(message, ...)
    local clean = pending
    pending = nil
    if type(clean) ~= "string" then return message, ... end
    return clean, ...
end

local function CleanFrame(frame)
    local count = Ask(frame, "GetNumMessages")
    if type(count) ~= "number" then return end
    local whispers, names, hideWhispers = false, false, P:IsOn("whispers")
    for i = 1, count do
        local message, _, _, _, _, _, _, event, args = frame:GetMessageInfo(i)
        if hideWhispers and OldWhisper(message, nil, nil, nil, nil, nil, nil, event) then
            whispers = true
        elseif not names and Text(message) and CleanLine(message, OldPublic(event, args)) ~= message then
            names = true
        end
    end
    if whispers and type(frame.RemoveMessagesByPredicate) == "function" then frame:RemoveMessagesByPredicate(OldWhisper) end
    if names and type(frame.TransformMessages) == "function" then frame:TransformMessages(Changed, Cleaned) end
end

-- The edit box header ----------------------------------------------------------------------------------

local boxOf = {} -- each header hooked: its edit box (kept here, never on Blizzard's frames)

local function ChannelHeader(box)
    local target = Ask(box, "GetChannelTarget")
    if target == nil or type(GetChannelName) ~= "function" then return nil end
    local ok, localID, name, instanceID, community = pcall(GetChannelName, target)
    if not ok or IsSecret(localID) or IsSecret(community) or community then return nil end
    local base = Text(name) and name:match("^(.-) %- .+$")
    if not base or base == "" then return nil end
    if type(instanceID) == "number" and not IsSecret(instanceID) and instanceID > 0 then base = base .. " " .. instanceID end
    return Format(CHAT_CHANNEL_SEND, "[%s. %s]: ", localID, base)
end

-- What the header should say for the box's chat type, and the key it's under.
local function HeaderText(box)
    local kind = Ask(box, "GetChatType")
    if (kind == "WHISPER" or kind == "BN_WHISPER") and P:IsOn("chatNames") then
        local target = kind == "WHISPER" and Text(Ask(box, "GetTellTarget"))
        local label = target and P:LabelForName(target) or P:StyleLabel(nil)
        return Format(kind == "WHISPER" and CHAT_WHISPER_SEND or CHAT_BN_WHISPER_SEND, "Tell %s: ", label), "chatNames"
    elseif kind == "EMOTE" and P:IsOn("chatNames") then
        return Format(CHAT_EMOTE_SEND, "%s ", (P:MyLabel())), "chatNames"
    elseif kind == "CHANNEL" and P:IsOn("channels") then
        return ChannelHeader(box), "channels"
    end
end

local function SwapHeader(header)
    local box = boxOf[header]
    if not box then return end
    local text, key = HeaderText(box)
    if text then P:SwapText(key, header, text) end
end

-- Runs inside the game's UpdateHeader, before it measures the header.
local OnHeader = P:Guard(M, function(header)
    if not (P:IsOn("chatNames") or P:IsOn("channels")) then return end
    SwapHeader(header)
end)

-- Whisper windows ----------------------------------------------------------------------------------------

local function TabKey()
    if P:IsOn("whispers") then return "whispers" end
    if P:IsOn("chatNames") then return "chatNames" end
end

local function IsWhisperWindow(frame)
    local kind = Field(frame, "chatType")
    return kind == "WHISPER" or kind == "BN_WHISPER"
end

local function WindowLabel(frame)
    local target = Field(frame, "chatType") == "WHISPER" and Text(Field(frame, "chatTarget"))
    local label = target and P:LabelForName(target) or P:StyleLabel(nil)
    if label == "" then return WHISPER end
    return label
end

-- One tab or button: a name the game kept secret can't be put back, so it
-- waits for a /reload (temporary windows don't outlast one).
local function SwapWindowText(key, region, label)
    if IsSecret(region:GetText()) then P:NeedsReload(key) end
    P:SwapText(key, region, label)
end

-- A whisper window's tab and minimised button.
local function RelabelWindow(frame)
    local key = TabKey()
    if not key or not IsWhisperWindow(frame) then return end
    local label = WindowLabel(frame)
    local tab, minimised = Named(frame, "Tab"), Named(frame, "Minimized")
    if tab then SwapWindowText(key, tab, label) end
    if minimised then SwapWindowText(key, minimised, label) end
end

local OnWindowName = P:Guard(M, function(frame)
    if not (P:IsOn("whispers") or P:IsOn("chatNames")) then return end
    if type(frame) == "table" then RelabelWindow(frame) end
end)

-- The list of windows past the dock's edge.
local OnOverflow = P:Guard(M, function(button, frame)
    if not (P:IsOn("whispers") or P:IsOn("chatNames")) then return end
    if type(button) ~= "table" or type(frame) ~= "table" or not IsWhisperWindow(frame) then return end
    SwapWindowText(TabKey(), button, WindowLabel(frame))
end)

-- Chat frames ----------------------------------------------------------------------------------------------

local function EachChatFrame(fn)
    local seen = {}
    local function Visit(frame)
        if type(frame) == "table" and not seen[frame] then
            seen[frame] = true
            fn(frame)
        end
    end
    if type(CHAT_FRAMES) == "table" then
        for _, name in pairs(CHAT_FRAMES) do
            if type(name) == "string" then Visit(_G[name]) end
        end
    end
    local constants = type(Constants) == "table" and Constants.ChatFrameConstants
    local count = tonumber(NUM_CHAT_WINDOWS) or (type(constants) == "table" and tonumber(constants.MaxChatWindows)) or 10
    for i = 1, count do Visit(_G["ChatFrame" .. i]) end
end

local hooked = {} -- chat frames already hooked

local function HookFrame(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    if type(frame.HookScript) == "function" then frame:HookScript("OnEvent", AfterEvent) end
    local box = Named(frame, "EditBox")
    local header = box and Named(box, "Header")
    if header and not boxOf[header] and type(header.SetFormattedText) == "function" then
        boxOf[header] = box
        hooksecurefunc(header, "SetFormattedText", OnHeader)
    end
end

-- Locked lines in whisper windows, a moment after one opens.
local SweepWhisperWindows = P:Guard(M, function()
    if not (P:IsOn("instChat") or P:IsOn("whispers")) or not OneWayAllowed() then return end
    EachChatFrame(function(frame)
        if IsWhisperWindow(frame) and HasLocked(frame) then HideLocked(frame) end
    end)
end)

-- A whisper window the game opens later gets the same hooks. The game then
-- sends the whisper that opened it straight into it; a locked one is taken
-- out a moment later, whether or not the window's own event hook saw it.
local OnNewWindow = P:Guard(M, function()
    if not (P:IsOn("instChat") or P:IsOn("whispers") or P:IsOn("chatNames") or P:IsOn("channels")) then return end
    EachChatFrame(HookFrame)
    if (P:IsOn("instChat") or P:IsOn("whispers")) and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, SweepWhisperWindows)
    end
end)

-- What's showing now: whisper tabs and the edit box header.
local function Relabel(frame)
    RelabelWindow(frame)
    local box = Named(frame, "EditBox")
    local header = box and Named(box, "Header")
    if header then SwapHeader(header) end
end

-- CVars -------------------------------------------------------------------------------------------------------

local function SetCVars()
    if P:IsOn("timestamps") then P:SetCVar("timestamps", "showTimestamps", "none") end
    if P:IsOn("bubbles") then
        P:SetCVar("bubbles", "chatBubbles", "0")
        P:SetCVar("bubbles", "chatBubblesParty", "0")
        P:SetCVar("bubbles", "chatBubblesRaid", "0")
    end
end

-- The module -----------------------------------------------------------------------------------------------------

local GLOBAL_HOOKS = { "FCF_SetWindowName", OnWindowName, "FCF_CreateMinimizedFrame", OnWindowName,
    "FCFDockOverflowListButton_SetValue", OnOverflow, "FCF_OpenTemporaryWindow", OnNewWindow }

local RELABEL = { chatNames = true, whispers = true, channels = true, nameStyle = true, myName = true, myColour = true }

-- Each step on its own guard, and each chat frame within it, so one failing
-- never stops the rest.
local function ForEachFrame(fn)
    local guarded = P:Guard(M, fn)
    return P:Guard(M, function() EachChatFrame(guarded) end)
end
local Steps = {
    AddFilters = P:Guard(M, AddFilters), RemoveFilters = P:Guard(M, RemoveFilters), SetCVars = P:Guard(M, SetCVars),
    Hook = ForEachFrame(HookFrame), Relabel = ForEachFrame(Relabel), HideOld = ForEachFrame(HideOld),
    Clean = ForEachFrame(CleanFrame), HideMotd = ForEachFrame(HideMotd),
}

function M:Setup()
    P:Guard(M, Compile)()
    Steps.Hook()
    for i = 1, #GLOBAL_HOOKS, 2 do
        if type(_G[GLOBAL_HOOKS[i]]) == "function" then hooksecurefunc(GLOBAL_HOOKS[i], GLOBAL_HOOKS[i + 1]) end
    end
end

-- Lines already in chat, changed for good: only with cleanOld ticked.
local function CleanOld()
    if not P:IsOn("cleanOld") then return end
    Steps.HideOld()
    Steps.Clean()
end

function M:Apply(on, key)
    if not on then
        Steps.RemoveFilters()
        return
    end
    if key == nil then
        Steps.AddFilters()
        Steps.Hook()
        Steps.SetCVars()
        Steps.Relabel()
        CleanOld()
        if P:IsOn("news") and OneWayAllowed() then Steps.HideMotd() end
    elseif key == "timestamps" or key == "bubbles" then
        Steps.SetCVars()
    elseif key == "instChat" or key == "cleanOld" then
        CleanOld()
    elseif RELABEL[key] then
        Steps.Relabel()
        if key == "whispers" and P:IsOn("whispers") then CleanOld() end
    end
end
