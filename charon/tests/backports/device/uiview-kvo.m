// uiview-kvo.m - what KVO of a UIView's frame and bounds tells, on the release it runs on, next to what the
// setters -[UIView setFrame:] and -setBounds: were called with, and what KVO does with an observer left on a view that
// deallocates (facts/UIKit/UIDynamicAnimator.md M3). A command-line program, no UIApplicationMain: build it as a
// daemon target (@addon/charon/daemon; Foundation, UIKit, QuartzCore, CoreGraphics; -fobjc-arc) and run it with
// `xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/<name>`, as tools/probe-exports.py does for its probe. It runs
// from 4.3 (apple_minimum 4.3, -d iPhone3,1) too, when -fobjc-arc is on the link line as well as the compile, so that
// clang force-loads Charon's arclite; path (f) is skipped on a release without NSLayoutConstraint (6.0 and later).
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <stdio.h>

static __weak UIView *g_view;
static int g_frameCalls, g_boundsCalls, g_sizeChangingCalls;

static void wrap(SEL selector, int *counter)
{
    Method method = class_getInstanceMethod([UIView class], selector);
    void (*original)(id, SEL, CGRect) = (void (*)(id, SEL, CGRect))method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^(UIView *view, CGRect rect) {
        CGSize old = view.bounds.size;
        original(view, selector, rect);
        if (view == g_view) {
            (*counter)++;
            if (!CGSizeEqualToSize(old, view.bounds.size))
                g_sizeChangingCalls++;
        }
    }));
}

@interface Watch : NSObject
@property (nonatomic) NSMutableArray *fired;
@property (nonatomic) CGSize size;
@property (nonatomic) CGSize before;
@property (nonatomic) int priors;
@property (nonatomic) int wakes;
@property (nonatomic) int callbacks;
@end

@implementation Watch
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    self.callbacks++;
    if (object != g_view)
        return;
    CGSize size = ((UIView *)object).bounds.size;
    if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
        self.priors++;
        self.before = size;
        return;
    }
    [self.fired addObject:key];
    if (!CGSizeEqualToSize(size, self.before))
        self.wakes++;
}
@end

static NSLayoutConstraint *g_height;

static void path(const char *name, void (^setup)(UIView *, UIView *), void (^act)(UIView *, UIView *))
{
    @autoreleasepool {
        UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 800)];
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [superview addSubview:view];
        if (setup)
            setup(superview, view);
        g_view = view;
        g_frameCalls = g_boundsCalls = g_sizeChangingCalls = 0;
        Watch *watch = [Watch new];
        watch.fired = [NSMutableArray array];
        watch.size = view.bounds.size;
        [view addObserver:watch forKeyPath:@"frame" options:NSKeyValueObservingOptionPrior context:NULL];
        [view addObserver:watch forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior context:NULL];
        act(superview, view);
        [view removeObserver:watch forKeyPath:@"frame"];
        [view removeObserver:watch forKeyPath:@"bounds"];
        printf("path %s: setFrame %d setBounds %d size-changing %d | KVO %s | KVO wakes %d (priors %d) | bounds %gx%g\n", name, g_frameCalls, g_boundsCalls,
               g_sizeChangingCalls, [[watch.fired componentsJoinedByString:@","] UTF8String], watch.wakes, watch.priors, view.bounds.size.width, view.bounds.size.height);
        fflush(stdout);
    }
}

@interface Remover : NSObject
- (instancetype)initWithView:(UIView *)view watch:(Watch *)watch;
@end

@implementation Remover {
    __unsafe_unretained UIView *_view;
    Watch *_watch;
}
- (instancetype)initWithView:(UIView *)view watch:(Watch *)watch
{
    if ((self = [super init])) {
        _view = view;
        _watch = watch;
    }
    return self;
}
- (void)dealloc
{
    printf("remover dealloc: view class %s\n", class_getName(object_getClass(_view)));
    fflush(stdout);
    [_view removeObserver:_watch forKeyPath:@"frame"];
    [_view removeObserver:_watch forKeyPath:@"bounds"];
    printf("remover: removed\n");
    fflush(stdout);
}
@end

static char removerKey;

static void lifetime(const char *name, BOOL withRemover)
{
    Watch *watch = [Watch new];
    watch.fired = [NSMutableArray array];
    g_view = nil;
    printf("lifetime %s: begin\n", name);
    fflush(stdout);
    @try {
        @autoreleasepool {
            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
            [view addObserver:watch forKeyPath:@"frame" options:NSKeyValueObservingOptionPrior context:NULL];
            [view addObserver:watch forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior context:NULL];
            if (withRemover)
                objc_setAssociatedObject(view, &removerKey, [[Remover alloc] initWithView:view watch:watch], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            printf("lifetime %s: view class %s, releasing it\n", name, class_getName(object_getClass(view)));
            fflush(stdout);
        }
        printf("lifetime %s: view released, process alive\n", name);
    } @catch (NSException *exception) {
        printf("lifetime %s: exception %s: %s\n", name, [[exception name] UTF8String], [[exception reason] UTF8String]);
    }
    fflush(stdout);
    // a view built now may take the address the dead one had; does the leftover observation reach the watch?
    watch.callbacks = 0;
    @try {
        for (int index = 0; index < 400; index++) {
            @autoreleasepool {
                UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                other.frame = CGRectMake(1, 2, 30, 40);
                other.bounds = CGRectMake(0, 0, 50, 60);
            }
        }
        printf("lifetime %s: 400 new views moved, %d stray callbacks\n", name, watch.callbacks);
    } @catch (NSException *exception) {
        printf("lifetime %s: later exception %s: %s\n", name, [[exception name] UTF8String], [[exception reason] UTF8String]);
    }
    fflush(stdout);
}

// the design: the observer is an object the view holds, gone with the view or when the animator lets it go
static void released_early(void)
{
    Watch *watch = [Watch new];
    watch.fired = [NSMutableArray array];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [view addObserver:watch forKeyPath:@"frame" options:NSKeyValueObservingOptionPrior context:NULL];
    [view addObserver:watch forKeyPath:@"bounds" options:NSKeyValueObservingOptionPrior context:NULL];
    Remover *remover = [[Remover alloc] initWithView:view watch:watch];
    objc_setAssociatedObject(view, &removerKey, remover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    remover = nil;
    printf("early: dropping the association from a live view\n");
    fflush(stdout);
    objc_setAssociatedObject(view, &removerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    g_view = view;
    view.frame = CGRectMake(0, 0, 200, 200);
    printf("early: live view moved after the association went, %d callbacks\n", watch.callbacks);
    g_view = nil;
    view = nil;
    printf("early: view released, process alive\n");
    fflush(stdout);
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        printf("kvo probe: %s\n", [[[UIDevice currentDevice] systemVersion] UTF8String]);
        wrap(@selector(setFrame:), &g_frameCalls);
        wrap(@selector(setBounds:), &g_boundsCalls);
        path("(a) view.frame", NULL, ^(UIView *s, UIView *v) { v.frame = CGRectMake(0, 0, 300, 600); });
        path("(b) view.bounds", NULL, ^(UIView *s, UIView *v) { v.bounds = CGRectMake(0, 0, 300, 600); });
        path("(c) layer.bounds", NULL, ^(UIView *s, UIView *v) { v.layer.bounds = CGRectMake(0, 0, 300, 600); });
        path("(d) layer.frame", NULL, ^(UIView *s, UIView *v) { v.layer.frame = CGRectMake(0, 0, 300, 600); });
        path("(e) superview resized, autoresizing", NULL, ^(UIView *s, UIView *v) { s.frame = CGRectMake(0, 0, 600, 1000); });
        // Looked up by name: a reference to the class itself would be a weak import that is NULL below 6.0.
        Class constraint = NSClassFromString(@"NSLayoutConstraint");
        if (constraint) {
            path("(f) Auto Layout constant",
                 ^(UIView *s, UIView *v) {
                     v.translatesAutoresizingMaskIntoConstraints = NO;
                     [s addConstraint:[constraint constraintWithItem:v attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:s attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
                     [s addConstraint:[constraint constraintWithItem:v attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:s attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
                     [v addConstraint:[constraint constraintWithItem:v attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:300]];
                     g_height = [constraint constraintWithItem:v attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:400];
                     [v addConstraint:g_height];
                     [s layoutIfNeeded];
                 },
                 ^(UIView *s, UIView *v) {
                     g_height.constant = 600;
                     [s setNeedsLayout];
                     [s layoutIfNeeded];
                 });
        } else {
            printf("path (f) Auto Layout constant: skipped, no NSLayoutConstraint on this release\n");
        }
        path("(g) center", NULL, ^(UIView *s, UIView *v) { v.center = CGPointMake(200, 300); });
        path("(h) transform", NULL, ^(UIView *s, UIView *v) { v.transform = CGAffineTransformMakeScale(2, 2); });
        path("(i) layer.position", NULL, ^(UIView *s, UIView *v) { v.layer.position = CGPointMake(200, 300); });
        // A leaks on purpose, and on 5.1.1 the leaked observation stays with the address and comes back on the next
        // objects built there: it goes last, so that B and the early release run on a clean process.
        released_early();
        lifetime("B, observer removed by an object the view holds", YES);
        lifetime("A, observer left on the dying view", NO);
    }
    printf("done\n");
    return 0;
}
