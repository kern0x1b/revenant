#import <UIKit/UIKit.h>

@interface UILexiconEntry (RevenantInit)
- (instancetype)initRevenantWithDocumentText:(NSString *)documentText userInput:(NSString *)userInput;
@end

@interface UILexicon (RevenantInit)
- (instancetype)initRevenantWithEntries:(NSArray<UILexiconEntry *> *)entries;
@end

@implementation UILexiconEntry {
    NSString *_documentText;
    NSString *_userInput;
}

- (instancetype)initRevenantWithDocumentText:(NSString *)documentText userInput:(NSString *)userInput
{
    if ((self = [super init])) {
        _documentText = [documentText copy];
        _userInput = [userInput copy];
    }
    return self;
}

- (NSString *)documentText
{
    return _documentText;
}

- (NSString *)userInput
{
    return _userInput;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UILexiconEntry class]])
        return NO;
    UILexiconEntry *other = object;
    return [_documentText isEqualToString:other->_documentText] && [_userInput isEqualToString:other->_userInput];
}

- (NSUInteger)hash
{
    return _documentText.hash ^ _userInput.hash;
}

@end

@implementation UILexicon {
    NSArray<UILexiconEntry *> *_entries;
}

- (instancetype)initRevenantWithEntries:(NSArray<UILexiconEntry *> *)entries
{
    if ((self = [super init]))
        _entries = [entries copy];
    return self;
}

- (NSArray<UILexiconEntry *> *)entries
{
    return _entries ?: @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
