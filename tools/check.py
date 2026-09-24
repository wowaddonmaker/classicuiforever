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
BASELINE_NAME = "tools/check-baseline.json"
DOC = "tools/CONVENTIONS.md"

FILE_LIMIT = 800
FUNC_LIMIT = 120
COMMENT_BLOCK_LIMIT = 3
COMMENT_CHAR_LIMIT = 140
DUP_WINDOW = 8
DUP_MIN_REAL = 4
DUPFN_MIN = 5

RULES = ["CVAR", "REGISTRY", "HOOK", "ONUPDATE", "LOADADDON", "EDITMODE", "PANELMGR",
         "FILESIZE", "FUNCSIZE", "COMMENT", "DUP", "DUPFN", "TOC"]
# A hit of these on a line the change adds fails even within the baseline, so swapping one call for another fails.
LINE_RULES = ("CVAR", "REGISTRY", "HOOK", "ONUPDATE", "LOADADDON", "EDITMODE", "PANELMGR")

# The one file allowed to hold each pattern.
ALLOWED = {
    "CVAR": "Core/Settings.lua",
    "HOOK": "Core/Hooks.lua",
    "ONUPDATE": "Core/Scheduler.lua",
    "EDITMODE": "Bar/BandPins.lua",
}

FIX = {
    "CVAR": "call ns.SetCVar (Core/Settings.lua), and only on a player action; " + DOC + " Taint rules",
    "REGISTRY": "use our own signal (ns.SignalSheetLaid pattern) or our own event frame (ns.RegisterEvents)",
    "HOOK": "use ns.HookMethod / ns.HookGlobal / ns.HookScriptOnce (Core/Hooks.lua), and prefer a watch (ns.Sched)",
    "ONUPDATE": "use ns.Sched.OnFrame(frame, spec) or ns.Sched.Job(spec) (Core/Scheduler.lua)",
    "LOADADDON": "never load a client addon from our code; wait for its ADDON_LOADED (ns.RegisterEvents)",
    "PANELMGR": "never drive the client window manager from our code (it then runs in our name and in combat can "
                "neither close nor place windows); open and close through ns.ShowPanel / ns.HidePanel",
    "EDITMODE": "never write layouts mid-session; writes run only as the session ends: the ns.sessionEnding jobs in "
                "Options/Layout.lua (ns.QueueLayoutJob: FitNow, ResetNow, ClassicNow, SelectNow, "
                "ns.ApplyClassicFrameSpots) and the pin writer in Bar/BandPins.lua",
    "FILESIZE": "split by responsibility into a sibling file listed in the .toc; " + DOC + " Folder map",
    "FUNCSIZE": "extract named local helpers, and reuse the shared ones in Core/ and UI/",
    "COMMENT": "comments are one-line essential whys; history and proofs belong in the commit message",
    "DUP": "move it into the shared layer (Core/, UI/Dress.lua, UI/Dialogs.lua, UI/Menus.lua ...) and call it from both places",
    "DUPFN": "keep one copy in the shared layer (Core/Util.lua, UI/...) as ns.Name and call it",
    "TOC": "list every addon .lua in " + TOC_NAME + " and remove entries for files that are gone",
    "BASELINE": "run python tools/check.py --carry-renames, then git add " + BASELINE_NAME,
}

# Names counted only where they are used (called, wrapped in pcall, passed, or assigned),
# never in existence guards like `if C_CVar and C_CVar.SetCVar then`. Run on code with strings blanked.
USE_PATTERNS = {
    "CVAR": re.compile(r"\b(?:SetCVar(?:Bit[Ff]ield)?|ConsoleExec)\b|\bSettings\s*\.\s*SetValue\b"),
    "REGISTRY": re.compile(
        r"\b(?:EventRegistry|CVarCallbackRegistry)\b(?:\s*[.:]\s*[A-Za-z_]\w*)?"
        r"|\b(?:RegisterCallback|RegisterCallbackWithHandle|UnregisterCallback|TriggerEvent)\b"),
    "LOADADDON": re.compile(r"\b(?:UIParent)?LoadAddOn\b"),
    "PANELMGR": re.compile(r"\b(?:UpdateUIPanelPositions|FramePositionDelegate|SetUIPanelAttribute)\b"),
    "EDITMODE": re.compile(
        r"\b(?:SaveLayouts|SaveLayoutChanges|SetActiveLayout|SelectLayout|OnSystemSettingChange"
        r"|UpdateSystemAnchorInfo|MakeNewLayout|DeleteLayout|RenameLayout|RevertAllChanges|SetHasActiveChanges"
        r"|OnLayoutAdded|OnLayoutDeleted|SetAccountSetting)\b"),
}
REGISTRY_METHODS = re.compile(r"(?:RegisterCallback|RegisterCallbackWithHandle|UnregisterCallback|TriggerEvent)$")
# A client object calling a registry method: Upper.chain:Method
CLIENT_METHOD_OWNER = re.compile(r"[A-Z]\w*(?:\s*\.\s*\w+)*\s*:\s*$")
HOOK_RX = re.compile(r"\bhooksecurefunc\b")
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
    "CVAR": "CVar write outside Core/Settings.lua",
    "REGISTRY": "call on a client callback registry",
    "HOOK": "hooksecurefunc outside Core/Hooks.lua",
    "ONUPDATE": "OnUpdate script outside Core/Scheduler.lua",
    "LOADADDON": "client addon loaded from our code",
    "PANELMGR": "client window manager driven from our code",
    "EDITMODE": "edit mode layout write",
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
    __slots__ = ("keep", "blank", "has_comment", "comment_len", "nlines")


def lex(text):
    """Per line: code with strings kept, code with strings blanked, comment facts."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    keep, blank, has_c, clen = [[]], [[]], [False], [0]

    def newline():
        keep.append([])
        blank.append([])
        has_c.append(False)
        clen.append(0)

    def spread(seg, is_comment, blank_token):
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


def pattern_hits(path, lx):
    found = set()
    for rule, rx in USE_PATTERNS.items():
        if ALLOWED.get(rule) == path:
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
    if ALLOWED["HOOK"] != path:
        for no, line in enumerate(lx.blank, 1):
            if HOOK_RX.search(line):
                found.add(("HOOK", no))
    if ALLOWED["ONUPDATE"] != path:
        for no in onupdate_lines(lx):
            found.add(("ONUPDATE", no))
    return [(rule, no, MESSAGES[rule]) for rule, no in sorted(found, key=lambda h: (h[1], h[0]))]


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
                is_local = bool(re.search(r"\blocal\s+$", line[:m.start()]))
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
    bodies = {}
    for path, funcs in corpus_funcs.items():
        lx = corpus_lex[path]
        for start, end, name, is_local in funcs:
            if not is_local:
                continue
            body = [SPACES.sub("", lx.blank[k - 1]) for k in range(start + 1, end)]
            body = [b for b in body if b]
            if len(body) < DUPFN_MIN:
                continue
            key = hashlib.md5("\n".join(body).encode()).digest()
            bodies.setdefault(key, []).append((path, start, name, end))
    hits = {}
    for group in bodies.values():
        if len({g[0] for g in group}) < 2:
            continue
        for path, start, name, end in group:
            other = next(g for g in group if g[0] != path)
            hits.setdefault(path, []).append(
                ("DUPFN", start, "local function %s has the same body as %s:%d (%s)" % (name, other[0], other[1], other[2]), end))
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
        hits[p] = pattern_hits(p, lx) + size_hits(lx, funcs[p]) + comment_hits(lx)
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
