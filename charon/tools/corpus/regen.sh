#!/bin/zsh
# regen.sh <batch-label>   e.g. regen.sh 787f291
# One command per registry-export ping. Order matters: the previous list must be saved
# BEFORE regenerating, and the hint ledger read AFTER, or the hint outcomes are lost.
set -e
T="${0:A:h}"          # neighbor scripts (crash-demand.lua etc.) sit beside this one, wherever it is copied to
# corpus/ is DATA, in the durable location CHARON_CORPUS_ROOT addresses (default coordination/),
# independent of this script's own location (same CORPUS the tools resolve internally --
# must agree with them, or this script's own cp lines silently touch the wrong directory).
CORPUS_ROOT="${CHARON_CORPUS_ROOT:-$HOME/Git/projects/ios/coordination}"
CORPUS="$CORPUS_ROOT/corpus"
[ -d "$CORPUS" ] || { echo "regen.sh: no corpus/ data directory found at $CORPUS. Set CHARON_CORPUS_ROOT."; exit 1; }
# The registry export: CHARON_REGISTRY_TSV, else this checkout's run folder (the same default as aggregate.lua).
F="${CHARON_REGISTRY_TSV:-$T/../../.agent-work/runs/registry-export/carried-registry.tsv}"
echo "registry export: $(ls -la $F | awk '{print $6,$7,$8}')  rows: $(wc -l < $F)"
cp "$CORPUS/crash-demand-top.tsv" "$CORPUS/crash-demand-prev.tsv"
xmake l "$T/crash-demand.lua" | sed -n 1,3p
xmake l "$T/hint-track.lua" "${1:-$(date +%F)}"
cp "$F" "$CORPUS/registry-last.tsv"      # baseline for the next run; hint-track has already read the old one
