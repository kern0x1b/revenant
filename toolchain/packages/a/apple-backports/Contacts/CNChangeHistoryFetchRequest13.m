#import "CharonContacts.h"

@implementation CNChangeHistoryFetchRequest {
    NSData *_charonStartingToken;
    NSArray *_charonAdditionalKeys;
    BOOL _charonShouldUnifyResults;
    BOOL _charonMutableObjects;
    BOOL _charonIncludeGroupChanges;
    NSArray *_charonExcludedAuthors;
}

@dynamic startingToken, additionalContactKeyDescriptors, shouldUnifyResults, mutableObjects, includeGroupChanges,
         excludedTransactionAuthors;

- (NSData *)startingToken { return _charonStartingToken; }
- (void)setStartingToken:(NSData *)token { _charonStartingToken = [token copy]; }
- (NSArray *)additionalContactKeyDescriptors { return _charonAdditionalKeys; }
- (void)setAdditionalContactKeyDescriptors:(NSArray *)keys { _charonAdditionalKeys = [keys copy]; }
- (BOOL)shouldUnifyResults { return _charonShouldUnifyResults; }
- (void)setShouldUnifyResults:(BOOL)unify { _charonShouldUnifyResults = unify; }
- (BOOL)mutableObjects { return _charonMutableObjects; }
- (void)setMutableObjects:(BOOL)mutableObjects { _charonMutableObjects = mutableObjects; }
- (BOOL)includeGroupChanges { return _charonIncludeGroupChanges; }
- (void)setIncludeGroupChanges:(BOOL)include { _charonIncludeGroupChanges = include; }
- (NSArray *)excludedTransactionAuthors { return _charonExcludedAuthors; }
- (void)setExcludedTransactionAuthors:(NSArray *)authors { _charonExcludedAuthors = [authors copy]; }

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_charonStartingToken forKey:@"startingToken"];
    [coder encodeObject:_charonAdditionalKeys forKey:@"additionalContactKeyDescriptors"];
    [coder encodeBool:_charonShouldUnifyResults forKey:@"shouldUnifyResults"];
    [coder encodeBool:_charonMutableObjects forKey:@"mutableObjects"];
    [coder encodeBool:_charonIncludeGroupChanges forKey:@"includeGroupChanges"];
    [coder encodeObject:_charonExcludedAuthors forKey:@"excludedTransactionAuthors"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _charonStartingToken = [[coder decodeObjectOfClass:[NSData class] forKey:@"startingToken"] copy];
        _charonAdditionalKeys = [[coder decodeObjectOfClass:[NSArray class] forKey:@"additionalContactKeyDescriptors"] copy];
        _charonShouldUnifyResults = [coder decodeBoolForKey:@"shouldUnifyResults"];
        _charonMutableObjects = [coder decodeBoolForKey:@"mutableObjects"];
        _charonIncludeGroupChanges = [coder decodeBoolForKey:@"includeGroupChanges"];
        _charonExcludedAuthors = [[coder decodeObjectOfClass:[NSArray class] forKey:@"excludedTransactionAuthors"] copy];
    }
    return self;
}

@end
