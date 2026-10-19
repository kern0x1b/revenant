#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

@interface CPTemplate (CharonVoiceControlDrawing)
- (UIViewController *)charon_viewControllerForInterfaceController:(CPInterfaceController *)controller;
@end

static const CGFloat CharonVoiceMaximumImagePoints = 150.0;
static const NSTimeInterval CharonVoiceMinimumCycle = 0.3;
static const NSTimeInterval CharonVoiceMaximumCycle = 5.0;

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

- (NSTimeInterval)charon_cycleForImage:(UIImage *)image
{
    NSUInteger frames = (NSUInteger)image.images.count;
    if (frames == 0) {
        return 0.0;
    }
    return MIN(MAX((double)frames / 30.0, CharonVoiceMinimumCycle), CharonVoiceMaximumCycle);
}

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
    [voice activateVoiceControlStateWithIdentifier:states[(NSUInteger)tag].identifier];
}

@end

@implementation CPVoiceControlTemplate {
    NSArray<CPVoiceControlState *> *_voiceControlStates;
    NSString *_activeStateIdentifier;
    __weak UIViewController *_charon_voiceView;
}

@synthesize voiceControlStates = _voiceControlStates;
@synthesize activeStateIdentifier = _activeStateIdentifier;

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
            _activeStateIdentifier = [_voiceControlStates.firstObject identifier];
        }
    }
    return self;
}

- (void)activateVoiceControlStateWithIdentifier:(NSString *)identifier
{
    _activeStateIdentifier = [identifier copy];
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
    CharonVoiceControlView *view = [[CharonVoiceControlView alloc] init];
    view.template = self;
    _charon_voiceView = view;
    return view;
}

@end
