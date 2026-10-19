#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
usage="usage: run.sh [--mutants]"
mutants=no
if [ "${1:-}" = --mutants ]; then
    mutants=yes
    shift
fi
[ $# -eq 0 ] || { echo "$usage" >&2; exit 2; }
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$here/../../../../.agent-work/runs/bundlerequest}
export BUILD
sources=${SOURCES:-$(cat "$here/sources.txt")}
# SAN=1 adds AddressSanitizer, which names the file, the line and the access where lldb only gives a
# frame; it is a debugging build of this test, not a mode the house runner needs.
sanitize=""
if [ "${SAN:-}" = 1 ]; then
    sanitize="-fsanitize=address -fno-omit-frame-pointer -g"
fi
quiet="-Werror=format -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers -Wno-nonnull"

if [ $mutants = yes ]; then
    missed=0
    caught=0
    tab=$(printf '\t')
    mutant=$BUILD-mutant
    device=0
    while IFS="$tab" read -r name file change mark; do
        # a comment, or anything without the three fields, is not a mutant: the counts below are of
        # the rows the file holds, and a comment must not be read as one
        case "$name" in ''|\#*) continue;; esac
        [ -n "$change" ] || continue
        if [ "$mark" = device ]; then
            # A row marked device-only is not run here, and the mark may not hide a stale row or a
            # real gap: its change is applied to a copy and must still apply, or the row is reported.
            rm -rf "$mutant"; mkdir -p "$mutant/Foundation"
            cp -R "$FOUNDATION"/ "$mutant/Foundation/"
            perl -0pi -e "$change" "$mutant/Foundation/$file"
            if cmp -s "$FOUNDATION/$file" "$mutant/Foundation/$file"; then
                echo "MISSED $name: marked device-only, and its change no longer applies"
                missed=$((missed + 1))
            else
                device=$((device + 1))
                echo "device-only: $name (not run in this process)"
            fi
            continue
        fi
        rm -rf "$mutant"
        mkdir -p "$mutant/Foundation"
        cp -R "$FOUNDATION"/ "$mutant/Foundation/"
        perl -0pi -e "$change" "$mutant/Foundation/$file"
        if cmp -s "$FOUNDATION/$file" "$mutant/Foundation/$file"; then
            echo "STALE $name: the change no longer applies"
            missed=$((missed + 1))
            continue
        fi
        if FOUNDATION="$mutant/Foundation" BUILD="$mutant/build" sh "$here/run.sh" > "$mutant.log" 2>&1; then
            echo "MISSED $name"
            missed=$((missed + 1))
        elif grep -q ' error: ' "$mutant.log"; then
            echo "BROKEN $name: the mutant does not compile"
            missed=$((missed + 1))
        elif grep -q '^FAIL ' "$mutant.log"; then
            caught=$((caught + 1))
            echo "caught $name: $(grep '^FAIL ' "$mutant.log" | head -1 | cut -c6- | cut -d: -f1)"
        else
            caught=$((caught + 1))
            echo "caught $name: the port crashed"
        fi
    done < "$here/mutants/bundlerequest.txt"
    rm -rf "$mutant" "$mutant.log"
    # The file must end in a newline and every row must be read: without this a dropped last line
    # looks exactly like a file with one fewer mutant, and nothing said so.
    host_rows=$(grep -c "	" "$here/mutants/bundlerequest.txt")
    host_rows=$((host_rows - device))
    seen=$((caught + missed))
    if [ "$seen" -ne "$host_rows" ]; then
        echo "MISSED the runner read $seen of the file's $host_rows host rows: check that it ends in a newline"
        missed=$((missed + 1))
    fi
    if [ "$missed" -ne 0 ]; then
        echo "$missed of the host rows went the wrong way"
    fi
    echo "$caught caught of $host_rows host rows, $device device-only"
    # the count, not the count as an exit status: 256 rows going the wrong way would exit 0
    [ "$missed" -eq 0 ] || exit 1
fi

rm -rf "$BUILD/plain" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/renamed"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $sanitize -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/plain/$source.o"
done
# The class and the two keys are the port's API and the host's are the real ones, so the port's are
# renamed. The category on NSBundle is not: NSBundle is the release's own class and both the host's
# additions and the port's attach to it, which is what lets the test ask each of them.
renames="-DNSBundleResourceRequest=CharonHostNSBundleResourceRequest"
for name in NSBundleResourceRequestLoadingPriorityUrgent NSBundleResourceRequestLowDiskSpaceNotification; do
    renames="$renames -D$name=CharonHost$name"
done
echo "renamed:$renames"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet $sanitize $renames -I"$FOUNDATION" -c "$FOUNDATION/$source" -o "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $quiet $sanitize "$here/differential.m" "$BUILD"/renamed/*.o -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
