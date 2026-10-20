#import <UIKit/UIKit.h>

static NSString *const revenantOpenInNewWindowTitle = @"Open in New Window";

static void revenant_requestWindow(UIWindowSceneActivationActionConfigurationProvider configurationProvider, UIAction *alternateAction, UIAction *action)
{
    UIWindowSceneActivationConfiguration *configuration = configurationProvider ? configurationProvider((UIWindowSceneActivationAction *)action) : nil;
    [[UIApplication sharedApplication] requestSceneSessionActivation:nil userActivity:configuration.userActivity options:configuration.options errorHandler:^(NSError *error) {
        [alternateAction performWithSender:action target:nil];
    }];
}

@implementation UIWindowSceneActivationAction

+ (instancetype)actionWithIdentifier:(UIActionIdentifier)identifier alternateAction:(UIAction *)alternateAction configurationProvider:(UIWindowSceneActivationActionConfigurationProvider)configurationProvider
{
    UIWindowSceneActivationActionConfigurationProvider provider = [configurationProvider copy];
    UIActionHandler handler = ^(UIAction *action) {
        revenant_requestWindow(provider, alternateAction, action);
    };
    return [self actionWithTitle:revenantOpenInNewWindowTitle image:nil identifier:identifier handler:handler];
}

@end
