#!/usr/bin/env python3
"""Convention checker for the addon's Lua code (standard library only).

  python tools/check.py --all                  every addon .lua in the tree (tracked and untracked)
  python tools/check.py --staged               staged .lua files, staged content
  python tools/check.py --files <path> [...]   the given files
  python tools/check.py --update-baseline      rewrite tools/check-baseline.json from the tree
  python tools/check.py --carry-renames        move baseline entries of renamed files to the new path
  add --json for machine output

Exit 0 clean against the baseline, 1 new violations, 2 usage or internal error.
Rules and their fixes are described in tools/CONVENTIONS.md.
"""

import bisect
import hashlib
import json
import os
import re
import subprocess
import sys
import time

TOC_NAME = "ClassicUIForever.toc"
EXCLUDED_DIRS = ("dev/", "tools/", "docs/", ".github/")
SHARED_LAYER = ("Core/", "Art/", "UI/")
BASELINE_NAME = "tools/check-baseline.json"
DOC = "tools/CONVENTIONS.md"

FILE_LIMIT = 800
FUNC_LIMIT = 120
COMMENT_BLOCK_LIMIT = 3
COMMENT_CHAR_LIMIT = 140
DUP_WINDOW = 6
DUP_MIN_REAL = 4
DUPFN_MIN = 3

RULES = ["CVAR", "CVARREAD", "CVARLOGIN", "CVARREG", "REGISTRY", "HOOK", "ONUPDATE", "SINCE", "TIMER", "THROTTLEFRAME", "SEARCHBOX", "ADDONCHAR",
         "LOADADDON", "EDITMODE", "EDITQUERY", "SETTLE",
         "PANELMGR", "SECRET", "WALK", "REGEVENTS", "EVENTFRAME", "POINTONCE", "SETIF", "THEME", "ONCEFLAG",
         "FRAMEFIELD", "GAMEMENU", "SHAREDART", "PLATES", "FORBIDDEN", "SYSBASE", "LAYOUTFIELD",
         "PADART", "SECRETMOUSE", "UNITEVENTS", "DRAGPOINT", "ERASPOT", "CHECKLABEL", "LUA51", "EDITSAVE", "KEYUP", "MOUSEORDER", "SELFBOX", "PADLIST", "POINTEXACT", "FADEDPIECE", "PCALLMANY", "ADDONFORBID", "SECRETLAYER", "SECRETATLAS", "SECRETBAR", "LOCALE", "OWNRELOAD", "HELDCVAR", "NAVFRAME", "NAMEDTEMPLATE", "FRAMEWALK", "OTHERADDON", "FILESIZE", "FUNCSIZE", "COMMENT", "DUP", "DUPFN", "DEADNS", "UNDEFNS", "TOC"]
# A hit of these on a line the change adds fails even within the baseline, so swapping one call for another fails.
# SINCE, DEADNS, FRAMEFIELD, CVARLOGIN and THROTTLEFRAME stay count-only, so a kept line can still be rewritten.
LINE_RULES = ("CVAR", "REGISTRY", "HOOK", "ONUPDATE", "LOADADDON", "FRAMEWALK", "EDITMODE", "PANELMGR", "SEARCHBOX", "ADDONCHAR",
              "CVARREAD", "THEME", "POINTONCE", "SECRET", "SETIF", "REGEVENTS", "ONCEFLAG", "TIMER", "EDITQUERY",
              "PLATES", "FORBIDDEN", "EVENTFRAME",
              "WALK", "GAMEMENU", "SHAREDART", "SYSBASE", "LAYOUTFIELD", "PADART", "SECRETMOUSE", "UNITEVENTS",
              "DRAGPOINT", "ERASPOT", "CVARREG", "CHECKLABEL", "LUA51", "EDITSAVE", "KEYUP", "MOUSEORDER", "SELFBOX", "PADLIST",
              "POINTEXACT",
              "FADEDPIECE", "PCALLMANY", "ADDONFORBID", "SECRETLAYER", "SECRETATLAS", "SECRETBAR", "LOCALE", "OWNRELOAD", "HELDCVAR", "NAVFRAME", "NAMEDTEMPLATE")

# The files allowed to hold each pattern, each with its reason; an entry ending in / is a folder.
ALLOWED = {
    "SETTLE": {"Social/SocialWindow.lua": "S.SettleFrame lives there"},
    "HOOK": {"Core/Hooks.lua": "the hook installers"},
    "ONUPDATE": {"Core/Scheduler.lua": "the one OnUpdate owner"},
    "SINCE": {"Core/Scheduler.lua": "the scheduler's own counters"},
    "TIMER": {"Core/Scheduler.lua": "NextFrame, Soon and AfterPerFrame wrap the client timers"},
    "EDITMODE": {"Bar/BandPins.lua": "the session-end pin writer",
                 "Options/LayoutCopy.lua": "the session-end hand back of old pins in the player's own layouts"},
    "EDITQUERY": {"Core/EditMode.lua": "the edit mode query helpers"},
    "SECRET": {"Core/Util.lua": "the secret-value helpers"},
    "WALK": {"Core/Util.lua": "ns.EachChild / ns.EachRegion"},
    "REGEVENTS": {"Core/Util.lua": "ns.RegisterEvents"},
    "EVENTFRAME": {"Core/Util.lua": "ns.EventFrame",
                   "Core/Core.lua": "loads before Core/Util.lua, so ns.EventFrame does not exist yet"},
    "POINTONCE": {"Core/Setters.lua": "ns.SetPointOnce"},
    "SETIF": {"Core/Setters.lua": "the compare-before-set setters"},
    "THEME": {"Art/": "the theme owns its registries", "Options/Welcome.lua": "the theme's first-run offer"},
    "GAMEMENU": {"UI/Escape.lua": "ns.CloseWithGameMenu", "Options/GameMenu.lua": "the game menu look"},
    "OWNRELOAD": {"Options/Layout.lua": "ns.ReloadForLayout and the turn-off popup's own press"},
    "PLATES": {"Units/NamePlates.lua": "ns.NP.EachPlate"},
    # Frames that never stand inside a window the gamepad navigates.
    "NAVFRAME": {"Core/": "ns.NewFrame itself, and the core's own frames", "Art/": "no windows",
                 "Bar/": "the band stands on UIParent", "Units/": "unit frames and plates are no windows",
                 "Map/Minimap.lua": "the minimap cluster is no window", "Map/MinimapButton.lua": "on the minimap",
                 "Map/MinimapCalendar.lua": "on the minimap", "Map/MinimapEye.lua": "on the minimap",
                 "Map/MinimapCollector.lua": "on the minimap", "Map/TrackingBuff.lua": "on the minimap"},
    "FORBIDDEN": {"Core/Util.lua": "ns.IsForbidden"},
    # Unit frame bars only: our own frames, buttons and client tabs never answer IsMouseOver with a secret.
    "SECRETMOUSE": {folder: "only unit frame bars can answer secret" for folder in (
        "Art/", "Bar/", "Character/", "Core/", "Map/", "Options/", "Quest/", "Skills/", "Social/", "Spells/",
        "UI/", "Windows/")},
    "SEARCHBOX": {"UI/Controls.lua": "ns.SearchBox", "Skills/TradeSkill.lua": "the craft count, no search",
                  "Social/SocialWindow.lua": "the who line: the lens, ns.SearchClear",
                  "Spells/SpellBook.lua": "its search, X built in, Escape keeps the text"},
}
# Frames allowed a pattern by file and variable: plan 4.2 keeps their own frames and registrations untouched.
ALLOWED_SITES = {
    # By list name (or the first UNIT_ event of a literal): why every unit's copy is wanted or cheap.
    "UNITEVENTS": {
        "Bar/BandBottom.lua:RESTAND_EVENTS": "UNIT_TARGETABLE_CHANGED is rare; it only re-stands the band container",
        "Quest/QuestLogWindow.lua:LOG_EVENTS": "other units only mark the party counts, and only while the log shows",
        "Units/HoverNumbers.lua:HOVER_EVENTS": "registered only while a hover number shows; HoverRefresh matches the unit",
        "Units/LastNames.lua:TRIM_EVENTS": "only with Hide Last Names on; the trim is keyed per frame",
        "Units/LastNames.lua:NAME_EVENTS": "only with Hide Last Names on; a unit's event re-trims only its own texts",
        "Units/NamePlates.lua:PLATE_EVENTS": "plates show every unit; OnEvent looks the plate up by its unit",
        "Units/NamePlateAuras.lua:RING_EVENTS": "nameplate units cannot be listed; other units return first thing",
        "Units/UnitFrames.lua:DRIVER_EVENTS": "OnEvent drops units the frames do not show (ShownUnit)",
    },
    "REGEVENTS": {
        "Core/Core.lua:frame": "the addon's first frame loads before Core/Util.lua",
    },
    "EVENTFRAME": {
        "Bar/BandWatch.lua:placer": "plan 4.2: the band placer (the lane and its last word) keeps its frame and order",
        "Bar/Band.lua:hot.watch": "plan 4.2: hot.watch keeps its frame and event order",
        "Units/LastNames.lua:after": "plan 4.2: re-registered behind each new plate",
        "Units/UnitFrames.lua:driver": "plan 4.2: the unit-frame driver keeps its frame",
        "Units/UnitFrames.lua:powerKick": "plan 4.2: its own frame for the power steps",
        "Units/UnitFrames.lua:auraKick": "plan 4.2: its own frame for the aura row",
        "Spells/SpellBook.lua:follow": "plan 4.2: one of SpellBook's REGEN_ENABLED frames",
        "Spells/SpellBook.lua:waiting": "plan 4.2: one of SpellBook's REGEN_ENABLED frames",
        "Social/GuildRoster.lua:regen": "plan 4.2: Guild's regen frame",
        "Social/SocialWindow.lua:frame": "plan 4.2: Guild's settle frame, one per module where it loads",
        "Social/GuildOpeners.lua:afterFight": "plan 4.2: Guild's afterFight frame",
        "Skills/ProfessionsWindow.lua:watch": "plan 4.2: the professions watch",
        # Secure buttons (guildBind, SpellBook's bind button) are Button frames, which the rule never matches.
    },
    # By frame: Era's panel table shifts it -16, +12 (an old 384 x 512 frame whose art has a margin).
    "ERASPOT": {
        "UI/Windows.lua:CharacterFrame": "Era's character sheet, like its trainer and trade skill frames",
    },
}
# Wrapper bodies where a raw CVar call is the point: only these, only in these files.
CVAR_WRAPPERS = ("ns.SetCVar", "ns.WriteCVar", "ns.GetCVar", "ns.GetCVarBool", "ns.GetCVarDefault")
ALLOWED_BODIES = {
    "CVAR": {"Core/Settings.lua": CVAR_WRAPPERS, "Core/Util.lua": CVAR_WRAPPERS},
    "CVARREAD": {"Core/Settings.lua": CVAR_WRAPPERS, "Core/Util.lua": CVAR_WRAPPERS},
}

# Names ClassicUIForeverDev reads; never reported by DEADNS.
DEV_NAMES = frozenset((
    "walkFns", "stopped", "savedFirst", "MicroButtonList", "barMoved", "bandPasses", "stripPasses", "OnBarLaid", "OnMinimapLaid", "OnSpellBarPlaced",
    "CharacterCameraInfo", "db", "Persist", "Print", "BeginOutput", "FlushNotice", "debugSink", "debugFlushNotice",
    "missing", "mirrorLoaded", "SkinBank", "ClassicLayoutActive", "GetMainBar", "BandBarsToUnpinned", "SystemMoved",
    "DressLootRoll", "ToggleSpellBook", "CombatNumbersInfo", "ClassicBarActive", "hookFns", "MODULE_ORDER", "modules",
    "BronzeOn", "DrainBronze", "UndrainBronze", "band", "Sched", "DB_DEFAULTS", "OpenGuildRoster", "sheet",
    "ClassBandState", "PadOf", "TrainerState", "ActiveLayoutInfo", "LayoutWritable", "BandPinsWanted",
    "WindowLockButtons", "GameArtTinted", "FlatLayersShown", "FlatState", "FlatPartOf", "ThemeLayerSample",
    "ClassicMapArt", "EachThemeLayer",
))
# Shared API kept without a reader yet (plan section 5); never reported by DEADNS.
KEPT_API = frozenset((
    "SetBarColorIf", "SetAttributeIf",
))

FIX = {
    "OTHERADDON": "say what it does in plain words; never name another addon or UI in a shipped file (the settings "
                  "Support tab's own lines, SUPPORT_MORE and its links, are the one exception)",
    "LUA51": "WoW runs Lua 5.1: no statement starting with ';', no goto or labels, no // or bitwise operators "
             "(the luac 5.4 here accepts them; the game refuses the whole file)",
    "EDITSAVE": "write it with Set(key, value) (UI/WindowHandles.lua), and add a new key to DialogKeys, so Save lights "
                "and Revert puts it back",
    "LOCALE": "put the text in Locales/enUS.lua under a stable id and read it as L[\"ID\"] (local L = ns.L), then add "
              "it to every language file in Locales/; the game's own strings (_G globals like SPELLBOOK) need no entry",
    "KEYUP": "bind the key to ns.KeyProxy(name) (Core/Util.lua): it acts on press, as the game's own windows do, and "
             "clicks the button; a snippet's SetBindingClick names that proxy (name .. \"Key\")",
    "FADEDPIECE": "hide the client's cap in a hidden frame of ours (StashCap in Bar/BandArt.lua): edit mode snaps other "
                  "pieces only to what is visible, and a snap to an unnamed cap is saved at the screen's top",
    "SECRETLAYER": "test it with ns.AnySecret(layer, sub) before any compare or math, and skip that region when secret",
    "SECRETBAR": "test it with ns.IsSecret / ns.AnySecret before any compare or math, and skip the work when secret",
    "SECRETATLAS": "test it with ns.IsSecret before a method call or table key on it, and skip that region when secret",
    "NAMEDTEMPLATE": "give the frame a name of ours: retail's copy of the template anchors its pieces by $parent names",
    "ADDONFORBID": "route it through a secure pad clicking the client's own button, or leave it to the client's code",
    "PCALLMANY": "pcall a function of ours that walks them and returns one value (ns.EachChildProtected, "
                 "ns.EachRegionProtected in Core/Util.lua), never the getter itself",
    "PADLIST": "change the list's size only in a secure snippet that measures it there too (LIST_TALL / LIST_BACK in "
               "Skills/Trainer.lua, GROW in Social/GuildNoteBridge.lua); our Lua never sizes, places or measures that list",
    "POINTEXACT": "compare the offset with ns.Near(x, want, 1) (Core/Setters.lua), or place through ns.SetPointIf: the "
                  "game hands an offset back a hair off (4000 came back 4000.000244), so an exact test never passes",
    "SELFBOX": "anchor an edit mode Selection to its own frame (offsets for a wider box): the client sets the frame's "
               "clamp and snap offsets from the gap between them, so a box hung elsewhere shoves the frame off its anchor",
    "MOUSEORDER": "set OnEnter/OnLeave/OnMouse* first, then SetMouseClickEnabled(false) (the hover sensor over the "
                  "unit frame bars ate every targeting click, 2026-09-28)",
    "CHECKLABEL": "make the label on the check itself (check:CreateFontString), so it hides with it; a dialog that "
                  "hides a row must not leave its label behind for the next row to land on (skill cuif-edit-mode-items)",
    "ERASPOT": "leave a new-style window (social, professions) on the game's 16, -116, Era's spot for it too; list an "
               "old 384 x 512 frame in ALLOWED_SITES only if Era's UIPanelWindows gives it xoffset -16, yoffset 12",
    "DRAGPOINT": "read the frame's place (GetLeft/GetTop/GetBottom) before StopMovingOrSizing, which can leave a frame "
                 "others hang on with no anchor; ns.MakeDraggable (UI/Dialogs.lua) already does",
    "CVAR": "our settings through ns.SetCVar and only on a player action; the player's own value or a hand-back "
            "through ns.WriteCVar (Core/Settings.lua); never at login; " + DOC + " Taint rules",
    "CVARREAD": "use ns.GetCVar / ns.GetCVarBool (Core/Util.lua)",
    "CVARLOGIN": "write CVars only on a player action (ns.SetCVar); today's login writes are baselined and moving "
                 "them is the author's call",
    "FRAMEFIELD": "keep our state in a file-local weak table keyed by the frame, ns.Once for a once-guard, or the "
                  "frame.fcui table the Own() setters keep",
    "EVENTFRAME": "ns.EventFrame(events, onEvent, unit1, unit2) (Core/Util.lua) makes the same frame at the same "
                  "moment",
    "THROTTLEFRAME": "ns.Sched.Job{ every } shares the sleeping driver; ns.Sched.Attach(host, spec) runs only while "
                     "its window shows (Core/Scheduler.lua)",
    "SETTLE": "use S.SettleFrame(state) (Social/SocialWindow.lua) where the module loads",
    "SECRET": "use ns.IsSecret / ns.Safe / ns.AnySecret (Core/Util.lua)",
    "EDITQUERY": "use ns.InDefaultPosition / ns.EditMode.Live / ns.ActiveLayoutInfo (Core/EditMode.lua)",
    "THEME": "use ns.ThemeLook / ns.ThemeTurned / ns.KeepDrained / ns.DrainInput / ns.INPUT_GREY / ns.DrainSlice / "
             "ns.TintSlice (Art/Bronze.lua); the registries are private to Art/",
    "TIMER": "use ns.Sched.NextFrame / Soon / AfterPerFrame, or ns.Sched.Job for a repeat (Core/Scheduler.lua)",
    "SINCE": "use ns.Sched.OnFrame every= / ns.Sched.Job (Core/Scheduler.lua), or B.Due in the band lane",
    "WALK": "use ns.EachChild / ns.EachRegion with a file-level visitor (Core/Util.lua)",
    "SETIF": "use ns.SetAlphaIf / SetScaleIf / SetLevelIf / SetStrataIf / SetShownIf with the site's tolerance "
             "(Core/Setters.lua)",
    "ONCEFLAG": "use ns.Once(frame, key), ns.Sched.Attach, or a file-local weak table; never our state as a field "
                "on a client frame",
    "GAMEMENU": "use ns.CloseWithGameMenu(frame|getter, closer) (UI/Escape.lua): one hook per call, same moment",
    "HELDCVAR": "use ns.SetCVarOrHold(name, value) (Core/Settings.lua): a pick made in a fight is written as it ends; "
                "ns.SetCVar refuses in combat and the after-fight pass read the old value back (2026-10-01)",
    "OWNRELOAD": "show a game popup whose OnAccept calls ns.ReloadForLayout (ns.ReloadPopup, UI/Dialogs.lua): a press "
                 "started on our own button that saved the layout first had the game refuse its reload (2026-10-01)",
    "CVARREG": "keep our settings in ForeverClassicUIDB only: saved variables persist on Forever since beta 70009, and an "
               "addon cvar is written mid-game in our name (the old settings mirror)",
    "REGEVENTS": "use ns.RegisterEvents(frame, LIST) (Core/Util.lua) on the same frame, same order",
    "LAYOUTFIELD": "write no layout field on any frame; keep watcher children off client layout frames (hang them "
                   "under a child the client marks out of layout, e.g. EditModeManagerFrame.Border)",
    "PADART": "give a secure pad no art or text of its own: light the control under it (LockHighlight in OnEnter, "
              "UnlockHighlight in OnLeave), so a pad that outlives its window (a fight blocks its hide) draws nothing",
    "ADDONCHAR": "name the character by UnitGUID(\"player\"), as the game's AddOns list does",
    "SEARCHBOX": "use ns.SearchBox(parent, width, hint) (UI/Controls.lua): the hint while empty, the X once typed; "
                 "show box.hint and box.clear by the text in OnTextChanged",
    "SECRETMOUSE": "read it into a local first, then test `not IsSecret(over) and over` (ns.IsSecret)",
    "UNITEVENTS": "register with the units the handler serves (ns.RegisterEvents(frame, LIST, unit1, unit2)), or drop "
                  "other units first thing in the handler and list the site in ALLOWED_SITES with its reason",
    "SYSBASE": "use ns.SetPointOnce / ns.SetPointIf / ns.SetScaleIf, or ns.BaseSetters(frame) for two points "
               "(Core/Setters.lua): they take an edit mode system's base calls",
    "SHAREDART": "use ns.SearchClear / ns.RedButtonArt / ns.RED_COORDS (UI/Controls.lua), ns.ART.PAGE_PREV / "
                 "PAGE_NEXT (UI/Dress.lua) or ns.PanelToggleFace",
    "POINTONCE": "use ns.SetPointOnce(X, ...) (Core/Setters.lua); keep two-point anchors as they are",
    "PLATES": "use ns.NP.EachPlate(fn, withForbidden) (Units/NamePlates.lua)",
    "NAVFRAME": "make it with ns.NewFrame (Core/Gamepad.lua): the gamepad's CreateFrame hook re-reads an open window's "
                "controls in our name, and every later close of it is refused (ADDON_ACTION_FORBIDDEN)",
    "FORBIDDEN": "use ns.IsForbidden(object) (Core/Util.lua)",
    "DEADNS": "delete it, or add it to DEV_NAMES (ClassicUIForeverDev reads it) or KEPT_API (planned shared API) "
              "in tools/check.py",
    "UNDEFNS": "define it, or call the helper that exists (grep '^function ns.' Core/); a field set some other way "
               "goes in NS_DYNAMIC in tools/check.py",
    "REGISTRY": "use our own signal (ns.SignalSheetLaid pattern) or our own event frame (ns.RegisterEvents)",
    "HOOK": "use ns.HookMethod / ns.HookGlobal / ns.HookScriptOnce (Core/Hooks.lua), and prefer a watch (ns.Sched)",
    "ONUPDATE": "use ns.Sched.OnFrame(frame, spec) or ns.Sched.Job(spec) (Core/Scheduler.lua)",
    "LOADADDON": "never load a client addon from our code; wait for its ADDON_LOADED (ns.RegisterEvents)",
    "FRAMEWALK": "never walk the game's frames; reach the frame from what the client hands out (a manager, the mouse, "
                 "a parent's children)",
    "PANELMGR": "never drive the client window manager from our code (it then runs in our name and in combat can "
                "neither close nor place windows); open and close through ns.ShowPanel / ns.HidePanel",
    "EDITMODE": "never write layouts mid-session; writes run only as the session ends: the ns.sessionEnding jobs in "
                "Options/Layout.lua (ns.QueueLayoutJob: FitNow, ResetNow, ClassicNow, SelectNow, "
                "ns.ApplyClassicFrameSpots) and the pin writer in Bar/BandPins.lua",
    "FILESIZE": "split by responsibility into a sibling file listed in the .toc; " + DOC + " Folder map",
    "FUNCSIZE": "extract named local helpers, and reuse the shared ones in Core/ and UI/",
    "COMMENT": "comments are one-line essential whys; history and proofs belong in the commit message",
    "DUP": "move it into the shared layer (Core/, UI/Dress.lua, UI/Dialogs.lua, UI/Menus.lua ...) and call it from both places",
    "DUPFN": "keep one copy in the shared layer (Core/Util.lua, UI/...) as ns.Name, or call the twin",
    "TOC": "list every addon .lua in " + TOC_NAME + " and remove entries for files that are gone",
    "BASELINE": "run python tools/check.py --carry-renames, then git add " + BASELINE_NAME,
    "NEWSOPTIN": "a What's New entry naming an off-by-default option says to turn it on in the options, and where",
    "USSPELL": "American spelling in English text: color, gray, center(ed), armor, -ize, check/checked (not tick)",
    "LOCALEKEYS": "every language file in Locales/ holds exactly the keys of Locales/enUS.lua, each with the same %s and "
                  "%d placeholders in the same order: translate a new or changed English string into every language "
                  "before committing (skill cuif-conventions, Localization)",
}

# Names counted only where they are used (called, wrapped in pcall, passed, or assigned),
# never in existence guards like `if C_CVar and C_CVar.SetCVar then`. Run on code with strings blanked.
USE_PATTERNS = {
    "LUA51": re.compile(r"^\s*;|\bgoto\b|::\w+::|[^/]//[^/]|<const>|<close>"),
    "CVAR": re.compile(
        r"\b(?:SetCVar\w*|RegisterCVar|SetTempCVar|RemoveTempCVar|ResetTestC[Vv]ars|ConsoleExec|CreateCVarAccessor)\b"
        r"|\bSettings\s*\.\s*(?:SetValue|GetSetting)\b"),
    "CVARREAD": re.compile(r"\b(?:GetCVar|GetCVarBool|GetCVarDefault|GetCVarInfo)\b"),
    "SECRET": re.compile(r"\b(?:issecretvalue|canaccessvalue|issecrettable|canaccesstable)\b"),
    "EDITQUERY": re.compile(r"\b(?:IsInDefaultPosition|IsEditModeActive|GetActiveLayoutInfo)\b"),
    "REGISTRY": re.compile(
        r"\b(?:EventRegistry|CVarCallbackRegistry)\b(?:\s*[.:]\s*[A-Za-z_]\w*)?"
        r"|\b(?:RegisterCallback|RegisterCallbackWithHandle|UnregisterCallback|TriggerEvent)\b"),
    "LOADADDON": re.compile(r"\b(?:UIParent)?LoadAddOn\b"),
    "FRAMEWALK": re.compile(r"(?<![\w.:])EnumerateFrames\b|_G\.EnumerateFrames\b"),
    "PANELMGR": re.compile(
        r"\b(?:UpdateUIPanelPositions|FramePositionDelegate|SetUIPanelAttribute|UpdateContainerFrameAnchors)\b"),
    "EDITMODE": re.compile(
        r"\b(?:SaveLayouts|SaveLayoutChanges|SetActiveLayout|SelectLayout|OnSystemSettingChange"
        r"|UpdateSystemAnchorInfo|MakeNewLayout|DeleteLayout|RenameLayout|RevertAllChanges|SetHasActiveChanges"
        r"|OnLayoutAdded|OnLayoutDeleted|SetAccountSetting)\b"),
    "PLATES": re.compile(r"\bGetNamePlates\b"),
}
REGISTRY_METHODS = re.compile(r"(?:RegisterCallback|RegisterCallbackWithHandle|UnregisterCallback|TriggerEvent)$")
# A client object calling a registry method: Upper.chain:Method
CLIENT_METHOD_OWNER = re.compile(r"[A-Z]\w*(?:\s*\.\s*\w+)*\s*:\s*$")
HOOK_RX = re.compile(r"\bhooksecurefunc\b")
# Plain matches per line, on code with strings blanked.
LINE_PATTERNS = {
    "HOOK": HOOK_RX,
    "ERASPOT": re.compile(r"(?<!function )\bAtEraSpot\s*\(\s*([A-Za-z_][\w.]*)"),
    "SETTLE": re.compile(r"\b(?:S|social)\s*\.\s*Settle\s*\("),
    "THEME": re.compile(r"\bns\s*\.\s*(?:BronzeOn|bronze)\b|\bdb\s*\.\s*bronzeTheme\b|\b(?:DrainBronze|LMR)\b.*\b0\.85\b"
                        r"|\bEachKey\s*\(.*\bKEYS\s*\.\s*LMR\b"),
    "TIMER": re.compile(r"\bC_Timer\s*\.\s*(?:After\s*\(\s*0\s*,|New(?:Ticker|Timer)\b)|(?<![\w.])RunNextFrame\b"),
    "SINCE": re.compile(r"(?<![\w.])([A-Za-z_][\w.]*)\s*=\s*\(?\s*\1\s*(?:or\s+0\s*\)\s*)?\+\s*elapsed\b"),
    "WALK": re.compile(r"\{\s*[\w.:\[\]\"]+\s*:\s*Get(?:Children|Regions)\s*\(\s*\)\s*\}"),
    "SETIF": re.compile(r"\bif\b.*:\s*Get(Alpha|Scale|FrameLevel|FrameStrata)\s*\(\s*\).*\bthen\b.*:\s*Set\1\s*\("
                        r"|\bif\b.*:\s*IsShown\s*\(\s*\)\s*~=.*\bthen\b.*:\s*SetShown\s*\("),
    "ONCEFLAG": re.compile(r"\.\s*fcui[A-Z]\w*\s*=\s*true\b|\.\s*fcui\w*(?:Watch|Shade|Look)\s*=(?!=)"),
    "GAMEMENU": re.compile(r"\bGameMenuFrame\s*:\s*HookScript\b"),
    "CVARREG": re.compile(r"\bRegisterCVar\b"),
    "REGEVENTS": re.compile(r"\bpcall\s*\(\s*([\w.]+)\s*\.\s*Register(?:Unit)?Event\b"),
    "FRAMEFIELD": re.compile(r"\.\s*fcui[A-Z]\w*\s*=(?!=)"),
    "SECRETMOUSE": re.compile(r"(?:\bif\b|\band\b|\bor\b|\bnot\b|\breturn\b)[^\n]*:\s*IsMouseOver\s*\(\s*\)"),
    "LAYOUTFIELD": re.compile(r"\.\s*(?:ignoreInLayout|includeInLayout|layoutIndex|includeAsLayoutChildWhenHidden"
                              r"|ignoreAllChildren|expand|align|topPadding|bottomPadding|leftPadding|rightPadding)\s*=(?!=)"),
    "SYSBASE": re.compile(
        r"(?<![\w.])(?:MainActionBar|MultiBar\w+|StanceBar|PetActionBar|PossessActionBar|BagsBar|MicroMenuContainer"
        r"|\w*StatusTrackingBarContainer|PlayerCastingBarFrame|PlayerFrame|TargetFrame|FocusFrame|PetFrame|MinimapCluster"
        r"|ChatFrame\d+|LootFrame|ObjectiveTrackerFrame|BuffFrame|DebuffFrame|PartyFrame)"
        r"\s*:\s*(?:SetPoint|ClearAllPoints|SetScale|SetAllPoints)\s*\("),
    # No `not` between the halves: `f.IsForbidden and not f:IsForbidden()` is a positive test that needs the method.
    "FORBIDDEN": re.compile(r"\b([A-Za-z_][\w.]*)\s*\.\s*IsForbidden\s+and\s+\1\s*:\s*IsForbidden\s*\("),
    # A parent other than nil or UIParent: the frame may be made inside an open window.
    "NAVFRAME": re.compile(r"(?:(?<![\w.:])CreateFrame\s*\(|\bpcall\s*\(\s*CreateFrame\s*,)\s*[^,()]*,\s*[^,()]*,"
                           r"\s*(?!nil\b|UIParent\b)[A-Za-z_]"),
    # Lua's api check in the beta client: pcall pushes its true past a frame of 22+ results (lapi.c 577).
    "FADEDPIECE": re.compile(r"\b(?:FadeTextures|SetAlpha|SetAlphaIf|OverlayOnBand)\s*\(\s*[\w.]*(?:\bcap|EndCap)\b"
                             r"|(?:\bcap|EndCap)\w*\s*:\s*SetAlpha\s*\(\s*0\b"),
    "ADDONFORBID": re.compile(r"\b(?:TryRequestRecentAlliesData|BuyTrainerService|UseContainerItem|GuildSetMOTD|"
                              r"GuildRosterSetPublicNote|GuildRosterSetOfficerNote)\s*\("),
    "PCALLMANY": re.compile(r"\bpcall\s*\(\s*[\w.:\[\]\"]+\s*[.:]\s*(?:GetChildren|GetRegions|GetAnimations)\b"),
}
# SYSBASE in Bar/: bar, frame and piece there are the band's edit mode systems.
SYSBASE_BAND = re.compile(r"(?<![\w.])(?:bar|frame|piece)\s*:\s*(?:SetPoint|ClearAllPoints|SetScale|SetAllPoints)\s*\(")
# The windows edit mode: a setting written straight to ns.db skips its Save light and Revert (Set is the way).
EDITSAVE_FILES = ("UI/WindowHandles.lua", "UI/WindowsEditMode.lua")
EDITSAVE_RX = re.compile(r"\bns\s*\.\s*db\s*(?:\.\s*\w+|\[[^\]]*\])\s*=(?!=)")
# Plain matches per line, on code with strings kept (macro text, securecall names, art paths).
# Client templates whose retail XML anchors children with relativeTo="$parent...": a frame made from one needs a name.
NAMED_TEMPLATES = ("ProfessionStatusBarTemplate",)
KEEP_PATTERNS = {
    "NAMEDTEMPLATE": re.compile(r"\b(?:CreateFrame|NewFrame)\b\W+\"\w+\"\s*,\s*nil\s*,[^\n]*\"(?:%s)\""
                                % "|".join(NAMED_TEMPLATES)),
    # The game's reload from our own button's click, or called outside ns.ReloadForLayout's file.
    "OWNRELOAD": re.compile(r'SetScript\s*\(\s*"On(?:Click|MouseUp|MouseDown)"[^\n]*\bReloadForLayout\b'
                            r"|\bC_UI\s*\.\s*Reload\b|(?<![\w.:])ReloadUI\s*\("),
    "KEYUP": re.compile(r"SetOverrideBindingClick\s*\((?![^\n]*ns\.KeyProxy\()|SetBindingClick\s*\([^\n]*[\"']\w*(?<!Key)[\"']\s*\)"),
    "CVAR": re.compile(r"[\"']\s*/console\b|[\"']SetCVar\w*[\"']"),
    "PANELMGR": re.compile(r"\bSetAttribute\b[^\n]*[\"']UIPanelLayout-"),
    "SEARCHBOX": re.compile(r"[\"']InputBoxTemplate[\"']"),
    # An addon's on/off state for a character by its name: the game keys it by GUID.
    "ADDONCHAR": re.compile(r"(?:EnableAddOn|DisableAddOn|GetAddOnEnableState)\b[^\n]*\bUnit(?:Full)?Name\s*\("
                            r"|[\"']ClassicUIForever[\"']\s*,\s*Unit(?:Full)?Name\s*\("),
    # Player-facing text as a literal: a set text or tooltip line, a text/title/label/tooltip field, or one of our
    # option and dialog row builders given a label (a capital letter then lower case: words, not keys or paths).
    # A literal after `or` is the English fallback for the game's own translated global (CLOSE or "Close").
    "LOCALE": re.compile(r":\s*(?:SetText|SetFormattedText|AddLine|AddDoubleLine|SetLabel)\s*\(\s*\"[A-Z][a-z]"
                         r"|\b(?:text|title|label|tooltip)\s*=\s*\"[A-Z][a-z]"
                         r"|\b(?:Stepper|ExtraStep|ExtraDrop|ValueDropRow|ColorRow|PanelButton|BagsCheck|DropShell)\s*\("
                         r"(?:[^\n\"]|\"[^\"]*\")*?(?<!or )\"[A-Z][a-z]"),
}
# Shared art literals, each with the files that own it (strings kept).
SHARED_ART = (
    (re.compile(r"ClearBroadcastIcon|\{\s*0\s*,\s*0\.625\s*,\s*0\s*,\s*0\.6875\s*\}"), ("UI/Controls.lua",)),
    # Art/ holds the texture keys and the bronze file map.
    (re.compile(r"UI-SpellbookIcon-(?:Prev|Next)Page", re.I), ("UI/Dress.lua", "Art/")),
)
# Structural detectors over code lines.
POINT_CLEAR = re.compile(r"^\s*([A-Za-z_][\w.]*(?:\[[^\]]*\])*)\s*:\s*ClearAllPoints\s*\(\s*\)\s*;?\s*$")
SIZE_METHODS = ("SetSize", "SetWidth", "SetHeight")
REGISTER_LINE = re.compile(r"^\s*([\w.]+)\s*:\s*RegisterEvent\s*\(")
REGISTER_RUN = 3
TARGET = r"[A-Za-z_][\w.]*(?:\[[^\]]*\])*"
# SETIF over two lines: `if X:GetScale() ~= v then`, then `X:SetScale(v)`.
SETIF_OPEN = re.compile(r"^\s*(?:else)?if\b.*\bthen\s*$")
SETIF_GET = re.compile(r"(?<![\w.\]])(" + TARGET + r")\s*:\s*(Get(?:Alpha|Scale|FrameLevel|FrameStrata)|IsShown)\s*\(\s*\)"
                       r"(\s*~=)?")
# ONCEFLAG guards: `if X.fcuiK then return end` or `if not X.fcuiK then`, then a write to X.fcuiK.
ONCE_GUARD = re.compile(r"\bif\s+(not\s+)?([A-Za-z_][\w.]*)\s*\.\s*(fcui\w+)\s+then\b(.*)$")
ONCE_RETURN = re.compile(r"^\s*return\s+end\b")
# EVENTFRAME: a plain frame (no name, parent or template), strings kept.
EVENT_FRAME = re.compile(r"^\s*(?:local\s+)?([A-Za-z_][\w.]*)\s*=\s*CreateFrame\s*\(\s*[\"']Frame[\"']\s*(?:,\s*nil\s*)?\)")
EVENT_FRAME_SPAN = 3
# CVARLOGIN: login event branches and the write calls counted inside them.
LOGIN_EVENTS = ('"ADDON_LOADED"', '"PLAYER_LOGIN"', '"PLAYER_ENTERING_WORLD"',
                "'ADDON_LOADED'", "'PLAYER_LOGIN'", "'PLAYER_ENTERING_WORLD'")
EVENT_TEST = re.compile(r"[A-Za-z_]\w*\s*==\s*\"\"|\"\"\s*==\s*[A-Za-z_]\w*")
NS_WRITE = re.compile(r"\bns\s*\.\s*(?:SetCVar|WriteCVar|MirrorSave)\b")
MODULE_CALL = re.compile(r"\bns\s*\.\s*RegisterModule\s*\(")
FUNCTION_DEF = re.compile(r"\bfunction\s+[\w.:]+\s*\(")
MODULE_KEY = re.compile(r"\b(apply|init)\s*=\s*(function\b|[A-Za-z_][\w.]*)")
# THROTTLEFRAME: OnFrame calls, found on the whole blanked text.
ONFRAME_CALL = re.compile(r"\bSched\s*\.\s*OnFrame\s*\(")
NUMBER_LOCAL = re.compile(r"^\s*local\s+([A-Za-z_]\w*)\s*=\s*([0-9.]+)\s*$")
# DEADNS: ns fields defined but never read.
NS_DEF = re.compile(r"^\s*function\s+ns\s*\.\s*(\w+)\s*\(|^\s*ns\s*\.\s*(\w+)\s*=(?!=)")
NS_REF = re.compile(r"\bns\s*\.\s*(\w+)")
# Runs over the whole file (strings kept, comments removed) so the arguments may sit on the next line.
ONUPDATE_RX = r":\s*(?:SetScript|HookScript)\s*\(\s*(?:\"OnUpdate\"|'OnUpdate'|\[(=*)\[OnUpdate\]\1\]%s)"
ONUPDATE_VAR = re.compile(r"\b([A-Za-z_]\w*)\s*=\s*(?:\"OnUpdate\"|'OnUpdate')")

QUALIFIER = re.compile(r"([A-Za-z_]\w*)\s*[.:]\s*$")
WRAPPED_CALL = re.compile(r"\b(?:x?pcall|securecall\w*)\s*\(\s*$")
ASSIGNED = re.compile(r"(?<![=~<>])=\s*(?:[\w.:\s]+?\b(?:and|or)\s+)?$")
CALL_OPEN = re.compile(r"([A-Za-z_]\w*|[\])])\s*\(\s*$")
NOT_A_CALL = {"and", "or", "not", "if", "elseif", "while", "until", "return", "in", "then", "do", "local",
              "type", "assert"}

MESSAGES = {
    "OTHERADDON": "another addon or UI named in a shipped file (the repo is public and players read it)",
    "LUA51": "syntax WoW's Lua 5.1 refuses (the file would not load at all)",
    "EDITSAVE": "a setting written straight to ns.db in the windows edit mode (Save never lights, Revert misses it)",
    "LOCALE": "text the player reads written as a literal (never translated)",
    "KEYUP": "a key bound straight to a release-acting button (it opens on release; the game's windows on press)",
    "CHECKLABEL": "a check's label made on another frame (it stays when the check hides; rows then overlap)",
    "MOUSEORDER": "a mouse script set after the frame's clicks were switched off (setting it turns clicks back on)",
    "POINTEXACT": "an offset read from GetPoint compared exactly with a number, constant or saved value (the test failed every "
                  "frame, and the hidden guild window was anchored again each one: 5 % CPU with the roster open)",
    "SELFBOX": "an edit mode Selection anchored to another frame than its own (the bars launched to the screen top)",
    "PADLIST": "a pad-clicked client list sized, placed or measured in our Lua (rows it rebuilds in our name are "
               "refused by Train's pad and fail a guild note save)",
    "FADEDPIECE": "a client end cap faded or laid on the band as a handle (bars snapped to it, saved at the screen top)",
    "PCALLMANY": "a pcall straight around GetChildren/GetRegions/GetAnimations: 22 or more results abort the beta client",
    "ADDONFORBID": "a call the game forbids to addons (ADDON_ACTION_FORBIDDEN, out of combat too)",
    "NAMEDTEMPLATE": "a nameless frame from a client template that anchors by $parent names on retail (the profession "
                     "bars' backs ran from one bar to another: a black box over the book)",
    "SECRETLAYER": "a draw layer read with no secret test beside it (a nameplate's pieces answer secret: 0.16.1, 1381 errors)",
    "SECRETBAR": "a client bar's value read in Units/ with no secret test beside it (the swing bar answered secret: 351 errors)",
    "SECRETATLAS": "an atlas read used as a table key or with a method on it, no secret test beside it (the nameplate "
                   "preview's spark answered secret: #139, 779 errors)",
    "ERASPOT": "Era's old-frame shift on a window Era leaves on 16, -116 (the social window flush on the screen edge)",
    "DRAGPOINT": "anchor read after StopMovingOrSizing (it can be gone: the saved place came out empty)",
    "CVAR": "CVar write or console command outside the ns.SetCVar / ns.WriteCVar wrappers",
    "CVARREAD": "raw CVar read outside the ns.GetCVar / ns.GetCVarBool wrappers",
    "CVARLOGIN": "CVar write in a module apply/init body or a login event branch",
    "FRAMEFIELD": "our state written as an fcui field on a frame",
    "EVENTFRAME": "event frame made by hand: use ns.EventFrame at the same site",
    "THROTTLEFRAME": "a throttled body on a per-frame host: use ns.Sched.Job or ns.Sched.Attach, or give the "
                     "frame-order reason on the call line",
    "SETTLE": "social settle frame made by hand",
    "REGISTRY": "call on a client callback registry",
    "HOOK": "hooksecurefunc outside Core/Hooks.lua",
    "ONUPDATE": "OnUpdate script outside Core/Scheduler.lua",
    "SINCE": "hand-written elapsed accumulator",
    "TIMER": "C_Timer.After(0, ...), NewTicker, NewTimer or RunNextFrame outside Core/Scheduler.lua",
    "LOADADDON": "client addon loaded from our code",
    "FRAMEWALK": "EnumerateFrames: a walk over every frame in the game (70 ms a frame on retail)",
    "PANELMGR": "client window manager driven from our code",
    "EDITMODE": "edit mode layout write",
    "EDITQUERY": "raw edit mode query outside Core/EditMode.lua",
    "SECRET": "raw secret-value test outside Core/Util.lua",
    "WALK": "child or region walk that builds a table",
    "REGEVENTS": "events registered by hand",
    "POINTONCE": "ClearAllPoints and one SetPoint by hand",
    "SETIF": "compare before set by hand",
    "THEME": "theme branch or input grey by hand outside Art/",
    "ONCEFLAG": "our state as a field on a frame",
    "GAMEMENU": "GameMenuFrame hooked outside ns.CloseWithGameMenu",
    "OWNRELOAD": "the game's reload from our own button's click (or called directly outside ns.ReloadForLayout)",
    "HELDCVAR": "ns.SetCVar in code a toggle runs at once, in a fight too (KeyEffects, an ns.OnToggle handler)",
    "CVARREG": "an addon-registered cvar (a settings copy outside saved variables)",
    "LAYOUTFIELD": "a field client layout code reads, written from our code (its layout pass then runs in our name)",
    "PADART": "a secure pad on UIParent with art or text of its own (a ghost bar where it outlives its window)",
    "SEARCHBOX": "an input box built by hand (the Legacy challenges' search came out with no X to clear it)",
    "ADDONCHAR": "an addon turned on, off or read for a character by name (Forever's UnitName is the first name "
                 "alone: /fcui off turned off nothing)",
    "SECRETMOUSE": "a unit frame bar's IsMouseOver() tested directly (it can answer a secret in a fight or an instance)",
    "UNITEVENTS": "UNIT_ events registered for every unit (each nameplate and group member's copy runs the handler)",
    "SYSBASE": "anchor or scale of a bar or edit mode system through the client's wrapper (its snap note taints the next drag)",
    "SHAREDART": "shared control art copied (clear icon, red button coords or page arrow paths)",
    "PLATES": "nameplate loop by hand outside Units/NamePlates.lua",
    "NAVFRAME": "a frame made with a parent in window code by raw CreateFrame",
    "FORBIDDEN": "ns.IsForbidden written out by hand",
}

LONG_OPEN = re.compile(r"\[(=*)\[")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
SPACES = re.compile(r"\s+")
# A line counts toward a DUP window only if it does something: a call, field or method access,
# or a statement keyword. Data rows ({ "key", "text" },) and closers never make a duplicate.
REAL = re.compile(r"[A-Za-z_]\w*\s*[.(:]|\b(?:local|if|for|while|return\s+\w|elseif|until|function)\b")
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


class UsageError(Exception):
    pass


# ----------------------------------------------------------------- repo and git

def find_root():
    here = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.isfile(os.path.join(here, TOC_NAME)):
            return here
        parent = os.path.dirname(here)
        if parent == here:
            raise UsageError("cannot find " + TOC_NAME + " above " + __file__)
        here = parent


def git(root, args, data=None):
    proc = subprocess.run(["git"] + args, cwd=root, input=data, capture_output=True)
    if proc.returncode != 0:
        raise UsageError("git " + " ".join(args) + " failed: " + proc.stderr.decode("utf-8", "replace").strip())
    return proc.stdout


def in_scope(path):
    return path.endswith(".lua") and not path.startswith(EXCLUDED_DIRS)


def tracked_files(root):
    try:
        raw = git(root, ["ls-files", "-z"])
        return [p.decode("utf-8") for p in raw.split(b"\0") if p], True
    except (UsageError, OSError):
        found = []
        for base, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in files:
                found.append(os.path.relpath(os.path.join(base, name), root).replace(os.sep, "/"))
        return found, False


def read_disk(root, rel):
    with open(os.path.join(root, rel), "rb") as handle:
        return handle.read().decode("utf-8-sig", "replace")


def read_index(root, paths):
    """Staged content of paths, one git process."""
    raw = git(root, ["ls-files", "-s", "-z", "--"] + paths)
    shas, order = {}, []
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        meta, path = entry.split(b"\t", 1)
        parts = meta.split()
        if parts[2] != b"0":
            continue
        shas[path.decode("utf-8")] = parts[1].decode()
        order.append(path.decode("utf-8"))
    if not order:
        return {}
    out = git(root, ["cat-file", "--batch"], data=("\n".join(shas[p] for p in order) + "\n").encode())
    result, pos = {}, 0
    for path in order:
        nl = out.index(b"\n", pos)
        header = out[pos:nl].split()
        size = int(header[2])
        body = out[nl + 1:nl + 1 + size]
        pos = nl + 1 + size + 1
        text = body.decode("utf-8", "replace")
        if text.startswith(chr(0xFEFF)):
            text = text[1:]
        result[path] = text
    return result


# ------------------------------------------------------------------------ lexer

class Lexed:
    __slots__ = ("keep", "blank", "has_comment", "comment_len", "nlines", "strs")


def lex(text):
    """Per line: code with strings kept, code with strings blanked, comment facts, the line's string literals."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    keep, blank, has_c, clen, strs = [[]], [[]], [False], [0], [[]]

    def newline():
        keep.append([])
        blank.append([])
        has_c.append(False)
        clen.append(0)
        strs.append([])

    def spread(seg, is_comment, blank_token):
        if blank_token:
            strs[-1].append(seg)
        parts = seg.split("\n")
        for idx, part in enumerate(parts):
            if idx:
                newline()
            if is_comment:
                has_c[-1] = True
                if len(part) > clen[-1]:
                    clen[-1] = len(part)
            else:
                keep[-1].append(part)
                if idx == 0:
                    blank[-1].append(blank_token)

    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "\n":
            newline()
            i += 1
        elif c == "-" and text.startswith("--", i):
            m = LONG_OPEN.match(text, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                k = text.find(close, m.end())
                end = n if k < 0 else k + len(close)
            else:
                k = text.find("\n", i)
                end = n if k < 0 else k
            spread(text[i:end], True, None)
            i = end
        elif c == '"' or c == "'":
            j = i + 1
            while j < n:
                d = text[j]
                if d == "\\":
                    j += 2
                    continue
                if d == c or d == "\n":
                    break
                j += 1
            end = j + 1 if j < n and text[j] == c else min(j, n)
            spread(text[i:end], False, '""')
            i = end
        elif c == "[" and LONG_OPEN.match(text, i):
            m = LONG_OPEN.match(text, i)
            close = "]" + m.group(1) + "]"
            k = text.find(close, m.end())
            end = n if k < 0 else k + len(close)
            spread(text[i:end], False, '""')
            i = end
        else:
            j = i
            while j < n and text[j] not in "\n-\"'[":
                j += 1
            if j == i:
                j = i + 1
            chunk = text[i:j]
            keep[-1].append(chunk)
            blank[-1].append(chunk)
            i = j
    lx = Lexed()
    lx.keep = ["".join(p) for p in keep]
    lx.blank = ["".join(p) for p in blank]
    lx.has_comment = has_c
    lx.comment_len = clen
    lx.strs = strs
    nlines = len(lx.keep)
    if nlines and text.endswith("\n"):
        nlines -= 1
    lx.nlines = nlines
    return lx


# ------------------------------------------------------------------------ rules

def qualified_start(line, pos):
    """Start of the dotted chain ending at pos (C_CVar. in C_CVar.SetCVar)."""
    while True:
        m = QUALIFIER.search(line[:pos])
        if not m:
            return pos
        pos = m.start(1)


def is_use(line, start, end):
    """True when the reference is called, wrapped, passed or assigned, false in a guard or a definition."""
    before, after = line[:start], line[end:]
    if re.search(r"\bfunction\s*$", before):
        return False
    if re.match(r"\s*[(\"{]", after):
        return True
    if WRAPPED_CALL.search(before):
        return True
    if not re.match(r"\s*(?:$|[;,)}\]])", after):
        return False
    if ASSIGNED.search(before):
        return True
    m = CALL_OPEN.search(before)
    if m and m.group(1) not in NOT_A_CALL:
        return True
    return before.rstrip().endswith(",")


def onupdate_lines(lx):
    text = "\n".join(lx.keep)
    names = sorted(set(ONUPDATE_VAR.findall(text)))
    extra = "|(?:%s)\\b\\s*," % "|".join(re.escape(n) for n in names) if names else ""
    starts, pos = [], 0
    for line in lx.keep:
        starts.append(pos)
        pos += len(line) + 1
    return {bisect.bisect_right(starts, m.start()) for m in re.finditer(ONUPDATE_RX % extra, text)}


def allowed(rule, path):
    for entry in ALLOWED.get(rule, ()):
        if path == entry or (entry.endswith("/") and path.startswith(entry)):
            return True
    return False


def site_allowed(rule, path, var):
    return (path + ":" + var) in ALLOWED_SITES.get(rule, {})


def body_lines(funcs, names):
    """Lines inside the bodies of the named functions of this file."""
    lines = set()
    for start, end, name, _ in funcs:
        if name in names:
            lines.update(range(start, end + 1))
    return lines


def own_lines(funcs, start, end):
    """Lines start..end minus the bodies of functions opened on a later line inside them (callbacks run later)."""
    lines = set(range(start, end + 1))
    for s, e, _, _ in funcs:
        if start < s and e <= end:
            lines.difference_update(range(s, e + 1))
    return lines


def method_call(line, target, methods, whole):
    """line is target:Method( for one of methods; with whole, its balanced parentheses also end the line."""
    m = re.match(r"\s*" + re.escape(target) + r"\s*:\s*(?:" + "|".join(methods) + r")\s*\(", line)
    if not m or not whole:
        return bool(m)
    depth = 0
    for k in range(m.end() - 1, len(line)):
        if line[k] == "(":
            depth += 1
        elif line[k] == ")":
            depth -= 1
            if depth == 0:
                return re.fullmatch(r"\s*;?\s*", line[k + 1:]) is not None
    return False


def point_once_hits(code):
    """A clear, at most one size line on the same target, then exactly one SetPoint."""
    found = set()
    for i, (no, line) in enumerate(code):
        m = POINT_CLEAR.match(line)
        if not m:
            continue
        target, j = m.group(1), i + 1
        if j < len(code) and method_call(code[j][1], target, SIZE_METHODS, True):
            j += 1
        if j >= len(code) or not method_call(code[j][1], target, ("SetPoint",), True):
            continue
        k = j + 1
        if k < len(code) and method_call(code[k][1], target, SIZE_METHODS, True):
            k += 1
        if k < len(code) and method_call(code[k][1], target, ("SetPoint",), False):
            continue
        found.add(("POINTONCE", no))
    return found


def setif_two_line_hits(code):
    """`if X:GetProp() ~= ... then` ending its line, then X:SetProp( on the next code line."""
    found = set()
    for i, (no, line) in enumerate(code[:-1]):
        if not SETIF_OPEN.match(line):
            continue
        after = code[i + 1][1]
        for m in SETIF_GET.finditer(line):
            getter = m.group(2)
            if not m.group(3):
                continue
            setter = "SetShown" if getter == "IsShown" else "S" + getter[1:]
            if method_call(after, m.group(1), (setter,), False):
                found.add(("SETIF", no))
                break
    return found


def once_guard_hits(code):
    """Once-guards on an fcui field: the write after `if X.K then return end` or inside `if not X.K then`."""
    found = set()
    for i, (no, line) in enumerate(code):
        m = ONCE_GUARD.search(line)
        if not m:
            continue
        negated, owner, key, rest = m.group(1), m.group(2), m.group(3), m.group(4)
        if not negated and not ONCE_RETURN.match(rest):
            continue
        write = re.compile(r"(?<![\w.])" + re.escape(owner) + r"\s*\.\s*" + re.escape(key)
                           + r"\s*=(?!=)\s*(?!nil\b|false\b)\S")
        if negated and write.search(rest):
            found.add(("ONCEFLAG", no))
        elif i + 1 < len(code) and write.match(code[i + 1][1].lstrip()):
            found.add(("ONCEFLAG", code[i + 1][0]))
    return found


def event_frame_hits(path, lx):
    """A plain CreateFrame('Frame') given RegisterEvent(s) and an OnEvent script within a few code lines."""
    found = set()
    code = [(no, line) for no, line in enumerate(lx.keep, 1) if line.strip()]
    for i, (no, line) in enumerate(code):
        m = EVENT_FRAME.match(line)
        if not m or site_allowed("EVENTFRAME", path, m.group(1)):
            continue
        var = re.escape(m.group(1))
        near = "\n".join(text for _, text in code[i:i + EVENT_FRAME_SPAN + 1])
        registers = re.search(r"(?<![\w.])" + var + r"\s*:\s*Register(?:Unit)?Event\s*\(|\bRegisterEvents\s*\(\s*"
                              + var + r"\s*[,)]|\bpcall\s*\(\s*" + var + r"\s*\.\s*Register(?:Unit)?Event\b", near)
        scripted = re.search(r"(?<![\w.])" + var + r"\s*:\s*SetScript\s*\(\s*[\"']OnEvent[\"']", near)
        if registers and scripted:
            found.add(("EVENTFRAME", no))
    return found


# UNIT_ events with no unit filter: every nameplate and group member's copy runs the handler.
UNIT_CALL = re.compile(r"(?:\bRegisterEvents|\bEventFrame|:\s*RegisterEvent|\bpcall)\s*\(")
UNIT_NAME = re.compile(r"[\"'](UNIT_\w+)[\"']")


def call_args(text, start):
    """Top-level argument texts of the call whose '(' is at start; None when it does not close."""
    args, depth, quote, i, arg = [], 0, None, start + 1, start + 1
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                args.append(text[arg:i].strip())
                return args
            depth -= 1
        elif c == "," and depth == 0:
            args.append(text[arg:i].strip())
            arg = i + 1
        i += 1
    return None


def unit_event_hits(path, lx):
    """Registrations of UNIT_ events with no unit filter, unless the list (or first event) is allowed as a site."""
    found = set()
    text = "\n".join(lx.keep)
    lists = {m.group(1): m.group(2) for m in re.finditer(r"\blocal\s+(\w+)\s*=\s*(\{[^{}]*\})", text)}
    for m in UNIT_CALL.finditer(text):
        args = call_args(text, m.end() - 1)
        if not args:
            continue
        kind = m.group(0)
        if "RegisterEvents" in kind:
            events = args[1] if len(args) == 2 else None
        elif "EventFrame" in kind:
            events = args[0] if len(args) == 2 else None
        elif "pcall" in kind:
            events = args[2] if len(args) == 3 and re.search(r"\.\s*RegisterEvent$", args[0]) else None
        else:
            events = args[0] if len(args) == 1 else None
        if not events:
            continue
        body = lists.get(events, events)
        unit = UNIT_NAME.search(body)
        if unit and not site_allowed("UNITEVENTS", path, events if events in lists else unit.group(1)):
            found.add(("UNITEVENTS", text.count("\n", 0, m.start()) + 1))
    return found


# Secure frames hung from UIParent: nothing hides them with the window they serve.
SECURE_FRAME = re.compile(r"(?:local\s+)?([\w.]+)\s*=\s*CreateFrame\s*\([^,]*,[^,]*,\s*UIParent\s*,\s*[\"']Secure\w*Template[\"']")
PAD_ART_METHODS = (r"CreateTexture|CreateFontString|SetNormalTexture|SetHighlightTexture|SetPushedTexture"
                   r"|SetCheckedTexture|SetDisabledTexture|SetNormalAtlas|SetHighlightAtlas|SetPushedAtlas|SetBackdrop")


def pad_art_hits(lx):
    """A secure frame given art or text of its own: drawn wherever it outlives its window."""
    found = set()
    names = {m.group(1) for line in lx.keep for m in [SECURE_FRAME.search(line)] if m}
    if not names:
        return found
    rx = re.compile(r"(?<![\w.])(?:" + "|".join(re.escape(n) for n in sorted(names)) + r")\s*:\s*(?:"
                    + PAD_ART_METHODS + r")\s*\(")
    for no, line in enumerate(lx.blank, 1):
        if rx.search(line):
            found.add(("PADART", no))
    return found


def structure_hits(path, lx):
    """Rules that read neighbouring code lines (strings blanked)."""
    found = set()
    code = [(no, line) for no, line in enumerate(lx.blank, 1) if line.strip()]
    if not allowed("POINTONCE", path):
        found |= point_once_hits(code)
    if not allowed("SETIF", path):
        found |= setif_two_line_hits(code)
    if not allowed("ONCEFLAG", path):
        found |= once_guard_hits(code)
    if not allowed("EVENTFRAME", path):
        found |= event_frame_hits(path, lx)
    if not allowed("PADART", path):
        found |= pad_art_hits(lx)
    if not allowed("UNITEVENTS", path):
        found |= unit_event_hits(path, lx)
    if not allowed("REGEVENTS", path):
        receiver, run = None, 0
        for no, line in code:
            m = REGISTER_LINE.match(line)
            if m and m.group(1) == receiver:
                run += 1
            else:
                receiver, run = (m.group(1), 1) if m else (None, 0)
            if run == REGISTER_RUN and not site_allowed("REGEVENTS", path, receiver):
                found.add(("REGEVENTS", no))
    return found


def raw_cvar_lines(lx):
    """Lines using a raw CVar write, as the CVAR rule counts them, before any allowance."""
    lines = set()
    rx = USE_PATTERNS["CVAR"]
    for no, line in enumerate(lx.blank, 1):
        for m in rx.finditer(line):
            qs = qualified_start(line, m.start())
            if not re.match(r"ns\s*[.:]", line[qs:m.start()]) and is_use(line, qs, m.end()):
                lines.add(no)
                break
    for no, line in enumerate(lx.keep, 1):
        if KEEP_PATTERNS["CVAR"].search(line):
            lines.add(no)
    return lines


def login_branches(lx):
    """(first, last) line of each if/elseif branch testing the event against a login event."""
    spans, stack = [], []
    for no, line in enumerate(lx.blank, 1):
        strs = lx.strs[no - 1] if no - 1 < len(lx.strs) else []
        for m in IDENT.finditer(line):
            word = m.group(0)
            if word in ("if", "elseif"):
                if word == "elseif":
                    if not stack or stack[-1][0] != "if":
                        continue
                    _, opened = stack.pop()
                    if opened:
                        spans.append((opened, max(opened, no - 1)))
                cond = line[m.end():]
                cut = re.search(r"\bthen\b", cond)
                cond = cond[:cut.start()] if cut else cond
                before = line[:m.end()].count('""')
                login = False
                for t in EVENT_TEST.finditer(cond):
                    index = before + cond[:t.start() + t.group(0).index('""')].count('""')
                    if index < len(strs) and strs[index] in LOGIN_EVENTS:
                        login = True
                stack.append(("if", no if login else 0))
            elif word == "else" and stack and stack[-1][0] == "if":
                _, opened = stack.pop()
                if opened:
                    spans.append((opened, max(opened, no - 1)))
                stack.append(("if", 0))
            elif word in ("function", "do", "repeat"):
                stack.append((word, 0))
            elif word in ("end", "until") and stack:
                kind, opened = stack.pop()
                if kind == "if" and opened:
                    spans.append((opened, no))
    return spans


def module_bodies(lx, funcs):
    """(start, end) of each module apply and init function registered in this file."""
    text = "\n".join(lx.blank)
    starts, pos = [], 0
    for line in lx.blank:
        starts.append(pos)
        pos += len(line) + 1
    by_name = {}
    for start, end, name, _ in funcs:
        by_name.setdefault(name, []).append((start, end))
    bodies = []
    for call in MODULE_CALL.finditer(text):
        close = balanced_close(text, call.end() - 1)
        spec = text[call.end():close]
        for m in MODULE_KEY.finditer(spec):
            at = bisect.bisect_right(starts, call.end() + m.start())
            if m.group(2) == "function":
                bodies.extend((s, e) for s, e, n, _ in funcs if s == at and n == m.group(1))
            else:
                places = by_name.get(m.group(2), [])
                before = [p for p in places if p[0] <= at]
                if before or places:
                    bodies.append(before[-1] if before else places[0])
    return bodies


def balanced_close(text, open_at):
    """Index of the bracket closing the one at open_at, or the end of text."""
    pairs = {"(": ")", "{": "}", "[": "]"}
    depth, closer = 0, pairs[text[open_at]]
    for k in range(open_at, len(text)):
        c = text[k]
        if c == text[open_at]:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                return k
    return len(text)


def cvar_login_hits(lx, funcs):
    """Writes (ns.SetCVar, ns.WriteCVar, ns.MirrorSave, raw) run from a module apply/init body or a login branch,
    directly or through a function of the same file."""
    direct = raw_cvar_lines(lx)
    for no, line in enumerate(lx.blank, 1):
        if NS_WRITE.search(line):
            direct.add(no)
    # A definition line is not a call of the function it defines.
    text = [FUNCTION_DEF.sub("function(", line) for line in lx.blank]
    own = [(n, own_lines(funcs, s, e)) for s, e, n, _ in funcs if n != "(anonymous)"]
    writers, calls, grew = set(), None, True
    while grew:
        grew = False
        for name, lines in own:
            if name not in writers and any(no in direct or (calls and calls.search(text[no - 1])) for no in lines):
                writers.add(name)
                grew = True
        calls = call_pattern(writers)
    region = set()
    for s, e in login_branches(lx) + module_bodies(lx, funcs):
        region |= own_lines(funcs, s, e)
    return {("CVARLOGIN", no) for no in region if no in direct or (calls and calls.search(text[no - 1]))}


def call_pattern(names):
    """One regex for a call of any of names (dotted or method), bare or through pcall / SafeCall; None if no names."""
    if not names:
        return None
    alts = []
    for name in sorted(names):
        parts = [re.escape(p) for p in re.split(r"[.:]", name)]
        alts.append(r"(?<![\w.:])" + r"\s*[.:]\s*".join(parts) + r"\s*\(")
        alts.append(r"\b(?:x?pcall|SafeCall)\s*\(\s*" + r"\s*[.:]\s*".join(parts) + r"\s*[,)]")
    return re.compile("|".join(alts))


def throttle_frame_hits(lx):
    """ns.Sched.OnFrame with a finite every > 0 and no pre, unless the call line gives its reason in a comment."""
    text = "\n".join(lx.blank)
    starts, pos = [], 0
    for line in lx.blank:
        starts.append(pos)
        pos += len(line) + 1
    numbers = {}
    for line in lx.blank:
        m = NUMBER_LOCAL.match(line)
        if m:
            numbers[m.group(1)] = m.group(2)
    found = set()
    for call in ONFRAME_CALL.finditer(text):
        no = bisect.bisect_right(starts, call.start())
        if lx.has_comment[no - 1]:
            continue
        args = text[call.end():balanced_close(text, call.end() - 1)]
        brace = args.find("{")
        if brace < 0:
            continue
        spec = args[brace + 1:balanced_close(args, brace)]
        top, depth = [], 0
        for c in spec:
            if c in "({[":
                depth += 1
            elif c in ")}]":
                depth -= 1
            top.append(c if depth == 0 else " ")
        top = "".join(top)
        if re.search(r"\bpre\s*=", top):
            continue
        every = re.search(r"\bevery\s*=\s*([^,]+)", top)
        value = every.group(1).strip() if every else "0"
        value = numbers.get(value, value)
        # Kick-only jobs doze off the frame loop between kicks (Core/Scheduler.lua).
        if value == "math.huge":
            continue
        try:
            positive = float(value) > 0
        except ValueError:
            positive = True
        if positive:
            found.add(("THROTTLEFRAME", no))
    return found


CHECK_MADE = re.compile(r"\b(\w+)\s*=\s*(?:CreateFrame|ns\.NewFrame)\(\s*\"CheckButton\"")
LABEL_MADE = re.compile(r"\blocal\s+(\w+)\s*=\s*([\w.]+):CreateFontString\(")
LABEL_BESIDE = re.compile(r"(?<![.\w])(\w+):SetPoint\(\s*\"LEFT\"\s*,\s*([\w.]+)\s*,\s*\"RIGHT\"")


def check_label_hits(lx):
    """A font string set beside a check button (LEFT to its RIGHT) but made on another frame."""
    found = set()
    checks, labels = set(), {}
    for no, line in enumerate(lx.keep, 1):
        for m in CHECK_MADE.finditer(line):
            checks.add(m.group(1))
        for m in LABEL_MADE.finditer(line):
            labels[m.group(1)] = (m.group(2), no)
        for m in LABEL_BESIDE.finditer(line):
            label, beside = m.group(1), m.group(2)
            made = labels.get(label)
            if made and beside in checks and made[0] != beside:
                found.add(("CHECKLABEL", made[1]))
    return found


CLICKS_OFF = re.compile(r"(?:\b(\w+):SetMouseClickEnabled\(\s*false|pcall\(\s*(\w+)\.SetMouseClickEnabled\s*,\s*\w+\s*,\s*false)")
# A nil handler clears a script and turns nothing on.
MOUSE_SCRIPT = re.compile(r"\b(\w+):(?:SetScript|HookScript)\(\s*\"(?:OnEnter|OnLeave|OnMouseDown|OnMouseUp|OnMouseWheel)\"\s*,(?!\s*nil\b)")


# A local holding a frame's Selection, and a SetPoint/SetAllPoints on one.
SELECTION_LOCAL = re.compile(r"\blocal\s+(\w+)\s*=\s*(?:[\w.]+\s+and\s+)?([\w.]+)\.Selection\b")
SELECTION_ANCHOR = re.compile(r"([\w.]+)\s*:\s*(SetPoint|SetAllPoints)\s*\(([^)]*)")


SECRET_LAYER_READ = re.compile(r":\s*GetDrawLayer\s*\(")
SECRET_TEST = re.compile(r"(?:IsSecret|AnySecret)")


def secret_layer_hits(lx):
    """A GetDrawLayer read with no IsSecret/AnySecret on its line or the next two."""
    found = set()
    lines = lx.blank
    for i, line in enumerate(lines):
        if SECRET_LAYER_READ.search(line) and not SECRET_TEST.search(" ".join(lines[i:i + 3])):
            found.add(("SECRETLAYER", i + 1))
    return found


SECRET_ATLAS_LOCAL = re.compile(r"\blocal\s+(\w+)\s*=.*:\s*GetAtlas\s*\(")
SECRET_ATLAS_INLINE = re.compile(r":\s*GetAtlas\s*\(\s*\)\s*:|\[[^\]]*:\s*GetAtlas\s*\(")


def secret_atlas_hits(lx):
    """An atlas read whose result takes a method call or is a table key, with no IsSecret/AnySecret on its line or the
    next two."""
    found = set()
    lines = lx.blank
    for i, line in enumerate(lines):
        near = " ".join(lines[i:i + 3])
        if SECRET_TEST.search(near):
            continue
        local = SECRET_ATLAS_LOCAL.search(line)
        if local:
            name = re.escape(local.group(1))
            if re.search(r"\b" + name + r"\s*:\s*\w+\s*\(|\[\s*" + name + r"\b", near):
                found.add(("SECRETATLAS", i + 1))
        elif SECRET_ATLAS_INLINE.search(line):
            found.add(("SECRETATLAS", i + 1))
    return found


SECRET_BAR_READ = re.compile(r":\s*(?:GetValue|GetMinMaxValues)\s*\(")


def secret_bar_hits(path, lx):
    """In Units/, a status bar's GetValue or GetMinMaxValues with no IsSecret/AnySecret on its line or the next two."""
    found = set()
    if not path.startswith("Units/"):
        return found
    lines = lx.blank
    for i, line in enumerate(lines):
        if SECRET_BAR_READ.search(line) and not SECRET_TEST.search(" ".join(lines[i:i + 3])):
            found.add(("SECRETBAR", i + 1))
    return found


def self_box_hits(lx):
    """A client Selection (frame.Selection, or a local holding one) anchored to anything but its own frame."""
    found = set()
    owner = {}
    for no, line in enumerate(lx.keep, 1):
        for m in SELECTION_LOCAL.finditer(line):
            owner[m.group(1)] = m.group(2)
        for m in SELECTION_ANCHOR.finditer(line):
            target = m.group(1)
            frame = target[:-len(".Selection")] if target.endswith(".Selection") else owner.get(target)
            if not frame:
                continue
            args = [a.strip() for a in m.group(3).split(",")]
            rel = args[0] if m.group(2) == "SetAllPoints" else (args[1] if len(args) > 1 else "")
            if rel != frame:
                found.add(("SELFBOX", no))
    return found


# The offsets (4th and 5th results) of a GetPoint read into locals, then compared exactly within the next lines.
POINT_READ = re.compile(r"\blocal\s+([\w\s,]+?)\s*=\s*[\w.\[\]]+:GetPoint\(")
POINT_REACH = 12


def point_exact_hits(lx):
    """An offset read from GetPoint compared with == or ~= to a number, a constant or a saved value."""
    found = set()
    lines = lx.blank
    for no, line in enumerate(lines, 1):
        m = POINT_READ.search(line)
        if not m:
            continue
        names = [n.strip() for n in m.group(1).split(",")]
        offsets = [re.escape(n) for n in names[3:5] if n and n != "_"]
        if not offsets:
            continue
        name = r"(?:%s)" % "|".join(offsets)
        # A number, a constant, or a saved value (a field or local): anything but nil.
        value = r"(?:-?\d[\d.]*|(?!nil\b)[A-Za-z_][\w.]*)"
        rx = re.compile(r"(?<![\w.])%s\s*(?:==|~=)\s*%s\b|(?<![\w.])%s\s*(?:==|~=)\s*%s\b" % (name, value, value, name))
        for at in range(no, min(no + POINT_REACH, len(lines)) + 1):
            if rx.search(lines[at - 1]):
                found.add(("POINTEXACT", at))
    return found


# Lists whose rows a secure pad clicks; only the pad's snippet may size them.
PADLIST_FILES = ("Skills/Trainer.lua", "Social/GuildNoteBridge.lua")
PADLIST_ANY_LOCAL = re.compile(r"\blocal\s+(\w+)\s*=")
PADLIST_LOCAL = re.compile(r"\blocal\s+(\w+)\s*=\s*(?:[\w.]+\s+and\s+)?[\w.]+\.Scroll(?:Box|Bar)\b")
PADLIST_CALL = re.compile(r"([\w.]+)\s*:\s*(?:Set(?:Height|Width|Size|Point|AllPoints)|ClearAllPoints"
                          r"|Get(?:Height|Width|Size|Rect|Top|Bottom|Left|Right))\s*\(")
PADLIST_SETTER = re.compile(r"\b(?:Set(?:Size|Point|Width|Height)If|SetPointOnce|PutPoints)\s*\(\s*([\w.]+)")


def pad_list_hits(path, lx):
    """The pad-clicked client list (X.ScrollBox / X.ScrollBar, or a local holding one) sized, placed or measured."""
    found = set()
    if path not in PADLIST_FILES:
        return found
    held = set()
    for no, line in enumerate(lx.blank, 1):
        for m in PADLIST_ANY_LOCAL.finditer(line):
            held.discard(m.group(1))
        for m in PADLIST_LOCAL.finditer(line):
            held.add(m.group(1))
        for rx in (PADLIST_CALL, PADLIST_SETTER):
            for m in rx.finditer(line):
                target = m.group(1)
                if target.endswith((".ScrollBox", ".ScrollBar")) or target in held:
                    found.add(("PADLIST", no))
    return found


def mouse_order_hits(lx):
    """A mouse script set on a frame after its clicks were switched off, in the same file."""
    found = set()
    off = {}
    for no, line in enumerate(lx.keep, 1):
        for m in CLICKS_OFF.finditer(line):
            off[m.group(1) or m.group(2)] = no
        for m in MOUSE_SCRIPT.finditer(line):
            if m.group(1) in off:
                found.add(("MOUSEORDER", no))
    return found


def drag_point_hits(lx, funcs):
    """GetPoint read after StopMovingOrSizing in the same function body (callbacks inside it excluded)."""
    found = set()
    for start, end, _, _ in funcs:
        mine = own_lines(funcs, start, end)
        stopped = False
        for no in range(start, end + 1):
            if no not in mine:
                continue
            line = lx.blank[no - 1]
            if stopped and re.search(r":GetPoint\s*\(", line):
                found.add(("DRAGPOINT", no))
            if re.search(r":StopMovingOrSizing\s*\(", line):
                stopped = True
    return found


# Comments and strings count: names hid in a tooltip and a comment.
def otheraddon_rx():
    """The names, from the main checkout's gitignored dev/otheraddons.txt (no name in the repo); None without it."""
    try:
        common = subprocess.run(["git", "rev-parse", "--git-common-dir"], capture_output=True, text=True,
                                cwd=os.path.dirname(os.path.abspath(__file__))).stdout.strip()
        path = os.path.join(os.path.dirname(os.path.abspath(common)), "dev", "otheraddons.txt")
        with open(path, encoding="utf-8") as fh:
            names = [n.strip() for n in fh if n.strip() and not n.startswith("#")]
    except OSError:
        return None
    parts = [r"[-\s]*".join(re.escape(w) for w in re.split(r"[-\s]+", n)) for n in names]
    return re.compile(r"(?i)\b(?:" + "|".join(parts) + r")\b") if parts else None


OTHERADDON_RX = otheraddon_rx()
# The settings Support tab is the one place that names our other addon.
OTHERADDON_HOME = "Options/HelpPanes.lua"
OTHERADDON_OK = re.compile(r"SUPPORT_MORE")


def otheraddon_hits(path, text):
    if OTHERADDON_RX is None or path == OTHERADDON_HOME:
        return []
    hits = []
    for no, line in enumerate(text.splitlines(), 1):
        if OTHERADDON_RX.search(line) and not OTHERADDON_OK.search(line):
            hits.append(("OTHERADDON", no, MESSAGES["OTHERADDON"]))
    return hits


def pattern_hits(path, lx, funcs):
    found = set()
    for rule, rx in USE_PATTERNS.items():
        if allowed(rule, path):
            continue
        for no, line in enumerate(lx.blank, 1):
            for m in rx.finditer(line):
                qs = qualified_start(line, m.start())
                qual = line[qs:m.start()]
                if re.match(r"ns\s*[.:]", qual):
                    continue
                if (rule == "REGISTRY" and REGISTRY_METHODS.match(m.group(0))
                        and not CLIENT_METHOD_OWNER.fullmatch(qual)):
                    continue
                if is_use(line, qs, m.end()):
                    found.add((rule, no))
                    break
    for patterns, lines in ((LINE_PATTERNS, lx.blank), (KEEP_PATTERNS, lx.keep)):
        for rule, rx in patterns.items():
            if allowed(rule, path):
                continue
            for no, line in enumerate(lines, 1):
                m = rx.search(line)
                if not m and rule == "SYSBASE" and path.startswith("Bar/"):
                    m = SYSBASE_BAND.search(line)
                if m and not (ALLOWED_SITES.get(rule) and m.lastindex and site_allowed(rule, path, m.group(1))):
                    found.add((rule, no))
    for rx, homes in SHARED_ART:
        if any(path == h or (h.endswith("/") and path.startswith(h)) for h in homes):
            continue
        for no, line in enumerate(lx.keep, 1):
            if rx.search(line):
                found.add(("SHAREDART", no))
    if not allowed("ONUPDATE", path):
        for no in onupdate_lines(lx):
            found.add(("ONUPDATE", no))
    if path in EDITSAVE_FILES:
        for no, line in enumerate(lx.blank, 1):
            if EDITSAVE_RX.search(line):
                found.add(("EDITSAVE", no))
    found |= structure_hits(path, lx)
    found |= drag_point_hits(lx, funcs)
    found |= check_label_hits(lx)
    found |= mouse_order_hits(lx)
    found |= self_box_hits(lx)
    found |= point_exact_hits(lx)
    found |= pad_list_hits(path, lx)
    found |= secret_layer_hits(lx)
    found |= secret_atlas_hits(lx)
    found |= secret_bar_hits(path, lx)
    found |= cvar_login_hits(lx, funcs)
    found |= held_cvar_hits(lx, funcs)
    if not allowed("THROTTLEFRAME", path):
        found |= throttle_frame_hits(lx)
    for rule, per_file in ALLOWED_BODIES.items():
        if path in per_file:
            inside = body_lines(funcs, per_file[path])
            found = {h for h in found if h[0] != rule or h[1] not in inside}
    return [(rule, no, MESSAGES[rule]) for rule, no in sorted(found, key=lambda h: (h[1], h[0]))]


HELDCVAR_RX = re.compile(r"\bns\s*\.\s*SetCVar\s*\(")


def held_cvar_hits(lx, funcs):
    """ns.SetCVar inside the toggle effects or a function opened on an ns.OnToggle line."""
    lines = set()
    for start, end, name, _ in funcs:
        if name == "KeyEffects" or "ns.OnToggle(" in lx.blank[start - 1]:
            lines.update(range(start, end + 1))
    return {("HELDCVAR", no) for no in lines if HELDCVAR_RX.search(lx.blank[no - 1])}


def function_name(line, col):
    before, after = line[:col], line[col + len("function"):]
    m = re.match(r"\s*([\w.:]+)\s*\(", after)
    if m:
        return m.group(1)
    m = re.search(r"([\w.:\[\]\"]+)\s*=\s*$", before)
    if m:
        return m.group(1)
    return "(anonymous)"


def functions(lx):
    """(start, end, name, is_local) for every function, by block keyword matching."""
    stack, found = [], []
    for no, line in enumerate(lx.blank, 1):
        for m in IDENT.finditer(line):
            word = m.group(0)
            if word == "function":
                is_local = bool(re.search(r"\blocal\s+(?:[A-Za-z_]\w*\s*=\s*)?$", line[:m.start()]))
                stack.append(("function", no, function_name(line, m.start()), is_local))
            elif word in ("if", "do", "repeat"):
                stack.append((word, no, None, False))
            elif word in ("end", "until") and stack:
                kind, start, name, is_local = stack.pop()
                if kind == "function":
                    found.append((start, no, name, is_local))
    return found


def size_hits(lx, funcs):
    hits = []
    if lx.nlines > FILE_LIMIT:
        hits.append(("FILESIZE", FILE_LIMIT + 1, "file has %d lines (limit %d)" % (lx.nlines, FILE_LIMIT)))
    for start, end, name, _ in funcs:
        length = end - start + 1
        if length > FUNC_LIMIT:
            hits.append(("FUNCSIZE", start, "function %s is %d lines (limit %d)" % (name, length, FUNC_LIMIT)))
    return hits


def comment_hits(lx):
    hits, run_start, run_len = [], 0, 0
    for idx in range(lx.nlines + 1):
        only = idx < lx.nlines and lx.has_comment[idx] and not lx.keep[idx].strip()
        if only:
            if run_len == 0:
                run_start = idx + 1
            run_len += 1
        else:
            if run_len > COMMENT_BLOCK_LIMIT:
                hits.append(("COMMENT", run_start, "comment block of %d lines (limit %d)" % (run_len, COMMENT_BLOCK_LIMIT)))
            run_len = 0
        if idx < lx.nlines and lx.comment_len[idx] > COMMENT_CHAR_LIMIT:
            hits.append(("COMMENT", idx + 1, "comment line of %d chars (limit %d)" % (lx.comment_len[idx], COMMENT_CHAR_LIMIT)))
    return hits


def code_lines(lx):
    """(normalized, line number, does something) for each line holding code."""
    out = []
    for no, line in enumerate(lx.blank, 1):
        norm = SPACES.sub("", line)
        if norm and norm != ";":
            out.append((norm, no, bool(REAL.search(line))))
    return out


def dup_hits(corpus_code):
    windows = {}
    for path, code in corpus_code.items():
        real = [0]
        for _, _, does in code:
            real.append(real[-1] + (1 if does else 0))
        for i in range(len(code) - DUP_WINDOW + 1):
            if real[i + DUP_WINDOW] - real[i] < DUP_MIN_REAL:
                continue
            key = hashlib.md5("\n".join(c[0] for c in code[i:i + DUP_WINDOW]).encode()).digest()
            windows.setdefault(key, []).append((path, i))
    covered, partner = {}, {}
    for occ in windows.values():
        if len(occ) < 2:
            continue
        kept, last = [], {}
        for path, i in sorted(occ):
            if path in last and i - last[path] < DUP_WINDOW:
                continue
            last[path] = i
            kept.append((path, i))
        if len(kept) < 2:
            continue
        for path, i in kept:
            marks = covered.setdefault(path, set())
            for k in range(i, i + DUP_WINDOW):
                marks.add(k)
            other = next(o for o in kept if o != (path, i))
            partner.setdefault((path, i), other)
    hits = {}
    for path, marks in covered.items():
        code = corpus_code[path]
        idxs = sorted(marks)
        blocks, start, prev = [], idxs[0], idxs[0]
        for k in idxs[1:]:
            if k != prev + 1:
                blocks.append((start, prev))
                start = k
            prev = k
        blocks.append((start, prev))
        for b0, b1 in blocks:
            other = None
            for k in range(b0, b1 + 1):
                if (path, k) in partner:
                    other = partner[(path, k)]
                    break
            where = "%s:%d" % (other[0], corpus_code[other[0]][other[1]][1]) if other else "?"
            hits.setdefault(path, []).append(
                ("DUP", code[b0][1], "%d code lines repeated (also at %s)" % (b1 - b0 + 1, where), code[b1][1]))
    return hits


def dupfn_hits(corpus_lex, corpus_funcs):
    """Copies: a local, or a module-table function (B.X, T:Y) outside the shared layer, whose body matches any
    function (local, ns., module-table or inline) in another file."""
    bodies = {}
    for path, funcs in corpus_funcs.items():
        lx = corpus_lex[path]
        for start, end, name, is_local in funcs:
            body = [SPACES.sub("", lx.blank[k - 1]) for k in range(start + 1, end)]
            body = [b for b in body if b]
            if len(body) < DUPFN_MIN:
                continue
            key = hashlib.md5("\n".join(body).encode()).digest()
            bodies.setdefault(key, []).append((path, start, name, end, is_local))
    hits = {}
    for group in bodies.values():
        if len({g[0] for g in group}) < 2:
            continue
        for path, start, name, end, is_local in group:
            on_table = re.search(r"[.:]", name) and not name.startswith("ns.") and not path.startswith(SHARED_LAYER)
            if not is_local and not on_table:
                continue
            # Point at the shared copy when there is one.
            others = sorted((g for g in group if g[0] != path),
                            key=lambda g: (not (g[2].startswith("ns.") or g[0].startswith(SHARED_LAYER)), g[4], g[0], g[1]))
            other = others[0]
            kind = "local function" if is_local else "function"
            hits.setdefault(path, []).append(
                ("DUPFN", start, "%s %s has the same body as %s:%d (%s)" % (kind, name, other[0], other[1], other[2]), end))
    return hits


def deadns_hits(corpus_lex):
    """ns fields whose every mention in the corpus is a definition, unless the dev addon reads them or they are kept API."""
    defs, refs = {}, {}
    for path, lx in corpus_lex.items():
        for no, line in enumerate(lx.blank, 1):
            for m in NS_REF.finditer(line):
                refs[m.group(1)] = refs.get(m.group(1), 0) + 1
            m = NS_DEF.match(line)
            if m:
                defs.setdefault(m.group(1) or m.group(2), []).append((path, no))
    hits = {}
    for name, places in defs.items():
        if name in DEV_NAMES or name in KEPT_API or refs.get(name, 0) > len(places):
            continue
        for path, no in places:
            hits.setdefault(path, []).append(("DEADNS", no, "ns.%s is defined but never read" % name))
    return hits


# ns fields set by a loop or a table copy the patterns cannot see; UNDEFNS never reports them.
# Set by the dev addon on attach: the walk helpers note each walk only then (Core/Util.lua).
NS_DYNAMIC = frozenset(("noteWalks",))
NS_DEF_ANY = re.compile(r"\bfunction\s+ns\s*[.:]\s*(\w+)\s*\(|\bns\s*\.\s*(\w+)\s*=(?!=)")
# ns.A, ns.B = 1, 2: every name on the left.
NS_DEF_LIST = re.compile(r"^\s*((?:ns\s*\.\s*\w+\s*,\s*)+ns\s*\.\s*\w+)\s*=(?!=)")


def undefns_hits(corpus_lex):
    """ns fields read or called somewhere and defined nowhere in the corpus: a typo or a helper that does not exist."""
    defs, uses = set(), {}
    for path, lx in corpus_lex.items():
        for no, line in enumerate(lx.blank, 1):
            for m in NS_DEF_ANY.finditer(line):
                defs.add(m.group(1) or m.group(2))
            m = NS_DEF_LIST.match(line)
            if m:
                defs.update(NS_REF.findall(m.group(1)))
            for m in NS_REF.finditer(line):
                uses.setdefault(m.group(1), []).append((path, no))
    hits = {}
    for name, places in uses.items():
        # DEV_NAMES are attach points the dev addon fills in.
        if name in defs or name in NS_DYNAMIC or name in DEV_NAMES:
            continue
        for path, no in places:
            hits.setdefault(path, []).append(("UNDEFNS", no, "ns.%s is used but never defined" % name))
    return hits


def toc_entries(text):
    directive = re.compile(r"\s+\[[^\]]*\]\s*$")
    for no, raw in enumerate(text.replace("\r\n", "\n").split("\n"), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        while directive.search(line):
            line = directive.sub("", line)
        yield no, line.replace("\\", "/")


LOCALE_DIR = "Locales"
LOCALE_ROW = re.compile(r'^L\["(\w+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', re.M)
LOCALE_ARGS = re.compile(r"%[sd]")


def locale_hits():
    """Each language file against enUS: keys missing or extra, and placeholders that differ."""
    hits = []
    if not os.path.isfile(os.path.join(LOCALE_DIR, "enUS.lua")):
        return hits
    # English may span enUS.lua and its siblings (enUS_WhatsNew.lua): every one is the base.
    base = {}
    for name in sorted(os.listdir(LOCALE_DIR)):
        if name.startswith("enUS") and name.endswith(".lua"):
            with open(os.path.join(LOCALE_DIR, name), encoding="utf-8") as fh:
                base.update(LOCALE_ROW.findall(fh.read()))
    # A language may span its file and siblings (deDE_WhatsNew.lua) too: checked as one, reported on the main file.
    langs = {}
    for name in sorted(os.listdir(LOCALE_DIR)):
        if name.endswith(".lua") and not name.startswith("enUS"):
            langs.setdefault(name[:-4].split("_")[0], []).append(name)
    for lang, names in sorted(langs.items()):
        path = LOCALE_DIR + "/" + lang + ".lua"
        text = ""
        for name in names:
            with open(os.path.join(LOCALE_DIR, name), encoding="utf-8") as fh:
                text += fh.read() + "\n"
        rows = LOCALE_ROW.findall(text)
        # A language that shares another's table (esMX from esES) holds no rows of its own.
        if not rows and "LocaleFrom" in text:
            continue
        have = dict(rows)
        missing = [k for k in base if k not in have]
        extra = [k for k in have if k not in base]
        if missing:
            hits.append((path, 1, "LOCALEKEYS", "%d English strings untranslated: %s%s" % (
                len(missing), ", ".join(missing[:6]), " ..." if len(missing) > 6 else "")))
        if extra:
            hits.append((path, 1, "LOCALEKEYS", "%d keys English no longer has: %s" % (len(extra), ", ".join(extra[:6]))))
        for key, value in rows:
            if key in base and LOCALE_ARGS.findall(value) != LOCALE_ARGS.findall(base[key]):
                line = text[:text.find('L["' + key + '"]')].count("\n") + 1
                hits.append((path, line, "LOCALEKEYS", key + " placeholders differ from English"))
    return hits


US_SPELL = re.compile(r"\b(colour\w*|grey\w*|centre[sd]?|centred|armour\w*|behaviour\w*|favour\w*|"
                      r"honour\w*|flavour\w*|recognis\w+|organis\w+|customis\w+|realis(?:e|ed|es|ing)\b|optimis\w+|"
                      r"initialis\w+|analys(?:e|ed|es|ing)\b|cancell\w+|travell\w+|labell\w+|modell\w+|licence|"
                      r"(?:un)?tick(?:ed|ing)?(?! marker))\b", re.I)
SPELL_DOCS = ("CHANGELOG.md", "README.md", "docs/description.md")


NEWS_TURN_ON = re.compile(r"\bturn (?:it |them )?on\b", re.I)


def news_hits():
    """The newest What's New: an entry naming an off-by-default option says to turn it on in the options."""
    hits = []
    welcome, defaults, toggles = "Options/Welcome.lua", "Core/Defaults.lua", "Options/Toggles.lua"
    if not all(os.path.isfile(f) for f in (welcome, defaults, toggles)):
        return hits
    with open(welcome, encoding="utf-8") as fh:
        newest = re.search(r'WHATSNEW = \{\s*\{ id = (\d+), version = "([\d.]+)"', fh.read())
    # A shipped version's text stays as players saw it.
    if newest and subprocess.run(["git", "tag", "-l", "v" + newest.group(2)], capture_output=True, text=True).stdout.strip():
        return hits
    with open(defaults, encoding="utf-8") as fh:
        block = fh.read().split("ns.DB_DEFAULTS = {", 1)[-1].split("\n}", 1)[0]
    with open(toggles, encoding="utf-8") as fh:
        toggle_keys = set(re.findall(r'^\s*\{ "(\w+)", L\[', fh.read(), re.M))
    off = {k for k in re.findall(r"^\s*(\w+) = false,", block, re.M) if k in toggle_keys}
    english = {}
    for name in sorted(os.listdir(LOCALE_DIR)):
        if name.startswith("enUS") and name.endswith(".lua"):
            with open(os.path.join(LOCALE_DIR, name), encoding="utf-8") as fh:
                english.update(LOCALE_ROW.findall(fh.read()))
    if not newest:
        return hits
    # A check list row reads "Group: item": its group names it too.
    labels = {}
    for key in off:
        label = english.get("OPT_" + key)
        if label:
            for name in {label, label.split(":")[0]}:
                if len(name) >= 6:
                    labels[name] = key
    prefix = "WN%s_" % newest.group(1)
    # An options section named as the place ("under Character and spells") names no option.
    groups = sorted((v for k, v in english.items() if k.startswith("GROUP_")), key=len, reverse=True)
    for key, text in english.items():
        if not (key.startswith(prefix) and key.endswith("_TEXT")):
            continue
        for group in groups:
            text = text.replace(group, "")
        named = sorted(n for n in labels if re.search(r"(?<!\w)" + re.escape(n) + r"(?!\w)", text))
        if named and not (NEWS_TURN_ON.search(text) and "options" in text.lower()):
            hits.append((LOCALE_DIR + "/enUS_WhatsNew.lua", 1, "NEWSOPTIN",
                         "%s names %s, off by default, without saying to turn it on in the options" % (key, named[0])))
    return hits


def spelling_hits():
    """British spellings in what players read in English: enUS strings, What's New, changelog, readme, description."""
    hits = []
    for name in sorted(os.listdir(LOCALE_DIR)) if os.path.isdir(LOCALE_DIR) else []:
        if not (name.startswith("enUS") and name.endswith(".lua")):
            continue
        with open(os.path.join(LOCALE_DIR, name), encoding="utf-8") as fh:
            for no, line in enumerate(fh, 1):
                m = LOCALE_ROW.match(line)
                word = m and US_SPELL.search(m.group(2))
                if word:
                    hits.append((LOCALE_DIR + "/" + name, no, "USSPELL", "British spelling \"%s\"" % word.group(1)))
    for doc in SPELL_DOCS:
        if not os.path.isfile(doc):
            continue
        with open(doc, encoding="utf-8") as fh:
            for no, line in enumerate(fh, 1):
                word = US_SPELL.search(line)
                if word:
                    hits.append((doc, no, "USSPELL", "British spelling \"%s\"" % word.group(1)))
    return hits


def toc_hits(tracked, toc_text):
    hits, listed = [], set()
    tracked_set = set(tracked)
    for no, entry in toc_entries(toc_text):
        listed.add(entry)
        if entry not in tracked_set:
            hits.append((TOC_NAME, no, "TOC", "toc entry %s is not a tracked file (check its case)" % entry, entry))
    for path in tracked:
        if in_scope(path) and path not in listed:
            hits.append((path, 1, "TOC", "file is not listed in " + TOC_NAME, path))
    return hits



# ---------------------------------------------------------------------- driver

def analyse(corpus):
    """Every hit for every file: {path: [(rule, line, message)]}."""
    lexed = {p: lex(t) for p, t in corpus.items()}
    funcs = {p: functions(lx) for p, lx in lexed.items()}
    code = {p: code_lines(lx) for p, lx in lexed.items()}
    hits = {}
    for p, lx in lexed.items():
        hits[p] = pattern_hits(p, lx, funcs[p]) + size_hits(lx, funcs[p]) + comment_hits(lx) + otheraddon_hits(p, corpus[p])
    same_fn = {}
    for p, items in dupfn_hits(lexed, funcs).items():
        for rule, start, msg, end in items:
            hits[p].append((rule, start, msg))
            same_fn.setdefault(p, []).append((start, end))
    # A DUP block inside a function DUPFN already reports is the same finding.
    for p, items in dup_hits(code).items():
        for rule, start, msg, end in items:
            if not any(s <= start and end <= e for s, e in same_fn.get(p, ())):
                hits[p].append((rule, start, msg))
    for p, items in deadns_hits(lexed).items():
        hits[p].extend(items)
    for p, items in undefns_hits(lexed).items():
        hits[p].extend(items)
    return hits


def counts_of(hits):
    counts = {}
    for path, items in hits.items():
        for rule, _, _ in items:
            counts.setdefault(rule, {}).setdefault(path, 0)
            counts[rule][path] += 1
    return counts


def load_baseline(root, text=None):
    if text is None:
        path = os.path.join(root, BASELINE_NAME)
        if not os.path.isfile(path):
            return {}
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    return json.loads(text).get("rules", {})


def save_baseline(root, rules):
    data = {
        "about": "Violations that existed when the checker arrived; a file passes a rule while its count is at or "
                 "below this number. Regenerate with python tools/check.py --update-baseline after a cleanup.",
        "rules": rules,
    }
    with open(os.path.join(root, BASELINE_NAME), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2, sort_keys=False)
        handle.write("\n")


def write_baseline(root, counts):
    rules = {}
    for rule in RULES:
        if rule == "TOC" or rule not in counts:
            continue
        rules[rule] = {p: counts[rule][p] for p in sorted(counts[rule])}
    save_baseline(root, rules)
    return rules


def parse_diff(raw):
    """From git diff -U0 -M: added {path: {line: text}}, removed {path: {normalized text: n}}, renames {new: old}."""
    added, removed, renames = {}, {}, {}
    path, old, in_hunk, newno = None, None, False, 0
    for bline in raw.split(b"\n"):
        line = bline.decode("utf-8", "replace").rstrip("\r")
        if line.startswith("diff --git "):
            path, old, in_hunk = None, None, False
        elif line.startswith("@@"):
            m = HUNK.match(line)
            newno = int(m.group(1)) if m else 0
            in_hunk = path is not None
        elif in_hunk and line.startswith("+"):
            added.setdefault(path, {})[newno] = line[1:]
            newno += 1
        elif in_hunk and line.startswith("-"):
            pool = removed.setdefault(path, {})
            norm = SPACES.sub("", line[1:])
            pool[norm] = pool.get(norm, 0) + 1
        elif in_hunk:
            continue
        elif line.startswith("rename from "):
            old = line[len("rename from "):]
        elif line.startswith("rename to ") and old:
            renames[line[len("rename to "):]] = old
        elif line.startswith("+++ "):
            target = line[4:]
            path = target[2:] if target.startswith("b/") else None
    return added, removed, renames


def change_info(root, mode, untracked, corpus):
    """What this change adds, against the index (--staged) or HEAD; None when git cannot say."""
    base = ["--cached"] if mode == "staged" else ["HEAD"]
    try:
        raw = git(root, ["-c", "core.quotepath=off", "diff", "-U0", "-M", "--no-color", "--no-ext-diff",
                         "--src-prefix=a/", "--dst-prefix=b/"] + base + ["--", "*.lua"])
    except (UsageError, OSError):
        return None
    added, removed, renames = parse_diff(raw)
    for p in untracked:
        if p in corpus:
            added[p] = {no: text for no, text in enumerate(corpus[p].replace("\r\n", "\n").split("\n"), 1)}
    return added, removed, renames


def parse_args(argv):
    opts = {"mode": None, "files": [], "json": False}
    modes = ("--all", "--staged", "--update-baseline", "--carry-renames")
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in modes or arg == "--files":
            if opts["mode"]:
                raise UsageError("pick one of --all, --staged, --files, --update-baseline, --carry-renames")
            opts["mode"] = arg[2:]
            if arg == "--files":
                while i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                    i += 1
                    opts["files"].append(argv[i])
                if not opts["files"]:
                    raise UsageError("--files needs at least one path")
        elif arg == "--json":
            opts["json"] = True
        elif arg in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
        else:
            raise UsageError("unknown argument " + arg)
        i += 1
    if not opts["mode"]:
        raise UsageError("pick one of --all, --staged, --files, --update-baseline, --carry-renames (see --help)")
    return opts


def rel_path(root, given):
    cands = [given] if os.path.isabs(given) else [os.path.join(os.getcwd(), given), os.path.join(root, given)]
    for cand in cands:
        full = os.path.abspath(cand)
        if os.path.isfile(full):
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if rel.startswith("../"):
                raise UsageError(given + " is outside the repo")
            return rel
    raise UsageError(given + " does not exist")


def untracked_files(root):
    try:
        raw = git(root, ["ls-files", "--others", "--exclude-standard", "-z"])
    except (UsageError, OSError):
        return []
    return [p.decode("utf-8") for p in raw.split(b"\0") if p]


def carry_renames(root):
    info = change_info(root, "all", [], {})
    if info is None:
        raise UsageError("git diff failed; cannot find renames")
    renames = {new: old for new, old in info[2].items() if in_scope(new)}
    rules = load_baseline(root)
    moved = 0
    for rule, per_file in rules.items():
        for new, old in renames.items():
            if old in per_file and new not in per_file:
                per_file[new] = per_file.pop(old)
                moved += 1
                print("%-9s %s -> %s" % (rule, old, new))
        rules[rule] = {p: per_file[p] for p in sorted(per_file)}
    save_baseline(root, rules)
    print("moved %d baseline entries; stage %s with the rename" % (moved, BASELINE_NAME))
    return 0


def is_new_line(change, path, line, spent):
    """A hit on a line this change adds, unless the same line text was removed from the file (a move)."""
    if change is None or line not in change[0].get(path, {}):
        return False
    key = (path, line)
    if key not in spent:
        norm = SPACES.sub("", change[0][path][line])
        pool = change[1].get(path, {})
        if pool.get(norm, 0) > 0:
            pool[norm] -= 1
            spent[key] = False
        else:
            spent[key] = True
    return spent[key]


def run(argv):
    started = time.time()
    opts = parse_args(argv)
    root = find_root()
    mode = opts["mode"]
    if mode == "carry-renames":
        return carry_renames(root)
    tracked, have_git = tracked_files(root)
    untracked = untracked_files(root) if have_git and mode != "staged" else []
    tracked += untracked
    scope = [p for p in tracked if in_scope(p)]

    baseline_text = None
    if mode == "staged":
        corpus = read_index(root, scope) if scope else {}
        raw = git(root, ["diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"])
        targets = [p.decode("utf-8") for p in raw.split(b"\0") if p]
        targets = [p for p in targets if in_scope(p) and p in corpus]
        toc_text = read_index(root, [TOC_NAME]).get(TOC_NAME, "")
        baseline_text = read_index(root, [BASELINE_NAME]).get(BASELINE_NAME)
    else:
        corpus = {}
        for p in scope:
            if os.path.isfile(os.path.join(root, p)):
                corpus[p] = read_disk(root, p)
        if mode == "files":
            targets = []
            for given in opts["files"]:
                rel = rel_path(root, given)
                if rel.endswith(".lua") and not rel.startswith(EXCLUDED_DIRS):
                    if rel not in corpus:
                        corpus[rel] = read_disk(root, rel)
                    targets.append(rel)
        else:
            targets = sorted(corpus)
        toc_text = read_disk(root, TOC_NAME)
        tracked = [p for p in tracked if os.path.isfile(os.path.join(root, p))]
        tracked += [t for t in targets if t not in tracked]

    hits = analyse(corpus)
    counts = counts_of(hits)

    if mode == "update-baseline":
        rules = write_baseline(root, counts)
        for rule in RULES:
            if rule in rules:
                print("%-9s %4d in %d files" % (rule, sum(rules[rule].values()), len(rules[rule])))
        print("wrote " + BASELINE_NAME + " (%.2fs)" % (time.time() - started))
        return 0

    baseline = load_baseline(root, baseline_text)
    change = change_info(root, mode, untracked, corpus) if have_git else None
    renames = change[2] if change else {}
    failures, improved, carried, spent = [], [], [], {}

    def fail(path, line, rule, msg, count=None, allowed=None, new=False, note=""):
        failures.append({"path": path, "line": line, "rule": rule, "message": msg + note, "new": new,
                         "count": count, "baseline": allowed, "fix": FIX[rule]})

    for path in targets:
        old = renames.get(path)
        if old and any(old in per and path not in per for per in baseline.values()):
            if mode == "staged":
                fail(path, 1, "BASELINE", "renamed from %s; its baseline entries still name the old path" % old)
            carried.append((old, path))
        by_rule = {}
        for rule, line, msg in hits.get(path, []):
            by_rule.setdefault(rule, []).append((line, msg))
        for rule in RULES:
            items = sorted(by_rule.get(rule, []))
            per = baseline.get(rule, {})
            allowed = per.get(path, per.get(old, 0) if old else 0)
            have = len(items)
            if have > allowed:
                for line, msg in items:
                    fail(path, line, rule, msg, have, allowed, is_new_line(change, path, line, spent))
            else:
                if rule in LINE_RULES:
                    for line, msg in items:
                        if is_new_line(change, path, line, spent):
                            fail(path, line, rule, msg, have, allowed, True,
                                 "; a call site this change adds (the baseline only covers the old ones)")
                if have < allowed:
                    improved.append({"path": path, "rule": rule, "count": have, "baseline": allowed})
    target_set = set(targets)
    target_lower = {t.lower() for t in targets}
    for path, line, rule, msg, entry in toc_hits(tracked, toc_text):
        if mode == "files":
            if path != TOC_NAME and path not in target_set:
                continue
            if path == TOC_NAME and entry.lower() not in target_lower:
                continue
        fail(path, line, rule, msg)

    for path, line, rule, msg in locale_hits() + spelling_hits() + news_hits():
        fail(path, line, rule, msg)

    elapsed = time.time() - started
    if opts["json"]:
        print(json.dumps({"ok": not failures, "mode": mode, "files": len(targets), "seconds": round(elapsed, 3),
                          "violations": failures, "improved": improved}, indent=2))
    else:
        for f in failures:
            tag = " [NEW]" if f["new"] else ""
            note = "" if f["count"] is None else " [%d in file, baseline %d]" % (f["count"], f["baseline"])
            print("%s:%d: %s%s %s%s. Fix: %s" % (f["path"], f["line"], f["rule"], tag, f["message"], note, f["fix"]))
        if carried and mode != "staged":
            for old, new in carried:
                sys.stderr.write("note: %s uses the baseline of %s (renamed); run python tools/check.py "
                                 "--carry-renames before committing\n" % (new, old))
        if improved:
            sys.stderr.write("note: %d file/rule counts are below the baseline; a maintainer can tighten it "
                             "with python tools/check.py --update-baseline\n" % len(improved))
        fresh = sum(1 for f in failures if f["new"])
        status = "FAIL: %d violation lines, %d on new lines" % (len(failures), fresh) if failures else "ok"
        sys.stderr.write("check.py --%s: %d files, %s (%.2fs)\n" % (mode, len(targets), status, elapsed))
    return 1 if failures else 0


def main():
    try:
        return run(sys.argv[1:])
    except UsageError as err:
        sys.stderr.write("check.py: " + str(err) + "\n")
        return 2
    except Exception as err:  # noqa: BLE001  internal errors must not read as a pass
        sys.stderr.write("check.py: internal error: %r\n" % (err,))
        return 2


if __name__ == "__main__":
    sys.exit(main())
