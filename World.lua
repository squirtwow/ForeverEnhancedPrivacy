-- World: tooltips, text and where you are. Owns questText, tooltips,
-- craftedBy, zoneText, coords, zonePopups, clock, worldMap and gold.
--
-- questText: your name in quest, gossip and NPC portrait text becomes your
--   typed name, or "adventurer". Boss emotes and raid warnings in the middle
--   of the screen get names swapped as chat does (open world: the game
--   locks raid warning text in dungeons and raids).
-- tooltips: player tooltips (the name line, title included, and the guild
--   line under it: blank, or on your own tooltip your made-up guild while
--   "Your guild's name" is ticked), pet owner lines, other names in unit
--   tooltips, corpse tooltips, and the names on the minimap's group dots.
--   The world map's group dots build their hover outside the tooltip
--   post-calls, so they're left alone (the Good to know page says so).
-- craftedBy: "<Made by Name>" on every item tooltip, chat links included.
-- Tooltip lines change only inside TooltipDataProcessor post-calls,
-- registered once at load, and nothing is kept to put back: the game writes
-- every line afresh each time a tooltip shows.
-- zoneText: the zone name above the minimap is blanked and its hover text
--   covered by a frame of our own (which also takes the click that opens
--   the map: M still works).
-- coords: the game's own coordinates, through their CVars.
-- zonePopups: the big zone names in the middle of the screen, hidden.
-- clock: the minimap clock shows realm time (a CVar), and its hover, which
--   always lists local time, is covered.
-- worldMap: "Keep closed" covers the world map and the zone map with a
--   curtain of our own, since an addon mustn't close Blizzard's windows.
-- gold: your own gold (bags, vendors, mail, trainers, the bank), hidden.
-- (Healer names on heal numbers are a CVar the game caches, so they're left
-- to the game's own options: the Good to know page says so.)
local _, P = ...

local M = P:Module("World")

local IsSecret = P.IsSecret

local QUEST, TIPS, MADE, ZONE, COORDS = "questText", "tooltips", "craftedBy", "zoneText", "coords"
local POPUPS, CLOCK, MAP, GOLD = "zonePopups", "clock", "worldMap", "gold"
local KEYS = { QUEST, TIPS, MADE, ZONE, COORDS, POPUPS, CLOCK, MAP, GOLD }

-- Plain text, never a secret.
local function Text(value)
    if IsSecret(value) or type(value) ~= "string" then return nil end
    return value
end

-- One of the game's own texts (a global string), or our English copy.
local function GameText(name, fallback)
    return Text(_G[name]) or fallback
end

-- Hooks ----------------------------------------------------------------------------------------

-- A hook's body: nothing at all unless private mode is on and its setting
-- ticked; an error is said once and swallowed.
local function Guarded(key, fn)
    return P:Guard(M, function(...)
        if not P:IsOn(key) then return end
        return fn(...)
    end)
end

local function HookGlobal(name, key, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, Guarded(key, fn)) end
end

local function HookShow(frame, key, fn)
    if type(frame) == "table" and type(frame.HookScript) == "function" then frame:HookScript("OnShow", Guarded(key, fn)) end
end

-- Runs fn(frame) once Blizzard's frame exists: now, or when its addon loads.
local function WhenReady(addon, global, fn)
    local run = P:Guard(M, function()
        local frame = _G[global]
        if type(frame) == "table" then fn(frame) end
    end)
    if _G[global] ~= nil then
        run()
    else
        P:OnAddOnLoaded(addon, run, M)
    end
end

-- Frames of our own ----------------------------------------------------------------------------

local shields = {}

-- A cover of our own over one of Blizzard's buttons, so hovering it shows
-- nothing (its hover text gives the game away).
local function Shield(key, button)
    if type(button) ~= "table" then return end
    local shield = shields[button]
    if not shield then
        shield = CreateFrame("Frame", nil, button)
        shield:SetAllPoints(button)
        shield:SetFrameLevel(button:GetFrameLevel() + 10)
        shield:EnableMouse(true)
        shields[button] = shield
    end
    shield:Show()
    P:OnRestore(key, shield, function() shield:Hide() end)
end

local curtains = {}
local CURTAIN_TEXT = "The map is hidden while private mode is on. Press Escape to close it."

local function Curtain(map)
    local curtain = curtains[map]
    if curtain then return curtain end
    curtain = CreateFrame("Frame", nil, map)
    curtain:SetAllPoints(map)
    curtain:SetFrameLevel(math.min(map:GetFrameLevel() + 2000, 9900))
    curtain:EnableMouse(true)
    curtain:EnableMouseWheel(true)
    local back = curtain:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(curtain)
    back:SetColorTexture(.06, .06, .08, 1)
    local note = curtain:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("CENTER", curtain, "CENTER", 0, 0)
    note:SetWidth(320)
    note:SetText(CURTAIN_TEXT)
    curtains[map] = curtain
    return curtain
end

-- "Keep closed": the map stays covered while it's open.
local function ShowCurtain(map)
    if type(map) ~= "table" then return end
    local curtain = Curtain(map)
    curtain:Show()
    P:OnRestore(MAP, curtain, function() curtain:Hide() end)
end

-- Your name in quest and gossip text -----------------------------------------------------------

local QUEST_TEXTS = { "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoRewardText", "QuestProgressText",
    "GreetingText", "QuestNPCModelText" }
local QUEST_INFO = { "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoRewardText" }
local LETTER = "^[%a\128-\255]"

-- What NPCs call you: your typed name as typed; else "adventurer", with a
-- capital to start a sentence.
local function Spoken(seg, s)
    local alias = P:Get("myName")
    if type(alias) == "string" and alias ~= "" then return alias end
    local before = (seg:sub(1, s - 1):gsub("[%s\"']+$", ""))
    if before == "" or before:find("[%.!%?]$") then return "Adventurer" end
    return "adventurer"
end

-- Your first name, and "First Surname", as whole words in plain text.
local function SwapPlainMine(seg, first, surname)
    local out, pos, changed = {}, 1, false
    while true do
        local s, e = seg:find("[%a\128-\255]+", pos)
        if not s then break end
        out[#out + 1] = seg:sub(pos, s - 1)
        if seg:sub(s, e) == first then
            if surname and seg:sub(e + 1, e + 1 + #surname) == " " .. surname and not seg:find(LETTER, e + 2 + #surname) then
                e = e + 1 + #surname
            end
            out[#out + 1] = Spoken(seg, s)
            changed = true
        else
            out[#out + 1] = seg:sub(s, e)
        end
        pos = e + 1
    end
    if not changed then return seg, false end
    out[#out + 1] = seg:sub(pos)
    return table.concat(out), true
end

-- Where an escape code that starts at bar ends: links keep their data, and
-- textures, atlases, colours and Battle.net names are left alone.
local CLOSERS = { H = "|h", T = "|t", A = "|a", K = "|k" }
local function CodeEnd(text, bar)
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

-- Quest text with your name swapped (only yours: an NPC's words that happen
-- to match a guildmate's name stay as they are). Returns text, changed.
local function SwapMine(text)
    text = Text(text)
    local first, full = P:MyNames()
    if not text or not first or not text:find(first, 1, true) then return text, false end
    local surname = full ~= first and full:sub(#first + 2) or nil
    local out, i, changed = {}, 1, false
    while i <= #text do
        local bar = text:find("|", i, true)
        local stop = bar and bar - 1 or #text
        if stop >= i then
            local seg, did = SwapPlainMine(text:sub(i, stop), first, surname)
            out[#out + 1] = seg
            changed = changed or did
        end
        if not bar then break end
        local last = CodeEnd(text, bar)
        out[#out + 1] = text:sub(bar, last)
        i = last + 1
    end
    if not changed then return text, false end
    return table.concat(out), true
end

local function SwapQuest(region)
    if type(region) ~= "table" then return end
    local text, changed = SwapMine(region:GetText())
    if changed then P:SwapText(QUEST, region, text) end
end

-- A gossip row: the greeting, or an option button.
local function SwapGossipRow(row)
    if type(row) ~= "table" then return end
    if type(row.GreetingText) == "table" then return SwapQuest(row.GreetingText) end
    if type(row.GetFontString) == "function" then SwapQuest(row:GetFontString()) end
end

-- The rows of a gossip window already open.
local function SwapGossip()
    local gossip = _G.GossipFrame
    if type(gossip) ~= "table" or not gossip:IsShown() then return end
    local panel = gossip.GreetingPanel
    local box = type(panel) == "table" and panel.ScrollBox
    if type(box) ~= "table" or type(box.GetFrames) ~= "function" then return end
    if type(box.HasView) == "function" and not box:HasView() then return end
    local rows = box:GetFrames()
    if type(rows) ~= "table" then return end
    for _, row in pairs(rows) do SwapGossipRow(row) end
end

-- Gossip rows copy these mixins' methods when the gossip window first builds
-- them, which can be before private mode is first on, so these two hooks go
-- in at load. Like every hook here, they do nothing while it's off.
local function HookMixin(name, fn)
    local mixin = _G[name]
    if type(mixin) == "table" and type(mixin.Setup) == "function" then hooksecurefunc(mixin, "Setup", Guarded(QUEST, fn)) end
end
HookMixin("GossipGreetingTextMixin", SwapGossipRow)
HookMixin("GossipOptionButtonMixin", SwapGossipRow)

local function SwapQuestInfo()
    for _, name in ipairs(QUEST_INFO) do SwapQuest(_G[name]) end
end

local function HookQuests()
    HookGlobal("QuestInfo_Display", QUEST, SwapQuestInfo)
    HookGlobal("QuestFrame_UpdatePortraitText", QUEST, function() SwapQuest(_G.QuestNPCModelText) end)
    HookShow(_G.QuestFrameProgressPanel, QUEST, function() SwapQuest(_G.QuestProgressText) end)
    HookShow(_G.QuestFrameGreetingPanel, QUEST, function() SwapQuest(_G.GreetingText) end)
end

-- Boss emotes and raid warnings in the middle of the screen --------------------------------------

local function SwapCentre(fontString)
    if type(fontString) ~= "table" then return end
    local text, changed = P:ReplaceNames(fontString:GetText(), nil, true)
    if changed then P:SwapText(QUEST, fontString, text) end
end

-- Every message showing (a secret one is left alone: the game locks those).
local function SwapMessages()
    local frame = _G.RaidWarningFrame
    local pool = type(frame) == "table" and frame.fontStringPool
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
    for fontString in pool:EnumerateActive() do SwapCentre(fontString) end
end

local function HookCentre(frame)
    if type(frame.AddMessage) == "function" and not frame:IsProtected() then
        hooksecurefunc(frame, "AddMessage", Guarded(QUEST, SwapMessages))
    end
end

local function ApplyQuest()
    for _, name in ipairs(QUEST_TEXTS) do SwapQuest(_G[name]) end
    SwapGossip()
    SwapMessages()
end

-- Tooltips -------------------------------------------------------------------------------------

local LINE = {} -- Enum.TooltipDataLineType, once the post-calls are in

-- A tooltip's line by its index (lineData.lineIndex).
local function TipLine(tooltip, index)
    if type(tooltip) ~= "table" or IsSecret(index) or type(index) ~= "number" then return nil end
    if type(tooltip.GetLeftLine) == "function" then
        local line = tooltip:GetLeftLine(index)
        if type(line) == "table" then return line end
    end
    local name = Text(tooltip:GetName())
    return name and _G[name .. "TextLeft" .. index]
end

-- A line of the tooltip being built: nothing kept to put back (the game
-- rewrites it next time, and reuses it in other tooltips).
local function SwapLine(tooltip, line, text, r, g, b)
    P:SetTransient(TipLine(tooltip, line.lineIndex), text, r, g, b)
end

local function Uncoloured(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- A Lua pattern for one of the game's "%s" texts, the name captured.
local patterns = {}
local function PatternFor(format)
    local pattern = patterns[format]
    if not pattern then
        local escaped = Uncoloured(format):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        pattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
        patterns[format] = pattern
    end
    return pattern
end

-- A line made from one of the game's "%s" texts round a player's name, the
-- name swapped ("" when names are hidden); nil when it isn't one.
local function Relabel(format, text)
    local name = Uncoloured(text):match(PatternFor(format))
    if not name then return nil end
    local label = P:LabelForName(name)
    if label == "" then return "" end
    return format:format(label)
end

local OWNERS = { { "UNITNAME_TITLE_PET", "%s's Pet" }, { "UNITNAME_TITLE_MINION", "%s's Minion" },
    { "UNITNAME_TITLE_GUARDIAN", "%s's Guardian" }, { "UNITNAME_TITLE_COMPANION", "%s's Companion" },
    { "UNITNAME_TITLE_CREATION", "%s's Creation" }, { "UNITNAME_TITLE_CHARM", "%s's Charm" } }

local function OwnerText(text)
    for _, owner in ipairs(OWNERS) do
        local swapped = Relabel(GameText(owner[1], owner[2]), text)
        if swapped then return swapped end
    end
end

-- Any other names in a line: known names (your group, guild and friends,
-- and players you've hovered) and yours.
local function SwapNamesIn(tooltip, line)
    local text = Text(line.leftText)
    if not text or text == "" then return end
    local swapped = line.type == LINE.UnitOwner and OwnerText(text) or nil
    if not swapped then
        local replaced, changed = P:ReplaceNames(text)
        if changed then swapped = replaced end
    end
    if swapped then SwapLine(tooltip, line, swapped) end
end

-- Notes a hovered player's name, so it's swapped in other text too.
local function LearnUnit(token)
    local ok, isPlayer = pcall(UnitIsPlayer, token)
    if not ok or IsSecret(isPlayer) or not isPlayer then return end
    local named, first, surname = pcall(UnitName, token)
    first, surname = named and Text(first), named and Text(surname)
    if not first then return end
    local classed, _, classFile = pcall(UnitClass, token)
    P:Learn(surname and surname ~= "" and (first .. " " .. surname) or first, classed and Text(classFile) or nil)
end

-- What the name line becomes, or nil to leave it (an NPC, or a unit the game
-- won't tell us about).
local function UnitLabel(data, line)
    local token = line.unitToken
    if not IsSecret(token) and type(token) == "string" then
        LearnUnit(token)
        return P:NameFor(token)
    end
    local guid = Text(data.guid)
    if guid then
        if guid:find("^Player%-") then return P:LabelForGUID(guid) end
        return nil
    end
    return P:NameFor("mouseover")
end

-- Whether the game plainly says so (never a secret).
local function Yes(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, answer = pcall(fn, ...)
    return ok and not IsSecret(answer) and answer == true
end

-- Whether a unit tooltip is yours (hovering yourself), found the way its
-- name line is: by token, else by GUID, else the unit under the mouse.
local function IsMine(data, line)
    local token = line.unitToken
    if not IsSecret(token) and type(token) == "string" then
        return token == "player" or Yes(UnitIsUnit, token, "player")
    end
    local guid = Text(data.guid)
    if guid then
        local ok, mine = pcall(UnitGUID, "player")
        return ok and Text(mine) == guid
    end
    return Yes(UnitIsUnit, "mouseover", "player")
end

-- What your own guild line becomes: your made-up guild (with "Your guild's
-- name" ticked), else nil, which blanks it. Only while you're in a guild,
-- so the line under your name really is the guild's.
local function MyGuildLine(data, line)
    local guild = P:MyGuild()
    if not guild or not Yes(IsInGuild) or not IsMine(data, line) then return nil end
    return P:GuildLine(guild)
end

-- A unit's tooltip: the name line (with any title), the guild line under a
-- player's or pet's name (yours can show your made-up guild), an owner
-- line, and any other names.
local function OnUnitTip(tooltip, data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local named, underName, guild = false, false, nil
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            local kind = line.type
            if not named and kind == LINE.UnitName then
                named = true
                local label, r, g, b = UnitLabel(data, line)
                if label then
                    SwapLine(tooltip, line, label, r, g, b)
                    underName = true
                    guild = MyGuildLine(data, line)
                end
            elseif underName and kind == LINE.None then
                -- In the line's own colour (the Name colour plays no part).
                SwapLine(tooltip, line, guild or "")
                guild = nil
            else
                underName = false
                SwapNamesIn(tooltip, line)
            end
        end
    end
end

-- "Corpse of Name": a secret name line becomes just "Corpse".
local function OnCorpseTip(tooltip, data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local corpse = GameText("CORPSE", "Corpse")
    for i, line in ipairs(data.lines) do
        if type(line) == "table" then
            if IsSecret(line.leftText) then
                if i == 1 then SwapLine(tooltip, line, corpse) end
            elseif Text(line.leftText) then
                local swapped = Relabel(GameText("CORPSE_TOOLTIP", "Corpse of %s"), line.leftText)
                if swapped == "" then swapped = corpse end
                if swapped then SwapLine(tooltip, line, swapped) else SwapNamesIn(tooltip, line) end
            end
        end
    end
end

-- Hovering group dots on the minimap.
local function OnMinimapTip(tooltip, data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then SwapNamesIn(tooltip, line) end
    end
end

-- "<Made by Name>" on any item tooltip.
local function OnItemTip(tooltip, data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local format = GameText("ITEM_CREATED_BY", "<Made by %s>")
    for _, line in ipairs(data.lines) do
        local text = type(line) == "table" and Text(line.leftText)
        local swapped = text and Relabel(format, text)
        if swapped then SwapLine(tooltip, line, swapped) end
    end
end

-- Registered once, at load, as the feasibility check says (never lazily:
-- they can't be removed, and each returns at once while off).
local function AddTipCalls()
    local processor, enum = _G.TooltipDataProcessor, _G.Enum
    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or type(enum) ~= "table" then return end
    local kinds = enum.TooltipDataType
    if type(kinds) ~= "table" or type(enum.TooltipDataLineType) ~= "table" then return end
    LINE = enum.TooltipDataLineType
    local function Add(kind, key, fn)
        if kind ~= nil then processor.AddTooltipPostCall(kind, Guarded(key, fn)) end
    end
    Add(kinds.Unit, TIPS, OnUnitTip)
    Add(kinds.Corpse, TIPS, OnCorpseTip)
    Add(kinds.MinimapMouseover, TIPS, OnMinimapTip)
    Add(kinds.Item, MADE, OnItemTip)
end
P:Guard(M, AddTipCalls)()

-- The world map and the zone map ----------------------------------------------------------------------

local function SetUpMap(map)
    if P:IsOn(MAP) then ShowCurtain(map) end
end

local function ApplyMaps()
    ShowCurtain(_G.WorldMapFrame)
    ShowCurtain(_G.BattlefieldMapFrame)
end

-- Where you are ------------------------------------------------------------------------------------

local function BlankZone()
    local text = _G.MinimapZoneText
    if type(text) == "table" then P:SwapText(ZONE, text, "") end
end

local function ApplyZone()
    BlankZone()
    local text = _G.MinimapZoneText
    if type(text) == "table" then Shield(ZONE, text:GetParent()) end
end

local POPUP_TEXTS = { "ZoneTextString", "SubZoneTextString", "PVPInfoTextString", "PVPArenaTextString" }
local function ApplyPopups()
    for _, name in ipairs(POPUP_TEXTS) do
        if type(_G[name]) == "table" then P:HideRegion(POPUPS, _G[name]) end
    end
end

local COORD_CVARS = { "minimapShowPlayerCoords", "worldMapShowPlayerCoords", "worldMapShowCursorCoords" }
local function ApplyCoords()
    for _, name in ipairs(COORD_CVARS) do P:SetCVar(COORDS, name, "0") end
end

local function ApplyClock()
    P:SetCVar(CLOCK, "timeMgrUseLocalTime", "0")
    Shield(CLOCK, _G.TimeManagerClockButton)
end

-- Gold -------------------------------------------------------------------------------------------------

-- Money frames that show only your own gold.
local MONEY_FRAMES = { "ContainerFrame1MoneyFrame", "MerchantMoneyFrame", "SendMailMoneyFrame" }

local function Amount(fn)
    if type(fn) ~= "function" then return 0 end
    local amount = fn()
    if IsSecret(amount) or type(amount) ~= "number" then return nil end
    return amount
end

-- Whether money shown is your gold (not a price): what you have, less any
-- on the cursor or in a trade, as the game's own money frames show it.
local function IsMyGold(money)
    if IsSecret(money) or type(money) ~= "number" or type(_G.GetMoney) ~= "function" then return false end
    local mine, cursor, trade = Amount(_G.GetMoney), Amount(_G.GetCursorMoney), Amount(_G.GetPlayerTradeMoney)
    if not (mine and cursor and trade) then return false end
    return money == mine or money == mine - cursor - trade
end

local function HideMoney(frame)
    if type(frame) ~= "table" then return end
    local kind = frame.moneyType
    if IsSecret(kind) or kind ~= "PLAYER" or frame:IsProtected() then return end
    P:HideRegion(GOLD, frame)
end

local function OnMoney(frame, money)
    if type(frame) == "string" then frame = _G[frame] end
    if IsMyGold(money) then HideMoney(frame) end
end

local function ApplyGold()
    for _, name in ipairs(MONEY_FRAMES) do HideMoney(_G[name]) end
    local bags = _G.ContainerFrameCombinedBags
    if type(bags) == "table" then HideMoney(bags.MoneyFrame) end
end

-- The module ---------------------------------------------------------------------------------------------

-- Each surface on its own guard, so one failing never stops the rest.
-- (Tooltips and "Made by" have nothing to apply: they change from the next
-- tooltip on.)
local APPLY = {}
for own, fn in pairs({ [QUEST] = ApplyQuest, [ZONE] = ApplyZone, [COORDS] = ApplyCoords, [POPUPS] = ApplyPopups,
    [CLOCK] = ApplyClock, [MAP] = ApplyMaps, [GOLD] = ApplyGold }) do
    APPLY[own] = P:Guard(M, fn)
end

local function Try(fn, ...)
    P:Guard(M, fn)(...)
end

function M:Setup()
    Try(HookQuests)
    Try(HookGlobal, "Minimap_Update", ZONE, BlankZone)
    Try(HookGlobal, "MoneyFrame_Update", GOLD, OnMoney)
    WhenReady("Blizzard_RaidWarning", "RaidWarningFrame", HookCentre)
    WhenReady("Blizzard_WorldMap", "WorldMapFrame", SetUpMap)
    WhenReady("Blizzard_BattlefieldMap", "BattlefieldMapFrame", SetUpMap)
    WhenReady("Blizzard_TimeManager", "TimeManagerClockButton", function(button)
        if P:IsOn(CLOCK) then Shield(CLOCK, button) end
    end)
end

-- Everything here is put back through the core's records (texts, alphas,
-- CVars, our covers), so turning off needs nothing more. Tooltips and "Made
-- by" lines change from the next tooltip on.
function M:Apply(on, key)
    if not on then return end
    if P.NAME_KEYS[key] then
        if P:IsOn(QUEST) then
            P:Restore(QUEST)
            APPLY[QUEST]()
        end
        return
    end
    for _, own in ipairs(KEYS) do
        if (key == nil or key == own) and APPLY[own] and P:IsOn(own) then APPLY[own]() end
    end
end
