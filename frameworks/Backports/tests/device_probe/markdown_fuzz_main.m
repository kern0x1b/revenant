#import <Foundation/Foundation.h>
#import "markdown_dump.h"

extern NSAttributedString *RVParse(NSString *source, NSInteger syntax, NSURL *base);

static uint64_t state;

static uint64_t next(void)
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return state;
}

static NSUInteger below(NSUInteger limit)
{
    return (NSUInteger)(next() % limit);
}

static NSString *escape(NSString *text)
{
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\\')
            [out appendString:@"\\\\"];
        else if (c == '\n')
            [out appendString:@"\\n"];
        else if (c == '\r')
            [out appendString:@"\\r"];
        else if (c == '\t')
            [out appendString:@"\\t"];
        else if (c < 0x20 || c > 0x7E)
            [out appendFormat:@"\\u%04X", c];
        else
            [out appendFormat:@"%C", c];
    }
    return out;
}

static NSString *hostDump(NSString *source, NSInteger syntax, NSURL *base)
{
    NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
    options.interpretedSyntax = (NSAttributedStringMarkdownInterpretedSyntax)syntax;
    NSError *error = nil;
    NSAttributedString *text = [[NSAttributedString alloc] initWithMarkdown:[source dataUsingEncoding:NSUTF8StringEncoding] options:options baseURL:base error:&error];
    return text ? revenant_dump(text) : [NSString stringWithFormat:@"error %ld\n", (long)error.code];
}

static NSString *mineDump(NSString *source, NSInteger syntax, NSURL *base)
{
    NSAttributedString *text = RVParse(source, syntax, base);
    return text ? revenant_dump(text) : @"nil\n";
}

static BOOL differs(NSArray *pieces, NSInteger syntax, NSURL *base)
{
    @autoreleasepool {
        NSString *source = [pieces componentsJoinedByString:@""];
        return ![hostDump(source, syntax, base) isEqualToString:mineDump(source, syntax, base)];
    }
}

static NSArray *split(NSString *text)
{
    NSMutableArray *pieces = [NSMutableArray array];
    NSUInteger index = 0;
    while (index < text.length) {
        NSRange range = [text rangeOfComposedCharacterSequenceAtIndex:index];
        [pieces addObject:[text substringWithRange:range]];
        index = NSMaxRange(range);
    }
    return pieces;
}

static NSArray *minimize(NSArray *pieces, NSInteger syntax, NSURL *base)
{
    NSMutableArray *current = [pieces mutableCopy];
    NSUInteger chunk = current.count / 2;
    if (chunk == 0)
        chunk = 1;
    while (YES) {
        BOOL removed = NO;
        NSUInteger at = 0;
        while (at < current.count) {
            NSUInteger length = MIN(chunk, current.count - at);
            NSMutableArray *candidate = [current mutableCopy];
            [candidate removeObjectsInRange:NSMakeRange(at, length)];
            if (candidate.count && differs(candidate, syntax, base)) {
                current = candidate;
                removed = YES;
            } else {
                at += length;
            }
        }
        if (chunk == 1 && !removed)
            break;
        if (!removed || chunk > 1)
            chunk = chunk > 1 ? chunk / 2 : 1;
    }
    return current;
}

static NSArray *tokens(void)
{
    unichar nul = 0, nel = 0x85;
    return @[[NSString stringWithCharacters:&nul length:1], @"\uFEFF", @"\uFEFF", @"\u2028", @"\u2029", [NSString stringWithCharacters:&nel length:1], @"\u200B", @"\u3000", @"\u00AD", @"\u2003", @"\u200D", @"\uFFFD", @"\u0301", @"\uFFFC",
             @"*", @"**", @"***", @"_", @"__", @"~", @"~~", @"`", @"``", @"[", @"]", @"(", @")", @"!", @"<", @">", @"http://a.example", @"https://b.example/c?d=1&e=2",
             @"www.x.example", @"a@b.example", @"foo", @"bar baz", @" ", @"  ", @"\n", @"\n", @"\n\n", @"\t", @"    ", @"- ", @"* ", @"+ ", @"1. ", @"2) ", @"3. ", @"# ", @"## ",
             @"---", @"===", @"|", @"|---|", @":-:", @"\\", @"&amp;", @"&#35;", @"&bogus;", @"&copy", @"\"", @"'", @"<b>", @"</b>", @"<div>", @"</div>", @"<!--", @"-->", @"```", @"~~~",
             @"[x]: /u \"t\"\n", @"[x]", @"![i](u)", @"[l](u)", @"<http://q.r>", @"<a@b.cc>", @"\r\n", @"\r", @"\u00e9", @"\U0001F600", @"\u00a0", @"> ", @">", @"-", @"=", @"1.", @"foo.bar",
             @"(u \"t\")", @"](u)", @"[x][y]", @"[y]: /v", @"<span class=\"a\">", @"<br/>", @"<?php ?>", @"<![CDATA[", @"]]>", @"|a|b|\n", @"|-|-|\n", @"| 1 | 2 |\n", @"\\|", @"mailto:", @"xmpp:", @"ftp://f.example",
             @"^[", @"^", @"](a: b)", @"<![CDATA[x]]]>", @"<![CDATA[", @"-|-", @"|-", @"[f]:l\n\n\"\"", @"<mailto:a&amp;b>", @"<scheme:a&amp;b >"];
}

static NSString *soup(void)
{
    static NSString *const alphabet = @"**__~~``[]()!<>&#;\n\n\n  --++==::||\"'\\\\1.0aAw/@\t^?{}%$,.";
    NSMutableString *out = [NSMutableString string];
    NSUInteger count = 2 + below(40);
    for (NSUInteger i = 0; i < count; i++) {
        unichar c = [alphabet characterAtIndex:below(alphabet.length)];
        [out appendFormat:@"%C", c];
    }
    return out;
}

static NSString *addressSoup(void)
{
    static NSArray *parts;
    if (!parts)
        parts = @[@"a", @"b", @"1", @"@", @"@", @".", @".", @"-", @"_", @"+", @"/", @":", @" ", @"mailto:", @"xmpp:", @"www.", @"http://", @"*", @"<", @">", @"(", @")", @"[", @"]"];
    NSMutableString *out = [NSMutableString string];
    NSUInteger count = 2 + below(18);
    for (NSUInteger i = 0; i < count; i++)
        [out appendString:parts[below(parts.count)]];
    return out;
}

static NSString *generate(NSArray *corpus)
{
    NSArray *tokenList = tokens();
    NSMutableString *out = [NSMutableString string];
    NSUInteger mode = below(5);
    if (mode == 0)
        return soup();
    if (mode == 1)
        return addressSoup();
    if (corpus.count && below(3) == 0) {
        NSArray *pieces = split(corpus[below(corpus.count)]);
        NSMutableArray *mutated = [pieces mutableCopy];
        NSUInteger edits = 1 + below(3);
        for (NSUInteger i = 0; i < edits; i++) {
            NSUInteger kind = below(3);
            if (kind == 0 && mutated.count)
                [mutated removeObjectAtIndex:below(mutated.count)];
            else
                [mutated insertObject:tokenList[below(tokenList.count)] atIndex:below(mutated.count + 1)];
        }
        return [mutated componentsJoinedByString:@""];
    }
    NSUInteger count = 1 + below(14);
    for (NSUInteger i = 0; i < count; i++)
        [out appendString:tokenList[below(tokenList.count)]];
    return out;
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "usage: %s corpus-file seed count [limit]\n", argv[0]);
        return 2;
    }
    @autoreleasepool {
        NSArray *corpus = revenant_corpus([NSString stringWithUTF8String:argv[1]]);
        state = (uint64_t)strtoull(argv[2], NULL, 10) * 2654435761u + 88172645463325252ull;
        NSUInteger count = (NSUInteger)strtoul(argv[3], NULL, 10);
        NSUInteger limit = argc > 4 ? (NSUInteger)strtoul(argv[4], NULL, 10) : 25;
        NSURL *base = [NSURL URLWithString:@"https://base.example/docs/"];
        NSArray *names = revenant_syntax_names();
        NSMutableSet *seen = [NSMutableSet set];
        NSUInteger failures = 0;
        for (NSUInteger iteration = 0; iteration < count && seen.count < limit; iteration++) {
            @autoreleasepool {
                NSString *source = generate(corpus);
                for (NSInteger syntax = 0; syntax < 3; syntax++) {
                    if (!differs(split(source), syntax, base))
                        continue;
                    failures++;
                    NSArray *small = minimize(split(source), syntax, base);
                    NSString *key = [NSString stringWithFormat:@"%ld %@", (long)syntax, [small componentsJoinedByString:@""]];
                    if ([seen containsObject:key])
                        continue;
                    [seen addObject:key];
                    NSString *text = [small componentsJoinedByString:@""];
                    printf("DIFF %s: %s\n", [names[(NSUInteger)syntax] UTF8String], [escape(text) UTF8String]);
                    printf("-- host\n%s-- mine\n%s", [hostDump(text, syntax, base) UTF8String], [mineDump(text, syntax, base) UTF8String]);
                }
            }
        }
        printf("fuzz %lu cases, %lu failing, %lu distinct\n", (unsigned long)count, (unsigned long)failures, (unsigned long)seen.count);
    }
    return 0;
}
