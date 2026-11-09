#import <Foundation/Foundation.h>
#import "markdown_dump.h"

extern NSAttributedString *RVParse(NSString *source, NSInteger syntax, NSURL *base);

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

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s corpus-file [verbose]\n", argv[0]);
        return 2;
    }
    @autoreleasepool {
        NSArray *sources = revenant_corpus([NSString stringWithUTF8String:argv[1]]);
        BOOL verbose = argc > 2;
        NSArray *names = revenant_syntax_names();
        NSURL *base = [NSURL URLWithString:@"https://base.example/docs/"];
        NSUInteger same = 0, total = 0;
        for (NSUInteger set = 0; set < names.count; set++) {
            NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
            options.interpretedSyntax = (NSAttributedStringMarkdownInterpretedSyntax)set;
            for (NSUInteger index = 0; index < sources.count; index++) {
                NSError *error = nil;
                NSAttributedString *host = [[NSAttributedString alloc] initWithMarkdown:[sources[index] dataUsingEncoding:NSUTF8StringEncoding] options:options baseURL:base error:&error];
                NSAttributedString *mine = RVParse(sources[index], (NSInteger)set, base);
                NSString *a = host ? revenant_dump(host) : [NSString stringWithFormat:@"error %ld\n", (long)error.code];
                NSString *b = mine ? revenant_dump(mine) : @"nil\n";
                total++;
                if ([a isEqualToString:b]) {
                    same++;
                    continue;
                }
                printf("DIFF %s %lu: %s\n", [names[set] UTF8String], (unsigned long)index, [escape(sources[index]) UTF8String]);
                if (verbose) {
                    printf("-- host\n%s-- mine\n%s", [a UTF8String], [b UTF8String]);
                }
            }
        }
        printf("same %lu of %lu\n", (unsigned long)same, (unsigned long)total);
    }
    return 0;
}
