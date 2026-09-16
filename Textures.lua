local _, ns = ...

local BUNDLED = "Interface\\AddOns\\ForeverClassicUI\\media\\"

-- Classic art paths as the client shipped them. Every entry also names the
-- copy in media/ so the addon keeps working if a client build drops the file.
ns.TEX = {
    endCap = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-EndCap-Dwarf" },
    barBody = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-Dwarf" },
    barKeyring = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-KeyRing", bundled = BUNDLED .. "UI-MainMenuBar-KeyRing" },
    maxLevel = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-MaxLevel", bundled = BUNDLED .. "UI-MainMenuBar-MaxLevel" },
    slotEmpty = { builtin = "Interface\\Buttons\\UI-Quickslot", bundled = BUNDLED .. "UI-Quickslot" },
    slotNormal = { builtin = "Interface\\Buttons\\UI-Quickslot2", bundled = BUNDLED .. "UI-Quickslot2" },
    slotPushed = { builtin = "Interface\\Buttons\\UI-Quickslot-Depress", bundled = BUNDLED .. "UI-Quickslot-Depress" },
    slotFlash = { builtin = "Interface\\Buttons\\UI-QuickslotRed", bundled = BUNDLED .. "UI-QuickslotRed" },
    highlight = { builtin = "Interface\\Buttons\\ButtonHilight-Square", bundled = BUNDLED .. "ButtonHilight-Square" },
    checked = { builtin = "Interface\\Buttons\\CheckButtonHilight", bundled = BUNDLED .. "CheckButtonHilight" },
    equippedBorder = { builtin = "Interface\\Buttons\\UI-ActionButton-Border", bundled = BUNDLED .. "UI-ActionButton-Border" },
    arrowUpUp = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Up" },
    arrowUpDown = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Down", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Down" },
    arrowUpDisabled = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Disabled", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Disabled" },
    arrowUpHighlight = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Highlight", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Highlight" },
    arrowDownUp = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Up", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Up" },
    arrowDownDown = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Down", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Down" },
    arrowDownDisabled = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Disabled", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Disabled" },
    arrowDownHighlight = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Highlight", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Highlight" },
}

-- Result of the last SetTexture per key, for /fcui debug.
ns.texStatus = {}

function ns.TexPath(key)
    local entry = ns.TEX[key]
    if ns.db and ns.db.textureSource == "bundled" then
        return entry.bundled, entry.builtin
    end
    return entry.builtin, entry.bundled
end

-- SetTexture returns false when the file does not exist; fall back to the
-- other copy so a missing client file never leaves a blank region.
function ns.SetTex(texture, key)
    local primary, fallback = ns.TexPath(key)
    local ok = texture:SetTexture(primary)
    if ok == false then
        ok = texture:SetTexture(fallback)
        ns.texStatus[key] = ok and "fallback" or "missing"
    else
        ns.texStatus[key] = "ok"
    end
    return ok ~= false
end

function ns.SetButtonTex(button, which, key)
    local setter = button["Set" .. which .. "Texture"]
    local getter = button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    local primary, fallback = ns.TexPath(key)
    setter(button, primary)
    local tex = getter(button)
    if tex and tex.GetTexture and not tex:GetTexture() then
        setter(button, fallback)
    end
    return tex
end
