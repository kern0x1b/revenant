#!/bin/zsh
# scan-app.sh <app-name> <path-to-.app>
# Gathers every Mach-O in the bundle (main + embedded frameworks + appex),
# runs corpus-scan.lua vs stock iOS 6.0, and ingests the classified demand.
set -e
NAME="$1"; APP="$2"
TOOLS="${0:A:h}"                      # neighbor scripts (corpus-scan.lua, aggregate.lua) sit beside this one
# corpus/ is DATA, in the durable location CHARON_CORPUS_ROOT addresses (default coordination/),
# independent of this script's own location. See tools/corpus/README.md.
CORPUS_ROOT="${CHARON_CORPUS_ROOT:-$HOME/Git/projects/ios/coordination}"
CORPUS="$CORPUS_ROOT/corpus"
[ -d "$CORPUS" ] || { echo "scan-app.sh: no corpus/ data directory found at $CORPUS. Set CHARON_CORPUS_ROOT."; exit 1; }
# CHARON_ROOT only needs a charon checkout's modules/apple/dyld.lua -- any current worktree
# supplies it, it is not tied to one specific worktree. Was hardcoded to
# .claude/worktrees/priceless-kepler-a7622c, a dead worktree removed since; every run would have
# failed the moment xmake tried to import a module rooted there. Same CHARON_*_DIR-first,
# then-real-candidates pattern as everywhere else, so a future worktree move doesn't repeat this.
WT="${CHARON_ROOT_DIR:-}"
if [ -z "$WT" ] || [ ! -d "$WT/modules" ]; then
  for c in "$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)" "$HOME/Git/projects/ios/charon"; do
    if [ -d "$c/modules" ]; then WT="$c"; break; fi
  done
fi
if [ -z "$WT" ] || [ ! -d "$WT/modules" ]; then
  echo "scan-app.sh: no charon checkout with modules/ found. Set CHARON_ROOT_DIR." >&2
  exit 1
fi
OUT="$CORPUS/$NAME.scan.tsv"

# collect Mach-O binaries (arm64 slices; skip resources)
bins=()
while IFS= read -r f; do
  if file "$f" | grep -q 'Mach-O'; then bins+=("$f"); fi
done < <(find "$APP" -type f ! -name '*.png' ! -name '*.plist' ! -name '*.nib' ! -name '*.car' ! -name '*.json' ! -name '*.strings' 2>/dev/null)

echo "[$NAME] ${#bins[@]} Mach-O binaries under bundle"
CHARON_ROOT="$WT" xmake l "$TOOLS/corpus-scan.lua" 6.0 "${bins[@]}" > "$OUT" 2>"$CORPUS/$NAME.scan.err" || {
  echo "scan failed; see $CORPUS/$NAME.scan.err"; tail "$CORPUS/$NAME.scan.err"; exit 1; }
# ingest reads the bundle, not the scan: $OUT is the scan TSV, and a file has no Mach-O under it, so ingesting
# $OUT stored every app with zero binaries and zero demand.
xmake l "$TOOLS/aggregate.lua" ingest "$NAME" "$APP"
