#ifndef REVENANT_CORNER_PATH_H
#define REVENANT_CORNER_PATH_H

#include <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGFloat topLeft, topRight, bottomLeft, bottomRight;
} RevenantCornerRadii;

CG_EXTERN RevenantCornerRadii RevenantCornerRadiiFitted(CGSize size, RevenantCornerRadii radii);
CG_EXTERN CGPathRef RevenantCornerPathCreate(CGRect rect, RevenantCornerRadii radii);

#endif
