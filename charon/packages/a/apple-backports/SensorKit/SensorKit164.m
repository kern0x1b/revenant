#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 16.4, the properties that arrived then.
@implementation SRApplicationUsage (CharonSensorKit164)
@dynamic supplementalCategories, relativeStartTime;
CHARON_VALUE_PROPERTY(NSArray *, supplementalCategories)
CHARON_SCALAR_PROPERTY(NSTimeInterval, relativeStartTime)
@end
@implementation SRApplicationUsage (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRMediaEvent
@dynamic mediaIdentifier, eventType;
CHARON_VALUE_PROPERTY(NSString *, mediaIdentifier)
CHARON_SCALAR_PROPERTY(SRMediaEventType, eventType)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying. The archiver walks the same property list the
// representation does, through CharonValueStore's own pair, so a value archived and read back lands in
// the store under the property's own name and nothing has to be written out by hand for it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names. A copy that
    // shared the store would be two names for one value, which is the opposite of what a copy is.
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = CharonValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        CharonValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end
@implementation SRMediaEvent (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
// The two of SRKeyboardMetrics the (CharonSensorKit164) category of CharonSensorKit.h declares and
// nothing implemented: a property a category of ours declares is answered in a category of ours, for
// the reason SensorKit140.m's own comment gives - the name is declared twice on the class otherwise,
// and clang cannot synthesise a member of a category. Both are value properties of the same store as
// the rest of the class, so they read back what was archived under their own names and nil until then.
//
// NOT sessionIdentifiers, the third property of that category: the 16.4 SDK declares it in the class's
// own @interface (SRKeyboardMetrics.h:35), so clang synthesises its accessor into the class, and
// writing one here would be a second definition of a method that exists. touchUpDown is in the SDK's
// own (ProbabilityMetrics) category at :152 and longWordTouchUpDown in a later one at :254, which is
// why neither of the three is answered the same way.
@implementation SRKeyboardMetrics (CharonSensorKit164)
@dynamic longWordTouchUpDown, touchUpDown;
CHARON_VALUE_PROPERTY(NSArray *, longWordTouchUpDown)
CHARON_VALUE_PROPERTY(id, touchUpDown)
@end
// One of the fourteen classes whose own framework refuses -init, with the reason string measured on
// the host (SRDeviceUsageCategories.h:67 and :68 close both), so the copy below takes the class's own
// door rather than -init. The door is declared here because no SDK header declares it and the copy is
// its only caller - the shape registry/MPS graph.json uses for the thirteen charon_ names its own
// files share.
@interface SRSupplementalCategory ()
- (instancetype)initWithCharonValues:(NSDictionary *)values;
@end

@implementation SRSupplementalCategory
@dynamic identifier;
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
CHARON_VALUE_COPY_INITIALISER
CHARON_VALUE_PROPERTY(NSString *, identifier)
// The SDK's own header declares this class conforming, so the port owes the three archiving methods,
// and -copyWithZone: where the header says NSCopying. The archiver walks the same property list the
// representation does, through CharonValueStore's own pair, so a value archived and read back lands in
// the store under the property's own name and nothing has to be written out by hand for it.
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    CharonValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        CharonValueDecode(self, coder, CharonValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    // A value object: the copy is a new object with the same values under the same names - a copy that
    // shared the store would be two names for one value - made through the class's own door, because
    // its own framework refuses -init here as it refuses it for the other thirteen value classes.
    return [[[self class] allocWithZone:zone] initWithCharonValues:CharonValueStore(self)];
}

@end
@implementation SRSupplementalCategory (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

// The single string constant of iOS 16.4,
// declared at SRSensors.h:246,
// named from CharonSensorKitNames.h rather than written here: an object carries the API of
// one release alone, while the values are one list that the host comparison in
// tests/backports/host/sensorkit-names walks whole.

#define CHARON_SENSORKIT_NAMES_16_4
#import "CharonSensorKitNames.h"
