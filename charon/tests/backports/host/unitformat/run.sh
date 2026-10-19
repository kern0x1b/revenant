#!/bin/sh
# The three measurement formatters of packages/a/apple-backports/Foundation - NSLengthFormatter,
# NSMassFormatter and NSEnergyFormatter, whole from the 26.2 header - against the host's own three.
# The port's classes are renamed, both are in one process, and every check compares two answers for
# one input: which unit a value is written in, the number, the name, the plural, the space between
# them, the flag, the number formatter the caller set, every threshold to the last bit, and the
# parse the header documents never to answer anything.
#
# The formatters read the current locale, so the process is started once per locale with
# -AppleLocale; that is the only way to put the port and the system in front of the same one, and
# it is why the locales below are the measurement systems of interest: "U.S.", "U.K." and "Metric".
# The port carries the system's English unit names and nothing else - the CLDR table they come from
# arrived in the ICU of iOS 8.0 and no release the port carries has it, measured over the whole cache
# ladder in facts/Foundation/NSUnitFormat.md - so the two are compared two ways and the differential
# says which is which in its header. In a locale that writes its names in English everything is
# compared with the name left out: the unit chosen, the number, the plural, the space, the two
# composite forms, all seven unit styles, every threshold to the last bit, the seven number styles
# and the three forXxxUse flags. In one that does not, the unit chosen, the digits of the number, the
# plural shape and the two-unit structure are, and the text of the name is not.
# An NSxxxFormatterUnit value outside the enumeration is not a unit: the system answers its own
# internal lookup key for it - "(null)_WIDE_OTHER_UNKNOWN" and its two siblings - and a written form
# built from a pattern it could not resolve. The port answers nil there, and in an English locale both
# answers are held, so the difference is stated rather than passed over.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/a/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh charon-unitformat)}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers -Wno-format-security"
rm -rf "$BUILD/port"
mkdir -p "$BUILD/port"
for pair in "NSLengthFormatter:CharonHostLengthFormatter" "NSMassFormatter:CharonHostMassFormatter" "NSEnergyFormatter:CharonHostEnergyFormatter"; do
    ours=${pair%%:*}
    theirs=${pair##*:}
    xcrun clang -fobjc-arc $quiet -D${ours}=${theirs} -I "$FOUNDATION" -c "$FOUNDATION/$ours.m" -o "$BUILD/port/$ours.o"
done
xcrun clang -fobjc-arc $quiet -I "$FOUNDATION" -c "$FOUNDATION/CharonUnitFormat.m" -o "$BUILD/port/CharonUnitFormat.o"
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD/port"/*.o -framework Foundation -o "$BUILD/differential"

status=0
for locale in en_US en_GB en_AU en_CA de_DE fr_FR ja_JP ru_RU ar_EG es_MX en_IN en_001; do
    printf '%-8s ' "$locale"
    "$BUILD/differential" -AppleLocale "$locale" || status=1
done
exit $status
