#import "RevenantDocument.h"
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

static NSString *const Base64Alphabet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static NSString *Base64(NSData *data)
{
    const unsigned char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < length; index += 3) {
        NSUInteger chunk = bytes[index] << 16;
        NSUInteger count = 1;
        if (index + 1 < length) {
            chunk |= bytes[index + 1] << 8;
            count++;
        }
        if (index + 2 < length) {
            chunk |= bytes[index + 2];
            count++;
        }
        for (NSUInteger shift = 0; shift < 4; shift++) {
            if (shift <= count)
                [text appendFormat:@"%C", [Base64Alphabet characterAtIndex:(chunk >> (18 - 6 * shift)) & 63]];
            else
                [text appendString:@"="];
        }
    }
    return text;
}

static NSString *ScriptText(NSString *script)
{
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < script.length; index++) {
        unichar unit = [script characterAtIndex:index];
        if (unit > 0x7F)
            [text appendFormat:@"\\u%04x", unit];
        else
            [text appendFormat:@"%C", unit];
    }
    return [text stringByReplacingOccurrencesOfString:@"</script" withString:@"<\\/script" options:NSCaseInsensitiveSearch range:NSMakeRange(0, text.length)];
}

static NSString *ScriptElements(NSArray<NSString *> *scripts)
{
    NSMutableString *text = [NSMutableString string];
    for (NSString *script in scripts)
        [text appendFormat:@"<script>%@</script>", ScriptText(script)];
    return text;
}

static NSRegularExpression *Expression(NSString *pattern)
{
    return [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
}

static NSString *FirstToken(NSString *text)
{
    for (NSString *token in [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (token.length)
            return token;
    }
    return @"";
}

static NSString *DirectiveWithHashes(NSString *directive, NSArray<NSString *> *hashes)
{
    NSMutableArray *tokens = [NSMutableArray array];
    for (NSString *token in [directive componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (token.length && ![token.lowercaseString isEqualToString:@"'none'"])
            [tokens addObject:token];
    }
    for (NSString *hash in hashes) {
        if (![tokens containsObject:hash])
            [tokens addObject:hash];
    }
    return [tokens componentsJoinedByString:@" "];
}

static NSString *MetaTagWithHashes(NSString *tag, NSArray<NSString *> *scripts)
{
    NSTextCheckingResult *content = [Expression(@"content\\s*=\\s*([\"'])(.*?)\\1") firstMatchInString:tag options:0 range:NSMakeRange(0, tag.length)];
    if (!content)
        return tag;
    NSString *quote = [tag substringWithRange:[content rangeAtIndex:1]];
    NSString *policy = RevenantDocumentCSPWithHashes([tag substringWithRange:[content rangeAtIndex:2]], scripts);
    return [tag stringByReplacingCharactersInRange:content.range withString:[NSString stringWithFormat:@"content=%@%@%@", quote, policy, quote]];
}

static NSStringEncoding EncodingNamed(NSString *name)
{
    if (!name.length)
        return 0;
    CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)name);
    if (encoding == kCFStringEncodingInvalidId)
        return 0;
    return CFStringConvertEncodingToNSStringEncoding(encoding);
}

static NSStringEncoding MetaEncoding(NSData *body)
{
    NSUInteger length = MIN(body.length, (NSUInteger)1024);
    NSString *head = [[NSString alloc] initWithBytes:body.bytes length:length encoding:NSISOLatin1StringEncoding];
    if (!head)
        return 0;
    NSTextCheckingResult *match = [Expression(@"<meta[^>]*charset\\s*=\\s*[\"']?\\s*([A-Za-z0-9_:.+-]+)") firstMatchInString:head options:0 range:NSMakeRange(0, head.length)];
    return match ? EncodingNamed([head substringWithRange:[match rangeAtIndex:1]]) : 0;
}

static NSString *Decode(NSData *body, NSString *charset, NSStringEncoding *encoding)
{
    NSStringEncoding chosen = EncodingNamed(charset);
    if (!chosen)
        chosen = MetaEncoding(body);
    if (!chosen)
        chosen = NSUTF8StringEncoding;
    *encoding = chosen;
    return [[NSString alloc] initWithData:body encoding:chosen];
}

static NSData *Inflate(NSData *data)
{
    z_stream stream;
    memset(&stream, 0, sizeof stream);
    if (inflateInit2(&stream, 15 + 16) != Z_OK)
        return nil;
    NSMutableData *output = [NSMutableData data];
    unsigned char buffer[16384];
    stream.next_in = (Bytef *)data.bytes;
    stream.avail_in = (uInt)data.length;
    int status = Z_OK;
    do {
        stream.next_out = buffer;
        stream.avail_out = sizeof buffer;
        status = inflate(&stream, Z_NO_FLUSH);
        if (status != Z_OK && status != Z_STREAM_END) {
            inflateEnd(&stream);
            return nil;
        }
        [output appendBytes:buffer length:sizeof buffer - stream.avail_out];
    } while (status != Z_STREAM_END && (stream.avail_in > 0 || stream.avail_out == 0));
    inflateEnd(&stream);
    return status == Z_STREAM_END ? output : nil;
}

static NSData *Plain(NSData *body, NSString *contentEncoding)
{
    NSString *coding = contentEncoding.lowercaseString;
    if (!coding.length || [coding isEqualToString:@"identity"])
        return body;
    if (![coding isEqualToString:@"gzip"] && ![coding isEqualToString:@"x-gzip"])
        return nil;
    const unsigned char *bytes = body.bytes;
    if (body.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b)
        return body;
    return Inflate(body);
}

NSString *RevenantDocumentHash(NSString *script)
{
    NSData *bytes = [ScriptText(script) dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    return [@"sha256-" stringByAppendingString:Base64([NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH])];
}

NSString *RevenantDocumentCSPWithHashes(NSString *policy, NSArray<NSString *> *scripts)
{
    if (!scripts.count)
        return policy;
    NSMutableArray *hashes = [NSMutableArray array];
    for (NSString *script in scripts)
        [hashes addObject:[NSString stringWithFormat:@"'%@'", RevenantDocumentHash(script)]];
    NSMutableArray *policies = [NSMutableArray array];
    for (NSString *single in [policy componentsSeparatedByString:@","]) {
        NSArray *directives = [single componentsSeparatedByString:@";"];
        NSInteger target = -1, fallback = -1;
        for (NSUInteger position = 0; position < directives.count; position++) {
            NSString *name = [FirstToken(directives[position]) lowercaseString];
            if (target < 0 && [name isEqualToString:@"script-src"])
                target = position;
            if (fallback < 0 && [name isEqualToString:@"default-src"])
                fallback = position;
        }
        NSInteger governing = target >= 0 ? target : fallback;
        NSMutableArray *edited = [NSMutableArray array];
        for (NSUInteger position = 0; position < directives.count; position++) {
            BOOL edit = (NSInteger)position == governing;
            [edited addObject:edit ? DirectiveWithHashes(directives[position], hashes) : directives[position]];
        }
        [policies addObject:[edited componentsJoinedByString:@";"]];
    }
    return [policies componentsJoinedByString:@","];
}

NSString *RevenantDocumentInsert(NSString *html, NSArray<NSString *> *scripts)
{
    NSMutableString *document = [html mutableCopy];
    NSArray *metas = [Expression(@"<meta\\b[^>]*http-equiv\\s*=\\s*[\"']?content-security-policy[\"']?[^>]*>") matchesInString:document options:0 range:NSMakeRange(0, document.length)];
    for (NSTextCheckingResult *meta in [metas reverseObjectEnumerator]) {
        NSString *tag = [document substringWithRange:meta.range];
        [document replaceCharactersInRange:meta.range withString:MetaTagWithHashes(tag, scripts)];
    }
    NSUInteger at = 0;
    NSTextCheckingResult *head = [Expression(@"<head(\\s[^>]*)?>") firstMatchInString:document options:0 range:NSMakeRange(0, document.length)];
    if (head) {
        at = NSMaxRange(head.range);
    } else {
        NSTextCheckingResult *doctype = [Expression(@"<!doctype[^>]*>") firstMatchInString:document options:0 range:NSMakeRange(0, document.length)];
        if (doctype)
            at = NSMaxRange(doctype.range);
    }
    [document insertString:ScriptElements(scripts) atIndex:at];
    return document;
}

NSData *RevenantDocumentRewrite(NSData *body, NSString *contentEncoding, NSString *charset, NSArray<NSString *> *scripts)
{
    if (!scripts.count)
        return nil;
    NSData *plain = Plain(body, contentEncoding);
    if (!plain)
        return nil;
    NSStringEncoding encoding = 0;
    NSString *html = Decode(plain, charset, &encoding);
    if (!html)
        return nil;
    return [RevenantDocumentInsert(html, scripts) dataUsingEncoding:encoding];
}
