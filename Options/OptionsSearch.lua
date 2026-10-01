local _, ns = ...

-- Options search: how well a row matches the query words (OptionsWindow.lua shows the best level only).

-- Every query word starts a word of text: "ring" finds rings, never hovering.
local function WordsIn(text, words)
    for i = 1, #words do
        if not text:find("%f[%w]" .. words[i]) then return false end
    end
    return true
end

-- Looser forms of a query word: its plural dropped, and the words people use for the same thing.
local SYNONYMS = {
    big = { "thick", "large", "tall", "fat" }, large = { "big", "thick", "tall" }, thick = { "big", "large", "fat" },
    fat = { "thick", "big" }, tall = { "big", "large" }, small = { "thin", "compact", "narrow" },
    thin = { "small", "narrow" }, color = { "colour" }, colour = { "color" }, hide = { "remove", "off" },
    remove = { "hide" }, size = { "scale" }, scale = { "size" }, font = { "text" },
}
local function Loose(word)
    local out = { word }
    local stem = #word > 3 and word:gsub("e?s$", "")
    if stem and stem ~= word then out[#out + 1] = stem end
    for _, alt in ipairs(SYNONYMS[word] or SYNONYMS[stem] or {}) do out[#out + 1] = alt end
    return out
end

-- Every word loosely: a looser form starting a word, or a long word inside the text with its spaces taken out.
local function LooseIn(text, words)
    local joined = text:gsub("%s+", "")
    for i = 1, #words do
        local found = false
        for _, form in ipairs(Loose(words[i])) do
            if text:find("%f[%w]" .. form) or (#form >= 5 and joined:find(form, 1, true)) then found = true break end
        end
        if not found then return false end
    end
    return true
end

-- 3: the name side has every word; 2: loosely; 1: only with the tooltip; 0: no. The best level found wins alone.
function ns.OptionMatchLevel(box, words)
    if WordsIn(box.keyLow, words) then return 3 end
    if LooseIn(box.keyLow, words) then return 2 end
    if WordsIn(box.keyLow .. " " .. box.tipLow, words) then return 1 end
    return 0
end
