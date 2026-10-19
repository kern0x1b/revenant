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
