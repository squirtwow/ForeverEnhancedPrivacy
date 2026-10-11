-- The settings window's look: flat dark panels with thin borders, gold
-- headings, and the family purple as the one accent. Every piece is given
-- its size as it's made, so nothing waits on a first refresh to have one.
local _, P = ...

local T = {}
P.Theme = T

local FLAT = "Interface\\Buttons\\WHITE8X8"

local function Rgb(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

T.C = {
    window = Rgb("0e1014"), edge = Rgb("2a2d35"),
    nav = Rgb("06070a"), navEdge = Rgb("22252c"), navHover = Rgb("0c0e12"), navSelected = Rgb("12151b"),
    text = Rgb("e8e6e1"), soft = Rgb("94a0ad"), muted = Rgb("8d96a3"), dim = Rgb("6f7a86"),
    gold = Rgb("edbf52"), tag = Rgb("a39a86"),
    row = Rgb("14171c"), rowEdge = Rgb("1d2128"), rowHover = Rgb("1a1e25"), rowHoverEdge = Rgb("2c313a"),
    tickEdge = Rgb("4d525c"), tickBack = Rgb("0f1013"),
    option = Rgb("0f1216"), optionEdge = Rgb("2f343e"), onAccent = Rgb("0d0e12"),
    field = Rgb("0c0e12"), button = Rgb("1b1f27"), buttonEdge = Rgb("3a3f4a"),
    panel = Rgb("0a0c10"), panelEdge = Rgb("23262d"), card = Rgb("12151a"), cardEdge = Rgb("262a31"),
    zone = Rgb("c9b27a"), health = Rgb("1f7a32"), mana = Rgb("8a1f1f"), portrait = Rgb("2a2622"), portraitEdge = Rgb("5c5040"),
}
T.ACCENT = P.ACCENT

function T:Hex(colour)
    local function Byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + .5) end
    return ("%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3]))
end

-- Text in a colour, for one piece of a longer line.
function T:Paint(text, colour)
    return "|cff" .. self:Hex(colour) .. text .. "|r"
end

function T:Fill(texture, colour, alpha)
    texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
end

function T:Flat(frame, fill, edge)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(fill[1], fill[2], fill[3], 1)
    edge = edge or self.C.edge
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

-- A plain colour block.
function T:Block(parent, colour, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    self:Fill(texture, colour)
    return texture
end

function T:Text(parent, font, colour)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetJustifyH("LEFT")
    colour = colour or self.C.text
    text:SetTextColor(colour[1], colour[2], colour[3])
    return text
end

-- A section heading: small gold capitals.
function T:Heading(parent, label)
    local text = self:Text(parent, "GameFontNormalSmall", self.C.gold)
    text:SetText(label:upper())
    return text
end

-- A row the width given, with a square tick in the accent, its label and a
-- quiet tag after it (lower case, never boxed).
function T:Tick(parent, width, label, tag)
    local C = self.C
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(width, 30)
    self:Flat(row, C.row, C.rowEdge)
    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(13, 13)
    box:SetPoint("LEFT", 10, 0)
    self:Flat(box, C.tickBack, C.tickEdge)
    box:EnableMouse(false)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    self:Fill(fill, self.ACCENT)
    fill:Hide()
    row.box, row.fill = box, fill
    row.label = self:Text(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", box, "RIGHT", 9, 0)
    row.label:SetText(label)
    if tag then
        row.tag = self:Text(row, "GameFontHighlightSmall", C.tag)
        row.tag:SetPoint("LEFT", row.label, "RIGHT", 5, 0)
        row.tag:SetText(tag:lower())
    end
    function row:SetChecked(on)
        self.checked = on and true or false
        self.fill:SetShown(self.checked)
    end
    function row:GetChecked()
        return self.checked == true
    end
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
        self:SetBackdropBorderColor(C.rowHoverEdge[1], C.rowHoverEdge[2], C.rowHoverEdge[3], 1)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.row[1], C.row[2], C.row[3], 1)
        self:SetBackdropBorderColor(C.rowEdge[1], C.rowEdge[2], C.rowEdge[3], 1)
    end)
    row:SetChecked(false)
    return row
end

-- One choice among several; the chosen one fills with the accent.
function T:Option(parent, label)
    local C = self.C
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.label = self:Text(button, "GameFontNormalSmall", C.soft)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label)
    button:SetSize(math.floor((button.label:GetStringWidth() or 60) + 20 + .5), 24)
    self:Flat(button, C.option, C.optionEdge)
    function button:SetSelected(on)
        self.selected = on and true or false
        local fill = self.selected and T.ACCENT or C.option
        local edge = self.selected and T.ACCENT or C.optionEdge
        local text = self.selected and C.onAccent or C.soft
        self:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        self:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        self.label:SetTextColor(text[1], text[2], text[3])
        -- The font's dark shadow smears dark text on the accent.
        self.label:SetShadowColor(0, 0, 0, self.selected and 0 or 1)
    end
    button:SetScript("OnEnter", function(self)
        if not self.selected then self.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end
    end)
    button:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
    button:SetSelected(false)
    return button
end

-- Options side by side from the left, 6 apart: { key, label } each.
-- onPick(key) runs on a click. Returns the bar, sized to fit, and its
-- buttons by key.
function T:Options(parent, items, onPick)
    local bar = CreateFrame("Frame", nil, parent)
    bar.buttons, bar.order = {}, {}
    local x = 0
    for _, item in ipairs(items) do
        local button = self:Option(bar, item.label)
        button:SetPoint("LEFT", x, 0)
        button.key = item.key
        button:SetScript("OnClick", function() onPick(item.key) end)
        bar.buttons[item.key] = button
        bar.order[#bar.order + 1] = button
        x = x + button:GetWidth() + 6
    end
    bar:SetSize(math.max(1, x - 6), 24)
    function bar:Select(key)
        self.selected = key
        for buttonKey, button in pairs(self.buttons) do button:SetSelected(buttonKey == key) end
    end
    return bar
end

-- A full-width row: its label on the left and its options on the right.
function T:Choice(parent, width, label, items, onPick)
    local C = self.C
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(width, 34)
    self:Flat(row, C.row, C.rowEdge)
    row:EnableMouse(true)
    row.label = self:Text(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", 12, 0)
    row.label:SetText(label)
    row.options = self:Options(row, items, onPick)
    row.options:SetPoint("RIGHT", -6, 0)
    function row:Select(key)
        self.options:Select(key)
    end
    return row
end

-- A flat text box with a grey placeholder while it's empty and unfocused.
function T:Input(parent, width, placeholder)
    local C = self.C
    local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(width, 30)
    self:Flat(input, C.field, C.optionEdge)
    input:SetFontObject("GameFontHighlight")
    input:SetTextInsets(10, 10, 0, 0)
    input:SetAutoFocus(false)
    input.placeholder = self:Text(input, "GameFontHighlight", C.dim)
    input.placeholder:SetPoint("LEFT", 10, 0)
    input.placeholder:SetText(placeholder)
    function input:ShowPlaceholder()
        self.placeholder:SetShown(not self:HasFocus() and (self:GetText() or "") == "")
    end
    input:SetScript("OnEditFocusGained", function(self) self.placeholder:Hide() end)
    return input
end

-- A small square button (the window's close).
function T:Square(parent, label)
    local C = self.C
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(22, 22)
    self:Flat(button, C.option, C.optionEdge)
    button.label = self:Text(button, "GameFontHighlight", C.soft)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label)
    button:SetScript("OnEnter", function(self) self.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
    button:SetScript("OnLeave", function(self) self.label:SetTextColor(C.soft[1], C.soft[2], C.soft[3]) end)
    return button
end

-- A list that scrolls with the mouse wheel, pinned by two corners to the
-- parent (insets: left, top, right, bottom), with a thin accent thumb. Its
-- content is width wide; set its height once filled.
function T:Scroll(parent, insets, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    -- Pinned again a moment after its page shows (Window.lua): a scroll
    -- frame first laid out under a parent with no size can stay blank.
    function scroll:Pin()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", insets[1], -insets[2])
        self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insets[3], insets[4])
    end
    scroll:Pin()
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    local thumb = parent:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    self:Fill(thumb, self.ACCENT, .8)
    thumb:Hide()
    scroll.thumb = thumb
    local function Range()
        local view = scroll:GetHeight() or 0
        if view <= 0 then return 0 end
        return math.max(0, (content:GetHeight() or 0) - view)
    end
    function scroll:UpdateThumb()
        local view, range = self:GetHeight() or 0, Range()
        if range <= 0 or view <= 0 then
            thumb:Hide()
            return
        end
        local size = math.max(16, view * view / (view + range))
        local offset = (view - size) * (self:GetVerticalScroll() or 0) / range
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, -offset)
        thumb:Show()
    end
    function scroll:ScrollTo(offset)
        self:SetVerticalScroll(math.max(0, math.min(Range(), offset)))
        self:UpdateThumb()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) self:ScrollTo((self:GetVerticalScroll() or 0) - delta * 40) end)
    scroll:SetScript("OnSizeChanged", function(self) self:ScrollTo(self:GetVerticalScroll() or 0) end)
    return scroll
end
