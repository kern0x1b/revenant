#!/bin/sh
# values.sh -- what a request HOLDS, as against what it BINDS.
#
# run.sh reads the binary and asks whether a member is bound. A value is not a method, so this is the
# second instrument: it runs the code. Two builds of the same source in one process -- the host's own
# classes, named as the SDK header names them and linked from the framework, and the port's, which this
# process never names because the port's own build renames them.
#
# The renames are on the port's translation units only, never on values.m: a test compiled with them
# would be asking the port's version of the question and calling it the host's.
#
# How a request is made is the whole thing. ASAuthorizationRequest's header marks -init and +new
# NS_UNAVAILABLE because a request is not constructed -- it comes from a provider, and the SDK gives the
# path: [[ASAuthorizationAppleIDProvider alloc] init] createRequest, which needs no daemon, no network
# and no UI. The port's provider is not implemented yet, so the port's request is made with alloc/init,
# which the port binds because its own header does not mark it unavailable. Two constructors, one per
# side, and the report says which.
#
#   sh values.sh               measure, exit 0 only when the two builds hold the same values
#   sh values.sh --mutate      change the port's default operation and require a difference
set -eu
here=$(cd "$(dirname "$0")" && pwd)
charon=${CHARON:-$here/../../../..}
package="$charon/packages/a/apple-backports/AuthenticationServices"
framework=/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices
build=${BUILD:-$charon/.agent-work/runs/authservices-values}
mutate=${1:-}
mkdir -p "$build"

# Before anything is built or run: the host half must not name any of the four methods that write this
# Mac's AutoFill state. Three checks answer three different questions, so each is named with the question
# it answers, and none of them is a fourth thing:
#
#   the GUARD        host-write-guard.py drops the comment lines and looks for this Mac's own
#                     ASCredentialIdentityStore class NAME in what is left. The question is CAN A PROBE
#                     EVEN HOLD THE HOST'S STORE. It does not look at the four writing selectors at all --
#                     those are the scan's -- and it is not what stands between this machine and its
#                     AutoFill state, because a probe sends selectors as strings through a cast
#                     objc_msgSend and reading a file cannot see that.
#   the SCAN         writing-selectors-scan.py greps the four writing selector names over the harness
#                     sources with the allowlist. The question is CAN A WRITE BE DISPATCHED WITHOUT THE
#                     RECEIVER CHECK -- every hit must be a comment, a string, or an allowlist line.
#   the RUNTIME half port-store-selftest.m asks the predicate the chokepoint uses -- the receiver's
#                     class name out of the runtime -- about this Mac's own
#                     ASCredentialIdentityStore class object, with the four selectors as strings and
#                     nothing sent. The question is WOULD A WRITE TO THE HOST'S STORE GET THROUGH, and
#                     this is the half that protects the machine, because it does not depend on reading
#                     any source.
python3 "$here/host-write-guard.py" "$here/values.m" "$here/hostshape.c"

# One -D list, used by every build of the port: the three classes it implements, and the one key it owns.
# The other names in the framework -- ASAuthorizationProvider, the scope and operation typedefs, the
# operations themselves -- are the release's, and the release's are what the host is asked about.
# One line, split where it is used. This was a multi-line string handed to `set --`, which set the
# SCRIPT's positional parameters, and inside build_and_run "$@" is the function's own two arguments --
# so the compiler was handed the tag "plain" where a -D belongs.
renames="-DASAuthorizationRequest=PortASAuthorizationRequest \
-DASAuthorizationOpenIDRequest=PortASAuthorizationOpenIDRequest \
-DASAuthorizationAppleIDRequest=PortASAuthorizationAppleIDRequest \
-DASAuthorizationAppleIDProvider=PortASAuthorizationAppleIDProvider \
-DASCharonProviderCodingKey=PortASCharonProviderCodingKey \
-DASCredentialServiceIdentifier=PortASCredentialServiceIdentifier \
-DASCredentialServiceIdentifierType=PortASCredentialServiceIdentifierType \
-DASPasswordCredentialIdentity=PortASPasswordCredentialIdentity \
-DASCredentialIdentityStore=PortASCredentialIdentityStore \
-DASCredentialIdentityStoreState=PortASCredentialIdentityStoreState -DASPasswordCredential=PortASPasswordCredential -DASCredentialProviderExtensionContext=PortASCredentialProviderExtensionContext \
-DASCredentialIdentityStoreErrorDomain=PortASCredentialIdentityStoreErrorDomain \
-DASCredentialIdentityStoreErrorCodeInternalError=PortASStoreErrorInternal \
-DASCredentialIdentityStoreErrorCodeStoreDisabled=PortASStoreErrorDisabled \
-DASCredentialIdentityStoreErrorCodeStoreBusy=PortASStoreErrorBusy"

: "${AS_CREDENTIAL_STORE_PATH:=$build/credential-store.plist}"
: "${CHICON_RUNS:=$build}"
export AS_CREDENTIAL_STORE_PATH CHICON_RUNS

sources="ASConstants12_0.m ASConstants13_0.m ASAuthorizationRequest.m ASAuthorizationOpenIDRequest.m ASAuthorizationAppleIDRequest.m \
ASAuthorizationAppleIDProvider.m ASCredentialServiceIdentifier.m ASPasswordCredentialIdentity.m \
ASCredentialIdentityStoreState.m ASCredentialIdentityStore.m ASPasswordCredential.m ASPortCredentialExchange.m ASCredentialProviderExtensionContext.m"

# build_and_run <source-dir> <tag>: compile the port's three sources from there under the renames, link
# them with the test into one binary, and run it. The tag is where the table lands. It returns the
# binary's status and never decides anything: a verdict is the caller's to give.
build_and_run() {
    from=$1
    tag=$2
    objects=""
    for name in $sources; do
        [ -f "$from/$name" ] || { echo "FAIL: $from/$name is not there"; return 1; }
        # shellcheck disable=SC2086
        xcrun clang -fobjc-arc -Os -g0 -I"$from" $renames -c "$from/$name" -o "$build/$tag-$name.o" \
            2> "$build/$tag-$name.log" || {
                echo "FAIL: $from/$name did not compile"; head -5 "$build/$tag-$name.log"; return 1; }
        objects="$objects $build/$tag-$name.o"
    done
    # -I"$from" is the port's own header directory, and values.m needs it: ASCredentialProviderExtensionContext
    # hands out -lastExchange, and a caller that reads what came back has to be able to NAME its type, which is
    # why the record's type lives in a port header rather than in the .m that implements it.
    xcrun clang -fobjc-arc -I"$from" -framework Foundation -framework AuthenticationServices \
        -o "$build/$tag-values" "$here/values.m" $objects 2> "$build/$tag-link.log" || {
            echo "FAIL: the two builds did not link into one binary"; head -6 "$build/$tag-link.log"; return 1; }
    # The port's renames are what make them a second hierarchy rather than a second name: the three
    # Port classes are in the binary and nothing else is.
    portCount=$(nm -m "$build/$tag-values" 2>/dev/null | grep -cE 'OBJC_CLASS_[$]_PortASAuthorization(Request|OpenIDRequest|AppleIDRequest|AppleIDProvider)' || true)
    if [ "$portCount" -ne 4 ]; then
        echo "FAIL: the binary does not carry the port's four renamed classes ($portCount found)"
        return 1
    fi
    "$build/$tag-values" "$framework" > "$build/$tag-table.txt" 2> "$build/$tag-table.err" || {
        echo "FAIL: the test did not run"; head -5 "$build/$tag-table.err"; return 1; }
    return 0
}

# verdict <table>: the host's answers are the reference and the port's half is the same lines. A
# difference is a behavioural difference an application can observe, and no member list can see it.
# It reports and returns non-zero; it does not exit, because a function that returns a verdict has no
# business deciding whether the run continues.
verdict() {
    python3 - "$1" <<'PYTHON'
import re, sys
host, port, side = {}, {}, None
for line in open(sys.argv[1]):
    line = line.rstrip("\n")
    if line in ("host", "port"):
        side = line
        continue
    if side and line.startswith("  "):
        parts = [part for part in re.split(r"\s{2,}", line.strip()) if part]
        if len(parts) >= 3:
            (host if side == "host" else port)[parts[0] + " " + parts[1]] = parts[-1]
        elif len(parts) == 2:
            (host if side == "host" else port)[parts[0]] = parts[1]
built = [(side, table.get("built request class")) for side, table in (("host", host), ("port", port))]
built = [(side, name) for side, name in built if name]
if len(built) == 2:
    if built[0][1] == built[1][1]:
        print("\nFAIL: both sides built their request from %s: that is one class, not two" % built[0][1])
        sys.exit(1)
    print("\n   two call targets: the host's request came from %s and the port's from %s"
          % (built[0][1], built[1][1]))
differ = [key for key in host if not key.startswith("built") and port.get(key) != host[key]]
print("   %d keys, %d differ between the two builds" % (len(host), len(differ)))
for key in differ:
    print("     DIFFERS %-32s host %-8s port %s" % (key, host[key], port.get(key)))
sys.exit(1 if differ else 0)
PYTHON
}

build_and_run "$package" plain

cat "$build/plain-table.txt"
status=0
verdict "$build/plain-table.txt" || status=$?
echo

if [ "$mutate" != "--mutate" ]; then
    if [ "$status" -ne 0 ]; then
        echo "FAIL: the two builds disagree about what a request holds"
        exit 1
    fi
    echo "ok: the host's and the port's requests hold the same values, asked through the provider"
    exit 0
fi

# The mutants, in the port's own source. Two, because the two claims each have one: a fresh request's
# default operation becomes the implicit one, which is what this port shipped until the host was asked
# what it actually holds; and the store's replace keeps the old set instead of replacing it, which is
# the behaviour the coordinator had rejected. Each copy is built the same way from the same list, so a
# mutant and the original differ in one value and in nothing else.
#
#   $1 is the case: "operation" or "replace"
echo "== mutants: each one has to be red, and neither is the other's"

# run_mutant <tag> <target> <old> <new> <what it is>
# run_mutant <tag>_from_file <anchor-file> <replacement-file> <target> <what it is>
#
# Both forms apply to the ONE named target file, through apply-anchor.py, which asserts the anchor
# occurs exactly once there before it writes. The first version ran its pattern over every .m in the copy
# and at every occurrence in each; the line it changed is also the first line of -charon_records, so the
# mutant's -charon_records began by calling -charon_records and the store's reads recursed until the stack
# went. That is the SIGSEGV the replace mutant was reported as, and the reason a mutation has to name a
# PLACE rather than a line: the same line is two different places depending on the method it is in.
run_mutant() {
    tag=$1
    anchorFile=""
    replFile=""
    # The marker is a SUFFIX on the tag, not a whole tag: it was two tags spelled out, and the third
    # mutant -- the credential's copy -- was silently run in the INLINE form with another mutant's
    # target, which is how a mutation meant for one class nearly mutated another.
    case "$tag" in
        *_from_file)
            # run_mutant <tag>_from_file <anchor> <replacement> <target> <what>
            anchorFile=$2; replFile=$3; target=$4; what=$5
            shift
            ;;
        *)
            # run_mutant <tag> <target> <old> <new> <what>
            target=$2; anchor=$3; repl=$4; what=$5
            shift
            ;;
    esac
    echo
    echo "-- $tag: $what"
    rm -rf "$build/$tag"
    mkdir -p "$build/$tag"
    for source in $sources; do cp "$package/$source" "$build/$tag/$source"; done
    cp "$package"/*.h "$build/$tag/" 2>/dev/null || true
    if [ ! -f "$build/$tag/$target" ]; then
        echo "FAIL: the mutation names $target, which is not one of the port's sources"
        return 1
    fi
    if [ -n "$anchorFile" ]; then
        python3 "$here/apply-anchor.py" "$anchorFile" "$replFile" "$build/$tag/$target" \
            || { echo "FAIL: the $tag mutation did not apply, and nothing was written"; return 1; }
    else
        # The inline form writes its two halves out and goes through the same one file, so both forms
        # are the same edit applied the same way.
        printf '%s\n' "$anchor" > "$build/$tag/.anchor"
        printf '%s\n' "$repl" > "$build/$tag/.repl"
        python3 "$here/apply-anchor.py" "$build/$tag/.anchor" "$build/$tag/.repl" "$build/$tag/$target" \
            || { echo "FAIL: the $tag mutation did not apply, and nothing was written"; return 1; }
    fi
    cmp -s "$build/$tag/$target" "$package/$target" && { echo "FAIL: the mutation changed nothing"; return 1; }
    echo "   $target changed:"
    diff "$package/$target" "$build/$tag/$target" | grep -E "^[<>]" | sed 's/^/     /' | head -4
    set +e
    build_and_run "$build/$tag" "$tag"
    built=$?
    set -e
    [ "$built" -eq 0 ] || { echo "FAIL: the $tag build did not complete"; return 1; }
    # The same comparison the check makes, over the same rows, by the same script a reader can run:
    # every row the check MEASURES, with the `built` rows excluded, because they are the control rather
    # than a measurement and a relocated address is not a value. This is compare-tables.py, not a
    # heredoc -- the heredoc version wrote an empty report and the run then claimed a row it never named.
    set +e
    python3 "$here/compare-tables.py" "$build/plain-table.txt" "$build/$tag-table.txt" \
        > "$build/$tag-verdict.txt" 2>&1
    judged=$?
    set -e
    sed 's/^/     /' "$build/$tag-verdict.txt"
    if [ "$judged" -eq 0 ]; then
        echo "FAIL: the $tag mutation changed no row the check measures -- a relocated address is not a value"
        return 1
    fi
    echo "   the $tag mutation is red, and the row that changed is named above"
    return 0
}

status=0
run_mutant operation ASAuthorizationOpenIDRequest.m "_requestedOperation = nil;" "_requestedOperation = [ASAuthorizationOperationImplicit copy];" "a fresh request's default operation becomes the implicit one" || status=1
run_mutant credential_from_file "$here/credential.anchor" "$here/credential.repl" ASPasswordCredential.m \
    "a credential's copy drops the password, which is what makes it a copy of nothing" || status=1
# A mutant whose check is the SCAN, not a value comparison, because a class that cannot be built for
# the host has no value table: the only thing a value comparison could say about it is nothing. The
# mutation is applied to a COPY of the port's sources, exactly as the other mutants are, so the tracked
# tree is never dirtied and there is nothing to restore; and the check is required to go RED by naming
# this class's file and line, which is the verdict.
run_scan_mutant() {
    tag=$1; anchorFile=$2; replFile=$3; target=$4; what=$5
    echo
    echo "-- $tag: $what"
    rm -rf "$build/$tag"
    mkdir -p "$build/$tag"
    for source in $sources; do cp "$package/$source" "$build/$tag/$source"; done
    cp "$package"/*.h "$build/$tag/" 2>/dev/null || true
    cp "$package/$target" "$build/$tag/$target"
    python3 "$here/apply-anchor.py" "$anchorFile" "$replFile" "$build/$tag/$target" \
        || { echo "FAIL: the $tag mutation did not apply, and nothing was written"; return 1; }
    cmp -s "$build/$tag/$target" "$package/$target" && { echo "FAIL: the mutation changed nothing"; return 1; }
    diff "$package/$target" "$build/$tag/$target" | grep -E "^[<>]" | sed 's/^/     /' | head -4
    set +e
    python3 "$here/writing-selectors-scan.py" "$build/$tag/$target" > "$build/$tag-scan.txt" 2>&1
    set -e
    sed 's/^/     /' "$build/$tag-scan.txt" | grep -E "FAIL|ok:" | head -4
    if ! grep -qE "^FAIL  $target:[0-9]+" "$build/$tag-scan.txt"; then
        echo "FAIL: the $tag mutation left the scan green -- the scan is the defect, not the mutant"
        return 1
    fi
    echo "     VERDICT the scan is red by this class's file and line, which is the row it measures"
    return 0
}

run_scan_mutant provider_from_file "$here/provider.anchor" "$here/provider.repl" \
    ASCredentialProviderViewController.m \
    "a base class default that reaches for the store" || status=1

run_mutant context_from_file "$here/context.anchor" "$here/context.repl" ASCredentialProviderExtensionContext.m \
    "a cancellation that drops the error, so a failed exchange looks like one that stopped" || status=1

run_mutant replace_from_file "$here/replace.anchor" "$here/replace.repl" ASCredentialIdentityStore.m \
    "replace keeps the old identities: the set it starts from is what the store already held" || status=1
exit "$status"
