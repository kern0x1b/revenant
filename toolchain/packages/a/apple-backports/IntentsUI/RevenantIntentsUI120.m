#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import <Intents/Intents.h>
#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>


static NSError *revenant_intents_ui_error(NSInteger code, NSString *reason)
{
    return [NSError errorWithDomain:@"org.revenant.intentsui" code:code
                           userInfo:@{NSLocalizedDescriptionKey: reason}];
}

#pragma mark - INUIAddVoiceShortcutButton

@implementation INUIAddVoiceShortcutButton {
    INUIAddVoiceShortcutButtonStyle _style;
    __weak id<INUIAddVoiceShortcutButtonDelegate> _delegate;
    INShortcut *_shortcut;
    CGFloat _cornerRadius;
}

@synthesize style = _style;
@synthesize delegate = _delegate;
@synthesize shortcut = _shortcut;
@synthesize cornerRadius = _cornerRadius;

- (instancetype)initWithStyle:(INUIAddVoiceShortcutButtonStyle)style
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _style = style;
        [self revenant_applyStyle];
        [self revenant_installAction];
    }
    return self;
}

- (void)setStyle:(INUIAddVoiceShortcutButtonStyle)style
{
    _style = style;
    [self revenant_applyStyle];
}

- (void)setShortcut:(INShortcut *)shortcut
{
    _shortcut = shortcut;
    [self revenant_installAction];
    [self setTitle:[self revenant_phrase] forState:UIControlStateNormal];
}

- (void)revenant_applyStyle
{
    BOOL dark = _style == INUIAddVoiceShortcutButtonStyleBlack ||
                _style == INUIAddVoiceShortcutButtonStyleBlackOutline ||
                _style == INUIAddVoiceShortcutButtonStyleAutomatic;
    BOOL outline = _style == INUIAddVoiceShortcutButtonStyleWhiteOutline ||
                   _style == INUIAddVoiceShortcutButtonStyleBlackOutline ||
                   _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline;
    BOOL automatic = _style == INUIAddVoiceShortcutButtonStyleAutomatic ||
                     _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline;
    BOOL onDark = automatic ? ([self.traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) : dark;
    self.backgroundColor = onDark ? [UIColor blackColor] : [UIColor whiteColor];
    self.layer.borderWidth = outline ? 1.0f : 0.0f;
    self.layer.borderColor = onDark ? [UIColor whiteColor].CGColor : [UIColor blackColor].CGColor;
    [self setTitleColor:onDark ? [UIColor whiteColor] : [UIColor blackColor]
                forState:UIControlStateNormal];
    self.layer.cornerRadius = _cornerRadius > 0 ? _cornerRadius : 5.0f;
}

- (NSString *)revenant_phrase
{
    NSString *phrase = _shortcut.intent.suggestedInvocationPhrase;
    if (phrase.length) {
        return phrase;
    }
    return _shortcut.userActivity ? _shortcut.userActivity.title : nil;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    CGFloat limit = self.bounds.size.height / 2.0f;
    _cornerRadius = cornerRadius > limit ? limit : cornerRadius;
    self.layer.cornerRadius = _cornerRadius > 0 ? _cornerRadius : 5.0f;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat limit = self.bounds.size.height / 2.0f;
    if (_cornerRadius > limit) {
        _cornerRadius = limit;
        self.layer.cornerRadius = limit;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous
{
    [super traitCollectionDidChange:previous];
    if (_style == INUIAddVoiceShortcutButtonStyleAutomatic ||
        _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline) {
        [self revenant_applyStyle];
    }
}

- (void)revenant_installAction
{
    [self removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    [self addTarget:self action:@selector(revenant_pressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)revenant_pressed:(id)sender
{
    id<INUIAddVoiceShortcutButtonDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(presentAddVoiceShortcutViewController:forAddVoiceShortcutButton:)]
        && _shortcut) {
        INUIAddVoiceShortcutViewController *controller =
            [[INUIAddVoiceShortcutViewController alloc] initWithShortcut:_shortcut];
        [delegate presentAddVoiceShortcutViewController:controller forAddVoiceShortcutButton:self];
    }
}

@end

#pragma mark - INUIAddVoiceShortcutViewController

@implementation INUIAddVoiceShortcutViewController {
    __weak id<INUIAddVoiceShortcutViewControllerDelegate> _delegate;
    INShortcut *_shortcut;
    UILabel *_phrase;
    UIButton *_done;
    UIButton *_cancel;
}

@synthesize delegate = _delegate;

- (instancetype)initWithShortcut:(INShortcut *)shortcut
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _shortcut = shortcut;
        self.view.backgroundColor = [UIColor whiteColor];

        _phrase = [[UILabel alloc] initWithFrame:CGRectZero];
        _phrase.text = [self revenant_phrase];
        _phrase.textAlignment = NSTextAlignmentCenter;
        _phrase.numberOfLines = 0;
        [self.view addSubview:_phrase];

        _done = [UIButton buttonWithType:UIButtonTypeSystem];
        [_done setTitle:@"Add" forState:UIControlStateNormal];
        [_done addTarget:self action:@selector(revenant_done:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_done];

        _cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancel setTitle:@"Cancel" forState:UIControlStateNormal];
        [_cancel addTarget:self action:@selector(revenant_cancel:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_cancel];
    }
    return self;
}

- (NSString *)revenant_phrase
{
    NSString *phrase = _shortcut.intent.suggestedInvocationPhrase;
    if (phrase.length) {
        return phrase;
    }
    return _shortcut.userActivity ? _shortcut.userActivity.title : @"";
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    CGFloat inset = 16.0f;
    _phrase.frame = CGRectMake(inset, CGRectGetMidY(bounds) - 44.0f,
                                CGRectGetWidth(bounds) - 2 * inset, 88.0f);
    _done.frame = CGRectMake(inset, CGRectGetMaxY(bounds) - 60.0f, 88.0f, 44.0f);
    _cancel.frame = CGRectMake(CGRectGetWidth(bounds) - inset - 88.0f, CGRectGetMaxY(bounds) - 60.0f,
                               88.0f, 44.0f);
}

- (void)revenant_done:(id)sender
{
    [_delegate addVoiceShortcutViewController:self
                       didFinishWithVoiceShortcut:nil
                                            error:revenant_intents_ui_error(-1,
                                                @"this release has no shortcut database, so no voice shortcut can be added")];
}

- (void)revenant_cancel:(id)sender
{
    [_delegate addVoiceShortcutViewControllerDidCancel:self];
}

@end

#pragma mark - INUIEditVoiceShortcutViewController

@implementation INUIEditVoiceShortcutViewController {
    __weak id<INUIEditVoiceShortcutViewControllerDelegate> _delegate;
    INVoiceShortcut *_voiceShortcut;
    UITextField *_phrase;
    UIButton *_save;
    UIButton *_delete;
}

@synthesize delegate = _delegate;

- (instancetype)initWithVoiceShortcut:(INVoiceShortcut *)voiceShortcut
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _voiceShortcut = voiceShortcut;
        self.view.backgroundColor = [UIColor whiteColor];

        _phrase = [[UITextField alloc] initWithFrame:CGRectZero];
        _phrase.text = voiceShortcut.invocationPhrase;
        _phrase.placeholder = @"Say \"Siri\" then…";
        [self.view addSubview:_phrase];

        _save = [UIButton buttonWithType:UIButtonTypeSystem];
        [_save setTitle:@"Save" forState:UIControlStateNormal];
        [_save addTarget:self action:@selector(revenant_save:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_save];

        _delete = [UIButton buttonWithType:UIButtonTypeSystem];
        [_delete setTitle:@"Delete" forState:UIControlStateNormal];
        [_delete addTarget:self action:@selector(revenant_delete:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_delete];
    }
    return self;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    CGFloat inset = 16.0f;
    _phrase.frame = CGRectMake(inset, CGRectGetMidY(bounds) - 22.0f, CGRectGetWidth(bounds) - 2 * inset, 44.0f);
    _save.frame = CGRectMake(inset, CGRectGetMaxY(bounds) - 60.0f, 88.0f, 44.0f);
    _delete.frame = CGRectMake(CGRectGetWidth(bounds) - inset - 88.0f, CGRectGetMaxY(bounds) - 60.0f,
                               88.0f, 44.0f);
}

- (void)revenant_save:(id)sender
{
    [_delegate editVoiceShortcutViewController:self
                       didUpdateVoiceShortcut:nil
                                         error:revenant_intents_ui_error(-1,
                                             @"this release has no shortcut database, so a voice shortcut's phrase cannot be changed")];
}

- (void)revenant_delete:(id)sender
{
    [_delegate editVoiceShortcutViewController:self
            didDeleteVoiceShortcutWithIdentifier:_voiceShortcut.identifier];
}

@end
