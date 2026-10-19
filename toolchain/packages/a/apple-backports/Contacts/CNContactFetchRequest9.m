#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CNContactFetchRequest {
    NSPredicate *_charonPredicate;
    NSArray *_charonKeysToFetch;
    BOOL _charonMutableObjects;
    BOOL _charonUnifyResults;
    CNContactSortOrder _charonSortOrder;
}

@dynamic predicate, keysToFetch, mutableObjects, unifyResults, sortOrder;

- (instancetype)initWithKeysToFetch:(NSArray *)keysToFetch
{
    self = [super init];
    if (self) {
        _charonKeysToFetch = [keysToFetch copy];
        _charonUnifyResults = YES;
        _charonSortOrder = CNContactSortOrderNone;
    }
    return self;
}

- (NSPredicate *)predicate { return _charonPredicate; }
- (void)setPredicate:(NSPredicate *)predicate { _charonPredicate = [predicate copy]; }
- (NSArray *)keysToFetch { return _charonKeysToFetch ?: @[]; }
- (void)setKeysToFetch:(NSArray *)keys { _charonKeysToFetch = [keys copy]; }
- (BOOL)mutableObjects { return _charonMutableObjects; }
- (void)setMutableObjects:(BOOL)mutableObjects { _charonMutableObjects = mutableObjects; }
- (BOOL)unifyResults { return _charonUnifyResults; }
- (void)setUnifyResults:(BOOL)unifyResults { _charonUnifyResults = unifyResults; }
- (CNContactSortOrder)sortOrder { return _charonSortOrder; }
- (void)setSortOrder:(CNContactSortOrder)sortOrder { _charonSortOrder = sortOrder; }

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonPredicate forKey:@"predicate"];
    [coder encodeObject:_charonKeysToFetch forKey:@"keysToFetch"];
    [coder encodeBool:_charonMutableObjects forKey:@"mutableObjects"];
    [coder encodeBool:_charonUnifyResults forKey:@"unifyResults"];
    [coder encodeInteger:_charonSortOrder forKey:@"sortOrder"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self initWithKeysToFetch:[coder decodeObjectOfClass:[NSArray class] forKey:@"keysToFetch"]];
    if (self) {
        _charonPredicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"predicate"];
        _charonMutableObjects = [coder decodeBoolForKey:@"mutableObjects"];
        _charonUnifyResults = [coder decodeBoolForKey:@"unifyResults"];
        _charonSortOrder = (CNContactSortOrder)[coder decodeIntegerForKey:@"sortOrder"];
    }
    return self;
}

@end
