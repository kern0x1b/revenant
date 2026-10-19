// probe.m - the reader sessions of CoreNFC, asked what they answer on a device with no radio: the initializers for each kind of
// delegate, the properties, and the callback a begun session makes. The same source is built for the host (Catalyst, where the
// classes are CoreNFC's) and for the port (the classes of CoreNFC/NFCReaderSession.m, renamed CharonHost<Name>).
//
// The classes are found by name at run time and every answer is read through its selector, so no header decides it. A callback
// is counted after the run loop has turned, and a session is kept alive where the callback is wanted: the framework does not
// keep a session that nothing holds, and that is measured too (the last case).
//
//   sh run.sh
#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>

#ifdef PORT
#define PREFIX "CharonHost"
#else
#define PREFIX ""
#endif

static void *kQueue = &kQueue;
static int calls = 0;
static int onCustomQueue = 0;
static long lastCode = -1;
static NSString *lastDomain = @"-";

static Class sessionClass(const char *name)
{
    return NSClassFromString([NSString stringWithFormat:@"%s%s", PREFIX, name]);
}

static BOOL askBOOL(id target, NSString *selector)
{
    return ((BOOL (*)(id, SEL))objc_msgSend)(target, NSSelectorFromString(selector));
}

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static void spinUntilCalled(NSTimeInterval limit)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:limit];
    while (calls == 0 && [until timeIntervalSinceNow] > 0) {
        spin(0.05);
    }
}

// Each delegate has the methods one case needs, and no more.
@interface FullDelegate : NSObject
@end
@implementation FullDelegate
- (void)readerSession:(id)session didDetectNDEFs:(NSArray *)messages {}
- (void)readerSessionDidBecomeActive:(id)session {}
- (void)readerSession:(id)session didInvalidateWithError:(NSError *)error
{
    calls++;
    lastCode = error.code;
    lastDomain = error.domain;
    onCustomQueue = dispatch_get_specific(kQueue) != NULL;
}
@end

@interface NDEFOnlyDelegate : NSObject
@end
@implementation NDEFOnlyDelegate
- (void)readerSession:(id)session didDetectNDEFs:(NSArray *)messages {}
@end

@interface InvalidOnlyDelegate : NSObject
@end
@implementation InvalidOnlyDelegate
- (void)readerSession:(id)session didInvalidateWithError:(NSError *)error {}
@end

@interface BecomeOnlyDelegate : NSObject
@end
@implementation BecomeOnlyDelegate
- (void)readerSessionDidBecomeActive:(id)session {}
@end

static void line(const char *label, id object)
{
    printf("%s %s\n", label, object ? "object" : "nil");
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class base = sessionClass("NFCReaderSession");
        Class ndef = sessionClass("NFCNDEFReaderSession");
        Class iso = sessionClass("NFCISO15693ReaderSession");
        printf("classes %d %d %d\n", base != nil, ndef != nil, iso != nil);
        printf("superclass ndef is base %d, iso is base %d\n",
               class_getSuperclass(ndef) == base, class_getSuperclass(iso) == base);
        printf("readingAvailable base %d ndef %d iso %d\n",
               askBOOL(base, @"readingAvailable"), askBOOL(ndef, @"readingAvailable"), askBOOL(iso, @"readingAvailable"));

        NSMutableArray *keep = [NSMutableArray array];
        FullDelegate *full = [[FullDelegate alloc] init];

        line("ndef init full delegate", [[(id)ndef alloc] initWithDelegate:full queue:nil invalidateAfterFirstRead:NO]);
        line("ndef init ndef-only delegate", [[(id)ndef alloc] initWithDelegate:[[NDEFOnlyDelegate alloc] init] queue:nil invalidateAfterFirstRead:NO]);
        line("ndef init invalid-only delegate", [[(id)ndef alloc] initWithDelegate:[[InvalidOnlyDelegate alloc] init] queue:nil invalidateAfterFirstRead:NO]);
        line("ndef init nil delegate", [[(id)ndef alloc] initWithDelegate:nil queue:nil invalidateAfterFirstRead:NO]);
        line("iso init become-only delegate", [[(id)iso alloc] initWithDelegate:[[BecomeOnlyDelegate alloc] init] queue:nil]);
        line("iso init invalid-only delegate", [[(id)iso alloc] initWithDelegate:[[InvalidOnlyDelegate alloc] init] queue:nil]);
        line("iso init nil delegate", [[(id)iso alloc] initWithDelegate:nil queue:nil]);

        // The session the properties and the callbacks are asked of: nil queue, the framework's own.
        id s1 = [[(id)ndef alloc] initWithDelegate:full queue:nil invalidateAfterFirstRead:NO];
        [keep addObject:s1];
        printf("ready %d\n", askBOOL(s1, @"isReady"));
        printf("alertMessage default %s\n", [s1 valueForKey:@"alertMessage"] ? "set" : "nil");
        [s1 setValue:@"Hold near a tag" forKey:@"alertMessage"];
        printf("alertMessage after set %s\n", [[s1 valueForKey:@"alertMessage"] UTF8String]);
        printf("delegate is the delegate %d\n", [s1 valueForKey:@"delegate"] == full);
        printf("sessionQueue set %d\n", [s1 valueForKey:@"sessionQueue"] != nil);
        printf("responds setDelegate %d, setAlertMessage %d, isReady %d, ready %d\n",
               [ndef instancesRespondToSelector:@selector(setDelegate:)],
               [ndef instancesRespondToSelector:@selector(setAlertMessage:)],
               [ndef instancesRespondToSelector:@selector(isReady)],
               [ndef instancesRespondToSelector:NSSelectorFromString(@"ready")]);

        // A begun session calls back with the unsupported-feature error, on the queue it was given; an invalidate after the
        // begin calls back again; a second begin calls back again.
        dispatch_queue_t queue = dispatch_queue_create("charon.nfc.test", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue, kQueue, (void *)kQueue, NULL);
        id s2 = [[(id)ndef alloc] initWithDelegate:full queue:queue invalidateAfterFirstRead:NO];
        [keep addObject:s2];
        printf("sessionQueue is the queue given %d\n", [s2 valueForKey:@"sessionQueue"] == queue);
        calls = 0;
        [s2 beginSession];
        spinUntilCalled(3.0);
        printf("begin: calls %d, domain %s, code %ld, on the queue given %d\n", calls, [lastDomain UTF8String], lastCode, onCustomQueue);
        calls = 0;
        [s2 invalidateSession];
        spinUntilCalled(3.0);
        printf("invalidate after begin: calls %d, code %ld\n", calls, lastCode);
        calls = 0;
        [s2 beginSession];
        spinUntilCalled(3.0);
        printf("second begin: calls %d\n", calls);

        // A session invalidated before it is begun is dead: the begin that follows calls nothing.
        id s6 = [[(id)ndef alloc] initWithDelegate:full queue:nil invalidateAfterFirstRead:NO];
        [keep addObject:s6];
        calls = 0;
        [s6 invalidateSession];
        spin(0.5);
        printf("invalidate before begin: calls %d\n", calls);
        [s6 beginSession];
        spin(1.0);
        printf("begin after invalidate: calls %d\n", calls);

        // The delegate is held weakly: once it is gone, the session answers nil for it.
        id s3 = nil;
        @autoreleasepool {
            FullDelegate *gone = [[FullDelegate alloc] init];
            s3 = [[(id)ndef alloc] initWithDelegate:gone queue:nil invalidateAfterFirstRead:NO];
            printf("delegate before release %d\n", [s3 valueForKey:@"delegate"] == gone);
        }
        printf("delegate after release nil %d\n", [s3 valueForKey:@"delegate"] == nil);
        [keep addObject:s3];

        // A session nothing holds is not kept by the framework, so its callback is not made.
        calls = 0;
        @autoreleasepool {
            id s4 = [[(id)ndef alloc] initWithDelegate:full queue:nil invalidateAfterFirstRead:NO];
            [s4 beginSession];
        }
        spin(1.0);
        printf("unheld session: calls %d\n", calls);

        printf("NFCErrorDomain %s\n", [NFCErrorDomain UTF8String]);
        printf("NFCReaderErrorUnsupportedFeature %ld\n", (long)NFCReaderErrorUnsupportedFeature);
        printf("NFCISO15693TagResponseErrorKey %s\n", [NFCISO15693TagResponseErrorKey UTF8String]);
    }
    return 0;
}
