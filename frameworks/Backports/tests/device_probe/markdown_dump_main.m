#import <Foundation/Foundation.h>

static NSString *revenant_intent(NSPresentationIntent *intent)
{
    NSMutableArray *chain = [NSMutableArray array];
    for (NSPresentationIntent *step = intent; step; step = step.parentIntent) {
        NSMutableString *line = [NSMutableString stringWithFormat:@"%ld#%ld", (long)step.intentKind, (long)step.identity];
        switch (step.intentKind) {
        case NSPresentationIntentKindHeader:
            [line appendFormat:@" level=%ld", (long)step.headerLevel];
            break;
        case NSPresentationIntentKindListItem:
            [line appendFormat:@" ordinal=%ld", (long)step.ordinal];
            break;
        case NSPresentationIntentKindCodeBlock:
            [line appendFormat:@" hint=%@", step.languageHint ?: @"nil"];
            break;
        case NSPresentationIntentKindTable:
            [line appendFormat:@" columns=%ld alignments=%@", (long)step.columnCount, [step.columnAlignments componentsJoinedByString:@","]];
            break;
        case NSPresentationIntentKindTableRow:
            [line appendFormat:@" row=%ld", (long)step.row];
            break;
        case NSPresentationIntentKindTableCell:
            [line appendFormat:@" column=%ld", (long)step.column];
            break;
        default:
            break;
        }
        [chain addObject:line];
    }
    return [chain componentsJoinedByString:@" <- "];
}

static NSString *revenant_value(id value)
{
    if ([value isKindOfClass:[NSPresentationIntent class]]) {
        return [NSString stringWithFormat:@"intent(%@)", revenant_intent(value)];
    }
    if ([value isKindOfClass:[NSURL class]]) {
        return [NSString stringWithFormat:@"url(%@)", [value absoluteString]];
    }
    return [NSString stringWithFormat:@"%@", value];
}

static NSString *revenant_dump(NSAttributedString *text)
{
    NSMutableString *out = [NSMutableString stringWithFormat:@"length=%lu\n", (unsigned long)text.length];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *key in [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [items addObject:[NSString stringWithFormat:@"%@=%@", key, revenant_value(attributes[key])]];
        }
        NSString *piece = [text.string substringWithRange:range];
        [out appendFormat:@"  %lu,%lu %@ {%@}\n", (unsigned long)range.location, (unsigned long)range.length, [piece stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"], [items componentsJoinedByString:@"; "]];
    }];
    return out;
}

int main(void)
{
    @autoreleasepool {
        NSArray *sources = @[
            @"plain text",
            @"# Title\n\nParagraph with *emphasis*, **strong**, `code`, ~~gone~~ and a [link](https://example.com/a?b=1).\n",
            @"- one\n- two\n  - nested\n\n1. first\n2. second\n",
            @"> quote\n\n```swift\nlet x = 1\n```\n\n---\n",
            @"| a | b |\n|---|:-:|\n| 1 | 2 |\n",
            @"![alt text](pic.png \"title\") and [relative](docs/a.md)",
            @"line one\nline two  \nhard\\\nbreak",
            @"<b>html</b> and <span>inline</span>",
            @"multi   space  \n\n\n  indented",
            @"café \U0001F600 **中文** שלום",
            @"Setext\n======\n\nSub\n---\n\ntext",
            @"3. three\n4. four\n\n- [ ] task\n- [x] done",
            @"## Heading with `code` and *em*\n\n### Third\n\n#### Fourth\n##### Fifth\n###### Sixth",
            @"<https://autolink.example> and https://bare.example and [titled](http://t.example \"Title\")",
            @"***both*** _under_ __strong__ *nested **inside** em*",
            @"escaped \\*stars\\* and \\# hash and a trailing backslash\\",
            @"    indented code block\n    second line\n\nparagraph",
            @"1. a\n   - b\n     1. c\n\n> - quoted list\n> > deeper",
            @"| Name | Qty | Note |\n|:-----|----:|:----:|\n| *x* | 1 | `y` |\n| z | 22 | [l](http://l.example) |",
            @"```\nno hint\n```\n\n~~~python\ntilde\n~~~",
        ];
        NSArray *names = @[@"full", @"inline", @"inlinePreserving"];
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
