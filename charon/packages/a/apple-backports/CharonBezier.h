#include <math.h>

// The progress along a cubic Bezier timing curve through (0,0), (x1,y1), (x2,y2), (1,1): solve x(s) = x, answer y(s).
// One solver for the port: UIKit's cubic timing parameters and SceneKit's CAMediaTimingFunction both take it from here.
static inline double charon_bezier_progress(double x1, double y1, double x2, double y2, double x)
{
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    double cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
    double cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
    double s = x;
    for (int i = 0; i < 8; i++) {
        double fx = ((ax * s + bx) * s + cx) * s - x;
        double dx = (3 * ax * s + 2 * bx) * s + cx;
        if (fabs(fx) < 1e-9) break;
        if (fabs(dx) < 1e-9) break;
        s -= fx / dx;
    }
    if (s < 0 || s > 1 || fabs(((ax * s + bx) * s + cx) * s - x) > 1e-7) {
        double lo = 0, hi = 1;
        s = x;
        for (int i = 0; i < 60; i++) {
            double fx = ((ax * s + bx) * s + cx) * s;
            if (fabs(fx - x) < 1e-9) break;
            if (fx < x) lo = s; else hi = s;
            s = (lo + hi) / 2;
        }
    }
    return ((ay * s + by) * s + cy) * s;
}
