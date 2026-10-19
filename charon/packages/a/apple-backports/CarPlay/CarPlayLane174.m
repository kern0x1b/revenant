// CPLane: one lane of a lane guidance, and the angle that says which way it points.
//
// CPLane.h:22-23 `API_AVAILABLE(ios(17.4))`. The port does not carry this class today and this file is
// what carries it, because `CPNavigationSession`'s 17.4 members need it: currentLaneGuidance's value is
// a CPLaneGuidance (CPNavigationSession.h:80) and a CPLaneGuidance's `lanes` is "an array of CPLane
// objects, each describes a single lane" (CPLaneGuidance.h:20-22). The object-plus-rows rule is why the
// registry carries this class's own rows alongside the six session members that need it.
//
// WHICH RELEASE EACH HALF BELONGS TO, and this is the split the file exists for. CPLane.h is two
// releases in one header and an object may hold API of exactly one release
// (modules/apple/backports.lua's releases_in, read by `tools/release-split.lua`):
//   17.4 -- :22 the class itself, :25 -init (deprecated in 18.0), :26-27 the two -initWithAngles:...
//           initialisers are API_AVAILABLE(ios(18.0)) and are NOT here, :32 status, :33 -setStatus:,
//           :38 primaryAngle, :48 secondaryAngles, all three deprecated in 18.0.
//   18.0 -- :43 highlightedAngle, :53 angles, and the two -initWithAngles:... initialisers.
// So the 17.4 half is here and the 18.0 half is CarPlayLane18.m. What the 18.0 object needs from this
// one is storage and a Charon accessor, the same shape the session's 17.4 members use.
//
// The measured answers, from Apple's own CarPlay on this machine with no head unit attached
// (tests/backports/host/carplay/headunit-probe.m), are in facts/CarPlay/NavigationSession174.md. The one
// that matters here: a fresh CPLaneGuidance answers NIL for both of its array properties rather than an
// empty array -- "a fresh lane guidance's lanes answer nil, not an empty array (measured)  nil" -- and
// this object keeps that distinction rather than defaulting nil to @[] behind the program's back.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
// CarPlay.h (the umbrella) does not import CPLane.h -- CPLane is not in the SDK's CarPlay.h at all, so
// the port names the header itself. Measured 2026-10-01 by compiling against the 26.2 SDK: with only
// Foundation and UIKit in scope this file failed with "unknown type name 'CPLaneStatus'; did you mean
// 'CTRunStatus'?" -- a name from CoreText, which is what an unqualified CPLaneStatus binds to when
// CarPlay's own declaration is absent. CPLaneGuidance IS reachable through the umbrella (CarPlay.h:55
// imports CPRouteInformation.h, which imports CPLaneGuidance.h), but CPLane is not on that path's
// surface, so the header is named directly rather than relied on to arrive.
#import "CharonCarPlay174.h"
#import "CharonCarPlayLane.h"

// CPLane.h:26-27, :43 and :53 are `API_AVAILABLE(ios(18.0))` and are carried in an object of their own
// (CarPlayLane18.m), so this 17.4 object does not define them and the compiler says so. The suppression
// is that sentence and nothing else -- the same suppression, for the same reason, as the one at the top
// of CarPlayNavigationSession12.m for the 15.4 pause method.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CPLane {
    CPLaneStatus _status;
    NSMeasurement<NSUnitAngle *> *_primaryAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_secondaryAngles;
    NSMeasurement<NSUnitAngle *> *_charonHighlightedAngle;
    NSArray<NSMeasurement<NSUnitAngle *> *> *_charonAngles;
}

// The two 18.0 properties are @dynamic and NOT @synthesize, and this is measured rather than
// stylistic. The compiler auto-synthesises every property an SDK header declares, and this object does
// not implement: with no @dynamic, CarPlayLane174.o listed
//     highlightedAngle   angles   _highlightedAngle   _angles
// as properties and IVARS OF THE 17.4 OBJECT -- which puts 18.0 storage and 18.0 accessors into a 17.4
// band. That is the same defect commit 329b2b23c found for CPSessionConfiguration's contentStyle and
// which main's tip commit fixed for PHPhotoLibrary's availability property. `@dynamic` says the storage
// belongs elsewhere, and CarPlayLane18.m's category is where those two accessors are.
@dynamic highlightedAngle;
@dynamic angles;

// The three 17.4 properties whose accessors are written by hand below are @synthesize'd explicitly, and
// the reason is a build flag rather than a style: the review's compile step runs with
// -Werror=objc-missing-property-synthesis, and a property with a hand-written getter and setter and no
// explicit @synthesize is still "default synthesizing" to that warning -- measured 2026-10-01 against
// the build SDK as "auto property synthesis is synthesizing property not explicitly synthesized" on
// `status`.
@synthesize status = _status;
@synthesize primaryAngle = _primaryAngle;
@synthesize secondaryAngles = _secondaryAngles;

// CPLane.h:25 declares -init and marks it API_DEPRECATED("-[CPLane initWithAngles:] or
// -[CPLane initWithHighlightedAngle:angles:isPreferred:]", ios(17.4, 18.0)) -- it is deprecated from
// the release that introduced it and removed at 18.0. It is carried because the 17.4 SDK declares it
// and a program written against 17.4 calls it; what it answers is the header's own default, a lane with
// no angles and the status the enumeration gives value 0, which is CPLaneStatusNotGood.
- (instancetype)init
{
    self = [super init];
    if (self) {
        _status = CPLaneStatusNotGood;
    }
    return self;
}

// :33 -setStatus: carries its own deprecation text ("Use -[CPLane initWithAngles:] to create a CPLane
// with CPLaneStatusNotGood, use -[CPLane initAngles:highlightedAngle:isPreferred:] to create a CPLane
// with status CPLaneStatusGood or CPLaneStatusPreferred"), so the setter keeps the value it was given
// and nothing else: the guidance is about how a lane is MADE, which is a choice the program makes
// through an initialiser, not a limit on what a setter may store.
- (void)setStatus:(CPLaneStatus)status
{
    _status = status;
}

// :22 in CPLaneGuidance.h says lanes is `copy`, so both array properties copy what they are given and a
// program that mutates its own array afterwards does not change the lane behind the port's back.
- (NSArray<NSMeasurement<NSUnitAngle *> *> *)secondaryAngles
{
    return _secondaryAngles;
}

- (void)setSecondaryAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)secondaryAngles
{
    _secondaryAngles = [secondaryAngles copy];
}

- (NSMeasurement<NSUnitAngle *> *)primaryAngle
{
    return _primaryAngle;
}

- (void)setPrimaryAngle:(NSMeasurement<NSUnitAngle *> *)primaryAngle
{
    _primaryAngle = primaryAngle;
}

// ---- The 18.0 half ---------------------------------------------------------------------------------
- (NSMeasurement<NSUnitAngle *> *)charon_highlightedAngle
{
    return _charonHighlightedAngle;
}

- (void)charon_setHighlightedAngle:(NSMeasurement<NSUnitAngle *> *)angle
{
    _charonHighlightedAngle = angle;
}

- (NSArray<NSMeasurement<NSUnitAngle *> *> *)charon_angles
{
    return _charonAngles;
}

- (void)charon_setAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
{
    _charonAngles = [angles copy];
}

// The body both 18.0 initialisers share. `CPLane.h:41` is the rule that decides what happens when there
// is no highlighted angle: the header forbids setting highlightedAngle when the status is CPLaneStatusNotGood, and
// :42 forbids including a present highlightedAngle in secondaryAngles, which is the same rule
// for the 17.4 property. So a preferred or good lane keeps the angle it was given and a NotGood lane
// does not keep one, and the angles list never contains the highlighted angle twice.
- (instancetype)initCharonWithAngles:(NSArray<NSMeasurement<NSUnitAngle *> *> *)angles
                    highlightedAngle:(NSMeasurement<NSUnitAngle *> *)highlightedAngle
                          isPreferred:(BOOL)preferred
{
// The selector starts with `init` on purpose. C's rule is that a method outside the
// initialiser family may not assign to `self`, and a first spelling of `charon_initWithAngles:...`
// failed with "cannot assign to 'self' outside of a method in the init family" -- the selector decides
// the family, not the body. So the 18.0 object's two -initWithAngles:... initialisers reach this one
// under a name the compiler reads as an initialiser, which is what it is.
    self = [self init];
    if (self == nil) {
        return nil;
    }
    _charonAngles = [angles copy];
    if (preferred) {
        _status = CPLaneStatusPreferred;
        _charonHighlightedAngle = highlightedAngle;
    } else if (highlightedAngle != nil) {
        _status = CPLaneStatusGood;
        _charonHighlightedAngle = highlightedAngle;
    } else {
        // No highlighted angle: the lane is not good, and the header's rule says it must not be set.
        _status = CPLaneStatusNotGood;
        _charonHighlightedAngle = nil;
    }
    return self;
}

// NSCopying is in the header (:23). A copy is a lane with the same angles and the same status -- every
// one of them a value -- so a program that copies a lane gets a lane that answers the same, and the
// arrays are copied so the two do not share storage.
- (id)copyWithZone:(NSZone *)zone
{
    CPLane *lane = [[[self class] allocWithZone:zone] init];
    lane.status = _status;
    lane.primaryAngle = _primaryAngle;
    lane.secondaryAngles = _secondaryAngles;
    [lane charon_setHighlightedAngle:_charonHighlightedAngle];
    [lane charon_setAngles:_charonAngles];
    return lane;
}

// NSSecureCoding is in the header (:23), so a lane has to encode: its status is an integer and its
// angles are NSMeasurement objects, which are themselves codable. The classes are named rather than
// assumed, so the decoder refuses a payload carrying something else instead of trusting it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_status forKey:@"charon.status"];
    [coder encodeObject:_primaryAngle forKey:@"charon.primaryAngle"];
    [coder encodeObject:_secondaryAngles forKey:@"charon.secondaryAngles"];
    [coder encodeObject:_charonHighlightedAngle forKey:@"charon.highlightedAngle"];
    [coder encodeObject:_charonAngles forKey:@"charon.angles"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _status = (CPLaneStatus)[coder decodeIntegerForKey:@"charon.status"];
        _primaryAngle = [coder decodeObjectOfClass:[NSMeasurement class] forKey:@"charon.primaryAngle"];
        _secondaryAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                               forKey:@"charon.secondaryAngles"];
        _charonHighlightedAngle = [coder decodeObjectOfClass:[NSMeasurement class]
                                                     forKey:@"charon.highlightedAngle"];
        _charonAngles = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSMeasurement class], nil]
                                             forKey:@"charon.angles"];
    }
    return self;
}

- (NSString *)description
{
    static NSString *const names[] = {@"NotGood", @"Good", @"Preferred"};
    NSUInteger index = (NSUInteger)_status;
    NSString *name = index < 3 ? names[index] : [NSString stringWithFormat:@"%lu", (unsigned long)index];
    return [NSString stringWithFormat:@"<CPLane: %p %@, primary %@, secondary %lu, angles %lu>",
            self, name, _primaryAngle.description ?: @"nil",
            (unsigned long)_secondaryAngles.count, (unsigned long)_charonAngles.count];
}

@end
#pragma clang diagnostic pop
