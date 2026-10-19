// dynamics-watch.m - the shipped UIDynamicAnimator's watch of its reference view (CharonReferenceViewWatch in
// UIDynamicAnimator.mm) on the release it runs on: what wakes a resting animator, and what KVO says when the
// animator or the view is released first (facts/UIKit/UIDynamicAnimator.md M3). Where uiview-kvo.m measures the release's
// KVO with a probe's own observer, this runs the class the backport ships. A command-line program, no UIApplicationMain:
// build it as a daemon target that requires charon@apple-backports with {configs = {uikit = true}} (add_packages and
// set_values("charon.libraries", ...), README's test port) and run it with `xmake emulate -d iPhone4,1 -r 6.1.3 run
// /usr/libexec/<name>`. It exits with the number of failed checks; the KVO line of a leaked observer is on stderr, and
// the run's log is read for it: `was deallocated while key value observers were still registered` must not be there.
// A process with no display has no display link to start, and on an emulated 4.3 asking for one faults in QuartzCore
// (display-probe.m; its measurements are in facts/UIKit/UIDynamicAnimator.md M3). No public call says beforehand whether the
// link call will fault; what the process can be asked is `[UIScreen screens]`, which agrees with the link's outcome at every point
// measured, and which is a property of the process, not of the release: on 4.3 it was empty in every probe run (a view, a window, a
// run loop turn, 30 s of them), and this program, which links the backports built at the release's minimum (`apple_minimum` set to the release), finds one screen on 5.1.1, 6.0
// and 6.1.3 (the same probe with no backports library finds none on 6.0, so a screen here is not the release's; whether the libraries' or the
// binary's minimum OS is what changes it is not separated, M3). With no screen the
// animators are kept from starting a link, the changes are made and the wake checks are skipped with a line each; the lifetimes,
// which are about the observers and not the wake, run whole. The last line counts the checks that failed and those skipped: the run's
// verdict (`pass`) is the exit status, which a skip leaves at 0.
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

// A reference view that counts its deallocations and logs each, so that a release that does not come is a failed check and not a
// silent one, and the log shows the order of the releases.
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

// Whether `change` woke an animator that was at rest: stopped the way an animator at rest is, with 7.0's own switch
// that keeps it from a display link (facts/UIKit/UIDynamicAnimator.md §1.6; no public call stops one), then released.
// The class and the helpers repeat wake_test.m's on the host: that program links the host's harness, this one runs on the guest.
static BOOL wakes(UIDynamicAnimator *animator, Resumes *resumes, void (^change)(void))
{
    [animator _setAlwaysDisableDisplayLink:YES];
    [animator _setAlwaysDisableDisplayLink:NO];
    int before = resumes.count;
    change();
    return resumes.count > before;
}

// The check that `change` woke (or, expected NO, did not wake) a resting animator; with no display it only makes the change.
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

// An animator over `view` with a gravity behavior and an item, built in a pool of its own so that what the run loop and
// UIKit autoreleased on the way is gone before the caller releases anything.
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
            // After the first view, which is the point display-probe.m asks at.
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
        // Each lifetime holds its view and animators in variables of its own, so that setting them to nil is the release.
        // Reading a weak property (the animator's own reference view, in its -dealloc) autoreleases what it returns, so a
        // view the animator was over dies when the pool of its lifetime drains, and the check comes after the pool.
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
        // views built now may take the addresses the dead ones had: a leaked observation would reach them
        for (int index = 0; index < 400; index++) {
            @autoreleasepool {
                UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                other.frame = CGRectMake(1, 2, 30, 40);
                other.bounds = CGRectMake(0, 0, 50, 60);
            }
        }
        NSLog(@"400 new views moved, failures %d", failures);
        // The run's own verdict (`pass`) is the exit status, which a skip leaves at 0; the last line says what the pass covered.
        NSLog(@"dynamics watch: %d checks failed, %d skipped%s", failures, skipped, skipped ? " (no display in this process: the wake checks did not run)" : "");
    }
    return failures;
}
