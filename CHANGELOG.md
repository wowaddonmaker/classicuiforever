# Changelog

All notable changes to ClassicUI Forever are documented here.

## [0.7.0] - 2026-09-20

### Added
- The talent window as the old one: one tree at a time on its old painting, the three trees on tabs along the foot, the old slots with the rank in its corner box (green while there is a rank to buy, gold when full, gray when locked), the branches and arrows between talents, points spent in the tree under the title, and your unspent points, Apply Changes and an undo for unapplied picks along the foot. A talent's tooltip gives its rank, what it still needs in red, what the rank does and what the next rank would do. The talents micro button and the talents key open it. Toggle: Classic talent window.
- The inspect window's Talents button opens the same window on the inspected player's talents, to look at, beside the inspect window.
- The inspect window loses this client's bronze slot surrounds, and its side tabs give way to the old tabs along the foot, which show only when there is a guild tab to turn to.
- The classic spellbook casts during a fight, on every tab and every page: it opens with the spellbook key or micro button, the tabs and page arrows turn, the cooldown swirls run, and a spell that cannot be cast is grayed as on the action bars (blue when only mana is missing). During a fight it closes with its key, its micro button or its X, the search box and the mouse wheel rest until the fight ends, and a turned page lands a moment late.
- A search box on a profession's window, between the All tab and the filter. Toggle: Trade skill search box.
- The spellbook has a side tab that opens What's Training beside the book, when that addon is installed (#21).
- /fcui status opens a status report: your addon version, game build, display, the settings you changed, your other addons and anything the game blocked this session, to screenshot or copy into a bug report. It is also a button in the options window, and the first time the game blocks something in a session one line of chat offers it. Nothing is saved.
- The character sheet stands beside the classic spellbook, talent window and quest log, as it used to, and no longer takes their place. During a fight it still does.

### Fixed
- With Classic spellbook turned off, clicking a spell in the game's own spellbook gave "ClassicUIForever has been blocked from an action", and a dragged spell brought up no empty slots on bars 2 to 5. New in 0.6.1. The addon now leaves the game's spellbook entirely alone while that toggle is off, and turning it off asks for an interface restart.
- A profession's window counts what you can make from your bags only, not from the bank.
- The character sheet stood some 200 past the professions book's edge when both were open.
- The friends tab's status drop down answered the mouse, unseen, over the Who list and the guild roster.
- The micro buttons stay pressed while their window is up and let go when it shuts, by one rule for all of them.
- The target of target follows the Class colored unit frames toggle.
- The classic spellbook and talent window stand side by side, the second clear of the first one's side tabs.
- The reputation tab's Faction label was half under the portrait ring.

## [0.6.1] - 2026-09-20

### Added
- The trainer's window as the old one: the trainer's greeting under the title, the All tab and the Filter drop down, the list under its headers in green for what you can learn, red for what you cannot yet and gray for what you know, the chosen service below with what it needs and what it costs, and your money, Train and Exit along the foot. Toggle: Classic trainer window.
- The spellbook carries the old Show all spell ranks box. Unticked, only the highest rank you know of each spell is listed. The same setting is in the options as Highest spell ranks only.
- No arrow beside the buffs: 1.x had no arrow next to the buff icons, so the small arrow that folds the buffs away is hidden. It still comes up under the mouse and still works, and the toggle brings it back for good.
- The quest log shows how many of your party are on each quest, the old [2] in front of the title, with their names when you point at the row.
- Opened bags beside the right action bars: bag windows start to the left of the action bars standing down the right edge of the screen, as they used to, and no longer cover them. A bar laid down or moved away from that edge is not counted. On by default, with a toggle.

### Fixed
- The Social micro button wears the old speech bubble again, and the minimap's tracking button the old magnifying glass while nothing is tracked. This client has redrawn both under their old names.
- The quest list the map opens at its side lies on the dark marble of the other lists, not on pale gray stone.
- The profession windows' Filter is the old drop down, and a primary profession's two spells stand close together in the professions book.
- The one bag window is eight columns wide to begin with.
- A black patch over the top of the head slot on the character sheet, new in 0.6.0.
- Your level gives way to the crossed swords during a fight, as it does to the zzz while resting. The swords were drawn on top of the number.
- The quest log's Share button is lit only for a quest that can be shared, with a party to share it with.
- The target of target's bars no longer show white, or the last unit's fill, for a moment when the frame comes up.
- The one bag window with enough bags showed a break across its lattice, where one piece of the old bag art met the next. The pieces are laid in whole rows and join cleanly.
- The Guild tab stays picked, with its label in white, the first time it is pressed in a session. It was unpicked again a moment later with the roster still up.

## [0.6.0] - 2026-09-20

### Added
- The professions window in the old style. The overview is the old professions book: each profession on its page with its ring, its rank and rank bar, and its spells on their plates. The game's side tabs are put away behind a small arrow under the close button, and come out when it is pressed. Toggle: Professions book.
- A profession's own window as the old trade skill window: the recipe list in its difficulty colors with how many you can make, the reagents below, Create All and Create with a quantity that counts down as each one is made, and the filters. Toggle: Trade skill window.
- The spellbook and the professions book carry the same tabs at their foot (Spellbook, Professions, and Pet when you have one) and turn into each other, as the old book's pages did.
- Show the game's damage numbers: a toggle for the floating damage over your targets.
- Nameplates follow the game's nameplate Size setting.
- A Default Size button in the group finder eye's edit mode window.
- Moving, resizing or resetting the micro menu in edit mode lights Save and Revert All Changes. Revert All Changes puts the menu back where it was when edit mode was opened.

### Fixed
- Action bars follow the Orientation and Rows set for them in edit mode. Bars 2 and 3 could not be stood up and bars 4 and 5 could not be laid down: the classic bar laid them out one way only and never read the setting.
- An end cap dragged off the bar in edit mode keeps its place. It went back onto the bar at the next login, and the saved place was then lost for good.
- The micro menu keeps the place it was dragged to, its size, and its order with the bags, from one session to the next.
- The world map key no longer fails with a blocked action during a fight after the map was opened from the quest log's Show Map button.
- The group finder eye can be picked up and moved in edit mode while it sits on the minimap. It fits inside its minimap border, and the border grows and shrinks with the eye's Size.
- The micro menu's edit mode box no longer stands in front of the edit mode window.
- Icons in the round portraits of the character sheet, the spellbook and the professions book no longer show their own square border inside the ring, and the character sheet's ring lies over the portrait, not under it.
- A book, plaque or letter shows no scroll column on a page that fits the window, and the column no longer lets the page show through it.
- Who list: sorting a column no longer asks the server again or flashes the game's own who window. A plain /who no longer shows the game's who window beside ours for a moment. The search line wears the old border, out to the window's edges, and the buttons are in the old order: Refresh, Add Friend, Group Invite. During a fight, where the social window cannot be opened for you, the game's own who list is left up.
- The Social button works during a fight. A press opened and shut the window in the same instant, and a window never opened that session was shown nowhere.
- With edit mode open during a fight the micro menu can be dragged, and no question about moved action bars follows the fight.
- A section header in the quest tracker could fade the game's own header art back in over ours.
- The enemy cast bar under a nameplate has no level slot and is the old yellow.
- Loot window: the page arrows sit on the window's body, and a row whose item was taken loses its name box.

## [0.5.4] - 2026-09-20

### Fixed
- The scroll knob in the quest windows, and in every other window of the game's that has the old scroll column, no longer slides up and down when there is nothing to scroll. With a page that fits its window the mouse wheel still moved the knob along the column while the page stood still. The knob is now put away when there is nothing to scroll, as the old scroll bars had it, and comes back when the text runs past the window.
- A friendly target or nameplate far above your level shows its level, not a skull. The skull is for what you can fight, as it was: the game never hid a friend's level.
- A short quest can no longer be scrolled over blank parchment. The game keeps each quest page as tall as its own, taller, quest window, which left the page taller than the shortened window showing it.

## [0.5.3] - 2026-09-20

### Fixed
- The spellbook's casting buttons no longer stay on the screen unseen after the book is closed during a fight. A book that was open when the fight began and was closed before it ended left them over the party frames until the fight was over: a click on a party member highlighted a spell instead, or cast it. The buttons are now put away the moment a fight begins. The book itself stays open, and its spells can be clicked again when the fight ends, the same as a book opened during one.

## [0.5.2] - 2026-09-20

### Fixed
- Errors in a fight that named this addon from inside the game's own damage meter, cooldown manager, action buttons and party frames. Whenever the addon wrote an edit mode layout while the game was running (setting up the classic layout, locking the bars, the bar size toggle, turning the classic bar off), the game marked every edit mode piece as the addon's for the rest of that session and then refused those pieces their combat values. No layout is written under a running game any more. Whatever you ask for is held until the interface restarts and is written in that same press, so the session that would have been marked is already over. "Later" on any of these prompts now means nothing has been written.
- The bars are locked into your layout, and unlocked again when the classic bar is turned off, in that same press. They were also meant to be locked quietly at logout, which the game never kept.
- A lock of the addon's is recognised by how the bar is held rather than by a saved note of it, so bars 2 and 3 and the stance bar keep following the classic bar after the game has lost the addon's saved settings.
- Party frames no longer come apart when someone gains a level in the group, or when someone joins in the middle of a fight. The game sets its party frames up afresh at those moments; the old art is put back at once, in a fight too, and the rest the moment the fight ends.
- The debuff row under the target and focus frames no longer drops a row and hops back.
- The spellbook and the social window close the instant a quest giver, vendor or any other window of the game's opens, the first time as well. The talents window is left open beside them, as it used to be.
- With the classic bar turned off the default interface is whole again: empty action slots show their sockets under Classic button style instead of vanishing, the page number goes back beside bar 1, and the micro menu no longer raises an error on the way back.
- Friendly players' nameplates are the old blue, and the level sits in the middle of its slot.
- The experience bar's fill no longer shows as a run of shaded blocks with a dark end.
- The arrows beside the sliders in the settings window are silver instead of missing.
- The Guild tab is no longer gray after you join a guild, and the social window's title follows the tab that is open. The Raid tab no longer reads "Who List".
- The friends list no longer comes back blank after switching between the tabs.
- The quest and gossip windows are their old height, with the parchment ending where the window does.
- Scroll bars in the game's windows stand in the old bordered column, which no longer runs on past the macro window the first time that window is opened.
- The game's floating damage numbers are no longer switched back on at login.

### Added
- The guild roster is the old one throughout. Clicking a member opens the member pane beside the roster, and it is the game's own member frame in the old silver, so the Note and Officer's Note boxes can be written, and promoting, demoting, removing and inviting work as they do in the game's guild window. The Player Status arrow switches the list to Name, Rank, Note and Last Online. Clicking the message of the day opens the game's editor for it, for whoever may set it. Guild Control and Add Member open the game's own dialogs, the chosen row wears the old gold highlight, and the scroll bar stays away until the list runs past the box.
- The Who list has the same gold highlight and the same scroll bar.

### Changed
- The prompts that change a layout restart the interface from their own button, in one press.
- The layout button in the options window is for the classic layout only: it sets the layout up, or offers to reset it when you are already on it. Any other layout is picked in edit mode.
- Square icons sits under Classic button style in the options, which it has always needed.

## [0.5.1] - 2026-09-19

### Fixed
- Action bars no longer jump about when a fight starts on an edit mode layout of your own. The classic bar's places for the bars were only ever written into the ClassicUI Forever layout; on any other layout the game still counted the bars as its own, laid them out its own way in the middle of a fight, and no addon may move a bar back until the fight is over. They can now be written into whichever layout of your own you are on. Bars you placed yourself are left where you put them, and turning the classic bar off takes back only what the addon wrote.
- When bars do move during a fight the addon says so once, right after it, and offers the way out: lock the bars into your layout, or, on one of the game's preset layouts, which nobody can write to, set up the classic layout.
- Setting up the ClassicUI Forever layout keeps the number of icons each of your action bars shows. It forced twelve on a new layout, and switching to a classic layout made earlier took whatever that one had, ten if it was last used with the default interface bar size.
- The world map button in the micro menu opens the map during a fight. It gave "interface action failed because of an AddOn" there, while the map key worked.
- The rotate buttons on the character sheet turn the figure while held. They were only for show.
- Searching the settings window shows a whole section or none of it, and a section is never cut in two by the column break, so nothing turns up indented under nothing.
- A toggle's name typed after /fcui works whatever its case, /fcui onebag on for one. Most names never matched.
- The chosen category in the game's options window wears the old yellow highlight instead of a white bar.

### Added
- The stat boxes of the 2.x character sheet, now the sheet's default: two drop downs under the model, each listing any section of the game's own character window, General, Primary Attributes, Weapons, Modifiers, Defense or Resistances. The lines, numbers and tooltips are the game's own, so they read exactly as the default window's do. Untick "Stat panes with drop downs" for the plain 1.x pair of attributes and attacks.
- One bag columns: how many slots across the one bag window is, from the old four up to sixteen. In the settings window under One bag, and under the bags dialog in edit mode.
- Opened bags above the bag buttons is a choice, and starts off: opened bags go where the default interface puts them unless you tick it, in the settings window or under the bags dialog in edit mode. The two tick boxes are the same setting.

### Changed
- The game menu is closer to the old one: white labels on the buttons under a gold Main Menu plate, the buttons at the old spacing, and the stack sitting up under the plate.

## [0.5.0] - 2026-09-19

### Added
- The classic bar comes apart in edit mode. The micro menu and the bags are pieces of their own: drag either one off the bar and it stays where you put it, with its piece of the stone bar under it, and drop it near the bar to snap it back. They snap on in either order, micro menu then bags or bags then micro menu, and the bar shows what letting go will do while you are still holding the piece.
- The bar is as long as what is on it. Take the bags off and it ends after the micro menu; take both off and it ends after bar 1's page arrows. The right gryphon, the experience bar and its segments close up to match.
- The two gryphons are edit mode pieces too, as they are in the default interface: drag one, hide it from its own dialog, or drop it near its end of the bar to put it back.
- The micro menu has its own edit mode dialog with a size slider, Reset To Default Size and Reset To Default Position. The bags dialog gains Reset To Default Size. A piece put back on the bar returns to its normal size so everything fits together.
- Bar 1 set to fewer than twelve icons in edit mode shortens the bar from the left, as the default bar does.
- One bag: all your bags open as a single window in the old bag art, as tall as your slots need. It is the game's own Combine Bags setting, offered in the addon's settings and under the bags dialog in edit mode.
- Opened bags hang above the bag buttons wherever those are, and can take the size you gave the bag row ("Opened bags take this size too", under the bags dialog in edit mode).
- Default interface bar size: a toggle that draws the classic bar at the size of the game's own action bar. The true 1.x bar is a fifth smaller at the same interface scale. With it on, bars 1 and 2 go to ten icons and the two side bars to eight in the ClassicUI Forever layout, since twelve no longer fit most screens.
- The PvP emblem beside the portrait on the player, target and focus frames, with the flag's timer over it, as 1.x drew it.
- Toggle all in the settings window, and Escape closes that window.
- The layout button offers Reset layout once you are on the ClassicUI Forever layout, which puts that layout back to its defaults.

### Changed
- The guild button in the micro menu is the old Social button again: it opens the friends window, with the guild as one of its tabs, and says Social. The guild key still opens the roster. The Guild tab is grayed out for a character in no guild.
- The reagent bag is a small round button between the key ring and the last bag instead of a full slot standing in the micro menu's part of the bar.
- The settings window is laid out afresh: the buttons that act on the toggles sit with the toggles, reports and feedback have their own corner, and the window is a little less see-through.
- Turning the addon off hands the default interface back as you left it. Unticking it in the AddOns list, or typing /fcui off, makes your earlier edit mode layout active again and restores the game settings the addon changed. Turning only the classic bar off resets every piece of the bar in the ClassicUI Forever layout so the game's own bar is not left in a jumble.

### Fixed
- A rogue's energy fills smoothly on the player frame instead of climbing in steps of twenty.
- The right click menu on a guild member closes when you click anywhere else, and with the roster.
- The experience bar's segments are whole and equal at any bar length, with no sliver of a segment at either end.
- The bag buttons no longer wear a brown ring the old bar never had, and an empty bag slot is not see-through when the bags are off the bar.
- A checkbox ticked in the copy of the settings inside the game's own Settings window no longer raises an error.
- Bar 1 dragged in edit mode is not put back where it was, and dropped near the middle of the screen it centers exactly.
- Turning the classic bar off no longer stops partway on an error from the game's own micro menu layout.
- The settings window no longer pokes through edit mode's panels.
- The character sheet no longer writes its size into the game's panel settings, one of the ways the addon could end up blamed for errors in the game's own frames.
- The talents window opens during a fight again, and opening it no longer stops the empty slots of bars 2 to 5 from showing up when you drag a spell. The classic spellbook had put itself in the way of every tab of the game's window, talents included; it now only answers for the spellbook.
- The spellbook button in the micro menu opens the classic spellbook, as the spellbook key does.
- One bag no longer shows slots that are not there. When your slots do not fill the last row, the places left over are plain leather, and they are at the bottom right instead of the top left. Separate bags of an odd size get the same treatment.
- The Who and Guild tabs of the social window keep the window's border, title bar and portrait ring.
- Opening the Skills tab of the character window during combat no longer raises an error. The tabs along the bottom of the classic character sheet are now the game's own tabs under the old art, and the skills list keeps the game's own layout, drawn at the old row spacing.
- The lower pane of the Skills tab is the old one: the description stands on the window's background with no black box behind it, the scroll column runs down to a gray foot with a Close button, the skill bar is narrower with the old small unlearn button at its end, and that button's tooltip is the one old line. The bar's name follows the skill you pick.
- The scroll bar's knob on the character sheet's lists reaches its arrows at both ends, and the track art of a short list no longer runs on below it.

## [0.4.5] - 2026-09-19

### Added
- The breath, fatigue and feign death bars in the old cast bar art, with their own toggle.

### Changed
- Once the classic layout is on, the Classic layout button in the options window reads "Back to" your earlier layout and switches you back to it.

### Fixed
- The health and power numbers on the unit frames are drawn over the frame's border instead of sliding under it.
- Vendor windows show their own tooltips again. Closing the classic spellbook during a fight could leave its unseen buttons answering the mouse there afterwards.
- The action bars and the chat window no longer hop sideways when you take a target, or sit shifted for the length of a fight. The stone bar's bars are now written into the ClassicUI Forever layout, quietly as a session ends, so this takes effect from your next login after updating. A bar you drag in edit mode is still yours to place.
- The classic spellbook opens during a fight on a fresh login too, not only after it has been opened once beforehand.
- Dragging a spell out of the classic spellbook no longer casts it.
- The target's target frame is back under the target's portrait, on the target frame and both sizes of the focus frame, with a green health bar and its bars inside the frame's art.
- The bag slots, the key ring and the micro buttons should hold their places on the stone bar better: when the game moves them they are now put back at once, during a fight as well, instead of once it ends.
- Action button icons could come out dimmed at random, from the socket art landing over the icon instead of under it. This should be gone; please report it if you still see it.
- The character window no longer leaves two loose icons beside it after the equipment manager has been open.
- The level on a nameplate takes the same color as the level on the target frame.

## [0.4.4] - 2026-09-19

### Fixed
- A skull again marks anything far above your level, on the nameplate and on the target frame, where the number was showing instead. 1.x never told you the level of a mob more than ten above you; this client does, so the old rule is kept in the addon.

## [0.4.3] - 2026-09-19

### Fixed
- The classic spellbook no longer lists a flyout, such as a warrior's Stances. A flyout groups spells that are each in the book already, the game's own spellbook does not list one either, and clicking it put a Lua error on screen.
- The classic spellbook opens during a fight again. Its casting buttons moved onto a layer of their own above the book, since a window holding them is one the game will not show there. Closing it during a fight fades it away and puts it away once the fight ends.
- The player frame keeps its old art through a fight. The game writes its own frame, flash and status art back whenever that art changes, low health among the reasons, and ours is put back over it; before, its modern art came through our shape as a stray hook of gold across the frame.
- The spellbook no longer takes the talents key. Ours answered the spellbook's own keys and the talents key as well, so the talents window could not be opened.
- With the classic spellbook turned off, the game's own spellbook is fully its own again, instead of a blocked action when its key was pressed during a fight.

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
