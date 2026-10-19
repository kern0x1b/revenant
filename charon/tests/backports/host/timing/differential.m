#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

static int checks;
static int failures;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void same_long(long ours, long theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: ours %ld, UIKit %ld", what, ours, theirs);
}

static void same_double(double ours, double theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: ours %.17g, UIKit %.17g", what, ours, theirs);
}

/* A settling duration is not held to the last bit: UIKit computes it in the width
   of a CGFloat, which is a float where this package is built and a double on the
   host, so the two round differently in the ninth digit. Everything else here is
   compared exactly. */
static void near_double(double ours, double theirs, NSString *what)
{
    checks++;
    if (fabs(ours - theirs) <= fmax(1e-9, fabs(theirs) * 1e-7))
        return;
    fail(@"%@: ours %.17g, UIKit %.17g", what, ours, theirs);
}

static void same_point(CGPoint ours, CGPoint theirs, NSString *what)
{
    checks++;
    if (!CGPointEqualToPoint(ours, theirs))
        fail(@"%@: ours %@, UIKit %@", what, NSStringFromCGPoint(ours), NSStringFromCGPoint(theirs));
}

/* A description carries the class name and the address, neither of which can match;
   what is compared is the shape and the values between them. */
static NSString *shape_of(NSString *description)
{
    NSString *text = [description stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRange open = [text rangeOfString:@"("], close = [text rangeOfString:@")"];
    if (open.location == NSNotFound || close.location == NSNotFound || close.location < open.location)
        return text;
    return [text stringByReplacingCharactersInRange:NSMakeRange(open.location, close.location - open.location + 1)
                                         withString:@"(*)"];
}

static void same_description(id ours, id theirs, NSString *what)
{
    checks++;
    NSString *a = shape_of([ours description]), *b = shape_of([theirs description]);
    if (![a isEqualToString:b])
        fail(@"%@ description: ours %@, UIKit %@", what, a, b);
}

static Class ours_of(NSString *name)
{
    Class mine = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
    if (!mine)
        fail(@"the backport defines no %@", name);
    return mine;
}

static NSString *reason_of(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name,
                [exception.reason stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""]];
    }
    return nil;
}

/* The four control points of whatever curve a timing function stands for, which is
   what the mapping from a UIViewAnimationCurve has to get right. */
static NSString *curve_of(id function)
{
    if (!function)
        return @"none";
    if ([function respondsToSelector:@selector(getControlPointAtIndex:values:)]) {
        NSMutableString *text = [NSMutableString string];
        for (size_t index = 0; index < 4; index++) {
            float values[2] = {0, 0};
            [(CAMediaTimingFunction *)function getControlPointAtIndex:index values:values];
            [text appendFormat:@"%.6f,%.6f ", values[0], values[1]];
        }
        return text;
    }
    CGPoint first = ((CGPoint (*)(id, SEL))objc_msgSend)(function, @selector(controlPoint1));
    CGPoint second = ((CGPoint (*)(id, SEL))objc_msgSend)(function, @selector(controlPoint2));
    return [NSString stringWithFormat:@"%.6f,%.6f %.6f,%.6f", first.x, first.y, second.x, second.y];
}

static void compare_cubic(void)
{
    Class theirs = [UICubicTimingParameters class], mine = ours_of(@"UICubicTimingParameters");
    if (!mine)
        return;
    const UIViewAnimationCurve curves[] = {UIViewAnimationCurveEaseInOut, UIViewAnimationCurveEaseIn,
                                           UIViewAnimationCurveEaseOut, UIViewAnimationCurveLinear};
    for (unsigned index = 0; index < 5; index++) {
        BOOL plain = index == 4;
        NSString *what = plain ? @"the default curve" : [NSString stringWithFormat:@"curve %u", index];
        UICubicTimingParameters *them = plain ? [[theirs alloc] init]
                                              : [[theirs alloc] initWithAnimationCurve:curves[index]];
        id us = plain ? [[mine alloc] init]
                      : ((id (*)(id, SEL, NSInteger))objc_msgSend)([mine alloc], @selector(initWithAnimationCurve:), curves[index]);
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(us, @selector(timingCurveType)), them.timingCurveType,
                  [what stringByAppendingString:@" timing curve type"]);
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(us, @selector(animationCurve)), them.animationCurve,
                  [what stringByAppendingString:@" animation curve"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(us, @selector(controlPoint1)), them.controlPoint1,
                   [what stringByAppendingString:@" control point 1"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(us, @selector(controlPoint2)), them.controlPoint2,
                   [what stringByAppendingString:@" control point 2"]);
        checks++;
        NSString *ourCurve = curve_of(((id (*)(id, SEL))objc_msgSend)(us, @selector(effectiveTimingFunction)));
        NSString *theirCurve = curve_of(((id (*)(id, SEL))objc_msgSend)(them, @selector(effectiveTimingFunction)));
        if (![ourCurve isEqualToString:theirCurve])
            fail(@"%@ effective timing function: ours %@, UIKit %@", what, ourCurve, theirCurve);
        same_long(((id (*)(id, SEL))objc_msgSend)(us, @selector(cubicTimingParameters)) == us,
                  them.cubicTimingParameters == them, [what stringByAppendingString:@" is its own cubic parameters"]);
        same_long(((id (*)(id, SEL))objc_msgSend)(us, @selector(springTimingParameters)) == nil,
                  them.springTimingParameters == nil, [what stringByAppendingString:@" has no spring parameters"]);
        same_description(us, them, what);

        id ourCopy = [us copy];
        UICubicTimingParameters *theirCopy = [them copy];
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(ourCopy, @selector(animationCurve)), theirCopy.animationCurve,
                  [what stringByAppendingString:@" survives a copy"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(ourCopy, @selector(controlPoint1)), theirCopy.controlPoint1,
                   [what stringByAppendingString:@" copied keeps control point 1"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(ourCopy, @selector(controlPoint2)), theirCopy.controlPoint2,
                   [what stringByAppendingString:@" copied keeps control point 2"]);
        id ourBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:us]];
        UICubicTimingParameters *theirBack = [NSKeyedUnarchiver unarchiveObjectWithData:
                                                 [NSKeyedArchiver archivedDataWithRootObject:them]];
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(ourBack, @selector(animationCurve)), theirBack.animationCurve,
                  [what stringByAppendingString:@" survives an archive"]);
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(ourBack, @selector(timingCurveType)), theirBack.timingCurveType,
                  [what stringByAppendingString:@" keeps its type through an archive"]);
    }

    const CGPoint firsts[] = {{0.1, 0.2}, {0, 0}, {1, 1}, {0.42, 0}};
    const CGPoint seconds[] = {{0.8, 0.9}, {1, 1}, {0, 0}, {0.58, 1}};
    for (unsigned index = 0; index < 4; index++) {
        NSString *what = [NSString stringWithFormat:@"control points %u", index];
        UICubicTimingParameters *them = [[theirs alloc] initWithControlPoint1:firsts[index] controlPoint2:seconds[index]];
        id us = ((id (*)(id, SEL, CGPoint, CGPoint))objc_msgSend)([mine alloc],
                    @selector(initWithControlPoint1:controlPoint2:), firsts[index], seconds[index]);
        same_long(((NSInteger (*)(id, SEL))objc_msgSend)(us, @selector(timingCurveType)), them.timingCurveType,
                  [what stringByAppendingString:@" timing curve type"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(us, @selector(controlPoint1)), them.controlPoint1,
                   [what stringByAppendingString:@" control point 1"]);
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(us, @selector(controlPoint2)), them.controlPoint2,
                   [what stringByAppendingString:@" control point 2"]);
        checks++;
        NSString *ourCurve = curve_of(((id (*)(id, SEL))objc_msgSend)(us, @selector(effectiveTimingFunction)));
        NSString *theirCurve = curve_of(((id (*)(id, SEL))objc_msgSend)(them, @selector(effectiveTimingFunction)));
        if (![ourCurve isEqualToString:theirCurve])
            fail(@"%@ effective timing function: ours %@, UIKit %@", what, ourCurve, theirCurve);
        id ourBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:us]];
        UICubicTimingParameters *theirBack = [NSKeyedUnarchiver unarchiveObjectWithData:
                                                 [NSKeyedArchiver archivedDataWithRootObject:them]];
        same_point(((CGPoint (*)(id, SEL))objc_msgSend)(ourBack, @selector(controlPoint1)), theirBack.controlPoint1,
                   [what stringByAppendingString:@" survives an archive"]);
    }

    same_description([[mine alloc] init], [[theirs alloc] init], @"the default curve again");
}

static void compare_spring(void)
{
    Class theirs = [UISpringTimingParameters class], mine = ours_of(@"UISpringTimingParameters");
    if (!mine)
        return;

    UISpringTimingParameters *themDefault = [[theirs alloc] init];
    id usDefault = [[mine alloc] init];
    same_double(((CGFloat (*)(id, SEL))objc_msgSend)(usDefault, @selector(mass)),
                ((CGFloat (*)(id, SEL))objc_msgSend)(themDefault, @selector(mass)), @"the default mass");
    same_double(((CGFloat (*)(id, SEL))objc_msgSend)(usDefault, @selector(stiffness)),
                ((CGFloat (*)(id, SEL))objc_msgSend)(themDefault, @selector(stiffness)), @"the default stiffness");
    same_double(((CGFloat (*)(id, SEL))objc_msgSend)(usDefault, @selector(damping)),
                ((CGFloat (*)(id, SEL))objc_msgSend)(themDefault, @selector(damping)), @"the default damping");
    same_long(((NSInteger (*)(id, SEL))objc_msgSend)(usDefault, @selector(timingCurveType)),
              themDefault.timingCurveType, @"a spring's timing curve type");
    same_description(usDefault, themDefault, @"the default spring");

    const CGFloat ratios[] = {0.2, 0.5, 1, 1.5};
    const CGVector velocities[] = {{0, 0}, {1, 0}, {0, -2.5}, {3, 4}};
    for (unsigned index = 0; index < 4; index++) {
        NSString *what = [NSString stringWithFormat:@"damping ratio %g", ratios[index]];
        UISpringTimingParameters *them = [[theirs alloc] initWithDampingRatio:ratios[index] initialVelocity:velocities[index]];
        id us = ((id (*)(id, SEL, CGFloat, CGVector))objc_msgSend)([mine alloc],
                    @selector(initWithDampingRatio:initialVelocity:), ratios[index], velocities[index]);
        same_double(((CGFloat (*)(id, SEL))objc_msgSend)(us, @selector(dampingRatio)),
                    ((CGFloat (*)(id, SEL))objc_msgSend)(them, @selector(dampingRatio)),
                    [what stringByAppendingString:@" damping ratio"]);
        CGVector ourVelocity = ((CGVector (*)(id, SEL))objc_msgSend)(us, @selector(initialVelocity));
        same_double(ourVelocity.dx, them.initialVelocity.dx, [what stringByAppendingString:@" velocity dx"]);
        same_double(ourVelocity.dy, them.initialVelocity.dy, [what stringByAppendingString:@" velocity dy"]);
        same_description(us, them, what);
        id ourBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:us]];
        UISpringTimingParameters *theirBack = [NSKeyedUnarchiver unarchiveObjectWithData:
                                                  [NSKeyedArchiver archivedDataWithRootObject:them]];
        same_double(((CGFloat (*)(id, SEL))objc_msgSend)(ourBack, @selector(dampingRatio)),
                    ((CGFloat (*)(id, SEL))objc_msgSend)(theirBack, @selector(dampingRatio)),
                    [what stringByAppendingString:@" survives an archive"]);
        same_description([us copy], [them copy], [what stringByAppendingString:@" copied"]);
    }

    const CGFloat masses[] = {1, 3, 0.5}, stiffnesses[] = {100, 1000, 40}, dampings[] = {10, 500, 2};
    for (unsigned index = 0; index < 3; index++) {
        NSString *what = [NSString stringWithFormat:@"spring %g/%g/%g", masses[index], stiffnesses[index], dampings[index]];
        UISpringTimingParameters *them = [[theirs alloc] initWithMass:masses[index] stiffness:stiffnesses[index]
                                                             damping:dampings[index] initialVelocity:CGVectorMake(1, 1)];
        id us = ((id (*)(id, SEL, CGFloat, CGFloat, CGFloat, CGVector))objc_msgSend)([mine alloc],
                    @selector(initWithMass:stiffness:damping:initialVelocity:),
                    masses[index], stiffnesses[index], dampings[index], CGVectorMake(1, 1));
        same_double(((CGFloat (*)(id, SEL))objc_msgSend)(us, @selector(dampingRatio)),
                    ((CGFloat (*)(id, SEL))objc_msgSend)(them, @selector(dampingRatio)),
                    [what stringByAppendingString:@" damping ratio"]);
        same_description(us, them, what);
        same_description([us copy], [them copy], [what stringByAppendingString:@" copied"]);
        id ourBack = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:us]];
        UISpringTimingParameters *theirBack = [NSKeyedUnarchiver unarchiveObjectWithData:
                                                  [NSKeyedArchiver archivedDataWithRootObject:them]];
        same_description(ourBack, theirBack, [what stringByAppendingString:@" archived"]);
    }

    UISpringTimingParameters *themOnly = [[theirs alloc] initWithDampingRatio:0.7];
    id usOnly = ((id (*)(id, SEL, CGFloat))objc_msgSend)([mine alloc], @selector(initWithDampingRatio:), (CGFloat)0.7);
    same_description(usOnly, themOnly, @"a spring made from a ratio alone");
}


/* How long the spring takes to settle, over a grid wide enough to reach both
   branches of the formula and both ends of the damping ratio's clamp. */
static void compare_settling(void)
{
    Class theirs = [UISpringTimingParameters class], mine = ours_of(@"UISpringTimingParameters");
    if (!mine)
        return;
    const CGFloat masses[] = {0.5, 1, 3, 10}, stiffnesses[] = {40, 100, 1000, 5000},
                  dampings[] = {1, 10, 100, 500, 2000};
    const CGVector velocities[] = {{0, 0}, {1, 0}, {10, 0}, {0, 10}, {6, 8}, {-10, 0}};
    for (unsigned a = 0; a < 4; a++)
        for (unsigned b = 0; b < 4; b++)
            for (unsigned c = 0; c < 5; c++)
                for (unsigned d = 0; d < 6; d++) {
                    UISpringTimingParameters *them = [[theirs alloc] initWithMass:masses[a] stiffness:stiffnesses[b]
                                                                          damping:dampings[c] initialVelocity:velocities[d]];
                    id us = ((id (*)(id, SEL, CGFloat, CGFloat, CGFloat, CGVector))objc_msgSend)([mine alloc],
                                @selector(initWithMass:stiffness:damping:initialVelocity:),
                                masses[a], stiffnesses[b], dampings[c], velocities[d]);
                    double ourSettling = ((double (*)(id, SEL))objc_msgSend)(us, @selector(settlingDuration));
                    double theirSettling = ((double (*)(id, SEL))objc_msgSend)(them, @selector(settlingDuration));
                    checks++;
                    if (fabs(ourSettling - theirSettling) > fmax(1e-9, fabs(theirSettling) * 1e-7))
                        fail(@"settling of %g/%g/%g at velocity (%g,%g): ours %.9g, UIKit %.9g",
                             masses[a], stiffnesses[b], dampings[c], velocities[d].dx, velocities[d].dy,
                             ourSettling, theirSettling);
                }
    /* A spring given only a damping ratio carries no mass, stiffness or damping,
       and settles in no time at all rather than in an infinity. */
    UISpringTimingParameters *themRatio = [[theirs alloc] initWithDampingRatio:0.5];
    id usRatio = ((id (*)(id, SEL, CGFloat))objc_msgSend)([mine alloc], @selector(initWithDampingRatio:), (CGFloat)0.5);
    near_double(((double (*)(id, SEL))objc_msgSend)(usRatio, @selector(settlingDuration)),
                ((double (*)(id, SEL))objc_msgSend)(themRatio, @selector(settlingDuration)),
                @"the settling of a spring made from a ratio alone");
    near_double(((double (*)(id, SEL))objc_msgSend)([[mine alloc] init], @selector(settlingDuration)),
                ((double (*)(id, SEL))objc_msgSend)([[theirs alloc] init], @selector(settlingDuration)),
                @"the settling of the default spring");
}

int main(void)
{
    @autoreleasepool {
        compare_cubic();
        compare_spring();
        compare_settling();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures;
}
