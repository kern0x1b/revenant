#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface CNFetchResult ()
- (instancetype)initRevenantWithValue:(id)value historyToken:(NSData *)token;
@end

@implementation CNFetchResult {
    id _revenantValue;
    NSData *_revenantToken;
}

@dynamic value, currentHistoryToken;

+ (instancetype)revenant_resultWithValue:(id)value historyToken:(NSData *)token
{
    return [[self alloc] initRevenantWithValue:value historyToken:token];
}

- (instancetype)initRevenantWithValue:(id)value historyToken:(NSData *)token
{
    self = [super init];
    if (self) {
        _revenantValue = value;
        _revenantToken = [token copy];
    }
    return self;
}

- (id)value { return _revenantValue; }
- (NSData *)currentHistoryToken { return _revenantToken; }

@end
