#import <Foundation/Foundation.h>
#import "markdown_dump.h"

#ifndef REVENANT_HOST_PROBE
NSString *const NSPresentationIntentAttributeName = @"NSPresentationIntent";
NSString *const NSInlinePresentationIntentAttributeName = @"NSInlinePresentationIntent";
NSString *const NSLanguageIdentifierAttributeName = @"NSLanguage";
NSString *const NSImageURLAttributeName = @"NSImageURL";
#endif

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 2) {
        fprintf(stderr, "usage: %s corpus-file\n", argv[0]);
        return 2;
    }
    @autoreleasepool {
        NSArray *sources = revenant_corpus([NSString stringWithUTF8String:argv[1]]);
        NSArray *names = revenant_syntax_names();
        NSURL *base = [NSURL URLWithString:@"https://base.example/docs/"];
        for (NSUInteger set = 0; set < names.count; set++) {
            NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
            options.interpretedSyntax = (NSAttributedStringMarkdownInterpretedSyntax)set;
            for (NSUInteger index = 0; index < sources.count; index++) {
                NSError *error = nil;
                NSAttributedString *text = [[NSAttributedString alloc] initWithMarkdown:[sources[index] dataUsingEncoding:NSUTF8StringEncoding] options:options baseURL:base error:&error];
                printf("== %s %lu\n%s", [names[set] UTF8String], (unsigned long)index, text ? [revenant_dump(text) UTF8String] : [[NSString stringWithFormat:@"error %@ %ld\n", error.domain, (long)error.code] UTF8String]);
            }
        }
    }
    return 0;
}
