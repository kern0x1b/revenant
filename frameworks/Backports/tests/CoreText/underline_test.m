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

enum { WIDE = 200, TALL = 40 };

static unsigned char *wideDraw(RevenantUnderlineBars value, int kind, CGFloat x, CGFloat y)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char *data = calloc(WIDE * TALL * 4, 1);
    CGContextRef context = CGBitmapContextCreate(data, WIDE, TALL, 8, WIDE * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGAffineTransform text = CGAffineTransformIdentity;
    if (kind == 1 || kind == 4 || kind == 9) {
        CGFloat scale = kind == 1 ? 1 : kind == 4 ? 2 : 1.5;
        CGContextTranslateCTM(context, 0, TALL);
        CGContextScaleCTM(context, scale, -scale);
        text = CGAffineTransformMakeScale(1, -1);
    } else if (kind == 3 || kind == 8) {
        CGContextScaleCTM(context, 2, 2);
    } else if (kind == 5) {
        CGContextScaleCTM(context, 3, 3);
    } else if (kind == 6) {
        CGContextScaleCTM(context, 1.5, 1.5);
    }
    if (kind == 7 || kind == 8)
        text = CGAffineTransformMakeScale(1.25, 1.25);
    CGContextSetTextMatrix(context, text);
    CGContextSetTextPosition(context, x, y);
    CGFloat components[4] = {0, 0, 0, 1};
    CGColorRef color = CGColorCreate(space, components);
    revenant_underline_fill(context, value, color);
    CGColorRelease(color);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

static int strongestRow(const unsigned char *data)
{
    int best = -1;
    unsigned bestSum = 0;
    for (int row = 0; row < TALL; row++) {
        unsigned sum = 0;
        for (int x = 0; x < WIDE; x++)
            sum += data[(row * WIDE + x) * 4 + 3];
        if (sum > bestSum) {
            bestSum = sum;
            best = row;
        }
    }
    return best;
}

static NSString *onRuns(const unsigned char *data, int row, int count)
{
    NSMutableString *text = [NSMutableString string];
    int x = 0, made = 0;
    while (x < WIDE && made < count) {
        if (data[(row * WIDE + x) * 4 + 3] < 8) {
            x++;
            continue;
        }
        int start = x;
        while (x < WIDE && data[(row * WIDE + x) * 4 + 3] >= 8)
            x++;
        [text appendFormat:@"%@[%d,%d)", made ? @" " : @"", start, x];
        made++;
    }
    return text;
}

static NSString *alphaRuns(const unsigned char *data, int row, int count)
{
    NSMutableString *text = [NSMutableString string];
    int x = 0, made = 0;
    while (x < WIDE && made < count) {
        unsigned alpha = data[(row * WIDE + x) * 4 + 3];
        int start = x;
        while (x < WIDE && abs((int)data[(row * WIDE + x) * 4 + 3] - (int)alpha) <= 3)
            x++;
        if (alpha != 0 || (start > 0 && x < WIDE)) {
            [text appendFormat:@"%@%u@%d+%d", made ? @" " : @"", alpha, start, x - start];
            made++;
        }
    }
    return text;
}

static BOOL alphaRunsMatch(NSString *seen, NSString *expected)
{
    NSArray *a = [seen componentsSeparatedByString:@" "], *b = [expected componentsSeparatedByString:@" "];
    if (a.count != b.count)
        return NO;
    for (NSUInteger index = 0; index < a.count; index++) {
        int alphaA, startA, lengthA, alphaB, startB, lengthB;
        if (sscanf([a[index] UTF8String], "%d@%d+%d", &alphaA, &startA, &lengthA) != 3 || sscanf([b[index] UTF8String], "%d@%d+%d", &alphaB, &startB, &lengthB) != 3)
            return NO;
        if (abs(alphaA - alphaB) > 3 || startA != startB || lengthA != lengthB)
            return NO;
    }
    return YES;
}

static void expectRows(const char *name, int style, CGFloat position, CGFloat thickness, NSString *expected)
{
    RevenantUnderlineBars value = bars(style, position, thickness, 0, 30, 0);
    unsigned char *data = wideDraw(value, 0, 4, 30);
    NSMutableString *seen = [NSMutableString string];
    for (int up = TALL - 1; up >= 0; up--) {
        int alpha = data[((TALL - 1 - up) * WIDE + 10) * 4 + 3];
        if (alpha > 0)
            [seen appendFormat:@"%@y%d:%d", seen.length ? @" " : @"", up, alpha];
    }
    free(data);
    NSArray *a = [seen componentsSeparatedByString:@" "], *b = [expected componentsSeparatedByString:@" "];
    BOOL same = a.count == b.count;
    for (NSUInteger index = 0; same && index < a.count; index++) {
        int rowA, alphaA, rowB, alphaB;
        same = sscanf([a[index] UTF8String], "y%d:%d", &rowA, &alphaA) == 2 && sscanf([b[index] UTF8String], "y%d:%d", &rowB, &alphaB) == 2 && rowA == rowB && abs(alphaA - alphaB) <= 3;
    }
    revenant_check(same, name, [NSString stringWithFormat:@"%@, expected %@", seen, expected]);
}

static CGFloat barStart = 0, barWidth = 120;

static void expectOnRuns(const char *name, int style, CGFloat position, CGFloat thickness, int kind, CGFloat baseline, int up, int count, NSString *expected)
{
    RevenantUnderlineBars value = bars(style, position, thickness, barStart, barWidth, 0);
    unsigned char *data = wideDraw(value, kind, 4, baseline);
    NSString *seen = onRuns(data, up < 0 ? strongestRow(data) : TALL - 1 - up, count);
    free(data);
    revenant_check([seen isEqualToString:expected], name, [NSString stringWithFormat:@"%@, expected %@", seen, expected]);
}

static void expectAlphaRuns(const char *name, int style, CGFloat position, CGFloat thickness, CGFloat x, CGFloat baseline, int up, int count, NSString *expected)
{
    RevenantUnderlineBars value = bars(style, position, thickness, barStart, barWidth, 0);
    unsigned char *data = wideDraw(value, 0, x, baseline);
    NSString *seen = alphaRuns(data, up < 0 ? strongestRow(data) : TALL - 1 - up, count);
    free(data);
    revenant_check(alphaRunsMatch(seen, expected), name, [NSString stringWithFormat:@"%@, expected %@", seen, expected]);
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
    expectBars("a dotted pattern keeps the bar of the single underline, the fill cuts it", bars(0x101, -2.125, 0.85, 4, 36.822, 0), @"1 {4.0000 -2.5000 37.0000 1.0000}");
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

    expectAlphaRuns("a dotted 17 pt underline at the text position (4, 14) is three pixels on and three off, the first on-run starting on the bar", 0x101, -2.125, 0.85, 4, 14, -1, 5,
                    @"129@4+3 0@7+3 129@10+3 0@13+3 129@16+3");
    expectAlphaRuns("a dotted 17 pt underline at 4.5 starts half a pixel in and keeps the sub-pixel edges", 0x101, -2.125, 0.85, 4.5, 14, -1, 6, @"64@4+1 129@5+2 64@7+1 0@8+2 64@10+1 129@11+2");
    expectAlphaRuns("a dotted 17 pt underline at 4.25 keeps the sub-pixel edges", 0x101, -2.125, 0.85, 4.25, 14, -1, 6, @"96@4+1 129@5+2 32@7+1 0@8+2 96@10+1 129@11+2");
    expectAlphaRuns("a dotted 60 pt underline runs in units of its three pixel thickness", 0x101, -7.5, 3, 4, 14, -1, 5, @"255@4+3 0@7+9 255@16+9 0@25+9 255@34+9");
    expectAlphaRuns("a dotted 60 pt underline at 4.5", 0x101, -7.5, 3, 4.5, 14, -1, 7, @"128@4+1 255@5+2 128@7+1 0@8+8 128@16+1 255@17+8 128@25+1");
    expectAlphaRuns("a dashed 17 pt underline is ten units on, three off", 0x201, -2.125, 0.85, 4, 14, -1, 4, @"129@5+10 0@15+3 129@18+10 0@28+3");
    expectOnRuns("a dotted 24 pt underline", 0x101, -3, 1.2, 0, 14, -1, 3, @"[5,11) [17,23) [29,35)");
    expectOnRuns("a dotted 40 pt underline", 0x101, -5, 2, 0, 14, -1, 3, @"[7,13) [19,25) [31,37)");
    expectOnRuns("a dashed 24 pt underline", 0x201, -3, 1.2, 0, 14, -1, 3, @"[4,13) [19,39) [45,65)");
    expectOnRuns("a dashed 40 pt underline", 0x201, -5, 2, 0, 14, -1, 3, @"[4,15) [21,41) [47,67)");
    expectOnRuns("a dashed 60 pt underline", 0x201, -7.5, 3, 0, 14, -1, 2, @"[4,28) [37,67)");
    expectOnRuns("a dash-dot 24 pt underline", 0x301, -3, 1.2, 0, 14, -1, 4, @"[4,13) [19,25) [31,51) [57,63)");
    expectOnRuns("a dash-dot-dot 24 pt underline", 0x401, -3, 1.2, 0, 14, -1, 4, @"[4,13) [19,25) [31,37) [43,63)");
    expectOnRuns("a dash-dot 17 pt underline", 0x301, -2.125, 0.85, 0, 14, -1, 4, @"[5,8) [11,21) [24,27) [30,40)");
    expectOnRuns("a dash-dot-dot 17 pt underline", 0x401, -2.125, 0.85, 0, 14, -1, 4, @"[5,8) [11,14) [17,27) [30,33)");
    expectOnRuns("a thick dotted 24 pt underline is dotted in half the unit", 0x102, -3, 1.2, 0, 14, -1, 3, @"[5,8) [11,14) [17,20)");
    expectOnRuns("a thick dotted 40 pt underline", 0x102, -5, 2, 0, 14, -1, 2, @"[7,10) [13,16)");
    expectOnRuns("a thick dashed 24 pt underline", 0x202, -3, 1.2, 0, 14, -1, 3, @"[6,16) [19,29) [32,42)");
    expectOnRuns("a thick dashed 40 pt underline", 0x202, -5, 2, 0, 14, -1, 3, @"[4,5) [8,18) [21,31)");
    expectOnRuns("a thick dotted 60 pt underline", 0x102, -7.5, 3, 0, 14, -1, 3, @"[7,12) [16,21) [25,30)");
    expectOnRuns("a thick dashed 60 pt underline", 0x202, -7.5, 3, 0, 14, -1, 3, @"[4,13) [17,33) [37,52)");

    expectOnRuns("a dotted 17 pt underline at the text position (4, 12) starts the pattern where the bar's centre is: the pattern follows the baseline", 0x101, -2.125, 0.85, 0, 12, -1, 4,
                 @"[6,9) [12,15) [18,21) [24,27)");
    expectOnRuns("a dotted 24 pt underline at (4, 12)", 0x101, -3, 1.2, 0, 12, -1, 4, @"[7,13) [19,25) [31,37) [43,49)");
    expectOnRuns("a dotted 40 pt underline at (4, 12)", 0x101, -5, 2, 0, 12, -1, 4, @"[9,15) [21,27) [33,39) [45,51)");
    expectOnRuns("a dashed 17 pt underline at (4, 12)", 0x201, -2.125, 0.85, 0, 12, -1, 4, @"[7,17) [20,30) [33,43) [46,56)");
    expectOnRuns("a dashed 24 pt underline at (4, 12)", 0x201, -3, 1.2, 0, 12, -1, 4, @"[4,15) [21,41) [47,67) [73,93)");
    expectOnRuns("a dashed 40 pt underline at (4, 12)", 0x201, -5, 2, 0, 12, -1, 4, @"[4,17) [23,43) [49,69) [75,95)");
    expectOnRuns("a flipped context leaves the pattern where the upright one has it", 0x101, -3, 1.2, 1, 12, -1, 4, @"[7,13) [19,25) [31,37) [43,49)");
    expectOnRuns("a flipped context, dashed 17 pt", 0x201, -2.125, 0.85, 1, 12, -1, 4, @"[7,17) [20,30) [33,43) [46,56)");
    expectOnRuns("a flipped context, dashed 40 pt, text position moved by half a pixel", 0x201, -5, 2, 1, 12.5, -1, 4, @"[4,17) [23,43) [49,69) [75,95)");
    expectOnRuns("a context scaled by two (a retina screen): the lengths stay in points, the phase is the device row of the bar, 17 pt dotted", 0x101, -2.125, 0.85, 3, 12, -1, 4,
                 @"[8,10) [16,22) [28,34) [40,46)");
    expectOnRuns("a context scaled by two, 24 pt dotted", 0x101, -3, 1.2, 3, 12, -1, 4, @"[20,32) [44,56) [68,80) [92,104)");
    expectOnRuns("a context scaled by two, 40 pt dotted", 0x101, -5, 2, 3, 12, -1, 4, @"[8,16) [28,40) [52,64) [76,88)");
    expectOnRuns("a context scaled by two and flipped, 24 pt dotted", 0x101, -3, 1.2, 4, 12, -1, 4, @"[20,32) [44,56) [68,80) [92,104)");
    expectOnRuns("a context scaled by two, 17 pt dashed", 0x201, -2.125, 0.85, 3, 12, -1, 4, @"[8,14) [20,40) [46,66) [72,92)");
    expectOnRuns("a context scaled by two, 24 pt dashed", 0x201, -3, 1.2, 3, 12, -1, 4, @"[8,12) [24,64) [76,116) [128,168)");
    expectOnRuns("a context scaled by two, 40 pt dashed", 0x201, -5, 2, 3, 12, -1, 4, @"[8,20) [32,72) [84,124) [136,176)");
    expectOnRuns("a context scaled by three, 17 pt dotted", 0x101, -2.125, 0.85, 5, 12, -1, 4, @"[12,21) [30,39) [48,57) [66,75)");
    expectOnRuns("a context scaled by three, 24 pt dotted", 0x101, -3, 1.2, 5, 12, -1, 4, @"[12,21) [39,57) [75,93) [111,129)");
    expectOnRuns("a context scaled by three, 40 pt dotted", 0x101, -5, 2, 5, 12, -1, 4, @"[21,39) [57,75) [93,111) [129,147)");
    expectOnRuns("a context scaled by three, 17 pt dashed", 0x201, -2.125, 0.85, 5, 12, -1, 4, @"[12,30) [39,69) [78,108) [117,147)");
    expectOnRuns("a context scaled by one and a half, 17 pt dotted", 0x101, -2.125, 0.85, 6, 12, -1, 4, @"[10,15) [19,24) [28,33) [37,42)");
    expectOnRuns("a context scaled by one and a half, 24 pt dotted", 0x101, -3, 1.2, 6, 12, -1, 4, @"[6,13) [21,31) [39,49) [57,67)");
    expectOnRuns("a context scaled by one and a half, 40 pt dotted", 0x101, -5, 2, 6, 12, -1, 4, @"[8,18) [26,36) [44,54) [62,72)");
    expectOnRuns("a context scaled by one and a half, 24 pt dashed", 0x201, -3, 1.2, 6, 12, -1, 4, @"[6,16) [24,55) [63,94) [102,133)");
    expectOnRuns("a context scaled by one and a half and flipped, 24 pt dashed", 0x201, -3, 1.2, 9, 12, -1, 4, @"[6,16) [24,55) [63,94) [102,133)");
    expectOnRuns("a text matrix that scales by 1.25 does not scale the dashes or move the phase, 24 pt dotted", 0x101, -3, 1.2, 7, 12, -1, 4, @"[7,13) [19,25) [31,37) [43,49)");
    expectOnRuns("a text matrix that scales by 1.25 in a context scaled by two, 24 pt dotted", 0x101, -3, 1.2, 8, 12, -1, 4, @"[20,32) [44,56) [68,80) [92,104)");

    expectRows("a double underline of 20 pt: the pair is centred on the position less half a bar, on the half pixel grid", 9, -2.5, 1.0, @"y28:191 y26:191");
    expectRows("a double underline of 28 pt", 9, -3.5, 1.4, @"y27:6 y26:255 y25:11 y24:255 y23:6");
    expectRows("a double underline of 36 pt", 9, -4.5, 1.8, @"y26:44 y25:255 y24:80 y23:255 y22:44");
    expectRows("a double underline above 2 pt of thickness has its bars four rows apart (44 pt)", 9, -5.5, 2.2, @"y26:211 y25:211 y22:211 y21:211");
    expectRows("a double underline of 50 pt", 9, -6.25, 2.5, @"y25:239 y24:239 y21:239 y20:239");
    expectRows("a double underline of 54 pt", 9, -6.75, 2.7, @"y25:3 y24:255 y23:255 y22:3 y21:3 y20:255 y19:255 y18:3");
    expectRows("a double underline of 70 pt: the bars are three rows thick and six rows apart", 9, -8.75, 3.5, @"y23:207 y22:255 y21:207 y17:207 y16:255 y15:207");
    expectRows("a double underline of 100 pt", 9, -12.5, 5, @"y21:223 y20:255 y19:255 y18:223 y13:223 y12:255 y11:255 y10:223");
    expectRows("a double underline of 120 pt", 9, -15, 6, @"y19:63 y18:255 y17:255 y16:255 y15:255 y14:63 y11:63 y10:255 y9:255 y8:255 y7:255 y6:63");
    expectRows("a single underline of 20 pt takes the position half a pixel away from the baseline", 1, -2.5, 1.0, @"y27:127 y26:127");
    expectRows("a single underline of 54 pt is three rows and a half", 1, -6.75, 2.7, @"y24:127 y23:255 y22:255 y21:127");
    expectRows("a single underline of 90 pt is five rows", 1, -11.25, 4.5, @"y21:127 y20:255 y19:255 y18:255 y17:255 y16:127");
    expectRows("a thick underline of 100 pt is the single one", 2, -12.5, 5, @"y19:127 y18:255 y17:255 y16:255 y15:255 y14:127");
    expectAlphaRuns("a double dotted 40 pt underline: both bars take one pattern, the phase is the middle of the pair, the rows are the bars' rows", 0x109, -5, 2, 4, 14, 9, 6,
                    @"128@4+1 255@5+4 0@9+4 128@13+1 255@14+4 0@18+4");
    expectAlphaRuns("the second bar of a double dotted 40 pt underline has the same pattern", 0x109, -5, 2, 4, 14, 7, 6, @"128@4+1 255@5+4 0@9+4 128@13+1 255@14+4 0@18+4");
    expectAlphaRuns("a double dotted 40 pt underline, the row a quarter covered by the upper bar", 0x109, -5, 2, 4, 14, 10, 5, @"32@4+1 64@5+4 0@9+4 32@13+1 64@14+4");
    expectAlphaRuns("a double dashed 40 pt underline", 0x209, -5, 2, 4, 14, 9, 7, @"255@4+6 128@10+1 0@11+4 255@15+15 0@30+4 128@34+1 255@35+14");
    expectAlphaRuns("a double dash-dot 40 pt underline", 0x309, -5, 2, 4, 14, 9, 8, @"255@4+6 128@10+1 0@11+4 255@15+4 128@19+1 0@20+4 255@24+15 0@39+4");
    expectAlphaRuns("a double dotted 17 pt underline: each bar is 41/64 of a pixel and the lengths are in its units", 0x109, -2.125, 0.85, 4, 14, 12, 8,
                    @"162@4+1 144@5+1 0@6+1 31@7+1 162@8+1 115@9+1 0@10+1 60@11+1");
    expectAlphaRuns("a double dashed 24 pt underline", 0x209, -3, 1.2, 4, 14, 11, 8, @"182@5+1 229@6+8 44@14+1 0@15+1 21@16+1 229@17+8 206@25+1 0@26+2");
    expectAlphaRuns("a double dotted 60 pt underline", 0x109, -7.5, 3, 4, 14, 7, 8, @"255@4+1 192@5+1 0@6+6 128@12+1 255@13+6 64@19+1 0@20+6 255@26+6");

    barStart = 28.88;
    barWidth = 28.88;
    expectAlphaRuns("a dotted 40 pt underline under the second of six characters starts its pattern on the bar and keeps the phase of the baseline", 0x101, -5, 2, 4, 14, -1, 6,
                    @"30@35+1 255@36+5 225@41+1 0@42+5 30@47+1 255@48+5");
    expectAlphaRuns("a dashed 40 pt underline under the second of six characters", 0x201, -5, 2, 4, 14, -1, 5, @"30@32+1 255@33+10 225@43+1 0@44+5 30@49+1");
    barStart = 12.274;
    barWidth = 12.274;
    expectAlphaRuns("a dotted 17 pt underline under the second of six characters", 0x101, -2.125, 0.85, 4, 14, -1, 7, @"93@16+1 129@17+2 35@19+1 0@20+2 93@22+1 129@23+2 35@25+1");
    barStart = 0;
    barWidth = 120;

    return revenant_finish();
}
