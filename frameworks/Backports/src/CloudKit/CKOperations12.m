#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKSubscription.h"


#pragma mark - CKFetchRecordZoneChangesConfiguration

@implementation CKFetchRecordZoneChangesConfiguration

+ (instancetype)configuration
{
    return [[self alloc] init];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _resultsLimit = CKQueryOperationMaximumResults;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CKFetchRecordZoneChangesConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.previousServerChangeToken = _previousServerChangeToken;
    copy.resultsLimit = _resultsLimit;
    copy.desiredKeys = _desiredKeys;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; previousServerChangeToken=%@, resultsLimit=%lu, desiredKeys=%@>",
            NSStringFromClass([self class]), self, _previousServerChangeToken,
            (unsigned long)_resultsLimit, _desiredKeys];
}

@end
