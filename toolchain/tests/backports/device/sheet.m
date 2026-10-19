#import <UIKit/UIKit.h>
#import "check.h"
#import "sheet-cases.h"
#import "sheet-expectations.h"

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
    revenant_log_to([results_folder stringByAppendingPathComponent:@"sheet.log"]);
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
            revenant_check(YES, name.UTF8String, nil);
        else
            revenant_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n    device %@\n    %@ %@", records[name], source, expected[name]]);
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
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", revenant_failures ? @"FAIL" : @"ok", revenant_checks, revenant_failures];
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
