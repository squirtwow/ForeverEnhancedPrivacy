-- Windows: pop-ups and windows that name players. Owns popups, readyCheck,
-- menus, trade, loot, meter, professions and scoreboard.
--
-- popups: the game's pop-ups that name someone (party invite and its role
--   version, guild invite, duel, trade request, summon, resurrection,
--   charter signing, chat channel invite, join requests) say "A player",
--   and a summon hides where it goes. The game's own copy of the name
--   (text_arg1, which its timers read back) is never touched.
-- readyCheck: the ready check pop-up, and the face of whoever started it.
-- menus: the title of right-click player menus (Menu.ModifyMenu, unit menus).
-- trade: both names in the trade window.
-- loot: the master loot list, the loot roll history (its rows, and who
--   rolled on its hover) and the boss loot banner. Loot lines in chat follow
--   this tick too, but Chat.lua does them. The hover's "Waiting on" line is
--   one of the game's tooltip lines, so it's left (Good to know says so).
-- meter: the damage meter's rows (yours too) and its breakdown.
-- professions: "Tailoring [name]" on a linked profession, and guild crafters.
-- scoreboard: battleground scoreboard and results names (experimental).
--
-- Only post-hooks, a HookScript and Menu.ModifyMenu, and every change goes
-- through the core so it comes back when private mode turns off. Each hook
-- returns at once while its setting is off.
local _, P = ...

local M = P:Module("Windows")

local IsSecret = P.IsSecret
local SOMEONE, SOMEONE_START = "a player", "A player"
local A_GUILD, HIDDEN, HIDDEN_PLACE = "A guild", "Hidden", "a hidden place"
local JOIN_REQUEST = "A player wants to join your group."
local INVITATION = "%s has invited you to join a group."
local POPUP_FRAMES = 4 -- StaticPopup1 to StaticPopup4
local MAX_GROUP = 40
local METER_WINDOWS = 10
local setUp = false -- Setup has run this session

-- Small helpers ------------------------------------------------------------------------------

-- A readable string with something in it, or nil (a secret never is).
local function Text(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

local function Number(value)
    if IsSecret(value) or type(value) ~= "number" then return nil end
    return value
end

-- A table hung on one of Blizzard's frames (a parentKey), or nil.
local function Child(object, key)
    if type(object) ~= "table" then return nil end
    local value = object[key]
    return type(value) == "table" and value or nil
end

-- One of the game's own strings, or our words when this client hasn't it.
local function Global(name, fallback)
    return Text(_G[name]) or fallback
end

-- A label in its colour, as text, where the game writes every name in its
-- class colour (the roll history, the meter's breakdown). Your typed name in
-- the game's own colour takes that class colour too (classFile: the row's).
local function ClassText(classFile, label, r, g, b)
    if not r then r, g, b = P:ClassColour(Text(classFile)) end
    return P:Colourise(label, r, g, b)
end

-- A format filled in, or nil if it won't take these values.
local function Fill(format, ...)
    if not Text(format) then return nil end
    local ok, text = pcall(string.format, format, ...)
    if ok and type(text) == "string" then return text end
    return nil
end

local function Capital(text)
    return text and (text:gsub("^" .. SOMEONE, SOMEONE_START))
end

-- The game's sentence with "a player" where it put the name (its first
-- value), and a capital when that opens the sentence.
local function Someone(format, ...)
    return Capital(Fill(format, SOMEONE, ...))
end

-- Asks one of Blizzard's objects something (a Get method), safely.
local function Ask(object, method, ...)
    local fn = type(object) == "table" and object[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
    return nil
end

-- Each frame a scroll box is showing.
local function ForFrames(scrollBox, fn)
    local frames = Ask(scrollBox, "GetFrames")
    if type(frames) ~= "table" then return end
    for _, frame in ipairs(frames) do fn(frame) end
end

-- Shows text on a region through the core (so it comes back), unless it
-- already shows exactly that, in that colour. No colour (your name in the
-- game's own): the game's colour, with ours taken off.
local function Put(key, region, text, r, g, b)
    if type(region) ~= "table" or type(text) ~= "string" then return end
    if P:Showing(key, region, text, r, g, b) then return end
    P:SwapText(key, region, text, r, g, b)
end

-- Hides a texture through the core (so it comes back), unless it's hidden.
local function Conceal(key, region)
    if type(region) ~= "table" then return end
    local alpha = region:GetAlpha()
    if not IsSecret(alpha) and alpha == 0 then return end
    P:HideRegion(key, region)
end

-- Hooks --------------------------------------------------------------------------------------

local hooked = {} -- method: { [object] = true }, so nothing is hooked twice

-- Post-hooks an object's method, or a global function when object is nil.
-- The hook can't break anything (P:Guard). False if there's nothing to hook.
local function Hook(object, method, fn)
    local target = object or _G
    if type(target) ~= "table" or type(target[method]) ~= "function" then return false end
    hooked[method] = hooked[method] or setmetatable({}, { __mode = "k" })
    if hooked[method][target] then return true end
    local guarded = P:Guard(M, fn)
    local ok
    if object then
        ok = pcall(hooksecurefunc, object, method, guarded)
    else
        ok = pcall(hooksecurefunc, method, guarded)
    end
    if ok then hooked[method][target] = true end
    return ok
end

local function HookMixin(name, method, fn)
    local mixin = _G[name]
    if type(mixin) ~= "table" then return false end
    return Hook(mixin, method, fn)
end

-- A row made before its mixin was hooked kept the old method: hook it too.
-- (The frame's own copy, read raw: only compared, never called.)
local function HookOlder(object, mixinName, method, fn)
    local mixin = _G[mixinName]
    if type(object) ~= "table" or type(mixin) ~= "table" then return end
    local own = rawget(object, method)
    if type(own) == "function" and own ~= mixin[method] then Hook(object, method, fn) end
end

-- Pop-ups ------------------------------------------------------------------------------------

local PLAIN = { TRADE = true, DUEL_REQUESTED = true, RESURRECT_NO_TIMER = true }
local TIMERS = { RESURRECT = "RESURRECT_REQUEST_TIMER", RESURRECT_NO_SICKNESS = "RESURRECT_REQUEST_NO_SICKNESS_TIMER" }
local SUMMONS = { CONFIRM_SUMMON = true, CONFIRM_SUMMON_SCENARIO = true, CONFIRM_SUMMON_STARTING_AREA = true }

-- A pop-up's countdown as the game words it (count, unit), or nil.
local function Countdown(dialog)
    local left = Number(dialog.startDelay)
    if not left or left <= 0 then left = Number(dialog.timeleft) end
    if not left or left <= 0 then return nil end
    left = math.ceil(left)
    if left < 60 then return left, Global("SECONDS", "sec") end
    return math.ceil(left / 60), Global("MINUTES", "min")
end

-- What a pop-up says instead, built from the game's own wording, or nil to
-- leave it.
local function PopupText(dialog)
    local which = Text(dialog.which)
    if not which then return nil end
    local info = dialog.dialogInfo
    local format = type(info) == "table" and info.text or nil
    if PLAIN[which] then return Someone(format) end
    if which == "PARTY_INVITE" then
        local text = Someone(Global("INVITATION", INVITATION))
        local queue = Text(_G.ACCEPTING_INVITE_WILL_REMOVE_QUEUE)
        local shown = Text(Ask(Child(dialog, "Text"), "GetText"))
        if text and queue and shown and shown:find(queue, 1, true) then text = text .. "\n\n" .. queue end
        return text
    end
    if which == "CHAT_CHANNEL_INVITE" then
        local region = Child(dialog, "Text")
        return Capital(Fill(format, Text(region and region.text_arg1) or "", SOMEONE))
    end
    if which == "DUEL_TO_THE_DEATH_REQUESTED" then
        local text = Fill(format, SOMEONE, SOMEONE)
        if not text then return nil end
        -- No link left to hover, so nothing can bring the name up.
        text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("%[" .. SOMEONE .. "%]", SOMEONE)
        return Capital(text)
    end
    if which == "GROUP_INVITE_CONFIRMATION" then return JOIN_REQUEST end
    if TIMERS[which] or SUMMONS[which] then
        local count, unit = Countdown(dialog)
        if not count then return nil end
        if SUMMONS[which] then return Someone(format, HIDDEN_PLACE, count, unit) end
        return Someone(_G[TIMERS[which]], count, unit)
    end
    return nil
end

-- From the pop-up's Init (before the game sizes it) and every frame it's up
-- (summons and res rewrite their text with a countdown).
local function FixPopup(dialog)
    if not P:IsOn("popups") or type(dialog) ~= "table" then return end
    local region = Child(dialog, "Text")
    if region then Put("popups", region, PopupText(dialog)) end
end

-- The party invite that asks for a role.
local function FixRoleInvite()
    if not P:IsOn("popups") then return end
    Put("popups", _G.LFGInvitePopupText, Someone(Global("INVITATION", INVITATION)))
end

local TABARD = { "GuildInviteFrameTabardEmblem", "GuildInviteFrameTabardBackground", "GuildInviteFrameTabardBorder" }

local function FixGuildInvite()
    if not P:IsOn("popups") then return end
    Put("popups", _G.GuildInviteFrameInviterName, SOMEONE_START)
    Put("popups", _G.GuildInviteFrameGuildName, A_GUILD)
    -- The warning names the guild you'd be leaving.
    local warning = _G.GuildInviteFrameWarningText
    if type(warning) == "table" and Text(warning:GetText()) then
        Put("popups", warning, Global("GUILD_REPUTATION_WARNING_GENERIC", ""))
    end
    for _, name in ipairs(TABARD) do Conceal("popups", _G[name]) end
end

local function CharterTitle()
    local title = Global("GUILD_CHARTER_TEMPLATE", "%s Guild Charter"):gsub("%%%d*%$?s", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return title ~= "" and title or "Guild Charter"
end

-- A guild charter: who started it, who signed, and the guild's name.
local function FixPetition()
    if not P:IsOn("popups") or type(GetPetitionInfo) ~= "function" then return end
    local ok, kind, _, _, _, originator, _, minimum = pcall(GetPetitionInfo)
    if not ok then return end
    if Text(kind) == "guild" then
        Put("popups", _G.PetitionFrameNpcNameText, CharterTitle())
        Put("popups", _G.PetitionFrameCharterName, HIDDEN)
        Put("popups", _G.PetitionFrameMasterName, (P:LabelForName(originator)))
    end
    local okCount, count = pcall(GetNumPetitionNames)
    count = okCount and Number(count) or 0
    for i = 1, math.min(count, Number(minimum) or 0) do
        local okName, name = pcall(GetPetitionNameInfo, i)
        if okName then Put("popups", _G["PetitionFrameMemberName" .. i], (P:LabelForName(name))) end
    end
end

local function RefreshPopups()
    for i = 1, POPUP_FRAMES do
        local dialog = _G["StaticPopup" .. i]
        if type(dialog) == "table" and dialog:IsShown() then FixPopup(dialog) end
    end
    local roles = _G.LFGInvitePopup
    if type(roles) == "table" and roles:IsShown() then FixRoleInvite() end
    local guild = _G.GuildInviteFrame
    if type(guild) == "table" and guild:IsShown() then FixGuildInvite() end
    local petition = _G.PetitionFrame
    if type(petition) == "table" and petition:IsShown() then FixPetition() end
end

-- Ready checks -------------------------------------------------------------------------------

-- The difficulty line the game adds under a ready check, or "".
local function DifficultyLine()
    if type(GetInstanceInfo) ~= "function" or type(GetDifficultyInfo) ~= "function" then return "" end
    local ok, _, _, id = pcall(GetInstanceInfo)
    id = ok and Number(id) or nil
    if not id or id == 0 then
        local okRaid, raid = pcall(UnitInRaid, "player")
        local get = (okRaid and not IsSecret(raid) and raid) and GetRaidDifficultyID or GetDungeonDifficultyID
        local okID, value = pcall(get)
        id = okID and Number(value) or nil
    end
    if not id then return "" end
    local okInfo, name, _, _, _, _, _, toggle = pcall(GetDifficultyInfo, id)
    if okInfo and Text(name) and Number(toggle) and toggle > 0 then
        return "\n" .. Global("RAID_DIFFICULTY", "Raid Difficulty") .. ": " .. name
    end
    return ""
end

-- Who started it can be a secret in dungeons, so it's never read: the line
-- is written fresh, and the starter's face is hidden.
local function FixReadyCheck()
    if not P:IsOn("readyCheck") then return end
    local frame = _G.ReadyCheckListenerFrame
    if type(frame) ~= "table" or not frame:IsShown() then return end
    local message = Someone(Global("READY_CHECK_MESSAGE", "%s has initiated a ready check."))
    Put("readyCheck", Child(frame, "Text") or _G.ReadyCheckFrameText, message and message .. DifficultyLine())
    Conceal("readyCheck", _G.ReadyCheckPortrait)
end

-- Right-click menus --------------------------------------------------------------------------

local MENUS = { "SELF", "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "ENEMY_PLAYER", "FRIEND", "FRIEND_OFFLINE",
    "BN_FRIEND", "BN_FRIEND_OFFLINE", "GUILD", "GUILD_OFFLINE", "CHAT_ROSTER", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER",
    "COMMUNITIES_MEMBER", "RECENT_ALLY", "RECENT_ALLY_OFFLINE", "PVP_SCOREBOARD", "WORLD_STATE_SCORE", "ARENAENEMY", "PET",
    "OTHERPET", "VEHICLE", "RAF_RECRUIT" } -- RAF_RECRUIT: a Recruit-A-Friend row (its name is the recruit's account)

-- What a menu's title becomes, or nil to leave it (an NPC's).
local function MenuLabel(context)
    if type(context) ~= "table" then return nil end
    local unit = Text(context.unit)
    if unit then
        local okExists, exists = pcall(UnitExists, unit)
        if okExists and not IsSecret(exists) and exists then return P:NameFor(unit) end
        -- The scoreboard's menus carry a GUID.
        if unit:find("^Player%-") then return P:LabelForGUID(unit) end
    end
    local name = context.name
    if IsSecret(name) then return P:StyleLabel(nil) end
    name = Text(name)
    if not name then return nil end
    local surname = Text(context.surname)
    return P:LabelForName(surname and (name .. " " .. surname) or name)
end

-- Blizzard's title initializer sets the name; ours runs after it. Menus are
-- drawn fresh each time they open, so there's nothing to put back.
local function OnMenu(_, root, context)
    if not P:IsOn("menus") or type(root) ~= "table" or type(root.EnumerateElementDescriptions) ~= "function" then return end
    local title
    for _, element in root:EnumerateElementDescriptions() do
        title = element
        break
    end
    if type(title) ~= "table" or type(title.AddInitializer) ~= "function" then return end
    title:AddInitializer(P:Guard(M, function(frame)
        if not P:IsOn("menus") then return end
        local label = MenuLabel(context)
        local text = Child(frame, "fontString")
        if label ~= nil and text then text:SetText(label) end
    end))
end

-- Trade --------------------------------------------------------------------------------------

local function FixTrade()
    if not P:IsOn("trade") then return end
    local mine = _G.TradeFramePlayerNameText
    if type(mine) == "table" then Put("trade", mine, P:MyLabel()) end
    local theirs = _G.TradeFrameRecipientNameText
    if type(theirs) == "table" then
        local label, r, g, b = P:NameFor("NPC")
        if label == nil then label, r, g, b = P:StyleLabel(nil) end
        Put("trade", theirs, label, r, g, b)
    end
end

-- Loot ---------------------------------------------------------------------------------------

local function FixMasterLoot()
    if not P:IsOn("loot") or type(GetMasterLootCandidate) ~= "function" then return end
    local frame, loot = _G.MasterLooterFrame, _G.LootFrame
    if type(frame) ~= "table" or type(loot) ~= "table" then return end
    local slot = loot.selectedSlot
    for i = 1, MAX_GROUP do
        local button = Child(frame, "player" .. i)
        local name = Child(button, "Name")
        if name and button:IsShown() then
            local ok, candidate, _, classFile = pcall(GetMasterLootCandidate, slot, button.id)
            if ok and (IsSecret(candidate) or Text(candidate)) then Put("loot", name, P:LabelForName(candidate, classFile)) end
        end
    end
end

-- Who a roll belongs to: you, or someone by name and class.
local function Roller(info)
    local me = info.isSelf
    if not IsSecret(me) and me == true then return P:MyLabel() end
    return P:LabelForName(info.playerName, info.playerClass)
end

-- A row of the loot roll history: the winner, or who's winning so far.
local function FixLootRow(row, drop)
    if not P:IsOn("loot") or type(row) ~= "table" then return end
    drop = type(drop) == "table" and drop or Child(row, "dropInfo")
    if not drop or drop.allPassed == true then return end
    if type(drop.winner) == "table" then
        Put("loot", Child(Child(row, "WinningRollInfo"), "WinningRoll"), ClassText(drop.winner.playerClass, Roller(drop.winner)))
    elseif type(drop.currentLeader) == "table" and drop.isTied ~= true then
        local text = Fill(Global("LOOT_HISTORY_CURRENT_WINNER", "%s (%d)"), (Roller(drop.currentLeader)), drop.currentLeader.roll)
        Put("loot", Child(Child(row, "PendingRollInfo"), "CurrentWinnerText"), text)
    end
end

-- A line of the roll history's hover: who rolled (its own small frame laid
-- into the tooltip, not one of the tooltip's lines), off-spec kept.
local function FixRollLine(line, rollInfo)
    if not P:IsOn("loot") or type(line) ~= "table" or type(rollInfo) ~= "table" then return end
    local text = ClassText(rollInfo.playerClass, Roller(rollInfo))
    local states = type(Enum) == "table" and Enum.EncounterLootDropRollState
    local offSpec = type(states) == "table" and states.NeedOffSpec
    local state = rollInfo.state
    if text ~= "" and offSpec ~= nil and not IsSecret(state) and state == offSpec then
        text = Fill(Global("LOOT_HISTORY_OFF_SPEC_FMT", "%s (Off-spec)"), text) or text
    end
    Put("loot", Child(line, "PlayerName"), text)
end

-- The boss kill banner's list of who got what.
local function FixBanner(lootFrame, data)
    if not P:IsOn("loot") or type(lootFrame) ~= "table" or type(data) ~= "table" then return end
    Put("loot", Child(lootFrame, "PlayerName"), P:LabelForName(data.playerName, data.className))
end

local function RefreshLoot()
    local master = _G.MasterLooterFrame
    if type(master) == "table" and master:IsShown() then FixMasterLoot() end
    local history = _G.GroupLootHistoryFrame
    if type(history) == "table" and history:IsShown() then
        ForFrames(Child(history, "ScrollBox"), FixLootRow)
        local anim = Child(history, "PerfectAnimFrame")
        if anim and anim:IsShown() then FixLootRow(anim) end
    end
end

-- Damage meter -------------------------------------------------------------------------------
-- Rows keep their source's class, whether it's you and its place, which
-- the game never makes secret; the name itself can be one in combat, so
-- it's never read.

local function MeterName(entry)
    return Child(Child(entry, "StatusBar"), "Name")
end

local function FixMeterSource(entry)
    if not P:IsOn("meter") or type(entry) ~= "table" then return end
    local classFile = Text(entry.classFilename)
    if not classFile then return end -- a creature
    local me = entry.isLocalPlayer
    local label
    if not IsSecret(me) and me == true then
        label = P:MyLabel()
    else
        label = P:StyleLabel(classFile)
    end
    local death, index = Number(entry.deathRecapID), Number(entry.index)
    local text = label
    if not (death and death ~= 0) and index then text = Fill(Global("DAMAGE_METER_SOURCE_NAME", "%d. %s"), index, label) or label end
    Put("meter", MeterName(entry), text)
end

-- A session window sets up every row it shows (your pinned row too) through
-- its InitEntry, so rows made before the hook are caught as well.
local function OnMeterEntry(_, entry)
    FixMeterSource(entry)
end

-- The breakdown's rows that name someone (damage taken from a player).
-- In combat the spell is a secret too, so the row shows the label alone.
local function FixMeterSpell(entry)
    if not P:IsOn("meter") or type(entry) ~= "table" then return end
    local classFile, spellID = Text(entry.unitClassFilename), entry.spellID
    if not classFile or (not IsSecret(spellID) and spellID == nil) then return end
    local creature, unitName = entry.creatureName, entry.unitName
    if IsSecret(creature) or Text(creature) then return end -- a pet's own line
    if not (IsSecret(unitName) or Text(unitName)) then return end
    local label = ClassText(classFile, P:LabelForName(unitName, classFile))
    local text = label
    if not IsSecret(spellID) and type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        local ok, spell = pcall(C_Spell.GetSpellName, spellID)
        if ok and Text(spell) then text = Fill(Global("DAMAGE_METER_SPELL_ENTRY_UNIT", "%s (%s)"), spell, label) or label end
    end
    Put("meter", MeterName(entry), text)
end

local function RefreshMeter()
    for i = 1, METER_WINDOWS do
        local window = _G["DamageMeterSessionWindow" .. i]
        if type(window) == "table" then
            ForFrames(Ask(window, "GetScrollBox"), FixMeterSource)
            local entry = Ask(window, "GetLocalPlayerEntry")
            if type(entry) == "table" and entry:IsShown() then FixMeterSource(entry) end
            ForFrames(Ask(Ask(window, "GetSourceWindow"), "GetScrollBox"), FixMeterSpell)
        end
    end
end

-- Professions --------------------------------------------------------------------------------

-- "Tailoring [name]" when the window shows someone's linked profession.
local function FixProfessionTitle(frame, skillLine)
    if not P:IsOn("professions") or type(frame) ~= "table" then return end
    local trade = C_TradeSkillUI
    if type(trade) ~= "table" or type(trade.IsTradeSkillLinked) ~= "function" then return end
    local book = Child(frame, "BookPage")
    if book and book:IsShown() then return end
    local okGuild, guild = pcall(trade.IsTradeSkillGuild)
    if okGuild and not IsSecret(guild) and guild then return end
    local ok, linked, name = pcall(trade.IsTradeSkillLinked)
    if not ok or IsSecret(linked) or not linked or not (IsSecret(name) or Text(name)) then return end
    skillLine = Text(skillLine)
    if not skillLine then
        local info = Child(frame, "professionInfo")
        skillLine = info and (Text(info.professionName) or Text(info.parentProfessionName))
    end
    local title = skillLine and Fill(Global("TRADE_SKILL_TITLE", "%s"), skillLine)
    if not title then return end
    local label = P:LabelForName(name)
    if label ~= "" then title = title .. " " .. (Text(_G.HIGHLIGHT_FONT_COLOR_CODE) or "") .. "[" .. label .. "]|r" end
    Put("professions", Ask(frame, "GetTitleText"), title)
end

-- A row of the guild crafters list for a recipe.
local function FixCrafter(button, data)
    if not P:IsOn("professions") or type(button) ~= "table" then return end
    data = type(data) == "table" and data or Ask(button, "GetElementData")
    if type(data) ~= "table" then return end
    Put("professions", Child(button, "Text"), (P:LabelForName(data.displayName, data.classFileName)))
end

local function RefreshProfessions()
    local frame = _G.ProfessionsFrame
    if type(frame) ~= "table" or not frame:IsShown() then return end
    FixProfessionTitle(frame)
    local guild = Child(Child(frame, "CraftingPage"), "GuildFrame")
    ForFrames(Child(Child(guild, "Container"), "ScrollBox"), FixCrafter)
end

-- Battleground scoreboard (experimental) -----------------------------------------------------
-- Names there are never secret; whether a row is yours is told by name,
-- never by comparing GUIDs.

local function FixScoreCell(cell, rowData)
    if not P:IsOn("scoreboard") or type(cell) ~= "table" then return end
    rowData = type(rowData) == "table" and rowData or Child(cell, "rowData")
    if not rowData then return end
    local label
    if P:IsMyName(rowData.name) then
        label = P:MyLabel()
    else
        label = P:StyleLabel(Text(rowData.classToken))
    end
    Put("scoreboard", Child(cell, "text"), label)
end

-- The name cells showing now: those whose Populate is the (hooked) name
-- column's.
local function RefreshScoreboard()
    local mixin = _G.PVPCellNameMixin
    if type(mixin) ~= "table" then return end
    for _, name in ipairs({ "PVPMatchScoreboard", "PVPMatchResults" }) do
        local board = _G[name]
        if type(board) == "table" and board:IsShown() then
            -- The scoreboard keeps its list at ScrollBox, the results page at scrollBox.
            ForFrames(Child(board, "ScrollBox") or Child(board, "scrollBox"), function(row)
                for _, cell in ipairs(Child(row, "cells") or {}) do
                    if type(cell) == "table" and rawget(cell, "Populate") == mixin.Populate then FixScoreCell(cell) end
                end
            end)
        end
    end
end

-- Hooks on Blizzard's mixins ---------------------------------------------------------------------
-- These go on as soon as each Blizzard addon is there, not in Setup: a frame
-- copies its mixin's methods when it's made, so a frame made before the
-- hook would never call it. While private mode is off each returns at once.
-- Frames that already exist (the loot history's roll animation, the meter's
-- session windows) are hooked one by one in Setup.

local function HookOlderRows()
    HookOlder(Child(_G.GroupLootHistoryFrame, "PerfectAnimFrame"), "LootHistoryElementMixin", "Init", FixLootRow)
    for i = 1, METER_WINDOWS do
        HookOlder(_G["DamageMeterSessionWindow" .. i], "DamageMeterSessionWindowMixin", "InitEntry", OnMeterEntry)
    end
end

HookMixin("LootHistoryElementMixin", "Init", FixLootRow) -- Blizzard_FrameXML, there before any addon
-- Its pool is made at load but its lines only when a roll is first hovered.
HookMixin("LootHistoryRollTooltipLineMixin", "Init", FixRollLine)
P:OnAddOnLoaded("Blizzard_DamageMeter", function()
    HookMixin("DamageMeterSessionWindowMixin", "InitEntry", OnMeterEntry)
    HookMixin("DamageMeterSpellEntryMixin", "Init", FixMeterSpell)
    if setUp then HookOlderRows() end
end, M)
P:OnAddOnLoaded("Blizzard_Professions", function() HookMixin("ProfessionsGuildCrafterButtonMixin", "Init", FixCrafter) end, M)
P:OnAddOnLoaded("Blizzard_PVPMatch", function() HookMixin("PVPCellNameMixin", "Populate", FixScoreCell) end, M)

-- Right-click menus: Menu.ModifyMenu callbacks, added once at load (like the
-- tooltip post-calls: never lazily). Each returns at once while off.
local menusAdded = false
local function AddMenus()
    if menusAdded or type(Menu) ~= "table" or type(Menu.ModifyMenu) ~= "function" then return end
    menusAdded = true
    local onMenu = P:Guard(M, OnMenu)
    for _, which in ipairs(MENUS) do pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, onMenu) end
end
AddMenus()

-- The module ---------------------------------------------------------------------------------

-- Each surface on its own guard, so one failing never stops the rest.
local REFRESH = {}
for name, fn in pairs({
    popups = RefreshPopups,
    readyCheck = FixReadyCheck,
    trade = function()
        local frame = _G.TradeFrame
        if type(frame) == "table" and frame:IsShown() then FixTrade() end
    end,
    loot = RefreshLoot,
    meter = RefreshMeter,
    professions = RefreshProfessions,
    scoreboard = RefreshScoreboard,
}) do REFRESH[name] = P:Guard(M, fn) end
local ORDER = { "popups", "readyCheck", "trade", "loot", "meter", "professions", "scoreboard" }

-- Everything else waits for private mode's first turn on.
function M:Setup()
    setUp = true
    HookOlderRows()
    for i = 1, POPUP_FRAMES do Hook(_G["StaticPopup" .. i], "Init", FixPopup) end
    Hook(nil, "StaticPopup_OnUpdate", FixPopup)
    Hook(nil, "LFGInvitePopup_Update", FixRoleInvite)
    Hook(nil, "PetitionFrame_Update", FixPetition)
    -- Its OnEvent is set in its XML, so a hook on the global would never run.
    local guild = _G.GuildInviteFrame
    if type(guild) == "table" then
        guild:HookScript("OnEvent", P:Guard(M, function(_, event)
            if event == "GUILD_INVITE_REQUEST" then FixGuildInvite() end
        end))
    end
    Hook(nil, "ShowReadyCheck", FixReadyCheck)
    AddMenus() -- only if Menu wasn't there at load
    Hook(nil, "TradeFrame_Update", FixTrade)
    Hook(nil, "MasterLooterFrame_UpdatePlayers", FixMasterLoot)
    Hook(nil, "BossBanner_ConfigureLootFrame", FixBanner)
    P:OnAddOnLoaded("Blizzard_Professions", function() Hook(_G.ProfessionsFrame, "SetTitle", FixProfessionTitle) end, M)
end

-- On: everything already showing is swapped. A setting turned on, or a new
-- name style, swaps what's showing again. Off: the core puts all of it back
-- (every change went through P:SwapText or P:HideRegion; menus are drawn
-- fresh each time they open).
function M:Apply(on, key)
    if not on then return end
    if key then
        if REFRESH[key] then
            if P:IsOn(key) then REFRESH[key]() end
            return
        end
        if not P.NAME_KEYS[key] then return end
    end
    for _, name in ipairs(ORDER) do
        if P:IsOn(name) then REFRESH[name]() end
    end
end
