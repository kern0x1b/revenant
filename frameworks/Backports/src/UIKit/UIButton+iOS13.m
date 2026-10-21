#import "RevenantSymbols.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_configurations_key;

@implementation UIButton (RevenantThirteen)

+ (instancetype)systemButtonWithImage:(UIImage *)image target:(id)target action:(SEL)action
{
    UIButton *button = [self buttonWithType:UIButtonTypeSystem];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIImageSymbolConfiguration *)preferredSymbolConfigurationForImageInState:(UIControlState)state
{
    return [objc_getAssociatedObject(self, &revenant_configurations_key) objectForKey:@(state)];
}

- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)configuration forImageInState:(UIControlState)state
{
    NSMutableDictionary *held = objc_getAssociatedObject(self, &revenant_configurations_key);
    if (!held) {
        held = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &revenant_configurations_key, held, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (configuration)
        held[@(state)] = configuration;
    else
        [held removeObjectForKey:@(state)];
}

- (UIImageSymbolConfiguration *)currentPreferredSymbolConfiguration
{
    UIImageSymbolConfiguration *current = [self preferredSymbolConfigurationForImageInState:self.state];
    return current ? current : [self preferredSymbolConfigurationForImageInState:UIControlStateNormal];
}

@end
