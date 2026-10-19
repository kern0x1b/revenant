#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_search_bar_style_key;
static char charon_bar_tint_key;
static char charon_minimal_background_key;

static UIImage *charon_clear_image(void)
{
    static UIImage *image;
    if (!image) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 0);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

@implementation UISearchBar (CharonBarStyle)

- (UISearchBarStyle)searchBarStyle
{
    return (UISearchBarStyle)[objc_getAssociatedObject(self, &charon_search_bar_style_key) unsignedIntegerValue];
}

- (void)setSearchBarStyle:(UISearchBarStyle)searchBarStyle
{
    searchBarStyle = (UISearchBarStyle)((NSUInteger)searchBarStyle & 7);
    objc_setAssociatedObject(self, &charon_search_bar_style_key, @(searchBarStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIImage *ours = objc_getAssociatedObject(self, &charon_minimal_background_key);
    if (searchBarStyle == UISearchBarStyleMinimal) {
        if (!self.backgroundImage) {
            UIImage *clear = charon_clear_image();
            objc_setAssociatedObject(self, &charon_minimal_background_key, clear, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            self.backgroundImage = clear;
        }
    } else if (ours) {
        if (self.backgroundImage == ours)
            self.backgroundImage = nil;
        objc_setAssociatedObject(self, &charon_minimal_background_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (UIColor *)barTintColor
{
    return objc_getAssociatedObject(self, &charon_bar_tint_key);
}

- (void)setBarTintColor:(UIColor *)barTintColor
{
    objc_setAssociatedObject(self, &charon_bar_tint_key, barTintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.tintColor = barTintColor;
}

@end
