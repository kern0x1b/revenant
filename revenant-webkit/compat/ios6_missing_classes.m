#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#import <stdio.h>

@interface CABackdropLayer : CALayer
@end

@interface LSAppLink : NSObject
@end

@interface LSBundleProxy : NSObject
@end

@interface _LSOpenConfiguration : NSObject
@property (nonatomic, retain) NSURL *referrerURL;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"

@implementation NSDateComponentsFormatter
+ (id)alloc
{
    static BOOL said_NSDateComponentsFormatter; if (!said_NSDateComponentsFormatter) { said_NSDateComponentsFormatter = YES; fprintf(stderr, "[ios6] class unavailable: NSDateComponentsFormatter\n"); }
    return [super alloc];
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval
{
    if (!(interval >= 0))
        interval = 0;
    long long total = (long long)(interval + 0.5);
    long long hours = total / 3600;
    long long minutes = (total % 3600) / 60;
    long long seconds = total % 60;

    NSCalendarUnit allowed = self.allowedUnits;
    if (!allowed)
        allowed = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSInteger maxUnits = self.maximumUnitCount;
    if (maxUnits <= 0)
        maxUnits = 3;

    NSMutableArray *parts = [NSMutableArray array];
    if ((allowed & NSCalendarUnitHour) && hours)
        [parts addObject:[NSString stringWithFormat:@"%lld %@", hours, hours == 1 ? @"hour" : @"hours"]];
    if ((allowed & NSCalendarUnitMinute) && (minutes || (parts.count == 0 && !(allowed & NSCalendarUnitSecond))))
        [parts addObject:[NSString stringWithFormat:@"%lld %@", minutes, minutes == 1 ? @"minute" : @"minutes"]];
    if ((allowed & NSCalendarUnitSecond) && (seconds || parts.count == 0))
        [parts addObject:[NSString stringWithFormat:@"%lld %@", seconds, seconds == 1 ? @"second" : @"seconds"]];

    while ((NSInteger)parts.count > maxUnits)
        [parts removeLastObject];
    return [parts componentsJoinedByString:@", "];
}
@end

@implementation NSItemProvider
+ (id)alloc
{
    static BOOL said_NSItemProvider; if (!said_NSItemProvider) { said_NSItemProvider = YES; fprintf(stderr, "[ios6] class unavailable: NSItemProvider\n"); }
    return [super alloc];
}
@end

@implementation NSURLSession
+ (id)alloc
{
    static BOOL said_NSURLSession; if (!said_NSURLSession) { said_NSURLSession = YES; fprintf(stderr, "[ios6] class unavailable: NSURLSession\n"); }
    return [super alloc];
}
@end

@implementation CABackdropLayer
+ (id)alloc
{
    static BOOL said_CABackdropLayer; if (!said_CABackdropLayer) { said_CABackdropLayer = YES; fprintf(stderr, "[ios6] class unavailable: CABackdropLayer\n"); }
    return [super alloc];
}
@end

@implementation LSAppLink
+ (id)alloc
{
    static BOOL said_LSAppLink; if (!said_LSAppLink) { said_LSAppLink = YES; fprintf(stderr, "[ios6] class unavailable: LSAppLink\n"); }
    return [super alloc];
}

+ (void)openWithURL:(NSURL *)url configuration:(id)configuration completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    static BOOL said_LSAppLink_open; if (!said_LSAppLink_open) { said_LSAppLink_open = YES; fprintf(stderr, "[ios6] class unavailable: LSAppLink openWithURL:\n"); }
    (void)url; (void)configuration;
    if (completionHandler)
        completionHandler(NO, nil);
}
@end

@implementation LSBundleProxy
+ (id)alloc
{
    static BOOL said_LSBundleProxy; if (!said_LSBundleProxy) { said_LSBundleProxy = YES; fprintf(stderr, "[ios6] class unavailable: LSBundleProxy\n"); }
    return [super alloc];
}
@end

@implementation NSPresentationIntent
{
    NSInteger _identity;
    NSPresentationIntent *_parentIntent;
}

@synthesize identity = _identity;
@synthesize parentIntent = _parentIntent;

+ (id)alloc
{
    static BOOL said_NSPresentationIntent; if (!said_NSPresentationIntent) { said_NSPresentationIntent = YES; fprintf(stderr, "[ios6] class unavailable: NSPresentationIntent\n"); }
    return [super alloc];
}

+ (instancetype)blockQuoteIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = [[self alloc] init];
    intent->_identity = identity;
    intent->_parentIntent = [parent retain];
    return [intent autorelease];
}

- (void)dealloc
{
    [_parentIntent release];
    [super dealloc];
}
@end

@implementation _LSOpenConfiguration
{
    NSURL *_referrerURL;
}

@synthesize referrerURL = _referrerURL;

+ (id)alloc
{
    fprintf(stderr, "[ios6] class unavailable: _LSOpenConfiguration\n");
    return [super alloc];
}

- (void)dealloc
{
    [_referrerURL release];
    [super dealloc];
}
@end

#pragma clang diagnostic pop

@interface NSProcessInfo (WebKitIOS6Power)
@end

@implementation NSProcessInfo (WebKitIOS6Power)
- (BOOL)isLowPowerModeEnabled { return NO; }
- (NSInteger)thermalState { return 0; /* NSProcessInfoThermalStateNominal */ }
@end

@implementation UITraitCollection

static UITraitCollection *webKitIOS6CurrentTraitCollection;

+ (UITraitCollection *)currentTraitCollection
{
    return webKitIOS6CurrentTraitCollection;
}

+ (void)setCurrentTraitCollection:(UITraitCollection *)collection
{
    if (webKitIOS6CurrentTraitCollection == collection)
        return;
    [webKitIOS6CurrentTraitCollection release];
    webKitIOS6CurrentTraitCollection = [collection retain];
}

@end

@interface CATransaction (WebKitIOS6CommitHandlers)
@end

@implementation CATransaction (WebKitIOS6CommitHandlers)

+ (void)addCommitHandler:(void (^)(void))block forPhase:(unsigned)phase
{
    if (!block)
        return;
    if (phase == 2 /* kCATransactionPhasePostCommit */) {
        void (^copied)(void) = [block copy];
        void (*runOnWebThread)(void (^)(void)) = (void (*)(void (^)(void)))dlsym(RTLD_DEFAULT, "WebThreadRun");
        if (runOnWebThread) {
            runOnWebThread(^{
                copied();
                [copied release];
            });
        } else {
            copied();
            [copied release];
        }
        return;
    }
    block();
}

@end

@interface CADisplayLink (WebKitIOS6FrameRate)
@end

@implementation CADisplayLink (WebKitIOS6FrameRate)

- (NSInteger)preferredFramesPerSecond
{
    NSInteger interval = [self frameInterval];
    return interval > 0 ? 60 / interval : 60;
}

- (void)setPreferredFramesPerSecond:(NSInteger)framesPerSecond
{
    [self setFrameInterval:framesPerSecond > 0 ? MAX(1, 60 / framesPerSecond) : 1];
}

@end
