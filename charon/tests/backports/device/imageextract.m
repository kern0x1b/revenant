#import <UIKit/UIKit.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

@interface ImageDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation ImageDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"imageextract.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"imageextract.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSDictionary *index = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"AssetCatalogImages" ofType:@"plist"]];
        CHECK(index.count > 10, "the index of an extracted catalogue is in the bundle");
        CGFloat screen = [UIScreen mainScreen].scale;
        BOOL pad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
        NSUInteger checked = 0, found = 0, sized = 0, scaled = 0;
        NSMutableArray *bad = [NSMutableArray array];
        for (NSString *name in [index.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *best = nil;
            for (NSDictionary *variant in index[name]) {
                NSInteger scale = [variant[@"scale"] integerValue];
                BOOL forPad = [variant[@"idiom"] isEqual:@"pad"];
                if (forPad && !pad)
                    continue;
                if (scale > screen)
                    continue;
                BOOL better = !best || (forPad && ![best[@"idiom"] isEqual:@"pad"]) || (forPad == [best[@"idiom"] isEqual:@"pad"] && scale > [best[@"scale"] integerValue]);
                if (better)
                    best = variant;
            }
            if (!best)
                continue;
            checked++;
            UIImage *image = [UIImage imageNamed:name];
            if (!image) {
                [bad addObject:[NSString stringWithFormat:@"%@ nil", name]];
                continue;
            }
            found++;
            CGFloat scale = [best[@"scale"] doubleValue];
            if (fabs(image.scale - scale) < 0.01)
                scaled++;
            else
                [bad addObject:[NSString stringWithFormat:@"%@ scale %.0f != %.0f", name, image.scale, scale]];
            if (fabs(image.size.width * image.scale - [best[@"width"] doubleValue]) < 1.01 && fabs(image.size.height * image.scale - [best[@"height"] doubleValue]) < 1.01)
                sized++;
            else
                [bad addObject:[NSString stringWithFormat:@"%@ size %@ x%.0f != %@x%@", name, NSStringFromCGSize(image.size), image.scale, best[@"width"], best[@"height"]]];
        }
        printf("names checked %lu found %lu right scale %lu right size %lu\n", (unsigned long)checked, (unsigned long)found, (unsigned long)scaled, (unsigned long)sized);
        for (NSString *line in bad)
            printf("  %s\n", line.UTF8String);
        CHECK(checked > 10 && found == checked, "every name of the catalogue the device can show is found by imageNamed:");
        CHECK(scaled == found, "at the scale of the best file for the screen");
        CHECK(sized == found, "and at the size the catalogue gave it");
        UIImage *first = [UIImage imageNamed:[[index.allKeys sortedArrayUsingSelector:@selector(compare:)] firstObject]];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
        [first drawInRect:CGRectMake(0, 0, 20, 20)];
        UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CHECK(first.CGImage != NULL && drawn != nil, "an extracted image draws");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"imageextract.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ImageDelegate class]));
    }
}
