#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_configuration_key;

@implementation UIResponder (RevenantItemsConfiguration)

- (id<UIActivityItemsConfigurationReading>)activityItemsConfiguration
{
    return objc_getAssociatedObject(self, &revenant_configuration_key);
}

- (void)setActivityItemsConfiguration:(id<UIActivityItemsConfigurationReading>)activityItemsConfiguration
{
    if (activityItemsConfiguration)
        revenant_menus_say_once(@"items-configuration", @"UIResponder.activityItemsConfiguration is kept and never asked: iOS 6 has no Share command in an edit menu and no keyboard shortcut for sharing, so nothing reads it from the responder chain");
    objc_setAssociatedObject(self, &revenant_configuration_key, activityItemsConfiguration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)validateCommand:(UICommand *)command
{
}

- (UIEditingInteractionConfiguration)editingInteractionConfiguration
{
    return UIEditingInteractionConfigurationDefault;
}

@end
