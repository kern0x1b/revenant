#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface UINavigationBar (RevenantHostBarAppearance)
- (UIColor *)revenantHostBarTintColor;
- (void)revenantHostSetBarTintColor:(UIColor *)color;
- (UIImage *)revenantHostBackIndicatorImage;
- (void)revenantHostSetBackIndicatorImage:(UIImage *)image;
- (UIImage *)revenantHostBackIndicatorTransitionMaskImage;
- (void)revenantHostSetBackIndicatorTransitionMaskImage:(UIImage *)image;
@end

@interface UIToolbar (RevenantHostBarTintColor)
- (UIColor *)revenantHostBarTintColor;
- (void)revenantHostSetBarTintColor:(UIColor *)color;
@end

@interface UITabBar (RevenantHostBarTintColor)
- (UIColor *)revenantHostBarTintColor;
- (void)revenantHostSetBarTintColor:(UIColor *)color;
@end

@interface UISearchBar (RevenantHostBarStyle)
- (UISearchBarStyle)revenantHostSearchBarStyle;
- (void)revenantHostSetSearchBarStyle:(UISearchBarStyle)style;
- (UIColor *)revenantHostBarTintColor;
- (void)revenantHostSetBarTintColor:(UIColor *)color;
@end

static UIImage *drawn_image(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), NO, 1);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, 4, 4));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

int main(void)
{
    @autoreleasepool {
        UIColor *colour = [UIColor orangeColor];
        UINavigationBar *navigation = [[UINavigationBar alloc] init];
        [navigation revenantHostSetBarTintColor:colour];
        revenant_check([navigation revenantHostBarTintColor] == colour, "the navigation bar keeps its bar tint colour", @"the colour differs");
        revenant_check([navigation.tintColor isEqual:colour], "the navigation bar tints itself with it", [NSString stringWithFormat:@"%@", navigation.tintColor]);
        [navigation revenantHostSetBarTintColor:nil];
        revenant_check([navigation revenantHostBarTintColor] == nil, "clearing the bar tint colour", [NSString stringWithFormat:@"%@", [navigation revenantHostBarTintColor]]);

        UIImage *image = drawn_image(), *mask = drawn_image();
        [navigation revenantHostSetBackIndicatorImage:image];
        [navigation revenantHostSetBackIndicatorTransitionMaskImage:mask];
        revenant_check([navigation revenantHostBackIndicatorImage] == image, "the back indicator image is kept", @"the image differs");
        revenant_check([navigation revenantHostBackIndicatorTransitionMaskImage] == mask, "the back indicator mask is kept", @"the mask differs");

        UIToolbar *toolbar = [[UIToolbar alloc] init];
        [toolbar revenantHostSetBarTintColor:colour];
        revenant_check([toolbar revenantHostBarTintColor] == colour && [toolbar.tintColor isEqual:colour], "the toolbar bar tint colour", @"the colour differs");
        UITabBar *tabs = [[UITabBar alloc] init];
        [tabs revenantHostSetBarTintColor:colour];
        revenant_check([tabs revenantHostBarTintColor] == colour && [tabs.tintColor isEqual:colour], "the tab bar bar tint colour", @"the colour differs");

        UISearchBar *search = [[UISearchBar alloc] init];
        [search revenantHostSetBarTintColor:colour];
        revenant_check([search revenantHostBarTintColor] == colour && [search.tintColor isEqual:colour], "the search bar bar tint colour", @"the colour differs");
        revenant_check([search revenantHostSearchBarStyle] == UISearchBarStyleDefault, "the default search bar style", @"the default style differs");
        [search revenantHostSetSearchBarStyle:UISearchBarStyleMinimal];
        revenant_check([search revenantHostSearchBarStyle] == UISearchBarStyleMinimal, "the search bar style is kept", @"the style differs");
        revenant_check(search.backgroundImage != nil, "the minimal style clears the iOS 6 bar background", @"the background image is still missing");
        [search revenantHostSetSearchBarStyle:UISearchBarStyleProminent];
        revenant_check(search.backgroundImage == nil, "leaving the minimal style brings the background back", @"the background image was kept");
        search.backgroundImage = image;
        [search revenantHostSetSearchBarStyle:UISearchBarStyleMinimal];
        revenant_check(CGSizeEqualToSize(search.backgroundImage.size, image.size), "the minimal style leaves an application background alone",
                     [NSString stringWithFormat:@"%@", NSStringFromCGSize(search.backgroundImage.size)]);
        [search revenantHostSetSearchBarStyle:UISearchBarStyleDefault];
        revenant_check(CGSizeEqualToSize(search.backgroundImage.size, image.size), "leaving the minimal style leaves an application background alone",
                     [NSString stringWithFormat:@"%@", NSStringFromCGSize(search.backgroundImage.size)]);

        NSInteger styles[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 15, 16, 255, 256, -1, -2, NSIntegerMin, NSIntegerMax};
        for (size_t index = 0; index < sizeof styles / sizeof *styles; index++) {
            UISearchBar *ours = [[UISearchBar alloc] init], *system = [[UISearchBar alloc] init];
            [ours revenantHostSetSearchBarStyle:(UISearchBarStyle)styles[index]];
            system.searchBarStyle = (UISearchBarStyle)styles[index];
            revenant_check((NSInteger)[ours revenantHostSearchBarStyle] == (NSInteger)system.searchBarStyle, NAMED(@"search bar style %ld reads as the system's", (long)styles[index]),
                         [NSString stringWithFormat:@"%ld != %ld", (long)[ours revenantHostSearchBarStyle], (long)system.searchBarStyle]);
        }

        for (unsigned steps = 0; steps < 4096; steps++) {
            UINavigationBar *ours = [[UINavigationBar alloc] init], *system = [[UINavigationBar alloc] init];
            UIImage *pair[2] = {drawn_image(), drawn_image()};
            UIImage *other[2] = {drawn_image(), drawn_image()};
            NSMutableString *trace = [NSMutableString string];
            BOOL same = YES;
            unsigned seed = steps;
            for (int move = 0; move < 6 && same; move++, seed /= 4) {
                int which = (seed >> 0) & 1, clear = (seed >> 1) & 1;
                UIImage *given = clear ? nil : (move % 2 ? other[which] : pair[which]);
                [trace appendFormat:@"%s%s ", which ? "mask" : "image", clear ? "=nil" : (move % 2 ? "'" : "")];
                if (which) {
                    [ours revenantHostSetBackIndicatorTransitionMaskImage:given];
                    system.backIndicatorTransitionMaskImage = given;
                } else {
                    [ours revenantHostSetBackIndicatorImage:given];
                    system.backIndicatorImage = given;
                }
                same = [ours revenantHostBackIndicatorImage] == system.backIndicatorImage && [ours revenantHostBackIndicatorTransitionMaskImage] == system.backIndicatorTransitionMaskImage;
            }
            if (!same) {
                revenant_check(NO, NAMED(@"the back indicator pair after %@", trace), @"the images differ from the system's");
                break;
            }
            if (steps == 4095)
                revenant_check(YES, "the back indicator pair answers as the system's over every order of six changes", @"");
        }

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
