#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern BOOL revenant_url_parse(NSString *string, NSRange *ranges);
extern BOOL revenant_url_valid(int part, NSString *string);
extern NSString *revenant_url_compose(NSURLComponents *components, NSRange *ranges);

static char RevenantURLComponentsRawKey;

static NSString *revenant_escaped(NSString *text)
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

static NSString *revenant_whole_escaped(NSString *text)
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

@implementation NSURLComponents (RevenantEncoding)

+ (NSURLComponents *)componentsWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSURLComponents *components = encoding ? [self componentsWithString:revenant_whole_escaped(string)] : [self componentsWithString:string];
    if (components)
        objc_setAssociatedObject(components, &RevenantURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return components;
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSURLComponents *components = encoding ? [[NSURLComponents alloc] initWithString:revenant_whole_escaped(string)]
                                           : [[NSURLComponents alloc] initWithString:string];
    if (components && components != self)
        objc_setAssociatedObject(components, &RevenantURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (components)
        objc_setAssociatedObject(self, &RevenantURLComponentsRawKey, [string copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return components == self ? self : components;
}

- (NSString *)encodedHost
{
    NSString *host = self.host;
    if (!host)
        return nil;
    NSString *raw = objc_getAssociatedObject(self, &RevenantURLComponentsRawKey);
    if (raw) {
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
    return revenant_escaped(host);
}

@end
