# renames.sh — sourced, not run: renames() prints the -D flags that give every class and every exported C symbol the
# object files define a RevenantHost prefix, so the backport and the system implementation can live side by side in one
# process. uikit2/run.sh and dynamics/run.sh build with it.
#
# It renames class names and C symbols, and nothing else. Those are whole identifiers, which is all a -D can rename:
# a -D applies to every occurrence of the name in the translation unit, and the port's sources include the SDK's.
# A selector is not a whole identifier — setObject:forTrait: is three of them — so renaming one of its pieces renames
# every unrelated use of that word too. Measured 2026-09-27 against the CommandLineTools 27 MacOSX SDK: renaming the
# `object` of a -setObject:forTrait: made os/object.h:222 declare @interface OS_revenantHostObject, while the use of the
# name in os/workgroup_base.h:44 sits behind a `, ## __VA_ARGS__` and is not expanded, so it still asked for OS_object,
# and every Objective-C source that includes dispatch stopped compiling with
#   os/workgroup_object.h:49: error: cannot find interface declaration for 'OS_object', superclass of 'OS_os_workgroup'
# — and, in the same file, every dictionary-subscript write with "expected method to write dictionary element not
# found". Isolating a selector is prefix_selectors.lua's work, which rewrites the whole selector in the source.
renames() {
    # $1: newline separated object files
    defined=$(nm -m $1 | grep -v '(undefined)')
    printf '%s\n' "$defined" | sed -n 's/.* external _OBJC_CLASS_\$_\(.*\)/-D\1=RevenantHost\1/p' | sort -u
    printf '%s\n' "$defined" | sed -n 's/.* external _\([A-Za-z_][A-Za-z0-9_]*\)$/\1/p' | grep -v '^OBJC_' | sort -u |
        awk '{ print "-D" $0 "=RevenantHost" $0 }'
}
