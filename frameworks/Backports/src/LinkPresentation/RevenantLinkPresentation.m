#import "RevenantLinkPresentation.h"

#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>

static NSString *revenant_link_entity(NSString *entity)
{
    static NSDictionary *named;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        named = @{@"amp": @"&", @"lt": @"<", @"gt": @">", @"quot": @"\"", @"apos": @"'", @"nbsp": @"\u00a0"};
    });
    NSString *value = named[entity];
    if (value || ![entity hasPrefix:@"#"] || entity.length < 2) {
        return value;
    }
    BOOL hex = [entity characterAtIndex:1] == 'x' || [entity characterAtIndex:1] == 'X';
    NSString *digits = [entity substringFromIndex:hex ? 2 : 1];
    unsigned long long code = strtoull(digits.UTF8String, NULL, hex ? 16 : 10);
    if (code == 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
        return nil;
    }
    uint32_t scalar = (uint32_t)code;
    return [[NSString alloc] initWithBytes:&scalar length:sizeof(scalar) encoding:NSUTF32LittleEndianStringEncoding];
}

static NSString *revenant_link_unescape(NSString *text)
{
    if ([text rangeOfString:@"&"].location == NSNotFound) {
        return text;
    }
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);" options:0 error:NULL];
    NSMutableString *result = [NSMutableString string];
    __block NSUInteger position = 0;
    [expression enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        [result appendString:[text substringWithRange:NSMakeRange(position, match.range.location - position)]];
        NSString *replacement = revenant_link_entity([text substringWithRange:[match rangeAtIndex:1]]);
        [result appendString:replacement ?: [text substringWithRange:match.range]];
        position = NSMaxRange(match.range);
    }];
    [result appendString:[text substringFromIndex:position]];
    return result;
}

NSString *revenant_link_first(NSArray *values)
{
    for (id value in values) {
        if (![value isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length) {
            return trimmed;
        }
    }
    return nil;
}

NSString *revenant_link_charset(NSData *data)
{
    NSString *head = [[NSString alloc] initWithBytes:data.bytes length:MIN(data.length, (NSUInteger)2048) encoding:NSISOLatin1StringEncoding];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"charset\\s*=\\s*[\"']?([A-Za-z0-9_.:-]+)" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *match = [expression firstMatchInString:head options:0 range:NSMakeRange(0, head.length)];
    return match ? [head substringWithRange:[match rangeAtIndex:1]] : nil;
}

NSString *revenant_link_text(NSData *data, NSString *charset)
{
    NSString *text = nil;
    CFStringEncoding encoding = charset ? CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset) : kCFStringEncodingInvalidId;
    if (encoding != kCFStringEncodingInvalidId) {
        text = [[NSString alloc] initWithData:data encoding:CFStringConvertEncodingToNSStringEncoding(encoding)];
    }
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    return text ?: @"";
}

NSURL *revenant_link_resolve(NSString *reference, NSURL *base)
{
    NSString *trimmed = [reference stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        return nil;
    }
    NSURL *url = [NSURL URLWithString:trimmed relativeToURL:base];
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        return nil;
    }
    return url.absoluteURL;
}

NSDictionary *revenant_link_parse_html(NSString *html)
{
    NSMutableDictionary *meta = [NSMutableDictionary dictionary];
    NSString *title = nil;
    __block NSString *appleIcon = nil;
    __block NSString *icon = nil;

    NSRegularExpression *titleExpression = [NSRegularExpression regularExpressionWithPattern:@"<title[^>]*>(.*?)</title" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators error:NULL];
    NSTextCheckingResult *titleMatch = [titleExpression firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
    if (titleMatch) {
        title = revenant_link_first(@[revenant_link_unescape([html substringWithRange:[titleMatch rangeAtIndex:1]])]);
    }

    NSRegularExpression *tagExpression = [NSRegularExpression regularExpressionWithPattern:@"<(meta|link)\\b([^>]*)>" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSRegularExpression *attributeExpression = [NSRegularExpression regularExpressionWithPattern:@"([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'=<>`]+))" options:0 error:NULL];
    [tagExpression enumerateMatchesInString:html options:0 range:NSMakeRange(0, html.length) usingBlock:^(NSTextCheckingResult *tag, NSMatchingFlags flags, BOOL *stop) {
        NSString *name = [[html substringWithRange:[tag rangeAtIndex:1]] lowercaseString];
        NSString *attributeText = [html substringWithRange:[tag rangeAtIndex:2]];
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributeExpression enumerateMatchesInString:attributeText options:0 range:NSMakeRange(0, attributeText.length) usingBlock:^(NSTextCheckingResult *pair, NSMatchingFlags pairFlags, BOOL *pairStop) {
            NSString *key = [[attributeText substringWithRange:[pair rangeAtIndex:1]] lowercaseString];
            NSRange valueRange = [pair rangeAtIndex:2];
            if (valueRange.location == NSNotFound) {
                valueRange = [pair rangeAtIndex:3];
            }
            if (valueRange.location == NSNotFound) {
                valueRange = [pair rangeAtIndex:4];
            }
            if (!attributes[key]) {
                attributes[key] = revenant_link_unescape([attributeText substringWithRange:valueRange]);
            }
        }];
        if ([name isEqualToString:@"meta"]) {
            NSString *key = [(attributes[@"property"] ?: attributes[@"name"]) lowercaseString];
            NSString *content = attributes[@"content"];
            if (key.length && content && !meta[key]) {
                meta[key] = content;
            }
            return;
        }
        NSArray *relations = [[attributes[@"rel"] lowercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *href = attributes[@"href"];
        if (!href.length) {
            return;
        }
        if ([relations containsObject:@"apple-touch-icon"] || [relations containsObject:@"apple-touch-icon-precomposed"]) {
            appleIcon = appleIcon ?: href;
        } else if ([relations containsObject:@"icon"]) {
            icon = icon ?: href;
        }
    }];

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObject:meta forKey:@"meta"];
    if (title) {
        result[@"title"] = title;
    }
    NSString *iconReference = appleIcon ?: icon;
    if (iconReference) {
        result[@"icon"] = iconReference;
    }
    return result;
}
