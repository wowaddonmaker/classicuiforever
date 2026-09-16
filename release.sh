#!/bin/bash
# =============================================================================
# ForeverClassicUI Release Script
# Creates a versioned release: changelog, zip, git tag, and GitHub release.
#
# Prerequisites:
#   - GitHub CLI (gh): winget install GitHub.cli
#   - Authenticated: gh auth login
#
# Usage:
#   ./release.sh           # Release version from .toc file
#   ./release.sh --dry-run # Preview without making changes
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE (no changes will be made) ==="
    echo
fi

# ── Preflight checks ────────────────────────────────────────────────────────

if ! command -v gh &>/dev/null; then
    echo "ERROR: GitHub CLI (gh) is not installed."
    echo "Install it with: winget install GitHub.cli"
    echo "Then authenticate: gh auth login"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "ERROR: Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

# ── Read version from .toc ──────────────────────────────────────────────────

VERSION=$(grep '## Version:' ForeverClassicUI.toc | sed 's/## Version:[[:space:]]*//')
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not read version from ForeverClassicUI.toc"
    exit 1
fi

TAG="v${VERSION}"
ADDON_NAME="ForeverClassicUI"
# Zip is written to curseforge_management/ at the workspace root so it lives
# alongside previously shipped releases instead of polluting the addon folder.
CURSEFORGE_ROOT="$(dirname "$SCRIPT_DIR")/curseforge_management"
ZIPNAME="${ADDON_NAME}-${VERSION}.zip"
ZIPPATH="${CURSEFORGE_ROOT}/${ZIPNAME}"

echo "Addon:   $ADDON_NAME"
echo "Version: $VERSION"
echo "Tag:     $TAG"
echo "Zip:     $ZIPPATH"
echo

# ── Check if tag/release already exists ─────────────────────────────────────

if git tag --list | grep -qx "$TAG"; then
    echo "ERROR: Tag $TAG already exists locally."
    echo "If you need to redo this release, delete it first:"
    echo "  git tag -d $TAG && git push origin :refs/tags/$TAG"
    exit 1
fi

if gh release view "$TAG" &>/dev/null; then
    echo "ERROR: GitHub release $TAG already exists."
    exit 1
fi

# ── Check for clean working tree ────────────────────────────────────────────

if [[ -n "$(git status --porcelain)" ]]; then
    echo "WARNING: You have uncommitted changes."
    echo "Releases should be created from a clean commit."
    read -rp "Continue anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 1
    fi
    echo
fi

# ── Step 1: Generate changelog ──────────────────────────────────────────────

echo "── Step 1/4: Generating changelog ──"

CHANGELOG_SCRIPT="$(dirname "$SCRIPT_DIR")/process_changelog.py"
if [[ ! -f "$CHANGELOG_SCRIPT" ]]; then
    echo "ERROR: process_changelog.py not found at $CHANGELOG_SCRIPT"
    exit 1
fi

CURSEFORGE_DIR="$(dirname "$SCRIPT_DIR")/curseforge_management/$ADDON_NAME"
CHANGELOG_FILE="$CURSEFORGE_DIR/${TAG}.md"

if $DRY_RUN; then
    echo "[dry-run] Would run: python \"$CHANGELOG_SCRIPT\" \"$SCRIPT_DIR\""
    echo "[dry-run] Output would go to: $CHANGELOG_FILE"
else
    python "$CHANGELOG_SCRIPT" "$SCRIPT_DIR"
fi

if ! $DRY_RUN && [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "ERROR: Changelog was not generated at $CHANGELOG_FILE"
    exit 1
fi

echo "Changelog ready: $CHANGELOG_FILE"
echo

# ── Step 2: Build zip ───────────────────────────────────────────────────────

echo "── Step 2/4: Building zip ──"

if $DRY_RUN; then
    echo "[dry-run] Would create: $ZIPPATH from tracked files"
    echo "[dry-run] Would package only ForeverClassicUI/ tracked files"
else
    mkdir -p "$CURSEFORGE_ROOT"
    python - "$ZIPPATH" <<'PY'
import subprocess
import sys
import zipfile

zip_path = sys.argv[1]
excluded_exact = {".gitignore", "release.sh", "README.md"}
excluded_prefixes = ("dev/", ".github/", "tools/", "docs/")
# media/ SHIPS (runtime textures), but never dev recordings
excluded_suffixes = (".mp4", ".mov", ".webm", ".avi", ".gif", ".psd")

raw = subprocess.check_output(["git", "ls-files", "-z"])
paths = [p.decode("utf-8") for p in raw.split(b"\0") if p]

with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in paths:
        if path in excluded_exact or path.startswith(excluded_prefixes):
            continue
        if path.lower().endswith(excluded_suffixes):
            continue

        arcname = "ForeverClassicUI/" + path

        data = subprocess.check_output(["git", "show", "HEAD:" + path])
        archive.writestr(arcname, data)

names = set(zipfile.ZipFile(zip_path).namelist())
required = {"ForeverClassicUI/ForeverClassicUI.toc"}
missing = required - names
if missing:
    print("ERROR: zip is missing required files: " + ", ".join(sorted(missing)))
    sys.exit(1)
PY

    echo "Created $ZIPPATH ($(du -h "$ZIPPATH" | cut -f1))"
fi
echo

# ── Step 3: Create and push git tag ─────────────────────────────────────────

echo "── Step 3/4: Creating git tag ──"

if $DRY_RUN; then
    echo "[dry-run] Would run: git tag -a $TAG -m \"Release $VERSION\""
    echo "[dry-run] Would run: git push origin $TAG"
else
    git tag -a "$TAG" -m "Release $VERSION"
    git push origin "$TAG"
    echo "Tag $TAG created and pushed."
fi
echo

# ── Step 4: Create GitHub release ───────────────────────────────────────────

echo "── Step 4/4: Creating GitHub release ──"

if $DRY_RUN; then
    echo "[dry-run] Would create GitHub release $TAG with:"
    echo "  - Notes from: $CHANGELOG_FILE"
    echo "  - Asset: $ZIPPATH"
else
    gh release create "$TAG" \
        --title "$ADDON_NAME $TAG" \
        --notes-file "$CHANGELOG_FILE" \
        "$ZIPPATH"

    echo "GitHub release created!"
fi
echo

# ── Done ────────────────────────────────────────────────────────────────────

echo "============================================"
if $DRY_RUN; then
    echo "  DRY RUN COMPLETE - no changes were made"
else
    echo "  Release $TAG complete!"
    echo
    echo "  GitHub: $(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "check github.com")"
    echo
    echo "  Next: Upload to CurseForge"
    echo "  Zip:       $ZIPPATH"
    echo "  Changelog: $CHANGELOG_FILE"
fi
echo "============================================"
