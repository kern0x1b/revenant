#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface DataAssetDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation DataAssetDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"nsdataasset.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"nsdataasset.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CHECK(![UIImage imageNamed:@"Plain"], "the release reads no image out of the catalogue, which is why a reader is carried");
        NSDataAsset *plain = [[NSDataAsset alloc] initWithName:@"Plain"];
        CHECK_EQUAL(plain.name, @"Plain", "a data set answers its name");
        CHECK_EQUAL(plain.data, [@"plain data set\n" dataUsingEncoding:NSUTF8StringEncoding], "and its data");
        CHECK_EQUAL(plain.typeIdentifier, @"public.data", "and public.data for a set with no type");
        NSDataAsset *config = [[NSDataAsset alloc] initWithName:@"Config" bundle:[NSBundle mainBundle]];
        CHECK_EQUAL(config.typeIdentifier, @"public.json", "the type of a typed set is read");
        CHECK([[NSDataAsset alloc] initWithName:@"Empty"].data.length == 0 && [[NSDataAsset alloc] initWithName:@"Empty"] != nil, "an empty set is there and has no data");
        NSData *binary = [[NSDataAsset alloc] initWithName:@"Binary"].data;
        BOOL exact = binary.length == 5120;
        for (NSUInteger index = 0; exact && index < binary.length; index++)
            exact = ((const uint8_t *)binary.bytes)[index] == index % 256;
        CHECK(exact, "binary data comes out byte for byte");
        NSData *varied = [[NSDataAsset alloc] initWithName:@"Varied"].data;
        BOOL phone = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
        CHECK_EQUAL(varied, [(phone ? @"phone" : @"pad") dataUsingEncoding:NSUTF8StringEncoding], "the set of the device's idiom is the one chosen");
        CHECK([[NSDataAsset alloc] initWithName:@"plain"] == nil && [[NSDataAsset alloc] initWithName:@"Missing"] == nil && [[NSDataAsset alloc] initWithName:@""] == nil, "a name that is not there, in another case or empty, finds nothing");
        CHECK([[NSDataAsset alloc] initWithName:@"Plain" bundle:nil] == nil, "no bundle finds nothing");
        BOOL raised = NO;
        @try { [[NSDataAsset alloc] initWithName:nil]; } @catch (NSException *e) { raised = [e.name isEqual:NSInternalInconsistencyException] && [e.reason isEqual:@"You cannot create an instance of NSDataAsset with a nil name."]; }
        CHECK(raised, "no name is refused with the system's words");
        CHECK([plain copy] == plain && plain.data == plain.data, "an asset copies as itself and holds one data");
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        for (int index = 0; index < 200; index++)
            [[NSDataAsset alloc] initWithName:@"Plain"];
        CHECK(CFAbsoluteTimeGetCurrent() - start < 2, "the catalogue is read once, not for every asset");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"nsdataasset.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DataAssetDelegate class]));
    }
}
