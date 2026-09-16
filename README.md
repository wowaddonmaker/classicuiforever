# Forever Classic UI

Brings the original Classic action bar look to World of Warcraft: Forever. Forever ships the modern edit-mode interface; this addon puts the 2004 art back on top of it without fighting edit mode.

## Features

- Gryphon end caps from the original bar, on both factions, mirrored the way the old bar did it.
- The stone bar band behind the main action bar, micro menu and bags, sized to whatever is on that row.
- Classic button style: square slot borders, old pressed and highlight art, red attack flash, equipped-item border, and optionally square icons instead of the rounded mask.
- Classic stone page arrows.
- Everything is a toggle. Edit mode keeps working: move the bars and the art follows.

## Commands

- `/fcui` opens the options panel.
- `/fcui on|off` master switch.
- `/fcui endcaps|barart|hidemodernborders|buttons|squareicons|pagearrows on|off` per-feature toggles.
- `/fcui textures builtin|bundled` reads the art from the game client or from the copies in `media/`.
- `/fcui status`, `/fcui debug`, `/fcui reset`.

## Notes

- Turning a feature off restores the modern art in place where possible. A `/reload` gives a completely clean slate.
- The addon also loads on the retail client for testing; the same frames exist there.
