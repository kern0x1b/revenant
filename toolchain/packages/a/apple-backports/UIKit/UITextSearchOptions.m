#import <UIKit/UIKit.h>

@implementation UITextSearchOptions {
@private
    UITextSearchMatchMethod _wordMatchMethod;
    NSStringCompareOptions _stringCompareOptions;
}

- (UITextSearchMatchMethod)wordMatchMethod
{
    return _wordMatchMethod;
}

- (NSStringCompareOptions)stringCompareOptions
{
    return _stringCompareOptions;
}

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:[UITextSearchOptions class]]) {
        return NO;
    }
    UITextSearchOptions *other = object;
    return _wordMatchMethod == other->_wordMatchMethod && _stringCompareOptions == other->_stringCompareOptions;
}

- (NSUInteger)hash
{
    return (NSUInteger)_wordMatchMethod * 31 + (NSUInteger)_stringCompareOptions;
}

@end
