// The 18.0 half of CPLane: the angle that is highlighted, the list of angles, and the two initialisers
// that build a lane from them.
//
// CPLane.h:26-27 declares -initWithAngles: and -initWithAngles:highlightedAngle:isPreferred:
// `API_AVAILABLE(ios(18.0))`, :43 declares `highlightedAngle` `API_AVAILABLE(ios(18.0))` and :53
// declares `angles` `API_AVAILABLE(ios(18.0))`. Those four are the whole of the 18.0 API of the class,
// and they are an object of their own because an object may hold API of exactly one release
// (modules/apple/backports.lua's releases_in, read by `tools/release-split.lua`) while the class's
// other half is 17.4 and lives in CarPlayLane174.m.
//
// The deprecation text is what these four are FOR, and it is the header's own account of them:
// CPLane.h:33 says "Use -[CPLane initWithAngles:] to create a CPLane with CPLaneStatusNotGood, use
// -[CPLane initAngles:highlightedAngle:isPreferred:] to create a CPLane with status CPLaneStatusGood
// or CPLaneStatusPreferred"; :38 says "Use highlightedAngle to get value, use
// -[CPLane initAngles:highlightedAngle:isPreferred:] to create a CPLane with angles set"; :48 says "Use
// angles to get value, Use -[CPLane initWithAngles:] to create a CPLane with angles". So the 18.0 API
// REPLACES the 17.4 way of building a lane -- an initialiser instead of a setter, and a read-only
// highlightedAngle/angles pair instead of the readwrite primaryAngle/secondaryAngles pair -- and this
// object is that replacement.
//
// The storage is not here: a category cannot add an ivar, so `angles`, `highlightedAngle` and the
// shared initialiser body live with the class's own 17.4 ivars in CarPlayLane174.m, reached through
// the Charon accessors declared there. Every one of those names is Charon-prefixed and carries no API.
//
// The rule that decides what a lane keeps, from the header's own sentences: :41-42 says
// highlightedAngle must not be set when the status is CPLaneStatusNotGood, a present highlightedAngle is not to be included in
// secondaryAngles, and :42 says the same for angles, so the highlighted angle is never both the highlighted one and one of
// the remaining ones.
#import <Foundation/Foundation.h>
#import "CharonCarPlay174.h"
#import "CharonCarPlayLane.h"

@implementation CPLane (CharonLaneAngles18)

// :26 "- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles" -- the
// initialiser the deprecation text at :33 and :38 names as the way to make a CPLane with
// CPLaneStatusNotGood, which is the status a lane with no highlighted angle has. So it is the same
// shared body with no highlighted angle and not preferred.
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self initCharonWithAngles:angles highlightedAngle:nil isPreferred:NO];
}

// :27 "- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
// highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle isPreferred:(BOOL)preferred" --
// the initialiser the deprecation text names as the way to make a lane that is Good or Preferred. The
// three arguments map onto the three states the header's own deprecation sentence lists: no highlighted
// angle and not preferred is NotGood, a highlighted angle and not preferred is Good, and preferred is
// Preferred whichever angle is highlighted.
- (instancetype)initWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
             highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                   isPreferred:(BOOL)preferred
{
    return [self initCharonWithAngles:angles highlightedAngle:highlightedAngle isPreferred:preferred];
}

// :43 highlightedAngle is the angle that should be highlighted, and it is never set for a NotGood status:
// it is `readonly`, so this answers the stored angle and answers
// nil for a NotGood lane rather than a zero-degree measurement that the program never gave.
- (NSMeasurement<NSUnitAngle *> *)highlightedAngle
{
    return [self charon_highlightedAngle];
}

// :53 lists the angles still left on this lane guidance, leaving out the highlighted one whenever one is set,
// and the property is `readonly, copy`.
- (NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    return [self charon_angles];
}

@end