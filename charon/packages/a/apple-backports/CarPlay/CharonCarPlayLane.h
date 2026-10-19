// The port's own Charon seam on CPLane, shared by the two objects that hold the class's two releases.
//
// CPLane.h is two releases in one header -- 17.4 at :22-48 and 18.0 at :26-27, :43 and :53 -- and an
// object may hold API of exactly one release (modules/apple/backports.lua's releases_in, read by
// `tools/release-split.lua`). So the 17.4 half is CarPlayLane174.m and the 18.0 half is CarPlayLane18.m,
// and a category cannot add an ivar: the 18.0 object's storage therefore sits with the class's own 17.4
// ivars, and these accessors are how it reaches them.
//
// They live in a header rather than being declared twice because a category that declares a method it
// does not implement warns, and the tree's own convention for exactly this is a Charon<Framework>.h per
// package (CharonHomeKitModel.h, CharonVImageFixed.h and the rest). Every name is Charon-prefixed, so
// none of this is API and none of it appears in the library's exports.
#ifndef CHARON_CARPLAY_LANE_H
#define CHARON_CARPLAY_LANE_H

#import <Foundation/Foundation.h>
#import "CharonCarPlay174.h"

@interface CPLane (CharonLaneAngles)

// The 18.0 storage, reached from CarPlayLane18.m.
- (NSMeasurement<NSUnitAngle *> *)charon_highlightedAngle;
- (void)charon_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle;
- (NSArray<NSMeasurement<NSUnitAngle *> *> *)charon_angles;
- (void)charon_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles;

// Both 18.0 initialisers' shared body (CPLane.h:26-27), reached from CarPlayLane18.m. The selector
// starts with `init` because C does not allow a method outside the initialiser family to assign to
// `self`; a `charon_init...` spelling failed with "cannot assign to 'self' outside of a method in the
// init family", measured 2026-10-01 compiling against the 26.2 SDK.
- (instancetype)initCharonWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred;

@end

#endif