#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <fcntl.h>
#import <pthread.h>
#import <signal.h>
#import <unistd.h>
#import "RNHostFiles.h"
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
    NSString *path = RNHostRunPath(@"rnhost.cmd.out");
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
    NSSet *touches = [NSSet setWithObject:touch];
    RNHostDeliver(window, touches, event, phase);
}

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

static volatile time_t RNHostTick;
static pthread_t RNHostMainThread;

static void RNHostStackHandler(int signal)
{
    void *frames[64];
    int count = backtrace(frames, 64);
    int fd = open(RNHostRunPath(@"rnhost.stack").fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd >= 0) {
        char name[64] = "";
        pthread_getname_np(pthread_self(), name, sizeof(name));
        write(fd, "---- ", 5);
        write(fd, name, strlen(name));
        write(fd, "\n", 1);
        backtrace_symbols_fd(frames, count, fd);
        close(fd);
    }
}

#import <mach/mach.h>

static void *RNHostProfiler(void *unused)
{
    for (;;) {
        usleep(100000);
        if (!RNHostAppFileExists(@"rnhost.prof")) {
            continue;
        }
        thread_act_array_t threads;
        mach_msg_type_number_t count = 0;
        if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS) {
            continue;
        }
        FILE *out = fopen(RNHostRunPath(@"rnhost.prof.out").fileSystemRepresentation, "a");
        if (out) {
            fprintf(out, "t=%.1f", CFAbsoluteTimeGetCurrent() - 0);
            for (mach_msg_type_number_t i = 0; i < count; i++) {
                thread_basic_info_data_t info;
                mach_msg_type_number_t size = THREAD_BASIC_INFO_COUNT;
                if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info, &size) == KERN_SUCCESS && info.cpu_usage > 50) {
                    if (RNHostAppFileExists(@"rnhost.prof.stacks")) {
                        pthread_t target = pthread_from_mach_thread_np(threads[i]);
                        if (target) {
                            pthread_kill(target, SIGUSR1);
                        }
                    }
                    char name[64] = "";
                    pthread_t thread = pthread_from_mach_thread_np(threads[i]);
                    if (thread) {
                        pthread_getname_np(thread, name, sizeof(name));
                    }
                    fprintf(out, " [%u %s %d%%]", threads[i], name, info.cpu_usage / 10);
                }
            }
            fprintf(out, "\n");
            fclose(out);
        }
        for (mach_msg_type_number_t i = 0; i < count; i++) {
            mach_port_deallocate(mach_task_self(), threads[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_t));
    }
    return NULL;
}

static void *RNHostWatchdog(void *unused)
{
    time_t reported = 0;
    pthread_t profiler;
    pthread_create(&profiler, NULL, RNHostProfiler, NULL);
    for (;;) {
        sleep(2);
        time_t tick = RNHostTick;
        if (tick != 0 && time(NULL) - tick > 10 && reported != tick) {
            reported = tick;
            pthread_kill(RNHostMainThread, SIGUSR1);
        }
    }
    return NULL;
}

@implementation RNHostTouch

+ (void)load
{
    NSString *interval = RNHostReadAppText(@"rnhost.fi");
    if (interval.integerValue > 1) {
        static NSInteger forced;
        forced = interval.integerValue;
        Class link = NSClassFromString(@"CADisplayLink");
        Method original = class_getInstanceMethod(link, @selector(addToRunLoop:forMode:));
        __block IMP originalImp = method_getImplementation(original);
        method_setImplementation(original, imp_implementationWithBlock(^(id self, NSRunLoop *loop, NSString *mode) {
            [(CADisplayLink *)self setFrameInterval:forced];
            ((void (*)(id, SEL, id, id))originalImp)(self, @selector(addToRunLoop:forMode:), loop, mode);
        }));
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        RNHostMainThread = pthread_self();
        RNHostTick = time(NULL);
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        signal(SIGUSR1, RNHostStackHandler);
        pthread_t watchdog;
        pthread_create(&watchdog, NULL, RNHostWatchdog, NULL);
        [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(poll) userInfo:nil repeats:YES];
    }];
}

static dev_t RNHostCommandDevice;
static ino_t RNHostCommandInode;
static NSString *RNHostCommandDone = @"";

static void RNHostRunNewCommands(NSData *data, struct stat info)
{
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return;
    NSRange newline = [text rangeOfString:@"\n" options:NSBackwardsSearch];
    NSString *complete = newline.location == NSNotFound ? @"" : [text substringToIndex:newline.location + 1];
    BOOL same = info.st_dev == RNHostCommandDevice && info.st_ino == RNHostCommandInode && [complete hasPrefix:RNHostCommandDone];
    NSString *fresh = same ? [complete substringFromIndex:RNHostCommandDone.length] : complete;
    RNHostCommandDevice = info.st_dev;
    RNHostCommandInode = info.st_ino;
    RNHostCommandDone = complete;
    for (NSString *line in [fresh componentsSeparatedByString:@"\n"]) {
        if (line.length > 0) {
            RNHostRun(line);
        }
    }
}

+ (void)poll
{
    RNHostTick = time(NULL);
    struct stat info;
    NSData *data = RNHostReadAppFile(@"rnhost.cmd", &info);
    if (data.length > 0) {
        RNHostRunNewCommands(data, info);
    }
}

@end
