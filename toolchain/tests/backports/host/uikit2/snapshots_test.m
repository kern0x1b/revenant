#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UIView (CharonHostSnapshots)
- (BOOL)charonHostDrawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates;
- (UIView *)charonHostResizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)insets;
- (UIView *)charonHostSnapshotViewAfterScreenUpdates:(BOOL)afterUpdates;
@end

void charon_windowed_run(UIWindow *window);

static NSString *pixel(UIImage *image, int x, int y)
{
    uint8_t data[100 * 50 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, 100, 50, 8, 400, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, 100, 50), image.CGImage);
    uint8_t *found = data + (y * 100 + x) * 4;
    NSString *text = [NSString stringWithFormat:@"%d,%d,%d,%d", found[0], found[1], found[2], found[3]];
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return text;
}

static NSString *drawn(UIView *view, BOOL ours, CGRect rect, int x, int y, BOOL after)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(100, 50), NO, 1);
    BOOL result = ours ? [view charonHostDrawViewHierarchyInRect:rect afterScreenUpdates:after] : [view drawViewHierarchyInRect:rect afterScreenUpdates:after];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [NSString stringWithFormat:@"%d %@", result, pixel(image, x, y)];
}

static NSString *described(UIView *snapshot)
{
    if (!snapshot)
        return @"nil";
    CALayer *layer = snapshot.layer;
    return [NSString stringWithFormat:@"%@ %@ %.4f %.4f %.4f %.4f scale %g %@ interaction %d subviews %lu mask %lu", NSStringFromCGRect(snapshot.frame), NSStringFromCGRect(snapshot.bounds),
            layer.contentsCenter.origin.x, layer.contentsCenter.origin.y, layer.contentsCenter.size.width, layer.contentsCenter.size.height, (double)layer.contentsScale, layer.contentsGravity,
            snapshot.userInteractionEnabled, (unsigned long)snapshot.subviews.count, (unsigned long)snapshot.autoresizingMask];
}

void charon_windowed_run(UIWindow *window)
{
    UIView *host = window.rootViewController.view;
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(10, 20, 100, 50)];
    view.backgroundColor = [UIColor redColor];
    UIView *blue = [[UIView alloc] initWithFrame:CGRectMake(50, 0, 50, 50)];
    blue.backgroundColor = [UIColor blueColor];
    [view addSubview:blue];
    [host addSubview:view];

    CGRect rects[] = {CGRectMake(0, 0, 100, 50), CGRectMake(0, 0, 50, 25), CGRectMake(20, 10, 50, 25), CGRectMake(80, 30, 60, 60), CGRectMake(-500, -500, 20, 20), CGRectNull, CGRectMake(0, 0, 0, 10)};
    UIEdgeInsets insets[] = {UIEdgeInsetsZero, UIEdgeInsetsMake(5, 6, 7, 8), UIEdgeInsetsMake(10, 10, 10, 10), UIEdgeInsetsMake(0, 15, 0, 0), UIEdgeInsetsMake(-5, 0, 0, 0), UIEdgeInsetsMake(0, 0, 3, 0)};
    for (size_t index = 0; index < sizeof rects / sizeof *rects; index++) {
        for (size_t cap = 0; cap < sizeof insets / sizeof *insets; cap++) {
            UIView *ours = [view charonHostResizableSnapshotViewFromRect:rects[index] afterScreenUpdates:YES withCapInsets:insets[cap]];
            UIView *system = [view resizableSnapshotViewFromRect:rects[index] afterScreenUpdates:YES withCapInsets:insets[cap]];
            charon_check([described(ours) isEqualToString:described(system)], NAMED(@"snapshot of rect %zu with insets %zu", index, cap), [NSString stringWithFormat:@"%@ != %@", described(ours), described(system)]);
        }
    }
    UIView *plain = [view charonHostSnapshotViewAfterScreenUpdates:NO];
    charon_check([described(plain) isEqualToString:described([view snapshotViewAfterScreenUpdates:NO])], "a plain snapshot", @"the snapshot differs");
    UIView *detached = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    charon_check([described([detached charonHostSnapshotViewAfterScreenUpdates:YES]) isEqualToString:described([detached snapshotViewAfterScreenUpdates:YES])], "a snapshot of a view outside a window", @"the snapshot differs");
    UIView *empty = [[UIView alloc] init];
    charon_check([described([empty charonHostSnapshotViewAfterScreenUpdates:YES]) isEqualToString:described([empty snapshotViewAfterScreenUpdates:YES])], "a snapshot of a view of no size", @"the snapshot differs");
    view.hidden = YES;
    charon_check([described([view charonHostSnapshotViewAfterScreenUpdates:YES]) isEqualToString:described([view snapshotViewAfterScreenUpdates:YES])], "a snapshot of a hidden view", @"the snapshot differs");
    view.hidden = NO;

    int probes[][2] = {{30, 25}, {80, 25}, {47, 12}, {12, 12}, {62, 35}, {90, 45}, {5, 5}};
    CGRect drawRects[] = {CGRectMake(0, 0, 100, 50), CGRectMake(0, 0, 50, 25), CGRectMake(20, 10, 50, 25), CGRectMake(0, 0, 200, 100), CGRectMake(-25, 0, 100, 50)};
    for (size_t rectIndex = 0; rectIndex < sizeof drawRects / sizeof *drawRects; rectIndex++) {
        for (size_t probe = 0; probe < sizeof probes / sizeof *probes; probe++) {
            NSString *ours = drawn(view, YES, drawRects[rectIndex], probes[probe][0], probes[probe][1], YES);
            NSString *system = drawn(view, NO, drawRects[rectIndex], probes[probe][0], probes[probe][1], YES);
            charon_check([ours isEqualToString:system], NAMED(@"drawn into rect %zu at %d,%d", rectIndex, probes[probe][0], probes[probe][1]), [NSString stringWithFormat:@"%@ != %@", ours, system]);
        }
    }
    view.alpha = 0.5;
    charon_check([drawn(view, YES, CGRectMake(0, 0, 100, 50), 30, 25, YES) isEqualToString:drawn(view, NO, CGRectMake(0, 0, 100, 50), 30, 25, YES)], "a view of half alpha is drawn with half alpha", @"the alpha differs");
    view.alpha = 0;
    charon_check([drawn(view, YES, CGRectMake(0, 0, 100, 50), 30, 25, YES) isEqualToString:drawn(view, NO, CGRectMake(0, 0, 100, 50), 30, 25, YES)], "a view of no alpha draws nothing", @"the pixel differs");
    view.alpha = 1;
    view.hidden = YES;
    charon_check([drawn(view, YES, CGRectMake(0, 0, 100, 50), 30, 25, YES) isEqualToString:drawn(view, NO, CGRectMake(0, 0, 100, 50), 30, 25, YES)], "a hidden view draws nothing and still answers yes", @"the pixel differs");
    view.hidden = NO;
    view.transform = CGAffineTransformMakeScale(0.5, 0.5);
    charon_check([drawn(view, YES, CGRectMake(0, 0, 100, 50), 30, 25, YES) isEqualToString:drawn(view, NO, CGRectMake(0, 0, 100, 50), 30, 25, YES)], "a transformed view is drawn without its transform", @"the pixel differs");
    view.transform = CGAffineTransformIdentity;
    charon_check([drawn(detached, YES, CGRectMake(0, 0, 40, 40), 10, 10, NO) isEqualToString:drawn(detached, NO, CGRectMake(0, 0, 40, 40), 10, 10, NO)], "a view outside a window is not drawn and answers no", @"the answer differs");
    charon_check([drawn(empty, YES, CGRectMake(0, 0, 10, 10), 1, 1, YES) isEqualToString:drawn(empty, NO, CGRectMake(0, 0, 10, 10), 1, 1, YES)], "a view of no size answers yes", @"the answer differs");
    charon_check([view charonHostDrawViewHierarchyInRect:CGRectMake(0, 0, 10, 10) afterScreenUpdates:YES] == [view drawViewHierarchyInRect:CGRectMake(0, 0, 10, 10) afterScreenUpdates:YES], "with no graphics context the answer is the system's", @"the answer differs");
}
