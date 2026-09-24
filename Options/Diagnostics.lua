local _, ns = ...

-- /fcui debug: client and frame details for bug reports.

local function FrameInfo(frame)
    if not frame then return "missing" end
    if not frame:GetLeft() then return "shown=" .. tostring(frame:IsShown()) .. " (no rect yet)" end
    return string.format("shown=%s w=%.0f h=%.0f left=%.0f bottom=%.0f scale=%.2f",
        tostring(frame:IsShown()), frame:GetWidth(), frame:GetHeight(), frame:GetLeft(), frame:GetBottom(), frame:GetEffectiveScale())
end

local function Level(frame)
    if not frame then return "missing" end
    return string.format("%s L%d %s", frame:GetFrameStrata(), frame:GetFrameLevel(), FrameInfo(frame))
end

local LEVEL_FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "MinimapCluster", "Minimap", "MinimapBackdrop", "PlayerCastingBarFrame",
    "CharacterMicroButton", "MainMenuMicroButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "QueueStatusButton", "GameTimeFrame", "TimeManagerClockButton" }
-- Windows whose combat protection is uncertain on this client.
local COMBAT_WINDOWS = { "FriendsFrame", "ForeverClassicUISpellBook", "CharacterFrame", "PlayerSpellsFrame", "WorldMapFrame" }

local function Debug()
    local version, build, _, toc = GetBuildInfo()
    ns.Print(string.format("client %s (%s) toc %s project %s", version, build, tostring(toc), tostring(WOW_PROJECT_ID)))
    local bar = ns.GetMainBar()
    ns.Print("main bar: " .. (bar and bar:GetName() or "none") .. ", classic bar: " .. ns.ClassicBarInfo())
    ns.Print("bar " .. FrameInfo(bar))
    ns.Print("micro " .. FrameInfo(MicroMenuContainer or MicroMenu))
    ns.Print("bags " .. FrameInfo(BagsBar))
    local ab1 = bar and bar.actionButtons and bar.actionButtons[1] or ActionButton1
    ns.Print("button1 " .. FrameInfo(ab1))
    if bar then
        local parent = bar:GetParent()
        ns.Print(string.format("bar strata %s level %d alpha %.2f visible %s parent %s hideBarArt %s",
            bar:GetFrameStrata(), bar:GetFrameLevel(), bar:GetAlpha(), tostring(bar:IsVisible()), parent and parent:GetName() or "?", tostring(bar.hideBarArt)))
    end
    if ab1 then
        local normal = ab1:GetNormalTexture()
        ns.Print(string.format("button1 normal tex %s %s alpha %.2f layer %s; slotArt alpha %s; icon masks %s",
            tostring(normal and normal:GetTexture()), normal and FrameInfo(normal) or "none", normal and normal:GetAlpha() or 0,
            tostring(normal and normal:GetDrawLayer()), tostring(ab1.SlotArt and ab1.SlotArt:GetAlpha()),
            tostring(ab1.icon and ab1.icon.GetNumMaskTextures and ab1.icon:GetNumMaskTextures())))
    end
    local keys = {}
    for key in pairs(ns.TEX) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local status = ns.texStatus[key]
        if status and status ~= "ok" then ns.Print("  tex " .. key .. ": " .. status) end
    end
    local missing = {}
    for name in pairs(ns.missing or {}) do missing[#missing + 1] = name end
    table.sort(missing)
    ns.Print("missing pieces: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
    for _, name in ipairs(LEVEL_FRAMES) do
        ns.Print(name .. " " .. Level(_G[name]))
    end
    ns.Print("tracking " .. Level(MinimapCluster and MinimapCluster.Tracking) .. " button " .. Level(MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button))
    ns.Print("zoomIn " .. Level(Minimap and Minimap.ZoomIn) .. " mail " .. Level(MinimapCluster and MinimapCluster.IndicatorFrame))
    local art = ForeverClassicUIBar
    ns.Print("art " .. Level(art) .. " pn " .. Level(bar and bar.ActionBarPageNumber) .. " up " .. Level(bar and bar.ActionBarPageNumber and bar.ActionBarPageNumber.UpButton))
    -- Reads UnitFrames' keys: PlayerFrame.fcui.host, host.fcui.power.
    local host = PlayerFrame and PlayerFrame.fcui and PlayerFrame.fcui.host
    local power = host and host.fcui and host.fcui.power
    if power then
        local r, g, b = power:GetStatusBarColor()
        local tex = power:GetStatusBarTexture()
        ns.Print(string.format("our power bar color %.2f %.2f %.2f value %s of %s tex %s shown %s %s", r or -1, g or -1, b or -1,
            tostring(power:GetValue()), tostring(select(2, power:GetMinMaxValues())), tostring(tex and tex:GetTexture()), tostring(power:IsShown()), FrameInfo(power)))
        local ptype, token = UnitPowerType("player")
        ns.Print("player power type " .. tostring(ptype) .. " token " .. tostring(token) .. " secret " .. tostring(ns.IsSecret(token)))
        local main = PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        ns.Print("blizz mana area alpha " .. tostring(main and main.ManaBarArea and main.ManaBarArea:GetAlpha()) .. " alt power shown " .. tostring(main and main.AlternatePowerBarArea and main.AlternatePowerBarArea:IsShown()))
    end
    local ftex = PlayerFrame and PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContainer.FrameTexture
    ns.Print("player frame texture " .. tostring(ftex and ftex:GetTexture()) .. " atlas " .. tostring(ftex and ftex:GetAtlas()) .. " " .. (ftex and FrameInfo(ftex) or ""))
    ns.Print("spellbook in a fight: " .. ns.SpellBookBindInfo())
    do
        local parts = {}
        for _, name in ipairs(COMBAT_WINDOWS) do
            local frame = _G[name]
            if frame then
                local protected = frame.IsProtected and frame:IsProtected()
                parts[#parts + 1] = string.format("%s protected=%s shown=%s", name, tostring(protected), tostring(frame:IsShown()))
            end
        end
        ns.Print("windows: " .. table.concat(parts, "; "))
        ns.Print("secure snippets usable: " .. tostring(loadstring_untainted ~= nil))
    end
    if ns.blocked and #ns.blocked > 0 then
        ns.Print("calls the client refused:")
        for _, hit in ipairs(ns.blocked) do
            ns.Print(string.format("  %s %s %s%s%s", hit.when, hit.event, hit.func,
                hit.combat and " (in combat)" or "", hit.editMode and " (edit mode)" or ""))
        end
    else
        ns.Print("calls the client refused: none")
    end
    -- Same source as the reload prompt.
    local owed = ns.ReloadOwedList()
    if #owed > 0 then
        local parts = {}
        for _, item in ipairs(owed) do parts[#parts + 1] = item.key .. " " .. item.way end
        ns.Print("a reload is owed for: " .. table.concat(parts, ", "))
    end
    if ns.SurnameSettings then
        local names = ns.SurnameSettings()
        if #names == 0 then
            ns.Print("surname settings: none on this client")
        else
            local parts = {}
            for _, name in ipairs(names) do
                parts[#parts + 1] = name .. "=" .. tostring(ns.GetCVar(name))
            end
            ns.Print("surname settings: " .. table.concat(parts, ", "))
        end
        ns.Print("player name " .. tostring(UnitName("player")) .. " unmodified " ..
            tostring(UnitNameUnmodified and UnitNameUnmodified("player")))
        -- API name next to each frame's drawn string, to see where surnames show.
        local drawn = {
            { "player frame", PlayerName },
            { "target frame", ns.Path(TargetFrame, "TargetFrameContent", "TargetFrameContentMain", "Name") },
            { "target api", nil, "target" },
        }
        for _, entry in ipairs(drawn) do
            if entry[2] then
                ns.Print("  " .. entry[1] .. " draws " .. tostring(entry[2].GetText and entry[2]:GetText()))
            elseif entry[3] and UnitExists(entry[3]) then
                ns.Print("  " .. entry[1] .. " " .. tostring(UnitName(entry[3])) .. " unmodified " ..
                    tostring(UnitNameUnmodified and UnitNameUnmodified(entry[3])))
            end
        end
    end
end
ns.options.Debug = Debug
