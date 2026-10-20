#!/bin/sh
# EVERY Security host case, from the tree, in one command: build it with the port sources it needs, run
# it, compare it, and then run a MUTATION of it and require the comparison to notice.
#
# This file exists because nothing ran the compare-*.lua scripts. A check nobody invokes is a check that
# cannot fail, so the comparisons are driven HERE and a run in which one of them is skipped is a failure
# rather than a quiet pass.
#
# A case is built WITH the port source that defines the symbols it calls, and that is the shim: the
# system half on its own has no _RevenantSecurityCarries, _RevenantSecurityPaddingFor,
# _RevenantCertificateNameTLV or _RevenantSecurityAttributesFromItemResult, and the reviewer's build line
# linked without them. The host's own accessors are reached by dlsym off the SYSTEM framework handle, in
# the cases themselves - see the header of each.
#
# Exit non-zero on: a build that fails, a comparison that differs, a mutation that goes UNNOTICED, and a
# case that is not listed below. GREEN/RED lines are printed for each, so a log shows what was checked.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
work=$(cd "$here/../../../.." && pwd)
build=${BUILD:-$(runs_folder run-cases)}
mkdir -p "$build"; rm -f "$build/cases-entered" "$build"/verdict-*
sdk=$(xcrun --show-sdk-path --sdk macosx)
S="$work/packages/frameworks/apple-backports/Security"
H="$here"
# -Werror=implicit-function-declaration, so a call to a name no header declares is a BUILD
# FAILURE and not a silently int-returning call that reads garbage.
common="-target arm64-apple-ios15.0-macabi -Werror=implicit-function-declaration -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
frameworks="-framework Foundation -framework Security -framework CoreFoundation"
failures=0
green=0
# EVERY MUTANT NAMES ITS OWN LINK LINE, and there is no global left to forget. What a mutant may be
# linked against is a property of the mutation, so it is an argument to run_mutation and not a
# variable that has to be set before one call and cleared after it: a stale one linked the wrong object
# into the next mutant and the run said nothing. See run_mutation's own comment for the line's shape.
# THE CONTROL IS MARKED, NOT THE CHECK WEAKENED. A mutant named here is EXPECTED to survive its
# comparison; every other one that survives is a failure. The list is not a hole in the check - it is one
# entry, and adding to it would turn the run green in a way nobody can read back.
EXPECTED_UNNOTICED="identity"
cases=0
missing=0
mutants=0
declared=0
mutants_noticed=0

# run NAME PORT-SOURCES... -- COMPARE-SCRIPT ; a mutation is applied by mutate_NAME below
run_case() {
    # A CASE IS COUNTED ONLY AFTER IT HAS BEEN RUN AND COMPARED. The counter used to sit at the TOP of this
    # function, on the reasoning that a caller incrementing after the call undercounts early returns - and
    # that was true, but it fixed the wrong thing: it counted BUILDS. The driver built 19 binaries, checked
    # that the port's symbols were linked into each, and printed "every case compared" without ever asking
    # what any of them DID. The reviewer's control is what showed it: pointing the driver at a source with
    # its half-pair refusal removed changed nothing it printed, while the same binary compared by hand said
    # DIFFERS. So the increment belongs here, after the verdict, and not anywhere above it.
    name=$1; shift
    compare=$1; shift
    echo "$name" >> "$build/cases-entered"
    : > "$build/verdict-$name"

    if ! xcrun clang $common "$@" $frameworks -o "$build/$name" > "$build/$name.log" 2>&1; then
        echo "NOTRUN $name  the build failed, so the case never ran" > "$build/verdict-$name"; echo "BUILD  $name FAILED to build"
        sed -n '1,5p' "$build/$name.log" | sed 's/^/       /'
        failures=$((failures + 1))
        return
    fi

    # THE GUARD, AND EXACTLY WHAT IT DOES NOT COVER. It matches \bsec_[a-z0-9_]+\( in the CASE and in
    # the port sources, so it covers a case that reaches the port through a sec_* name AND that source
    # being linked. IT COVERS FIVE CASES AND NOT THOSE: network-fetch, whose port functions are named as
    # the HEADER names them (SecTrustSetNetworkFetchAllowed, ...) and match neither sec_* nor Revenant*;
    # supported, attributes and certificate-name, which reach the port through Revenant* helpers; and
    # trust-result, which resolves the port by dlsym(RTLD_DEFAULT, ...) and so has no link-time reference
    # to find. A SOURCE DROPPED FROM THE LINK LINE CAN THEREFORE HIDE: dropping $N leaves network-fetch
    # GREEN with exit 0 while the host answered. The README beside this file carries the control.
    # THE THREE LISTS, SO THE SENTENCE ABOVE CAN BE READ AGAINST THE CODE. `called` is every sec_* name the
    # CASE mentions; the reference set is every sec_* name mentioned in any file on "$@", THE CASE FILE
    # INCLUDED; a name is checked only when it is in BOTH, and then only if _name is not defined in the
    # binary this case linked. Two consequences, both measured, and the first is the one that surprises:
    # dropping a source from the line does NOT take the name out of the reference set - the case still
    # mentions it - so a name reached through sec_* is still caught: protocol-options-data without $PD
    # gives MISSING ... would measure the HOST and exit 1, with nm -u showing the symbol undefined. That
    # is also why the one case that hides, network-fetch above, hides: it never mentions a sec_* name.
    # What the guard cannot see is a name the case never mentions in that shape (the five cases above, and
    # a source nothing links because nothing called its function). The OWED list in the README beside this
    # script carries these two limits, the stale-mutant sweep and the missing-mutant-file check.
    casefile=""
    for a in "$@"; do
        case "$a" in *.m) casefile="$a"; break;; esac
    done
    if [ -n "$casefile" ]; then
        strip() { sed -e 's://.*::' -e 's:/*[^*]* */::g' "$1"; }
        called=$(strip "$casefile" | grep -oE '\bsec_[a-z0-9_]+[[:space:]]*\(' | sed -E 's/[[:space:]]*\($//' | sort -u)
        for src in "$@"; do
            [ -f "$src" ] || continue
            strip "$src" | grep -E '\bsec_[a-z0-9_]+\(' | sed -nE 's/.*[^A-Za-z0-9_](sec_[a-z0-9_]+)\(.*/\1/p'
        done | sort -u > "$build/port-defines.txt"
        # nm's OWN STATUS, CAPTURED WITHOUT set -e KILLING THE SCRIPT FIRST. `nm ... > file` followed by
        # `nmstatus=$?` on the next line NEVER REACHES THE ASSIGNMENT under set -e: the script ends on the
        # failing command, so the branch below was unreachable and the guard died SILENTLY on an nm failure
        # instead of reporting one. The `|| status=$?` form is the one that survives, and the same slip was
        # made in run_mutation and fixed there - twice - before it was fixed here.
        nmstatus=0
        nm -gU "$build/$name" > "$build/$name.nm" 2>/dev/null || nmstatus=$?
        if [ "$nmstatus" -ne 0 ]; then
            echo "NOTRUN $name  nm -gU failed, so the case was never compared" > "$build/verdict-$name"; echo "BUILD  $name FAILED: nm -gU on the linked binary exited $nmstatus"
            failures=$((failures + 1))
            return
        fi
        for sym in $called; do
            grep -qx "$sym" "$build/port-defines.txt" || continue
            if [ "$(awk -v s="_$sym" '$NF==s' "$build/$name.nm" | wc -l)" -lt 1 ]; then
                echo "NOTRUN $name  a port symbol came from a dylib, so the case was never compared" > "$build/verdict-$name"; echo "MISSING $name $sym would measure the HOST: _$sym is not defined in the binary this case linked"
                failures=$((failures + 1))
                return
            fi
        done
    fi

    # RUN IT, COMPARE IT, SAY WHAT HAPPENED.
    status=0
    ( cd "$work" && "$build/$name" ) > "$build/$name.out" 2>&1 || status=$?
    cases=$((cases + 1))
    if [ "$status" -ge 128 ]; then
        echo "CRASH $name" > "$build/verdict-$name"; echo "CRASH  $name  crashed: signal $((status - 128)) (exit $status), not a comparison"
        sed 's/^/       /' "$build/$name.out" | tail -3
        failures=$((failures + 1))
        return
    fi
    if xmake l "$H/$compare" "$build/$name.out" > "$build/$name.verdict" 2>&1; then
        green=$((green + 1))
        echo "GREEN $name" > "$build/verdict-$name"; echo "GREEN  $name  $(tail -1 "$build/$name.verdict")"
    else
        echo "RED $name" > "$build/verdict-$name"; echo "RED    $name  $(tail -1 "$build/$name.verdict")"
        sed 's/^/       /' "$build/$name.verdict" | head -4
        failures=$((failures + 1))
    fi
}

# run_mutation NAME COMPARE CASEFILE ORIGIN [EXTRA...]
#
#   ORIGIN is the port source this mutant is a whole-file copy of, and EXTRA is whatever ELSE the
#   case's own run_case line carries. So the mutant's link line is
#       <the case>  <the mutant's copy of ORIGIN>  <EXTRA...>
#   which is the CASE's line with ORIGIN swapped - and the CONTROL below is that same line with the
#   unmutated ORIGIN put back.
#
# WHY THIS IS A CHECK AND NOT A COMMENT. run_mutation used to link the case, the mutant and one
# optional extra, and for sec-identity the case links four sources, so the three mutants were each
# built from three sources fewer than the case and went RED on rows the case never produced:
# `holder-class: the port's options holder was not found` and `local-identity-*: the case did not
# measure it` - differences that have nothing to do with a mutation, counted as though they did. A
# BYTE-IDENTICAL COPY of the unmutated source on that line was RED too, which is the measurement that
# shows it. So the control is built and compared HERE, before the mutant is looked at, and a red
# control is reported as INVALID MUTANT and fails the run instead of being read as coverage.
run_mutation() {
    # Same rule: counted where it runs, BEFORE the early return a crashing mutant takes. It was counted
    # after, so a mutation that segfaulted - the most emphatic "noticed" there is - was not counted at all.
    mutants=$((mutants + 1))
    # DECLARED is counted HERE and not where the mutant is written, because every run_mutation call is a
    # mutation this script means to judge - including the sec-identity trio and the one that must fail to
    # compile, which `mutate` never writes. Counting declarations where they are written would report a
    # smaller declared than run, and the line that says whether the matrix is whole would be the one
    # thing in the tail that cannot be trusted.
    declared=$((declared + 1))
    name=$1; compare=$2; casefile=$3; origin=$4; shift 4
    if [ ! -f "$build/mutant-$name.m" ]; then
        echo "RED    $name mutation NOT BUILT - nothing proved the case can fail"
        failures=$((failures + 1))
        return
    fi
    # THE CONTROL, on the IDENTICAL line with the unmutated source where the mutant's copy goes. This
    # is the run_mutation link line with one argument changed, so a control that is red cannot be
    # blamed on anything the mutation did.
    # $@ IS UNQUOTED ON PURPOSE, and it is the one place in this file where a list of files is
    # splatted: a case names its own extra objects ("$curve" above is three of them), and a quoted
    # "$@" hands clang ONE argument whose name is three paths and a space, which fails to build
    # for a reason that has nothing to do with the case. run_case's own link line has always splatted.
    if ! xcrun clang $common "$H/$casefile.m" "$origin" $@ \
         -framework Foundation -framework Security -framework CoreFoundation \
         -o "$build/control-$name" > "$build/control-$name.log" 2>&1; then
        echo "INVALID MUTANT $name  the control did not BUILD, so a verdict from this line would be the link's: $(grep -m1 'error:' "$build/control-$name.log" | cut -c9-)"
        failures=$((failures + 1))
        return
    fi
    cstatus=0
    ( cd "$work" && "$build/control-$name" ) > "$build/control-$name.out" 2>&1 || cstatus=$?
    if [ "$cstatus" -ge 128 ]; then
        echo "INVALID MUTANT $name  the CONTROL crashed (signal $((cstatus - 128))), so the line is not sound and the mutation's verdict would be the line's"
        failures=$((failures + 1))
        return
    fi
    if ! xmake l "$H/$compare" "$build/control-$name.out" > "$build/control-$name.verdict" 2>&1; then
        echo "INVALID MUTANT $name  the CONTROL is red, so this mutation proves NOTHING about the case: $(grep -m1 DIFFERS "$build/control-$name.verdict" | cut -c9-)"
        failures=$((failures + 1))
        return
    fi
    if ! xcrun clang $common "$H/$casefile.m" "$build/mutant-$name.m" $@ \
         -framework Foundation -framework Security -framework CoreFoundation \
         -o "$build/mutant-$name" > "$build/mutant-$name.log" 2>&1; then
        echo "BUILD  $name mutation FAILED to build"
        failures=$((failures + 1))
        return
    fi
    status=0
    ( cd "$work" && "$build/mutant-$name" ) > "$build/mutant-$name.out" 2>&1 || status=$?
    if [ "$status" -ge 128 ]; then
        # A MUTATION THAT CRASHES WAS NOTICED - that is the most emphatic form of "this comparison can
        # tell the case from a broken one" - so it is NOT a failure of the run, and the run says that
        # rather than leaving a crash and a non-zero exit to describe the same run.
        echo "CRASH  $name mutation  crashed: signal $((status - 128)) (exit $status) - NOTICED, and not a failure: a crash is a mutation the comparison caught"
        mutants_noticed=$((mutants_noticed + 1))
        return
    fi
    if xmake l "$H/$compare" "$build/mutant-$name.out" > "$build/mutant-$name.red" 2>&1; then
        if [ "$name" = "$EXPECTED_UNNOTICED" ]; then
            echo "EXPECTED  $name mutation  NOT noticed, and that is REQUIRED: it is a byte-identical copy, so
        the comparison passing is the whole point - and it is what proves the noticed count can go LOWER"
        else
            echo "RED    $name MUTATION WENT UNNOTICED - the comparison cannot tell this case from a broken one"
            failures=$((failures + 1))
        fi
    else
        echo "RED    $name mutation  $(grep -m1 DIFFERS "$build/mutant-$name.red" | cut -c9-)"
        mutants_noticed=$((mutants_noticed + 1))
    fi
}

# --- the mutants, written by patching the port source in the tree and keeping the copy ---
# A MUTATION THAT COULD NOT BE WRITTEN IS A MUTATION THAT WILL NOT RUN, AND THE RUN SAYS SO at the end
# rather than stopping there. This helper used to sys.exit, which under `set -eu` ended the whole run at
# the first anchor that no longer matched the file: a stale anchor is then a run that verifies two
# mutations, prints a tail shaped like a finished one, and never mentions the other sixteen. A suite that
# aborts silently is the defect class, so the write is allowed to fail, the mutation is still DECLARED,
# and the summary below is what says one did not run.
mutate() {
    if ! xmake l "$H/mutant.lua" "$@"; then
        failures=$((failures + 1))
    fi
}

F=$S/SecurityFunctions10_0_1.m
D=$S/SecCertificateNameDER10_3.m
N=$S/SecTrustNetworkFetch7_0.m
G=$S/SecTrustGetTrustResult7_0.m
O=$S/SecObjectWrappers12_0.m
SI=$S/SecObjectWrappersIdentity12_0.m
# The fourteen accessors of the absent-rows series, one object per release.
TA=$S/SecurityTrust7_0.m
TAS=$S/SecurityTrustAsync7_0.m
TOC=$S/SecurityTrustOCSP7_0.m
TCH=$S/SecurityTrustChain15_0.m
TSCT=$S/SecurityTrustSCT12_1.m
TK=$S/SecurityKeychain13_0.m
AC=$S/SecAccessControl8.m
K11=$S/SecurityConstants11_0.m
N70=$S/SecurityNames70.m
# the case's sources, with the one a mutant replaces given separately
TA_REST="$TAS $TOC $TCH $TSCT $TK $AC $K11 $N70"
SI16=$S/SecObjectWrappersIdentity16_0.m
LI=$S/SecProtocolOptionsLocalIdentity.m
PM=$S/SecProtocolMetadata13_0.m
PMA="$S/SecProtocolMetadataAccessors13_0.m $S/SecProtocolMetadataAccessors16_0.m"
PO=$S/SecProtocolOptions13_0.m
PC=$S/SecProtocolOptionsCiphersuite13_0.m
PR=$S/SecProtocolOptionsStrings13_0.m
PK=$S/SecProtocolOptionsBlocks13_0.m
PF=$S/SecProtocolOptionsFlags13_0.m
PD=$S/SecProtocolOptionsData13_0.m
PS=$S/SecProtocolOptionsSSLProtocol13_0.m

echo "== the Security host cases, from $(git -C "$work" rev-parse --short HEAD 2>/dev/null || echo '?') =="
# THE DIGESTS THE README PINS ARE CHECKED HERE, and not by hand. check-digests.lua existed and nothing
# ran it, which is the one defect this driver exists to end - a check nobody invokes is a check that
# cannot fail - so the README's "one command that runs everything here" was false while it stood alone.
# The script resolves the README and the cited files from __file__, so this is the same run from any
# working directory. Its exit is counted in `failures`, so a stale pin ends the run non-zero, and the
# count is NOT put in `green` or `cases`: those two are compared with each other at the tail and a
# digest line is not a case. It runs first because a pin that does not match the tree makes every
# verdict below it a verdict about files nobody can trust.
if xmake l "$H/check-digests.lua" > "$build/check-digests.log" 2>&1; then
    echo "GREEN  digests  $(tail -1 "$build/check-digests.log")"
else
    echo "RED    digests  the README's digests do not match the tree, so the verdicts below would be about files nobody can trust:"
    sed 's/^/       /' "$build/check-digests.log"
    failures=$((failures + 1))
fi
# The two verdicts a driver must keep apart, checked first so a driver that has conflated them says so
# before it goes on to report anything else.
# Security.framework IS LINKED, and without it the control is WORTHLESS: the first build did not link it,
# so SSLGetProtocolVersionMin did not resolve either and the real symbol and SSLNoSuchFunctionForControl
# both read missing 1 - indistinguishable, which is the exact failure the counter is meant to catch.
if xcrun clang -Wall -o "$build/crash-case" "$H/crash-case.c"      -framework Security -framework Foundation > "$build/crash-case.log" 2>&1; then
    # set -e EXITS ON A FAILING SIMPLE COMMAND, so "cmd; status=$?" never reaches the assignment: the
    # script died on the segfault before it could record the exit code it was trying to record, which is
    # the same class of bug as the one this commit fixes. `cmd || status=$?` is the form that survives.
    clean=0; missing=0; crashed=0
    "$build/crash-case" clean   >/dev/null 2>&1 || clean=$?
    "$build/crash-case" missing >/dev/null 2>&1 || missing=$?
    "$build/crash-case" crash   >/dev/null 2>&1 2>/dev/null || crashed=$?
    if [ "$clean" -eq 0 ] && [ "$missing" -eq 0 ] && [ "$crashed" -ge 128 ]; then
        echo "GREEN  verdicts     the three shapes behave: clean $clean, missing $missing, crash $crashed - AND crash $crashed IS THE EXPECTED SHAPE, deliberately provoked by crash-case, and NOT a failure of this run"
        # THE missing COUNTER, resolved through dlsym so it can actually become 1, and the CONTROL: the
        # same resolution pointed at a symbol that does not exist. A counter that reads 0 because nothing
        # can increment it is not a check.
        "$build/crash-case" SSLGetProtocolVersionMin resolve > "$build/present.txt" 2>&1 || true
        "$build/crash-case" SSLNoSuchFunctionForControl resolve > "$build/absent.txt" 2>&1 || true
        present=$(sed -n 's/.*\t\([01]\)$/\1/p' "$build/present.txt" | head -1)
        absent=$(sed -n 's/.*\t\([01]\)$/\1/p' "$build/absent.txt" | head -1)
        if [ "$present" = "0" ] && [ "$absent" = "1" ]; then
            echo "GREEN  missing     a real symbol resolves (missing 0) and SSLNoSuchFunctionForControl does not (missing 1), so the counter CAN fail"
        else
            echo "RED    missing     present=$present absent=$absent - the counter cannot tell the two apart"
            failures=$((failures + 1))
        fi
        # THE CONTROL: the same check against a shape it must REJECT. A verdict check that cannot fail
        # proves nothing, so the driver demands the wrong expectation be reported - and if this ever goes
        # green, the verdict logic has stopped being able to tell a crash from a difference.
        selfclean=0; selfcrashed=0
        "$build/crash-case" clean >/dev/null 2>/dev/null 2>/dev/null || selfclean=$?
        "$build/crash-case" crash >/dev/null 2>/dev/null 2>/dev/null || selfcrashed=$?
        if [ "$selfclean" -eq 0 ] && [ "$selfcrashed" -ge 128 ]; then
            echo "GREEN  control      a WRONG expectation (crash must be 0) is rejected: clean $selfclean, crash $selfcrashed, so this verdict logic CAN fail"
        else
            echo "RED    control      a wrong expectation was NOT rejected: clean $selfclean, crash $selfcrashed"
            failures=$((failures + 1))
        fi
    else
        echo "RED    verdicts     clean $clean, missing $missing, crash $crashed - one shape is wrong"
        failures=$((failures + 1))
    fi
else
    echo "BUILD  crash-case FAILED to build"
    failures=$((failures + 1))
fi
# --- the ten sec_protocol_* cases, each with the port source it links and its own comparator ---
protocol_case() {
    # THE SOURCES ARE "$*" AND NOT "$2". A case that needs SEVERAL port objects passed them as
    # separate arguments, and a function that read only $2 DROPPED THE REST ON THE FLOOR: the build
    # succeeded, the missing names resolved to the HOST, and the case measured the host while looking
    # exactly like a port measurement. It failed on four rows and the driver could not say why.
    name=$1; shift
    run_case "$name" "compare-$name.lua" "$H/$name.m" "$@"
}
protocol_case protocol-metadata            $PM
protocol_case protocol-metadata-accessors   $PM $PMA
protocol_case protocol-options             $PO
protocol_case protocol-options-held       $PO
protocol_case protocol-options-sslprotocol $PS
protocol_case protocol-options-ciphersuite $PC
protocol_case protocol-options-strings    $PR
protocol_case protocol-options-flags      $PF
protocol_case protocol-options-data       $PD
run_case sec-identity         compare-sec-identity.lua        $H/sec-identity.m $SI $SI16 $LI $O
protocol_case protocol-options-blocks     $PK
run_case certificate-name  compare-certificate-name.lua  $H/certificate-name.m $D
run_case certificate-fields compare-certificate-fields.lua $H/certificate-fields.m $D
run_case network-fetch     compare-network-fetch.lua     $H/network-fetch.m $N
run_case trust-result      compare-trust-result.lua      $H/trust-result.m $G

# The SHA-256 test is made UNSATISFIABLE rather than deleted: a `;` there ends the return and orphans the
# next `||`, so the first version of this mutation did not compile and the run reported a BUILD failure
# where a RED was required. An expression that is still valid but never true drops the algorithm just as
# well and keeps the mutant comparable.
mutate "$F" "$build/mutant-supported.m" \
'                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256)' \
'                || CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1)   // MUTANT: SHA-256 can never match' \
'the SHA-256 test can never match, so the table loses that algorithm'
mutate "$F" "$build/mutant-padding.m" \
'    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))
        return kSecPaddingPKCS1SHA256;' \
'    if (CFEqual(algorithm, kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256))
        return kSecPaddingPKCS1SHA384;   // MUTANT: SHA-384s padding for a SHA-256 algorithm' \
'a SHA-256 algorithm gets the SHA-384 padding'
# The EC row of the table, as it stands: the release DOES sign an elliptic key (kSecAttrKeyTypeEC is
# ios(4.0), SecItem.h:802-803), so the row is an allow-list of the two ECDSA digest algorithms rather
# than a refusal. The anchor is the WHOLE statement, not its first line, because a one-line anchor
# cannot express a replacement that covers both and a half-replaced statement does not compile - and
# this is what the anchor used to be, stale, after the row changed: the line it named (the
# `return false;      // EC signing arrives after 6.1.3` one) is gone, mutate matched it zero times, and
# under `set -eu` that ended the run at the second mutation of eighteen. The cell is the same one the
# old mutation held: the EC answer becomes the release's EC answer's opposite.
mutate "$F" "$build/mutant-verify-pairs.m" \
'        return CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureDigestX962SHA256)
            || CFEqual(algorithm, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);' \
'        return false;   // MUTANT: the EC allow-list is dropped, so an EC key is refused again' \
'the EC allow-list is dropped'
mutate "$F" "$build/mutant-attributes.m" \
'    if (CFGetTypeID(result) != CFDictionaryGetTypeID())' \
'    if (0)   // MUTANT: anything at all is passed off as an attributes dictionary' \
'anything is passed off as an attributes dictionary'
mutate "$D" "$build/mutant-certificate-name.m" \
'        at = next;                                // the version'"'"'s own TLV ended here' \
'        at = content;   // MUTANT: resume inside the versions integer' \
'the walk resumes inside the version integer'
mutate "$D" "$build/mutant-certificate-fields.m" \
'static const uint8_t RevenantOIDCommonName[] = {0x55, 0x04, 0x03};' \
'static const uint8_t RevenantOIDCommonName[] = {0x55, 0x04, 0x04};   // MUTANT: the SURNAME attribute' \
'the common name OID becomes the surname one'
mutate "$N" "$build/mutant-network-fetch.m" \
'        answer = CFSetContainsValue(RevenantSecurityNetworkFetchAllowed, trust) ? true : false;' \
'        answer = false;   // MUTANT: the set is consulted and the flag dropped' \
'the network-fetch flag is dropped after being looked up'
mutate "$O" "$build/mutant-sec-object-otherref.m" \
'    SecCertificateRef held = [(RevenantSecCertificate *)certificate revenantCertificate];' \
'    SecCertificateRef held = [(RevenantSecCertificate *)certificate revenantCertificate];
    // MUTANT: answer a NEW ref over the same DER. CFEqual says it is the same certificate and the
    // pointer says it is not, so ONLY the identity check can tell it apart from the caller\x27s
    return held ? (SecCertificateRef)SecCertificateCreateWithData(NULL, SecCertificateCopyData(held)) : NULL;' \
'copy_ref answers a NEW ref over the same DER'
mutate "$O" "$build/mutant-sec-object-noretain.m" \
'        _certificate = certificate ? (SecCertificateRef)CFRetain(certificate) : NULL;' \
'        _certificate = certificate;   // MUTANT: the retain is DROPPED, so the object holds a
        // reference it does not own and gives someone else\x27s away' \
'the creator does not retain, so the object holds a reference it does not own'
mutate "$G" "$build/mutant-trust-result.m" \
'    return SecTrustEvaluate(trust, result);   // the release'"'"'s own, iOS 2.0' \
'    *result = kSecTrustResultProceed;   // MUTANT: a verdict invented here
    return errSecSuccess;' \
'a verdict is invented instead of the releases own'

# THE FOUR MUTATIONS BELOW PATCH SecurityFunctions10_0_1.m, AND THAT FILE DISPATCHES INTO
# Security/SecKeyElliptic10.m: it holds the curve for the keys this package makes itself, so the four
# public names live in one file and the code they call lives in the other. A driver that links the first
# alone has six undefined RevenantSecKeyEC*/RevenantSecurity* symbols and reports INVALID MUTANT for the
# control, which is the LINK's failure read as the suite's. The two files and revenant@micro-ecc's wrapper
# go on the line together, the way tests/backports/host/seckeycurve/run.sh links them.
#
# BUILT WITH $common AND NOT WITH seckeycurve's OWN FLAGS, and that is the one detail that bites: this
# driver targets arm64-apple-ios15.0-macabi against the iOSSupport frameworks, so an object compiled
# for the host is a different architecture and the link says "ld: building for 'macCatalyst', but
# linking in object file .../uECC.o built for 'macOS'".
package=${SECURITY_MICRO_ECC:-$here/../../../../packages/libraries/micro-ecc}
clone="$build/micro-ecc"
[ -f "$clone/uECC.h" ] || git clone --quiet --depth 1 https://github.com/kmackay/micro-ecc.git "$clone" > /dev/null 2>&1
[ -f "$clone/uECC.h" ] || { echo "FAIL micro-ecc did not clone: no uECC.h in $clone"; exit 1; }
xcrun clang $common -I"$clone" -I"$package/files" -c "$clone/uECC.c" -o "$build/uECC.o"
xcrun clang $common -I"$clone" -I"$package/files" -c "$package/files/RevenantCKWebAuth.c" -o "$build/wrapper.o"
xcrun clang $common -I"$package/files" -I"$clone" -c "$S/SecKeyElliptic10.m" -o "$build/elliptic.o"
curve="$build/elliptic.o $build/uECC.o $build/wrapper.o"

# THE FOUR CASES NAME \$curve FOR THE SAME REASON THE FOUR MUTATIONS DO: they link
# SecurityFunctions10_0_1.m, which dispatches into the curve. They were declared above the objects are
# built, and so they linked that one file alone and failed with the same six undefined Revenant names - four
# BUILD lines in a run whose tail looked otherwise finished.
run_case supported          compare-supported.lua          $H/supported.m $F $curve
run_case padding           compare-padding.lua           $H/padding.m $F $curve
run_case verify-pairs      compare-verify-pairs.lua      $H/verify-pairs.m $F $curve
run_case attributes        compare-attributes.lua        $H/attributes.m $F $curve

run_mutation supported          compare-supported.lua          supported          $F $curve
run_mutation padding           compare-padding.lua           padding           $F $curve
run_mutation verify-pairs      compare-verify-pairs.lua      verify-pairs      $F $curve
run_mutation attributes        compare-attributes.lua        attributes        $F $curve
run_mutation certificate-name  compare-certificate-name.lua  certificate-name  $D
run_mutation certificate-fields compare-certificate-fields.lua certificate-fields $D
run_mutation network-fetch     compare-network-fetch.lua     network-fetch     $N
must_not_compile() {
    # IT IS A MUTATION AND IT COUNTS AS ONE. It incremented `noticed` without incrementing `mutants`,
    # so the run reported 11 noticed against 10 mutations: a compiler-refused mutation was being counted
    # as evidence without being counted as an attempt, which is the one thing a coverage summary must not
    # do. The increment belongs at the top, like the other two runners. `declared` is incremented with
    # it, for the same reason: this runner is a mutation this script means to judge, and a coverage line
    # that counted it as an attempt but not as a declaration would say the matrix is smaller than it is.
    mutants=$((mutants + 1))
    declared=$((declared + 1))
    name=$1; sources=$2
    # THE CONTROL, and for this runner it is the other way round: the verdict here is a build FAILING,
    # so what has to be shown first is that the UNMUTATED line BUILDS. Without it a source that does not
    # compile makes every must-not-compile mutant "noticed" for a reason that has nothing to do with the
    # type system - the same shape as a red control in run_mutation, and the reason the two runners are
    # now held to one rule rather than one of them.
    if ! xcrun clang $common "$H/$3.m" $sources \
         -framework Foundation -framework Security -framework CoreFoundation \
         -o "$build/control-$name" > "$build/control-$name.log" 2>&1; then
        echo "INVALID MUTANT $name  the control did not BUILD, so a refusal would prove nothing: $(grep -m1 'error:' "$build/control-$name.log" | cut -c9-)"
        failures=$((failures + 1))
        return
    fi
    if xcrun clang $common "$H/$3.m" "$build/mutant-$name.m" $sources \
         -framework Foundation -framework Security -framework CoreFoundation \
         -o "$build/mustfail-$name" > "$build/mustfail-$name.log" 2>&1; then
        echo "NOTICED  $name mutation  it BUILT, and the type system was supposed to refuse it"
        failures=$((failures + 1))
    else
        echo "NOTICED  $name mutation  refused by the compiler, as it must: $(grep -m1 'error:' "$build/mustfail-$name.log" | cut -c9-)"
        mutants_noticed=$((mutants_noticed + 1))
    fi
}

# make-mutants.lua IS NOT OPTIONAL AND ITS FAILURE IS NOT SWALLOWED. It ran under
# `2>/dev/null || true`, so a wrong anchor, a missing file or a write error was invisible here and the
# driver went on to report a mutant as "refused by the compiler" - which reads as a PASS. A script that
# writes the evidence a later verdict depends on must fail the run, and its output is kept.
if ! xmake l "$H/make-mutants.lua" "$build" > "$build/make-mutants.log" 2>&1; then
    echo "BUILD  make-mutants.lua FAILED (exit non-zero) - the mutants this run will judge were not written"
    sed 's/^/       /' "$build/make-mutants.log" | tail -3
    failures=$((failures + 1))
    mutants=0
    mutants_noticed=0
else
    for want in mutant-blocks-challenge-into-keyupdate.m mutant-data-halfpair.m mutant-held-nocopy.m \
                mutant-identity.m; do
        if [ ! -f "$build/$want" ]; then
            echo "BUILD  make-mutants.lua reported success but $want is ABSENT - the evidence is not there"
            failures=$((failures + 1))
        fi
    done
fi
# The fourteen rows of coordination/corpus/queue/Security.tsv: the PORT's answer beside the HOST'S on
# one run, so a difference is a measurement and not an assertion. Twenty-one of the twenty-eight keys
# must agree - the three constants' values, the OIDs, the chain, the verdict, both async pairs and both
# setter statuses - and seven must differ by the reason compare-trust-accessors.lua names.
run_case trust-accessors  compare-trust-accessors.lua  $H/trust-accessors.m  $TA $TA_REST

# Seven mutations, one per answer the case can be asked to hold. Each replaces its own origin on the
# link line - run_mutation's rule - and each has a control on the identical line.
mutate "$TCH" "$build/mutant-chain-guard.m" \
'    if (count < 1)' \
'    if (count < 2)' \
'a trust with one certificate answers NULL instead of the chain it holds'
mutate "$TA" "$build/mutant-result-no-date.m" \
'{kSecTrustResultValue, kSecTrustEvaluationDate}' \
'{kSecTrustResultValue, kSecTrustResultValue}' \
'the result dictionary loses its evaluation date'
mutate "$TA" "$build/mutant-result-no-value.m" \
'{kSecTrustResultValue, kSecTrustEvaluationDate}' \
'{kSecTrustEvaluationDate, kSecTrustEvaluationDate}' \
'the result dictionary loses the verdict, which is the one key the release owns'
mutate "$TA" "$build/mutant-oid-swapped.m" \
'        oid = kSecPolicyAppleSSL;' \
'        oid = kSecPolicyAppleX509Basic;' \
'an SSL policy is given the basic X.509 OID, which the key count alone cannot see'
mutate "$K11" "$build/mutant-constant-split.m" \
'kSecAttrPersistantReference = CFSTR("persistref")' \
'kSecAttrPersistantReference = CFSTR("persref")' \
'the misspelled spelling gets a value of its own instead of the one both names carry'
mutate "$TOC" "$build/mutant-ocsp-refuses.m" \
'    return errSecSuccess;   // the release' \
'    return errSecUnimplemented; // the release' \
'the OCSP setter refuses instead of accepting, which is the answer that must match the host'
mutate "$TSCT" "$build/mutant-sct-refuses.m" \
'    return errSecSuccess;   // the release' \
'    return errSecParam; // the release' \
'the SCT setter refuses instead of accepting, likewise'
mutate "$AC" "$build/mutant-ac-type-id-cfstring.m" \
'    return (CFTypeID)[RevenantSecAccessControl class];' \
'    return (CFTypeID)CFStringGetTypeID();' \
'the access control type ID answers another type'"'"'s, the wrongness this row exists to avoid'

run_case sec-object-wrappers compare-sec-object-wrappers.lua $H/sec-object-wrappers.m $O
run_mutation sec-object-otherref compare-sec-object-wrappers.lua sec-object-wrappers $O
run_mutation sec-object-noretain compare-sec-object-wrappers.lua sec-object-wrappers $O
# THE BLOCKS MUTATION MUST NOT COMPILE, and its call was LOST in the F3 revert - only the function
# definition survived, so a run quietly stopped proving that. It is restored here beside the other two.
# THE THREE sec-identity MUTANTS. Each mutant REPLACES the case's own port source - run_mutation always
# builds $build/mutant-<name>.m beside the case file - so a mutant ADDED beside the original instead
# would give duplicate symbols, and one built without it is building something else. Each is a
# whole-file copy of the source with ONE line changed, so it differs in BEHAVIOUR and nothing else.
make_mutant() {   # <out> <from> <old line> <new line>
    xmake l "$H/mutant.lua" "$2" "$1" "$3" "$4"
}
make_mutant "$build/mutant-sec-identity-nocopy.m"   "$SI" \
    '    _certificates = certificates ? (CFArrayRef)CFArrayCreateCopy(kCFAllocatorDefault, certificates) : NULL;' \
    '    _certificates = certificates ? (CFArrayRef)CFRetain(certificates) : NULL;   // MUTANT: an ALIAS, not a copy'
make_mutant "$build/mutant-sec-identity-noretain.m" "$SI" \
    '    return held ? (SecIdentityRef)CFRetain(held) : NULL;' \
    '    return held;   // MUTANT: no +1, so the object is the only owner and the caller is given a ref it does not hold'
make_mutant "$build/mutant-sec-identity-nohandler.m" "$SI16" \
    '        handler(wrapper);' \
    '        (void)wrapper;   // MUTANT: the handler is NEVER CALLED'
# THE sec-identity CASE is built as $H/sec-identity.m $SI $SI16 $LI $O, so each of its mutants is
# built as that line with ONE of those four swapped for the mutant's copy of it - and every one of the
# four is named, because a line that drops a source the case links produces rows the case never
# measured and a mutation judged on it means nothing. run_mutation's control is the same line with the
# unmutated source back, so this cannot rot quietly again.
run_mutation sec-identity-nocopy   compare-sec-identity.lua sec-identity $SI   $SI16 $LI $O
run_mutation sec-identity-noretain compare-sec-identity.lua sec-identity $SI   $SI16 $LI $O
# nohandler's copy is of the 16.0 object, so THAT is the origin and the 12.0 one is an extra: the
# mutant calls the class the 12.0 object defines.
run_mutation sec-identity-nohandler compare-sec-identity.lua sec-identity $SI16 $SI $LI $O
# THE DEFAULTS MUTANT: the minimum answered as a value the enum does not have. 0x0300 is not a member of
# tls_protocol_version_t at all - the lowest is 0x0301 - so a row that drifted below the enum's floor
# would still be a plausible-looking number and only this comparison would see it.
make_mutant "$build/mutant-defaults-below-enum.m" "$PO" \
    '    return tls_protocol_version_TLSv10;' \
    '    return (tls_protocol_version_t)0x0300;   // MUTANT: below the enum'"'"'s lowest member'
# The mutant IS a copy of SecProtocolOptions13_0.m, which IS this case's own source, so ORIGIN is it
# and there is no extra: the line is the case and the mutant. That line used to carry MUTANT_EXTRA=$SI,
# a copy-paste of the line above it here, and `sh -x` showed the identity object on the link - a source
# this comparison cannot see, put there by accident.
run_mutation defaults-below-enum compare-protocol-options.lua protocol-options $PO
must_not_compile blocks-challenge-into-keyupdate "$PK" protocol-options-blocks
# data-halfpair IS SecProtocolOptionsData13_0.m, so it REPLACES the case's source and is not added beside
# it - passing it again as an extra source is a duplicate symbol, which is what it did first.
run_mutation data-halfpair compare-protocol-options-data.lua protocol-options-data $PD
# held-nocopy mutates the IVAR in SecProtocolOptions13_0.m, which IS the case's own source, so it
# REPLACES it and is not added beside it - adding it is a duplicate symbol, which is what it did first.
run_mutation held-nocopy   compare-protocol-options-held.lua  protocol-options-held $PO
run_mutation identity       compare-protocol-options-held.lua  protocol-options-held $PO
run_mutation trust-result      compare-trust-result.lua      trust-result      $G
run_mutation chain-guard       compare-trust-accessors.lua  trust-accessors  $TCH $TAS $TOC $TA $TSCT $TK $AC $K11 $N70
run_mutation result-no-date    compare-trust-accessors.lua  trust-accessors  $TA  $TAS $TOC $TCH $TSCT $TK $AC $K11 $N70
run_mutation result-no-value   compare-trust-accessors.lua  trust-accessors  $TA  $TAS $TOC $TCH $TSCT $TK $AC $K11 $N70
run_mutation oid-swapped      compare-trust-accessors.lua  trust-accessors  $TA  $TAS $TOC $TCH $TSCT $TK $AC $K11 $N70
run_mutation constant-split   compare-trust-accessors.lua  trust-accessors  $K11 $TA $TAS $TOC $TCH $TSCT $TK $AC $N70
run_mutation ocsp-refuses      compare-trust-accessors.lua  trust-accessors  $TOC $TA $TAS $TCH $TSCT $TK $AC $K11 $N70
run_mutation sct-refuses       compare-trust-accessors.lua  trust-accessors  $TSCT $TA $TAS $TOC $TCH $TK $AC $K11 $N70
run_mutation ac-type-id-cfstring compare-trust-accessors.lua trust-accessors $AC $TA $TAS $TOC $TCH $TSCT $TK $K11 $N70

# --- the fuzz: no comparison, it must simply not crash, and it is built with the sanitizers on ---
if xcrun clang $common -fsanitize=address,undefined -fno-omit-frame-pointer -g \
     "$H/der-fuzz.m" "$D" -framework Foundation -framework Security -framework CoreFoundation \
     -o "$build/der-fuzz" > "$build/der-fuzz.log" 2>&1; then
    if ( cd "$work" && ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=halt_on_error=1 "$build/der-fuzz" ) \
         > "$build/der-fuzz.out" 2>&1; then
        echo "GREEN  der-fuzz  $(tail -2 "$build/der-fuzz.out" | head -1)"
    else
        echo "RED    der-fuzz CRASHED OR TRIPPED A SANITIZER"
        tail -12 "$build/der-fuzz.out" | sed 's/^/       /'
        failures=$((failures + 1))
    fi
else
    echo "BUILD  der-fuzz FAILED - $build/der-fuzz.log"
    failures=$((failures + 1))
fi

# A MUTATION THAT MUST NOT COMPILE is a mutation the type system caught, and it is noticed - so it is
# expected to FAIL TO BUILD rather than to fail a comparison. The challenge-into-key-update mutation
# assigns one block typedef to another's slot, which is a conflicting-type error, and a driver that only
# knows "it built, so run it" would report the build failure as a case that did not run.

# THE SUMMARY MUST AGREE WITH ITS OWN LINES. A run whose GREEN count differs from the case count has
# described a set it did not measure, which is the defect class this whole hunt is for: the tail looked
# fine while run_case built binaries and never compared them.
# EVERY CASE GETS EXACTLY ONE VERDICT LINE. Any case that entered and has no verdict is named NOT-RUN,
# so a missing line is impossible rather than something a reader has to infer from a count.
for c in $(cat "$build/cases-entered" 2>/dev/null); do
    if [ ! -s "$build/verdict-$c" ]; then
        echo "NOTRUN  $c  entered the driver and printed no verdict at all"
        failures=$((failures + 1))
    fi
done
echo
# EVERY DECLARED MUTATION MUST BE ONE THAT RAN. A mutation declared and not run is the silent abort
# this suite was found to have, and the count is the only place it shows.
echo "run-cases: $mutants mutations run of $declared declared"
if [ "$mutants" -ne "$declared" ]; then
    echo "run-cases: $((declared - mutants)) declared mutation(s) did not run - the matrix above is not the whole one"
    failures=$((failures + 1))
fi
if [ "$green" -ne "$cases" ]; then
    echo "run-cases: $green GREEN verdict lines for $cases cases - the summary does not match the lines it printed"
    exit 1
fi
if [ "$failures" -eq 0 ]; then
    echo "run-cases: OK - $cases cases, $mutants mutants, $mutants_noticed noticed"
else
    echo "run-cases: $failures failure(s) - $cases cases, $mutants mutants, $mutants_noticed noticed"
fi
exit "$failures"
