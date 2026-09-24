# Conventions

How the addon is laid out, which shared helper does what, and the rules the checker enforces.
Read this before adding code. `tools/`, `docs/`, `dev/` and `.github/` never ship.

## Before adding code

1. Search for an existing helper first (`grep -rn "function ns\." Core UI Art`).
2. A second copy of a pattern goes into the shared layer (Core/, Art/, UI/) as an `ns.` function, and both places call it. Never paste it a second time.
3. Run `bash tools/ci-local.sh` before you push. CI runs the same steps.

## Folder map

Load order is the order of `ClassicUIForever.toc`. Every addon `.lua` must be listed there.

| Folder | Owns |
|---|---|
| Core | Module registry and the apply pass (`ns.RegisterModule`, `ns.ApplyAll`), defaults and module order (Defaults.lua), saved settings and every CVar write (Settings.lua), the scheduler (Scheduler.lua), hook installers (Hooks.lua), compare-before-set setters (Setters.lua), edit mode queries (EditMode.lua), secret-safe helpers (Util.lua). |
| Art | Texture keys and files (TextureData.lua, Textures.lua: `ns.SetTex`, `ns.SetFile`), the bronze theme (Bronze.lua, BronzeClient.lua, generated BronzeArt.lua). |
| UI | Shared look pieces: texture dressing, dialogs and popups, menus, tooltips, client menus, controls, scroll bars, list pieces, colours, our window manager (Windows.lua), Escape handling, secure pads, the edit mode look. |
| Bar | The classic main bar: the band, its art, action bars, bags, micro menu, status bars, cast bar spot, pins, and the band's watch. |
| Units | Unit frames, cast bars, nameplates, combo points, mirror timers, buff arrow, raid manager, last names. |
| Map | Minimap cluster, tracking icon, queue eye, minimap button, map fade. |
| Quest | Quest log window and data, map quest pane, quest tracker look. |
| Windows | Old chrome on client windows (WindowChrome, Panels, PanelAfters, Tabs), chat buttons, loot, NPC windows, bags and bank. |
| Social | Social window helpers, guild roster, data, openers and note bridge, who list, group finder and its tabs. |
| Character | The character sheet: core, model, stats, stat panes, list tabs, skill and reputation detail, equipment pane. |
| Spells | The classic spellbook. |
| Skills | The skill window shell and its users: trade skill, trainer, professions book and window, talents. |
| Options | Toggles table, options window, settings page, slash commands, layout, game menu and settings panel looks, status, diagnostics, welcome note. |

A feature is a module: `ns.RegisterModule(key, { apply, restore, init })`, its id listed in `ns.MODULE_ORDER` (Core/Defaults.lua), its toggle in `ns.TOGGLES` (Options/Toggles.lua). `restore` hands back everything `apply` took. Both run on every pass, so they work only on a change.

## Shared helpers

| Need | Use |
|---|---|
| Run something every frame or on a period | `ns.Sched.Job{ name, every, fn }` (one shared driver, sleeps when idle) or `ns.Sched.OnFrame(frame, spec)` for a watch that must run on its own frame. `job:Wake()`, `:Sleep()`, `:Kick()`, `:Burst(s)`. Core/Scheduler.lua |
| Run once later | `ns.Sched.Soon(key, fn)` (this frame's pass), `ns.Sched.NextFrame(key, fn)` (leave a client pass), `ns.Sched.AfterPerFrame(key, s, fn)`. `ns.WhenCalm(key, fn)` waits for combat to end. |
| Hook client code (existing work only) | `ns.HookMethod(frame, method, fn)`, `ns.HookGlobal(name, fn)`, `ns.HookScriptOnce(frame, script, fn)`. Core/Hooks.lua |
| Events | `ns.RegisterEvents(frame, list, unit1, unit2)`. Core/Util.lua |
| Write a CVar | `ns.SetCVar(name, value)`, only from a player action; it records the old value to hand back. Read with `ns.GetCVar(name)`. Core/Settings.lua |
| Tell other code something happened | Our own signal, like `ForeverClassicUI_OnSheetLaid` / `ns.SignalSheetLaid` (Core/Core.lua). |
| Set a value without a no-op write | `ns.SetPointIf`, `ns.SetAlphaIf`, `ns.SetShownIf`, `ns.SetScaleIf`, `ns.SetLevelIf`, `ns.SetVertexColorIf`, `ns.SetAttributeIf`; `ns.Fade` / `ns.Unfade`; `ns.OwnTexture`, `ns.OwnFontString`. Core/Setters.lua |
| Values that may be secret | `ns.IsSecret(v)`, `ns.Safe(v, fallback)`, `ns.AnySecret(...)`. Core/Util.lua |
| Edit mode state | `ns.EditMode`, `ns.OnEditMode`, `ns.ActiveLayoutInfo()`, `ns.InDefaultPosition()`. Core/EditMode.lua |
| Put art on a texture | `ns.Dress(tex, key, spec, ...)`, `ns.DressNew(parent, key, spec, ...)`, `ns.DressPieces`, `ns.ThreeSlice`, `ns.TileTex`. Specs are constants at the call site. UI/Dress.lua |
| Button state art | `ns.DressStates(button, normal, pushed, disabled, highlight, how)`, `ns.EachState`, `ns.FadeKeys`, `ns.EachTexture`. UI/Dress.lua |
| Dialog box, header plate, close X, drag | `ns.Backdrop(frame, info, how)` with `ns.BACKDROP`, `ns.DialogBacking`, `ns.DialogEdge`, `ns.DialogHeader`, `ns.DialogClose`, `ns.MakeDraggable`. UI/Dialogs.lua |
| Popups and tips on our widgets | `ns.Popup(name, def)`, `ns.ReloadPopup`, `ns.AttachTip(widget, spec)`, `ns.ShowTip`, `ns.HideTip`, `ns.SayNotInCombat()`. UI/Dialogs.lua |
| Drop downs and right-click menus | `ns.DropList(entries)`, `ns.RowMenu(entries)`, look from `ns.MENU_LOOK`. UI/Menus.lua. Client menus get the old rim in UI/ClientMenus.lua; client tooltips in UI/Tooltips.lua. |
| Old skins on client controls | `ns.SkinRedButton`, `ns.SkinCheckbox`, `ns.SkinDropdown`, `ns.SkinSliderWithSteppers`, `ns.SkinMinimalTab` (UI/Controls.lua); scroll bars in UI/ScrollBars.lua; list pieces in UI/ListPieces.lua; edit mode pieces `ns.EditModeBorder`, `ns.EditModeClose`, `ns.EditModeSlider`, `ns.EditModeCheck`, `ns.EditModeRed` (UI/EditModeLook.lua). |
| Our own windows | `ns.DefinePanel`, `ns.RegisterClassicWindow`, `ns.ShowPanel`, `ns.HidePanel` (UI/Windows.lua); Escape via `ns.CloseOnEscape`, `ns.CloseWithGameMenu` (UI/Escape.lua). |
| A secure click on a client button | `ns.MapPad` (UI/SecurePad.lua). |
| Colours and fonts | `ns.FONT_GOLD*`, `ns.QuestLevelColor`, `ns.HealthColor`, `ns.PowerColor`, `ns.CreateBar`. UI/Colors.lua |

## Theme rule

The normal look is classic silver everywhere. The bronze theme (`ns.BronzeOn()`) keeps every classic shape and makes the metal bronze: windows and dialog-style boxes (popups, edit mode, the game menu, the quest timers box, ours) show the 1.x shapes in the bronze copies of the art (`ns.OldDialogBorder`, `ns.OldDialogHeader`, `ns.Backdrop`). Two exceptions show Forever's own art with the theme on: tooltips (UI/Tooltips.lua) and menus (UI/ClientMenus.lua). A new piece follows the dialog rule unless it is a tooltip or a menu. Every new piece follows the toggle: tint our silver art with `ns.BronzeTint`, keep client bronze with `ns.BronzeKeep`, drain client trim with `ns.DrainBronze`, borders through `ns.BronzeBackdrop` (or `ns.Backdrop`, which calls it). Registered pieces repaint on a toggle (`ns.RepaintBronze`); a restore that hands a texture back takes it out of the file swap first (`ns.UnswapBronze`, Art/Textures.lua). Art/Bronze.lua

## Taint rules

- Watch, do not hook, client code in new work. Poll state from a scheduler job; our code inside a client pass taints that pass.
- No CVar writes unless the player asked for the change. They go through `ns.SetCVar`.
- No calls on client callback registries (`EventRegistry`, `CVarCallbackRegistry`, a client frame's `RegisterCallback` / `TriggerEvent`). Use our own signal or event frame.
- No edit mode layout writes during a session. Writes run only as the session ends: the `ns.sessionEnding` jobs queued with `ns.QueueLayoutJob` in Options/Layout.lua (`FitNow`, `ResetNow`, `ClassicNow`, `SelectNow`, `ns.ApplyClassicFrameSpots`) and the pin writer in Bar/BandPins.lua.
- Do not load client addons from our code. Wait for their `ADDON_LOADED`.
- Do not drive the client window manager from our code (`UpdateUIPanelPositions`, `FramePositionDelegate`, `SetUIPanelAttribute`): its pass then runs in our name, and in combat it can neither close windows on Escape nor place them. Open and close through `ns.ShowPanel` / `ns.HidePanel`.
- Nothing protected in combat: check `InCombatLockdown()`, defer with `ns.WhenCalm`.
- Never compare or do arithmetic on a secret value. Test with `ns.IsSecret` / `ns.Safe` first.
- No fields written on client frames. Keep state in our own weak tables.

## Comment style

One line, and only the essential why. No history, no proofs, no narration. At most 3 comment lines in a row, and no comment line over 140 characters. History belongs in the commit message.

## The checker

`tools/check.py` is standard library Python 3 and runs in CI (Conventions job), in `tools/ci-local.sh`, and before a release build.

```
python tools/check.py --all                  # every addon .lua in the tree, untracked ones too
python tools/check.py --staged               # staged .lua files, staged content (pre-commit)
python tools/check.py --files Core/Util.lua  # given files
python tools/check.py --all --json           # machine output
python tools/check.py --update-baseline      # maintainers only, after a cleanup
python tools/check.py --carry-renames        # after a git mv, moves the file's baseline entries
bash tools/ci-local.sh                       # luacheck + TOC + conventions, like CI
```

Exit 0 is clean, 1 is new violations (`path:line: RULE message. Fix: ...`), 2 is a usage or internal error.

Existing violations are recorded per rule and per file in `tools/check-baseline.json`. A file passes while its count is at or below that number, so old code passes and new violations fail. When you remove violations, a maintainer lowers the baseline with `--update-baseline`. Never raise it to make a change pass.

- Lines the change adds (against the index for `--staged`, against HEAD otherwise, and every line of an untracked file) are marked `[NEW]`. For CVAR, REGISTRY, HOOK, ONUPDATE, LOADADDON and EDITMODE a hit on an added line fails even while the file is within its baseline, so swapping one call for another fails. A line moved within the same file (same text removed and added) is not new.
- The pattern rules count uses only: a call, a `pcall` wrapper, a reference passed or assigned (`local set = SetCVar`). Existence guards such as `if C_CVar and C_CVar.SetCVar then` do not count.
- Renaming a file: after `git mv`, run `python tools/check.py --carry-renames` and stage `tools/check-baseline.json` with the rename. `--staged` refuses the commit until you do; `--all` and `--files` carry the entries meanwhile.

| Rule | Fails on | Fix |
|---|---|---|
| CVAR | `SetCVar`, `_G.SetCVar`, `C_CVar.SetCVar` (or an alias of `C_CVar`), `SetCVarBitfield`, `ConsoleExec`, `Settings.SetValue` outside Core/Settings.lua | `ns.SetCVar`, on a player action only |
| REGISTRY | `EventRegistry`, `CVarCallbackRegistry`, `Client:RegisterCallback` / `TriggerEvent` | our own signal or event frame |
| HOOK | `hooksecurefunc` outside Core/Hooks.lua | `ns.HookMethod` / `ns.HookGlobal` / `ns.HookScriptOnce`; prefer a watch |
| ONUPDATE | `:SetScript` or `:HookScript` with `"OnUpdate"`, `[[OnUpdate]]` or a variable holding it (arguments may be on the next line) outside Core/Scheduler.lua | `ns.Sched.OnFrame` / `ns.Sched.Job` |
| LOADADDON | `LoadAddOn`, `C_AddOns.LoadAddOn`, `UIParentLoadAddOn` | wait for `ADDON_LOADED` |
| EDITMODE | layout writes and layout-changing calls (`SaveLayouts`, `SetActiveLayout`, `SelectLayout`, `OnSystemSettingChange`, `UpdateSystemAnchorInfo`, `MakeNewLayout`, `DeleteLayout`, `RenameLayout`, `RevertAllChanges`, `SetHasActiveChanges`...) outside Bar/BandPins.lua | never write layouts mid-session; session-end writers only |
| FILESIZE | a file over 800 lines | split it by responsibility |
| FUNCSIZE | a function over 120 lines | extract named local helpers |
| COMMENT | more than 3 comment lines in a row, or one over 140 characters | one-line whys |
| DUP | 8 or more code lines repeated elsewhere | move it to the shared layer |
| DUPFN | a local function with the same body as one in another file (reported instead of DUP) | one `ns.` copy in the shared layer |
| TOC | an addon `.lua` missing from the .toc (untracked new files too), or a .toc entry that is not a file | fix the .toc |
| BASELINE | `--staged` only: a renamed file whose baseline entries still name the old path | `--carry-renames`, then stage the baseline |
