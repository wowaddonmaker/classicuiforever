# Changelog

All notable changes to ClassicUI Forever are documented here.

## [0.4.3] - 2026-09-18

### Fixed
- Clicking an entry in the classic spellbook that opens a list of its own, a warrior's Stances or a hunter's Call Pet, put a Lua error on screen instead of opening it. The client's list asks the button it hangs off which way to open and to show itself held down; the book's buttons answer both now.

## [0.4.2] - 2026-09-18

### Added
- A toggle that takes the cast animation off the action buttons. 1.x played nothing over a button while its spell was casting, and the cooldown swipe under it stays solid instead of being lightened so the animation can show through. On by default; turn it off to keep the animation.

### Changed
- The message that a piece needs the interface reloaded is hard to miss now, and it asks rather than telling: turning off a piece that leaves art on screen puts the question on screen with a button on it.

### Fixed
- Lua errors on the party and raid frames, reported by players using raid-style party frames and by players with the edit mode panel open. This addon was doing its work inside the client's own passes over its frames, and the client holds such a pass against an addon afterwards, which is what left those frames reporting an error on every health change. Everything this addon puts back is now done outside the client's passes. The error is hard to bring on deliberately, so this is the cause as far as it could be traced rather than a confirmed cure; if you still see it, please say so with the error text.
- Switching to the classic edit mode layout asks for a reload when it finishes, since applying a layout from an addon leaves the frames in it on an addon's footing for the rest of the session.
- Closing the roster or the Who list during a fight no longer puts the blocked-action box on screen. Giving the client's own panels their mouse back is its call to refuse there, as taking it was, so it waits for the fight to end.
- The experience and reputation bars stay in the band. They no longer hop out of it and back when you take a target, and they are dressed when the client hands them over a moment after you log in.

## [0.4.1] - 2026-09-18

### Added
- The skills tab has its lower section back: picking a skill shows its own bar and what it does under the list, with the button that unlearns a profession beside it. The client keeps that pane in the side panel this window does not have, so it is brought down here.
- A right click on a name in the Who list opens the old little menu: whisper, invite, add friend and ignore.

### Removed
- Classic damage numbers. The old engine drew only your own damage over a mob, and this client tells an addon what a unit took without ever saying who dealt it: the combat log does not reach addons, the combat text call holds its numbers back and so does the damage meter. Numbers that show a stranger's hits are worse than none, so the feature is gone and the game's own numbers are turned back on for anyone who had it.

### Fixed
- The classic windows keep the old manners: opening one closes whatever window was in its place, and opening one of the client's windows closes ours. The quest log no longer sits on top of a vendor or a quest giver.
- The spellbook opens and closes during a fight, and stands in the window place at the screen's left where the 1.x book stood.
- The spellbook's page number sits on the page beside its arrows instead of below the book.
- The classic windows open during a fight again. The client's own window manager turns an addon away there, so the spellbook and the other windows this addon owns now put themselves on screen instead of asking it. Casting from the book during a fight is still the client's to refuse: what a button casts is set on it, and that cannot be set once a fight has started.
- The guild roster no longer leaves its button dead after a press made during a fight: a window the client refused to open left the roster marked as open with nothing on screen, and every press after it read as a close.
- Dragging anything in edit mode is steady: this addon lays nothing out while a frame is being dragged, so its layout and the client's snapping no longer answer each other under the cursor.
- The player, target, focus and pet frames sit on whole pixels, so two frames written to the same line share it whatever size each is set to.
- The settings window stands on solid stone rather than showing the ground through the page, with its category list and page in the old gray insets.
- The experience bar is one even shade along its length: the fill took a slice of a sheet that runs dark to light, which drew a band that changed shade partway along.
- A right click menu is solid black with a thin silver line around it, as the old menus were, instead of a plate you could see the world through.
- Whisper from a name in the Who list or the roster opens a clean line ready to type, where before it added to whatever was half typed in the chat box.
- The guild message and the window's title are read out of combat and kept, since the client refuses those calls during a fight and the refusal put the blocked-action box on screen.
- The character window opened during a fight kept the client's shape: the slots spread out, the weapons floated into the stat box and every stat read zero. It takes the old shape in a fight now, and the numbers the client holds back stay as they were instead of dropping to zero.
- Edit mode's icon size works on the classic bars: each bar wears its own, Action Bar 1's is the size of the whole band with the bags, the micro menu and the experience bar following it, and the selection box sits on the buttons it belongs to. The number of icons, the rows, the padding and the orientation all lay the band out again as they change.
- The guild registrar and the charter are written on parchment again instead of near black stone.
- Nothing asks the client for an action it refuses: the party frames while a fight is on, and the three settings behind bars 6 to 8, both of which put the blocked-action box on screen.
- The thin scroll bars inside a window sit a pixel further right, where the old track is, and a scroll knob reaches its arrows at each end.
- Hide last names takes the surname off every name this UI draws, where before it wrote them back and forth.

## [0.4.0] - 2026-09-18

### Added
- The 1.x guild roster, as a Guild tab on the social window: the old column plates over the roster, Show Offline Members on the pill under the title, the member count and the guild message in their own sections, and Guild Information, Add Member and Guild Control along the foot. Player Status opens the member beside the window with their zone, rank, last online and note, promote and demote on the rank, and Remove and Group Invite. A right click on a member opens the old little menu. The guild button and its key open it, and press again to close.
- The 1.x Who list, as a Who tab beside it: names, zone, level and class in sortable columns, a query line at the foot so a search needs no slash command, and Refresh, Add Friend and Group Invite. A /who typed anywhere answers into this window instead of the client's own.
- The social window's tabs read Friends, Who, Guild in the old order, and the first one is called Friends again.
- The guild control window takes the old look: the classic window art, check boxes, drop downs and red buttons, with the client's own rules still deciding what a rank may change.
- The addon's own toggle panel is the page the game's settings window shows for it, search box, columns and all, in place of the plain list of check boxes.
- Class colored unit frames and class colored nameplates, a toggle each and both off by default: a player's health bar takes their class color, everything else keeps the color it had.
- Hide last names, a toggle of its own: the Forever client's surnames go, and the game's own box for them stays in step, so putting surnames back there turns the toggle off.
- Fade map while moving, a toggle of its own and off by default: the game's own map fade, so a change made in either place is kept.

### Changed
- Quest rewards sit on the old name plate again, in the quest log and at the quest giver, sized from the art's own padding so the plate fills its row.
- Every red button in the addon wears the old gold on its label rather than the client's bronze.
- The character pane's tabs are roomier and its scroll knob rides the line its arrows are on.
- US spelling throughout the addon's text.

### Fixed
- Enemy nameplates turned themselves back on: the classic damage numbers live on the enemy plate and turned it on at every pass. The plates are turned on once for them, and turning them off again is kept.
- Edit mode no longer stutters while a setting is flipped: the passes the client asks for are gathered into one, and Hide Bar Art answers with the band's own art rather than a whole layout.
- The client's bag bar art no longer shows around the key ring on the band.

## [0.3.7] - 2026-09-18

### Added
- One bar, a toggle under the classic main menu bar: the band stops after the twelve main slots with a gryphon at each end, bars 2 and 3 stack above it with the stance and pet row over them, the experience bar takes the same width, and the micro menu and the bags move to the screen's bottom right corner in their old art.
- A search box on the classic spellbook, a toggle of its own: type, and every known spell whose name or rank line holds the words is listed across the tabs, paged like the book itself.

### Changed
- Edit mode's Hide Bar Art for Action Bar 1 now hides the classic gryphons as well, and brings them back when turned off; the band stays.

### Fixed
- The right hand bars jumped to another spot on entering combat and back on leaving it. Their buttons now hang from the screen's corner instead of from the bars, which edit mode re-anchors whenever the room beside the minimap changes.
- Every bar can be placed in edit mode again: a bar moved there keeps its own spot and its buttons follow it, instead of snapping back to the band. Bars 2 to 5 and the stance and pet bars all take it.
- Edit mode's minimap size grows the whole classic minimap as one. The map used to slide out of its ring and the zone name to land inside it.
- The target frame in the classic layout sits at the player frame's height, so the two portraits line up.
- The action bar page number sits beside its arrows instead of at the band's middle.

## [0.3.6] - 2026-09-18

### Fixed
- The trade window takes the same lower bottom border, and its second portrait, the other party's, sits in the old metal ring instead of the client's bronze corner, which had shown through behind their name.

## [0.3.5] - 2026-09-18

### Fixed
- The talk and quest windows (a guard's directions, a quest giver's text) take a lower bottom border, so it no longer cuts through the Goodbye, Accept and Decline buttons along their feet, and their rock backing stops at the border on the right instead of showing past it.

## [0.3.4] - 2026-09-18

### Fixed
- The bank as the 1.x window had it: its gravel floor, cut from the old window sheet as a tile, under everything; near-black slot holes under the rings; Item Slots in gold over the grid; an empty bag slot wearing the old bag, red while the slot is not yet bought. The client re-sets its own art every time the bank opens, so the dressing is put back on every open.

## [0.3.3] - 2026-09-18

### Added
- A double-pane quest log, off by default: the classic log as the wider 3.x window, the list on the left and the quest on the parchment beside it, with Show Map at the top and Abandon, Share, Track and Close along the foot. A Double pane switch sits under Track Quest in the single pane and beside the quest count in the double, the same setting as the toggle in the options.
- The bank window in the old manner: the item and bag slots in the old rings over the old dark holes, a marble floor, gold titles, the modern shadows and divider gone, and the banker in the portrait ring.
- The rested experience bar: the fill turns blue while rested experience is banked, a faint blue run continues to the old tick marker, and the level text yields to the zzz.
- Each unit frame has its own toggle under Classic unit frames: player, target, focus, pet and party.
- The options window lists its toggles in two scrolling columns, a child toggle indented under its parent and grayed while the parent is off, with the old scroll bar beside them; the buttons along the foot stay put.
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
- Abandon, Share and Track in the quest log gray out when there is no quest.
- Turning Classic unit frames off and on again lost the bars; they show again.

## [0.3.2] - 2026-09-18

### Added
- The game menu as 1.x drew it: the old dialog box with its header plate, and the compact red buttons with yellow labels. A toggle of its own.
- The settings window as the old options dialog: the see-through dialog box with its header plate, the category list and the page each in a thin-bordered inset, the old tabs standing on the list box, white group and section headers over the gold rows, the old yellow bar under the chosen category, and every control in the old art: check boxes, the 17 pixel slider bar with its round button, drop downs, scroll bars and red buttons. A toggle of its own.

### Fixed
- The focus frame in the classic layout sits straight under the target frame; it had been 15 pixels to the right.

## [0.3.1] - 2026-09-18

### Added
- The map's quest pane in the quest log's manner: the list on the dark floor with plus and minus headers, titles in the 1.x difficulty colors with the old check for a tracked quest, and a quest's details on the old parchment in the parchment ink. A toggle of its own.
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
- Classic damage numbers over the mob you hit, in place of the game's: melee white, spells yellow, heals green, misses as words, crits large. The motion was measured from a 1.x recording: a hit climbs slowly for near two seconds, a crit appears huge and faint above the mob and drops into place. Numbers scatter and never stack. Needs enemy nameplates, which the toggle turns on; the game's own text over your character comes on too, with its 1.x colors.
- The reputation tab in the 1.x manner: Faction and Standing, each faction on the old plate with the bar frame and a gradient fill in the standing color, plus and minus on the headers.
- Skills, Currency and Stats tabs inside the old art with the old scroll track, knob and arrows; skills as the old full-width blue bars with the name inside and the rank after it, headers in white.
- The character sheet's bottom tabs cut from the old tab sheets, sized to their labels, glowing their own shape on mouse-over.
- Options window: CurseForge and GitHub issues buttons, the action row centered, and a Welcome note toggle.
- On the Forever client the welcome note and the layout question arrive as one chat line with links instead of windows.

### Changed
- The addon's folder is now ClassicUIForever, matching its name. Settings live in a file named after the folder, so they start fresh; to keep the old ones, rename WTF\Account\<account>\SavedVariables\ForeverClassicUI.lua to ClassicUIForever.lua before logging in.
- The classic layout puts the focus frame under the target with a gap, and pressing the layout button on an existing layout moves the player, target and focus frames to their 1.x spots instead of only switching to it.
- Quest log and tracker use the 1.x difficulty colors: red, orange, yellow, green and gray by level, with the All tab and the quest count in the same yellow.
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
- The 1.x quest log in its own window, apart from the map: the book in the portrait ring, the quest count, the All tab, Track Quest, six list rows with level colors and tags over the parchment detail with objectives, description and rewards, and Abandon, Share and Exit. The quest micro button, the quest log key and quest clicks in the tracker open it.
- The 1.x spellbook is back: the parchment book, twelve spells a page with name and rank, school tabs down the right edge, page arrows and a pet tab, on the micro button, the keybind and /spellbook. Talents keep the modern window.
- The 1.x character sheet: the old window art, slots down the sides with the weapons underneath, the model with its rotate buttons, the attribute and armour box, the melee and ranged attack box, the five resistances and the bottom tabs. Retail's side panel and stat list stay closed.
- The world map window in the old metal border with the title strip, and no portrait.
- Quest log: the old scroll bar arrows and knob (bundled, the client's copies are stand-ins), the detail text stays inside its pane, Abandon is live whenever a quest is selected, and button labels sit centered.
- The micro row keeps its full 1.x size on the Forever client: the buttons overlap by their clear margins, the shop button stays in the Escape menu instead of the row, and an empty reagent bag shows the dim bag eagle like the client's own bar.
- A world map button in the micro row beside the quest button, with the old globe art; housing keeps its modern art. While the classic quest log is on, the map opens without the quest side panel.
- Classic combo points: five orbs curving down the right side of the target portrait, lit as points are earned, in place of retail's display under the player frame.
- A "No simplified nameplates" toggle, on by default: friendly players and NPCs, minions and minor mobs get the full plate instead of the game's reduced one that only grows when targeted. Turning it off puts the game's setting back.
- The reputation tab in the 1.x manner: Faction and Standing over the list, each faction on the old plate with the bar frame at the right and a plain fill in the standing color, plus and minus on the headers, and the list inside the window with the old scroll knob and arrows.
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
- The classic bar centers itself unless you drag Action Bar 1 in edit mode while the bar is on; its reset-to-default button hands placement back to the band. Layouts saved by earlier builds no longer shift the whole band sideways.
- The objective tracker reads as plain text: small gold section titles, quest titles in the level color with the level in front, objectives one size smaller in gray that turns white with progress and green when done.

## [0.1.1] - 2026-09-17

### Added
- A first-login welcome in the old dialog style: the addon is a work in progress, with the CurseForge and GitHub addresses ready to copy.
- A button on the minimap ring that opens the options window; drag it around the ring.
- The options window and every toggle now go by the name ClassicUI Forever.

### Fixed
- Target and focus cast bars sit below the buff and debuff rows, and move with them. The small focus frame keeps its cast bar at the same size as the frame.
- Cast bars no longer touch protected values on other units' casts.
- Bag buttons snap back into the band's sockets whenever the game re-anchors them, and the micro row scales to fit every button.
- Party frame bars sit inside the party frame art with the right colors, and members who join later are skinned too.
- Player frame bars back at their old spots, numbers show on hover, and the level stays in its circle instead of the role icon or the PvP badge.
- Layout passes wait for combat to end instead of tripping the protected-frame guard.
- The addon no longer writes a log to its saved variables.

## [0.1.0] - 2026-09-17

### Added
- The original main bar: gryphon end caps, the stone band behind the action buttons, micro menu and bags, the stone page arrows, twelve slots on every bar, and bars 4 and 5 stacked down the right edge. A first-login prompt can set up an edit mode layout with everything in its old place; your current layout and keybinds are left alone.
- Classic button style: square slot borders, the old pressed and highlight art, red attack flash, the equipped-item border, and square icons in place of the rounded mask. Empty slots on the side bars stay hidden until something is dragged onto them. Bars 6 to 8 are faded out; their keybinds still work.
- Micro buttons in their old art, scaled as a row so every one of them fits between the action buttons and the bags. Bag buttons and the key ring sit in the band's sockets.
- Player, target, focus, target of target, pet and party frames with the old frame art, portraits, level circle, elite dragon, and health and power bars in their old spots and colors. Numbers show on hover.
- Cast bars in the old border, colors and spark on the player, pet, target, focus and boss bars. The target and focus bars sit under the buff rows where they used to.
- The round minimap ring with the zone name across the top, tracking, mail, zoom, calendar and clock in their old places. Addon buttons sit on the ring.
- Flat nameplates with a thin dark edge and an outlined white name.
- The old stone headers and small collapse buttons on the objective tracker, and the parchment quest log background.
- The metal window border with the round portrait, the small close button, the stone title strip and character-sheet tabs on the character, inspect, merchant, mail, friends, quest, trade, bank and other windows.
- An options window in the old dialog style, one checkbox per piece, with the same toggles in the game's Settings window. Art is read from the game client with bundled copies as a fallback. `/fcui` commands for every toggle, plus status, debug and reset.

---
