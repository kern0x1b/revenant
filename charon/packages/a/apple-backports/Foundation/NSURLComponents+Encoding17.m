#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* The two ways of reading a components string that percent-encode what a URL cannot carry, and the
   host of a components object in the form a URL needs.

   The header: with encodingInvalidCharacters:NO a character a URL cannot carry makes the whole read
   answer nil (measured: "https://example.com/a b" is nil both ways round, and "https://example.com/a
   %20b" with NO). The rule the port uses is the release's own URL grammar: a character is written as
   a percent escape when it is not one a URL may carry unescaped, and the escape is upper case.

   encodedHost is the host as a URL writes it, which is not the host as a property reads it: a host
   that came in with a percent escape reads back decoded and keeps the escape in encodedHost
   (measured: "ex%61mple.com" reads as the host "example.com" and the encoded host "ex%61mple.com"),
   and a host set with a space in it is written "a%20b". */

extern BOOL charon_url_parse(NSString *string, NSRange *ranges);
extern BOOL charon_url_valid(int part, NSString *string);
extern NSString *charon_url_compose(NSURLComponents *components, NSRange *ranges);

static char CharonURLComponentsRawKey;

static NSString *charon_escaped(NSString *text)
{
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSCharacterSet *allowed = [NSCharacterSet URLUserAllowedCharacterSet];
    for (NSUInteger index = 0; index < text.length; index++) {
        unichar character = [text characterAtIndex:index];
        if (character < 128 && [allowed characterIsMember:character]) {
            [out appendFormat:@"%C", character];
            continue;
        }
        [out appendFormat:@"%%%02X", character];
    }
    return out;
}

static NSString *charon_whole_escaped(NSString *text)
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
        [out appendFormat:@"%%%02X", character];
    }
    return out;
}

@implementation NSURLComponents (CharonEncoding)

+ (NSURLComponents *)componentsWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSURLComponents *components = encoding ? [self componentsWithString:charon_whole_escaped(string)] : [self componentsWithString:string];
    if (components)
        objc_setAssociatedObject(components, &CharonURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return components;
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSURLComponents *components = encoding ? [[NSURLComponents alloc] initWithString:charon_whole_escaped(string)]
                                           : [[NSURLComponents alloc] initWithString:string];
    if (components && components != self)
        objc_setAssociatedObject(components, &CharonURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (components)
        objc_setAssociatedObject(self, &CharonURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return components == self ? self : components;
}

- (NSString *)encodedHost
{
    NSString *host = self.host;
    if (!host)
        return nil;
    NSString *raw = objc_getAssociatedObject(self, &CharonURLComponentsRawKey);
    if (raw) {
        /* The host as it was written, when the string still carries it. */
        NSRange schemeRange = [raw rangeOfString:@"://"];
        if (schemeRange.location != NSNotFound) {
            NSString *rest = [raw substringFromIndex:NSMaxRange(schemeRange)];
            NSRange at = [rest rangeOfString:@"@"];
            if (at.location != NSNotFound)
                rest = [rest substringFromIndex:NSMaxRange(at)];
            NSRange end = [rest rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(':', 1)].invertedSet];
            if (end.location != NSNotFound)
                rest = [rest substringToIndex:end.location];
            if (rest.length)
                return rest;
        }
    }
    return charon_escaped(host);
}

@end
