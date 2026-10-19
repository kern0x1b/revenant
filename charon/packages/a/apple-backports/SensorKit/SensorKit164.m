#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

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
@implementation SRKeyboardMetrics (CharonSensorKit164)
@dynamic longWordTouchUpDown, touchUpDown;
CHARON_VALUE_PROPERTY(NSArray *, longWordTouchUpDown)
CHARON_VALUE_PROPERTY(id, touchUpDown)
@end
@interface SRSupplementalCategory ()
- (instancetype)initWithCharonValues:(NSDictionary *)values;
@end

@implementation SRSupplementalCategory
@dynamic identifier;
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
CHARON_VALUE_COPY_INITIALISER
CHARON_VALUE_PROPERTY(NSString *, identifier)
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
    return [[[self class] allocWithZone:zone] initWithCharonValues:CharonValueStore(self)];
}

@end
@implementation SRSupplementalCategory (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

#define CHARON_SENSORKIT_NAMES_16_4
#import "CharonSensorKitNames.h"
