#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"
#import "appearances-cases.h"
#import "appearances-expectations.h"

static NSString *image_of(Class class)
{
    Dl_info info;
    return dladdr((__bridge const void *)class, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static void check_classes(void)
{
    for (NSString *name in @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance", @"UIBarButtonItemAppearance", @"UIBarButtonItemStateAppearance",
                             @"UITabBarItemAppearance", @"UITabBarItemStateAppearance"]) {
        Class kind = NSClassFromString(name);
        CHECK(kind != Nil, ([NSString stringWithFormat:@"%@ is there", name].UTF8String));
        CHECK_EQUAL(image_of(kind), @"libUIKitBackports.dylib", ([NSString stringWithFormat:@"%@ comes from the backports library", name].UTF8String));
    }
    for (NSString *name in @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance", @"UIBarButtonItemAppearance", @"UITabBarItemAppearance"]) {
        Class kind = NSClassFromString(name);
        CHECK([kind supportsSecureCoding] && [kind conformsToProtocol:@protocol(NSCopying)], ([NSString stringWithFormat:@"%@ adopts NSCopying and secure coding", name].UTF8String));
    }
    CHECK(class_getSuperclass(NSClassFromString(@"UINavigationBarAppearance")) == NSClassFromString(@"UIBarAppearance") && class_getSuperclass(NSClassFromString(@"UIToolbarAppearance")) == NSClassFromString(@"UIBarAppearance") &&
          class_getSuperclass(NSClassFromString(@"UITabBarAppearance")) == NSClassFromString(@"UIBarAppearance"), "the three bar appearances descend from UIBarAppearance");
    CHECK([UINavigationBar instancesRespondToSelector:@selector(standardAppearance)] && [UINavigationBar instancesRespondToSelector:@selector(setCompactAppearance:)] &&
          [UINavigationBar instancesRespondToSelector:@selector(scrollEdgeAppearance)] && [UINavigationBar instancesRespondToSelector:@selector(compactScrollEdgeAppearance)],
          "a navigation bar answers the four appearances");
    CHECK([UIToolbar instancesRespondToSelector:@selector(standardAppearance)] && [UIToolbar instancesRespondToSelector:@selector(compactAppearance)] &&
          [UIToolbar instancesRespondToSelector:@selector(scrollEdgeAppearance)] && [UIToolbar instancesRespondToSelector:@selector(compactScrollEdgeAppearance)], "a toolbar answers the four appearances");
    CHECK([UITabBar instancesRespondToSelector:@selector(standardAppearance)] && [UITabBar instancesRespondToSelector:@selector(scrollEdgeAppearance)] &&
          ![UITabBar instancesRespondToSelector:NSSelectorFromString(@"compactAppearance")], "a tab bar answers its two appearances and has no compact one");
    CHECK([UINavigationItem instancesRespondToSelector:@selector(standardAppearance)] && [UINavigationItem instancesRespondToSelector:@selector(compactScrollEdgeAppearance)] &&
          [UITabBarItem instancesRespondToSelector:@selector(standardAppearance)] && [UITabBarItem instancesRespondToSelector:@selector(scrollEdgeAppearance)], "the items answer their appearances");
    CHECK(![NSClassFromString(@"UINavigationBarAppearance") instancesRespondToSelector:NSSelectorFromString(@"subtitleTextAttributes")] &&
          ![NSClassFromString(@"UIBarAppearance") instancesRespondToSelector:NSSelectorFromString(@"overrideUserInterfaceStyle")], "the members of iOS 26 and 27 that are absent are not answered");
}

static void check_scripted_cases(void)
{
    NSArray *cases = charon_appearance_cases();
    CHECK_EQUAL(@(cases.count), @(sizeof charon_appearance_expectations / sizeof *charon_appearance_expectations), "there is an expectation for every scripted case");
    CharonAppearanceMaker maker = ^id(NSString *kind) { return [[NSClassFromString(kind) alloc] init]; };
    for (NSUInteger index = 0; index < cases.count && index < sizeof charon_appearance_expectations / sizeof *charon_appearance_expectations; index++) {
        NSDictionary *one = cases[index];
        id object = ((CharonAppearanceCase)one[@"body"])(maker);
        NSString *actual = object ? charon_snapshot(object) : @"nil";
        charon_check([actual isEqual:charon_appearance_expectations[index]], ([NSString stringWithFormat:@"the host's answers for: %@", one[@"name"]].UTF8String),
                     [NSString stringWithFormat:@"\n  actual   %@\n  expected %@", actual, charon_appearance_expectations[index]]);
    }
}

static void check_extras(void)
{
    id navigation = [[NSClassFromString(@"UINavigationBarAppearance") alloc] init];
    CHECK_EQUAL(raised(^{ [navigation setValue:nil forKey:@"buttonAppearance"]; }), @"NSInternalInconsistencyException: use -[UIBarButtonItemAppearance configureWithDefaultForStyle:] to reset appearance values",
                "a nil plain button appearance is refused as the release of the system refuses it");
    CHECK_EQUAL(raised(^{ (void)[(UIBarButtonItemAppearance *)[NSClassFromString(@"UIBarButtonItemAppearance") alloc] initWithStyle:(UIBarButtonItemStyle)1]; }), @"NSInternalInconsistencyException: Unsupported style: 1", "a button style of 1 is refused");
    CHECK_EQUAL(raised(^{ (void)[(UITabBarItemAppearance *)[NSClassFromString(@"UITabBarItemAppearance") alloc] initWithStyle:(UITabBarItemAppearanceStyle)5]; }), @"NSInternalInconsistencyException: Unsupported style 5", "a tab item style of 5 is refused");
    CHECK([navigation backIndicatorImage] == nil && [navigation backIndicatorTransitionMaskImage] == nil, "a new navigation bar appearance holds no back indicator, as the release has none to name");

    UIFont *font = [UIFont systemFontOfSize:20];
    [navigation setTitleTextAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor redColor], NSKernAttributeName: @3}];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:navigation requiringSecureCoding:YES error:NULL];
    id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:NSClassFromString(@"UINavigationBarAppearance") fromData:data error:NULL];
    NSDictionary *attributes = [decoded titleTextAttributes];
    CHECK(decoded != nil && [attributes[NSFontAttributeName] pointSize] == 20 && [attributes[NSFontAttributeName] fontName].length && [attributes[NSKernAttributeName] isEqual:@3], "a title font, colour and kern survive a secure archive");
    CHECK([charon_rgba(attributes[NSForegroundColorAttributeName]) isEqual:charon_rgba([UIColor redColor])], "the title colour survives a secure archive");
    CHECK([[navigation titleTextAttributes][NSFontAttributeName] fontName].length && [[decoded titleTextAttributes][NSFontAttributeName] fontName].length, "the fonts are named");
}

static NSString *const results_folder = @"/private/var/backports";

@interface CharonAppearancesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonAppearancesDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    charon_log_to([results_folder stringByAppendingPathComponent:@"appearances.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(runAndReport) withObject:nil afterDelay:0.5];
    return YES;
}

- (void)runAndReport
{
    @try {
        charon_prepare_images();
        check_scripted_cases();
        check_extras();
    } @catch (NSException *exception) {
        charon_check(NO, "the checks raise no exception", [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]);
    }
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"appearances.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
        return UIApplicationMain(argc, argv, nil, @"CharonAppearancesDelegate");
    }
}
