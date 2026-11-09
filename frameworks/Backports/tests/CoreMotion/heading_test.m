#import <Foundation/Foundation.h>
#include <math.h>
#import "check.h"
#import "RevenantMotionHeading.h"

typedef struct {
    double x;
    double y;
    double z;
} Vector;

static const double radians_per_degree = M_PI / 180.0;

static Vector vector_scale(Vector a, double k)
{
    return (Vector){a.x * k, a.y * k, a.z * k};
}

static Vector vector_add(Vector a, Vector b)
{
    return (Vector){a.x + b.x, a.y + b.y, a.z + b.z};
}

static Vector turn_clockwise(Vector v, double degrees)
{
    double h = degrees * radians_per_degree;
    double north = v.x;
    double east = -v.y;
    double turned_north = north * cos(h) - east * sin(h);
    double turned_east = east * cos(h) + north * sin(h);
    return (Vector){turned_north, -turned_east, v.z};
}

static double bearing(Vector v)
{
    double degrees = atan2(-v.y, v.x) / radians_per_degree;
    return degrees < 0 ? degrees + 360.0 : degrees;
}

static double angle_between(double a, double b)
{
    double d = fmod(fabs(a - b), 360.0);
    return d > 180.0 ? 360.0 - d : d;
}

typedef struct {
    Vector y;
    Vector z;
} Pose;

static Pose pose(double heading, double tilt, double roll)
{
    Vector north = {1, 0, 0};
    Vector east = {0, -1, 0};
    Vector up = {0, 0, 1};
    double t = tilt * radians_per_degree;
    double r = roll * radians_per_degree;
    Vector y = vector_add(vector_scale(north, cos(t)), vector_scale(up, sin(t)));
    Vector z = vector_add(vector_scale(up, cos(t)), vector_scale(north, -sin(t)));
    Vector x = east;
    Vector rolled_z = vector_add(vector_scale(x, sin(r)), vector_scale(z, cos(r)));
    return (Pose){turn_clockwise(y, heading), turn_clockwise(rolled_z, heading)};
}

static double heading_of(Pose p)
{
    return RevenantMotionHeadingDegrees(p.y.x, p.y.y, p.y.z, p.z.x, p.z.y, p.z.z);
}

static double independent_heading(Pose p)
{
    if (fabs(p.z.z) >= fabs(p.y.z)) {
        return bearing(p.y);
    }
    return bearing(vector_scale(p.z, -1.0));
}

int main(void)
{
    @autoreleasepool {
        int worst_flat = 0;
        int count = 0;
        for (int heading = 0; heading < 360; heading += 5) {
            double tilts[] = {0, 20, 44, 46, 60, 80, 89, -20};
            for (size_t index = 0; index < sizeof(tilts) / sizeof(tilts[0]); index++) {
                double got = heading_of(pose(heading, tilts[index], 0));
                count++;
                if (angle_between(got, heading) > 1e-9) {
                    worst_flat++;
                    printf("heading %d tilt %.0f gave %.9f\n", heading, tilts[index], got);
                }
            }
        }
        revenant_check(worst_flat == 0, "an upright or tilted device reports the heading it was built with", [NSString stringWithFormat:@"%d of %d differ", worst_flat, count]);

        int bad_turns = 0;
        int turns = 0;
        for (int heading = 0; heading < 360; heading += 7) {
            double tilts[] = {-60, -80, 100, 120, 170};
            for (size_t index = 0; index < sizeof(tilts) / sizeof(tilts[0]); index++) {
                Pose p = pose(heading, tilts[index], 0);
                turns++;
                if (angle_between(heading_of(p), independent_heading(p)) > 1e-9) {
                    bad_turns++;
                }
            }
        }
        revenant_check(bad_turns == 0, "a device tilted past the vertical follows the direction of its back", [NSString stringWithFormat:@"%d of %d differ", bad_turns, turns]);

        int bad_rolls = 0;
        int rolls = 0;
        for (int heading = 0; heading < 360; heading += 11) {
            double tilts[] = {0, 30, 60, 85};
            double rolled[] = {-40, -10, 10, 25, 70};
            for (size_t i = 0; i < sizeof(tilts) / sizeof(tilts[0]); i++) {
                for (size_t j = 0; j < sizeof(rolled) / sizeof(rolled[0]); j++) {
                    Pose p = pose(heading, tilts[i], rolled[j]);
                    rolls++;
                    if (angle_between(heading_of(p), independent_heading(p)) > 1e-9) {
                        bad_rolls++;
                    }
                }
            }
        }
        revenant_check(bad_rolls == 0, "a rolled device follows the same axis as the construction", [NSString stringWithFormat:@"%d of %d differ", bad_rolls, rolls]);

        double flat_rolled = heading_of(pose(123.0, 0.0, 33.0));
        revenant_check(angle_between(flat_rolled, 123.0) < 1e-9, "a rolled device lying flat keeps the direction of its top", [NSString stringWithFormat:@"%.6f", flat_rolled]);

        double measured = RevenantMotionHeadingDegrees(-0.028, 0.235, 0.972, -0.035, -0.972, 0.234);
        revenant_check(fabs(measured - 272.06) < 0.1, "the attitude measured on an iPhone 4S held upright points its back at 272 degrees", [NSString stringWithFormat:@"%.4f", measured]);

        double range_ok = 1;
        for (int step = 0; step < 3600; step++) {
            double a = step * 0.1 * radians_per_degree;
            double value = RevenantMotionHeadingDegrees(cos(a), -sin(a), 0, 0, 0, 1);
            if (!(value >= 0.0 && value < 360.0)) {
                range_ok = 0;
            }
        }
        revenant_check(range_ok == 1, "the heading stays in [0, 360)", @"a value fell outside");

        revenant_check(fabs(RevenantMotionHeadingDegrees(1, 0, 0, 0, 0, 1) - 0.0) < 1e-12 && fabs(RevenantMotionHeadingDegrees(0, -1, 0, 0, 0, 1) - 90.0) < 1e-9 && fabs(RevenantMotionHeadingDegrees(-1, 0, 0, 0, 0, 1) - 180.0) < 1e-9 && fabs(RevenantMotionHeadingDegrees(0, 1, 0, 0, 0, 1) - 270.0) < 1e-9, "north, east, south and west are 0, 90, 180 and 270", @"a cardinal direction is off");
    }
    return revenant_finish();
}
