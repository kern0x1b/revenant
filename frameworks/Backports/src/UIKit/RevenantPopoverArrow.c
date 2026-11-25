#include "RevenantPopoverArrow.h"

RevenantPopoverShape RevenantPopoverShapeMake(CGRect bounds, int direction, CGFloat offset, CGFloat base, CGFloat height)
{
    RevenantPopoverShape shape = {bounds, {0, 0}, {0, 0}, {0, 0}};
    CGFloat x = CGRectGetMidX(bounds) + offset, y = CGRectGetMidY(bounds) + offset, half = base / 2;
    CGRectEdge edge;
    switch (direction) {
    case 1:
        edge = CGRectMinYEdge;
        break;
    case 2:
        edge = CGRectMaxYEdge;
        break;
    case 4:
        edge = CGRectMinXEdge;
        break;
    case 8:
        edge = CGRectMaxXEdge;
        break;
    default:
        return shape;
    }
    CGRect strip;
    CGRectDivide(bounds, &strip, &shape.body, height, edge);
    if (edge == CGRectMinYEdge || edge == CGRectMaxYEdge) {
        CGFloat inner = edge == CGRectMinYEdge ? CGRectGetMaxY(strip) : CGRectGetMinY(strip);
        shape.tip = CGPointMake(x, edge == CGRectMinYEdge ? CGRectGetMinY(strip) : CGRectGetMaxY(strip));
        shape.first = CGPointMake(x - half, inner);
        shape.second = CGPointMake(x + half, inner);
    } else {
        CGFloat inner = edge == CGRectMinXEdge ? CGRectGetMaxX(strip) : CGRectGetMinX(strip);
        shape.tip = CGPointMake(edge == CGRectMinXEdge ? CGRectGetMinX(strip) : CGRectGetMaxX(strip), y);
        shape.first = CGPointMake(inner, y - half);
        shape.second = CGPointMake(inner, y + half);
    }
    return shape;
}
