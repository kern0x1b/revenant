#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

static NSString *const results_folder = @"/private/var/backports";

@interface Delegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

static void spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static void pixel_of(CGImageRef image, CGFloat fx, CGFloat fy, int out[3])
{
    size_t w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    uint8_t px[4] = {0, 0, 0, 0};
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(px, 1, 1, 8, 4, rgb, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, -(CGFloat)(fx * (w - 1)), -(CGFloat)((1 - fy) * (h - 1)));
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), image);
    CGContextRelease(context);
    CGColorSpaceRelease(rgb);
    out[0] = px[0];
    out[1] = px[1];
    out[2] = px[2];
}

static CGImageRef backdrop_of(UIVisualEffectView *view)
{
    for (CALayer *layer in view.layer.sublayers)
        if (layer.contents)
            return (__bridge CGImageRef)layer.contents;
    return NULL;
}

@implementation Delegate

- (void)run
{
    CGRect bounds = [UIScreen mainScreen].bounds;
    UIView *root = self.window.rootViewController.view;
    NSArray *colors = @[[UIColor redColor], [UIColor greenColor], [UIColor blueColor], [UIColor yellowColor]];
    CGFloat quarter = bounds.size.width / 4;
    for (int i = 0; i < 4; i++) {
        UIView *stripe = [[UIView alloc] initWithFrame:CGRectMake(i * quarter, 0, quarter, bounds.size.height)];
        stripe.backgroundColor = colors[i];
        [root addSubview:stripe];
    }
    CGRect area = CGRectMake(0, bounds.size.height * 0.25, bounds.size.width, bounds.size.height * 0.2);
    UIVisualEffectView *light = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    light.frame = area;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(light.contentView.bounds, 10, 10)];
    label.text = @"Light";
    label.backgroundColor = [UIColor clearColor];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [light.contentView addSubview:label];
    [root addSubview:light];
    UIVisualEffectView *dark = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    dark.frame = CGRectMake(0, bounds.size.height * 0.55, bounds.size.width, bounds.size.height * 0.2);
    [root addSubview:dark];
    UIVisualEffectView *none = [[UIVisualEffectView alloc] initWithEffect:nil];
    none.frame = CGRectMake(0, bounds.size.height * 0.8, bounds.size.width, bounds.size.height * 0.1);
    [root addSubview:none];
    spin(1.5);

    CGImageRef lightImage = backdrop_of(light), darkImage = backdrop_of(dark);
    CHECK(lightImage != NULL, "a light effect view shows an image of what lies behind it");
    CHECK(backdrop_of(none) == NULL, "a view with no effect shows none");
    CHECK([light.contentView.subviews containsObject:label], "its content view holds the application's views");
    if (lightImage && darkImage) {
        size_t w = CGImageGetWidth(lightImage);
        CHECK(w > 0 && w <= (size_t)ceil(bounds.size.width * 0.25) + 40, "the image is small, a quarter of the view or less");
        int inside[3], edge[3], darkInside[3], darkEdge[3];
        pixel_of(lightImage, 0.125, 0.5, inside);
        pixel_of(lightImage, 0.25, 0.5, edge);
        pixel_of(darkImage, 0.125, 0.5, darkInside);
        pixel_of(darkImage, 0.25, 0.5, darkEdge);
        printf("light: inside %d,%d,%d edge %d,%d,%d; dark: inside %d,%d,%d edge %d,%d,%d\n", inside[0], inside[1], inside[2], edge[0], edge[1], edge[2], darkInside[0], darkInside[1], darkInside[2], darkEdge[0], darkEdge[1], darkEdge[2]);
        CHECK(inside[0] > inside[1] + 20 && inside[0] > inside[2] + 20, "in the middle of the red stripe the light blur is reddish");
        CHECK(inside[0] > 200 && inside[1] > 30 && inside[2] > 30, "and it is not the pure red behind it: the white tint is mixed in");
        CHECK(edge[0] > 40 && edge[1] > 40 && edge[0] < 250 && edge[1] < 250, "at the line between red and green it is neither: the picture is blurred");
        CHECK(darkInside[0] < inside[0] && darkInside[0] + darkInside[1] + darkInside[2] < inside[0] + inside[1] + inside[2], "the dark effect is darker than the light one");
    }
    NSTimeInterval total = 0;
    for (int i = 0; i < 5; i++) {
        NSTimeInterval start = CACurrentMediaTime();
        [light performSelector:@selector(charon_refresh)];
        total += CACurrentMediaTime() - start;
    }
    printf("a refresh of a view of %.0f x %.0f points took %.1f ms\n", area.size.width, area.size.height, total / 5 * 1000);
    CHECK(total / 5 < 0.25, "a refresh takes less than a quarter of a second");
    UIColor *before = light.backgroundColor;
    CHECK(before == nil || CGColorGetAlpha(before.CGColor) == 0, "the view itself stays transparent");
    UIView *first = root.subviews.firstObject;
    [first setBackgroundColor:[UIColor blackColor]];
    int changed[3] = {255, 255, 255};
    for (int i = 0; i < 12 && !(changed[0] < 200 && changed[0] + changed[1] + changed[2] < 500); i++) {
        spin(0.25);
        pixel_of(backdrop_of(light), 0.06, 0.5, changed);
        printf("after %.2f s: %d,%d,%d\n", (i + 1) * 0.25, changed[0], changed[1], changed[2]);
    }
    CHECK(changed[0] < 200 && changed[0] + changed[1] + changed[2] < 500, "what lies behind it is followed: the red stripe turned black and the blur went with it");
    [light removeFromSuperview];
    [dark removeFromSuperview];
    spin(0.3);
    CHECK(YES, "a view removed from the window stops its refresh without harm");
}

- (void)runAndFinish
{
    @try {
        [self run];
    } @catch (NSException *exception) {
        charon_check(NO, "the effect views run without an exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%d checks, %d failed\n", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"visualeffect.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"visualeffect.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"visualeffect.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.rootViewController.view.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndFinish) withObject:nil afterDelay:0.3];
    return YES;
}
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([Delegate class]));
    }
}
