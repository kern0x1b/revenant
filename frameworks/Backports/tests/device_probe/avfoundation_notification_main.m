#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

static NSString *const PROBE_LOG = @"/var/revenant/avf-notification-probe.txt";
static BOOL constructor_done = NO;
static BOOL load_before_constructor = NO;
static NSString *load_value = nil;

__attribute__((constructor)) static void probe_constructor(void)
{
    constructor_done = YES;
}

@interface RevenantNotificationProbe : NSObject
@end

@implementation RevenantNotificationProbe

+ (void)load
{
    load_before_constructor = !constructor_done;
    load_value = [AVCaptureSessionDidStartRunningNotification copy];
}

+ (void)worker:(id)argument
{
    (void)argument;
}

@end

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSMutableString *log = [NSMutableString string];
        BOOL system_value = [load_value isEqualToString:@"AVCaptureSessionDidStartRunningNotification"];
        [log appendFormat:@"+load runs before the C constructor of this image: %@\n", load_before_constructor ? @"YES" : @"NO"];
        [log appendFormat:@"constant in +load: %@ (system value: %@)\n", load_value ?: @"(nil)", system_value ? @"YES" : @"NO"];
        [log appendFormat:@"constant in main: %@\n", AVCaptureSessionDidStartRunningNotification ?: @"(nil)"];
        [NSThread detachNewThreadSelector:@selector(worker:) toTarget:[RevenantNotificationProbe class] withObject:nil];
        NSLog(@"posting NSWillBecomeMultiThreadedNotification with the NSThread object");
        [[NSNotificationCenter defaultCenter] postNotificationName:NSWillBecomeMultiThreadedNotification object:[NSThread currentThread]];
        [NSThread sleepForTimeInterval:0.5];
        [log appendFormat:@"multithreaded after detach: %@\n", [NSThread isMultiThreaded] ? @"YES" : @"NO"];
        [log appendString:@"verdict: no crash after NSWillBecomeMultiThreadedNotification\n"];
        [log writeToFile:PROBE_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSLog(@"%@", log);
    }
    return 0;
}
