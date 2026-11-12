#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantCASpringAnimation.h"
#import "RevenantSwitchGeometry.h"

@interface RevenantSwitchState : NSObject {
@public
    BOOL on;
    BOOL pressed;
    BOOL tracking;
    NSUInteger generation;
    RevenantSwitchTracking touch;
    UIColor *onTintColor;
    UIColor *tintColor;
    UIColor *thumbTintColor;
    UIImage *onImage;
    UIImage *offImage;
    CALayer *content;
    CALayer *base;
    CALayer *fill;
    CALayer *well;
    CALayer *knob;
    id knobOff;
    id knobOn;
}
@end

@implementation RevenantSwitchState
@end

@interface RevenantSwitch : UIControl
@end

static const char revenant_switch_state_key;

static RevenantSwitchState *revenant_switch_state(UIView *view)
{
    return objc_getAssociatedObject(view, &revenant_switch_state_key);
}

static UIColor *revenant_switch_color(const CGFloat *components)
{
    return [UIColor colorWithRed:components[0] green:components[1] blue:components[2] alpha:components[3]];
}

static CGFloat revenant_switch_scale(void)
{
    return [UIScreen mainScreen].scale;
}

static id revenant_switch_knob_image(UIColor *color, BOOL on)
{
    static id standard[2];
    if (color)
        return CFBridgingRelease(RevenantSwitchKnobImageCreate(color.CGColor, revenant_switch_scale(), on));
    if (!standard[on])
        standard[on] = CFBridgingRelease(RevenantSwitchKnobImageCreate([UIColor whiteColor].CGColor, revenant_switch_scale(), on));
    return standard[on];
}

static void revenant_switch_set_knob_images(RevenantSwitchState *state, UIColor *color)
{
    state->knobOff = revenant_switch_knob_image(color, NO);
    state->knobOn = revenant_switch_knob_image(color, YES);
}

static id revenant_switch_well_image(UIColor *color)
{
    static id standard;
    if (color)
        return CFBridgingRelease(RevenantSwitchWellImageCreate(color.CGColor, revenant_switch_scale()));
    if (!standard)
        standard = CFBridgingRelease(RevenantSwitchWellImageCreate(revenant_switch_color(RevenantSwitchOnComponents).CGColor, revenant_switch_scale()));
    return standard;
}

static UIColor *revenant_switch_on_color(RevenantSwitchState *state)
{
    return state->onTintColor ?: revenant_switch_color(RevenantSwitchOnComponents);
}

static CGPoint revenant_switch_center(CGRect frame)
{
    return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

static void revenant_switch_spring(CALayer *layer, NSString *keyPath, id from, id to, RevenantSwitchSpring spring)
{
    RevenantCASpringAnimation *animation = [RevenantCASpringAnimation animationWithKeyPath:keyPath];
    animation.mass = spring.mass;
    animation.stiffness = spring.stiffness;
    animation.damping = spring.damping;
    animation.duration = spring.duration;
    animation.fromValue = from;
    animation.toValue = to;
    animation.fillMode = kCAFillModeBackwards;
    [layer addAnimation:animation forKey:keyPath];
}

static void revenant_switch_static_fill(RevenantSwitchState *state, BOOL displayedOn)
{
    state->fill.backgroundColor = displayedOn ? revenant_switch_on_color(state).CGColor : NULL;
    state->fill.masksToBounds = NO;
    state->well.hidden = YES;
    [state->well removeAllAnimations];
    state->well.frame = RevenantSwitchWellFrame(displayedOn);
}

static void revenant_switch_show(RevenantSwitchState *state, BOOL displayedOn, BOOL wasDisplayedOn, BOOL wasPressed, BOOL animated)
{
    CALayer *knob = state->knob;
    CALayer *well = state->well;
    CALayer *knobNow = animated ? (knob.presentationLayer ?: knob) : knob;
    CALayer *wellNow = animated ? (well.presentationLayer ?: well) : well;
    NSValue *knobBoundsFrom = [NSValue valueWithCGRect:knobNow.bounds];
    NSValue *knobPositionFrom = [NSValue valueWithCGPoint:knobNow.position];
    BOOL wellMoving = !well.hidden;
    NSValue *wellFrom = [NSValue valueWithCGPoint:wellMoving ? wellNow.position : revenant_switch_center(RevenantSwitchWellFrame(wasDisplayedOn))];
    NSUInteger generation = ++state->generation;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (animated) {
        [CATransaction setCompletionBlock:^{
            if (state->generation != generation)
                return;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            revenant_switch_static_fill(state, state->tracking ? state->touch.displayedOn : state->on);
            [CATransaction commit];
        }];
    }
    knob.contents = displayedOn ? state->knobOn : state->knobOff;
    knob.bounds = RevenantSwitchKnobBounds(state->pressed);
    knob.position = RevenantSwitchKnobPosition(displayedOn, state->pressed);
    if (animated && (displayedOn != wasDisplayedOn || state->pressed != wasPressed)) {
        revenant_switch_spring(knob, @"bounds", knobBoundsFrom, [NSValue valueWithCGRect:knob.bounds], RevenantSwitchKnobSpring);
        revenant_switch_spring(knob, @"position", knobPositionFrom, [NSValue valueWithCGPoint:knob.position], RevenantSwitchKnobSpring);
    }
    if (animated && (displayedOn != wasDisplayedOn || wellMoving)) {
        state->fill.backgroundColor = NULL;
        state->fill.masksToBounds = YES;
        well.hidden = NO;
        well.frame = RevenantSwitchWellFrame(displayedOn);
        revenant_switch_spring(well, @"position", wellFrom, [NSValue valueWithCGPoint:well.position], displayedOn ? RevenantSwitchWellOnSpring : RevenantSwitchWellOffSpring);
    } else {
        revenant_switch_static_fill(state, displayedOn);
    }
    [CATransaction commit];
}

static void revenant_switch_build(UIControl *view, RevenantSwitchState *state)
{
    CGFloat scale = revenant_switch_scale();
    CGRect bounds = {CGPointZero, RevenantSwitchSize};
    CGFloat radius = RevenantSwitchSize.height / 2;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CALayer *content = [CALayer layer];
    content.frame = bounds;
    content.allowsGroupOpacity = YES;
    content.opacity = view.enabled ? 1 : RevenantSwitchDisabledAlpha;
    CALayer *base = [CALayer layer];
    base.frame = bounds;
    base.cornerRadius = radius;
    base.backgroundColor = revenant_switch_color(RevenantSwitchOffComponents).CGColor;
    CALayer *fill = [CALayer layer];
    fill.frame = bounds;
    fill.cornerRadius = radius;
    CALayer *well = [CALayer layer];
    well.contentsScale = scale;
    well.contents = revenant_switch_well_image(nil);
    well.hidden = YES;
    CALayer *knob = [CALayer layer];
    knob.contentsScale = scale;
    revenant_switch_set_knob_images(state, nil);
    knob.contentsCenter = RevenantSwitchKnobContentsCenter();
    [fill addSublayer:well];
    [content addSublayer:base];
    [content addSublayer:fill];
    [content addSublayer:knob];
    [view.layer addSublayer:content];
    [CATransaction commit];
    state->content = content;
    state->base = base;
    state->fill = fill;
    state->well = well;
    state->knob = knob;
    objc_setAssociatedObject(view, &revenant_switch_state_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_switch_show(state, state->on, state->on, NO, NO);
}

static void revenant_switch_set_on(UIView *view, BOOL on, BOOL animated)
{
    RevenantSwitchState *state = revenant_switch_state(view);
    BOOL was = state->tracking ? state->touch.displayedOn : state->on;
    state->on = on;
    if (state->tracking)
        RevenantSwitchTrackingBegin(&state->touch, on, state->touch.touchX);
    revenant_switch_show(state, on, was, state->pressed, animated && was != on && view.window != nil);
}

static void revenant_switch_press(UIView *view, RevenantSwitchState *state, BOOL pressed, BOOL displayedOn, BOOL wasDisplayedOn)
{
    BOOL wasPressed = state->pressed;
    state->pressed = pressed;
    revenant_switch_show(state, displayedOn, wasDisplayedOn, wasPressed, view.window != nil);
}

@implementation RevenantSwitch

+ (void)load
{
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        return;
    Class target = [UISwitch class];
    unsigned int count = 0;
    Method *methods = class_copyMethodList(self, &count);
    for (unsigned int index = 0; index < count; index++)
        class_replaceMethod(target, method_getName(methods[index]), method_getImplementation(methods[index]), method_getTypeEncoding(methods[index]));
    free(methods);
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    frame.size = RevenantSwitchSize;
    if ((self = [super initWithFrame:frame]))
        revenant_switch_build(self, [RevenantSwitchState new]);
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
        return nil;
    RevenantSwitchState *state = [RevenantSwitchState new];
    state->on = [coder decodeBoolForKey:@"UISwitchOn"];
    state->tintColor = [coder decodeObjectForKey:@"UISwitchTintColor"];
    state->onImage = [coder decodeObjectForKey:@"UISwitchOnImage"];
    state->offImage = [coder decodeObjectForKey:@"UISwitchOffImage"];
    revenant_switch_build(self, state);
    [self setOnTintColor:[coder decodeObjectForKey:@"UISwitchOnTintColor"]];
    [self setThumbTintColor:[coder decodeObjectForKey:@"UISwitchThumbTintColor"]];
    [self setFrame:self.frame];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    RevenantSwitchState *state = revenant_switch_state(self);
    [coder encodeBool:state->on forKey:@"UISwitchOn"];
    [coder encodeObject:state->onTintColor forKey:@"UISwitchOnTintColor"];
    [coder encodeObject:state->tintColor forKey:@"UISwitchTintColor"];
    [coder encodeObject:state->thumbTintColor forKey:@"UISwitchThumbTintColor"];
    [coder encodeObject:state->onImage forKey:@"UISwitchOnImage"];
    [coder encodeObject:state->offImage forKey:@"UISwitchOffImage"];
}

- (void)setFrame:(CGRect)frame
{
    frame.size = RevenantSwitchSize;
    [super setFrame:frame];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return RevenantSwitchSize;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(RevenantSwitchSize.width - RevenantSwitchAlignmentRight, RevenantSwitchSize.height);
}

- (CGSize)_intrinsicSizeWithinSize:(CGSize)size
{
    return [self intrinsicContentSize];
}

- (UIEdgeInsets)alignmentRectInsets
{
    return UIEdgeInsetsMake(0, 0, 0, RevenantSwitchAlignmentRight);
}

- (BOOL)isOn
{
    return revenant_switch_state(self)->on;
}

- (void)setOn:(BOOL)on
{
    revenant_switch_set_on(self, on, NO);
}

- (void)setOn:(BOOL)on animated:(BOOL)animated
{
    revenant_switch_set_on(self, on, animated);
}

- (UIColor *)onTintColor
{
    return revenant_switch_state(self)->onTintColor;
}

- (void)setOnTintColor:(UIColor *)color
{
    RevenantSwitchState *state = revenant_switch_state(self);
    state->onTintColor = color;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    state->well.contents = revenant_switch_well_image(color);
    if (state->fill.backgroundColor)
        state->fill.backgroundColor = revenant_switch_on_color(state).CGColor;
    [CATransaction commit];
}

- (UIColor *)tintColor
{
    return revenant_switch_state(self)->tintColor;
}

- (void)setTintColor:(UIColor *)color
{
    revenant_switch_state(self)->tintColor = color;
}

- (UIColor *)thumbTintColor
{
    return revenant_switch_state(self)->thumbTintColor;
}

- (void)setThumbTintColor:(UIColor *)color
{
    RevenantSwitchState *state = revenant_switch_state(self);
    state->thumbTintColor = color;
    revenant_switch_set_knob_images(state, color);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    state->knob.contents = (state->tracking ? state->touch.displayedOn : state->on) ? state->knobOn : state->knobOff;
    [CATransaction commit];
}

- (UIImage *)onImage
{
    return revenant_switch_state(self)->onImage;
}

- (void)setOnImage:(UIImage *)image
{
    revenant_switch_state(self)->onImage = image;
}

- (UIImage *)offImage
{
    return revenant_switch_state(self)->offImage;
}

- (void)setOffImage:(UIImage *)image
{
    revenant_switch_state(self)->offImage = image;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    RevenantSwitchState *state = revenant_switch_state(self);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    state->content.opacity = enabled ? 1 : RevenantSwitchDisabledAlpha;
    [CATransaction commit];
}

- (void)setAlpha:(CGFloat)alpha
{
    [super setAlpha:alpha];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    RevenantSwitchState *state = revenant_switch_state(self);
    state->tracking = YES;
    RevenantSwitchTrackingBegin(&state->touch, state->on, [touch locationInView:self].x);
    revenant_switch_press(self, state, YES, state->on, state->on);
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    RevenantSwitchState *state = revenant_switch_state(self);
    BOOL was = state->touch.displayedOn;
    if (RevenantSwitchTrackingMove(&state->touch, [touch locationInView:self].x))
        revenant_switch_press(self, state, YES, state->touch.displayedOn, was);
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    RevenantSwitchState *state = revenant_switch_state(self);
    BOOL was = state->touch.displayedOn;
    BOOL on = RevenantSwitchTrackingEnd(&state->touch, self.touchInside);
    BOOL changed = on != state->on;
    state->tracking = NO;
    state->on = on;
    revenant_switch_press(self, state, NO, on, was);
    if (changed)
        [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    RevenantSwitchState *state = revenant_switch_state(self);
    BOOL was = state->touch.displayedOn;
    state->tracking = NO;
    revenant_switch_press(self, state, NO, state->on, was);
}

@end
