#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface CNFetchResult ()
- (instancetype)initCharonWithValue:(id)value historyToken:(NSData *)token;
@end

@implementation CNFetchResult {
    id _charonValue;
    NSData *_charonToken;
}

@dynamic value, currentHistoryToken;

+ (instancetype)charon_resultWithValue:(id)value historyToken:(NSData *)token
{
    return [[self alloc] initCharonWithValue:value historyToken:token];
}

- (instancetype)initCharonWithValue:(id)value historyToken:(NSData *)token
{
    self = [super init];
    if (self) {
        _charonValue = value;
        _charonToken = [token copy];
    }
    return self;
}

- (id)value { return _charonValue; }
- (NSData *)currentHistoryToken { return _charonToken; }

@end
