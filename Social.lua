-- Social: friends, guild and the rest of the social windows. Owns friends,
-- bnToasts, whoList, roster, news, guildName, mail, groupFinder and calendar.
--   friends: the friends list (WoW and Battle.net names, their zones), friend
--     requests, the friends hover box (names, notes, broadcasts), your own
--     BattleTag and your broadcast box; in the newer social window too (your
--     BattleTag in its header, with its copy button out of reach, friend and
--     request cards, the broadcast box), and Quick Join and Recruit-A-Friend.
--   bnToasts: the Battle.net pop-ups say "A friend".
--   whoList: /who rows (covered, never rewritten, so right-click still works;
--     your own row's guild hidden, or your made-up guild over it), the
--     ignore and block list, and recent players (both windows).
--   roster: guild roster rows and notes, the member details panel and the
--     guild event log.
--   news: the guild news feed, the message of the day and the guild info text.
--   guildName: your guild's name in the guild window's list (communities
--     too; your guild shows your made-up guild, if typed) and on the
--     inspect window's guild tab. (Guild charters are the Windows module's,
--     under its pop-ups setting.)
--   mail: inbox senders and subjects, the open letter (sender, body, invoice),
--     the To box when sending and its suggestions.
--   groupFinder: leader names in the group finder, its hover box and comments.
--   calendar: invite lists and who made each event.
-- Hooks go in once, the first time private mode turns on (Setup). The few on
-- Blizzard's row mixins go in at load, before any rows are made, because rows
-- copy the mixin's functions when they're made. Every hook returns at once
-- while private mode or its tick is off.
local _, P = ...

local M = P:Module("Social")

local IsSecret = P.IsSecret
local FRIEND, A_FRIEND, REQUEST = "Friend", "A friend", "Friend request"
local GUILD, COMMUNITY = "Guild", "Community"
local BATTLENET, BROADCAST = "Battle.net", "New broadcast"
local MOTD_HIDDEN = "Message of the day hidden"

-- Small helpers ------------------------------------------------------------------------------

-- A value, or nil when it's a secret.
local function Plain(value)
    if IsSecret(value) then return nil end
    return value
end

-- A table's field, or nil when the table or the field is a secret.
local function Field(t, key)
    if IsSecret(t) or type(t) ~= "table" then return nil end
    local value = t[key]
    if IsSecret(value) then return nil end
    return value
end

-- Text that's safe to read: a plain string, else nil.
local function Readable(value)
    value = Plain(value)
    if type(value) ~= "string" then return nil end
    return value
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h, i, j, k, l, m
end

-- A label, in its colour, as text.
local function Coloured(label, r, g, b)
    return P:Colourise(label, r, g, b) or ""
end

-- A class file from the game's class names (friends come with names).
local function ClassFileFromName(className)
    className = Readable(className)
    if not className or className == "" then return nil end
    for _, global in ipairs({ "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE" }) do
        local list = _G[global]
        if type(list) == "table" then
            for classFile, name in pairs(list) do
                if name == className then return classFile end
            end
        end
    end
end

-- A class file from a class ID (guild and recent players come with IDs).
local function ClassFileFromID(classID)
    classID = Plain(classID)
    if type(classID) ~= "number" or not C_CreatureInfo then return nil end
    return Readable(Field(Call(C_CreatureInfo.GetClassInfo, classID), "classFile"))
end

-- A class file from a class colour (the group finder's hover box colours
-- names by class and gives nothing else to go on).
local function ClassFromColour(r, g, b)
    r, g, b = Plain(r), Plain(g), Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or type(RAID_CLASS_COLORS) ~= "table" then return nil end
    for classFile, colour in pairs(RAID_CLASS_COLORS) do
        if type(colour) == "table" and type(colour.r) == "number" and math.abs(colour.r - r) < .01
            and math.abs(colour.g - g) < .01 and math.abs(colour.b - b) < .01 then
            return classFile
        end
    end
end

-- Blizzard's text for a region, kept from the last time the game wrote it,
-- so a label can be worked out again after ours is showing. Nil for a secret.
local seen = setmetatable({}, { __mode = "k" })
local function Base(region)
    local text = region:GetText()
    if IsSecret(text) then
        seen[region] = nil
        return nil
    end
    local s = seen[region]
    if s and s.ours ~= nil and text == s.ours then return s.base end
    seen[region] = { base = text }
    return text
end

-- Swaps a region's text through the core (so it's put back), noting ours.
-- Text already showing is left as it is (so applying twice writes nothing).
-- Things the game itself can leave empty (notes, zones) are hidden with
-- Mask instead, so an empty one is never "put back" as someone else's.
local function Put(key, region, text)
    if not region then return end
    local current = region:GetText()
    if not IsSecret(current) and current == text then return end
    P:SwapText(key, region, text)
    local s = seen[region]
    if s then s.ours = text end
end

-- Swaps the names the core knows in a region's text, if any.
local function PutNames(key, region)
    if not region then return end
    local base = Base(region)
    if not base then return end
    local text, changed = P:ReplaceNames(base, nil, true)
    if changed then Put(key, region, text) end
end

-- Regions hidden by their alpha (notes, zones, free text): never their text,
-- so a row the game reuses can't get someone else's text back. MaskIf hides
-- one for one row only (your own row's zone) and shows it again when the
-- row is reused. And our own text laid over a hidden name the game reads
-- back from the screen (right-click menus, Reply), which is never rewritten.
local covers = setmetatable({}, { __mode = "k" })

local function Uncover(region)
    local cover = region and covers[region]
    if not cover then return end
    if cover.alpha ~= nil then
        region:SetAlpha(cover.alpha)
        cover.alpha = nil
    end
    if cover.frame then cover.frame:Hide() end
end

local function UncoverAll(key)
    for region, cover in pairs(covers) do
        if cover.key == key then Uncover(region) end
    end
end

local function Mask(key, region)
    if not region then return nil end
    local cover = covers[region]
    if not cover then
        cover = {}
        covers[region] = cover
    end
    cover.key = key
    local alpha = region:GetAlpha()
    alpha = (type(alpha) == "number" and not IsSecret(alpha)) and alpha or 1
    if cover.alpha == nil then cover.alpha = alpha end
    if alpha ~= 0 then region:SetAlpha(0) end
    P:OnRestore(key, "covers", function() UncoverAll(key) end)
    return cover
end

-- Mask when it applies (your own row, an online friend), else show it.
local function MaskIf(key, region, hide)
    if hide then Mask(key, region) else Uncover(region) end
end

-- A region's text colour, or nothing when it's a secret.
local function TextColour(region)
    if type(region.GetTextColor) ~= "function" then return nil end
    local r, g, b = region:GetTextColor()
    r, g, b = Plain(r), Plain(g), Plain(b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return r, g, b
end

local function Cover(key, parent, region, label, r, g, b)
    local cover = Mask(key, region)
    if not cover then return end
    if not cover.frame then
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetAllPoints(region)
        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetAllPoints(frame)
        text:SetJustifyH("LEFT")
        local font = region.GetFontObject and region:GetFontObject()
        if font then text:SetFontObject(font) end
        cover.frame, cover.text = frame, text
    end
    cover.text:SetText(label)
    -- No colour (your name in the game's own): the colour of the name covered.
    if not r then r, g, b = TextColour(region) end
    if r then cover.text:SetTextColor(r, g, b) end
    cover.frame:Show()
end

-- A text box that shows stars while private; what it holds (and sends) is
-- unchanged.
local function Stars(key, box)
    if not box or not box.SetPassword then return end
    if not (box.IsPassword and box:IsPassword() == true) then box:SetPassword(true) end
    P:OnRestore(key, box, function() box:SetPassword(false) end)
end

-- The frames a scroll list is showing now.
local function Rows(scrollBox)
    if type(scrollBox) ~= "table" or type(scrollBox.GetFrames) ~= "function" then return {} end
    local frames = Call(scrollBox.GetFrames, scrollBox)
    return type(frames) == "table" and frames or {}
end

local function Shown(frame)
    return type(frame) == "table" and frame.IsShown and frame:IsShown() and true or false
end

-- What's on screen now, re-applied when private mode turns on or a name
-- setting changes, by setting key.
local onScreen = {}
local function OnScreen(key, fn)
    onScreen[key] = onScreen[key] or {}
    table.insert(onScreen[key], P:Guard(M, fn))
end

-- Post-hooks, made safe: on a global function, or on a table's method.
local function HookGlobal(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, P:Guard(M, fn)) end
end

local function HookMethod(t, name, fn)
    if type(t) == "table" and type(t[name]) == "function" then hooksecurefunc(t, name, P:Guard(M, fn)) end
end

-- Runs fn now if ready() says the game's part is there, else once that
-- Blizzard addon has loaded.
local function When(addon, ready, fn)
    if ready() then
        fn()
    else
        P:OnAddOnLoaded(addon, function() if ready() then fn() end end, M)
    end
end

-- Names ----------------------------------------------------------------------------------------

-- A Battle.net account (a person, not a character): "Friend", with their
-- character's class in class style.
local function AccountLabel(classFile)
    local style = P:Get("nameStyle")
    if style == "hidden" then return "" end
    if style == "class" and classFile then
        local label, r, g, b = P:StyleLabel(classFile)
        if label ~= "" then return FRIEND .. " (" .. Coloured(label, r, g, b) .. ")" end
    end
    return FRIEND
end

-- A word in place of a person (a request, a pop-up): blank when hidden.
local function Word(text)
    if P:Get("nameStyle") == "hidden" then return "" end
    return text
end

-- A made-up BattleTag drawn as the game draws the real one (base, the
-- game's text): the name in the colour that text starts with, "#" and what
-- follows in the colour the real "#" has. A colour the game's text doesn't
-- show is left to the region's own.
local function TagLook(base, tag)
    base = Readable(base)
    local name, number = tag:match("^(.-)(#.*)$")
    if not name then name, number = tag, "" end
    local first = base and base:match("^(|c%x%x%x%x%x%x%x%x)")
    local hash = base and base:match("(|c%x%x%x%x%x%x%x%x)#")
    local look = (first and name ~= "") and (first .. name .. "|r") or name
    if number ~= "" then look = look .. (hash and (hash .. number .. "|r") or number) end
    return look
end

-- Your own BattleTag: the made-up one typed in "Your BattleTag becomes" if
-- there is one, else your typed name, either in its chosen colour; else
-- "Battle.net". base: the game's text for the real one, so a made-up tag
-- in the game's own colour looks the same.
local function TagLabel(base)
    local tag, r, g, b = P:MyTag()
    if tag then
        if r then return Coloured(tag, r, g, b) end
        return TagLook(base, tag)
    end
    local alias = P:Get("myName")
    if type(alias) == "string" and alias ~= "" then return Coloured(P:MyLabel()) end
    return Word(BATTLENET)
end

local function NameLabel(name, classFile)
    return Coloured(P:LabelForName(name, classFile))
end

-- Battle.net text (a protected |K name or a BattleTag) can't be read, only
-- covered.
local function IsAccountText(text)
    return text:find("|K", 1, true) ~= nil or text:find("#", 1, true) ~= nil
end

-- A game account's class file (the newer window's data names it; the older
-- one's gives the class's name).
local function GameClass(game)
    local file = Readable(Field(game, "classFilename"))
    if file and file ~= "" then return file end
    return ClassFileFromName(Field(game, "className"))
end

-- A Battle.net friend's character, noted so its name is swapped in text too.
local function LearnAccount(info)
    local game = Field(info, "gameAccountInfo")
    local name = Readable(Field(game, "characterName"))
    if not name or name == "" then return nil end
    if Field(game, "clientProgram") ~= (BNET_CLIENT_WOW or "WoW") then return nil end
    local classFile = GameClass(game)
    P:Learn(name, classFile)
    return classFile
end

local function LearnBattleNet()
    if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return end
    local count = Plain(Call(BNGetNumFriends))
    if type(count) ~= "number" then return end
    for i = 1, count do LearnAccount(Call(C_BattleNet.GetFriendAccountInfo, i)) end
end

-- Friends (friends) ------------------------------------------------------------------------------

local function Format(pattern, ...)
    if type(pattern) ~= "string" then return nil end
    local ok, text = pcall(string.format, pattern, ...)
    return ok and text or nil
end

local function FriendRow(button)
    if not P:IsOn("friends") then return end
    local kind, id = Plain(button.buttonType), Plain(button.id)
    if kind == FRIENDS_BUTTON_TYPE_WOW then
        local info = Call(C_FriendList and C_FriendList.GetFriendInfoByIndex, id)
        if not info then return end
        local name, connected = Field(info, "name"), Field(info, "connected")
        local label, r, g, b = P:LabelForName(name, ClassFileFromName(Field(info, "className")))
        if connected then
            local level = Format(FRIENDS_LEVEL_TEMPLATE, Field(info, "level") or 0, Field(info, "className") or "")
            label = Coloured(label, r, g, b)
            if level then label = label == "" and level or (label .. ", " .. level) end
        end
        Put("friends", button.name, label)
        -- Where an online friend is; "Offline" stays.
        MaskIf("friends", button.info, connected)
    elseif kind == FRIENDS_BUTTON_TYPE_BNET then
        local info = Call(C_BattleNet and C_BattleNet.GetFriendAccountInfo, id)
        if not info then return end
        Put("friends", button.name, AccountLabel(LearnAccount(info)))
        MaskIf("friends", button.info, Field(Field(info, "gameAccountInfo"), "isOnline"))
    end
end

local function InviteRow(button)
    if not P:IsOn("friends") then return end
    Put("friends", button.Name, Word(REQUEST))
end

local function RefreshFriends()
    for _, row in ipairs(Rows(FriendsListFrame and FriendsListFrame.ScrollBox)) do
        local kind = Plain(row.buttonType)
        if kind == FRIENDS_BUTTON_TYPE_INVITE then
            InviteRow(row)
        elseif kind == FRIENDS_BUTTON_TYPE_WOW or kind == FRIENDS_BUTTON_TYPE_BNET then
            FriendRow(row)
        end
    end
end

local function BattleTag()
    if not P:IsOn("friends") then return end
    local frame = FriendsFrameBattlenetFrame
    local tag = frame and frame.Tag
    if not tag then return end
    -- Whether there's a BattleTag to cover is the game's text to say, not
    -- ours (a blank Hidden label is re-labelled when the style changes).
    local base = Base(tag)
    if IsSecret(tag:GetText()) or (base or "") ~= "" then Put("friends", tag, TagLabel(base)) end
    Stars("friends", frame.BroadcastFrame and frame.BroadcastFrame.EditBox)
end

-- The friends hover box is its own frame (not the game's tooltip). Its
-- header is the friend; the lines under it say where they are, their notes
-- and broadcasts.
local tipLines, tipAccount = nil, false

local function TipLines()
    if tipLines then return tipLines end
    tipLines = {}
    local function Mark(region, kind) if region then tipLines[region] = kind end end
    Mark(FriendsTooltipHeader, "header")
    Mark(FriendsTooltipNoteText, "blank")
    Mark(FriendsTooltipBroadcastText, "blank")
    for i = 1, Plain(FRIENDS_TOOLTIP_MAX_GAME_ACCOUNTS) or 5 do
        Mark(_G["FriendsTooltipGameAccount" .. i .. "Name"], "name")
        Mark(_G["FriendsTooltipGameAccount" .. i .. "Info"], "blank")
    end
    return tipLines
end

local function TipLine(line)
    if not P:IsOn("friends") or not line then return end
    local kind = TipLines()[line]
    if kind == "header" then
        local text = Base(line)
        local wow = text and not IsAccountText(text)
            and Call(C_FriendList and C_FriendList.GetFriendInfo, text)
        tipAccount = not wow
        if wow then
            Put("friends", line, NameLabel(text, ClassFileFromName(Field(wow, "className"))))
        else
            Put("friends", line, AccountLabel(nil))
        end
    elseif kind == "name" then
        local base = Base(line)
        if not base then return end
        local text, changed = P:ReplaceNames(base, nil, true)
        if changed then Put("friends", line, text) end
        -- A Battle.net friend's other accounts (BattleTags, other games).
        MaskIf("friends", line, not changed and tipAccount and base ~= "")
    elseif kind == "blank" then
        Mask("friends", line)
    end
end

-- Battle.net pop-ups (bnToasts) ---------------------------------------------------------------------

local NAMED_TOAST = { [1] = true, [2] = true, [3] = true } -- online, offline, broadcast

local function Toast(toast)
    if not P:IsOn("bnToasts") or not toast then return end
    local kind = Plain(toast.toastType)
    if not NAMED_TOAST[kind] then return end
    Put("bnToasts", toast.TopLine, A_FRIEND)
    Mask("bnToasts", toast.MiddleLine)
    if kind == 3 then Put("bnToasts", toast.BottomLine, BROADCAST) end
end

-- The character's name comes in a moment later (once its game icon has
-- loaded), straight onto the middle line, which only ever shows that name.
local function ToastMiddle(line)
    if P:IsOn("bnToasts") then Mask("bnToasts", line) end
end

local function RefreshToast()
    if Shown(BNToastFrame) then Toast(BNToastFrame) end
end

-- /who, ignore and recent players (whoList) --------------------------------------------------------

-- Your own /who row's guild: hidden, or your made-up guild laid over it (in
-- the column's own colour) while you're in a guild, as in your tooltip.
-- Anyone else's row shows theirs.
local function WhoGuild(row, mine)
    local region = row.GuildName
    local guild = mine and Plain(Call(IsInGuild)) == true and P:MyGuild()
    if guild then return Cover("whoList", row, region, guild) end
    local cover = region and covers[region]
    if cover and cover.frame then cover.frame:Hide() end
    MaskIf("whoList", region, mine)
end

-- /who rows: the right-click menu reads the name back off the row, so the
-- name is covered, never rewritten.
local function WhoRow(row, elementData)
    if not P:IsOn("whoList") or not row or not row.Name then return end
    local info = Field(elementData, "info")
    if not info then return end
    local name = Field(info, "fullName")
    local label, r, g, b = P:LabelForName(name, Field(info, "filename"))
    Cover("whoList", row, row.Name, label, r, g, b)
    -- Your own row's zone and guild.
    local mine = P:IsMyName(name)
    MaskIf("whoList", row.Variable, mine)
    WhoGuild(row, mine)
end

local function RefreshWho()
    for _, row in ipairs(Rows(LFGWhoListFrame and LFGWhoListFrame.ScrollBox)) do
        if row.GetElementData then WhoRow(row, row:GetElementData()) end
    end
end

-- A name on the ignore list: an ignored player by class, a Battle.net
-- block (a BattleTag or account name) as "Player". Both windows.
local function BlockedName(region, ignored)
    local text = Base(region)
    if not text or text == "" or text == UNKNOWN then return end
    if IsAccountText(text) or not ignored then
        Put("whoList", region, Coloured(P:StyleLabel(nil)))
    else
        Put("whoList", region, NameLabel(text))
    end
end

local function IgnoreRow(button)
    if not P:IsOn("whoList") or not button.name then return end
    BlockedName(button.name, Plain(button.type) == SQUELCH_TYPE_IGNORE)
end

local function RefreshIgnore()
    local window = FriendsFrame and FriendsFrame.IgnoreListWindow
    for _, row in ipairs(Rows(window and window.ScrollBox)) do IgnoreRow(row) end
end

-- A recent player's name, from the row's own data. Both windows.
local function AllyName(region, elementData)
    local character = Field(Plain(elementData), "characterData")
    if not character or not region then return end
    local name = Field(character, "fullName") or Field(character, "name")
    Put("whoList", region, NameLabel(name, ClassFileFromID(Field(character, "classID"))))
end

local function RecentRow(entry)
    if not P:IsOn("whoList") then return end
    AllyName(entry.CharacterData and entry.CharacterData.Name, entry.elementData)
end

local function RefreshRecent()
    local list = RecentAlliesFrame and RecentAlliesFrame.List
    for _, row in ipairs(Rows(list and list.ScrollBox)) do RecentRow(row) end
end

-- Guild roster (roster) ------------------------------------------------------------------------------
-- The roster's member info is secret in dungeons and raids (all but isSelf),
-- so nothing is read without asking first.

local function MemberLabel(info)
    if Field(info, "isSelf") == true then return P:MyLabel() end
    return P:StyleLabel(ClassFileFromID(Field(info, "classID")))
end

local function MemberRow(row)
    if not P:IsOn("roster") then return end
    local info = Plain(row.memberInfo)
    if not info or not row.NameFrame then return end
    Put("roster", row.NameFrame.Name, (MemberLabel(info)))
end

local function MemberColumns(row)
    if not P:IsOn("roster") then return end
    local info = Plain(row.memberInfo)
    if not info or not Plain(row.expanded) then return end
    Mask("roster", row.Note)
    MaskIf("roster", row.Zone, Field(info, "isSelf") == true)
end

local function MemberDetail(panel, _, info)
    info = Plain(info)
    if not P:IsOn("roster") or not info or not Shown(panel) then return end
    Put("roster", panel.Name, (MemberLabel(info)))
    Mask("roster", panel.NoteBackground and panel.NoteBackground.PersonalNoteText)
    Mask("roster", panel.OfficerNoteBackground and panel.OfficerNoteBackground.OfficerNoteText)
    MaskIf("roster", panel.ZoneText, Field(info, "isSelf") == true)
end

local function RefreshRoster()
    local frame = CommunitiesFrame
    if not frame then return end
    for _, row in ipairs(Rows(frame.MemberList and frame.MemberList.ScrollBox)) do
        MemberRow(row)
        MemberColumns(row)
    end
    local panel = frame.GuildMemberDetailFrame
    if Shown(panel) and panel.GetMemberInfo then MemberDetail(panel, nil, panel:GetMemberInfo()) end
    -- The guild event log ("X invited Y") is hidden whole.
    local log = CommunitiesGuildLogFrame
    local html = log and log.Container and log.Container.ScrollFrame and log.Container.ScrollFrame.Child
        and log.Container.ScrollFrame.Child.HTMLFrame
    Mask("roster", html)
end

-- Guild news and message of the day (news) ---------------------------------------------------------

local function NewsRow(button)
    if not P:IsOn("news") or not button.text then return end
    local info = Plain(button.newsInfo)
    if not info or Field(info, "isHeader") or Field(info, "newsType") == NEWS_GUILD_ACHIEVEMENT then return end
    local who = Readable(Field(info, "whoText"))
    local base = Base(button.text)
    if not who or who == "" or not base then return end
    local s, e = base:find(who, 1, true)
    if not s then return end
    Put("news", button.text, base:sub(1, s - 1) .. NameLabel(who) .. base:sub(e + 1))
end

local function NewsMotd(button)
    if not P:IsOn("news") or not button.text then return end
    Put("news", button.text, MOTD_HIDDEN)
end

local function RefreshNews()
    local details = CommunitiesFrame and CommunitiesFrame.GuildDetailsFrame
    if not details then return end
    for _, row in ipairs(Rows(details.News and details.News.ScrollBox)) do
        if Plain(row.newsType) == NEWS_MOTD then NewsMotd(row) else NewsRow(row) end
    end
    -- The message of the day and the guild info are free text: hidden whole.
    local info = details.Info
    if not info then return end
    Mask("news", info.MOTDScrollFrame and info.MOTDScrollFrame.MOTD)
    local child = info.DetailsFrame and info.DetailsFrame.GetScrollChild and info.DetailsFrame:GetScrollChild()
    Mask("news", child and child.Details)
end

-- Your guild's name (guildName) ---------------------------------------------------------------------

local function ClubRow(row, elementData)
    if not P:IsOn("guildName") or not row.Name then return end
    local club = Field(elementData, "clubInfo")
    if not club then return end
    -- One you're in (the game marks those): an invitation or a ticket is
    -- another guild's, never yours.
    local joined = Field(club, "isClub") == true
    if Field(club, "isTicket") then club = Field(club, "clubInfo") or club end
    local guildType = Enum and Enum.ClubType and Enum.ClubType.Guild
    if Field(club, "clubType") ~= guildType then return Put("guildName", row.Name, COMMUNITY) end
    -- Your own guild: your made-up guild, if one is typed.
    Put("guildName", row.Name, joined and P:MyGuild() or GUILD)
end

local function RefreshClubs()
    local list = CommunitiesFrame and CommunitiesFrame.CommunitiesList
    for _, row in ipairs(Rows(list and list.ScrollBox)) do
        if row.GetElementData then ClubRow(row, row:GetElementData()) end
    end
end

local function InspectGuild()
    if not P:IsOn("guildName") then return end
    local frame = InspectGuildFrame
    if frame and frame.guildName then Put("guildName", frame.guildName, GUILD) end
end

-- Guild charters are the Windows module's (under its pop-ups setting), so
-- they're left alone here: two modules swapping one text would fight.

-- Mail (mail) ----------------------------------------------------------------------------------------
-- Only mail you can reply to is from a player; the Auction House and the
-- game's own letters keep their senders.

local function Sender(index)
    local _, _, sender, _, _, _, _, _, _, _, _, canReply = Call(GetInboxHeaderInfo, index)
    sender = Readable(sender)
    if sender and Plain(canReply) then return sender end
end

local function Inbox()
    if not P:IsOn("mail") then return end
    for i = 1, Plain(INBOXITEMS_TO_DISPLAY) or 7 do
        local button = _G["MailItem" .. i .. "Button"]
        if Shown(button) then
            local sender = Sender(Plain(button.index))
            if sender then Put("mail", _G["MailItem" .. i .. "Sender"], NameLabel(sender)) end
            PutNames("mail", _G["MailItem" .. i .. "Subject"])
        end
    end
end

-- The letter's text (shown with its markup off, so plain words, no colour).
local function PutBody(id)
    local body = OpenMailBodyText
    local text = Readable(Call(GetInboxText, id))
    if not body or not text then return end
    local swapped, changed = P:ReplaceNames(text)
    if not changed then return end
    body:SetText(swapped, true)
    P:OnRestore("mail", "body", function()
        if not Shown(OpenMailFrame) then return end
        local original = Readable(Call(GetInboxText, Plain(InboxFrame and InboxFrame.openMailID)))
        if original then body:SetText(original, true) end
    end)
end

-- The letter's sender is covered: Reply reads the name back off it.
local function Letter()
    if not P:IsOn("mail") then return end
    local id = Plain(InboxFrame and InboxFrame.openMailID)
    local holder = OpenMailSender
    if not id or not holder or not holder.Name then return end
    local sender = Sender(id)
    if sender then
        local label, r, g, b = P:LabelForName(sender)
        Cover("mail", holder, holder.Name, label, r, g, b)
    else
        Uncover(holder.Name)
    end
    PutNames("mail", OpenMailSubject)
    PutBody(id)
    local invoiceType, _, buyer = Call(GetInboxInvoiceInfo, id)
    invoiceType, buyer = Plain(invoiceType), Readable(buyer)
    if invoiceType and buyer and OpenMailInvoicePurchaser then
        local prefix = invoiceType == "buyer" and SOLD_BY_COLON or PURCHASED_BY_COLON
        Put("mail", OpenMailInvoicePurchaser, (Readable(prefix) or "") .. " " .. NameLabel(buyer))
    end
end

-- The To box itself is left readable: you need to see the name you type.

-- Name suggestions under the To box (the same box serves chat; only the
-- mail's is touched).
local function Suggestions(box, results)
    if not P:IsOn("mail") or not box or not SendMailNameEditBox or box.parent ~= SendMailNameEditBox then return end
    if type(results) ~= "table" or IsSecret(results) then return end
    local most = Plain(AUTOCOMPLETE_MAX_BUTTONS) or 5
    local shown = math.min(#results, most)
    if #results > most then shown = shown - 1 end
    for i = 1, shown do
        local button = _G["AutoCompleteButton" .. i]
        local name = Field(results[i], "name")
        if button and name then Put("mail", button, NameLabel(name)) end
    end
end

local function RefreshMail()
    if Shown(InboxFrame) then Inbox() end
    if Shown(OpenMailFrame) then Letter() end
end

-- Group finder (groupFinder) ---------------------------------------------------------------------------
-- Listings are secret in dungeons and raids; then names fall back to
-- "Player" without being read.

local function LeaderLabel(resultID)
    local leader = Call(C_LFGList and C_LFGList.GetSearchResultLeaderInfo, Plain(resultID))
    return NameLabel(Field(leader, "name"), Field(leader, "classFilename"))
end

local function Listing(row)
    if not P:IsOn("groupFinder") or not row.Name then return end
    Put("groupFinder", row.Name, LeaderLabel(row.resultID))
end

local function ListingTip(tip, resultID)
    if not P:IsOn("groupFinder") or not tip then return end
    if tip.Leader and tip.Leader.Name then Put("groupFinder", tip.Leader.Name, LeaderLabel(resultID)) end
    local pool = tip.memberPool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for frame in pool:EnumerateActive() do
            local region = frame.Name
            if region then
                local name = region:GetText()
                Put("groupFinder", region, NameLabel(name, ClassFromColour(region:GetTextColor())))
            end
        end
    end
    PutNames("groupFinder", tip.Comment)
end

local function ListingComment(region)
    if P:IsOn("groupFinder") then PutNames("groupFinder", region) end
end

local function RefreshFinder()
    for _, row in ipairs(Rows(LFGBrowseFrame and LFGBrowseFrame.ScrollBox)) do Listing(row) end
end

-- Calendar (calendar) ------------------------------------------------------------------------------------
-- Invites are secret in dungeons and raids too.

local function InviteName(button, _, invite)
    if not P:IsOn("calendar") or not button.Name then return end
    Put("calendar", button.Name, (P:LabelForName(Field(invite, "name"), Field(invite, "classFilename"))))
end

local function Creator(region)
    if not P:IsOn("calendar") or not region then return end
    local info = Call(C_Calendar and C_Calendar.GetEventInfo)
    local text = Format(Readable(CALENDAR_EVENT_CREATORNAME) or "Created by %s", NameLabel(Field(info, "creator")))
    if text then Put("calendar", region, text) end
end

local function ViewEvent()
    Creator(CalendarViewEventCreatorName)
end

local function EditEvent()
    Creator(CalendarCreateEventCreatorName)
end

local function RefreshCalendar()
    for _, global in ipairs({ "CalendarViewEventInviteList", "CalendarCreateEventInviteList" }) do
        local list = _G[global]
        for _, row in ipairs(Rows(list and list.ScrollBox)) do
            local index = Plain(row.inviteIndex)
            if index then InviteName(row, index, Call(C_Calendar and C_Calendar.EventGetInvite, index)) end
        end
    end
    if Shown(CalendarViewEventFrame) then ViewEvent() end
    if Shown(CalendarCreateEventFrame) then EditEvent() end
end

-- The newer social window (friends, whoList) -------------------------------------------------------------
-- Forever's own friends window (Blizzard_SocialUI, when C_SocialUI.IsSystemEnabled()):
-- your BattleTag in its header, friend and request cards, the broadcast box,
-- the ignore list, recent allies, Quick Join and Recruit-A-Friend. Its cards
-- are recycled, so each is labelled again every time the game fills it, from
-- the card's own data (before the game measures the text). Its hover boxes
-- use the game's tooltip and are left alone.

-- A table inside a table by its keys, or nil (never a stray function).
local function Part(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[(select(i, ...))]
    end
    if type(t) ~= "table" then return nil end
    return t
end

-- The colour code the game's text starts with, put round a label of ours
-- (so "Friend" keeps the card's blue or grey). Blank stays blank.
local function Tint(base, label)
    if type(label) ~= "string" or label == "" or type(base) ~= "string" then return label end
    local code = base:match("^(|c%x%x%x%x%x%x%x%x)")
    if not code then return label end
    return code .. label .. "|r"
end

-- The rows a scroll list is showing, for each list given (some may be nil).
local function EachRow(fn, ...)
    for i = 1, select("#", ...) do
        for _, row in ipairs(Rows((select(i, ...)))) do fn(row) end
    end
end

-- A row the game made before its mixin was hooked (Quick Join and
-- Recruit-A-Friend fill their lists as they load, so after a /reload some
-- rows can be older than our hooks) kept the old method: that row is hooked
-- too, once. Its own copy is read raw, only to compare.
local older = setmetatable({}, { __mode = "k" })
local function HookOlder(row, mixin, method, fn)
    if type(row) ~= "table" or type(mixin) ~= "table" then return end
    local done = older[row]
    if done and done[method] then return end
    local own = rawget(row, method)
    if type(own) ~= "function" or own == mixin[method] then return end
    older[row] = done or {}
    older[row][method] = true
    HookMethod(row, method, fn)
end

-- Your BattleTag in the header. The game's text is hidden (alpha), never
-- rewritten, so it comes back just as the game laid it out; a strip of our
-- own over the whole BattleTag area shows the label and takes the mouse, so
-- the copy button under it (hidden too) can't be clicked and the real
-- BattleTag is never copied, and the hover that repeats the text can't
-- show. "Battle.net unavailable" (no BattleTag) is left alone.
local function TagHolder()
    return Part(SocialUIFrame, "BattleNetBar", "ControlsContainer", "PersonalBattleTagDisplay")
end

local function TagStrip(display, region)
    local frame = CreateFrame("Frame", nil, display)
    frame:SetAllPoints(display)
    frame:SetFrameLevel(display:GetFrameLevel() + 10)
    frame:EnableMouse(true)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font = region.GetFontObject and region:GetFontObject()
    if font then text:SetFontObject(font) end
    text:SetPoint("CENTER", region, "CENTER", 0, 0)
    return frame, text
end

local function TagDisplay(display)
    local region = P:IsOn("friends") and Part(display, "DisplayText")
    if not region then return end
    local copy = Part(display, "CopyBattleTagToClipboardButton")
    local raw = region:GetText()
    local text = Readable(raw)
    -- Your BattleTag shows: the game's text has its "#", or can't be read (a
    -- secret) while the copy button is up (the game shows it only with your
    -- BattleTag), so a secret one is covered too, never left showing.
    local showing = (text and text:find("#", 1, true)) or (IsSecret(raw) and Shown(copy))
    if not showing then
        Uncover(region)
        Uncover(copy)
        return
    end
    -- Your typed name in the game's own colour (or "Battle.net") takes the
    -- BattleTag's colour, a made-up BattleTag the real one's look; a chosen
    -- colour is its own.
    local label = TagLabel(text)
    if not label:find("|c", 1, true) then label = Tint(text, label) end
    local cover = Mask("friends", region)
    if not cover.frame then cover.frame, cover.text = TagStrip(display, region) end
    cover.text:SetText(label)
    cover.frame:Show()
    Mask("friends", copy)
end

local function SocialHeader()
    TagDisplay(TagHolder())
    Stars("friends", Part(SocialUIFrame, "BattleNetBroadcastFrame", "EditBox"))
end

-- A friend's card: "Friend (Mage)" for the person (as the older list), the
-- character by their label (class colour while online, the game's grey
-- otherwise), another game's name (or a BattleTag in its place) hidden, and
-- where they are hidden while they're online.
local function CardAccount(card)
    return Field(Plain(card.elementData), "accountInfo")
end

local function CharacterLine(region, name, classFile, online)
    local label, r, g, b = P:LabelForName(name, classFile)
    if online then
        Put("friends", region, Coloured(label, r, g, b))
    else
        Put("friends", region, Tint(Base(region), label))
    end
end

local function CardName(card)
    local region = P:IsOn("friends") and Part(card, "FriendName")
    local info = region and CardAccount(card)
    if not info then return end
    Put("friends", region, Tint(Base(region), AccountLabel(LearnAccount(info))))
end

-- The card's game account, or nil when it can't be read (a secret).
local function CardGame(info)
    local game = info.gameAccountInfo
    if IsSecret(game) or type(game) ~= "table" then return nil end
    return game
end

local function CardCharacter(card)
    local region = P:IsOn("friends") and Part(card, "Name")
    local info = region and CardAccount(card)
    if not info then return end
    local game = CardGame(info)
    local raw = game and game.characterName
    -- No character at all: the game hides the line. One that can't be read
    -- is hidden too.
    if game and not IsSecret(raw) and raw == nil then
        Uncover(region)
        return
    end
    local name = Readable(raw)
    if not name or name == "" or Field(game, "clientProgram") ~= (BNET_CLIENT_WOW or "WoW") then
        Mask("friends", region)
        return
    end
    Uncover(region)
    CharacterLine(region, name, GameClass(game), Field(game, "isOnline"))
end

-- Where they are, hidden while online (or when that can't be read);
-- "Last online" kept.
local function CardLocation(card)
    local region = P:IsOn("friends") and Part(card, "Location")
    local info = region and CardAccount(card)
    if not info then return end
    local game = CardGame(info)
    local online = game and game.isOnline
    MaskIf("friends", region, not game or IsSecret(online) or online == true)
end

-- A friend request's card: "Friend request" in the game's colour.
local function RequestCard(card)
    local region = P:IsOn("friends") and Part(card, "Name")
    if not region or Field(Plain(card.elementData), "inviteIndex") == nil then return end
    Put("friends", region, Tint(Base(region), Word(REQUEST)))
end

-- Quick Join (the newer window's tab and the older one's): each member's
-- name is a link whose data (the real name, for the right-click and the
-- whisper) is kept; only the name shown becomes the label: a Battle.net
-- friend "Friend (Mage)", anyone else their class, you your label. A name
-- with no link (the game doesn't know it) is left.
local function QueueLabel(member)
    local guid = Readable(Field(member, "guid"))
    if not guid then return Coloured(P:StyleLabel(nil)) end
    local account = Plain(Call(C_BattleNet and C_BattleNet.GetAccountInfoByGUID, guid))
    if type(account) == "table" then return AccountLabel(LearnAccount(account)) end
    return Coloured(P:LabelForGUID(guid))
end

local function QueueRow(row, entry)
    if not P:IsOn("friends") or type(row) ~= "table" then return end
    entry = Plain(entry) or Plain(row.entry)
    local members, regions = Field(entry, "displayedMembers"), Part(row, "Members")
    if type(members) ~= "table" or not regions then return end
    for i, member in ipairs(members) do
        local region = regions[i]
        local base = type(region) == "table" and Base(region)
        if base then
            local label = QueueLabel(member)
            local text, links = base:gsub("(|H.-|h).-(|h)", function(head, tail) return head .. label .. tail end, 1)
            if links > 0 then Put("friends", region, text) end
        end
    end
end

-- Recruit-A-Friend (both windows): the recruit as "Friend (Mage)", their
-- character by its label. "Pending recruit" names nobody and is left.
local HookRecruit

local function RecruitRow(row, recruitInfo)
    local region = P:IsOn("friends") and Part(row, "Name")
    if not region then return end
    HookRecruit(row)
    local info = Plain(recruitInfo)
    if type(info) ~= "table" then info = Plain(row.recruitInfo) end
    if type(info) ~= "table" then return end
    local plain, pending = Readable(Field(info, "plainName")), Readable(RAF_PENDING_RECRUIT)
    if plain and plain == pending then return end
    local classFile = LearnAccount(Field(info, "accountInfo"))
    Put("friends", region, Tint(Base(region), AccountLabel(classFile)))
    local line, character = Part(row, "CharacterName"), Readable(Field(info, "characterName"))
    if line and character and character ~= "" then CharacterLine(line, character, classFile, Field(info, "isOnline")) end
end

-- A row the game made before the hooks (the lists fill as they load, so
-- after a /reload) kept the old methods: it's hooked on the step that
-- writes its names last (the newer window's colours, else the older
-- window's setup). A newer-window row always passes through the hooked
-- setup first, so it's hooked just before its colour step runs.
HookRecruit = function(row)
    if rawget(row, "UpdateCardTextColors") then
        HookOlder(row, RecruitListButtonSocialMixin, "UpdateCardTextColors", RecruitRow)
    else
        HookOlder(row, RecruitListButtonMixin, "SetupRecruit", RecruitRow)
    end
end

local function RefreshQueues()
    EachRow(function(row)
        HookOlder(row, QuickJoinButtonMixin, "SetEntry", QueueRow)
        QueueRow(row)
    end, Part(SocialUIFrame, "QuickJoinFrame", "ScrollBox"), Part(QuickJoinFrame, "ScrollBox"))
end

-- Also run after each update of the older window's list (see HookFriends).
local function RefreshRecruits()
    if not P:IsOn("friends") then return end
    EachRow(RecruitRow, Part(SocialUIFrame, "RecruitAFriendFrame", "ScrollBox"), Part(RecruitAFriendFrame, "RecruitList", "ScrollBox"))
end

local function RefreshCards()
    EachRow(function(card)
        CardName(card)
        CardCharacter(card)
        CardLocation(card)
    end, Part(SocialUIFrame, "FriendsList", "ScrollBox"))
end

local function RefreshRequests()
    EachRow(RequestCard, Part(SocialUIFrame, "FriendRequestsList", "ScrollBox"))
end

-- The newer window's ignore list (whoList).
local function BlockedEntry(entry)
    local region = P:IsOn("whoList") and Part(entry, "Name")
    if not region then return end
    local kind = Field(Plain(entry.elementData), "blockType")
    local ignore = Part(Enum, "SocialUIBlockType")
    BlockedName(region, kind ~= nil and kind == ((ignore and ignore.Ignore) or 1))
end

-- A recent ally's card (whoList): the name by its label, as the older list.
local function AllyCard(card)
    local region = P:IsOn("whoList") and Part(card, "Name")
    if region then AllyName(region, card.elementData) end
end

local function RefreshBlocked()
    EachRow(BlockedEntry, Part(SocialUIFrame, "IgnoreListFrame", "ScrollBox"))
end

local function RefreshAllies()
    EachRow(AllyCard, Part(SocialUIFrame, "RecentAlliesList", "ScrollBox"))
end

-- Hooks -------------------------------------------------------------------------------------------------

-- At load: Blizzard's row mixins, before any rows copy them. The hooks
-- do nothing until private mode is on.
P:OnAddOnLoaded("Blizzard_Communities", function()
    HookMethod(CommunitiesMemberListEntryMixin, "SetMember", MemberRow)
    HookMethod(CommunitiesMemberListEntryMixin, "RefreshExpandedColumns", MemberColumns)
    HookMethod(CommunitiesListEntryMixin, "Init", ClubRow)
end, M)
P:OnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
    HookMethod(LFGWhoListButtonMixin, "InitButton", WhoRow)
end, M)
P:OnAddOnLoaded("Blizzard_RecentAllies", function()
    HookMethod(RecentAlliesEntryMixin, "SetCharacterName", RecentRow)
    HookMethod(RecentAlliesSocialCardMixin, "RefreshCharacterDataDisplayText", AllyCard)
end, M)
-- The newer social window's cards and rows. Each hook is on the step that
-- writes the text, which runs before the game measures it for the layout.
P:OnAddOnLoaded("Blizzard_FriendsFrame", function()
    HookMethod(FriendsListSocialCardMixin, "RefreshFriendNameDisplayText", CardName)
    HookMethod(FriendsListSocialCardMixin, "RefreshFriendCharacterDataDisplayText", CardCharacter)
    HookMethod(FriendsListSocialCardMixin, "RefreshLocationDisplayText", CardLocation)
    HookMethod(FriendRequestsListSocialCardMixin, "InitializeRequesterNameText", RequestCard)
end, M)
P:OnAddOnLoaded("Blizzard_SocialUI", function()
    HookMethod(SocialUIIgnoreListEntryMixin, "RefreshName", BlockedEntry)
end, M)
P:OnAddOnLoaded("Blizzard_QuickJoin", function()
    HookMethod(QuickJoinButtonMixin, "SetEntry", QueueRow)
    -- Each group's entry writes the names into whichever row shows it, and
    -- entries are made afresh from this mixin every time a list opens, so a
    -- row older than the hooks (kept back by the list and reused later) is
    -- labelled too.
    HookMethod(QuickJoinEntryMixin, "ApplyToFrame", function(entry, row) QueueRow(row, entry) end)
end, M)
P:OnAddOnLoaded("Blizzard_RecruitAFriend", function()
    HookMethod(RecruitListButtonMixin, "SetupRecruit", RecruitRow)
    HookMethod(RecruitListButtonSocialMixin, "UpdateCardTextColors", RecruitRow)
end, M)

local function GlobalReady(name)
    return function() return type(_G[name]) == "function" end
end

local function HookFriends()
    When("Blizzard_FriendsFrame", GlobalReady("FriendsFrame_UpdateFriendButton"), function()
        HookGlobal("FriendsFrame_UpdateFriendButton", FriendRow)
        HookGlobal("FriendsFrame_UpdateFriendInviteButton", InviteRow)
        HookGlobal("FriendsFrame_CheckBattlenetStatus", BattleTag)
        HookGlobal("FriendsFrameTooltip_SetLine", TipLine)
        HookGlobal("IgnoreList_InitButton", IgnoreRow)
    end)
    When("Blizzard_BNet", function() return BNToastFrame ~= nil end, function()
        HookMethod(BNToastFrame, "ShowToast", Toast)
        HookMethod(BNToastFrame.MiddleLine, "SetFormattedText", ToastMiddle)
    end)
    -- The newer window's header, made once with the window: its BattleTag
    -- display is hooked on the instance (it copied its mixin long before).
    When("Blizzard_SocialUI", function() return TagHolder() ~= nil end, function()
        HookMethod(TagHolder(), "ShowBestDisplayTextAndButton", TagDisplay)
        if P:IsOn("friends") then SocialHeader() end
    end)
    -- The older window's Recruit-A-Friend list fills as it loads, so a row
    -- kept back from then can come back later with its old methods: each
    -- update of the list labels (and hooks) its rows again. The newer
    -- window's rows hook themselves (HookRecruit).
    When("Blizzard_RecruitAFriend", function() return RecruitAFriendFrame ~= nil end, function()
        HookMethod(RecruitAFriendFrame, "UpdateRecruitList", RefreshRecruits)
    end)
end

local function HookGuild()
    When("Blizzard_Communities", function() return CommunitiesFrame ~= nil end, function()
        HookMethod(CommunitiesFrame.GuildMemberDetailFrame, "DisplayMember", MemberDetail)
    end)
    HookGlobal("GuildNewsButton_SetNews", NewsRow)
    HookGlobal("GuildNewsButton_SetMOTD", NewsMotd)
    When("Blizzard_InspectUI", GlobalReady("InspectGuildFrame_Update"), function()
        HookGlobal("InspectGuildFrame_Update", InspectGuild)
    end)
end

local function HookMail()
    When("Blizzard_MailFrame", function() return InboxFrame ~= nil end, function()
        HookMethod(InboxFrame, "Update", Inbox)
        HookMethod(OpenMailFrame, "Update", Letter)
    end)
    HookGlobal("AutoComplete_UpdateResults", Suggestions)
end

local function HookFinderAndCalendar()
    When("Blizzard_GroupFinder_VanillaStyle", GlobalReady("LFGBrowseSearchEntry_Update"), function()
        HookGlobal("LFGBrowseSearchEntry_Update", Listing)
        HookGlobal("LFGBrowseSearchEntryTooltip_UpdateAndShow", ListingTip)
        HookGlobal("LFGBrowseGroupDataDisplayComment_Update", ListingComment)
    end)
    When("Blizzard_Calendar", GlobalReady("CalendarEventInviteList_InitButtonShared"), function()
        HookGlobal("CalendarEventInviteList_InitButtonShared", InviteName)
        HookGlobal("CalendarViewEventFrame_Update", ViewEvent)
        HookGlobal("CalendarCreateEventFrame_Update", EditEvent)
    end)
end

-- Each surface on its own guard, so one failing never stops the others.
OnScreen("friends", RefreshFriends)
OnScreen("friends", BattleTag)
OnScreen("friends", SocialHeader)
OnScreen("friends", RefreshCards)
OnScreen("friends", RefreshRequests)
OnScreen("friends", RefreshQueues)
OnScreen("friends", RefreshRecruits)
OnScreen("bnToasts", RefreshToast)
OnScreen("whoList", RefreshWho)
OnScreen("whoList", RefreshIgnore)
OnScreen("whoList", RefreshRecent)
OnScreen("whoList", RefreshBlocked)
OnScreen("whoList", RefreshAllies)
OnScreen("roster", RefreshRoster)
OnScreen("news", RefreshNews)
OnScreen("guildName", RefreshClubs)
OnScreen("guildName", InspectGuild)
OnScreen("mail", RefreshMail)
OnScreen("groupFinder", RefreshFinder)
OnScreen("calendar", RefreshCalendar)

function M:Setup()
    HookFriends()
    HookGuild()
    HookMail()
    HookFinderAndCalendar()
end

-- Your own /who row shows your made-up guild only while guildName is
-- ticked, so a change to that tick re-labels the whoList lists too.
local ALSO = { guildName = "whoList" }

-- Private mode on: everything ticked, as it shows now. A setting turned
-- off has already been put back by the core; one turned on (or a name
-- setting changed) is applied to what's showing. Off: the core puts back
-- everything recorded, covers and the To box included.
function M:Apply(on, key)
    if not on then return end
    if key == nil then LearnBattleNet() end
    local all = key == nil or P.NAME_KEYS[key]
    for owned, list in pairs(onScreen) do
        if (all or key == owned or ALSO[key] == owned) and P:IsOn(owned) then
            for _, fn in ipairs(list) do fn() end
        end
    end
end
