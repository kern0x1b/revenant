#!/bin/sh
# run-rows.sh - the two harness builds of tests/backports/host/intents/ against the system's own
# Intents, in one binary and one process, with the controls and the negative control run.
#
# init-rows.m is the per-class harness facts/Intents/Intents.md names as owed: it reads, for every
# class of init-classes.txt, what the system's own class answers for -init through the IMP, because
# the SDK's header forbids naming that selector at compile time and the port's own emitted body is
# built around the same restriction.  factory-rows.m reads the six release-13 rows of
# registry/Intents/ios16.json that the file listed as absent with a reason about a group of the
# delivery.  intents12-rows.m reads the twelve members of the iOS 12.0 group that the generator
# writes by hand, including whether each completion handler runs before the call returns.
#
# BOTH PROGRAMS LINK -framework Intents, and that is not decoration.  A first attempt at
# factory-rows.m read the four classes with NSClassFromString from a program that did not link the
# framework and got ABSENT for every one of them: the reader was blind, not the host.  A measurement
# whose reader is blind looks exactly like a measurement of an absence, so both programs print a
# class the system does not carry and the harness has to report ABSENT for it, and this script runs
# that list and fails when the harness passes it.
#
# The four classes are API_UNAVAILABLE(macos) in the SDK, so factory-rows.m reaches every one of
# them through the runtime and reads every value through KVC; a program that named them would not
# compile, and a program that read them with NSClassFromString without linking -framework Intents
# answers ABSENT for all four and is wrong about every one.  Each section is a separate run, so a
# section the host cannot answer does not take the other three with it.
#
# Usage: sh tests/backports/host/intents/run-rows.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
build=${INTENTS_ROWS_BUILD:-$here/../../../.agent-work/build/intents-rows}
mkdir -p "$build"
flags="-fobjc-arc -w -Wno-deprecated-declarations"

echo "intents rows: building both harnesses"
xcrun clang $flags "$here/init-rows.m" -framework Intents -framework Foundation -o "$build/init-rows"
xcrun clang $flags "$here/factory-rows.m" -framework Intents -framework Foundation -o "$build/factory-rows"

echo "intents rows: the 21 -init rows, class by class, against the system's own classes"
"$build/init-rows" "$here/init-classes.txt" | tee "$build/init-rows.log"

echo "intents rows: the negative control - a class list the system does not carry must all fail"
printf '# the negative control: one class the system does not carry, and one it does\nINCharonNoSuchClassForThisHarness\nNSObject\n' \
    > "$build/control-classes.txt"
if "$build/init-rows" "$build/control-classes.txt" > "$build/control.log" 2>&1; then
    echo "intents rows: FAIL the harness passed a class the system does not carry, so it cannot tell the two apart"
    exit 1
fi
sed 's/^/intents rows:   /' "$build/control.log"
echo "intents rows: the control is red, as it must be"

echo "intents rows: the six rows the registry listed as absent, one section per run"
: > "$build/factory-rows.log"
for section in destination resolution file usercontext; do
    if "$build/factory-rows" "$section" 2>&1 | tee -a "$build/factory-rows.log"; then
        :
    else
        echo "intents rows:   the $section section was killed, so the host does not answer it" | tee -a "$build/factory-rows.log"
    fi
done

# The twelve members of the 12.0 group that gen-intents.py's EXTRA_METHODS writes by hand.  One
# PROCESS PER SECTION and one per receiver: intents12-rows.m's own comment gives the measurement that
# showed a single process cannot measure two receivers of the same member.
echo "intents rows: building the 12.0 group harness"
xcrun clang $flags "$here/intents12-rows.m" -framework Intents -framework Foundation -o "$build/intents12-rows"
: > "$build/intents12-rows.log"

# The reader's own two controls first.  A class the system does not carry must read ABSENT, or a
# harness that measured nothing is indistinguishable from one that measured an answer; and all five
# classes must be found, or every section below is the reader's blindness rather than the host's.
"$build/intents12-rows" classes > "$build/classes.log" 2>&1 || {
    echo "intents rows: FAIL the class census section did not run"
    exit 1
}
classes_line=$(cat "$build/classes.log")
echo "$classes_line" | tee -a "$build/intents12-rows.log"
case "$classes_line" in
    *INCharonNoSuchClassForThisHarness=0*) : ;;
    *) echo "intents rows: FAIL the system answered for a class it does not carry: $classes_line"
       exit 1 ;;
esac
for want in INShortcut INVoiceShortcut INVoiceShortcutCenter INRelevantShortcutStore INUpcomingMediaManager; do
    case "$classes_line" in
        *"$want=1"*) : ;;
        *) echo "intents rows: FAIL the system does not answer for $want, so the sections below would be blind"
           exit 1 ;;
    esac
done
# ABSENT and IMP non-NULL are matched as a whole line, so an empty output cannot pass: a harness that
# printed nothing would leave the case below unmatched and fail, rather than look like a control
# that agreed.
absent_line=$("$build/intents12-rows" absent-control 2>&1) || {
    echo "intents rows: FAIL the absent-control section did not run"
    exit 1
}
echo "$absent_line" | tee -a "$build/intents12-rows.log"
case "$absent_line" in
    *ABSENT*) : ;;
    *) echo "intents rows: FAIL the harness answered for a class the system does not carry: $absent_line"
       exit 1 ;;
esac
object_line=$("$build/intents12-rows" object-control 2>&1) || {
    echo "intents rows: FAIL the object-control section did not run"
    exit 1
}
echo "$object_line" | tee -a "$build/intents12-rows.log"
case "$object_line" in
    *"IMP non-NULL"*) : ;;
    *) echo "intents rows: FAIL a class whose header marks nothing unavailable did not answer: $object_line"
       exit 1 ;;
esac
# The negative control FOR THE ASSERTION: a handler called before its method returned must make the
# harness exit non-zero, or a before-return=1 anywhere below would be printed and ignored.
if "$build/intents12-rows" sync-plant > "$build/sync-plant.log" 2>&1; then
    echo "intents rows: FAIL a synchronous answer passed the before-return check, so the check is not live"
    exit 1
fi
sed 's/^/intents rows:   /' "$build/sync-plant.log"
echo "intents rows: the three controls are as they must be"

echo "intents rows: the twelve members of the 12.0 group, one process per section"
for section in new-shortcut new-voice new-centre defaultStore sharedManager sharedCenter \
                setShortcutSuggestions setSuggestedMediaIntents setPredictionMode; do
    if "$build/intents12-rows" "$section" 2>&1 | tee -a "$build/intents12-rows.log"; then
        :
    else
        echo "intents rows:   the $section section was killed, so the host does not answer it" | tee -a "$build/intents12-rows.log"
    fi
done

echo "intents rows: the three members that take a handler, once per receiver"
for section in setRelevantShortcuts getAllVoiceShortcuts getVoiceShortcut; do
    for receiver in singleton fresh; do
        # The harness's OWN exit status is the verdict, and a pipeline would throw it away: in
        # `if cmd | tee`, the `if` sees tee's status, not the harness's. So the output goes to a
        # file first and the status is taken from the command itself.
        if "$build/intents12-rows" "$section" "$receiver" > "$build/section.log" 2>&1; then
            cat "$build/section.log" | tee -a "$build/intents12-rows.log"
        else
            cat "$build/section.log" | tee -a "$build/intents12-rows.log"
            echo "intents rows: FAIL the $section/$receiver section answered its handler before the call returned" \
                | tee -a "$build/intents12-rows.log"
            exit 1
        fi
    done
done
echo "intents rows: 12.0 group measured; what it settles and what it does not is in facts/Intents/Intents.md"

# The PORT's side of the same three members, and it is a different kind of check from the ones above:
# the harness above measures what the system's own framework DOES, this one asserts the shape of the
# port's own generated body, because the port's objects are armv7 and do not run on this host and
# cannot be linked beside the framework either.  That is measured, and facts/Intents/Intents.md
# writes it out: tests/backports/host/prefix_selectors.py renames SELECTORS and not class names (its
# own docstring: "gives one to the selectors the port's Charon categories carry"), the class renaming
# is -D, and a -D moves the SDK's own declaration of the same class along with the port's - so for
# CharonIntents262.h:39 the host build answers
#   error: duplicate interface definition for class 'CharonHostINMessageLinkMetadata'
# and there is nothing in the tree that renames the port's class without the SDK's.
#
# So the expectation still comes from the measurement above - the handler must not be called before
# the method returns - and what is checked here is the one thing that can be: that the port's body
# hands the handler to a dispatch instead of calling it inline.  A direct call would sit between the
# method's opening brace and the dispatch, so its absence there is the assertion.
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Intents/IN12_0.m
echo "intents rows: the port's own three bodies hand the handler to a dispatch"
python3 - "$port" <<'PY'
import sys
source = open(sys.argv[1], encoding="utf-8").read()
# Each member by the FIRST LINE of its definition, which is where the generator writes it: a
# selector is wrapped across lines, so the whole selector is not one string to look for. The body is
# everything from there to the end of its @implementation.
members = {
    "- (void)setRelevantShortcuts:(NSArray<INRelevantShortcut *> *)shortcuts":
        "INRelevantShortcutStore -setRelevantShortcuts:completionHandler:",
    "- (void)getAllVoiceShortcutsWithCompletion:":
        "INVoiceShortcutCenter -getAllVoiceShortcutsWithCompletion:",
    "- (void)getVoiceShortcutWithIdentifier:(NSUUID *)identifier":
        "INVoiceShortcutCenter -getVoiceShortcutWithIdentifier:completion:",
}
failures = []
for definition, row in members.items():
    start = source.find("\n" + definition)
    if start < 0:
        failures.append("%s: the method is not in the object at all" % row)
        continue
    end = source.find("\n@end", start)
    body = source[start:end if end > 0 else len(source)]
    brace = body.index("{")
    dispatch = body.find("dispatch_async(", brace)
    if dispatch < 0:
        failures.append("%s: no dispatch at all, so the handler is called inline" % row)
        continue
    # A call before the dispatch is the synchronous answer this check exists to catch. The pattern
    # carries the open paren, and it appears nowhere but in the three real calls - the prose above
    # each body writes the selector with a colon, never with one - so a comment cannot satisfy or
    # trip it.
    if "completionHandler(" in body[brace:dispatch]:
        failures.append("%s: the handler is called BEFORE the dispatch" % row)
        continue
    print("intents12 port %-56s dispatches its handler" % row)
for failure in failures:
    print("FAIL " + failure)
print("port bodies: %d of %d dispatch, %d failed"
      % (len(members) - len(failures), len(members), len(failures)))
sys.exit(1 if failures else 0)
PY
echo "intents rows: the port's three bodies are asynchronous, which is what the host measurement demands"