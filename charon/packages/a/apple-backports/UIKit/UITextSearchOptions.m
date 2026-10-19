#import <UIKit/UIKit.h>

// The two values are readonly in the header, and the find session is the only thing that makes an options object with other values.
// The port has no find session, so the options it makes are the release's defaults (the first match method, no compare options), which
// the ivars' zero values give; -init is not marked unavailable by the SDK, and the runtime answers the same state.
//
// Equality is by value, as the release's is: two options with the same match method and compare options are equal, and nothing else is.
// The hash follows the value, so equal options hash alike; the release's hash is per object (named in the facts file).
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
