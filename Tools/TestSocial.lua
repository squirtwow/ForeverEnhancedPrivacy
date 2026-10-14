-- The Social module against a mock game (Tools/Harness.lua): the friends
-- list, its hover box, your BattleTag and broadcast box, friend requests,
-- the ignore list, Battle.net pop-ups, /who rows (covered, never rewritten),
-- recent players, the guild roster, details panel, notes, event log, news,
-- message of the day and info, the guild and community list, charters, the
-- inspect window's guild tab, a made-up guild (your guild's row and your own
-- /who row's guild), mail (inbox, letter, invoice, To box and its
-- suggestions), the group finder and the calendar. Off does nothing, on
-- swaps, each tick puts back only its own, name settings re-label, off puts
-- it all back, and secrets are never read.
-- The game's social windows are stood in for here, as Blizzard builds them;
-- they're this module's alone, so they live in this file.
-- Run with fengari: Tools/TestSocial.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local T = H.Text
local P, G
-- The globals there before any game is built, so a later game can start
-- without these windows.
local BASELINE = {}
for key in pairs(_G) do BASELINE[key] = true end

-- Building Blizzard's side ------------------------------------------------------------------------

local function Frame(name, parent, fields) return H.BlizzardFrame("Frame", name, parent, fields) end
local function Button(name, parent, fields) return H.BlizzardFrame("Button", name, parent, fields) end

-- A FontString of Blizzard's under parent[key] (and global name, if given).
local function Text(parent, key, text, name)
    local fs = H.BlizzardText(name, parent, text or "")
    if key then rawset(parent, key, fs) end
    return fs
end

local function Child(parent, key, kind, name, fields)
    local frame = H.BlizzardFrame(kind or "Frame", name, parent, fields)
    rawset(parent, key, frame)
    return frame
end

-- A scroll list: its rows are whatever the test puts in the returned table.
local function List(parent, key)
    local rows = {}
    Child(parent, key, "Frame", nil, { GetFrames = function() return rows end })
    return rows
end

-- A row made from a mixin: its functions copied in as the game does when
-- the row is made (so hooks on the mixin made before then are in it).
local function Mixin(row, mixin)
    for key, value in pairs(mixin) do rawset(row, key, value) end
    return row
end

local elementData = {}
local function WithData(row)
    rawset(row, "GetElementData", function(self) return elementData[self] end)
    return row
end

local function Constants()
    FRIENDS_BUTTON_TYPE_BNET, FRIENDS_BUTTON_TYPE_WOW, FRIENDS_BUTTON_TYPE_INVITE = 2, 3, 4
    SQUELCH_TYPE_IGNORE, SQUELCH_TYPE_BLOCK_INVITE = 1, 2
    FRIENDS_LEVEL_TEMPLATE = "Level %d %s"
    FRIENDS_TOOLTIP_MAX_GAME_ACCOUNTS = 5
    BNET_CLIENT_WOW = "WoW"
    UNKNOWN = "Unknown"
    NEWS_MOTD, NEWS_GUILD_ACHIEVEMENT, NEWS_ITEM_LOOTED = -1, 0, 3
    GUILD_NEWS_FORMAT0, GUILD_NEWS_FORMAT3 = "Guild earned %s.", "%s obtained %s."
    CALENDAR_EVENT_CREATORNAME = "Created by %s"
    INBOXITEMS_TO_DISPLAY = 7
    SOLD_BY_COLON, PURCHASED_BY_COLON = "Sold by:", "Purchased by:"
    AUTOCOMPLETE_MAX_BUTTONS = 5
    Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2, Other = 3 }
    local CLASS_IDS = { [1] = "WARRIOR", [5] = "PRIEST", [8] = "MAGE", [11] = "DRUID" }
    C_CreatureInfo = { GetClassInfo = function(id)
        local file = CLASS_IDS[id]
        return file and { classFile = file, className = H.CLASS_NAMES[file] }
    end }
end

-- Friends, Battle.net, the ignore list and the pop-ups (Blizzard_FriendsFrame, Blizzard_BNet).
local function Friends()
    H.friends = {
        { name = "Brannoc Stonehelm", className = "Warrior", level = 60, area = "Ironforge", notes = "Lives next door", connected = true },
        { name = "Tamsin Reed", className = "Mage", level = 42, connected = false },
    }
    local function Info(i)
        local f = H.friends[i]
        return f and { name = f.name, className = f.className, level = f.level, area = f.area, notes = f.notes, connected = f.connected }
    end
    C_FriendList.GetFriendInfoByIndex = Info
    C_FriendList.GetFriendInfo = function(name)
        for i, f in ipairs(H.friends) do if f.name == name then return Info(i) end end
    end
    G.ignored = { "Grubb Fizzwick" }
    C_FriendList.GetIgnoreName = function(i) return G.ignored[i] end
    G.bn = {
        { accountName = "|Kq1|k", battleTag = "Pal#1234", note = "Work mate", customMessage = "Raid at eight",
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Odessa Vale", className = "Priest",
                raceName = "Human", characterLevel = 60, areaName = "Stormwind" } },
    }
    BNGetNumFriends = function() return #G.bn, #G.bn, 0, 0 end
    G.tag = "Squirt#1234"
    BNGetInfo = function() return 1, G.tag, 2, "Back soon" end
    C_BattleNet = { GetFriendAccountInfo = function(i) return G.bn[i] end, GetAccountInfoByID = function(id) return G.bn[id] end }

    Frame("FriendsFrame", UIParent)
    G.friendRows = List(Frame("FriendsListFrame", FriendsFrame), "ScrollBox")
    FriendsFrame_UpdateFriendButton = function(button, data)
        button.buttonType, button.id = data.buttonType, data.id
        local nameText, infoText
        if data.buttonType == FRIENDS_BUTTON_TYPE_WOW then
            local info = C_FriendList.GetFriendInfoByIndex(data.id)
            if info.connected then
                nameText, infoText = info.name .. ", " .. FRIENDS_LEVEL_TEMPLATE:format(info.level, info.className), info.area
            else
                nameText, infoText = info.name, "Offline"
            end
        else
            local account = C_BattleNet.GetFriendAccountInfo(data.id)
            local game = account.gameAccountInfo
            nameText = account.accountName .. " (" .. game.characterName .. ")"
            infoText = game.isOnline and game.areaName or "Last online 3 days ago"
        end
        button.name:SetText(nameText)
        button.info:SetText(infoText)
    end
    FriendsFrame_UpdateFriendInviteButton = function(button, data)
        button.buttonType, button.id = data.buttonType, data.id
        button.Name:SetText("|Kq9|k")
    end

    -- The hover box, its own frame, and the lines Blizzard's OnEnter fills.
    Frame("FriendsTooltip", UIParent)
    for _, name in ipairs({ "Header", "NoteText", "BroadcastText", "GameAccount1Name", "GameAccount1Info", "GameAccount2Name",
        "GameAccount2Info" }) do
        Text(FriendsTooltip, nil, "", "FriendsTooltip" .. name)
    end
    FriendsFrameTooltip_SetLine = function(line, _, text) line:SetText(text or "") end

    local bnFrame = Frame("FriendsFrameBattlenetFrame", FriendsFrame)
    -- Your BattleTag in the header: the XML's blue, the number after "#" in a
    -- darker one (as Camelot's FriendsFrame_CheckBattlenetStatus writes it).
    S[Text(bnFrame, "Tag")].colour = { .345, .667, .867, 1 }
    local broadcast = Child(bnFrame, "BroadcastFrame")
    Child(broadcast, "EditBox", "EditBox")
    FriendsFrame_CheckBattlenetStatus = function()
        local _, tag, _, message = BNGetInfo()
        local symbol = not issecretvalue(tag) and tag and tag:find("#", 1, true)
        if symbol then tag = tag:sub(1, symbol - 1) .. "|cff416380" .. tag:sub(symbol) .. "|r" end
        FriendsFrameBattlenetFrame.Tag:SetText(tag)
        FriendsFrameBattlenetFrame.BroadcastFrame.EditBox:SetText(message)
    end

    local ignore = Child(FriendsFrame, "IgnoreListWindow")
    G.ignoreRows = List(ignore, "ScrollBox")
    IgnoreList_InitButton = function(button, data)
        button.index, button.type = data.index, data.squelchType
        button.name:SetText(data.squelchType == SQUELCH_TYPE_IGNORE and C_FriendList.GetIgnoreName(data.index) or "|Kq7|k")
    end

    -- Blizzard_RecentAllies: a mixin; its rows sit in the friends window.
    RecentAlliesEntryMixin = { SetCharacterName = function(self)
        self.CharacterData.Name:SetText("|cffffd100" .. self.elementData.characterData.name .. "|r")
    end }
    local recent = Frame("RecentAlliesFrame", FriendsFrame)
    G.recentRows = List(Child(recent, "List"), "ScrollBox")

    -- Blizzard_BNet's pop-up. The online one's character name comes later.
    Button("BNToastFrame", UIParent, { ShowToast = function(self, kind, id)
        local account = G.bn[id]
        self.toastType = kind
        self.TopLine:SetText(account and account.accountName or "")
        self.MiddleLine:SetText("")
        if kind == 1 then
            self.BottomLine:SetText("has come online.")
            G.lateName = function() self.MiddleLine:SetFormattedText(account.gameAccountInfo.characterName) end
        elseif kind == 3 then
            self.BottomLine:SetText(account.customMessage)
        else
            self.TopLine:SetText("New friend request")
            self.BottomLine:SetText("")
        end
    end })
    Text(BNToastFrame, "TopLine")
    Text(BNToastFrame, "MiddleLine")
    Text(BNToastFrame, "BottomLine")
end

-- The guild and communities window (Blizzard_Communities), guild news,
-- charters and the guild event log.
local function Guild()
    H.guild = { { name = "Brannoc Stonehelm", classFile = "WARRIOR" }, { name = "Tamsin Reed", classFile = "MAGE" } }
    CommunitiesMemberListEntryMixin = {
        SetMember = function(self, info)
            self.memberInfo = info
            self.NameFrame.Name:SetText(info and info.name or nil)
            self:RefreshExpandedColumns()
        end,
        RefreshExpandedColumns = function(self)
            local info = self.memberInfo
            if not self.expanded or not info then return end
            self.Zone:SetText(info.zone or "")
            self.Note:SetText(info.memberNote or "")
        end,
    }
    -- As the game's list: your own clubs come marked isClub, another guild's
    -- invitation isInvitation, and a ticket holds its club one layer down.
    CommunitiesListEntryMixin = { Init = function(self, data)
        local club = data.clubInfo
        if club and club.isTicket then club = club.clubInfo end
        self.Name:SetText(club and club.name or "Join a community")
    end }
    local frame = Frame("CommunitiesFrame", UIParent)
    G.memberRows = List(Child(frame, "MemberList"), "ScrollBox")
    G.clubRows = List(Child(frame, "CommunitiesList"), "ScrollBox")

    local detail = Child(frame, "GuildMemberDetailFrame", "Frame", nil, {
        DisplayMember = function(self, _, info)
            self.Name:SetText(info.name)
            self.ZoneText:SetText(info.zone)
            self.NoteBackground.PersonalNoteText:SetText(info.memberNote)
            self.OfficerNoteBackground.OfficerNoteText:SetText(info.officerNote)
            self:Show()
        end,
        GetMemberInfo = function() return G.detailInfo end,
    })
    Text(detail, "Name")
    Text(detail, "ZoneText")
    Text(Child(detail, "NoteBackground"), "PersonalNoteText")
    Text(Child(detail, "OfficerNoteBackground"), "OfficerNoteText")
    H.Blizzard(function() detail:Hide() end)

    local details = Child(frame, "GuildDetailsFrame")
    local info = Child(details, "Info")
    G.motd = Child(Child(info, "MOTDScrollFrame"), "MOTD", "SimpleHTML")
    local scrollChild = H.BlizzardFrame("Frame", nil, info)
    G.infoText = Text(scrollChild, "Details", "Raids on Friday. Discord: knights.gg")
    Child(info, "DetailsFrame", "Frame", nil, { GetScrollChild = function() return scrollChild end })
    G.newsRows = List(Child(details, "News"), "ScrollBox")
    G.news = {
        { newsType = NEWS_ITEM_LOOTED, whoText = "Brannoc Stonehelm", whatText = "[Thunderfury]" },
        { newsType = NEWS_ITEM_LOOTED, whoText = "Zriel Gustbellow", whatText = "[Copper Ore]" },
        { newsType = NEWS_GUILD_ACHIEVEMENT, whoText = "Brannoc Stonehelm", whatText = "[Guild Level 5]" },
    }
    GuildNewsButton_SetNews = function(button, id)
        local news = G.news[id]
        button.newsInfo, button.newsType = news, news.newsType
        local who = news.newsType == NEWS_GUILD_ACHIEVEMENT and news.whatText or news.whoText
        button.text:SetFormattedText(_G["GUILD_NEWS_FORMAT" .. news.newsType], who, news.whatText)
    end
    GuildNewsButton_SetMOTD = function(button, text)
        button.newsInfo, button.newsType = nil, NEWS_MOTD
        button.text:SetFormattedText("Message of the Day: %s", text)
    end

    local log = Frame("CommunitiesGuildLogFrame", UIParent)
    G.log = Child(Child(Child(Child(log, "Container"), "ScrollFrame"), "Child"), "HTMLFrame", "SimpleHTML")

    -- Charters (Blizzard_UIPanels_Game).
    GetPetitionInfo = function() return "guild", "Knights of Zriel", "", 9, "Brannoc Stonehelm", false, 3 end
    GetNumPetitionNames = function() return 2 end
    GetPetitionNameInfo = function(i) return ({ "Tamsin Reed", "Zriel Gustbellow" })[i] end
    local petition = Frame("PetitionFrame", UIParent)
    for _, name in ipairs({ "NpcNameText", "CharterName", "MasterName", "MemberName1", "MemberName2", "MemberName3" }) do
        Text(petition, nil, "", "PetitionFrame" .. name)
    end
    H.Blizzard(function() petition:Hide() end)
    PetitionFrame_Update = function()
        local _, title, _, _, origin, _, minimum = GetPetitionInfo()
        PetitionFrameNpcNameText:SetFormattedText("%s Charter", title)
        PetitionFrameCharterName:SetText(title)
        PetitionFrameMasterName:SetText(origin)
        for i = 1, minimum do
            _G["PetitionFrameMemberName" .. i]:SetText(i <= GetNumPetitionNames() and GetPetitionNameInfo(i) or "Not yet signed")
        end
    end
end

-- Mail (Blizzard_MailFrame) and the name suggestions (Blizzard_AutoComplete).
local function Mail()
    G.mail = {
        { sender = "Brannoc Stonehelm", subject = "Thanks Zriel", canReply = true,
            body = "Hi Zriel, here's the ore from Brannoc.\nBrannoc" },
        { sender = "Stormwind Auction House", subject = "Auction sold: Copper Ore", canReply = false, body = "",
            invoice = { "seller", "Copper Ore", "Grubb Fizzwick" } },
    }
    GetInboxHeaderInfo = function(i)
        local m = G.mail[i]
        if m then return nil, nil, m.sender, m.subject, 0, 0, 3, 0, false, nil, nil, m.canReply, false end
    end
    GetInboxText = function(i) return G.mail[i] and G.mail[i].body end
    GetInboxInvoiceInfo = function(i)
        local m = G.mail[i]
        if m and m.invoice then return m.invoice[1], m.invoice[2], m.invoice[3] end
    end
    Frame("InboxFrame", UIParent, { Update = function()
        for i = 1, INBOXITEMS_TO_DISPLAY do
            local m, button = G.mail[i], _G["MailItem" .. i .. "Button"]
            if m then
                button:Show()
                button.index = i
                _G["MailItem" .. i .. "Sender"]:SetText(m.sender)
                _G["MailItem" .. i .. "Subject"]:SetText(m.subject)
            else
                button:Hide()
                _G["MailItem" .. i .. "Sender"]:SetText("")
                _G["MailItem" .. i .. "Subject"]:SetText("")
            end
        end
    end })
    for i = 1, 7 do
        H.BlizzardFrame("CheckButton", "MailItem" .. i .. "Button", InboxFrame)
        Text(InboxFrame, nil, "", "MailItem" .. i .. "Sender")
        Text(InboxFrame, nil, "", "MailItem" .. i .. "Subject")
    end
    Frame("OpenMailFrame", UIParent, { Update = function()
        local m = G.mail[InboxFrame.openMailID]
        OpenMailSender.Name:SetText(m.sender)
        OpenMailSubject:SetText(m.subject)
        OpenMailBodyText:SetText(m.body, true)
        OpenMailInvoicePurchaser:SetText(m.invoice and (PURCHASED_BY_COLON .. " " .. m.invoice[3]) or "")
    end })
    Text(Frame("OpenMailSender", OpenMailFrame), "Name")
    Text(OpenMailFrame, nil, "", "OpenMailSubject")
    H.BlizzardFrame("SimpleHTML", "OpenMailBodyText", OpenMailFrame)
    Text(OpenMailFrame, nil, "", "OpenMailInvoicePurchaser")
    H.Blizzard(function() OpenMailFrame:Hide() end)
    H.BlizzardFrame("EditBox", "SendMailNameEditBox", UIParent)
    G.chatBox = H.BlizzardFrame("EditBox", nil, UIParent)
    Frame("AutoCompleteBox", UIParent)
    for i = 1, 5 do Button("AutoCompleteButton" .. i, AutoCompleteBox) end
    AutoComplete_UpdateResults = function(_, results)
        for i = 1, math.min(#results, 5) do _G["AutoCompleteButton" .. i]:SetText("|cff00ff00" .. results[i].name .. "|r") end
    end
end

-- The group finder and /who (Blizzard_GroupFinder_VanillaStyle, load on
-- demand): made when the test loads it.
local function GroupFinder()
    LFGWhoListButtonMixin = { InitButton = function(self, data)
        local info = data.info
        self.index = data.index
        self.Name:SetText(info.fullName)
        self.Variable:SetText(info.area)
        self.GuildName:SetText(info.fullGuildName or "")
    end }
    G.whoRows = List(Frame("LFGWhoListFrame", UIParent), "ScrollBox")
    G.results = { { name = "Brannoc Stonehelm", classFilename = "WARRIOR" }, H.SECRET, { name = "Zriel Gustbellow", classFilename = "DRUID" } }
    C_LFGList = { GetSearchResultLeaderInfo = function(id) return G.results[id] end }
    G.browseRows = List(Frame("LFGBrowseFrame", UIParent), "ScrollBox")
    LFGBrowseSearchEntry_Update = function(self)
        local leader = C_LFGList.GetSearchResultLeaderInfo(self.resultID)
        self.Name:SetText(issecretvalue(leader) and H.SECRET or leader.name)
    end
    local tip = Frame("LFGBrowseSearchEntryTooltip", UIParent)
    Text(Child(tip, "Leader"), "Name")
    G.memberFrames = { Frame(nil, tip), Frame(nil, tip) }
    for _, member in ipairs(G.memberFrames) do Text(member, "Name") end
    rawset(tip, "memberPool", { EnumerateActive = function()
        local i = 0
        return function()
            i = i + 1
            return G.memberFrames[i]
        end
    end })
    Text(tip, "Comment")
    G.members = { { name = "Tamsin Reed", classFile = "MAGE" }, { name = "Zriel Gustbellow", classFile = "DRUID" } }
    LFGBrowseSearchEntryTooltip_UpdateAndShow = function(self, resultID)
        local leader = C_LFGList.GetSearchResultLeaderInfo(resultID)
        local colour = H.CLASS_COLOURS[leader.classFilename]
        self.Leader.Name:SetText(leader.name)
        self.Leader.Name:SetTextColor(colour.r, colour.g, colour.b)
        for i, member in ipairs(G.members) do
            local c = H.CLASS_COLOURS[member.classFile]
            G.memberFrames[i].Name:SetText(member.name)
            G.memberFrames[i].Name:SetTextColor(c.r, c.g, c.b)
        end
        self.Comment:SetText("Deadmines, whisper Zriel or Tamsin")
    end
    LFGBrowseGroupDataDisplayComment_Update = function(self, text) self:SetText(text) end
end

-- The calendar (Blizzard_Calendar, load on demand).
local function Calendar()
    G.invites = { { name = "Brannoc Stonehelm", classFilename = "WARRIOR" }, { name = H.SECRET, classFilename = H.SECRET } }
    C_Calendar = { GetEventInfo = function() return { creator = "Tamsin Reed" } end, EventGetInvite = function(i) return G.invites[i] end }
    local view = Frame("CalendarViewEventFrame", UIParent)
    Text(view, nil, "", "CalendarViewEventCreatorName")
    G.inviteRows = List(Frame("CalendarViewEventInviteList", view), "ScrollBox")
    local create = Frame("CalendarCreateEventFrame", UIParent)
    Text(create, nil, "", "CalendarCreateEventCreatorName")
    H.Blizzard(function() create:Hide() end)
    CalendarEventInviteList_InitButtonShared = function(button, index, info)
        button.inviteIndex = index
        button.Name:SetText(info.name)
    end
    CalendarViewEventFrame_Update = function()
        CalendarViewEventCreatorName:SetFormattedText(CALENDAR_EVENT_CREATORNAME, C_Calendar.GetEventInfo().creator)
    end
    CalendarCreateEventFrame_Update = function()
        CalendarCreateEventCreatorName:SetFormattedText(CALENDAR_EVENT_CREATORNAME, C_Calendar.GetEventInfo().creator)
    end
end

-- The inspect window's guild tab (Blizzard_InspectUI, load on demand).
local function Inspect()
    Text(Frame("InspectGuildFrame", UIParent), "guildName")
    InspectGuildFrame_Update = function() InspectGuildFrame.guildName:SetText("Knights of Zriel") end
end

-- A fresh game with the social windows, logged in; returns the addon.
local function Fresh(saved)
    H.Environment()
    G = {}
    elementData = {}
    Constants()
    Friends()
    Guild()
    Mail()
    for _, name in ipairs({ "Blizzard_FriendsFrame", "Blizzard_BNet", "Blizzard_Communities", "Blizzard_RecentAllies",
        "Blizzard_MailFrame" }) do
        H.addOns[name] = true
    end
    P = H.Load(saved)
    return P
end

-- Drawing, as the game does it ---------------------------------------------------------------------

local function Run(fn, ...) return H.Blizzard(fn, ...) end

local function FriendRow(data)
    local row = Button(nil, FriendsListFrame.ScrollBox)
    Text(row, "name")
    Text(row, "info")
    Text(row, "Name")
    table.insert(G.friendRows, row)
    elementData[row] = data
    return row
end

local FRIEND_DATA = { { buttonType = 3, id = 1 }, { buttonType = 3, id = 2 }, { buttonType = 2, id = 1 }, { buttonType = 4, id = 1 } }
local function DrawFriends()
    for i, row in ipairs(G.friendRows) do
        local data = FRIEND_DATA[i]
        if data.buttonType == FRIENDS_BUTTON_TYPE_INVITE then
            Run(function() FriendsFrame_UpdateFriendInviteButton(row, data) end)
        else
            Run(function() FriendsFrame_UpdateFriendButton(row, data) end)
        end
    end
end

-- Blizzard's OnEnter for a friend's row: the hover box's lines.
local function HoverFriend(row)
    Run(function()
        local SetLine = FriendsFrameTooltip_SetLine
        if row.buttonType == FRIENDS_BUTTON_TYPE_BNET then
            local account = C_BattleNet.GetFriendAccountInfo(row.id)
            local game = account.gameAccountInfo
            SetLine(FriendsTooltipHeader, nil, account.accountName)
            SetLine(FriendsTooltipGameAccount1Name, nil, ("%s, Level %d %s %s"):format(game.characterName, game.characterLevel,
                game.raceName, game.className))
            SetLine(FriendsTooltipGameAccount1Info, nil, game.areaName .. " - Forever")
            SetLine(FriendsTooltipNoteText, nil, account.note)
            SetLine(FriendsTooltipBroadcastText, nil, account.customMessage)
            SetLine(FriendsTooltipGameAccount2Name, nil, "Pal")
        else
            local info = C_FriendList.GetFriendInfoByIndex(row.id)
            SetLine(FriendsTooltipHeader, nil, info.name)
            SetLine(FriendsTooltipGameAccount1Name, nil, FRIENDS_LEVEL_TEMPLATE:format(info.level, info.className))
            SetLine(FriendsTooltipGameAccount1Info, nil, info.area)
            SetLine(FriendsTooltipNoteText, nil, info.notes)
        end
    end)
end

local function IgnoreRow(data)
    local row = Button(nil, FriendsFrame.IgnoreListWindow.ScrollBox)
    Text(row, "name")
    table.insert(G.ignoreRows, row)
    Run(function() IgnoreList_InitButton(row, data) end)
    return row
end

local function RecentRow(character)
    local row = Mixin(Button(nil, RecentAlliesFrame.List.ScrollBox), RecentAlliesEntryMixin)
    Text(Child(row, "CharacterData"), "Name")
    table.insert(G.recentRows, row)
    Run(function()
        row.elementData = { characterData = character }
        row:SetCharacterName()
    end)
    return row
end

local function MemberRow()
    local row = Mixin(Button(nil, CommunitiesFrame.MemberList.ScrollBox), CommunitiesMemberListEntryMixin)
    Text(Child(row, "NameFrame"), "Name")
    Text(row, "Zone")
    Text(row, "Note")
    rawset(row, "expanded", true)
    table.insert(G.memberRows, row)
    return row
end

local function ClubRow(data)
    local row = WithData(Mixin(Button(nil, CommunitiesFrame.CommunitiesList.ScrollBox), CommunitiesListEntryMixin))
    Text(row, "Name")
    table.insert(G.clubRows, row)
    elementData[row] = data
    Run(function() row:Init(data) end)
    return row
end

local function NewsRow()
    local row = Button(nil, CommunitiesFrame.GuildDetailsFrame.News.ScrollBox)
    Text(row, "text")
    table.insert(G.newsRows, row)
    return row
end

local function WhoRow(data)
    local row = WithData(Mixin(Button(nil, LFGWhoListFrame.ScrollBox), LFGWhoListButtonMixin))
    Text(row, "Name")
    Text(row, "Variable")
    Text(row, "GuildName")
    table.insert(G.whoRows, row)
    elementData[row] = data
    Run(function() row:InitButton(data, false) end)
    return row
end

-- The text our cover shows over a row's hidden name, and whether it shows.
local function CoverOf(row)
    for _, child in ipairs(S[row].children) do
        if not S[child].sealed then
            local text = S[child].children[1]
            return text and S[text].text, S[child].shown
        end
    end
end

-- Our own frame laid over one region of a row (your /who row's guild): its
-- text, whether it shows and its colour; nil when none was made.
local function CoverOver(row, region)
    for _, child in ipairs(S[row].children) do
        local at = S[child].points and S[child].points[1]
        if not S[child].sealed and at and rawequal(at[2], region) then
            local text = S[child].children[1]
            local c = S[text].colour
            return S[text].text, S[child].shown, c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "none"
        end
    end
end

local function Class(file)
    local c = H.CLASS_COLOURS[file]
    return P:Colourise(H.CLASS_NAMES[file], c.r, c.g, c.b)
end
local function Grey(word) return P:Colourise(word, .78, .78, .78) end
-- Your BattleTag as the game draws it, and the header's own blue.
local REAL_TAG, TAG_BLUE = "Squirt|cff416380#1234|r", "0.345 0.667 0.867"
local function TagColour()
    local c = S[FriendsFrameBattlenetFrame.Tag].colour
    return ("%.3f %.3f %.3f"):format(c[1], c[2], c[3])
end
local function Alphas(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring(H.Alpha((select(i, ...)))) end
    return table.concat(out)
end

-- Off: nothing at all ---------------------------------------------------------------------------------

Fresh(nil)
local hooked = {}
for _, hook in ipairs(H.hooks) do hooked[hook.key] = (hooked[hook.key] or 0) + 1 end
Equal(hooked.SetMember, 1, "the roster row mixin is hooked at load, before rows copy it")
Equal(hooked.SetCharacterName, 1, "and recent players'")
Equal(hooked.FriendsFrame_UpdateFriendButton, nil, "global hooks wait for private mode")
Equal(hooked.InitButton, nil, "the /who mixin waits for its addon to load")

for _ = 1, #FRIEND_DATA do FriendRow() end
DrawFriends()
local wowRow, offlineRow, bnRow, inviteRow = G.friendRows[1], G.friendRows[2], G.friendRows[3], G.friendRows[4]
Run(FriendsFrame_CheckBattlenetStatus)
local ignoreRow = IgnoreRow({ index = 1, squelchType = SQUELCH_TYPE_IGNORE })
local blockRow = IgnoreRow({ index = 1, squelchType = SQUELCH_TYPE_BLOCK_INVITE })
local recentRow = RecentRow({ name = "Tamsin Reed", classID = 8 })
local me = { name = "Zriel Gustbellow", isSelf = true, classID = 11, zone = "Elwynn Forest", memberNote = "Alt of the GM",
    officerNote = "Main tank" }
local brannoc = { name = "Brannoc Stonehelm", isSelf = false, classID = 1, zone = "Ironforge", memberNote = "Mining",
    officerNote = "Trial" }
local hiddenMember = { name = H.SECRET, isSelf = false, classID = H.SECRET, zone = H.SECRET, memberNote = H.SECRET }
local myRow, brannocRow, secretRow = MemberRow(), MemberRow(), MemberRow()
Run(function()
    myRow:SetMember(me)
    brannocRow:SetMember(brannoc)
    secretRow:SetMember(hiddenMember)
end)
local guildRow = ClubRow({ clubInfo = { name = "Knights of Zriel", clubType = Enum.ClubType.Guild, isClub = true } })
local communityRow = ClubRow({ clubInfo = { name = "Zriel's Pals", clubType = Enum.ClubType.Character, isClub = true } })
local joinRow = ClubRow({})
local invitedRow = ClubRow({ clubInfo = { name = "Iron Wolves", clubType = Enum.ClubType.Guild, isInvitation = true } })
local ticketRow = ClubRow({ clubInfo = { isTicket = true, clubInfo = { name = "Iron Wolves", clubType = Enum.ClubType.Guild } } })
local lootRow, myLootRow, achievementRow, motdRow = NewsRow(), NewsRow(), NewsRow(), NewsRow()
Run(function()
    GuildNewsButton_SetNews(lootRow, 1)
    GuildNewsButton_SetNews(myLootRow, 2)
    GuildNewsButton_SetNews(achievementRow, 3)
    GuildNewsButton_SetMOTD(motdRow, "Welcome Zriel!")
end)
Run(function() InboxFrame:Update() end)

Equal(T(wowRow.name), "Brannoc Stonehelm, Level 60 Warrior", "off: the real friend")
Equal(T(bnRow.name), "|Kq1|k (Odessa Vale)", "off: the real Battle.net friend")
Equal(T(FriendsFrameBattlenetFrame.Tag), REAL_TAG, "off: your BattleTag")
Equal(T(myRow.NameFrame.Name), "Zriel Gustbellow", "off: your roster row")
Equal(T(MailItem1Sender), "Brannoc Stonehelm", "off: the inbox")
Equal(H.Writes(), 0, "off: nothing of Blizzard's touched")
Equal(#H.cvarWrites, 0, "and no game setting")
Equal(H.Problems(), "", "nothing wrong while off")

-- On: friends -----------------------------------------------------------------------------------------

P:SetPrivate(true)
hooked = {}
for _, hook in ipairs(H.hooks) do hooked[hook.key] = (hooked[hook.key] or 0) + 1 end
Equal(hooked.FriendsFrame_UpdateFriendButton, 1, "on: the global hooks go in, once")
Equal(hooked.ShowToast, 1, "and the pop-up's")

Equal(T(wowRow.name), Class("WARRIOR") .. ", Level 60 Warrior", "on: an online friend becomes their class, at once")
Equal(Alphas(wowRow.info), "0", "their zone hidden")
Equal(T(offlineRow.name), "Mage", "an offline friend: the class, not coloured")
Equal(T(offlineRow.info) .. " " .. Alphas(offlineRow.info), "Offline 1", "and still says offline")
Equal(T(bnRow.name), "Friend (" .. Class("PRIEST") .. ")", "a Battle.net friend: Friend, with their character's class")
Equal(Alphas(bnRow.info), "0", "their zone hidden")
Equal(T(inviteRow.Name), "Friend request", "a friend request")
Equal(T(FriendsFrameBattlenetFrame.Tag), "Battle.net", "your BattleTag")
True(S[FriendsFrameBattlenetFrame.BroadcastFrame.EditBox].password, "your broadcast box shows stars")
DrawFriends()
Equal(T(wowRow.name), Class("WARRIOR") .. ", Level 60 Warrior", "and after the game redraws the list")
Equal(T(bnRow.name), "Friend (" .. Class("PRIEST") .. ")", "the Battle.net friend too")

HoverFriend(bnRow)
Equal(T(FriendsTooltipHeader), "Friend", "hover box: a Battle.net friend's name")
Equal(T(FriendsTooltipGameAccount1Name), Class("PRIEST") .. ", Level 60 Human Priest", "their character's name swapped")
Equal(Alphas(FriendsTooltipGameAccount1Name, FriendsTooltipGameAccount1Info), "10", "where they are, hidden")
Equal(Alphas(FriendsTooltipNoteText, FriendsTooltipBroadcastText), "00", "the note and broadcast hidden")
Equal(Alphas(FriendsTooltipGameAccount2Name), "0", "another game's account name (a BattleTag) hidden")
HoverFriend(wowRow)
Equal(T(FriendsTooltipHeader), Class("WARRIOR"), "hover box: a friend's name")
Equal(T(FriendsTooltipGameAccount1Name), "Level 60 Warrior", "their level and class kept")
Equal(Alphas(FriendsTooltipGameAccount1Name, FriendsTooltipNoteText), "10", "the note hidden")

Equal(T(ignoreRow.name), Grey("Player"), "ignore list: a name")
Equal(T(blockRow.name), Grey("Player"), "and a Battle.net block")
Equal(T(recentRow.CharacterData.Name), Class("MAGE"), "recent players")

Run(function() BNToastFrame:ShowToast(1, 1) end)
Equal(T(BNToastFrame.TopLine) .. "|" .. T(BNToastFrame.BottomLine), "A friend|has come online.", "a came-online pop-up says A friend")
Run(G.lateName)
Equal(Alphas(BNToastFrame.MiddleLine), "0", "and the character's name that comes later stays hidden")
Run(function() BNToastFrame:ShowToast(3, 1) end)
Equal(T(BNToastFrame.TopLine) .. "|" .. T(BNToastFrame.BottomLine), "A friend|New broadcast", "a broadcast pop-up")
Run(function() BNToastFrame:ShowToast(5) end)
Equal(T(BNToastFrame.TopLine), "New friend request", "a request pop-up names nobody: left alone")

-- On: the guild --------------------------------------------------------------------------------------

Equal(T(myRow.NameFrame.Name), "Druid", "roster: you, by your class")
Equal(T(brannocRow.NameFrame.Name), "Warrior", "a member, by class (the game colours the row)")
Equal(T(secretRow.NameFrame.Name), "Player", "a secret member (in a dungeon): Player, never read")
Equal(Alphas(myRow.Note, brannocRow.Note, secretRow.Note), "000", "public notes hidden")
Equal(H.Alpha(myRow.Zone) .. " " .. H.Alpha(brannocRow.Zone), "0 1", "your zone hidden, others' kept")
Run(function() myRow:SetMember(brannoc) end)
Equal(H.Alpha(myRow.Zone), 1, "a row reused for someone else shows their zone")
Equal(T(myRow.NameFrame.Name), "Warrior", "and their label")
Run(function() myRow:SetMember(me) end)
Equal(H.Alpha(myRow.Zone), 0, "back to you: hidden again")
local quietRow = MemberRow()
Run(function()
    quietRow:SetMember(brannoc)
    quietRow:SetMember({ name = "Tamsin Reed", isSelf = false, classID = 8, zone = "Darnassus", memberNote = "" })
end)
Equal(T(quietRow.NameFrame.Name) .. " " .. Alphas(quietRow.Note), "Mage 0", "a row reused for someone with no note")

local detail = CommunitiesFrame.GuildMemberDetailFrame
Run(function() detail:DisplayMember(1, me) end)
Equal(T(detail.Name), "Druid", "details panel: the name")
Equal(Alphas(detail.NoteBackground.PersonalNoteText, detail.OfficerNoteBackground.OfficerNoteText), "00", "both notes hidden")
Equal(H.Alpha(detail.ZoneText), 0, "your zone hidden")
Run(function() detail:DisplayMember(1, hiddenMember) end)
Equal(T(detail.Name), "Player", "a secret member's details")
Equal(H.Alpha(detail.ZoneText), 1, "their zone isn't yours")

Equal(T(guildRow.Name) .. "|" .. T(communityRow.Name) .. "|" .. T(joinRow.Name), "Guild|Community|Join a community",
    "the guild and community list")
Equal(T(invitedRow.Name) .. "|" .. T(ticketRow.Name), "Guild|Guild", "another guild's invitation and a ticket too")
Equal(H.Alpha(G.motd) .. H.Alpha(G.infoText) .. H.Alpha(G.log), "000", "message of the day, guild info and the event log hidden")
Equal(T(lootRow.text), Class("WARRIOR") .. " obtained [Thunderfury].", "news: a guildmate's loot")
Equal(T(myLootRow.text), Class("DRUID") .. " obtained [Copper Ore].", "your own")
Equal(T(achievementRow.text), "Guild earned [Guild Level 5].", "a guild achievement names nobody")
Equal(T(motdRow.text), "Message of the day hidden", "the news feed's message of the day")

-- Charters are the Windows module's (its pop-ups setting): with that off,
-- nothing of this module's touches one.
P:Set("popups", false)
Run(function() PetitionFrame:Show() end)
Run(PetitionFrame_Update, PetitionFrame)
Equal(T(PetitionFrameMasterName) .. "|" .. T(PetitionFrameCharterName) .. "|" .. T(PetitionFrameMemberName2),
    "Brannoc Stonehelm|Knights of Zriel|Zriel Gustbellow", "a charter is left to the Windows module")
P:Set("popups", true)

Inspect()
H.LoadAddOn("Blizzard_InspectUI")
Run(InspectGuildFrame_Update)
Equal(T(InspectGuildFrame.guildName), "Guild", "the inspect window's guild tab, once it loads")

-- Applying again is the same as once: nothing written twice.
do
    local writes = H.Writes()
    P:Module("Social"):Apply(true)
    Equal(H.Writes(), writes, "applying again changes nothing")
end

-- On: mail -------------------------------------------------------------------------------------------

Equal(T(MailItem1Sender), Class("WARRIOR"), "inbox: a player's letter, at once")
Equal(T(MailItem1Subject), "Thanks " .. Class("DRUID"), "your name in a subject")
Equal(T(MailItem2Sender), "Stormwind Auction House", "the Auction House keeps its name")
Run(function() InboxFrame:Update() end)
Equal(T(MailItem1Sender), Class("WARRIOR"), "and after the game redraws it")

Run(function()
    InboxFrame.openMailID = 1
    OpenMailFrame:Show()
    OpenMailFrame:Update()
end)
Equal(T(OpenMailSender.Name), "Brannoc Stonehelm", "an open letter: the sender's text is the game's, so Reply still works")
Equal(H.Alpha(OpenMailSender.Name), 0, "but it's hidden")
local coverText, coverShown = CoverOf(OpenMailSender)
Equal(coverText, "Warrior", "under our own label")
True(coverShown, "which shows")
Equal(T(OpenMailBodyText), "Hi Druid, here's the ore from Warrior.\nBrannoc", "names in the letter swapped, as plain words "
    .. "(a guildmate's first name alone starting a line is left: it may be a word)")
Run(function()
    InboxFrame.openMailID = 2
    OpenMailFrame:Update()
end)
Equal(H.Alpha(OpenMailSender.Name), 1, "the Auction House's letter shows its sender")
Equal(select(2, CoverOf(OpenMailSender)), false, "with no label over it")
Equal(T(OpenMailInvoicePurchaser), "Purchased by: " .. Grey("Player"), "an invoice's buyer")
True(not S[SendMailNameEditBox].password, "the To box shows the name you type")

Run(function() AutoCompleteBox.parent = SendMailNameEditBox end)
Run(AutoComplete_UpdateResults, AutoCompleteBox, { { name = "Brannoc Stonehelm" }, { name = "Tamsin Reed" } })
Equal(T(AutoCompleteButton1) .. "|" .. T(AutoCompleteButton2), Class("WARRIOR") .. "|" .. Class("MAGE"), "the To box's suggestions")
Run(function() AutoCompleteBox.parent = G.chatBox end)
Run(AutoComplete_UpdateResults, AutoCompleteBox, { { name = "Brannoc Stonehelm" } })
Equal(T(AutoCompleteButton1), "|cff00ff00Brannoc Stonehelm|r", "chat's suggestions are left to chat")

-- On: the group finder and /who, loaded later -------------------------------------------------------

GroupFinder()
H.LoadAddOn("Blizzard_GroupFinder_VanillaStyle")
local whoBrannoc = WhoRow({ index = 1, info = { fullName = "Brannoc Stonehelm", filename = "WARRIOR", area = "Ironforge",
    fullGuildName = "Knights of Zriel" } })
local whoMe = WhoRow({ index = 2, info = { fullName = "Zriel Gustbellow", filename = "DRUID", area = "Elwynn Forest",
    fullGuildName = "Knights of Zriel" } })
Equal(T(whoBrannoc.Name), "Brannoc Stonehelm", "/who: the name stays the game's, for its right-click menu")
Equal(H.Alpha(whoBrannoc.Name), 0, "hidden")
Equal(CoverOf(whoBrannoc), "Warrior", "under our label")
Equal(CoverOf(whoMe), "Druid", "your own row")
Equal(H.Alpha(whoMe.Variable) .. H.Alpha(whoMe.GuildName), "00", "your zone and guild hidden")
Equal(H.Alpha(whoBrannoc.Variable), 1, "others' kept")

local function BrowseRow(resultID)
    local row = Button(nil, LFGBrowseFrame.ScrollBox)
    Text(row, "Name")
    table.insert(G.browseRows, row)
    Run(function()
        row.resultID = resultID
        LFGBrowseSearchEntry_Update(row)
    end)
    return row
end
local listing, secretListing, myListing = BrowseRow(1), BrowseRow(2), BrowseRow(3)
Equal(T(listing.Name), Class("WARRIOR"), "group finder: a leader")
Equal(T(secretListing.Name), Grey("Player"), "a secret listing: Player, never read")
Equal(T(myListing.Name), Class("DRUID"), "your own listing")
Run(LFGBrowseSearchEntryTooltip_UpdateAndShow, LFGBrowseSearchEntryTooltip, 1)
Equal(T(LFGBrowseSearchEntryTooltip.Leader.Name), Class("WARRIOR"), "its hover box: the leader")
Equal(T(G.memberFrames[1].Name) .. "|" .. T(G.memberFrames[2].Name), Class("MAGE") .. "|" .. Class("DRUID"),
    "members, by their colour")
Equal(T(LFGBrowseSearchEntryTooltip.Comment), "Deadmines, whisper " .. Class("DRUID") .. " or " .. Class("MAGE"),
    "names in the comment")
local comment = Text(UIParent, nil, "")
Run(LFGBrowseGroupDataDisplayComment_Update, comment, "Need healer, ask Brannoc Stonehelm")
Equal(T(comment), "Need healer, ask " .. Class("WARRIOR"), "a listing's comment")

-- On: the calendar, loaded later -----------------------------------------------------------------------

Calendar()
H.LoadAddOn("Blizzard_Calendar")
local function InviteRow(index)
    local row = Button(nil, CalendarViewEventInviteList.ScrollBox)
    Text(row, "Name")
    table.insert(G.inviteRows, row)
    Run(CalendarEventInviteList_InitButtonShared, row, index, C_Calendar.EventGetInvite(index))
    return row
end
local invite, secretInvite = InviteRow(1), InviteRow(2)
Equal(T(invite.Name), "Warrior", "calendar: an invite (the game colours it)")
Equal(T(secretInvite.Name), "Player", "a secret invite")
Run(CalendarViewEventFrame_Update)
Equal(T(CalendarViewEventCreatorName), "Created by " .. Class("MAGE"), "who made the event")
Run(CalendarCreateEventFrame_Update)
Equal(T(CalendarCreateEventCreatorName), "Created by " .. Class("MAGE"), "and in the edit window")
do
    local writes = H.Writes()
    P:Module("Social"):Apply(true)
    Equal(H.Writes(), writes, "with every window showing, applying again changes nothing")
end
Equal(H.Problems(), "", "nothing wrong while on")

-- Ticks: each puts back only its own --------------------------------------------------------------------

P:Set("friends", false)
Equal(T(wowRow.name), "Brannoc Stonehelm, Level 60 Warrior", "friends unticked: names back")
Equal(T(wowRow.info) .. "|" .. T(bnRow.info) .. " " .. Alphas(wowRow.info, bnRow.info), "Ironforge|Stormwind 11", "zones back")
Equal(T(FriendsFrameBattlenetFrame.Tag), REAL_TAG, "your BattleTag back")
Equal(S[FriendsFrameBattlenetFrame.BroadcastFrame.EditBox].password, false, "the broadcast box readable")
Equal(T(myRow.NameFrame.Name), "Druid", "the roster untouched")
H.ResetWrites()
DrawFriends()
Equal(H.Writes(), 0, "the list redraws untouched while unticked")
P:Set("friends", true)
Equal(T(wowRow.name), Class("WARRIOR") .. ", Level 60 Warrior", "ticked again: swapped at once")

P:Set("whoList", false)
Equal(H.Alpha(whoBrannoc.Name) .. H.Alpha(whoMe.Variable), "11", "/who unticked: names and your zone show")
Equal(select(2, CoverOf(whoBrannoc)), false, "the label is gone")
Equal(T(ignoreRow.name) .. "|" .. T(recentRow.CharacterData.Name), "Grubb Fizzwick||cffffd100Tamsin Reed|r",
    "ignore and recent players back")
P:Set("whoList", true)
Equal(H.Alpha(whoBrannoc.Name), 0, "ticked again")
Equal(CoverOf(whoBrannoc), "Warrior", "with its label")

P:Set("roster", false)
Equal(T(brannocRow.NameFrame.Name) .. "|" .. T(brannocRow.Note) .. " " .. Alphas(brannocRow.Note), "Brannoc Stonehelm|Mining 1",
    "roster unticked")
Equal(H.Alpha(myRow.Zone) .. H.Alpha(G.log), "11", "your zone and the event log show")
Equal(T(lootRow.text), Class("WARRIOR") .. " obtained [Thunderfury].", "the news untouched")
P:Set("roster", true)

P:Set("news", false)
Equal(T(lootRow.text) .. "|" .. T(motdRow.text), "Brannoc Stonehelm obtained [Thunderfury].|Message of the Day: Welcome Zriel!",
    "news unticked")
Equal(H.Alpha(G.motd) .. H.Alpha(G.infoText), "11", "message of the day and info show")
P:Set("news", true)
Equal(T(lootRow.text), Class("WARRIOR") .. " obtained [Thunderfury].", "news ticked again: worked out afresh")

P:Set("guildName", false)
Equal(T(guildRow.Name) .. "|" .. T(communityRow.Name) .. "|" .. T(InspectGuildFrame.guildName),
    "Knights of Zriel|Zriel's Pals|Knights of Zriel", "guild name unticked")
P:Set("guildName", true)

P:Set("mail", false)
Equal(T(MailItem1Sender) .. "|" .. T(MailItem1Subject), "Brannoc Stonehelm|Thanks Zriel", "mail unticked: the inbox")
True(not S[SendMailNameEditBox].password, "the To box readable")
P:Set("mail", true)

P:Set("bnToasts", false)
Equal(T(BNToastFrame.TopLine), "New friend request", "pop-ups unticked: nothing to put back on a request")
Run(function() BNToastFrame:ShowToast(1, 1) end)
Equal(T(BNToastFrame.TopLine), "|Kq1|k", "and the next one shows the friend")
P:Set("bnToasts", true)

P:Set("groupFinder", false)
Equal(T(listing.Name), "Brannoc Stonehelm", "group finder unticked")
P:Set("groupFinder", true)
P:Set("calendar", false)
Equal(T(invite.Name) .. "|" .. T(CalendarViewEventCreatorName), "Brannoc Stonehelm|Created by Tamsin Reed", "calendar unticked")
P:Set("calendar", true)
Equal(T(invite.Name), "Warrior", "ticked again")

-- Name settings re-label what's showing -------------------------------------------------------------------

P:Set("nameStyle", "player")
Equal(T(wowRow.name), Grey("Player") .. ", Level 60 Warrior", "Player style: the friends list")
Equal(T(bnRow.name), "Friend", "a Battle.net friend is still Friend")
Equal(T(myRow.NameFrame.Name) .. "|" .. T(brannocRow.NameFrame.Name), "Player|Player", "the roster")
Equal(CoverOf(whoBrannoc), "Player", "/who")
Equal(T(lootRow.text), Grey("Player") .. " obtained [Thunderfury].", "the news, from the game's own text")
Equal(T(MailItem1Subject), "Thanks " .. Grey("Player"), "a subject")
P:Set("myName", "Mr Shadow")
Equal(T(myRow.NameFrame.Name), "Mr Shadow", "your typed name: the roster")
Equal(T(FriendsFrameBattlenetFrame.Tag), "Mr Shadow", "your BattleTag, in its own colour (the game's own, to begin with)")
Equal(T(myLootRow.text), "Mr Shadow obtained [Copper Ore].", "the news")
Equal(CoverOf(whoMe), "Mr Shadow", "/who")
-- Your typed name in each colour, everywhere it shows here: in text (your
-- BattleTag, the news, a subject, your listing, the group finder's hover box
-- and its comment), on our label over your /who row (the game's own: the
-- colour of the name it covers), and plain where the game colours the row
-- (the roster, the details panel).
do
    local function CoverColour(row)
        for _, child in ipairs(S[row].children) do
            if not S[child].sealed then
                local c = S[S[child].children[1]].colour
                return c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "none"
            end
        end
    end
    S[whoMe.Name].colour = { .5, .6, .7, 1 }
    Run(function() detail:DisplayMember(1, me) end)
    local cases = { { "accent", "0.69 0.49 0.94", P.ACCENT }, { "class", "1.00 0.49 0.04", { 1, .49, .04 } },
        { "white", "1.00 1.00 1.00", { 1, 1, 1 } }, { "game", "0.50 0.60 0.70" } }
    for _, case in ipairs(cases) do
        local choice, rgb = case[1], case[3]
        P:Set("myColour", choice)
        local mine = rgb and P:Colourise("Mr Shadow", rgb[1], rgb[2], rgb[3]) or "Mr Shadow"
        Run(LFGBrowseSearchEntryTooltip_UpdateAndShow, LFGBrowseSearchEntryTooltip, 1)
        Equal(T(FriendsFrameBattlenetFrame.Tag) .. "|" .. T(myLootRow.text) .. "|" .. T(MailItem1Subject),
            mine .. "|" .. mine .. " obtained [Copper Ore].|Thanks " .. mine, choice .. ": BattleTag, the news and a subject")
        Equal(T(myListing.Name) .. "|" .. T(G.memberFrames[2].Name) .. "|" .. T(LFGBrowseSearchEntryTooltip.Comment),
            mine .. "|" .. mine .. "|Deadmines, whisper " .. mine .. " or " .. Grey("Player"), choice .. ": the group finder")
        Equal(CoverOf(whoMe) .. " / " .. CoverColour(whoMe), "Mr Shadow / " .. case[2], choice .. ": your /who row's label")
        Equal(T(myRow.NameFrame.Name) .. "|" .. T(detail.Name) .. "|" .. tostring(S[myRow.NameFrame.Name].colour) .. "|"
            .. tostring(S[detail.Name].colour), "Mr Shadow|Mr Shadow|nil|nil", choice .. ": the roster and details panel, uncoloured")
        Equal(T(listing.Name), Grey("Player"), choice .. ": anyone else as before")
    end
    S[whoMe.Name].colour = nil
end
-- A made-up BattleTag ("Your BattleTag becomes"): on your BattleTag instead
-- of your name, drawn as the game draws the real one (the number in its
-- darker blue) in the game's own colour, else all in your Name colour; your
-- name everywhere else stays your typed name.
do
    local tag = FriendsFrameBattlenetFrame.Tag
    local FAKE = "Fake|cff416380#9999|r"
    P:Set("myTag", "Fake#9999")
    Equal(T(tag) .. " / " .. TagColour(), FAKE .. " / " .. TAG_BLUE, "a made-up BattleTag at once, looking like the real one")
    Equal(T(myRow.NameFrame.Name) .. "|" .. T(myLootRow.text) .. "|" .. CoverOf(whoMe), "Mr Shadow|Mr Shadow obtained [Copper Ore].|Mr Shadow",
        "your typed name everywhere else")
    Run(FriendsFrame_CheckBattlenetStatus)
    Equal(T(tag), FAKE, "and after the game draws the header again")
    do
        local writes = H.Writes()
        P:Module("Social"):Apply(true)
        Equal(H.Writes(), writes, "applying again writes nothing")
    end
    for _, case in ipairs({ { "accent", P.ACCENT }, { "class", { 1, .49, .04 } }, { "white", { 1, 1, 1 } } }) do
        P:Set("myColour", case[1])
        local rgb = case[2]
        Equal(T(tag) .. " / " .. TagColour(), P:Colourise("Fake#9999", rgb[1], rgb[2], rgb[3]) .. " / " .. TAG_BLUE,
            case[1] .. ": all of it in that colour, the header's own blue left")
        Equal(T(myLootRow.text), P:Colourise("Mr Shadow", rgb[1], rgb[2], rgb[3]) .. " obtained [Copper Ore].", case[1] .. ": your name too")
    end
    P:Set("myColour", "game")
    Equal(T(tag), FAKE, "the game's own again: the real one's look")
    P:Set("myTag", "Streamer")
    Equal(T(tag) .. " / " .. TagColour(), "Streamer / " .. TAG_BLUE, "one with no number: all in the header's blue")
    P:Set("nameStyle", "hidden")
    Equal(T(tag), "Streamer", "the Hidden style leaves a typed BattleTag")
    P:Set("myName", "")
    Equal(T(tag), "Streamer", "and so does no typed name")
    P:Set("nameStyle", "player")
    P:Set("myName", "Mr Shadow")
    -- The game's text can't be read (a secret): the made-up one, plain.
    G.tag = H.SECRET
    Run(FriendsFrame_CheckBattlenetStatus)
    P:Set("myTag", "Fake#9999")
    Equal(T(tag), "Fake#9999", "the real one a secret: the made-up one, without the real one's look")
    G.tag = "Squirt#1234"
    Run(FriendsFrame_CheckBattlenetStatus)
    Equal(T(tag), FAKE, "readable again: its look back")
    P:Set("friends", false)
    Equal(T(tag) .. " / " .. TagColour(), REAL_TAG .. " / " .. TAG_BLUE, "friends unticked: your real BattleTag back")
    P:Set("friends", true)
    Equal(T(tag), FAKE, "ticked again: the made-up one")
    P:Set("myTag", "")
    Equal(T(tag), "Mr Shadow", "emptied: your typed name, as before")
    P:Set("myName", "")
    Equal(T(tag), "Battle.net", "and with no typed name either: Battle.net, as before")
    P:Set("myName", "Mr Shadow")
    Equal(H.Problems(), "", "no secret read")
end
-- A made-up guild ("Your guild becomes"): your own guild's row in the guild
-- list, and your own /who row's guild (laid over it, never rewritten).
-- Another guild's invitation or ticket, communities, the inspect tab (always
-- someone else's guild) and other players' /who rows never show it.
do
    local GUILD_GREY = "0.50 0.50 0.50"
    S[whoMe.GuildName].colour = { .5, .5, .5, 1 }
    S[whoBrannoc.GuildName].colour = { .5, .5, .5, 1 }
    local function Who(row)
        local text, shown = CoverOver(row, row.GuildName)
        return T(row.GuildName) .. " " .. H.Alpha(row.GuildName) .. " " .. tostring(text) .. " " .. tostring(shown)
    end
    Equal(CoverOver(whoMe, whoMe.GuildName), nil, "no made-up guild yet: nothing laid over your /who row's guild")
    P:Set("myGuild", "Lancers of Elwynn")
    Equal(T(guildRow.Name), "Lancers of Elwynn", "your guild's row: the made-up guild, at once")
    Equal(T(invitedRow.Name) .. "|" .. T(ticketRow.Name) .. "|" .. T(communityRow.Name), "Guild|Guild|Community",
        "another guild's invitation and ticket still Guild, a community still Community")
    Run(function() guildRow:Init(elementData[guildRow]) end)
    Equal(T(guildRow.Name), "Lancers of Elwynn", "and after the game draws the row again")
    Run(InspectGuildFrame_Update)
    Equal(T(InspectGuildFrame.guildName), "Guild", "the inspect tab is someone else's guild: still Guild")
    Equal(Who(whoMe), "Knights of Zriel 0 Lancers of Elwynn true", "your /who row: the game's text kept and hidden, the made-up guild over it")
    Equal(select(3, CoverOver(whoMe, whoMe.GuildName)), GUILD_GREY, "in the column's own colour")
    Equal(Who(whoBrannoc), "Knights of Zriel 1 nil nil", "someone else's /who row: their guild as it is, nothing over it")
    Equal(CoverOf(whoMe), "Mr Shadow", "your name's label on /who left as it was")
    do
        local writes = H.Writes()
        P:Module("Social"):Apply(true)
        Equal(H.Writes(), writes, "applying again writes nothing")
    end
    P:Set("myColour", "accent")
    Equal(T(guildRow.Name) .. " / " .. select(3, CoverOver(whoMe, whoMe.GuildName)), "Lancers of Elwynn / " .. GUILD_GREY,
        "the Name colour plays no part")
    P:Set("myColour", "game")
    P:Set("nameStyle", "hidden")
    Equal(T(guildRow.Name) .. " / " .. Who(whoMe), "Lancers of Elwynn / Knights of Zriel 0 Lancers of Elwynn true",
        "the Hidden style leaves a typed guild")
    P:Set("nameStyle", "player")
    P:Set("myGuild", "Iron Wolves Kin")
    Equal(T(guildRow.Name) .. " / " .. Who(whoMe), "Iron Wolves Kin / Knights of Zriel 0 Iron Wolves Kin true", "a new one at once, everywhere")
    -- Your /who row reused for someone else, then you again.
    local myData = elementData[whoMe]
    local theirs = { index = 2, info = { fullName = "Tamsin Reed", filename = "MAGE", area = "Darnassus", fullGuildName = "Iron Vanguard" } }
    elementData[whoMe] = theirs
    Run(function() whoMe:InitButton(theirs, false) end)
    Equal(Who(whoMe), "Iron Vanguard 1 Iron Wolves Kin false", "the row reused for someone else: their guild shows, ours gone")
    elementData[whoMe] = myData
    Run(function() whoMe:InitButton(myData, false) end)
    Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin true", "back to you: the made-up guild again")
    -- Your guild's name unticked: the real name back in the list; on /who
    -- your guild hidden again (whoList is still ticked), the made-up one gone.
    P:Set("guildName", false)
    Equal(T(guildRow.Name) .. "|" .. T(invitedRow.Name) .. "|" .. T(ticketRow.Name), "Knights of Zriel|Iron Wolves|Iron Wolves",
        "guildName unticked: the list's real names back")
    Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin false", "your /who guild hidden as before, the made-up one gone")
    Run(function() whoMe:InitButton(myData, false) end)
    Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin false", "and when the game draws the row again")
    P:Set("guildName", true)
    Equal(T(guildRow.Name) .. " / " .. Who(whoMe), "Iron Wolves Kin / Knights of Zriel 0 Iron Wolves Kin true", "ticked again: back at once")
    P:Set("whoList", false)
    Equal(Who(whoMe), "Knights of Zriel 1 Iron Wolves Kin false", "/who unticked: your real guild shows, ours gone")
    Equal(T(guildRow.Name), "Iron Wolves Kin", "the guild list keeps its own tick")
    P:Set("whoList", true)
    Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin true", "/who ticked again: the made-up guild over it")
    -- Not in a guild: nothing to stand in for, as in your tooltip.
    do
        local guild = H.guild
        H.guild = nil
        Run(function() whoMe:InitButton(myData, false) end)
        Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin false", "not in a guild: no made-up guild on your /who row")
        H.guild = guild
        Run(function() whoMe:InitButton(myData, false) end)
        Equal(Who(whoMe), "Knights of Zriel 0 Iron Wolves Kin true", "in one again: back")
    end
    P:Set("myGuild", "")
    Equal(T(guildRow.Name) .. " / " .. Who(whoMe), "Guild / Knights of Zriel 0 Iron Wolves Kin false", "emptied: Guild, and hidden on /who, as before")
    P:Set("myGuild", "Lancers of Elwynn")
    Equal(H.Problems(), "", "nothing wrong with a made-up guild")
end
P:Set("nameStyle", "hidden")
P:Set("myName", "")
Equal(T(wowRow.name), "Level 60 Warrior", "Hidden style: just the level")
Equal(T(bnRow.name) .. "|" .. T(inviteRow.Name) .. "|" .. T(FriendsFrameBattlenetFrame.Tag), "||", "Battle.net names blank")
Equal(T(brannocRow.NameFrame.Name), "", "the roster blank")
P:Set("nameStyle", "class")
Equal(T(wowRow.name), Class("WARRIOR") .. ", Level 60 Warrior", "back to class names")
Equal(T(FriendsFrameBattlenetFrame.Tag), "Battle.net", "and your BattleTag, blank under Hidden, labelled again at once")
Equal(H.Problems(), "", "nothing wrong with the settings")

-- In a fight: nothing here is protected, so re-labelling carries on safely.
H.Combat(true)
P:Set("nameStyle", "player")
Run(function() brannocRow:SetMember(brannoc) end)
DrawFriends()
Equal(T(brannocRow.NameFrame.Name), "Player", "in combat: the roster still swaps")
P:Set("nameStyle", "class")
H.Combat(false)
Equal(H.Problems(), "", "in combat: nothing protected touched")

-- Off: everything back --------------------------------------------------------------------------------------

P:Set("myTag", "Fake#9999")
Equal(T(FriendsFrameBattlenetFrame.Tag), "Fake|cff416380#9999|r", "a made-up BattleTag showing as private mode goes off")
P:SetPrivate(false)
Equal(T(wowRow.name) .. "|" .. T(wowRow.info), "Brannoc Stonehelm, Level 60 Warrior|Ironforge", "off: friends back")
Equal(T(bnRow.name), "|Kq1|k (Odessa Vale)", "Battle.net friends back")
Equal(T(inviteRow.Name), "|Kq9|k", "requests back")
Equal(T(FriendsFrameBattlenetFrame.Tag), REAL_TAG, "your BattleTag back")
Equal(S[FriendsFrameBattlenetFrame.BroadcastFrame.EditBox].password, false, "the broadcast box readable")
Equal(T(FriendsTooltipHeader), "Brannoc Stonehelm", "the hover box's last header back")
Equal(T(BNToastFrame.TopLine), "|Kq1|k", "the pop-up back")
Equal(T(myRow.NameFrame.Name) .. "|" .. T(myRow.Note), "Zriel Gustbellow|Alt of the GM", "the roster back")
Equal(T(quietRow.Note) .. "|" .. Alphas(quietRow.Note, myRow.Note), "|11", "a reused row's empty note stays empty: no one else's")
Equal(Alphas(FriendsTooltipNoteText, FriendsTooltipGameAccount1Info, BNToastFrame.MiddleLine), "111", "hover box and pop-up lines show")
Equal(T(secretRow.NameFrame.Name), "Player", "a secret's original was never kept: left for the game's next update")
Equal(H.Alpha(myRow.Zone) .. H.Alpha(G.motd) .. H.Alpha(G.infoText) .. H.Alpha(G.log), "1111", "everything hidden shows")
Equal(T(lootRow.text) .. "|" .. T(motdRow.text), "Brannoc Stonehelm obtained [Thunderfury].|Message of the Day: Welcome Zriel!",
    "the news back")
Equal(T(guildRow.Name) .. "|" .. T(InspectGuildFrame.guildName), "Knights of Zriel|Knights of Zriel", "the guild's name back")
Equal(T(invitedRow.Name) .. "|" .. T(ticketRow.Name), "Iron Wolves|Iron Wolves", "and the invitation's and ticket's")
Equal(T(whoBrannoc.Name) .. " " .. H.Alpha(whoBrannoc.Name), "Brannoc Stonehelm 1", "/who back")
Equal(select(2, CoverOf(whoBrannoc)), false, "its label gone")
Equal(H.Alpha(whoMe.GuildName), 1, "your guild on /who")
Equal(select(2, CoverOver(whoMe, whoMe.GuildName)), false, "the made-up guild over it gone")
Equal(T(MailItem1Sender) .. "|" .. T(MailItem1Subject), "Brannoc Stonehelm|Thanks Zriel", "the inbox back")
Equal(T(OpenMailInvoicePurchaser), "Purchased by: Grubb Fizzwick", "the invoice back")
True(not S[SendMailNameEditBox].password, "the To box readable")
Equal(T(AutoCompleteButton2), "|cff00ff00Tamsin Reed|r", "the suggestions back")
Equal(T(listing.Name) .. "|" .. T(comment), "Brannoc Stonehelm|Need healer, ask Brannoc Stonehelm", "the group finder back")
Equal(T(invite.Name) .. "|" .. T(CalendarViewEventCreatorName), "Brannoc Stonehelm|Created by Tamsin Reed", "the calendar back")

H.ResetWrites()
DrawFriends()
HoverFriend(bnRow)
Run(function() InboxFrame:Update() end)
Run(function() myRow:SetMember(me) end)
Run(function() BNToastFrame:ShowToast(1, 1) end)
Run(G.lateName)
WhoRow({ index = 3, info = { fullName = "Tamsin Reed", filename = "MAGE", area = "Darnassus" } })
Run(PetitionFrame_Update, PetitionFrame)
Run(AutoComplete_UpdateResults, AutoCompleteBox, { { name = "Brannoc Stonehelm" } })
Run(CalendarViewEventFrame_Update)
Equal(H.Writes(), 0, "off again: every hook does nothing")
Equal(T(bnRow.name) .. "|" .. T(FriendsTooltipHeader), "|Kq1|k (Odessa Vale)||Kq1|k", "the game's own text")
P:Set("myTag", "Other#42")
Run(FriendsFrame_CheckBattlenetStatus)
Equal(H.Writes() .. " " .. T(FriendsFrameBattlenetFrame.Tag), "0 " .. REAL_TAG, "off: a made-up BattleTag typed now touches nothing")
P:Set("myTag", "Fake#9999")
P:Set("myGuild", "Iron Wolves Kin")
Run(function() guildRow:Init(elementData[guildRow]) end)
Run(function() whoMe:InitButton(elementData[whoMe], false) end)
Equal(H.Writes() .. " " .. T(guildRow.Name) .. " " .. H.Alpha(whoMe.GuildName) .. " " .. tostring(select(2, CoverOver(whoMe, whoMe.GuildName))),
    "0 Knights of Zriel 1 false", "off: a made-up guild typed now touches nothing")
P:Set("myGuild", "Lancers of Elwynn")

-- An open letter put back as it shows.
Run(function()
    InboxFrame.openMailID = 1
    OpenMailFrame:Update()
end)
P:SetPrivate(true)
Equal(H.Alpha(OpenMailSender.Name), 0, "on with a letter open: its sender covered")
P:SetPrivate(false)
Equal(H.Alpha(OpenMailSender.Name), 1, "off: shown again")
Equal(T(OpenMailBodyText), "Hi Zriel, here's the ore from Brannoc.\nBrannoc", "and the letter as written")
Equal(select(2, CoverOf(OpenMailSender)), false, "no label left")

Equal(H.Problems(), "", "no violations, hook errors or prints")

-- A game with none of these windows: nothing breaks ------------------------------------------------------

for key in pairs(_G) do
    if not BASELINE[key] then _G[key] = nil end
end
H.Environment()
P = H.Load(nil)
P:SetPrivate(true)
P:Set("nameStyle", "player")
P:SetPrivate(false)
Equal(H.Writes(), 0, "no windows: nothing touched")
Equal(H.Problems(), "", "and nothing wrong")

io.stdout:write("TestSocial: " .. H.checks .. " checks passed\n")
