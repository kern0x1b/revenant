#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface UIAlertAction (RevenantAlertController)
- (void (^)(UIAlertAction *action))revenant_handler;
@end

@interface RevenantAlertPopoverPresentation : NSObject
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;
@property (nonatomic, strong) UIBarButtonItem *barButtonItem;
@property (nonatomic) UIPopoverArrowDirection permittedArrowDirections;
@property (nonatomic, weak) id delegate;
@property (nonatomic, copy) NSArray *passthroughViews;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic) UIEdgeInsets popoverLayoutMargins;
@end

@implementation RevenantAlertPopoverPresentation

@synthesize sourceView = _sourceView, sourceRect = _sourceRect, barButtonItem = _barButtonItem,
            permittedArrowDirections = _permittedArrowDirections, delegate = _delegate, passthroughViews = _passthroughViews,
            backgroundColor = _backgroundColor, popoverLayoutMargins = _popoverLayoutMargins;

- (instancetype)init
{
    if ((self = [super init]))
        _permittedArrowDirections = UIPopoverArrowDirectionAny;
    return self;
}

@end

@interface UIAlertController () <UIAlertViewDelegate, UIActionSheetDelegate>
- (void)revenant_presentFromViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)revenant_dismissAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)revenant_isPresented;
@end

static char revenant_presented_alert_key;

static void (*revenant_present_original)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void (*revenant_dismiss_original)(id, SEL, BOOL, void (^)(void));
static id (*revenant_presented_original)(id, SEL);

static UIViewController *revenant_presentation_host(UIViewController *controller)
{
    while (controller.parentViewController)
        controller = controller.parentViewController;
    return controller;
}

static UIAlertController *revenant_presented_alert(UIViewController *controller)
{
    return controller ? objc_getAssociatedObject(revenant_presentation_host(controller), &revenant_presented_alert_key) : nil;
}

static UIViewController *revenant_natively_presented(UIViewController *controller)
{
    if (revenant_presented_original)
        return revenant_presented_original(controller, @selector(presentedViewController));
    return controller.presentedViewController;
}

static void revenant_present(UIViewController *receiver, SEL selector, UIViewController *controller, BOOL animated, void (^completion)(void))
{
    if ([controller isKindOfClass:[UIAlertController class]]) {
        [(UIAlertController *)controller revenant_presentFromViewController:receiver animated:animated completion:completion];
        return;
    }
    UIAlertController *alert = revenant_presented_alert(receiver);
    if (alert) {
        NSLog(@"Warning: Attempt to present %@ on %@ which is already presenting %@", controller, revenant_presentation_host(receiver), alert);
        return;
    }
    revenant_present_original(receiver, selector, controller, animated, completion);
}

static void revenant_dismiss(UIViewController *receiver, SEL selector, BOOL animated, void (^completion)(void))
{
    if ([receiver isKindOfClass:[UIAlertController class]] && [(UIAlertController *)receiver revenant_isPresented]) {
        [(UIAlertController *)receiver revenant_dismissAnimated:animated completion:completion];
        return;
    }
    UIAlertController *alert = revenant_presented_alert(receiver);
    if (alert) {
        [alert revenant_dismissAnimated:animated completion:completion];
        return;
    }
    for (UIViewController *above = revenant_natively_presented(receiver); above; above = revenant_natively_presented(above))
        [revenant_presented_alert(above) revenant_dismissAnimated:NO completion:nil];
    revenant_dismiss_original(receiver, selector, animated, completion);
}

static id revenant_presented(UIViewController *receiver, SEL selector)
{
    id presented = revenant_presented_original(receiver, selector);
    return presented ? presented : revenant_presented_alert(receiver);
}

static void revenant_install_presentation(void)
{
    Class controller = [UIViewController class];
    Method present = class_getInstanceMethod(controller, @selector(presentViewController:animated:completion:));
    Method dismiss = class_getInstanceMethod(controller, @selector(dismissViewControllerAnimated:completion:));
    Method presented = class_getInstanceMethod(controller, @selector(presentedViewController));
    if (!present || !dismiss || !presented)
        return;
    revenant_present_original = (void (*)(id, SEL, UIViewController *, BOOL, void (^)(void)))method_setImplementation(present, (IMP)revenant_present);
    revenant_dismiss_original = (void (*)(id, SEL, BOOL, void (^)(void)))method_setImplementation(dismiss, (IMP)revenant_dismiss);
    revenant_presented_original = (id (*)(id, SEL))method_setImplementation(presented, (IMP)revenant_presented);
}

static NSString *revenant_button_title(UIAlertAction *action)
{
    return action.title ? action.title : @"";
}

static NSString *revenant_sheet_title(NSString *title, NSString *message)
{
    if (title.length && message.length)
        return [NSString stringWithFormat:@"%@\n%@", title, message];
    if (title.length)
        return title;
    return message.length ? message : nil;
}

static void revenant_place(NSMutableArray *buttons, NSInteger index, UIAlertAction *action)
{
    if (index < 0 || !action)
        return;
    while ((NSInteger)buttons.count <= index)
        [buttons addObject:[NSNull null]];
    [buttons replaceObjectAtIndex:index withObject:action];
}

static UIAlertAction *revenant_action_at(NSArray *buttons, NSInteger index)
{
    if (index < 0 || index >= (NSInteger)buttons.count)
        return nil;
    id action = [buttons objectAtIndex:index];
    return action == [NSNull null] ? nil : action;
}

static UIAlertViewStyle revenant_alert_view_style(NSArray *fields)
{
    if (fields.count == 0)
        return UIAlertViewStyleDefault;
    if (fields.count == 1)
        return [[fields objectAtIndex:0] isSecureTextEntry] ? UIAlertViewStyleSecureTextInput : UIAlertViewStylePlainTextInput;
    return UIAlertViewStyleLoginAndPasswordInput;
}

static BOOL revenant_differs(id value, id standard)
{
    return value != standard && ![value isEqual:standard];
}

static void revenant_copy_field(UITextField *from, UITextField *to)
{
    UITextField *pristine = [[UITextField alloc] init];
    if (revenant_differs(from.placeholder, pristine.placeholder))
        to.placeholder = from.placeholder;
    if (revenant_differs(from.font, pristine.font))
        to.font = from.font;
    if (revenant_differs(from.textColor, pristine.textColor))
        to.textColor = from.textColor;
    if (from.textAlignment != pristine.textAlignment)
        to.textAlignment = from.textAlignment;
    if (from.clearButtonMode != pristine.clearButtonMode)
        to.clearButtonMode = from.clearButtonMode;
    if (from.clearsOnBeginEditing != pristine.clearsOnBeginEditing)
        to.clearsOnBeginEditing = from.clearsOnBeginEditing;
    if (from.adjustsFontSizeToFitWidth != pristine.adjustsFontSizeToFitWidth)
        to.adjustsFontSizeToFitWidth = from.adjustsFontSizeToFitWidth;
    if (from.minimumFontSize != pristine.minimumFontSize)
        to.minimumFontSize = from.minimumFontSize;
    if (from.leftView) {
        to.leftView = from.leftView;
        to.leftViewMode = from.leftViewMode;
    }
    if (from.rightView) {
        to.rightView = from.rightView;
        to.rightViewMode = from.rightViewMode;
    }
    if (from.inputView)
        to.inputView = from.inputView;
    if (from.inputAccessoryView)
        to.inputAccessoryView = from.inputAccessoryView;
    if (from.keyboardType != pristine.keyboardType)
        to.keyboardType = from.keyboardType;
    if (from.keyboardAppearance != pristine.keyboardAppearance)
        to.keyboardAppearance = from.keyboardAppearance;
    if (from.returnKeyType != pristine.returnKeyType)
        to.returnKeyType = from.returnKeyType;
    if (from.autocapitalizationType != pristine.autocapitalizationType)
        to.autocapitalizationType = from.autocapitalizationType;
    if (from.autocorrectionType != pristine.autocorrectionType)
        to.autocorrectionType = from.autocorrectionType;
    if (from.spellCheckingType != pristine.spellCheckingType)
        to.spellCheckingType = from.spellCheckingType;
    if (from.enablesReturnKeyAutomatically != pristine.enablesReturnKeyAutomatically)
        to.enablesReturnKeyAutomatically = from.enablesReturnKeyAutomatically;
    if (from.delegate)
        to.delegate = from.delegate;
    if (from.tag != pristine.tag)
        to.tag = from.tag;
    if (revenant_differs(from.accessibilityLabel, pristine.accessibilityLabel))
        to.accessibilityLabel = from.accessibilityLabel;
    to.secureTextEntry = from.secureTextEntry;
    to.text = from.text;
}

static void revenant_copy_actions(UITextField *from, UITextField *to)
{
    UIControlEvents events = from.allControlEvents;
    for (id target in from.allTargets) {
        id receiver = target == [NSNull null] ? nil : target;
        for (NSUInteger bit = 0; bit < 32; bit++) {
            UIControlEvents event = (UIControlEvents)1 << bit;
            if (!(events & event))
                continue;
            for (NSString *action in [from actionsForTarget:receiver forControlEvent:event])
                [to addTarget:receiver action:NSSelectorFromString(action) forControlEvents:event];
        }
    }
}

@implementation UIAlertController {
    NSString *_message;
    UIAlertControllerStyle _preferredStyle;
    NSMutableArray *_actions;
    NSMutableArray *_textFields;
    RevenantAlertPopoverPresentation *_popover;
    UIAlertView *_alertView;
    UIActionSheet *_actionSheet;
    NSArray *_buttonActions;
    NSArray *_nativeFields;
    UIViewController *_presenter;
    void (^_presentCompletion)(void);
    void (^_dismissCompletion)(void);
    BOOL _dismissing;
}

@dynamic preferredAction, severity;

+ (void)initialize
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (objc_getClass("UIAlertController") == [UIAlertController class])
            revenant_install_presentation();
    });
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle
{
    UIAlertController *controller = [[self alloc] init];
    controller.title = title;
    controller->_message = [message copy];
    controller->_preferredStyle = preferredStyle;
    return controller;
}

- (instancetype)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    if ((self = [super initWithNibName:name bundle:bundle])) {
        _preferredStyle = UIAlertControllerStyleAlert;
        _actions = [NSMutableArray array];
        _textFields = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [self revenant_releaseNativeView];
}

- (NSArray *)actions
{
    return _actions ? [_actions copy] : [NSArray array];
}

- (void)addAction:(UIAlertAction *)action
{
    if (!_actions)
        _actions = [NSMutableArray array];
    if (action.style == UIAlertActionStyleCancel) {
        for (UIAlertAction *existing in _actions) {
            if (existing.style == UIAlertActionStyleCancel)
                [NSException raise:NSInternalInconsistencyException format:@"UIAlertController can only have one action with a style of UIAlertActionStyleCancel"];
        }
    }
    [_actions addObject:action];
}

- (NSArray *)textFields
{
    return _textFields ? [_textFields copy] : [NSArray array];
}

- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *textField))configurationHandler
{
    if (_preferredStyle == UIAlertControllerStyleActionSheet)
        [NSException raise:NSInternalInconsistencyException format:@"Text fields can only be added to an alert controller of style UIAlertControllerStyleAlert"];
    if (!_textFields)
        _textFields = [NSMutableArray array];
    if (_textFields.count >= 2)
        [NSException raise:NSInternalInconsistencyException format:@"UIAlertController shows its text fields in a UIAlertView on this iOS, which holds at most two"];
    UITextField *field = [[UITextField alloc] init];
    [_textFields addObject:field];
    if (configurationHandler)
        configurationHandler(field);
}

- (NSString *)message
{
    return _message;
}

- (void)setMessage:(NSString *)message
{
    _message = [message copy];
    _alertView.message = _message;
    _actionSheet.title = revenant_sheet_title(self.title, _message);
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    _alertView.title = self.title;
    _actionSheet.title = revenant_sheet_title(self.title, _message);
}

- (UIAlertControllerStyle)preferredStyle
{
    return _preferredStyle;
}

- (UIPopoverPresentationController *)popoverPresentationController
{
    if (_preferredStyle != UIAlertControllerStyleActionSheet || [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)
        return nil;
    if (!_popover)
        _popover = [[RevenantAlertPopoverPresentation alloc] init];
    return (id)_popover;
}

- (UIViewController *)presentingViewController
{
    return _presenter ? _presenter : [super presentingViewController];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return _presenter ? [_presenter supportedInterfaceOrientations] : [super supportedInterfaceOrientations];
}

- (BOOL)shouldAutorotate
{
    return _presenter ? [_presenter shouldAutorotate] : [super shouldAutorotate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return _presenter ? [_presenter shouldAutorotateToInterfaceOrientation:orientation] : [super shouldAutorotateToInterfaceOrientation:orientation];
}

- (BOOL)revenant_isPresented
{
    return _presenter != nil;
}

- (UIView *)revenant_nativeView
{
    [self revenant_releaseNativeView];
    if (_preferredStyle == UIAlertControllerStyleActionSheet)
        [self revenant_makeActionSheet];
    else
        [self revenant_makeAlertView];
    return _alertView ? (UIView *)_alertView : (UIView *)_actionSheet;
}

- (void)revenant_makeAlertView
{
    UIAlertAction *cancel = nil;
    NSMutableArray *others = [NSMutableArray array];
    for (UIAlertAction *action in _actions) {
        if (action.style == UIAlertActionStyleCancel && !cancel)
            cancel = action;
        else
            [others addObject:action];
    }
    UIAlertAction *first = others.count ? [others objectAtIndex:0] : nil;
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:self.title message:_message delegate:self
                                         cancelButtonTitle:cancel ? revenant_button_title(cancel) : nil
                                         otherButtonTitles:first ? revenant_button_title(first) : nil, nil];
    NSMutableArray *buttons = [NSMutableArray array];
    revenant_place(buttons, view.cancelButtonIndex, cancel);
    revenant_place(buttons, view.firstOtherButtonIndex, first);
    for (NSUInteger index = 1; index < others.count; index++) {
        UIAlertAction *action = [others objectAtIndex:index];
        revenant_place(buttons, [view addButtonWithTitle:revenant_button_title(action)], action);
    }
    view.alertViewStyle = revenant_alert_view_style(_textFields);
    NSMutableArray *nativeFields = [NSMutableArray array];
    for (NSUInteger index = 0; index < _textFields.count; index++) {
        UITextField *field = [_textFields objectAtIndex:index];
        UITextField *native = [view textFieldAtIndex:index];
        if (!native)
            continue;
        revenant_copy_field(field, native);
        [native addTarget:self action:@selector(revenant_nativeFieldChanged:) forControlEvents:UIControlEventEditingChanged];
        revenant_copy_actions(field, native);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revenant_nativeFieldDidChange:) name:UITextFieldTextDidChangeNotification object:native];
        [nativeFields addObject:native];
    }
    _alertView = view;
    _buttonActions = buttons;
    _nativeFields = nativeFields;
}

- (void)revenant_makeActionSheet
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:revenant_sheet_title(self.title, _message) delegate:self
                                              cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    NSMutableArray *buttons = [NSMutableArray array];
    UIAlertAction *cancel = nil;
    for (UIAlertAction *action in _actions) {
        if (action.style == UIAlertActionStyleCancel && !cancel) {
            cancel = action;
            continue;
        }
        NSInteger index = [sheet addButtonWithTitle:revenant_button_title(action)];
        revenant_place(buttons, index, action);
        if (action.style == UIAlertActionStyleDestructive && sheet.destructiveButtonIndex < 0)
            sheet.destructiveButtonIndex = index;
    }
    if (cancel) {
        NSInteger index = [sheet addButtonWithTitle:revenant_button_title(cancel)];
        sheet.cancelButtonIndex = index;
        revenant_place(buttons, index, cancel);
    }
    _actionSheet = sheet;
    _buttonActions = buttons;
    _nativeFields = nil;
}

- (void)revenant_releaseNativeView
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    for (UITextField *native in _nativeFields)
        [native removeTarget:self action:@selector(revenant_nativeFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    _alertView.delegate = nil;
    _actionSheet.delegate = nil;
    _alertView = nil;
    _actionSheet = nil;
    _buttonActions = nil;
    _nativeFields = nil;
}

- (void)revenant_presentFromViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion
{
    if (_presenter)
        [NSException raise:NSInvalidArgumentException format:@"Application tried to present modally an active controller %@.", self];
    UIViewController *host = revenant_presentation_host(controller);
    UIViewController *busy = revenant_natively_presented(host);
    if (!busy)
        busy = revenant_presented_alert(host);
    if (busy) {
        NSLog(@"Warning: Attempt to present %@ on %@ which is already presenting %@", self, host, busy);
        return;
    }
    UIWindow *window = host.isViewLoaded ? host.view.window : nil;
    if (!window) {
        NSLog(@"Warning: Attempt to present %@ on %@ whose view is not in the window hierarchy!", self, host);
        return;
    }
    _presenter = host;
    _presentCompletion = [completion copy];
    _dismissCompletion = nil;
    _dismissing = NO;
    objc_setAssociatedObject(host, &revenant_presented_alert_key, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self revenant_nativeView];
    if (_alertView) {
        [_alertView show];
        return;
    }
    RevenantAlertPopoverPresentation *popover = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? _popover : nil;
    if (popover.barButtonItem)
        [_actionSheet showFromBarButtonItem:popover.barButtonItem animated:animated];
    else if (popover.sourceView.window)
        [_actionSheet showFromRect:popover.sourceRect inView:popover.sourceView animated:animated];
    else
        [_actionSheet showInView:window];
}

- (void)revenant_dismissAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    if (_dismissing || (!_alertView && !_actionSheet))
        return;
    _dismissing = YES;
    _dismissCompletion = [completion copy];
    if (_alertView)
        [_alertView dismissWithClickedButtonIndex:_alertView.cancelButtonIndex animated:animated];
    else
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:animated];
}

- (void)revenant_syncTextFields
{
    for (NSUInteger index = 0; index < _nativeFields.count && index < _textFields.count; index++) {
        UITextField *field = [_textFields objectAtIndex:index];
        NSString *text = [[_nativeFields objectAtIndex:index] text];
        if (field.text != text && ![field.text isEqualToString:text])
            field.text = text;
    }
}

- (void)revenant_nativeFieldChanged:(UITextField *)native
{
    [self revenant_syncTextFields];
}

- (void)revenant_nativeFieldDidChange:(NSNotification *)notification
{
    [self revenant_syncTextFields];
    NSUInteger index = [_nativeFields indexOfObjectIdenticalTo:notification.object];
    if (index != NSNotFound && index < _textFields.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:[_textFields objectAtIndex:index]];
}

- (void)revenant_finishPresentation
{
    void (^completion)(void) = _presentCompletion;
    _presentCompletion = nil;
    if (completion)
        completion();
}

- (void)revenant_nativeView:(UIView *)view didDismissWithButtonIndex:(NSInteger)index
{
    if (!view || (view != _alertView && view != _actionSheet))
        return;
    __attribute__((objc_precise_lifetime)) UIAlertController *keep = self;
    [self revenant_syncTextFields];
    UIAlertAction *action = _dismissing ? nil : revenant_action_at(_buttonActions, index);
    if (!action.enabled)
        action = nil;
    void (^presented)(void) = _presentCompletion;
    void (^dismissed)(void) = _dismissCompletion;
    [self revenant_releaseNativeView];
    if (_presenter && objc_getAssociatedObject(_presenter, &revenant_presented_alert_key) == keep)
        objc_setAssociatedObject(_presenter, &revenant_presented_alert_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _presenter = nil;
    _presentCompletion = nil;
    _dismissCompletion = nil;
    _dismissing = NO;
    if (presented)
        presented();
    void (^handler)(UIAlertAction *action) = [action revenant_handler];
    if (handler)
        handler(action);
    if (dismissed)
        dismissed();
}

- (void)didPresentAlertView:(UIAlertView *)alertView
{
    if (alertView == _alertView)
        [self revenant_finishPresentation];
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    UIAlertAction *action = revenant_action_at(_buttonActions, alertView.firstOtherButtonIndex);
    return action ? action.enabled : YES;
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == _alertView)
        [self revenant_syncTextFields];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self revenant_nativeView:alertView didDismissWithButtonIndex:buttonIndex];
}

- (void)didPresentActionSheet:(UIActionSheet *)actionSheet
{
    if (actionSheet == _actionSheet)
        [self revenant_finishPresentation];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self revenant_nativeView:actionSheet didDismissWithButtonIndex:buttonIndex];
}

@end
