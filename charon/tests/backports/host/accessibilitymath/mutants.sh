#!/bin/sh
# accessibilitymath/mutants.sh - every mutant of the two groups has to be told apart by the case of
# run.sh, and by the failure report run.sh prints.
#
# A differential that examines nothing says it passed, and a mutant that stops the build says nothing
# either. So each mutant here changes one line of the port's own source in a copy of it, rebuilds the
# case against that copy, and has to be held by the comparison - a line of the two answers that do not
# match, *and* the whole diff that run.sh prints when they do not. Both are required: the diff is a
# promise a script under `set -e` cannot keep, because a bare compare.py leaves it at the comparison,
# and a mutant that dies without ever reaching the diff has not proved the report is reachable either.
# The suite fails if no mutant dies that way.
#
# A mutant that survives, one that dies of a build error, and one that dies of anything else are all
# failures of the case, and the script exits on the count of each.
#
# The rules each mutant breaks:
#   M1  a leaf answers a constant for every content, where the measured answer is what it was given
#       (the macro's one assignment, so all four leaves are wrong at once and the case sees all four)
#   M2  a leaf's content is the empty string where a caller passed nil
#   M3  a container of one array drops it, as the host's Row and Table do - the mutation that shows the
#       declared difference is load-bearing and not a stale declaration
#   M4  a container copies the array instead of answering the very array it was given
#   M5  the sub/superscript answers the first of the base expressions, which is the flattening the port
#       refuses to do and the host does not do either
#   M6  the fraction's denimonator is its numerator, which Apple's own misspelling makes easy to write
#   M7  a content's plain label answers the value, which is the mistake a store of four values makes
#   M8  a content's importance defaults to High, where the header names the default as Default
#   M9  a content's equality ignores the importance, so a High content compares equal to a Default one
#       (measured on the host: it does not, so this is the case that holds the clause in place)
#   M10 a copy drops the importance
#   M11 the coder does not carry the importance, so a High content comes back at the default
#   M12 the coder drops the attributed strings, so both plain spellings come back nil
#   M13 the description names the importance, which the system's own description does not print
# The rule that +customContentWithLabel:value: and +customContentWithAttributedLabel:attributedValue:
# COPY what they are given has no mutant here, and the reason is worth writing down rather than leaving
# as a gap. Measured: a mutable string given to either factory and mutated afterwards leaves what the
# host's own content answers unchanged (four cases, `cc.plain.factory.copies.*` and
# `cc.attr.factory.copies.*`, on both sides, 0 undeclared differences), so the port copies too. The only
# mutation that breaks it is to store the caller's NSString under the ivar the header types as an
# NSAttributedString, and that raises in -label rather than printing a different value - measured: the
# mutant dies with `-[NSObject(NSObject) __retain_OA]` from `-[CharonPortAXCustomContent label] + 36`.
# This suite counts a mutant that dies any way other than an undeclared difference plus the diff as a
# mutant that did not die in the required way, which is the rule M13's comment below is about. So the
# rule is held by the comparison against the host and there is no mutant for it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
sources=$root/packages/a/apple-backports/Accessibility
# A directory of its own per mutant, and not one shared: this script re-invokes itself once per mutant,
# and a child that cleared the parent's directory took the parent's logs with it - measured, and every
# mutant then died of a missing log rather than of its own mutation.
mutant=${MUTANT:-all}
case $mutant in
    all) work=$root/.agent-work/runs/accessibilitymath-mutants/all ;;
    *)   work=$root/.agent-work/runs/accessibilitymath-mutants/m$mutant ;;
esac
rm -rf "$work"
mkdir -p "$work"

# SRC=<file>   which of the two port sources to change, for a mutant that is not in the math one

apply() {
    # $1 the file, $2 the search, $3 the replacement. The copy is this run's own src directory, so a
    # mutant never edits the tree it is measured against.
    file=$1
    search=$2
    replace=$3
    copy=$work/src
    if ! grep -qF -- "$search" "$sources/$file"; then
        echo "MUTANT-SETUP-FAILED: this line is not in $sources/$file, so the mutant would not apply:" >&2
        echo "  $search" >&2
        exit 2
    fi
    mkdir -p "$copy"
    cp "$sources"/*.h "$sources"/*.m "$copy/"
    python3 - "$copy/$(basename "$file")" "$search" "$replace" <<'PY'
import sys
path, search, replace = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(search) != 1:
    sys.exit("MUTANT-SETUP-FAILED: %r appears %d times, and a mutant must change one line"
             % (search, text.count(search)))
open(path, 'w').write(text.replace(search, replace))
PY
}

# Each entry: the mutant's number, the file, the line to change, and what it changes to.
case $mutant in
1) apply CharonAXMathExpression.m '            _content = [content copy];' '            _content = @"0";' ;;
2) apply CharonAXMathExpression.m '        return _content;' '        return _content ?: @"";' ;;
3) apply CharonAXMathExpression.m '        _expressions = expressions;
        _openString = [openString copy];
        _closeString = [closeString copy];' '        _expressions = nil;
        _openString = [openString copy];
        _closeString = [closeString copy];' ;;
4) apply CharonAXMathExpression.m '        _expressions = expressions;
        _openString = [openString copy];
        _closeString = [closeString copy];' '        _expressions = [expressions copy];
        _openString = [openString copy];
        _closeString = [closeString copy];' ;;
5) apply CharonAXMathExpression.m '    return (AXMathExpression *)_baseExpression;' '    return (AXMathExpression *)_baseExpression.firstObject;' ;;
6) apply CharonAXMathExpression.m '    return _denimonatorExpression;' '    return _numeratorExpression;' ;;
7) apply CharonAXCustomContent.m '    return _charon_attributedLabel.string;' '    return _charon_attributedValue.string;' ;;
8) apply CharonAXCustomContent.m '    return _charon_importance;' '    return AXCustomContentImportanceHigh;' ;;
9) apply CharonAXCustomContent.m '        && _charon_importance == content->_charon_importance;' '        && YES;' ;;
10) apply CharonAXCustomContent.m '    copy->_charon_importance = _charon_importance;' '' ;;
11) apply CharonAXCustomContent.m '    [coder encodeInteger:(NSInteger)_charon_importance forKey:@"importance"];' '' ;;
12) apply CharonAXCustomContent.m '    [coder encodeObject:_charon_attributedLabel forKey:@"attributedLabel"];' '' ;;
# The one this suite found by accident first: -description spelled with %@ on self calls itself, and the
# case that reads it died on a segfault rather than on a difference. M13 is the rule it must also hold -
# the two values and nothing else - because a description naming an importance the system does not print
# is a claim the system does not make.
# The first spelling of this mutant added a fifth argument to a four-specifier format, so
# stringWithFormat ignored it and the description came out unchanged: the case passed with the rule
# broken. It is written here as one line that changes what the format is given, which is the mistake.
13) apply CharonAXCustomContent.m '            _charon_attributedLabel.string, _charon_attributedValue.string];' '            _charon_attributedLabel.string, [NSString stringWithFormat:@"%@ importance %d", _charon_attributedValue.string, (int)_charon_importance]];' ;;
all)
    total=13
    killed=0
    build_failed=0
    survived=0
    for n in $(seq 1 "$total"); do
        MUTANT=$n sh "$0" > "$work/m$n.log" 2>&1 && {
            echo "M$n SURVIVED: the case passed with this rule broken, so it examines nothing about it"
            survived=$((survived + 1))
            continue
        }
        if grep -q 'MUTANT-SETUP-FAILED' "$work/m$n.log"; then
            echo "M$n DID NOT APPLY:"
            sed 's/^/    /' "$work/m$n.log"
            build_failed=$((build_failed + 1))
            continue
        fi
        if grep -q 'UNDECLARED DIFFERENCE' "$work/m$n.log" && grep -q '^--- ' "$work/m$n.log"; then
            echo "M$n killed: an undeclared difference and the diff that shows it"
            killed=$((killed + 1))
            continue
        fi
        echo "M$n died, but not in the way this suite requires: it must be an undeclared difference and the diff"
        sed 's/^/    /' "$work/m$n.log" | tail -20
        build_failed=$((build_failed + 1))
    done
    echo "=== $total mutants: $killed killed by the comparison, $build_failed did not die in the required way, $survived survived"
    # A suite in which nothing was killed has proved nothing, and a mutant that did not apply is not a
    # killed one: both are failures, and the count says which.
    [ "$killed" -eq "$total" ] || exit 1
    exit 0
    ;;
*)
    echo "usage: MUTANT=<1..13> sh $0" >&2
    exit 2
    ;;
esac

ACCESSIBILITY_SRC=$work/src sh "$here/run.sh" BUILD=$work/build || exit 1
# A mutant that did not fail the case is a survivor, and the caller is told so by the exit status
# above; reaching here means the mutant passed, which is the one outcome this file exists to prevent.
echo "M$mutant SURVIVED: the case passed with this rule broken"
exit 1
