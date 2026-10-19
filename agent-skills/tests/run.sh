#!/bin/bash
# Runs psychopomp scenarios on a clean machine: for each one, an empty project directory outside
# any repository, a fresh HOME in which only this plugin is installed (from a clone of hades
# at HEAD), the scenario's answers.md, and an agent run headless on request.md.
# tests/check.sh then decides whether the run counts. Evidence is copied to
# $HOME/.cache/hades/psychopomp/<run>/<scenario>/.
#
# Usage: tests/run.sh [--runtime claude] [--hours N] SCENARIO... | all
#
# Shared state, deliberately not isolated: the xmake package store (XMAKE_GLOBALDIR points at the
# real home, so ~/.xmake is the one every project uses and nothing is rebuilt privately) and
# Charon's firmware, dyld caches and emulator images (CHARON_HOME). A guard on PATH refuses
# `xmake emulate clean` and `--force`, which would damage that shared state.
#
# Login: the agent's own login is copied from the login keychain into the scenario's HOME as
# .claude/.credentials.json (only the Claude login, mode 600). The HOME is removed right after the
# scenario and by a trap on any exit; the evidence is scanned for the token before that. A scenario
# is capped to the access token's remaining lifetime so the copy never refreshes it: a refresh from
# the copy could rotate the refresh token under the real login.
set -euo pipefail

runtime=claude hours=6 scenarios=()
while [ $# -gt 0 ]; do
  case $1 in
    --runtime) runtime=$2; shift 2 ;;
    --hours) hours=$2; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) scenarios+=("$1"); shift ;;
  esac
done
repo=$(cd "$(dirname "$0")/.." && pwd)
top=$(git -C "$repo" rev-parse --show-toplevel)
cache=$HOME/.cache/hades/psychopomp
[ ${#scenarios[@]} -gt 0 ] || { echo "name a scenario, or all" >&2; exit 2; }
[ "${scenarios[0]}" = all ] && scenarios=($(ls "$repo/tests/scenarios"))

# The isolation was approved by the owner; the variable keeps an accidental run from starting it.
if [ "${PSYCHOPOMP_ISOLATION_APPROVED:-}" != 1 ]; then
  echo "refused: set PSYCHOPOMP_ISOLATION_APPROVED=1 to run with the approved isolation" >&2
  exit 3
fi

git -C "$top" diff --quiet HEAD -- || { echo "commit first: the plugin is installed from HEAD" >&2; exit 2; }
commit=$(git -C "$repo" rev-parse --short HEAD)
run=$(date +%Y%m%d-%H%M%S)-$commit
evidence_root=$cache/$run
mkdir -p "$cache"
scratch=$(mktemp -d "$cache/scratch.XXXXXX")
scratch=$(cd "$scratch" && pwd -P)
case $scratch in "$(cd "$top" && pwd -P)"/*) echo "scratch $scratch is inside hades" >&2; exit 2 ;; esac
mkdir -p "$evidence_root"
echo "run $run, scratch $scratch"

real_home=$HOME
brew_prefix=$(brew --prefix 2>/dev/null || echo /opt/homebrew)
xmake_bin=$(command -v xmake)
tests_dir=$(cd "$(dirname "$0")" && pwd)

# The plugin cloned at HEAD, and the guard in front of xmake. Each scenario gets its own HOME.
clone=$scratch/hades plugin=$scratch/hades/psychopomp guard=$scratch/guard
mkdir -p "$guard"
homes=()
cleanup() { local h; for h in "${homes[@]+"${homes[@]}"}"; do rm -rf "$h"; done; }
trap cleanup EXIT INT TERM HUP
git clone -q "$top" "$clone" && git -C "$clone" checkout -q "$commit"
cat > "$guard/xmake" <<EOF
#!/bin/bash
for a in "\$@"; do [ "\$a" = --force ] && { echo "refused by the test guard: --force damages the shared store" >&2; exit 97; }; done
[ "\${1:-}" = emulate ] && printf ' %s' "\$@" | grep -q ' clean' && { echo "refused by the test guard: emulate clean wipes shared emulator state" >&2; exit 97; }
exec "$xmake_bin" "\$@"
EOF
chmod +x "$guard/xmake"

# A fresh HOME holding only the Claude login, mode 600. Sets home, vars, and left (seconds the
# access token has left).
fresh_home() {
  home=$1; homes+=("$home"); mkdir -p "$home/.claude"; chmod 700 "$home"
  vars=(HOME="$home" USER="$USER" LOGNAME="$USER" SHELL=/bin/zsh LANG=en_US.UTF-8 TERM=xterm-256color
        TMPDIR="$scratch/tmp" PATH="$guard:$brew_prefix/bin:$brew_prefix/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        XMAKE_GLOBALDIR="$real_home" CHARON_HOME="$real_home/.charon")
  (umask 077; security find-generic-password -s "Claude Code-credentials" -w |
    "$xmake_bin" l "$tests_dir/credentials.lua" store "$home/.claude/.credentials.json")
  left=$("$xmake_bin" l "$tests_dir/credentials.lua" left "$home/.claude/.credentials.json")
}
# The exact token strings, to prove none reached the evidence.
leaked() {
  "$xmake_bin" l "$tests_dir/credentials.lua" leaked "$home/.claude/.credentials.json" "$1"
}
clean_env() { env -i "${vars[@]}" "$@"; }
mkdir -p "$scratch/tmp"

case $runtime in
  claude) ;;
  *) echo "runtime $runtime: not supported yet" >&2; exit 2 ;;
esac
# Install the plugin into a HOME with nothing else in it, the way a user would.
install_plugin() {
  clean_env claude plugin marketplace add "$clone" > "$1" 2>&1
  clean_env claude plugin install psychopomp@hades --scope user >> "$1" 2>&1
  clean_env claude plugin list >> "$1" 2>&1
  grep -q psychopomp "$1" || { echo "the plugin did not install; see $1" >&2; return 1; }
  local d
  for d in .claude/skills .agents/skills .codex .config/opencode; do
    [ ! -e "$home/$d" ] || { echo "the clean HOME already has $d" >&2; return 1; }
  done
}
agent=(claude -p --permission-mode bypassPermissions --output-format stream-json --verbose)

status=0
for id in "${scenarios[@]}"; do
  sc=$repo/tests/scenarios/$id
  [ -f "$sc/request.md" ] || { echo "no scenario $id" >&2; status=1; continue; }
  project=$scratch/projects/$id evidence=$evidence_root/$id
  mkdir -p "$project" "$evidence"
  fresh_home "$scratch/home-$id"
  limit=$((hours * 3600)); [ $((left - 900)) -lt $limit ] && limit=$((left - 900))
  if [ $limit -lt 3600 ]; then
    echo "$id: the login expires in $((left / 60)) min; start again after it is refreshed" >&2
    rm -rf "$home"; status=1; continue
  fi
  install_plugin "$evidence/install.log" || { rm -rf "$home"; status=1; continue; }
  cp "$sc/answers.md" "$project/answers.md"
  echo "== $id: agent running (up to $((limit / 60)) min)"
  ( cd "$project" && perl -e 'alarm shift; exec @ARGV' $limit \
      env -i "${vars[@]}" "${agent[@]}" "$(cat "$sc/request.md")" ) \
      > "$evidence/transcript.jsonl" 2> "$evidence/agent.stderr" || echo "agent exited $?" >> "$evidence/agent.stderr"
  # Evidence: the project without build products, its logs, and its packages.
  rsync -a --exclude build --exclude .xmake "$project/" "$evidence/project/"
  find "$project/build" -maxdepth 3 -name '*.deb' -exec cp {} "$evidence/" \; 2>/dev/null || true
  hits=$(leaked "$evidence")
  if [ -n "$hits" ]; then
    printf '%s\n' "$hits" | while read -r f; do rm -f "$f"; done
    echo "FAIL  the login token reached the evidence; removed: $hits" | tee -a "$evidence/check.txt"; status=1
  fi
  rm -rf "$home"
  "$repo/tests/check.sh" "$project" "$sc" "$plugin" "$evidence" | tee -a "$evidence/check.txt" || status=1
done
echo "evidence in $evidence_root; scratch kept at $scratch"
exit $status
