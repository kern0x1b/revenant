#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
output=$(mktemp "$(runs_folder revenant-session)/output.XXXXXX")
python3 "$here/server.py" 0 > "$output" 2>&1 &
server=$!
trap 'kill $server 2>/dev/null; rm -f "$output"' EXIT
while ! grep -q '^port ' "$output"; do sleep 0.1; done
port=$(awk '/^port /{print $2}' "$output")
status=0
"$@" "$port" || status=$?
exit $status
