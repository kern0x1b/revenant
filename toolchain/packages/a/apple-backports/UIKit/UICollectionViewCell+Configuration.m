#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionViewCell (RevenantConfiguration)

- (id<UIContentConfiguration>)contentConfiguration
{
    return revenant_host_content(self);
}

- (void)setContentConfiguration:(id<UIContentConfiguration>)contentConfiguration
{
    revenant_host_set_content(self, contentConfiguration);
}

- (BOOL)automaticallyUpdatesContentConfiguration
{
    return revenant_host_automatic(self, NO);
}

- (void)setAutomaticallyUpdatesContentConfiguration:(BOOL)automaticallyUpdatesContentConfiguration
{
    revenant_host_set_automatic(self, NO, automaticallyUpdatesContentConfiguration);
    if (automaticallyUpdatesContentConfiguration)
        revenant_request_update(self);
}

- (UIBackgroundConfiguration *)backgroundConfiguration
{
    return revenant_host_background(self);
}

- (void)setBackgroundConfiguration:(UIBackgroundConfiguration *)backgroundConfiguration
{
    revenant_host_set_background(self, backgroundConfiguration);
}

- (BOOL)automaticallyUpdatesBackgroundConfiguration
{
    return revenant_host_automatic(self, YES);
}

- (void)setAutomaticallyUpdatesBackgroundConfiguration:(BOOL)automaticallyUpdatesBackgroundConfiguration
{
    revenant_host_set_automatic(self, YES, automaticallyUpdatesBackgroundConfiguration);
    if (automaticallyUpdatesBackgroundConfiguration)
        revenant_request_update(self);
}

- (UICellConfigurationState *)configurationState
{
    return (UICellConfigurationState *)[self revenant_makeConfigurationState];
}

- (void)setNeedsUpdateConfiguration
{
    [self revenant_setNeedsUpdateConfiguration];
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state
{
    revenant_host_default_update(self, state);
}

@end
