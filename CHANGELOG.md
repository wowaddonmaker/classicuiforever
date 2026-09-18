# Changelog

All notable changes to ClassicUI Forever are documented here.

## [0.3.4] - 2026-09-18

### Fixed
- The bank as the 1.x window had it: its gravel floor, cut from the old window sheet as a tile, under everything; near-black slot holes under the rings; Item Slots in gold over the grid; an empty bag slot wearing the old bag, red while the slot is not yet bought. The client re-sets its own art every time the bank opens, so the dressing is put back on every open.

## [0.3.3] - 2026-09-18

### Added
- A double-pane quest log, off by default: the classic log as the wider 3.x window, the list on the left and the quest on the parchment beside it, with Show Map at the top and Abandon, Share, Track and Close along the foot. A Double pane switch sits under Track Quest in the single pane and beside the quest count in the double, the same setting as the toggle in the options.
- The bank window in the old manner: the item and bag slots in the old rings over the old dark holes, a marble floor, gold titles, the modern shadows and divider gone, and the banker in the portrait ring.
- The rested experience bar: the fill turns blue while rested experience is banked, a faint blue run continues to the old tick marker, and the level text yields to the zzz.
- Each unit frame has its own toggle under Classic unit frames: player, target, focus, pet and party.
- The options window lists its toggles in two scrolling columns, a child toggle indented under its parent and greyed while the parent is off, with the old scroll bar beside them; the buttons along the foot stay put.
- A search box above the toggles in the options window, with a clear X: type a word and only the toggles whose name or description holds it stay.
- Hide bars 6 to 8 and the game's own Action Bar 6, 7 and 8 settings stay in step: the toggle turns them off, and enabling any of them in Settings turns the toggle off.

### Changed
- The stone page arrows come with the classic main bar and go with it; they are no longer a toggle of their own, since neither set of arrows suits the other bar.
- The minimap button wears the gryphon on a black disc, filling its ring, so it is easy to hit.
- Every thin scroll bar inside a skinned window wears the old knob and arrows, and the knob rides its track end to end.
- The character sheet's tabs read Character and Reputation in full, sized to their words.
- The game menu and the settings window use the old gold for their text.
- The rock backing of a skinned window runs out to the metal border, and the inset's inner border line fades, closing the strip of world that showed down the left of the mail and collections windows.
- The mail, vendor and social windows take a lower bottom border, meeting the rows along their feet.
- The quest log's arrows stay in view whether or not there is anything to scroll; only the knob goes.

### Fixed
- On the Forever client every toggle came back as its default at the next login: the client writes an addon's saved settings at logout but does not bring them back. The settings are now mirrored into a cvar of the addon's own, which the client does bring back, and read from it at load.
- The Forever client threw "Attempt to access forbidden object" at login while the addon looked for scroll bars under the bank window; forbidden frames are skipped.
- Abandon, Share and Track in the quest log grey out when there is no quest.
- Turning Classic unit frames off and on again lost the bars; they show again.

## [0.3.2] - 2026-09-18

### Added
- The game menu as 1.x drew it: the old dialog box with its header plate, and the compact red buttons with yellow labels. A toggle of its own.
- The settings window as the old options dialog: the see-through dialog box with its header plate, the category list and the page each in a thin-bordered inset, the old tabs standing on the list box, white group and section headers over the gold rows, the old yellow bar under the chosen category, and every control in the old art: check boxes, the 17 pixel slider bar with its round button, drop downs, scroll bars and red buttons. A toggle of its own.

### Fixed
- The focus frame in the classic layout sits straight under the target frame; it had been 15 pixels to the right.

## [0.3.1] - 2026-09-18

### Added
- The map's quest pane in the quest log's manner: the list on the dark floor with plus and minus headers, titles in the 1.x difficulty colours with the old check for a tracked quest, and a quest's details on the old parchment in the parchment ink. A toggle of its own.
- The equipment manager beside the classic sheet, the way Wrath did it: an arrow in the sheet's top right corner opens the sets in a dialog docked to the right of the window, with Equip, Save and New Set. The Transmog Inspector copy docks past the dialog while it is open.

### Changed
- Every skinned window is built the way the old windows were: rock out to the metal border, the streak band under the title, the old title strip, and marble as the floor of the item inset alone. The vendor window gets its old bottom strip with the repair slots.
- Close buttons hang off the border's top right corner piece at one offset, on every window, instead of a spot per window.
- Tabs along a window's bottom meet the metal border.
- The raid frame manager's tall panel at the screen edge fades while collapsed, leaving its small arrow below the player frame; expanding it brings the panel back.

### Fixed
- Opening the character window on the Forever client threw "attempt to compare a secret number value" from the status bar text. The sheet had written the window's collapsed-pane flag; it now hides the pane's frames and leaves the flag to Blizzard.
- Bag rows: the band behind each row is cut at its own height so the cells meet the slots; the bag close button sits in its socket.
- The merchant tabs hold their width when Blizzard resizes them.
- Opening the reputation tab could throw "attempt to index field elementData" on the Forever client: a row was skinned the moment it was acquired, before its data arrived.

## [0.3.0] - 2026-09-17

### Added
- Classic bags: each bag drawn from the old bag sheet in the pieces the Classic client used, the backpack from its own sheet with the money strip, the old bag icon in the ring, slots on the old 41 pixel grid with the old slot border, and empty slots showing the sheet's cell alone. The combined bag window keeps the modern look.
- The 1.x loot window: the old loot panel with the skull in the ring, the item name boxes, four rows, and with more loot the old paging arrows over three rows.
- Classic damage numbers over the mob you hit, in place of the game's: melee white, spells yellow, heals green, misses as words, crits large. The motion was measured from a 1.x recording: a hit climbs slowly for near two seconds, a crit appears huge and faint above the mob and drops into place. Numbers scatter and never stack. Needs enemy nameplates, which the toggle turns on; the game's own text over your character comes on too, with its 1.x colours.
- The reputation tab in the 1.x manner: Faction and Standing, each faction on the old plate with the bar frame and a gradient fill in the standing colour, plus and minus on the headers.
- Skills, Currency and Stats tabs inside the old art with the old scroll track, knob and arrows; skills as the old full-width blue bars with the name inside and the rank after it, headers in white.
- The character sheet's bottom tabs cut from the old tab sheets, sized to their labels, glowing their own shape on mouse-over.
- Options window: CurseForge and GitHub issues buttons, the action row centred, and a Welcome note toggle.
- On the Forever client the welcome note and the layout question arrive as one chat line with links instead of windows.

### Changed
- The addon's folder is now ClassicUIForever, matching its name. Settings live in a file named after the folder, so they start fresh; to keep the old ones, rename WTF\Account\<account>\SavedVariables\ForeverClassicUI.lua to ClassicUIForever.lua before logging in.
- The classic layout puts the focus frame under the target with a gap, and pressing the layout button on an existing layout moves the player, target and focus frames to their 1.x spots instead of only switching to it.
- Quest log and tracker use the 1.x difficulty colours: red, orange, yellow, green and grey by level, with the All tab and the quest count in the same yellow.
- Every skinned window gets a stone backing out to the metal border, and the border's bottom pieces meet the content; the Forever client's bronze frames around the equipment and ammo slots are faded.
- The character sheet's camera backs off a step so the character fits the old window.

### Fixed
- The character sheet's stat update tripped on retail, where the resistance API no longer exists, and every layout pass after it was cut short. Retail's sheet now has no resistance column; Forever keeps the five schools.
- The options window closes in combat.
- Spellbook spells cast when clicked; the game's key-down setting needed the press.
- Quest log rows no longer spill into the parchment, and the plus and minus on headers collapse and expand; the map's own log had been reopening them.
- Micro buttons show pressed only while their window is open, for the quest log, spellbook, world map, professions and the rest.
- The loot window, map and character frame portraits sit inside their rings.

## [0.2.0] - 2026-09-17

### Added
- The 1.x quest log in its own window, apart from the map: the book in the portrait ring, the quest count, the All tab, Track Quest, six list rows with level colours and tags over the parchment detail with objectives, description and rewards, and Abandon, Share and Exit. The quest micro button, the quest log key and quest clicks in the tracker open it.
- The 1.x spellbook is back: the parchment book, twelve spells a page with name and rank, school tabs down the right edge, page arrows and a pet tab, on the micro button, the keybind and /spellbook. Talents keep the modern window.
- The 1.x character sheet: the old window art, slots down the sides with the weapons underneath, the model with its rotate buttons, the attribute and armour box, the melee and ranged attack box, the five resistances and the bottom tabs. Retail's side panel and stat list stay closed.
- The world map window in the old metal border with the title strip, and no portrait.
- Quest log: the old scroll bar arrows and knob (bundled, the client's copies are stand-ins), the detail text stays inside its pane, Abandon is live whenever a quest is selected, and button labels sit centred.
- The micro row keeps its full 1.x size on the Forever client: the buttons overlap by their clear margins, the shop button stays in the Escape menu instead of the row, and an empty reagent bag shows the dim bag eagle like the client's own bar.
- A world map button in the micro row beside the quest button, with the old globe art; housing keeps its modern art. While the classic quest log is on, the map opens without the quest side panel.
- Classic combo points: five orbs curving down the right side of the target portrait, lit as points are earned, in place of retail's display under the player frame.
- A "No simplified nameplates" toggle, on by default: friendly players and NPCs, minions and minor mobs get the full plate instead of the game's reduced one that only grows when targeted. Turning it off puts the game's setting back.
- The reputation tab in the 1.x manner: Faction and Standing over the list, each faction on the old plate with the bar frame at the right and a plain fill in the standing colour, plus and minus on the headers, and the list inside the window with the old scroll knob and arrows.
- The character sheet's bottom tabs are cut from the old tab sheets and sized to their labels: Char, Reputation, Skills, PvP, Currency and Stats.

### Removed
- The "Enable ClassicUI Forever" master switch and `/fcui on|off`. Disabling the addon in the game's addon list does the same thing; every piece keeps its own toggle.

### Fixed
- Creating the classic layout makes it the active layout. The game could leave the previous layout selected after the reload, so the bar and chat placement never showed.

### Changed
- On the Forever client the welcome note and the layout question no longer open on their own. One chat line offers each as a link; the beta forgets addon settings between sessions, so a window every login would have been a nuisance. Retail keeps the windows.
- The Forever client's bronze frame around each equipment slot is faded on the classic sheet.
- The classic edit mode layout puts the chat frame where 1.x kept it, above the bottom bars and the pet row, instead of across bars 2 and 3.
- Nameplates are the 1.x plate drawn from the old sheet at its old size: the 128 by 16 rounded border with the level in its slot, the shaded bar inside it, the name above, and the cast bar in the same border underneath with the spell icon to its left.
- The classic bar centres itself unless you drag Action Bar 1 in edit mode while the bar is on; its reset-to-default button hands placement back to the band. Layouts saved by earlier builds no longer shift the whole band sideways.
- The objective tracker reads as plain text: small gold section titles, quest titles in the level colour with the level in front, objectives one size smaller in grey that turns white with progress and green when done.

## [0.1.1] - 2026-09-17

### Added
- A first-login welcome in the old dialog style: the addon is a work in progress, with the CurseForge and GitHub addresses ready to copy.
- A button on the minimap ring that opens the options window; drag it around the ring.
- The options window and every toggle now go by the name ClassicUI Forever.

### Fixed
- Target and focus cast bars sit below the buff and debuff rows, and move with them. The small focus frame keeps its cast bar at the same size as the frame.
- Cast bars no longer touch protected values on other units' casts.
- Bag buttons snap back into the band's sockets whenever the game re-anchors them, and the micro row scales to fit every button.
- Party frame bars sit inside the party frame art with the right colours, and members who join later are skinned too.
- Player frame bars back at their old spots, numbers show on hover, and the level stays in its circle instead of the role icon or the PvP badge.
- Layout passes wait for combat to end instead of tripping the protected-frame guard.
- The addon no longer writes a log to its saved variables.

## [0.1.0] - 2026-09-17

### Added
- The original main bar: gryphon end caps, the stone band behind the action buttons, micro menu and bags, the stone page arrows, twelve slots on every bar, and bars 4 and 5 stacked down the right edge. A first-login prompt can set up an edit mode layout with everything in its old place; your current layout and keybinds are left alone.
- Classic button style: square slot borders, the old pressed and highlight art, red attack flash, the equipped-item border, and square icons in place of the rounded mask. Empty slots on the side bars stay hidden until something is dragged onto them. Bars 6 to 8 are faded out; their keybinds still work.
- Micro buttons in their old art, scaled as a row so every one of them fits between the action buttons and the bags. Bag buttons and the key ring sit in the band's sockets.
- Player, target, focus, target of target, pet and party frames with the old frame art, portraits, level circle, elite dragon, and health and power bars in their old spots and colours. Numbers show on hover.
- Cast bars in the old border, colours and spark on the player, pet, target, focus and boss bars. The target and focus bars sit under the buff rows where they used to.
- The round minimap ring with the zone name across the top, tracking, mail, zoom, calendar and clock in their old places. Addon buttons sit on the ring.
- Flat nameplates with a thin dark edge and an outlined white name.
- The old stone headers and small collapse buttons on the objective tracker, and the parchment quest log background.
- The metal window border with the round portrait, the small close button, the stone title strip and character-sheet tabs on the character, inspect, merchant, mail, friends, quest, trade, bank and other windows.
- An options window in the old dialog style, one checkbox per piece, with the same toggles in the game's Settings window. Art is read from the game client with bundled copies as a fallback. `/fcui` commands for every toggle, plus status, debug and reset.

---
