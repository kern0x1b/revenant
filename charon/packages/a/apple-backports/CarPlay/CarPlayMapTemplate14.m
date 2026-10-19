// The one 14.0 member of CPMapTemplate, in an object of its own release.
//
// CPMapTemplate.h:117 declares -showTripPreviews:selectedTrip:textConfiguration: as
// API_AVAILABLE(ios(14.0)), so it is not in CarPlayMapTemplate12.m: one object per release, and this is
// the object named for that one. It is the 12.0 member plus the trip to select, and the 12.0 object's
// own limit and drawing are reached rather than written twice:
//
//   -showTripPreviews:textConfiguration:               12.0, CarPlayMapTemplate12.m
//   -showTripPreviews:selectedTrip:textConfiguration:  14.0, this object
//
// A category cannot write an ivar, so the storage - the previews and the selected trip - is declared
// with the class's own ivars in CarPlayTemplatesView12.m and reached through CharonCarPlayTemplate.h.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

@implementation CPMapTemplate (CharonMapTemplate14)

// CPMapTemplate.h:117-121: the header says a preview for a trip gives an overview of the coming trip, or can show several trip
// options, and an optional selectedTrip is highlighted among the previews.
- (void)showTripPreviews:(NSArray<CPTrip *> *)trips
             selectedTrip:(CPTrip *)selectedTrip
        textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trips == nil) {
        return;
    }
    // The header's own limit is twelve here too, and the selected trip is one of the shown ones or
    // none: a caller that selects a trip it did not pass has selected nothing, and highlighting the
    // first shown trip instead would be a highlight the caller did not ask for.
    NSUInteger kept = MIN(trips.count, (NSUInteger)12);
    NSArray<CPTrip *> *shown = [trips subarrayWithRange:NSMakeRange(0, kept)];
    CPTrip *selected = [shown containsObject:selectedTrip] ? selectedTrip : nil;
    [self charon_setTripPreviews:shown selectedTrip:selected];
    [self charon_drawTripPreviews];
}

@end