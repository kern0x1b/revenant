#include "RevenantCornerPath.h"

static CGFloat clamped(CGFloat radius)
{
    return radius > 0 ? radius : 0;
}

static CGFloat shrink(CGFloat factor, CGFloat length, CGFloat radii)
{
    return radii > length && radii > 0 ? (length / radii < factor ? length / radii : factor) : factor;
}

RevenantCornerRadii RevenantCornerRadiiFitted(CGSize size, RevenantCornerRadii radii)
{
    radii.topLeft = clamped(radii.topLeft);
    radii.topRight = clamped(radii.topRight);
    radii.bottomLeft = clamped(radii.bottomLeft);
    radii.bottomRight = clamped(radii.bottomRight);
    CGFloat factor = 1;
    factor = shrink(factor, size.width, radii.topLeft + radii.topRight);
    factor = shrink(factor, size.width, radii.bottomLeft + radii.bottomRight);
    factor = shrink(factor, size.height, radii.topLeft + radii.bottomLeft);
    factor = shrink(factor, size.height, radii.topRight + radii.bottomRight);
    radii.topLeft *= factor;
    radii.topRight *= factor;
    radii.bottomLeft *= factor;
    radii.bottomRight *= factor;
    return radii;
}

CGPathRef RevenantCornerPathCreate(CGRect rect, RevenantCornerRadii radii)
{
    radii = RevenantCornerRadiiFitted(rect.size, radii);
    CGFloat left = CGRectGetMinX(rect), right = CGRectGetMaxX(rect);
    CGFloat top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, left + radii.topLeft, top);
    CGPathAddArcToPoint(path, NULL, right, top, right, top + radii.topRight, radii.topRight);
    CGPathAddArcToPoint(path, NULL, right, bottom, right - radii.bottomRight, bottom, radii.bottomRight);
    CGPathAddArcToPoint(path, NULL, left, bottom, left, bottom - radii.bottomLeft, radii.bottomLeft);
    CGPathAddArcToPoint(path, NULL, left, top, left + radii.topLeft, top, radii.topLeft);
    CGPathCloseSubpath(path);
    return path;
}
