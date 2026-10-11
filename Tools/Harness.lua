-- A mock of the game for the addon's tests, loaded with loadfile. The addon's
-- real files run in it, in the TOC's order.
--
-- Blizzard's objects here are sealed, as the addon must leave them: writing
-- any key on one is a violation, and so is calling any method but a read
-- (Get..., Is..., Has..., Can..., Enumerate..., Num..., Does...), HookScript, or a cosmetic
-- setter (SetText, SetFormattedText, SetTextColor, SetVertexColor,
-- SetShadowColor, SetPassword; and SetAlpha, Show, Hide, SetShown, SetWidth,
-- SetHeight and SetSize only on what isn't protected), or one of the chat
-- history edits Blizzard opens to addons (SANCTIONED). That holds for the
-- methods a test gives an object too (H.BlizzardFrame's fields, or rawset):
-- a sealed object keeps its functions off its own table, so every call goes
-- through the check. Hooking a method on a protected frame is a violation
-- too, and so is changing a tooltip's line outside a tooltip post-call.
-- Only Blizzard's own code, run by a test through H.Blizzard (or by a hooked
-- Blizzard function), may do more. Violations are recorded even when the
-- addon catches the error.
--
-- Secrets are one value, H.SECRET: indexing, joining, measuring, arithmetic,
-- calling or turning it into text is a violation (comparing it with a plain
-- string can't be caught in Lua: always ask issecretvalue first). Units,
-- CVars, chat filters, tooltip post-calls and Menu.ModifyMenu are stood in
-- for; see Tools/Notes.md for how a module's test uses them.
local H = {}

H.ADDON = "ForeverEnhancedPrivacy"
-- The addon's files, in the TOC's order (Tools/TestRules.mjs checks they match).
H.FILES = { "Core.lua", "Theme.lua", "Names.lua", "UnitFrames.lua", "Chat.lua", "Social.lua", "Windows.lua", "World.lua",
    "Window.lua", "Eye.lua", "MinimapButton.lua" }

local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpackAll = table.unpack or unpack
_G.unpack = _G.unpack or table.unpack
local rawGet, rawSet = rawget, rawset

-- Checks ------------------------------------------------------------------------------------

H.checks = 0
function H.Equal(actual, expected, label)
    H.checks = H.checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

function H.True(value, label)
    H.checks = H.checks + 1
    if not value then error(label .. ": expected true, got " .. tostring(value), 2) end
end

-- Secrets --------------------------------------------------------------------------------------

H.violations = {}
local function Violation(text)
    H.violations[#H.violations + 1] = text
end
H.Violation = Violation

local function Boom(what)
    return function()
        Violation("a secret value was " .. what)
        error("secret value " .. what, 2)
    end
end
H.SECRET = setmetatable({}, { __index = Boom("indexed"), __newindex = Boom("written into"), __eq = Boom("compared"),
    __lt = Boom("compared"), __le = Boom("compared"), __add = Boom("used in arithmetic"), __sub = Boom("used in arithmetic"),
    __mul = Boom("used in arithmetic"), __div = Boom("used in arithmetic"), __mod = Boom("used in arithmetic"),
    __pow = Boom("used in arithmetic"), __unm = Boom("used in arithmetic"), __concat = Boom("joined"),
    __len = Boom("measured"), __call = Boom("called"), __tostring = Boom("turned into text") })
local SECRET = H.SECRET
local function IsSecret(v) return rawequal(v, SECRET) end
H.IsSecret = IsSecret

-- Mock objects ----------------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- each object's state, never on the object
H.S = S
local Proto = {}
H.Proto = Proto
local blizzardCalling = false -- Blizzard's own code is running
local tooltipCalling = false -- a tooltip's pre- or post-call is running

local READS = { "Get", "Is", "Has", "Can", "Enumerate", "Num", "Does" }
local COSMETIC = { SetText = true, SetFormattedText = true, SetTextColor = true, SetVertexColor = true, SetShadowColor = true,
    SetPassword = true }
local UNPROTECTED = { SetAlpha = true, Show = true, Hide = true, SetShown = true, SetWidth = true, SetHeight = true, SetSize = true }
-- Blizzard opens these to addons on purpose: a chat frame's history edits
-- (ScrollingMessageFrameSecureMixin, which runs them as if untainted).
local SANCTIONED = { TransformMessages = true, RemoveMessagesByPredicate = true }

-- Whether the addon may call this method on one of Blizzard's objects.
local function Allowed(obj, key)
    if type(key) ~= "string" or not key:match("^[A-Z]") then return true end
    if key == "HookScript" or COSMETIC[key] or SANCTIONED[key] then return true end
    for _, prefix in ipairs(READS) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    if UNPROTECTED[key] then return not S[obj].protected end
    return false
end
H.Allowed = Allowed

local function Name(obj)
    local s = S[obj]
    return s and (s.name or s.kind) or "?"
end
H.Name = Name

-- The addon's cosmetic calls on Blizzard's objects, counted (H.Writes) and
-- listed (H.writeLog: "Name:Method").
H.writes, H.writeLog = 0, {}
function H.Writes() return H.writes end
function H.ResetWrites() H.writes, H.writeLog = 0, {} end

H.counts = {}
local function Record(obj, key, ...)
    local s = S[obj]
    s.last[key] = pack(...)
    s.calls[key] = (s.calls[key] or 0) + 1
    H.counts[key] = (H.counts[key] or 0) + 1
end

local New
New = function(kind, parent)
    local obj = {}
    S[obj] = { kind = kind, parent = parent, shown = true, last = {}, calls = {}, scripts = {}, events = {}, points = {},
        width = 0, height = 0, alpha = 1, children = {} }
    H.objects[#H.objects + 1] = obj
    if parent and S[parent] then table.insert(S[parent].children, obj) end
    setmetatable(obj, {
        __index = function(_, key)
            local s = S[obj]
            -- A method the test gave this sealed object, or a hook on one.
            local field = s.fields and s.fields[key]
            if s.blizzard and not blizzardCalling then
                if not Allowed(obj, key) then
                    return function()
                        Violation("called " .. key .. " on Blizzard's " .. Name(obj))
                        error("called " .. key .. " on a Blizzard frame", 2)
                    end
                end
                if COSMETIC[key] or UNPROTECTED[key] then
                    local method = Proto[key]
                    return function(self, ...)
                        H.writes = H.writes + 1
                        H.writeLog[#H.writeLog + 1] = Name(obj) .. ":" .. key
                        if s.tipLine and not tooltipCalling then
                            Violation("changed Blizzard's tooltip line " .. Name(obj) .. " outside a tooltip post-call")
                        end
                        if field then return field(self, ...) end
                        if method then return method(self, ...) end
                        Record(self, key, ...)
                    end
                end
            end
            if field ~= nil then return field end
            local method = Proto[key]
            if method then return method end
            if type(key) == "string" and key:match("^[A-Z]") then
                -- Anything else: recorded, the last call's arguments kept.
                return function(self, ...) Record(self, key, ...) end
            end
        end,
        __newindex = function(t, key, value)
            if S[t].sealed and not blizzardCalling then
                Violation("wrote key '" .. tostring(key) .. "' on Blizzard's " .. Name(t))
                error("wrote key '" .. tostring(key) .. "' on a Blizzard frame", 2)
            end
            rawset(t, key, value)
        end,
    })
    return obj
end
H.New = New

-- A sealed object keeps its functions apart (S[obj].fields), so the addon
-- reaches them only through the check above. rawset and rawget see them
-- where they'd be on the game's frame (the addon never uses rawset).
local function StoreField(t, key, value)
    local s = S[t]
    s.fields = s.fields or {}
    if type(value) == "function" then
        s.fields[key] = value
        rawSet(t, key, nil)
        return
    end
    s.fields[key] = nil
    rawSet(t, key, value)
end

_G.rawset = function(t, key, value)
    if S[t] and S[t].sealed then
        StoreField(t, key, value)
        return t
    end
    return rawSet(t, key, value)
end

_G.rawget = function(t, key)
    local value = rawGet(t, key)
    if value == nil and S[t] and S[t].fields then return S[t].fields[key] end
    return value
end

function H.Last(obj, method, i)
    local call = S[obj].last[method]
    return call and call[i or 1]
end

function H.Calls(obj, method)
    return S[obj].calls[method] or 0
end

-- Like the game: showing or hiding runs the frame's OnShow or OnHide.
local function Toggled(self, v)
    local s = S[self]
    local changed = s.shown ~= v
    s.shown = v
    if changed then
        local script = s.scripts[v and "OnShow" or "OnHide"]
        if script then script(self) end
    end
end
function Proto:Show() Toggled(self, true) end
function Proto:Hide() Toggled(self, false) end
function Proto:SetShown(v) Toggled(self, v and true or false) end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible()
    local s = S[self]
    if not s.shown then return false end
    local parent = s.parent
    return parent == nil or S[parent] == nil or parent:IsVisible()
end
function Proto:SetScript(k, fn) S[self].scripts[k] = fn end
function Proto:GetScript(k) return S[self].scripts[k] end
-- Like the game: a hook runs after the script, as the addon's code.
function Proto:HookScript(k, fn)
    local old = S[self].scripts[k]
    S[self].scripts[k] = function(...)
        if old then old(...) end
        local was = blizzardCalling
        blizzardCalling = false
        local ok, err = pcall(fn, ...)
        blizzardCalling = was
        if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
    end
end
function Proto:RegisterEvent(e) S[self].events[e] = true end
function Proto:RegisterUnitEvent(e, unit) S[self].events[e] = unit or true end
function Proto:UnregisterEvent(e) S[self].events[e] = nil end
function Proto:UnregisterAllEvents() S[self].events = {} end
function Proto:IsEventRegistered(e) return S[self].events[e] ~= nil end
function Proto:GetObjectType() return S[self].kind end
function Proto:GetParent() return S[self].parent end
function Proto:GetName() return S[self].name end
function Proto:IsForbidden() return S[self].forbidden == true end
function Proto:IsProtected() return S[self].protected == true end
function Proto:CreateTexture(_, layer)
    local t = New("Texture", self)
    S[t].layer = layer
    if S[self].sealed then S[t].sealed, S[t].blizzard = true, true end
    return t
end
function Proto:CreateFontString(_, layer, template)
    local text = New("FontString", self)
    S[text].template, S[text].layer = template, layer
    if S[self].sealed then S[text].sealed, S[text].blizzard = true, true end
    return text
end
-- The game refuses text on a string made with no template and given no font.
local function NeedsFont(obj, method)
    local s = S[obj]
    if s.kind == "FontString" and not s.template and not s.fontFile and not s.blizzard then
        error("FontString:" .. method .. "(): Font not set", 3)
    end
end
-- Text takes anything the game's would: a secret too (kept as the secret).
function Proto:SetText(t)
    NeedsFont(self, "SetText")
    if t ~= nil and not IsSecret(t) and type(t) ~= "string" and type(t) ~= "number" then
        error("SetText takes text", 2)
    end
    S[self].text = (t ~= nil and not IsSecret(t)) and tostring(t) or t
    S[self].calls.SetText = (S[self].calls.SetText or 0) + 1
end
function Proto:SetFormattedText(fmt, ...)
    NeedsFont(self, "SetFormattedText")
    for i = 1, select("#", ...) do
        if IsSecret((select(i, ...))) then
            S[self].text = SECRET
            return
        end
    end
    S[self].text = fmt:format(...)
end
function Proto:GetText()
    local s = S[self]
    if s.kind == "EditBox" then return s.text or "" end
    return s.text
end
function Proto:SetTextColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetTextColor()
    local c = S[self].colour or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end
function Proto:SetShadowColor(_, _, _, a) S[self].shadow = a end
function Proto:SetPassword(on) S[self].password = on and true or false end
function Proto:IsPassword() return S[self].password == true end
function Proto:SetFontObject(font) S[self].fontFile = font end
function Proto:SetFont(file) S[self].fontFile = file end
-- Like the game: a second point of the same name replaces the first.
function Proto:SetPoint(point, ...)
    local s = S[self]
    local entry = pack(point, ...)
    for i, old in ipairs(s.points) do
        if old[1] == point then
            s.points[i] = entry
            return
        end
    end
    s.points[#s.points + 1] = entry
end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetAllPoints(rel) S[self].points = { pack("ALL", rel) } end
function Proto:GetNumPoints() return #S[self].points end
function Proto:SetSize(w, h) S[self].width, S[self].height = w, h end
function Proto:SetWidth(w) S[self].width = w end
function Proto:SetHeight(h) S[self].height = h end
function Proto:GetWidth() return S[self].width end
function Proto:GetHeight() return S[self].height end
function Proto:GetSize() return S[self].width, S[self].height end
function Proto:GetVerticalScroll() return S[self].scroll or 0 end
function Proto:SetVerticalScroll(v) S[self].scroll = v end
function Proto:GetEffectiveScale() return 1 end
function Proto:SetBackdrop(b) S[self].backdropInfo = b end
function Proto:SetBackdropBorderColor(r, g, b, a) S[self].border = { r, g, b, a } end
function Proto:SetBackdropColor(r, g, b, a) S[self].backdrop = { r, g, b, a } end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:GetFrameLevel() return S[self].level or 1 end
function Proto:SetFrameLevel(level) S[self].level = level end
function Proto:SetFrameStrata(strata) S[self].strata = strata end
function Proto:GetFrameStrata() return S[self].strata or "MEDIUM" end
-- One line of text: about six units a letter.
function Proto:GetStringWidth()
    local text = S[self].text
    return type(text) == "string" and #text * 6 or 0
end
-- Wrapped text: about six units a letter, twelve a line.
function Proto:GetStringHeight()
    local s = S[self]
    local text = type(s.text) == "string" and s.text or ""
    return math.max(1, math.ceil(#text * 6 / math.max(1, s.width))) * 12
end
function Proto:Click(button)
    local script = S[self].scripts.OnClick
    if script then script(self, button or "LeftButton") end
end
function Proto:SetTexture(t) S[self].texture = t end
function Proto:GetTexture() return S[self].texture end
function Proto:SetTexCoord(...) S[self].texCoord = { ... } end
function Proto:SetColorTexture(r, g, b, a) S[self].color = { r, g, b, a } end
function Proto:SetVertexColor(r, g, b, a) S[self].tint = { r, g, b, a } end
function Proto:EnableMouse(v) S[self].mouse = v and true or false end
function Proto:IsMouseEnabled() return S[self].mouse == true end
function Proto:SetEnabled(v) S[self].enabled = v and true or false end
function Proto:IsEnabled() return S[self].enabled ~= false end
-- Text boxes.
function Proto:SetFocus()
    local s = S[self]
    if not s.focus then
        s.focus = true
        if s.scripts.OnEditFocusGained then s.scripts.OnEditFocusGained(self) end
    end
end
function Proto:ClearFocus()
    local s = S[self]
    if s.focus then
        s.focus = false
        if s.scripts.OnEditFocusLost then s.scripts.OnEditFocusLost(self) end
    end
end
function Proto:HasFocus() return S[self].focus == true end
function Proto:SetMaxLetters(n) S[self].maxLetters = n end
function Proto:GetMaxLetters() return S[self].maxLetters or 0 end

-- Seals an object and everything in it as Blizzard's (its functions moved
-- apart, so calling them goes through the check).
local function Seal(obj)
    S[obj].sealed, S[obj].blizzard = true, true
    local functions = {}
    for key, value in next, obj do
        if type(value) == "function" then functions[key] = value end
    end
    for key, value in pairs(functions) do StoreField(obj, key, value) end
    for _, child in ipairs(S[obj].children) do Seal(child) end
end
H.Seal = Seal

-- A protected frame (a secure unit button, say): only reads, hooks and
-- text setters, ever.
function H.Protect(obj)
    S[obj].protected = true
    return obj
end

-- Builds one of Blizzard's objects: sealed, under its global name if given.
-- fields: plain keys to put on it as Blizzard's code would (frame.unit...).
function H.BlizzardFrame(kind, name, parent, fields)
    local obj = New(kind or "Frame", parent)
    S[obj].name = name
    for key, value in pairs(fields or {}) do rawSet(obj, key, value) end
    Seal(obj)
    if name then _G[name] = obj end
    return obj
end

function H.BlizzardText(name, parent, text)
    local fs = H.BlizzardFrame("FontString", name, parent)
    S[fs].text, S[fs].template = text, "GameFontNormal"
    return fs
end

-- A secure unit frame as the game makes them: protected, frame.unit set and
-- its name FontString in frame.name (also global as <name>Name).
function H.UnitFrame(name, unit, parent)
    local frame = H.BlizzardFrame("Button", name, parent or UIParent)
    H.Protect(frame)
    local text = H.BlizzardText(name and (name .. "Name") or nil, frame, "")
    rawset(frame, "unit", unit)
    rawset(frame, "name", text)
    return frame, text
end

-- Text and alpha as the screen shows them.
function H.Text(region) return S[region].text end
function H.Alpha(region) return S[region].alpha end
function H.Shown(region) return region ~= nil and region:IsVisible() end

-- Events and time ----------------------------------------------------------------------------------

function H.Fire(event, ...)
    local list = {}
    for _, frame in ipairs(H.frames) do list[#list + 1] = frame end
    for _, frame in ipairs(list) do
        if S[frame].events[event] and S[frame].scripts.OnEvent then S[frame].scripts.OnEvent(frame, event, ...) end
    end
end

-- Timers waiting, run all at once, as if their time had passed.
function H.RunTimers()
    local due = H.timers
    H.timers = {}
    for _, timer in ipairs(due) do timer() end
end

-- Blizzard's own code, run by the test as the game would.
function H.Blizzard(fn, ...)
    local was = blizzardCalling
    blizzardCalling = true
    local results = pack(pcall(fn, ...))
    blizzardCalling = was
    if not results[1] then error(results[2], 2) end
    return unpackAll(results, 2, results.n)
end

-- Fights begin and end as the game says.
function H.Combat(on)
    if on then
        H.Fire("PLAYER_REGEN_DISABLED")
        H.lockdown = true
    else
        H.lockdown = false
        H.Fire("PLAYER_REGEN_ENABLED")
    end
end

-- A screenshot: "start", then "done" or "fail".
function H.Screenshot(step)
    if step == "start" then H.Fire("SCREENSHOT_STARTED")
    elseif step == "fail" then H.Fire("SCREENSHOT_FAILED")
    else H.Fire("SCREENSHOT_SUCCEEDED") end
end

-- Units -------------------------------------------------------------------------------------------------
-- H.units[token] = { name, surname, class, classFile, player, pet, guid, and
-- secretName, secretClass, secretPlayer, secretCompare to make those
-- answers secrets }. Two tokens are the same unit when their guids match.

H.PLAYER = { name = "Zriel", surname = "Gustbellow", class = "Druid", classFile = "DRUID", player = true, guid = "Player-1-0001" }

local function U(unit) return type(unit) == "string" and not IsSecret(unit) and H.units[unit] or nil end

local function InstallUnits()
    _G.UnitExists = function(unit) return U(unit) ~= nil end
    _G.UnitName = function(unit)
        local u = U(unit)
        if not u then return nil end
        if u.secretName then return SECRET, SECRET end
        return u.name, u.surname
    end
    _G.GetUnitName = function(unit)
        local u = U(unit)
        if not u then return nil end
        if u.secretName then return SECRET end
        return u.surname and (u.name .. " " .. u.surname) or u.name
    end
    _G.UnitNameUnmodified = _G.UnitName
    _G.UnitClass = function(unit)
        local u = U(unit)
        if not u then return nil end
        if u.secretClass then return SECRET, SECRET, SECRET end
        return u.class, u.classFile, 1
    end
    _G.UnitIsPlayer = function(unit)
        local u = U(unit)
        if not u then return false end
        if u.secretPlayer then return SECRET end
        return u.player == true
    end
    _G.UnitPlayerControlled = function(unit)
        local u = U(unit)
        return u ~= nil and (u.player == true or u.pet == true)
    end
    _G.UnitIsUnit = function(a, b)
        local ua, ub = U(a), U(b)
        if not ua or not ub then return false end
        if ua.secretCompare or ub.secretCompare then return SECRET end
        return ua.guid ~= nil and ua.guid == ub.guid
    end
    _G.UnitGUID = function(unit)
        local u = U(unit)
        return u and u.guid
    end
    _G.GetPlayerInfoByGUID = function(guid)
        for _, u in pairs(H.units) do
            if u.guid == guid and u.player then return u.class, u.classFile, "Human", "Human", 2, u.surname and (u.name .. " " .. u.surname) or u.name, "" end
        end
    end
    _G.GetNumGroupMembers = function()
        local n = 0
        for token in pairs(H.units) do
            if token:match("^party%d$") then n = n + 1 end
        end
        if H.raid then
            n = 0
            for token in pairs(H.units) do
                if token:match("^raid%d+$") then n = n + 1 end
            end
            return n
        end
        return n > 0 and n + 1 or 0
    end
    _G.IsInRaid = function() return H.raid == true end
    _G.IsInGroup = function() return GetNumGroupMembers() > 0 end
end

-- Guild and friends: H.guild = { { name, classFile }, ... } (nil: no
-- guild); H.friends = { { name, className }, ... }.
local function InstallSocial()
    _G.IsInGuild = function() return H.guild ~= nil end
    _G.GetNumGuildMembers = function() return H.guild and #H.guild or 0 end
    _G.GetGuildRosterInfo = function(i)
        local m = H.guild and H.guild[i]
        if not m then return nil end
        if m.secret then return SECRET, SECRET, 0, 60, SECRET, "", "", "", true, 0, SECRET end
        return m.name, "Member", 2, 60, m.class or "", "", "", "", true, 0, m.classFile
    end
    _G.C_FriendList = {
        GetNumFriends = function() return #H.friends end,
        GetFriendInfoByIndex = function(i)
            local f = H.friends[i]
            return f and { name = f.name, className = f.className, connected = true }
        end,
    }
end

-- CVars ----------------------------------------------------------------------------------------------------
-- H.cvars holds the client's CVars (name: value as text); a name not there
-- doesn't exist on this client. Every change is listed in H.cvarWrites.

local CVARS = {
    UnitNameOwn = "1", UnitNameFriendlyPlayerName = "1", UnitNameEnemyPlayerName = "1", UnitNamePlayerGuild = "1",
    UnitNameFriendlyMinionName = "1", UnitNameEnemyMinionName = "1", nameplateForceShowUnitName = "1", UnitNameFocused = "1",
    chatBubbles = "1", chatBubblesParty = "1", showTimestamps = "none", timeMgrUseLocalTime = "1",
    minimapShowPlayerCoords = "1", worldMapShowPlayerCoords = "1", worldMapShowCursorCoords = "1",
    floatingCombatTextFriendlyHealers_v2 = "1", showToastOnline = "1", showToastOffline = "1",
    showToastBroadcast = "1", showToastFriendRequest = "1",
}

-- CVars the game caches (CVarCallbackRegistry): an addon's change taints the
-- cached copy, so changing one is a violation. The registry stands in with
-- these marked, as the game has them once its addons load.
H.CACHABLE = { floatingCombatTextFriendlyHealers_v2 = true, nameplateForceShowUnitName = true }

local function InstallCVars()
    H.cvars, H.cvarWrites = {}, {}
    for name, value in pairs(CVARS) do H.cvars[name] = value end
    local cachable = {}
    for name in pairs(H.CACHABLE) do cachable[name] = true end
    _G.CVarCallbackRegistry = { cachable = cachable }
    local function Get(name) return H.cvars[name] end
    local function Set(name, value)
        if H.lockdown then Violation("changed the game setting " .. tostring(name) .. " in combat") end
        if cachable[name] then Violation("changed " .. tostring(name) .. ", a setting the game caches") end
        if H.cvars[name] == nil then return false end
        H.cvars[name] = tostring(value)
        H.cvarWrites[#H.cvarWrites + 1] = name .. "=" .. tostring(value)
        return true
    end
    _G.C_CVar = { GetCVar = Get, SetCVar = Set, GetCVarBool = function(name) return H.cvars[name] == "1" end }
    _G.GetCVar, _G.SetCVar = Get, Set
    _G.GetCVarBool = C_CVar.GetCVarBool
end

-- Chat filters ------------------------------------------------------------------------------------------------
-- ChatFrameUtil's filter lists, run as Blizzard runs them (ChatFrameFilters.lua):
-- a message filter is skipped while any argument is a secret; it returns
-- discard, then every argument (its second return, when set, replaces them
-- all); a sender filter is skipped for a secret name and returns the new
-- name or nil.

local function InstallChat()
    H.messageFilters, H.senderFilters = {}, {}
    local function Find(list, fn)
        for i, f in ipairs(list) do
            if f == fn then return i end
        end
    end
    _G.ChatFrameUtil = {
        AddMessageEventFilter = function(event, fn)
            H.messageFilters[event] = H.messageFilters[event] or {}
            if not Find(H.messageFilters[event], fn) then table.insert(H.messageFilters[event], fn) end
        end,
        RemoveMessageEventFilter = function(event, fn)
            local list = H.messageFilters[event]
            local i = list and Find(list, fn)
            if i then table.remove(list, i) end
        end,
        AddSenderNameFilter = function(fn)
            if not Find(H.senderFilters, fn) then table.insert(H.senderFilters, fn) end
        end,
        RemoveSenderNameFilter = function(fn)
            local i = Find(H.senderFilters, fn)
            if i then table.remove(H.senderFilters, i) end
        end,
    }
end

local function Accessible(args)
    for i = 1, args.n do
        if IsSecret(args[i]) then return false end
    end
    return true
end

-- A chat event through the message filters: returns discard, then the
-- arguments as they'd be printed.
function H.Chat(event, ...)
    local args = pack(...)
    local list = {}
    for _, fn in ipairs(H.messageFilters[event] or {}) do list[#list + 1] = fn end
    for _, fn in ipairs(list) do
        if Accessible(args) then
            local was = blizzardCalling
            blizzardCalling = false
            local results = pack(pcall(fn, H.chatFrame, event, unpackAll(args, 1, args.n)))
            blizzardCalling = was
            if not results[1] then
                H.hookErrors[#H.hookErrors + 1] = tostring(results[2])
            else
                if results[2] then return true end
                if results[3] then args = pack(unpackAll(results, 3, results.n)) end
            end
        end
    end
    return false, unpackAll(args, 1, args.n)
end

-- A sender's shown name through the sender filters.
function H.SenderName(event, decorated, ...)
    for _, fn in ipairs(H.senderFilters) do
        if not IsSecret(decorated) then
            local was = blizzardCalling
            blizzardCalling = false
            local ok, name = pcall(fn, event, decorated, ...)
            blizzardCalling = was
            if not ok then
                H.hookErrors[#H.hookErrors + 1] = tostring(name)
            elseif name ~= nil then
                decorated = name
            end
        end
    end
    return decorated
end

-- Tooltips -------------------------------------------------------------------------------------------------------
-- TooltipDataProcessor's lists, run as Blizzard's ProcessInfo runs them:
-- tooltip pre-calls (true stops it), each line's pre-calls (true drops the
-- line), the line drawn, its post-calls, then the tooltip's post-calls.

local TOOLTIP_TYPES = { "Item", "Spell", "Unit", "Corpse", "Object", "Currency", "BattlePet", "UnitAura", "AzeriteEssence",
    "CompanionPet", "Mount", "PetAction", "Achievement", "EnhancedConduit", "EquipmentSet", "InstanceLock", "PvPBrawl",
    "RecipeRankInfo", "Totem", "Toy", "CorruptionCleanser", "MinimapMouseover", "Flyout", "Quest", "QuestPartyProgress",
    "Macro", "Debug", "Outfit" }
local LINE_TYPES = { "None", "Blank", "UnitName", "GemSocket", "AzeriteEssenceSlot", "AzeriteEssencePower", "LearnableSpell",
    "UnitThreat", "QuestObjective", "AzeriteItemPowerDescription", "RuneforgeLegendaryPowerDescription", "SellPrice",
    "ProfessionCraftingQuality", "SpellName", "CurrencyTotal", "ItemEnchantmentPermanent", "UnitOwner", "QuestTitle",
    "QuestPlayer", "NestedBlock", "ItemBinding", "EquipSlot", "ItemName", "Separator", "ToyName", "ToyText", "ToyEffect",
    "ToyDuration", "ToyDescription", "ToySource", "GemSocketEnchantment", "ItemLevel", "ItemUpgradeLevel", "SpellPassive",
    "SpellDescription", "ItemQuality", "TradeTimeRemaining", "FlavorText", "ItemSpellTriggerLearn", "LearnTransmogSet",
    "LearnTransmogIllusion", "ErrorLine", "DisabledLine", "UsageRequirement", "ItemSpellTriggerOnUse",
    "ItemSpellTriggerOnEquip", "ItemSpellTriggerOnProc", "UnitLevel", "UnitType", "UnitDead", "UnitCriteriaProgress",
    "AuraCaster" }

local function Enumerate(names)
    local enum = {}
    for i, name in ipairs(names) do enum[name] = i - 1 end
    return enum
end

local function InstallTooltips()
    H.tooltipCalls = { tooltipPre = {}, tooltipPost = {}, linePre = {}, linePost = {} }
    local function Adder(list)
        return function(kind, fn)
            local calls = H.tooltipCalls[list]
            calls[kind] = calls[kind] or {}
            table.insert(calls[kind], fn)
        end
    end
    _G.TooltipDataProcessor = { AllTypes = "ALL", AddTooltipPreCall = Adder("tooltipPre"),
        AddTooltipPostCall = Adder("tooltipPost"), AddLinePreCall = Adder("linePre"), AddLinePostCall = Adder("linePost") }
end

-- A tooltip as Blizzard's: lines as global FontStrings <name>TextLeft<i>
-- and <name>TextRight<i>, and GetLeftLine(i).
function H.NewTooltip(name, lines)
    local tip = H.BlizzardFrame("GameTooltip", name, UIParent)
    rawset(tip, "GetLeftLine", function(_, i) return _G[name .. "TextLeft" .. i] end)
    rawset(tip, "GetRightLine", function(_, i) return _G[name .. "TextRight" .. i] end)
    for i = 1, lines or 8 do
        -- Its lines: the addon may change them only inside a post-call.
        S[H.BlizzardText(name .. "TextLeft" .. i, tip, nil)].tipLine = true
        S[H.BlizzardText(name .. "TextRight" .. i, tip, nil)].tipLine = true
    end
    return tip
end

local function Each(list, kind, fn)
    local calls = {}
    for _, key in ipairs({ kind, "ALL" }) do
        for _, call in ipairs(list[key] or {}) do calls[#calls + 1] = call end
    end
    for _, call in ipairs(calls) do
        local was = blizzardCalling
        blizzardCalling = false
        tooltipCalling = true
        local ok, result = pcall(fn, call)
        tooltipCalling = false
        blizzardCalling = was
        if not ok then
            H.hookErrors[#H.hookErrors + 1] = tostring(result)
        elseif result == true then
            return true
        end
    end
end

-- Shows data (kind: an Enum.TooltipDataType; data.lines = { { type,
-- leftText, unitToken... } }) on a tooltip from H.NewTooltip.
function H.Tooltip(kind, tooltip, data)
    local calls = H.tooltipCalls
    if Each(calls.tooltipPre, kind, function(call) return call(tooltip, data) end) then return end
    local index = 0
    for _, line in ipairs(data.lines or {}) do
        if not Each(calls.linePre, line.type, function(call) return call(tooltip, line) end) then
            index = index + 1
            line.lineIndex = index
            H.Blizzard(function() tooltip:GetLeftLine(index):SetText(line.leftText) end)
            Each(calls.linePost, line.type, function(call) call(tooltip, line) end)
        end
    end
    Each(calls.tooltipPost, kind, function(call) call(tooltip, data) end)
end

-- Menus ---------------------------------------------------------------------------------------------------------------
-- Menu.ModifyMenu callbacks, run when a tagged menu opens (H.Menu). The menu
-- has a title element first; its initializers draw it: Blizzard's sets the
-- title's text, then any the addon added.

local function InstallMenus()
    H.menuCallbacks = {}
    _G.Menu = { ModifyMenu = function(tag, fn)
        H.menuCallbacks[tag] = H.menuCallbacks[tag] or {}
        table.insert(H.menuCallbacks[tag], fn)
    end }
end

local function MenuElement(kind)
    local element = { kind = kind, initializers = {} }
    function element:AddInitializer(fn) table.insert(self.initializers, fn) end
    return element
end

-- Opens a tagged menu titled title for contextData; returns the title as
-- drawn, and the menu's root.
function H.Menu(tag, contextData, title, owner)
    local titleElement = MenuElement("title")
    titleElement.initializers[1] = function(frame) H.Blizzard(function() frame.fontString:SetText(title) end) end
    local root = { elements = { titleElement, MenuElement("button") }, contextData = contextData }
    function root:EnumerateElementDescriptions() return ipairs(self.elements) end
    local was = blizzardCalling
    for _, fn in ipairs(H.menuCallbacks[tag] or {}) do
        blizzardCalling = false
        local ok, err = pcall(fn, owner, root, contextData)
        if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
    end
    local frame = { fontString = H.BlizzardText(nil, nil, "") }
    for _, init in ipairs(titleElement.initializers) do
        blizzardCalling = false
        local ok, err = pcall(init, frame, titleElement, root)
        if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
    end
    blizzardCalling = was
    return S[frame.fontString].text, root
end

-- The game ---------------------------------------------------------------------------------------------------------------

H.CLASS_COLOURS = {
    DRUID = { r = 1, g = .49, b = .04, colorStr = "ffff7c0a" }, WARRIOR = { r = .78, g = .61, b = .43, colorStr = "ffc69b6d" },
    MAGE = { r = .25, g = .78, b = .92, colorStr = "ff3fc7eb" }, PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" },
    ROGUE = { r = 1, g = .96, b = .41, colorStr = "fffff468" }, PALADIN = { r = .96, g = .55, b = .73, colorStr = "fff48cba" },
    HUNTER = { r = .67, g = .83, b = .45, colorStr = "ffaad372" }, WARLOCK = { r = .53, g = .53, b = .93, colorStr = "ff8788ee" },
    SHAMAN = { r = 0, g = .44, b = .87, colorStr = "ff0070dd" },
}
H.CLASS_NAMES = { DRUID = "Druid", WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest", ROGUE = "Rogue", PALADIN = "Paladin",
    HUNTER = "Hunter", WARLOCK = "Warlock", SHAMAN = "Shaman" }

local FONTS = { "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontNormalHuge", "GameFontHighlight",
    "GameFontHighlightSmall", "GameFontHighlightLarge", "GameFontDisable", "GameFontDisableSmall" }

-- Blizzard's frames every test has: UIParent, the minimap (140 across, its
-- button's home), a chat frame and GameTooltip.
local function BuildBlizzardFrames()
    _G.UIParent = H.BlizzardFrame("Frame", "UIParent")
    S[UIParent].width, S[UIParent].height = 1024, 768
    _G.Minimap = H.BlizzardFrame("Frame", "Minimap", UIParent)
    S[Minimap].width, S[Minimap].height = 140, 140
    H.chatFrame = H.BlizzardFrame("ScrollingMessageFrame", "ChatFrame1", UIParent)
    _G.DEFAULT_CHAT_FRAME = H.chatFrame
    H.NewTooltip("GameTooltip", 8)
end

local ADDON_GLOBALS = { "^FEPRIVACY", "^SLASH_FEPRIVACY", "^BINDING_HEADER_FEPRIVACY$", "^BINDING_NAME_FEPRIVACY",
    "^ForeverEnhancedPrivacy" }
local function Ours(key)
    if type(key) ~= "string" then return false end
    for _, pattern in ipairs(ADDON_GLOBALS) do
        if key:find(pattern) then return true end
    end
    return false
end
H.Ours = Ours

-- A fresh game, as after a restart: nothing of the addon's left.
function H.Environment()
    for key in pairs(_G) do
        if Ours(key) then _G[key] = nil end
    end
    H.objects, H.frames, H.violations, H.hooks, H.hookErrors, H.timers, H.printed = {}, {}, {}, {}, {}, {}, {}
    H.counts, H.writes, H.writeLog = {}, 0, {}
    H.lockdown, H.clock, H.raid = false, 100, false
    H.guild, H.friends = nil, {}
    blizzardCalling = false
    H.units = { player = {} }
    for key, value in pairs(H.PLAYER) do H.units.player[key] = value end
    _G.C_Timer = {
        After = function(_, fn) H.timers[#H.timers + 1] = fn end,
        NewTicker = function(_, fn) H.timers[#H.timers + 1] = fn; return { Cancel = function() end } end,
    }
    _G.GetTime = function() return H.clock end
    _G.time = function() return 1700000000 end
    _G.InCombatLockdown = function() return H.lockdown end
    _G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
    _G.RAID_CLASS_COLORS = H.CLASS_COLOURS
    _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE = H.CLASS_NAMES, H.CLASS_NAMES
    _G.UNKNOWNOBJECT = "Unknown"
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        H.printed[#H.printed + 1] = table.concat(parts, " ")
    end
    _G.issecretvalue = IsSecret
    _G.canaccessvalue = function(...) return Accessible(pack(...)) end
    _G.geterrorhandler = function() return function(err) H.hookErrors[#H.hookErrors + 1] = tostring(err) end end
    _G.Enum = { TooltipDataType = Enumerate(TOOLTIP_TYPES), TooltipDataLineType = Enumerate(LINE_TYPES) }
    for _, font in ipairs(FONTS) do _G[font] = { GetFont = function() return "font", 12, "" end } end
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.ReloadUI = function() Violation("reloaded the interface") end
    _G.SetOverrideBinding = function() Violation("changed a key binding") end
    _G.SetOverrideBindingClick = _G.SetOverrideBinding
    _G.ClearOverrideBindings = _G.SetOverrideBinding
    _G.ShowUIPanel = function() Violation("opened one of Blizzard's windows") end
    _G.HideUIPanel = function() Violation("closed one of Blizzard's windows") end
    _G.CreateFrame = function(kind, name, parent, template)
        local f = New(kind, parent)
        S[f].name, S[f].template = name, template
        H.frames[#H.frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    -- Post-hooks, as the game makes them: the original runs as whoever
    -- called it, then the hook as the addon's code. On a sealed object the
    -- hooked method is kept with its other functions, so the addon's own
    -- calls to it still go through the check (and a hooked SetText the
    -- addon calls still counts as a write).
    _G.hooksecurefunc = function(a, b, c)
        local t, key, hook = a, b, c
        if type(a) == "string" then t, key, hook = _G, a, b end
        if S[t] and S[t].protected then Violation("hooked " .. tostring(key) .. " on Blizzard's protected " .. Name(t)) end
        local original = rawget(t, key)
        if original == nil and S[t] then original = Proto[key] end
        assert(type(original) == "function", "hooked " .. tostring(key) .. ", which isn't a function")
        local function hooked(...)
            local results = pack(original(...))
            local was = blizzardCalling
            blizzardCalling = false
            local ok, err = pcall(hook, ...)
            blizzardCalling = was
            if not ok then H.hookErrors[#H.hookErrors + 1] = tostring(err) end
            return unpackAll(results, 1, results.n)
        end
        if S[t] and S[t].sealed then
            StoreField(t, key, hooked)
        else
            rawSet(t, key, hooked)
        end
        H.hooks[#H.hooks + 1] = { t = t, key = key }
    end
    H.addOns = {}
    _G.C_AddOns = { IsAddOnLoaded = function(name)
        local on = H.addOns[name] == true
        return on, on
    end }
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(canvas, title) return { canvas = canvas, title = title } end,
        RegisterAddOnCategory = function(category) H.category = category end,
    }
    H.category = nil
    InstallUnits()
    InstallSocial()
    InstallCVars()
    InstallChat()
    InstallTooltips()
    InstallMenus()
    BuildBlizzardFrames()
    _G.ForeverEnhancedPrivacyDB = nil
end

-- Loads the addon's files as the game does, then logs in: ADDON_LOADED,
-- PLAYER_LOGIN and the first PLAYER_ENTERING_WORLD (a fresh login, or a
-- /reload with opts.reload). opts.beforeLogin stops after ADDON_LOADED.
-- Returns the addon's namespace.
function H.Load(saved, opts)
    opts = opts or {}
    H.before = {}
    for key in pairs(_G) do H.before[key] = true end
    local P = {}
    _G.ForeverEnhancedPrivacyDB = saved
    for _, file in ipairs(H.FILES) do assert(loadfile(file))(H.ADDON, P) end
    H.Fire("ADDON_LOADED", H.ADDON)
    if not opts.beforeLogin then
        H.Fire("PLAYER_LOGIN")
        H.Login(opts.reload)
    end
    return P
end

-- The first PLAYER_ENTERING_WORLD: a fresh login, or a /reload.
function H.Login(reload)
    H.Fire("PLAYER_ENTERING_WORLD", not reload, reload and true or false)
end

-- An addon of Blizzard's loading on demand.
function H.LoadAddOn(name)
    H.addOns[name] = true
    H.Fire("ADDON_LOADED", name)
end

-- The global names the addon has added since it began loading.
function H.NewGlobals()
    local added = {}
    for key in pairs(_G) do
        if not H.before[key] then added[#added + 1] = tostring(key) end
    end
    table.sort(added)
    return added
end

-- The newest region showing this text (or containing it, with part).
function H.Find(text, part)
    for i = #H.objects, 1, -1 do
        local s = S[H.objects[i]]
        if s and (rawequal(s.text, text) or (part and type(s.text) == "string" and s.text:find(text, 1, true))) then
            return H.objects[i]
        end
    end
end

-- Whether a region sits somewhere inside root.
function H.Under(region, root)
    local parent = S[region] and S[region].parent
    while parent do
        if parent == root then return true end
        parent = S[parent] and S[parent].parent
    end
    return false
end

-- Runs a frame's script as the game would (OnEnter, OnLeave, OnClick...).
function H.Script(frame, script, ...)
    local fn = S[frame].scripts[script]
    if fn then return fn(frame, ...) end
end

-- Everything that went wrong, as one line: rule violations, hook errors and
-- anything printed.
function H.Problems()
    local list = {}
    for _, v in ipairs(H.violations) do list[#list + 1] = v end
    for _, e in ipairs(H.hookErrors) do list[#list + 1] = "hook error: " .. e end
    for _, p in ipairs(H.printed) do list[#list + 1] = "printed: " .. tostring(p) end
    return table.concat(list, " | ")
end

-- Clears what's been printed and gone wrong so far (after a check of it).
function H.Clear()
    H.violations, H.hookErrors, H.printed = {}, {}, {}
end

return H
