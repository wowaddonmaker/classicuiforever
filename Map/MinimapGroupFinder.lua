local _, ns = ...

-- Classic's group finder eye on the minimap ring, while the micro menu's group finder button is hidden. Its click goes
-- through a secure pad onto that hidden button, so the finder opens in the player's name. Face: the first eye frame, cropped.

local EYE = { layer = "ARTWORK", coords = { 0.019, 0.106, 0.0375, 0.2125 }, w = 24, h = 24, point = "CENTER", relPoint = "TOPLEFT",
    x = ns.RING_ICON_FACE.x, y = ns.RING_ICON_FACE.y }

local function Wanted()
    local db = ns.db
    return db and db.lfgMinimapButton == true and db.hideMicroButtons == true and db.hideMicroGroupFinder == true
        and _G.LFDMicroButton ~= nil
end

local padded = false
local ShowRing, HideRing = ns.RingButton({
    name = "ForeverClassicUIGroupFinderButton",
    key = "minimapGroupFinder",
    angleKey = "lfgButtonAngle",
    angle = 137,   -- Era's LFG eye spot (backdrop top left +25, -28)
    show = "GroupFinderButton",
    face = function(icon) ns.Dress(icon, "lfgEye", EYE) end,
    tip = { anchor = "ANCHOR_LEFT", text = function()
        local name = _G.LFG_BUTTON or "Group Finder"
        return MicroButtonTooltipText and MicroButtonTooltipText(name, "TOGGLEGROUPFINDER") or name
    end, r = 1, g = 1, b = 1 },
})

local function Apply()
    if not Wanted() then
        HideRing()
        return
    end
    ShowRing()
    local button = _G.ForeverClassicUIGroupFinderButton
    if button and not padded then
        padded = true
        ns.MapPad(button, "MEDIUM", nil, _G.LFDMicroButton)
    end
end

ns.RegisterModule("lfgMinimapButton", { apply = Apply, restore = HideRing })
