#import <UIKit/UIKit.h>

// The title the release gives the action when none is set: the English text of its own string, which the host answers
// under an English locale. The other locales' texts are not carried, so the title is English in every language.
static NSString *const charonOpenInNewWindowTitle = @"Open in New Window";

// The action asks its configuration provider for what the new window opens with, and asks the application for a scene.
// The release has one scene and refuses a second (UISceneErrorDomain code 0); the refusal runs the alternate action, which
// is what the system shows where a second window cannot open. Without an alternate action the refusal has nowhere to go.
static void charon_requestWindow(UIWindowSceneActivationActionConfigurationProvider configurationProvider, UIAction *alternateAction, UIAction *action)
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
        charon_requestWindow(provider, alternateAction, action);
    };
    return [self actionWithTitle:charonOpenInNewWindowTitle image:nil identifier:identifier handler:handler];
}

@end
