#!/bin/sh
# Negative controls of tests/backports/host/dynamics: each mutant of a copy of UIKit/ must fail its group.
w=$(cd "$(dirname "$0")/../../../.." && pwd)
. "$w/tests/backports/common/runs.sh" "$w"
m=$(runs_folder revenant-dynamics-mutant)
run() {
    name=$1 file=$2 from=$3 to=$4
    rm -rf "$m"; cp -R "$w/packages/frameworks/apple-backports/UIKit" "$m"
    sed -i '' "s/$from/$to/g" "$m/$file"
    if cmp -s "$w/packages/frameworks/apple-backports/UIKit/$file" "$m/$file"; then echo "MUTANT $name changed nothing"; return; fi
    echo "== mutant $name"
    DYNAMICS_SOURCES=$m DYNAMICS_BUILD=$(runs_folder revenant-dynamics-mutant-build) sh "$w/tests/backports/host/dynamics/run.sh" 2>&1 | grep -E 'passed=|^FAIL [^T]' | cut -c1-160
}
run exception-name UIDynamicAnimator.mm 'raise:NSInvalidArgumentException format:@"View item' 'raise:NSInternalInconsistencyException format:@"View item'
run gravity-scale UIDynamicAnimator.mm ' \* 10.0)' ' * 10.5)'
run substep-7.0 UIDynamicAnimator.mm '(double)_speed \* 0.004)' '(double)_speed * 0.005)'
run restart-in-dealloc UIDynamicAnimator.mm ' || _disableDisplayLink || _deallocating)' ' || _disableDisplayLink)'
run circle-edge UIRegion.m 'revenant_region_ellipse(halfWidth, halfHeight, point) <= 1.0f;' 'revenant_region_ellipse(halfWidth, halfHeight, point) < 1.0f;'
run group-transform UIDynamicItemGroup.m 'transform.c \* offset.y' 'transform.b * offset.y'
run vortex-mass UIFieldBehavior.m '(uy \* scale) \/ m, (-ux \* scale) \/ m' '(uy * scale), (-ux * scale)'
run wake-on-move UIDynamicAnimator.mm 'else if (!CGSizeEqualToSize(size, _sizeBefore))' 'else'
run wake-without-prior UIDynamicAnimator.mm 'forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior' 'forKeyPath:@"bounds" options:0'
