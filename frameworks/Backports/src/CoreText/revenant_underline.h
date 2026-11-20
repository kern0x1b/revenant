#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>

typedef struct {
    int count;
    CGRect bars[2];
} RevenantUnderlineBars;

static inline RevenantUnderlineBars revenant_underline_bars(int style, CGFloat position, CGFloat thickness, CGFloat x, CGFloat width, CGFloat offset)
{
    RevenantUnderlineBars result = {0, {CGRectZero, CGRectZero}};
    int kind = style & 0xFF;
    CGFloat length = ceil(width);
    if (kind == 0 || length <= 0)
        return result;
    CGFloat centre = round(position);
    if (offset != 0)
        centre = fmin(centre + offset, 0);
    if (kind == 9) {
        CGFloat each = round(thickness * 0.75 * 64) / 64;
        result.count = 2;
        result.bars[0] = CGRectMake(x, centre + 0.5 - each / 2, length, each);
        result.bars[1] = CGRectMake(x, centre - 1.5 - each / 2, length, each);
    } else {
        CGFloat each = fmax(1, ceil(thickness));
        result.count = 1;
        result.bars[0] = CGRectMake(x, centre - each / 2, length, each);
    }
    return result;
}

static inline void revenant_underline_fill(CGContextRef context, RevenantUnderlineBars bars, CGColorRef color)
{
    CGAffineTransform text = CGContextGetTextMatrix(context);
    CGFloat shift = floor(text.ty) - text.ty;
    CGFloat stretch = hypot(text.c, text.d);
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, text.c * shift, text.d * shift);
    CGContextConcatCTM(context, text);
    CGContextSetFillColorWithColor(context, color);
    for (int index = 0; index < bars.count; index++) {
        CGRect bar = bars.bars[index];
        if (stretch > 0) {
            CGFloat centre = bar.origin.y + bar.size.height / 2;
            bar.size.height /= stretch;
            bar.origin.y = centre - bar.size.height / 2;
        }
        CGContextFillRect(context, bar);
    }
    CGContextRestoreGState(context);
}
