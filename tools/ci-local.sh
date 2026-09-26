#!/usr/bin/env bash
# Local mirror of .github/workflows/ci.yml: luacheck, TOC validation, conventions, offline tests.
# Runs every step, prints one line per step, exits nonzero when any step fails.
# LUACHECK=/path/to/luacheck, PYTHON=/path/to/python and LUA=/path/to/lua override the lookups.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

LOG_DIR="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/ci-local.$$")"
mkdir -p "$LOG_DIR"
trap 'rm -rf "$LOG_DIR"' EXIT

find_luacheck() {
    if [[ -n "${LUACHECK:-}" ]]; then echo "$LUACHECK"; return; fi
    if command -v luacheck >/dev/null 2>&1; then command -v luacheck; return; fi
    if [[ -n "${LOCALAPPDATA:-}" ]]; then
        local base="$LOCALAPPDATA"
        command -v cygpath >/dev/null 2>&1 && base="$(cygpath -u "$LOCALAPPDATA")"
        for cand in "$base/Programs/Lua/bin/luacheck.exe" "$base/Programs/Lua/bin/luacheck"; do
            if [[ -x "$cand" ]]; then echo "$cand"; return; fi
        done
    fi
}

find_python() {
    if [[ -n "${PYTHON:-}" ]]; then echo "$PYTHON"; return; fi
    for cand in python python3; do
        if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import sys" >/dev/null 2>&1; then
            echo "$cand"; return
        fi
    done
}

find_lua() {
    if [[ -n "${LUA:-}" ]]; then echo "$LUA"; return; fi
    if command -v lua >/dev/null 2>&1; then command -v lua; return; fi
    if [[ -n "${LOCALAPPDATA:-}" ]]; then
        local base="$LOCALAPPDATA"
        command -v cygpath >/dev/null 2>&1 && base="$(cygpath -u "$LOCALAPPDATA")"
        for cand in "$base/Programs/Lua/bin/lua.exe" "$base/Programs/Lua/bin/lua"; do
            if [[ -x "$cand" ]]; then echo "$cand"; return; fi
        done
    fi
}

step_luacheck() {
    local bin
    bin="$(find_luacheck)"
    if [[ -z "$bin" ]]; then
        echo "luacheck not found (set LUACHECK or put it on PATH)"
        return 1
    fi
    local files=()
    mapfile -t files < <(git ls-files '*.lua')
    "$bin" --no-color -q "${files[@]}"
}

# The CI job's loop, with shell builtins in place of its sed and tr (subshells are slow on Windows).
step_toc() {
    local exit_code=0 toc tocdir line filepath
    while IFS= read -r toc; do
        tocdir="$(dirname "$toc")"
        while IFS= read -r line; do
            line="${line%$'\r'}"
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^## ]] && continue
            filepath="$tocdir/${line//\\//}"
            if [[ ! -f "$filepath" ]]; then
                echo "FAIL: $filepath listed in $toc but does not exist"
                exit_code=1
            fi
        done < "$toc"
    done < <(git ls-files '*.toc')
    return $exit_code
}

step_conventions() {
    local py
    py="$(find_python)"
    if [[ -z "$py" ]]; then
        echo "python not found (set PYTHON or put it on PATH)"
        return 1
    fi
    "$py" tools/check.py --all
}

# Every tools/tests/*_test.lua; each exits nonzero on a failed check.
step_tests() {
    local bin status=0 t
    bin="$(find_lua)"
    if [[ -z "$bin" ]]; then
        echo "lua not found (set LUA or put it on PATH)"
        return 1
    fi
    for t in tools/tests/*_test.lua; do
        echo "== $t"
        "$bin" "$t" || status=1
    done
    return $status
}

FAILED=0
run_step() {
    local name="$1" fn="$2" log="$LOG_DIR/$2.log" start end status
    start=$(date +%s.%N 2>/dev/null || date +%s)
    "$fn" >"$log" 2>&1
    status=$?
    end=$(date +%s.%N 2>/dev/null || date +%s)
    local secs
    secs=$(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.1f", b - a }')
    if [[ $status -eq 0 ]]; then
        printf 'PASS  %-12s %ss\n' "$name" "$secs"
    else
        printf 'FAIL  %-12s %ss (exit %d)\n' "$name" "$secs" "$status"
        sed 's/^/      /' "$log"
        FAILED=1
    fi
}

run_step "luacheck" step_luacheck
run_step "toc" step_toc
run_step "conventions" step_conventions
run_step "tests" step_tests

if [[ $FAILED -ne 0 ]]; then
    echo "ci-local: FAILED"
    exit 1
fi
echo "ci-local: all steps passed"
