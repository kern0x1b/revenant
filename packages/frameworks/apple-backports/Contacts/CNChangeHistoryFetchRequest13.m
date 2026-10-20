#import "RevenantContacts.h"

@implementation CNChangeHistoryFetchRequest {
    NSData *_revenantStartingToken;
    NSArray *_revenantAdditionalKeys;
    BOOL _revenantShouldUnifyResults;
    BOOL _revenantMutableObjects;
    BOOL _revenantIncludeGroupChanges;
    NSArray *_revenantExcludedAuthors;
}

@dynamic startingToken, additionalContactKeyDescriptors, shouldUnifyResults, mutableObjects, includeGroupChanges,
         excludedTransactionAuthors;

- (NSData *)startingToken { return _revenantStartingToken; }
- (void)setStartingToken:(NSData *)token { _revenantStartingToken = [token copy]; }
- (NSArray *)additionalContactKeyDescriptors { return _revenantAdditionalKeys; }
- (void)setAdditionalContactKeyDescriptors:(NSArray *)keys { _revenantAdditionalKeys = [keys copy]; }
- (BOOL)shouldUnifyResults { return _revenantShouldUnifyResults; }
- (void)setShouldUnifyResults:(BOOL)unify { _revenantShouldUnifyResults = unify; }
- (BOOL)mutableObjects { return _revenantMutableObjects; }
- (void)setMutableObjects:(BOOL)mutableObjects { _revenantMutableObjects = mutableObjects; }
- (BOOL)includeGroupChanges { return _revenantIncludeGroupChanges; }
- (void)setIncludeGroupChanges:(BOOL)include { _revenantIncludeGroupChanges = include; }
- (NSArray *)excludedTransactionAuthors { return _revenantExcludedAuthors; }
- (void)setExcludedTransactionAuthors:(NSArray *)authors { _revenantExcludedAuthors = [authors copy]; }

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_revenantStartingToken forKey:@"startingToken"];
    [coder encodeObject:_revenantAdditionalKeys forKey:@"additionalContactKeyDescriptors"];
    [coder encodeBool:_revenantShouldUnifyResults forKey:@"shouldUnifyResults"];
    [coder encodeBool:_revenantMutableObjects forKey:@"mutableObjects"];
    [coder encodeBool:_revenantIncludeGroupChanges forKey:@"includeGroupChanges"];
    [coder encodeObject:_revenantExcludedAuthors forKey:@"excludedTransactionAuthors"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _revenantStartingToken = [[coder decodeObjectOfClass:[NSData class] forKey:@"startingToken"] copy];
        _revenantAdditionalKeys = [[coder decodeObjectOfClass:[NSArray class] forKey:@"additionalContactKeyDescriptors"] copy];
        _revenantShouldUnifyResults = [coder decodeBoolForKey:@"shouldUnifyResults"];
        _revenantMutableObjects = [coder decodeBoolForKey:@"mutableObjects"];
        _revenantIncludeGroupChanges = [coder decodeBoolForKey:@"includeGroupChanges"];
        _revenantExcludedAuthors = [[coder decodeObjectOfClass:[NSArray class] forKey:@"excludedTransactionAuthors"] copy];
    }
    return self;
}

@end
