#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_mode_key, revenant_applied_key;

@interface UINavigationItem (RevenantBackTitle)
- (NSString *)backButtonTitle;
- (void)setBackButtonTitle:(NSString *)title;
@end

@implementation UINavigationItem (RevenantBackDisplayMode14)

- (UINavigationItemBackButtonDisplayMode)backButtonDisplayMode
{
    return (UINavigationItemBackButtonDisplayMode)[objc_getAssociatedObject(self, &revenant_mode_key) integerValue];
}

- (void)setBackButtonDisplayMode:(UINavigationItemBackButtonDisplayMode)mode
{
    objc_setAssociatedObject(self, &revenant_mode_key, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (![self respondsToSelector:@selector(setBackButtonTitle:)])
        return;
    NSString *applied = objc_getAssociatedObject(self, &revenant_applied_key);
    NSString *current = [self backButtonTitle];
    if (current && !(applied && [applied isEqualToString:current]))
        return;
    NSString *wanted = nil;
    if (mode == UINavigationItemBackButtonDisplayModeGeneric)
        wanted = [[NSBundle bundleForClass:[UIApplication class]] localizedStringForKey:@"Back" value:@"Back" table:nil];
    else if (mode == UINavigationItemBackButtonDisplayModeMinimal)
        wanted = @"";
    objc_setAssociatedObject(self, &revenant_applied_key, wanted, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setBackButtonTitle:wanted];
}

@end
