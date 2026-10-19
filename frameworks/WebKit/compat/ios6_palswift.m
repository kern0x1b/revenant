#import <Foundation/Foundation.h>

@interface WebPALRegexHelper : NSObject
+ (BOOL)matchPattern:(NSString *)pattern value:(NSString *)value shouldIgnoreCase:(BOOL)shouldIgnoreCase;
@end

@implementation WebPALRegexHelper

+ (BOOL)matchPattern:(NSString *)pattern value:(NSString *)value shouldIgnoreCase:(BOOL)shouldIgnoreCase
{
    if (!pattern || !value)
        return NO;

    NSRegularExpressionOptions options = shouldIgnoreCase ? NSRegularExpressionCaseInsensitive : 0;
    NSError *error = nil;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:options
                                                                                 error:&error];
    if (!expression || error)
        return NO;

    return [expression numberOfMatchesInString:value
                                       options:0
                                         range:NSMakeRange(0, [value length])] > 0;
}

@end
