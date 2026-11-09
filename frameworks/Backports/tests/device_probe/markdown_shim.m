#import <Foundation/Foundation.h>
#import "../../src/Foundation/RevenantMarkdownEntities.m"
#import "../../src/Foundation/RevenantMarkdownParser.m"
#import "../../src/Foundation/RevenantURLParser.m"
#import "../../src/Foundation/RevenantURLReference.m"
#import "../../src/Foundation/NSAttributedStringMarkdown15.m"

NSAttributedString *RVParse(NSString *source, NSInteger syntax, NSURL *base)
{
    NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
    options.interpretedSyntax = (NSAttributedStringMarkdownInterpretedSyntax)syntax;
    NSError *error = nil;
    return [[NSAttributedString alloc] initWithMarkdownString:source options:options baseURL:base error:&error];
}
