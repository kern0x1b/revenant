#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation CNContactFetchRequest {
    NSPredicate *_revenantPredicate;
    NSArray *_revenantKeysToFetch;
    BOOL _revenantMutableObjects;
    BOOL _revenantUnifyResults;
    CNContactSortOrder _revenantSortOrder;
}

@dynamic predicate, keysToFetch, mutableObjects, unifyResults, sortOrder;

- (instancetype)initWithKeysToFetch:(NSArray *)keysToFetch
{
    self = [super init];
    if (self) {
        _revenantKeysToFetch = [keysToFetch copy];
        _revenantUnifyResults = YES;
        _revenantSortOrder = CNContactSortOrderNone;
    }
    return self;
}

- (NSPredicate *)predicate { return _revenantPredicate; }
- (void)setPredicate:(NSPredicate *)predicate { _revenantPredicate = [predicate copy]; }
- (NSArray *)keysToFetch { return _revenantKeysToFetch ?: @[]; }
- (void)setKeysToFetch:(NSArray *)keys { _revenantKeysToFetch = [keys copy]; }
- (BOOL)mutableObjects { return _revenantMutableObjects; }
- (void)setMutableObjects:(BOOL)mutableObjects { _revenantMutableObjects = mutableObjects; }
- (BOOL)unifyResults { return _revenantUnifyResults; }
- (void)setUnifyResults:(BOOL)unifyResults { _revenantUnifyResults = unifyResults; }
- (CNContactSortOrder)sortOrder { return _revenantSortOrder; }
- (void)setSortOrder:(CNContactSortOrder)sortOrder { _revenantSortOrder = sortOrder; }

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantPredicate forKey:@"predicate"];
    [coder encodeObject:_revenantKeysToFetch forKey:@"keysToFetch"];
    [coder encodeBool:_revenantMutableObjects forKey:@"mutableObjects"];
    [coder encodeBool:_revenantUnifyResults forKey:@"unifyResults"];
    [coder encodeInteger:_revenantSortOrder forKey:@"sortOrder"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self initWithKeysToFetch:[coder decodeObjectOfClass:[NSArray class] forKey:@"keysToFetch"]];
    if (self) {
        _revenantPredicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"predicate"];
        _revenantMutableObjects = [coder decodeBoolForKey:@"mutableObjects"];
        _revenantUnifyResults = [coder decodeBoolForKey:@"unifyResults"];
        _revenantSortOrder = (CNContactSortOrder)[coder decodeIntegerForKey:@"sortOrder"];
    }
    return self;
}

@end
