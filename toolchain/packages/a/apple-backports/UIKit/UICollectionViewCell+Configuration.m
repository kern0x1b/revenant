#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionViewCell (CharonConfiguration)

- (id<UIContentConfiguration>)contentConfiguration
{
    return charon_host_content(self);
}

- (void)setContentConfiguration:(id<UIContentConfiguration>)contentConfiguration
{
    charon_host_set_content(self, contentConfiguration);
}

- (BOOL)automaticallyUpdatesContentConfiguration
{
    return charon_host_automatic(self, NO);
}

- (void)setAutomaticallyUpdatesContentConfiguration:(BOOL)automaticallyUpdatesContentConfiguration
{
    charon_host_set_automatic(self, NO, automaticallyUpdatesContentConfiguration);
    if (automaticallyUpdatesContentConfiguration)
        charon_request_update(self);
}

- (UIBackgroundConfiguration *)backgroundConfiguration
{
    return charon_host_background(self);
}

- (void)setBackgroundConfiguration:(UIBackgroundConfiguration *)backgroundConfiguration
{
    charon_host_set_background(self, backgroundConfiguration);
}

- (BOOL)automaticallyUpdatesBackgroundConfiguration
{
    return charon_host_automatic(self, YES);
}

- (void)setAutomaticallyUpdatesBackgroundConfiguration:(BOOL)automaticallyUpdatesBackgroundConfiguration
{
    charon_host_set_automatic(self, YES, automaticallyUpdatesBackgroundConfiguration);
    if (automaticallyUpdatesBackgroundConfiguration)
        charon_request_update(self);
}

- (UICellConfigurationState *)configurationState
{
    return (UICellConfigurationState *)[self charon_makeConfigurationState];
}

- (void)setNeedsUpdateConfiguration
{
    [self charon_setNeedsUpdateConfiguration];
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state
{
    charon_host_default_update(self, state);
}

@end
