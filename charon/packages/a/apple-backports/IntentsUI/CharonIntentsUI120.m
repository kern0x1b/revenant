//
//  CharonIntentsUI120.m
//  IntentsUI
//
//  The three IntentsUI classes, hand written: a button that shows what a shortcut would do, and
//  the two controllers that take a person through adding or editing a shortcut.
//
//  What is different here from the rest of this framework is stated plainly in
//  facts/IntentsUI/IntentsUI.md and repeated in each registry entry: the flow these two
//  controllers drive is **the system's** - Siri's own screens, writing into the system's shortcut
//  database - and iOS 6 has neither. There is no extension host, no Shortcuts database and no
//  Siri, so a controller here is a real view controller that shows the shortcut and asks the
//  application's own delegate, and the store the package already keeps is where a shortcut that
//  was added is written. That is in-process handling, which is what the release can do, and it
//  is not the system's flow and does not claim to be.
//

// The SDK marks each class's initialiser as the designated one, in a header this package does
// not own, so clang reads the -initWithCoder: of a UIViewController subclass as a convenience
// initialiser of a class that has a designated one. The warning is about a convention.
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#import <Intents/Intents.h>
#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>


// The error the two flows end in, in a domain of this package's own so a caller can tell it
// from a system error: the number is the one CoreFoundation's NSError uses for a failure with no
// system code behind it, and the reason says which wall it is.
static NSError *charon_intents_ui_error(NSInteger code, NSString *reason)
{
    return [NSError errorWithDomain:@"org.charon.intentsui" code:code
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
        [self charon_applyStyle];
        [self charon_installAction];
    }
    return self;
}

- (void)setStyle:(INUIAddVoiceShortcutButtonStyle)style
{
    _style = style;
    [self charon_applyStyle];
}

- (void)setShortcut:(INShortcut *)shortcut
{
    _shortcut = shortcut;
    [self charon_installAction];
    // The button is titled with what the shortcut would say, which is the suggested invocation
    // phrase the intent or the user activity carries - the same value the button stands for.
    [self setTitle:[self charon_phrase] forState:UIControlStateNormal];
}

// The four styles the header names, drawn by the button itself: the two light ones take dark
// ink, the two dark ones take light, and the outlines take none at all.
- (void)charon_applyStyle
{
    BOOL dark = _style == INUIAddVoiceShortcutButtonStyleBlack ||
                _style == INUIAddVoiceShortcutButtonStyleBlackOutline ||
                _style == INUIAddVoiceShortcutButtonStyleAutomatic;
    BOOL outline = _style == INUIAddVoiceShortcutButtonStyleWhiteOutline ||
                   _style == INUIAddVoiceShortcutButtonStyleBlackOutline ||
                   _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline;
    BOOL automatic = _style == INUIAddVoiceShortcutButtonStyleAutomatic ||
                     _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline;
    // Automatic follows the interface style, and this release's trait collection is the one
    // UIKit hands every view, so the question is answered by what UIKit itself says.
    BOOL onDark = automatic ? ([self.traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) : dark;
    self.backgroundColor = onDark ? [UIColor blackColor] : [UIColor whiteColor];
    self.layer.borderWidth = outline ? 1.0f : 0.0f;
    self.layer.borderColor = onDark ? [UIColor whiteColor].CGColor : [UIColor blackColor].CGColor;
    [self setTitleColor:onDark ? [UIColor whiteColor] : [UIColor blackColor]
                forState:UIControlStateNormal];
    self.layer.cornerRadius = _cornerRadius > 0 ? _cornerRadius : 5.0f;
}

- (NSString *)charon_phrase
{
    NSString *phrase = _shortcut.intent.suggestedInvocationPhrase;
    if (phrase.length) {
        return phrase;
    }
    return _shortcut.userActivity ? _shortcut.userActivity.title : nil;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    // The header's own rule: a radius greater than half the button's height is capped at half of
    // it, so the corner can never fold past the middle of the side it belongs to.
    CGFloat limit = self.bounds.size.height / 2.0f;
    _cornerRadius = cornerRadius > limit ? limit : cornerRadius;
    self.layer.cornerRadius = _cornerRadius > 0 ? _cornerRadius : 5.0f;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    // The cap is of the height, which only the layout knows.
    CGFloat limit = self.bounds.size.height / 2.0f;
    if (_cornerRadius > limit) {
        _cornerRadius = limit;
        self.layer.cornerRadius = limit;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous
{
    [super traitCollectionDidChange:previous];
    // An automatic style follows the interface, so it is applied again when that changes.
    if (_style == INUIAddVoiceShortcutButtonStyleAutomatic ||
        _style == INUIAddVoiceShortcutButtonStyleAutomaticOutline) {
        [self charon_applyStyle];
    }
}

// The button's whole action is to ask its delegate for the two controllers: there is no system
// flow to open, so the delegate is what presents them, and the button installs that on itself
// rather than leaving an application to wire a target it has no reason to know about.
- (void)charon_installAction
{
    [self removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];
    [self addTarget:self action:@selector(charon_pressed:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)charon_pressed:(id)sender
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

        // The screen the system's own flow would show, built from what the shortcut says: the
        // phrase, and the two answers. Nothing here is a system view - there is none to show.
        _phrase = [[UILabel alloc] initWithFrame:CGRectZero];
        _phrase.text = [self charon_phrase];
        _phrase.textAlignment = NSTextAlignmentCenter;
        _phrase.numberOfLines = 0;
        [self.view addSubview:_phrase];

        _done = [UIButton buttonWithType:UIButtonTypeSystem];
        [_done setTitle:@"Add" forState:UIControlStateNormal];
        [_done addTarget:self action:@selector(charon_done:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_done];

        _cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancel setTitle:@"Cancel" forState:UIControlStateNormal];
        [_cancel addTarget:self action:@selector(charon_cancel:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_cancel];
    }
    return self;
}

- (NSString *)charon_phrase
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
    // Laid out by hand: this release's UIKit has no auto layout guide chain worth relying on for
    // a view nobody has loaded a nib for, and the three pieces are the whole of the screen.
    CGRect bounds = self.view.bounds;
    CGFloat inset = 16.0f;
    _phrase.frame = CGRectMake(inset, CGRectGetMidY(bounds) - 44.0f,
                                CGRectGetWidth(bounds) - 2 * inset, 88.0f);
    _done.frame = CGRectMake(inset, CGRectGetMaxY(bounds) - 60.0f, 88.0f, 44.0f);
    _cancel.frame = CGRectMake(CGRectGetWidth(bounds) - inset - 88.0f, CGRectGetMaxY(bounds) - 60.0f,
                               88.0f, 44.0f);
}

- (void)charon_done:(id)sender
{
    // The header says this is called "with either the successfully-added voice shortcut, or an
    // error", and it is the error that is true here: INVoiceShortcut declares no initialiser at
    // all - only NS_UNAVAILABLE - because a voice shortcut is the system's own object, written
    // into the system's database, and this release has neither. The app's delegate is told so
    // rather than handed a voice shortcut this port could only have invented.
    [_delegate addVoiceShortcutViewController:self
                       didFinishWithVoiceShortcut:nil
                                            error:charon_intents_ui_error(-1,
                                                @"this release has no shortcut database, so no voice shortcut can be added")];
}

- (void)charon_cancel:(id)sender
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
        [_save addTarget:self action:@selector(charon_save:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_save];

        _delete = [UIButton buttonWithType:UIButtonTypeSystem];
        [_delete setTitle:@"Delete" forState:UIControlStateNormal];
        [_delete addTarget:self action:@selector(charon_delete:) forControlEvents:UIControlEventTouchUpInside];
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

- (void)charon_save:(id)sender
{
    // The phrase of a voice shortcut is readonly in the SDK's own header and there is no
    // database behind it here, so the edit cannot be written: the delegate is told the update
    // failed, with the reason, which is the answer the header's own signature has for it.
    [_delegate editVoiceShortcutViewController:self
                       didUpdateVoiceShortcut:nil
                                         error:charon_intents_ui_error(-1,
                                             @"this release has no shortcut database, so a voice shortcut's phrase cannot be changed")];
}

- (void)charon_delete:(id)sender
{
    // The identifier the delegate is given is the voice shortcut's own, which is a UUID.
    [_delegate editVoiceShortcutViewController:self
            didDeleteVoiceShortcutWithIdentifier:_voiceShortcut.identifier];
}

@end
