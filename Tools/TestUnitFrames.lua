-- UnitFrames against a mock game (Tools/Harness.lua): the player, pet,
-- target, target of target, focus and party frames (UnitFrame_Update and each
-- name's SetText), raid-style party and raid frames and nameplates
-- (CompactUnitFrame_UpdateName), the Raid tab's group buttons, pulled-out
-- groups and the Social view's list, the character, inspect and inspect
-- talents titles, and the name CVars. Checked: nothing hooked or touched
-- while off, every surface swapped at once and kept through the game's own
-- updates (and another addon's rewrites), NPCs and locked plates left alone,
-- secrets never read, each tick putting back its own surface, name styles
-- and your typed name, combat, a /reload, screenshots, and everything back,
-- colours included, when private mode turns off.
-- Run with fengari: Tools/TestUnitFrames.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local P, F, M

local function Colour(region)
    local c = S[region].colour or { 1, 1, 1, 1 }
    return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3])
end
local GOLD = { 1, .82, 0, 1 }
local GOLDEN, DRUID, WARRIOR, MAGE = "1.00 0.82 0.00", "1.00 0.49 0.04", "0.78 0.61 0.43", "0.25 0.78 0.92"
local GREY, ACCENT = "0.78 0.78 0.78", "0.69 0.49 0.94"

-- People ------------------------------------------------------------------------------------

local function Copy(t, extra)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end
local BRANNOC = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true,
    guid = "Player-1-0002" }
local MERRIN = { name = "Merrin", surname = "Lightfoot", class = "Priest", classFile = "PRIEST", player = true,
    guid = "Player-1-0003" }
local KAELIS = { name = "Kaelis", surname = "Dawnbrook", class = "Mage", classFile = "MAGE", player = true,
    guid = "Player-1-0004" }
local HOGGER, KOBOLD = { name = "Hogger", guid = "Creature-1" }, { name = "Kobold Miner", guid = "Creature-2" }
local GRIMFANG, SHADOWPAW = { name = "Grimfang", pet = true, guid = "Pet-1" }, { name = "Shadowpaw", pet = true, guid = "Pet-2" }

local function SetUnits()
    local u = H.units
    u.target, u.targettarget, u.focus = BRANNOC, Copy(H.PLAYER), HOGGER
    u.pet, u.party1, u.partypet1, u.party2 = GRIMFANG, MERRIN, SHADOWPAW, KAELIS
    u.raid1, u.raid2, u.raid3, u.raidpet2 = Copy(H.PLAYER), MERRIN, BRANNOC, SHADOWPAW
    u.raid2target, u.raid2targettarget = BRANNOC, HOGGER
    u.nameplate1, u.nameplate2, u.nameplate3, u.nameplate4 = BRANNOC, KOBOLD, SHADOWPAW, KAELIS
end

-- Blizzard's side ----------------------------------------------------------------------------------

local function Unit(name, unit, parent, colour)
    local frame, text = H.UnitFrame(name, unit, parent)
    if colour then S[text].colour = { colour[1], colour[2], colour[3], colour[4] } end
    return frame, text
end

-- A window with a title, as TitledPanelMixin gives one.
local function Titled(name, title, fields)
    local frame = H.BlizzardFrame("Frame", name, UIParent, fields)
    local text = H.BlizzardText(nil, frame, title)
    rawset(frame, "GetTitleText", function() return text end)
    return frame, text
end

local function UnitFrames(f)
    f.player, f.playerName = Unit("PlayerFrame", "player", nil, GOLD)
    f.pet, f.petName = Unit("PetFrame", "pet", nil, GOLD)
    f.target, f.targetName = Unit("TargetFrame", "target", nil, GOLD)
    f.tot, f.totName = Unit("TargetFrameToT", "targettarget", f.target)
    f.focus, f.focusName = Unit("FocusFrame", "focus", nil, GOLD)
    f.focusToT, f.focusToTName = Unit("FocusFrameToT", "focustarget", f.focus)
    -- Party frames come from a pool: PartyFrame.MemberFrame1 and its PetFrame,
    -- and a second the pool hands out later.
    f.partyFrame = H.BlizzardFrame("Frame", "PartyFrame", UIParent)
    f.party1, f.party1Name = Unit(nil, "party1", f.partyFrame, GOLD)
    f.party1Pet, f.party1PetName = Unit(nil, "partypet1", f.party1)
    rawset(f.partyFrame, "MemberFrame1", f.party1)
    rawset(f.party1, "PetFrame", f.party1Pet)
    f.party2, f.party2Name = Unit(nil, "party2", f.partyFrame)
end

local function CompactFrames(f)
    f.compactParty = H.BlizzardFrame("Frame", "CompactPartyFrame", UIParent)
    f.cMe, f.cMeName = Unit("CompactPartyFrameMember1", "player", f.compactParty)
    f.cMerrin, f.cMerrinName = Unit("CompactPartyFrameMember2", "party1", f.compactParty)
    f.cPet, f.cPetName = Unit("CompactPartyFramePet1", "partypet1", f.compactParty)
    rawset(f.compactParty, "memberUnitFrames", { f.cMe, f.cMerrin })
    rawset(f.compactParty, "petUnitFrames", { f.cPet })
    f.cRaid, f.cRaidName = Unit("CompactRaidFrame1", "raid3")
    f.cGroup, f.cGroupName = Unit("CompactRaidGroup1Member1", "raid2")
    f.plates = {}
    for i = 1, 4 do
        local frame, text = Unit(nil, "nameplate" .. i)
        f.plates[i] = { frame = frame, name = text,
            base = H.BlizzardFrame("Frame", "NamePlate" .. i, UIParent, { UnitFrame = frame }) }
    end
    -- One the game locks (forbidden): never touched.
    f.locked, f.lockedName = Unit(nil, "nameplate4")
    S[f.locked].forbidden = true
    _G.C_NamePlate = { GetNamePlates = function()
        return { f.plates[1].base, f.plates[2].base, f.plates[3].base, f.plates[4].base }
    end }
end

-- The Social view's raid list (made at load) and the character window.
local function Windows(f)
    local social = H.BlizzardFrame("Frame", "SocialUIFrame", UIParent)
    f.raidList = H.BlizzardFrame("Frame", nil, social)
    local row = H.Protect(H.BlizzardFrame("Button", nil, f.raidList, { unit = "raid3" }))
    f.rowName = H.BlizzardText(nil, row, "")
    rawset(row, "CharacterName", f.rowName)
    rawset(f.raidList, "players", { row })
    rawset(f.raidList, "UpdateContents", function(self)
        for _, r in ipairs(self.players) do r.CharacterName:SetText(GetUnitName(r.unit, true)) end
    end)
    rawset(social, "RaidFrame", f.raidList)
    H.addOns.Blizzard_SocialUI = true
    f.char, f.charTitle = Titled("CharacterFrame", "Zriel Gustbellow", { activeSubframe = "PaperDollFrame" })
    _G.characterFrameDisplayInfo = { Default = {}, ReputationFrame = {}, SkillsFrame = {} }
end

local function BlizzardCode()
    _G.UnitFrame_Update = function(frame)
        local text = GetUnitName(frame.unit, true)
        if text then frame.name:SetText(text) end
    end
    _G.CompactUnitFrame_UpdateName = function(frame)
        if not UnitExists(frame.unit) then
            frame.name:Hide()
            return
        end
        frame.name:Show()
        frame.name:SetText(GetUnitName(frame.unit, true))
        frame.name:SetVertexColor(1, 1, 1)
    end
end

local function Update(frame) H.Blizzard(function() UnitFrame_Update(frame) end) end
local function UpdateCompact(frame) H.Blizzard(function() CompactUnitFrame_UpdateName(frame) end) end
local function DrawAll()
    for _, frame in ipairs({ F.player, F.pet, F.target, F.tot, F.focus, F.focusToT, F.party1, F.party1Pet }) do Update(frame) end
    for _, frame in ipairs({ F.cMe, F.cMerrin, F.cPet, F.cRaid, F.cGroup, F.locked }) do UpdateCompact(frame) end
    for _, plate in ipairs(F.plates) do UpdateCompact(plate.frame) end
end

local function Game(saved, opts)
    H.Environment()
    SetUnits()
    F = {}
    UnitFrames(F)
    CompactFrames(F)
    Windows(F)
    BlizzardCode()
    P = H.Load(saved, opts)
    M = P:Module("UnitFrames")
    return P
end

local function Texts(...)
    local list = {}
    for i = 1, select("#", ...) do list[#list + 1] = tostring(H.Text((select(i, ...)))) end
    return table.concat(list, ", ")
end
local function Plates() return Texts(F.plates[1].name, F.plates[2].name, F.plates[3].name, F.plates[4].name) end
local function Hooks(t, key)
    local n = 0
    for _, hook in ipairs(H.hooks) do
        if hook.t == t and hook.key == key then n = n + 1 end
    end
    return n
end
local DB = function() return ForeverEnhancedPrivacyDB end

-- Off: the game's names, nothing hooked or touched ----------------------------------------------

Game(nil)
local plainUpdate, plainCompact = UnitFrame_Update, CompactUnitFrame_UpdateName
DrawAll()
Equal(Texts(F.playerName, F.targetName, F.party1Name, F.cMeName), "Zriel Gustbellow, Brannoc Stonehelm, Merrin Lightfoot, "
    .. "Zriel Gustbellow", "off: the real names")
Equal(UnitFrame_Update, plainUpdate, "off: nothing hooked before private mode first turns on")
Equal(CompactUnitFrame_UpdateName, plainCompact, "nor the raid-style frames")
Equal(rawget(F.playerName, "SetText"), nil, "nor any name")
Equal(H.Writes() .. " " .. #H.cvarWrites, "0 0", "nothing of Blizzard's touched, no game setting changed")
Equal(H.Problems(), "", "nothing wrong at load")

-- On: every surface swapped at once ------------------------------------------------------------------

P:SetPrivate(true)
Equal(H.Text(F.playerName) .. " / " .. Colour(F.playerName), "Druid / " .. DRUID, "your name: your class, in its colour")
Equal(H.Text(F.petName) .. " / " .. Colour(F.petName), "Pet / " .. GREY, "your pet: Pet")
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Warrior / " .. WARRIOR, "your target")
Equal(H.Text(F.totName), "Druid", "its target is you")
Equal(H.Text(F.focusName) .. " / " .. Colour(F.focusName), "Hogger / " .. GOLDEN, "an NPC focus: left alone")
Equal(H.Text(F.focusToTName), "", "no focus target: nothing")
Equal(Texts(F.party1Name, F.party1PetName), "Priest, Pet", "a party member and their pet")
Equal(Texts(F.cMeName, F.cMerrinName, F.cPetName), "Druid, Priest, Pet", "raid-style party frames, you included")
Equal(S[F.cMerrinName].colour, nil, "raid-style names keep the game's own colours")
Equal(Texts(F.cRaidName, F.cGroupName), "Warrior, Priest", "raid frames")
Equal(Plates(), "Warrior, Kobold Miner, Pet, Mage", "plates: players and pets swapped, NPCs left")
Equal(H.Text(F.lockedName), "Kaelis Dawnbrook", "a plate the game locks: never touched")
Equal(H.Text(F.rowName), "Warrior", "the Social view's raid list")
Equal(H.Text(F.charTitle), "Druid", "the character window's title")
do
    local c = H.cvars
    Equal(c.UnitNameOwn .. c.UnitNameFriendlyPlayerName .. c.UnitNameEnemyPlayerName .. c.UnitNamePlayerGuild
        .. c.UnitNameFriendlyMinionName .. c.UnitNameEnemyMinionName .. c.UnitNameFocused,
        "0000000", "names, guilds, titles and pets' names above heads hidden")
    local forced = false
    for _, write in ipairs(H.cvarWrites) do
        if write:find("^nameplateForceShowUnitName=") then forced = true end
    end
    Equal(forced, false, "names forced onto plates left to the game: a CVar it caches is never written")
    Equal(DB().cvarBackup.UnitNameOwn .. DB().cvarBackup.UnitNamePlayerGuild, "11", "their originals kept")
end
Equal(H.Problems(), "", "nothing wrong turning on")

-- The game's own updates (and anyone else's) keep the labels -------------------------------------------

H.units.target = KAELIS
Update(F.target)
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Mage / " .. MAGE, "a new target: swapped as the game draws it")
H.units.target = HOGGER
Update(F.target)
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Hogger / " .. GOLDEN, "an NPC target: its own name and colour")
H.units.target = BRANNOC
Update(F.target)
Equal(H.Text(F.targetName), "Warrior", "a player again")
H.Blizzard(function() F.targetName:SetText("Brannoc") end)
Equal(H.Text(F.targetName), "Warrior", "another addon writing the real name back: swapped straight back")
-- (The newest write is what comes back later: here, your first name alone.)
H.Blizzard(function() F.playerName:SetText("Zriel") end)
Equal(H.Text(F.playerName), "Druid", "on the player frame too")
Update(F.party2)
Equal(H.Text(F.party2Name), "Mage", "a party frame the game hands out later: found by its first update")
H.Blizzard(function() F.party2Name:SetText("Kaelis") end)
Equal(H.Text(F.party2Name), "Mage", "and kept from then on")
H.units.raid3 = nil
UpdateCompact(F.cRaid)
Equal(H.Shown(F.cRaidName), false, "a raid-style name the game hides")
H.units.raid3 = BRANNOC
UpdateCompact(F.cRaid)
Equal(H.Text(F.cRaidName), "Warrior", "shown again: swapped")
H.units.nameplate1 = KOBOLD
UpdateCompact(F.plates[1].frame)
Equal(H.Text(F.plates[1].name), "Kobold Miner", "a plate reused for an NPC: its name")
H.units.nameplate1 = BRANNOC
UpdateCompact(F.plates[1].frame)
Equal(H.Text(F.plates[1].name), "Warrior", "and for a player again: swapped")
H.Blizzard(function()
    F.char.activeSubframe = "ReputationFrame"
    F.charTitle:SetText("Reputation")
end)
Equal(H.Text(F.charTitle), "Reputation", "the character window's other pages keep their titles")
H.Blizzard(function()
    F.char.activeSubframe = "PaperDollFrame"
    F.charTitle:SetText("Zriel Gustbellow")
end)
Equal(H.Text(F.charTitle), "Druid", "its own page: swapped")
H.Blizzard(function() F.raidList:UpdateContents() end)
Equal(H.Text(F.rowName), "Warrior", "the raid list drawn again: swapped")
Equal(Hooks(F.targetName, "SetText") .. Hooks(_G, "UnitFrame_Update") .. Hooks(_G, "CompactUnitFrame_UpdateName"), "111",
    "each hook made once")
Equal(H.Problems(), "", "nothing wrong with the game's updates")

-- Secrets: never read, compared or joined ------------------------------------------------------------

H.units.target = Copy(BRANNOC, { secretName = true, secretClass = true })
Update(F.target)
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Player / " .. GREY, "a secret name and class: Player")
H.units.targettarget = Copy(H.PLAYER, { secretCompare = true, secretClass = true })
Update(F.tot)
Equal(H.Text(F.totName), "Player", "the game won't say who the target's target is: Player")
H.units.party2 = Copy(KAELIS, { secretPlayer = true })
Update(F.party2)
Equal(H.Text(F.party2Name), "Player", "won't say if it's a player: Player, to be safe")
H.units.nameplate1 = Copy(BRANNOC, { secretName = true })
UpdateCompact(F.plates[1].frame)
Equal(H.Text(F.plates[1].name), "Warrior", "a secret name on a plate, class known")
Equal(H.Problems(), "", "no secret read")
H.units.target, H.units.targettarget, H.units.party2, H.units.nameplate1 = BRANNOC, Copy(H.PLAYER), KAELIS, BRANNOC
for _, frame in ipairs({ F.target, F.tot, F.party2 }) do Update(frame) end
UpdateCompact(F.plates[1].frame)

-- Each tick puts back its own surface, and only that -------------------------------------------------

P:Set("targetFrames", false)
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Brannoc Stonehelm / " .. GOLDEN, "unticked: the name and colour back")
Equal(H.Text(F.totName), "Zriel Gustbellow", "the target's target too")
Equal(H.Text(F.playerName) .. " " .. H.Text(F.party1Name), "Druid Priest", "the rest left")
H.units.target = KAELIS
Update(F.target)
Equal(H.Text(F.targetName), "Kaelis Dawnbrook", "the game's updates left alone")
P:Set("targetFrames", true)
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Mage / " .. MAGE, "ticked again: swapped at once")
H.units.target = BRANNOC
Update(F.target)

P:Set("petNames", false)
Equal(Texts(F.party1PetName, F.cPetName, F.plates[3].name), "Shadowpaw, Shadowpaw, Shadowpaw", "pets: back on frames and plates")
Equal(Texts(F.petName, F.plates[1].name, F.cMerrinName), "Pet, Warrior, Priest", "your pet's frame and players stay")
P:Set("petNames", true)
Equal(Texts(F.party1PetName, F.cPetName, F.plates[3].name), "Pet, Pet, Pet", "pets ticked again")
P:Set("nameplates", false)
Equal(Plates(), "Brannoc Stonehelm, Kobold Miner, Shadowpaw, Kaelis Dawnbrook", "nameplates unticked: all back")
Equal(H.Text(F.cRaidName), "Warrior", "raid frames stay")
P:Set("nameplates", true)
Equal(Plates(), "Warrior, Kobold Miner, Pet, Mage", "ticked again")
P:Set("groupFrames", false)
Equal(Texts(F.party1Name, F.party2Name, F.cMeName, F.cMerrinName, F.cRaidName, F.cGroupName, F.rowName),
    "Merrin Lightfoot, Kaelis Dawnbrook, Zriel Gustbellow, Merrin Lightfoot, Brannoc Stonehelm, Merrin Lightfoot, "
    .. "Brannoc Stonehelm", "group frames unticked: all back")
Equal(Colour(F.party1Name), GOLDEN, "with their colour")
Equal(H.Text(F.party1PetName), "Pet", "pets are their own tick")
P:Set("groupFrames", true)
Equal(Texts(F.party1Name, F.cMeName, F.rowName), "Priest, Druid, Warrior", "ticked again")
P:Set("playerFrame", false)
Equal(Texts(F.playerName, F.petName) .. " / " .. Colour(F.playerName) .. " / " .. Colour(F.petName),
    "Zriel, Grimfang / " .. GOLDEN .. " / " .. GOLDEN, "player frame unticked: you and your pet back, as last written")
Equal(H.Text(F.cMeName), "Druid", "your raid-style frame is the group frames'")
P:Set("playerFrame", true)
Equal(H.Text(F.playerName), "Druid", "ticked again")
P:Set("charTitles", false)
Equal(H.Text(F.charTitle), "Zriel Gustbellow", "titles unticked")
P:Set("charTitles", true)
Equal(H.Text(F.charTitle), "Druid", "ticked again")

-- Name styles and your typed name ---------------------------------------------------------------

P:Set("nameStyle", "player")
Equal(Texts(F.playerName, F.targetName, F.party1Name, F.cMerrinName, F.plates[1].name, F.charTitle, F.party1PetName),
    "Player, Player, Player, Player, Player, Player, Pet", "Player: every name")
Equal(Colour(F.targetName), GREY, "in grey")
P:Set("nameStyle", "hidden")
Equal(Texts(F.playerName, F.targetName, F.party1Name, F.cMerrinName, F.plates[1].name, F.party1PetName), ", , , , , ",
    "Hidden: blank")
P:Set("nameStyle", "class")
Equal(Texts(F.playerName, F.targetName, F.cMerrinName), "Druid, Warrior, Priest", "class names again")
P:Set("myName", "Shade")
Equal(H.Text(F.playerName) .. " / " .. Colour(F.playerName), "Shade / " .. GOLDEN,
    "your typed name, in the frame's own colour (the game's own, to begin with)")
Equal(Texts(F.cMeName, F.totName, F.charTitle, F.targetName), "Shade, Shade, Shade, Warrior", "everywhere you show")
-- Each name colour on every frame that shows you: the player frame, a target
-- or focus that's you, the target of target, raid-style frames and the title.
do
    H.units.target, H.units.focus = Copy(H.PLAYER), Copy(H.PLAYER)
    Update(F.target)
    Update(F.focus)
    local function Yours()
        return Colour(F.playerName) .. " / " .. Colour(F.targetName) .. " / " .. Colour(F.focusName) .. " / " .. Colour(F.totName)
    end
    Equal(Texts(F.playerName, F.targetName, F.focusName, F.totName), "Shade, Shade, Shade, Shade", "you on four frames")
    Equal(Yours(), GOLDEN .. " / " .. GOLDEN .. " / " .. GOLDEN .. " / 1.00 1.00 1.00", "the game's own: each frame's own colour")
    local WHITE = "1.00 1.00 1.00"
    for _, case in ipairs({ { "accent", ACCENT }, { "class", DRUID }, { "white", WHITE } }) do
        P:Set("myColour", case[1])
        Equal(Yours(), ("%s / %s / %s / %s"):format(case[2], case[2], case[2], case[2]), case[1] .. ": every frame that shows you, at once")
        Equal(Texts(F.playerName, F.targetName, F.cMeName, F.charTitle), "Shade, Shade, Shade, Shade", case[1] .. ": the same name")
        Equal(tostring(S[F.cMeName].colour) .. " " .. tostring(S[F.charTitle].colour), "nil nil",
            case[1] .. ": raid-style frames and titles keep the game's colours")
        Update(F.player)
        H.Blizzard(function() F.targetName:SetText("Zriel") end)
        Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Shade / " .. case[2], case[1] .. ": kept through the game's updates")
    end
    P:Set("myColour", "game")
    Equal(Yours(), GOLDEN .. " / " .. GOLDEN .. " / " .. GOLDEN .. " / 1.00 1.00 1.00",
        "back to the game's own: each frame's own colour again, at once")
    Update(F.player)
    Update(F.target)
    Equal(Colour(F.playerName) .. " / " .. Colour(F.targetName), GOLDEN .. " / " .. GOLDEN, "and after the game's updates")
    P:Set("myColour", "accent")
    P:Set("myName", "")
    Equal(H.Text(F.playerName) .. " / " .. Colour(F.playerName), "Druid / " .. DRUID, "no typed name: the colour choice changes nothing")
    P:Set("myColour", "game")
    Equal(Colour(F.playerName), DRUID, "whatever it is")
    P:Set("myName", "Shade")
    P:Set("myColour", "class")
    H.units.target, H.units.focus = BRANNOC, HOGGER
    Update(F.target)
    Update(F.focus)
    Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Warrior / " .. WARRIOR, "someone else targeted: their colour")
    Equal(H.Text(F.focusName) .. " / " .. Colour(F.focusName), "Hogger / " .. GOLDEN, "an NPC focus: its own")
    P:Set("myColour", "game")
    -- The newest write is what comes back at the end: your first name, as before.
    H.Blizzard(function() F.playerName:SetText("Zriel") end)
end
P:Set("myName", "")
Equal(H.Text(F.playerName) .. " / " .. Colour(F.playerName), "Druid / " .. DRUID, "cleared: the name style again")

-- Names above heads ------------------------------------------------------------------------------------

P:Set("otherHeads", false)
Equal(H.cvars.UnitNameFriendlyPlayerName .. H.cvars.UnitNamePlayerGuild .. H.cvars.UnitNameOwn, "110",
    "others' names unticked: back; yours still hidden")
P:Set("ownHead", false)
Equal(H.cvars.UnitNameOwn, "1", "yours unticked")
P:Set("otherHeads", true)
P:Set("ownHead", true)
Equal(H.cvars.UnitNameFriendlyPlayerName .. H.cvars.UnitNameOwn, "00", "ticked again")
H.Combat(true)
P:Set("otherHeads", false)
Equal(H.cvars.UnitNameFriendlyPlayerName, "0", "in combat: the game's settings wait")
H.units.target = KAELIS
Update(F.target)
Equal(H.Text(F.targetName), "Mage", "names still swap in combat")
H.Combat(false)
Equal(H.cvars.UnitNameFriendlyPlayerName, "1", "after the fight: back")
P:Set("otherHeads", true)
H.units.target = BRANNOC
Update(F.target)
Equal(H.Problems(), "", "nothing protected touched, no game setting changed in combat")

-- Blizzard's addons that load later: the Raid tab, inspect, inspect talents ----------------------------------

do
    for i = 1, 3 do
        local button = H.Protect(H.BlizzardFrame("Button", "RaidGroupButton" .. i, UIParent))
        F["raid" .. i] = H.BlizzardText("RaidGroupButton" .. i .. "Name", button, "")
    end
    _G.RaidGroupFrame_Update = function()
        for i = 1, 3 do _G["RaidGroupButton" .. i .. "Name"]:SetText(GetUnitName("raid" .. i, true)) end
    end
    local pull = H.BlizzardFrame("Button", "RaidPullout1", UIParent)
    local members = {}
    for i, unit in ipairs({ "raid2", "raidpet2" }) do
        local button = H.Protect(H.BlizzardFrame("Button", "RaidPullout1Button" .. i, pull, { unit = unit }))
        F["pull" .. i] = H.BlizzardText(nil, button, "")
        rawset(button, "nameLabel", F["pull" .. i])
        F["pull" .. i .. "Target"] = H.BlizzardText("RaidPullout1Button" .. i .. "TargetName", button, "")
        F["pull" .. i .. "TargetTarget"] = H.BlizzardText("RaidPullout1Button" .. i .. "TargetTargetName", button, "")
        members[i] = button
    end
    rawset(pull, "buttons", members)
    _G.NUM_RAID_PULLOUT_FRAMES = 1
    _G.RaidPullout_UpdateTarget = function(_, buttonName, unit, which)
        _G[buttonName .. which .. "Name"]:SetText(UnitName(unit) or "")
    end
    _G.RaidPullout_Update = function(frame)
        for _, button in ipairs(frame.buttons) do
            button.nameLabel:SetText((UnitName(button.unit)))
            RaidPullout_UpdateTarget(frame:GetName(), button:GetName(), button.unit .. "target", "Target")
            RaidPullout_UpdateTarget(frame:GetName(), button:GetName(), button.unit .. "targettarget", "TargetTarget")
        end
        return 1
    end
    H.LoadAddOn("Blizzard_RaidUI")
    H.Blizzard(function() RaidGroupFrame_Update() end)
    Equal(Texts(F.raid1, F.raid2, F.raid3), "Druid, Priest, Warrior", "the Raid tab's group buttons")
    P:Set("myName", "Shade")
    for _, choice in ipairs({ "accent", "class", "white", "game" }) do
        P:Set("myColour", choice)
        Equal(H.Text(F.raid1) .. " " .. tostring(S[F.raid1].colour), "Shade nil", choice .. ": you on the Raid tab, in the game's colour")
    end
    P:Set("myName", "")
    Equal(H.Text(F.raid1), "Druid", "the Raid tab: the name style again")
    Equal(H.Blizzard(function() return RaidPullout_Update(pull) end), 1, "the game's answer kept")
    Equal(Texts(F.pull1, F.pull1Target, F.pull1TargetTarget, F.pull2), "Priest, Warrior, Hogger, Pet",
        "a pulled-out group: members, their targets (NPCs left) and pets")
    H.units.raid2target = KAELIS
    H.Blizzard(function() RaidPullout_UpdateTarget("RaidPullout1", "RaidPullout1Button1", "raid2target", "Target") end)
    Equal(H.Text(F.pull1Target), "Mage", "a target line on its own timer")
    H.units.raid2target = BRANNOC
    H.Blizzard(function() RaidPullout_UpdateTarget("RaidPullout1", "RaidPullout1Button1", "raid2target", "Target") end)
    Equal(H.Text(F.pull1Target), "Warrior", "and again")

    F.inspect, F.inspectTitle = Titled("InspectFrame", "", { unit = "target" })
    H.LoadAddOn("Blizzard_InspectUI")
    H.Blizzard(function() F.inspectTitle:SetText(GetUnitName("target", true)) end)
    Equal(H.Text(F.inspectTitle), "Warrior", "the inspect window's title")
    H.units.target = MERRIN
    H.Blizzard(function() F.inspectTitle:SetText(GetUnitName("target", true)) end)
    Equal(H.Text(F.inspectTitle), "Priest", "someone else inspected")
    H.units.target = BRANNOC
    H.Blizzard(function() F.inspectTitle:SetText(GetUnitName("target", true)) end)

    F.spells, F.spellsTitle = Titled("PlayerSpellsFrame", "", { inspectUnit = "target" })
    rawset(F.spells, "GetInspectUnit", function(self) return self.inspectUnit end)
    _G.TALENTS_INSPECT_FORMAT, _G.TALENTS = "Talents - %s", "Talents"
    H.LoadAddOn("Blizzard_PlayerSpells")
    H.Blizzard(function() F.spellsTitle:SetText(TALENTS_INSPECT_FORMAT:format(UnitName("target"))) end)
    Equal(H.Text(F.spellsTitle), "Talents - Warrior", "the inspect talents title")
    H.Blizzard(function()
        F.spells.inspectUnit = nil
        F.spellsTitle:SetText("Spellbook")
    end)
    Equal(H.Text(F.spellsTitle), "Spellbook", "its own titles left")
    H.Blizzard(function()
        F.spells.inspectUnit = "target"
        F.spellsTitle:SetText("Talents - Brannoc")
    end)
    Equal(H.Problems(), "", "nothing wrong with the later addons")
end

-- Twice is the same as once ---------------------------------------------------------------------------

M:Apply(true)
M:Apply(true)
Equal(Texts(F.targetName, F.cMerrinName, F.raid2, F.inspectTitle), "Warrior, Priest, Priest, Warrior", "applied twice: the same")

-- Off: everything back, and the hooks do nothing ------------------------------------------------------------

P:SetPrivate(false)
Equal(Texts(F.playerName, F.petName, F.targetName, F.totName, F.focusName, F.party1Name, F.party1PetName, F.party2Name),
    "Zriel, Grimfang, Brannoc Stonehelm, Zriel Gustbellow, Hogger, Merrin Lightfoot, Shadowpaw, Kaelis Dawnbrook",
    "off: unit frames back")
Equal(Colour(F.playerName) .. " / " .. Colour(F.targetName) .. " / " .. Colour(F.petName), GOLDEN .. " / " .. GOLDEN .. " / "
    .. GOLDEN, "with their own colours")
Equal(Texts(F.cMeName, F.cMerrinName, F.cPetName, F.cRaidName, F.cGroupName), "Zriel Gustbellow, Merrin Lightfoot, Shadowpaw, "
    .. "Brannoc Stonehelm, Merrin Lightfoot", "raid-style frames back")
Equal(Plates(), "Brannoc Stonehelm, Kobold Miner, Shadowpaw, Kaelis Dawnbrook", "plates back")
Equal(Texts(F.raid1, F.raid2, F.raid3, F.pull1, F.pull1Target, F.pull2, F.rowName), "Zriel Gustbellow, Merrin Lightfoot, "
    .. "Brannoc Stonehelm, Merrin, Brannoc, Shadowpaw, Brannoc Stonehelm", "the Raid tab back")
Equal(Texts(F.charTitle, F.inspectTitle, F.spellsTitle), "Zriel Gustbellow, Brannoc Stonehelm, Talents - Brannoc",
    "titles back")
do
    local c = H.cvars
    Equal(c.UnitNameOwn .. c.UnitNameFriendlyPlayerName .. c.UnitNamePlayerGuild .. c.UnitNameFocused .. " "
        .. tostring(next(DB().cvarBackup)), "1111 nil", "names above heads back, nothing left saved")
end
H.ResetWrites()
DrawAll()
H.units.target = KAELIS
Update(F.target)
H.Blizzard(function()
    F.targetName:SetText("Kaelis")
    RaidGroupFrame_Update()
    F.raidList:UpdateContents()
    F.charTitle:SetText("Zriel Gustbellow")
end)
Equal(Texts(F.targetName, F.playerName, F.raid1, F.rowName, F.charTitle), "Kaelis, Zriel Gustbellow, Zriel Gustbellow, "
    .. "Brannoc Stonehelm, Zriel Gustbellow", "off: the game's names stay")
Equal(H.Writes(), 0, "off: the hooks touch nothing")
Equal(H.Problems(), "", "nothing wrong turning off")

-- Safe in a bare game (no frames at all) --------------------------------------------------------------------

H.Environment()
P = H.Load(nil)
P:SetPrivate(true)
P:Set("nameStyle", "player")
P:SetPrivate(false)
Equal(H.Problems(), "", "no frames: nothing wrong")

-- A /reload while private: swapped as you come back in --------------------------------------------------------

Game({ wasOn = true }, { beforeLogin = true })
DrawAll()
H.Fire("PLAYER_LOGIN")
H.Login(true)
Equal(P:Private(), true, "a /reload while on: still on")
Equal(Texts(F.playerName, F.targetName, F.cMerrinName, F.plates[1].name), "Druid, Warrior, Priest, Warrior",
    "frames drawn before it: swapped")
P:SetPrivate(false)
Equal(H.Text(F.targetName), "Brannoc Stonehelm", "and back")

-- Screenshots: swapped for the moment, then straight back ---------------------------------------------------------

Game({ mode = "shots" })
DrawAll()
H.Screenshot("start")
Equal(Texts(F.playerName, F.targetName, F.cMerrinName), "Druid, Warrior, Priest", "a screenshot: swapped")
H.Screenshot("done")
Equal(H.Text(F.targetName) .. " / " .. Colour(F.targetName), "Brannoc Stonehelm / " .. GOLDEN, "then straight back")
Equal(H.Problems(), "", "nothing wrong with screenshots")
True(H.checks > 100, "a full run")

io.stdout:write("TestUnitFrames: " .. H.checks .. " checks passed\n")
