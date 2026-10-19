#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface UIAlertAction (CharonAlertController)
- (void (^)(UIAlertAction *action))charon_handler;
@end

@interface CharonAlertPopoverPresentation : NSObject
@property (nonatomic, strong) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;
@property (nonatomic, strong) UIBarButtonItem *barButtonItem;
@property (nonatomic) UIPopoverArrowDirection permittedArrowDirections;
@property (nonatomic, weak) id delegate;
@property (nonatomic, copy) NSArray *passthroughViews;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic) UIEdgeInsets popoverLayoutMargins;
@end

@implementation CharonAlertPopoverPresentation

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
- (void)charon_presentFromViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)charon_dismissAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (BOOL)charon_isPresented;
@end

static char charon_presented_alert_key;

static void (*charon_present_original)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void (*charon_dismiss_original)(id, SEL, BOOL, void (^)(void));
static id (*charon_presented_original)(id, SEL);

static UIViewController *charon_presentation_host(UIViewController *controller)
{
    while (controller.parentViewController)
        controller = controller.parentViewController;
    return controller;
}

static UIAlertController *charon_presented_alert(UIViewController *controller)
{
    return controller ? objc_getAssociatedObject(charon_presentation_host(controller), &charon_presented_alert_key) : nil;
}

static UIViewController *charon_natively_presented(UIViewController *controller)
{
    if (charon_presented_original)
        return charon_presented_original(controller, @selector(presentedViewController));
    return controller.presentedViewController;
}

static void charon_present(UIViewController *receiver, SEL selector, UIViewController *controller, BOOL animated, void (^completion)(void))
{
    if ([controller isKindOfClass:[UIAlertController class]]) {
        [(UIAlertController *)controller charon_presentFromViewController:receiver animated:animated completion:completion];
        return;
    }
    UIAlertController *alert = charon_presented_alert(receiver);
    if (alert) {
        NSLog(@"Warning: Attempt to present %@ on %@ which is already presenting %@", controller, charon_presentation_host(receiver), alert);
        return;
    }
    charon_present_original(receiver, selector, controller, animated, completion);
}

static void charon_dismiss(UIViewController *receiver, SEL selector, BOOL animated, void (^completion)(void))
{
    if ([receiver isKindOfClass:[UIAlertController class]] && [(UIAlertController *)receiver charon_isPresented]) {
        [(UIAlertController *)receiver charon_dismissAnimated:animated completion:completion];
        return;
    }
    UIAlertController *alert = charon_presented_alert(receiver);
    if (alert) {
        [alert charon_dismissAnimated:animated completion:completion];
        return;
    }
    for (UIViewController *above = charon_natively_presented(receiver); above; above = charon_natively_presented(above))
        [charon_presented_alert(above) charon_dismissAnimated:NO completion:nil];
    charon_dismiss_original(receiver, selector, animated, completion);
}

static id charon_presented(UIViewController *receiver, SEL selector)
{
    id presented = charon_presented_original(receiver, selector);
    return presented ? presented : charon_presented_alert(receiver);
}

static void charon_install_presentation(void)
{
    Class controller = [UIViewController class];
    Method present = class_getInstanceMethod(controller, @selector(presentViewController:animated:completion:));
    Method dismiss = class_getInstanceMethod(controller, @selector(dismissViewControllerAnimated:completion:));
    Method presented = class_getInstanceMethod(controller, @selector(presentedViewController));
    if (!present || !dismiss || !presented)
        return;
    charon_present_original = (void (*)(id, SEL, UIViewController *, BOOL, void (^)(void)))method_setImplementation(present, (IMP)charon_present);
    charon_dismiss_original = (void (*)(id, SEL, BOOL, void (^)(void)))method_setImplementation(dismiss, (IMP)charon_dismiss);
    charon_presented_original = (id (*)(id, SEL))method_setImplementation(presented, (IMP)charon_presented);
}

static NSString *charon_button_title(UIAlertAction *action)
{
    return action.title ? action.title : @"";
}

static NSString *charon_sheet_title(NSString *title, NSString *message)
{
    if (title.length && message.length)
        return [NSString stringWithFormat:@"%@\n%@", title, message];
    if (title.length)
        return title;
    return message.length ? message : nil;
}

static void charon_place(NSMutableArray *buttons, NSInteger index, UIAlertAction *action)
{
    if (index < 0 || !action)
        return;
    while ((NSInteger)buttons.count <= index)
        [buttons addObject:[NSNull null]];
    [buttons replaceObjectAtIndex:index withObject:action];
}

static UIAlertAction *charon_action_at(NSArray *buttons, NSInteger index)
{
    if (index < 0 || index >= (NSInteger)buttons.count)
        return nil;
    id action = [buttons objectAtIndex:index];
    return action == [NSNull null] ? nil : action;
}

static UIAlertViewStyle charon_alert_view_style(NSArray *fields)
{
    if (fields.count == 0)
        return UIAlertViewStyleDefault;
    if (fields.count == 1)
        return [[fields objectAtIndex:0] isSecureTextEntry] ? UIAlertViewStyleSecureTextInput : UIAlertViewStylePlainTextInput;
    return UIAlertViewStyleLoginAndPasswordInput;
}

static BOOL charon_differs(id value, id standard)
{
    return value != standard && ![value isEqual:standard];
}

static void charon_copy_field(UITextField *from, UITextField *to)
{
    UITextField *pristine = [[UITextField alloc] init];
    if (charon_differs(from.placeholder, pristine.placeholder))
        to.placeholder = from.placeholder;
    if (charon_differs(from.font, pristine.font))
        to.font = from.font;
    if (charon_differs(from.textColor, pristine.textColor))
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
    if (charon_differs(from.accessibilityLabel, pristine.accessibilityLabel))
        to.accessibilityLabel = from.accessibilityLabel;
    to.secureTextEntry = from.secureTextEntry;
    to.text = from.text;
}

static void charon_copy_actions(UITextField *from, UITextField *to)
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
    CharonAlertPopoverPresentation *_popover;
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
            charon_install_presentation();
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
    [self charon_releaseNativeView];
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
    _actionSheet.title = charon_sheet_title(self.title, _message);
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    _alertView.title = self.title;
    _actionSheet.title = charon_sheet_title(self.title, _message);
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
        _popover = [[CharonAlertPopoverPresentation alloc] init];
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

- (BOOL)charon_isPresented
{
    return _presenter != nil;
}

- (UIView *)charon_nativeView
{
    [self charon_releaseNativeView];
    if (_preferredStyle == UIAlertControllerStyleActionSheet)
        [self charon_makeActionSheet];
    else
        [self charon_makeAlertView];
    return _alertView ? (UIView *)_alertView : (UIView *)_actionSheet;
}

- (void)charon_makeAlertView
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
                                         cancelButtonTitle:cancel ? charon_button_title(cancel) : nil
                                         otherButtonTitles:first ? charon_button_title(first) : nil, nil];
    NSMutableArray *buttons = [NSMutableArray array];
    charon_place(buttons, view.cancelButtonIndex, cancel);
    charon_place(buttons, view.firstOtherButtonIndex, first);
    for (NSUInteger index = 1; index < others.count; index++) {
        UIAlertAction *action = [others objectAtIndex:index];
        charon_place(buttons, [view addButtonWithTitle:charon_button_title(action)], action);
    }
    view.alertViewStyle = charon_alert_view_style(_textFields);
    NSMutableArray *nativeFields = [NSMutableArray array];
    for (NSUInteger index = 0; index < _textFields.count; index++) {
        UITextField *field = [_textFields objectAtIndex:index];
        UITextField *native = [view textFieldAtIndex:index];
        if (!native)
            continue;
        charon_copy_field(field, native);
        [native addTarget:self action:@selector(charon_nativeFieldChanged:) forControlEvents:UIControlEventEditingChanged];
        charon_copy_actions(field, native);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(charon_nativeFieldDidChange:) name:UITextFieldTextDidChangeNotification object:native];
        [nativeFields addObject:native];
    }
    _alertView = view;
    _buttonActions = buttons;
    _nativeFields = nativeFields;
}

- (void)charon_makeActionSheet
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:charon_sheet_title(self.title, _message) delegate:self
                                              cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    NSMutableArray *buttons = [NSMutableArray array];
    UIAlertAction *cancel = nil;
    for (UIAlertAction *action in _actions) {
        if (action.style == UIAlertActionStyleCancel && !cancel) {
            cancel = action;
            continue;
        }
        NSInteger index = [sheet addButtonWithTitle:charon_button_title(action)];
        charon_place(buttons, index, action);
        if (action.style == UIAlertActionStyleDestructive && sheet.destructiveButtonIndex < 0)
            sheet.destructiveButtonIndex = index;
    }
    if (cancel) {
        NSInteger index = [sheet addButtonWithTitle:charon_button_title(cancel)];
        sheet.cancelButtonIndex = index;
        charon_place(buttons, index, cancel);
    }
    _actionSheet = sheet;
    _buttonActions = buttons;
    _nativeFields = nil;
}

- (void)charon_releaseNativeView
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    for (UITextField *native in _nativeFields)
        [native removeTarget:self action:@selector(charon_nativeFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    _alertView.delegate = nil;
    _actionSheet.delegate = nil;
    _alertView = nil;
    _actionSheet = nil;
    _buttonActions = nil;
    _nativeFields = nil;
}

- (void)charon_presentFromViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion
{
    if (_presenter)
        [NSException raise:NSInvalidArgumentException format:@"Application tried to present modally an active controller %@.", self];
    UIViewController *host = charon_presentation_host(controller);
    UIViewController *busy = charon_natively_presented(host);
    if (!busy)
        busy = charon_presented_alert(host);
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
    objc_setAssociatedObject(host, &charon_presented_alert_key, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self charon_nativeView];
    if (_alertView) {
        [_alertView show];
        return;
    }
    CharonAlertPopoverPresentation *popover = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? _popover : nil;
    if (popover.barButtonItem)
        [_actionSheet showFromBarButtonItem:popover.barButtonItem animated:animated];
    else if (popover.sourceView.window)
        [_actionSheet showFromRect:popover.sourceRect inView:popover.sourceView animated:animated];
    else
        [_actionSheet showInView:window];
}

- (void)charon_dismissAnimated:(BOOL)animated completion:(void (^)(void))completion
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

- (void)charon_syncTextFields
{
    for (NSUInteger index = 0; index < _nativeFields.count && index < _textFields.count; index++) {
        UITextField *field = [_textFields objectAtIndex:index];
        NSString *text = [[_nativeFields objectAtIndex:index] text];
        if (field.text != text && ![field.text isEqualToString:text])
            field.text = text;
    }
}

- (void)charon_nativeFieldChanged:(UITextField *)native
{
    [self charon_syncTextFields];
}

- (void)charon_nativeFieldDidChange:(NSNotification *)notification
{
    [self charon_syncTextFields];
    NSUInteger index = [_nativeFields indexOfObjectIdenticalTo:notification.object];
    if (index != NSNotFound && index < _textFields.count)
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:[_textFields objectAtIndex:index]];
}

- (void)charon_finishPresentation
{
    void (^completion)(void) = _presentCompletion;
    _presentCompletion = nil;
    if (completion)
        completion();
}

- (void)charon_nativeView:(UIView *)view didDismissWithButtonIndex:(NSInteger)index
{
    if (!view || (view != _alertView && view != _actionSheet))
        return;
    __attribute__((objc_precise_lifetime)) UIAlertController *keep = self;
    [self charon_syncTextFields];
    UIAlertAction *action = _dismissing ? nil : charon_action_at(_buttonActions, index);
    if (!action.enabled)
        action = nil;
    void (^presented)(void) = _presentCompletion;
    void (^dismissed)(void) = _dismissCompletion;
    [self charon_releaseNativeView];
    if (_presenter && objc_getAssociatedObject(_presenter, &charon_presented_alert_key) == keep)
        objc_setAssociatedObject(_presenter, &charon_presented_alert_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _presenter = nil;
    _presentCompletion = nil;
    _dismissCompletion = nil;
    _dismissing = NO;
    if (presented)
        presented();
    void (^handler)(UIAlertAction *action) = [action charon_handler];
    if (handler)
        handler(action);
    if (dismissed)
        dismissed();
}

- (void)didPresentAlertView:(UIAlertView *)alertView
{
    if (alertView == _alertView)
        [self charon_finishPresentation];
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    UIAlertAction *action = charon_action_at(_buttonActions, alertView.firstOtherButtonIndex);
    return action ? action.enabled : YES;
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == _alertView)
        [self charon_syncTextFields];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self charon_nativeView:alertView didDismissWithButtonIndex:buttonIndex];
}

- (void)didPresentActionSheet:(UIActionSheet *)actionSheet
{
    if (actionSheet == _actionSheet)
        [self charon_finishPresentation];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self charon_nativeView:actionSheet didDismissWithButtonIndex:buttonIndex];
}

@end
