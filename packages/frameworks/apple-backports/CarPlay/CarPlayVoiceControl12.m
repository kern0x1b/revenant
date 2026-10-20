#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

@interface CPTemplate (RevenantVoiceControlDrawing)
- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller;
@end

static const CGFloat RevenantVoiceMaximumImagePoints = 150.0;
static const NSTimeInterval RevenantVoiceMinimumCycle = 0.3;
static const NSTimeInterval RevenantVoiceMaximumCycle = 5.0;

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
        _image = image != nil ? [[self class] revenant_imageLimitedToPoints:image] : nil;
        _repeats = repeats;
    }
    return self;
}

+ (UIImage *)revenant_imageLimitedToPoints:(UIImage *)image
{
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    if (width <= RevenantVoiceMaximumImagePoints && height <= RevenantVoiceMaximumImagePoints) {
        return image;
    }
    CGFloat scale = RevenantVoiceMaximumImagePoints / MAX(width, height);
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

static CGSize RevenantAspectFitInSize(CGSize size, CGSize box)
{
    if (size.width <= 0.0 || size.height <= 0.0) {
        return box;
    }
    CGFloat scale = MIN(box.width / size.width, box.height / size.height);
    return CGSizeMake(size.width * scale, size.height * scale);
}

@interface RevenantVoiceControlView : UIViewController
@property (nonatomic, weak) CPVoiceControlTemplate *template;
- (void)revenant_redrawVoiceControl;
@end

@interface CPVoiceControlTemplate (RevenantVoiceControlStates)
- (CPVoiceControlState *)revenant_stateForIdentifier:(NSString *)identifier;
@end

@implementation RevenantVoiceControlView {
    UIImageView *_revenant_image;
    UILabel *_revenant_title;
    NSMutableArray *_revenant_buttons;
    CGSize _revenant_drawnSize;
}

@synthesize template = _template;

- (void)loadView
{
    UIView *canvas = [[UIView alloc] initWithFrame:CGRectZero];
    canvas.backgroundColor = [UIColor blackColor];
    self.view = canvas;
    _revenant_image = [[UIImageView alloc] initWithFrame:CGRectZero];
    [canvas addSubview:_revenant_image];
    _revenant_title = [[UILabel alloc] initWithFrame:CGRectZero];
    _revenant_title.textAlignment = NSTextAlignmentCenter;
    _revenant_title.textColor = [UIColor whiteColor];
    _revenant_title.backgroundColor = [UIColor clearColor];
    [canvas addSubview:_revenant_title];
    _revenant_buttons = [NSMutableArray array];
}

- (NSTimeInterval)revenant_cycleForImage:(UIImage *)image
{
    NSUInteger frames = (NSUInteger)image.images.count;
    if (frames == 0) {
        return 0.0;
    }
    return MIN(MAX((double)frames / 30.0, RevenantVoiceMinimumCycle), RevenantVoiceMaximumCycle);
}

- (NSString *)revenant_titleForState:(CPVoiceControlState *)state inWidth:(CGFloat)width
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
    if (!CGSizeEqualToSize(_revenant_drawnSize, self.view.bounds.size)) {
        [self revenant_redrawVoiceControl];
    }
}

- (void)revenant_redrawVoiceControl
{
    CPVoiceControlTemplate *voice = self.template;
    CPVoiceControlState *state = [voice revenant_stateForIdentifier:voice.activeStateIdentifier];
    UIView *canvas = self.view;
    CGRect bounds = canvas.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    _revenant_drawnSize = bounds.size;

    if (state.image != nil) {
        _revenant_image.image = state.image;
        CGSize fitted = RevenantAspectFitInSize(state.image.size, CGSizeMake(width, width));
        _revenant_image.frame = CGRectMake((width - fitted.width) / 2.0, 24.0, fitted.width, fitted.height);
        _revenant_image.hidden = NO;
        [self revenant_animateImage:state];
    } else {
        _revenant_image.image = nil;
        _revenant_image.hidden = YES;
    }

    _revenant_title.frame = CGRectMake(16.0, CGRectGetMaxY(_revenant_image.frame) + 12.0, width - 32.0, 40.0);
    _revenant_title.text = state != nil ? [self revenant_titleForState:state inWidth:width - 32.0] : nil;

    for (UIButton *button in _revenant_buttons) {
        [button removeFromSuperview];
    }
    [_revenant_buttons removeAllObjects];
    NSArray<CPVoiceControlState *> *states = voice.voiceControlStates;
    CGFloat plate = 64.0;
    CGFloat at = (width - plate * (CGFloat)states.count) / 2.0;
    for (CPVoiceControlState *each in states) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(at, CGRectGetHeight(bounds) - plate - 24.0, plate, plate);
        [button setTitle:each.identifier forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        button.tag = (NSInteger)[_revenant_buttons count];
        [button addTarget:self action:@selector(revenant_stateTapped:) forControlEvents:UIControlEventTouchUpInside];
        [canvas addSubview:button];
        [_revenant_buttons addObject:button];
        at += plate;
    }
}

- (void)revenant_animateImage:(CPVoiceControlState *)state
{
    [_revenant_image.layer removeAllAnimations];
    NSTimeInterval cycle = [self revenant_cycleForImage:state.image];
    if (cycle <= 0.0) {
        return;
    }
    UIViewAnimationOptions options = UIViewAnimationOptionAutoreverse;
    if (state.repeats) {
        options |= UIViewAnimationOptionRepeat;
    }
    _revenant_image.alpha = 1.0;
    [UIView animateWithDuration:cycle
                          delay:0.0
                        options:options
                     animations:^{ _revenant_image.alpha = 0.25; }
                     completion:nil];
}

- (void)revenant_stateTapped:(UIButton *)button
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
    __weak UIViewController *_revenant_voiceView;
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
    RevenantVoiceControlView *view = (RevenantVoiceControlView *)_revenant_voiceView;
    if (view != nil) {
        [view revenant_redrawVoiceControl];
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

- (CPVoiceControlState *)revenant_stateForIdentifier:(NSString *)identifier
{
    for (CPVoiceControlState *state in _voiceControlStates) {
        if (identifier != nil && [state.identifier isEqualToString:identifier]) {
            return state;
        }
    }
    return nil;
}

- (UIViewController *)revenant_viewControllerForInterfaceController:(CPInterfaceController *)controller
{
    RevenantVoiceControlView *view = [[RevenantVoiceControlView alloc] init];
    view.template = self;
    _revenant_voiceView = view;
    return view;
}

@end
