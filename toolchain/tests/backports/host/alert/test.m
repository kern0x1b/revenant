#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wnonnull"

@interface NSObject (CharonHostAlert)
- (void (^)(UIAlertAction *action))charon_handler;
- (UIView *)charon_nativeView;
@end

@interface Recorder : NSObject
@property (nonatomic) NSInteger count;
@property (nonatomic, strong) id last;
- (void)fire:(id)sender;
- (void)notice:(NSNotification *)notification;
@end

@implementation Recorder
- (void)fire:(id)sender
{
    self.count++;
    self.last = sender;
}
- (void)notice:(NSNotification *)notification
{
    self.count++;
    self.last = notification.object;
}
@end

static UIAlertAction *action_of(Class cls, NSString *title, UIAlertActionStyle style, void (^handler)(UIAlertAction *action))
{
    return ((UIAlertAction *(*)(id, SEL, NSString *, UIAlertActionStyle, id))objc_msgSend)(cls, @selector(actionWithTitle:style:handler:), title, style, handler);
}

static UIAlertController *controller_of(Class cls, NSString *title, NSString *message, UIAlertControllerStyle style)
{
    return ((UIAlertController *(*)(id, SEL, NSString *, NSString *, UIAlertControllerStyle))objc_msgSend)(cls, @selector(alertControllerWithTitle:message:preferredStyle:), title, message, style);
}

static NSString *outcome(void (^block)(void))
{
    @try {
        block();
        return @"no exception";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

static NSString *exception_name(void (^block)(void))
{
    @try {
        block();
        return @"no exception";
    } @catch (NSException *exception) {
        return exception.name;
    }
}

static NSArray *titles_of(UIView *view)
{
    NSMutableArray *titles = [NSMutableArray array];
    NSInteger count = [(id)view numberOfButtons];
    for (NSInteger index = 0; index < count; index++)
        [titles addObject:[(id)view buttonTitleAtIndex:index]];
    return titles;
}

static void compare_actions(Class system, Class mine)
{
    UIAlertActionStyle styles[] = {UIAlertActionStyleDefault, UIAlertActionStyleCancel, UIAlertActionStyleDestructive};
    for (size_t index = 0; index < 3; index++) {
        UIAlertAction *theirs = action_of(system, @"Title", styles[index], nil);
        UIAlertAction *ours = action_of(mine, @"Title", styles[index], nil);
        CHECK_EQUAL(ours.title, theirs.title, "action title matches the system");
        CHECK_EQUAL(@(ours.style), @(theirs.style), "action style matches the system");
        CHECK_EQUAL(@(ours.enabled), @(theirs.enabled), "action from the factory is enabled like the system's");
    }
    UIAlertAction *oursNil = action_of(mine, nil, UIAlertActionStyleDefault, nil);
    CHECK(oursNil.title == nil, "nil action title stays nil, which the system checks only on a pad");
    UIAlertAction *theirsNew = [system new];
    UIAlertAction *oursNew = [mine new];
    CHECK_EQUAL(oursNew.title, theirsNew.title, "plain init title matches the system");
    CHECK_EQUAL(@(oursNew.style), @(theirsNew.style), "plain init style matches the system");
    CHECK_EQUAL(@(oursNew.enabled), @(theirsNew.enabled), "plain init enabled matches the system");
    CHECK([mine conformsToProtocol:@protocol(NSCopying)] == [system conformsToProtocol:@protocol(NSCopying)], "action adopts NSCopying like the system");

    __block NSInteger calls = 0;
    UIAlertAction *theirs = action_of(system, @"Copy", UIAlertActionStyleDestructive, ^(UIAlertAction *action) { calls++; });
    UIAlertAction *ours = action_of(mine, @"Copy", UIAlertActionStyleDestructive, ^(UIAlertAction *action) { calls++; });
    theirs.enabled = NO;
    ours.enabled = NO;
    UIAlertAction *theirsCopy = [theirs copy];
    UIAlertAction *oursCopy = [ours copy];
    CHECK((oursCopy == ours) == (theirsCopy == theirs), "copy is a distinct object like the system's");
    CHECK([oursCopy class] == [ours class], "copy keeps the class");
    CHECK_EQUAL(oursCopy.title, theirsCopy.title, "copy keeps the title like the system");
    CHECK_EQUAL(@(oursCopy.style), @(theirsCopy.style), "copy keeps the style like the system");
    CHECK_EQUAL(@(oursCopy.enabled), @(theirsCopy.enabled), "copy keeps enabled like the system");
    CHECK([oursCopy isEqual:ours] == [theirsCopy isEqual:theirs], "copy equality matches the system");
    [oursCopy charon_handler](oursCopy);
    CHECK(calls == 1, "copy keeps the handler");
    oursCopy.enabled = YES;
    CHECK(!ours.enabled, "enabling a copy leaves the original");
}

static void compare_controllers(Class system, Class mine, Class systemAction, Class mineAction)
{
    UIAlertControllerStyle styles[] = {UIAlertControllerStyleActionSheet, UIAlertControllerStyleAlert};
    for (size_t index = 0; index < 2; index++) {
        UIAlertController *theirs = controller_of(system, @"T", @"M", styles[index]);
        UIAlertController *ours = controller_of(mine, @"T", @"M", styles[index]);
        CHECK_EQUAL(ours.title, theirs.title, "controller title matches the system");
        CHECK_EQUAL(ours.message, theirs.message, "controller message matches the system");
        CHECK_EQUAL(@(ours.preferredStyle), @(theirs.preferredStyle), "controller style matches the system");
        CHECK_EQUAL(@(ours.actions.count), @(theirs.actions.count), "new controller has no actions like the system");
        CHECK((ours.actions != nil) == (theirs.actions != nil), "actions array exists like the system's");
        CHECK_EQUAL(@(ours.textFields.count), @(theirs.textFields.count), "new controller has no text fields like the system");
        CHECK((ours.textFields != nil) == (theirs.textFields != nil), "text field array exists like the system's");
        CHECK(ours.preferredAction == nil && theirs.preferredAction == nil, "no preferred action at first");
        ours.title = @"New";
        theirs.title = @"New";
        ours.message = nil;
        theirs.message = nil;
        CHECK_EQUAL(ours.title, theirs.title, "title setter matches the system");
        CHECK_EQUAL(ours.message, theirs.message, "message setter matches the system");
    }
    UIAlertController *theirsNil = controller_of(system, nil, nil, UIAlertControllerStyleAlert);
    UIAlertController *oursNil = controller_of(mine, nil, nil, UIAlertControllerStyleAlert);
    CHECK_EQUAL(oursNil.title, theirsNil.title, "nil title matches the system");
    CHECK_EQUAL(oursNil.message, theirsNil.message, "nil message matches the system");
    CHECK_EQUAL(@(((UIAlertController *)[[mine alloc] init]).preferredStyle), @(((UIAlertController *)[[system alloc] init]).preferredStyle), "plain init style matches the system");

    UIAlertController *theirs = controller_of(system, @"T", nil, UIAlertControllerStyleAlert);
    UIAlertController *ours = controller_of(mine, @"T", nil, UIAlertControllerStyleAlert);
    UIAlertAction *theirsCancel = action_of(systemAction, @"C", UIAlertActionStyleCancel, nil);
    UIAlertAction *oursCancel = action_of(mineAction, @"C", UIAlertActionStyleCancel, nil);
    UIAlertAction *theirsDefault = action_of(systemAction, @"D", UIAlertActionStyleDefault, nil);
    UIAlertAction *oursDefault = action_of(mineAction, @"D", UIAlertActionStyleDefault, nil);
    [theirs addAction:theirsDefault];
    [ours addAction:oursDefault];
    [theirs addAction:theirsCancel];
    [ours addAction:oursCancel];
    CHECK_EQUAL(outcome(^{ [ours addAction:action_of(mineAction, @"C2", UIAlertActionStyleCancel, nil)]; }),
                outcome(^{ [theirs addAction:action_of(systemAction, @"C2", UIAlertActionStyleCancel, nil)]; }),
                "second cancel action raises like the system");
    CHECK_EQUAL(outcome(^{ [ours addAction:[oursCancel copy]]; }), outcome(^{ [theirs addAction:[theirsCancel copy]]; }), "copy of the cancel action raises like the system");
    CHECK_EQUAL(outcome(^{ [ours addAction:oursDefault]; }), outcome(^{ [theirs addAction:theirsDefault]; }), "same default action twice is accepted like the system");
    CHECK_EQUAL(exception_name(^{ [ours addAction:nil]; }), exception_name(^{ [theirs addAction:nil]; }), "nil action raises like the system");
    CHECK_EQUAL(@(ours.actions.count), @(theirs.actions.count), "action count after failures matches the system");
    CHECK(ours.actions[0] == oursDefault && ours.actions[1] == oursCancel && ours.actions[2] == oursDefault, "actions keep order and identity");
    NSArray *snapshot = ours.actions;
    [ours addAction:action_of(mineAction, @"E", UIAlertActionStyleDefault, nil)];
    CHECK(snapshot.count == 3 && ours.actions.count == 4, "actions returns a snapshot");

    CHECK_EQUAL(outcome(^{ ours.preferredAction = action_of(mineAction, @"X", UIAlertActionStyleDefault, nil); }),
                outcome(^{ theirs.preferredAction = action_of(systemAction, @"X", UIAlertActionStyleDefault, nil); }),
                "foreign preferred action raises like the system");
    CHECK(ours.preferredAction == nil, "failed preferred action leaves nil");
    CHECK_EQUAL(outcome(^{ ours.preferredAction = [oursDefault copy]; }), outcome(^{ theirs.preferredAction = [theirsDefault copy]; }), "copy of a member as preferred action raises like the system");
    CHECK_EQUAL(outcome(^{ ours.preferredAction = oursCancel; }), outcome(^{ theirs.preferredAction = theirsCancel; }), "member preferred action is accepted like the system");
    CHECK(ours.preferredAction == oursCancel, "preferred action is kept");
    CHECK_EQUAL(outcome(^{ ours.preferredAction = nil; }), outcome(^{ theirs.preferredAction = nil; }), "nil preferred action is accepted like the system");
    CHECK(ours.preferredAction == nil, "preferred action resets to nil");

    UIAlertController *theirsSheet = controller_of(system, @"T", nil, UIAlertControllerStyleActionSheet);
    UIAlertController *oursSheet = controller_of(mine, @"T", nil, UIAlertControllerStyleActionSheet);
    CHECK_EQUAL(outcome(^{ [oursSheet addTextFieldWithConfigurationHandler:nil]; }), outcome(^{ [theirsSheet addTextFieldWithConfigurationHandler:nil]; }), "text field on an action sheet raises like the system");

    __block NSInteger theirsCalls = 0, oursCalls = 0;
    __block UITextField *theirsField, *oursField;
    [theirs addTextFieldWithConfigurationHandler:^(UITextField *field) { theirsCalls++; theirsField = field; field.text = @"x"; }];
    [ours addTextFieldWithConfigurationHandler:^(UITextField *field) { oursCalls++; oursField = field; field.text = @"x"; }];
    CHECK_EQUAL(@(oursCalls), @(theirsCalls), "configuration handler runs synchronously like the system's");
    CHECK_EQUAL(@(ours.textFields.count), @(theirs.textFields.count), "text field count matches the system");
    CHECK([ours.textFields[0] isKindOfClass:[UITextField class]], "text field is a UITextField");
    CHECK(ours.textFields[0] == oursField && theirs.textFields[0] == theirsField, "configured field is the listed field");
    CHECK_EQUAL(ours.textFields[0].text, theirs.textFields[0].text, "configured text is kept like the system");
    CHECK_EQUAL(outcome(^{ [ours addTextFieldWithConfigurationHandler:nil]; }), outcome(^{ [theirs addTextFieldWithConfigurationHandler:nil]; }), "second text field is accepted like the system");
    CHECK_EQUAL(exception_name(^{ [ours addTextFieldWithConfigurationHandler:nil]; }), @"NSInternalInconsistencyException", "third text field raises on this backport, which UIAlertView limits to two");
    CHECK_EQUAL(outcome(^{ [theirs addTextFieldWithConfigurationHandler:nil]; }), @"no exception", "the system accepts a third text field");

    CHECK(ours.popoverPresentationController == nil, "alert style has no popover presentation");
    UIView *anchor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    id popover = oursSheet.popoverPresentationController;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        CHECK(popover != nil && popover == oursSheet.popoverPresentationController, "action sheet on a pad has one popover presentation object");
        [popover setSourceView:anchor];
        [popover setSourceRect:CGRectMake(1, 2, 3, 4)];
        CHECK([popover sourceView] == anchor, "popover keeps the source view");
        CHECK(CGRectEqualToRect([popover sourceRect], CGRectMake(1, 2, 3, 4)), "popover keeps the source rect");
        CHECK_EQUAL(@([popover permittedArrowDirections]), @(UIPopoverArrowDirectionAny), "popover allows any arrow direction");
    }
}

static UIAlertController *make(Class controller, Class action, UIAlertControllerStyle style, NSArray *specs, NSMutableArray *log)
{
    UIAlertController *alert = controller_of(controller, @"T", @"M", style);
    for (NSArray *spec in specs) {
        NSString *title = spec[0] == [NSNull null] ? nil : spec[0];
        [alert addAction:action_of(action, title, [spec[1] integerValue], ^(UIAlertAction *fired) {
            [log addObject:fired.title ? fired.title : @"<nil>"];
        })];
    }
    return alert;
}

static void check_mapping(Class controller, Class action)
{
    NSMutableArray *log = [NSMutableArray array];
    UIAlertController *alert = make(controller, action, UIAlertControllerStyleAlert, @[@[@"A", @0], @[@"C", @1], @[@"D", @2]], log);
    UIAlertView *view = (UIAlertView *)[alert charon_nativeView];
    CHECK([view isKindOfClass:[UIAlertView class]], "alert style builds a UIAlertView");
    CHECK_EQUAL(titles_of(view), (@[@"C", @"A", @"D"]), "alert view lists cancel first, then the others in order");
    CHECK_EQUAL(@(view.cancelButtonIndex), @0, "alert view cancel index");
    CHECK_EQUAL(@(view.firstOtherButtonIndex), @1, "alert view first other index");
    CHECK_EQUAL(view.title, @"T", "alert view title");
    CHECK_EQUAL(view.message, @"M", "alert view message");
    CHECK_EQUAL(@(view.alertViewStyle), @(UIAlertViewStyleDefault), "no text fields gives the default style");
    CHECK(view.delegate == (id)alert, "controller is the alert view delegate");
    alert.message = @"Changed";
    CHECK_EQUAL(view.message, @"Changed", "message change reaches the alert view");
    [view.delegate alertView:view didDismissWithButtonIndex:2];
    CHECK_EQUAL(log, (@[@"D"]), "dismissal with an index runs that action's handler");
    [(id)alert alertView:view didDismissWithButtonIndex:2];
    CHECK_EQUAL(log, (@[@"D"]), "a stale alert view does not run handlers again");

    [log removeAllObjects];
    alert = make(controller, action, UIAlertControllerStyleAlert, @[@[@"A", @0], @[[NSNull null], @0]], log);
    view = (UIAlertView *)[alert charon_nativeView];
    CHECK_EQUAL(titles_of(view), (@[@"A", @""]), "alert without cancel keeps order and shows a nil title as empty");
    CHECK_EQUAL(@(view.cancelButtonIndex), @(-1), "alert without cancel has no cancel index");
    CHECK_EQUAL(@(view.firstOtherButtonIndex), @0, "alert without cancel starts others at zero");
    CHECK([(id)alert alertViewShouldEnableFirstOtherButton:view], "enabled first other action enables the button");
    alert.actions[0].enabled = NO;
    CHECK(![(id)alert alertViewShouldEnableFirstOtherButton:view], "disabled first other action disables the button");
    [view.delegate alertView:view didDismissWithButtonIndex:0];
    CHECK_EQUAL(log, (@[]), "dismissal on a disabled action runs no handler");
    view = (UIAlertView *)[alert charon_nativeView];
    [view.delegate alertView:view didDismissWithButtonIndex:1];
    CHECK_EQUAL(log, (@[@"<nil>"]), "a rebuilt alert view runs handlers again");
    view = (UIAlertView *)[alert charon_nativeView];
    [view.delegate alertView:view didDismissWithButtonIndex:-1];
    CHECK_EQUAL(log, (@[@"<nil>"]), "index -1 runs no handler");

    alert = make(controller, action, UIAlertControllerStyleAlert, @[@[@"C", @1]], log);
    view = (UIAlertView *)[alert charon_nativeView];
    CHECK_EQUAL(titles_of(view), (@[@"C"]), "cancel-only alert");
    CHECK_EQUAL(@(view.firstOtherButtonIndex), @(-1), "cancel-only alert has no other button");
    CHECK([(id)alert alertViewShouldEnableFirstOtherButton:view], "without another button the delegate answers yes");

    [log removeAllObjects];
    UIAlertController *sheet = make(controller, action, UIAlertControllerStyleActionSheet, @[@[@"A", @0], @[@"D1", @2], @[@"C", @1], @[@"D2", @2]], log);
    UIActionSheet *actionSheet = (UIActionSheet *)[sheet charon_nativeView];
    CHECK([actionSheet isKindOfClass:[UIActionSheet class]], "action sheet style builds a UIActionSheet");
    CHECK_EQUAL(titles_of(actionSheet), (@[@"A", @"D1", @"D2", @"C"]), "action sheet keeps order and puts cancel last");
    CHECK_EQUAL(@(actionSheet.cancelButtonIndex), @3, "action sheet cancel index");
    CHECK_EQUAL(@(actionSheet.destructiveButtonIndex), @1, "action sheet destructive index is the first destructive action");
    CHECK_EQUAL(actionSheet.title, @"T\nM", "action sheet shows title and message");
    [actionSheet.delegate actionSheet:actionSheet didDismissWithButtonIndex:3];
    CHECK_EQUAL(log, (@[@"C"]), "action sheet cancel runs the cancel handler");
    sheet.title = nil;
    CHECK_EQUAL(((UIActionSheet *)[sheet charon_nativeView]).title, @"M", "action sheet with only a message shows it");
    sheet.message = @"";
    CHECK(((UIActionSheet *)[sheet charon_nativeView]).title == nil, "action sheet without title and message has none");
    UIAlertController *plain = make(controller, action, UIAlertControllerStyleActionSheet, @[@[@"A", @0]], log);
    actionSheet = (UIActionSheet *)[plain charon_nativeView];
    CHECK_EQUAL(@(actionSheet.cancelButtonIndex), @(-1), "action sheet without cancel has no cancel index");
    CHECK_EQUAL(@(actionSheet.destructiveButtonIndex), @(-1), "action sheet without destructive has no destructive index");

    alert = make(controller, action, UIAlertControllerStyleAlert, @[@[@"OK", @0]], log);
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Name"; }];
    CHECK_EQUAL(@(((UIAlertView *)[alert charon_nativeView]).alertViewStyle), @(UIAlertViewStylePlainTextInput), "one plain field gives plain text input");
    alert.textFields[0].secureTextEntry = YES;
    CHECK_EQUAL(@(((UIAlertView *)[alert charon_nativeView]).alertViewStyle), @(UIAlertViewStyleSecureTextInput), "one secure field gives secure text input");

    [log removeAllObjects];
    Recorder *recorder = [Recorder new];
    Recorder *listener = [Recorder new];
    __block UITextField *login, *password;
    alert = make(controller, action, UIAlertControllerStyleAlert, @[@[@"Cancel", @1], @[@"Sign In", @0]], log);
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        login = field;
        field.placeholder = @"Login";
        field.text = @"user";
        field.keyboardType = UIKeyboardTypeEmailAddress;
        [field addTarget:recorder action:@selector(fire:) forControlEvents:UIControlEventEditingChanged];
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        password = field;
        field.placeholder = @"Password";
        field.secureTextEntry = NO;
    }];
    [[NSNotificationCenter defaultCenter] addObserver:listener selector:@selector(notice:) name:UITextFieldTextDidChangeNotification object:login];
    view = (UIAlertView *)[alert charon_nativeView];
    CHECK_EQUAL(@(view.alertViewStyle), @(UIAlertViewStyleLoginAndPasswordInput), "two fields give login and password input");
    UITextField *nativeLogin = [view textFieldAtIndex:0];
    UITextField *nativePassword = [view textFieldAtIndex:1];
    CHECK_EQUAL(nativeLogin.text, @"user", "configured text reaches the native field");
    CHECK_EQUAL(nativeLogin.placeholder, @"Login", "configured placeholder reaches the native field");
    CHECK_EQUAL(@(nativeLogin.keyboardType), @(UIKeyboardTypeEmailAddress), "configured keyboard reaches the native field");
    CHECK_EQUAL(nativePassword.placeholder, @"Password", "second placeholder reaches the native field");
    CHECK(!nativePassword.secureTextEntry, "a plain second field stays plain");
    CHECK_EQUAL([nativeLogin actionsForTarget:recorder forControlEvent:UIControlEventEditingChanged], (@[@"fire:"]), "configured target action reaches the native field");
    nativeLogin.text = @"typed";
    [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:nativeLogin];
    CHECK_EQUAL(login.text, @"typed", "native change is copied to the configured field");
    CHECK(listener.count == 1 && listener.last == login, "change notification is posted for the configured field");
    nativePassword.text = @"secret";
    [view.delegate alertView:view didDismissWithButtonIndex:1];
    CHECK_EQUAL(log, (@[@"Sign In"]), "sign in handler runs");
    CHECK_EQUAL(password.text, @"secret", "text typed before dismissal is visible to the handler's fields");
    CHECK(alert.textFields[1] == password, "text fields keep their identity after dismissal");
    [[NSNotificationCenter defaultCenter] removeObserver:listener];
}

int main(void)
{
    @autoreleasepool {
        Class mineAction = NSClassFromString(@"CharonHostUIAlertAction");
        Class mineController = NSClassFromString(@"CharonHostUIAlertController");
        CHECK(mineAction != Nil && mineController != Nil, "renamed backport classes are loaded");
        CHECK([mineController isSubclassOfClass:[UIViewController class]], "controller is a view controller");
        compare_actions([UIAlertAction class], mineAction);
        compare_controllers([UIAlertController class], mineController, [UIAlertAction class], mineAction);
        check_mapping(mineController, mineAction);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
