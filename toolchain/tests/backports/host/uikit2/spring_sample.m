#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSWindow *window;

static CALayer *hosted_layer(void)
{
    CALayer *layer = [CALayer layer];
    [window.contentView.layer addSublayer:layer];
    return layer;
}

static CALayer *presentation(CALayer *layer, CAAnimation *animation, double offset)
{
    animation.speed = 0;
    animation.timeOffset = offset;
    animation.fillMode = kCAFillModeBoth;
    [layer addAnimation:animation forKey:@"charon"];
    [CATransaction flush];
    return (CALayer *)layer.presentationLayer;
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 400) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.contentView.wantsLayer = YES;
        NSString *text = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            NSArray *fields = [line componentsSeparatedByString:@" "];
            NSString *kind = fields.count ? [fields objectAtIndex:0] : @"";
            if ([kind isEqualToString:@"sample"] && fields.count == 7) {
                double stiffness = [[fields objectAtIndex:1] doubleValue], damping = [[fields objectAtIndex:2] doubleValue];
                double velocity = [[fields objectAtIndex:3] doubleValue], duration = [[fields objectAtIndex:4] doubleValue];
                double time = [[fields objectAtIndex:5] doubleValue], ours = [[fields objectAtIndex:6] doubleValue];
                if (time >= duration)
                    continue;
                CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:@"position.x"];
                spring.mass = 1;
                spring.stiffness = stiffness;
                spring.damping = damping;
                spring.initialVelocity = velocity;
                spring.fromValue = @0;
                spring.toValue = @100;
                spring.duration = duration;
                CALayer *layer = hosted_layer();
                double system = [presentation(layer, spring, time) position].x;
                charon_check(fabs(system - ours) < 0.05, NAMED(@"spring of %g s, damping %g, velocity %g at %g s", duration, damping / (2 * sqrt(stiffness)), velocity, time),
                             [NSString stringWithFormat:@"%.6f != %.6f", ours, system]);
            } else if ([kind isEqualToString:@"interp"] && fields.count == 9) {
                BOOL point = [[fields objectAtIndex:1] isEqualToString:@"point"];
                double fromX = [[fields objectAtIndex:2] doubleValue], fromY = [[fields objectAtIndex:3] doubleValue];
                double toX = [[fields objectAtIndex:4] doubleValue], toY = [[fields objectAtIndex:5] doubleValue];
                double progress = [[fields objectAtIndex:6] doubleValue];
                double oursX = [[fields objectAtIndex:7] doubleValue], oursY = [[fields objectAtIndex:8] doubleValue];
                if (progress >= 1)
                    continue;
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:point ? @"position" : @"bounds"];
                animation.fromValue = point ? [NSValue valueWithPoint:NSMakePoint(fromX, fromY)] : [NSValue valueWithRect:NSMakeRect(0, 0, fromX, fromY)];
                animation.toValue = point ? [NSValue valueWithPoint:NSMakePoint(toX, toY)] : [NSValue valueWithRect:NSMakeRect(0, 0, toX, toY)];
                animation.duration = 1;
                CALayer *shown = presentation(hosted_layer(), animation, progress);
                double systemX = point ? shown.position.x : shown.bounds.size.width;
                double systemY = point ? shown.position.y : shown.bounds.size.height;
                charon_check(fabs(systemX - oursX) < 0.01 && fabs(systemY - oursY) < 0.01, NAMED(@"%s at %g", point ? "point" : "bounds", progress),
                             [NSString stringWithFormat:@"(%.4f, %.4f) != (%.4f, %.4f)", oursX, oursY, systemX, systemY]);
            } else if ([kind isEqualToString:@"interp"] && fields.count == 7) {
                double progress = [[fields objectAtIndex:2] doubleValue];
                double m11 = [[fields objectAtIndex:3] doubleValue], m22 = [[fields objectAtIndex:4] doubleValue];
                double m41 = [[fields objectAtIndex:5] doubleValue], m42 = [[fields objectAtIndex:6] doubleValue];
                if (progress >= 1)
                    continue;
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
                animation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
                animation.toValue = [NSValue valueWithCATransform3D:CATransform3DConcat(CATransform3DMakeScale(2, 3, 1), CATransform3DMakeTranslation(30, 12, 0))];
                animation.duration = 1;
                CATransform3D shown = [presentation(hosted_layer(), animation, progress) transform];
                charon_check(fabs(shown.m11 - m11) < 0.01 && fabs(shown.m22 - m22) < 0.01 && fabs(shown.m41 - m41) < 0.01 && fabs(shown.m42 - m42) < 0.01,
                             NAMED(@"transform at %g", progress),
                             [NSString stringWithFormat:@"(%.4f %.4f %.4f %.4f) != (%.4f %.4f %.4f %.4f)", m11, m22, m41, m42, shown.m11, shown.m22, shown.m41, shown.m42]);
            }
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
