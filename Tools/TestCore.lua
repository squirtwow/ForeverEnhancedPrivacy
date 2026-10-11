-- The core against a mock game (Tools/Harness.lua): loading and the saved
-- defaults, /privacy and the key binding, the three modes (key, screenshots,
-- always) and /reload, the modules (set up only when first needed, told in
-- order, one failing never stopping the rest, nothing at all while private
-- mode is off), the record of changes and putting them back, CVars saved and
-- restored (crash recovery and combat included), the eye, your own name and
-- made-up BattleTag (tidied, checked at load, re-labelling while private), and
-- every naming helper (NameFor, labels, names noted while private, swapping
-- names in text), secrets included.
-- Run with fengari: Tools/TestCore.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local P

-- Every module's calls, in order: "Name:Method(on,key)".
local log
local function Spy(names)
    log = {}
    for _, name in ipairs(names or { "Names", "UnitFrames", "Chat", "Social", "Windows", "World" }) do
        local module = P:Module(name)
        local setup, apply = module.Setup, module.Apply
        module.Setup = function(self, ...)
            log[#log + 1] = name .. ":Setup"
            if setup then return setup(self, ...) end
        end
        module.Apply = function(self, on, key)
            log[#log + 1] = name .. ":Apply(" .. tostring(on) .. (key and ("," .. key) or "") .. ")"
            return apply(self, on, key)
        end
    end
end
local function Log()
    local text = table.concat(log, " ")
    log = {}
    return text
end
local function Fresh(saved, opts)
    H.Environment()
    P = H.Load(saved, opts)
    return P
end
local DB = function() return ForeverEnhancedPrivacyDB end

-- Loading and the defaults ---------------------------------------------------------------------

Fresh(nil)
Equal(type(DB()), "table", "saved settings made")
Equal(P:Private(), false, "private mode starts off")
Equal(#P.KEYS, 42, "42 settings across the five list pages")
local OFF = { cleanOld = true, whispers = true, gold = true, clock = true, publicChannels = true }
for _, key in ipairs(P.KEYS) do
    local row = P.ROWS[key]
    if not row.options then Equal(P:Get(key), not OFF[key], key .. " starts as the mockup has it") end
    True(P:ModuleFor(key), key .. " has a module that owns it")
end
Equal(P:Get("instChat") .. " " .. P:Get("worldMap"), "names leave", "the two choices start on Hide names and Leave as is")
Equal(P:Get("mode") .. " " .. P:Get("nameStyle") .. " [" .. P:Get("myName") .. "] " .. P:Get("myColour") .. " " .. tostring(P:Get("eye")),
    "key class [] game true", "with its key, class names, no typed name in the game's own colour, the eye on")
Equal("[" .. P:Get("myTag") .. "] " .. tostring(P:MyTag()), "[] nil", "and no made-up BattleTag (off)")
do
    local names = {}
    for _, module in ipairs(P.modules) do names[#names + 1] = module.name end
    Equal(table.concat(names, " "), "Names UnitFrames Chat Social Windows World", "the modules, in the TOC's order")
    local owners = {}
    for _, row in pairs(P.ROWS) do owners[row.owner] = (owners[row.owner] or 0) + 1 end
    Equal(owners.UnitFrames .. " " .. owners.Chat .. " " .. owners.Social .. " " .. owners.Windows .. " " .. owners.World,
        "8 8 9 8 9", "each surface module owns its rows")
    Equal(tostring(P:Get("publicChannels")) .. " " .. P.ROWS.publicChannels.page .. " " .. P.ROWS.publicChannels.owner,
        "false chat Chat", "Leave public channels as they are: off to begin with, on the Chat page, Chat's")
    Equal(P.ROWS.combatText, nil, "healer names are left to the game's own options (a CVar it caches)")
end
Equal(table.concat(H.NewGlobals(), " "), "BINDING_HEADER_FEPRIVACY BINDING_NAME_FEPRIVACY_TOGGLE ForeverEnhancedPrivacyDB "
    .. "ForeverEnhancedPrivacyMinimapButton ForeverEnhancedPrivacy_Toggle SLASH_FEPRIVACY1",
    "only its own globals (the minimap button named, for minimap tidiers)")
Equal(H.category and H.category.title, "Forever Enhanced Privacy", "listed under Options > AddOns")
Equal(#H.cvarWrites, 0, "no game setting touched at load")
Equal(H.Writes(), 0, "nothing of Blizzard's touched at load")
Equal(ForeverEnhancedPrivacyFrame, nil, "no window until it's asked for")
Equal(H.Problems(), "", "nothing wrong at load")

-- Saved settings are checked as they load.
Fresh({ mode = "bogus", nameStyle = 3, instChat = "x", gold = "yes", worldMap = "hide", chatNames = false, myName = "  Mr|r   Shadow  ",
    myColour = "pink", cvarBackup = "nope", wasOn = "yes" })
Equal(P:Get("mode") .. " " .. P:Get("nameStyle") .. " " .. P:Get("instChat") .. " " .. tostring(P:Get("gold")) .. " " .. P:Get("myColour"),
    "key class names false game", "bad saved values go back to the defaults")
Equal(P:Get("worldMap") .. " " .. tostring(P:Get("chatNames")), "hide false", "good ones are kept")
Equal(P:Get("myName"), "Mrr Shadow", "a saved name is cleaned")
Equal(type(DB().cvarBackup) .. " " .. tostring(DB().wasOn), "table false", "and the CVar backup and the /reload flag repaired")
Fresh({ myColour = "white" })
Equal(P:Get("myColour"), "white", "a saved name colour is kept")
Equal(tostring(P:Set("myColour", "pink")) .. " " .. P:Get("myColour"), "false white", "and only the four choices are taken")

-- Typed names.
Equal(P:CleanName("  Mr   Shadow  "), "Mr Shadow", "spaces trimmed and squeezed")
Equal(P:CleanName("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), "ABCDEFGHIJKLMNOPQRSTUVWX", "at most 24 letters")
Equal(P:CleanName("Zr\195\175el Gustbellow the Bold One"), "Zr\195\175el Gustbellow the Bol", "letters, not bytes, counted")
Equal(P:CleanName("|cffff0000Red|r"), "cffff0000Redr", "no escape codes")
Equal(P:CleanName(H.SECRET), "", "a secret is never read")
Equal(P:CleanName(nil), "", "nothing is nothing")

-- A made-up BattleTag ("Your BattleTag becomes"): tidied as a typed name is.
Equal(P.TAG_MAX, 24, "a BattleTag of at most 24 letters")
Equal(P:CleanTag("  Fake   Tag#1234  "), "Fake Tag#1234", "BattleTag: spaces trimmed and squeezed, the # kept")
Equal(P:CleanTag("ABCDEFGHIJKLMNOPQRSTUVWXYZ#1234"), "ABCDEFGHIJKLMNOPQRSTUVWX", "BattleTag: at most 24 letters")
Equal(P:CleanTag("Zr\195\175el#12345678901234567890"), "Zr\195\175el#123456789012345678", "BattleTag: letters, not bytes")
Equal(P:CleanTag("|cffff0000Red|r#1|Kq1|k"), "cffff0000Redr#1Kq1k", "BattleTag: no escape codes")
Equal(P:CleanTag("Two\nLines#1"), "Two Lines#1", "BattleTag: no control characters")
Equal(P:CleanTag(H.SECRET) .. "|" .. P:CleanTag(nil) .. "|" .. P:CleanTag(42), "||", "BattleTag: a secret never read, only text taken")
Fresh(nil)
Equal(tostring(P:Set("myTag", "  Fake#9999 ")) .. " " .. P:Get("myTag") .. " " .. DB().myTag, "true Fake#9999 Fake#9999",
    "a typed BattleTag saves, tidied")
Equal(tostring(P:Set("myTag", "Fake#9999")), "false", "the same again changes nothing")
Equal(P:Get("myName"), "", "your name is its own setting")
Equal(tostring(P:Set("myTag", "   ")) .. " [" .. P:Get("myTag") .. "]", "true []", "spaces alone: emptied, so off")
P:Set("myTag", "Fake#9999")
Equal(tostring(P:Set("myTag", 7)) .. " [" .. P:Get("myTag") .. "]", "true []", "anything but text counts as nothing typed, as for your name")
Fresh({ myTag = "  Mr|r   Fake#12  " })
Equal(P:Get("myTag"), "Mrr Fake#12", "a saved BattleTag is cleaned as it loads")
Fresh({ myTag = string.rep("y", 30) })
Equal(P:Get("myTag"), string.rep("y", 24), "and cut to 24 letters")
Fresh({ myTag = 12 })
Equal("[" .. P:Get("myTag") .. "] " .. tostring(DB().myTag), "[] nil", "a saved one that isn't text goes back to none")
Fresh({ myTag = string.rep("z", 200) })
Equal("[" .. P:Get("myTag") .. "] " .. tostring(DB().myTag), "[] nil", "and one far too long to be typed")

-- /privacy and the key binding -------------------------------------------------------------------------

Fresh(nil)
Equal(SLASH_FEPRIVACY1, "/privacy", "/privacy")
SlashCmdList.FEPRIVACY("")
True(ForeverEnhancedPrivacyFrame and ForeverEnhancedPrivacyFrame:IsShown(), "/privacy opens the window")
SlashCmdList.FEPRIVACY("  ")
Equal(ForeverEnhancedPrivacyFrame:IsShown(), false, "and closes it")
SlashCmdList.FEPRIVACY("on")
Equal(P:Private(), true, "/privacy on")
Equal(H.printed[#H.printed], "|cffb07df0Forever Enhanced Privacy|r: Private mode is on.", "says so")
SlashCmdList.FEPRIVACY("OFF")
Equal(P:Private(), false, "/privacy off, any case")
SlashCmdList.FEPRIVACY("toggle")
Equal(P:Private(), true, "/privacy toggle turns it on")
SlashCmdList.FEPRIVACY("toggle")
Equal(P:Private(), false, "and off")
SlashCmdList.FEPRIVACY("what")
True(H.printed[#H.printed]:find("/privacy on, off or toggle", 1, true), "anything else: how to use it")
True(H.printed[#H.printed]:find("/privacy minimap shows or hides the minimap button.", 1, true), "the minimap button's command too")
H.Clear()
Equal(BINDING_HEADER_FEPRIVACY .. " / " .. BINDING_NAME_FEPRIVACY_TOGGLE, "Forever Enhanced Privacy / Toggle private mode",
    "the key binding's names")
ForeverEnhancedPrivacy_Toggle()
Equal(P:Private(), true, "the key turns it on")
Equal(#H.printed, 0, "quietly")
ForeverEnhancedPrivacy_Toggle()
Equal(P:Private(), false, "and off")
Equal(H.Problems(), "", "nothing wrong with the commands")

-- Modules: set up when first needed, told in order, nothing while off ------------------------------------------

Fresh(nil)
Spy()
H.Fire("GROUP_ROSTER_UPDATE")
H.Fire("GUILD_ROSTER_UPDATE")
H.Fire("FRIENDLIST_UPDATE")
Equal(Log(), "", "while off, no module is set up or told anything")
P:Set("chatNames", false)
P:Set("nameStyle", "player")
Equal(Log(), "", "not even when a setting changes")
P:Set("chatNames", true)
P:Set("nameStyle", "class")
P:SetPrivate(true)
Equal(Log(), "Names:Setup Names:Apply(true) UnitFrames:Setup UnitFrames:Apply(true) Chat:Setup Chat:Apply(true) Social:Setup "
    .. "Social:Apply(true) Windows:Setup Windows:Apply(true) World:Setup World:Apply(true)", "the first turn on: each set up, then applied")
P:SetPrivate(true)
Equal(Log(), "", "on again does nothing")
P:SetPrivate(false)
Equal(Log(), "World:Apply(false) Windows:Apply(false) Social:Apply(false) Chat:Apply(false) UnitFrames:Apply(false) Names:Apply(false)",
    "off: each told, last first")
P:SetPrivate(true)
Equal(Log(), "Names:Apply(true) UnitFrames:Apply(true) Chat:Apply(true) Social:Apply(true) Windows:Apply(true) World:Apply(true)",
    "set up only once")
-- A setting changing while private: its owner alone hears.
P:Set("targetFrames", false)
Equal(Log(), "UnitFrames:Apply(true,targetFrames)", "unticked: the owner")
P:Set("targetFrames", true)
Equal(Log(), "UnitFrames:Apply(true,targetFrames)", "ticked again: the owner")
P:Set("instChat", "chat")
Equal(Log(), "Chat:Apply(true,instChat)", "a choice: its owner")
P:Set("worldMap", "hide")
Equal(Log(), "World:Apply(true,worldMap)", "World owns the world map")
P:Set("questText", false)
Equal(Log(), "World:Apply(true,questText)", "and quest text, though it's on the Names page")
P:Set("nameStyle", "hidden")
Equal(Log(), "Names:Apply(true,nameStyle) UnitFrames:Apply(true,nameStyle) Chat:Apply(true,nameStyle) Social:Apply(true,nameStyle) "
    .. "Windows:Apply(true,nameStyle) World:Apply(true,nameStyle)", "the name style: everyone")
P:Set("myName", "Shade")
Equal(Log(), "Names:Apply(true,myName) UnitFrames:Apply(true,myName) Chat:Apply(true,myName) Social:Apply(true,myName) "
    .. "Windows:Apply(true,myName) World:Apply(true,myName)", "your name: everyone")
P:Set("myColour", "accent")
Equal(Log(), "Names:Apply(true,myColour) UnitFrames:Apply(true,myColour) Chat:Apply(true,myColour) Social:Apply(true,myColour) "
    .. "Windows:Apply(true,myColour) World:Apply(true,myColour)", "your name's colour: everyone, to re-label what's showing")
P:Set("myTag", "Fake#9999")
Equal(Log(), "Names:Apply(true,myTag) UnitFrames:Apply(true,myTag) Chat:Apply(true,myTag) Social:Apply(true,myTag) "
    .. "Windows:Apply(true,myTag) World:Apply(true,myTag)", "a made-up BattleTag: everyone, to re-label what's showing")
P:Set("myTag", "")
Equal(Log(), "Names:Apply(true,myTag) UnitFrames:Apply(true,myTag) Chat:Apply(true,myTag) Social:Apply(true,myTag) "
    .. "Windows:Apply(true,myTag) World:Apply(true,myTag)", "and emptied again: the same")
P:Set("myTag", "Fake#9999")
Log()
P:Set("myName", "Shade")
P:Set("myColour", "accent")
P:Set("myTag", "  Fake#9999 ")
P:Set("mode", "key")
P:Set("eye", true)
Equal(Log(), "", "no change, no news; and the mode and eye are no module's")
P:Set("nonsense", true)
P:Set("gold", "yes")
P:Set("myColour", "pink")
Equal(Log(), "", "unknown settings and wrong values are refused")
Equal(P:IsOn("targetFrames"), true, "IsOn: private and ticked")
P:Set("targetFrames", false)
Equal(P:IsOn("targetFrames"), false, "unticked")
Equal(P:IsOn("instChat"), true, "a choice is on unless Leave as is")
P:Set("instChat", "leave")
Equal(P:IsOn("instChat"), false, "Leave as is")
P:SetPrivate(false)
P:Set("targetFrames", true)
Equal(P:IsOn("targetFrames"), false, "nothing is on while private mode is off")
Equal(H.Problems(), "", "nothing wrong with the modules")

-- One module failing never stops the rest; it's said once.
Fresh(nil)
Spy()
P:Module("Chat").Apply = function() log[#log + 1] = "Chat:boom"; error("Chat.lua:9: kaboom", 0) end
P:Module("Social").Setup = function() log[#log + 1] = "Social:Setup"; error("Social.lua:3: no frame", 0) end
P:SetPrivate(true)
Equal(Log(), "Names:Setup Names:Apply(true) UnitFrames:Setup UnitFrames:Apply(true) Chat:Setup Chat:boom Social:Setup "
    .. "Windows:Setup Windows:Apply(true) World:Setup World:Apply(true)", "the others carry on; a failed set up is skipped after")
Equal(#H.printed, 2, "each failure said once")
True(H.printed[1]:find("The Chat part hit an error, so it may miss some names. Chat.lua:9: kaboom", 1, true), "naming the part and the error")
True(H.printed[2]:find("The Social part", 1, true), "the set up's too")
P:SetPrivate(false)
P:SetPrivate(true)
Equal(#H.printed, 2, "and not again")
Equal(Log():find("Social", 1, true), nil, "a module whose set up failed is left alone")
H.Clear()

-- Guarded functions: an error is said once and swallowed, answers pass through.
do
    local fn = P:Guard(P:Module("World"), function(a, b) return nil, a + b, nil end)
    local x, y, z = fn(2, 3)
    Equal(tostring(x) .. " " .. y .. " " .. tostring(z), "nil 5 nil", "answers, nils included")
    Equal(select("#", fn(1, 1)), 3, "every answer")
    local bad = P:Guard(P:Module("World"), function() error("World.lua:1: oops") end)
    Equal(select("#", bad()), 0, "an error gives nothing back")
    bad()
    Equal(#H.printed, 1, "said once")
    True(H.printed[1]:find("The World part", 1, true), "naming the module")
    H.Clear()
end

-- Blizzard's addons that load later.
do
    local ran = {}
    P:OnAddOnLoaded("Blizzard_InspectUI", function() ran[#ran + 1] = "inspect" end)
    Equal(#ran, 0, "waits for the addon")
    H.LoadAddOn("Blizzard_InspectUI")
    Equal(table.concat(ran, " "), "inspect", "runs once it loads")
    H.LoadAddOn("Blizzard_InspectUI")
    Equal(#ran, 1, "only once")
    P:OnAddOnLoaded("Blizzard_InspectUI", function() ran[#ran + 1] = "now" end)
    Equal(ran[2], "now", "already loaded: runs at once")
    P:OnAddOnLoaded("Blizzard_Calendar", function() error("x") end, P:Module("Windows"))
    H.LoadAddOn("Blizzard_Calendar")
    True(H.printed[1] and H.printed[1]:find("The Windows part", 1, true), "an error in it is said, against the module")
    H.Clear()
end

-- The record of changes, and putting it back --------------------------------------------------------------------

Fresh(nil)
do
    local name = H.BlizzardText("TestPartyName", UIParent, "Merrin Lightfoot")
    P:SetPrivate(true)
    P:SwapText("groupFrames", name, "Priest", 1, 1, 1)
    Equal(H.Text(name), "Priest", "swapped")
    H.Blizzard(function() name:SetText("Kaelis Dawnbrook") end)
    P:SwapText("groupFrames", name, "Mage", .25, .78, .92)
    P:SwapText("groupFrames", name, "Mage", .25, .78, .92)
    Equal(H.Text(name), "Mage", "the game wrote a new name; swapped again")
    P:SetPrivate(false)
    Equal(H.Text(name), "Kaelis Dawnbrook", "put back: the game's newest text, not ours")
    Equal(S[name].colour[1], 1, "and its colour")

    local secret = H.BlizzardText("TestSecretName", UIParent, H.SECRET)
    local later = H.BlizzardText("TestLaterName", UIParent, "Brannoc Stonehelm")
    local zone = H.BlizzardText("TestZone", UIParent, "Stormwind City")
    S[zone].alpha = .7
    P:SetPrivate(true)
    P:SwapText("targetFrames", secret, "Player")
    P:SwapText("targetFrames", later, "Warrior")
    H.Blizzard(function() later:SetText("Hogger") end)
    P:HideRegion("zoneText", zone)
    P:HideRegion("zoneText", zone)
    Equal(H.Alpha(zone), 0, "hidden by its alpha")
    local undone = 0
    P:OnRestore("zoneText", "overlay", function() undone = undone + 1 end)
    P:OnRestore("zoneText", "overlay", function() undone = undone + 1 end)
    -- Unticking one setting puts back only what's under it.
    P:Set("zoneText", false)
    Equal(H.Alpha(zone) .. " " .. undone, "0.7 1", "its alpha back, its undo run once")
    Equal(H.Text(later), "Hogger", "other keys untouched")
    P:SetPrivate(false)
    Equal(H.Text(secret), "Player", "a secret original is never kept: left for the game's next update")
    Equal(H.Text(later), "Hogger", "text the game has rewritten since is left alone")
    Equal(undone, 1, "an undo runs once")
    Equal(H.Problems(), "", "no secret read on the way")

    -- A /reload note, said once, in chat with the window shut...
    P:Set("zoneText", true)
    P:SetPrivate(true)
    P:NeedsReload("zoneText")
    P:NeedsReload("coords")
    P:SetPrivate(false)
    Equal(table.concat(H.printed, " | "), "|cffb07df0Forever Enhanced Privacy|r: Some things only come back fully after a /reload.",
        "once, however many need it")
    H.Clear()
    P:SetPrivate(true)
    P:SetPrivate(false)
    Equal(#H.printed, 0, "not again when nothing needs it")
    -- ...and in the footer with it open.
    P.ShowWindow()
    P:SetPrivate(true)
    P:NeedsReload("gold")
    P:SetPrivate(false)
    Equal(#H.printed, 0, "not in chat while the window is open")
    Equal(H.Text(ForeverEnhancedPrivacyFrame.note), P.RELOAD_NOTE, "in the footer")
    P.window:Hide()
    Equal(H.Problems(), "", "nothing wrong putting things back")
end

-- Colours: the game's own is kept while ours is on, and comes back at once
-- when a swap brings none (your typed name in the game's own colour).
Fresh(nil)
do
    local function Colour(region)
        local c = S[region].colour
        return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3])
    end
    local function Showing(...) return tostring(P:Showing(...)) end
    local mine = H.BlizzardText("TestMyName", UIParent, "Zriel Gustbellow")
    S[mine].colour = { 1, .82, 0, 1 }
    P:SetPrivate(true)
    P:SwapText("playerFrame", mine, "Shade", .69, .49, .94)
    Equal(H.Text(mine) .. " / " .. Colour(mine), "Shade / 0.69 0.49 0.94", "a colour of ours")
    Equal(Showing("playerFrame", mine, "Shade", .69, .49, .94), "true", "showing: that text in that colour")
    Equal(Showing("playerFrame", mine, "Shade") .. " " .. Showing("playerFrame", mine, "Shade", 1, 1, 1) .. " "
        .. Showing("playerFrame", mine, "Bob", .69, .49, .94), "false false false",
        "not with none of ours, in another colour, or another text")
    P:SwapText("playerFrame", mine, "Shade", 1, 1, 1)
    Equal(Colour(mine), "1.00 1.00 1.00", "another colour of ours")
    P:SwapText("playerFrame", mine, "Shade")
    Equal(H.Text(mine) .. " / " .. Colour(mine), "Shade / 1.00 0.82 0.00", "none: the game's own colour back at once, the text still ours")
    Equal(Showing("playerFrame", mine, "Shade"), "true", "showing as asked")
    P:SwapText("playerFrame", mine, "Shade")
    Equal(Colour(mine), "1.00 0.82 0.00", "none again: still the game's")
    P:SwapText("playerFrame", mine, "Shade", 1, .49, .04)
    Equal(Colour(mine), "1.00 0.49 0.04", "a colour of ours again")
    -- The game paints its own over ours: that's left as it is.
    H.Blizzard(function() mine:SetTextColor(.5, .5, .5) end)
    Equal(Showing("playerFrame", mine, "Shade"), "true", "the game's colour showing: nothing of ours to take off")
    P:SwapText("playerFrame", mine, "Shade")
    Equal(Colour(mine), "0.50 0.50 0.50", "none: the game's newest colour stays")
    -- The game writes the name again but not its colour: what comes back is
    -- its colour from before ours, never ours.
    P:SwapText("playerFrame", mine, "Shade", 1, .49, .04)
    H.Blizzard(function() mine:SetText("Zriel") end)
    P:SwapText("playerFrame", mine, "Shade", .69, .49, .94)
    P:SetPrivate(false)
    Equal(H.Text(mine) .. " / " .. Colour(mine), "Zriel / 0.50 0.50 0.50", "put back: the game's newest text, and its colour")
    -- Put back with no colour of ours on: the colour is left alone.
    P:SetPrivate(true)
    P:SwapText("playerFrame", mine, "Shade", .69, .49, .94)
    P:SwapText("playerFrame", mine, "Shade")
    H.Blizzard(function() mine:SetTextColor(.2, .2, .2) end)
    P:SetPrivate(false)
    Equal(H.Text(mine) .. " / " .. Colour(mine), "Zriel / 0.20 0.20 0.20", "off after the game's own colour: the text back, its colour kept")
    Equal(H.Problems(), "", "nothing wrong with colours")
end

-- CVars ------------------------------------------------------------------------------------------------------------

Fresh(nil)
do
    P:SetPrivate(true)
    Equal(P:SetCVar("ownHead", "UnitNameOwn", 0), true, "a CVar changed")
    Equal(H.cvars.UnitNameOwn .. " " .. DB().cvarBackup.UnitNameOwn, "0 1", "its original kept in the saved settings")
    Equal(P:SetCVar("ownHead", "NoSuchCVar", 0), false, "a CVar this client hasn't: nothing")
    Equal(DB().cvarBackup.NoSuchCVar, nil, "and nothing saved")
    -- CVars the game caches: an addon's change would taint the cached copy.
    local writes = #H.cvarWrites
    Equal(P:SetCVar("otherHeads", "nameplateForceShowUnitName", "1"), false, "a CVar the game caches: refused")
    Equal(P:SetCVar("ownHead", "floatingCombatTextFriendlyHealers_v2", "0"), false, "the healer names one too")
    H.cvars.someLaterCachedCVar = "1"
    CVarCallbackRegistry.cachable.someLaterCachedCVar = true
    Equal(P:SetCVar("ownHead", "someLaterCachedCVar", "0"), false, "and any the game's registry marks later")
    Equal(#H.cvarWrites .. " " .. tostring(DB().cvarBackup.nameplateForceShowUnitName), writes .. " nil", "nothing written or saved")
    True(P.CACHABLE_CVARS.nameplateForceShowUnitName and P.CACHABLE_CVARS.floatingCombatTextFriendlyHealers_v2,
        "both on the core's own list")
    P:SetCVar("otherHeads", "UnitNameFriendlyPlayerName", "0")
    P:SetCVar("nameplates", "UnitNameFriendlyPlayerName", "0")
    P:SetCVar("ownHead", "UnitNameOwn", 0)
    Equal(DB().cvarBackup.UnitNameOwn, "1", "asking again keeps the first original")
    P:Set("nameplates", false)
    Equal(H.cvars.UnitNameFriendlyPlayerName, "0", "still wanted by another setting: left")
    P:Set("otherHeads", false)
    Equal(H.cvars.UnitNameFriendlyPlayerName .. " " .. tostring(DB().cvarBackup.UnitNameFriendlyPlayerName), "1 nil",
        "nobody wants it: put back, and forgotten")
    P:SetPrivate(false)
    Equal(H.cvars.UnitNameOwn .. " " .. tostring(next(DB().cvarBackup)), "1 nil", "off: every CVar back, nothing left saved")
    -- Changed by hand meanwhile? Put back to how it was before private mode.
    P:Set("otherHeads", true)
    P:Set("nameplates", true)
    -- In combat: waits for the fight to end, both ways.
    H.Combat(true)
    P:SetPrivate(true)
    P:SetCVar("bubbles", "chatBubbles", 0)
    Equal(H.cvars.chatBubbles, "1", "not in combat")
    H.Combat(false)
    Equal(H.cvars.chatBubbles .. " " .. DB().cvarBackup.chatBubbles, "0 1", "once it ends")
    H.Combat(true)
    P:SetPrivate(false)
    Equal(H.cvars.chatBubbles, "0", "put back only after the fight")
    H.Combat(false)
    Equal(H.cvars.chatBubbles .. " " .. tostring(DB().cvarBackup.chatBubbles), "1 nil", "then back")
    -- Set and put back inside one fight: never touched.
    local writes = #H.cvarWrites
    H.Combat(true)
    P:SetPrivate(true)
    P:SetCVar("bubbles", "chatBubbles", 0)
    P:SetPrivate(false)
    H.Combat(false)
    Equal(#H.cvarWrites .. " " .. H.cvars.chatBubbles, writes .. " 1", "on and off inside a fight: no change at all")
    Equal(H.Problems(), "", "no CVar changed in combat")
end

-- Crash recovery: CVars left changed are put back at the next login.
H.Environment()
H.cvars.UnitNameOwn, H.cvars.chatBubbles = "0", "0"
P = H.Load({ cvarBackup = { UnitNameOwn = "1", chatBubbles = "1" }, wasOn = true })
Equal(P:Private(), false, "a fresh login after a crash: off (with its key)")
Equal(H.cvars.UnitNameOwn .. H.cvars.chatBubbles .. " " .. tostring(next(DB().cvarBackup)), "11 nil", "every CVar back")
Equal(DB().wasOn, false, "and the /reload flag cleared")

-- Logging out or a /reload while private: every CVar back first, so turning the addon off
-- before the next login leaves nothing hidden.
Fresh(nil)
do
    P:SetPrivate(true)
    P:SetCVar("otherHeads", "UnitNameFriendlyPlayerName", "0")
    P:SetCVar("bubbles", "chatBubbles", "0")
    H.Fire("PLAYER_LOGOUT")
    Equal(H.cvars.UnitNameFriendlyPlayerName .. H.cvars.chatBubbles .. " " .. tostring(next(DB().cvarBackup)), "11 nil",
        "logging out while private: every CVar back, nothing left saved")
    Equal(DB().wasOn, true, "and private mode still due back after a /reload")
    P:SetCVar("otherHeads", "UnitNameFriendlyPlayerName", "0")
    H.Combat(true)
    H.Fire("PLAYER_LOGOUT")
    Equal(H.cvars.UnitNameFriendlyPlayerName .. " " .. DB().cvarBackup.UnitNameFriendlyPlayerName, "0 1",
        "in combat: left, its original kept for the next login")
    H.Combat(false)
    Equal(H.Problems(), "", "no CVar changed in combat at logout")
end
-- The next login with the addon on and private mode due back: hidden again, true originals kept.
H.Environment()
H.cvars.UnitNameFriendlyPlayerName = "1"
P = H.Load({ wasOn = true }, { reload = true })
Equal(P:Private(), true, "a /reload after the logout put-back: on again")
Equal(H.cvars.UnitNameFriendlyPlayerName .. " " .. tostring(DB().cvarBackup.UnitNameFriendlyPlayerName), "0 1",
    "names hidden again, with the true original kept")

-- A cached CVar an earlier build left changed: never put back from here, you're told instead.
H.Environment()
H.cvars.floatingCombatTextFriendlyHealers_v2 = "0"
P = H.Load({ cvarBackup = { floatingCombatTextFriendlyHealers_v2 = "1", nameplateForceShowUnitName = "1" }, combatText = true })
Equal(H.cvars.floatingCombatTextFriendlyHealers_v2 .. " " .. #H.cvarWrites, "0 0", "a cached CVar left as it is")
Equal(next(DB().cvarBackup), nil, "its saved original dropped")
Equal(DB().combatText, nil, "and the retired setting cleared")
Equal(#H.printed, 1, "said once, for the one that differs")
True(H.printed[1]:find("friendly healer names, in the Combat options", 1, true), "naming it as the options do")
H.Clear()

-- With "always", the originals are kept while private mode comes straight back on.
H.Environment()
H.cvars.UnitNameOwn, H.cvars.chatBubbles = "0", "0"
do
    local saved = { mode = "always", cvarBackup = { UnitNameOwn = "1", chatBubbles = "1" } }
    _G.ForeverEnhancedPrivacyDB = saved
    local ns = {}
    H.before = {}
    for _, file in ipairs(H.FILES) do assert(loadfile(file))(H.ADDON, ns) end
    P = ns
    P:Module("UnitFrames").Apply = function(_, on) if on then P:SetCVar("ownHead", "UnitNameOwn", "0") end end
    -- The real Chat module hides bubbles from login; here chatBubbles stands for a CVar nothing uses.
    P:Module("Chat").Apply = function() end
    H.Fire("ADDON_LOADED", H.ADDON)
    H.Fire("PLAYER_LOGIN")
    H.Login(false)
end
Equal(P:Private(), true, "always: on from login")
Equal(H.cvars.UnitNameOwn .. " " .. DB().cvarBackup.UnitNameOwn, "0 1", "the CVar still in use keeps its true original")
Equal(H.cvars.chatBubbles .. " " .. tostring(DB().cvarBackup.chatBubbles), "1 nil", "one nothing uses now is put back")
P:SetPrivate(false)
Equal(H.cvars.UnitNameOwn, "1", "turned off: the true original")

-- A /reload keeps private mode as it was; a fresh login doesn't.
Fresh({ wasOn = true }, { reload = true })
Equal(P:Private(), true, "a /reload while on: still on")
Fresh({ wasOn = false }, { reload = true })
Equal(P:Private(), false, "a /reload while off: off")
Fresh({ wasOn = true })
Equal(P:Private(), false, "a fresh login: off, with its key")
Fresh({ mode = "shots", wasOn = true })
Equal(P:Private(), false, "and for screenshots")
Fresh({ mode = "always" })
Equal(P:Private(), true, "always: on")
H.Login(false)
Equal(P:Private(), true, "a later loading screen changes nothing")
Equal(H.Problems(), "", "nothing wrong at login")

-- Reset all settings ------------------------------------------------------------------------------------------------------

-- Everything changed, private mode on with CVars changed: a reset puts it all back.
Fresh({ mode = "always", nameStyle = "hidden", myName = "Shade", myTag = "Fake#9999", myColour = "white", eye = false,
    chatNames = false, publicChannels = true, instChat = "chat", worldMap = "hide", gold = true, cleanOld = true, combatText = true,
    someOldKey = "x" })
do
    Equal(P:Private(), true, "reset: private mode on from login (always)")
    Spy()
    local heard, offFirst = {}, nil
    P:Listen(function(what)
        heard[#heard + 1] = what
        -- When private mode goes off: what's back, and what's still saved.
        if what == "private" and not offFirst then
            offFirst = H.cvars.UnitNameOwn .. H.cvars.chatBubbles .. " " .. tostring(next(DB().cvarBackup)) .. " " .. P:Get("myName")
        end
    end)
    local saved = DB()
    local name = H.BlizzardText("TestResetName", UIParent, "Merrin Lightfoot")
    P:SwapText("groupFrames", name, "Priest", 1, 1, 1)
    P:SetCVar("ownHead", "UnitNameOwn", "0")
    P:SetCVar("bubbles", "chatBubbles", "0")
    Equal(H.cvars.UnitNameOwn .. H.cvars.chatBubbles, "00", "CVars changed while private")
    H.Clear()
    Equal(P:Reset(), true, "a reset")
    Equal(P:Private(), false, "private mode off")
    Equal(Log(), "World:Apply(false) Windows:Apply(false) Social:Apply(false) Chat:Apply(false) UnitFrames:Apply(false) Names:Apply(false)",
        "through the usual path: each module told, last first, and nothing else")
    Equal(H.Text(name), "Merrin Lightfoot", "every swap put back")
    Equal(H.cvars.UnitNameOwn .. H.cvars.chatBubbles .. " " .. tostring(next(DB().cvarBackup)), "11 nil", "every CVar back, no backup left")
    Equal(offFirst, "11 nil Shade", "private mode off and every CVar back first, before any setting is dropped")
    for _, key in ipairs(P.KEYS) do Equal(P:Get(key), P.DEFAULTS[key], key .. " back to its default") end
    for key, value in pairs(P.DEFAULTS) do Equal(P:Get(key), value, key .. ": the default") end
    Equal(P:Get("mode") .. " " .. P:Get("nameStyle") .. " [" .. P:Get("myName") .. "][" .. P:Get("myTag") .. "] " .. P:Get("myColour")
        .. " " .. tostring(P:Get("eye")), "key class [][] game true", "with its key, class names, no name or BattleTag, the eye on")
    do
        local left = {}
        for key, value in pairs(DB()) do left[#left + 1] = key .. "=" .. (type(value) == "table" and "{}" or tostring(value)) end
        table.sort(left)
        Equal(table.concat(left, " "), "cvarBackup={} wasOn=false", "nothing else kept in the saved settings")
    end
    Equal(rawequal(DB(), saved), true, "the same saved table, emptied (never swapped for a new one)")
    Equal(table.concat(heard, " "), "private reset", "the window and the eye hear of it")
    Equal(table.concat(H.printed, " | "), "|cffb07df0Forever Enhanced Privacy|r: Settings reset.", "one short line in chat")
    H.Clear()
    Equal(P:Set("chatNames", false), true, "settings change as usual after")
    P:Set("chatNames", true)
    Equal(DB().chatNames, true, "and save")
    -- With nothing changed and private mode off: still a reset, quietly.
    Equal(P:Reset(), true, "a second reset")
    Equal(Log(), "", "private mode already off: no module told")
    Equal(DB().chatNames, nil, "the saved value dropped again")
    Equal(#H.printed, 1, "said once")
    H.Clear()
    Equal(H.Problems(), "", "nothing wrong resetting")
end
-- The next login after a reset: off, with its key.
H.Environment()
P = H.Load({ cvarBackup = {}, wasOn = false }, { reload = true })
Equal(P:Private(), false, "after a reset, a /reload: off")

-- In combat: the settings reset at once, the CVars wait for the fight to end, their originals kept till then.
Fresh(nil)
do
    P:Set("myName", "Shade")
    P:Set("publicChannels", true)
    P:SetPrivate(true)
    P:SetCVar("ownHead", "UnitNameOwn", "0")
    H.Combat(true)
    local writes = #H.cvarWrites
    P:Reset()
    Equal(P:Private() and "on" or "off", "off", "in combat: private mode off")
    Equal(P:Get("myName") .. "|" .. tostring(P:Get("publicChannels")), "|false", "every setting reset at once")
    Equal(#H.cvarWrites .. " " .. H.cvars.UnitNameOwn, writes .. " 0", "no CVar touched in the fight")
    Equal(DB().cvarBackup.UnitNameOwn, "1", "its original kept to put back")
    Equal(DB().wasOn, false, "and private mode not due back after a /reload")
    H.Combat(false)
    Equal(H.cvars.UnitNameOwn .. " " .. tostring(next(DB().cvarBackup)), "1 nil", "put back once it ends, the backup emptied")
    H.Clear()
    Equal(H.Problems(), "", "no CVar changed in combat")
end
-- A backup left from a crash survives a reset in a fight, and goes back at the next login.
H.Environment()
H.cvars.chatBubbles = "0"
P = H.Load({ cvarBackup = { chatBubbles = "1" }, wasOn = false }, { beforeLogin = true })
H.Combat(true)
P:Reset()
Equal(DB().cvarBackup.chatBubbles, "1", "a reset keeps an original still waiting to go back")
H.Combat(false)
H.Login(false)
Equal(H.cvars.chatBubbles .. " " .. tostring(next(DB().cvarBackup)), "1 nil", "and the login puts it back")
H.Clear()
-- Private mode on and reset in the same fight: the change still waiting is dropped, nothing written after.
Fresh(nil)
do
    H.Combat(true)
    P:SetPrivate(true)
    P:SetCVar("ownHead", "UnitNameOwn", "0")
    local writes = #H.cvarWrites
    P:Reset()
    H.Combat(false)
    Equal(#H.cvarWrites - writes .. " " .. H.cvars.UnitNameOwn .. " " .. tostring(next(DB().cvarBackup)), "0 1 nil",
        "on and reset in one fight: no CVar written when it ends, nothing saved")
    H.Clear()
    Equal(H.Problems(), "", "nothing wrong")
end

-- Screenshots and the eye ---------------------------------------------------------------------------------------------

Fresh(nil)
Equal(P.Eye:Frame(), nil, "no eye until it's needed")
P:SetPrivate(true)
local eye = P.Eye:Frame()
True(eye and eye:IsShown(), "the eye shows while private")
Equal(S[eye].points[1][1] .. " " .. S[eye].width .. "x" .. S[eye].height .. " " .. tostring(S[eye].mouse), "TOP 22x14 false",
    "small, at the top, never taking the mouse")
H.Screenshot("start")
Equal(eye:IsShown(), false, "it steps aside for a screenshot")
Equal(P:Private(), true, "private mode stays on")
H.Screenshot("done")
Equal(eye:IsShown(), true, "and comes back")
P:Set("eye", false)
Equal(eye:IsShown(), false, "the Extras tick hides it")
P:Set("eye", true)
Equal(eye:IsShown(), true, "and shows it")
P:SetPrivate(false)
Equal(eye:IsShown(), false, "gone when private mode is off")
H.Screenshot("start")
Equal(P:Private(), false, "with its key, a screenshot doesn't turn it on")
H.Screenshot("done")
-- For screenshots.
P:Set("mode", "shots")
Spy()
local shotOnlyDuring
P:Module("Names").Apply = function(_, on) if on then shotOnlyDuring = P:ShotOnly() end end
H.Screenshot("start")
Equal(P:Private(), true, "a screenshot turns it on")
Equal(shotOnlyDuring, true, "the modules know it's for the screenshot alone as they're told")
Equal(eye:IsShown(), false, "with no eye in the picture")
H.Screenshot("done")
Equal(P:Private(), false, "and straight off after")
Equal(P:ShotOnly(), false, "off: not for a screenshot either")
H.Screenshot("start")
H.Screenshot("fail")
Equal(P:Private(), false, "a failed one too")
True(Log():find("World:Apply(true) ", 1, true), "every module told each time")
Equal(DB().wasOn, false, "a screenshot never counts for /reload")
P:SetPrivate(true)
Equal(P:ShotOnly(), false, "on by hand: not just for a screenshot")
H.Screenshot("start")
H.Screenshot("done")
Equal(P:Private(), true, "already on by hand: still on after")
Equal(H.Problems(), "", "nothing wrong with screenshots")

-- Names ------------------------------------------------------------------------------------------------------------------

Fresh(nil)
do
    local function Label(...)
        local label, r, g, b = ...
        if r then return ("%s %.2f %.2f %.2f"):format(label, r, g, b) end
        return tostring(label)
    end
    H.units.target = { name = "Brannoc", surname = "Stonehelm", class = "Warrior", classFile = "WARRIOR", player = true, guid = "Player-1-0002" }
    H.units.focus = { name = "Hogger", player = false, guid = "Creature-0-1" }
    H.units.pet = { name = "Fluffy", pet = true, guid = "Pet-0-1" }
    H.units.party1 = { name = "Merrin", surname = "Lightfoot", class = "Priest", classFile = "PRIEST", player = true, guid = "Player-1-0003" }
    Equal(Label(P:NameFor("player")), "Druid 1.00 0.49 0.04", "you: your class in its colour")
    Equal(Label(P:NameFor("target")), "Warrior 0.78 0.61 0.43", "another player: theirs")
    Equal(P:NameFor("focus"), nil, "an NPC: left alone")
    Equal(Label(P:NameFor("pet")), "Pet 0.78 0.78 0.78", "a pet: Pet")
    Equal(P:NameFor("raid40"), nil, "nobody there: nothing")
    Equal(P:NameFor(H.SECRET), nil, "a secret unit: nothing")
    Equal(P:NameFor(nil), nil, "no unit: nothing")
    -- The same player by another token.
    H.units.targettarget = { name = "Zriel", surname = "Gustbellow", class = "Druid", classFile = "DRUID", player = true, guid = "Player-1-0001" }
    P:Set("myName", "Shade")
    Equal(Label(P:NameFor("targettarget")), "Shade", "you by another token: your typed name, with no colour (the game's own)")
    Equal(Label(P:NameFor("player")), "Shade", "and yourself")
    Equal(P:MyLabel(), "Shade", "MyLabel")
    Equal(select("#", P:MyLabel()) .. " " .. tostring(select(2, P:MyLabel())), "2 nil", "no colour at all: nil")
    -- Each name colour.
    local COLOURS = { game = "Shade", accent = "Shade 0.69 0.49 0.94", class = "Shade 1.00 0.49 0.04", white = "Shade 1.00 1.00 1.00" }
    for _, choice in ipairs({ "accent", "class", "white", "game" }) do
        P:Set("myColour", choice)
        Equal(Label(P:MyLabel()) .. " | " .. Label(P:NameFor("targettarget")) .. " | " .. Label(P:LabelForGUID("Player-1-0001"))
            .. " | " .. Label(P:LabelForName("Zriel Gustbellow")), ("%s | %s | %s | %s"):format(COLOURS[choice], COLOURS[choice],
            COLOURS[choice], COLOURS[choice]), choice .. ": your typed name by unit, GUID and name")
        Equal(Label(P:NameFor("target")), "Warrior 0.78 0.61 0.43", choice .. ": anyone else as before")
    end
    -- A made-up BattleTag: in the same Name colour as your typed name, and
    -- never your name anywhere else.
    Equal(tostring(P:MyTag()), "nil", "no made-up BattleTag: nil")
    P:Set("myTag", "Fake#9999")
    local TAGS = { game = "Fake#9999", accent = "Fake#9999 0.69 0.49 0.94", class = "Fake#9999 1.00 0.49 0.04",
        white = "Fake#9999 1.00 1.00 1.00" }
    for _, choice in ipairs({ "accent", "class", "white", "game" }) do
        P:Set("myColour", choice)
        Equal(Label(P:MyTag()) .. " | " .. Label(P:MyLabel()) .. " | " .. Label(P:NameFor("player")),
            TAGS[choice] .. " | " .. COLOURS[choice] .. " | " .. COLOURS[choice], choice .. ": the made-up BattleTag, your name as before")
    end
    Equal(select("#", P:MyTag()) .. " " .. tostring(select(2, P:MyTag())), "2 nil", "the game's own: no colour at all")
    P:Set("nameStyle", "hidden")
    Equal(Label(P:MyTag()), "Fake#9999", "the Hidden style leaves a typed BattleTag")
    P:Set("nameStyle", "class")
    P:Set("myName", "")
    P:Set("myColour", "accent")
    Equal(Label(P:MyTag()) .. " | " .. Label(P:MyLabel()), "Fake#9999 0.69 0.49 0.94 | Druid 1.00 0.49 0.04",
        "with no typed name: the BattleTag in its colour, you by the name style")
    H.units.player.secretClass = true
    P:Set("myColour", "class")
    Equal(Label(P:MyTag()), "Fake#9999", "your class colour when the game won't say your class: the game's own")
    H.units.player.secretClass = nil
    P:Set("myTag", "")
    Equal(tostring(P:MyTag()), "nil", "emptied: nil again")
    P:Set("myName", "Shade")
    P:Set("myColour", "game")
    H.units.player.secretClass = true
    P:Set("myColour", "class")
    Equal(Label(P:MyLabel()), "Shade", "your class colour when the game won't say your class: the game's own")
    H.units.player.secretClass = nil
    P:Set("myName", "")
    for _, choice in ipairs({ "accent", "white", "game" }) do
        P:Set("myColour", choice)
        Equal(Label(P:MyLabel()), "Druid 1.00 0.49 0.04", choice .. ": with no typed name, the name style as it was")
    end
    P:Set("myName", "Shade")
    P:Set("myColour", "accent")
    Equal(Label(P:NameFor("targettarget")), "Shade 0.69 0.49 0.94", "Purple for what follows")
    -- Secrets: a comparison the game won't answer, a class it won't say.
    H.units.targettarget.secretCompare = true
    Equal(Label(P:NameFor("targettarget")), "Druid 1.00 0.49 0.04", "can't tell it's you: a class label, never your name")
    H.units.targettarget.secretClass = true
    Equal(Label(P:NameFor("targettarget")), "Player 0.78 0.78 0.78", "can't say the class either: Player")
    H.units.targettarget = { name = "X", secretPlayer = true, guid = "?" }
    Equal(Label(P:NameFor("targettarget")), "Player 0.78 0.78 0.78", "can't tell it's a player: Player, to be safe")
    P:Set("myName", "")
    P:Set("myColour", "game")
    P:Set("nameStyle", "player")
    Equal(P:NameFor("target") .. " " .. P:NameFor("player") .. " " .. P:NameFor("pet"), "Player Player Pet", "the Player style")
    P:Set("nameStyle", "hidden")
    Equal("[" .. P:NameFor("target") .. "][" .. P:NameFor("player") .. "][" .. P:NameFor("pet") .. "]", "[][][]", "the Hidden style")
    P:Set("nameStyle", "class")
    H.units.target.classFile = "NOSUCHCLASS"
    Equal(P:NameFor("target"), "Player", "an unknown class: Player")
    H.units.target.classFile = "WARRIOR"
    -- Your name.
    Equal(table.concat({ P:MyNames() }, "|"), "Zriel|Zriel Gustbellow", "your first and full names")
    Equal(tostring(P:IsMyName("Zriel")) .. tostring(P:IsMyName("Zriel Gustbellow")), "truetrue", "both forms are you")
    Equal(tostring(P:IsMyName("Zriel Other")) .. tostring(P:IsMyName("Zrie")) .. tostring(P:IsMyName("")) .. tostring(P:IsMyName(nil))
        .. tostring(P:IsMyName(H.SECRET)), "falsefalsefalsefalsefalse", "nothing else is, and never a secret")
    H.units.player.surname = nil
    Equal(table.concat({ P:MyNames() }, "|"), "Zriel|Zriel", "no surname: the first name twice")
    H.units.player.surname = "Gustbellow"
    -- GUIDs.
    Equal(P:LabelForGUID("Player-1-0001") .. " " .. P:LabelForGUID("Player-1-0002") .. " " .. P:LabelForGUID("Player-9-9999")
        .. " " .. P:LabelForGUID(H.SECRET), "Druid Warrior Player Player", "by GUID: you, a player, a stranger, a secret")
    -- Names learned while private.
    H.guild = { { name = "Kaelis Dawnbrook", classFile = "MAGE" }, { secret = true } }
    H.friends = { { name = "Tamsin Ashvale", className = "Rogue" } }
    H.Fire("GROUP_ROSTER_UPDATE")
    Equal(P:ClassOf("Merrin Lightfoot"), nil, "nothing noted while off")
    P:SetPrivate(true)
    Equal(P:ClassOf("Merrin Lightfoot") .. " " .. P:ClassOf("Kaelis Dawnbrook") .. " " .. P:ClassOf("Tamsin Ashvale"),
        "PRIEST MAGE ROGUE", "your group, guild and friends noted when it turns on")
    H.units.party2 = { name = "Orin", surname = "Vale", class = "Paladin", classFile = "PALADIN", player = true, guid = "Player-1-0004" }
    H.Fire("GROUP_ROSTER_UPDATE")
    Equal(P:ClassOf("Orin Vale"), "PALADIN", "and as the group changes")
    H.guild[3] = { name = "Bram Oakes", classFile = "HUNTER" }
    H.Fire("GUILD_ROSTER_UPDATE")
    H.Fire("GUILD_ROSTER_UPDATE")
    Equal(#H.timers, 1, "a busy guild roster: one scan waits")
    H.RunTimers()
    Equal(P:ClassOf("Bram Oakes"), "HUNTER", "then runs")
    P:Learn("Nadia-Stormrage", "WARLOCK")
    P:Learn("Zriel Gustbellow", "DRUID")
    P:Learn(H.SECRET, "MAGE")
    P:Learn("Unknown", "MAGE")
    Equal(tostring(P:ClassOf("Nadia")) .. " " .. tostring(P:ClassOf("Zriel Gustbellow")) .. " " .. tostring(P:ClassOf("Unknown")),
        "WARLOCK nil nil", "a realm dropped; never you, a secret or Unknown")
    Equal(P:LabelForName("Merrin Lightfoot") .. " " .. P:LabelForName("Zriel") .. " " .. P:LabelForName("Somebody")
        .. " " .. P:LabelForName("Somebody", "SHAMAN"), "Priest Druid Player Shaman", "names seen as text")
    -- Swapping names in text.
    local function Swap(text, me, colour) return (P:ReplaceNames(text, me, colour)) end
    Equal(Swap("Zriel Gustbellow says hi"), "Druid says hi", "your full name")
    Equal(Swap("Hi Zriel, welcome!"), "Hi Druid, welcome!", "your first name")
    Equal(Swap("Zrielle and Zriels are not you"), "Zrielle and Zriels are not you", "whole words only")
    Equal(Swap("Merrin Lightfoot joins the party. Merrin waves."), "Priest joins the party. Priest waves.", "noted names, full or first")
    Equal(Swap("|Hplayer:Zriel Gustbellow|h[Zriel Gustbellow]|h: hello"), "|Hplayer:Zriel Gustbellow|h[Druid]|h: hello",
        "a link's data kept, so whispering still works")
    Equal(Swap("|cff40ff40Kaelis Dawnbrook|r loots"), "|cff40ff40Mage|r loots", "colour codes kept")
    Equal(Swap("|TInterface\\Merrin:0|t Merrin"), "|TInterface\\Merrin:0|t Priest", "never inside a texture")
    Equal(Swap("|Kq12|k is online"), "|Kq12|k is online", "Battle.net names left as they are")
    Equal(Swap("Greetings, Zriel."), "Greetings, Druid.", "quest text")
    Equal(Swap("Greetings, Zriel.", "adventurer"), "Greetings, adventurer.", "or the module's own words for you")
    Equal(Swap("Merrin Lightfoot", nil, true), "|cffffffffPriest|r", "in its colour, asked")
    Equal(Swap("Nobody here"), "Nobody here", "nothing to swap")
    local same, changed = P:ReplaceNames(H.SECRET)
    True(rawequal(same, H.SECRET) and changed == false, "a secret comes back untouched")
    Equal(tostring(select(2, P:ReplaceNames("Merrin"))), "true", "says when it changed")
    -- A first name alone: your group's anywhere, anyone else's only inside a sentence.
    P:Learn("Will Ashford", "MAGE")
    Equal(Swap("Will you tank? Ask Will Ashford."), "Will you tank? Ask Mage.",
        "a guildmate's first name starting a sentence is left (it may be a word); the whole name still goes")
    Equal(Swap("Kaelis, are you on? Ask Kaelis about it.\nKaelis"), "Kaelis, are you on? Ask Mage about it.\nKaelis",
        "inside a sentence it goes; at the start of one or of a line it stays")
    Equal(Swap("Merrin, are you on?"), "Priest, are you on?", "someone in your group: anywhere")
    H.units.party1 = nil
    H.Fire("GROUP_ROSTER_UPDATE")
    Equal(Swap("Merrin, are you on? Ask Merrin."), "Merrin, are you on? Ask Priest.", "once they've left, like anyone else")
    P:Set("nameStyle", "hidden")
    Equal(Swap("Zriel waves at Merrin."), " waves at .", "the Hidden style blanks them")
    P:Set("nameStyle", "class")
    P:Set("myName", "Shade")
    Equal(Swap("Zriel Gustbellow and Zriel"), "Shade and Shade", "your typed name")
    Equal(Swap("Hi Zriel, meet Merrin Lightfoot", nil, true), "Hi Shade, meet |cffffffffPriest|r",
        "in its colour, asked: the game's own is none of ours")
    for choice, code in pairs({ accent = "|cffb07df0", class = "|cffff7d0a", white = "|cffffffff" }) do
        P:Set("myColour", choice)
        Equal(Swap("Hi Zriel", nil, true), "Hi " .. code .. "Shade|r", choice .. ": your name in text, in its colour")
        Equal(Swap("Hi Zriel"), "Hi Shade", choice .. ": with colour not asked, none")
    end
    P:Set("myColour", "game")
    Equal(Swap("Hi Zriel", nil, true), "Hi Shade", "back to the game's own: no colour code")
    Equal(H.Problems(), "", "no secret read, no error")
end

io.stdout:write("TestCore: " .. H.checks .. " checks passed\n")
