#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation GCControllerTouchpad {
    GCControllerButtonInput *_button;
    GCControllerDirectionPad *_touchSurface;
    GCControllerTouchpadHandler _touchDown;
    GCControllerTouchpadHandler _touchMoved;
    GCControllerTouchpadHandler _touchUp;
    GCTouchState _touchState;
    BOOL _reportsAbsoluteTouchSurfaceValues;
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    NSDictionary *surface = @{@"kind": @"dpad", @"aliases": @[@"Touch Surface"], @"local": @"Touch Surface",
                              @"unmappedLocal": @"Touch Surface", @"sf": [NSNull null], @"unmappedSf": [NSNull null],
                              @"analog": @1, @"system": @0, @"order": @0};
    NSDictionary *button = @{@"kind": @"button", @"aliases": @[@"Button A"], @"local": @"Touch Surface Button",
                             @"unmappedLocal": @"Touch Surface Button", @"sf": [NSNull null], @"unmappedSf": [NSNull null],
                             @"analog": @0, @"system": @0, @"order": @1};
    NSDictionary *(^child)(NSString *, NSString *, NSString *, BOOL) = ^NSDictionary *(NSString *alias, NSString *local, NSString *parent, BOOL analog) {
        return @{@"kind": @"button", @"aliases": @[alias], @"local": local, @"unmappedLocal": local,
                 @"sf": [NSNull null], @"unmappedSf": [NSNull null], @"analog": @(analog), @"system": @0,
                 @"collection": parent, @"order": @(-1)};
    };
    _touchSurface = [[GCControllerDirectionPad alloc] initWithCharonSpec:surface];
    _button = [[GCControllerButtonInput alloc] initWithCharonSpec:button];
    GCControllerAxisInput *x = [[GCControllerAxisInput alloc] initWithCharonSpec:child(@"Direction Pad X Axis", @"Touch Surface (Horizontal)", @"Touch Surface", YES)];
    GCControllerAxisInput *y = [[GCControllerAxisInput alloc] initWithCharonSpec:child(@"Direction Pad Y Axis", @"Touch Surface (Vertical)", @"Touch Surface", YES)];
    GCControllerButtonInput *up = [[GCControllerButtonInput alloc] initWithCharonSpec:child(@"Direction Pad Up", @"Touch Surface (Up)", @"Touch Surface", NO)];
    GCControllerButtonInput *down = [[GCControllerButtonInput alloc] initWithCharonSpec:child(@"Direction Pad Down", @"Touch Surface (Down)", @"Touch Surface", NO)];
    GCControllerButtonInput *left = [[GCControllerButtonInput alloc] initWithCharonSpec:child(@"Direction Pad Left", @"Touch Surface (Left)", @"Touch Surface", NO)];
    GCControllerButtonInput *right = [[GCControllerButtonInput alloc] initWithCharonSpec:child(@"Direction Pad Right", @"Touch Surface (Right)", @"Touch Surface", NO)];
    [_touchSurface charon_linkXAxis:x yAxis:y up:up down:down left:left right:right];
    [x charon_linkPositive:right negative:left dpad:_touchSurface];
    [y charon_linkPositive:up negative:down dpad:_touchSurface];
    _touchState = GCTouchStateUp;
    _reportsAbsoluteTouchSurfaceValues = NO;
    return self;
}

- (GCControllerButtonInput *)button
{
    return _button;
}

- (GCControllerDirectionPad *)touchSurface
{
    return _touchSurface;
}

- (GCTouchState)touchState
{
    return _touchState;
}

- (BOOL)reportsAbsoluteTouchSurfaceValues
{
    return _reportsAbsoluteTouchSurfaceValues;
}

- (void)setReportsAbsoluteTouchSurfaceValues:(BOOL)reportsAbsoluteTouchSurfaceValues
{
    _reportsAbsoluteTouchSurfaceValues = reportsAbsoluteTouchSurfaceValues;
}

- (GCControllerTouchpadHandler)touchDown
{
    return _touchDown;
}

- (void)setTouchDown:(GCControllerTouchpadHandler)touchDown
{
    _touchDown = [touchDown copy];
}

- (GCControllerTouchpadHandler)touchMoved
{
    return _touchMoved;
}

- (void)setTouchMoved:(GCControllerTouchpadHandler)touchMoved
{
    _touchMoved = [touchMoved copy];
}

- (GCControllerTouchpadHandler)touchUp
{
    return _touchUp;
}

- (void)setTouchUp:(GCControllerTouchpadHandler)touchUp
{
    _touchUp = [touchUp copy];
}

- (void)setValueForXAxis:(float)xAxis yAxis:(float)yAxis touchDown:(BOOL)touchDown buttonValue:(float)buttonValue
{
    float x = fmaxf(-1, fminf(1, xAxis));
    float y = fmaxf(-1, fminf(1, yAxis));
    [_touchSurface setValueForXAxis:x yAxis:y];
    [_button setValue:fmaxf(0, fminf(1, buttonValue))];
    GCTouchState state;
    if (!touchDown)
        state = GCTouchStateUp;
    else if (_touchState == GCTouchStateDown)
        state = GCTouchStateMoving;
    else
        state = GCTouchStateDown;
    _touchState = state;
    GCControllerTouchpadHandler handler = touchDown ? _touchDown : _touchUp;
    if (!handler)
        return;
    float button = _button.value;
    BOOL pressed = _button.isPressed;
    [self charon_enqueue:^{
        handler(self, x, y, button, pressed);
    }];
}

@end
