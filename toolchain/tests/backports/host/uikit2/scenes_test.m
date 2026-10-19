#import <UIKit/UIKit.h>
#import "check.h"

extern NSString *const RevenantHostUISceneWillConnectNotification, *const RevenantHostUISceneDidDisconnectNotification, *const RevenantHostUISceneDidActivateNotification,
    *const RevenantHostUISceneWillDeactivateNotification, *const RevenantHostUISceneWillEnterForegroundNotification, *const RevenantHostUISceneDidEnterBackgroundNotification,
    *const RevenantHostUIWindowSceneSessionRoleApplication, *const RevenantHostUIWindowSceneSessionRoleExternalDisplay,
    *const RevenantHostUIWindowSceneSessionRoleExternalDisplayNonInteractive;

#define ROLE(object) [(UISceneConfiguration *)(object) role]

static id make(Class cls)
{
    return [[cls alloc] init];
}

static NSString *coded(id object, Class cls, id *decoded)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    *decoded = data ? [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error] : nil;
    return error ? error.localizedDescription : @"ok";
}

int main(void)
{
    @autoreleasepool {
        CHECK_EQUAL(RevenantHostUISceneWillConnectNotification, UISceneWillConnectNotification, "the will connect notification");
        CHECK_EQUAL(RevenantHostUISceneDidDisconnectNotification, UISceneDidDisconnectNotification, "the did disconnect notification");
        CHECK_EQUAL(RevenantHostUISceneDidActivateNotification, UISceneDidActivateNotification, "the did activate notification");
        CHECK_EQUAL(RevenantHostUISceneWillDeactivateNotification, UISceneWillDeactivateNotification, "the will deactivate notification");
        CHECK_EQUAL(RevenantHostUISceneWillEnterForegroundNotification, UISceneWillEnterForegroundNotification, "the will enter foreground notification");
        CHECK_EQUAL(RevenantHostUISceneDidEnterBackgroundNotification, UISceneDidEnterBackgroundNotification, "the did enter background notification");
        CHECK_EQUAL(RevenantHostUIWindowSceneSessionRoleApplication, UIWindowSceneSessionRoleApplication, "the application role");
        CHECK_EQUAL(RevenantHostUIWindowSceneSessionRoleExternalDisplay, UIWindowSceneSessionRoleExternalDisplay, "the external display role");
        CHECK_EQUAL(RevenantHostUIWindowSceneSessionRoleExternalDisplayNonInteractive, UIWindowSceneSessionRoleExternalDisplayNonInteractive, "the non-interactive external display role");

        Class ourConfiguration = NSClassFromString(@"RevenantHostUISceneConfiguration");
        CHECK(ourConfiguration != Nil, "the port defines the configuration");
        id ours = make(ourConfiguration);
        UISceneConfiguration *theirs = make([UISceneConfiguration class]);
        CHECK_EQUAL([ours name] ?: @"(nil)", theirs.name ?: @"(nil)", "a plain configuration's name");
        CHECK_EQUAL(ROLE(ours), theirs.role, "a plain configuration's role");
        CHECK([ours sceneClass] == theirs.sceneClass && [ours delegateClass] == theirs.delegateClass && [ours storyboard] == theirs.storyboard, "and its classes and storyboard");
        id one = [ourConfiguration configurationWithName:@"Main" sessionRole:UIWindowSceneSessionRoleExternalDisplay];
        UISceneConfiguration *two = [UISceneConfiguration configurationWithName:@"Main" sessionRole:UIWindowSceneSessionRoleExternalDisplay];
        CHECK_EQUAL(ROLE(one), two.role, "and its role");
        [one setSceneClass:[UIResponder class]];
        [one setDelegateClass:[NSObject class]];
        two.sceneClass = [UIResponder class];
        two.delegateClass = [NSObject class];
        id copyOne = [one copy];
        UISceneConfiguration *copyTwo = [two copy];
        CHECK([copyOne sceneClass] == copyTwo.sceneClass && [copyOne delegateClass] == copyTwo.delegateClass, "a copy keeps the configuration");
        CHECK(copyOne != one && copyTwo != two, "a copy is another object");
        CHECK_EQUAL(@([ourConfiguration supportsSecureCoding]), @([UISceneConfiguration supportsSecureCoding]), "the configuration's secure coding");
        id backOne = nil, backTwoObject = nil;
        CHECK_EQUAL(coded(one, ourConfiguration, &backOne), coded(two, [UISceneConfiguration class], &backTwoObject), "a configuration is archived");
        UISceneConfiguration *backTwo = backTwoObject;
        BOOL same = [ROLE(backOne) isEqual:backTwo.role] && [backOne sceneClass] == backTwo.sceneClass && [backOne delegateClass] == backTwo.delegateClass;
        CHECK(same, "and read back as the system's is");

        Class ourConditions = NSClassFromString(@"RevenantHostUISceneActivationConditions");
        id conditions = make(ourConditions);
        UISceneActivationConditions *systemConditions = make([UISceneActivationConditions class]);
        CHECK_EQUAL([[conditions canActivateForTargetContentIdentifierPredicate] predicateFormat], systemConditions.canActivateForTargetContentIdentifierPredicate.predicateFormat, "the default can activate predicate");
        CHECK_EQUAL([[conditions prefersToActivateForTargetContentIdentifierPredicate] predicateFormat], systemConditions.prefersToActivateForTargetContentIdentifierPredicate.predicateFormat, "the default prefers to activate predicate");
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'a'"];
        [conditions setCanActivateForTargetContentIdentifierPredicate:predicate];
        systemConditions.canActivateForTargetContentIdentifierPredicate = predicate;
        id backConditions = nil, backSystemObject = nil;
        CHECK_EQUAL(coded(conditions, ourConditions, &backConditions), coded(systemConditions, [UISceneActivationConditions class], &backSystemObject), "activation conditions are archived");
        UISceneActivationConditions *backSystem = backSystemObject;
        CHECK_EQUAL([[backConditions canActivateForTargetContentIdentifierPredicate] predicateFormat], backSystem.canActivateForTargetContentIdentifierPredicate.predicateFormat, "and read back");
        CHECK_EQUAL(@([ourConditions supportsSecureCoding]), @([UISceneActivationConditions supportsSecureCoding]), "the conditions' secure coding");

        id options = make(NSClassFromString(@"RevenantHostUISceneOpenExternalURLOptions"));
        UISceneOpenExternalURLOptions *systemOptions = make([UISceneOpenExternalURLOptions class]);
        CHECK_EQUAL(@([options universalLinksOnly]), @(systemOptions.universalLinksOnly), "universal links only starts off");
        id destruction = make(NSClassFromString(@"RevenantHostUIWindowSceneDestructionRequestOptions"));
        UIWindowSceneDestructionRequestOptions *systemDestruction = make([UIWindowSceneDestructionRequestOptions class]);
        CHECK_EQUAL(@([destruction windowDismissalAnimation]), @(systemDestruction.windowDismissalAnimation), "the dismissal animation starts as the system's");
        id restrictions = make(NSClassFromString(@"RevenantHostUISceneSizeRestrictions"));
        CHECK(restrictions != nil, "size restrictions can be made");
        id request = make(NSClassFromString(@"RevenantHostUISceneActivationRequestOptions"));
        UISceneActivationRequestOptions *systemRequest = make([UISceneActivationRequestOptions class]);
        CHECK([request requestingScene] == nil && systemRequest.requestingScene == nil, "an activation request names no scene");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
