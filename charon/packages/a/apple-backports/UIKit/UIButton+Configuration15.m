#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

extern id charon_host_update_handler(UIView *host);
extern void charon_host_set_update_handler(UIView *host, id handler);
extern void charon_request_update(UIView *view);

static const void *CharonButtonConfigurationKey = &CharonButtonConfigurationKey;
static const void *CharonButtonAutoUpdateKey = &CharonButtonAutoUpdateKey;
static const void *CharonButtonPrimaryActionKey = &CharonButtonPrimaryActionKey;
static const void *CharonButtonSubtitleLabelKey = &CharonButtonSubtitleLabelKey;

@implementation UIButton (CharonConfiguration15)

+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)configuration primaryAction:(UIAction *)primaryAction
{
    UIButton *button = [self buttonWithType:UIButtonTypeSystem primaryAction:primaryAction];
    button.configuration = configuration;
    return button;
}

- (UIButtonConfiguration *)configuration
{
    return objc_getAssociatedObject(self, CharonButtonConfigurationKey);
}

- (void)setConfiguration:(UIButtonConfiguration *)configuration
{
    objc_setAssociatedObject(self, CharonButtonConfigurationKey, [configuration copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}

- (UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    return charon_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    charon_host_set_update_handler(self, configurationUpdateHandler);
}

- (BOOL)automaticallyUpdatesConfiguration
{
    NSNumber *kept = objc_getAssociatedObject(self, CharonButtonAutoUpdateKey);
    return kept ? kept.boolValue : YES;
}

- (void)setAutomaticallyUpdatesConfiguration:(BOOL)automaticallyUpdatesConfiguration
{
    objc_setAssociatedObject(self, CharonButtonAutoUpdateKey, @(automaticallyUpdatesConfiguration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (automaticallyUpdatesConfiguration)
        [self setNeedsUpdateConfiguration];
}

- (void)setNeedsUpdateConfiguration
{
    charon_request_update(self);
}

- (void)updateConfiguration
{
    UIButtonConfigurationUpdateHandler handler = charon_host_update_handler(self);
    if (handler)
        handler(self);
}

- (BOOL)changesSelectionAsPrimaryAction
{
    return [objc_getAssociatedObject(self, CharonButtonPrimaryActionKey) boolValue];
}

- (void)setChangesSelectionAsPrimaryAction:(BOOL)changesSelectionAsPrimaryAction
{
    objc_setAssociatedObject(self, CharonButtonPrimaryActionKey, @(changesSelectionAsPrimaryAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UILabel *)subtitleLabel
{
    UILabel *label = objc_getAssociatedObject(self, CharonButtonSubtitleLabelKey);
    if (label)
        return label;
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(self, CharonButtonSubtitleLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return label;
}

@end
