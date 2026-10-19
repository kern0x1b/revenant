#pragma once

#import <Accelerate/Accelerate.h>
#include <string.h>

typedef struct CharonTurn {
    int inside;
    vImagePixelCount sourceRow;
    vImagePixelCount sourceColumn;
} CharonTurn;

static inline CharonTurn charon_turn(uint8_t rotationConstant, vImagePixelCount dx, vImagePixelCount dy,
                                     vImagePixelCount width, vImagePixelCount height)
{
    CharonTurn found;
    switch (rotationConstant) {
    case 0:  found.sourceRow = dy;            found.sourceColumn = dx;               break;
    case 1:  found.sourceRow = dx;            found.sourceColumn = width - 1 - dy;   break;
    case 2:  found.sourceRow = height - 1 - dy; found.sourceColumn = width - 1 - dx; break;
    default: found.sourceRow = height - 1 - dx; found.sourceColumn = dy;             break;
    }
    found.inside = (found.sourceRow < height && found.sourceColumn < width) ? 1 : 0;
    return found;
}

static inline vImage_Error charon_turn_ready(const vImage_Buffer *src, const vImage_Buffer *dest,
                                             uint8_t rotationConstant)
{
    if (rotationConstant > 3)
        return kvImageInvalidParameter;
    if (!src || !dest)
        return kvImageNullPointerArgument;
    return kvImageNoError;
}

static inline vImage_Error charon_turn_run(const vImage_Buffer *src, const vImage_Buffer *dest,
                                           uint8_t rotationConstant, const void *backColor, size_t bytes,
                                           vImage_Flags flags)
{
    vImagePixelCount width = src->width, height = src->height;
    int quarter = (rotationConstant == 1 || rotationConstant == 3);
    vImagePixelCount turnedWidth = quarter ? height : width;
    vImagePixelCount turnedHeight = quarter ? width : height;
    long differenceX = (long)dest->width - (long)turnedWidth;
    long differenceY = (long)dest->height - (long)turnedHeight;
    long offsetX = differenceX >= 0 ? (differenceX + 1) / 2 : differenceX / 2;
    long offsetY = differenceY >= 0 ? (differenceY + 1) / 2 : differenceY / 2;
    int extend = (flags & kvImageEdgeExtend) ? 1 : 0;
    for (vImagePixelCount dy = 0; dy < dest->height; dy++) {
        uint8_t *out = (uint8_t *)dest->data + (size_t)dy * dest->rowBytes;
        for (vImagePixelCount dx = 0; dx < dest->width; dx++) {
            long tx = (long)dx - offsetX, ty = (long)dy - offsetY;
            CharonTurn from;
            const uint8_t *pixel;
            if (tx < 0 || ty < 0 || (vImagePixelCount)tx >= turnedWidth || (vImagePixelCount)ty >= turnedHeight) {
                if (!extend) {
                    memcpy(out + (size_t)dx * bytes, backColor, bytes);
                    continue;
                }
                if (tx < 0) tx = 0;
                if (ty < 0) ty = 0;
                if ((vImagePixelCount)tx >= turnedWidth) tx = turnedWidth ? turnedWidth - 1 : 0;
                if ((vImagePixelCount)ty >= turnedHeight) ty = turnedHeight ? turnedHeight - 1 : 0;
            }
            from = charon_turn(rotationConstant, (vImagePixelCount)tx, (vImagePixelCount)ty, width, height);
            if (from.inside)
                pixel = (const uint8_t *)src->data + (size_t)from.sourceRow * src->rowBytes
                      + (size_t)from.sourceColumn * bytes;
            else
                pixel = (const uint8_t *)backColor;
            memcpy(out + (size_t)dx * bytes, pixel, bytes);
        }
    }
    return kvImageNoError;
}
