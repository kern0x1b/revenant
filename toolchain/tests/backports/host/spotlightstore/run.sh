#!/bin/sh
# run.sh - builds the port's CoreSpotlight sources on the host, with REVENANT_SPOTLIGHT_SHARED_ROOT moved into the build directory, and
# runs store.m against them: a write refused by the file system (the store's directory without write permission) and a write allowed
# after it. The host's own CoreSpotlight.framework is not linked, only its headers are read, so the classes are the port's.
# search.m does the same with the search bundle's RevenantSearchDatastore.m added, reading a store into which entries no indexing
# application would write have been put. Then mutants of the rollback, the cause and the reading, which the checks must tell apart.
set -eu
echo "FAIL host/spotlightstore/run.sh: its Python steps are gone and not yet ported to Lua: mutate.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
spotlight=${SPOTLIGHT:-$here/../../../../packages/frameworks/apple-backports/CoreSpotlight}
build=${SPOTLIGHTSTORE_BUILD:-$(runs_folder revenant-spotlightstore-host)}

run() {
    dir=$1
    root="$dir/root"
    sed "s|^#define REVENANT_SPOTLIGHT_SHARED_ROOT .*|#define REVENANT_SPOTLIGHT_SHARED_ROOT @\"$root\"|" "$spotlight/RevenantSpotlightStore.h" > "$dir/RevenantSpotlightStore.h"
    grep -q "$root" "$dir/RevenantSpotlightStore.h"
    # The host's headers declare what later releases added; the port's sources are built as the package builds them, not held to those.
    for source in "$dir"/*.m; do xcrun clang -fobjc-arc -w -I"$dir" -c "$source" -o "$source.o" || return 1; done
    xcrun clang -fobjc-arc -Wall -Werror "$here/store.m" "$dir"/*.m.o -framework Foundation -o "$dir/store" || return 1
    # A binary without a bundle identifier keeps its store in the port's default directory.
    mkdir -p "$root/space.kern0x1b.corespotlight.default"
    chmod 555 "$root/space.kern0x1b.corespotlight.default"
    # Called from an if, run() is not stopped by set -e: each step ends it itself.
    "$dir/store" "$root/space.kern0x1b.corespotlight.default/store.plist" || return 1
    # The bundle is built against the same root; the install folder it dlopen()s the port from is not there on the host, which it logs.
    xcrun clang -fobjc-arc -w -I"$dir" -DREVENANT_BACKPORTS_INSTALL_FOLDER='"/nonexistent"' -c "$dir/SearchBundle/RevenantSearchDatastore.m" -o "$dir/SearchBundle/bundle.o" || return 1
    # search.m archives the way the port does and the release did, with the API iOS 6 has.
    xcrun clang -fobjc-arc -Wall -Werror -Wno-deprecated-declarations "$here/search.m" "$dir"/*.m.o "$dir/SearchBundle/bundle.o" -framework Foundation -o "$dir/search" || return 1
    rm -rf "$root"
    mkdir -p "$root/space.kern0x1b.corespotlight.default"
    "$dir/search" "$root" "$dir/search.log" || { status=$?; cat "$dir/search.log"; return $status; }
}

sources() {
    mkdir -p "$1/SearchBundle"
    cp "$spotlight"/*.m "$1/"
    cp "$spotlight/SearchBundle/RevenantSearchDatastore.m" "$1/SearchBundle/"
}

rm -rf "$build"
sources "$build/port"
run "$build/port"

survived=0
mutant() {
    file=$1; from=$2; to=$3
    rm -rf "$build/mutant"; sources "$build/mutant"
    python3 "$here/../contacts/mutate.py" "$build/mutant/$file" "$from" "$to"
    if run "$build/mutant" > "$build/mutant.log" 2>&1; then echo "MUTANT SURVIVED: $from -> $to"; survived=$((survived + 1))
    # A mutant that does not build proves nothing about the checks.
    elif grep -q 'uncaught exception' "$build/mutant.log"; then echo "killed: the reading raised what it should have logged"
    elif ! grep -q '^FAIL' "$build/mutant.log"; then echo "MUTANT DID NOT RUN: $from -> $to"; survived=$((survived + 1))
    else echo "killed: $(grep '^FAIL' "$build/mutant.log" | head -1 | cut -c1-100)"; fi
}
mutant CSSearchableIndex.m "    if (error) {
        _entries = entries;" "    if (NO) {
        _entries = entries;"
mutant CSSearchableIndex.m "        info[NSUnderlyingErrorKey] = cause;" ";"
mutant CSSearchableIndex.m "[data writeToFile:path options:NSDataWritingAtomic error:&cause]" "[data writeToFile:path atomically:YES]"
mutant SearchBundle/RevenantSearchDatastore.m "if (![archived isKindOfClass:[NSData class]]) {" "if (NO) {"
mutant SearchBundle/RevenantSearchDatastore.m "NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archived];" "NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archived]; if (!unarchiver) continue;"
mutant SearchBundle/RevenantSearchDatastore.m "if (![entries isKindOfClass:[NSDictionary class]]) {" "if (NO) {"
mutant SearchBundle/RevenantSearchDatastore.m "if (![item isKindOfClass:itemClass]) {" "if (!item) {"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
