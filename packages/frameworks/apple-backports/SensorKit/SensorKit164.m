#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRApplicationUsage (RevenantSensorKit164)
@dynamic supplementalCategories, relativeStartTime;
REVENANT_VALUE_PROPERTY(NSArray *, supplementalCategories)
REVENANT_SCALAR_PROPERTY(NSTimeInterval, relativeStartTime)
@end
@implementation SRApplicationUsage (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRMediaEvent
@dynamic mediaIdentifier, eventType;
REVENANT_VALUE_PROPERTY(NSString *, mediaIdentifier)
REVENANT_SCALAR_PROPERTY(SRMediaEventType, eventType)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    id copy = [[[self class] allocWithZone:zone] init];
    NSDictionary *values = RevenantValueStore(self);
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id held = values[key];
        RevenantValueStore(copy)[key] = [held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held;
    }
    return copy;
}

@end
@implementation SRMediaEvent (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRKeyboardMetrics (RevenantSensorKit164)
@dynamic longWordTouchUpDown, touchUpDown;
REVENANT_VALUE_PROPERTY(NSArray *, longWordTouchUpDown)
REVENANT_VALUE_PROPERTY(id, touchUpDown)
@end
@interface SRSupplementalCategory ()
- (instancetype)initWithRevenantValues:(NSDictionary *)values;
@end

@implementation SRSupplementalCategory
@dynamic identifier;
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Not available")
REVENANT_VALUE_COPY_INITIALISER
REVENANT_VALUE_PROPERTY(NSString *, identifier)
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    RevenantValueEncode(self, coder);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        RevenantValueDecode(self, coder, RevenantValueDecodableClasses(@"SR"));
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithRevenantValues:RevenantValueStore(self)];
}

@end
@implementation SRSupplementalCategory (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

#define REVENANT_SENSORKIT_NAMES_16_4
#import "RevenantSensorKitNames.h"
