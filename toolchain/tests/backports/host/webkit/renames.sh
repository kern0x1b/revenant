# renames.sh — sourced, not run: renames() prints the -D flags that give the port's own classes and C symbols a
# CharonHost prefix, so the port and the system's WebKit can live side by side in one process. This is
# uikit2's renames.sh, kept beside the test that uses it, with one thing changed and the change forced by
# measurement.
#
# uikit2's version reads the class names out of the compiled objects, from _OBJC_CLASS_$_ symbols. That
# works there because those sources ADD categories to classes the system owns, so the port defines nothing.
# This family's sources do the opposite: each of them IMPLEMENTS a class the system also declares, so with
# -DCHARON_HOST_DIFFERENTIAL the port's own header steps aside and clang matches the SDK's @interface.
# Measured over the objects run.sh itself builds: pass one emits eight _OBJC_CLASS_$_ symbols, and they are the
# eight classes the flags rename, so the earlier claim of exactly one was wrong. The names still come from the
# port's own sources rather than from a symbol scan: every class its headers declare and every class its
# sources implement, which is a list read out of the tree rather than a list kept beside it.
#
# It renames class names and C symbols, and nothing else. Those are whole identifiers, which is all a -D can
# rename: a -D applies to every occurrence of the name in the translation unit, and the port's sources include
# the SDK's. A selector is not a whole identifier -- setObject:forTrait: is three of them -- so renaming one of
# its pieces renames every unrelated use of that word too. Isolating a selector is prefix_selectors.py's work,
# and this family does not need it: every class here is one the port IMPLEMENTS rather than a category it adds
# to a class the system owns, so renaming the class is enough to keep the two apart.
renames() {
    # $1: the port's headers and sources, whose @interface and @implementation lines name the classes
    # $2: the object files, for the C symbols they export
    grep -hE '^[[:space:]]*@(interface|implementation)[[:space:]]+[A-Za-z_]' $1 |
        sed -E 's/^[[:space:]]*@(interface|implementation)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\2/' | sort -u |
        awk '{ print "-D" $0 "=CharonHost" $0 }'
    defined=$(nm -m $2 | grep -v '(undefined)')
    printf '%s\n' "$defined" | sed -n 's/.* external _\([A-Za-z_][A-Za-z0-9_]*\)$/\1/p' |
        grep -vE '^(OBJC_|__copy_helper_block_|__destroy_helper_block_|__block_|__NSGlobal)' | sort -u |
        awk '{ print "-D" $0 "=CharonHost" $0 }'
}
