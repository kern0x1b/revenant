#import <UIKit/UIKit.h>
#import "check.h"
#import "sheet-cases.h"
#import "sheet-expectations.h"

/* An iPhone application (UIDeviceFamily 1), so that the iPad 2 runs it in a phone-sized window
   too and the sheet is the compact-width one.

   The layout records are held to values worked out from UIKitCore of the 16.0 cache
   (packages/a/apple-backports/facts/UIKit/UISheetPresentationController.md), for a 320 x 480
   window with a 20 point status bar: the sheet 320 x 440 at y 40, the medium detent 440 x 0.63
   high, the root view (0 20 320 460) scaled by 1 - 2 x 16 / 320 = 0.9 behind a sheet at its
   full height with its top 10 above the sheet's, the first sheet the same way behind a second
   one, and the root at depth 2 under the first. A tap on the grabber moves to the detent
   before the current one, the last after the first (-[_UISheetLayoutInfo
   _indexOfActiveDetentForTappingGrabber]), and tells the delegate. While a text field in the
   sheet has the keyboard the sheet stands at its first detent, the large one here, and keeps
   its selection; a tap on the grabber then ends editing and the sheet goes back to it. */
static NSDictionary *layout_expectations(void)
{
    return @{
        @"layout.large": @"root=16.0 30.0 288.0 414.0 first=0.0 40.0 320.0 440.0 second=- selected=com.apple.UIKit.large container=1 calls=",
        @"layout.controller": @"same=1 presenting=1",
        @"layout.medium": @"root=0.0 20.0 320.0 460.0 first=0.0 202.8 320.0 440.0 second=- selected=com.apple.UIKit.medium container=1 calls=",
        @"layout.largeAgain": @"root=16.0 30.0 288.0 414.0 first=0.0 40.0 320.0 440.0 second=- selected=com.apple.UIKit.large container=1 calls=",
        @"layout.grabberFromLarge": @"root=0.0 20.0 320.0 460.0 first=0.0 202.8 320.0 440.0 second=- selected=com.apple.UIKit.medium container=1 calls=didChangeDetent",
        @"layout.grabberFromMedium": @"root=16.0 30.0 288.0 414.0 first=0.0 40.0 320.0 440.0 second=- selected=com.apple.UIKit.large container=1 calls=didChangeDetent,didChangeDetent",
        @"layout.keyboard": @"root=16.0 30.0 288.0 414.0 first=0.0 40.0 320.0 440.0 second=- selected=com.apple.UIKit.medium container=1 calls=",
        @"layout.keyboard.editing": @"1",
        @"layout.keyboardEnded": @"root=0.0 20.0 320.0 460.0 first=0.0 202.8 320.0 440.0 second=- selected=com.apple.UIKit.medium container=1 calls=",
        @"layout.keyboardEnded.editing": @"0",
        @"layout.hit.visible": @"centre=1 above=1",
        @"layout.hit.hidden": @"above=0",
        @"layout.readOnly": @"root=0.0 20.0 320.0 460.0 first=0.0 202.8 320.0 440.0 second=- selected=com.apple.UIKit.medium container=1 calls=",
        @"layout.readOnly.responder": @"1",
        @"layout.shadow": @"near=1",
        @"layout.stacked": @"root=16.0 40.0 288.0 414.0 first=16.0 30.0 288.0 396.0 second=0.0 40.0 320.0 440.0 selected=com.apple.UIKit.large container=1 calls=",
        @"layout.unstacked": @"root=16.0 30.0 288.0 414.0 first=0.0 40.0 320.0 440.0 second=- selected=com.apple.UIKit.large container=1 calls=",
        @"layout.dismissed": @"root=0.0 20.0 320.0 460.0 first=- second=- selected=com.apple.UIKit.large container=0 calls=",
        @"layout.after": @"transform=[1, 0, 0, 1, 0, 0] radius=0.0 masks=0",
    };
}

static NSString *const results_folder = @"/private/var/backports";

@interface SheetTestDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SheetTestDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"sheet.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"sheet.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    [self performSelector:@selector(run) withObject:nil afterDelay:1];
    return YES;
}

- (void)compare:(NSDictionary *)expected with:(NSDictionary *)records source:(NSString *)source
{
    for (NSString *name in [expected.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([expected[name] isEqualToString:records[name]])
            charon_check(YES, name.UTF8String, nil);
        else
            charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    %@ %@", records[name], source, expected[name]]);
    }
}

- (void)run
{
    NSDictionary *api = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:sheet_expectations length:strlen(sheet_expectations)] options:0 error:NULL];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    SheetRecorder record = ^(NSString *name, NSString *value) {
        records[name] = value;
        printf("record %s: %s\n", name.UTF8String, value.UTF8String);
    };
    sheet_api_run(record);
    [self compare:api with:records source:@"host  "];
    sheet_layout_run(self.window, record, ^{
        [self compare:layout_expectations() with:records source:@"cache "];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"sheet.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SheetTestDelegate class]));
    }
}
