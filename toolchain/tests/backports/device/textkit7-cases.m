#import <UIKit/UIKit.h>
#import "textkit7-cases.h"

static NSString *color_text(UIColor *color)
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat white;
        [color getWhite:&white alpha:&a];
        r = g = b = white;
    }
    return [NSString stringWithFormat:@"%.2f,%.2f,%.2f,%.2f", r, g, b, a];
}

static NSString *style_text(NSParagraphStyle *style)
{
    NSMutableArray *tabs = [NSMutableArray array];
    for (id tab in style.tabStops)
        [tabs addObject:[NSString stringWithFormat:@"%.0f", [(NSTextTab *)tab location]]];
    return [NSString stringWithFormat:@"align=%ld first=%.0f head=%.0f tail=%.0f spacing=%.0f before=%.0f line=%.0f mult=%.2f tabs=[%@] interval=%.0f lists=%lu", (long)style.alignment, style.firstLineHeadIndent, style.headIndent, style.tailIndent,
            style.paragraphSpacing, style.paragraphSpacingBefore, style.lineSpacing, style.lineHeightMultiple, [tabs componentsJoinedByString:@" "], style.defaultTabInterval, (unsigned long)style.textLists.count];
}

static NSString *attribute_text(NSString *key, id value)
{
    if ([value isKindOfClass:[UIFont class]])
        return [NSString stringWithFormat:@"%.0f %@", [(UIFont *)value pointSize], [(UIFont *)value fontName]];
    if ([value isKindOfClass:[UIColor class]])
        return color_text(value);
    if ([value isKindOfClass:[NSParagraphStyle class]])
        return style_text(value);
    if ([value isKindOfClass:[NSURL class]])
        return [(NSURL *)value absoluteString];
    if ([value isKindOfClass:[NSTextAttachment class]])
        return @"attachment";
    return [value description];
}

static NSString *runs_text(NSAttributedString *text, NSArray *keys)
{
    if (!text)
        return @"nil";
    NSMutableArray *lines = [NSMutableArray array];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSString *key in keys) {
            id value = attributes[key];
            if (value)
                [parts addObject:[NSString stringWithFormat:@"%@=%@", [key stringByReplacingOccurrencesOfString:@"NS" withString:@""], attribute_text(key, value)]];
        }
        [lines addObject:[NSString stringWithFormat:@"%@ {%@}", [[text.string substringWithRange:range] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"], [parts componentsJoinedByString:@"; "]]];
    }];
    return [lines componentsJoinedByString:@"\n"];
}

static NSString *members(NSCharacterSet *set)
{
    NSMutableString *text = [NSMutableString string];
    for (unichar c = 0; c < 0x800; c++)
        if ([set characterIsMember:c])
            [text appendFormat:@"U+%04X ", c];
    return text;
}

static NSString *options_text(NSDictionary *options)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in [options.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id value = options[key];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, [value isKindOfClass:[NSCharacterSet class]] ? members(value) : value]];
    }
    return [parts componentsJoinedByString:@"; "];
}

void textkit7_run(TextKit7Recorder record)
{
    NSDictionary *constants = @{
        @"NSTextEffectAttributeName": NSTextEffectAttributeName, @"NSAttachmentAttributeName": NSAttachmentAttributeName, @"NSLinkAttributeName": NSLinkAttributeName,
        @"NSBaselineOffsetAttributeName": NSBaselineOffsetAttributeName, @"NSUnderlineColorAttributeName": NSUnderlineColorAttributeName, @"NSStrikethroughColorAttributeName": NSStrikethroughColorAttributeName,
        @"NSObliquenessAttributeName": NSObliquenessAttributeName, @"NSExpansionAttributeName": NSExpansionAttributeName, @"NSWritingDirectionAttributeName": NSWritingDirectionAttributeName,
        @"NSTextEffectLetterpressStyle": NSTextEffectLetterpressStyle, @"NSTabColumnTerminatorsAttributeName": NSTabColumnTerminatorsAttributeName,
        @"NSPlainTextDocumentType": NSPlainTextDocumentType, @"NSRTFTextDocumentType": NSRTFTextDocumentType, @"NSRTFDTextDocumentType": NSRTFDTextDocumentType, @"NSHTMLTextDocumentType": NSHTMLTextDocumentType,
        @"NSDocumentTypeDocumentAttribute": NSDocumentTypeDocumentAttribute, @"NSCharacterEncodingDocumentAttribute": NSCharacterEncodingDocumentAttribute, @"NSDefaultAttributesDocumentAttribute": NSDefaultAttributesDocumentAttribute,
        @"NSPaperSizeDocumentAttribute": NSPaperSizeDocumentAttribute, @"NSPaperMarginDocumentAttribute": NSPaperMarginDocumentAttribute, @"NSViewSizeDocumentAttribute": NSViewSizeDocumentAttribute,
        @"NSViewZoomDocumentAttribute": NSViewZoomDocumentAttribute, @"NSViewModeDocumentAttribute": NSViewModeDocumentAttribute, @"NSReadOnlyDocumentAttribute": NSReadOnlyDocumentAttribute,
        @"NSBackgroundColorDocumentAttribute": NSBackgroundColorDocumentAttribute, @"NSHyphenationFactorDocumentAttribute": NSHyphenationFactorDocumentAttribute, @"NSDefaultTabIntervalDocumentAttribute": NSDefaultTabIntervalDocumentAttribute,
        @"NSTextLayoutSectionsAttribute": NSTextLayoutSectionsAttribute, @"NSTextLayoutSectionOrientation": NSTextLayoutSectionOrientation, @"NSTextLayoutSectionRange": NSTextLayoutSectionRange,
        @"NSDocumentTypeDocumentOption": NSDocumentTypeDocumentOption, @"NSDefaultAttributesDocumentOption": NSDefaultAttributesDocumentOption, @"NSCharacterEncodingDocumentOption": NSCharacterEncodingDocumentOption,
    };
    for (NSString *name in constants)
        record([@"constant." stringByAppendingString:name], constants[name]);

    Class tabClass = [NSTextTab class];
    record(@"tab.class", [NSString stringWithFormat:@"%@ named=%d", NSStringFromClass(tabClass), tabClass == NSClassFromString(@"NSTextTab")]);
    NSTextTab *left = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:50 options:nil];
    record(@"tab.made", [NSString stringWithFormat:@"%d", left != nil]);
    for (NSInteger alignment = 0; alignment < 5; alignment++) {
        NSTextTab *tab = [[NSTextTab alloc] initWithTextAlignment:(NSTextAlignment)alignment location:72.5 options:@{}];
        record([NSString stringWithFormat:@"tab.align.%ld", (long)alignment], [NSString stringWithFormat:@"alignment=%ld location=%.1f options=[%@]", (long)tab.alignment, tab.location, options_text(tab.options)]);
    }
    NSTextTab *digits = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:100 options:@{NSTabColumnTerminatorsAttributeName: [NSCharacterSet characterSetWithCharactersInString:@".,"]}];
    record(@"tab.options", options_text(digits.options));
    NSTextTab *same = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:50 options:nil];
    NSTextTab *empty = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:50 options:@{}];
    record(@"tab.equal.options", [NSString stringWithFormat:@"nil-empty=%d empty-empty=%d", [left isEqual:empty], [empty isEqual:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:50 options:@{}]]]);
    NSTextTab *other = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter location:50 options:nil];
    NSTextTab *further = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:51 options:nil];
    record(@"tab.equal", [NSString stringWithFormat:@"same=%d hash=%d other=%d further=%d copy=%d self=%d nil=%d", [left isEqual:same], left.hash == same.hash, [left isEqual:other], [left isEqual:further], [left copy] == left, [left isEqual:left], [left isEqual:nil]]);
    record(@"tab.kind", [NSString stringWithFormat:@"%d %d", [left isKindOfClass:[NSTextTab class]], [left isMemberOfClass:[NSTextTab class]]]);
    for (NSString *identifier in @[@"en_US", @"de_DE", @"fr_FR", @"ar_SA", @"ru_RU", @"ja_JP", @"de_CH"])
        record([@"tab.terminators." stringByAppendingString:identifier], members([NSTextTab columnTerminatorsForLocale:[NSLocale localeWithLocaleIdentifier:identifier]]));
    record(@"tab.terminators.nil", members([NSTextTab columnTerminatorsForLocale:nil]));

    NSParagraphStyle *plain = [NSParagraphStyle defaultParagraphStyle];
    record(@"style.default", style_text(plain));
    NSMutableParagraphStyle *style = [plain mutableCopy];
    style.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:50 options:nil], [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight location:20 options:nil]];
    style.defaultTabInterval = 33;
    record(@"style.tabs", style_text(style));
    NSParagraphStyle *copy = [style copy];
    record(@"style.copy", [NSString stringWithFormat:@"%@ equal=%d", style_text(copy), [copy isEqual:style]]);
    style.tabStops = nil;
    record(@"style.cleared", style_text(style));
    NSAttributedString *marked = [[NSAttributedString alloc] initWithString:@"tab" attributes:@{NSUnderlineColorAttributeName: [UIColor redColor], NSStrikethroughColorAttributeName: [UIColor blueColor], NSObliquenessAttributeName: @0.25, NSExpansionAttributeName: @0.5, NSWritingDirectionAttributeName: @[@0], NSTextEffectAttributeName: NSTextEffectLetterpressStyle}];
    NSDictionary *held = [marked attributesAtIndex:0 effectiveRange:NULL];
    record(@"attributes.kept", [NSString stringWithFormat:@"%lu %@ %@ %@", (unsigned long)held.count, held[NSObliquenessAttributeName], held[NSExpansionAttributeName], held[NSTextEffectAttributeName]]);

    NSArray *keys = @[NSFontAttributeName, NSForegroundColorAttributeName, NSLinkAttributeName, NSUnderlineStyleAttributeName, NSStrikethroughStyleAttributeName, NSBackgroundColorAttributeName, NSBaselineOffsetAttributeName, NSParagraphStyleAttributeName];
    NSDictionary *snippets = @{
        @"bold": @"<b>bold</b> plain <i>italic</i>",
        @"link": @"go <a href=\"http://example.com/x?y=1\">there</a> now",
        @"paragraphs": @"<p>one</p><p>two</p>",
        @"break": @"line<br>break",
        @"underline": @"<u>under</u> <s>struck</s>",
        @"entities": @"a &amp; b &lt; c &#65;",
        @"list": @"<ul><li>a</li><li>b</li></ul>",
        @"heading": @"<h1>Title</h1>text",
        @"span": @"<span style=\"color:#ff0000;font-size:20px\">red</span>",
        @"font": @"<font color=\"blue\" size=\"5\">big</font>",
        @"sub": @"H<sub>2</sub>O x<sup>2</sup>",
    };
    for (NSString *name in [snippets.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSError *error = nil;
        NSDictionary *attributes = nil;
        NSAttributedString *text = [[NSAttributedString alloc] initWithData:[snippets[name] dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} documentAttributes:&attributes error:&error];
        record([@"html." stringByAppendingString:name], runs_text(text, keys));
        if ([name isEqualToString:@"bold"])
            record(@"html.documentAttributes", [NSString stringWithFormat:@"type=%@ error=%d", attributes[NSDocumentTypeDocumentAttribute], error != nil]);
    }
    NSError *error = nil;
    NSAttributedString *rtf = [[NSAttributedString alloc] initWithData:[@"{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}}Hello {\\b bold} {\\i it} \\ul u\\ulnone  end\\par}" dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType} documentAttributes:NULL error:&error];
    record(@"rtf.import", runs_text(rtf, keys));
    NSAttributedString *plainText = [[NSAttributedString alloc] initWithData:[@"plain text\nline two" dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute: NSPlainTextDocumentType, NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} documentAttributes:NULL error:&error];
    record(@"plain.import", runs_text(plainText, @[NSForegroundColorAttributeName]));
}
