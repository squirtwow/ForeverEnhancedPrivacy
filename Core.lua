-- Forever Enhanced Privacy, a personal addon by Squirt: a private mode for
-- streams and screenshots that hides or swaps names and giveaways.
--
-- This file holds every setting the window shows (one table; the window and
-- the defaults are built from it), private mode and the three ways it turns
-- on, /privacy and the key binding, the surface modules, and the record of
-- each change they make, so turning private mode off puts things back.
-- Tools/Notes.md spells out the contract the modules follow.
local ADDON, P = ...

P.TITLE = "Forever Enhanced Privacy"
P.SLASH = "/privacy"
P.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
P.ACCENT = { .69, .49, .94 } -- #b07df0, the family purple
P.ACCENT_HEX = "b07df0"
P.NAME_MAX = 24 -- letters in "Your name becomes"
-- Letters in "Your BattleTag becomes": room for any real BattleTag, and
-- still inside the older friends window's BattleTag box (190 wide).
P.TAG_MAX = 24

local issecretvalue = issecretvalue or function() return false end

-- Whether a value is one of the game's secrets, which must never be read,
-- compared, joined or measured, only passed straight to a widget's setter.
function P.IsSecret(value)
    return issecretvalue(value) == true
end

-- Pages and rows ------------------------------------------------------------------------
-- Each row's owner is the module that does the work for it. Rows with
-- options are choices; the rest are ticks. A tag is a quiet word after the
-- label. The descriptions show in the window's footer on hover.

local HIDE_ONLY, EXPERIMENTAL = "hide only", "experimental"

P.PAGES = {
    { key = "overview", label = "Overview", about = "Turn private mode on, and pick how names look while it is." },
    { key = "names", label = "Names", about = "Your name and other players' names on frames, plates and tooltips." },
    { key = "chat", label = "Chat", about = "Names and giveaways in chat." },
    { key = "social", label = "Friends and guild", about = "Battle.net, friends, your guild, mail and group finder." },
    { key = "windows", label = "Windows and pop-ups", about = "Invites, trades, loot, the damage meter and more." },
    { key = "world", label = "World and location", about = "Anything that shows where you are, and your gold." },
    { key = "limits", label = "Good to know", about = "What the game won't let an addon change, and how to work round it." },
}

P.SECTIONS = {
    names = {
        { title = "You", rows = {
            { key = "playerFrame", owner = "UnitFrames", label = "Player and pet frames",
                desc = "Your name on your player frame, and your pet's name." },
            { key = "charTitles", owner = "UnitFrames", label = "Character and inspect windows",
                desc = "Window titles that show your name, or the name of anyone you inspect." },
            { key = "questText", owner = "World", label = "Your name in quest text",
                desc = "NPCs who say your name in quests and gossip say your chosen name, or \"adventurer\"." },
            { key = "ownHead", owner = "UnitFrames", label = "Your name above your head", tag = HIDE_ONLY,
                desc = "The game draws these names itself, so they can be hidden but not renamed." },
        } },
        { title = "Other players", rows = {
            { key = "targetFrames", owner = "UnitFrames", label = "Target, target of target and focus",
                desc = "In dungeons the game sometimes won't say who a target of target is, so it shows \"Player\"." },
            { key = "groupFrames", owner = "UnitFrames", label = "Party and raid frames",
                desc = "Party frames, raid-style frames, the Raid tab and pulled-out groups. Safe in combat." },
            { key = "nameplates", owner = "UnitFrames", label = "Nameplates", tag = EXPERIMENTAL,
                desc = "A few plates in dungeons are locked by the game and keep their names." },
            { key = "otherHeads", owner = "UnitFrames", label = "Names, guilds and titles above heads", tag = HIDE_ONLY,
                desc = "Hidden while private mode is on, then put back as they were." },
            { key = "tooltips", owner = "World", label = "Player tooltips", tag = EXPERIMENTAL,
                desc = "Name, guild and title lines. Needs one check in game that it causes no errors." },
            { key = "craftedBy", owner = "World", label = "\"Made by\" on crafted items",
                desc = "Item tooltips and links stop saying who made the item." },
            { key = "petNames", owner = "UnitFrames", label = "Other players' pets",
                desc = "Pets on party and raid frames show \"Pet\"." },
        } },
    },
    chat = {
        { title = "Names", rows = {
            -- Two columns, filled row by row: "Leave public channels as they
            -- are" sits right under "Swap names in chat", the choice below both.
            { key = "chatNames", owner = "Chat", label = "Swap names in chat",
                desc = "Names in every channel, emotes and system lines. Works in the open world and cities." },
            { key = "whispers", owner = "Chat", label = "Hide whispers",
                desc = "Whispers and Battle.net whispers stay out of chat while private mode is on. A whisper can still open "
                    .. "an empty whisper tab." },
            { key = "publicChannels", owner = "Chat", label = "Leave public channels as they are",
                desc = "Names in Trade, General and Looking for Group show as normal, so you can read who's selling and "
                    .. "chatting. Your own name is still swapped." },
            { key = "cleanOld", owner = "Chat", label = "Clean lines already in chat",
                desc = "Names already in chat are cleaned when you turn it on. They don't come back after." },
            { key = "instChat", owner = "Chat", label = "In dungeons and raids", default = "names",
                options = { { key = "names", label = "Hide names" }, { key = "chat", label = "Hide chat" },
                    { key = "leave", label = "Leave as is" } },
                desc = "The game locks chat in dungeons, raids and battlegrounds. Hide names turns each locked line into "
                    .. "\"[Party] (hidden)\" and Hide chat takes it out. Those lines don't come back." },
        } },
        { title = "Giveaways", rows = {
            { key = "channels", owner = "Chat", label = "Channel names",
                desc = "\"General - Stormwind\" becomes \"General\", so chat doesn't say where you are." },
            { key = "timestamps", owner = "Chat", label = "Chat timestamps",
                desc = "Turned off while private, since they show your time zone." },
            { key = "bubbles", owner = "Chat", label = "Chat bubbles", tag = HIDE_ONLY,
                desc = "Speech bubbles above heads, which can name people." },
        } },
    },
    social = {
        { title = "Friends", rows = {
            { key = "friends", owner = "Social", label = "Friends list and your BattleTag",
                desc = "Character names, Battle.net names, notes and your own BattleTag at the top. Hovering a card in "
                    .. "the newer Friends window still shows them." },
            { key = "bnToasts", owner = "Social", label = "\"Came online\" pop-ups",
                desc = "Battle.net pop-ups say \"A friend\" instead of a name." },
            { key = "whoList", owner = "Social", label = "/who, ignore and recent players", tag = EXPERIMENTAL,
                desc = "Names in these lists. A very long name can still show in its hover tooltip." },
        } },
        { title = "Guild", rows = {
            { key = "roster", owner = "Social", label = "Guild roster and notes",
                desc = "Member names, the details panel, and public and officer notes." },
            { key = "news", owner = "Social", label = "Guild news and message of the day",
                desc = "The news feed, and the guild message, which officers can write anything in." },
            { key = "guildName", owner = "Social", label = "Your guild's name",
                desc = "Your guild name in the guild window and on your character." },
        } },
        { title = "Other", rows = {
            { key = "mail", owner = "Social", label = "Mail",
                desc = "Sender names in your inbox and letters, and the names suggested when sending." },
            { key = "groupFinder", owner = "Social", label = "Group finder", tag = EXPERIMENTAL,
                desc = "Leader names, the hover box and comments. The right-click menu title can't be changed." },
            { key = "calendar", owner = "Social", label = "Calendar",
                desc = "Invites and who made each event." },
        } },
    },
    windows = {
        { title = "Pop-ups", rows = {
            { key = "popups", owner = "Windows", label = "Invites, duels, trades, summons and res",
                desc = "Pop-ups say \"A player\". A summon also hides where you're going." },
            { key = "readyCheck", owner = "Windows", label = "Ready checks",
                desc = "The ready check pop-up. Its lines in chat follow your chat choices." },
            { key = "menus", owner = "Windows", label = "Right-click player menus",
                desc = "The name at the top of the menu when you right-click a player." },
        } },
        { title = "Windows", rows = {
            { key = "trade", owner = "Windows", label = "Trade window",
                desc = "Your name and your trading partner's." },
            { key = "loot", owner = "Windows", label = "Loot and rolls",
                desc = "The master loot list, roll history and loot lines in chat." },
            { key = "meter", owner = "Windows", label = "Damage meter",
                desc = "Player names in the meter, yours included." },
            { key = "professions", owner = "Windows", label = "Linked professions",
                desc = "\"Tailoring (name)\" when you open someone's profession link." },
            { key = "scoreboard", owner = "Windows", label = "Battleground scoreboard", tag = EXPERIMENTAL,
                desc = "Names on the scoreboard and results, once battlegrounds are in Forever." },
        } },
    },
    world = {
        { title = "Where you are", rows = {
            { key = "zoneText", owner = "World", label = "Zone name on the minimap",
                desc = "The zone name above the minimap and its hover text." },
            { key = "coords", owner = "World", label = "Coordinates",
                desc = "Coordinates on the minimap and the world map." },
            { key = "zonePopups", owner = "World", label = "Big zone announcements",
                desc = "The zone names that appear in the middle of the screen." },
            { key = "clock", owner = "World", label = "Clock",
                desc = "The minimap clock, which shows your time zone." },
            { key = "worldMap", owner = "World", label = "World map", default = "leave",
                options = { { key = "hide", label = "Keep closed" }, { key = "leave", label = "Leave as is" } },
                desc = "The map opens on your zone with your arrow on it, so it can stay closed while private mode is on." },
        } },
        { title = "Other", rows = {
            { key = "gold", owner = "World", label = "Gold",
                desc = "Your gold in bags, mail and vendors." },
        } },
    },
}

-- The Good to know page.
P.LIMITS = {
    { title = "Chat in dungeons, raids and battlegrounds", text = "The game locks names there. Hide names turns each locked line "
        .. "into \"[Party] (hidden)\", and Hide chat takes it out. Those lines don't come back." },
    { title = "Names above heads", text = "The game draws them itself, so they can be hidden but never renamed." },
    { title = "A few hover tooltips", text = "Cards and Quick Join groups in the newer Friends window, Raid tab buttons, guild "
        .. "roster rows, group dots on the world map, the mail icon by the minimap, calendar days, the roll history's "
        .. "\"Waiting on\" line, scoreboard names and some long names in lists. Avoid hovering them on stream." },
    { title = "Healer names on heal numbers", text = "Untick friendly healer names in the game's Combat options before you "
        .. "stream. An addon can't change that setting without causing errors." },
    { title = "Some right-click menus", text = "The group finder's and Quick Join's right-click titles can't be changed." },
    { title = "What others see", text = "/who, inspecting you and the armory are the server's. Nothing here changes them." },
    { title = "Arenas", text = "Not in Forever yet. Covered when they arrive." },
}

-- How private mode turns on, and how names look while it is.
P.MODES = {
    { key = "key", label = "With its key", help = "Press its key, or type /privacy on, to turn it on and off." },
    { key = "shots", label = "For screenshots", tag = EXPERIMENTAL,
        help = "Everything hides for the moment you press Print Screen, then comes straight back." },
    { key = "always", label = "Always, from login", help = "On every time you log in. For streaming." },
}
P.STYLES = {
    { key = "class", label = "Class name", help = "Names become the class name in its colour, like Rogue or Mage." },
    { key = "player", label = "Player", help = "Every name becomes Player." },
    { key = "hidden", label = "Hidden", help = "Names are left blank." },
}
-- The colour of your typed name. "game": none of ours, so each place keeps
-- the colour the game gives it.
P.COLOURS = {
    { key = "game", label = "Game's own" },
    { key = "accent", label = "Purple" },
    { key = "class", label = "Your class colour" },
    { key = "white", label = "White" },
}
P.COLOUR_HELP = "The colour of your name and BattleTag while private. Game's own keeps whatever colour the game gives it in each place."
-- Settings that change how names look: every module hears of a change to
-- one while private, and re-labels what's showing.
P.NAME_KEYS = { nameStyle = true, myName = true, myColour = true, myTag = true }
-- The Overview's Extras: the eye and the minimap button, side by side.
P.EYE_ROW = { key = "eye", label = "Show a small eye",
    desc = "A small eye at the top of the screen while private mode is on, so you know it's working. It hides itself in "
        .. "screenshots, but stream viewers can see it, so you can turn it off." }
P.MINIMAP_ROW = { key = "minimap", label = "Show a minimap button",
    desc = "Left-click turns private mode on or off, right-click opens these settings, and you can drag it round the minimap. "
        .. "It hides itself in screenshots." }
-- Where the minimap button starts: degrees anticlockwise from the minimap's
-- right, so 180 is its left. A spot of its own, clear of where Squirt's
-- other addons put theirs.
P.MINIMAP_ANGLE = 165
P.RELOAD_NOTE = "Some things only come back fully after a /reload."

-- Every row by its key, and the keys in the window's order.
P.ROWS, P.KEYS = {}, {}
for _, page in ipairs(P.PAGES) do
    for _, section in ipairs(P.SECTIONS[page.key] or {}) do
        for _, row in ipairs(section.rows) do
            row.page = page.key
            P.ROWS[row.key] = row
            P.KEYS[#P.KEYS + 1] = row.key
        end
    end
end

-- Settings -------------------------------------------------------------------------------

local OFF_BY_DEFAULT = { cleanOld = true, whispers = true, gold = true, clock = true, publicChannels = true }
-- Settings an earlier build had, cleared from the saved variables.
local RETIRED = { "combatText" }
P.DEFAULTS = { mode = "key", nameStyle = "class", myName = "", myColour = "game", myTag = "", eye = true, minimap = true,
    minimapAngle = P.MINIMAP_ANGLE }
for key, row in pairs(P.ROWS) do
    if row.options then
        P.DEFAULTS[key] = row.default
    else
        P.DEFAULTS[key] = not OFF_BY_DEFAULT[key]
    end
end

local function Listed(list, value)
    for _, item in ipairs(list) do
        if item.key == value then return true end
    end
    return false
end

local function Valid(key, value)
    local default = P.DEFAULTS[key]
    if default == nil then return false end
    if key == "mode" then return Listed(P.MODES, value) end
    if key == "nameStyle" then return Listed(P.STYLES, value) end
    if key == "myColour" then return Listed(P.COLOURS, value) end
    if key == "myName" then return type(value) == "string" and #value <= P.NAME_MAX * 4 end
    if key == "myTag" then return type(value) == "string" and #value <= P.TAG_MAX * 4 end
    -- A number round the circle (never NaN or endless, which fail both).
    if key == "minimapAngle" then return type(value) == "number" and value >= 0 and value < 360 end
    local row = P.ROWS[key]
    if row and row.options then return Listed(row.options, value) end
    return type(value) == type(default)
end
P.Valid = Valid

-- A typed name made safe to show: no escape codes or control characters,
-- spaces trimmed and squeezed, and no more letters than most (P.NAME_MAX
-- if not given).
function P:CleanName(text, most)
    if type(text) ~= "string" or P.IsSecret(text) then return "" end
    most = most or P.NAME_MAX
    text = text:gsub("|", ""):gsub("[%c]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    local letters, cut = 0, #text
    for i = 1, #text do
        local byte = text:byte(i)
        if byte < 128 or byte >= 192 then
            letters = letters + 1
            if letters > most then
                cut = i - 1
                break
            end
        end
    end
    return (text:sub(1, cut):gsub(" $", ""))
end

-- A typed BattleTag ("Your BattleTag becomes"), made safe the same way.
function P:CleanTag(text)
    return P:CleanName(text, P.TAG_MAX)
end

local db
local loaded = false
local private = false -- private mode is on
local shooting = false -- a screenshot is being taken
local shotOn = false -- private mode came on for this screenshot alone
local shotOnly = false -- the same, known from the moment it turns on

function P:Get(key)
    local value = db and db[key]
    if value == nil then return P.DEFAULTS[key] end
    return value
end

function P:Private()
    return private
end

function P:Shooting()
    return shooting
end

-- Whether private mode is on only for the screenshot being taken ("For
-- screenshots"), so changes that can't be put back are skipped.
function P:ShotOnly()
    return private and shotOnly
end

-- Whether a setting's surface should be private right now: private mode is
-- on and the row is ticked (or, for a choice, not "leave").
function P:IsOn(key)
    if not private then return false end
    local row = P.ROWS[key]
    if row and row.options then return P:Get(key) ~= "leave" end
    return P:Get(key) == true
end

-- Chat and the footer --------------------------------------------------------------------

function P:Print(text)
    print("|cff" .. P.ACCENT_HEX .. P.TITLE .. "|r: " .. text)
end

-- Says something once: in the window's footer while it's open, else in chat.
function P:Say(text)
    if P.window and P.window:IsVisible() and P.window.Say then
        P.window:Say(text)
    else
        P:Print(text)
    end
end

local reported = {}
-- A module's error, said once in chat; the other modules carry on.
local function Report(name, err)
    name = tostring(name or "?")
    if reported[name] then return end
    reported[name] = true
    local text = ""
    if type(err) == "string" and not P.IsSecret(err) then text = err:match("^[^\n]*") or "" end
    if #text > 160 then text = text:sub(1, 160) .. "..." end
    P:Print(("The %s part hit an error, so it may miss some names. %s"):format(name, text))
end
P.Report = Report

-- Listeners (the window, the eye, the minimap button) hear about every
-- change: a setting's key, "private", "shot" or "reset".
local listeners = {}
function P:Listen(listener)
    listeners[#listeners + 1] = listener
end

local function Notify(what)
    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener, what)
        if not ok then Report("window", err) end
    end
end

-- Modules ----------------------------------------------------------------------------------

P.modules = {}
local byName = {}

-- A surface module, made on first ask. Modules are told what to do in
-- registration order (the TOC's), each inside its own pcall.
function P:Module(name)
    if byName[name] then return byName[name] end
    local module = { name = name }
    byName[name] = module
    P.modules[#P.modules + 1] = module
    return module
end

function P:ModuleFor(key)
    local row = P.ROWS[key]
    return row and byName[row.owner]
end

local function Run(module, method, ...)
    if module.broken then return false end
    local fn = module[method]
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, module, ...)
    if not ok then Report(module.name, err) end
    return ok
end

-- A function that can't break anything else: an error is said once and
-- swallowed (returning nothing). For hooks, filters and post-calls.
function P:Guard(module, fn)
    local name = type(module) == "table" and module.name or module
    local function Pass(ok, ...)
        if ok then return ... end
        Report(name, (...))
    end
    return function(...)
        return Pass(pcall(fn, ...))
    end
end

-- Runs fn once the named Blizzard addon has loaded: now, if it already has.
local waiting = {}
function P:OnAddOnLoaded(name, fn, module)
    local check = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local done = false
    if check then
        local _, isLoaded = check(name)
        done = isLoaded and true or false
    end
    if done then
        local ok, err = pcall(fn)
        if not ok then Report(module and module.name or name, err) end
        return
    end
    waiting[name] = waiting[name] or {}
    table.insert(waiting[name], { fn = fn, module = module })
end

function P:InCombat()
    return InCombatLockdown() and true or false
end

-- The record of changes ----------------------------------------------------------------------
-- Everything a module changes through these helpers is filed under a
-- setting's key and put back when that key turns off or private mode does.

local records = {} -- key: { texts = { [region] = rec }, alphas = { [region] = alpha }, undo = { [id] = fn } }
local reloadKeys, reloadDue = {}, false

local function Book(key)
    local book = records[key]
    if not book then
        book = { texts = {}, alphas = {}, undo = {} }
        records[key] = book
    end
    return book
end

local function SameText(a, b)
    return (a or "") == (b or "")
end

-- A region's text colour, or nil when the game won't say (a secret).
local function ColourOf(region)
    local r, g, b, a = region:GetTextColor()
    if P.IsSecret(r) or P.IsSecret(g) or P.IsSecret(b) or P.IsSecret(a) then return nil end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return { r, g, b, a }
end

-- Whether a region still shows this colour (ours, put on earlier).
local function ShowsColour(region, colour)
    local now = ColourOf(region)
    if not now then return false end
    for i = 1, 3 do
        if math.abs(now[i] - colour[i]) > .005 then return false end
    end
    return true
end

-- Sets a region's text (and colour, given r, g, b), keeping the game's own
-- text to put back. The original is taken afresh each time the game has
-- written a new text since ours, and never kept when it's a secret. The
-- game's colour is kept from when ours first goes on (afresh if the game has
-- painted its own since); with no colour given, ours comes off at once and
-- the game's is back (your name in the game's own colour).
function P:SwapText(key, region, text, r, g, b)
    if not region then return end
    local book = Book(key)
    local rec = book.texts[region]
    if not rec then
        rec = {}
        book.texts[region] = rec
    end
    local current = region:GetText()
    if P.IsSecret(current) then
        rec.known, rec.original = false, nil
    elseif not rec.set or not SameText(current, rec.ours) then
        rec.known, rec.original = true, current
    end
    if rec.tint and not ShowsColour(region, rec.tint) then rec.colour, rec.tint = nil, nil end
    if r then
        if not rec.tint then rec.colour = ColourOf(region) end
        rec.tint = { r, g, b }
    elseif rec.tint then
        local kept = rec.colour
        rec.colour, rec.tint = nil, nil
        if kept then region:SetTextColor(kept[1], kept[2], kept[3], kept[4]) end
    end
    rec.ours, rec.set = text, true
    region:SetText(text)
    if r then region:SetTextColor(r, g, b) end
end

-- Whether a region already shows this text in this colour (with no colour
-- given: with none of ours left on it), so a swap would change nothing.
function P:Showing(key, region, text, r, g, b)
    if not region then return false end
    local current = region:GetText()
    if P.IsSecret(current) or current ~= text then return false end
    if r then return ShowsColour(region, { r, g, b }) end
    local book = records[key]
    local rec = book and book.texts[region]
    return not (rec and rec.tint and ShowsColour(region, rec.tint))
end

-- Sets a tooltip line's text (and colour), keeping nothing to put back: the
-- game writes every line afresh each time a tooltip shows, and its lines are
-- reused by every later tooltip, so an old text put back could land in
-- another tooltip. Only from inside a TooltipDataProcessor post-call.
function P:SetTransient(region, text, r, g, b)
    if not region then return end
    region:SetText(text)
    if r then region:SetTextColor(r, g, b) end
end

-- Hides a region by its alpha (never a protected frame), keeping the alpha
-- to put back.
function P:HideRegion(key, region)
    if not region then return end
    local alphas = Book(key).alphas
    if alphas[region] == nil then
        local alpha = region:GetAlpha()
        alphas[region] = (type(alpha) == "number" and not P.IsSecret(alpha)) and alpha or 1
    end
    region:SetAlpha(0)
end

-- Anything else to undo when the key turns off: fn runs once. id keeps one
-- undo per thing however often it's asked for.
function P:OnRestore(key, id, fn)
    Book(key).undo[id] = fn
end

-- Something under this key can only come back fully after a /reload: said
-- once when it's put back.
function P:NeedsReload(key)
    reloadKeys[key] = true
end

-- CVars -------------------------------------------------------------------------------------
-- The game's own settings, changed only out of combat (queued till it ends),
-- with each one's original kept in the saved variables, so a crash or logout
-- while private still gets it back at the next login.

local cvarUsers = {} -- name: { [key] = true }, the keys that want it changed
local pendingCVars = {} -- name: value or RESTORE, waiting for combat to end
local RESTORE = {}
local events -- the core's event frame

-- CVars the game keeps a cached copy of (CVarCallbackRegistry:SetCVarCachable,
-- and the combat text list), from Forever's own code. A change made by an
-- addon reaches that cache from the addon's code, which taints the cached
-- value until the next change: the game's own code that reads it (heal
-- numbers, nameplates) then fails on secret values, even after private mode
-- is off. Never written; Tools/TestRules.mjs keeps this list complete.
P.CACHABLE_CVARS = {}
for _, name in ipairs({
    "countdownForCooldowns", "buffDurations", "consolidateBuffs", "collapseExpandBuffs", "displayTemporaryEnchantIcon",
    "GamepadShowAutoAuraTooltip", "externalDefensivesEnabled", "cooldownViewerEnabled", "cooldownViewerShowUnlearned",
    "damageMeterEnabled", "showArenaEnemyPets", "showCastableBuffs", "showDispelDebuffs", "rotateMinimap",
    "disableSuggestedLevelActivityFilter", "colorblindMode", "showSwingTimer", "pvpFramesDisplayClassColor",
    "spellDiminishPVPEnemiesEnabled", "showTargetOfTarget", "threatShowNumeric", "showPartyPets", "noBuffDebuffFilterOnTarget",
    "movePadLocked", "movePadInPressAndHoldMode",
    -- Combat text (CombatTextCachableCVars).
    "floatingCombatTextLowManaHealth_v2", "floatingCombatTextAuras_v2", "floatingCombatTextCombatState_v2",
    "floatingCombatTextDodgeParryMiss_v2", "floatingCombatTextDamageReduction_v2", "floatingCombatTextRepChanges_v2",
    "floatingCombatTextReactives_v2", "floatingCombatTextFriendlyHealers_v2", "floatingCombatTextComboPoints_v2",
    "floatingCombatTextEnergyGains_v2", "floatingCombatTextPeriodicEnergyGains_v2", "floatingCombatTextFloatMode_v2",
    "floatingCombatTextHonorGains_v2",
    -- Nameplates (NamePlateConstants).
    "nameplateForceShowUnitName", "nameplateInfoDisplay", "nameplateCastBarDisplay", "nameplateThreatDisplay",
    "nameplateEnemyNpcAuraDisplay", "nameplateEnemyPlayerAuraDisplay", "nameplateFriendlyPlayerAuraDisplay",
    "nameplateShowDebuffsOnFriendly", "nameplateDebuffPadding", "nameplateAuraScale", "nameplateSize", "nameplateStyle",
    "nameplateSimplifiedTypes", "nameplateShowFriendlyNpcs", "nameplateShowOnlyNameForFriendlyPlayerUnits",
    "nameplateUseClassColorForFriendlyPlayerUnitNames", "nameplateShowAllPersonalAuras", "SoftTargetNameplateSize",
    "SoftTargetIconEnemy", "SoftTargetIconFriend", "SoftTargetIconInteract",
    -- Encounter timeline and warnings, narration.
    "encounterTimelineEnabled", "encounterTimelineIconographyEnabled", "encounterTimelineIconographyHiddenMask",
    "encounterTimelineHighlightDuration", "combatWarningsEnabled", "encounterWarningsEnabled", "encounterWarningsLevel",
    "accessibilityScreenNarrationEnabled", "accessibilityScreenNarrationVoice", "accessibilityScreenNarrationSpeechRate",
    "accessibilityScreenNarrationSpeechVolume",
    -- Gamepad.
    "GamepadActionBarLeftRightDelay", "GamepadActionBarTopBottomDelay", "GamepadTargetingModifierVisualDelay",
    "GamepadCompassCustomFilterFriendly", "GamepadCompassCustomFilterEnemy", "GamepadCompassCustomFilterBoss",
    "GamepadCompassCustomFilterParty", "GamepadCompassCustomFilterCritter", "GamepadHudModifierUsesToggle",
    "GamepadSwapTargetModifiers", "GamepadTargetingMode", "GamepadSwapFriendlyTargetActions", "GamepadSwapHostileTargetActions",
    "GamepadTabHostileTargetAction", "GamepadTabFriendlyTargetAction",
}) do P.CACHABLE_CVARS[name] = true end

-- Whether the game caches this CVar: the list above, or the game's own
-- registry (only read) for any it marks later.
local function Cachable(name)
    if P.CACHABLE_CVARS[name] then return true end
    local registry = CVarCallbackRegistry
    local cachable = type(registry) == "table" and registry.cachable
    if type(cachable) ~= "table" then return false end
    local marked = cachable[name]
    return not P.IsSecret(marked) and marked == true
end

local function ReadCVar(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if not get then return nil end
    local ok, value = pcall(get, name)
    if not ok or value == nil or P.IsSecret(value) then return nil end
    return tostring(value)
end

local function WriteCVar(name, value)
    if InCombatLockdown() then
        pendingCVars[name] = value
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pendingCVars[name] = nil
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    local backup = db.cvarBackup
    if value == RESTORE then
        local original = backup[name]
        backup[name] = nil
        if original ~= nil and ReadCVar(name) ~= original then pcall(set, name, original) end
        return
    end
    local now = ReadCVar(name)
    if now == nil then return end
    if backup[name] == nil then backup[name] = now end
    if now ~= value then pcall(set, name, value) end
end

-- Changes a CVar for this key while private. False if this client has no
-- such CVar, or if it's one the game caches (never changed: see above).
function P:SetCVar(key, name, value)
    if not db or type(name) ~= "string" or Cachable(name) or ReadCVar(name) == nil then return false end
    cvarUsers[name] = cvarUsers[name] or {}
    cvarUsers[name][key] = true
    WriteCVar(name, tostring(value))
    return true
end

local function ReleaseCVars(key)
    for name, users in pairs(cvarUsers) do
        if users[key] then
            users[key] = nil
            if next(users) == nil then
                cvarUsers[name] = nil
                WriteCVar(name, RESTORE)
            end
        end
    end
end

-- Originals left from last time (a crash, or a logout while private): all
-- of them back, or, with private mode on again, those nothing uses now.
local function RecoverCVars(keepUsed)
    for name in pairs(db.cvarBackup) do
        if not (keepUsed and cvarUsers[name]) then WriteCVar(name, RESTORE) end
    end
end

-- Logging out or a /reload: every CVar back to its original, so names and
-- the rest come back even if this addon is turned off before the next login
-- (private mode comes back on at login as it was, with fresh originals).
-- Not in combat: those stay saved and are put back at the next login.
local function LogoutCVars()
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not set or InCombatLockdown() then return end
    for name, original in pairs(db.cvarBackup) do
        if ReadCVar(name) ~= original then pcall(set, name, original) end
        if ReadCVar(name) == original then db.cvarBackup[name] = nil end
    end
end

-- Putting back --------------------------------------------------------------------------------

local function PutText(region, rec)
    if not rec.known then return end
    local current = region:GetText()
    if P.IsSecret(current) or not SameText(current, rec.ours) then return end
    region:SetText(rec.original or "")
    -- The game's colour, unless it has painted its own over ours since.
    if rec.colour and rec.tint and ShowsColour(region, rec.tint) then
        region:SetTextColor(rec.colour[1], rec.colour[2], rec.colour[3], rec.colour[4])
    end
end

-- Puts back everything filed under this key.
function P:Restore(key)
    local row = P.ROWS[key]
    local owner = row and row.owner or key
    local book = records[key]
    if book then
        records[key] = nil
        for region, rec in pairs(book.texts) do
            local ok, err = pcall(PutText, region, rec)
            if not ok then Report(owner, err) end
        end
        for region, alpha in pairs(book.alphas) do
            local ok, err = pcall(region.SetAlpha, region, alpha)
            if not ok then Report(owner, err) end
        end
        for _, fn in pairs(book.undo) do
            local ok, err = pcall(fn)
            if not ok then Report(owner, err) end
        end
    end
    ReleaseCVars(key)
    if reloadKeys[key] then
        reloadKeys[key] = nil
        reloadDue = true
    end
end

local function RestoreAll()
    local keys = {}
    for key in pairs(records) do keys[key] = true end
    for _, users in pairs(cvarUsers) do
        for key in pairs(users) do keys[key] = true end
    end
    for key in pairs(reloadKeys) do keys[key] = true end
    for key in pairs(keys) do P:Restore(key) end
end

local function SayReloadNote()
    if not reloadDue then return end
    reloadDue = false
    P:Say(P.RELOAD_NOTE)
end

-- Private mode ----------------------------------------------------------------------------------

-- Turns private mode on or off. why: "shot" for a screenshot's moment
-- (not remembered over a /reload), anything else otherwise.
function P:SetPrivate(on, why)
    on = on and true or false
    if not loaded or on == private then return false end
    private = on
    shotOnly = on and why == "shot"
    if why ~= "shot" then db.wasOn = on end
    if on then
        for _, module in ipairs(P.modules) do
            if not module.setUp and not module.broken then
                module.setUp = true
                if not Run(module, "Setup") then module.broken = true end
            end
            Run(module, "Apply", true)
        end
    else
        for i = #P.modules, 1, -1 do Run(P.modules[i], "Apply", false) end
        RestoreAll()
    end
    SayReloadNote()
    Notify("private")
    return true
end

function P:Toggle()
    return P:SetPrivate(not private, "toggle")
end

-- Changes a setting. While private, the module that owns it is told at
-- once; a name setting tells them all.
function P:Set(key, value)
    if key == "myName" then value = P:CleanName(value) end
    if key == "myTag" then value = P:CleanTag(value) end
    if not db or not Valid(key, value) or P:Get(key) == value then return false end
    db[key] = value
    if private then
        local row = P.ROWS[key]
        if row then
            if not P:IsOn(key) then P:Restore(key) end
            local owner = byName[row.owner]
            if owner then Run(owner, "Apply", true, key) end
        elseif P.NAME_KEYS[key] then
            for _, module in ipairs(P.modules) do Run(module, "Apply", true, key) end
        end
        SayReloadNote()
    end
    Notify(key)
    return true
end

-- "Reset all settings" (the Overview, after the window asks). Private mode
-- goes off first, the usual way, so everything it changed is put back; then
-- every saved setting is dropped, so each is its default again (your name and
-- BattleTag empty, with its key). Only CVar originals still waiting to go back
-- (in a fight) are kept, so they go back once it ends. The key binding is the
-- game's, so it stays.
function P:Reset()
    if not loaded then return false end
    P:SetPrivate(false, "reset")
    local backup = db.cvarBackup
    for key in pairs(db) do db[key] = nil end
    db.cvarBackup = type(backup) == "table" and backup or {}
    db.wasOn = false
    Notify("reset")
    P:Print("Settings reset.")
    return true
end

-- The key binding (Bindings.xml) and /privacy ---------------------------------------------------

BINDING_HEADER_FEPRIVACY = P.TITLE
BINDING_NAME_FEPRIVACY_TOGGLE = "Toggle private mode"

function ForeverEnhancedPrivacy_Toggle()
    P:Toggle()
end

local function Slash(msg)
    msg = type(msg) == "string" and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if msg == "" then
        if P.ToggleWindow then P.ToggleWindow() end
    elseif msg == "on" or msg == "off" or msg == "toggle" then
        local on = msg == "on" or (msg == "toggle" and not private)
        P:SetPrivate(on, "slash")
        P:Print(private and "Private mode is on." or "Private mode is off.")
    elseif msg == "minimap" then
        -- The minimap button's own tick (the Overview's Extras), for when
        -- it's hidden and the window is hard to reach.
        P:Set("minimap", not P:Get("minimap"))
        P:Print(P:Get("minimap") and "The minimap button is back."
            or ("The minimap button is hidden. " .. P.SLASH .. " minimap brings it back."))
    else
        P:Print(P.SLASH .. " opens the settings. " .. P.SLASH .. " on, off or toggle turns private mode on or off. " .. P.SLASH
            .. " minimap shows or hides the minimap button.")
    end
end

-- Options > AddOns -------------------------------------------------------------------------------

local function BuildOptionsEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local canvas = CreateFrame("Frame")
    canvas:SetSize(600, 200)
    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(P.TITLE)
    local about = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    about:SetWidth(560)
    about:SetJustifyH("LEFT")
    about:SetText("A private mode for streams and screenshots: names, chat giveaways and where you are, hidden or swapped. Type "
        .. P.SLASH .. ", or click below, for the settings.")
    local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    open:SetSize(160, 24)
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -14)
    open:SetText("Open settings")
    open:SetScript("OnClick", function() if P.ShowWindow then P.ShowWindow() end end)
    local category = Settings.RegisterCanvasLayoutCategory(canvas, P.TITLE)
    Settings.RegisterAddOnCategory(category)
end

-- Startup -------------------------------------------------------------------------------------------

-- Game settings an earlier build changed that the game caches, by what the
-- options call them.
local LEFT_CHANGED = { floatingCombatTextFriendlyHealers_v2 = "friendly healer names, in the Combat options",
    nameplateForceShowUnitName = "names always shown on nameplates" }
local leftChanged = {}

local function Load()
    ForeverEnhancedPrivacyDB = type(ForeverEnhancedPrivacyDB) == "table" and ForeverEnhancedPrivacyDB or {}
    db = ForeverEnhancedPrivacyDB
    for key, value in pairs(db) do
        if P.DEFAULTS[key] ~= nil and not Valid(key, value) then db[key] = nil end
    end
    if db.myName ~= nil then db.myName = P:CleanName(db.myName) end
    if db.myTag ~= nil then db.myTag = P:CleanTag(db.myTag) end
    for _, key in ipairs(RETIRED) do db[key] = nil end
    if type(db.cvarBackup) ~= "table" then db.cvarBackup = {} end
    for name, value in pairs(db.cvarBackup) do
        if type(name) ~= "string" or type(value) ~= "string" then
            db.cvarBackup[name] = nil
        elseif Cachable(name) then
            -- Left by an earlier build: putting it back from here would do the
            -- same harm, so it's dropped and you're told to set it by hand.
            db.cvarBackup[name] = nil
            if ReadCVar(name) ~= value then leftChanged[#leftChanged + 1] = LEFT_CHANGED[name] or name end
        end
    end
    if type(db.wasOn) ~= "boolean" then db.wasOn = false end
    loaded = true

    SLASH_FEPRIVACY1 = P.SLASH
    SlashCmdList.FEPRIVACY = Slash
    BuildOptionsEntry()
end

-- The first time into the world: "always" turns private mode on, and so
-- does a /reload while it was on; then any CVar left changed from last
-- time is put back.
local function Login(isInitialLogin, isReloadingUi)
    if P:Get("mode") == "always" or (isReloadingUi and not isInitialLogin and db.wasOn) then
        P:SetPrivate(true, "login")
    else
        db.wasOn = false
    end
    RecoverCVars(private)
    for _, what in ipairs(leftChanged) do
        P:Print("An earlier version turned off " .. what .. ". Turn it back on in the game's options if you want it.")
    end
    leftChanged = {}
end

events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("SCREENSHOT_STARTED")
events:RegisterEvent("SCREENSHOT_SUCCEEDED")
events:RegisterEvent("SCREENSHOT_FAILED")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON then
            Load()
        elseif waiting[name] then
            local list = waiting[name]
            waiting[name] = nil
            for _, entry in ipairs(list) do
                local ok, err = pcall(entry.fn)
                if not ok then Report(entry.module and entry.module.name or name, err) end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not loaded then return end
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Login(...)
    elseif event == "PLAYER_LOGOUT" then
        if loaded then LogoutCVars() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        for name, value in pairs(pendingCVars) do WriteCVar(name, value) end
    elseif event == "SCREENSHOT_STARTED" then
        shooting = true
        if loaded and P:Get("mode") == "shots" and not private then shotOn = P:SetPrivate(true, "shot") end
        Notify("shot")
    elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
        shooting = false
        if shotOn then
            shotOn = false
            P:SetPrivate(false, "shot")
        end
        Notify("shot")
    end
end)
