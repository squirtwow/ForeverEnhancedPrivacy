-- World against a mock game (Tools/Harness.lua): your name in quest, gossip
-- and portrait text, boss emotes and raid warnings, player, pet, corpse,
-- minimap and item tooltips (your own guild line's made-up guild too), the
-- world map's group dots and its curtain, the
-- minimap zone text and its cover, coordinates, zone announcements, the
-- clock, gold and healer names. Checked: nothing while off, every surface
-- while on, each tick putting back only its own, new labels when the name
-- settings change, everything back when off, secrets, combat, and addons of
-- Blizzard's that load later.
-- Only the Names and World modules run here: the other modules have their own
-- tests. Blizzard's side is built in this file, as the game has it.
-- Run with fengari: Tools/TestWorld.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True

local B -- Blizzard's side of the current game
local P

-- Blizzard's side ----------------------------------------------------------------------------------

local function BuildQuests()
    B.quest = { desc = "Greetings, Zriel. The Light needs you.", objectives = "Bring Zriel Gustbellow's letter to Marshal Dughan.",
        reward = "Zriel, you've done well.", progress = "Have you found them yet, Zriel?", greeting = "Well met, Zriel Gustbellow!" }
    B.desc = H.BlizzardText("QuestInfoDescriptionText", UIParent, "")
    B.objectives = H.BlizzardText("QuestInfoObjectivesText", UIParent, "")
    B.reward = H.BlizzardText("QuestInfoRewardText", UIParent, "")
    _G.QuestInfo_Display = function()
        B.desc:SetText(B.quest.desc)
        B.objectives:SetText(B.quest.objectives)
        B.reward:SetText(B.quest.reward)
    end
    B.progressPanel = H.BlizzardFrame("Frame", "QuestFrameProgressPanel", UIParent)
    B.progress = H.BlizzardText("QuestProgressText", B.progressPanel, "")
    S[B.progressPanel].shown = false
    S[B.progressPanel].scripts.OnShow = function() B.progress:SetText(B.quest.progress) end
    B.greetingPanel = H.BlizzardFrame("Frame", "QuestFrameGreetingPanel", UIParent)
    B.greeting = H.BlizzardText("GreetingText", B.greetingPanel, "")
    S[B.greetingPanel].shown = false
    S[B.greetingPanel].scripts.OnShow = function() B.greeting:SetText(B.quest.greeting) end
    B.portrait = H.BlizzardText("QuestNPCModelText", UIParent, "")
    _G.QuestFrame_UpdatePortraitText = function(text) B.portrait:SetText(text or "") end
end

local function BuildGossip()
    _G.GossipGreetingTextMixin = { Setup = function(self, text) self.GreetingText:SetText(text) end }
    _G.GossipOptionButtonMixin = { Setup = function(self, info) self:GetFontString():SetText(info.name) end }
    B.rows = {}
    local box = H.BlizzardFrame("Frame", nil, UIParent, { GetFrames = function() return B.rows end,
        HasView = function() return B.rows ~= nil end })
    B.gossipBox = box
    local panel = H.BlizzardFrame("Frame", nil, UIParent, { ScrollBox = box })
    B.gossip = H.BlizzardFrame("Frame", "GossipFrame", UIParent, { GreetingPanel = panel })
end

-- The gossip window's rows, made as the game makes them (copying the mixins'
-- methods) and set up with these texts.
local function GossipRows(greetingText, optionText)
    local greeting = H.BlizzardFrame("Frame", nil, B.gossip)
    rawset(greeting, "GreetingText", H.BlizzardText(nil, greeting, ""))
    rawset(greeting, "Setup", GossipGreetingTextMixin.Setup)
    local option = H.BlizzardFrame("Button", nil, B.gossip)
    local label = H.BlizzardText(nil, option, "")
    rawset(option, "GetFontString", function() return label end)
    rawset(option, "Setup", GossipOptionButtonMixin.Setup)
    B.rows = { greeting, option }
    H.Blizzard(function()
        greeting:Setup(greetingText)
        option:Setup({ name = optionText })
    end)
    return greeting.GreetingText, label
end

local function BuildMinimap()
    B.zone = "Elwynn Forest"
    B.zoneButton = H.BlizzardFrame("Button", nil, UIParent)
    B.zoneText = H.BlizzardText("MinimapZoneText", B.zoneButton, "Elwynn Forest")
    _G.Minimap_Update = function()
        B.zoneText:SetText(B.zone)
        B.zoneText:SetTextColor(1, .82, 0)
    end
    B.zoneFrame = H.BlizzardFrame("Frame", "ZoneTextFrame", UIParent)
    B.popups = {}
    for _, name in ipairs({ "ZoneTextString", "SubZoneTextString", "PVPInfoTextString", "PVPArenaTextString" }) do
        B.popups[#B.popups + 1] = H.BlizzardText(name, B.zoneFrame, name)
    end
end

local function BuildCentre()
    B.pool = { active = {} }
    function B.pool:EnumerateActive() return pairs(self.active) end
    B.warning = H.BlizzardFrame("Frame", "RaidWarningFrame", UIParent, { fontStringPool = B.pool,
        AddMessage = function(self, text)
            local fontString = H.BlizzardText(nil, self, nil)
            fontString:SetText(text)
            B.pool.active[fontString] = true
            B.message = fontString
        end })
end

-- A map with one group dot, as Blizzard_SharedMapDataProviders has it.
local function NewMap(name)
    local pin = H.BlizzardFrame("Frame", nil, UIParent, {
        currentMouseOverUnits = {},
        IsMouseOverUnitExcluded = function(_, unit) return unit == "player" end,
        UpdateUnitTooltips = function(self, tooltip)
            local names = {}
            for unit in pairs(self.currentMouseOverUnits) do
                if not self:IsMouseOverUnitExcluded(unit) then names[#names + 1] = GetUnitName(unit) end
            end
            B.owner = self
            tooltip:GetLeftLine(1):SetText(table.concat(names, "\n"))
        end })
    local map = H.BlizzardFrame("Frame", name, UIParent, { EnumeratePinsByTemplate = function(_, template)
        local list, i = template == "GroupMembersPinTemplate" and { pin } or {}, 0
        return function()
            i = i + 1
            return list[i]
        end
    end })
    S[map].shown = false
    return map, pin
end

local function BuildMoney()
    B.money = 4123700
    _G.GetMoney = function() return B.money end
    _G.GetCursorMoney = function() return 0 end
    _G.GetPlayerTradeMoney = function() return 0 end
    B.bagMoney = H.BlizzardFrame("Frame", "ContainerFrame1MoneyFrame", UIParent, { moneyType = "PLAYER" })
    B.vendorMoney = H.BlizzardFrame("Frame", "MerchantMoneyFrame", UIParent, { moneyType = "PLAYER" })
    B.combinedMoney = H.BlizzardFrame("Frame", nil, UIParent, { moneyType = "PLAYER" })
    B.bags = H.BlizzardFrame("Frame", "ContainerFrameCombinedBags", UIParent, { MoneyFrame = B.combinedMoney })
    B.trainerMoney = H.BlizzardFrame("Frame", nil, UIParent, { moneyType = "PLAYER" })
    B.popupMoney = H.BlizzardFrame("Frame", nil, UIParent, { moneyType = "PLAYER" })
    B.price = H.BlizzardFrame("Frame", "SomePriceMoneyFrame", UIParent, { moneyType = "STATIC" })
    _G.MoneyFrame_Update = function(frame, money)
        if type(frame) == "string" then frame = _G[frame] end
        S[frame].money = money
    end
end

local function BuildUnits()
    H.units.target = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
        guid = "Player-1-0002" }
    H.units.mouseover = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
        guid = "Player-1-0002" }
    H.units.party1 = { name = "Kaelis", surname = "Dawnbrook", class = "Priest", classFile = "PRIEST", player = true,
        guid = "Player-1-0003" }
    H.units.pet = { name = "Wolfie", pet = true, guid = "Pet-1-0004" }
    H.units.npc = { name = "Marshal", surname = "Dughan", guid = "Creature-1-0005" }
    H.units.focus = { name = "Thessaly", surname = "Moonwhisper", player = true, secretClass = true, guid = "Player-1-0006" }
    H.guild = { { name = "Light Bringer", classFile = "PALADIN" } }
end

local function BuildStrings(english)
    _G.ITEM_CREATED_BY = english and "|cff00ff00<Made by %s>|r" or nil
    _G.CORPSE_TOOLTIP = english and "Corpse of %s" or nil
    _G.CORPSE = english and "Corpse" or nil
    _G.UNITNAME_TITLE_PET = english and "%s's Pet" or nil
end

-- A fresh game with Blizzard's side built, the addon loaded and logged in.
local function Game(saved, english)
    H.Environment()
    B = {}
    BuildQuests()
    BuildGossip()
    BuildMinimap()
    BuildCentre()
    B.map, B.pin = NewMap("WorldMapFrame")
    BuildMoney()
    BuildUnits()
    BuildStrings(english ~= false)
    B.itemTip = H.NewTooltip("ItemRefTooltip", 8)
    rawset(GameTooltip, "GetOwner", function() return B.owner end)
    P = H.Load(saved)
    for _, module in ipairs(P.modules) do
        if module.name ~= "Names" and module.name ~= "World" then module.broken = true end
    end
    return P
end

-- Helpers ------------------------------------------------------------------------------------------------

local TT, LT -- Enum.TooltipDataType, Enum.TooltipDataLineType

local function Tip(kind, lines, data, tooltip)
    data = data or {}
    data.lines = lines
    H.Tooltip(kind, tooltip or GameTooltip, data)
end

local function TipText(i, name)
    return H.Text(_G[(name or "GameTooltip") .. "TextLeft" .. i])
end

local function TipColour(i)
    local colour = S[_G["GameTooltipTextLeft" .. i]].colour
    return colour and (("%.2f %.2f %.2f"):format(colour[1], colour[2], colour[3])) or "none"
end

-- The frames of our own made inside one of Blizzard's.
local function Ours(parent)
    local found = {}
    for _, child in ipairs(S[parent].children) do
        if not S[child].blizzard then found[#found + 1] = child end
    end
    return found
end

local function Say(message)
    H.Blizzard(function() RaidWarningFrame:AddMessage(message) end)
    return B.message
end

local function Money(frame, money)
    H.Blizzard(MoneyFrame_Update, frame, money)
end

local function ShowPanel(panel)
    H.Blizzard(function()
        panel:Hide()
        panel:Show()
    end)
end

-- What the hooks hang on, by name: none of these is hooked before private
-- mode is first turned on.
local function HookedNames()
    local names = {}
    for _, hook in ipairs(H.hooks) do
        if hook.t == _G then names[#names + 1] = hook.key end
        if hook.t == GossipGreetingTextMixin then names[#names + 1] = "greeting:" .. hook.key end
        if hook.t == GossipOptionButtonMixin then names[#names + 1] = "option:" .. hook.key end
        if hook.t == RaidWarningFrame then names[#names + 1] = "warning:" .. hook.key end
        if hook.t == B.pin then names[#names + 1] = "pin:" .. hook.key end
    end
    table.sort(names)
    return table.concat(names, " ")
end

-- Off: nothing at all ---------------------------------------------------------------------------------------

Game(nil)
TT, LT = Enum.TooltipDataType, Enum.TooltipDataLineType
Equal(HookedNames(), "greeting:Setup option:Setup", "at load: only the two gossip mixins (rows copy them later)")
do
    local kinds = {}
    for _, kind in ipairs({ "Unit", "Corpse", "MinimapMouseover", "Item" }) do
        kinds[#kinds + 1] = kind .. "=" .. #(H.tooltipCalls.tooltipPost[TT[kind]] or {})
    end
    Equal(table.concat(kinds, " "), "Unit=1 Corpse=1 MinimapMouseover=1 Item=1",
        "the tooltip post-calls registered once, at load (never lazily)")
end
H.Blizzard(QuestInfo_Display)
H.Blizzard(Minimap_Update)
ShowPanel(B.progressPanel)
local greetingRow, optionRow = GossipRows("Hello there, Zriel Gustbellow.", "Tell me about Zriel's past.")
Equal(H.Text(greetingRow), "Hello there, Zriel Gustbellow.", "off: gossip left as the game has it")
Equal(H.Text(optionRow), "Tell me about Zriel's past.", "off: gossip options too")
Say("Ragnaros looks at Zriel Gustbellow!")
Money(B.bagMoney, B.money)
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" } })
Equal(TipText(1), "Brannoc Stonehelm", "off: tooltips as they are")
Equal(H.Writes(), 0, "off: nothing of Blizzard's touched")
Equal(#H.cvarWrites, 0, "off: no game setting changed")
Equal(H.Problems(), "", "nothing wrong while off")

-- Turned on, then off again: the hooks stay but do nothing while off.
P:SetPrivate(true)
P:SetPrivate(false)
Equal(HookedNames(), "Minimap_Update MoneyFrame_Update QuestFrame_UpdatePortraitText QuestInfo_Display greeting:Setup "
    .. "option:Setup warning:AddMessage", "set up once private mode first came on (the world map's dots never hooked)")
Equal(#(H.tooltipCalls.tooltipPost[TT.Unit] or {}), 1, "and the post-calls not added again")
Equal(H.Text(B.desc), "Greetings, Zriel. The Light needs you.", "off again: quest text back")
H.ResetWrites()
H.Blizzard(QuestInfo_Display)
H.Blizzard(Minimap_Update)
ShowPanel(B.progressPanel)
ShowPanel(B.greetingPanel)
H.Blizzard(QuestFrame_UpdatePortraitText, "Speak to Zriel.")
GossipRows("Hello there, Zriel Gustbellow.", "Tell me about Zriel's past.")
Say("Ragnaros looks at Zriel Gustbellow!")
Money(B.bagMoney, B.money)
Money("MerchantMoneyFrame", B.money)
B.pin.currentMouseOverUnits.party1 = true
H.Blizzard(function() B.pin:UpdateUnitTooltips(GameTooltip) end)
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" }, { type = LT.None, leftText = "<Iron Vanguard>" } })
Tip(TT.Item, { { type = LT.None, leftText = "|cff00ff00<Made by Zriel Gustbellow>|r" } }, nil, B.itemTip)
Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Brannoc Stonehelm" } })
Tip(TT.MinimapMouseover, { { type = LT.None, leftText = "Kaelis Dawnbrook" } })
Equal(H.Writes(), 0, "off after being on: every hook does nothing")
Equal(TipText(1) .. "|" .. TipText(1, "ItemRefTooltip"), "Kaelis Dawnbrook||cff00ff00<Made by Zriel Gustbellow>|r",
    "off: tooltips untouched")
Equal(#H.cvarWrites, 6, "the CVars changed once and put back once")
Equal(H.Problems(), "", "nothing wrong")

-- On: every surface ---------------------------------------------------------------------------------------------

Game(nil)
P:Set("gold", true)
P:Set("clock", true)
P:Set("worldMap", "hide")
Equal(H.Writes() .. " " .. #H.cvarWrites, "0 0", "ticking settings while off changes nothing")
-- What's on screen as private mode comes on.
H.Blizzard(QuestInfo_Display)
local greetingText, optionText = GossipRows("Hello there, Zriel Gustbellow.", "Tell me about Zriel's past.")
local shout = Say("Ragnaros looks at Zriel Gustbellow!")
Money(B.bagMoney, B.money)
H.Blizzard(function() B.map:Show() end)
P:SetPrivate(true)

Equal(H.Text(B.desc), "Greetings, adventurer. The Light needs you.", "quest text: your name, and a guildmate's name left alone")
Equal(H.Text(B.objectives), "Bring adventurer's letter to Marshal Dughan.", "your full name too")
Equal(H.Text(B.reward), "Adventurer, you've done well.", "a capital to start a sentence")
Equal(H.Text(greetingText), "Hello there, adventurer.", "gossip already open")
Equal(H.Text(optionText), "Tell me about adventurer's past.", "and its options")
local druid = P:Colourise("Druid", 1, .49, .04)
Equal(H.Text(shout), "Ragnaros looks at " .. druid .. "!", "a boss emote naming you, as chat would show it")
Equal(H.Text(B.zoneText), "", "the zone name above the minimap: blank")
Equal(#Ours(B.zoneButton) .. " " .. tostring(H.Shown(Ours(B.zoneButton)[1])), "1 true", "and its hover covered")
True(S[Ours(B.zoneButton)[1]].mouse, "the cover takes the mouse")
for _, popup in ipairs(B.popups) do Equal(H.Alpha(popup), 0, H.Text(popup) .. ": hidden") end
Equal(H.cvars.minimapShowPlayerCoords .. H.cvars.worldMapShowPlayerCoords .. H.cvars.worldMapShowCursorCoords, "000", "coordinates off")
Equal(ForeverEnhancedPrivacyDB.cvarBackup.minimapShowPlayerCoords, "1", "their originals kept")
Equal(H.cvars.timeMgrUseLocalTime, "0", "the clock on realm time")
Equal(H.cvars.floatingCombatTextFriendlyHealers_v2, "1", "healer names left to the game's own options (a CVar it caches)")
Equal(H.Alpha(B.bagMoney) .. H.Alpha(B.vendorMoney) .. H.Alpha(B.combinedMoney), "000", "gold hidden in bags and at vendors")
Equal(H.Alpha(B.price) .. H.Alpha(B.trainerMoney), "11", "prices left alone")
local curtain = Ours(B.map)[1]
True(curtain and H.Shown(curtain), "the world map covered")
True(S[curtain].mouse, "its curtain takes the mouse")
True(H.Find("The map is hidden while private mode is on.", true), "and says why")
Equal(H.Problems(), "", "nothing wrong turning on")

-- The game's next updates while on.
B.quest.desc = "Zriel! Zriel Gustbellow, at last. Zrielle sent you?"
H.Blizzard(QuestInfo_Display)
Equal(H.Text(B.desc), "Adventurer! Adventurer, at last. Zrielle sent you?", "whole words only")
ShowPanel(B.progressPanel)
Equal(H.Text(B.progress), "Have you found them yet, adventurer?", "the progress page")
ShowPanel(B.greetingPanel)
Equal(H.Text(B.greeting), "Well met, adventurer!", "the quest greeting page")
H.Blizzard(QuestFrame_UpdatePortraitText, "Speak to Zriel.")
Equal(H.Text(B.portrait), "Speak to adventurer.", "the portrait text")
B.zone = "Goldshire"
H.Blizzard(Minimap_Update)
Equal(H.Text(B.zoneText), "", "a new zone: still blank")
Money(B.trainerMoney, B.money)
Equal(H.Alpha(B.trainerMoney), 0, "gold in a window opened later: hidden")
Money(B.popupMoney, 5000)
Money(B.price, B.money)
Equal(H.Alpha(B.popupMoney) .. H.Alpha(B.price), "11", "a price stays, even one that matches your gold")
Money("MerchantMoneyFrame", B.money)
Equal(H.Alpha(B.vendorMoney), 0, "updated by name: still hidden")
local link = "|Hplayer:Zriel Gustbellow|h[Zriel Gustbellow]|h"
local priest = P:Colourise("Priest", 1, 1, 1)
Equal(H.Text(Say(link .. ": stack on Kaelis Dawnbrook")), "|Hplayer:Zriel Gustbellow|h[" .. druid .. "]|h: stack on " .. priest,
    "a raid warning: names swapped, the link's data kept")
Equal(H.Problems(), "", "nothing wrong on the game's updates")

-- Tooltips.
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Sergeant Brannoc Stonehelm", unitToken = "target" },
    { type = LT.None, leftText = "<Iron Vanguard>" }, { type = LT.UnitLevel, leftText = "Level 30 Human Warrior (Player)" } },
    { guid = "Player-1-0002" })
Equal(TipText(1) .. "|" .. TipText(2) .. "|" .. TipText(3), "Warrior||Level 30 Human Warrior (Player)",
    "a player: name and title swapped, guild blank, the rest left")
Equal(TipColour(1), "0.78 0.61 0.43", "in the class colour")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Zriel Gustbellow", unitToken = "player" }, { type = LT.None, leftText = "<Hearth>" } })
Equal(TipText(1) .. "|" .. TipText(2), "Druid|", "your own tooltip")
-- Your guild becomes: your own guild line shows the made-up guild, as the
-- game writes a guild line, in the line's own colour; nobody else's does.
do
    local function Mine(token, data, second)
        H.Blizzard(function() GameTooltipTextLeft2:SetTextColor(.25, 1, .25) end)
        Tip(TT.Unit, { { type = LT.UnitName, leftText = "Zriel Gustbellow", unitToken = token }, { type = LT.None, leftText = "<Hearth>" },
            second or { type = LT.UnitLevel, leftText = "Level 30 Night Elf Druid (Player)" } }, data)
        return TipText(1) .. "|" .. TipText(2) .. "|" .. TipText(3)
    end
    local LEVEL = "Level 30 Night Elf Druid (Player)"
    P:Set("myGuild", "Lancers of Elwynn")
    Equal(Mine("player"), "Druid|Lancers of Elwynn|" .. LEVEL, "your tooltip: the made-up guild in your guild's line")
    Equal(TipColour(2), "0.25 1.00 0.25", "in the colour the game drew the line in")
    H.units.raid1 = { name = "Zriel", surname = "Gustbellow", class = "Druid", classFile = "DRUID", player = true, guid = "Player-1-0001" }
    Equal(Mine("raid1"), "Druid|Lancers of Elwynn|" .. LEVEL, "you by any token (your raid frame)")
    H.units.raid1 = nil
    Equal(Mine(nil, { guid = "Player-1-0001" }), "Druid|Lancers of Elwynn|" .. LEVEL, "you by GUID")
    Mine(nil, { guid = H.SECRET })
    Equal(TipText(2), "", "a GUID the game won't say: the unit under the mouse decides (someone else here), never read")
    H.units.mouseover = H.units.player
    Mine(nil, { guid = H.SECRET })
    Equal(TipText(2), "Lancers of Elwynn", "and when that's you, your made-up guild")
    H.units.mouseover = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
        guid = "Player-1-0002" }
    Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" }, { type = LT.None, leftText = "<Iron Vanguard>" } })
    Equal(TipText(1) .. "|" .. TipText(2), "Warrior|", "someone else's guild line: still blank, never your made-up guild")
    Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm" }, { type = LT.None, leftText = "<Iron Vanguard>" } },
        { guid = "Player-1-0002" })
    Equal(TipText(2), "", "nor theirs by GUID")
    Tip(TT.Unit, { { type = LT.UnitName, leftText = "Wolfie", unitToken = "pet" }, { type = LT.None, leftText = "<Hearth>" } })
    Equal(TipText(2), "", "nor your pet's line")
    Equal(Mine("player", nil, { type = LT.None, leftText = "Second line" }), "Druid|Lancers of Elwynn|",
        "only the guild line itself: a second line under your name still blank")
    P:Set("myColour", "accent")
    Equal(Mine("player") .. " / " .. TipColour(2), "Druid|Lancers of Elwynn|" .. LEVEL .. " / 0.25 1.00 0.25",
        "the Name colour plays no part")
    P:Set("myColour", "game")
    P:Set("nameStyle", "hidden")
    Equal(Mine("player"), "|Lancers of Elwynn|" .. LEVEL, "the Hidden style: your name blank, the typed guild kept")
    P:Set("nameStyle", "class")
    H.guild = nil
    Equal(Mine("player"), "Druid||" .. LEVEL, "in no guild: the line under your name isn't a guild's, so it's only blanked")
    H.guild = { { name = "Light Bringer", classFile = "PALADIN" } }
    P:Set("guildName", false)
    Equal(Mine("player"), "Druid||" .. LEVEL, "Your guild's name unticked: blank, as before")
    P:Set("guildName", true)
    P:Set("tooltips", false)
    Equal(Mine("player"), "Zriel Gustbellow|<Hearth>|" .. LEVEL, "Player tooltips unticked: your tooltip as the game draws it")
    P:Set("tooltips", true)
    P:Set("myGuild", "")
    Equal(Mine("player"), "Druid||" .. LEVEL, "emptied: blank, as before")
    Equal(H.Problems(), "", "nothing wrong with your guild line")
end
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Marshal Dughan", unitToken = "npc" },
    { type = LT.None, leftText = "<Marshal of Goldshire>" } })
Equal(TipText(1) .. "|" .. TipText(2), "Marshal Dughan|<Marshal of Goldshire>", "an NPC: left alone")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Wolfie", unitToken = "pet" },
    { type = LT.UnitOwner, leftText = "Brannoc Stonehelm's Pet" } })
Equal(TipText(1) .. "|" .. TipText(2), "Pet|Warrior's Pet", "a pet and its owner (noted from hovering him)")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Kobold Vermin", unitToken = "npc" },
    { type = LT.QuestPlayer, leftText = "Kaelis Dawnbrook" }, { type = LT.QuestObjective, leftText = "Kobold Candles: 3/8" } })
Equal(TipText(2) .. "|" .. TipText(3), "Priest|Kobold Candles: 3/8", "your group's quest progress")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm" } }, { guid = "Player-1-0002" })
Equal(TipText(1), "Warrior", "no unit token: by GUID")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Thessaly Moonwhisper", unitToken = "focus" } })
Equal(TipText(1), "Player", "a class the game won't say: Player")
H.units.mouseover = nil
Tip(TT.Unit, { { type = LT.UnitName, leftText = H.SECRET, unitToken = H.SECRET }, { type = LT.None, leftText = H.SECRET } },
    { guid = H.SECRET })
True(H.IsSecret(TipText(1)), "a secret unit: left to the game")
Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Brannoc Stonehelm" } })
Equal(TipText(1), "Corpse of Warrior", "a corpse")
Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Zriel Gustbellow" } })
Equal(TipText(1), "Corpse of Druid", "your corpse")
Tip(TT.Corpse, { { type = LT.None, leftText = H.SECRET } })
Equal(TipText(1), "Corpse", "a secret corpse: just Corpse")
Tip(TT.MinimapMouseover, { { type = LT.None, leftText = "Kaelis Dawnbrook" }, { type = LT.None, leftText = "Peacebloom" } })
Equal(TipText(1) .. "|" .. TipText(2), "Priest|Peacebloom", "minimap dots")
Tip(TT.Item, { { type = LT.ItemName, leftText = "Runecloth Bag" }, { type = LT.None, leftText = "|cff00ff00<Made by Zriel Gustbellow>|r" } },
    nil, B.itemTip)
Equal(TipText(1, "ItemRefTooltip") .. "|" .. TipText(2, "ItemRefTooltip"), "Runecloth Bag||cff00ff00<Made by Druid>|r", "made by you")
Tip(TT.Item, { { type = LT.None, leftText = "<Made by Someone Else>" } })
Equal(TipText(1), "|cff00ff00<Made by Player>|r", "made by a stranger")
B.pin.currentMouseOverUnits.party1 = true
H.Blizzard(function() B.pin:UpdateUnitTooltips(GameTooltip) end)
Equal(TipText(1), "Kaelis Dawnbrook", "a group dot on the world map: left to the game (its hover is built outside the post-calls)")
Equal(H.Problems(), "", "nothing wrong with tooltips")

-- Each tick puts back only its own -------------------------------------------------------------------------------

P:Set("questText", false)
Equal(H.Text(B.desc) .. "|" .. H.Text(B.portrait), "Zriel! Zriel Gustbellow, at last. Zrielle sent you?|Speak to Zriel.", "quest text back")
Equal(H.Text(shout), "Ragnaros looks at Zriel Gustbellow!", "the boss emote back")
Equal(H.Text(greetingText), "Hello there, Zriel Gustbellow.", "gossip back")
Equal(H.Text(B.zoneText), "", "the zone still blank")
H.Blizzard(function() B.gossip:Hide() end)
P:Set("questText", true)
Equal(H.Text(B.desc), "Adventurer! Adventurer, at last. Zrielle sent you?", "ticked again: swapped at once")
Equal(H.Text(greetingText), "Hello there, Zriel Gustbellow.", "a closed gossip window left for its next opening")
H.Blizzard(function() B.gossip:Show() end)
local rows = B.rows
B.rows = nil
P:Set("questText", false)
P:Set("questText", true)
Equal(H.Text(greetingText), "Hello there, Zriel Gustbellow.", "a gossip list not built yet: nothing to do")
B.rows = rows
P:Set("questText", false)
P:Set("questText", true)
Equal(H.Text(greetingText), "Hello there, adventurer.", "open again: swapped")
P:Set("zoneText", false)
Equal(H.Text(B.zoneText) .. " " .. tostring(H.Shown(Ours(B.zoneButton)[1])), "Goldshire false", "zone text back, its cover gone")
P:Set("zoneText", true)
P:Set("zoneText", false)
P:Set("zoneText", true)
Equal(#Ours(B.zoneButton) .. H.Text(B.zoneText), "1", "one cover however often")
P:Set("coords", false)
Equal(H.cvars.minimapShowPlayerCoords .. H.cvars.worldMapShowCursorCoords .. " " .. tostring(ForeverEnhancedPrivacyDB.cvarBackup
    .minimapShowPlayerCoords), "11 nil", "coordinates back")
Equal(H.cvars.timeMgrUseLocalTime, "0", "the clock still on realm time")
P:Set("zonePopups", false)
Equal(H.Alpha(B.popups[1]) .. H.Alpha(B.popups[4]), "11", "zone announcements back")
P:Set("worldMap", "leave")
Equal(H.Shown(curtain), false, "Leave as is: the map uncovered")
P:Set("worldMap", "hide")
Equal(H.Shown(curtain) and #Ours(B.map), 1, "Keep closed again: the same curtain")
P:Set("gold", false)
Equal(H.Alpha(B.bagMoney) .. H.Alpha(B.vendorMoney) .. H.Alpha(B.trainerMoney), "111", "gold back")
P:Set("tooltips", false)
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" }, { type = LT.None, leftText = "<Iron Vanguard>" } })
Equal(TipText(1) .. "|" .. TipText(2), "Brannoc Stonehelm|<Iron Vanguard>", "tooltips unticked: as they are")
Tip(TT.Item, { { type = LT.None, leftText = "<Made by Zriel Gustbellow>" } })
Equal(TipText(1), "|cff00ff00<Made by Druid>|r", "Made by is its own tick")
P:Set("craftedBy", false)
Tip(TT.Item, { { type = LT.None, leftText = "<Made by Zriel Gustbellow>" } })
Equal(TipText(1), "<Made by Zriel Gustbellow>", "and unticked")
P:Set("tooltips", true)
P:Set("craftedBy", true)
P:Set("gold", true)
Equal(H.Alpha(B.bagMoney), 0, "gold ticked again: hidden at once")
Equal(H.Problems(), "", "nothing wrong ticking")

-- Your name and the name style -----------------------------------------------------------------------------------

P:Set("myName", "Bob")
Equal(H.Text(B.desc) .. "|" .. H.Text(B.reward), "Bob! Bob, at last. Zrielle sent you?|Bob, you've done well.", "your typed name, as typed")
Equal(H.Text(optionText), "Tell me about Bob's past.", "in gossip too")
Equal(H.Text(shout), "Ragnaros looks at Bob!", "the boss emote too, with no colour of ours (the game's own, to begin with)")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Zriel Gustbellow", unitToken = "player" } })
Equal(TipText(1), "Bob", "and your tooltip")
-- Each name colour: the boss emote and raid warnings (coloured text) and
-- your tooltip's name line (the game's own: the colour the game drew it in);
-- quest text, your corpse and "Made by" stay plain words.
for _, case in ipairs({ { "accent", P.ACCENT }, { "class", { 1, .49, .04 } }, { "white", { 1, 1, 1 } }, { "game" },
    { "class", { 1, .49, .04 } }, { "game" } }) do
    local choice, rgb = case[1], case[2]
    P:Set("myColour", choice)
    local bob = rgb and P:Colourise("Bob", rgb[1], rgb[2], rgb[3]) or "Bob"
    Equal(H.Text(shout), "Ragnaros looks at " .. bob .. "!", choice .. ": the boss emote, re-labelled at once")
    Equal(H.Text(Say(link .. ": heal me")), "|Hplayer:Zriel Gustbellow|h[" .. bob .. "]|h: heal me", choice .. ": a raid warning")
    -- The game draws your name line in its own colour first.
    H.Blizzard(function() GameTooltipTextLeft1:SetTextColor(.25, .5, 1) end)
    Tip(TT.Unit, { { type = LT.UnitName, leftText = "Zriel Gustbellow", unitToken = "player" } })
    Equal(TipText(1) .. " / " .. TipColour(1), "Bob / " .. (rgb and ("%.2f %.2f %.2f"):format(rgb[1], rgb[2], rgb[3]) or "0.25 0.50 1.00"),
        choice .. ": your tooltip's name line")
    Equal(H.Text(B.desc), "Bob! Bob, at last. Zrielle sent you?", choice .. ": quest text as typed, never coloured")
    Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Zriel Gustbellow" } })
    Equal(TipText(1), "Corpse of Bob", choice .. ": your corpse")
    Tip(TT.Item, { { type = LT.None, leftText = "<Made by Zriel Gustbellow>" } })
    Equal(TipText(1), "|cff00ff00<Made by Bob>|r", choice .. ": made by you")
end
P:Set("myName", "")
P:Set("nameStyle", "hidden")
Equal(H.Text(B.desc), "Adventurer! Adventurer, at last. Zrielle sent you?", "hidden names: NPCs still call you adventurer")
Equal(H.Text(shout), "Ragnaros looks at !", "the boss emote leaves the name out")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" } })
Equal(TipText(1), "", "a tooltip's name: blank")
Tip(TT.Item, { { type = LT.None, leftText = "<Made by Brannoc Stonehelm>" } })
Equal(TipText(1), "", "Made by: a blank line")
P:Set("nameStyle", "player")
Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Brannoc Stonehelm" } })
Equal(TipText(1), "Corpse of Player", "the Player style")
P:Set("nameStyle", "class")
Equal(H.Problems(), "", "nothing wrong re-labelling")

-- Blizzard's addons that load later ---------------------------------------------------------------------------------

Equal(H.cvars.timeMgrUseLocalTime, "0", "the clock: on realm time before its button exists")
local clock = H.BlizzardFrame("Button", "TimeManagerClockButton", UIParent)
H.LoadAddOn("Blizzard_TimeManager")
Equal(#Ours(clock) .. " " .. tostring(H.Shown(Ours(clock)[1])), "1 true", "its hover covered once it loads")
P:Set("clock", false)
Equal(H.cvars.timeMgrUseLocalTime .. " " .. tostring(H.Shown(Ours(clock)[1])), "1 false", "unticked: local time and no cover")
local zoneMap = NewMap("BattlefieldMapFrame")
H.Blizzard(function() zoneMap:Show() end)
H.LoadAddOn("Blizzard_BattlefieldMap")
True(Ours(zoneMap)[1] and H.Shown(Ours(zoneMap)[1]), "the zone map covered once it loads")
Equal(H.Problems(), "", "nothing wrong with later addons")

-- Secrets ------------------------------------------------------------------------------------------------------------

B.quest.desc = H.SECRET
H.Blizzard(QuestInfo_Display)
True(H.IsSecret(H.Text(B.desc)), "a secret quest text: left as it is")
GossipRows(H.SECRET, H.SECRET)
local secretShout = Say(H.SECRET)
True(H.IsSecret(H.Text(secretShout)), "a secret raid warning: left to the game")
Money(B.trainerMoney, H.SECRET)
Equal(H.Problems(), "", "no secret read, compared or joined")
B.quest.desc = "Greetings, Zriel. The Light needs you."
H.Blizzard(QuestInfo_Display)

-- Off: everything back ---------------------------------------------------------------------------------------------

P:SetPrivate(false)
Equal(H.Text(B.desc) .. "|" .. H.Text(B.progress) .. "|" .. H.Text(B.portrait), "Greetings, Zriel. The Light needs you.|"
    .. "Have you found them yet, Zriel?|Speak to Zriel.", "quest text back")
Equal(H.Text(greetingText) .. "|" .. H.Text(optionText), "Hello there, Zriel Gustbellow.|Tell me about Zriel's past.", "gossip back")
Equal(H.Text(shout), "Ragnaros looks at Zriel Gustbellow!", "the boss emote back")
Equal(H.Text(B.zoneText) .. " " .. tostring(H.Shown(Ours(B.zoneButton)[1])), "Goldshire false", "the zone back, uncovered")
Equal(H.cvars.minimapShowPlayerCoords .. H.cvars.timeMgrUseLocalTime .. H.cvars.floatingCombatTextFriendlyHealers_v2, "111",
    "every CVar back")
Equal(next(ForeverEnhancedPrivacyDB.cvarBackup), nil, "and nothing left saved")
Equal(H.Alpha(B.bagMoney) .. H.Alpha(B.popups[2]), "11", "gold and zone announcements back")
Equal(tostring(H.Shown(curtain)) .. " " .. tostring(H.Shown(Ours(zoneMap)[1])), "false false", "both maps uncovered")
Equal(H.Problems(), "", "nothing wrong turning off")

-- In combat: CVars wait for the fight to end; the rest is safe in it ----------------------------------------------

Game(nil)
H.Combat(true)
P:SetPrivate(true)
Equal(H.cvars.minimapShowPlayerCoords, "1", "in combat: coordinates wait")
Equal(H.Text(B.zoneText), "", "the zone name doesn't")
H.Combat(false)
Equal(H.cvars.minimapShowPlayerCoords, "0", "the fight over: coordinates off")
H.Combat(true)
P:SetPrivate(false)
Equal(H.cvars.minimapShowPlayerCoords .. H.Text(B.zoneText), "0Elwynn Forest", "off in combat: the zone at once, CVars wait")
H.Combat(false)
Equal(H.cvars.minimapShowPlayerCoords, "1", "then back")
Equal(H.Problems(), "", "no game setting changed in combat")

-- Without the game's own texts: our English copies ------------------------------------------------------------------

Game(nil, false)
P:SetPrivate(true)
Tip(TT.Item, { { type = LT.None, leftText = "<Made by Zriel Gustbellow>" } })
Equal(TipText(1), "<Made by Druid>", "Made by")
Tip(TT.Corpse, { { type = LT.None, leftText = "Corpse of Brannoc Stonehelm" } })
Equal(TipText(1), "Corpse of Player", "a corpse (a stranger's)")
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Wolfie", unitToken = "pet" }, { type = LT.UnitOwner, leftText = "Zriel Gustbellow's Pet" } })
Equal(TipText(2), "Druid's Pet", "your pet")
P:SetPrivate(false)
Equal(H.Problems(), "", "nothing wrong")

-- Tooltip lines are the game's to rebuild: nothing is put back into them ------------------------------------------

Game(nil)
P:SetPrivate(true)
Tip(TT.Unit, { { type = LT.UnitName, leftText = "Brannoc Stonehelm", unitToken = "target" }, { type = LT.None, leftText = "<Iron Wolves>" } })
Equal(TipText(1) .. "|" .. TipText(2), "Warrior|", "a player: the guild line blanked")
-- The next tooltip reuses the same lines: an item with a blank second line.
Tip(TT.Item, { { type = LT.ItemName, leftText = "Runecloth Bag" }, { type = LT.None, leftText = "" } })
P:SetPrivate(false)
Equal(TipText(1) .. "|" .. TipText(2), "Runecloth Bag|", "off: the item's lines left as the game drew them, no old guild name put back")
Equal(H.Problems(), "", "no tooltip line changed outside a post-call")

-- One surface failing never stops the others --------------------------------------------------------------------------

Game(nil)
rawset(B.gossipBox, "GetFrames", function() error("the gossip list broke") end)
B.zone = "Goldshire"
H.Blizzard(Minimap_Update)
P:SetPrivate(true)
Equal(H.Text(B.zoneText), "", "the zone name blanked although the gossip window failed first")
Equal(H.cvars.minimapShowPlayerCoords, "0", "coordinates off too")
for _, popup in ipairs(B.popups) do Equal(H.Alpha(popup), 0, H.Text(popup) .. ": hidden too") end
Equal(#H.printed, 1, "the error said once")
True(H.printed[1]:find("The World part hit an error", 1, true), "as the World part's")
H.Clear()
P:SetPrivate(false)
Equal(H.Text(B.zoneText) .. " " .. H.cvars.minimapShowPlayerCoords, "Goldshire 1", "and all put back")
Equal(H.Problems(), "", "nothing else wrong")

-- Always from login: on before any window opens --------------------------------------------------------------------

Game({ mode = "always" })
Equal(P:Private(), true, "on from login")
Equal(H.Text(B.zoneText), "", "the zone blank from the start")
H.Blizzard(QuestInfo_Display)
Equal(H.Text(B.desc), "Greetings, adventurer. The Light needs you.", "the first quest opened")
Equal(H.Problems(), "", "nothing wrong")

io.stdout:write("TestWorld: " .. H.checks .. " checks passed\n")
