#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "RevenantCornerPath.h"
#import "check.h"

static BOOL inside_by_geometry(CGPoint p, CGRect rect, RevenantCornerRadii r, BOOL *near_edge)
{
    CGFloat left = CGRectGetMinX(rect), right = CGRectGetMaxX(rect), top = CGRectGetMinY(rect), bottom = CGRectGetMaxY(rect);
    *near_edge = fabs(p.x - left) < 1e-3 || fabs(p.x - right) < 1e-3 || fabs(p.y - top) < 1e-3 || fabs(p.y - bottom) < 1e-3;
    if (p.x < left || p.x > right || p.y < top || p.y > bottom) {
        return NO;
    }
    struct {
        CGFloat radius, cx, cy;
        int sx, sy;
    } corners[4] = {
        {r.topLeft, left + r.topLeft, top + r.topLeft, -1, -1},
        {r.topRight, right - r.topRight, top + r.topRight, 1, -1},
        {r.bottomLeft, left + r.bottomLeft, bottom - r.bottomLeft, -1, 1},
        {r.bottomRight, right - r.bottomRight, bottom - r.bottomRight, 1, 1},
    };
    for (int i = 0; i < 4; i++) {
        CGFloat dx = (p.x - corners[i].cx) * corners[i].sx, dy = (p.y - corners[i].cy) * corners[i].sy;
        if (dx > 0 && dy > 0) {
            CGFloat distance = hypot(dx, dy);
            if (fabs(distance - corners[i].radius) < 0.02) {
                *near_edge = YES;
            }
            if (distance > corners[i].radius) {
                return NO;
            }
        }
    }
    return YES;
}

static NSUInteger disagreements(CGRect rect, RevenantCornerRadii radii, RevenantCornerRadii fitted, NSUInteger *compared)
{
    CGPathRef path = RevenantCornerPathCreate(rect, radii);
    NSUInteger wrong = 0;
    *compared = 0;
    CGFloat step = 0.37;
    for (CGFloat y = rect.origin.y - 2; y <= CGRectGetMaxY(rect) + 2; y += step) {
        for (CGFloat x = rect.origin.x - 2; x <= CGRectGetMaxX(rect) + 2; x += step) {
            BOOL near_edge = NO;
            BOOL expected = inside_by_geometry(CGPointMake(x, y), rect, fitted, &near_edge);
            if (near_edge) {
                continue;
            }
            (*compared)++;
            if (CGPathContainsPoint(path, NULL, CGPointMake(x, y), false) != expected) {
                wrong++;
            }
        }
    }
    CGPathRelease(path);
    return wrong;
}

static void expect_shape(const char *name, CGRect rect, RevenantCornerRadii radii)
{
    RevenantCornerRadii fitted = RevenantCornerRadiiFitted(rect.size, radii);
    NSUInteger compared = 0;
    NSUInteger wrong = disagreements(rect, radii, revenant_negative ? radii : fitted, &compared);
    revenant_check(compared > 1000 && wrong == 0, name, [NSString stringWithFormat:@"%lu of %lu points differ from the geometry", (unsigned long)wrong, (unsigned long)compared]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    CGRect rect = CGRectMake(10, 20, 80, 50);
    expect_shape("four different radii cut each corner by its own circle", rect, (RevenantCornerRadii){4, 12, 20, 8});
    expect_shape("one rounded corner leaves the other three square", rect, (RevenantCornerRadii){0, 0, 0, 18});
    expect_shape("no radius gives the rectangle", rect, (RevenantCornerRadii){0, 0, 0, 0});
    expect_shape("radii that overrun a side shrink together", rect, (RevenantCornerRadii){60, 60, 30, 30});
    expect_shape("a negative radius is no radius", rect, (RevenantCornerRadii){-5, 10, 10, 10});

    RevenantCornerRadii fitted = RevenantCornerRadiiFitted(CGSizeMake(80, 50), (RevenantCornerRadii){60, 60, 30, 30});
    revenant_check(fitted.topLeft + fitted.topRight <= 80 + 1e-9 && fitted.bottomLeft + fitted.bottomRight <= 80 + 1e-9 &&
                       fitted.topRight + fitted.bottomRight <= 50 + 1e-9 && fabs(fitted.topLeft / fitted.bottomLeft - 2) < 1e-9 &&
                       fabs(fitted.topLeft + fitted.bottomLeft - 50) < 1e-9,
                   "the shrink keeps the ratio of the radii and fills the tightest side",
                   [NSString stringWithFormat:@"%g %g %g %g", fitted.topLeft, fitted.topRight, fitted.bottomLeft, fitted.bottomRight]);

    RevenantCornerRadii flat = RevenantCornerRadiiFitted(CGSizeMake(0, 50), (RevenantCornerRadii){5, 5, 5, 5});
    revenant_check(flat.topLeft == 0 && flat.bottomRight == 0, "a view without width has no rounded corners", @"a radius survives");

    CGFloat radius = 14;
    CGPathRef system = CGPathCreateWithRoundedRect(rect, radius, radius, NULL);
    CGPathRef ours = RevenantCornerPathCreate(rect, (RevenantCornerRadii){radius, radius, radius, radius});
    NSUInteger differ = 0, total = 0;
    for (CGFloat y = rect.origin.y - 1; y <= CGRectGetMaxY(rect) + 1; y += 0.41) {
        for (CGFloat x = rect.origin.x - 1; x <= CGRectGetMaxX(rect) + 1; x += 0.41) {
            CGPoint p = CGPointMake(x, y);
            total++;
            BOOL same = CGPathContainsPoint(system, NULL, p, false) == CGPathContainsPoint(ours, NULL, p, false);
            differ += same ? 0 : 1;
        }
    }
    revenant_check(differ * 500 < total, "equal radii enclose what the system's rounded rectangle encloses",
                   [NSString stringWithFormat:@"%lu of %lu points differ", (unsigned long)differ, (unsigned long)total]);
    CGPathRelease(system);
    CGPathRelease(ours);
    return revenant_finish();
}
