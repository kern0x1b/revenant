#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>

typedef struct {
    int count;
    CGRect bars[2];
    int pattern;
    CGFloat unit;
    CGFloat phase[2];
} RevenantUnderlineBars;

static inline RevenantUnderlineBars revenant_underline_bars(int style, CGFloat position, CGFloat thickness, CGFloat x, CGFloat width, CGFloat offset)
{
    RevenantUnderlineBars result = {0, {CGRectZero, CGRectZero}, 0, 0, {0, 0}};
    int kind = style & 0xFF;
    int pattern = (style >> 8) & 0xF;
    CGFloat length = ceil(width);
    if (kind == 0 || length <= 0)
        return result;
    result.pattern = pattern <= 4 ? pattern : 0;
    if (kind == 9) {
        CGFloat each = round(thickness * 0.75 * 64) / 64;
        int apart = 1;
        CGFloat middle = round(position) - 0.5;
        if (each >= 0.5) {
            apart = (int)ceil(each - 0.5);
            if (apart < 1)
                apart = 1;
            CGFloat ideal = position - each / 2;
            middle = (apart & 1) ? floor(ideal) + 0.5 : round(ideal);
        }
        if (offset != 0)
            middle = fmin(middle + offset, (apart & 1) ? 0.5 - apart : -apart);
        result.count = 2;
        result.bars[0] = CGRectMake(x, middle + apart - each / 2, length, each);
        result.bars[1] = CGRectMake(x, middle - apart - each / 2, length, each);
        result.unit = thickness * 0.75;
        result.phase[0] = middle;
        result.phase[1] = middle;
    } else {
        CGFloat centre = round(position);
        if (offset != 0)
            centre = fmin(centre + offset, 0);
        CGFloat each = fmax(1, ceil(thickness));
        result.count = 1;
        result.bars[0] = CGRectMake(x, centre - each / 2, length, each);
        result.unit = kind == 2 ? each / 2 : each;
        result.phase[0] = centre;
    }
    return result;
}

static inline int revenant_underline_dashes(int pattern, CGFloat unit, CGFloat divisor, CGFloat *lengths)
{
    static const int counts[5] = {0, 2, 2, 4, 6};
    static const CGFloat units[5][6] = {{0}, {3, 3}, {10, 3}, {10, 3, 3, 3}, {10, 3, 3, 3, 3, 3}};
    for (int index = 0; index < counts[pattern]; index++)
        lengths[index] = units[pattern][index] * unit / divisor;
    return counts[pattern];
}

static inline void revenant_underline_fill(CGContextRef context, RevenantUnderlineBars bars, CGColorRef color)
{
    CGAffineTransform text = CGContextGetTextMatrix(context);
    CGAffineTransform device = CGContextGetCTM(context);
    CGFloat shift = floor(text.ty) - text.ty;
    CGFloat stretch = hypot(text.c, text.d);
    CGFloat along = hypot(text.a, text.b);
    CGFloat scale = hypot(device.a, device.b);
    CGFloat lengths[6];
    int dashes = along > 0 && bars.unit > 0 ? revenant_underline_dashes(bars.pattern, bars.unit, along, lengths) : 0;
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, text.c * shift, text.d * shift);
    CGContextConcatCTM(context, text);
    CGContextSetFillColorWithColor(context, color);
    CGContextSetStrokeColorWithColor(context, color);
    CGContextSetLineCap(context, kCGLineCapButt);
    for (int index = 0; index < bars.count; index++) {
        CGRect bar = bars.bars[index];
        CGFloat centre = bar.origin.y + bar.size.height / 2;
        if (stretch > 0) {
            bar.size.height /= stretch;
            bar.origin.y = centre - bar.size.height / 2;
        }
        if (dashes > 0) {
            CGFloat phase = scale * (floor(text.ty) + bars.phase[index]) / along;
            CGContextSetLineWidth(context, bar.size.height);
            CGContextSetLineDash(context, phase, lengths, (size_t)dashes);
            CGPoint ends[2] = {CGPointMake(bar.origin.x, bar.origin.y + bar.size.height / 2), CGPointMake(bar.origin.x + bar.size.width, bar.origin.y + bar.size.height / 2)};
            CGContextStrokeLineSegments(context, ends, 2);
        } else {
            CGContextFillRect(context, bar);
        }
    }
    CGContextRestoreGState(context);
}
