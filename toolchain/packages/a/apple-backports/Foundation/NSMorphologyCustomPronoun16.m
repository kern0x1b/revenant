#import <Foundation/Foundation.h>

#import "CharonMorphology.h"

NSAttributedStringKey const NSInflectionRuleAttributeName = @"NSInflect";
NSAttributedStringKey const NSInflectionAlternativeAttributeName = @"NSInflectionAlternative";

@implementation NSMorphologyCustomPronoun
{
    NSString *_subjectForm, *_objectForm, *_possessiveForm, *_possessiveAdjectiveForm, *_reflexiveForm;
}

+ (BOOL)isSupportedForLanguage:(NSString *)language
{
    return CharonCustomPronounSupportedLanguage(language);
}

+ (NSArray<NSString *> *)requiredKeysForLanguage:(NSString *)language
{
    return CharonCustomPronounSupportedLanguage(language) ? CharonCustomPronounRequiredKeys() : @[];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMorphologyCustomPronoun *copy = [[[self class] allocWithZone:zone] init];
    copy->_subjectForm = [_subjectForm copy];
    copy->_objectForm = [_objectForm copy];
    copy->_possessiveForm = [_possessiveForm copy];
    copy->_possessiveAdjectiveForm = [_possessiveAdjectiveForm copy];
    copy->_reflexiveForm = [_reflexiveForm copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_subjectForm forKey:@"subjectForm"];
    [coder encodeObject:_objectForm forKey:@"objectForm"];
    [coder encodeObject:_possessiveForm forKey:@"possessiveForm"];
    [coder encodeObject:_possessiveAdjectiveForm forKey:@"possessiveAdjectiveForm"];
    [coder encodeObject:_reflexiveForm forKey:@"reflexiveForm"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _subjectForm = [[coder decodeObjectOfClass:[NSString class] forKey:@"subjectForm"] copy];
    _objectForm = [[coder decodeObjectOfClass:[NSString class] forKey:@"objectForm"] copy];
    _possessiveForm = [[coder decodeObjectOfClass:[NSString class] forKey:@"possessiveForm"] copy];
    _possessiveAdjectiveForm = [[coder decodeObjectOfClass:[NSString class] forKey:@"possessiveAdjectiveForm"] copy];
    _reflexiveForm = [[coder decodeObjectOfClass:[NSString class] forKey:@"reflexiveForm"] copy];
    return self;
}

- (NSString *)charon_firstMissingKey
{
    NSArray *values = @[_subjectForm ?: @"", _objectForm ?: @"", _possessiveForm ?: @"",
                        _possessiveAdjectiveForm ?: @"", _reflexiveForm ?: @""];
    NSArray *keys = CharonCustomPronounRequiredKeys();
    for (NSUInteger index = 0; index < keys.count; index++)
        if (![values[index] length])
            return keys[index];
    return nil;
}

@end
