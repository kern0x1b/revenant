// The zone changes of iOS 12, and the two objects that describe them.
//
// CKFetchRecordZoneChangesOperation fetches the changes of several zones in one request, each with
// its own configuration or its own options, and CKFetchDatabaseChangesOperation is the one that
// walks the zones themselves so a caller learns which ones changed before fetching any of them. The
// two share the same rule as every other operation here: the per-item block on the transport's
// queue in the service's order, the completion last and exactly once, and a partial answer as
// CKErrorPartialFailure with the failures under CKPartialErrorsByItemIDKey.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKSubscription.h"


#pragma mark - CKFetchRecordZoneChangesConfiguration

// The two are the same three members with two names: the configuration of iOS 12 and the options
// that preceded it, which the header keeps so a caller of either can be built. Both are kept as given
// and both are read the same way, which is what the service takes either of them as.
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

