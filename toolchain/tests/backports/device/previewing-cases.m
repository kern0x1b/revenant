#import "previewing-cases.h"

@interface PreviewWatcher : NSObject <UIViewControllerPreviewingDelegate>
@property (nonatomic, assign) NSUInteger asked;
@property (nonatomic, assign) NSUInteger committed;
@end

@implementation PreviewWatcher

@synthesize asked, committed;

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    self.asked = self.asked + 1;
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    self.committed = self.committed + 1;
}

@end

static void settle(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
}

void previewing_run(UIWindow *window, PreviewingRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    PreviewWatcher *watcher = [[PreviewWatcher alloc] init];
    UIView *source = [[UIView alloc] initWithFrame:CGRectMake(20, 80, 120, 60)];
    [root.view addSubview:source];
    [window layoutIfNeeded];
    settle();

    record(@"the force touch capability a context is registered under", [NSString stringWithFormat:@"%ld", (long)root.traitCollection.forceTouchCapability]);

    id<UIViewControllerPreviewing> context = [root registerForPreviewingWithDelegate:watcher sourceView:source];
    settle();
    record(@"registering for previewing answers a context", [NSString stringWithFormat:@"%@ | %@ | %@ | %@",
                                                             context ? @"context" : @"nil",
                                                             context.delegate == watcher ? @"delegate kept" : @"delegate lost",
                                                             context.sourceView == source ? @"source kept" : @"source lost",
                                                             NSStringFromCGRect(context.sourceRect)]);
    UIGestureRecognizer *relationship = context.previewingGestureRecognizerForFailureRelationship;
    record(@"the context has a recogniser for a failure relationship",
           [NSString stringWithFormat:@"%@ | %@ | %@ | %@", relationship ? @"recogniser" : @"nil",
                                      [source.gestureRecognizers containsObject:relationship] ? @"on the source view" : @"not on the source view",
                                      relationship.enabled ? @"enabled" : @"disabled",
                                      relationship.view ? @"in a view" : @"in no view"]);
    record(@"the recogniser is the same one every time",
           relationship == context.previewingGestureRecognizerForFailureRelationship ? @"same" : @"another");

    context.sourceRect = CGRectMake(1, 2, 3, 4);
    record(@"the source rect can be set", NSStringFromCGRect(context.sourceRect));

    id<UIViewControllerPreviewing> second = [root registerForPreviewingWithDelegate:watcher sourceView:source];
    record(@"a second registration answers a context of its own",
           [NSString stringWithFormat:@"%@ | %@", second == context ? @"the same" : @"another",
                                      second.previewingGestureRecognizerForFailureRelationship == relationship ? @"the same recogniser" : @"a recogniser of its own"]);

    UIView *otherSource = [[UIView alloc] initWithFrame:CGRectMake(20, 160, 120, 60)];
    [root.view addSubview:otherSource];
    id<UIViewControllerPreviewing> onOther = [root registerForPreviewingWithDelegate:watcher sourceView:otherSource];
    record(@"a registration on another source view answers another context",
           [NSString stringWithFormat:@"%@ | %@", onOther == context ? @"the same" : @"another",
                                      onOther.sourceView == otherSource ? @"that source" : @"the wrong source"]);

    PreviewWatcher *otherWatcher = [[PreviewWatcher alloc] init];
    id<UIViewControllerPreviewing> onOtherDelegate = [root registerForPreviewingWithDelegate:otherWatcher sourceView:source];
    record(@"a registration with another delegate on the same source view",
           [NSString stringWithFormat:@"%@ | %@", onOtherDelegate == context ? @"the same" : @"another",
                                      onOtherDelegate.delegate == otherWatcher ? @"the new delegate" : @"the old delegate"]);

    settle();
    record(@"nothing asked the delegate", [NSString stringWithFormat:@"%lu | %lu", (unsigned long)watcher.asked, (unsigned long)watcher.committed]);

    [root unregisterForPreviewingWithContext:context];
    [root unregisterForPreviewingWithContext:second];
    [root unregisterForPreviewingWithContext:onOther];
    [root unregisterForPreviewingWithContext:onOtherDelegate];
    settle();
    record(@"unregistering leaves no recogniser on the source view",
           [source.gestureRecognizers containsObject:relationship] ? @"still there" : @"gone");
    record(@"unregistering a context that was never registered is quiet", @"returned");
    [root unregisterForPreviewingWithContext:context];
    record(@"unregistering twice is quiet", @"returned");
}
