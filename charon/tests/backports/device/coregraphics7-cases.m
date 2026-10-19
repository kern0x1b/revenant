#import <CoreGraphics/CoreGraphics.h>
#import "coregraphics7-cases.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static void collect(void *info, const CGPathElement *element)
{
    NSMutableString *digest = (__bridge NSMutableString *)info;
    int count = element->type == kCGPathElementMoveToPoint || element->type == kCGPathElementAddLineToPoint ? 1 : element->type == kCGPathElementAddQuadCurveToPoint ? 2 : element->type == kCGPathElementAddCurveToPoint ? 3 : 0;
    [digest appendFormat:@"%d", (int)element->type];
    for (int i = 0; i < count; i++)
        [digest appendFormat:@"(%.4f,%.4f)", element->points[i].x, element->points[i].y];
    [digest appendString:@";"];
}

static NSString *digest_of(CGPathRef path)
{
    NSMutableString *digest = [NSMutableString string];
    CGPathApply(path, (__bridge void *)digest, collect);
    return digest;
}

static NSString *colour_digest(CGColorRef color)
{
    NSMutableString *digest = [NSMutableString string];
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    for (size_t i = 0; i < count; i++)
        [digest appendFormat:@"%.4f,", components[i]];
    [digest appendFormat:@"%zu %d", count, (int)CGColorSpaceGetModel(CGColorGetColorSpace(color))];
    return digest;
}

void charon_cg7_cases(void (^emit)(NSString *name, NSString *value))
{
    CGRect rects[] = {{{0, 0}, {100, 50}}, {{10, 20}, {30, 30}}, {{-5, -5}, {40, 10}}, {{100, 100}, {-60, -40}}, {{3.5, 7.25}, {12.5, 80}}};
    CGSize corners[] = {{0, 0}, {5, 5}, {25, 10}, {50, 25}, {10, 0}, {0, 10}, {1.5, 2.5}};
    CGAffineTransform transforms[] = {CGAffineTransformMakeTranslation(7, -3), CGAffineTransformMakeRotation(0.7), CGAffineTransformMakeScale(2, 0.5), CGAffineTransformConcat(CGAffineTransformMakeRotation(-1.1), CGAffineTransformMakeTranslation(20, 30))};
    for (size_t r = 0; r < sizeof(rects) / sizeof(*rects); r++) {
        for (size_t c = 0; c < sizeof(corners) / sizeof(*corners); c++) {
            if (!(2 * corners[c].width <= CGRectGetWidth(rects[r]) && 2 * corners[c].height <= CGRectGetHeight(rects[r])))
                continue;
            for (int t = -1; t < (int)(sizeof(transforms) / sizeof(*transforms)); t++) {
                const CGAffineTransform *transform = t < 0 ? NULL : &transforms[t];
                CGMutablePathRef added = CGPathCreateMutable();
                CGPathAddRoundedRect(added, transform, rects[r], corners[c].width, corners[c].height);
                emit([NSString stringWithFormat:@"add %zu %zu %d", r, c, t], digest_of(added));
                CGPathRef created = CGPathCreateWithRoundedRect(rects[r], corners[c].width, corners[c].height, transform);
                emit([NSString stringWithFormat:@"create %zu %zu %d", r, c, t], digest_of(created));
                CGPathRelease(added);
                CGPathRelease(created);
            }
        }
    }
    CGColorRef rgb = CGColorCreateGenericRGB(0.1, 0.2, 0.3, 0.4), gray = CGColorCreateGenericGray(0.6, 0.5), cmyk = CGColorCreateGenericCMYK(0.1, 0.2, 0.3, 0.4, 0.5);
    emit(@"generic rgb", colour_digest(rgb));
    emit(@"generic gray", colour_digest(gray));
    emit(@"generic cmyk", colour_digest(cmyk));
    CGColorRelease(rgb);
    CGColorRelease(gray);
    CGColorRelease(cmyk);
    CFStringRef names[] = {kCGColorWhite, kCGColorBlack, kCGColorClear};
    for (int i = 0; i < 3; i++)
        emit([NSString stringWithFormat:@"constant %d", i], colour_digest(CGColorGetConstantColor(names[i])));
}
