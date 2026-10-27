#import "gesture.h"
#import "hid.h"

static NSMutableArray *queue;
static void (^queue_finished)(void);

BOOL gesture_ready(void)
{
    return hid_ready();
}

void gesture_touch(int phase, CGPoint point)
{
    hid_touch(phase, point);
}

void gesture_step(NSTimeInterval wait, void (^block)(void))
{
    if (!queue)
        queue = [NSMutableArray array];
    [queue addObject:@[@(wait), [block copy]]];
}

static void run_next(void)
{
    if (!queue.count) {
        void (^finished)(void) = queue_finished;
        queue_finished = nil;
        if (finished)
            finished();
        return;
    }
    NSArray *entry = queue[0];
    [queue removeObjectAtIndex:0];
    void (^block)(void) = entry[1];
    block();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([entry[0] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        run_next();
    });
}

void gesture_run(void (^finished)(void))
{
    queue_finished = [finished copy];
    run_next();
}

void gesture_drag(CGPoint (^from)(void), CGPoint (^to)(void), int steps, NSTimeInterval settle)
{
    __block CGPoint start, end;
    gesture_step(0.03, ^{ start = from(); end = to(); gesture_touch(0, start); });
    for (int index = 1; index <= steps; index++)
        gesture_step(0.03, ^{ gesture_touch(1, CGPointMake(start.x + (end.x - start.x) * index / steps, start.y + (end.y - start.y) * index / steps)); });
    gesture_step(settle, ^{ gesture_touch(2, end); });
}

void gesture_tap(CGPoint (^point)(void), NSTimeInterval settle)
{
    __block CGPoint at;
    gesture_step(0.08, ^{ at = point(); gesture_touch(0, at); });
    gesture_step(settle, ^{ gesture_touch(2, at); });
}

@interface GestureCanary : UIView
@property (nonatomic) BOOL touched;
@end

@implementation GestureCanary

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.touched = YES;
}

@end

static void unblock_attempt(UIWindow *window, GestureCanary *canary, NSMutableArray *candidates, BOOL wasBlocked, GestureUnblocked done)
{
    CGPoint probe = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetHeight(window.bounds) * 0.25);
    canary.touched = NO;
    gesture_touch(0, probe);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gesture_touch(2, probe);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (canary.touched || !candidates.count) {
                BOOL reached = canary.touched;
                [canary removeFromSuperview];
                done(wasBlocked, reached);
                return;
            }
            NSValue *next = candidates[0];
            [candidates removeObjectAtIndex:0];
            CGPoint point = [next CGPointValue];
            gesture_touch(0, point);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                gesture_touch(2, point);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    unblock_attempt(window, canary, candidates, YES, done);
                });
            });
        });
    });
}

void gesture_unblock(UIWindow *window, GestureUnblocked done)
{
    GestureCanary *canary = [[GestureCanary alloc] initWithFrame:window.bounds];
    canary.backgroundColor = [UIColor clearColor];
    [window addSubview:canary];
    [window bringSubviewToFront:canary];
    CGSize size = window.bounds.size;
    NSMutableArray *candidates = [NSMutableArray array];
    for (CGFloat offset = 40; offset <= 120; offset += 20)
        for (NSNumber *side in @[@-70, @70, @-110, @110])
            [candidates addObject:[NSValue valueWithCGPoint:CGPointMake(size.width / 2 + side.floatValue, size.height / 2 + offset)]];
    unblock_attempt(window, canary, candidates, NO, done);
}
