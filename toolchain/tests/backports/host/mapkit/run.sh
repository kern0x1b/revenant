#!/bin/sh
# The behaviour the MapKit backports' arithmetic is measured against: the host's own MapKit answers
# for all of it, and this compares the port's answers with the host's, name for name.
#
#   the projection        MKMapPointForCoordinate / MKCoordinateForMapPoint, the port through
#                         RevenantMapKit and the release's own C functions
#   the distance format   MKDistanceFormatter, over both measures and both styles
#   the camera            +cameraLookingAtCenterCoordinate:fromEyeCoordinate:eyeAltitude: and
#                         -centerCoordinate / -heading / -centerCoordinateDistance
#   the tile URL          MKTileOverlay -URLForTilePath: and the header's own {x}{y}{z}{scale}
#   the geodesic         MKGeodesicPolyline's point count and its end points against the great circle
#
# The port's objects are compiled with their own names renamed to revenantHost_*, so the two live in
# one process: the host's own MapKit answers for the unrenamed name beside it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/MapKit}
build=${MAPKIT_BUILD:-$(runs_folder revenant-mapkit-host)}
rm -rf "$build"
mkdir -p "$build"
renames=""
while read -r name; do
    [ -n "$name" ] || continue
    renames="$renames -D$name=revenantHost_$name"
done <<'NAMES'
RevenantMapKit
MKDistanceFormatter
MKMapCamera
NAMES
objects=""
for source in RevenantMapKit MKDistanceFormatter MKMapCamera; do
    # REVENANT_HOST_PROBE: the host's own MapKit declares the classes the port declares under Apple's
    # own names, so on this host those are the host's declarations and this port's object is not
    # compiled for it.
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w -DREVENANT_HOST_PROBE=1 $renames -I"$port" -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -framework Foundation -framework MapKit -framework CoreLocation \
    -I"$port" "$here/differential.m" $objects -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
