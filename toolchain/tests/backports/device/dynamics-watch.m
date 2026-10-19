#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface Resumes : NSObject <UIDynamicAnimatorDelegate>
@property (nonatomic) int count;
@end

@implementation Resumes
- (void)dynamicAnimatorWillResume:(UIDynamicAnimator *)animator
{
    self.count++;
}
@end

static int deallocations;

@interface Tracked : UIView
@end

@implementation Tracked
- (void)dealloc
{
    deallocations++;
    NSLog(@"  (a Tracked view deallocates, %d)", deallocations);
}
@end

@interface UIDynamicAnimator (Private)
- (void)_setAlwaysDisableDisplayLink:(BOOL)disable;
@end

static int failures;
static int skipped;
static BOOL have_display;

static void check(BOOL ok, NSString *what)
{
    NSLog(@"%@ %@", ok ? @"ok  " : @"FAIL", what);
    if (!ok)
        failures++;
}

static UIDynamicAnimator *animator_over(UIView *view, Resumes *resumes)
{
    UIDynamicAnimator *animator = [[UIDynamicAnimator alloc] initWithReferenceView:view];
    if (!have_display)
        [animator _setAlwaysDisableDisplayLink:YES];
    animator.delegate = resumes;
    UIView *item = [[UIView alloc] initWithFrame:CGRectMake(100, 100, 40, 40)];
    [view addSubview:item];
    [animator addBehavior:[[UIGravityBehavior alloc] initWithItems:@[item]]];
    return animator;
}

static BOOL wakes(UIDynamicAnimator *animator, Resumes *resumes, void (^change)(void))
{
    [animator _setAlwaysDisableDisplayLink:YES];
    [animator _setAlwaysDisableDisplayLink:NO];
    int before = resumes.count;
    change();
    return resumes.count > before;
}

static void check_wake(UIDynamicAnimator *animator, Resumes *resumes, BOOL expected, NSString *what, void (^change)(void))
{
    if (!have_display) {
        change();
        skipped++;
        NSLog(@"skip %@: no display in this process, so no display link to start", what);
        return;
    }
    check(wakes(animator, resumes, change) == expected, what);
}

static UIDynamicAnimator *animator_in_pool(UIView *view, Resumes *resumes)
{
    UIDynamicAnimator *animator;
    @autoreleasepool {
        animator = animator_over(view, resumes);
    }
    return animator;
}

int main(void)
{
    @autoreleasepool {
        NSLog(@"dynamics watch: %@", [[UIDevice currentDevice] systemVersion]);
        {
            UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 800)];
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
            view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [superview addSubview:view];
            have_display = [[UIScreen screens] count] > 0;
            NSLog(@"screens: %lu, so %s", (unsigned long)[[UIScreen screens] count], have_display ? "the wake checks run" : "no display link, the wake checks are skipped");
            Resumes *resumes = [Resumes new];
            UIDynamicAnimator *animator = animator_in_pool(view, resumes);
            check_wake(animator, resumes, YES, @"(a) view.frame wakes", ^{ view.frame = CGRectMake(0, 0, 300, 600); });
            check_wake(animator, resumes, YES, @"(b) view.bounds wakes", ^{ view.bounds = CGRectMake(0, 0, 320, 600); });
            check_wake(animator, resumes, YES, @"(e) autoresizing wakes", ^{ superview.frame = CGRectMake(0, 0, 600, 1000); });
            check_wake(animator, resumes, NO, @"(c) layer.bounds does not wake", ^{ view.layer.bounds = CGRectMake(0, 0, 300, 700); });
            check_wake(animator, resumes, NO, @"(g) center does not wake", ^{ view.center = CGPointMake(200, 300); });
            check_wake(animator, resumes, NO, @"(h) transform does not wake", ^{ view.transform = CGAffineTransformMakeScale(2, 2); });
        }
        int before = deallocations;
        @autoreleasepool {
            Tracked *view = [[Tracked alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
            UIDynamicAnimator *animator = animator_in_pool(view, [Resumes new]);
            NSLog(@"lifetime 1: releasing the animator, then the view");
            animator = nil;
            NSLog(@"lifetime 1: animator released, releasing the view");
            view = nil;
        }
        check(deallocations == before + 1, @"lifetime 1: the view deallocated with the animator gone");
        before = deallocations;
        @autoreleasepool {
            Tracked *view = [[Tracked alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
            UIDynamicAnimator *animator = animator_in_pool(view, [Resumes new]);
            NSLog(@"lifetime 2: releasing the view, the animator still alive");
            view = nil;
            check(deallocations == before + 1, @"lifetime 2: the view deallocated with the animator alive");
            NSLog(@"lifetime 2: view released, releasing the animator (%@)", animator.referenceView);
            animator = nil;
        }
        before = deallocations;
        @autoreleasepool {
            Tracked *view = [[Tracked alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
            Resumes *second = [Resumes new];
            UIDynamicAnimator *one = animator_in_pool(view, [Resumes new]);
            UIDynamicAnimator *two = animator_in_pool(view, second);
            NSLog(@"lifetime 3: two animators over one view, releasing the first");
            one = nil;
            check_wake(two, second, YES, @"lifetime 3: (a) still wakes the second animator once the first is gone", ^{ view.frame = CGRectMake(0, 0, 300, 600); });
            two = nil;
            view.frame = CGRectMake(0, 0, 300, 700);
            NSLog(@"lifetime 3: both released, the view moved, releasing the view");
            view = nil;
        }
        check(deallocations == before + 1, @"lifetime 3: the view deallocated with both animators gone");
        for (int index = 0; index < 400; index++) {
            @autoreleasepool {
                UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                other.frame = CGRectMake(1, 2, 30, 40);
                other.bounds = CGRectMake(0, 0, 50, 60);
            }
        }
        NSLog(@"400 new views moved, failures %d", failures);
        NSLog(@"dynamics watch: %d checks failed, %d skipped%s", failures, skipped, skipped ? " (no display in this process: the wake checks did not run)" : "");
    }
    return failures;
}
