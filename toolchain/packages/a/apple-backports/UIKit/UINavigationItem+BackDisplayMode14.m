#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char charon_mode_key, charon_applied_key;

@interface UINavigationItem (CharonBackTitle)
- (NSString *)backButtonTitle;
- (void)setBackButtonTitle:(NSString *)title;
@end

@implementation UINavigationItem (CharonBackDisplayMode14)

- (UINavigationItemBackButtonDisplayMode)backButtonDisplayMode
{
    return (UINavigationItemBackButtonDisplayMode)[objc_getAssociatedObject(self, &charon_mode_key) integerValue];
}

- (void)setBackButtonDisplayMode:(UINavigationItemBackButtonDisplayMode)mode
{
    objc_setAssociatedObject(self, &charon_mode_key, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (![self respondsToSelector:@selector(setBackButtonTitle:)])
        return;
    NSString *applied = objc_getAssociatedObject(self, &charon_applied_key);
    NSString *current = [self backButtonTitle];
    if (current && !(applied && [applied isEqualToString:current]))
        return;
    NSString *wanted = nil;
    if (mode == UINavigationItemBackButtonDisplayModeGeneric)
        wanted = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Back" value:@"Back" table:nil];
    else if (mode == UINavigationItemBackButtonDisplayModeMinimal)
        wanted = @"";
    objc_setAssociatedObject(self, &charon_applied_key, wanted, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setBackButtonTitle:wanted];
}

@end
