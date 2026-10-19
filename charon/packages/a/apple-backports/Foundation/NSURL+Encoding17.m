#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The two ways of reading a URL string that percent-encode what a URL cannot carry. The rule is the
   one the release's own URL grammar uses, and the answer for a string that still cannot be read
   afterwards is nil, which is what the host answers with the flag off (measured: "https://
   example.com/a b" is nil, "https://example.com/a%20b" is a URL). */

/* Whether a string carries a character a URL cannot read. The release's own +URLWithString: takes
   some of them and percent-escapes what it can, which is not what the modern API promises with the
   flag off: the host answers nil for a string with a space in it (measured, and the differential holds
   it for four strings), so the check is made before the release is asked. */
static BOOL charon_url_readable(NSString *text)
{
    /* RFC 3986's unreserved and reserved sets: what a URL may carry as it stands. Anything else has
       to be written as a percent escape, which is what the flag on turns on. */
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

/* The escape is written from the string's UTF-8 bytes, which is what a URL carries: a percent escape
   is two hex digits of a byte, and a character outside ASCII is three bytes and so three escapes. */
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
