#import <UIKit/UIKit.h>
#import "stringdrawing-cases.h"

static NSString *rect_text(CGRect rect)
{
    return [NSString stringWithFormat:@"%.2f %.2f %.2f %.2f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

static NSString *ink_text(void (^draw)(void))
{
    const size_t width = 240, height = 120;
    uint8_t *pixels = calloc(width * height, 1);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width, space, kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    CGContextSetGrayFillColor(context, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    UIGraphicsPushContext(context);
    draw();
    UIGraphicsPopContext();
    size_t left = width, top = height, right = 0, bottom = 0;
    for (size_t y = 0; y < height; y++)
        for (size_t x = 0; x < width; x++)
            if (pixels[y * width + x] < 128) {
                left = MIN(left, x); right = MAX(right, x); top = MIN(top, y); bottom = MAX(bottom, y);
            }
    CGContextRelease(context);
    free(pixels);
    return right < left ? @"none" : [NSString stringWithFormat:@"%zu %zu %zu %zu", left, top, right + 1, bottom + 1];
}

void stringdrawing_run(StringDrawingRecorder record)
{
    NSDictionary *helvetica = @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14]};
    NSDictionary *times = @{NSFontAttributeName: [UIFont fontWithName:@"TimesNewRomanPSMT" size:20]};
    NSMutableParagraphStyle *centered = [[NSMutableParagraphStyle alloc] init];
    centered.alignment = NSTextAlignmentCenter;
    NSDictionary *styled = @{NSFontAttributeName: [UIFont fontWithName:@"Helvetica" size:14], NSParagraphStyleAttributeName: centered};
    NSDictionary *fonts = @{@"helvetica": helvetica, @"times": times, @"styled": styled};
    NSArray *texts = @[@"Hello", @"Hello world, this is quite a long line of text", @"two\nlines", @"", @" ", @"Ág"];
    for (NSString *fontName in [fonts.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *attributes = fonts[fontName];
        for (NSUInteger index = 0; index < texts.count; index++) {
            NSString *text = texts[index];
            NSString *base = [NSString stringWithFormat:@"%@.%lu", fontName, (unsigned long)index];
            CGSize size = [text sizeWithAttributes:attributes];
            record([base stringByAppendingString:@".size"], [NSString stringWithFormat:@"%.2f %.2f", size.width, size.height]);
            record([base stringByAppendingString:@".bound0"], rect_text([text boundingRectWithSize:CGSizeMake(1000, 1000) options:0 attributes:attributes context:nil]));
            record([base stringByAppendingString:@".boundLine"], rect_text([text boundingRectWithSize:CGSizeMake(1000, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil]));
            record([base stringByAppendingString:@".boundLeading"], rect_text([text boundingRectWithSize:CGSizeMake(1000, 1000) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:attributes context:nil]));
            record([base stringByAppendingString:@".bound100"], rect_text([text boundingRectWithSize:CGSizeMake(100, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil]));
        }
        record([fontName stringByAppendingString:@".drawAtPoint"], ink_text(^{ [@"Hello" drawAtPoint:CGPointMake(10, 10) withAttributes:attributes]; }));
        record([fontName stringByAppendingString:@".drawInRect"], ink_text(^{ [@"Hello world, this is quite a long line of text" drawInRect:CGRectMake(10, 10, 100, 100) withAttributes:attributes]; }));
        record([fontName stringByAppendingString:@".drawWithRect"], ink_text(^{ [@"two\nlines" drawWithRect:CGRectMake(10, 10, 200, 100) options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil]; }));
    }
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    CGRect wrapped = [@"Hello world, this is quite a long line of text" boundingRectWithSize:CGSizeMake(100, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:helvetica context:context];
    record(@"context.total", [NSString stringWithFormat:@"%d %@", context != nil, rect_text(wrapped)]);
    CGRect none = [@"Hello" boundingRectWithSize:CGSizeMake(1000, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:nil context:nil];
    record(@"attributes.nil", [NSString stringWithFormat:@"%d", none.size.width > 0 && none.size.height > 0]);
}
