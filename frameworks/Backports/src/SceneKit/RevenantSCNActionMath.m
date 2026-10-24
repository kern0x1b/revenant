#import "RevenantSCNActionMath.h"
#include <math.h>

static double revenant_bezier(double t, double a, double b)
{
    double u = 1 - t;
    return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t;
}

static double revenant_bezier_slope(double t, double a, double b)
{
    double u = 1 - t;
    return 3 * u * u * a + 6 * u * t * (b - a) + 3 * t * t * (1 - b);
}

void RevenantSCNActionTimingPoints(SCNActionTimingMode mode, double points[4])
{
    static const double linear[4] = {0.0, 0.0, 1.0, 1.0};
    static const double easeIn[4] = {0.42, 0.0, 1.0, 1.0};
    static const double easeOut[4] = {0.0, 0.0, 0.58, 1.0};
    static const double easeInEaseOut[4] = {0.42, 0.0, 0.58, 1.0};
    const double *source = linear;
    switch (mode) {
        case SCNActionTimingModeEaseIn:
            source = easeIn;
            break;
        case SCNActionTimingModeEaseOut:
            source = easeOut;
            break;
        case SCNActionTimingModeEaseInEaseOut:
            source = easeInEaseOut;
            break;
        default:
            break;
    }
    for (int i = 0; i < 4; i++) {
        points[i] = source[i];
    }
}

double RevenantSCNActionCubicProgress(double progress, double x1, double y1, double x2, double y2)
{
    if (progress <= 0) {
        return 0;
    }
    if (progress >= 1) {
        return 1;
    }
    double t = progress;
    for (int i = 0; i < 8; i++) {
        double error = revenant_bezier(t, x1, x2) - progress;
        if (fabs(error) < 1e-9) {
            break;
        }
        double slope = revenant_bezier_slope(t, x1, x2);
        if (fabs(slope) < 1e-9) {
            break;
        }
        t -= error / slope;
        t = t < 0 ? 0 : (t > 1 ? 1 : t);
    }
    if (fabs(revenant_bezier(t, x1, x2) - progress) > 1e-7) {
        double low = 0, high = 1;
        for (int i = 0; i < 64; i++) {
            t = (low + high) / 2;
            if (revenant_bezier(t, x1, x2) < progress) {
                low = t;
            } else {
                high = t;
            }
        }
        t = (low + high) / 2;
    }
    return revenant_bezier(t, y1, y2);
}

double RevenantSCNActionEase(double progress, SCNActionTimingMode mode)
{
    double points[4];
    RevenantSCNActionTimingPoints(mode, points);
    return RevenantSCNActionCubicProgress(progress, points[0], points[1], points[2], points[3]);
}

double RevenantSCNActionShortestAngle(double from, double to)
{
    double delta = fmod(to - from, 2 * M_PI);
    if (delta > M_PI) {
        delta -= 2 * M_PI;
    } else if (delta < -M_PI) {
        delta += 2 * M_PI;
    }
    return delta;
}
