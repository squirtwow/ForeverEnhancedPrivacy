-- The /privacy window: pages down the left, the page on the right and a
-- footer that explains whatever is under the mouse. The Overview has the
-- big private mode button, how it turns on, how names look, your own name,
-- a made-up BattleTag, their colour, the eye, and a live preview of sample
-- names. Every other page is drawn from Core.lua's rows, so the modules
-- never touch the window.
local _, P = ...

local T = P.Theme
local C = T.C

local WIDTH, HEIGHT, NAV, FOOTER = 900, 580, 200, 46
local PAGE_W, PAGE_H = WIDTH - NAV - 2, HEIGHT - FOOTER - 5
local PAD, BODY_TOP = 24, 82
local INNER = PAGE_W - PAD * 2
local GAP, ROW_H, ROW_GAP = 10, 30, 4
local COLUMN = math.floor((INNER - GAP) / 2)
local LEFT_W = 350
local LEFT_H = 438 -- the Overview's left column, down to the key note; ends 9 above the footer
local PREVIEW_X = PAD + LEFT_W + 22
local PREVIEW_W, PREVIEW_H = PAGE_W - PREVIEW_X - PAD, 354

P.WINDOW_SIZE = { WIDTH, HEIGHT }

-- "Made with <heart> by Squirt", the heart and name in the accent. The
-- font has no heart, so it's a small white texture tinted inline.
local function Credit()
    local r, g, b = math.floor(P.ACCENT[1] * 255 + .5), math.floor(P.ACCENT[2] * 255 + .5), math.floor(P.ACCENT[3] * 255 + .5)
    return ("Made with |T%sHeart.tga:0:0:0:0:32:32:0:32:0:32:%d:%d:%d|t by |cff%sSquirt|r"):format(P.MEDIA, r, g, b, P.ACCENT_HEX)
end
P.Credit = Credit

-- The footer ----------------------------------------------------------------------------------

local function BuildFooter(window)
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", NAV + 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetSize(PAGE_W, FOOTER)
    local line = T:Block(footer, C.navEdge, "BORDER")
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    local note = T:Text(footer, "GameFontHighlightSmall", C.soft)
    note:SetPoint("TOPLEFT", PAD, -6)
    note:SetPoint("BOTTOMRIGHT", -PAD, 5)
    note:SetJustifyV("MIDDLE")
    note:SetWordWrap(true)
    window.note = note

    -- At rest the footer shows the last thing said, or the credit.
    function window:ShowNote()
        local control = self.hovered
        if control and not control:IsVisible() then control, self.hovered = nil, nil end
        local text
        if control then
            local about = control.hintText
            if type(about) == "function" then about = about(control) end
            text = T:Paint(control.hintTitle, C.text) .. "  " .. (about or "")
        end
        note:SetText(text or self.message or Credit())
    end
    function window:Say(text)
        self.message = text
        self:ShowNote()
    end
    function window:Note(control)
        self.hovered = control
        self:ShowNote()
    end
    -- Only the control whose note is up can take it down.
    function window:Unnote(control)
        if self.hovered ~= control then return end
        self.hovered = nil
        self:ShowNote()
    end
    -- text: the note, or a function for one that changes.
    function window:Hint(control, title, text)
        control.hintTitle, control.hintText = title, text
        control:HookScript("OnEnter", function() window:Note(control) end)
        control:HookScript("OnLeave", function() window:Unnote(control) end)
    end
end

-- The page list -----------------------------------------------------------------------------------

local function NavItem(window, nav, page, y)
    local item = CreateFrame("Button", nil, nav)
    item:SetPoint("TOPLEFT", 0, -y)
    item:SetSize(NAV, 32)
    item.fill = T:Block(item, C.navSelected)
    item.fill:SetAllPoints()
    item.hover = T:Block(item, C.navHover)
    item.hover:SetAllPoints()
    item.hover:Hide()
    item.mark = T:Block(item, T.ACCENT, "ARTWORK")
    item.mark:SetPoint("TOPLEFT")
    item.mark:SetPoint("BOTTOMLEFT")
    item.mark:SetWidth(3)
    item.label = T:Text(item, "GameFontHighlight", C.soft)
    item.label:SetPoint("LEFT", 18, 0)
    item.label:SetText(page.label)
    item.key = page.key
    item:SetScript("OnClick", function() window:Select(page.key) end)
    item:SetScript("OnEnter", function(self)
        if window.selected ~= self.key then
            self.hover:Show()
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end)
    item:SetScript("OnLeave", function(self)
        self.hover:Hide()
        local colour = window.selected == self.key and C.text or C.soft
        self.label:SetTextColor(colour[1], colour[2], colour[3])
    end)
    window:Hint(item, page.label, page.about)
    return item
end

local function BuildNav(window)
    local nav = CreateFrame("Frame", nil, window, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 1, -4)
    nav:SetPoint("BOTTOMLEFT", 1, 1)
    nav:SetSize(NAV, HEIGHT - 5)
    T:Flat(nav, C.nav, C.nav)
    local edge = T:Block(nav, C.navEdge, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    local title = T:Text(nav, "GameFontNormalLarge", T.ACCENT)
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetWidth(NAV - 30)
    title:SetText(P.TITLE)
    window.title = title
    local status = T:Text(nav, "GameFontHighlightSmall", C.muted)
    status:SetPoint("TOPLEFT", 18, -64)
    window.status = status
    window.nav = {}
    local y = 88
    for _, page in ipairs(P.PAGES) do
        window.nav[page.key] = NavItem(window, nav, page, y)
        y = y + 32
    end
    local open = T:Text(nav, "GameFontHighlightSmall", C.dim)
    open:SetPoint("BOTTOMLEFT", 18, 16)
    open:SetText(P.SLASH .. " to open")
    window.navFrame = nav
end

-- The Overview ---------------------------------------------------------------------------------------

local function Heading(parent, label, y)
    local heading = T:Heading(parent, label)
    heading:SetPoint("TOPLEFT", 0, -y)
    return heading
end

local function Help(list, key)
    for _, item in ipairs(list) do
        if item.key == key then return item.help .. (item.tag and (" (" .. item.tag .. ")") or "") end
    end
    return ""
end

local function BuildBigButton(window, left)
    local big = CreateFrame("Button", nil, left, "BackdropTemplate")
    big:SetSize(LEFT_W, 44)
    big:SetPoint("TOPLEFT")
    T:Flat(big, C.button, C.buttonEdge)
    big.label = T:Text(big, "GameFontNormalLarge", C.text)
    big.label:SetPoint("CENTER")
    big.label:SetJustifyH("CENTER")
    big:SetScript("OnClick", function() P:SetPrivate(not P:Private(), "window") end)
    function big:Refresh()
        local on = P:Private()
        local fill = on and T.ACCENT or C.button
        local edge = on and T.ACCENT or C.buttonEdge
        local text = on and C.onAccent or C.text
        self:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        self:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        self.label:SetText(on and "Private mode is on. Turn it off" or "Turn private mode on")
        self.label:SetTextColor(text[1], text[2], text[3])
        self.label:SetShadowColor(0, 0, 0, on and 0 or 1)
    end
    window:Hint(big, "Private mode", "Hides or swaps everything ticked on these pages. Turn it off and it all comes back, "
        .. "apart from chat lines that were cleaned or hidden.")
    window.privateButton = big
end

local function BuildChoices(window, left)
    local heading = Heading(left, "How it turns on", 60)
    local modes = T:Options(left, P.MODES, function(key) P:Set("mode", key) end)
    modes:SetPoint("TOPLEFT", 0, -78)
    for _, button in ipairs(modes.order) do
        window:Hint(button, button.label:GetText(), function() return Help(P.MODES, button.key) end)
    end
    window.modes = modes
    -- A quiet word after the heading while the experimental mode is chosen
    -- (after the buttons it would run into the preview).
    local tag = T:Text(left, "GameFontHighlightSmall", C.tag)
    tag:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    tag:SetText("experimental")
    window.modeTag = tag

    Heading(left, "Names become", 116)
    local styles = T:Options(left, P.STYLES, function(key) P:Set("nameStyle", key) end)
    styles:SetPoint("TOPLEFT", 0, -134)
    for _, button in ipairs(styles.order) do
        window:Hint(button, button.label:GetText(), function() return Help(P.STYLES, button.key) end)
    end
    window.styles = styles
end

-- The typed settings: your name, then the made-up BattleTag under it. Each
-- saves (tidied by the core) when its box loses focus or Enter is pressed;
-- Escape puts the saved one back.
local TEXT_BOXES = {
    { key = "myName", field = "nameBox", title = "Your name becomes", y = 172, most = P.NAME_MAX,
        placeholder = "Leave empty to use the setting above",
        help = "The name you show as while private mode is on: frames, chat, tooltips, and NPCs who say your name. Empty: your "
            .. "name follows the setting above." },
    { key = "myTag", field = "tagBox", title = "Your BattleTag becomes", y = 234, most = P.TAG_MAX,
        placeholder = "Leave empty to use your name above",
        help = "A made-up BattleTag shown instead of yours in the friends windows. Empty: your name above, or \"Battle.net\"." },
}

local function BuildTextBox(window, left, setting)
    Heading(left, setting.title, setting.y)
    local box = T:Input(left, LEFT_W, setting.placeholder)
    box:SetPoint("TOPLEFT", 0, -(setting.y + 18))
    box:SetMaxLetters(setting.most)
    box.key = setting.key
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(P:Get(setting.key))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        P:Set(setting.key, self:GetText() or "")
        self:SetText(P:Get(setting.key))
        self:ShowPlaceholder()
    end)
    window:Hint(box, setting.title, setting.help)
    window[setting.field] = box
    window.textBoxes[#window.textBoxes + 1] = box
end

local function BuildColours(window, left)
    Heading(left, "Name colour", 296)
    local colours = T:Options(left, P.COLOURS, function(key) P:Set("myColour", key) end)
    colours:SetPoint("TOPLEFT", 0, -314)
    for _, button in ipairs(colours.order) do
        window:Hint(button, "Name colour: " .. button.label:GetText(), P.COLOUR_HELP)
    end
    window.colours = colours
end

local function BuildExtras(window, left)
    Heading(left, "Extras", 352)
    local eye = T:Tick(left, LEFT_W, P.EYE_ROW.label)
    eye:SetPoint("TOPLEFT", 0, -370)
    eye:SetScript("OnClick", function() P:Set("eye", not P:Get("eye")) end)
    window:Hint(eye, P.EYE_ROW.label, P.EYE_ROW.desc)
    window.eyeRow = eye
    local keyNote = T:Text(left, "GameFontHighlightSmall", C.muted)
    keyNote:SetPoint("TOPLEFT", 0, -412)
    keyNote:SetWidth(LEFT_W)
    keyNote:SetText("Set its key in the game's Key Bindings, under AddOns.")
    window.keyNote = keyNote
end

-- The preview's sample people and chat.
local TARGET = { name = "Brannoc Stonehelm", class = "WARRIOR" }
local PARTY = { { name = "Merrin Lightfoot", class = "PRIEST" }, { name = "Kaelis Dawnbrook", class = "MAGE" } }
local CHAT = {
    { channel = "[Guild]", colour = "40ff40", me = true, text = "anyone up for Deadmines?" },
    { channel = "[1. General - Stormwind]", short = "[1. General]", colour = "ffc0c0", sample = PARTY[1], text = "LF tank for Stockades" },
    { channel = "[Party]", colour = "aaaaff", sample = PARTY[2], text = "water up, 2 min" },
}
-- A friend coming online, as chat shows it. Chat can't rename them (the game
-- builds the line from their account), so private mode leaves the line out.
local TOAST = { real = "Beatrix (Bea#2231)", text = " has come online.", colour = "00ccff" }

local function Card(parent, width, height, fill, edge)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    T:Flat(card, fill, edge)
    return card
end

local function BuildPreviewTarget(view, panel)
    local target = Card(panel, PREVIEW_W - 24, 54, C.card, C.cardEdge)
    target:SetPoint("TOPLEFT", 12, -34)
    local portrait = Card(target, 36, 36, C.portrait, C.portraitEdge)
    portrait:SetPoint("LEFT", 8, 0)
    view.target = T:Text(target, "GameFontNormal")
    view.target:SetPoint("TOPLEFT", 54, -9)
    view.target:SetWidth(PREVIEW_W - 24 - 64)
    local health = T:Block(target, C.health, "ARTWORK")
    health:SetPoint("TOPLEFT", 54, -27)
    health:SetSize(PREVIEW_W - 24 - 64, 7)
    local mana = T:Block(target, C.mana, "ARTWORK")
    mana:SetPoint("TOPLEFT", 54, -37)
    mana:SetSize(PREVIEW_W - 24 - 64, 5)
end

local function BuildPreviewLists(view, panel)
    view.party = {}
    for i = 1, 3 do
        local row = Card(panel, PREVIEW_W - 24, 22, C.card, C.card)
        row:SetPoint("TOPLEFT", 12, -96 - (i - 1) * 25)
        local edge = T:Block(row, C.health, "ARTWORK")
        edge:SetPoint("TOPLEFT")
        edge:SetPoint("BOTTOMLEFT")
        edge:SetWidth(3)
        view.party[i] = T:Text(row, "GameFontHighlightSmall")
        view.party[i]:SetPoint("LEFT", 10, 0)
    end
    -- Room for every chat line to wrap onto a second row.
    local chat = Card(panel, PREVIEW_W - 24, 140, C.panel, C.rowEdge)
    chat:SetPoint("TOPLEFT", 12, -178)
    view.chat = {}
    for i = 1, 4 do
        local line = T:Text(chat, "GameFontHighlightSmall")
        if i == 1 then
            line:SetPoint("TOPLEFT", 8, -8)
        else
            line:SetPoint("TOPLEFT", view.chat[i - 1], "BOTTOMLEFT", 0, -4)
        end
        line:SetWidth(PREVIEW_W - 40)
        line:SetWordWrap(true)
        view.chat[i] = line
    end
    view.zone = T:Text(panel, "GameFontHighlightSmall", C.zone)
    view.zone:SetPoint("TOPLEFT", 14, -330)
    view.coords = T:Text(panel, "GameFontHighlightSmall", C.muted)
    view.coords:SetPoint("TOPRIGHT", -14, -330)
    view.coords:SetJustifyH("RIGHT")
end

local function BuildPreview(window, page)
    local panel = Card(page, PREVIEW_W, PREVIEW_H, C.panel, C.panelEdge)
    panel:SetPoint("TOPLEFT", PREVIEW_X, -BODY_TOP)
    local view = { panel = panel }
    local label = T:Text(panel, "GameFontNormalSmall", C.dim)
    label:SetPoint("TOPLEFT", 14, -12)
    label:SetText("PREVIEW")
    view.eye = panel:CreateTexture(nil, "ARTWORK")
    view.eye:SetSize(22, 14)
    view.eye:SetPoint("TOPRIGHT", -12, -10)
    view.eye:SetTexture(P.MEDIA .. "Eye.tga")
    view.eye:SetTexCoord(0, 1, 12 / 64, 52 / 64)
    view.eye:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3])
    BuildPreviewTarget(view, panel)
    BuildPreviewLists(view, panel)
    window.preview = view
end

local function BuildOverview(window, page)
    local left = CreateFrame("Frame", nil, page)
    left:SetPoint("TOPLEFT", PAD, -BODY_TOP)
    left:SetSize(LEFT_W, LEFT_H)
    window.column = left
    BuildBigButton(window, left)
    BuildChoices(window, left)
    window.textBoxes = {}
    for _, setting in ipairs(TEXT_BOXES) do BuildTextBox(window, left, setting) end
    BuildColours(window, left)
    BuildExtras(window, left)
    BuildPreview(window, page)
end

-- How a sample name shows: as it is unless private mode and its row are on.
-- A label with no colour (your typed name in the game's own) shows in the
-- colour the real name has here.
local function Shown(real, classFile, key, isMe)
    if not P:IsOn(key) then return real, C.text end
    local label, r, g, b
    if isMe then
        label, r, g, b = P:MyLabel()
    else
        label, r, g, b = P:StyleLabel(classFile)
    end
    if not r then return label, C.text end
    return label, { r, g, b }
end

local function MySample()
    local _, full = P:MyNames()
    local ok, _, classFile = pcall(UnitClass, "player")
    if not ok or P.IsSecret(classFile) then classFile = nil end
    return full or "You", classFile
end

local function ChatLine(line, myName, myClass)
    local channel = line.channel
    if line.short and P:IsOn("channels") then channel = line.short end
    local real, classFile = myName, myClass
    if line.sample then real, classFile = line.sample.name, line.sample.class end
    local name, colour = Shown(real, classFile, "chatNames", line.me)
    local chColour = { tonumber(line.colour:sub(1, 2), 16) / 255, tonumber(line.colour:sub(3, 4), 16) / 255,
        tonumber(line.colour:sub(5, 6), 16) / 255 }
    local who = name ~= "" and (" " .. T:Paint("[" .. name .. "]", colour)) or ""
    return T:Paint(channel, chColour) .. who .. T:Paint(": " .. line.text, chColour)
end

local function RefreshPreview(window)
    local view = window.preview
    local myName, myClass = MySample()
    local name, colour = Shown(TARGET.name, TARGET.class, "targetFrames")
    view.target:SetText(name)
    view.target:SetTextColor(colour[1], colour[2], colour[3])
    local people = { PARTY[1], PARTY[2], { name = myName, class = myClass, me = true } }
    for i, person in ipairs(people) do
        name, colour = Shown(person.name, person.class, person.me and "playerFrame" or "groupFrames", person.me)
        view.party[i]:SetText(name)
        view.party[i]:SetTextColor(colour[1], colour[2], colour[3])
    end
    for i, line in ipairs(CHAT) do view.chat[i]:SetText(ChatLine(line, myName, myClass)) end
    local dropped = P:IsOn("chatNames") or P:IsOn("bnToasts")
    view.chat[4]:SetText(dropped and "" or ("|cff" .. TOAST.colour .. TOAST.real .. TOAST.text .. "|r"))
    view.zone:SetText(P:IsOn("zoneText") and "" or "Stormwind City")
    view.coords:SetText(P:IsOn("coords") and "" or "48.2, 61.7")
    view.eye:SetShown(P:Private() and P:Get("eye") == true)
end

local function RefreshOverview(window)
    window.privateButton:Refresh()
    window.modes:Select(P:Get("mode"))
    window.modeTag:SetShown(P:Get("mode") == "shots")
    window.styles:Select(P:Get("nameStyle"))
    window.colours:Select(P:Get("myColour"))
    for _, box in ipairs(window.textBoxes) do
        if not box:HasFocus() then
            box:SetText(P:Get(box.key))
            box:ShowPlaceholder()
        end
    end
    window.eyeRow:SetChecked(P:Get("eye"))
    RefreshPreview(window)
end

-- The list pages ----------------------------------------------------------------------------------

local function TickControl(window, content, row, x, y)
    local tick = T:Tick(content, COLUMN, row.label, row.tag)
    tick:SetPoint("TOPLEFT", x, -y)
    tick:SetScript("OnClick", function() P:Set(row.key, not P:Get(row.key)) end)
    return tick
end

local function ChoiceControl(window, content, row, y)
    local choice = T:Choice(content, INNER, row.label, row.options, function(key) P:Set(row.key, key) end)
    choice:SetPoint("TOPLEFT", 0, -y)
    for _, button in ipairs(choice.options.order) do
        window:Hint(button, row.label .. ": " .. button.label:GetText(), row.desc)
    end
    return choice
end

local function BuildList(window, page, sections)
    local scroll = T:Scroll(page, { PAD, BODY_TOP, PAD, 8 }, INNER)
    page.scroll = scroll
    local content = scroll.content
    local y = 0
    for _, section in ipairs(sections) do
        Heading(content, section.title, y)
        y = y + 20
        local column = 0
        for _, row in ipairs(section.rows) do
            local control
            if row.options then
                if column == 1 then y, column = y + ROW_H + ROW_GAP, 0 end
                control = ChoiceControl(window, content, row, y)
                y = y + 34 + ROW_GAP
            else
                control = TickControl(window, content, row, column * (COLUMN + GAP), y)
                if column == 1 then y, column = y + ROW_H + ROW_GAP, 0 else column = 1 end
            end
            window:Hint(control, row.label, row.desc .. (row.tag and (" (" .. row.tag .. ")") or ""))
            window.controls[row.key] = control
        end
        if column == 1 then y = y + ROW_H + ROW_GAP end
        y = y + 14
    end
    content:SetHeight(y)
end

local function BuildLimits(window, page)
    local scroll = T:Scroll(page, { PAD, BODY_TOP, PAD, 8 }, INNER)
    page.scroll = scroll
    local content = scroll.content
    local width = math.min(INNER, 640)
    local y = 0
    window.limits = {}
    for i, limit in ipairs(P.LIMITS) do
        local card = Card(content, width, 60, C.row, C.rowEdge)
        card:SetPoint("TOPLEFT", 0, -y)
        local title = T:Text(card, "GameFontHighlight")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText(limit.title)
        local text = T:Text(card, "GameFontHighlightSmall", C.soft)
        text:SetPoint("TOPLEFT", 14, -32)
        text:SetWidth(width - 28)
        text:SetText(limit.text)
        local height = math.max(60, 32 + math.ceil(text:GetStringHeight() or 14) + 12)
        card:SetHeight(height)
        y = y + height + 10
        window.limits[i] = card
    end
    content:SetHeight(y)
end

-- The window -----------------------------------------------------------------------------------------

local function BuildPage(window, page)
    local frame = CreateFrame("Frame", nil, window)
    frame:SetPoint("TOPLEFT", NAV + 1, -4)
    frame:SetPoint("BOTTOMRIGHT", -1, FOOTER + 1)
    frame:SetSize(PAGE_W, PAGE_H)
    frame:Hide()
    local title = T:Text(frame, "GameFontNormalHuge", C.gold)
    title:SetPoint("TOPLEFT", PAD, -22)
    title:SetText(page.label)
    local about = T:Text(frame, "GameFontHighlight", C.soft)
    about:SetPoint("TOPLEFT", PAD, -52)
    about:SetWidth(INNER - 30)
    about:SetText(page.about)
    frame.title, frame.about = title, about
    if page.key == "overview" then
        BuildOverview(window, frame)
    elseif page.key == "limits" then
        BuildLimits(window, frame)
    else
        BuildList(window, frame, P.SECTIONS[page.key])
    end
    -- Pinned again a moment after it shows (see Theme.lua's T:Scroll).
    frame:SetScript("OnShow", function(self)
        local scroll = self.scroll
        if scroll then
            C_Timer.After(0, function()
                scroll:Pin()
                scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
            end)
        end
    end)
    window.pages[page.key] = frame
end

local function BuildFrame()
    local window = CreateFrame("Frame", "ForeverEnhancedPrivacyFrame", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 0, 30)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    T:Flat(window, C.window, C.edge)
    local accent = T:Block(window, T.ACCENT, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(3)
    window:Hide()
    -- Escape closes it, through the game's own list of windows it closes
    -- (never by changing key bindings, which breaks things on Forever).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "ForeverEnhancedPrivacyFrame") end
    return window
end

local function Build()
    local window = BuildFrame()
    window.pages, window.controls = {}, {}
    BuildFooter(window)
    BuildNav(window)
    for _, page in ipairs(P.PAGES) do BuildPage(window, page) end
    local close = T:Square(window, "x")
    close:SetPoint("TOPRIGHT", -10, -12)
    close:SetScript("OnClick", function() window:Hide() end)
    window:Hint(close, "Close", "Escape closes it too, and " .. P.SLASH .. " opens it again.")
    window.close = close

    window.selected = "overview"
    function window:Select(key)
        if not self.pages[key] then return end
        self.selected = key
        self.hovered = nil
        self:Refresh()
    end
    function window:Refresh()
        local on = P:Private()
        self.status:SetText("Private mode: " .. (on and T:Paint("on", T.ACCENT) or "off"))
        for key, item in pairs(self.nav) do
            local chosen = key == self.selected
            item.fill:SetShown(chosen)
            item.mark:SetShown(chosen)
            local colour = chosen and C.text or C.soft
            item.label:SetTextColor(colour[1], colour[2], colour[3])
        end
        for key, page in pairs(self.pages) do page:SetShown(key == self.selected) end
        for key, control in pairs(self.controls) do
            if P.ROWS[key].options then control:Select(P:Get(key)) else control:SetChecked(P:Get(key)) end
        end
        RefreshOverview(self)
        self:ShowNote()
    end
    window:SetScript("OnShow", function(self) self:Refresh() end)
    window:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        self.hovered, self.message = nil, nil
        for _, box in ipairs(self.textBoxes) do
            if box:HasFocus() then box:ClearFocus() end
        end
    end)
    return window
end

function P.ShowWindow()
    P.window = P.window or Build()
    P.window:Show()
    P.window:Refresh()
end

function P.ToggleWindow()
    if P.window and P.window:IsShown() then
        P.window:Hide()
    else
        P.ShowWindow()
    end
end

P:Listen(function()
    if P.window and P.window:IsShown() then P.window:Refresh() end
end)
