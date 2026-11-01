// Touch and text injection for the host on a phone without a touch tool.
//
// The host reads /var/tmp/rnhost.cmd every 300 ms. A line is one command:
//   tap X Y                 a touch down and up at the point (X, Y) of the key window, in points
//   swipe X1 Y1 X2 Y2 [MS]  a touch that moves from one point to the other in MS milliseconds (default 300)
//   text STRING             inserts STRING into the first responder, as the keyboard would
//   key delete              deletes one character backwards
// The file is removed when read, and the result of each line is appended to /var/tmp/rnhost.cmd.out.
//
// A tap is a real UITouch in a real UIEvent given to -[UIApplication sendEvent:], as UIKit gives it from the hardware, so
// the gesture recognizers of React Native's touch handler see it. UITouch has no public initializer, so its fields are set
// through the private setters iOS 6 has (the approach of the KIF test framework).

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface UITouch (RNHostPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)count;
- (void)setIsTap:(BOOL)isTap;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)phase;
- (void)setGestureView:(UIView *)view;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)reset;
- (void)_setIsFirstTouchForView:(BOOL)first;
@end

@interface UIEvent (RNHostPrivate)
- (void)_clearTouches;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
@end

@interface UIApplication (RNHostPrivate)
- (UIEvent *)_touchesEvent;
@end

@interface RNHostTouch : NSObject
@end

static void RNHostCommandResult(NSString *line)
{
    NSString *path = @"/var/tmp/rnhost.cmd.out";
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [handle seekToEndOfFile];
    [handle writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

static UIWindow *RNHostKeyWindow(void)
{
    UIApplication *application = [UIApplication sharedApplication];
    return application.keyWindow ?: application.windows.firstObject;
}

static void RNHostDeliver(UIView *view, NSSet *touches, UIEvent *event, UITouchPhase phase)
{
    for (UIGestureRecognizer *recognizer in [view.gestureRecognizers copy]) {
        if (!recognizer.enabled || !([NSStringFromClass([recognizer class]) hasPrefix:@"RCT"] || [NSStringFromClass([recognizer class]) hasPrefix:@"RNG"])) {
            continue;
        }
        if (phase == UITouchPhaseBegan) {
            [recognizer touchesBegan:touches withEvent:event];
        } else if (phase == UITouchPhaseMoved) {
            [recognizer touchesMoved:touches withEvent:event];
        } else {
            [recognizer touchesEnded:touches withEvent:event];
        }
    }
    for (UIView *subview in [view.subviews copy]) {
        RNHostDeliver(subview, touches, event, phase);
    }
}

static void RNHostSendTouch(UITouch *touch, CGPoint point, UITouchPhase phase, UIWindow *window)
{
    [touch setTimestamp:[NSProcessInfo processInfo].systemUptime];
    [touch setPhase:phase];
    if ([touch respondsToSelector:@selector(_setLocationInWindow:resetPrevious:)]) {
        [touch _setLocationInWindow:point resetPrevious:phase == UITouchPhaseBegan];
    } else {
        // the ivars UIKit reads the location from
        if (phase == UITouchPhaseBegan) {
            [touch setValue:[NSValue valueWithCGPoint:point] forKey:@"_previousLocationInWindow"];
        } else {
            [touch setValue:[touch valueForKey:@"_locationInWindow"] forKey:@"_previousLocationInWindow"];
        }
        [touch setValue:[NSValue valueWithCGPoint:point] forKey:@"_locationInWindow"];
    }
    UIApplication *application = [UIApplication sharedApplication];
    UIEvent *event = [application _touchesEvent];
    [event _setTimestamp:[NSProcessInfo processInfo].systemUptime];
    [event _clearTouches];
    [event _addTouch:touch forDelayedDelivery:NO];
    // -[UIApplication sendEvent:] needs the GSEvent the hardware makes (UIKit reads it and faults on a synthesized event), so
    // the touch goes to the gesture recognizers of the window's views directly, as UIWindow would give it to them.
    NSSet *touches = [NSSet setWithObject:touch];
    RNHostDeliver(window, touches, event, phase);
}

// The deepest view in the tree whose accessibility label is TEXT, found without the clipping of its parents: the view of a
// button the layout put below the screen.
static UIView *RNHostFindLabel(UIView *view, NSString *text)
{
    for (UIView *subview in [view.subviews reverseObjectEnumerator]) {
        UIView *found = RNHostFindLabel(subview, text);
        if (found) {
            return found;
        }
    }
    NSString *label = view.accessibilityLabel;
    return [label isEqualToString:text] ? view : nil;
}

static UIView *RNHostForcedView = nil;

static UITouch *RNHostBeginTouch(CGPoint point, UIWindow *window)
{
    UIView *view = RNHostForcedView ?: [window hitTest:point withEvent:nil];
    UITouch *touch = [[UITouch alloc] init];
    [touch setWindow:window];
    [touch setView:view];
    [touch setTapCount:1];
    [touch setIsTap:YES];
    [touch _setIsFirstTouchForView:YES];
    RNHostSendTouch(touch, point, UITouchPhaseBegan, window);
    return touch;
}

static void RNHostMove(UITouch *touch, UIWindow *window, CGPoint from, CGPoint to, int milliseconds, int step, int steps)
{
    if (step > steps) {
        RNHostSendTouch(touch, to, UITouchPhaseEnded, window);
        RNHostCommandResult(@"ok");
        return;
    }
    CGFloat fraction = (CGFloat)step / steps;
    CGPoint point = CGPointMake(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction);
    RNHostSendTouch(touch, point, UITouchPhaseMoved, window);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((milliseconds / steps) * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        RNHostMove(touch, window, from, to, milliseconds, step + 1, steps);
    });
}

static UIResponder *RNHostFirstResponder(UIView *view)
{
    if ([view isFirstResponder]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        UIResponder *found = RNHostFirstResponder(subview);
        if (found) {
            return found;
        }
    }
    return nil;
}

static void RNHostRun(NSString *line)
{
    NSArray *words = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *verb = words.firstObject;
    UIWindow *window = RNHostKeyWindow();
    if (!window) {
        RNHostCommandResult(@"error: no window");
    } else if ([verb isEqualToString:@"tap"] && words.count >= 3) {
        CGPoint point = CGPointMake([words[1] floatValue], [words[2] floatValue]);
        UITouch *touch = RNHostBeginTouch(point, window);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            RNHostSendTouch(touch, point, UITouchPhaseEnded, window);
            RNHostCommandResult([NSString stringWithFormat:@"ok tap %@ view %@", line, NSStringFromClass([[window hitTest:point withEvent:nil] class])]);
        });
    } else if ([verb isEqualToString:@"taptext"] && line.length > 8) {
        // taptext LABEL: a tap on the view with that accessibility label, wherever the layout put it
        UIView *target = RNHostFindLabel(window, [line substringFromIndex:8]);
        if (!target) {
            RNHostCommandResult(@"error: no view with that label");
        } else {
            CGPoint point = [target convertPoint:CGPointMake(CGRectGetMidX(target.bounds), CGRectGetMidY(target.bounds)) toView:window];
            RNHostForcedView = target;
            UITouch *touch = RNHostBeginTouch(point, window);
            RNHostForcedView = nil;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                RNHostSendTouch(touch, point, UITouchPhaseEnded, window);
                RNHostCommandResult([NSString stringWithFormat:@"ok taptext %@ at %.0f,%.0f", NSStringFromClass([target class]), point.x, point.y]);
            });
        }
    } else if ([verb isEqualToString:@"scroll"] && words.count >= 4) {
        // scroll X Y DY: moves the content of the nearest scroll view under the point by DY points (a pan needs the hardware path)
        CGPoint point = CGPointMake([words[1] floatValue], [words[2] floatValue]);
        UIView *view = [window hitTest:point withEvent:nil];
        while (view && ![view isKindOfClass:[UIScrollView class]]) {
            view = view.superview;
        }
        if ([view isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)view;
            CGFloat maximum = MAX(0, scrollView.contentSize.height - scrollView.bounds.size.height);
            CGFloat offset = MIN(maximum, MAX(0, scrollView.contentOffset.y + [words[3] floatValue]));
            [scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, offset) animated:NO];
            RNHostCommandResult([NSString stringWithFormat:@"ok scroll %@ offset %.0f of %.0f", NSStringFromClass([view class]), offset, maximum]);
        } else {
            RNHostCommandResult(@"error: no scroll view under the point");
        }
    } else if ([verb isEqualToString:@"methods"] && words.count >= 2) {
        // diagnostics: the methods and instance variables of a class, for a release whose private selectors differ
        Class cls = NSClassFromString(words[1]);
        NSMutableString *out = [NSMutableString stringWithFormat:@"%@:", words[1]];
        unsigned count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned i = 0; i < count; i++) {
            [out appendFormat:@" %@", NSStringFromSelector(method_getName(methods[i]))];
        }
        free(methods);
        Ivar *ivars = class_copyIvarList(cls, &count);
        [out appendString:@" | ivars:"];
        for (unsigned i = 0; i < count; i++) {
            [out appendFormat:@" %s", ivar_getName(ivars[i])];
        }
        free(ivars);
        RNHostCommandResult(out);
    } else if ([verb isEqualToString:@"swipe"] && words.count >= 5) {
        CGPoint from = CGPointMake([words[1] floatValue], [words[2] floatValue]);
        CGPoint to = CGPointMake([words[3] floatValue], [words[4] floatValue]);
        int milliseconds = words.count > 5 ? [words[5] intValue] : 300;
        UITouch *touch = RNHostBeginTouch(from, window);
        RNHostMove(touch, window, from, to, milliseconds, 1, 10);
    } else if ([verb isEqualToString:@"text"]) {
        NSString *text = line.length > 5 ? [line substringFromIndex:5] : @"";
        UIResponder *responder = RNHostFirstResponder(window);
        if ([responder conformsToProtocol:@protocol(UIKeyInput)]) {
            [(id<UIKeyInput>)responder insertText:text];
            RNHostCommandResult([NSString stringWithFormat:@"ok text into %@", NSStringFromClass([responder class])]);
        } else {
            RNHostCommandResult(@"error: no first responder takes text");
        }
    } else if ([verb isEqualToString:@"key"] && words.count >= 2 && [words[1] isEqualToString:@"delete"]) {
        UIResponder *responder = RNHostFirstResponder(window);
        if ([responder conformsToProtocol:@protocol(UIKeyInput)]) {
            [(id<UIKeyInput>)responder deleteBackward];
            RNHostCommandResult(@"ok key delete");
        } else {
            RNHostCommandResult(@"error: no first responder takes text");
        }
    } else {
        RNHostCommandResult([@"error: unknown command " stringByAppendingString:line]);
    }
}

@implementation RNHostTouch

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(poll) userInfo:nil repeats:YES];
    }];
}

+ (void)poll
{
    NSString *path = @"/var/tmp/rnhost.cmd";
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (text.length == 0) {
        return;
    }
    // the file is made by another user in a sticky directory, so it is emptied, not removed
    [@"" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (line.length > 0) {
            RNHostRun(line);
        }
    }
}

@end
