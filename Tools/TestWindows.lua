-- Windows against a mock game (Tools/Harness.lua): the pop-ups that name
-- someone (party invite and its role version, guild invite, duel, trade,
-- summon, res, charter, channel invite, join requests), the ready check,
-- right-click menu titles, the trade window, loot (master loot list, roll
-- history, boss banner; its chat lines are Chat.lua's), the damage meter and its
-- breakdown, linked professions and guild crafters, and the battleground
-- scoreboard. Each: nothing while off, swapped while on, put back by its
-- own tick (leaving the others) and by turning private mode off, secrets
-- never read, nothing of Blizzard's written but text, colour and alpha.
-- Run with fengari: Tools/TestWindows.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local Text = H.Text

-- The globals there before any game: a fresh game drops every other one
-- (Blizzard's frames and functions this test made for the last).
local BASE = {}
for key in pairs(_G) do BASE[key] = true end
local function Wipe()
    local extra = {}
    for key in pairs(_G) do
        if not BASE[key] then extra[#extra + 1] = key end
    end
    for _, key in ipairs(extra) do _G[key] = nil end
end

-- The game's strings ---------------------------------------------------------------------------

local function Strings()
    INVITATION = "%s has invited you to join a group."
    ACCEPTING_INVITE_WILL_REMOVE_QUEUE = "Accepting will take you out of every queue."
    TRADE_WITH_QUESTION = "Trade with %s?"
    DUEL_REQUESTED = "%s has challenged you to a duel."
    DUEL_TO_THE_DEATH_REQUESTED = "|Hplayer:%s|h[%s]|h has challenged you to a Duel to the Death."
    RESURRECT_REQUEST = "%s wants to resurrect you."
    RESURRECT_REQUEST_NO_SICKNESS = "%s wants to bring you back."
    RESURRECT_REQUEST_TIMER = "%s wants to resurrect you. Wait %d %s."
    CONFIRM_SUMMON = "%s wants to summon you to %s. Ends in %d %s."
    -- The game's is positional (%2$s, %1$s), which fengari's format can't do.
    CHAT_INVITE_NOTICE_POPUP = "Join '%s'? Asked by %s."
    SECONDS, MINUTES = "sec", "min"
    READY_CHECK_MESSAGE = "%s has initiated a ready check."
    RAID_DIFFICULTY = "Raid Difficulty"
    GUILD_REPUTATION_WARNING = "You will lose your standing with %s."
    GUILD_REPUTATION_WARNING_GENERIC = "You will lose your guild standing."
    GUILD_CHARTER_TEMPLATE = "%s Guild Charter"
    NOT_YET_SIGNED = "Not yet signed"
    LOOT_HISTORY_CURRENT_WINNER = "%s (%d)"
    DAMAGE_METER_SOURCE_NAME = "%d. %s"
    DAMAGE_METER_SPELL_ENTRY_UNIT = "%s (%s)"
    TRADE_SKILL_TITLE = "%s"
    HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff"
end

local BRANNOC = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
    guid = "Player-1-0002" }
local MERRIN = { name = "Merrin", surname = "Lightfoot", class = "Mage", classFile = "MAGE", player = true, guid = "Player-1-0003" }
local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- Blizzard's side: each builder makes its frames (sealed) and the functions
-- the module hooks, written as the game's own code. -----------------------------------------

local function Hide(frame) S[frame].shown = false end
local function ShowIt(frame) H.Blizzard(function() frame:Show() end) end
local function HideIt(frame) H.Blizzard(function() frame:Hide() end) end

local B = {} -- the built objects, by name

local function BuildPopups()
    local function TimerText(format)
        return function(dialog, _, left)
            if left < 60 then return format:format(dialog.Text.text_arg1, left, SECONDS) end
            return format:format(dialog.Text.text_arg1, math.ceil(left / 60), MINUTES)
        end
    end
    local function SummonText(dialog, _, left)
        local who, area = C_SummonInfo.GetSummonConfirmSummoner(), C_SummonInfo.GetSummonConfirmAreaName()
        if left < 60 then return dialog.dialogInfo.text:format(who, area, left, SECONDS) end
        return dialog.dialogInfo.text:format(who, area, math.ceil(left / 60), MINUTES)
    end
    C_SummonInfo = { GetSummonConfirmSummoner = function() return "Brannoc Stonehelm" end,
        GetSummonConfirmAreaName = function() return "Stormwind City" end }
    StaticPopupDialogs = {
        TRADE = { text = TRADE_WITH_QUESTION },
        PARTY_INVITE = { text = "%s" },
        DUEL_REQUESTED = { text = DUEL_REQUESTED },
        DUEL_TO_THE_DEATH_REQUESTED = { text = DUEL_TO_THE_DEATH_REQUESTED },
        RESURRECT = { text = RESURRECT_REQUEST, deferred = true, startDelay = 0, timeout = 60, shownTime = 90,
            GetExpirationText = TimerText(RESURRECT_REQUEST_TIMER) },
        RESURRECT_NO_TIMER = { text = RESURRECT_REQUEST_NO_SICKNESS },
        CONFIRM_SUMMON = { text = CONFIRM_SUMMON, deferred = true, timeout = 0, shownTime = 120, GetExpirationText = SummonText },
        CHAT_CHANNEL_INVITE = { text = CHAT_INVITE_NOTICE_POPUP },
        GROUP_INVITE_CONFIRMATION = { text = "%s" },
        DELETE_ITEM = { text = "Delete %s?" },
    }
    -- GameDialogMixin:Init's text part.
    local function Init(dialog, which, a1, a2)
        local info = StaticPopupDialogs[which]
        if info.deferred then dialog.Text:SetText(" ") else dialog.Text:SetFormattedText(info.text, a1, a2) end
        dialog.Text.text_arg1, dialog.Text.text_arg2 = a1, a2
        dialog.startDelay = info.startDelay
    end
    B.dialogs, B.popupInit = {}, Init
    for i = 1, 4 do
        local dialog = H.BlizzardFrame("Frame", "StaticPopup" .. i, UIParent, { Init = Init })
        rawset(dialog, "Text", H.BlizzardText("StaticPopup" .. i .. "Text", dialog, ""))
        Hide(dialog)
        B.dialogs[i] = dialog
    end
    StaticPopup_Show = function(which, a1, a2)
        local info = StaticPopupDialogs[which]
        local dialog
        for i = 1, 4 do
            if not B.dialogs[i]:IsShown() then
                dialog = B.dialogs[i]
                break
            end
        end
        dialog.which, dialog.dialogInfo, dialog.timeleft = which, info, info.timeout or 0
        dialog:Init(which, a1, a2)
        dialog:Show()
        if info.shownTime then dialog.timeleft = info.shownTime end
        return dialog
    end
    StaticPopup_OnUpdate = function(dialog, elapsed)
        local info = dialog.dialogInfo
        if dialog.timeleft > 0 then
            dialog.timeleft = math.max(dialog.timeleft - elapsed, 0)
            if dialog.timeleft <= 0 then
                dialog:Hide()
                return
            end
            if not dialog.startDelay and info.GetExpirationText then
                dialog.Text:SetText(info.GetExpirationText(dialog, nil, math.ceil(dialog.timeleft)))
            end
        end
        if dialog.startDelay then
            local left = dialog.startDelay - elapsed
            if left <= 0 then
                dialog.startDelay = nil
                dialog.Text:SetFormattedText(info.text, dialog.Text.text_arg1, dialog.Text.text_arg2)
                return
            end
            dialog.startDelay = left
            if info.GetExpirationText then dialog.Text:SetText(info.GetExpirationText(dialog, nil, math.ceil(left))) end
        end
    end
    -- The role-asking party invite.
    B.roles = H.BlizzardFrame("Frame", "LFGInvitePopup", UIParent)
    B.rolesText = H.BlizzardText("LFGInvitePopupText", B.roles, "")
    Hide(B.roles)
    LFGInvitePopup_Update = function(inviter) LFGInvitePopupText:SetFormattedText(INVITATION, inviter) end
    -- The guild invite (its OnEvent is set in its XML).
    B.guild = H.BlizzardFrame("Frame", "GuildInviteFrame", UIParent)
    B.inviter = H.BlizzardText("GuildInviteFrameInviterName", B.guild, "")
    B.guildName = H.BlizzardText("GuildInviteFrameGuildName", B.guild, "")
    B.warning = H.BlizzardText("GuildInviteFrameWarningText", B.guild, "")
    B.emblem = H.BlizzardFrame("Texture", "GuildInviteFrameTabardEmblem", B.guild)
    B.tabardBack = H.BlizzardFrame("Texture", "GuildInviteFrameTabardBackground", B.guild)
    Hide(B.guild)
    S[B.guild].scripts.OnEvent = function(self, event, inviter, guildName, _, oldGuild)
        if event == "GUILD_INVITE_REQUEST" then
            GuildInviteFrameInviterName:SetText(inviter)
            GuildInviteFrameGuildName:SetText(guildName)
            if oldGuild then
                GuildInviteFrameWarningText:SetFormattedText(GUILD_REPUTATION_WARNING, oldGuild)
            else
                GuildInviteFrameWarningText:SetText("")
            end
            self:Show()
        end
    end
    -- A guild charter.
    B.petition = H.BlizzardFrame("Frame", "PetitionFrame", UIParent)
    for _, name in ipairs({ "NpcNameText", "CharterName", "MasterName" }) do B[name] = H.BlizzardText("PetitionFrame" .. name, B.petition, "") end
    B.members = {}
    for i = 1, 9 do B.members[i] = H.BlizzardText("PetitionFrameMemberName" .. i, B.petition, "") end
    Hide(B.petition)
    B.signers = { "Merrin Lightfoot", "Zriel Gustbellow", "Stranger Danger" }
    GetPetitionInfo = function() return "guild", "Iron Guard", "", 9, "Brannoc Stonehelm", false, 4 end
    GetNumPetitionNames = function() return #B.signers end
    GetPetitionNameInfo = function(i) return B.signers[i] end
    PetitionFrame_Update = function()
        local _, title, _, _, originator, _, minimum = GetPetitionInfo()
        PetitionFrameNpcNameText:SetFormattedText(GUILD_CHARTER_TEMPLATE, title)
        PetitionFrameCharterName:SetText(title)
        PetitionFrameMasterName:SetText(originator)
        for i = 1, minimum do
            _G["PetitionFrameMemberName" .. i]:SetText(i <= GetNumPetitionNames() and GetPetitionNameInfo(i) or NOT_YET_SIGNED)
        end
    end
end

local function BuildReadyCheck()
    B.ready = H.BlizzardFrame("Frame", "ReadyCheckFrame", UIParent)
    B.listener = H.BlizzardFrame("Frame", "ReadyCheckListenerFrame", B.ready)
    B.readyText = H.BlizzardText("ReadyCheckFrameText", B.listener, "")
    rawset(B.listener, "Text", B.readyText)
    B.portrait = H.BlizzardFrame("Texture", "ReadyCheckPortrait", B.listener)
    Hide(B.ready)
    B.difficulty = 2
    GetInstanceInfo = function() return "The Deadmines", "party", B.difficulty end
    GetDifficultyInfo = function(id) if id == 2 then return "Heroic", "party", false, false, false, false, 1 end end
    ShowReadyCheck = function(initiator)
        ReadyCheckFrame:Show()
        if UnitIsUnit("player", initiator) then
            ReadyCheckListenerFrame:Hide()
        else
            local line = READY_CHECK_MESSAGE
            local name, _, _, _, _, _, toggle = GetDifficultyInfo(B.difficulty)
            if toggle and toggle > 0 then line = READY_CHECK_MESSAGE .. "\n" .. RAID_DIFFICULTY .. ": " .. name end
            ReadyCheckListenerFrame.Text:SetFormattedText(line, initiator)
            ReadyCheckListenerFrame:Show()
        end
    end
end

local function BuildTrade()
    B.trade = H.BlizzardFrame("Frame", "TradeFrame", UIParent)
    B.myTradeName = H.BlizzardText("TradeFramePlayerNameText", B.trade, "")
    S[B.myTradeName].colour = { 1, .82, 0, 1 } -- the window's own gold
    B.theirTradeName = H.BlizzardText("TradeFrameRecipientNameText", B.trade, "")
    Hide(B.trade)
    TradeFrame_Update = function()
        TradeFramePlayerNameText:SetText(GetUnitName("player"))
        TradeFrameRecipientNameText:SetText(GetUnitName("NPC"))
    end
end

-- A loot history row, made as the game makes one: it copies the mixin's
-- Init at that moment.
local function LootRow(parent)
    local row = H.BlizzardFrame("Frame", nil, parent, { Init = LootHistoryElementMixin.Init })
    local won = H.BlizzardFrame("Frame", nil, row)
    rawset(won, "WinningRoll", H.BlizzardText(nil, won, ""))
    local pending = H.BlizzardFrame("Frame", nil, row)
    rawset(pending, "CurrentWinnerText", H.BlizzardText(nil, pending, ""))
    rawset(row, "WinningRollInfo", won)
    rawset(row, "PendingRollInfo", pending)
    return row
end

local function BuildLoot()
    B.lootFrame = H.BlizzardFrame("Frame", "LootFrame", UIParent, { selectedSlot = 1 })
    B.master = H.BlizzardFrame("Frame", "MasterLooterFrame", UIParent)
    Hide(B.master)
    B.candidates = { { "Zriel Gustbellow", "Druid", "DRUID" }, { "Brannoc Stonehelm", "Warrior", "WARRIOR" },
        { "Merrin Lightfoot", "Mage", "MAGE" } }
    GetMasterLootCandidate = function(_, i)
        local c = B.candidates[i]
        if c then return c[1], c[2], c[3] end
    end
    MasterLooterFrame_UpdatePlayers = function()
        for i = 1, 40 do
            local name, _, classFile = GetMasterLootCandidate(LootFrame.selectedSlot, i)
            if not name then break end
            local button = MasterLooterFrame["player" .. i]
            if not button then
                button = H.BlizzardFrame("Button", nil, MasterLooterFrame)
                rawset(button, "Name", H.BlizzardText(nil, button, ""))
                MasterLooterFrame["player" .. i] = button
            end
            button.id = i
            button.Name:SetText(name)
            local colour = RAID_CLASS_COLORS[classFile]
            button.Name:SetTextColor(colour.r, colour.g, colour.b)
            button:Show()
        end
    end
    LootHistoryElementMixin = {}
    function LootHistoryElementMixin:Init(dropInfo)
        self.dropInfo = dropInfo
        if dropInfo.winner then
            local colour = RAID_CLASS_COLORS[dropInfo.winner.playerClass]
            self.WinningRollInfo.WinningRoll:SetText("|c" .. colour.colorStr .. dropInfo.winner.playerName .. "|r")
        elseif dropInfo.currentLeader then
            self.PendingRollInfo.CurrentWinnerText:SetText(LOOT_HISTORY_CURRENT_WINNER:format(dropInfo.currentLeader.playerName,
                dropInfo.currentLeader.roll))
        end
    end
    B.lootInit = LootHistoryElementMixin.Init
    -- The roll history's hover: a small frame per roller laid into the tooltip.
    Enum.EncounterLootDropRollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
    LOOT_HISTORY_OFF_SPEC_FMT = "%s (Off-spec)"
    LootHistoryRollTooltipLineMixin = {}
    function LootHistoryRollTooltipLineMixin:Init(rollInfo)
        local name = "|c" .. RAID_CLASS_COLORS[rollInfo.playerClass].colorStr .. rollInfo.playerName .. "|r"
        if rollInfo.state == Enum.EncounterLootDropRollState.NeedOffSpec then name = LOOT_HISTORY_OFF_SPEC_FMT:format(name) end
        self.PlayerName:SetText(name)
    end
    B.rollLineInit = LootHistoryRollTooltipLineMixin.Init
    B.history = H.BlizzardFrame("Frame", "GroupLootHistoryFrame", UIParent)
    B.historyRows = {}
    rawset(B.history, "ScrollBox", H.BlizzardFrame("Frame", nil, B.history, { GetFrames = function() return B.historyRows end }))
    -- Made with the window, at load, before the addon.
    rawset(B.history, "PerfectAnimFrame", LootRow(B.history))
    Hide(B.history.PerfectAnimFrame)
    B.banner = H.BlizzardFrame("Frame", nil, UIParent)
    rawset(B.banner, "PlayerName", H.BlizzardText(nil, B.banner, ""))
    BossBanner_ConfigureLootFrame = function(lootFrame, data)
        lootFrame.PlayerName:SetText(data.playerName)
        local colour = RAID_CLASS_COLORS[data.className]
        lootFrame.PlayerName:SetTextColor(colour.r, colour.g, colour.b)
    end
end

-- A line of the roll history's hover, from the tooltip's pool (made when a
-- roll is first hovered, so it copies the hooked mixin).
local function RollLine(rollInfo)
    local line = H.BlizzardFrame("Frame", nil, UIParent, { Init = LootHistoryRollTooltipLineMixin.Init })
    rawset(line, "PlayerName", H.BlizzardText(nil, line, ""))
    H.Blizzard(function() line:Init(rollInfo) end)
    return line
end

-- A damage meter row as the game makes one (copying the mixin's Init).
local function MeterRow(mixin, parent)
    local row = H.BlizzardFrame("Button", nil, parent, { Init = mixin.Init })
    local bar = H.BlizzardFrame("StatusBar", nil, row)
    rawset(bar, "Name", H.BlizzardText(nil, bar, ""))
    rawset(row, "StatusBar", bar)
    return row
end

local function BuildMeter()
    DamageMeterSourceEntryMixin = {}
    function DamageMeterSourceEntryMixin:Init(source)
        self.sourceName, self.isLocalPlayer, self.classFilename = source.name, source.isLocalPlayer, source.classFilename
        self.deathRecapID, self.index = source.deathRecapID or 0, source.index
        local text
        if H.IsSecret(source.name) or self.deathRecapID ~= 0 then
            text = source.name
        else
            text = DAMAGE_METER_SOURCE_NAME:format(source.index, source.name)
        end
        -- UpdateName: only when it changed.
        if not rawequal(text, self.nameText) then
            self.nameText = text
            self.StatusBar.Name:SetText(text)
        end
    end
    DamageMeterSpellEntryMixin = {}
    function DamageMeterSpellEntryMixin:Init(spell)
        self.spellID, self.creatureName, self.unitName, self.unitClassFilename = spell.spellID, spell.creatureName, spell.unitName,
            spell.unitClassFilename
        if H.IsSecret(spell.spellID) or H.IsSecret(spell.unitName) then
            self.StatusBar.Name:SetText(H.SECRET)
        elseif spell.creatureName then
            self.StatusBar.Name:SetText(DAMAGE_METER_SPELL_ENTRY_UNIT:format(C_Spell.GetSpellName(spell.spellID), spell.creatureName))
        else
            local colour = RAID_CLASS_COLORS[spell.unitClassFilename]
            self.StatusBar.Name:SetText(DAMAGE_METER_SPELL_ENTRY_UNIT:format(C_Spell.GetSpellName(spell.spellID),
                "|c" .. colour.colorStr .. spell.unitName .. "|r"))
        end
    end
    C_Spell = { GetSpellName = function(id)
        if H.IsSecret(id) then return H.SECRET end
        return ({ [78] = "Heroic Strike", [133] = "Fireball" })[id]
    end }
    DamageMeterSessionWindowMixin = { InitEntry = function(_, frame, elementData) frame:Init(elementData) end }
    B.initEntry = DamageMeterSessionWindowMixin.InitEntry
    -- Made as the addon loads, before this one.
    B.meter = H.BlizzardFrame("Frame", "DamageMeterSessionWindow1", UIParent, { InitEntry = DamageMeterSessionWindowMixin.InitEntry })
    B.meterRows, B.spellRows = {}, {}
    local scroll = H.BlizzardFrame("Frame", nil, B.meter, { GetFrames = function() return B.meterRows end })
    -- The window's own row for you, made from its XML before the addon.
    B.localEntry = MeterRow(DamageMeterSourceEntryMixin, B.meter)
    Hide(B.localEntry)
    local source = H.BlizzardFrame("Frame", nil, B.meter)
    local spellScroll = H.BlizzardFrame("Frame", nil, source, { GetFrames = function() return B.spellRows end })
    rawset(source, "GetScrollBox", function() return spellScroll end)
    rawset(B.meter, "GetScrollBox", function() return scroll end)
    rawset(B.meter, "GetLocalPlayerEntry", function() return B.localEntry end)
    rawset(B.meter, "GetSourceWindow", function() return source end)
    B.scroll, B.spellScroll = scroll, spellScroll
end

local function BuildScoreboard()
    PVPCellNameMixin = { Populate = function(self, rowData) self.text:SetText(rowData.name) end }
    B.board = H.BlizzardFrame("Frame", "PVPMatchScoreboard", UIParent)
    B.boardRows = {}
    rawset(B.board, "ScrollBox", H.BlizzardFrame("Frame", nil, B.board, { GetFrames = function() return B.boardRows end }))
    Hide(B.board)
    -- The end-of-match results keep their list at scrollBox (lower case).
    B.results = H.BlizzardFrame("Frame", "PVPMatchResults", UIParent)
    B.resultRows = {}
    rawset(B.results, "scrollBox", H.BlizzardFrame("Frame", nil, B.results, { GetFrames = function() return B.resultRows end }))
    Hide(B.results)
end

-- A scoreboard row with its name cell, made in a match (after the addon).
local function ScoreRow(rowData, results)
    local row = H.BlizzardFrame("Frame", nil, results and B.results or B.board)
    local cell = H.BlizzardFrame("Button", nil, row, { Populate = PVPCellNameMixin.Populate, rowData = rowData })
    rawset(cell, "text", H.BlizzardText(nil, cell, ""))
    rawset(row, "cells", { cell })
    local rows = results and B.resultRows or B.boardRows
    rows[#rows + 1] = row
    H.Blizzard(function() cell:Populate(rowData) end)
    return cell
end

-- Blizzard_Professions is load-on-demand: its frames are made as it loads.
local function LoadProfessions()
    B.linked, B.linkedName = true, "Brannoc Stonehelm"
    C_TradeSkillUI = { IsTradeSkillLinked = function() return B.linked, B.linkedName end, IsTradeSkillGuild = function() return false end }
    ProfessionsGuildCrafterButtonMixin = { Init = function(self, data) self.Text:SetText(data.displayName) end }
    B.professions = H.BlizzardFrame("Frame", "ProfessionsFrame", UIParent, {
        SetTitle = function(self, skillLine)
            local linked, name = C_TradeSkillUI.IsTradeSkillLinked()
            if linked and name then
                self:GetTitleText():SetFormattedText("%s %s[%s]|r", TRADE_SKILL_TITLE:format(skillLine), HIGHLIGHT_FONT_COLOR_CODE, name)
            else
                self:GetTitleText():SetFormattedText(TRADE_SKILL_TITLE, skillLine)
            end
        end,
        GetTitleText = function() return B.title end,
        professionInfo = { professionName = "Tailoring" },
    })
    B.title = H.BlizzardText(nil, B.professions, "")
    local page = H.BlizzardFrame("Frame", nil, B.professions)
    local guild = H.BlizzardFrame("Frame", nil, page)
    local container = H.BlizzardFrame("Frame", nil, guild)
    B.crafters = {}
    rawset(container, "ScrollBox", H.BlizzardFrame("Frame", nil, container, { GetFrames = function() return B.crafters end }))
    rawset(guild, "Container", container)
    rawset(page, "GuildFrame", guild)
    rawset(B.professions, "CraftingPage", page)
    H.LoadAddOn("Blizzard_Professions")
end

local function Crafter(data)
    local button = H.BlizzardFrame("Button", nil, UIParent, { Init = ProfessionsGuildCrafterButtonMixin.Init,
        GetElementData = function() return data end })
    rawset(button, "Text", H.BlizzardText(nil, button, ""))
    B.crafters[#B.crafters + 1] = button
    H.Blizzard(function() button:Init(data) end)
    return button
end

local function Game()
    Wipe()
    H.Environment()
    Strings()
    for k in pairs(B) do B[k] = nil end
    H.units.party1 = Copy(BRANNOC)
    H.units.party2 = Copy(MERRIN)
    H.units.target = Copy(BRANNOC)
    H.units.NPC = Copy(BRANNOC)
    BuildPopups()
    BuildReadyCheck()
    BuildTrade()
    BuildLoot()
    BuildMeter()
    BuildScoreboard()
    -- Loaded with the game, before the addon.
    H.addOns.Blizzard_DamageMeter, H.addOns.Blizzard_PVPMatch = true, true
end

-- The game doing its own updates -------------------------------------------------------------------

local function Show(which, a1, a2) return H.Blizzard(function() return StaticPopup_Show(which, a1, a2) end) end
local function Tick(dialog, elapsed) H.Blizzard(function() StaticPopup_OnUpdate(dialog, elapsed) end) end
local function GuildInvite() H.Blizzard(H.Script, B.guild, "OnEvent", "GUILD_INVITE_REQUEST", "Brannoc Stonehelm", "Iron Guard", 0, "Old Friends") end
local function Petition()
    H.Blizzard(function()
        PetitionFrame:Show()
        PetitionFrame_Update(PetitionFrame)
    end)
end
local function RoleInvite()
    H.Blizzard(function()
        LFGInvitePopup:Show()
        LFGInvitePopup_Update("Brannoc Stonehelm", true, true, true)
    end)
end
local function ReadyCheck(initiator) H.Blizzard(function() ShowReadyCheck(initiator) end) end
local function Trade()
    H.Blizzard(function()
        TradeFrame:Show()
        TradeFrame_Update(TradeFrame)
    end)
end
local function MasterLoot()
    H.Blizzard(function()
        MasterLooterFrame:Show()
        MasterLooterFrame_UpdatePlayers()
    end)
end
local DROP_WON = { winner = { playerName = "Brannoc Stonehelm", playerClass = "WARRIOR", roll = 99 } }
local DROP_PENDING = { currentLeader = { playerName = "Merrin Lightfoot", playerClass = "MAGE", roll = 87 } }
local DROP_MINE = { winner = { playerName = "Zriel Gustbellow", playerClass = "DRUID", roll = 100, isSelf = true } }
local function InitRow(row, drop) H.Blizzard(function() row:Init(drop) end) end
local function Banner(data) H.Blizzard(function() BossBanner_ConfigureLootFrame(B.banner, data) end) end
local SOURCES = {
    { name = "Brannoc Stonehelm", classFilename = "WARRIOR", isLocalPlayer = false, index = 1 },
    { name = "Zriel Gustbellow", classFilename = "DRUID", isLocalPlayer = true, index = 2 },
    { name = "Defias Pillager", classFilename = "", isLocalPlayer = false, index = 3 },
}
-- A session row is set up through its window; a breakdown row on its own.
local function InitMeter(row, source, window)
    H.Blizzard(function() (window or B.meter):InitEntry(row, source) end)
end
local function InitSpell(row, spell) H.Blizzard(function() row:Init(spell) end) end
local SPELL = { spellID = 78, unitName = "Brannoc Stonehelm", unitClassFilename = "WARRIOR" }
local PET_SPELL = { spellID = 133, creatureName = "Wolfie", unitName = "Brannoc Stonehelm", unitClassFilename = "WARRIOR" }

-- Off: the game's names, nothing hooked but the row mixins, nothing touched ------------------------

Game()
local P = H.Load(nil)
local plainUpdate, plainShowReady = StaticPopup_OnUpdate, ShowReadyCheck
Equal(rawget(B.dialogs[1], "Init"), B.popupInit, "the pop-ups' Init is Blizzard's own until private mode first turns on")
True(LootHistoryElementMixin.Init ~= B.lootInit, "the loot history's row mixin is hooked at load, before rows are made")
True(LootHistoryRollTooltipLineMixin.Init ~= B.rollLineInit, "and its hover's line mixin, before its pool makes a line")
Equal(#(H.menuCallbacks.MENU_UNIT_TARGET or {}) .. " " .. #(H.menuCallbacks.MENU_UNIT_SELF or {}), "1 1",
    "the right-click menu callbacks added once, at load (never lazily)")
True(DamageMeterSessionWindowMixin.InitEntry ~= B.initEntry, "and the damage meter's, its addon being there already")
Equal(rawget(B.meter, "InitEntry"), B.initEntry, "but not a window made before it: that waits for private mode")

local trade = Show("TRADE", "Brannoc Stonehelm")
Equal(Text(trade.Text), "Trade with Brannoc Stonehelm?", "off: the trade request names them")
Tick(trade, .1)
GuildInvite()
Petition()
RoleInvite()
ReadyCheck("Brannoc Stonehelm")
Trade()
MasterLoot()
local wonRow = LootRow(B.history)
local pendingRow = LootRow(B.history)
B.historyRows[1], B.historyRows[2] = wonRow, pendingRow
InitRow(wonRow, DROP_WON)
InitRow(pendingRow, DROP_PENDING)
Banner({ playerName = "Brannoc Stonehelm", className = "WARRIOR" })
B.meterRows[1] = MeterRow(DamageMeterSourceEntryMixin, B.scroll)
B.meterRows[2] = MeterRow(DamageMeterSourceEntryMixin, B.scroll)
B.meterRows[3] = MeterRow(DamageMeterSourceEntryMixin, B.scroll)
for i = 1, 3 do InitMeter(B.meterRows[i], SOURCES[i]) end
B.spellRows[1] = MeterRow(DamageMeterSpellEntryMixin, B.spellScroll)
InitSpell(B.spellRows[1], SPELL)
ShowIt(B.board)
local myCell = ScoreRow({ name = "Zriel Gustbellow", classToken = "DRUID" })
local theirCell = ScoreRow({ name = "Merrin Lightfoot", classToken = "MAGE" })
ShowIt(B.results)
local resultCell = ScoreRow({ name = "Brannoc Stonehelm", classToken = "WARRIOR" }, true)
local rollLine = RollLine({ playerName = "Brannoc Stonehelm", playerClass = "WARRIOR", state = 0 })
Equal(Text(B.inviter) .. " / " .. Text(B.guildName) .. " / " .. Text(B.warning), "Brannoc Stonehelm / Iron Guard / You will lose "
    .. "your standing with Old Friends.", "off: the guild invite as the game wrote it")
Equal(Text(B.MasterName) .. " " .. Text(B.members[1]) .. " " .. Text(B.members[4]), "Brannoc Stonehelm Merrin Lightfoot Not yet signed",
    "off: the charter")
Equal(Text(B.readyText), "Brannoc Stonehelm has initiated a ready check.\nRaid Difficulty: Heroic", "off: the ready check")
Equal(Text(B.myTradeName) .. " / " .. Text(B.theirTradeName), "Zriel Gustbellow / Brannoc Stonehelm", "off: the trade window")
Equal(Text(B.master.player2.Name), "Brannoc Stonehelm", "off: the master loot list")
Equal(Text(B.meterRows[1].StatusBar.Name) .. " " .. Text(B.meterRows[2].StatusBar.Name), "1. Brannoc Stonehelm 2. Zriel Gustbellow",
    "off: the damage meter")
Equal(Text(myCell.text) .. " " .. Text(theirCell.text), "Zriel Gustbellow Merrin Lightfoot", "off: the scoreboard")
Equal(Text(resultCell.text), "Brannoc Stonehelm", "off: the results page")
Equal(Text(rollLine.PlayerName), "|c" .. RAID_CLASS_COLORS.WARRIOR.colorStr .. "Brannoc Stonehelm|r", "off: the roll history's hover")
Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Brannoc", surname = "Stonehelm" }, "Brannoc Stonehelm"),
    "Brannoc Stonehelm", "off: menus as the game draws them")
Equal(StaticPopup_OnUpdate, plainUpdate, "off: the pop-ups not hooked before private mode first turns on")
Equal(ShowReadyCheck, plainShowReady, "nor the ready check")
Equal(H.Writes(), 0, "off: nothing of Blizzard's touched")
Equal(H.Problems(), "", "off: nothing wrong")

-- On: everything showing swapped at once -------------------------------------------------------------

P:SetPrivate(true)
local function Warrior() return P:Colourise("Warrior", P:ClassColour("WARRIOR")) end
Equal(Text(trade.Text), "Trade with a player?", "on: the trade request says a player")
Equal(rawget(trade.Text, "text_arg1"), "Brannoc Stonehelm", "and the game's own copy of the name is left alone")
Equal(Text(B.inviter) .. " / " .. Text(B.guildName) .. " / " .. Text(B.warning), "A player / A guild / You will lose your guild "
    .. "standing.", "on: the guild invite")
Equal(H.Alpha(B.emblem) .. " " .. H.Alpha(B.tabardBack), "0 0", "and its tabard hidden")
Equal(Text(B.NpcNameText) .. " / " .. Text(B.CharterName) .. " / " .. Text(B.MasterName), "Guild Charter / Hidden / Warrior",
    "on: the charter's guild and who started it")
Equal(Text(B.members[1]) .. ", " .. Text(B.members[2]) .. ", " .. Text(B.members[3]) .. ", " .. Text(B.members[4]),
    "Mage, Druid, Player, Not yet signed", "and who signed, you and a stranger included")
Equal(Text(B.rolesText), "A player has invited you to join a group.", "on: the role-asking invite")
Equal(Text(B.readyText), "A player has initiated a ready check.\nRaid Difficulty: Heroic", "on: the ready check, its difficulty kept")
Equal(H.Alpha(B.portrait), 0, "and the face of who started it hidden")
Equal(Text(B.myTradeName) .. " / " .. Text(B.theirTradeName), "Druid / Warrior", "on: both names in the trade window")
Equal(S[B.theirTradeName].colour[1], RAID_CLASS_COLORS.WARRIOR.r, "in their class colour")
Equal(Text(B.master.player1.Name) .. " " .. Text(B.master.player2.Name) .. " " .. Text(B.master.player3.Name), "Druid Warrior Mage",
    "on: the master loot list")
Equal(Text(wonRow.WinningRollInfo.WinningRoll), Warrior(), "on: the roll history's winner")
Equal(Text(pendingRow.PendingRollInfo.CurrentWinnerText), "Mage (87)", "and who's winning so far")
Equal(Text(B.meterRows[1].StatusBar.Name) .. " " .. Text(B.meterRows[2].StatusBar.Name), "1. Warrior 2. Druid",
    "on: the damage meter, you included")
Equal(Text(B.meterRows[3].StatusBar.Name), "3. Defias Pillager", "a creature keeps its name")
Equal(Text(B.spellRows[1].StatusBar.Name), "Heroic Strike (" .. Warrior() .. ")", "the breakdown names a class")
Equal(Text(myCell.text) .. " " .. Text(theirCell.text), "Druid Mage", "on: the scoreboard, your own row by name")
Equal(Text(resultCell.text), "Warrior", "and the end-of-match results page (its list is scrollBox)")
H.Blizzard(function() rollLine:Init({ playerName = "Brannoc Stonehelm", playerClass = "WARRIOR", state = 0 }) end)
Equal(Text(rollLine.PlayerName), Warrior(), "the roll history's hover line, swapped as the next hover sets it up")
True(rawget(B.meter, "InitEntry") ~= B.initEntry, "the meter window, made before the addon, is hooked now")
True(rawget(B.history.PerfectAnimFrame, "Init") ~= B.lootInit, "and the roll history's animation row")
Equal(H.Problems(), "", "on: nothing wrong")

-- Apply twice is the same as once.
do
    local writes = H.Writes()
    P:Module("Windows"):Apply(true)
    Equal(H.Writes(), writes, "applying again changes nothing")
end

-- On: new pop-ups ------------------------------------------------------------------------------------

HideIt(trade)
local invite = Show("PARTY_INVITE", INVITATION:format("|cff00ff00Brannoc Stonehelm|r") .. "\n\n" .. ACCEPTING_INVITE_WILL_REMOVE_QUEUE)
Equal(Text(invite.Text), "A player has invited you to join a group.\n\n" .. ACCEPTING_INVITE_WILL_REMOVE_QUEUE,
    "a party invite, swapped in its Init before the game sizes it, the queue warning kept")
Tick(invite, .1)
Equal(Text(invite.Text), "A player has invited you to join a group.\n\n" .. ACCEPTING_INVITE_WILL_REMOVE_QUEUE, "and it stays")
HideIt(invite)
local duel = Show("DUEL_REQUESTED", "Brannoc Stonehelm")
Equal(Text(duel.Text), "A player has challenged you to a duel.", "a duel")
HideIt(duel)
local deathDuel = Show("DUEL_TO_THE_DEATH_REQUESTED", "Brannoc Stonehelm", "Brannoc Stonehelm")
Equal(Text(deathDuel.Text), "A player has challenged you to a Duel to the Death.", "a duel to the death, with no link left to hover")
HideIt(deathDuel)
local res = Show("RESURRECT_NO_TIMER", "Brannoc Stonehelm")
Equal(Text(res.Text), "A player wants to bring you back.", "a res")
HideIt(res)
local channel = Show("CHAT_CHANNEL_INVITE", "Crafters", "Brannoc Stonehelm")
Equal(Text(channel.Text), "Join 'Crafters'? Asked by a player.", "a channel invite: the channel kept, the name not")
HideIt(channel)
local join = Show("GROUP_INVITE_CONFIRMATION", "|Hplayer:Brannoc Stonehelm|h[Brannoc Stonehelm]|h wants to join.")
Equal(Text(join.Text), "A player wants to join your group.", "a join request, with no link left to hover")
HideIt(join)
local other = Show("DELETE_ITEM", "[Sword]")
Equal(Text(other.Text), "Delete [Sword]?", "a pop-up that names no one is left alone")
HideIt(other)

-- The timed ones rewrite their text every frame.
local timed = Show("RESURRECT", "Brannoc Stonehelm")
Tick(timed, .5)
Equal(Text(timed.Text), "A player wants to resurrect you. Wait 2 min.", "a timed res, the moment its delay ends")
Tick(timed, .5)
Equal(Text(timed.Text), "A player wants to resurrect you. Wait 2 min.", "and on its countdown")
Tick(timed, 60)
Equal(Text(timed.Text), "A player wants to resurrect you. Wait 29 sec.", "in seconds, as the game words it")
Equal(rawget(timed.Text, "text_arg1"), "Brannoc Stonehelm", "the timer's name, read back by the game, left alone")
local summon = Show("CONFIRM_SUMMON")
Tick(summon, .5)
Equal(Text(summon.Text), "A player wants to summon you to a hidden place. Ends in 2 min.", "a summon hides where it goes too")
Equal(H.Problems(), "", "pop-ups: nothing wrong")

-- Right-click menus ------------------------------------------------------------------------------------

Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Brannoc", surname = "Stonehelm" }, "Brannoc Stonehelm"), "Warrior",
    "a target's menu")
Equal(H.Menu("MENU_UNIT_SELF", { unit = "player", name = "Zriel", surname = "Gustbellow" }, "Zriel Gustbellow"), "Druid", "your own")
Equal(H.Menu("MENU_UNIT_FRIEND", { name = "Merrin", surname = "Lightfoot" }, "Merrin Lightfoot"), "Mage",
    "a menu with a name, not a unit")
Equal(H.Menu("MENU_UNIT_PVP_SCOREBOARD", { unit = "Player-1-0002", name = "Brannoc" }, "Brannoc"), "Warrior",
    "the scoreboard's, which carries a GUID")
Equal(H.Menu("MENU_UNIT_BN_FRIEND", { name = "|Kq12|k" }, "|Kq12|k"), "Player", "a Battle.net friend's")
Equal(H.Menu("MENU_UNIT_RAF_RECRUIT", { name = "|Kq13|k", bnetIDAccount = 13, isRafRecruit = true }, "|Kq13|k"), "Player",
    "a Recruit-A-Friend row's (the recruit's account name)")
H.units.target = { name = "Hogger", classFile = "WARRIOR", player = false, guid = "Creature-0-1" }
Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Hogger" }, "Hogger"), "Hogger", "an NPC's is left alone")
H.units.target = { name = "Brannoc", surname = "Stonehelm", player = true, secretName = true, secretClass = true, secretPlayer = true,
    guid = "Player-1-0009" }
Equal(H.Menu("MENU_UNIT_ENEMY_PLAYER", { unit = "target", name = H.SECRET }, H.SECRET), "Player",
    "a player the game keeps secret is Player, and nothing secret is read")
H.units.target = Copy(BRANNOC)
Equal(H.Menu("MENU_GROUP_LOOT", {}, "Master Looter"), "Master Looter", "a menu that isn't a unit's is left alone")
Equal(H.Problems(), "", "menus: nothing wrong")

-- Loot (its lines in chat are Chat.lua's) -------------------------------------------------------------

Banner({ playerName = "Brannoc Stonehelm", className = "WARRIOR" })
Equal(Text(B.banner.PlayerName), "Warrior", "the boss banner's loot list")
local mineRow = LootRow(B.history)
B.historyRows[3] = mineRow
InitRow(mineRow, DROP_MINE)
Equal(Text(mineRow.WinningRollInfo.WinningRoll), P:Colourise("Druid", P:ClassColour("DRUID")), "a roll you won: your label")
ShowIt(B.history.PerfectAnimFrame)
InitRow(B.history.PerfectAnimFrame, DROP_WON)
Equal(Text(B.history.PerfectAnimFrame.WinningRollInfo.WinningRoll), Warrior(), "the perfect roll animation's row")
MasterLoot()
Equal(Text(B.master.player2.Name), "Warrior", "the master loot list after the game's next update")
local offSpecLine = RollLine({ playerName = "Merrin Lightfoot", playerClass = "MAGE", state = 1 })
Equal(Text(offSpecLine.PlayerName), P:Colourise("Mage", P:ClassColour("MAGE")) .. " (Off-spec)",
    "who rolled, on the roll history's hover: off-spec kept")
local myRollLine = RollLine({ playerName = "Zriel Gustbellow", playerClass = "DRUID", isSelf = true, state = 3 })
Equal(Text(myRollLine.PlayerName), P:Colourise("Druid", P:ClassColour("DRUID")), "your own roll")

-- The damage meter in combat: names are secrets then ----------------------------------------------------

H.Combat(true)
InitMeter(B.meterRows[1], { name = H.SECRET, classFilename = "MAGE", isLocalPlayer = false, index = 1 })
Equal(Text(B.meterRows[1].StatusBar.Name), "1. Mage", "in combat: a secret name swapped, never read")
InitMeter(B.meterRows[2], { name = H.SECRET, classFilename = "DRUID", isLocalPlayer = true, index = 2, deathRecapID = 7 })
Equal(Text(B.meterRows[2].StatusBar.Name), "Druid", "a death row shows the label alone")
InitSpell(B.spellRows[1], { spellID = H.SECRET, unitName = H.SECRET, unitClassFilename = "WARRIOR" })
Equal(Text(B.spellRows[1].StatusBar.Name), Warrior(), "a breakdown row with a secret spell: the label alone")
ShowIt(B.localEntry)
InitMeter(B.localEntry, SOURCES[2])
Equal(Text(B.localEntry.StatusBar.Name), "2. Druid", "the window's own row for you")
H.Combat(false)
InitSpell(B.spellRows[1], PET_SPELL)
Equal(Text(B.spellRows[1].StatusBar.Name), "Fireball (Wolfie)", "a pet's line names only the pet, and is left alone")
InitMeter(B.meterRows[1], SOURCES[1])
InitMeter(B.meterRows[2], SOURCES[2])
InitSpell(B.spellRows[1], SPELL)
Equal(Text(B.meterRows[1].StatusBar.Name) .. " " .. Text(B.meterRows[2].StatusBar.Name), "1. Warrior 2. Druid", "after the fight")

-- A ready check started in a dungeon names a secret.
HideIt(B.listener)
ReadyCheck(H.SECRET)
Equal(Text(B.readyText), "A player has initiated a ready check.\nRaid Difficulty: Heroic", "a secret starter: swapped, never read")
ReadyCheck("player")
Equal(H.Shown(B.listener), false, "your own ready check shows no pop-up to swap")
ReadyCheck("Brannoc Stonehelm")
Equal(Text(B.readyText), "A player has initiated a ready check.\nRaid Difficulty: Heroic", "back to a readable one")

-- Professions load later -------------------------------------------------------------------------------

LoadProfessions()
H.Blizzard(function()
    ProfessionsFrame:Show()
    ProfessionsFrame:SetTitle("Tailoring")
end)
Equal(Text(B.title), "Tailoring |cffffffff[Warrior]|r", "a linked profession, its addon loaded after private mode came on")
local crafter = Crafter({ displayName = "Merrin Lightfoot", fullName = "Merrin Lightfoot", classFileName = "MAGE", online = true })
Equal(Text(crafter.Text), "Mage", "a guild crafter")
B.linked = false
H.Blizzard(function() ProfessionsFrame:SetTitle("Tailoring") end)
Equal(Text(B.title), "Tailoring", "your own profession is left alone")
B.linked = true
H.Blizzard(function() ProfessionsFrame:SetTitle("Tailoring") end)
Equal(H.Problems(), "", "loot, meter and professions: nothing wrong")

-- Name style and your own name ----------------------------------------------------------------------------

P:Set("nameStyle", "player")
Equal(Text(B.theirTradeName) .. " " .. Text(B.myTradeName), "Player Player", "Player style: the trade window")
Equal(Text(B.meterRows[1].StatusBar.Name), "1. Player", "the meter")
Equal(Text(B.master.player3.Name), "Player", "the master loot list")
Equal(Text(theirCell.text), "Player", "the scoreboard")
Equal(Text(B.title), "Tailoring |cffffffff[Player]|r", "the profession title")
Equal(Text(summon.Text), "A player wants to summon you to a hidden place. Ends in 2 min.", "pop-ups say a player in any style")
P:Set("myName", "Squirt")
Equal(Text(B.myTradeName) .. " " .. Text(B.meterRows[2].StatusBar.Name) .. " " .. Text(myCell.text), "Squirt 2. Squirt Squirt",
    "your typed name everywhere yours shows")
-- Your typed name in each colour, wherever it shows here. The game's own: the
-- trade window, the master loot list and the boss banner keep the colour the
-- game gave the name; the roll history, which writes every name in its class
-- colour, shows yours in your class colour; the rest are never coloured.
do
    local function Rgb(region)
        local c = S[region].colour
        return c and ("%.2f %.2f %.2f"):format(c[1], c[2], c[3]) or "none"
    end
    local function Hex(rgb) return ("%.2f %.2f %.2f"):format(rgb[1], rgb[2], rgb[3]) end
    local DRUID = { 1, .49, .04 }
    local cases = { { "accent", P.ACCENT }, { "class", DRUID }, { "white", { 1, 1, 1 } }, { "game" }, { "accent", P.ACCENT }, { "game" } }
    for _, case in ipairs(cases) do
        local choice, rgb = case[1], case[2]
        P:Set("myColour", choice)
        Banner({ playerName = "Zriel Gustbellow", className = "DRUID" })
        local rollLine = RollLine({ playerName = "Zriel Gustbellow", playerClass = "DRUID", isSelf = true, state = 0 })
        Equal(Text(B.myTradeName) .. " / " .. Rgb(B.myTradeName), "Squirt / " .. Hex(rgb or { 1, .82, 0 }),
            choice .. ": the trade window (the game's own: its gold)")
        Equal(Text(B.master.player1.Name) .. " / " .. Rgb(B.master.player1.Name), "Squirt / " .. Hex(rgb or DRUID),
            choice .. ": the master loot list (the game's own: the colour it gave)")
        Equal(Text(B.banner.PlayerName) .. " / " .. Rgb(B.banner.PlayerName), "Squirt / " .. Hex(rgb or DRUID),
            choice .. ": the boss banner")
        local coloured = P:Colourise("Squirt", unpack(rgb or DRUID))
        Equal(Text(mineRow.WinningRollInfo.WinningRoll) .. " | " .. Text(rollLine.PlayerName), coloured .. " | " .. coloured,
            choice .. ": the roll history and its hover")
        Equal(Text(B.meterRows[2].StatusBar.Name) .. " " .. Rgb(B.meterRows[2].StatusBar.Name) .. " | " .. Text(myCell.text) .. " "
            .. Rgb(myCell.text), "2. Squirt none | Squirt none", choice .. ": the meter and scoreboard, never coloured")
        Equal(H.Menu("MENU_UNIT_SELF", { unit = "player", name = "Zriel", surname = "Gustbellow" }, "Zriel Gustbellow"), "Squirt",
            choice .. ": your menu's title")
        Equal(Text(B.theirTradeName) .. " / " .. Rgb(B.theirTradeName), "Player / 0.78 0.78 0.78", choice .. ": your partner as before")
        local writes = H.Writes()
        P:Module("Windows"):Apply(true)
        Equal(H.Writes(), writes, choice .. ": applied again, nothing written")
    end
    Banner({ playerName = "Brannoc Stonehelm", className = "WARRIOR" })
end
P:Set("nameStyle", "hidden")
Equal(Text(B.theirTradeName) .. "|" .. Text(B.meterRows[1].StatusBar.Name), "|1. ", "Hidden: blank")
Equal(Text(B.title), "Tailoring", "a hidden name leaves no brackets")
P:Set("nameStyle", "class")
P:Set("myName", "")
Equal(Text(B.myTradeName) .. " " .. Text(B.theirTradeName), "Druid Warrior", "back to class names")
Equal(H.Problems(), "", "names: nothing wrong")

-- Each tick puts back its own surface and leaves the rest ----------------------------------------------------

HideIt(timed)
trade = Show("TRADE", "Brannoc Stonehelm")
Equal(Text(trade.Text), "Trade with a player?", "a new trade request")
P:Set("popups", false)
Equal(Text(trade.Text), "Trade with Brannoc Stonehelm?", "popups off: the trade request named again")
Equal(Text(B.inviter) .. " / " .. Text(B.guildName), "Brannoc Stonehelm / Iron Guard", "the guild invite")
Equal(H.Alpha(B.emblem), 1, "its tabard")
Equal(Text(B.MasterName) .. " " .. Text(B.members[2]), "Brannoc Stonehelm Zriel Gustbellow", "the charter")
Equal(Text(B.rolesText), "Brannoc Stonehelm has invited you to join a group.", "the role invite")
Equal(Text(B.theirTradeName), "Warrior", "and the trade window, another tick, stays swapped")
Tick(summon, .5)
Equal(Text(summon.Text), "Brannoc Stonehelm wants to summon you to Stormwind City. Ends in 2 min.", "a summon's next frame, left alone")
P:Set("popups", true)
Equal(Text(trade.Text) .. " " .. Text(B.inviter), "Trade with a player? A player", "popups back on: swapped at once")
Equal(Text(summon.Text), "A player wants to summon you to a hidden place. Ends in 2 min.", "the summon too")

P:Set("readyCheck", false)
Equal(Text(B.readyText), "Brannoc Stonehelm has initiated a ready check.\nRaid Difficulty: Heroic", "readyCheck off: put back")
Equal(H.Alpha(B.portrait), 1, "with its face")
P:Set("readyCheck", true)
Equal(Text(B.readyText), "A player has initiated a ready check.\nRaid Difficulty: Heroic", "and back on")

P:Set("menus", false)
Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Brannoc", surname = "Stonehelm" }, "Brannoc Stonehelm"),
    "Brannoc Stonehelm", "menus off: the game's title")
P:Set("menus", true)
Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Brannoc", surname = "Stonehelm" }, "Brannoc Stonehelm"), "Warrior",
    "and back on")

P:Set("trade", false)
Equal(Text(B.myTradeName) .. " / " .. Text(B.theirTradeName), "Zriel Gustbellow / Brannoc Stonehelm", "trade off: put back")
Equal(table.concat(S[B.theirTradeName].colour, ","), "1,1,1,1", "its colour too")
P:Set("trade", true)
Equal(Text(B.theirTradeName), "Warrior", "and back on")

P:Set("loot", false)
Equal(Text(B.master.player2.Name), "Brannoc Stonehelm", "loot off: the master loot list")
Equal(S[B.master.player2.Name].colour[1], RAID_CLASS_COLORS.WARRIOR.r, "in the game's colour")
Equal(Text(wonRow.WinningRollInfo.WinningRoll), "|c" .. RAID_CLASS_COLORS.WARRIOR.colorStr .. "Brannoc Stonehelm|r", "the roll history")
Equal(Text(B.banner.PlayerName), "Brannoc Stonehelm", "the boss banner")
Equal(Text(offSpecLine.PlayerName), LOOT_HISTORY_OFF_SPEC_FMT:format("|c" .. RAID_CLASS_COLORS.MAGE.colorStr .. "Merrin Lightfoot|r"),
    "the roll history's hover")
Equal(Text(B.meterRows[1].StatusBar.Name), "1. Warrior", "and the meter, another tick, stays swapped")
P:Set("loot", true)
Equal(Text(B.master.player2.Name) .. " " .. Text(wonRow.WinningRollInfo.WinningRoll), "Warrior " .. Warrior(), "and back on")

P:Set("meter", false)
Equal(Text(B.meterRows[1].StatusBar.Name) .. " " .. Text(B.meterRows[2].StatusBar.Name), "1. Brannoc Stonehelm 2. Zriel Gustbellow",
    "meter off: put back")
Equal(Text(B.spellRows[1].StatusBar.Name), "Heroic Strike (|c" .. RAID_CLASS_COLORS.WARRIOR.colorStr .. "Brannoc Stonehelm|r)",
    "its breakdown")
InitMeter(B.meterRows[1], SOURCES[1])
Equal(Text(B.meterRows[1].StatusBar.Name), "1. Brannoc Stonehelm", "and the game's next update leaves it")
P:Set("meter", true)
Equal(Text(B.meterRows[1].StatusBar.Name) .. " " .. Text(B.localEntry.StatusBar.Name), "1. Warrior 2. Druid", "and back on")

P:Set("professions", false)
Equal(Text(B.title) .. " " .. Text(crafter.Text), "Tailoring |cffffffff[Brannoc Stonehelm]|r Merrin Lightfoot", "professions off")
P:Set("professions", true)
Equal(Text(B.title) .. " " .. Text(crafter.Text), "Tailoring |cffffffff[Warrior]|r Mage", "and back on")

P:Set("scoreboard", false)
Equal(Text(myCell.text) .. " " .. Text(theirCell.text), "Zriel Gustbellow Merrin Lightfoot", "scoreboard off")
P:Set("scoreboard", true)
Equal(Text(myCell.text) .. " " .. Text(theirCell.text), "Druid Mage", "and back on")
Equal(H.Problems(), "", "ticks: nothing wrong")

-- Off: everything put back, and nothing touched after ------------------------------------------------------

P:SetPrivate(false)
Equal(Text(trade.Text), "Trade with Brannoc Stonehelm?", "off: the trade request")
Equal(Text(B.inviter) .. " / " .. Text(B.guildName) .. " / " .. Text(B.warning), "Brannoc Stonehelm / Iron Guard / You will lose "
    .. "your standing with Old Friends.", "the guild invite")
Equal(H.Alpha(B.emblem) .. " " .. H.Alpha(B.tabardBack), "1 1", "its tabard")
Equal(Text(B.NpcNameText) .. " / " .. Text(B.CharterName) .. " / " .. Text(B.members[1]), "Iron Guard Guild Charter / Iron Guard / "
    .. "Merrin Lightfoot", "the charter")
Equal(Text(B.readyText), "Brannoc Stonehelm has initiated a ready check.\nRaid Difficulty: Heroic", "the ready check")
Equal(H.Alpha(B.portrait), 1, "its face")
Equal(Text(B.myTradeName) .. " / " .. Text(B.theirTradeName), "Zriel Gustbellow / Brannoc Stonehelm", "the trade window")
Equal(Text(B.master.player1.Name) .. ", " .. Text(B.master.player3.Name), "Zriel Gustbellow, Merrin Lightfoot", "the master loot list")
Equal(Text(pendingRow.PendingRollInfo.CurrentWinnerText), "Merrin Lightfoot (87)", "the roll history")
Equal(Text(B.meterRows[2].StatusBar.Name) .. " / " .. Text(B.localEntry.StatusBar.Name), "2. Zriel Gustbellow / 2. Zriel Gustbellow",
    "the meter")
Equal(Text(B.title) .. " " .. Text(crafter.Text), "Tailoring |cffffffff[Brannoc Stonehelm]|r Merrin Lightfoot", "professions")
Equal(Text(myCell.text) .. " " .. Text(resultCell.text), "Zriel Gustbellow Brannoc Stonehelm", "the scoreboard and results")
Equal(Text(rollLine.PlayerName), "|c" .. RAID_CLASS_COLORS.WARRIOR.colorStr .. "Brannoc Stonehelm|r", "the roll history's hover")
H.ResetWrites()
local cvarsBefore = #H.cvarWrites -- the other modules' settings, put back
HideIt(trade)
trade = Show("TRADE", "Brannoc Stonehelm")
Tick(trade, .1)
Tick(summon, .5)
GuildInvite()
Petition()
RoleInvite()
ReadyCheck("Brannoc Stonehelm")
Trade()
MasterLoot()
InitRow(wonRow, DROP_WON)
Banner({ playerName = "Brannoc Stonehelm", className = "WARRIOR" })
InitMeter(B.meterRows[1], SOURCES[1])
InitSpell(B.spellRows[1], SPELL)
H.Blizzard(function() ProfessionsFrame:SetTitle("Tailoring") end)
H.Blizzard(function() myCell:Populate(myCell.rowData) end)
Equal(Text(trade.Text) .. " " .. Text(summon.Text), "Trade with Brannoc Stonehelm? Brannoc Stonehelm wants to summon you to "
    .. "Stormwind City. Ends in 2 min.", "off: the game's own text from then on")
Equal(H.Menu("MENU_UNIT_TARGET", { unit = "target", name = "Brannoc", surname = "Stonehelm" }, "Brannoc Stonehelm"),
    "Brannoc Stonehelm", "menus")
Equal(H.Writes(), 0, "off: the hooks touch nothing of Blizzard's")
Equal(#H.cvarWrites, cvarsBefore, "and no game setting changed")
Equal(H.Problems(), "", "off: nothing wrong")

-- A meter that loads after private mode came on ------------------------------------------------------------

do
    Wipe()
    H.Environment()
    Strings()
    for k in pairs(B) do B[k] = nil end
    H.units.party1 = Copy(BRANNOC)
    local P2 = H.Load(nil)
    P2:SetPrivate(true)
    BuildMeter()
    H.LoadAddOn("Blizzard_DamageMeter")
    ShowIt(B.localEntry)
    InitMeter(B.localEntry, SOURCES[2])
    Equal(Text(B.localEntry.StatusBar.Name), "2. Druid", "a meter loaded later: its window, made before the hook, is hooked")
    local row = MeterRow(DamageMeterSourceEntryMixin, B.scroll)
    InitMeter(row, SOURCES[1])
    Equal(Text(row.StatusBar.Name), "1. Warrior", "and its rows")
    P2:SetPrivate(false)
    Equal(Text(row.StatusBar.Name) .. " / " .. Text(B.localEntry.StatusBar.Name), "1. Brannoc Stonehelm / 2. Zriel Gustbellow",
        "put back when private mode turns off")
    Equal(H.Problems(), "", "nothing wrong")
end

-- A meter window the player adds after the hook copies the hooked mixin, so
-- Setup leaves it as made (never hooked twice).
do
    Wipe()
    H.Environment()
    Strings()
    for k in pairs(B) do B[k] = nil end
    H.units.party1 = Copy(BRANNOC)
    local P2 = H.Load(nil)
    BuildMeter()
    H.LoadAddOn("Blizzard_DamageMeter")
    local second = H.BlizzardFrame("Frame", "DamageMeterSessionWindow2", UIParent,
        { InitEntry = DamageMeterSessionWindowMixin.InitEntry })
    P2:SetPrivate(true)
    Equal(rawget(second, "InitEntry"), DamageMeterSessionWindowMixin.InitEntry, "a window made after the hook is left as made")
    True(rawget(B.meter, "InitEntry") ~= B.initEntry, "one made before it is hooked")
    local calls = 0
    local row = MeterRow(DamageMeterSourceEntryMixin, second)
    InitMeter(row, SOURCES[1], second)
    Equal(Text(row.StatusBar.Name), "1. Warrior", "and its rows are swapped")
    local first = MeterRow(DamageMeterSourceEntryMixin, B.scroll)
    InitMeter(first, SOURCES[2])
    Equal(Text(first.StatusBar.Name), "2. Druid", "as are the other window's")
    calls = H.Writes()
    InitMeter(first, SOURCES[2])
    Equal(H.Writes(), calls, "the same row again: nothing written twice")
    P2:SetPrivate(false)
    Equal(H.Problems(), "", "nothing wrong")
end

-- One surface failing never stops the others ------------------------------------------------------------------

do
    Game()
    local P2 = H.Load(nil)
    rawset(B.dialogs[1], "IsShown", function() error("the pop-up broke") end)
    ReadyCheck("Brannoc Stonehelm")
    Trade()
    P2:SetPrivate(true)
    Equal(Text(B.readyText), "A player has initiated a ready check.\nRaid Difficulty: Heroic",
        "the ready check swapped although the pop-ups failed first")
    Equal(Text(B.theirTradeName), "Warrior", "and the trade window")
    Equal(#H.printed, 1, "the error said once")
    True(H.printed[1]:find("The Windows part hit an error", 1, true), "as the Windows part's")
    H.Clear()
    P2:SetPrivate(false)
    Equal(H.Problems(), "", "nothing else wrong")
end

-- Nothing of Blizzard's there at all (an older client, or a test of the core) --------------------------------

do
    Wipe()
    H.Environment()
    local P3 = H.Load(nil)
    P3:SetPrivate(true)
    P3:Set("nameStyle", "player")
    P3:Set("loot", false)
    P3:SetPrivate(false)
    Equal(H.Writes(), 0, "with none of the windows, nothing is touched")
    Equal(H.Problems(), "", "and nothing goes wrong")
end

io.stdout:write("TestWindows: " .. H.checks .. " checks passed\n")
