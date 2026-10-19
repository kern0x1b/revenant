#import <UIKit/UIKit.h>
#import "check.h"
#import "imagenamed-cases.h"
#import "imagenamed-expectations.h"

static NSString *const results_folder = @"/private/var/backports";

@interface ImageNamedDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ImageNamedDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"imagenamed.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"imagenamed.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSBundle *bundle = imagenamed_bundle();
        NSArray *names = IMAGENAMED_NAMES;
        CHECK(sizeof imagenamed_expectations / sizeof imagenamed_expectations[0] == names.count * 6, "there is one recorded answer for every name under every trait");
        size_t index = 0;
        for (NSString *name in names) {
            for (NSNumber *scale in IMAGENAMED_SCALES) {
                for (NSNumber *idiom in IMAGENAMED_IDIOMS) {
                    UITraitCollection *traits = [UITraitCollection traitCollectionWithTraitsFromCollections:@[
                        [UITraitCollection traitCollectionWithDisplayScale:scale.doubleValue],
                        [UITraitCollection traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom.integerValue]]];
                    UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:traits];
                    NSString *label = [NSString stringWithFormat:@"%@ at scale %@ for idiom %@ answers as the system does", name.length ? name : @"(empty)", scale, idiom];
                    NSString *expected = @(imagenamed_expectations[index]);
                    if ([name isEqual:@"PLAIN"] && ![[NSFileManager defaultManager] fileExistsAtPath:[bundle.bundlePath stringByAppendingPathComponent:@"PLAIN.png"]])
                        expected = @"nil";
                    CHECK_EQUAL(imagenamed_describe(image), expected, label.UTF8String);
                    index++;
                }
            }
        }
        CGFloat screen = [UIScreen mainScreen].scale;
        NSString *own = [NSString stringWithFormat:@"scale %g", screen];
        UIImage *implicit = [UIImage imageNamed:@"both" inBundle:bundle compatibleWithTraitCollection:nil];
        CHECK(implicit && fabs(implicit.scale - screen) < 0.01, "no traits gives the scale of the screen");
        CHECK([imagenamed_describe(implicit) hasSuffix:own], "and its size is that of the file");
        BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        UIImage *idiom = [UIImage imageNamed:@"idiom" inBundle:bundle compatibleWithTraitCollection:nil];
        CHECK(idiom && idiom.size.width == (pad ? 12 : 10), "no traits gives the idiom of the device");
        CHECK([UIImage imageNamed:@"anything" inBundle:nil compatibleWithTraitCollection:nil] == nil, "no bundle is the main bundle, which holds no such image");
        NSString *folder = bundle.bundlePath;
        imagenamed_write(folder, @"phone~iphone.png", 14, NO);
        imagenamed_write(folder, @"phone.png", 10, NO);
        UIImage *phone = [UIImage imageNamed:@"phone" inBundle:bundle compatibleWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPhone]];
        CHECK(phone && phone.size.width == 14, "a file for the phone is chosen for the phone idiom");
        UIImage *padImage = [UIImage imageNamed:@"phone" inBundle:bundle compatibleWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad]];
        CHECK(padImage && padImage.size.width == 10, "and not for the pad");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"imagenamed.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ImageNamedDelegate class]));
    }
}
