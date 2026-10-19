#import "RevenantLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

extern id revenant_host_update_handler(UIView *host);
extern void revenant_host_set_update_handler(UIView *host, id handler);
extern void revenant_request_update(UIView *view);

static const void *RevenantButtonConfigurationKey = &RevenantButtonConfigurationKey;
static const void *RevenantButtonAutoUpdateKey = &RevenantButtonAutoUpdateKey;
static const void *RevenantButtonPrimaryActionKey = &RevenantButtonPrimaryActionKey;
static const void *RevenantButtonSubtitleLabelKey = &RevenantButtonSubtitleLabelKey;

@implementation UIButton (RevenantConfiguration15)

+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)configuration primaryAction:(UIAction *)primaryAction
{
    UIButton *button = [self buttonWithType:UIButtonTypeSystem primaryAction:primaryAction];
    button.configuration = configuration;
    return button;
}

- (UIButtonConfiguration *)configuration
{
    return objc_getAssociatedObject(self, RevenantButtonConfigurationKey);
}

- (void)setConfiguration:(UIButtonConfiguration *)configuration
{
    objc_setAssociatedObject(self, RevenantButtonConfigurationKey, [configuration copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}

- (UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    return revenant_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    revenant_host_set_update_handler(self, configurationUpdateHandler);
}

- (BOOL)automaticallyUpdatesConfiguration
{
    NSNumber *kept = objc_getAssociatedObject(self, RevenantButtonAutoUpdateKey);
    return kept ? kept.boolValue : YES;
}

- (void)setAutomaticallyUpdatesConfiguration:(BOOL)automaticallyUpdatesConfiguration
{
    objc_setAssociatedObject(self, RevenantButtonAutoUpdateKey, @(automaticallyUpdatesConfiguration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (automaticallyUpdatesConfiguration)
        [self setNeedsUpdateConfiguration];
}

- (void)setNeedsUpdateConfiguration
{
    revenant_request_update(self);
}

- (void)updateConfiguration
{
    UIButtonConfigurationUpdateHandler handler = revenant_host_update_handler(self);
    if (handler)
        handler(self);
}

- (BOOL)changesSelectionAsPrimaryAction
{
    return [objc_getAssociatedObject(self, RevenantButtonPrimaryActionKey) boolValue];
}

- (void)setChangesSelectionAsPrimaryAction:(BOOL)changesSelectionAsPrimaryAction
{
    objc_setAssociatedObject(self, RevenantButtonPrimaryActionKey, @(changesSelectionAsPrimaryAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UILabel *)subtitleLabel
{
    UILabel *label = objc_getAssociatedObject(self, RevenantButtonSubtitleLabelKey);
    if (label)
        return label;
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(self, RevenantButtonSubtitleLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return label;
}

@end
