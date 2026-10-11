-- The Social module against Forever's newer social window (Blizzard_SocialUI,
-- used when C_SocialUI.IsSystemEnabled()), stood in for as Blizzard builds
-- it: your BattleTag in the header and its copy button, the broadcast box,
-- friend cards (a WoW friend, another game, offline, no character), friend
-- request cards, the ignore list, recent allies, Quick Join and
-- Recruit-A-Friend (rows of both windows, rows older than the addon's hooks
-- too) and the Battle.net pop-up as the mainline code shows it. Off does
-- nothing; on hides or swaps; the copy button can't be clicked; Name colour
-- follows on the BattleTag; recycled cards follow whoever they show now;
-- each tick puts back only its own; off puts it all back; secrets are never
-- read; and a window that loads later is covered as it loads.
-- Run with fengari: Tools/TestSocialUI.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local T = H.Text
local P, G
-- The globals there before any game is built, so a later game can start
-- without this one's window.
local BASELINE = {}
for key in pairs(_G) do BASELINE[key] = true end
local function Wipe()
    for key in pairs(_G) do
        if not BASELINE[key] then _G[key] = nil end
    end
end

-- The game's colour codes (as WrapTextInColorCode writes them).
local NORMAL, HIGHLIGHT, BNET, GRAY, DARKGRAY = "|cffffd100", "|cffffffff", "|cff82c5ff", "|cff808080", "|cff4d4d4d"
local TAG, TAG_SUFFIX, GUILDIE, DISABLED = "|cff82c5ff", "|cff6f7d8a", "|cff40ff40", "|cff7f7f7f"
local function Wrap(code, text) return code .. text .. "|r" end

-- Building Blizzard's side ------------------------------------------------------------------------

local function Frame(name, parent, fields) return H.BlizzardFrame("Frame", name, parent, fields) end
local function Button(name, parent, fields) return H.BlizzardFrame("Button", name, parent, fields) end

local function Text(parent, key, text)
    local fs = H.BlizzardText(nil, parent, text or "")
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

local function Run(fn, ...) return H.Blizzard(fn, ...) end

local function Constants()
    BNET_CLIENT_WOW, UNKNOWN, RAF_PENDING_RECRUIT = "WoW", "Unknown", "Pending Recruit"
    Enum.SocialUIBlockType = { None = 0, Ignore = 1, BattleNetInviteBlock = 2 }
    Enum.BattleNetFriendLevel = { BattleTag = 1, RealID = 2, Title = 3 }
    local CLASS_IDS = { [1] = "WARRIOR", [5] = "PRIEST", [8] = "MAGE", [11] = "DRUID" }
    C_CreatureInfo = { GetClassInfo = function(id)
        local file = CLASS_IDS[id]
        return file and { classFile = file, className = H.CLASS_NAMES[file] }
    end }
end

-- Battle.net friends, as C_BattleNet gives them: a WoW friend online,
-- another game (no character name: the game shows the BattleTag), an
-- offline WoW friend, and one with no character at all.
local function Accounts()
    G.bn = {
        { bnetAccountID = 11, accountName = "|Kq1|k", battleTag = "Pal#1234", friendLevel = 1,
            gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Odessa Vale", className = "Priest",
                classFilename = "PRIEST", characterLevel = 60, areaName = "Stormwind", playerGuid = "Player-1-0011" } },
        { bnetAccountID = 12, accountName = "|Kq2|k", battleTag = "Gamer#5678", friendLevel = 1,
            gameAccountInfo = { isOnline = true, clientProgram = "Pro", characterName = "", richPresence = "In a match" } },
        { bnetAccountID = 13, accountName = "|Kq3|k", battleTag = "Tam#4321", friendLevel = 3,
            gameAccountInfo = { isOnline = false, clientProgram = "WoW", characterName = "Tamsin Reed", className = "Mage",
                classFilename = "MAGE", characterLevel = 42 } },
        { bnetAccountID = 14, accountName = "|Kq4|k", battleTag = "Quiet#1111", friendLevel = 1,
            gameAccountInfo = { isOnline = false, clientProgram = "" } },
        -- One whose character and whether they're online can't be read.
        { bnetAccountID = 15, accountName = "|Kq5|k", battleTag = "Hush#2222", friendLevel = 1,
            gameAccountInfo = { isOnline = H.SECRET, clientProgram = "WoW", characterName = H.SECRET, areaName = "Ironforge" } },
    }
    G.invites = { { inviteID = 7, accountName = "|Kq9|k", friendLevel = 1 }, { inviteID = 8, accountName = "Grubb Fizzwick", friendLevel = 3 } }
    BNGetNumFriends = function() return #G.bn, 2, 0, 0 end
    C_BattleNet = {
        GetFriendAccountInfo = function(i) return G.bn[i] end,
        GetFriendInviteInfo = function(i) return G.invites[i] end,
        GetAccountInfoByGUID = function(guid)
            for _, account in ipairs(G.bn) do
                if account.gameAccountInfo.playerGuid == guid then return account end
            end
        end,
    }
    G.ignored, G.blocked = { "Grubb Fizzwick", "Brannoc Stonehelm" }, { "|Kq7|k" }
    C_FriendList.GetIgnoreName = function(i) return G.ignored[i] end
    -- People Quick Join names by GUID.
    H.units.guildie = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
        guid = "Player-1-0002" }
    H.guild = { { name = "Brannoc Stonehelm", classFile = "WARRIOR" } }
end

-- The window's mixins (Blizzard_FriendsFrame, Blizzard_SocialUI,
-- Blizzard_RecentAllies, Blizzard_QuickJoin, Blizzard_RecruitAFriend), as
-- Forever's code writes each card's text: one step at a time, then the
-- layout, which measures what's there.
local function FriendCardMixin()
    FriendsListSocialCardMixin = {
        Initialize = function(self, node)
            self.elementData = node
            self:InitializeCardDisplayText()
        end,
        InitializeCardDisplayText = function(self)
            self:RefreshFriendNameDisplayText()
            self:RefreshFriendCharacterDataDisplayText()
            self:RefreshLocationDisplayText()
            self:LayoutScaledContent()
        end,
        RefreshFriendNameDisplayText = function(self)
            local account = self.elementData.accountInfo
            local game = account.gameAccountInfo
            local colour = game.isOnline and (account.friendLevel == 3 and HIGHLIGHT or BNET) or GRAY
            self.FriendName:SetText(Wrap(colour, account.accountName))
        end,
        RefreshFriendCharacterDataDisplayText = function(self)
            local account = self.elementData.accountInfo
            local game = account.gameAccountInfo
            local name = ""
            if issecretvalue(game.characterName) then
                name = game.characterName -- a secret goes straight in
            elseif game.characterName then
                name = game.characterName ~= "" and game.characterName or account.battleTag:match("^(.-)#")
                name = Wrap(game.isOnline and NORMAL or DARKGRAY, name)
            end
            self.Name:SetText(name)
            self.Level:SetText(game.characterLevel and Wrap(HIGHLIGHT, "Lvl " .. game.characterLevel) or "")
            self.Class:SetText(game.className and Wrap(HIGHLIGHT, game.className) or "")
        end,
        RefreshLocationDisplayText = function(self)
            local game = self.elementData.accountInfo.gameAccountInfo
            if game.isOnline then
                self.Location:SetText(Wrap(GRAY, game.areaName or game.richPresence))
            else
                self.Location:SetText(Wrap(DARKGRAY, "Last online 3 days ago"))
            end
        end,
        LayoutScaledContent = function(self)
            self.FriendName:SetWidth(self.FriendName:GetStringWidth())
            self.Name:SetWidth(self.Name:GetStringWidth())
        end,
    }
    FriendRequestsListSocialCardMixin = {
        Initialize = function(self, node)
            local info = C_BattleNet.GetFriendInviteInfo(node.inviteIndex)
            self.elementData = { inviteIndex = node.inviteIndex, accountName = info.accountName, friendLevel = info.friendLevel }
            self:InitializeRequestTimestampText()
            self:InitializeRequesterNameText()
            self:InitializeFriendTypeText()
        end,
        InitializeRequestTimestampText = function(self) self.RequestTimestamp:SetText(Wrap(HIGHLIGHT, "Sent 2 days ago")) end,
        InitializeRequesterNameText = function(self)
            local data = self.elementData
            self.Name:SetText(Wrap(data.friendLevel == 3 and NORMAL or BNET, data.accountName))
        end,
        InitializeFriendTypeText = function(self) self.FriendType:SetText(Wrap(GRAY, "Battle.net friend")) end,
    }
end

local function ListMixins()
    SocialUIIgnoreListEntryMixin = {
        Initialize = function(self, data)
            self.elementData = data
            self:RefreshName()
        end,
        RefreshName = function(self)
            local data = self.elementData
            local name = data.blockType == 1 and C_FriendList.GetIgnoreName(data.blockIndex) or G.blocked[data.blockIndex]
            self.Name:SetText(name)
        end,
    }
    RecentAlliesSocialCardMixin = {
        Initialize = function(self, node)
            self.elementData = node
            self:RefreshCharacterDataDisplayText()
            self:RefreshLocationDisplayText()
        end,
        RefreshCharacterDataDisplayText = function(self)
            local character, state = self.elementData.characterData, self.elementData.stateData
            if issecretvalue(character) then
                self.Name:SetText(character)
                return
            end
            self.Name:SetText(Wrap(state.isOnline and NORMAL or DARKGRAY, character.name))
            self.Level:SetText(Wrap(HIGHLIGHT, "Lvl " .. character.level))
        end,
        RefreshLocationDisplayText = function(self)
            local state = self.elementData.stateData
            self.Location:SetText(Wrap(GRAY, state.currentLocation or ""))
        end,
    }
end

-- Quick Join (QuickJoin.lua): each member's name is a link, in the colour of
-- how you know them (SocialQueueUtil_GetRelationshipInfo).
local function Relationship(guid)
    if issecretvalue(guid) then return guid end
    local account = C_BattleNet.GetAccountInfoByGUID(guid)
    if account then
        local name = account.accountName
        return name, BNET, ("|HBNplayer:%s:%d:0:0:0|h%s|h"):format(name, account.bnetAccountID, name)
    end
    local _, _, _, _, _, name = GetPlayerInfoByGUID(guid)
    if not name then return "Unknown", GUILDIE end
    return name, GUILDIE, ("|Hplayer:%s|h%s|h"):format(name, name)
end

-- A group's entry, made from QuickJoinEntryMixin as the game makes them
-- (CreateFromMixins: the mixin's functions copied in when it's made, so an
-- entry made before the addon's hooks has the old ApplyToFrame).
local function QueueEntry(guids)
    local entry = { displayedMembers = {} }
    for key, value in pairs(QuickJoinEntryMixin) do entry[key] = value end
    for i, guid in ipairs(guids) do entry.displayedMembers[i] = { guid = guid } end
    return entry
end

local function QueueMixin()
    QuickJoinEntryMixin = {
        ApplyToFrame = function(self, frame)
            for i, member in ipairs(self.displayedMembers) do
                local name, colour, link = Relationship(member.guid)
                local region = frame.Members[i]
                if issecretvalue(name) then
                    region:SetText(name)
                else
                    region:SetText((colour or DISABLED) .. (link or name) .. "|r")
                end
                region:Show()
            end
            for i = #self.displayedMembers + 1, #frame.Members do frame.Members[i]:Hide() end
        end,
    }
    QuickJoinButtonMixin = {
        Init = function(self, entry) self:SetEntry(entry) end,
        SetEntry = function(self, entry)
            entry:ApplyToFrame(self)
            self.entry = entry
        end,
    }
end

-- Recruit-A-Friend (RecruitAFriendFrame.lua, RecruitAFriendSocialView.lua):
-- the newer window's rows copy the older mixin when the file loads, then
-- write their own colours over what the older one wrote.
local function RecruitMixins()
    RecruitListButtonMixin = {
        Init = function(self, info) self:SetupRecruit(info) end,
        SetupRecruit = function(self, info)
            self.recruitInfo = info
            self.Name:SetText(info.nameText)
            self.InfoText:SetText(info.isOnline and "Active recruit" or "Last online 2 days ago")
        end,
    }
    RecruitListButtonSocialMixin = {}
    for key, value in pairs(RecruitListButtonMixin) do RecruitListButtonSocialMixin[key] = value end
    RecruitListButtonSocialMixin.SetupRecruit = function(self, info)
        RecruitListButtonMixin.SetupRecruit(self, info)
        self:UpdateCardTextColors(info)
    end
    RecruitListButtonSocialMixin.UpdateCardTextColors = function(self, info)
        self.Name:SetText(Wrap(info.isOnline and HIGHLIGHT or DARKGRAY, info.plainName))
        self.CharacterName:SetText(Wrap(info.isOnline and NORMAL or DARKGRAY, info.characterName or ""))
    end
    G.recruits = {
        { accountInfo = G.bn[1], plainName = "|Kq1|k", nameText = "|Kq1|k |cff40ff40(Odessa Vale)|r", characterName = "Odessa Vale",
            isOnline = true },
        { plainName = "Pending Recruit", nameText = "Pending Recruit", isOnline = false },
        { plainName = "Newbie", nameText = "Newbie", isOnline = false },
    }
end

-- The window itself (SocialUI.xml and SocialUITemplates.xml), made when
-- Blizzard_SocialUI loads: the header's BattleTag display, the side windows
-- and each tab's content frame with its scroll list.
local function SocialWindow()
    G.tag, G.connected, G.clipboard = "Squirt#1234", true, nil
    local frame = Frame("SocialUIFrame", UIParent)
    local controls = Child(Child(frame, "BattleNetBar"), "ControlsContainer")
    local display = Child(controls, "PersonalBattleTagDisplay", "Frame", nil, {
        ShowBestDisplayTextAndButton = function(self)
            if G.connected then
                self:ShowBattleTag()
            else
                self.DisplayText:SetText(Wrap(NORMAL, "Battle.net unavailable"))
            end
            self.BattleNetUnavailableNoticeButton:SetShown(not G.connected)
            self.CopyBattleTagToClipboardButton:SetShown(G.connected)
        end,
        ShowBattleTag = function(self)
            -- A BattleTag the game makes a secret goes straight in.
            if G.secretTag then return self.DisplayText:SetText(H.SECRET) end
            local prefix, suffix = G.tag:match("^(.-)#(.*)$")
            self.DisplayText:SetText(Wrap(TAG, prefix) .. Wrap(TAG_SUFFIX, "#") .. Wrap(TAG_SUFFIX, suffix))
        end,
    })
    Text(display, "DisplayText")
    local copy = Child(display, "CopyBattleTagToClipboardButton", "Button")
    local notice = Child(display, "BattleNetUnavailableNoticeButton", "Button")
    S[display].level, S[copy].level, S[notice].level = 5, 6, 6
    Run(function()
        copy:SetScript("OnClick", function() G.clipboard = G.tag end)
        notice:Hide()
    end)
    Child(Child(frame, "BattleNetBroadcastFrame"), "EditBox", "EditBox")
    G.ignoreRows = List(Child(frame, "IgnoreListFrame"), "ScrollBox")
    G.friendRows = List(Child(frame, "FriendsList"), "ScrollBox")
    G.requestRows = List(Child(frame, "FriendRequestsList"), "ScrollBox")
    G.allyRows = List(Child(frame, "RecentAlliesList"), "ScrollBox")
    G.queueRows = List(Child(frame, "QuickJoinFrame"), "ScrollBox")
    G.recruitRows = List(Child(frame, "RecruitAFriendFrame"), "ScrollBox")
end

-- The older friends window's Quick Join and Recruit-A-Friend tabs. The
-- recruit list's update (RecruitAFriendFrameMixin:UpdateRecruitList) gives
-- its rows back to the scroll list's pool, then each recruit takes one
-- (the oldest kept back first) and fills it.
local function OlderTabs()
    G.oldQueueRows = List(Frame("QuickJoinFrame", UIParent), "ScrollBox")
    G.oldRecruitPool = {}
    local frame = Frame("RecruitAFriendFrame", UIParent, { UpdateRecruitList = function(_, recruits)
        for i = #G.oldRecruitRows, 1, -1 do table.insert(G.oldRecruitPool, table.remove(G.oldRecruitRows, i)) end
        for _, recruit in ipairs(recruits) do
            local row = table.remove(G.oldRecruitPool, 1)
            if not row then break end
            table.insert(G.oldRecruitRows, row)
            row:Init(recruit)
        end
    end })
    G.oldRecruitRows = List(Child(frame, "RecruitList"), "ScrollBox")
end

-- The Battle.net pop-up as the mainline code shows it (Blizzard_BNet): it
-- takes the next toast from its queue and names its kind last.
local function Toast()
    G.toasts = {}
    Button("BNToastFrame", UIParent, { ShowToast = function(self)
        local toast = table.remove(G.toasts, 1)
        local kind, account = toast.kind, G.bn[toast.id or 1]
        if kind == 1 then
            self.TopLine:SetText(Wrap(BNET, account.accountName))
            self.BottomLine:SetText(Wrap(GRAY, "has come online."))
            G.lateName = function() self.MiddleLine:SetFormattedText(account.gameAccountInfo.characterName) end
        elseif kind == 3 then
            self.TopLine:SetText(account.accountName)
            self.BottomLine:SetText("Raid at eight")
        elseif kind == 5 then
            self.DoubleLine:SetText("You have received a new friend request.")
        end
        self.toastType = kind
    end })
    Text(BNToastFrame, "TopLine")
    Text(BNToastFrame, "MiddleLine")
    Text(BNToastFrame, "BottomLine")
    Text(BNToastFrame, "DoubleLine")
end

-- Rows, as the game makes them --------------------------------------------------------------------

local function FriendCard()
    local card = Mixin(Button(nil, SocialUIFrame.FriendsList.ScrollBox), FriendsListSocialCardMixin)
    for _, key in ipairs({ "FriendName", "Name", "Level", "Class", "Location" }) do Text(card, key) end
    table.insert(G.friendRows, card)
    return card
end

local function ShowFriend(card, index)
    Run(function() card:Initialize({ friendIndex = index, accountInfo = G.bn[index] }) end)
end

local function HeaderRow(rows, parent, text)
    local header = Button(nil, parent)
    Text(header, "ButtonText", text)
    table.insert(rows, header)
    return header
end

local function RequestCard(index)
    local card = Mixin(Button(nil, SocialUIFrame.FriendRequestsList.ScrollBox), FriendRequestsListSocialCardMixin)
    for _, key in ipairs({ "RequestTimestamp", "Name", "FriendType" }) do Text(card, key) end
    table.insert(G.requestRows, card)
    Run(function() card:Initialize({ inviteIndex = index }) end)
    return card
end

local function IgnoreEntry(data)
    local entry = Mixin(Button(nil, SocialUIFrame.IgnoreListFrame.ScrollBox), SocialUIIgnoreListEntryMixin)
    Text(entry, "Name")
    table.insert(G.ignoreRows, entry)
    Run(function() entry:Initialize(data) end)
    return entry
end

local function AllyCard(node)
    local card = Mixin(Button(nil, SocialUIFrame.RecentAlliesList.ScrollBox), RecentAlliesSocialCardMixin)
    for _, key in ipairs({ "Name", "Level", "Location" }) do Text(card, key) end
    table.insert(G.allyRows, card)
    Run(function() card:Initialize(node) end)
    return card
end

local function QueueRow(rows, parent)
    local row = Mixin(Button(nil, parent), QuickJoinButtonMixin)
    rawset(row, "Members", { Text(row, nil), Text(row, nil), Text(row, nil) })
    table.insert(rows, row)
    return row
end

local function ShowQueue(row, guids)
    Run(function() row:Init(QueueEntry(guids)) end)
end

local function RecruitRow(rows, parent, social)
    local row = Mixin(Button(nil, parent), social and RecruitListButtonSocialMixin or RecruitListButtonMixin)
    Text(row, "Name")
    Text(row, "InfoText")
    if social then Text(row, "CharacterName") end
    table.insert(rows, row)
    return row
end

local function ShowRecruit(row, index)
    Run(function() row:Init(G.recruits[index]) end)
end

-- What shows ----------------------------------------------------------------------------------------

local function Class(file)
    local c = H.CLASS_COLOURS[file]
    return P:Colourise(H.CLASS_NAMES[file], c.r, c.g, c.b)
end
local function Grey(word) return P:Colourise(word, .78, .78, .78) end
local function Alphas(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = tostring(H.Alpha((select(i, ...)))) end
    return table.concat(out)
end

local function Display() return SocialUIFrame.BattleNetBar.ControlsContainer.PersonalBattleTagDisplay end
local function RealTag() return Wrap(TAG, "Squirt") .. Wrap(TAG_SUFFIX, "#") .. Wrap(TAG_SUFFIX, "1234") end
local function RefreshHeader() Run(function() Display():ShowBestDisplayTextAndButton() end) end

-- Our strip over the BattleTag: its text, whether it shows, and whether it
-- takes the mouse.
local function Strip()
    for _, child in ipairs(S[Display()].children) do
        if not S[child].sealed then
            local text = S[child].children[1]
            return text and S[text].text, child:IsVisible(), S[child].mouse == true, child
        end
    end
end

-- A click on the copy button's spot, as the game would route it: a shown
-- frame of ours over it that takes the mouse gets it first; else the
-- button's own click copies your BattleTag.
local function ClickCopy()
    G.clipboard = nil
    local copy = Display().CopyBattleTagToClipboardButton
    if not copy:IsVisible() then return "nothing there" end
    for _, frame in ipairs(H.frames) do
        local point = S[frame].points[1]
        local over = point and point[1] == "ALL" and (point[2] == Display() or point[2] == copy)
        if over and frame:IsVisible() and S[frame].mouse and frame:GetFrameLevel() > copy:GetFrameLevel() then return "ours" end
    end
    G.clipboard = nil
    H.Script(copy, "OnClick")
    return G.clipboard and ("copied " .. G.clipboard) or "no copy"
end

local function Hooked()
    local count = {}
    for _, hook in ipairs(H.hooks) do count[hook.key] = (count[hook.key] or 0) + 1 end
    return count
end

-- A fresh game with the window, logged in -------------------------------------------------------------

H.Environment()
G = {}
Constants()
Accounts()
FriendCardMixin()
ListMixins()
QueueMixin()
RecruitMixins()
SocialWindow()
OlderTabs()
Toast()
-- Rows the game made as its addons loaded, before this addon did (after a
-- /reload, Quick Join and Recruit-A-Friend fill their lists at once).
local oldQueue = QueueRow(G.oldQueueRows, QuickJoinFrame.ScrollBox)
ShowQueue(oldQueue, { "Player-1-0002" })
local oldSocialRecruit = RecruitRow(G.recruitRows, SocialUIFrame.RecruitAFriendFrame.ScrollBox, true)
ShowRecruit(oldSocialRecruit, 1)
local oldRecruit = RecruitRow(G.oldRecruitRows, RecruitAFriendFrame.RecruitList.ScrollBox, false)
ShowRecruit(oldRecruit, 1)
for _, name in ipairs({ "Blizzard_FriendsFrame", "Blizzard_SocialUI", "Blizzard_SocialUIShared", "Blizzard_SocialToast",
    "Blizzard_BNet", "Blizzard_RecentAllies", "Blizzard_QuickJoin", "Blizzard_RecruitAFriend" }) do
    H.addOns[name] = true
end
P = H.Load(nil)

-- Off: nothing at all ---------------------------------------------------------------------------------

do
    local hooked = Hooked()
    Equal(hooked.RefreshFriendNameDisplayText, 1, "the friend card mixin is hooked at load, before cards copy it")
    Equal(hooked.InitializeRequesterNameText, 1, "and the request card's")
    Equal(hooked.RefreshName, 1, "and the ignore list's")
    Equal(hooked.RefreshCharacterDataDisplayText, 1, "and recent allies'")
    Equal(hooked.SetEntry, 1, "and Quick Join's")
    Equal(hooked.ApplyToFrame, 1, "and its group entries' (made afresh each time a list opens)")
    Equal((hooked.SetupRecruit or 0) .. (hooked.UpdateCardTextColors or 0), "11", "and Recruit-A-Friend's, both windows'")
    Equal(hooked.ShowBestDisplayTextAndButton, nil, "the header waits for private mode")
    Equal(hooked.UpdateRecruitList, nil, "and so does the older window's recruit list")
end

RefreshHeader()
local friendHeader = HeaderRow(G.friendRows, SocialUIFrame.FriendsList.ScrollBox, "Friends (2/4)")
local cards = {}
for i = 1, 4 do
    cards[i] = FriendCard()
    ShowFriend(cards[i], i)
end
local request, titleRequest = RequestCard(1), RequestCard(2)
local ignoreHeader = HeaderRow(G.ignoreRows, SocialUIFrame.IgnoreListFrame.ScrollBox, "Ignored")
local ignored = IgnoreEntry({ blockType = 1, blockIndex = 1 })
local ignoredGuildie = IgnoreEntry({ blockType = 1, blockIndex = 2 })
local blocked = IgnoreEntry({ blockType = 2, blockIndex = 1 })
local ally = AllyCard({ characterData = { name = "Tamsin Reed", fullName = "Tamsin Reed", classID = 8, level = 42 },
    stateData = { isOnline = true, currentLocation = "Darnassus" } })
local secretAlly = AllyCard({ characterData = H.SECRET, stateData = {} })
local queue = QueueRow(G.queueRows, SocialUIFrame.QuickJoinFrame.ScrollBox)
ShowQueue(queue, { "Player-1-0011", "Player-1-0002", "Player-1-0099" })
local secretQueue = QueueRow(G.queueRows, SocialUIFrame.QuickJoinFrame.ScrollBox)
ShowQueue(secretQueue, { H.SECRET })
local recruit, pending, newbie = RecruitRow(G.recruitRows, SocialUIFrame.RecruitAFriendFrame.ScrollBox, true),
    RecruitRow(G.recruitRows, SocialUIFrame.RecruitAFriendFrame.ScrollBox, true),
    RecruitRow(G.recruitRows, SocialUIFrame.RecruitAFriendFrame.ScrollBox, true)
ShowRecruit(recruit, 1)
ShowRecruit(pending, 2)
ShowRecruit(newbie, 3)
local broadcast = SocialUIFrame.BattleNetBroadcastFrame.EditBox

local display = Display()
local BN_LINK = "|HBNplayer:|Kq1|k:11:0:0:0|h"
Equal(T(display.DisplayText), RealTag(), "off: your BattleTag")
Equal(ClickCopy(), "copied Squirt#1234", "off: the copy button copies it")
Equal(T(cards[1].FriendName) .. "|" .. T(cards[1].Name), Wrap(BNET, "|Kq1|k") .. "|" .. Wrap(NORMAL, "Odessa Vale"), "off: a friend's card")
Equal(T(request.Name), Wrap(BNET, "|Kq9|k"), "off: a request")
Equal(T(queue.Members[1]), BNET .. BN_LINK .. "|Kq1|k|h|r", "off: Quick Join")
Equal(T(recruit.Name), Wrap(HIGHLIGHT, "|Kq1|k"), "off: a recruit")
Equal(H.Writes(), 0, "off: nothing of Blizzard's touched")
Equal(H.Problems(), "", "nothing wrong while off")

-- On: the header --------------------------------------------------------------------------------------

P:SetPrivate(true)
Equal(Hooked().ShowBestDisplayTextAndButton, 1, "on: the header's display is hooked, once")
Equal(Hooked().UpdateRecruitList, 1, "and the older window's recruit list update")

do
    local text, shown, mouse = Strip()
    Equal(text, Wrap(TAG, "Battle.net"), "on: your BattleTag reads Battle.net, in the BattleTag's colour")
    True(shown and mouse, "on a strip of our own that takes the mouse")
    Equal(T(display.DisplayText), RealTag(), "the game's text is never rewritten")
    Equal(H.Alpha(display.DisplayText) .. H.Alpha(display.CopyBattleTagToClipboardButton), "00", "but hidden, and the copy button too")
    Equal(ClickCopy(), "ours", "a click on the copy button lands on our strip")
    Equal(G.clipboard, nil, "so your BattleTag is never copied")
end
RefreshHeader()
Equal(Strip(), Wrap(TAG, "Battle.net"), "and after the game refreshes the header")
Equal(ClickCopy(), "ours", "still out of reach")
True(S[broadcast].password, "your broadcast box shows stars")

-- Battle.net down: the game's notice and its button are left alone.
G.connected = false
RefreshHeader()
do
    local _, shown = Strip()
    Equal(shown, false, "Battle.net unavailable: our strip goes")
    Equal(T(display.DisplayText) .. " " .. H.Alpha(display.DisplayText), Wrap(NORMAL, "Battle.net unavailable") .. " 1",
        "and the game's notice shows")
    True(display.BattleNetUnavailableNoticeButton:IsVisible(), "with its button free")
end
G.connected = true
RefreshHeader()
Equal(select(2, Strip()), true, "back online: covered again")

-- On: friend cards ----------------------------------------------------------------------------------

Equal(T(cards[1].FriendName), Wrap(BNET, "Friend (" .. Class("PRIEST") .. ")"), "a friend's card: Friend, with their class, in the card's blue")
Equal(T(cards[1].Name), Class("PRIEST"), "their character, by class, in class colour while online")
Equal(T(cards[1].Level) .. "|" .. T(cards[1].Class), Wrap(HIGHLIGHT, "Lvl 60") .. "|" .. Wrap(HIGHLIGHT, "Priest"), "level and class kept")
Equal(Alphas(cards[1].Location), "0", "where they are, hidden")
Equal(T(cards[2].FriendName), Wrap(BNET, "Friend"), "another game: Friend")
Equal(Alphas(cards[2].Name, cards[2].Location), "00", "its name (a BattleTag in its place) and what they're doing hidden")
Equal(T(cards[3].FriendName), Wrap(GRAY, "Friend (" .. Class("MAGE") .. ")"), "an offline friend: in the game's grey")
Equal(T(cards[3].Name), Wrap(DARKGRAY, "Mage"), "their character in the game's dark grey")
Equal(T(cards[3].Location) .. " " .. Alphas(cards[3].Location), Wrap(DARKGRAY, "Last online 3 days ago") .. " 1", "last online kept")
Equal(T(cards[4].FriendName) .. "|" .. T(cards[4].Name) .. "|" .. Alphas(cards[4].Name), Wrap(GRAY, "Friend") .. "||1",
    "no character: nothing to hide")
local hushed = FriendCard()
ShowFriend(hushed, 5)
Equal(T(hushed.FriendName) .. " " .. Alphas(hushed.Name, hushed.Location), Wrap(BNET, "Friend") .. " 00",
    "a character and online state that can't be read (secrets): never read, both hidden")
Equal(T(friendHeader.ButtonText), "Friends (2/4)", "the list's header left")

-- Cards drawn while private: the game measures our label, not the name.
ShowFriend(cards[1], 1)
Equal(S[cards[1].FriendName].width, #T(cards[1].FriendName) * 6, "a card drawn while private is laid out for the label")
Equal(T(cards[1].Name), Class("PRIEST"), "after the game redraws it")

-- Recycled cards follow whoever they show now.
ShowFriend(cards[1], 2)
Equal(T(cards[1].FriendName) .. " " .. Alphas(cards[1].Name), Wrap(BNET, "Friend") .. " 0", "a card reused for another game's friend")
ShowFriend(cards[1], 3)
Equal(T(cards[1].Name) .. " " .. Alphas(cards[1].Name, cards[1].Location), Wrap(DARKGRAY, "Mage") .. " 11",
    "then for an offline friend: their name back in view as a label, last online shown")
ShowFriend(cards[1], 1)
Equal(T(cards[1].Name) .. " " .. Alphas(cards[1].Location), Class("PRIEST") .. " 0", "and back")

Equal(T(request.Name), Wrap(BNET, "Friend request"), "a request: Friend request, in the game's colour")
Equal(T(titleRequest.Name), Wrap(NORMAL, "Friend request"), "a WoW friend's request too")
Equal(T(request.RequestTimestamp) .. "|" .. T(request.FriendType), Wrap(HIGHLIGHT, "Sent 2 days ago") .. "|" .. Wrap(GRAY, "Battle.net friend"),
    "when and what kind kept")

-- On: the ignore list and recent allies (whoList) ---------------------------------------------------------

Equal(T(ignored.Name), Grey("Player"), "ignore list: someone unknown")
Equal(T(ignoredGuildie.Name), Class("WARRIOR"), "a guildmate, by class")
Equal(T(blocked.Name), Grey("Player"), "a Battle.net block")
Equal(T(ignoreHeader.ButtonText), "Ignored", "the header left")
Equal(T(ally.Name), Class("MAGE"), "recent allies: by class")
Equal(T(ally.Location) .. " " .. Alphas(ally.Location), Wrap(GRAY, "Darnassus") .. " 1", "others' zones kept, as the older list")
Equal(T(secretAlly.Name), H.SECRET, "a secret ally (in a dungeon): never read, left for the game")

-- On: Quick Join and Recruit-A-Friend (friends) ------------------------------------------------------------

Equal(T(queue.Members[1]), BNET .. BN_LINK .. "Friend (" .. Class("PRIEST") .. ")|h|r", "Quick Join: a Battle.net friend, link kept")
Equal(T(queue.Members[2]), GUILDIE .. "|Hplayer:Brannoc Stonehelm|h" .. Class("WARRIOR") .. "|h|r", "a guildmate, by class, link kept")
Equal(T(queue.Members[3]), GUILDIE .. "Unknown|r", "a name the game doesn't know: left")
Equal(T(secretQueue.Members[1]), H.SECRET, "a secret member: never read")
ShowQueue(queue, { H.PLAYER.guid })
Equal(T(queue.Members[1]), GUILDIE .. "|Hplayer:Zriel Gustbellow|h" .. Class("DRUID") .. "|h|r", "a row reused for your group: you")
Equal(H.Shown(queue.Members[2]), false, "its other names hidden by the game")
ShowQueue(queue, { "Player-1-0011", "Player-1-0002", "Player-1-0099" })
Equal(T(oldQueue.Members[1]), GUILDIE .. "|Hplayer:Brannoc Stonehelm|h" .. Class("WARRIOR") .. "|h|r",
    "an older row (made before the addon's hooks): swapped at once")
ShowQueue(oldQueue, { "Player-1-0011" })
Equal(T(oldQueue.Members[1]), BNET .. BN_LINK .. "Friend (" .. Class("PRIEST") .. ")|h|r", "and hooked, so it follows its next group")

Equal(T(recruit.Name), Wrap(HIGHLIGHT, "Friend (" .. Class("PRIEST") .. ")"), "Recruit-A-Friend: the recruit")
Equal(T(recruit.CharacterName), Class("PRIEST"), "their character")
Equal(T(recruit.InfoText), "Active recruit", "their status kept")
Equal(T(pending.Name), Wrap(DARKGRAY, "Pending Recruit"), "a pending recruit names nobody: left")
Equal(T(newbie.Name), Wrap(DARKGRAY, "Friend"), "a recruit known by a BattleTag: Friend")
Equal(T(oldSocialRecruit.Name) .. "|" .. T(oldSocialRecruit.CharacterName), Wrap(HIGHLIGHT, "Friend (" .. Class("PRIEST") .. ")") .. "|"
    .. Class("PRIEST"), "an older row: swapped at once")
ShowRecruit(oldSocialRecruit, 3)
Equal(T(oldSocialRecruit.Name), Wrap(DARKGRAY, "Friend"), "and hooked")
Equal(T(oldRecruit.Name), "Friend (" .. Class("PRIEST") .. ")", "the older window's list: the recruit")
ShowRecruit(oldRecruit, 3)
Equal(T(oldRecruit.Name), "Friend", "and hooked, though made before the addon")
local laterRecruit = RecruitRow(G.oldRecruitRows, RecruitAFriendFrame.RecruitList.ScrollBox, false)
ShowRecruit(laterRecruit, 1)
Equal(T(laterRecruit.Name), "Friend (" .. Class("PRIEST") .. ")", "a row made later copies the hooked mixin")

-- On: the Battle.net pop-up (bnToasts) ----------------------------------------------------------------------

G.toasts = { { kind = 1, id = 1 } }
Run(function() BNToastFrame:ShowToast() end)
Equal(T(BNToastFrame.TopLine) .. "|" .. T(BNToastFrame.BottomLine), "A friend|" .. Wrap(GRAY, "has come online."), "pop-up: A friend")
Run(G.lateName)
Equal(Alphas(BNToastFrame.MiddleLine), "0", "the character's name that comes later stays hidden")
G.toasts = { { kind = 3, id = 1 } }
Run(function() BNToastFrame:ShowToast() end)
Equal(T(BNToastFrame.TopLine) .. "|" .. T(BNToastFrame.BottomLine), "A friend|New broadcast", "a broadcast")
G.toasts = { { kind = 5 } }
Run(function() BNToastFrame:ShowToast() end)
Equal(T(BNToastFrame.DoubleLine), "You have received a new friend request.", "a request names nobody: left")

do
    local writes = H.Writes()
    P:Module("Social"):Apply(true)
    Equal(H.Writes(), writes, "applying again changes nothing")
end
Equal(H.Problems(), "", "nothing wrong while on")

-- Name settings ------------------------------------------------------------------------------------------

P:Set("nameStyle", "player")
Equal(T(cards[1].FriendName) .. "|" .. T(cards[1].Name), Wrap(BNET, "Friend") .. "|" .. Grey("Player"), "Player style: a card")
Equal(T(queue.Members[2]), GUILDIE .. "|Hplayer:Brannoc Stonehelm|h" .. Grey("Player") .. "|h|r", "Quick Join")
Equal(T(ally.Name) .. "|" .. T(ignoredGuildie.Name), Grey("Player") .. "|" .. Grey("Player"), "recent allies and the ignore list")
Equal(Strip(), Wrap(TAG, "Battle.net"), "the header unchanged")
-- Your typed name on the BattleTag, in each Name colour (the game's own:
-- the BattleTag's colour).
P:Set("myName", "Mr Shadow")
for _, case in ipairs({ { "game" }, { "accent", P.ACCENT }, { "class", { 1, .49, .04 } }, { "white", { 1, 1, 1 } } }) do
    P:Set("myColour", case[1])
    local rgb = case[2]
    local mine = rgb and P:Colourise("Mr Shadow", rgb[1], rgb[2], rgb[3]) or Wrap(TAG, "Mr Shadow")
    Equal(Strip(), mine, case[1] .. ": your typed name on the BattleTag")
    Equal(T(display.DisplayText) .. " " .. ClickCopy(), RealTag() .. " ours", case[1] .. ": the game's text and copy button untouched")
end
P:Set("myColour", "game")
-- A made-up BattleTag ("Your BattleTag becomes"): on the strip instead of
-- your name, drawn as the game draws the real one in the game's own colour,
-- else all in your Name colour. The game's text and the copy button stay as
-- they were, out of reach: nothing is ever copied.
local FAKE = Wrap(TAG, "Fake") .. Wrap(TAG_SUFFIX, "#9999")
P:Set("myTag", "Fake#9999")
Equal(Strip(), FAKE, "a made-up BattleTag at once, looking like the real one")
Equal(T(display.DisplayText) .. " " .. Alphas(display.DisplayText, display.CopyBattleTagToClipboardButton), RealTag() .. " 00",
    "the game's text never rewritten, still hidden, the copy button too")
Equal(ClickCopy(), "ours", "a click on the copy button lands on our strip")
Equal(G.clipboard, nil, "so nothing is copied")
RefreshHeader()
Equal(Strip(), FAKE, "and after the game refreshes the header")
Equal(T(cards[1].FriendName), Wrap(BNET, "Friend"), "friends' cards as before")
for _, case in ipairs({ { "accent", P.ACCENT }, { "class", { 1, .49, .04 } }, { "white", { 1, 1, 1 } } }) do
    P:Set("myColour", case[1])
    local rgb = case[2]
    Equal(Strip(), P:Colourise("Fake#9999", rgb[1], rgb[2], rgb[3]), case[1] .. ": all of it in that colour")
    Equal(ClickCopy(), "ours", case[1] .. ": still out of reach")
end
P:Set("myColour", "game")
Equal(Strip(), FAKE, "the game's own again: the real one's look")
P:Set("myTag", "Streamer")
Equal(Strip(), Wrap(TAG, "Streamer"), "one with no number: in the BattleTag's colour")
P:Set("nameStyle", "hidden")
Equal(Strip(), Wrap(TAG, "Streamer"), "the Hidden style leaves a typed BattleTag")
P:Set("nameStyle", "player")
P:Set("myTag", "Fake#9999")
P:Set("friends", false)
do
    local _, shown = Strip()
    Equal(tostring(shown) .. " " .. T(display.DisplayText) .. " " .. ClickCopy(), "false " .. RealTag() .. " copied Squirt#1234",
        "friends unticked: your real BattleTag and its copy button back")
end
P:Set("friends", true)
Equal(Strip(), FAKE, "ticked again: the made-up one at once")
Equal(ClickCopy(), "ours", "and the copy button out of reach again")
-- The game's text can't be read (a secret) with your BattleTag up: still
-- covered, by the made-up one (plain: no look to borrow), never copied.
G.secretTag = true
RefreshHeader()
do
    local text, shown = Strip()
    Equal(tostring(text) .. " " .. tostring(shown) .. " " .. Alphas(display.DisplayText, display.CopyBattleTagToClipboardButton),
        "Fake#9999 true 00", "the real one a secret: still covered, by the made-up one")
end
Equal(ClickCopy(), "ours", "and out of reach")
P:Set("myTag", "")
Equal(Strip(), "Mr Shadow", "with none typed: your name, still covering it")
P:Set("myTag", "Fake#9999")
G.secretTag = nil
RefreshHeader()
Equal(Strip(), FAKE, "readable again: the real one's look back")
P:Set("myTag", "")
Equal(Strip(), Wrap(TAG, "Mr Shadow"), "emptied: your typed name, as before")
Equal(H.Problems(), "", "nothing wrong with a made-up BattleTag")
P:Set("nameStyle", "hidden")
P:Set("myName", "")
Equal(Strip(), "", "Hidden style: the BattleTag blank")
Equal(ClickCopy(), "ours", "and still can't be copied")
Equal(T(cards[1].FriendName) .. "|" .. T(cards[1].Name) .. "|" .. T(request.Name) .. "|" .. T(recruit.Name), "|||",
    "cards and requests blank")
P:Set("nameStyle", "class")
Equal(T(cards[1].FriendName), Wrap(BNET, "Friend (" .. Class("PRIEST") .. ")"), "back to class names")
Equal(Strip(), Wrap(TAG, "Battle.net"), "and Battle.net")
Equal(H.Problems(), "", "nothing wrong with the settings")

-- Ticks: each puts back only its own ------------------------------------------------------------------------

P:Set("friends", false)
do
    local _, shown = Strip()
    Equal(shown, false, "friends unticked: our strip goes")
    Equal(H.Alpha(display.DisplayText) .. H.Alpha(display.CopyBattleTagToClipboardButton), "11", "your BattleTag and its button show")
    Equal(T(display.DisplayText), RealTag(), "just as the game laid it out")
    Equal(ClickCopy(), "copied Squirt#1234", "and copying works again")
end
Equal(S[broadcast].password, false, "the broadcast box readable")
Equal(T(cards[1].FriendName) .. "|" .. T(cards[1].Name), Wrap(BNET, "|Kq1|k") .. "|" .. Wrap(NORMAL, "Odessa Vale"), "cards back")
Equal(Alphas(cards[1].Location, cards[2].Name, cards[2].Location), "111", "zones and other games' names show")
Equal(T(request.Name), Wrap(BNET, "|Kq9|k"), "requests back")
Equal(T(queue.Members[2]), GUILDIE .. "|Hplayer:Brannoc Stonehelm|hBrannoc Stonehelm|h|r", "Quick Join back")
Equal(T(recruit.Name) .. "|" .. T(recruit.CharacterName), Wrap(HIGHLIGHT, "|Kq1|k") .. "|" .. Wrap(NORMAL, "Odessa Vale"), "recruits back")
Equal(T(ally.Name) .. "|" .. T(ignoredGuildie.Name), Class("MAGE") .. "|" .. Class("WARRIOR"), "whoList's untouched")
H.ResetWrites()
RefreshHeader()
ShowFriend(cards[1], 1)
RequestCard(1)
ShowQueue(queue, { "Player-1-0011" })
ShowRecruit(recruit, 1)
Equal(H.Writes(), 0, "while unticked, the game's own text is left as it draws it")
P:Set("friends", true)
Equal(select(2, Strip()), true, "ticked again: covered at once")
Equal(T(cards[1].FriendName), Wrap(BNET, "Friend (" .. Class("PRIEST") .. ")"), "and the cards")

P:Set("whoList", false)
Equal(T(ally.Name) .. "|" .. T(ignored.Name) .. "|" .. T(blocked.Name), Wrap(NORMAL, "Tamsin Reed") .. "|Grubb Fizzwick||Kq7|k",
    "whoList unticked: recent allies and the ignore list back")
Equal(select(2, Strip()), true, "the header untouched")
P:Set("whoList", true)
Equal(T(ally.Name), Class("MAGE"), "ticked again")

P:Set("bnToasts", false)
G.toasts = { { kind = 1, id = 1 } }
Run(function() BNToastFrame:ShowToast() end)
Equal(T(BNToastFrame.TopLine), Wrap(BNET, "|Kq1|k"), "pop-ups unticked: the next one shows the friend")
P:Set("bnToasts", true)

-- Off: everything back --------------------------------------------------------------------------------------

P:Set("myTag", "Fake#9999")
Equal(Strip(), FAKE, "a made-up BattleTag showing as private mode goes off")
P:SetPrivate(false)
Equal(select(2, Strip()), false, "off: our strip gone")
Equal(T(display.DisplayText) .. " " .. Alphas(display.DisplayText, display.CopyBattleTagToClipboardButton), RealTag() .. " 11",
    "your BattleTag and its button back")
Equal(ClickCopy(), "copied Squirt#1234", "copying works")
Equal(S[broadcast].password, false, "the broadcast box readable")
Equal(T(cards[1].FriendName) .. "|" .. T(cards[3].Name), Wrap(BNET, "|Kq1|k") .. "|" .. Wrap(DARKGRAY, "Tamsin Reed"), "cards back")
Equal(Alphas(cards[1].Location, cards[2].Name, cards[2].Location), "111", "everything hidden shows")
Equal(T(titleRequest.Name), Wrap(NORMAL, "Grubb Fizzwick"), "requests back")
Equal(T(ignored.Name) .. "|" .. T(ally.Name), "Grubb Fizzwick|" .. Wrap(NORMAL, "Tamsin Reed"), "ignore list and recent allies back")
Equal(T(oldQueue.Members[1]), BNET .. BN_LINK .. "|Kq1|k|h|r", "Quick Join back")
Equal(T(oldRecruit.Name) .. "|" .. T(newbie.Name), "Newbie|" .. Wrap(DARKGRAY, "Newbie"), "recruits back")
Equal(T(secretAlly.Name), H.SECRET, "a secret was never kept or touched")

H.ResetWrites()
RefreshHeader()
for i = 1, 4 do ShowFriend(cards[i], i) end
RequestCard(2)
IgnoreEntry({ blockType = 1, blockIndex = 2 })
AllyCard({ characterData = { name = "Tamsin Reed", fullName = "Tamsin Reed", classID = 8, level = 42 }, stateData = { isOnline = true } })
ShowQueue(queue, { "Player-1-0011", "Player-1-0002" })
ShowQueue(oldQueue, { "Player-1-0002" })
ShowRecruit(oldRecruit, 1)
ShowRecruit(oldSocialRecruit, 1)
G.toasts = { { kind = 1, id = 1 } }
Run(function() BNToastFrame:ShowToast() end)
Run(G.lateName)
Equal(H.Writes(), 0, "off again: every hook does nothing")
P:Set("myTag", "Other#42")
RefreshHeader()
Equal(H.Writes() .. " " .. tostring(select(2, Strip())) .. " " .. ClickCopy(), "0 false copied Squirt#1234",
    "off: a made-up BattleTag typed now touches nothing")
Equal(H.Problems(), "", "no violations, hook errors or prints")

-- Rows kept back from before the addon's hooks ------------------------------------------------------------
-- After a /reload with groups and recruits listed, Quick Join and
-- Recruit-A-Friend fill their lists before this addon loads. If those
-- groups go (or the list shrinks) before private mode turns on, the rows go
-- back to their lists' pools unhooked, and come back later for someone new.

do
    Wipe()
    H.Environment()
    G = {}
    Constants()
    Accounts()
    FriendCardMixin()
    ListMixins()
    QueueMixin()
    RecruitMixins()
    SocialWindow()
    OlderTabs()
    local queueRow = QueueRow(G.queueRows, SocialUIFrame.QuickJoinFrame.ScrollBox)
    ShowQueue(queueRow, { "Player-1-0002" })
    local socialRecruit = RecruitRow(G.recruitRows, SocialUIFrame.RecruitAFriendFrame.ScrollBox, true)
    ShowRecruit(socialRecruit, 1)
    local oldRecruit = RecruitRow(G.oldRecruitRows, RecruitAFriendFrame.RecruitList.ScrollBox, false)
    ShowRecruit(oldRecruit, 1)
    for name in pairs({ Blizzard_FriendsFrame = 1, Blizzard_SocialUI = 1, Blizzard_BNet = 1, Blizzard_RecentAllies = 1,
        Blizzard_QuickJoin = 1, Blizzard_RecruitAFriend = 1 }) do
        H.addOns[name] = true
    end
    P = H.Load(nil)
    -- The lists empty: their rows go back to the pools.
    table.remove(G.queueRows)
    table.remove(G.recruitRows)
    table.insert(G.oldRecruitPool, table.remove(G.oldRecruitRows))
    P:SetPrivate(true)
    Equal(T(queueRow.Members[1]), GUILDIE .. "|Hplayer:Brannoc Stonehelm|hBrannoc Stonehelm|h|r", "a row in the pool: left")

    -- A new group takes the kept-back row (its entry made now, as the list opens).
    table.insert(G.queueRows, queueRow)
    ShowQueue(queueRow, { "Player-1-0011", "Player-1-0002" })
    Equal(T(queueRow.Members[1]) .. " " .. T(queueRow.Members[2]), BNET .. BN_LINK .. "Friend (" .. Class("PRIEST") .. ")|h|r "
        .. GUILDIE .. "|Hplayer:Brannoc Stonehelm|h" .. Class("WARRIOR") .. "|h|r", "Quick Join: a kept-back row shows labels")

    -- The newer window's kept-back recruit row: its own colour step (which
    -- writes the names last) is hooked as it fills.
    table.insert(G.recruitRows, socialRecruit)
    ShowRecruit(socialRecruit, 1)
    Equal(T(socialRecruit.Name) .. "|" .. T(socialRecruit.CharacterName), Wrap(HIGHLIGHT, "Friend (" .. Class("PRIEST") .. ")") .. "|"
        .. Class("PRIEST"), "Recruit-A-Friend, newer window: a kept-back row shows labels")
    ShowRecruit(socialRecruit, 3)
    Equal(T(socialRecruit.Name), Wrap(DARKGRAY, "Friend"), "and follows its next recruit")

    -- The older window's: labelled (and hooked) when its list updates.
    Run(function() RecruitAFriendFrame:UpdateRecruitList({ G.recruits[1] }) end)
    Equal(T(oldRecruit.Name), "Friend (" .. Class("PRIEST") .. ")", "older window: a kept-back row labelled as the list updates")
    ShowRecruit(oldRecruit, 3)
    Equal(T(oldRecruit.Name), "Friend", "and hooked from then on")

    P:SetPrivate(false)
    Equal(T(queueRow.Members[1]), BNET .. BN_LINK .. "|Kq1|k|h|r", "off: Quick Join back")
    Equal(T(socialRecruit.Name) .. "|" .. T(oldRecruit.Name), Wrap(DARKGRAY, "Newbie") .. "|Newbie", "recruits back")
    H.ResetWrites()
    ShowQueue(queueRow, { "Player-1-0002" })
    ShowRecruit(socialRecruit, 1)
    Run(function() RecruitAFriendFrame:UpdateRecruitList({ G.recruits[1] }) end)
    Equal(H.Writes(), 0, "off: the new hooks do nothing")
    Equal(H.Problems(), "", "nothing wrong")
end

-- A window that loads after private mode is on: covered as it loads ----------------------------------------

do
    Wipe()
    H.Environment()
    G = {}
    Constants()
    Accounts()
    P = H.Load(nil)
    P:SetPrivate(true)
    Equal(Hooked().ShowBestDisplayTextAndButton, nil, "no window yet: nothing hooked")
    ListMixins()
    SocialWindow()
    RefreshHeader()
    H.LoadAddOn("Blizzard_SocialUI")
    Equal(Hooked().ShowBestDisplayTextAndButton, 1, "the window loads: its header is hooked")
    Equal(Hooked().RefreshName, 1, "and the ignore list's mixin, before its rows are made")
    Equal(Strip(), Wrap(TAG, "Battle.net"), "and covered at once")
    Equal(ClickCopy(), "ours", "the copy button out of reach")
    P:Set("myTag", "Late#1")
    Equal(Strip(), Wrap(TAG, "Late") .. Wrap(TAG_SUFFIX, "#1"), "a made-up BattleTag typed now shows at once")
    Equal(ClickCopy(), "ours", "still out of reach")
    local entry = IgnoreEntry({ blockType = 1, blockIndex = 1 })
    Equal(T(entry.Name), Grey("Player"), "its ignore list swaps")
    P:SetPrivate(false)
    Equal(ClickCopy(), "copied Squirt#1234", "off: back")
    Equal(H.Problems(), "", "nothing wrong")
end

-- A game with no newer window at all: nothing breaks -------------------------------------------------------

do
    Wipe()
    H.Environment()
    for _, name in ipairs({ "Blizzard_FriendsFrame", "Blizzard_SocialUI", "Blizzard_QuickJoin", "Blizzard_RecruitAFriend" }) do
        H.addOns[name] = true
    end
    P = H.Load(nil)
    P:SetPrivate(true)
    P:Set("nameStyle", "player")
    P:SetPrivate(false)
    Equal(H.Writes(), 0, "no window: nothing touched")
    Equal(H.Problems(), "", "and nothing wrong")
end

io.stdout:write("TestSocialUI: " .. H.checks .. " checks passed\n")
