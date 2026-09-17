# Forever Classic UI

Puts the original Classic look back on top of the modern interface in World of Warcraft: Forever. Forever ships the edit-mode interface; this addon puts the old art on top of it without fighting edit mode.

## What it restores

- The main bar: gryphon end caps, the stone band behind the action buttons, micro menu and bags, stone page arrows, twelve slots per bar, bars 4 and 5 down the right edge. A first-login prompt can set up an edit mode layout with everything in its old place; your current layout and keybinds are left alone.
- Square buttons with the old pressed, highlight and attack flash art, the equipped-item border and square icons. Empty side bar slots stay hidden until something is dragged onto them. Bars 6 to 8 fade out; their keybinds still work.
- Player, target, focus, target of target, pet and party frames with the old art, portraits, level circle and elite dragon, bars in their old spots and colours, numbers on hover.
- Cast bars in the old border, colours and spark, sitting under the buff rows.
- The round minimap ring with the zone name across the top and the old tracking, mail, zoom, calendar and clock spots.
- Flat nameplates with an outlined white name.
- The old objective tracker headers and the parchment quest log.
- The metal window border, round portrait and character-sheet tabs on the character, inspect, merchant, mail, friends, quest, trade, bank and other windows.

Every piece is a toggle. Turning one off restores the modern look in place; a `/reload` gives a completely clean slate.

## Commands

- `/fcui` opens the options window; `/fcui settings` opens the same toggles in the game's Settings.
- `/fcui on|off` master switch.
- `/fcui classicBar|buttons|squareIcons|pageArrows|hideExtraBars|emptySlots|unitFrames|castBars|minimap|namePlates|questTracker|panels on|off` per-piece toggles.
- `/fcui layout` creates and selects the classic edit mode layout; `/fcui prompt` shows the first-login question again.
- `/fcui textures builtin|bundled` reads the art from the game client or from the copies in `media/`.
- `/fcui status`, `/fcui debug`, `/fcui reset`.

## Notes

- The addon also loads on the retail client, where the same frames exist.
