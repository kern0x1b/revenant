#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static BOOL charon_url_readable(NSString *text)
{
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSCharacterSet characterSetWithCharactersInString:
                   @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%"];
    });
    for (NSUInteger index = 0; index < text.length; index++)
        if (![allowed characterIsMember:[text characterAtIndex:index]])
            return NO;
    return YES;
}

static NSString *charon_url_escaped(NSString *text)
{
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar character = [text characterAtIndex:index];
        if ((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') ||
            (character >= '0' && character <= '9') || character == '-' || character == '.' ||
            character == '_' || character == '~' || character == ':' || character == '/' ||
            character == '?' || character == '#' || character == '[' || character == ']' ||
            character == '@' || character == '!' || character == '$' || character == '&' ||
            character == '\'' || character == '(' || character == ')' || character == '*' ||
            character == '+' || character == ',' || character == ';' || character == '=' || character == '%') {
            [out appendFormat:@"%C", character];
            continue;
        }
        [out appendString:[NSString stringWithFormat:@"%%%02X", character]];
    }
    return out;
}

static NSString *charon_url_percent_escaped(NSString *text)
{
    NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *raw = bytes.bytes;
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger index = 0; index < bytes.length; index++)
        [out appendFormat:@"%%%02X", raw[index]];
    return out;
}

@implementation NSURL (CharonEncoding)

+ (NSURL *)URLWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    if (!encoding)
        return charon_url_readable(string) ? [self URLWithString:string] : nil;
    NSMutableString *escaped = [NSMutableString stringWithCapacity:string.length];
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar character = [string characterAtIndex:index];
        if (character < 128) {
            [escaped appendFormat:@"%C", character];
            continue;
        }
        [escaped appendString:charon_url_percent_escaped([NSString stringWithFormat:@"%C", character])];
    }
    return [self URLWithString:charon_url_escaped(escaped)];
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    if (!encoding)
        return charon_url_readable(string) ? [self initWithString:string] : nil;
    NSMutableString *escaped = [NSMutableString stringWithCapacity:string.length];
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar character = [string characterAtIndex:index];
        if (character < 128) {
            [escaped appendFormat:@"%C", character];
            continue;
        }
        [escaped appendString:charon_url_percent_escaped([NSString stringWithFormat:@"%C", character])];
    }
    return [self initWithString:charon_url_escaped(escaped)];
}

@end
