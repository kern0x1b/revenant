// CPLaneGuidance: guidance on which lane or lanes the user should be given as preferred.
//
// CPLaneGuidance.h:16-17 `API_AVAILABLE(ios(17.4))`, `NSObject <NSCopying, NSSecureCoding>`. The port
// carries it because `CPNavigationSession`'s 17.4 members need it: currentLaneGuidance's value is one
// (CPNavigationSession.h:80) and -addLaneGuidances: takes an array of them (:93).
//
// The measured answer that decides what this object does with a nil, on Apple's own CarPlay on this
// machine with no head unit attached (tests/backports/host/carplay/headunit-probe.m, section 8):
//
//   ok  a fresh lane guidance's lanes answer nil, not an empty array (measured)      nil
//   ok  a fresh lane guidance's instructionVariants answer nil, not an empty array   nil
//   ok  +supportsSecureCoding is YES (NSSecureCoding is in the header)                YES
//
// So nil in, nil out, and an empty array in, an empty array out -- two different answers, kept apart.
// This is the same honest line as the dismissal rule elsewhere in this family: a first reading of the
// header says "an array of NSString", and Apple's own object says nil, and the port follows the object.
// A defaulted @[] here would be an invented value that reads as "a guidance with no instruction", which
// is not the same thing as no guidance at all.
#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>
#import "CharonCarPlay174.h"

@implementation CPLaneGuidance {
    NSArray<CPLane *> *_lanes;
    NSArray<NSString *> *_instructionVariants;
}

// -init is NOT declared in the header and NOT marked unavailable, so this is the release's NSObject
// initialiser and it is called; what it answers afterwards is the measurement above.
- (instancetype)init
{
    self = [super init];
    if (self) {
        // Nothing is defaulted here, on purpose: the measurement says a fresh one answers nil for both
        // properties, and assigning @[] in an initialiser is exactly the defaulted empty array the
        // measurement rules out.
    }
    return self;
}

// :22 `lanes` is `copy` and is "an array of CPLane objects, each describes a single lane", so the array
// is copied and nil stays nil.
- (NSArray<CPLane *> *)lanes
{
    return _lanes;
}

- (void)setLanes:(NSArray<CPLane *> *)lanes
{
    _lanes = [lanes copy];
}

// :28 `instructionVariants` is `copy` and is an array of NSString values giving the wording for this
// lane guidance, ordered from the most preferred to the least, with at least one variant required. The
// order is the program's and is kept as given, since the ordering says which one a driver should read first.
// The header requires one variant at least, and that is the
// program's obligation to the guidance it builds: this object does not invent a variant for an empty
// one, and it does not reject an empty one either -- a caller that sets none has said what it said.
- (NSArray<NSString *> *)instructionVariants
{
    return _instructionVariants;
}

- (void)setInstructionVariants:(NSArray<NSString *> *)instructionVariants
{
    _instructionVariants = [instructionVariants copy];
}

// NSCopying is in the header (:17): a copy is a guidance with the same lanes and the same variants, both
// copied so the two objects share no storage.
- (id)copyWithZone:(NSZone *)zone
{
    CPLaneGuidance *guidance = [[[self class] allocWithZone:zone] init];
    guidance.lanes = _lanes;
    guidance.instructionVariants = _instructionVariants;
    return guidance;
}

// NSSecureCoding is in the header (:17) and the probe measured +supportsSecureCoding answering YES on
// Apple's own class, so the port's answers it for the same class.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_lanes forKey:@"charon.lanes"];
    [coder encodeObject:_instructionVariants forKey:@"charon.instructionVariants"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _lanes = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [CPLane class], nil] forKey:@"charon.lanes"];
        _instructionVariants = [coder decodeObjectOfClasses:
            [NSSet setWithObjects:[NSArray class], [NSString class], nil]
                                                    forKey:@"charon.instructionVariants"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CPLaneGuidance: %p, %lu lanes, %lu variants>", self,
            (unsigned long)_lanes.count, (unsigned long)_instructionVariants.count];
}

@end