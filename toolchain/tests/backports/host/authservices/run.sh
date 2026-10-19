#!/bin/sh
# run.sh -- the host differential for AuthenticationServices' surface shape, with a mutant.
#
# **The member list comes from clang**, not from a pattern: members.py runs `clang -ast-dump=json` over
# the class's own header and takes its ObjCMethodDecls. That is the header as the compiler reads it, and
# it is the only source that gives the full selector -- initWithURL:callbackURLScheme:completionHandler:
# is one member and initWithURL: is not a member of anything -- which class or instance, and whether the
# release marks it NS_UNAVAILABLE. The first version used regular expressions and produced a selector
# nobody declared.
#
# **Both sides are answered from a runtime view.** The host's own copy of the framework, asked with
# class_getInstanceMethod and class_getClassMethod by hostshape.c. The port's built library, read out of
# the linked binary's method list by portshape.py -- the port's objects are armv7 and this host is arm64,
# so the library cannot be dlopen'd here and its method list is read out of the file instead. Reading the
# port's *source text* was the earlier mistake, and it invented a selector the file does not contain.
# An inherited method counts on both sides, which is the control: +new comes from NSObject.
#
# **A class the registry carries and whose header cannot be found is an error.** There is no table here
# to be left out of, which is what let a class be asked about one member and pass.
#
# The port's library is built from this worktree's own sources into .agent-work/runs/, so the port side
# measures the tree and not a gate's older binary.
#
#   sh run.sh                measure, exit 0 only when every case agrees
#   sh run.sh --mutate       remove one method from the port and require exactly that case red
set -eu
here=$(cd "$(dirname "$0")" && pwd)
charon=${CHARON:-$here/../../../..}
package="$charon/packages/a/apple-backports/AuthenticationServices"
registry="$charon/packages/a/apple-backports/registry/AuthenticationServices"
framework=${AS_FRAMEWORK:-AuthenticationServices}
build=${BUILD:-$charon/.agent-work/runs/authservices-shape}
mkdir -p "$build"

# The SDK the port is compiled against: the headers are where the member list comes from and the SDK is
# where the library is built with, so the two can never be from different SDKs.
sdk=${AS_SDK:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/*/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null | head -1)}
if [ -z "$sdk" ] || [ ! -d "$sdk" ]; then
    echo "FAIL: no iPhoneOS SDK on this machine. The member list comes from the headers and the library"
    echo "      is built with it, and measuring against a list or a toolchain kept here instead is the"
    echo "      gap this check exists to close. Set AS_SDK."
    exit 1
fi
headers="$sdk/System/Library/Frameworks/AuthenticationServices.framework/Headers"
[ -d "$headers" ] || { echo "FAIL: no AuthenticationServices headers under $sdk"; exit 1; }
echo "sdk:      $sdk"
echo "headers:  $headers"
echo "library:  $build/libAuthenticationServicesBackports.dylib"

cc -O2 -Wno-unused-parameter -o "$build/hostshape" "$here/hostshape.c" -framework Foundation

# 1. The port's library, from this worktree's sources. Undefined symbols are deferred: this is a shape
#    check, and the classes here call into SafariServices and into the release's own internals, which a
#    shape measurement does not need bound.
build_library() {
    sources=$1
    output=$2
    objects=""
    # Each build compiles into its own directory: a second build reusing the first one's object files is
    # how a mutation ends up measured against the thing it was meant to remove.
    objdir=$(dirname "$output")/objects
    mkdir -p "$objdir"
    rm -f "$objdir"/*.o
    for source in $sources; do
        name=$(basename "$source" .m)
        "$AS_CLANG" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -fobjc-arc -Os -g0 -fPIC \
            -I"$package" -I"$charon/packages/a/apple-backports/HomeKit" -I"$monocypher" \
            -c "$source" -o "$objdir/$name.o" 2>"$build/$name.log" || {
                echo "FAIL: $source did not compile"; head -5 "$build/$name.log"; return 1; }
        objects="$objects $objdir/$name.o"
    done
    "$AS_CLANG" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -dynamiclib \
        -Wl,-undefined,dynamic_lookup -install_name /usr/lib/libAuthenticationServicesBackports.dylib \
        -o "$output" $objects 2>"$build/link.log" || { echo "FAIL: the library did not link"; return 1; }
}
export AS_CLANG=${AS_CLANG:-$HOME/.xmake/packages/l/llvm/23.1.1/6a8c97aaa69241df9ed69ac86f13a045/bin/clang}
monocypher=$(ls -d "$HOME"/.xmake/packages/m/monocypher/*/*/include 2>/dev/null | head -1)
[ -x "$AS_CLANG" ] || { echo "FAIL: no compiler at $AS_CLANG; set AS_CLANG to the llvm package's clang"; exit 1; }

# The sources: every .m in the framework's own directory, and HomeKit's CharonHomeKitModel.m, which
# the construction header reaches. A class whose source is not here is a class the check cannot see, so
# the list is what is on disk rather than a list kept here.
sources=$(ls "$package"/*.m)
shared=$(ls "$charon/packages/a/apple-backports/HomeKit"/Charon*.m 2>/dev/null || true)
build_library "$sources $shared" "$build/libAuthenticationServicesBackports.dylib"
echo "built:    $(ls "$package"/*.m | wc -l | tr -d ' ') AuthenticationServices sources, $(echo $shared | wc -w | tr -d ' ') shared"

# 2. The cases: every class the registry carries, with the public members clang reads out of its header.
PORT_HEADERS="$package" AUTHORSERVICES_SOURCES="$package" python3 - "$registry" "$build/classes.txt" "$here/members.py" "$headers" "$sdk" <<'PYTHON'
import json, os, re, subprocess, sys
registry, out, members_py, headers, sdk = sys.argv[1:6]
rows = []
for name in sorted(os.listdir(registry)):
    if not name.endswith(".json"):
        continue
    with open(os.path.join(registry, name)) as f:
        for entry in json.load(f).get("entries", []):
            if entry.get("kind") == "class" and entry.get("status") in ("implemented", "inert"):
                rows.append(entry["api"])
if not rows:
    sys.stderr.write("no class row in the registry is carried; nothing to measure\n")
    sys.exit(1)
env = dict(os.environ, MEMBERS_CFLAGS="-isysroot " + sdk)
run = subprocess.run([sys.executable, members_py, headers] + sorted(set(rows)),
                     capture_output=True, text=True, env=env)
if run.returncode != 0:
    sys.stderr.write(run.stderr)
    sys.exit(1)
cases = [line for line in run.stdout.split("\n") if line.strip()]
if not cases:
    sys.stderr.write("clang read the headers and found no method in any of them\n")
    sys.exit(1)
# Every class the registry carries must have produced at least one case. A class that produced none is
# a class the check is silently not looking at -- the same silent narrowing the member table used to
# allow, and the reason a class can be registered, reported as implemented, and never measured.
asked = {}
for line in cases:
    name = line.split("\t")[0]
    asked[name] = asked.get(name, 0) + 1
produced = {name: asked.get(name, 0) for name in sorted(set(rows))}
# The other direction: a class this library DEFINES that the registry does not carry as implemented is
# a class that is written, reported as absent, and never measured -- the same false claim the row below
# was, with the sides swapped. Found here that way: the row for ASCredentialServiceIdentifier said
# absent while the class was in the tree, and the run quietly measured six classes instead of seven.
defined = set()
for source in sorted(os.listdir(os.environ["AUTHORSERVICES_SOURCES"])):
    if not source.endswith(".m"):
        continue
    text = open(os.path.join(os.environ["AUTHORSERVICES_SOURCES"], source)).read()
    for found in re.findall(r"@implementation\s+(\w+)", text):
        defined.add(found)
unclaimed = sorted(defined - set(rows))
if unclaimed:
    sys.stderr.write("these classes are DEFINED in the tree and the registry does not carry them as "
                     "implemented, so they are not measured at all: %s\n" % ", ".join(unclaimed))
    sys.exit(1)
print("   per class, members asked of clang and cases built:")
for name in sorted(set(rows)):
    print("     %-44s %d" % (name, produced[name]))
missingClasses = sorted(set(rows) - set(asked))
if missingClasses:
    sys.stderr.write("these classes produced no case and would not be measured at all: %s\n"
                     % ", ".join(missingClasses))
    sys.exit(1)
# Per MEMBER as well as per class: a class that produced a case can still have lost members, and that is
# what happened to ASCredentialServiceIdentifier's three -- the class was counted, the members were not.
raw = run.stdout
perHeader = {}
for name in sorted(set(rows)):
    perHeader[name] = len([line for line in raw.split("\n")
                            if line.startswith(name + "\t")])
short = [name for name in sorted(set(rows)) if perHeader[name] != produced[name]]
if short:
    for name in short:
        sys.stderr.write("FAIL: %s: clang read %d members, %d cases were built\n"
                         % (name, perHeader[name], produced[name]))
    sys.exit(1)
with open(out, "w") as f:
    f.write("\n".join(cases) + "\n")
print("%d class rows, %d members from clang" % (len(set(rows)), len(cases)))
PYTHON

# 3. The comparison. `must-be-unavailable` is a member the header marks NS_UNAVAILABLE: the port must
#    not declare it, and the host answers it because NSObject has it -- which is why it is a state and
#    not a question asked of the port as a member it must have.
# compare() returns a verdict. It does not `set -e`, and it does not `exit`: a function that decides
# whether the run passed has no business deciding whether the run continues, and a red here is the
# mutant run's whole purpose. The caller reads $? and acts on it. This has been got wrong three times
# in this family -- once as an `ok:` printed over a red table, once as a check that invented a
# selector, and once as a script that exited 1 on a successful mutant with its verdict never printed --
# so the rule is written here rather than left to the next reader.
compare() {
    label="$1"
    library="$2"
    "$build/hostshape" "$framework" "$build/classes.txt" > "$build/$label-host.tsv" 2>"$build/$label-host.err"
    python3 "$here/portshape.py" "$library" "$build/classes.txt" > "$build/$label-port.tsv" 2>"$build/$label-port.err"
    portStatus=$?
    cat "$build/$label-host.err" "$build/$label-port.err"
    python3 - "$build/$label-host.tsv" "$build/$label-port.tsv" "$headers" <<'PYTHON'
import os
import sys
headers = sys.argv[3]
host, port = {}, {}
for path, table in ((sys.argv[1], host), (sys.argv[2], port)):
    with open(path) as f:
        next(f, None)
        for line in f:
            if not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            table[(fields[0], fields[1], fields[2])] = (fields[3], fields[4])
print("class\tselector\tkind\tstate\thost\tport\tverdict")
red = 0
for key in sorted(set(host) | set(port)):
    state, hostSays = host.get(key, ("-", "?"))
    _, portSays = port.get(key, ("-", "?"))
    # A must-be-unavailable member is one the port must not declare; the host answering "yes" for it
    # is the inherited +new and is expected, so the two sides are not required to agree there.
    if state == "must-be-unavailable":
        verdict = "ok" if portSays == "no" else "the port declares a member the release marks unavailable"
        if verdict != "ok":
            red += 1
    elif hostSays == "no" and portSays == "yes" and not os.path.isfile(
            os.path.join(headers, key[0] + ".h")):
        # A class the PORT defines has no SDK header, and the host is not supposed to have it, so
        # "the host says no and the port says yes" is the EXPECTED shape for such a row rather than a
        # divergence -- the same reasoning as a must-be-unavailable member, one case further along:
        # there is no release member to agree with. The row says which case it is, so a reader is not
        # left guessing why nine rows that differ are called ok.
        verdict = "ok (the port's own class: the release has no such header, so the host owes nothing)"
    else:
        verdict = "same" if hostSays == portSays else "the two sides differ"
        if verdict != "same":
            red += 1
    print("%s\t%s\t%s\t%s\t%s\t%s\t%s" % (key[0], key[1], key[2], state, hostSays, portSays, verdict))
print("\n%d cases, %d red" % (len(set(host) | set(port)), red))
sys.exit(1 if red else 0)
PYTHON
}

compare tree "$build/libAuthenticationServicesBackports.dylib"
status=$?
echo

if [ "${1:-}" = "--mutate" ]; then
    # One method removed from the port, and exactly that case must go red. The mutation is made on a
    # copy of the source and built the same way, so the tree is not touched and the run after this one
    # measures the real thing again.
    echo "== mutant: ASAuthorizationRequest's -provider removed from a copy of the source"
    mkdir -p "$build/mutant"
    cp "$package"/*.m "$build/mutant/" 2>/dev/null || true
    # The headers travel with the copy: the sources import them by name, and a build whose include path
    # is the mutant's own directory needs them there or it stops at the first import.
    cp "$package"/*.h "$build/mutant/" 2>/dev/null || true
    # Removing the getter's body is not enough, and measuring that is what this says. The SDK's header
    # declares `@property (nonatomic, readonly, strong) id <ASAuthorizationProvider> provider;`, so the
    # class's own @implementation autosynthesises the accessor: take the body away and add nothing and
    # the method is still bound, at the same address, and the check cannot see the removal at all. The
    # first version of this mutation removed the body *and* the @synthesize line, which re-enabled
    # autosynthesis rather than disabling it. `@dynamic` is what turns it off, and it is the same thing
    # the port's own comments say about a bare @property not counting as an implementation.
    python3 - "$build/mutant/ASAuthorizationRequest.m" <<'PYTHON'
import re, sys
path = sys.argv[1]
text = open(path).read()
before = text
text = re.sub(r"- \(id<ASAuthorizationProvider>\)provider\n\{\n    return _provider;\n\}\n", "", text)
if text == before:
    sys.stderr.write("the mutation changed nothing: the member's text is not what the pattern expects\n")
    sys.exit(1)
# `@dynamic` turns autosynthesis off, which stops the accessor being bound -- and it also stops the
# ivar being synthesised, so the mutant declares the ivar itself. What is left is a class that compiles
# and holds the provider, with no -provider method bound at all, which is exactly the state a removal
# would leave.
text = text.replace("@synthesize provider = _provider;\n",
                    "{\n    id<ASAuthorizationProvider> _provider;\n}\n@dynamic provider;\n", 1)
open(path, "w").write(text)
PYTHON
    saved=$package
    package=$build/mutant
    build_library "$(ls "$build/mutant"/*.m) $shared" "$build/mutant/lib.dylib"
    package=$saved
    # A mutant that did not take is not a mutant: the method has to be gone from the binary's own method
    # list before the comparison is run, or the check is being asked to notice something that is still
    # there and its "passes" would mean nothing.
    # The same rule the port side reads by, and not a grep: otool's dump keeps a property's name in
    # baseProperties whether or not an accessor was written, so a grep over `name` lines reads a
    # property as a bound method and refuses a mutation that took. The check is the parse's own.
    if python3 - "$here/portshape.py" "$build/mutant/lib.dylib" ASAuthorizationRequest provider instance <<'PYTHON'
import sys
# The module sits beside this script, and the path has to be its directory rather than the current
# one: the run happens from wherever the caller was, and "no module named portshape" from the
# self-test is a broken witness, not a red one.
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(sys.argv[1])))
from portshape import methods_of
library, className, selector, kind = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
if (selector, kind) in methods_of(library).get(className, set()):
    sys.stderr.write("FAIL: the mutation did not take: %s still binds -%s\n" % (className, selector))
    sys.exit(1)
sys.stderr.write("ok: %s no longer binds -%s in the class's own method list\n" % (className, selector))
PYTHON
    then :; else exit 1; fi
    echo "   the method is gone from the mutant library's method list, so the check below can notice"
    set +e
    compare mutant "$build/mutant/lib.dylib" > "$build/mutant.txt" 2>&1
    mutant=$?
    set -e
    cat "$build/mutant.txt"
    # Two things, not one: the comparison has to have returned non-zero, AND it has to have said why.
    # A run that is red because it crashed, or because it aborted before printing, is not a mutant
    # that worked -- and the third of the three bugs above was exactly that, green in the summary and
    # red in fact, and would have passed a check on the exit code alone.
    if [ "$mutant" -eq 0 ]; then
        echo "FAIL: the check passed with a method the port no longer defines"
        exit 1
    fi
    if ! grep -q "^ASAuthorizationRequest	provider	instance	available	yes	no	the two sides differ$" "$build/mutant.txt"; then
        echo "FAIL: the comparison went red without saying so: the line naming the removed method and the"
        echo "      disagreement is not in its output, so this is a crash or an abort and not a mutant."
        exit 1
    fi
    redLines=$(grep -c "	the two sides differ$" "$build/mutant.txt" || true)
    if [ "$redLines" -ne 1 ]; then
        echo "FAIL: $redLines cases are red, and the mutation removes one method: exactly one must be"
        exit 1
    fi
    echo "ok: the check went red, it said so, and exactly $redLines case is red -- the removed method"
    echo "    and nothing else. The port's own source and its library are untouched by this run."
fi

if [ "$status" -ne 0 ]; then
    echo "FAIL: a class the registry carries is not a shape the host has and the port defines"
    exit 1
fi
echo "ok: every class the registry carries, and every public member its header declares, is a member"
echo "    the host has and the port binds"
