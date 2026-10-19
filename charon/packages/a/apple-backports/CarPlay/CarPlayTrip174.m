// CarPlayTrip174.m - the 17.4 member of CPTrip, in a 17.4 object of its own.
//
// CPTrip.h:158 declares
//     @property (nonatomic, copy, nullable) NSArray<NSString *> *destinationNameVariants
//         API_DEPRECATED_WITH_REPLACEMENT("destinationWaypoint.nameVariants", ios(17.4, 27.0))
// and it is the whole of the 17.4 API of the class. The class itself is 12.0 and its @implementation is
// CarPlayTemplatesMore12.m, so this is the same split CarPlayLane174.m and CarPlayLane18.m make for
// CPLane: an object holds API of exactly one release (modules/apple/backports.lua's releases_in, read by
// tools/release-split.lua).
//
// It is deprecated in 27.0 in favour of CPNavigationWaypoint's nameVariants, and the replacement is not
// carried by the port - it is 26.4 and this is a 17.4 object - so this property is still the spelling an
// application compiled against 17.4 through 26.x writes, and it is the one that is answered here.
//
// What the variants are is the header's own shape: the names the destination may be written under, most
// preferred first, the same array-of-variants idea the maneuver's instructionVariants already uses in
// CarPlayTemplates12.m. They are copied on the way in and a nil in is a nil out, which is what `copy,
// nullable` promises.

#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

@interface CPTrip (CharonTrip174Storage)
- (NSArray<NSString *> *)charon_destinationNameVariants;
- (void)charon_setDestinationNameVariants:(NSArray<NSString *> *)variants;
@end

@implementation CPTrip (CharonTrip174)

- (NSArray<NSString *> *)destinationNameVariants
{
    return [self charon_destinationNameVariants];
}

- (void)setDestinationNameVariants:(NSArray<NSString *> *)destinationNameVariants
{
    [self charon_setDestinationNameVariants:destinationNameVariants];
}

@end
