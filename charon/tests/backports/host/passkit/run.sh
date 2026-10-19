#!/bin/sh
# The PassKit Secure Element and the wallet: one case per member, driven against the PORT'S OWN
# renamed classes, with a mutant that answers YES where a registry row says NO.
#
# The port's categories are compiled onto classes the run renames (charonHost_PKPassLibrary and the
# rest), so the runner reaches the port through the runtime and never the host's PassKit. The value
# is checked against the port's own registry rows, because a Mac answers these from a real Secure
# Element and this device has none -- the host is not the oracle for what a 4S should say. It IS the
# oracle for PKPassKitErrorDomain, and the last case uses it.
#
# The probe FAILS if the mutant does not differ, because a green mutant is a comparison that decides
# nothing, and FAILS if the real run made fewer than 31 members, because then it is not covering the
# thirty-one the registry rows name. The floor counts the 31 MEMBERS, not the check lines: the
# operations each take two lines (the ok flag and the error's shape) and that is the honest unit.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
port=${PORT:-$here/../../../../packages/a/apple-backports/PassKit}
# BUILD goes under the repository's own .agent-work, never the system temp: the run output is
# evidence and belongs with the band's runs. Same rule as the other probes in this package.
build=${PASSKIT_BUILD:-$PWD/.agent-work/runs/passkit}
mkdir -p "$build"
# The clear-out MUST include the mutants' own sources. Leaving them out lets a mutant file from an
# earlier run be linked in place of the one this run writes, which is not a stale-cache nuisance: it
# makes the run GREEN on an artefact the current run never produced, and the run then dies on a fresh
# build directory. That is exactly what happened to the third mutant, and the only reason it was
# caught is that a reviewer built it clean.
rm -rf "$build/mut5"
rm -f "$build"/cc.log "$build"/runner.log "$build"/*.txt "$build"/*.body "$build"/*.dylib \
      "$build"/*.mutated.m "$build"/runner "$build"/port-classes.o
MACOSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
TARGET="-target arm64-apple-ios17.0-macabi -isysroot $MACOSX_SDK -isystem $MACOSX_SDK/System/iOSSupport/usr/include -F $MACOSX_SDK/System/iOSSupport/System/Library/Frameworks"
RENAME="-DPKPassLibrary=charonHost_PKPassLibrary \
    -DPKPaymentAuthorizationController=charonHost_PKPaymentAuthorizationController \
    -DPKPaymentAuthorizationViewController=charonHost_PKPaymentAuthorizationViewController \
    -DPKAddPassesViewController=charonHost_PKAddPassesViewController \
    -DPKPaymentAuthorizationResult=charonHost_PKPaymentAuthorizationResult \
    -DPKPaymentRequestUpdate=charonHost_PKPaymentRequestUpdate \
    -DPKPaymentRequestShippingMethodUpdate=charonHost_PKPaymentRequestShippingMethodUpdate \
    -DPKPaymentRequestPaymentMethodUpdate=charonHost_PKPaymentRequestPaymentMethodUpdate \
    -DPKPaymentRequestShippingContactUpdate=charonHost_PKPaymentRequestShippingContactUpdate"

# The shim names the four classes literally, so it is compiled WITHOUT the -D renames -- the renames
# exist to move the PORT's references, and the shim's whole job is to declare what they moved onto.
xcrun clang -fobjc-arc -Wall -fPIC $TARGET -DCHARON_HOST_PROBE=1 \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -c "$here/port-classes.m" -o "$build/port-classes.o" 2> "$build/ccclasses.log" || {
        grep -m5 ': error:' "$build/ccclasses.log" || true; exit 1; }

build_port() {
    out=$1
    shift
    xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
        -I"$port" -framework Foundation -framework PassKit -framework UIKit \
        -DCHARON_PASSKIT_STANDIN=1 \
        "$build/port-classes.o" "$port/CharonPassKit.m" "$port/PKSecureElement8.m" "$port/PKWallet.m" \
        "$port/PKPaymentAuthorizationController10.m" "$port/PKPaymentAuthorizationViewController8.m" \
        "$port/PKPaymentAuthorizationViewController9.m" "$port/PKPaymentRequestStatus11.m" -o "$out" 2> "$build/cc.log" || {
            grep -m5 ': error:' "$build/cc.log" || true; exit 1; }
}
build_port "$build/libport.dylib"
# The mutant: the SAME source, one line changed -- a NO that becomes YES, which is the answer a row
# forbids. mutate.py asserts the line is there, so a renamed line fails the build rather than
# producing a mutant that is quietly identical to the real run.
# The NO that becomes YES now lives in the class object, since that is where the class and its
# capability answers are: the two controller categories left PKSecureElement8.m in the previous commit,
# so mutating THAT file is mutating a file that no longer has the line -- and the assert below is what
# says so instead of producing a mutant that is quietly the real run.
cp "$port/PKPaymentAuthorizationController10.m" "$build/PKPaymentAuthorizationController10.mutated.m"
python3 - "$build/PKPaymentAuthorizationController10.mutated.m" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = """+ (BOOL)canMakePayments
{
    return NO;
}"""
new = """+ (BOOL)canMakePayments
{
    return YES;
}"""
assert old in text, "the line the mutant changes is not there: the mutant would be the real run"
open(path, "w").write(text.replace(old, new, 1))
PY
# A SECOND mutant, on the shared error rather than on a capability: one code changed, so the
# comparison is shown to see the error's VALUE and not only the NO. Two mutants, because one kind of
# mutation that goes red is not evidence that the other would.
# THE THIRD MUTANT, on PKSecureElement8.m -- the file the 6.1.3 gate refused to accept, so it is the
# one worth proving. It is TWO changes in one file, and the two must come out OPPOSITE ways:
#
#   1. presentSecureElementPass: answers NO in the real run because nothing is presented. The mutant
#      makes it YES. That is a flipped answer, so it must go RED and name that case.
#   2. a comment's wording is changed. That is bytes and not behaviour, and it must stay GREEN -- a
#      differential that went red on a reworded comment would be reading the file, not the answer, and
#      every future edit would make it useless.
# Asserting both lines are present is what stops a rename turning either mutation into the real run.
cp "$port/PKSecureElement8.m" "$build/PKSecureElement8.mutated.m"
python3 - "$build/PKSecureElement8.mutated.m" <<'PY3'
import sys
path = sys.argv[1]
text = open(path).read()
flipped = """- (BOOL)presentSecureElementPass:(PKSecureElementPass *)secureElementPass
{
    (void)secureElementPass;
    return NO;
}"""
flipped_to = """- (BOOL)presentSecureElementPass:(PKSecureElementPass *)secureElementPass
{
    (void)secureElementPass;
    return YES;
}"""
assert flipped in text, "the answer the third mutant flips is not there: the mutant would be the real run"
text = text.replace(flipped, flipped_to, 1)
# the bytes-and-not-behaviour half: a word in the file's own header, which is a real line of
# PKSecureElement8.m so the assertion below is about this file and not about a string I remembered
old_comment = "answered the way Apple's documentation says for a device that has no Secure Element"
new_comment = "answered the way Apple's documentation states it for a device with no Secure Element"
assert old_comment in text, "the comment the third mutant rewords is not there"
text = text.replace(old_comment, new_comment, 1)
open(path, "w").write(text)
PY3

# THE FOURTH MUTANT, on the iOS 11 value classes' own object. The file it mutates is the newest one, and
# the two changes must come out OPPOSITE ways again:
#
#   1. the update's DEFAULT status, PKPaymentAuthorizationStatusSuccess -> Failure. That is a value the
#      transcript prints, so it must go RED and name the case.
#   2. a comment's wording in the same file. That is bytes and not behaviour, and it must stay GREEN --
#      a comparison that turned red on a reworded comment would be reading the file, not the answer.
cp "$port/PKPaymentRequestStatus11.m" "$build/PKPaymentRequestStatus11.mutated.m"
python3 - "$build/PKPaymentRequestStatus11.mutated.m" <<'PY4'
import sys
path = sys.argv[1]
text = open(path).read()
flipped = """    _status = PKPaymentAuthorizationStatusSuccess;
    _paymentSummaryItems = [paymentSummaryItems copy];"""
flipped_to = """    _status = PKPaymentAuthorizationStatusFailure;
    _paymentSummaryItems = [paymentSummaryItems copy];"""
assert flipped in text, "the default the fourth mutant flips is not there: the mutant would be the real run"
text = text.replace(flipped, flipped_to, 1)
old_comment = "the object stores what the delegate put in it and hands the same values back"
new_comment = "the object stores what the delegate put in it and hands back the same values"
assert old_comment in text, "the comment the fourth mutant rewords is not there"
text = text.replace(old_comment, new_comment, 1)
open(path, "w").write(text)
PY4

# THE FIFTH MUTANT, on the view controller's SUPERCLASS -- the check that is class_getSuperclass and
# not isSubclassOfClass, so this is the only mutant that can tell the two apart.
#
# The mutation is the SUBCLASS the release never had: PKPaymentAuthorizationViewController declared as
# a UIView subclass instead of the UIViewController one the header names. It must go RED and name the
# superclass case. Under the old isSubclassOfClass check it would have been GREEN and said nothing,
# because a UIView is not a UIViewController either -- which is why the check is spelled the way it
# is, and why the control has to be this one.
#
# It is a HEADER, and that decides where the copies go. A quoted #import resolves against the importing
# file's own directory FIRST, so a mutated CharonPassKitStandin.h dropped beside the port's sources
# would be reached by nothing -- every port file sits in $port and would find its own -- while the
# copies mutants 3 and 4 already have in $build would silently be built against it too. So the fifth
# mutant gets its own directory: the mutated header and the one port file that implements the class are
# copied INTO it, that file's own quote-import then finds the mutated header beside it, and no other
# mutant's sources can see either. The port-classes object is the real one, unchanged: its declaration
# is a declaration only, and the runtime shape comes from the implementation the mutated header was
# compiled with.
mut5=$build/mut5
mkdir -p "$mut5"
cp "$port/CharonPassKitStandin.h" "$mut5/CharonPassKitStandin.h"
cp "$port/PKPaymentAuthorizationViewController8.m" "$mut5/PKPaymentAuthorizationViewController8.m"
python3 - "$mut5/CharonPassKitStandin.h" <<'PY5'
import sys
path = sys.argv[1]
text = open(path).read()
old = "@interface PKPaymentAuthorizationViewController : UIViewController"
new = "@interface PKPaymentAuthorizationViewController : UIView"
assert text.count(old) == 1, "the superclass the fifth mutant changes is not there exactly once"
open(path, "w").write(text.replace(old, new, 1))
PY5

cp "$port/CharonPassKit.m" "$build/CharonPassKit.mutated.m"
python3 - "$build/CharonPassKit.mutated.m" <<'PY2'
import sys
text = open(sys.argv[1]).read()
old = "code:PKUnsupportedVersionError"
new = "code:PKInvalidSignature"
assert old in text, "the code the mutant changes is not there"
open(sys.argv[1], "w").write(text.replace(old, new, 1))
PY2
# MUTANT 1: the class object's NO becomes YES. The Secure Element file is UNMUTATED here, so the
# third mutant's file is not linked into this build -- a mutant dylib with two mutations in it cannot
# say which one the transcript saw.
# MUTANT 3: the Secure Element file, on its own -- a flipped answer AND a reworded comment, which
# must come out opposite ways. It is built as its own dylib so the transcript can say which of the two
# it saw.
xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -DCHARON_PASSKIT_STANDIN=1 \
    "$build/port-classes.o" "$port/CharonPassKit.m" "$build/PKSecureElement8.mutated.m" \
    "$port/PKWallet.m" "$port/PKPaymentAuthorizationController10.m" \
    "$port/PKPaymentAuthorizationViewController8.m" \
    "$port/PKPaymentAuthorizationViewController9.m" "$port/PKPaymentRequestStatus11.m" -o "$build/libmutant3.dylib" 2> "$build/ccmut3.log" || {
        grep -m5 ': error:' "$build/ccmut3.log" || true; exit 1; }

xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -DCHARON_PASSKIT_STANDIN=1 \
    "$build/port-classes.o" "$port/CharonPassKit.m" "$port/PKSecureElement8.m" "$port/PKWallet.m" \
    "$port/PKPaymentAuthorizationController10.m" "$port/PKPaymentAuthorizationViewController8.m" \
    "$port/PKPaymentAuthorizationViewController9.m" "$build/PKPaymentRequestStatus11.mutated.m" \
    -o "$build/libmutant4.dylib" 2> "$build/ccmut4.log" || {
        grep -m5 ': error:' "$build/ccmut4.log" || true; exit 1; }

xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -DCHARON_PASSKIT_STANDIN=1 \
    "$build/port-classes.o" "$port/CharonPassKit.m" "$port/PKSecureElement8.m" "$port/PKWallet.m" \
    "$build/PKPaymentAuthorizationController10.mutated.m" \
    "$port/PKPaymentAuthorizationViewController8.m" \
    "$port/PKPaymentAuthorizationViewController9.m" "$port/PKPaymentRequestStatus11.m" -o "$build/libmutant.dylib" 2> "$build/ccmut.log" || {
        grep -m5 ': error:' "$build/ccmut.log" || true; exit 1; }
xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -DCHARON_PASSKIT_STANDIN=1 \
    "$build/port-classes.o" "$build/CharonPassKit.mutated.m" "$port/PKSecureElement8.m" "$port/PKWallet.m" \
    "$port/PKPaymentAuthorizationController10.m" "$port/PKPaymentAuthorizationViewController8.m" \
    "$port/PKPaymentAuthorizationViewController9.m" "$port/PKPaymentRequestStatus11.m" -o "$build/libmutant2.dylib" 2> "$build/ccmut2.log" || {
        grep -m5 ': error:' "$build/ccmut2.log" || true; exit 1; }

# MUTANT 5: the view controller's superclass. Its own directory, so the mutated stand-in header is
# reached by exactly the one file copied into it and by nothing else.
xcrun clang -fobjc-arc -Wall -fPIC -dynamiclib $TARGET -DCHARON_HOST_PROBE=1 $RENAME \
    -I"$port" -framework Foundation -framework PassKit -framework UIKit \
    -DCHARON_PASSKIT_STANDIN=1 \
    "$build/port-classes.o" "$port/CharonPassKit.m" "$port/PKSecureElement8.m" "$port/PKWallet.m" \
    "$port/PKPaymentAuthorizationController10.m" "$mut5/PKPaymentAuthorizationViewController8.m" \
    "$port/PKPaymentAuthorizationViewController9.m" "$port/PKPaymentRequestStatus11.m" -o "$build/libmutant5.dylib" 2> "$build/ccmut5.log" || {
        grep -m5 ': error:' "$build/ccmut5.log" || true; exit 1; }

xcrun clang -fobjc-arc -Wall $TARGET -ldl -framework Foundation -framework PassKit -framework UIKit \
    "$here/runner.m" -o "$build/runner" 2> "$build/runner.log" || {
        grep -m5 ': error:' "$build/runner.log" || true; exit 1; }

DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libport.dylib" "$build/runner" > "$build/real.txt" 2>&1 && true
DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libmutant.dylib" "$build/runner" > "$build/mutant.txt" 2>&1 && true
DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libmutant2.dylib" "$build/runner" > "$build/mutant2.txt" 2>&1 && true
DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libmutant3.dylib" "$build/runner" > "$build/mutant3.txt" 2>&1 && true
DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libmutant4.dylib" "$build/runner" > "$build/mutant4.txt" 2>&1 && true
DYLD_FRAMEWORK_PATH="$MACOSX_SDK/System/iOSSupport/System/Library/Frameworks" \
    CHARON_PORT_DYLIB="$build/libmutant5.dylib" "$build/runner" > "$build/mutant5.txt" 2>&1 && true
cat "$build/real.txt"; cat "$build/mutant.txt"; cat "$build/mutant2.txt"; cat "$build/mutant3.txt"; cat "$build/mutant4.txt"; cat "$build/mutant5.txt"

# the member lines, and the continuation lines under them: an operation's error is checked in
# a line of its own, and a filter that drops those checks six answers without a word
body() { grep -E '^ +(\.|[A-Za-z])' "$1"; }
body "$build/real.txt" > "$build/real.body"
body "$build/mutant.txt" > "$build/mutant.body"
body "$build/mutant2.txt" > "$build/mutant2.body"
body "$build/mutant3.txt" > "$build/mutant3.body"
body "$build/mutant4.txt" > "$build/mutant4.body"
body "$build/mutant5.txt" > "$build/mutant5.body"
# EVERY TRANSCRIPT MUST REACH THE RUNNER'S OWN SUMMARY LINE. Found by this run: the `errors:` case
# type-punned its argument, the runner raised on the next line, and every transcript stopped there --
# with no FAIL in it, because the cases after the crash never ran. A crashed runner reads as a green
# run for every case it did not reach, so the check is that it reached the end.
for name in real mutant mutant2 mutant3 mutant4 mutant5; do
  if ! tail -1 "$build/$name.txt" | grep -qE '^# [0-9]+ check\(s\)'; then
    echo "FAIL the $name transcript does not end with the runner's own summary line, so that runner"
    echo "     did not finish -- a crash reads as a green run for every case after it"
    tail -3 "$build/$name.txt"
    exit 1
  fi
done
echo "ok every transcript reached the runner's own summary line"
lines=$(wc -l < "$build/real.body" | tr -d ' ')
# one case line per member, plus one extra for each operation, which reports its ok flag and then the
# error's own shape on a continuation line, plus the six CLASS cases the two payment controllers add.
# Counted from the transcript rather than hard-coded, so a member or a class that stops being answered
# stops being counted
ops=$(grep -c '^    \.\.\.' "$build/real.body" || true)
members=$((lines - ops))
echo "--- the real run made $members member case(s) over $lines check line(s):"
if [ "$members" -lt 37 ]; then
    echo "FAIL only $members of the thirty-one members reached, so the probe is not covering them"
    exit 1
fi
if grep -q 'FAIL$' "$build/real.body"; then
    echo "FAIL the real run has a failing case:"
    grep 'FAIL$' "$build/real.body"
    exit 1
fi
echo "ok the real run's every case matches the row it checks"
if diff -q "$build/real.body" "$build/mutant.body" >/dev/null 2>&1; then
    echo "FAIL the mutant does not differ from the real run: this comparison cannot see a wrong"
    echo "     answer, so a green run here would decide nothing"
    exit 1
fi
echo "ok the mutant differs, so the comparison does see the value it is checking"
diff -u "$build/real.body" "$build/mutant.body" | sed -n '1,8p'
if diff -q "$build/real.body" "$build/mutant2.body" >/dev/null 2>&1; then
    echo "FAIL the second mutant -- a wrong error CODE, PKUnsupportedVersionError -> PKInvalidSignature"
    echo "     -- does not differ, so nothing here checks the error's own value"
    exit 1
fi
echo "ok the second mutant differs too, so the error's code is checked and not just its presence"
diff -u "$build/real.body" "$build/mutant2.body" | sed -n '1,8p'

# THE THIRD MUTANT, and it has TWO verdicts because it makes TWO changes. The file it mutates is the
# one the 6.1.3 gate refused to accept, so the file is not the point -- the two outcomes are.
if diff -q "$build/real.body" "$build/mutant3.body" >/dev/null 2>&1; then
    echo "FAIL the third mutant does not differ: the Secure Element file's own answers are not read"
    exit 1
fi
echo "ok the third mutant differs, so PKSecureElement8.m's answers are read"
diff -u "$build/real.body" "$build/mutant3.body" | sed -n '1,10p'
# and it must be the FLIPPED ANSWER that differs, by name -- a reworded comment changing the
# transcript would mean the comparison reads the file rather than the answer
if ! grep -q 'presentSecureElementPass' "$build/mutant3.body"; then
    echo "FAIL the third mutant's difference is not the case it flipped: presentSecureElementPass is"
    echo "     not in its transcript, so something else moved and the naming below would be a guess"
    exit 1
fi
echo "ok the third mutant's difference is the case it names"
if grep -q 'FAIL$' "$build/mutant3.body"; then
    echo "ok the third mutant's transcript says which case is wrong, not merely that it is:"
    grep 'FAIL$' "$build/mutant3.body" | sed 's/^/   /'
else
    echo "FAIL the third mutant differs but its transcript reports no failing case, so the difference"
    echo "     is not visible in the transcript a reader would read"
    exit 1
fi

# AND THE FOURTH, on the iOS 11 value classes. Same two verdicts, same reason: a flipped value must go
# red and name its case, and the reworded comment in the SAME file must not move the transcript at all.
if diff -q "$build/real.body" "$build/mutant4.body" >/dev/null 2>&1; then
    echo "FAIL the fourth mutant does not differ: PKPaymentRequestStatus11.m's own answers are not read"
    exit 1
fi
echo "ok the fourth mutant differs, so PKPaymentRequestStatus11.m's answers are read"
diff -u "$build/real.body" "$build/mutant4.body" | sed -n '1,10p'
if ! grep -q 'PKPaymentRequestUpdate.status defaults to Success' "$build/mutant4.body"; then
    echo "FAIL the fourth mutant's difference is not the case it flipped: the update's default status is"
    echo "     not in its transcript, so something else moved and the naming below would be a guess"
    exit 1
fi
echo "ok the fourth mutant's difference is the case it names"
if grep -q 'FAIL$' "$build/mutant4.body"; then
    echo "ok the fourth mutant's transcript says which case is wrong, not merely that it is:"
    grep 'FAIL$' "$build/mutant4.body" | sed 's/^/   /'
else
    echo "FAIL the fourth mutant differs but its transcript reports no failing case, so the difference"
    echo "     is not visible in the transcript a reader would read"
    exit 1
fi

# AND THE FIFTH, on the view controller's superclass. One change, and it has to move the transcript in
# one named place: a renamed subclass of the wrong class is a class the release never had, and only the
# exact-superclass case says so.
if diff -q "$build/real.body" "$build/mutant5.body" >/dev/null 2>&1; then
    echo "FAIL the fifth mutant does not differ: the view controller's superclass is not checked"
    exit 1
fi
echo "ok the fifth mutant differs, so the view controller's superclass is read"
diff -u "$build/real.body" "$build/mutant5.body" | sed -n '1,10p'
if ! grep -q 'its superclass is UIViewController, the header.s own' "$build/mutant5.body"; then
    echo "FAIL the fifth mutant's difference is not the case it changed: the view controller's superclass"
    echo "     case is not in its transcript, so something else moved and the naming below would be a guess"
    exit 1
fi
echo "ok the fifth mutant's difference is the case it names"
if grep -q 'FAIL$' "$build/mutant5.body"; then
    echo "ok the fifth mutant's transcript says which case is wrong, not merely that it is:"
    grep 'FAIL$' "$build/mutant5.body" | sed 's/^/   /'
else
    echo "FAIL the fifth mutant differs but its transcript reports no failing case, so the difference"
    echo "     is not visible in the transcript a reader would read"
    exit 1
fi
exit 0
