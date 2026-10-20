#!/bin/sh
# The host-probe rule (coordinator ruling, 2026-10-10) and the check that keeps it.
#
# A host CoreMIDI probe MAY create process-lifetime virtual sources and destinations and connect ports to them: the oracle
# needs it. It must NOT make anything persist:
#   - no MIDIDeviceCreate / MIDIExternalDeviceCreate that outlives the process;
#   - no MIDISetup* call;
#   - no MIDIObjectSetProperty* on an object the probe did not create;
#   - never MIDIRestart, never MIDIBluetoothDriverActivateAllConnections.
# Every probe run is bracketed by this check: the persistent MIDI preferences (the ByHost com.apple.MIDI.*.plist files and
# everything under ~/Library/Audio/MIDI Configurations) are hashed, read only, before and after, and the run fails when
# the two digests differ. A difference is reported with the files and the lines that differ (held in memory: nothing is
# copied), so that a change made by another process of the machine at the same moment can be told from one of the probe.
# The host's MIDI server re-serializes the file (same content, other bytes) while endpoints exist, and writes it back when
# they are gone: the digests are taken settled, and the after digest is waited for (see settled_digest and wait_for_digest). A
# file that is not back to the digest of before within 20 s is a change that persisted.
#
# Usage:
#   sh prefs-bracket.sh digest            print the digest of the persistent MIDI preferences
#   sh prefs-bracket.sh run <command...>  run the command between two digests; exit 1 when they differ, else the command's status
#   sh prefs-bracket.sh selftest          prove the check can fail: a stand-in home with a preference file is changed under it
# MIDI_PREFS_HOME names the home the preferences are read from (default $HOME); selftest makes its own stand-in home.
set -eu

home=${MIDI_PREFS_HOME:-$HOME}

# The files: the MIDI setup of this host and the saved configurations.
files() {
    root=${1:-$home}
    if [ -d "$root/Library/Preferences/ByHost" ]; then
        find "$root/Library/Preferences/ByHost" -type f -name 'com.apple.MIDI.*.plist' -print
    fi
    if [ -d "$root/Library/Audio/MIDI Configurations" ]; then
        find "$root/Library/Audio/MIDI Configurations" -type f -print
    fi
}

# One line per file: its hash and its path. A file that appears or disappears changes the listing.
listing() {
    files "$1" | LC_ALL=C sort | while IFS= read -r file; do
        printf '%s  %s\n' "$(shasum -a 256 < "$file" | cut -d' ' -f1)" "$file"
    done
}

digest() {
    listing "${1:-$home}" | shasum -a 256 | cut -d' ' -f1
}

# The text of each file, for the report of a difference (a property list is printed as plutil reads it).
texts() {
    files "$1" | LC_ALL=C sort | while IFS= read -r file; do
        printf '== %s\n' "$file"
        plutil -p "$file" || cat -v "$file"
    done
}

# The lines of $1 that $2 does not have, and the other way round.
differing_lines() {
    A="$1" B="$2" awk 'BEGIN {
        na = split(ENVIRON["A"], al, "\n"); nb = split(ENVIRON["B"], bl, "\n")
        for (i = 1; i <= na; i++) inA[al[i]] = 1
        for (i = 1; i <= nb; i++) inB[bl[i]] = 1
        for (i = 1; i <= na; i++) if (!(al[i] in inB)) print "  before only: " al[i]
        for (i = 1; i <= nb; i++) if (!(bl[i] in inA)) print "  after only:  " bl[i]
    }'
}

# The MIDI server of the host rewrites its preference file with another serialization (the same content, other bytes) when the
# endpoints of a process come and go, and writes it back a moment later; a process of another band does the same to it. So the
# digest is taken when it has been the same three times, a second apart (at most 15 s), before the run; and after the run it
# is waited for until it is the digest of before again (at most 20 s). A file that is still different then is a change that
# persisted, and fails the run. MIDI_PREFS_SETTLE=0 takes the digests at once.

settled_digest() {
    current=$(digest)
    if [ "${MIDI_PREFS_SETTLE:-1}" = 0 ]; then
        echo "$current"
        return 0
    fi
    same=1
    tries=0
    while [ "$same" -lt 3 ] && [ "$tries" -lt 15 ]; do
        sleep 1
        next=$(digest)
        if [ "$next" = "$current" ]; then same=$((same + 1)); else same=1; current=$next; fi
        tries=$((tries + 1))
    done
    echo "$current"
}

# Waits for the digest to be $1 again.
wait_for_digest() {
    waited=0
    while [ "$(digest)" != "$1" ] && [ "${MIDI_PREFS_SETTLE:-1}" != 0 ] && [ "$waited" -lt 20 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    return 0
}

run() {
    before=$(settled_digest)
    before_listing=$(listing "$home")
    before_text=$(texts "$home")
    status=0
    "$@" || status=$?
    wait_for_digest "$before"
    after=$(digest)
    if [ "$before" != "$after" ]; then
        echo "prefs-bracket: the persistent MIDI preferences changed during the run (before $before, after $after)" >&2
        differing_lines "$before_listing" "$(listing "$home")" >&2
        differing_lines "$before_text" "$(texts "$home")" >&2
        exit 1
    fi
    echo "prefs-bracket: the persistent MIDI preferences are byte-identical before and after ($after)"
    return "$status"
}

selftest() {
    here=$(cd "$(dirname "$0")" && pwd)
    . "$here/../../common/runs.sh" "$here"
    area=${MIDI_PREFS_SELFTEST_DIR:-$(runs_folder prefs-bracket-selftest)}
    rm -rf "$area"
    mkdir -p "$area/Library/Preferences/ByHost" "$area/Library/Audio/MIDI Configurations"
    printf 'one\n' > "$area/Library/Preferences/ByHost/com.apple.MIDI.TEST.plist"
    printf 'cfg\n' > "$area/Library/Audio/MIDI Configurations/Setup.plist"
    a=$(digest "$area")
    b=$(digest "$area")
    printf 'two\n' > "$area/Library/Preferences/ByHost/com.apple.MIDI.TEST.plist"
    c=$(digest "$area")
    printf 'cfg\n' > "$area/Library/Audio/MIDI Configurations/Other.plist"
    d=$(digest "$area")
    # The run: a change that persists fails it, and one the server writes back within the wait does not.
    home=$area
    file="$area/Library/Preferences/ByHost/com.apple.MIDI.TEST.plist"
    persisted=pass
    if (MIDI_PREFS_SETTLE=0 run sh -c 'printf changed > "$1"' sh "$file") > /dev/null 2>&1; then persisted=missed; fi
    printf 'two\n' > "$file"
    transient=fail
    if run sh -c '(sleep 2; printf "two\n" > "$1") & printf changed > "$1"' sh "$file" > /dev/null 2>&1; then transient=pass; fi
    rm -rf "$area"
    if [ "$persisted" != pass ] || [ "$transient" != pass ]; then
        echo "prefs-bracket: selftest FAILED (a persisted change is $persisted: failed the run $([ "$persisted" = pass ] && echo yes || echo no); a change written back within the wait passes $transient)" >&2
        exit 1
    fi
    if [ "$a" != "$b" ] || [ "$a" = "$c" ] || [ "$c" = "$d" ]; then
        echo "prefs-bracket: selftest FAILED (same $([ "$a" = "$b" ] && echo yes || echo no), changed file seen $([ "$a" != "$c" ] && echo yes || echo no), new file seen $([ "$c" != "$d" ] && echo yes || echo no))" >&2
        exit 1
    fi
    echo "prefs-bracket: selftest ok (an unchanged tree keeps its digest; a changed and an added file change it; a persisted change fails a run and one written back within the wait does not)"
}

case "${1:-}" in
    digest) digest ;;
    run) shift; run "$@" ;;
    selftest) selftest ;;
    *) echo "usage: prefs-bracket.sh digest | run <command...> | selftest" >&2; exit 2 ;;
esac
