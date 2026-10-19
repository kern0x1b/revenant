// CarPlay's voice control on iOS 6: the state a program declares and the template that shows it.
//
// Neither of these needs a car, and that is measured rather than assumed. CPVoiceControlTemplate.h
// says that an app may create the template holding one or more states, and that it may
// call activateVoiceControlState: to switch between states the app has defined -- the states are the
// program's own, the switch is the program's own call, and the only thing a car adds is a screen to
// show the result on. `tests/backports/host/carplay/headunit-probe.m` asks Apple's own CarPlay on
// this machine with no head unit attached and gets back, for a template built the same way:
//
//   the template keeps the five states the header's limit allows      5 of 6
//   the first of the states it was given is the active one            charon.state0
//   activating switches the active state with no car attached         charon.state3
//   twelve activations in a tight loop all take effect                 12 of 12
//   an image over 150 points a side comes back 150 by 150             150 by 150
//   a nil array of states answers nil for both                         nil
//
// Every one of those is an answer this file has to give identically, and the three that differ from
// the header's prose are the ones worth reading twice:
//
//   * the header's warning that activation "will have no effect" before the template is presented
//     through a CPInterfaceController is about what a CAR then shows. Apple's own object switches its
//     active state with no car and no presentation, so this one does too;
//   * the header's rate limit means the template may ignore state changes that come too fast: that is likewise about the
//     presentation: twelve activations in a tight loop all take,
//     so there is no interval in the object and none is invented here;
//   * an identifier no state carries still becomes the active one, because Apple's object does not
//     check. Drawing then has no state to draw, and nothing is drawn rather than something invented.
//
// The wall is the screen, and it is the same wall the scenes are: a CarPlay head unit. What the port
// draws instead is the release's own UI, in this library's own cards, which is what every other
// CarPlay template here does.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

// The template's own view controller, asked for by the interface controller when it pushes it. The
// same hook every other template in this library implements, and it is where the drawing is.
@interface CPTemplate (CharonVoiceControlDrawing)
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller;
@end

// The header's own bounds on a state image: a state image may be at most 150 by 150 points, and the system enforces
// a cycle of at least 0.3 seconds and at most 5 seconds. Apple's numbers, from the header's own text, and both are enforced here
// rather than documented: an image over 150 points a side is scaled down, and an animated image's
// cycle is held inside those two seconds. Charon's own, so no API.
static const CGFloat CharonVoiceMaximumImagePoints = 150.0;
static const NSTimeInterval CharonVoiceMinimumCycle = 0.3;
static const NSTimeInterval CharonVoiceMaximumCycle = 5.0;

// ============================ the state ============================

@implementation CPVoiceControlState {
    NSString *_identifier;
    NSArray<NSString *> *_titleVariants;
    UIImage *_image;
    BOOL _repeats;
}

@synthesize identifier = _identifier;
@synthesize titleVariants = _titleVariants;
@synthesize image = _image;
@synthesize repeats = _repeats;

// The header's own initialiser, and the header's own nullability: titleVariants and image may be
// nil and then answer nil, which is measured (Apple's object answers nil for a nil array rather than
// an empty one, and a `?: @[]` here would be a quiet different answer).
// The signature is on ONE line on purpose. Apple's own CPVoiceControlTemplate.h:36 wraps this same
// four-argument selector over four lines, and a grep of that one line reads a complete one-argument
// selector -- a name no CarPlay class in any SDK declares, which a reader then goes looking for in the
// registry. A line that cannot be mistaken for a shorter selector is worth more here than the four
// lines Apple's header wraps it over.
- (instancetype)initWithIdentifier:(NSString *)identifier titleVariants:(NSArray<NSString *> *)titleVariants image:(UIImage *)image repeats:(BOOL)repeats
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _titleVariants = [titleVariants copy];
        _image = image != nil ? [[self class] charon_imageLimitedToPoints:image] : nil;
        _repeats = repeats;
    }
    return self;
}

// The 150-point limit, enforced. A smaller image is kept as it is; a larger one is redrawn at the
// limit, keeping its shape, so a state never holds an image a car could not draw.
+ (UIImage *)charon_imageLimitedToPoints:(UIImage *)image
{
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    if (width <= CharonVoiceMaximumImagePoints && height <= CharonVoiceMaximumImagePoints) {
        return image;
    }
    CGFloat scale = CharonVoiceMaximumImagePoints / MAX(width, height);
    CGSize fitted = CGSizeMake(MAX(1.0, floorf((float)(width * scale))),
                               MAX(1.0, floorf((float)(height * scale))));
    UIGraphicsBeginImageContextWithOptions(fitted, NO, image.scale > 0.0 ? image.scale : 1.0);
    [image drawInRect:CGRectMake(0.0, 0.0, fitted.width, fitted.height)];
    UIImage *drawn = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return drawn ?: image;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // No [super encodeWithCoder:]: the release's NSObject declares no coder at all, so the four
    // members this class holds are the whole of what there is to write.
    [coder encodeObject:_identifier forKey:@"CPVoiceControlStateIdentifier"];
    [coder encodeObject:_titleVariants forKey:@"CPVoiceControlStateTitleVariants"];
    [coder encodeObject:_image forKey:@"CPVoiceControlStateImage"];
    [coder encodeBool:_repeats forKey:@"CPVoiceControlStateRepeats"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _identifier = [coder decodeObjectForKey:@"CPVoiceControlStateIdentifier"];
        _titleVariants = [coder decodeObjectForKey:@"CPVoiceControlStateTitleVariants"];
        _image = [coder decodeObjectForKey:@"CPVoiceControlStateImage"];
        _repeats = [coder decodeBoolForKey:@"CPVoiceControlStateRepeats"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

// ============================ the template ============================

// The image's own shape inside a box, which keeps a tall mark from being stretched into a square.
static CGSize CharonAspectFitInSize(CGSize size, CGSize box)
{
    if (size.width <= 0.0 || size.height <= 0.0) {
        return box;
    }
    CGFloat scale = MIN(box.width / size.width, box.height / size.height);
    return CGSizeMake(size.width * scale, size.height * scale);
}

@interface CharonVoiceControlView : UIViewController
@property (nonatomic, weak) CPVoiceControlTemplate *template;
- (void)charon_redrawVoiceControl;
@end

// The state an identifier names, declared here because the drawing asks for it and the template
// below is what answers. Charon's own, so no API.
@interface CPVoiceControlTemplate (CharonVoiceControlStates)
- (CPVoiceControlState *)charon_stateForIdentifier:(NSString *)identifier;
@end

@implementation CharonVoiceControlView {
    UIImageView *_charon_image;
    UILabel *_charon_title;
    NSMutableArray *_charon_buttons;
    CGSize _charon_drawnSize;
}

@synthesize template = _template;

- (void)loadView
{
    // A plain black canvas, which is what the other templates here present, and the three pieces the
    // state's own contents are drawn in.
    UIView *canvas = [[UIView alloc] initWithFrame:CGRectZero];
    canvas.backgroundColor = [UIColor blackColor];
    self.view = canvas;
    _charon_image = [[UIImageView alloc] initWithFrame:CGRectZero];
    [canvas addSubview:_charon_image];
    _charon_title = [[UILabel alloc] initWithFrame:CGRectZero];
    _charon_title.textAlignment = NSTextAlignmentCenter;
    _charon_title.textColor = [UIColor whiteColor];
    _charon_title.backgroundColor = [UIColor clearColor];
    [canvas addSubview:_charon_title];
    _charon_buttons = [NSMutableArray array];
}

// The cycle an animated image runs at, which is UIKit's own rule for a multi-frame image --
// UIImageView's default of "number of images * 1/30th of a second" -- held inside the two bounds the
// header names. Nothing here is invented: the 30 is the release's own frame rate for an animated
// image and 0.3 and 5.0 are the header's own text.
- (NSTimeInterval)charon_cycleForImage:(UIImage *)image
{
    NSUInteger frames = (NSUInteger)image.images.count;
    if (frames == 0) {
        return 0.0;
    }
    return MIN(MAX((double)frames / 30.0, CharonVoiceMinimumCycle), CharonVoiceMaximumCycle);
}

// The state's own title, chosen the header's way: the template selects the longest variant that fits the specified content.
// So the variants are tried longest first and the
// first that fits is the one drawn. When none fits -- a template narrower than its shortest variant,
// which the header does not say anything about -- the shortest is drawn and the label truncates it,
// which is an answer rather than an empty label.
- (NSString *)charon_titleForState:(CPVoiceControlState *)state inWidth:(CGFloat)width
{
    NSArray<NSString *> *variants = state.titleVariants;
    if (variants.count == 0) {
        return nil;
    }
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:28.0]};
    for (NSString *variant in variants) {
        CGSize size = [variant sizeWithAttributes:attributes];
        if (size.width <= width) {
            return variant;
        }
    }
    return variants.lastObject;
}

// The first layout pass is what draws, and a pass over the same size draws nothing: the plates are
// real buttons with real targets, so rebuilding them on every pass would throw away the ones a touch
// is halfway into.
- (void)viewDidLayoutSubviews
{
    if (!CGSizeEqualToSize(_charon_drawnSize, self.view.bounds.size)) {
        [self charon_redrawVoiceControl];
    }
}

- (void)charon_redrawVoiceControl
{
    CPVoiceControlTemplate *voice = self.template;
    CPVoiceControlState *state = [voice charon_stateForIdentifier:voice.activeStateIdentifier];
    UIView *canvas = self.view;
    CGRect bounds = canvas.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    _charon_drawnSize = bounds.size;

    // The state is drawn in the release's own chrome: the image above, the title under it, and the
    // states themselves as a row of plates a tap switches to, which is the same mechanism the
    // alert's own actions use in CarPlayTemplatesMore12.m.
    if (state.image != nil) {
        _charon_image.image = state.image;
        CGSize fitted = CharonAspectFitInSize(state.image.size, CGSizeMake(width, width));
        _charon_image.frame = CGRectMake((width - fitted.width) / 2.0, 24.0, fitted.width, fitted.height);
        _charon_image.hidden = NO;
        [self charon_animateImage:state];
    } else {
        _charon_image.image = nil;
        _charon_image.hidden = YES;
    }

    _charon_title.frame = CGRectMake(16.0, CGRectGetMaxY(_charon_image.frame) + 12.0, width - 32.0, 40.0);
    _charon_title.text = state != nil ? [self charon_titleForState:state inWidth:width - 32.0] : nil;

    for (UIButton *button in _charon_buttons) {
        [button removeFromSuperview];
    }
    [_charon_buttons removeAllObjects];
    NSArray<CPVoiceControlState *> *states = voice.voiceControlStates;
    CGFloat plate = 64.0;
    CGFloat at = (width - plate * (CGFloat)states.count) / 2.0;
    for (CPVoiceControlState *each in states) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(at, CGRectGetHeight(bounds) - plate - 24.0, plate, plate);
        [button setTitle:each.identifier forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        button.tag = (NSInteger)[_charon_buttons count];
        [button addTarget:self action:@selector(charon_stateTapped:) forControlEvents:UIControlEventTouchUpInside];
        [canvas addSubview:button];
        [_charon_buttons addObject:button];
        at += plate;
    }
}

// The state's own animation, on the header's own two bounds: an animated image repeats for as long
// as the state is active when `repeats` is YES, and runs once when it is NO, and the cycle stays
// inside the 0.3 and 5 seconds the header names.
- (void)charon_animateImage:(CPVoiceControlState *)state
{
    [_charon_image.layer removeAllAnimations];
    NSTimeInterval cycle = [self charon_cycleForImage:state.image];
    if (cycle <= 0.0) {
        return;
    }
    UIViewAnimationOptions options = UIViewAnimationOptionAutoreverse;
    if (state.repeats) {
        options |= UIViewAnimationOptionRepeat;
    }
    _charon_image.alpha = 1.0;
    [UIView animateWithDuration:cycle
                          delay:0.0
                        options:options
                     animations:^{ _charon_image.alpha = 0.25; }
                     completion:nil];
}

- (void)charon_stateTapped:(UIButton *)button
{
    CPVoiceControlTemplate *voice = self.template;
    NSArray<CPVoiceControlState *> *states = voice.voiceControlStates;
    NSInteger tag = button.tag;
    if (tag < 0 || (NSUInteger)tag >= states.count) {
        return;
    }
    // The program's own switch, called with the identifier of the plate that was tapped, which is
    // the call the header declares and the one a car would be shown.
    [voice activateVoiceControlStateWithIdentifier:states[(NSUInteger)tag].identifier];
}

@end

@implementation CPVoiceControlTemplate {
    NSArray<CPVoiceControlState *> *_voiceControlStates;
    NSString *_activeStateIdentifier;
    // The view this port made for the template when a program pushed it, so an activation that
    // happens while it is on screen is drawn. Charon's own, so it carries no API, and it is weak
    // because the interface controller owns the view and not the template.
    __weak UIViewController *_charon_voiceView;
}

@synthesize voiceControlStates = _voiceControlStates;
@synthesize activeStateIdentifier = _activeStateIdentifier;

// The header's own initialiser, and the header's own limit: a caller may specify at most 5 voice
// states, and any beyond the first 5 are not available. Measured on
// Apple's own object: six in, five held. A nil array answers nil and an empty array answers an empty
// array, which is what Apple's object does and what a `?: @[]` would not do.
- (instancetype)initWithVoiceControlStates:(NSArray<CPVoiceControlState *> *)voiceControlStates
{
    self = [super init];
    if (self) {
        if (voiceControlStates == nil) {
            _voiceControlStates = nil;
            _activeStateIdentifier = nil;
        } else {
            NSUInteger kept = MIN((NSUInteger)5, (NSUInteger)voiceControlStates.count);
            _voiceControlStates = [voiceControlStates subarrayWithRange:NSMakeRange(0, kept)];
            // By default, the header says the template begins on the first state given.
            _activeStateIdentifier = [_voiceControlStates.firstObject identifier];
        }
    }
    return self;
}

// The switch, and the header's own rate limit is NOT here: measured on Apple's own object, twelve
// activations in a tight loop all take effect, because the limit the header describes is on what a
// car then shows. The identifier is kept as it is given, with no check, because Apple's object does
// not check either -- a program that switches to a state it never declared gets that identifier back
// and nothing is drawn for it, which is the honest answer and not an invented one.
- (void)activateVoiceControlStateWithIdentifier:(NSString *)identifier
{
    _activeStateIdentifier = [identifier copy];
    // A program that switches state while the template is on screen sees the switch, which is what
    // the other templates here do when a value they draw changes under them.
    CharonVoiceControlView *view = (CharonVoiceControlView *)_charon_voiceView;
    if (view != nil) {
        [view charon_redrawVoiceControl];
    }
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_voiceControlStates forKey:@"CPVoiceControlTemplateStates"];
    [coder encodeObject:_activeStateIdentifier forKey:@"CPVoiceControlTemplateActive"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _voiceControlStates = [coder decodeObjectForKey:@"CPVoiceControlTemplateStates"];
        _activeStateIdentifier = [coder decodeObjectForKey:@"CPVoiceControlTemplateActive"];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The state an identifier names, and nil when it names none -- which is what an activation of an
// identifier the template was never given comes to, and what the drawing then has to answer.
- (CPVoiceControlState *)charon_stateForIdentifier:(NSString *)identifier
{
    for (CPVoiceControlState *state in _voiceControlStates) {
        if (identifier != nil && [state.identifier isEqualToString:identifier]) {
            return state;
        }
    }
    return nil;
}

- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    // The view draws itself when it is laid out, not here: at this point the controller has no view
    // yet, and a template that drew into a view that does not exist would push an empty screen.
    CharonVoiceControlView *view = [[CharonVoiceControlView alloc] init];
    view.template = self;
    _charon_voiceView = view;
    return view;
}

@end

// ============================ the drawing ============================
