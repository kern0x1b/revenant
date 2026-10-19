#import "CharonGC.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static id charon_nullable(id value)
{
    return value == [NSNull null] ? nil : value;
}

@implementation GCControllerElement {
    __weak GCControllerElement *_collection;
    __weak GCPhysicalInputProfile *_profile;
    BOOL _analog;
    BOOL _boundToSystemGesture;
    GCSystemGestureState _preferredSystemGestureState;
    NSString *_sfSymbolsName;
    NSString *_unmappedSfSymbolsName;
    NSString *_localizedName;
    NSString *_unmappedLocalizedName;
    NSString *_defaultLocalizedName;
    NSString *_defaultUnmappedLocalizedName;
    NSSet<NSString *> *_aliases;
}

- (instancetype)initWithCharonSpec:(NSDictionary *)spec
{
    self = [super init];
    if (self) {
        _analog = [spec[@"analog"] boolValue];
        _boundToSystemGesture = [spec[@"system"] boolValue];
        _aliases = [NSSet setWithArray:spec[@"aliases"]];
        _defaultLocalizedName = charon_nullable(spec[@"local"]);
        _defaultUnmappedLocalizedName = charon_nullable(spec[@"unmappedLocal"]);
        _sfSymbolsName = charon_nullable(spec[@"sf"]);
        _unmappedSfSymbolsName = charon_nullable(spec[@"unmappedSf"]);
    }
    return self;
}

- (void)charon_attachToProfile:(GCPhysicalInputProfile *)profile
{
    _profile = profile;
}

- (void)charon_setCollection:(GCControllerElement *)collection
{
    _collection = collection;
}

- (void)charon_enqueue:(dispatch_block_t)block
{
    id<GCDevice> device = _profile.device;
    dispatch_queue_t queue = device.handlerQueue ?: dispatch_get_main_queue();
    dispatch_async(queue, block);
}

- (BOOL)isAnalog
{
    return _analog;
}

- (BOOL)isBoundToSystemGesture
{
    return _boundToSystemGesture;
}

- (NSSet<NSString *> *)aliases
{
    return _aliases;
}

- (NSString *)localizedName
{
    return _localizedName ?: _defaultLocalizedName;
}

- (void)setLocalizedName:(NSString *)name
{
    _localizedName = [name copy];
}

- (NSString *)unmappedLocalizedName
{
    return _unmappedLocalizedName ?: _defaultUnmappedLocalizedName;
}

- (void)setUnmappedLocalizedName:(NSString *)name
{
    _unmappedLocalizedName = [name copy];
}

- (NSString *)unmappedSfSymbolsName
{
    return _unmappedSfSymbolsName;
}

- (void)setUnmappedSfSymbolsName:(NSString *)name
{
    _unmappedSfSymbolsName = [name copy];
    _sfSymbolsName = [name copy];
}

@end

static const float charon_touchThreshold = 0.001953125f;

@implementation GCControllerButtonInput {
    float _value;
    BOOL _pressed;
    BOOL _touched;
    __weak GCControllerAxisInput *_axis;
    float _sign;
}

- (void)charon_deriveFromAxis:(GCControllerAxisInput *)axis sign:(float)sign
{
    _axis = axis;
    _sign = sign;
    _value = sign < 0 ? -0.0f : 0;
}

- (float)charon_derivedValue
{
    float axis = _axis.value;
    if (_sign > 0)
        return axis < 0 ? 0 : axis;
    float negated = -axis;
    return negated < 0 ? 0 : negated;
}

- (float)value
{
    return _axis ? [self charon_derivedValue] : _value;
}

- (BOOL)isPressed
{
    return _axis ? [self charon_derivedValue] > 0 : _pressed;
}

- (BOOL)isTouched
{
    return _touched;
}

- (void)setValue:(float)value
{
    if (_axis)
        value *= _sign;
    [self charon_update:value < 0 ? 0 : value > 1 ? 1 : value];
}

- (void)charon_axisChanged
{
    float scale = _sign < 0 ? 16777216.0f : 33554432.0f;
    [self charon_update:rintf([self charon_derivedValue] * scale) / scale];
}

- (void)charon_update:(float)value
{
    if (value == _value)
        return;
    BOOL wasPressed = _pressed;
    BOOL wasTouched = _touched;
    _value = value;
    _pressed = _axis ? value > 0 : value > charon_touchThreshold;
    _touched = value > charon_touchThreshold;
    BOOL pressed = _pressed;
    BOOL touched = _touched;
    GCControllerButtonValueChangedHandler changed = self.valueChangedHandler;
    GCControllerButtonTouchedChangedHandler touchedHandler = self.touchedChangedHandler;
    GCControllerButtonValueChangedHandler pressedHandler = self.pressedChangedHandler;
    [self charon_enqueue:^{
        if (changed)
            changed(self, value, pressed);
        if (touchedHandler && touched != wasTouched)
            touchedHandler(self, value, pressed, touched);
        if (pressedHandler && pressed != wasPressed)
            pressedHandler(self, value, pressed);
    }];
}

@end

@implementation GCControllerAxisInput {
    float _value;
    __weak GCControllerButtonInput *_positive;
    __weak GCControllerButtonInput *_negative;
    __weak GCControllerDirectionPad *_dpad;
}

- (float)value
{
    return _value;
}

- (void)charon_linkPositive:(GCControllerButtonInput *)positive negative:(GCControllerButtonInput *)negative dpad:(GCControllerDirectionPad *)dpad
{
    _positive = positive;
    _negative = negative;
    _dpad = dpad;
    [positive charon_deriveFromAxis:self sign:1];
    [negative charon_deriveFromAxis:self sign:-1];
}

- (void)setValue:(float)value
{
    [self charon_setValue:value];
}

- (void)charon_setValue:(float)raw
{
    float value = fmaxf(-1, fminf(1, raw));
    if (raw == _value)
        return;
    _value = value;
    [_negative charon_axisChanged];
    [_positive charon_axisChanged];
    GCControllerAxisValueChangedHandler changed = self.valueChangedHandler;
    [self charon_enqueue:^{
        if (changed)
            changed(self, raw);
    }];
    [_dpad charon_axisChanged];
}

@end

@implementation GCControllerDirectionPad {
    GCControllerAxisInput *_xAxis;
    GCControllerAxisInput *_yAxis;
    GCControllerButtonInput *_up;
    GCControllerButtonInput *_down;
    GCControllerButtonInput *_left;
    GCControllerButtonInput *_right;
}

- (void)charon_linkXAxis:(GCControllerAxisInput *)x yAxis:(GCControllerAxisInput *)y up:(GCControllerButtonInput *)up down:(GCControllerButtonInput *)down
                    left:(GCControllerButtonInput *)left right:(GCControllerButtonInput *)right
{
    _xAxis = x;
    _yAxis = y;
    _up = up;
    _down = down;
    _left = left;
    _right = right;
}

- (GCControllerAxisInput *)xAxis
{
    return _xAxis;
}

- (GCControllerAxisInput *)yAxis
{
    return _yAxis;
}

- (GCControllerButtonInput *)up
{
    return _up;
}

- (GCControllerButtonInput *)down
{
    return _down;
}

- (GCControllerButtonInput *)left
{
    return _left;
}

- (GCControllerButtonInput *)right
{
    return _right;
}

- (void)setValueForXAxis:(float)xAxis yAxis:(float)yAxis
{
    [_xAxis charon_setValue:xAxis];
    [_yAxis charon_setValue:yAxis];
}

- (void)charon_axisChanged
{
    float x = _xAxis.value;
    float y = _yAxis.value;
    GCControllerDirectionPadValueChangedHandler changed = self.valueChangedHandler;
    [self charon_enqueue:^{
        if (changed)
            changed(self, x, y);
    }];
}

@end
