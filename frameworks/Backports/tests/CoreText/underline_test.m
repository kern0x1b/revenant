#import "../Foundation/check.h"
#import <CoreText/CoreText.h>
#import "revenant_underline.h"

static RevenantUnderlineBars bars(int style, CGFloat position, CGFloat thickness, CGFloat x, CGFloat width, CGFloat offset)
{
    if (revenant_negative) {
        offset = 0;
        style = style & 0xFF ? 1 : 0;
    }
    return revenant_underline_bars(style, position, thickness, x, width, offset);
}

static NSString *rect(CGRect value)
{
    return [NSString stringWithFormat:@"{%.4f %.4f %.4f %.4f}", value.origin.x, value.origin.y, value.size.width, value.size.height];
}

static NSString *describe(RevenantUnderlineBars value)
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"%d", value.count];
    for (int index = 0; index < value.count; index++)
        [text appendFormat:@" %@", rect(value.bars[index])];
    return text;
}

static void expectBars(const char *name, RevenantUnderlineBars value, NSString *expected)
{
    NSString *seen = describe(value);
    revenant_check([seen isEqualToString:expected], name, [NSString stringWithFormat:@"%@, expected %@", seen, expected]);
}

enum { SIDE = 40 };

static unsigned char *pixels(CGContextRef *context)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char *data = calloc(SIDE * SIDE * 4, 1);
    *context = CGBitmapContextCreate(data, SIDE, SIDE, 8, SIDE * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    return data;
}

static const unsigned char *pixel(const unsigned char *data, int x, int up)
{
    return data + ((SIDE - 1 - up) * SIDE + x) * 4;
}

static int inked(const unsigned char *data)
{
    int count = 0;
    for (int index = 3; index < SIDE * SIDE * 4; index += 4)
        count += data[index] != 0;
    return count;
}

static void drawnBars(RevenantUnderlineBars value, CGFloat baseline, CGFloat red, CGAffineTransform matrix, BOOL flipped, unsigned char **keep)
{
    CGContextRef context;
    unsigned char *data = pixels(&context);
    if (flipped) {
        CGContextTranslateCTM(context, 0, SIDE);
        CGContextScaleCTM(context, 1, -1);
    }
    CGContextSetTextMatrix(context, matrix);
    CGContextSetTextPosition(context, 4, flipped ? SIDE - baseline : baseline);
    CGFloat components[4] = {red, 0, 0, 1};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    revenant_underline_fill(context, value, color);
    CGColorRelease(color);
    CGContextRelease(context);
    *keep = data;
}

static void unfixedFill(CGContextRef context, RevenantUnderlineBars bars, CGColorRef color)
{
    CGAffineTransform text = CGContextGetTextMatrix(context);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, floor(text.ty) - text.ty);
    CGContextConcatCTM(context, text);
    CGContextSetFillColorWithColor(context, color);
    for (int index = 0; index < bars.count; index++)
        CGContextFillRect(context, bars.bars[index]);
    CGContextRestoreGState(context);
}

static unsigned char *drawnAt(RevenantUnderlineBars value, CGFloat x, CGFloat y, CGAffineTransform matrix, BOOL flipped)
{
    CGContextRef context;
    unsigned char *data = pixels(&context);
    if (flipped) {
        CGContextTranslateCTM(context, 0, SIDE);
        CGContextScaleCTM(context, 1, -1);
    }
    CGContextSetTextMatrix(context, matrix);
    CGContextSetTextPosition(context, x, y);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[4] = {0, 0, 0, 1};
    CGColorRef color = CGColorCreate(space, components);
    CGColorSpaceRelease(space);
    if (revenant_negative)
        unfixedFill(context, value, color);
    else
        revenant_underline_fill(context, value, color);
    CGColorRelease(color);
    CGContextRelease(context);
    return data;
}

static double columnCentre(const unsigned char *data, int x, double *total)
{
    double sum = 0, weighted = 0;
    for (int up = 0; up < SIDE; up++) {
        double coverage = pixel(data, x, up)[3] / 255.0;
        sum += coverage;
        weighted += coverage * (up + 0.5);
    }
    *total = sum;
    return sum > 0 ? weighted / sum : -1;
}

static int near(int value, int expected)
{
    return abs(value - expected) <= 2;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    expectBars("a single underline of a 17 pt font is one bar on the rounded position, as wide as the run rounded up, one pixel thick",
               bars(1, -2.125, 0.85, 4, 36.822, 0), @"1 {4.0000 -2.5000 37.0000 1.0000}");
    expectBars("a 40 pt font keeps its thickness and its whole-pixel position",
               bars(1, -5, 2, 4, 86.64, 0), @"1 {4.0000 -6.0000 87.0000 2.0000}");
    expectBars("a thickness above a pixel is rounded up (1.2 points is two pixels)", bars(1, -3, 1.2, 4, 51.984, 0), @"1 {4.0000 -4.0000 52.0000 2.0000}");
    expectBars("a position on half a pixel is rounded away from the baseline", bars(1, -1.5, 0.6, 4, 25.992, 0), @"1 {4.0000 -2.5000 26.0000 1.0000}");
    expectBars("a width that is a whole number of pixels and a bit more takes one pixel more", bars(1, -1.5, 0.6, 4, 18.0029, 0), @"1 {4.0000 -2.5000 19.0000 1.0000}");
    expectBars("a thick underline is drawn as the single one, as the system does on iOS 6", bars(2, -2.125, 0.85, 4, 36.822, 0), @"1 {4.0000 -2.5000 37.0000 1.0000}");
    expectBars("a dotted pattern is drawn solid", bars(0x101, -2.125, 0.85, 4, 36.822, 0), @"1 {4.0000 -2.5000 37.0000 1.0000}");
    expectBars("a double underline of 40 pt is two bars three quarters as thick, a pixel and a half apart",
               bars(9, -5, 2, 4, 86.64, 0), @"2 {4.0000 -5.2500 87.0000 1.5000} {4.0000 -7.2500 87.0000 1.5000}");
    expectBars("a double underline of 17 pt keeps each bar inside one pixel row",
               bars(9, -2.125, 0.85, 4, 36.822, 0), @"2 {4.0000 -1.8203 37.0000 0.6406} {4.0000 -3.8203 37.0000 0.6406}");
    expectBars("a double underline of 24 pt takes each bar's thickness to 1/64 of a pixel, as the system's fixed point does (0.9 is 58/64)", bars(9, -3, 1.2, 4, 40, 0),
               @"2 {4.0000 -2.9531 40.0000 0.9062} {4.0000 -4.9531 40.0000 0.9062}");
    expectBars("the stretch of a run starts where the run does and is as wide as the run rounded up",
               bars(1, -2.125, 0.85, 16.274, 12.274, 0), @"1 {16.2740 -2.5000 13.0000 1.0000}");
    expectBars("a run without width has no underline", bars(1, -2.125, 0.85, 4, 0, 0), @"0");
    expectBars("a style of none has no underline", bars(0, -2.125, 0.85, 4, 30, 0), @"0");
    expectBars("a lowered run takes its underline down by the offset", bars(1, -2.125, 0.85, 4, 36.822, -4), @"1 {4.0000 -6.5000 37.0000 1.0000}");
    expectBars("a raised run takes its underline up by the offset", bars(1, -5, 2, 4, 86.64, 2), @"1 {4.0000 -4.0000 87.0000 2.0000}");
    expectBars("a raised run's underline stops with its centre on the baseline", bars(1, -5, 2, 4, 86.64, 12), @"1 {4.0000 -1.0000 87.0000 2.0000}");
    expectBars("a double underline of a lowered run moves as a whole", bars(9, -5, 2, 4, 86.64, -3), @"2 {4.0000 -8.2500 87.0000 1.5000} {4.0000 -10.2500 87.0000 1.5000}");

    unsigned char *data = NULL;
    CGAffineTransform identity = CGAffineTransformIdentity;
    RevenantUnderlineBars single = revenant_underline_bars(1, -2.125, 0.85, 0, 20, 0);
    drawnBars(single, revenant_negative ? 15 : 14.75, revenant_negative ? 0 : 1, identity, NO, &data);
    revenant_check(near(pixel(data, 10, 12)[3], 127) && near(pixel(data, 10, 11)[3], 127) && pixel(data, 10, 13)[3] == 0 && pixel(data, 10, 10)[3] == 0,
                   "the underline is snapped to the whole pixel row of the text position, not rounded with it, and covers two half rows",
                   [NSString stringWithFormat:@"%d %d %d %d", pixel(data, 10, 13)[3], pixel(data, 10, 12)[3], pixel(data, 10, 11)[3], pixel(data, 10, 10)[3]]);
    revenant_check(near(pixel(data, 10, 12)[0], 127) && pixel(data, 10, 12)[1] == 0 && pixel(data, 10, 12)[2] == 0, "the underline is drawn in the colour it is given",
                   [NSString stringWithFormat:@"%d,%d,%d", pixel(data, 10, 12)[0], pixel(data, 10, 12)[1], pixel(data, 10, 12)[2]]);
    revenant_check(inked(data) == 40, "the underline covers its stretch and nothing else", [NSString stringWithFormat:@"%d pixels", inked(data)]);
    free(data);

    RevenantUnderlineBars partial = revenant_underline_bars(1, -2.125, 0.85, revenant_negative ? 13.5 : 12.274, 12.274, 0);
    drawnBars(partial, 14, 0, identity, NO, &data);
    revenant_check(near(pixel(data, 16, 12)[3], 127 * 0.726) && near(pixel(data, 20, 12)[3], 127) && near(pixel(data, 29, 12)[3], 127 * 0.274 + 0.5) && pixel(data, 15, 12)[3] == 0 && pixel(data, 30, 12)[3] == 0,
                   "the stretch of a run starts at the run's own position inside the pixel, and is as wide as the run rounded up",
                   [NSString stringWithFormat:@"%d %d %d", pixel(data, 16, 12)[3], pixel(data, 20, 12)[3], pixel(data, 29, 12)[3]]);
    free(data);

    RevenantUnderlineBars line = revenant_underline_bars(1, -2.125, 0.85, 0, 30, 0);
    CGAffineTransform flip = CGAffineTransformMakeScale(1, -1);
    double base, moved, total;
    data = drawnAt(line, 4, 14, flip, YES);
    base = columnCentre(data, 10, &total);
    free(data);
    data = drawnAt(line, 4, 14.3, flip, YES);
    moved = columnCentre(data, 10, &total);
    free(data);
    revenant_check(fabs((moved - base) + 0.6) < 0.05, "in a flipped context a text position moved down by 0.3 takes the underline down by 0.6, as the system's shift is made through the text matrix",
                   [NSString stringWithFormat:@"moved %.3f of %.3f rows", moved - base, 1.0]);
    data = drawnAt(line, 4, 14, CGAffineTransformIdentity, NO);
    base = columnCentre(data, 10, &total);
    free(data);
    data = drawnAt(line, 4, 14.3, CGAffineTransformIdentity, NO);
    moved = columnCentre(data, 10, &total);
    free(data);
    revenant_check(fabs(moved - base) < 0.05, "in an upright context a text position moved by 0.3 leaves the underline where it was", [NSString stringWithFormat:@"moved %.3f", moved - base]);
    CGAffineTransform turned = CGAffineTransformMake(1.25 * 0.98877, 1.25 * 0.14944, -1.25 * 0.14944, 1.25 * 0.98877, 0, 0);
    data = drawnAt(line, 4, 10, turned, NO);
    columnCentre(data, 20, &total);
    free(data);
    revenant_check(fabs(total - 1.0 / 0.98877) < 0.03, "a text matrix that scales by 1.25 and turns does not thicken the underline: one pixel across the bar",
                   [NSString stringWithFormat:@"%.4f rows of ink in a column, expected %.4f", total, 1.0 / 0.98877]);

    return revenant_finish();
}
