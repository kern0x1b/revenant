#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"
#include <math.h>

double charon_spring_frequency(double duration, double dampingRatio, double velocity);
double charon_spring_progress(double omega, double dampingRatio, double velocity, double time);
id charon_spring_interpolate(id from, id to, double progress);

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static FILE *samples;

static void sample_curve(double duration, double dampingRatio, double velocity)
{
    double omega = charon_spring_frequency(duration, dampingRatio, velocity);
    if (isnan(omega))
        return;
    double zeta = MIN(MAX(dampingRatio, 1.1920929e-07), 1.0);
    for (int step = 0; step <= 10; step++) {
        double time = duration * step / 10;
        fprintf(samples, "sample %.17g %.17g %.17g %.17g %.17g %.17g\n", omega * omega, 2 * zeta * omega, velocity, duration, time, 100 * charon_spring_progress(omega, dampingRatio, velocity, time));
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *text = argc > 2 ? [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:NULL] : nil;
        samples = argc > 2 ? fopen(argv[2], "w") : NULL;
        charon_check(samples != NULL, "the sample file is writable", @"no output file");
        if (!samples)
            return 1;
        charon_check(text.length > 0, "UIKit spring parameters were collected", @"no input file");
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            NSArray *fields = [line componentsSeparatedByString:@" "];
            if (fields.count != 6 || ![[fields objectAtIndex:0] isEqualToString:@"case"])
                continue;
            double duration = [[fields objectAtIndex:1] doubleValue];
            double dampingRatio = [[fields objectAtIndex:2] doubleValue];
            double velocity = [[fields objectAtIndex:3] doubleValue];
            double stiffness = [[fields objectAtIndex:4] doubleValue];
            double damping = [[fields objectAtIndex:5] doubleValue];
            double omega = charon_spring_frequency(duration, dampingRatio, velocity);
            double zeta = MIN(MAX(dampingRatio, 1.1920929e-07), 1.0);
            const char *name = NAMED(@"spring of %g s, damping %g, velocity %g", duration, dampingRatio, velocity);
            charon_check(fabs(omega * omega - stiffness) <= stiffness * 1e-3, name, [NSString stringWithFormat:@"stiffness %.6f != %.6f", omega * omega, stiffness]);
            charon_check(fabs(2 * zeta * omega - damping) <= damping * 1e-3, NAMED(@"%s damping", name), [NSString stringWithFormat:@"damping %.6f != %.6f", 2 * zeta * omega, damping]);
        }
        double dampings[] = {0.1, 0.3, 0.5, 0.75, 1.0};
        double velocities[] = {0, 5, -4};
        for (int damping = 0; damping < 5; damping++) {
            for (int velocity = 0; velocity < 3; velocity++)
                sample_curve(damping == 2 ? 0.4 : 0.9, dampings[damping], velocities[velocity]);
        }
        NSValue *fromPoint = [NSValue valueWithCGPoint:CGPointMake(10, -20)], *toPoint = [NSValue valueWithCGPoint:CGPointMake(120, 60)];
        NSValue *fromRect = [NSValue valueWithCGRect:CGRectMake(0, 0, 50, 40)], *toRect = [NSValue valueWithCGRect:CGRectMake(0, 0, 200, 90)];
        double progresses[] = {0, 0.25, 0.5, 0.75, 1, 1.2};
        for (int index = 0; index < 6; index++) {
            CGPoint point = [charon_spring_interpolate(fromPoint, toPoint, progresses[index]) CGPointValue];
            fprintf(samples, "interp point %g %g %g %g %.17g %.17g %.17g\n", 10.0, -20.0, 120.0, 60.0, progresses[index], point.x, point.y);
            CGRect rect = [charon_spring_interpolate(fromRect, toRect, progresses[index]) CGRectValue];
            fprintf(samples, "interp bounds %g %g %g %g %.17g %.17g %.17g\n", 50.0, 40.0, 200.0, 90.0, progresses[index], rect.size.width, rect.size.height);
            CATransform3D from = CATransform3DMakeScale(1, 1, 1);
            CATransform3D to = CATransform3DConcat(CATransform3DMakeScale(2, 3, 1), CATransform3DMakeTranslation(30, 12, 0));
            CATransform3D mixed;
            [charon_spring_interpolate([NSValue valueWithCATransform3D:from], [NSValue valueWithCATransform3D:to], progresses[index]) getValue:&mixed];
            fprintf(samples, "interp transform %.17g %.17g %.17g %.17g %.17g\n", progresses[index], mixed.m11, mixed.m22, mixed.m41, mixed.m42);
        }
        charon_check(charon_spring_interpolate(@"text", @"other", 0.5) == nil, "a key path the backport cannot interpolate is left alone", @"a string was interpolated");
        charon_check(charon_spring_interpolate(fromPoint, fromRect, 0.5) == nil, "mismatched value types are left alone", @"a point and a rect were interpolated");
        charon_check(isnan(charon_spring_frequency(0.5, 0, 0)), "an undamped spring without velocity has no solution", @"a frequency was found");
        fclose(samples);
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
