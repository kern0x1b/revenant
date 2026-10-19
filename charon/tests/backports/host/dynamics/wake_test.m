// wake_test.m — facts/UIKit/UIDynamicAnimator.md M3: a paused animator of ours wakes when -[UIView setFrame:] or
// -setBounds: changes its reference view's bounds size, and on no other change of the view. The wake is the delegate's
// dynamicAnimatorWillResume:. The animator is stopped between the steps the way an animator at rest is: the switch
// that keeps it from a display link, then released. (The host's own animator wakes by itself in the host UIKit; this
// tests ours, whose observer the reference view holds.)
#import "dynamics.h"
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

static void bring_to_rest(UIDynamicAnimator *animator)
{
    [animator _setAlwaysDisableDisplayLink:YES];
    [animator _setAlwaysDisableDisplayLink:NO];
}

static UIDynamicAnimator *animator_over(UIView *view, Resumes *resumes)
{
    UIDynamicAnimator *animator = [[side_class(Ours, @"UIDynamicAnimator") alloc] initWithReferenceView:view];
    animator.delegate = resumes;
    Item *item = [Item itemAt:CGPointMake(100, 100) size:CGSizeMake(40, 40)];
    [animator addBehavior:[MAKE(Ours, UIGravityBehavior) initWithItems:@[item]]];
    return animator;
}

// Whether `change` woke an animator that was at rest.
static BOOL wakes(UIDynamicAnimator *animator, Resumes *resumes, void (^change)(void))
{
    bring_to_rest(animator);
    int before = resumes.count;
    change();
    return resumes.count > before;
}

static void test_wake(void)
{
    UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 800)];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [superview addSubview:view];
    Resumes *resumes = [Resumes new];
    UIDynamicAnimator *animator = animator_over(view, resumes);
    charon_check(resumes.count == 1, "adding a behavior with an item starts the animator", @"ours");

    CHECK(wakes(animator, resumes, ^{ view.frame = CGRectMake(0, 0, 300, 600); }), "(a) view.frame wakes");
    CHECK(wakes(animator, resumes, ^{ view.bounds = CGRectMake(0, 0, 320, 600); }), "(b) view.bounds wakes");
    CHECK(wakes(animator, resumes, ^{ superview.frame = CGRectMake(0, 0, 600, 1000); }), "(e) autoresizing wakes");
    CHECK(!wakes(animator, resumes, ^{ view.layer.bounds = CGRectMake(0, 0, 300, 700); }), "(c) layer.bounds does not wake");
    CHECK(!wakes(animator, resumes, ^{ view.layer.frame = CGRectMake(0, 0, 300, 800); }), "(d) layer.frame does not wake");
    CHECK(!wakes(animator, resumes, ^{ view.center = CGPointMake(200, 300); }), "(g) center does not wake");
    CHECK(!wakes(animator, resumes, ^{ view.transform = CGAffineTransformMakeScale(2, 2); }), "(h) transform does not wake");
    CHECK(!wakes(animator, resumes, ^{ view.layer.position = CGPointMake(250, 350); }), "(i) layer.position does not wake");
    CHECK(!wakes(animator, resumes, ^{ view.transform = CGAffineTransformIdentity; view.frame = CGRectOffset(view.frame, 5, 5); }),
          "a move without a change of size does not wake");
    // The size the layer was left at is the size the setter compares with: 7.0 tests the bounds size before and after
    // the call, not the size the last notification saw.
    view.layer.bounds = CGRectMake(0, 0, 300, 900);
    CHECK(!wakes(animator, resumes, ^{ view.bounds = CGRectMake(0, 0, 300, 900); }), "a setter that leaves the size as the layer made it does not wake");
    CHECK(wakes(animator, resumes, ^{ view.bounds = CGRectMake(0, 0, 300, 950); }), "the next real change wakes");
}

static void test_lifetime(void)
{
    // An animator that goes leaves the view as it was; another over the same view keeps its observer.
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    Resumes *resumes = [Resumes new];
    UIDynamicAnimator *first = animator_over(view, resumes);
    @autoreleasepool {
        (void)animator_over(view, [Resumes new]);
    }
    CHECK(wakes(first, resumes, ^{ view.frame = CGRectMake(0, 0, 300, 500); }), "an animator over the same view still wakes after another went");
    first = nil;
    view.frame = CGRectMake(0, 0, 300, 600);
    charon_check(YES, "a view whose animators all went can be resized", @"ours");

    // A view that goes while its animator stays: the observer goes with the view, and the animator has no reference view.
    UIDynamicAnimator *orphan;
    @autoreleasepool {
        UIView *short_lived = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        orphan = animator_over(short_lived, [Resumes new]);
    }
    CHECK(orphan.referenceView == nil, "the animator does not keep its reference view");
    orphan = nil;
    charon_check(YES, "an animator outliving its view goes without a fault", @"ours");
}

int main(void)
{
    @autoreleasepool {
        test_wake();
        test_lifetime();
        return finish();
    }
}
