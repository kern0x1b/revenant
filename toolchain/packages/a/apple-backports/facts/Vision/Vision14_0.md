# Vision of iOS 14.0 - the geometry, the stateful request and the video cadence

iOS 14 added the geometry of `VNGeometry.h` (`VNPoint`, `VNVector`, `VNCircle`, `VNContour`), the
smallest-circle helper of `VNGeometryUtils.h`, the base class a request that carries evidence over
time is built on (`VNStatefulRequest`), the cadence values that say how often a video is analysed
and the per-request options that hold one of them. Nine of those twenty-three names are here; the
other fourteen are not, and each of those rows says what is missing.

Everything below is a command a reader can run. The SDK is the one the port compiles against
(`$HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk`),
written below as `$SDK`.

## What the object exports

Compiled to a scratch directory, with the flags `modules/apple/backports.lua` uses
(`-Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -Werror=objc-missing-property-synthesis
-fobjc-arc`, from `compile_arguments` at `modules/apple/backports.lua:474`), for the two band ends
and nothing else - no `xmake` build, nothing written under `~/.xmake`:

    clang -target armv7-apple-ios4.3   -miphoneos-version-min=4.3   ... -c Vision14_0.m   # exit 0, no diagnostics
    clang -target armv7s-apple-ios6.1.3 -miphoneos-version-min=6.1.3 ... -c Vision14_0.m   # exit 0, no diagnostics

(the port's own `-Wno-incompatible-sysroot` suppresses the one notice clang gives about a 16.4
sysroot with a 4.3 or 6.1.3 target, which every link in that file gives.)

`nm -gUm` on the 6.1.3 object, filtered the way `exported_symbols` and `internal_symbol` filter it
(`modules/apple/backports.lua:239` and `:169`), leaves exactly the nine class names - read with the
project's own Mach-O reader rather than with `nm`, so the answer is the one the registry check
reads:

    $ xmake l exports.lua V14-6.1.3.o        # imports backports.lua and calls its symbols_of() with its own predicate
    _OBJC_CLASS_$_VNCircle                                     -> VNCircle
    _OBJC_CLASS_$_VNGeometryUtils                              -> VNGeometryUtils
    _OBJC_CLASS_$_VNPoint                                      -> VNPoint
    _OBJC_CLASS_$_VNStatefulRequest                            -> VNStatefulRequest
    _OBJC_CLASS_$_VNVector                                     -> VNVector
    _OBJC_CLASS_$_VNVideoProcessorCadence                      -> VNVideoProcessorCadence
    _OBJC_CLASS_$_VNVideoProcessorFrameRateCadence             -> VNVideoProcessorFrameRateCadence
    _OBJC_CLASS_$_VNVideoProcessorRequestProcessingOptions     -> VNVideoProcessorRequestProcessingOptions
    _OBJC_CLASS_$_VNVideoProcessorTimeIntervalCadence          -> VNVideoProcessorTimeIntervalCadence
    (and the nine _OBJC_METACLASS_$_ of the same)

The weak private externals an object of this shape always carries - `__OBJC_PROTOCOL_$_NSCopying`,
`__OBJC_LABEL_PROTOCOL_$_NSSecureCoding`, the block descriptor `dispatch_once` needs - are filtered
out by `defined_symbols`, because their n_type carries `N_WEAK_DEF`; the same is true of
`VNObservations.m`, an object already in the tree, whose `nm -gUm` output has the same twelve
entries beyond its classes.

## Every symbol the object needs is on 6.1.3

This is the check the brief names after a real landing: a name the *current* SDK declares and the
release does not carry is an undefined symbol at link time. The C symbols were read with the
project's own index, which needs the leading underscore:

    $ printf '%s\n' _CGAffineTransformIdentity _CGPointZero _CGSizeZero _CGRectZero _CGPathCreateMutable \
        _CGRectGetMinX _CGRectStandardize _CGRectIntersection _CGPathCloseSubpath _CGPathMoveToPoint \
        _CGPathAddLineToPoint _CGContextDrawImage _NSGetSizeAndAlignment _CGPathAddLines _CGPathCreateCopy \
        _CGPathApplyTransform _CGRectContainsPoint _CGRectGetMidY _CGRectGetHeight _CGRectGetWidth \
        _hypot _atan2 _sqrt _fabs _pow _cos _sin _CGPathGetBoundingBox _CGPathContainsPoint \
        | xmake l tools/cache-index/first-rung.lua
    ... every one of them 3.0, except _CGPathApplyTransform which prints NONE

`nm -u` on the object, which is the import list the gate checks against the device's cache, is
exactly the following 35 names: the objc runtime (`_objc_msgSend`, `_objc_msgSendSuper2`,
`_objc_retain`, `_objc_release`, `_objc_storeStrong`, `_objc_autorelease`,
`_objc_autoreleaseReturnValue`, `_objc_retainAutoreleaseReturnValue`,
`_objc_retainAutoreleasedReturnValue`, `__objc_empty_cache`, `_class_copyIvarList`,
`_class_getSuperclass`, `_ivar_getOffset`, `_ivar_getTypeEncoding`, `_object_getIvar`,
`_object_setIvar`), libm (`_hypot`, `_atan2`, `_sqrt`, `_fabs`, `_cos`, `_sin`), libSystem
(`_malloc`, `_free`, `_memcpy`, `_dispatch_once`, `__NSConcreteGlobalBlock`), Foundation
(`_OBJC_CLASS_$_NSDictionary`, `_OBJC_CLASS_$_NSError`, `_OBJC_CLASS_$_NSObject`,
`_OBJC_METACLASS_$_NSObject`, `_NSGetSizeAndAlignment`, `_NSLocalizedDescriptionKey`,
`___CFConstantStringClassReference`) and this library's own (`_VNErrorDomain`,
`_OBJC_CLASS_$_VNImageBasedRequest`, `_OBJC_METACLASS_$_VNImageBasedRequest`).

The selectors were read out of the armv7 cache of 6.1.3 itself, one `grep -cxF` per selector, with
a control in the same run so a zero elsewhere is the release's and not the reader's:

    $ for s in encodeDouble:forKey: decodeDoubleForKey: supportsSecureCoding copyWithZone: \
        encodeWithCoder: initWithCoder: indexAtPosition: objectsAtIndexes: addObject: objectAtIndex: \
        count setObject:atIndexedSubscript:; do printf "%-40s %s\n" "$s" "$(grep -cxF "$s" ~/.charon/dyld/6.1.3/selectors_armv7.txt)"; done
    encodeDouble:forKey:                     1        control: initWithFrameRate:                       0
    decodeDoubleForKey:                      1        control: boundingCircleForPoints:                 0
    supportsSecureCoding                     1        control: polygonApproximationWithEpsilon:error:  0
    copyWithZone:                            1
    encodeWithCoder:                         1
    initWithCoder:                           1
    indexAtPosition:                         1
    objectsAtIndexes:                        1
    addObject:                               1
    objectAtIndex:                           1
    count                                    1
    setObject:atIndexedSubscript:            1

Two things this file deliberately does not use, both because a first reading said the cache does not
carry them and both would have been an undefined symbol:

- `+[NSIndexPath indexPathWithIndexes:length:]` reads 3.0 but `-[NSIndexPath getIndexes:range:]`
  reads **7.0** on this ladder. Neither is used: `VNContour` is not built here (below), so the only
  index path the port touches is none.
- `NSStringFromClass` and `+[NSObject classForName]` read 0 in the 6.1.3 selector list - the first is
  a C function and the second a class name, neither a selector, and the control above shows the list
  answers for selectors only. Neither is used.

`CMTime` is a struct and the port needs no CoreMedia symbol for it: the fields are read and written
in place, and `kCMTimeFlags_Valid` is a member of a `CF_OPTIONS` enumeration
(`$SDK/System/Library/Frameworks/CoreMedia.framework/Headers/CMTime.h:76`), which is an integer and
not an exported symbol. So `VNStatefulRequest` stores the spacing it is given and hands the same
`CMTime` back, and `VisionBackports` keeps not linking CoreMedia.

## The smallest circle is exact, and that was measured

`VNGeometryUtils`'s two point overloads answer the smallest circle that holds the points given. It is
found by the three cases the name implies - one point on its own, two as a diameter, three as the
circle through them - and the points are shuffled first with a constant-seeded generator, so the
same points answer the same circle on every run and on every device.

The C helpers were taken verbatim out of `Vision14_0.m` and driven on this host against a reference
that enumerates every pair and every triple and accepts a candidate only when the candidate's own
circle holds all n points:

    $ clang -O2 -o circle_test circle_test.c -lm && ./circle_test
    control 1 point          -> (0.25, 0.75) r=0   want 0.25, 0.75, 0
    control 0 points         -> count 0   want 0
    control collinear 0..3   -> (1.5, 0) r=1.5   want 1.5, 0, 1.5
    control unit square      -> (0.5, 0.5) r=0.70710678118654757   want 0.5, 0.5, 0.7071067811865476
    5000 random cases: 0 not minimal, 0 not containing, worst relative excess 5.45e-15

and on the three shapes a contour's point buffer has, at n = 4000:

    closed curve -> center (0.5, 0.5) r=0.40000000000000002, 0 outside   (an ellipse of semi-axes 0.4 and 0.3)
    uniform      -> center (0.50972548255231231, 0.50200977339409292) r=0.69558203230076987, 0 outside
    all equal    -> center (0.25, 0.75) r=0, 0 outside

The cost is linear in the number of points, measured by doubling the input: 1024 points 0.0 ms,
4096 0.0 ms, 16384 0.1 ms, 65536 0.4 ms.

The collinear case is in the controls because it is the one the algorithm has no circumcircle for:
three points on a line have no circle through them, so the circle that holds all three is the one
over the two farthest apart.

## The release claim behind every row that stays absent

The project's own census tool, run on this machine over both releases that matter, with its control
in the same run:

    $ CHARON_ROOT=<worktree> xmake l tools/corpus/cache-census.lua VN 6.1.3 12.0
    6.1.3     $HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7
             images 524, of which naming VN 0
             classes 11378, of which VN* 0
             protocols 1171, of which VN* 0
    12.0      $HOME/.charon/dyld/12.0/dyld_shared_cache_arm64
             images 1368, of which naming VN 0
             classes 63192, of which VN* 222 (VNANEProcessingDevice ... <elided>)
             protocols 11426, of which VN* 23 (VNClustererModelBuilding ... <elided>)
    control: 245 name(s) beginning VN found in this run, so a zero on another rung is the release's and not the reader's

iOS 6.1.3 carries **no `VN*` class and no `VN*` protocol at all** - none of 11378 classes and none of
1171 protocols - while the same reader finds 222 classes and 23 protocols on 12.0. That is the
release claim every `absent` row of this file rests on, and the same run is what
`facts/Vision/Absence.md` section 1 records for 4.3 as well.

## What the object does not carry, and why

The fourteen rows that stay `absent` split in two.

**Five requests that run a model.** `VNDetectContoursRequest`, `VNDetectHumanBodyPoseRequest`,
`VNDetectHumanHandPoseRequest`, `VNDetectTrajectoriesRequest` and `VNGenerateOpticalFlowRequest` do
one thing each: run the model that release carries and iOS 6 does not. `coordination/corpus/sources.md`
records that no public source exists for Vision, so there is no description of the network to write
from, and iOS 6 has no second implementation of any of the five to borrow. Their own headers say
what each computes, and those lines are quoted in the rows.

**Eight values only those requests fill.** `VNContour`, `VNContoursObservation`, `VNDetectedPoint`,
`VNRecognizedPoint`, `VNRecognizedPointsObservation`, `VNHumanBodyPoseObservation`,
`VNHumanHandPoseObservation` and `VNTrajectoryObservation` are results, not inputs: each one is
written by a request of the group above. Two of them also say so themselves - the header marks
`+new` and `-init` of `VNContour` unavailable
(`$SDK/.../Vision.framework/Headers/VNGeometry.h:243` and `:244`), and those of `VNDetectedPoint`
(`$SDK/.../Headers/VNDetectedPoint.h:29` to `:32`) - so a caller cannot build one either. An object
with no initializer the header leaves available and no producer would answer zero for the rest of
the process, which is a facade and not an implementation.

`VNVideoProcessor` is the fourteenth and is on its own: it is the controller that pulls frames out
of an `AVAsset` and runs requests over them, so it needs both halves that are missing - the requests
to run, and the frame source, and `VisionBackports` links neither AVFoundation nor CoreMedia.

`VNGeometryUtils` is here with its two point overloads and **not** with `+calculateArea:forContour:orientedArea:error:`
or `+calculatePerimeter:forContour:error:`, because both take a `VNContour` and there is none. They
are not declared, so `respondsToSelector:` answers honestly and an unchecked call raises; the row's
effect says so. Green's theorem and the arc length sum are not the difficulty - a contour to apply
them to is.

## One release, one object

Every name in `Vision14_0.m` is `introduced` 14.0 in the 16.4 SDK headers, so the file carries one
release's API and no other's. It builds against the port's own `VNImageBasedRequest` and
`VNErrorDomain`, which are 11.0 and both carried from 6.0, and the two are in the same band: the
rows of this file are all `minimum` 6.0 and so is the row of that base class
(`registry/Vision/ios11.json`), so no band is left holding one without the other.
