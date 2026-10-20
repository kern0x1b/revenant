#import <Foundation/Foundation.h>
#import <CarPlay/CarPlay.h>

@interface CPTrip (RevenantTrip174Storage)
- (NSArray<NSString *> *)revenant_destinationNameVariants;
- (void)revenant_setDestinationNameVariants:(NSArray<NSString *> *)variants;
@end

@implementation CPTrip (RevenantTrip174)

- (NSArray<NSString *> *)destinationNameVariants
{
    return [self revenant_destinationNameVariants];
}

- (void)setDestinationNameVariants:(NSArray<NSString *> *)destinationNameVariants
{
    [self revenant_setDestinationNameVariants:destinationNameVariants];
}

@end
