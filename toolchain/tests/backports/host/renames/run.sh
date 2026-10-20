#!/bin/sh
# run.sh — what tests/backports/host/uikit2/renames.sh is allowed to do. The differential compiles the backport's
# sources into the same process as the framework they sit beside, so the port's names have to move: renames()
# gives a RevenantHost prefix to the classes and C symbols the objects define, and prefix_selectors.py gives one to
# the selectors the port's Revenant categories carry, whole.
#
# A -D can only rename a whole identifier, so only a class name and a C symbol may be renamed that way. A selector
# is not one: setObject:forTrait: is three of them, and a -D for the `object` in it renames every other use of that
# word in the file, the SDK's included. This test pins both halves of the rule - renames() renames no piece of a
# selector, and it still renames the class and the C symbol - and then checks what broke: the flags leave a file
# that includes Foundation and writes a dictionary element compiling. With -Dobject= the SDK's os/object.h declares
# @interface OS_object under the new name while os/workgroup_base.h, whose use of it sits behind a `, ## __VA_ARGS__`
# and is not expanded, still asks for OS_object, so os/workgroup_object.h:49 fails and every source that includes
# dispatch stops compiling.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${RENAMES_BUILD:-$(runs_folder revenant-renames-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
flags="-DREVENANT_HOST_DIFFERENTIAL=1 -fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new"
. "$here/../uikit2/renames.sh"

checks=0
failures=0
check() {
    checks=$((checks + 1))
    if [ "$1" = "$2" ]; then
        printf 'ok %d - %s\n' "$checks" "$3"
    else
        failures=$((failures + 1))
        printf 'FAIL %d - %s\n  expected: %s\n  got:      %s\n' "$checks" "$3" "$1" "$2"
    fi
}
present() { grep -q -- "$1" "$2" && echo yes || echo no; }

rm -rf "$build"
mkdir -p "$build"
xcrun clang $target $flags -w -c "$here/probe.m" -o "$build/probe.o"
renames "$build/probe.o" > "$build/flags"
printf 'note %d defines: %s\n' "$(grep -c . "$build/flags")" "$(tr '\n' ' ' < "$build/flags")"

# every piece of every selector the object defines
nm "$build/probe.o" | sed -n 's/.*[-+]\[[A-Za-z_]*(*[A-Za-z]*)* \([A-Za-z_][A-Za-z0-9_:]*\)\]$/\1/p' |
    tr ':' '\n' | sort -u > "$build/pieces"
# every name renames() printed a define for
sed -n 's/^-D\([^=]*\)=.*/\1/p' "$build/flags" | sort -u > "$build/renamed"
check "" "$(comm -12 "$build/pieces" "$build/renamed" | tr '\n' ' ')" "renames() renames no piece of a selector"

# the port's own class and C function are still renamed, or the differential would link against the framework's
check "RevenantHostRevenantRenamesProbe" "$(sed -n 's/^-DRevenantRenamesProbe=//p' "$build/flags")" "the probe's class is renamed"
check "RevenantHostrevenant_renames_probe_value" "$(sed -n 's/^-Drevenant_renames_probe_value=//p' "$build/flags")" "the probe's C function is renamed"
check "" "$(sed -n 's/^-DNSString=//p' "$build/flags")" "a category does not rename the class it adds to"

# the flags leave a file that includes Foundation and writes a dictionary element compiling
cat > "$build/subscript.m" <<'EOF'
#import <Foundation/Foundation.h>
int main(void)
{
    @autoreleasepool {
        NSMutableDictionary *extras = [NSMutableDictionary dictionary];
        NSString *name = @"key";
        id value = @(1);
        extras[name] = value;
        return (int)[extras count];
    }
}
EOF
if xcrun clang $target $flags $(cat "$build/flags") -w -c "$build/subscript.m" -o "$build/subscript.o" 2> "$build/subscript.err"; then
    check yes yes "a dictionary-subscript write compiles under the renamer's flags"
else
    check yes no "a dictionary-subscript write compiles under the renamer's flags"
    sed 's/^/    /' "$build/subscript.err"
fi

# and the probe's own sources still build under them, renamed
if xcrun clang $target $flags $(cat "$build/flags") -w -c "$here/probe.m" -o "$build/probe.renamed.o" 2> "$build/probe.err"; then
    check yes yes "the probe's own sources build under the renamer's flags"
else
    check yes no "the probe's own sources build under the renamer's flags"
    sed 's/^/    /' "$build/probe.err"
fi

# the whole-selector renamer does what renames() must not: a category's selector prefixed whole, with the
# identifiers inside the selector left as they are
runs_xmake l "$here/../prefix_selectors.lua" "$here/probe.m" "$build/probe.renamed.m" charonHost \
    --declarations="$build/declarations.h" $flags -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -- "$build/probe.o"
check yes "$(present 'revenantHostProbeOf:(id)object forKey:(id)key' "$build/probe.renamed.m")" "the category's two-piece selector is prefixed whole"
check yes "$(present 'revenantHostProbeOf:(__strong id)object forKey:(__strong id)key' "$build/declarations.h")" "and declared prefixed, whole"
check no "$(present '-D' "$build/declarations.h")" "the declarations are method declarations, not -D defines"
check yes "$(present '(id)setObject:(id)object forTrait:(id)trait' "$build/probe.renamed.m")" "the port class's own selector is left alone, its class is renamed instead"
check yes "$(present '- (id)extra;' "$build/probe.renamed.m")" "a category on the port class's own member is left alone too"
check no "$(present 'revenantHostExtra' "$build/probe.renamed.m")" "and is not prefixed: the class rename already keeps it apart"
check no "$(present 'revenantHostExtra' "$build/declarations.h")" "so no prefixed declaration of it is emitted"

# and the check above has teeth: a -D for the `object` of a selector does break that same file
if xcrun clang $target $flags -Dobject=revenantHostObject -DsetObject=setRevenantHostObject -w -c "$build/subscript.m" -o "$build/broken.o" 2> "$build/broken.err"; then
    check yes no "a -D for a selector piece does break the same file"
    note "the control did not break, so check 5 proves nothing on this SDK"
else
    check yes yes "a -D for a selector piece does break the same file"
    grep -m2 'error:' "$build/broken.err" | sed 's/^/    /'
fi

# and the check every differential wants runs over what it built: a test that names a renamed selector no
# object defines would be an unrecognized selector at run time, with nothing in the gate to see it
cat > "$build/undefined.m" <<'EOF'
#import <UIKit/UIKit.h>
@interface UIView (RevenantUndefined)
- (NSInteger)revenantHostCount;
@end
int main(void)
{
    @autoreleasepool {
        return (int)[[UIView new] revenantHostCount];
    }
}
EOF
if xcrun clang $target $flags -w -c "$build/undefined.m" -o "$build/undefined.o"; then
    if runs_xmake l "$here/../check-private-selectors.lua" "$build/undefined.o" "$build/probe.renamed.o" > "$build/private.log" 2>&1; then
        check yes no "a test naming a renamed selector no object defines is refused"
        sed 's/^/    /' "$build/private.log"
    else
        check yes yes "a test naming a renamed selector no object defines is refused"
        grep -m1 '^FAIL' "$build/private.log" | cut -c1-120 | sed 's/^/    /'
    fi
    if runs_xmake l "$here/../check-private-selectors.lua" "$build/probe.renamed.o" "$build/probe.renamed.o" > "$build/private2.log" 2>&1; then
        check yes yes "a test naming only what the objects define passes"
    else
        check yes no "a test naming only what the objects define passes"
        sed 's/^/    /' "$build/private2.log"
    fi
else
    check yes no "the probe of a renamed selector nobody defines compiles"
fi

printf 'checks=%d failures=%d\n' "$checks" "$failures"
[ "$failures" = 0 ]
