-- Names: what a name becomes while private mode is on. Every module asks
-- here, so the whole addon agrees: you (your typed name, or the name style),
-- other players (their class name in its colour, "Player", or blank), pets
-- ("Pet") and NPCs (left alone). Forever names are "First Surname" with no
-- realm, and UnitName gives the two parts apart, so both forms count as
-- yours. While private, the names of your group, guild and friends are
-- noted (never saved) so names that only turn up as words in text can be
-- swapped too. Nothing here ever reads, compares or joins a secret.
local _, P = ...

local IsSecret = P.IsSecret
local PLAYER, PET = "Player", "Pet"
local GREY = { .78, .78, .78 }
-- For a client without the game's list of class names.
local ENGLISH = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid", DEATHKNIGHT = "Death Knight",
    MONK = "Monk", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}

local function Text(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

-- Classes and colours ---------------------------------------------------------------------

function P:ClassName(classFile)
    classFile = Text(classFile)
    if not classFile then return nil end
    local list = LOCALIZED_CLASS_NAMES_MALE
    local name = type(list) == "table" and Text(list[classFile])
    return name or ENGLISH[classFile]
end

function P:ClassColour(classFile)
    classFile = Text(classFile)
    local colours = RAID_CLASS_COLORS
    local colour = classFile and type(colours) == "table" and colours[classFile]
    if type(colour) ~= "table" or type(colour.r) ~= "number" then return nil end
    return colour.r, colour.g, colour.b
end

local function Byte(v)
    return math.floor(math.max(0, math.min(1, v or 1)) * 255 + .5)
end

-- A label wrapped in its colour, for text; a blank label stays blank.
function P:Colourise(label, r, g, b)
    if type(label) ~= "string" or label == "" or not r then return label end
    return ("|cff%02x%02x%02x%s|r"):format(Byte(r), Byte(g), Byte(b), label)
end

-- Labels -----------------------------------------------------------------------------------
-- Each returns the label and its colour (r, g, b). A blank label ("") is
-- the Hidden style.

-- Someone else, by class file (nil when unknown): the name style decides.
function P:StyleLabel(classFile)
    local style = P:Get("nameStyle")
    if style == "hidden" then return "", 1, 1, 1 end
    local name = style == "class" and P:ClassName(classFile)
    if not name then return PLAYER, GREY[1], GREY[2], GREY[3] end
    local r, g, b = P:ClassColour(classFile)
    return name, r or 1, g or 1, b or 1
end

function P:PetLabel()
    if P:Get("nameStyle") == "hidden" then return "", 1, 1, 1 end
    return PET, GREY[1], GREY[2], GREY[3]
end

local function UnitClassFile(unit)
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classFile = pcall(UnitClass, unit)
    if not ok then return nil end
    return Text(classFile)
end

-- The colour chosen for your typed name ("Name colour"), or nothing for the
-- game's own: each place then keeps the colour the game gives it.
local function MyColour()
    local choice = P:Get("myColour")
    if choice == "accent" then return P.ACCENT[1], P.ACCENT[2], P.ACCENT[3] end
    if choice == "white" then return 1, 1, 1 end
    if choice == "class" then return P:ClassColour(UnitClassFile("player")) end
    return nil
end

-- You: the name typed in "Your name becomes", in its chosen colour (none for
-- the game's own), or else the name style with your own class.
function P:MyLabel()
    local alias = P:Get("myName")
    if type(alias) == "string" and alias ~= "" then return alias, MyColour() end
    return P:StyleLabel(UnitClassFile("player"))
end

-- Your made-up BattleTag ("Your BattleTag becomes") in the same Name colour
-- as your typed name (none for the game's own), or nil when none is typed.
-- Only where your own BattleTag shows (the friends windows' headers).
function P:MyTag()
    local tag = P:Get("myTag")
    if type(tag) ~= "string" or tag == "" then return nil end
    return tag, MyColour()
end

-- Your first name and your full name ("First Surname"; just the first
-- name when there's no surname), or nil while the game won't say.
function P:MyNames()
    if type(UnitName) ~= "function" then return nil, nil end
    local ok, first, surname = pcall(UnitName, "player")
    first = ok and Text(first)
    if not first then return nil, nil end
    surname = Text(surname)
    if not surname then return first, first end
    return first, first .. " " .. surname
end

-- Whether text is your name: your first name or your full name. Never true
-- for a secret.
function P:IsMyName(text)
    text = Text(text)
    if not text then return false end
    local first, full = P:MyNames()
    return text == first or text == full
end

-- Asks the game something about a unit: the answer, nil if it failed, or
-- SECRET if it's a secret.
local SECRET = {}
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    if IsSecret(value) then return SECRET end
    return value
end

-- What a unit's name becomes: you (your label), another player (the style
-- with their class; "Player" when the class is secret or unknown), a pet or
-- other player-controlled unit ("Pet"), or nil for an NPC, meaning leave it.
-- Returns the label and its colour.
function P:NameFor(unit)
    if IsSecret(unit) or type(unit) ~= "string" or unit == "" then return nil end
    if unit == "player" then return P:MyLabel() end
    local isPlayer = Ask(UnitIsPlayer, unit)
    -- Can't tell: hide it, to be safe.
    if isPlayer == SECRET then return P:StyleLabel(nil) end
    if not isPlayer then
        local controlled = Ask(UnitPlayerControlled, unit)
        if controlled and controlled ~= SECRET then return P:PetLabel() end
        return nil
    end
    local me = Ask(UnitIsUnit, unit, "player")
    if me and me ~= SECRET then return P:MyLabel() end
    return P:StyleLabel(UnitClassFile(unit))
end

-- What a player's name becomes from their GUID (a chat sender's, say).
function P:LabelForGUID(guid)
    guid = Text(guid)
    if not guid then return P:StyleLabel(nil) end
    local mine = Ask(UnitGUID, "player")
    if mine ~= SECRET and mine == guid then return P:MyLabel() end
    if type(GetPlayerInfoByGUID) ~= "function" then return P:StyleLabel(nil) end
    local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)
    return P:StyleLabel(ok and Text(classFile) or nil)
end

-- Names seen as text ------------------------------------------------------------------------

local known = {} -- full name: class file, or false when unknown
local byFirst = {} -- first name: { [surname, or "" for none] = full name }
-- Your current group's full names: theirs (like yours) are swapped from the
-- first name alone anywhere. Anyone else's first name alone only inside a
-- sentence, never starting one, so a guildmate called "Will Ashford" never
-- turns "Will you tank?" into "Mage you tank?".
local grouped = {}

local function Split(name)
    local first, surname = name:match("^(%S+) (.+)$")
    if first then return first, surname end
    return name, ""
end

-- Notes a player's name (and class file, if known) for swapping in text.
-- Kept for the session only, and never for your own name. Returns the name
-- as noted.
function P:Learn(name, classFile)
    name = Text(name)
    if not name then return end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    -- A realm on the end ("Name-Realm"), from a client that adds one.
    if not name:find(" ", 1, true) then name = name:gsub("%-.*$", "") end
    if name == "" or name == UNKNOWNOBJECT or P:IsMyName(name) then return end
    classFile = Text(classFile)
    known[name] = classFile or known[name] or false
    local first, surname = Split(name)
    byFirst[first] = byFirst[first] or {}
    byFirst[first][surname] = name
    return name
end

-- The class file noted for a name, if any.
function P:ClassOf(name)
    name = Text(name)
    return name and known[name] or nil
end

-- What a name seen as text becomes: yours, or someone else's by class
-- (given, else noted, else unknown).
function P:LabelForName(name, classFile)
    if P:IsMyName(name) then return P:MyLabel() end
    classFile = Text(classFile) or P:ClassOf(name)
    return P:StyleLabel(classFile)
end

local WORD_START = "^[%a\128-\255]"

local function Label(full, isMe, me, colour)
    if isMe and me then return me end
    local label, r, g, b
    if isMe then
        label, r, g, b = P:MyLabel()
    else
        label, r, g, b = P:LabelForName(full)
    end
    if colour then return P:Colourise(label, r, g, b) end
    return label
end

-- The full name a word starts (word, then " Surname"), and where it ends.
local function FullAt(seg, e, entry)
    for surname, name in pairs(entry) do
        if surname ~= "" then
            local tail = e + 1 + #surname
            if seg:sub(e + 1, tail) == " " .. surname and not seg:find(WORD_START, tail + 1) then return name, tail end
        end
    end
end

-- Whether the word at s starts a sentence (or a line, or the text).
local function SentenceStart(seg, s)
    local before = seg:sub(1, s - 1)
    local trimmed = before:gsub("[%s\"'%(%[]+$", "")
    if trimmed == "" or before:find("\n", #trimmed + 1, true) then return true end
    return trimmed:find("[%.!%?]$") ~= nil
end

-- Whose name a first name alone (the word at s) stands for: someone noted
-- with no surname (that is their whole name), someone in your group, or
-- anyone else noted when the word doesn't start a sentence.
local function FirstOnly(entry, seg, s)
    if entry[""] then return entry[""] end
    for _, name in pairs(entry) do
        if grouped[name] then return name end
    end
    if not SentenceStart(seg, s) then return select(2, next(entry)) end
end

-- Swaps names in plain text (no escape codes in it).
local function SwapPlain(seg, me, colour, myFirst, mySurname)
    local out, pos, changed = {}, 1, false
    while true do
        local s, e = seg:find("[%a\128-\255]+", pos)
        if not s then break end
        local word = seg:sub(s, e)
        local entry = byFirst[word]
        local full, stop, isMe
        if entry then full, stop = FullAt(seg, e, entry) end
        if not stop and word == myFirst then
            isMe, stop = true, e
            if mySurname then
                local tail = e + 1 + #mySurname
                if seg:sub(e + 1, tail) == " " .. mySurname and not seg:find(WORD_START, tail + 1) then stop = tail end
            end
        end
        if not stop and entry then
            full = FirstOnly(entry, seg, s)
            if full then stop = e end
        end
        if stop then
            out[#out + 1] = seg:sub(pos, s - 1)
            out[#out + 1] = Label(full, isMe, me, colour)
            pos, changed = stop + 1, true
        else
            out[#out + 1] = seg:sub(pos, e)
            pos = e + 1
        end
    end
    if not changed then return seg, false end
    out[#out + 1] = seg:sub(pos)
    return table.concat(out), true
end

-- Where an escape code that starts at bar ends. Links keep their data (so
-- whispering a name still works), and textures, atlases, colours and
-- Battle.net names are left as they are.
local CLOSERS = { H = "|h", T = "|t", A = "|a", K = "|k" }
local function EscapeEnd(text, bar)
    local code = text:sub(bar + 1, bar + 1)
    local closer = CLOSERS[code]
    if closer then
        local close = text:find(closer, bar + 2, true)
        return close and close + 1 or #text
    end
    if code == "c" then
        if text:sub(bar + 2, bar + 2) == "n" then return text:find(":", bar + 3, true) or #text end
        return math.min(#text, bar + 9)
    end
    return math.min(#text, bar + 1)
end

-- Swaps every name it knows in text: yours (full name first, then your
-- first name) and every noted name, as whole words only, never inside a
-- link's data or an escape code. me: words for you instead of your label
-- (quest text's "adventurer", say). colour: wrap labels in their colour.
-- Returns the text and whether it changed. A secret comes back untouched.
function P:ReplaceNames(text, me, colour)
    if IsSecret(text) or type(text) ~= "string" or text == "" then return text, false end
    local myFirst, myFull = P:MyNames()
    if not myFirst and next(byFirst) == nil then return text, false end
    local mySurname = myFull and myFull ~= myFirst and myFull:sub(#myFirst + 2) or nil
    local out, i, n, changed = {}, 1, #text, false
    while i <= n do
        local bar = text:find("|", i, true)
        local stop = bar and bar - 1 or n
        if stop >= i then
            local seg, did = SwapPlain(text:sub(i, stop), me, colour, myFirst, mySurname)
            out[#out + 1] = seg
            changed = changed or did
        end
        if not bar then break end
        local last = EscapeEnd(text, bar)
        out[#out + 1] = text:sub(bar, last)
        i = last + 1
    end
    if not changed then return text, false end
    return table.concat(out), true
end

-- Noting names while private ---------------------------------------------------------------------

local Names = P:Module("Names")
local watcher, guildDue = nil, false

local function LearnUnit(unit)
    if type(UnitName) ~= "function" then return end
    local ok, first, surname = pcall(UnitName, unit)
    first = ok and Text(first)
    if not first then return end
    surname = Text(surname)
    return P:Learn(surname and (first .. " " .. surname) or first, UnitClassFile(unit))
end

local function LearnMember(unit)
    local name = LearnUnit(unit)
    if name then grouped[name] = true end
end

-- Your group as it is now (and who's in it, for first names alone).
local function ScanGroup()
    for name in pairs(grouped) do grouped[name] = nil end
    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers()
        if IsSecret(count) or type(count) ~= "number" then return end
        for i = 1, count do LearnMember("raid" .. i) end
    else
        for i = 1, 4 do LearnMember("party" .. i) end
    end
end

local function ScanGuild()
    guildDue = false
    if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
    local count = GetNumGuildMembers()
    if IsSecret(count) or type(count) ~= "number" then return end
    for i = 1, count do
        local ok, name, _, _, _, _, _, _, _, _, _, classFile = pcall(GetGuildRosterInfo, i)
        if ok then P:Learn(name, classFile) end
    end
end

-- The game's class names, back to class files (friends come with names).
local function ClassFileFromName(className)
    className = Text(className)
    if not className then return nil end
    for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE, ENGLISH }) do
        if type(list) == "table" then
            for classFile, name in pairs(list) do
                if name == className then return classFile end
            end
        end
    end
end

local function ScanFriends()
    local list = C_FriendList
    if not (list and list.GetNumFriends and list.GetFriendInfoByIndex) then return end
    local count = list.GetNumFriends()
    if IsSecret(count) or type(count) ~= "number" then return end
    for i = 1, count do
        local ok, info = pcall(list.GetFriendInfoByIndex, i)
        if ok and type(info) == "table" then P:Learn(info.name, ClassFileFromName(info.className)) end
    end
end

local OnEvent = P:Guard(Names, function(_, event)
    if not P:Private() then return end
    if event == "GROUP_ROSTER_UPDATE" then
        ScanGroup()
    elseif event == "GUILD_ROSTER_UPDATE" then
        -- It can come often: a scan at most every two seconds.
        if not guildDue then
            guildDue = true
            C_Timer.After(2, P:Guard(Names, function() if P:Private() then ScanGuild() else guildDue = false end end))
        end
    elseif event == "FRIENDLIST_UPDATE" then
        ScanFriends()
    end
end)

function Names:Apply(on, key)
    if key then return end
    if on then
        if not watcher then
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnEvent", OnEvent)
        end
        watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
        watcher:RegisterEvent("GUILD_ROSTER_UPDATE")
        watcher:RegisterEvent("FRIENDLIST_UPDATE")
        ScanGroup()
        ScanGuild()
        ScanFriends()
    elseif watcher then
        watcher:UnregisterAllEvents()
    end
end
