-- The eye: a small eye at the top of the screen while private mode is on,
-- so you can see it's working (the Extras tick turns it off). It steps
-- aside the moment a screenshot starts and comes back once it's taken. Our
-- own frame, made the first time it's needed, and never takes the mouse.
local _, P = ...

local Eye = {}
P.Eye = Eye

local frame

local function Build()
    frame = CreateFrame("Frame", "ForeverEnhancedPrivacyEye", UIParent)
    frame:SetSize(22, 14)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -6)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(P.MEDIA .. "Eye.tga")
    -- The eye sits in rows 12 to 52 of its 64 by 64 picture.
    icon:SetTexCoord(0, 1, 12 / 64, 52 / 64)
    icon:SetVertexColor(P.ACCENT[1], P.ACCENT[2], P.ACCENT[3])
    icon:SetAlpha(.85)
    frame.icon = icon
    frame:Hide()
end

function Eye:Wanted()
    return P:Private() and P:Get("eye") == true and not P:Shooting()
end

function Eye:Refresh()
    local show = self:Wanted()
    if show and not frame then Build() end
    if frame then frame:SetShown(show) end
end

function Eye:Frame()
    return frame
end

P:Listen(function() Eye:Refresh() end)
