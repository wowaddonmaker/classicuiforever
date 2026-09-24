# Conventions

How the addon is laid out, which shared helper does what, and the rules the checker enforces.
Read this before adding code. `tools/`, `docs/`, `dev/` and `.github/` never ship.

## Before adding code

1. Search for an existing helper first (`grep -rn "function ns\." Core UI Art`).
2. A second copy of a pattern goes into the shared layer (Core/, Art/, UI/) as an `ns.` function, and both places call it. Never paste it a second time.
3. Per-frame work only where no client signal exists, and only while its state is active.
4. Run `bash tools/ci-local.sh` before you push. CI runs the same steps.

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
| Run something every frame or on a period | `ns.Sched.Job{ name, every, fn }` (one shared driver, off the frame loop when idle and between slow jobs) or `ns.Sched.OnFrame(frame, spec)` for a watch that must run on its own frame (a throttled one gives its frame-order reason on the call line). `job:Wake()`, `:Sleep()`, `:Kick()`, `:Burst(s)`. Core/Scheduler.lua |
| Watch only while a window shows | `ns.Sched.Attach(host, spec)` -> job, made: one pure child watcher per host and name, kept in the scheduler, never on host; `ns.Sched.Attached(host, name)` finds it. Core/Scheduler.lua |
| Hear a frame show, hide or move | `ns.Sched.OnVisible(host, name, fn)`: fn(shown) from one pure child per host and name, inside the client's show pass, so fn only notes, kicks or asks `NextFrame`. `ns.Sched.OnMove(frame, fn)`: fn() in the layout pass that moves or resizes frame. Core/Scheduler.lua |
| Beat inside a per-frame lane | `ns.Sched.Due(state, elapsed, every, force, key)` returns the time gathered when due (`B.Due` in the band); an OnFrame `pre` asks `job:DueWith(elapsed)` instead of reading scheduler fields. Core/Scheduler.lua |
| Run once later | `ns.Sched.Soon(key, fn)` (this frame's pass), `ns.Sched.NextFrame(key, fn)` (leave a client pass), `ns.Sched.AfterPerFrame(key, s, fn)`. `ns.WhenCalm(key, fn)` waits for combat to end. |
| Call without breaking the pass | `ns.SafeCall(fn, ...)`; `ns.Report(err)` is the xpcall handler (the error handler is looked up only on an error). Core/Core.lua |
| Hook client code (existing work only) | `ns.HookMethod(frame, method, fn)`, `ns.HookGlobal(name, fn)`, `ns.HookScriptOnce(frame, script, fn)`. Core/Hooks.lua |
| Events | `ns.RegisterEvents(frame, list, unit1, unit2)` on an existing frame; `ns.EventFrame(events, onEvent, unit1, unit2)` makes the plain event frame at the caller's own site (events is one name or a list). Core/Util.lua |
| Write a CVar | `ns.SetCVar(name, value)`, only from a player action; it records the old value to hand back. `ns.WriteCVar(name, value)` for the player's own value or a hand-back (never recorded, no same-value skip). Core/Settings.lua |
| Read a CVar | `ns.GetCVar(name)`, `ns.GetCVarBool(name)` (nil when missing or the call fails). Core/Util.lua |
| Tell other code something happened | Our own signal, like `ForeverClassicUI_OnSheetLaid` / `ns.SignalSheetLaid` (Core/Core.lua). |
| Set a value without a no-op write | `ns.SetPointIf`, `ns.SetAlphaIf`, `ns.SetShownIf`, `ns.SetScaleIf`, `ns.SetLevelIf`, `ns.SetStrataIf`, `ns.SetVertexColorIf`, `ns.SetBarColorIf`, `ns.SetAttributeIf`; `ns.SetPointOnce` (unconditional clear and one point); `ns.Near(a, b, tol)` for callers that check types first; `ns.Fade` / `ns.Unfade`; `ns.OwnTexture`, `ns.OwnFontString`. Core/Setters.lua |
| Once per frame, our own regions | `ns.Once(frame, key)` is true the first time per frame and key (a weak table, never a field on the frame); `ns.IsOwnRegion(frame, region)` tells our regions kept in `frame.fcui`. Core/Setters.lua |
| Values that may be secret, frames that may be forbidden | `ns.IsSecret(v)`, `ns.Safe(v, fallback)`, `ns.AnySecret(...)`; `ns.IsForbidden(object)` (missing or forbidden: ask it nothing); `ns.Askable(frame, method)` (has the method and may be asked). Core/Util.lua |
| Edit mode state | `ns.EditMode`, `ns.OnEditMode`, `ns.ActiveLayoutInfo()`, `ns.InDefaultPosition()`. Core/EditMode.lua |
| Theme look | `ns.ThemeLook(clientArt)` ("classic", "bronze" or "client"), `ns.ThemeTurned(state)` (true once per theme change in a module's own pass), `ns.KeepDrained(region, r, g, b)`, `ns.DrainInput(box, drain)` with `ns.INPUT_GREY`, `ns.DrainSlice(slice, grey, drain)`, `ns.TintSlice(slice)`. Art/Bronze.lua |
| Put art on a texture | `ns.Dress(tex, key, spec, ...)`, `ns.DressNew(parent, key, spec, ...)`, `ns.DressPieces`, `ns.ThreeSlice`, `ns.TileTex`; art paths in `ns.ART` (`ns.ART.PAGE_PREV`, `ns.ART.PAGE_NEXT` ...). Specs are constants at the call site. UI/Dress.lua |
| Button state art | `ns.DressStates(button, normal, pushed, disabled, highlight, how)`, `ns.EachState`, `ns.FadeKeys`, `ns.EachTexture`. UI/Dress.lua |
| Dialog box, header plate, close X, drag | `ns.Backdrop(frame, info, how)` with `ns.BACKDROP`, `ns.DialogBacking`, `ns.DialogEdge`, `ns.DialogHeader`, `ns.DialogClose`, `ns.MakeDraggable`; `ns.DialogWindow(name, y, strata, opts)` is our standalone dialog shell, hidden. UI/Dialogs.lua |
| Old dialog chrome on client dialogs | `ns.DialogChrome(paintNow)` -> a set with `:Border`, `:Header`, `:Drain`, `:Fade`, `:On`, `:Off`, shared by UI/EditModeLook.lua and UI/ClientDialogs.lua. UI/EditModeLook.lua |
| Popups and tips on our widgets | `ns.Popup(name, def)`, `ns.ReloadPopup`, `ns.AttachTip(widget, spec)`, `ns.ShowTip`, `ns.HideTip`, `ns.SayNotInCombat()`. UI/Dialogs.lua |
| Drop downs and right-click menus | `ns.DropList(entries)`, `ns.RowMenu(entries)`, look from `ns.MENU_LOOK`. UI/Menus.lua. Client menus get the old rim in UI/ClientMenus.lua; client tooltips in UI/Tooltips.lua. |
| Old skins on client controls | `ns.SkinRedButton`, `ns.SkinCheckbox`, `ns.SkinDropdown`, `ns.SkinSliderWithSteppers`, `ns.SkinMinimalTab`, `ns.SearchClear(box)` (the client's X on a search box), `ns.RedButtonArt(button, how)` with `ns.RED_COORDS` (UI/Controls.lua); scroll bars in UI/ScrollBars.lua; list pieces in UI/ListPieces.lua; edit mode pieces `ns.EditModeBorder`, `ns.EditModeClose`, `ns.EditModeSlider`, `ns.EditModeCheck`, `ns.EditModeRed` (UI/EditModeLook.lua). |
| Page-arrow toggle, list offset | `ns.PanelToggle(parent, name, size, point, rel, relPoint, x, y, level, onClick, tip)`, `ns.PanelToggleFace(button, open, how)` (each site keeps its own `how`); `ns.ListOffset(bar)` is a list's first row from its scroll bar. UI/Controls.lua |
| Our own windows | `ns.DefinePanel`, `ns.RegisterClassicWindow`, `ns.ShowPanel`, `ns.HidePanel` (UI/Windows.lua); Escape via `ns.CloseOnEscape`, `ns.CloseWithGameMenu` (UI/Escape.lua). |
| A secure click on a client button | `ns.MapPad` (UI/SecurePad.lua). |
| Colours and fonts | `ns.FONT_GOLD*`, `ns.QuestLevelColor`, `ns.HealthColor`, `ns.PowerColor`, `ns.ClassRGB(classFile)` (nothing for a missing, secret or unknown class), `ns.CreateBar`. UI/Colors.lua |
| Nameplates | `ns.NP.EachPlate(fn, withForbidden)`. Units/NamePlates.lua |
| The band | `B.Due` (lane beat), `B.Drifted(frame, mark, withRelPoint)` (moved from a Record mark), `B.WhileApplying(fn, ...)` (our own pass: the watches skip what it moves), `B.WakeBars(asleep)` (the only writer of the bars watch's sleep), `B.GuardedSlider(slider, init, onChange, opts)` (a band dialog slider whose own Init never reaches onChange). Bar/Band.lua |
| Social lists | `S.SettleFrame(state)` (one per module, where it loads), `S.ShowRow(row, entry, zone, level, class, classFile, selected, dim)`, `S.HideRow(row)`. Social/SocialWindow.lua |
| Window chrome | `P.MaxMinBeside(sizer, close, x)` (the size button beside the X). Windows/WindowChrome.lua |

## Theme rule

`ns.ThemeLook(clientArt)` (Art/Bronze.lua) is the single statement of this rule: it answers "classic" with the theme off, "bronze" with it on, and "client" for a piece that shows Forever's own art with the theme on (pass `clientArt`). Code outside Art/ asks it and never reads the setting by hand (THEME).

The normal look is classic silver everywhere. The bronze theme keeps every classic shape and makes the metal bronze: windows and dialog-style boxes (popups, edit mode, the game menu, the quest timers box, ours) show the 1.x shapes in the bronze copies of the art (`ns.OldDialogBorder`, `ns.OldDialogHeader`, `ns.Backdrop`). Two exceptions show Forever's own art with the theme on: tooltips (UI/Tooltips.lua) and menus (UI/ClientMenus.lua). A new piece follows the dialog rule unless it is a tooltip or a menu. Every new piece follows the toggle: tint our silver art with `ns.BronzeTint`, keep client bronze with `ns.BronzeKeep`, drain client trim with `ns.DrainBronze` (input boxes with `ns.DrainInput`), borders through `ns.BronzeBackdrop` (or `ns.Backdrop`, which calls it). Registered pieces repaint on a toggle (`ns.RepaintBronze`); a module that paints in its own pass notices the toggle with `ns.ThemeTurned`. A restore that hands a texture back takes it out of the file swap first (`ns.UnswapBronze`, Art/Textures.lua).

## Taint rules

- Watch, do not hook, client code in new work. Poll state from a scheduler job; our code inside a client pass taints that pass.
- No CVar writes unless the player asked for the change. They go through `ns.SetCVar`; never at login.
- No calls on client callback registries (`EventRegistry`, `CVarCallbackRegistry`, a client frame's `RegisterCallback` / `TriggerEvent`). Use our own signal or event frame.
- No edit mode layout writes during a session. Writes run only as the session ends: the `ns.sessionEnding` jobs queued with `ns.QueueLayoutJob` in Options/Layout.lua (`FitNow`, `ResetNow`, `ClassicNow`, `SelectNow`, `ns.ApplyClassicFrameSpots`) and the pin writer in Bar/BandPins.lua.
- Do not load client addons from our code. Wait for their `ADDON_LOADED`.
- Do not drive the client window manager from our code (`UpdateUIPanelPositions`, `FramePositionDelegate`, `SetUIPanelAttribute`, `UpdateContainerFrameAnchors`, `UIPanelLayout-` attributes): its pass then runs in our name, and in combat it can neither close windows on Escape nor place them. Open and close through `ns.ShowPanel` / `ns.HidePanel`.
- Nothing protected in combat: check `InCombatLockdown()`, defer with `ns.WhenCalm`.
- Never compare or do arithmetic on a secret value. Test with `ns.IsSecret` / `ns.Safe` first.
- No fields written on client frames. Keep state in our own weak tables (`ns.Once` for a once-guard).

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

- Lines the change adds (against the index for `--staged`, against HEAD otherwise, and every line of an untracked file) are marked `[NEW]`. For CVAR, CVARREAD, REGISTRY, HOOK, ONUPDATE, TIMER, LOADADDON, EDITMODE, EDITQUERY, PANELMGR, SECRET, WALK, REGEVENTS, EVENTFRAME, POINTONCE, SETIF, THEME, ONCEFLAG, GAMEMENU, SHAREDART, PLATES, FORBIDDEN, SYSBASE, LAYOUTFIELD and PADART a hit on an added line fails even while the file is within its baseline, so swapping one call for another fails. A line moved within the same file (same text removed and added) is not new. The count-only rules (SINCE, CVARLOGIN, THROTTLEFRAME, FRAMEFIELD, DEADNS) fail only when a file's count goes up.
- The pattern rules count uses only: a call, a `pcall` wrapper, a reference passed or assigned (`local set = SetCVar`). Existence guards such as `if C_CVar and C_CVar.SetCVar then` do not count.
- Each allowance carries its reason in `tools/check.py`: whole files in `ALLOWED`, single frames (file and variable) in `ALLOWED_SITES`, wrapper bodies in `ALLOWED_BODIES`; unread names in `DEV_NAMES` (the dev addon reads them) and `KEPT_API` (planned shared API).
- Renaming a file: after `git mv`, run `python tools/check.py --carry-renames` and stage `tools/check-baseline.json` with the rename. `--staged` refuses the commit until you do; `--all` and `--files` carry the entries meanwhile.

| Rule | Fails on | Fix |
|---|---|---|
| CVAR | `SetCVar`, `_G.SetCVar`, `C_CVar.SetCVar` (or an alias of `C_CVar`), `SetCVarBitfield`, `RegisterCVar`, `SetTempCVar`, `ConsoleExec`, `CreateCVarAccessor`, `Settings.SetValue`, `/console` macro text and `"SetCVar"` names, anywhere but inside the bodies of `ns.SetCVar`, `ns.WriteCVar`, `ns.GetCVar`, `ns.GetCVarBool` (Core/Settings.lua, Core/Util.lua) | `ns.SetCVar`, on a player action only; `ns.WriteCVar` for the player's own value or a hand-back |
| CVARREAD | `GetCVar`, `GetCVarBool`, `GetCVarDefault`, `GetCVarInfo` outside those four wrapper bodies | `ns.GetCVar` / `ns.GetCVarBool` |
| CVARLOGIN | count-only: a CVar write (`ns.SetCVar`, `ns.WriteCVar`, `ns.MirrorSave` or raw) in a module `apply` / `init` body or an `ADDON_LOADED` / `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD` branch, directly or through a function of the same file (callbacks defined there run later and do not count) | write on a player action; moving today's baselined sites is the author's call |
| REGISTRY | `EventRegistry`, `CVarCallbackRegistry`, `Client:RegisterCallback` / `TriggerEvent` | our own signal or event frame |
| HOOK | `hooksecurefunc` outside Core/Hooks.lua | `ns.HookMethod` / `ns.HookGlobal` / `ns.HookScriptOnce`; prefer a watch |
| ONUPDATE | `:SetScript` or `:HookScript` with `"OnUpdate"`, `[[OnUpdate]]` or a variable holding it (arguments may be on the next line) outside Core/Scheduler.lua | `ns.Sched.OnFrame` / `ns.Sched.Job` |
| SINCE | count-only: a hand-written `x = x + elapsed` or `x = (x or 0) + elapsed` accumulator outside Core/Scheduler.lua | `ns.Sched.OnFrame` with `every`, `ns.Sched.Job`, `ns.Sched.Due` (`B.Due` in the band) |
| TIMER | `C_Timer.After(0, ...)`, `C_Timer.NewTicker`, `C_Timer.NewTimer`, `RunNextFrame` outside Core/Scheduler.lua | `ns.Sched.NextFrame` / `Soon` / `AfterPerFrame`; `ns.Sched.Job` for a repeat |
| THROTTLEFRAME | count-only: `ns.Sched.OnFrame` whose spec has `every` above 0 and no `pre`, unless the call line gives its frame-order reason in a comment | `ns.Sched.Job` (the sleeping driver) or `ns.Sched.Attach` (runs only while its window shows) |
| LOADADDON | `LoadAddOn`, `C_AddOns.LoadAddOn`, `UIParentLoadAddOn` | wait for `ADDON_LOADED` |
| EDITMODE | layout writes and layout-changing calls (`SaveLayouts`, `SetActiveLayout`, `SelectLayout`, `OnSystemSettingChange`, `UpdateSystemAnchorInfo`, `MakeNewLayout`, `DeleteLayout`, `RenameLayout`, `RevertAllChanges`, `SetHasActiveChanges`...) outside Bar/BandPins.lua | never write layouts mid-session; session-end writers only |
| EDITQUERY | `IsInDefaultPosition`, `IsEditModeActive`, `GetActiveLayoutInfo` outside Core/EditMode.lua | `ns.InDefaultPosition` / `ns.EditMode.Live` / `ns.ActiveLayoutInfo` |
| SETTLE | `S.Settle(...)` wired by hand outside Social/SocialWindow.lua | `S.SettleFrame(state)` where the module loads |
| PANELMGR | `UpdateUIPanelPositions`, `FramePositionDelegate`, `SetUIPanelAttribute`, `UpdateContainerFrameAnchors`, `SetAttribute` with a `UIPanelLayout-` name | `ns.ShowPanel` / `ns.HidePanel` |
| SECRET | `issecretvalue`, `canaccessvalue`, `issecrettable`, `canaccesstable` outside Core/Util.lua | `ns.IsSecret` / `ns.Safe` / `ns.AnySecret` |
| WALK | `{ X:GetChildren() }` or `{ X:GetRegions() }`: a walk that builds a table | `ns.EachChild` / `ns.EachRegion` with a file-level visitor |
| REGEVENTS | three `X:RegisterEvent` lines in a row on one frame, or `pcall(X.RegisterEvent, ...)`; Core/Core.lua's first frame is allowed (it loads before Core/Util.lua) | `ns.RegisterEvents(frame, LIST)`, same frame, same order |
| EVENTFRAME | a plain `CreateFrame("Frame")` given `RegisterEvent` / `ns.RegisterEvents` and `SetScript("OnEvent")` within 3 code lines; Core/Core.lua and the plan 4.2 frames (band placer, hot.watch, LastNames `after`, the unit-frame driver, powerKick and auraKick, SpellBook's REGEN_ENABLED frames, Guild's regen, settle and afterFight frames, the professions watch) are allowed; secure buttons are Button frames and never match | `ns.EventFrame` at the same site |
| POINTONCE | `X:ClearAllPoints()` then exactly one `X:SetPoint(...)`, with at most one `X:SetSize` / `SetWidth` / `SetHeight` line between | `X:SetSize(...)` then `ns.SetPointOnce(X, ...)`; keep two-point anchors as they are |
| SETIF | `if X:GetAlpha/GetScale/GetFrameLevel/GetFrameStrata() ... then X:Set...(` on one line, `if X:Get...() ~= ... then` ending a line with `X:Set...(` on the next, and `IsShown() ~= ...` with `SetShown` | `ns.SetAlphaIf` / `SetScaleIf` / `SetLevelIf` / `SetStrataIf` / `SetShownIf` with the site's tolerance |
| THEME | `ns.BronzeOn`, `ns.bronze`, `db.bronzeTheme`, `DrainBronze` or `LMR` with a literal `0.85`, `EachKey(..., KEYS.LMR, ...)` outside Art/ and Options/Welcome.lua | `ns.ThemeLook`, `ns.ThemeTurned`, `ns.KeepDrained`, `ns.DrainInput`, `ns.DrainSlice`, `ns.TintSlice` |
| ONCEFLAG | `.fcuiX = true`, a `.fcui...Watch` / `Shade` / `Look` field, and every once-guard write: after `if X.fcuiK then return end` or inside `if not X.fcuiK then` | `ns.Once(frame, key)`, `ns.Sched.Attach`, or a file-local weak table |
| FRAMEFIELD | count-only: any `.fcuiX = ...` write (the Own() `frame.fcui` table is the sanctioned exception) | a file-local weak table keyed by the frame, `ns.Once` for a once-guard |
| GAMEMENU | `GameMenuFrame:HookScript` outside UI/Escape.lua and Options/GameMenu.lua | `ns.CloseWithGameMenu(frame\|getter, closer)` |
| SHAREDART | the search clear icon or the red button coords outside UI/Controls.lua; `UI-SpellbookIcon-PrevPage` / `NextPage` paths outside UI/Dress.lua and Art/ | `ns.SearchClear`, `ns.RedButtonArt`, `ns.RED_COORDS`, `ns.ART.PAGE_PREV` / `PAGE_NEXT`, `ns.PanelToggleFace` |
| PLATES | `GetNamePlates` outside Units/NamePlates.lua | `ns.NP.EachPlate(fn, withForbidden)` |
| FORBIDDEN | `X.IsForbidden and X:IsForbidden(`, with or without a leading `not X or`, outside Core/Util.lua (`X.IsForbidden and not X:IsForbidden()` is a positive test and passes) | `ns.IsForbidden(X)` |
| SYSBASE | `SetPoint`, `ClearAllPoints`, `SetScale` or `SetAllPoints` called on a named edit mode system (action bars, bags bar, micro menu, status holders, cast bar, unit frames, minimap cluster, chat frames, loot, tracker, buffs), or on `bar`, `frame` or `piece` in Bar/: the client's wrappers write a snap note that taints its next drag | `ns.SetPointOnce`, `ns.SetPointIf`, `ns.SetScaleIf`, or `ns.BaseSetters(frame)` for two points |
| LAYOUTFIELD | a write to `ignoreInLayout`, `includeInLayout`, `layoutIndex`, `includeAsLayoutChildWhenHidden`, `ignoreAllChildren`, `expand`, `align` or a padding field on any frame: client layout code reads them, and one we wrote runs its layout pass in our name (protected calls refused in a fight) | write none; hang watcher children off client layout frames, under a child the client marks out of layout (e.g. `EditModeManagerFrame.Border`) |
| PADART | a secure frame hung from UIParent (`CreateFrame(type, name, UIParent, "Secure...Template")`) given a texture, font string, button art or backdrop: our code cannot hide it in a fight, so one that outlives its window draws a ghost bar | no art on pads; light the control under it (`LockHighlight` in OnEnter, `UnlockHighlight` in OnLeave) |
| FILESIZE | a file over 800 lines | split it by responsibility |
| FUNCSIZE | a function over 120 lines | extract named local helpers |
| COMMENT | more than 3 comment lines in a row, or one over 140 characters | one-line whys |
| DUP | 6 or more code lines (4 of them doing something) repeated elsewhere | move it to the shared layer |
| DUPFN | a local function, or a module-table function outside Core/, Art/ and UI/, whose body (3 lines or more) matches any function in another file, `ns.` ones included (reported instead of DUP) | one `ns.` copy in the shared layer, or call the twin |
| DEADNS | count-only: an `ns.` field defined but never read, unless listed in `DEV_NAMES` or `KEPT_API` | delete it, or list it there with its reason |
| TOC | an addon `.lua` missing from the .toc (untracked new files too), or a .toc entry that is not a file | fix the .toc |
| BASELINE | `--staged` only: a renamed file whose baseline entries still name the old path | `--carry-renames`, then stage the baseline |
