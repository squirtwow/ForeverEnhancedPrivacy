-- UnitFrames: names on unit frames and in the world. Owns playerFrame,
-- charTitles, ownHead, targetFrames, groupFrames, nameplates, otherHeads
-- and petNames.
--
-- playerFrame: your name on the player frame, and your pet's on the pet frame.
-- targetFrames: target, focus, and the target of target for both.
-- groupFrames: party frames, raid-style party and raid frames, the Raid tab's
--   group buttons (classic and Social views) and pulled-out groups.
-- petNames: pets on party and raid frames (and pets' plates, with nameplates).
-- nameplates: names on the nameplates the game lets addons touch.
-- charTitles: the character window's title, the inspect window's title and
--   the inspect talents title. (The inspect guild tab is Social's guildName.)
-- ownHead, otherHeads: names, guilds and titles above heads, through CVars
--   (hide only; the game draws them itself).
--
-- How: post-hooks on UnitFrame_Update and CompactUnitFrame_UpdateName (and on
-- the Raid tab's own updates once it loads), and a SetText post-hook on each
-- unit frame's name and each window title, so a name written again by
-- anything (the game, or another addon keeping the target name) is swapped
-- straight back. Only SetText and SetTextColor on those FontStrings; never a
-- key written on a Blizzard frame, never a frame shown, hidden or moved.
-- Nothing is hooked until private mode first turns on, and every hook
-- returns at once while it's off.
local _, P = ...

local M = P:Module("UnitFrames")

local IsSecret = P.IsSecret

-- CVars that hide names above heads (0 hides). otherHeads also covers your
-- target's name. nameplateForceShowUnitName is left alone: the game caches
-- it, and a change from an addon would break every nameplate's update (see
-- P.CACHABLE_CVARS); it's off unless set by hand.
local HEADS = {
    ownHead = { "UnitNameOwn" },
    otherHeads = { "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle",
        "UnitNameGuildTitle", "UnitNameFriendlyMinionName", "UnitNameEnemyMinionName", "UnitNameFocused" },
}
-- Settings whose surface is text on screen.
local TEXT_KEYS = { playerFrame = true, charTitles = true, targetFrames = true, groupFrames = true, nameplates = true,
    petNames = true }
-- Unit frames made at load, with their name FontString in frame.name.
local KNOWN = { "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT" }

local busy = false -- our own SetText is running: the text hooks let it pass
local owners = setmetatable({}, { __mode = "k" }) -- a unit frame's name FontString: its frame
local seen = setmetatable({}, { __mode = "k" }) -- raid-style frames and plates met while private
local painted = setmetatable({}, { __mode = "k" }) -- FontString: its colour before we first coloured it
local hooked = setmetatable({}, { __mode = "k" }) -- title FontStrings already hooked
local socialRaid -- the Social view's raid list, once hooked
local watcher -- puts the CVars back on after a loading screen

-- Plain text, or nil (a secret, not text, or empty).
local function Text(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

-- Writing ------------------------------------------------------------------------------------

-- Our text on a region, through the core so it can be put back, with the
-- text hooks told to let it pass.
local function Write(key, region, label, r, g, b)
    busy = true
    local ok, err = pcall(P.SwapText, P, key, region, label, r, g, b)
    busy = false
    if not ok then error(err, 0) end
end

-- Unit frame names keep the colour we give them (the game never sets it
-- again), so their colour from before is kept here and put back.
local function Unpaint(region)
    local colour = painted[region]
    if colour then region:SetTextColor(colour[1], colour[2], colour[3], colour[4]) end
end

local function Paint(key, region, label, r, g, b)
    if painted[region] == nil then
        local cr, cg, cb, ca = region:GetTextColor()
        if IsSecret(cr) or IsSecret(cg) or IsSecret(cb) or IsSecret(ca) or type(cr) ~= "number" then
            painted[region] = false
        else
            painted[region] = { cr, cg, cb, ca }
        end
        P:OnRestore(key, region, function()
            Unpaint(region)
            painted[region] = nil
        end)
    end
    Write(key, region, label, r, g, b)
end

-- Units --------------------------------------------------------------------------------------

-- Whether a unit is a pet (player-controlled, not a player). False when the
-- game won't say.
local function IsPetUnit(unit)
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or IsSecret(isPlayer) or isPlayer then return false end
    local fine, controlled = pcall(UnitPlayerControlled, unit)
    return fine and not IsSecret(controlled) and controlled and true or false
end

-- The setting a group token's name goes under: pets apart.
local function GroupKey(unit)
    return unit:find("pet", 1, true) and "petNames" or "groupFrames"
end

local function UnitFrameKey(frame, unit)
    if frame == _G.PlayerFrame or frame == _G.PetFrame or unit == "player" or unit == "pet" or unit == "vehicle" then
        return "playerFrame"
    end
    if unit:find("^party") or unit:find("^raid") then return GroupKey(unit) end
    return "targetFrames"
end

-- Unit frames (player, pet, target, focus, both targets of target, party) -----------------------

local function RelabelUnitFrame(frame)
    local region, unit = frame.name, frame.unit
    if type(region) ~= "table" or IsSecret(unit) or type(unit) ~= "string" then return end
    local key = UnitFrameKey(frame, unit)
    if not P:IsOn(key) then return end
    local label, r, g, b = P:NameFor(unit)
    if label == nil then
        -- An NPC: its own name, in the frame's own colour.
        Unpaint(region)
    elseif r == nil then
        -- Your typed name in the game's own colour: the frame's colour back.
        Unpaint(region)
        Write(key, region, label)
    else
        Paint(key, region, label, r, g, b)
    end
end

local OnNameText = P:Guard(M, function(region)
    if busy or not P:Private() then return end
    local frame = owners[region]
    if frame then RelabelUnitFrame(frame) end
end)

-- Hooks a unit frame's name FontString, once.
local function Watch(frame)
    if type(frame) ~= "table" then return end
    local region = frame.name
    if type(region) ~= "table" or owners[region] ~= nil then return end
    owners[region] = frame
    hooksecurefunc(region, "SetText", OnNameText)
end

local function WatchKnown()
    for _, name in ipairs(KNOWN) do Watch(_G[name]) end
    local party = _G.PartyFrame
    if type(party) ~= "table" then return end
    for i = 1, 4 do
        local member = party["MemberFrame" .. i]
        if type(member) == "table" then
            Watch(member)
            Watch(member.PetFrame)
        end
    end
end

local OnUnitFrameUpdate = P:Guard(M, function(frame)
    if busy or not P:Private() or type(frame) ~= "table" then return end
    Watch(frame)
    RelabelUnitFrame(frame)
end)

local function RelabelUnitFrames()
    WatchKnown()
    for _, frame in pairs(owners) do RelabelUnitFrame(frame) end
end

-- Raid-style frames and nameplates (CompactUnitFrame_UpdateName) -------------------------------

local function CompactKey(unit)
    if unit:find("^nameplate") then
        if not P:IsOn("nameplates") then return nil end
        if IsPetUnit(unit) and not P:IsOn("petNames") then return nil end
        return "nameplates"
    end
    local key = GroupKey(unit)
    return P:IsOn(key) and key or nil
end

-- The game colours these names itself, so only the text changes.
local function RelabelCompact(frame)
    if type(frame) ~= "table" or frame:IsForbidden() then return end
    local region, unit = frame.name, frame.unit
    if type(region) ~= "table" or IsSecret(unit) or type(unit) ~= "string" or not region:IsShown() then return end
    local key = CompactKey(unit)
    if not key then return end
    seen[frame] = true
    local label = P:NameFor(unit)
    if label ~= nil then Write(key, region, label) end
end

local OnCompactName = P:Guard(M, function(frame)
    if busy or not P:Private() then return end
    RelabelCompact(frame)
end)

local function RelabelList(list)
    if type(list) ~= "table" then return end
    for _, frame in ipairs(list) do RelabelCompact(frame) end
end

local function RelabelPlates()
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    if type(plates) ~= "table" then return end
    for _, plate in pairs(plates) do
        if type(plate) == "table" and not plate:IsForbidden() then RelabelCompact(plate.UnitFrame) end
    end
end

local function RelabelCompacts()
    for frame in pairs(seen) do RelabelCompact(frame) end
    local party = _G.CompactPartyFrame
    if type(party) == "table" then
        RelabelList(party.memberUnitFrames)
        RelabelList(party.petUnitFrames)
    end
    local n = 1
    while type(_G["CompactRaidFrame" .. n]) == "table" do
        RelabelCompact(_G["CompactRaidFrame" .. n])
        n = n + 1
    end
    for group = 1, 8 do
        for i = 1, 5 do RelabelCompact(_G["CompactRaidGroup" .. group .. "Member" .. i]) end
    end
    RelabelPlates()
end

-- The Raid tab: group buttons, pulled-out groups, the Social view's list --------------------------

-- One name line for a unit; the game colours these itself.
local function RelabelLine(region, unit, key)
    if type(region) ~= "table" or not Text(unit) or not region:IsShown() then return end
    key = key or GroupKey(unit)
    if not P:IsOn(key) then return end
    local label = P:NameFor(unit)
    if label ~= nil then Write(key, region, label) end
end

local function RelabelRaidGroups()
    if not P:IsOn("groupFrames") then return end
    local count = MAX_RAID_MEMBERS
    if IsSecret(count) or type(count) ~= "number" then count = 40 end
    for i = 1, count do
        local button = _G["RaidGroupButton" .. i]
        if type(button) == "table" and button:IsShown() then RelabelLine(_G["RaidGroupButton" .. i .. "Name"], "raid" .. i) end
    end
end

-- A pulled-out member's target and target of target lines.
local function RelabelPulloutTarget(buttonName, unit, which)
    buttonName, unit, which = Text(buttonName), Text(unit), Text(which)
    if buttonName and unit and which then RelabelLine(_G[buttonName .. which .. "Name"], unit, "groupFrames") end
end

local function RelabelPullout(frame)
    if type(frame) ~= "table" or not frame:IsShown() or type(frame.buttons) ~= "table" then return end
    for _, button in ipairs(frame.buttons) do
        local unit = type(button) == "table" and Text(button.unit)
        if unit and button:IsShown() then
            RelabelLine(button.nameLabel, unit)
            local name = Text(button:GetName())
            if name then
                RelabelPulloutTarget(name, unit .. "target", "Target")
                RelabelPulloutTarget(name, unit .. "targettarget", "TargetTarget")
            end
        end
    end
end

local function RelabelSocialRaid(raid)
    if type(raid) ~= "table" or type(raid.players) ~= "table" then return end
    for _, row in ipairs(raid.players) do
        if type(row) == "table" then RelabelLine(row.CharacterName, row.unit) end
    end
end

local function RelabelRaidTab()
    RelabelRaidGroups()
    local count = NUM_RAID_PULLOUT_FRAMES
    if not IsSecret(count) and type(count) == "number" then
        for i = 1, count do RelabelPullout(_G["RaidPullout" .. i]) end
    end
    RelabelSocialRaid(socialRaid)
end

local OnRaidGroups = P:Guard(M, function()
    if busy or not P:IsOn("groupFrames") then return end
    RelabelRaidGroups()
end)

local OnPullout = P:Guard(M, function(frame)
    if busy or not P:Private() then return end
    RelabelPullout(frame)
end)

local OnPulloutTarget = P:Guard(M, function(_, buttonName, unit, which)
    if busy or not P:IsOn("groupFrames") then return end
    RelabelPulloutTarget(buttonName, unit, which)
end)

local OnSocialRaid = P:Guard(M, function(raid)
    if busy or not P:Private() then return end
    RelabelSocialRaid(raid)
end)

-- Window titles ----------------------------------------------------------------------------------

local function TitleOf(frame)
    if type(frame) ~= "table" or type(frame.GetTitleText) ~= "function" then return nil end
    local region = frame:GetTitleText()
    return type(region) == "table" and region or nil
end

-- Whether text has your first name in it as a whole word.
local function HasMyName(text)
    text = Text(text)
    local first = P:MyNames()
    if not text or not first then return false end
    local start = 1
    while true do
        local s, e = text:find(first, start, true)
        if not s then return false end
        if not text:sub(s - 1, s - 1):find("[%a\128-\255]") and not text:sub(e + 1, e + 1):find("[%a\128-\255]") then
            return true
        end
        start = e + 1
    end
end

-- The character window's title is your name and title on its own page,
-- and a page name (Reputation, Skills...) on the others.
local function CharacterTitleIsName(frame, region)
    local info = _G.characterFrameDisplayInfo
    if type(info) == "table" then
        local page = Text(frame.activeSubframe)
        return not page or info[page] == nil
    end
    return HasMyName(region:GetText())
end

local function RelabelCharacterTitle()
    if not P:IsOn("charTitles") then return end
    local frame = _G.CharacterFrame
    local region = TitleOf(frame)
    if region and CharacterTitleIsName(frame, region) then Write("charTitles", region, (P:MyLabel())) end
end

-- Whoever a window shows by unit: their label, or "Player" when unknown.
local function LabelForUnit(unit)
    local label = Text(unit) and P:NameFor(unit)
    if label == nil or label == false then label = P:StyleLabel(nil) end
    return label
end

local function RelabelInspectTitle()
    if not P:IsOn("charTitles") then return end
    local frame = _G.InspectFrame
    local region = TitleOf(frame)
    if region then Write("charTitles", region, LabelForUnit(frame.unit)) end
end

-- The inspect talents title ("Talents - Name"); its other titles are left.
local function RelabelTalentsTitle()
    if not P:IsOn("charTitles") then return end
    local frame = _G.PlayerSpellsFrame
    local region = TitleOf(frame)
    if not region or type(frame.GetInspectUnit) ~= "function" then return end
    local unit = Text(frame:GetInspectUnit())
    if not unit then return end
    local label, format = LabelForUnit(unit), Text(TALENTS_INSPECT_FORMAT)
    local text = label
    if label == "" then
        text = Text(TALENTS) or ""
    elseif format and format:find("%s", 1, true) then
        text = format:format(label)
    end
    Write("charTitles", region, text)
end

local function TitleHook(fn)
    return P:Guard(M, function()
        if busy or not P:IsOn("charTitles") then return end
        fn()
    end)
end
local OnCharacterTitle, OnInspectTitle = TitleHook(RelabelCharacterTitle), TitleHook(RelabelInspectTitle)
local OnTalentsTitle = TitleHook(RelabelTalentsTitle)

local function RelabelTitles()
    RelabelCharacterTitle()
    RelabelInspectTitle()
    RelabelTalentsTitle()
end

-- Setting up (once, the first time private mode turns on) --------------------------------------

local function HookGlobal(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end

local function HookTitle(frame, fn)
    local region = TitleOf(frame)
    if not region or hooked[region] then return end
    hooked[region] = true
    hooksecurefunc(region, "SetText", fn)
end

local function HookRaidUI()
    HookGlobal("RaidGroupFrame_Update", OnRaidGroups)
    HookGlobal("RaidPullout_Update", OnPullout)
    HookGlobal("RaidPullout_UpdateTarget", OnPulloutTarget)
    RelabelRaidTab()
end

-- The Social view's raid list is made at load; its rows are pooled, so the
-- list's own update is hooked on the list itself.
local function HookSocialRaid()
    local social = _G.SocialUIFrame
    local raid = type(social) == "table" and social.RaidFrame
    if socialRaid or type(raid) ~= "table" or type(raid.UpdateContents) ~= "function" then return end
    hooksecurefunc(raid, "UpdateContents", OnSocialRaid)
    socialRaid = raid
    RelabelSocialRaid(raid)
end

local function HookInspect()
    HookTitle(_G.InspectFrame, OnInspectTitle)
    RelabelInspectTitle()
end

local function HookTalents()
    HookTitle(_G.PlayerSpellsFrame, OnTalentsTitle)
    RelabelTalentsTitle()
end

-- Each kind of surface as it shows now; one failing never stops the rest.
local refreshers = { P:Guard(M, RelabelUnitFrames), P:Guard(M, RelabelCompacts), P:Guard(M, RelabelRaidTab),
    P:Guard(M, RelabelTitles) }

local function RelabelAll()
    for _, refresh in ipairs(refreshers) do refresh() end
end

local function ApplyHeads()
    for key, names in pairs(HEADS) do
        if P:IsOn(key) then
            for _, name in ipairs(names) do P:SetCVar(key, name, "0") end
        end
    end
end

-- After a loading screen: the game can put name CVars back, and frames are
-- drawn afresh.
local OnLoadingScreen = P:Guard(M, function()
    if not P:Private() then return end
    ApplyHeads()
    RelabelAll()
end)

function M:Setup()
    P:Guard(M, function()
        HookGlobal("UnitFrame_Update", OnUnitFrameUpdate)
        WatchKnown()
    end)()
    P:Guard(M, function() HookGlobal("CompactUnitFrame_UpdateName", OnCompactName) end)()
    P:Guard(M, function() HookTitle(_G.CharacterFrame, OnCharacterTitle) end)()
    P:OnAddOnLoaded("Blizzard_SocialUI", HookSocialRaid, M)
    P:OnAddOnLoaded("Blizzard_RaidUI", HookRaidUI, M)
    P:OnAddOnLoaded("Blizzard_InspectUI", HookInspect, M)
    P:OnAddOnLoaded("Blizzard_PlayerSpells", HookTalents, M)
end

function M:Apply(on, key)
    if not on then
        -- Everything changed is on the core's record, which puts it back.
        if watcher then watcher:UnregisterAllEvents() end
        return
    end
    if key == nil then
        if not watcher then
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnEvent", OnLoadingScreen)
        end
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        ApplyHeads()
        RelabelAll()
    elseif HEADS[key] then
        ApplyHeads()
    elseif TEXT_KEYS[key] or P.NAME_KEYS[key] then
        -- Pets' plates are filed under nameplates, so they come back with it.
        if key == "petNames" and not P:IsOn("petNames") then P:Restore("nameplates") end
        RelabelAll()
    end
end
