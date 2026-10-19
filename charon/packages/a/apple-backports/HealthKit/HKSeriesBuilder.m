// HKSeriesBuilder and HKSeriesSample: the two abstract superclasses the release's own series classes
// inherit from, the SDK's headers declare them and the corpus carries no row for either, and the armv7
// shared cache of 10.0.1 carries both, so this is a file of 10.0 and the 11.0 route classes inherit
// from it as the release's do.
//
// Neither carries a member here. HKSeriesSample's count and HKSeriesBuilder's discard are both of 12.0,
// and the 12.0 group answers them on the subclass that holds the data; until then a member this library
// does not answer is @dynamic, so the selector is not in the library at all.

#import <HealthKit/HealthKit.h>

@implementation HKSeriesBuilder
@end

@implementation HKSeriesSample
@dynamic count;
@end
