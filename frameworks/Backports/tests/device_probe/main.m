#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#ifdef REVENANT_PROBE_SCENEKIT
#import <SceneKit/SceneKit.h>
#endif
#import <SystemConfiguration/SystemConfiguration.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_types.h>
#import <netinet/in.h>
#import <sys/socket.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *const REVENANT_PROBE_LOG = @"/var/revenant/device-probe.txt";

static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_line(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [REVENANT_LOG appendFormat:@"%@\n", line];
}

static void revenant_check(BOOL ok, NSString *name)
{
    if (!ok)
        REVENANT_FAILURES++;
    revenant_line(@"%@ %@", ok ? @"PASS" : @"FAIL", name);
}

static void revenant_animation_checks(void)
{
    revenant_check([UIView inheritedAnimationDuration] == 0, @"inheritedAnimationDuration is zero outside an animation");

    __block NSTimeInterval outer = -1, inner = -1, restored = -1;
    [UIView animateWithDuration:0.5 animations:^{
        outer = [UIView inheritedAnimationDuration];
        [UIView animateWithDuration:0.25 animations:^{
            inner = [UIView inheritedAnimationDuration];
        }];
        restored = [UIView inheritedAnimationDuration];
    }];
    revenant_check(outer == 0.5, @"animateWithDuration:0.5 reports 0.5 inside its block");
    revenant_check(inner == 0.25, @"a nested animateWithDuration:0.25 reports 0.25 inside its block");
    revenant_check(restored == 0.5, @"the outer duration is restored after the nested block");
    revenant_check([UIView inheritedAnimationDuration] == 0, @"inheritedAnimationDuration is zero after the animation");

    __block NSTimeInterval keyframe = -1;
    [UIView animateKeyframesWithDuration:0.4 delay:0 options:0 animations:^{
        keyframe = [UIView inheritedAnimationDuration];
    } completion:nil];
    revenant_check(keyframe == 0.4, @"animateKeyframesWithDuration:0.4 reports 0.4 inside its block");

    [UIView beginAnimations:@"revenant" context:NULL];
    [UIView setAnimationDuration:0.3];
    NSTimeInterval classic = [UIView inheritedAnimationDuration];
    [UIView commitAnimations];
    revenant_check(classic == 0.3, @"beginAnimations with setAnimationDuration:0.3 reports 0.3");
    revenant_check([UIView inheritedAnimationDuration] == 0, @"commitAnimations pops the duration");
}

static void revenant_repeat_checks(UIWindow *window)
{
    BOOL modifies = [UIView respondsToSelector:@selector(modifyAnimationsWithRepeatCount:autoreverses:animations:)];
    revenant_check(modifies, @"+modifyAnimationsWithRepeatCount:autoreverses:animations: exists on iOS 6 through the backport");
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    [window addSubview:view];
    [UIView beginAnimations:@"revenant.repeat" context:NULL];
    [UIView setAnimationDuration:1];
    [UIView setAnimationRepeatCount:3];
    [UIView setAnimationRepeatAutoreverses:NO];
    if (modifies) {
        [UIView modifyAnimationsWithRepeatCount:5 autoreverses:YES animations:^{
            view.center = CGPointMake(50, 50);
        }];
    }
    view.bounds = CGRectMake(0, 0, 20, 20);
    [UIView commitAnimations];
    BOOL inside = NO, enclosing = NO;
    for (NSString *key in view.layer.animationKeys) {
        CAAnimation *animation = [view.layer animationForKey:key];
        if (![animation isKindOfClass:[CABasicAnimation class]])
            continue;
        CABasicAnimation *basic = (CABasicAnimation *)animation;
        revenant_line(@"INFO repeat key %@ count %g autoreverses %d", key, basic.repeatCount, basic.autoreverses);
        if (fabsf(basic.repeatCount - 5) < 0.001 && basic.autoreverses)
            inside = YES;
        if (fabsf(basic.repeatCount - 3) < 0.001 && !basic.autoreverses)
            enclosing = YES;
    }
    revenant_check(inside, @"modifyAnimationsWithRepeatCount:5 autoreverses:YES gives the animations inside the block 5 and autoreverse");
    revenant_check(enclosing, @"the enclosing group's repeat count 3 without autoreverse is put back after the block");
    [view removeFromSuperview];
}

static void revenant_text_checks(void)
{
    UITextField *field = [[UITextField alloc] init];
    UITextInputMode *current = [UITextInputMode currentInputMode];
    UITextInputMode *mode = [field textInputMode];
    revenant_check(mode != nil, @"textInputMode is not nil");
    revenant_check([mode.primaryLanguage isEqualToString:current.primaryLanguage], @"textInputMode has the current primary language");
    revenant_line(@"INFO primaryLanguage %@ same object %d", current.primaryLanguage, mode == current);

    UITextField *code = [[UITextField alloc] init];
    revenant_check(code.keyboardType == UIKeyboardTypeDefault, @"a new field has the default keyboard");
    [code setValue:@"oneTimeCode" forKey:@"textContentType"];
    revenant_check(code.keyboardType == UIKeyboardTypeNumberPad, @"oneTimeCode sets the number pad keyboard");
    revenant_check([[code valueForKey:@"textContentType"] isEqualToString:@"oneTimeCode"], @"textContentType reads back oneTimeCode");
    UITextField *chosen = [[UITextField alloc] init];
    chosen.keyboardType = UIKeyboardTypeURL;
    [chosen setValue:@"oneTimeCode" forKey:@"textContentType"];
    revenant_check(chosen.keyboardType == UIKeyboardTypeURL, @"an explicit keyboard type is kept under oneTimeCode");
}

static void revenant_metal_checks(UIWindow *window)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    revenant_check(device != nil, @"MTLCreateSystemDefaultDevice returns a device");
    if (!device)
        return;

    id<MTLBuffer> buffer = [device newBufferWithLength:256 options:MTLResourceStorageModeShared];
    MTLPurgeableState first = [buffer setPurgeableState:MTLPurgeableStateVolatile];
    MTLPurgeableState second = [buffer setPurgeableState:MTLPurgeableStateKeepCurrent];
    revenant_check(first == MTLPurgeableStateNonVolatile, @"setPurgeableState returns the previous state, NonVolatile for a new buffer");
    revenant_check(second == MTLPurgeableStateVolatile, @"KeepCurrent returns Volatile, the state set before it");

    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.frame = CGRectMake(0, 0, 64, 64);
    [window.layer addSublayer:layer];
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    revenant_check(drawable != nil, @"nextDrawable returns a drawable");
    if (!drawable)
        return;

    __block BOOL presented = NO;
    __block id<MTLDrawable> received = nil;
    [drawable addPresentedHandler:^(id<MTLDrawable> presentedDrawable) {
        presented = YES;
        received = presentedDrawable;
    }];
    [drawable present];
    revenant_check(presented, @"the presented handler runs after present");
    revenant_check(received == drawable, @"the presented handler receives the drawable");
    revenant_check([drawable drawableID] > 0, @"drawableID is set");
    revenant_check([drawable presentedTime] > 0, @"presentedTime is set after present");
}

static CFTimeInterval REVENANT_REQUESTED_AT;
static CFTimeInterval REVENANT_PRESENTED_AT;
static BOOL REVENANT_TIMED_PRESENTED;

static void revenant_paragraph_checks(void)
{
    NSParagraphStyle *defaults = [NSParagraphStyle defaultParagraphStyle];
    revenant_check(!defaults.allowsDefaultTighteningForTruncation, @"NSParagraphStyle does not tighten before truncation by default");
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    revenant_check(!style.allowsDefaultTighteningForTruncation, @"a new NSMutableParagraphStyle does not tighten before truncation");
    style.allowsDefaultTighteningForTruncation = YES;
    revenant_check(style.allowsDefaultTighteningForTruncation, @"an NSMutableParagraphStyle keeps allowsDefaultTighteningForTruncation");
    NSParagraphStyle *copied = [style copy];
    revenant_check(copied.allowsDefaultTighteningForTruncation, @"a copy of the style keeps allowsDefaultTighteningForTruncation");
}

static NSData *revenant_label_image(NSString *string, NSAttributedString *attributed, CGFloat width, BOOL tightening)
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, 30)];
    label.font = [UIFont systemFontOfSize:17];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.numberOfLines = 1;
    label.allowsDefaultTighteningForTruncation = tightening;
    if (attributed)
        label.attributedText = attributed;
    else
        label.text = string;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, 30), NO, 1);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImagePNGRepresentation(image);
}

static NSData *revenant_label_pixels(UIImage *image, NSUInteger width, NSUInteger height)
{
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

static void revenant_ink_report(NSString *name, NSData *pixels, NSUInteger width, NSUInteger height)
{
    const unsigned char *bytes = pixels.bytes;
    NSUInteger left = width, right = 0, top = height, bottom = 0;
    for (NSUInteger y = 0; y < height; y++) {
        for (NSUInteger x = 0; x < width; x++) {
            if (bytes[(y * width + x) * 4 + 3] > 16) {
                if (x < left)
                    left = x;
                if (x > right)
                    right = x;
                if (y < top)
                    top = y;
                if (y > bottom)
                    bottom = y;
            }
        }
    }
    revenant_line(@"INFO ink %@ x %lu..%lu y %lu..%lu", name, (unsigned long)left, (unsigned long)right, (unsigned long)top, (unsigned long)bottom);
}

static void revenant_label_checks(void)
{
    NSString *string = @"Tightening the spacing before the label truncates the line";
    UIFont *font = [UIFont systemFontOfSize:17];
    CGFloat full = [[[NSAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: font}] size].width;
    NSData *plain = revenant_label_image(string, nil, full - 6, NO);
    NSData *tightened = revenant_label_image(string, nil, full - 6, YES);
    revenant_check(plain.length > 0 && tightened.length > 0, @"a label renders with and without tightening");
    revenant_check(![tightened isEqualToData:plain], @"a label that allows tightening draws a line that fits, not the truncated one");
    NSData *overflow = revenant_label_image(string, nil, full * 0.5, YES);
    NSData *overflowPlain = revenant_label_image(string, nil, full * 0.5, NO);
    revenant_check([overflow isEqualToData:overflowPlain], @"an overflow over the cap truncates as it does without tightening");
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    style.allowsDefaultTighteningForTruncation = YES;
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: font, NSParagraphStyleAttributeName: style}];
    NSData *styled = revenant_label_image(nil, attributed, full - 6, NO);
    revenant_line(@"INFO label png bytes plain %lu tightened %lu styled %lu", (unsigned long)plain.length, (unsigned long)tightened.length, (unsigned long)styled.length);
    UIImage *tightenedImage = [UIImage imageWithData:tightened];
    UIImage *styledImage = [UIImage imageWithData:styled];
    NSUInteger width = (NSUInteger)tightenedImage.size.width;
    NSUInteger height = (NSUInteger)tightenedImage.size.height;
    NSData *tightenedPixels = revenant_label_pixels(tightenedImage, width, height);
    NSData *styledPixels = revenant_label_pixels(styledImage, width, height);
    const unsigned char *a = tightenedPixels.bytes;
    const unsigned char *b = styledPixels.bytes;
    NSUInteger differing = 0;
    int worst = 0;
    for (NSUInteger index = 0; index < width * height; index++) {
        int pixelWorst = 0;
        for (int channel = 0; channel < 4; channel++) {
            int delta = (int)a[index * 4 + channel] - (int)b[index * 4 + channel];
            if (delta < 0)
                delta = -delta;
            if (delta > pixelWorst)
                pixelWorst = delta;
        }
        if (pixelWorst > 0)
            differing++;
        if (pixelWorst > worst)
            worst = pixelWorst;
    }
    revenant_line(@"INFO styled against tightened %lux%lu: %lu pixels differ, worst channel delta %d", (unsigned long)width, (unsigned long)height, (unsigned long)differing, worst);
    revenant_ink_report(@"plain", revenant_label_pixels([UIImage imageWithData:plain], width, height), width, height);
    revenant_ink_report(@"tightened", tightenedPixels, width, height);
    revenant_ink_report(@"styled", styledPixels, width, height);
    revenant_check([styled isEqualToData:tightened], @"a paragraph style that allows tightening tightens the label as the label property does");
}

static void revenant_present_timed_start(UIWindow *window)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device)
        return;
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.frame = CGRectMake(0, 0, 64, 64);
    [window.layer addSublayer:layer];
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    if (!drawable)
        return;
    REVENANT_REQUESTED_AT = CACurrentMediaTime() + 0.5;
    [drawable addPresentedHandler:^(id<MTLDrawable> presentedDrawable) {
        id<CAMetalDrawable> shown = (id<CAMetalDrawable>)presentedDrawable;
        REVENANT_PRESENTED_AT = [shown presentedTime];
        REVENANT_TIMED_PRESENTED = YES;
    }];
    [drawable presentAtTime:REVENANT_REQUESTED_AT];
    revenant_check(!REVENANT_TIMED_PRESENTED, @"presentAtTime does not present before the requested time");
}

static CFTimeInterval REVENANT_FIRST_PRESENTED;
static CFTimeInterval REVENANT_MINIMUM_PRESENTED;
static BOOL REVENANT_MINIMUM_DONE;

static void revenant_present_minimum_start(UIWindow *window)
{
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device)
        return;
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = device;
    layer.frame = CGRectMake(0, 0, 64, 64);
    [window.layer addSublayer:layer];
    id<CAMetalDrawable> first = [layer nextDrawable];
    if (!first)
        return;
    [first present];
    REVENANT_FIRST_PRESENTED = [first presentedTime];
    id<CAMetalDrawable> second = [layer nextDrawable];
    if (!second)
        return;
    [second addPresentedHandler:^(id<MTLDrawable> presentedDrawable) {
        id<CAMetalDrawable> shown = (id<CAMetalDrawable>)presentedDrawable;
        REVENANT_MINIMUM_PRESENTED = [shown presentedTime];
        REVENANT_MINIMUM_DONE = YES;
    }];
    [second presentAfterMinimumDuration:0.5];
    revenant_check(!REVENANT_MINIMUM_DONE, @"presentAfterMinimumDuration does not present at once after a previous presentation");
}

static void revenant_present_minimum_finish(void)
{
    revenant_check(REVENANT_MINIMUM_DONE, @"presentAfterMinimumDuration presents once the minimum duration has passed");
    revenant_check(REVENANT_MINIMUM_DONE && REVENANT_MINIMUM_PRESENTED - REVENANT_FIRST_PRESENTED >= 0.5, @"presentAfterMinimumDuration presents no earlier than the duration after the previous presentation on the layer");
}

static void revenant_present_timed_finish(void)
{
    revenant_check(REVENANT_TIMED_PRESENTED, @"presentAtTime presents once the requested time has come");
    revenant_check(REVENANT_TIMED_PRESENTED && REVENANT_PRESENTED_AT >= REVENANT_REQUESTED_AT, @"presentAtTime presents no earlier than the requested time");
}

#ifdef REVENANT_PROBE_SCENEKIT

static const int REVENANT_JITTER_SIDE = 128;

static NSData *revenant_snapshot_pixels(UIImage *image)
{
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)(REVENANT_JITTER_SIDE * REVENANT_JITTER_SIDE * 4)];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, REVENANT_JITTER_SIDE, REVENANT_JITTER_SIDE, 8, REVENANT_JITTER_SIDE * 4,
                                                 space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, REVENANT_JITTER_SIDE, REVENANT_JITTER_SIDE), image.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

static int revenant_edge_count(NSData *pixels)
{
    const unsigned char *bytes = pixels.bytes;
    int count = 0;
    for (int index = 0; index < REVENANT_JITTER_SIDE * REVENANT_JITTER_SIDE; index++) {
        unsigned char alpha = bytes[index * 4 + 3];
        if (alpha > 16 && alpha < 239)
            count++;
    }
    return count;
}

static int revenant_centre_difference(NSData *first, NSData *second)
{
    const unsigned char *a = first.bytes;
    const unsigned char *b = second.bytes;
    int centre = (REVENANT_JITTER_SIDE / 2) * REVENANT_JITTER_SIDE + REVENANT_JITTER_SIDE / 2;
    int worst = 0;
    for (int channel = 0; channel < 4; channel++) {
        int delta = (int)a[centre * 4 + channel] - (int)b[centre * 4 + channel];
        if (delta < 0)
            delta = -delta;
        if (delta > worst)
            worst = delta;
    }
    return worst;
}

static UIImage *revenant_snapshot_after(SCNView *view, int frames)
{
    UIImage *image = nil;
    for (int frame = 0; frame < frames; frame++)
        image = [view snapshot];
    return image;
}

static void revenant_jitter_checks(void)
{
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.camera = [[SCNCamera alloc] init];
    camera.position = SCNVector3Make(0, 0, 5);
    [scene.rootNode addChildNode:camera];
    SCNNode *plane = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:2 height:2]];
    plane.eulerAngles = SCNVector3Make(0, 0, 0.4);
    [scene.rootNode addChildNode:plane];
    SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, REVENANT_JITTER_SIDE, REVENANT_JITTER_SIDE)];
    view.contentScaleFactor = 1;
    view.scene = scene;
    view.pointOfView = camera;

    UIImage *plainImage = [view snapshot];
    revenant_check(plainImage != nil, @"an SCNView snapshot renders on the device");
    if (!plainImage)
        return;
    NSData *plain = revenant_snapshot_pixels(plainImage);
    view.jitteringEnabled = YES;
    NSData *jittered = revenant_snapshot_pixels(revenant_snapshot_after(view, 8));
    int plainEdges = revenant_edge_count(plain);
    int jitteredEdges = revenant_edge_count(jittered);
    int stillCentre = revenant_centre_difference(plain, jittered);
    revenant_line(@"INFO jitter still plain edges %d jittered edges %d centre difference %d", plainEdges, jitteredEdges, stillCentre);
    revenant_check(jitteredEdges > 20 && jitteredEdges > plainEdges * 2, @"jittering smooths the edges of a still plane on the device");
    revenant_check(stillCentre <= 3, @"the interior of a still plane is the same with jittering on the device");

    plane.eulerAngles = SCNVector3Make(0, 0, 0.9);
    NSData *firstChanged = revenant_snapshot_pixels([view snapshot]);
    SCNView *fresh = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, REVENANT_JITTER_SIDE, REVENANT_JITTER_SIDE)];
    fresh.contentScaleFactor = 1;
    fresh.scene = scene;
    fresh.pointOfView = camera;
    fresh.jitteringEnabled = YES;
    NSData *freshSample = revenant_snapshot_pixels([fresh snapshot]);
    NSData *settledChanged = revenant_snapshot_pixels(revenant_snapshot_after(view, 8));
    int firstEdges = revenant_edge_count(firstChanged);
    int freshEdges = revenant_edge_count(freshSample);
    int settledEdges = revenant_edge_count(settledChanged);
    revenant_line(@"INFO jitter animated first frame edges %d fresh single sample edges %d settled edges %d", firstEdges, freshEdges, settledEdges);
    revenant_check(firstEdges <= freshEdges + 4, @"a frame after the plane turns is one jittered sample, with no blend of the old angle");
    revenant_check(settledEdges > firstEdges, @"the accumulation builds again at the new angle");
}

#endif

static void revenant_network_facts(void)
{
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&address);
    SCNetworkReachabilityFlags flags = 0;
    BOOL read = reachability != NULL && SCNetworkReachabilityGetFlags(reachability, &flags);
    revenant_check(read, @"SCNetworkReachability reads the default route flags");
    revenant_line(@"INFO reachability flags 0x%x reachable %d wwan %d", (unsigned)flags,
                  (flags & kSCNetworkReachabilityFlagsReachable) != 0, (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0);
    if (reachability)
        CFRelease(reachability);

    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0)
        return;
    for (struct ifaddrs *entry = list; entry != NULL; entry = entry->ifa_next) {
        if (!(entry->ifa_flags & IFF_UP) || !entry->ifa_addr)
            continue;
        if (entry->ifa_addr->sa_family == AF_LINK && entry->ifa_data) {
            revenant_line(@"INFO link %s ifi_type %u", entry->ifa_name, (unsigned)((struct if_data *)entry->ifa_data)->ifi_type);
        }
        if (entry->ifa_addr->sa_family == AF_INET) {
            BOOL routable = ((struct sockaddr_in *)entry->ifa_addr)->sin_addr.s_addr != 0;
            revenant_line(@"INFO inet %s has address %d", entry->ifa_name, routable);
        }
    }
    freeifaddrs(list);
}

@interface RevenantProbeDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantProbeDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(revenantRun) withObject:nil afterDelay:1.0];
    return YES;
}

- (void)revenantRun
{
    REVENANT_LOG = [NSMutableString string];
    revenant_line(@"INFO %@ iOS %@", [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]);
    revenant_animation_checks();
    revenant_repeat_checks(self.window);
    revenant_text_checks();
    revenant_paragraph_checks();
    revenant_label_checks();
    revenant_metal_checks(self.window);
    revenant_present_timed_start(self.window);
    revenant_present_minimum_start(self.window);
#ifdef REVENANT_PROBE_SCENEKIT
    revenant_jitter_checks();
#endif
    revenant_network_facts();
    [self performSelector:@selector(revenantFinish) withObject:nil afterDelay:1.5];
}

- (void)revenantFinish
{
    revenant_present_timed_finish();
    revenant_present_minimum_finish();
    revenant_line(@"REVENANT-DONE failures %lu", (unsigned long)REVENANT_FAILURES);
    [REVENANT_LOG writeToFile:REVENANT_PROBE_LOG atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    exit(0);
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantProbeDelegate class]));
    }
}
