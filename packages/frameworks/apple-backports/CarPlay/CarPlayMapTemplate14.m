#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlayTemplate.h"

@implementation CPMapTemplate (RevenantMapTemplate14)

- (void)showTripPreviews:(NSArray<CPTrip *> *)trips
             selectedTrip:(CPTrip *)selectedTrip
        textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trips == nil) {
        return;
    }
    NSUInteger kept = MIN(trips.count, (NSUInteger)12);
    NSArray<CPTrip *> *shown = [trips subarrayWithRange:NSMakeRange(0, kept)];
    CPTrip *selected = [shown containsObject:selectedTrip] ? selectedTrip : nil;
    [self revenant_setTripPreviews:shown selectedTrip:selected];
    [self revenant_drawTripPreviews];
}

@end
