#import <UIKit/UIKit.h>
#import "textsystem7-cases.h"

static NSString *rect_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.2f %.2f %.2f %.2f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

static NSString *container_text(NSTextContainer *container)
{
    return [NSString stringWithFormat:@"size=%.0f,%.0f padding=%.0f lines=%lu mode=%ld exclusions=%lu width=%d height=%d simple=%d", container.size.width, container.size.height, container.lineFragmentPadding,
            (unsigned long)container.maximumNumberOfLines, (long)container.lineBreakMode, (unsigned long)container.exclusionPaths.count, container.widthTracksTextView, container.heightTracksTextView, container.simpleRectangularTextContainer];
}

static NSString *style_text(NSParagraphStyle *style)
{
    return [NSString stringWithFormat:@"tighten=%d strategy=%ld", style.allowsDefaultTighteningForTruncation, (long)style.lineBreakStrategy];
}

void textsystem7_run(TextSystem7Recorder record)
{
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(100, 200)];
    record(@"container.new", container_text(container));
    record(@"container.init", [NSString stringWithFormat:@"%d", [[NSTextContainer alloc] init].size.width > 1000]);
    container.size = CGSizeMake(120, 240);
    container.exclusionPaths = @[[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 40, 40)]];
    container.widthTracksTextView = YES;
    container.heightTracksTextView = YES;
    container.lineBreakMode = NSLineBreakByTruncatingTail;
    container.maximumNumberOfLines = 3;
    record(@"container.set", container_text(container));
    container.exclusionPaths = nil;
    container.maximumNumberOfLines = 0;
    record(@"container.cleared", container_text(container));
    NSTextContainer *lines = [[NSTextContainer alloc] initWithSize:CGSizeMake(100, 200)];
    CGRect remaining = CGRectZero;
    record(@"container.fragment", rect_text([lines lineFragmentRectForProposedRect:CGRectMake(0, 0, 50, 20) atIndex:0 writingDirection:NSWritingDirectionLeftToRight remainingRect:&remaining]));
    record(@"container.fragmentWide", [NSString stringWithFormat:@"%@ | %@", rect_text([lines lineFragmentRectForProposedRect:CGRectMake(0, 0, 500, 20) atIndex:0 writingDirection:NSWritingDirectionLeftToRight remainingRect:&remaining]), rect_text(remaining)]);

    NSParagraphStyle *plain = [NSParagraphStyle defaultParagraphStyle];
    record(@"style.default", style_text(plain));
    record(@"style.new", style_text([[NSMutableParagraphStyle alloc] init]));
    NSMutableParagraphStyle *style = [plain mutableCopy];
    style.allowsDefaultTighteningForTruncation = NO;
    style.lineBreakStrategy = NSLineBreakStrategyPushOut;
    NSParagraphStyle *copy = [style copy];
    NSMutableParagraphStyle *mutableCopy = [style mutableCopy];
    record(@"style.set", [NSString stringWithFormat:@"%@ | copy %@ | mutable %@ | equalDefault=%d equalCopy=%d", style_text(style), style_text(copy), style_text(mutableCopy), [plain isEqual:style], [style isEqual:copy]]);

    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    record(@"attachment.new", [NSString stringWithFormat:@"%@ %d %d %d", rect_text(attachment.bounds), attachment.contents != nil, attachment.fileType != nil, attachment.image != nil]);
    attachment.bounds = CGRectMake(1, 2, 30, 40);
    record(@"attachment.bounds", rect_text(attachment.bounds));
    NSTextAttachment *data = [[NSTextAttachment alloc] initWithData:[@"hello" dataUsingEncoding:NSUTF8StringEncoding] ofType:@"public.plain-text"];
    record(@"attachment.data", [NSString stringWithFormat:@"%@ %@", [[NSString alloc] initWithData:data.contents encoding:NSUTF8StringEncoding], data.fileType]);
    NSTextAttachment *wrapped = [[NSTextAttachment alloc] init];
    wrapped.fileWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:[@"wrapped" dataUsingEncoding:NSUTF8StringEncoding]];
    record(@"attachment.wrapper", [[NSString alloc] initWithData:wrapped.contents encoding:NSUTF8StringEncoding] ?: @"nil");
    NSTextAttachment *contents = [[NSTextAttachment alloc] init];
    contents.contents = [@"set" dataUsingEncoding:NSUTF8StringEncoding];
    contents.fileType = @"public.text";
    record(@"attachment.contents", [NSString stringWithFormat:@"%@ %@", [[NSString alloc] initWithData:contents.contents encoding:NSUTF8StringEncoding], contents.fileType]);

    NSDictionary *attributes = @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14]};
    NSTextStorage *storage = [[NSTextStorage alloc] initWithString:@"Hello world, this is a long text\nthat wraps over lines\tand a tab" attributes:attributes];
    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    NSTextContainer *narrow = [[NSTextContainer alloc] initWithSize:CGSizeMake(100, 10000)];
    [manager addTextContainer:narrow];
    [storage addLayoutManager:manager];
    record(@"layout.used", rect_text([manager usedRectForTextContainer:narrow]));
    record(@"layout.glyphs", [NSString stringWithFormat:@"%lu", (unsigned long)manager.numberOfGlyphs]);
    NSMutableArray *fragments = [NSMutableArray array];
    [manager enumerateLineFragmentsForGlyphRange:NSMakeRange(0, manager.numberOfGlyphs) usingBlock:^(CGRect rect, CGRect used, NSTextContainer *inContainer, NSRange glyphs, BOOL *stop) {
        [fragments addObject:[NSString stringWithFormat:@"%@ | %@ | %d | %lu,%lu", rect_text(rect), rect_text(used), inContainer == narrow, (unsigned long)glyphs.location, (unsigned long)glyphs.length]];
    }];
    record(@"layout.fragments", [fragments componentsJoinedByString:@"\n"]);
    __block NSUInteger stops = 0;
    [manager enumerateLineFragmentsForGlyphRange:NSMakeRange(0, manager.numberOfGlyphs) usingBlock:^(CGRect rect, CGRect used, NSTextContainer *inContainer, NSRange glyphs, BOOL *stop) {
        stops++;
        *stop = YES;
    }];
    record(@"layout.stop", [NSString stringWithFormat:@"%lu", (unsigned long)stops]);
    NSMutableArray *enclosing = [NSMutableArray array];
    [manager enumerateEnclosingRectsForGlyphRange:NSMakeRange(2, 30) withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0) inTextContainer:narrow usingBlock:^(CGRect rect, BOOL *stop) {
        [enclosing addObject:rect_text(rect)];
    }];
    record(@"layout.enclosing", [enclosing componentsJoinedByString:@"\n"]);
    BOOL valid = NO;
    CGGlyph glyph = [manager CGGlyphAtIndex:1 isValidIndex:&valid];
    record(@"layout.glyph", [NSString stringWithFormat:@"%d %d %d", glyph != 0, valid, [manager CGGlyphAtIndex:1] == glyph]);
    NSMutableArray *properties = [NSMutableArray array];
    for (NSUInteger index = 0; index < manager.numberOfGlyphs; index++) {
        NSGlyphProperty property = [manager propertyForGlyphAtIndex:index];
        if (property)
            [properties addObject:[NSString stringWithFormat:@"%lu:%ld", (unsigned long)index, (long)property]];
    }
    record(@"layout.properties", [properties componentsJoinedByString:@" "]);
    CGGlyph glyphs[8];
    NSGlyphProperty flags[8];
    NSUInteger characters[8];
    [manager getGlyphsInRange:NSMakeRange(30, 4) glyphs:glyphs properties:flags characterIndexes:characters bidiLevels:NULL];
    record(@"layout.getGlyphs", [NSString stringWithFormat:@"%lu %lu %ld %ld", (unsigned long)characters[0], (unsigned long)characters[3], (long)flags[0], (long)flags[3]]);
    record(@"layout.truncated", [NSString stringWithFormat:@"%d", [manager truncatedGlyphRangeInLineFragmentForGlyphAtIndex:0].location == NSNotFound]);
    NSTextStorage *fresh = [[NSTextStorage alloc] initWithString:@"one two three four five six seven" attributes:attributes];
    NSLayoutManager *lazy = [[NSLayoutManager alloc] init];
    NSTextContainer *lazyContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(80, 10000)];
    [lazy addTextContainer:lazyContainer];
    [fresh addLayoutManager:lazy];
    CGRect first = [lazy usedRectForTextContainer:lazyContainer];
    record(@"layout.lazy", [NSString stringWithFormat:@"%d", first.size.width > 0 && first.size.height > 0]);
    lazy.limitsLayoutForSuspiciousContents = YES;
    record(@"layout.limits", [NSString stringWithFormat:@"%d", lazy.limitsLayoutForSuspiciousContents]);
}
