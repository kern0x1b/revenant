#import <UIKit/UIKit.h>
#import "exclusion-cases.h"

static NSString *layout(NSArray<UIBezierPath *> *paths, CGSize size, NSString *text)
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [UIFont fontWithName:@"Courier" size:14]}];
    NSTextStorage *storage = [[NSTextStorage alloc] initWithAttributedString:string];
    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:size];
    container.exclusionPaths = paths;
    [manager addTextContainer:container];
    [storage addLayoutManager:manager];
    [manager ensureLayoutForTextContainer:container];
    NSMutableArray *lines = [NSMutableArray array];
    NSRange glyphs = [manager glyphRangeForTextContainer:container];
    [manager enumerateLineFragmentsForGlyphRange:glyphs usingBlock:^(CGRect rect, CGRect used, NSTextContainer *inContainer, NSRange range, BOOL *stop) {
        [lines addObject:[NSString stringWithFormat:@"%lu+%lu @ %.1f,%.1f %.1fx%.1f used %.1f,%.1f %.1fx%.1f", (unsigned long)range.location, (unsigned long)range.length, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height, used.origin.x, used.origin.y, used.size.width, used.size.height]];
    }];
    return [lines componentsJoinedByString:@" ; "];
}

void exclusion_run(ExclusionRecorder record)
{
    NSString *text = @"The quick brown fox jumps over the lazy dog and keeps running through the tall grass until the evening comes and the light fades away over the quiet hills beyond the river";
    CGSize size = CGSizeMake(200, 400);
    record(@"none", layout(nil, size, text));
    record(@"top right", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(120, 0, 80, 60)]], size, text));
    record(@"top left", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 80, 60)]], size, text));
    record(@"middle", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(70, 20, 60, 50)]], size, text));
    record(@"oval", layout(@[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 100, 100)]], size, text));
    record(@"two", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 50, 40)], [UIBezierPath bezierPathWithRect:CGRectMake(150, 30, 50, 40)]], size, text));
    record(@"band", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(0, 30, 200, 40)]], size, text));
    record(@"beyond", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(150, 0, 150, 50)]], size, text));
    record(@"triangle", layout(@[({ UIBezierPath *path = [UIBezierPath bezierPath]; [path moveToPoint:CGPointMake(200, 0)]; [path addLineToPoint:CGPointMake(200, 90)]; [path addLineToPoint:CGPointMake(100, 0)]; [path closePath]; path; })], size, text));
    record(@"narrow gap", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 195, 40)]], size, text));
    record(@"outside", layout(@[[UIBezierPath bezierPathWithRect:CGRectMake(0, 300, 200, 50)]], size, text));
}
