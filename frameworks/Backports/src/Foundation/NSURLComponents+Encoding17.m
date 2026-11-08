#import <Foundation/Foundation.h>

static NSCharacterSet *revenant_written_characters(void)
{
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        allowed = [NSCharacterSet characterSetWithCharactersInString:
                   @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%"];
    });
    return allowed;
}

static BOOL revenant_readable(NSString *text)
{
    NSCharacterSet *allowed = revenant_written_characters();
    for (NSUInteger index = 0; index < text.length; index++) {
        if (![allowed characterIsMember:[text characterAtIndex:index]])
            return NO;
    }
    return YES;
}

static NSString *revenant_whole_escaped(NSString *text)
{
    NSCharacterSet *allowed = revenant_written_characters();
    NSData *bytes = [text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    const unsigned char *raw = bytes.bytes;
    NSMutableString *out = [NSMutableString stringWithCapacity:bytes.length];
    for (NSUInteger index = 0; index < bytes.length; index++) {
        if (raw[index] < 128 && [allowed characterIsMember:raw[index]])
            [out appendFormat:@"%c", raw[index]];
        else
            [out appendFormat:@"%%%02X", raw[index]];
    }
    return out;
}

static BOOL revenant_scheme_character(unichar character, BOOL first)
{
    if ((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z'))
        return YES;
    return !first && ((character >= '0' && character <= '9') || character == '+' || character == '-' || character == '.');
}

static NSRange revenant_host_range(NSString *text)
{
    NSUInteger length = text.length;
    NSUInteger after = 0;
    NSUInteger scan = 0;
    while (scan < length && revenant_scheme_character([text characterAtIndex:scan], scan == 0))
        scan++;
    if (scan > 0 && scan < length && [text characterAtIndex:scan] == ':')
        after = scan + 1;
    if (after + 2 > length || [text characterAtIndex:after] != '/' || [text characterAtIndex:after + 1] != '/')
        return NSMakeRange(NSNotFound, 0);
    NSUInteger authority = after + 2;
    NSUInteger end = authority;
    while (end < length) {
        unichar character = [text characterAtIndex:end];
        if (character == '/' || character == '?' || character == '#')
            break;
        end++;
    }
    NSUInteger start = authority;
    for (NSUInteger index = authority; index < end; index++) {
        if ([text characterAtIndex:index] == '@')
            start = index + 1;
    }
    NSUInteger stop = end;
    if (start < end && [text characterAtIndex:start] == '[') {
        for (NSUInteger index = start; index < end; index++) {
            if ([text characterAtIndex:index] == ']') {
                stop = index + 1;
                break;
            }
        }
    } else {
        for (NSUInteger index = end; index > start; index--) {
            if ([text characterAtIndex:index - 1] == ':') {
                stop = index - 1;
                break;
            }
        }
    }
    return NSMakeRange(start, stop - start);
}

static NSString *revenant_encoded_invalid(NSString *text)
{
    NSRange host = revenant_host_range(text);
    if (host.location == NSNotFound)
        return revenant_whole_escaped(text);
    NSString *head = [text substringToIndex:host.location];
    NSString *tail = [text substringFromIndex:NSMaxRange(host)];
    return [@[revenant_whole_escaped(head), [text substringWithRange:host], revenant_whole_escaped(tail)] componentsJoinedByString:@""];
}

@implementation NSURLComponents (RevenantEncoding)

+ (NSURLComponents *)componentsWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    return [[self alloc] initWithString:string encodingInvalidCharacters:encoding];
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    if (encoding)
        return [self initWithString:revenant_encoded_invalid(string)];
    if (!revenant_readable(string))
        return nil;
    self = [self initWithString:string];
    return [self.string isEqualToString:string] ? self : nil;
}

@end
