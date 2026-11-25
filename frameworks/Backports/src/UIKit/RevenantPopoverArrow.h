#ifndef REVENANT_POPOVER_ARROW_H
#define REVENANT_POPOVER_ARROW_H

#include <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGRect body;
    CGPoint tip;
    CGPoint first;
    CGPoint second;
} RevenantPopoverShape;

CG_EXTERN RevenantPopoverShape RevenantPopoverShapeMake(CGRect bounds, int direction, CGFloat offset, CGFloat base, CGFloat height);

#endif
