#import "CharonMetricValue.h"
#import "CharonMetricKit.h"

// MXMetric is the root every metric of this framework inherits, and the two things the whole framework
// promises on a value are implemented once, for it, in the category CharonMetricValue.m holds: the
// dictionary a metric is written as, and the JSON that dictionary serialises to. The three methods the
// header declares here are that dictionary twice under the two spellings Apple has given them - the
// current -dictionaryRepresentation and the deprecated NS_REFINED_FOR_SWIFT -DictionaryRepresentation -
// and the JSON.
//
// There is nothing to add to the class itself. It has no properties of its own (a metric's values are
// its subclass's), and the port does not fabricate a measurement: an MXMetric is a value the system
// fills in, and on this release nothing fills one, so every metric the application can hold is one it
// decoded from a payload or one the port measured itself. That is why a property reads nil rather than a
// zero: a metric that was never measured says so, and a zero would say it was measured and was nothing.

// The concrete initialiser the port's own store and manager use, and the one an application can use to
// build a value in a test fixture. Apple's headers have no initialiser at all - the system constructs
// these - so this is a Charon-prefixed name on the port's own class, which is what the registry's Charon
// rule keeps out of the API it has to describe.
@interface MXMetric (CharonConstruction)
+ (instancetype)charon_metric;
@end

@implementation MXMetric (CharonConstruction)

+ (instancetype)charon_metric
{
    return [[self alloc] init];
}

@end
// The class itself is in MXValues130.m, with the iOS 13.0 classes it is the root of: an object carries
// API that arrived in one release, and MXMetric arrived in 13.0. What is here is the one constructor
// Apple's headers have no name for, which the port's own measurements and an application's fixtures use.
