#!/bin/sh
# run.sh - the port's LAEnvironment, LAEnvironmentState, its mechanisms and LADomainState (renamed
# RevenantHost*) against the host's own LocalAuthentication. The host has a Touch ID and a passcode set;
# this is what it says, and the port's answers for a device with neither are read against it: the
# shapes must be the same, the strings the port carries must be the host's own, and every place the
# port differs is a difference the test names.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
. "$here/../../common/generated.sh"
ensure_generated "$here" LocalAuthentication
port=${PORT:-$here/../../../../packages/a/apple-backports/LocalAuthentication}
# the generated layer's protocol header (RevenantLocalAuthenticationProtocols.h) is in .gen/LocalAuthentication
port_gen=$here/../../../../packages/a/apple-backports/.gen/LocalAuthentication
harness=${LOCALAUTH18_HARNESS:-$here/../../device}
build=${LOCALAUTH18_BUILD:-$(runs_fresh revenant-localauth18)}
rm -rf "$build"
mkdir -p "$build"
renames=""
for name in LAEnvironment LAEnvironmentState LAEnvironmentMechanism LAEnvironmentMechanismBiometry \
            LAEnvironmentMechanismCompanion LAEnvironmentMechanismUserPassword LADomainState \
            LADomainStateBiometry LADomainStateCompanion LAEnvironmentObserver; do
    renames="$renames -D$name=RevenantHost$name"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -I"$port_gen" -c "$port/LAEnvironment18.m" -o "$build/environment.o"
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -fvisibility=hidden -w $renames -I"$port_gen" -c "$port/LADomainState18.m" -o "$build/domain.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/environment.o" "$build/domain.o" \
    -framework Foundation -framework LocalAuthentication -o "$build/differential"
"$build/differential"
