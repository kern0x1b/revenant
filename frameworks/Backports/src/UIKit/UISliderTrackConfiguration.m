#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantSliderTrackConfigurationKey;

@interface UISliderTick ()
@property (nonatomic, readwrite) float position;
- (instancetype)initRevenantWithPosition:(float)position title:(nullable NSString *)title image:(nullable UIImage *)image;
@end

@implementation UISliderTick

@synthesize position = _position;

+ (instancetype)tickWithPosition:(float)position title:(NSString *)title image:(UIImage *)image
{
    return [[self alloc] initRevenantWithPosition:position title:title image:image];
}

- (instancetype)initRevenantWithPosition:(float)position title:(NSString *)title image:(UIImage *)image
{
    self = [super init];
    if (self) {
        _position = position;
        _title = [title copy];
        _image = image;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    id title = [coder decodeObjectForKey:@"title"];
    id image = [coder decodeObjectForKey:@"image"];
    if ((title && ![title isKindOfClass:NSString.class]) || (image && ![image isKindOfClass:UIImage.class]))
        return nil;
    self = [super init];
    if (self) {
        _position = [coder decodeFloatForKey:@"position"];
        _title = title;
        _image = image;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeFloat:_position forKey:@"position"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_image forKey:@"image"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[self.class allocWithZone:zone] initRevenantWithPosition:_position title:_title image:_image];
}

@end

@interface UISliderTrackConfiguration ()
@property (nonatomic, readwrite, copy) NSArray<UISliderTick *> *ticks;
- (instancetype)initRevenantWithTicks:(NSArray<UISliderTick *> *)ticks;
@end

@implementation UISliderTrackConfiguration

@synthesize ticks = _ticks;

+ (instancetype)configurationWithTicks:(NSArray<UISliderTick *> *)ticks
{
    return [[self alloc] initRevenantWithTicks:ticks];
}

+ (instancetype)configurationWithNumberOfTicks:(NSInteger)ticks
{
    NSMutableArray<UISliderTick *> *positioned = [NSMutableArray arrayWithCapacity:MAX(ticks, 0)];
    for (NSInteger index = 0; index < ticks; index++) {
        float position = ticks == 1 ? 0.5f : (float)index / (float)(ticks - 1);
        [positioned addObject:[UISliderTick tickWithPosition:position title:nil image:nil]];
    }
    return [self configurationWithTicks:positioned];
}

- (instancetype)initRevenantWithTicks:(NSArray<UISliderTick *> *)ticks
{
    self = [super init];
    if (self) {
        _allowsTickValuesOnly = YES;
        _neutralValue = 0;
        _minimumEnabledValue = 0;
        _maximumEnabledValue = 1;
        NSMutableArray<UISliderTick *> *copies = [NSMutableArray arrayWithCapacity:ticks.count];
        for (UISliderTick *tick in ticks)
            [copies addObject:[tick copy]];
        _ticks = [copies sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(UISliderTick *first, UISliderTick *second) {
            if (first.position < second.position)
                return NSOrderedAscending;
            if (first.position > second.position)
                return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
    return self;
}

- (void)setMinimumEnabledValue:(float)minimumEnabledValue
{
    if (minimumEnabledValue > _maximumEnabledValue)
        [NSException raise:NSInvalidArgumentException format:@"minimumEnabledValue %g is above maximumEnabledValue %g", minimumEnabledValue, _maximumEnabledValue];
    _minimumEnabledValue = minimumEnabledValue;
}

- (void)setMaximumEnabledValue:(float)maximumEnabledValue
{
    if (maximumEnabledValue < _minimumEnabledValue)
        [NSException raise:NSInvalidArgumentException format:@"maximumEnabledValue %g is below minimumEnabledValue %g", maximumEnabledValue, _minimumEnabledValue];
    _maximumEnabledValue = maximumEnabledValue;
}

- (id)copyWithZone:(NSZone *)zone
{
    UISliderTrackConfiguration *copy = [[self.class allocWithZone:zone] initRevenantWithTicks:_ticks];
    copy->_allowsTickValuesOnly = _allowsTickValuesOnly;
    copy->_neutralValue = _neutralValue;
    copy->_minimumEnabledValue = _minimumEnabledValue;
    copy->_maximumEnabledValue = _maximumEnabledValue;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSArray *ticks = [coder decodeObjectForKey:@"ticks"];
    if (![ticks isKindOfClass:NSArray.class])
        return nil;
    for (id tick in ticks) {
        if (![tick isKindOfClass:UISliderTick.class])
            return nil;
    }
    float minimum = [coder decodeFloatForKey:@"minimumEnabledValue"];
    float maximum = [coder decodeFloatForKey:@"maximumEnabledValue"];
    if (minimum > maximum)
        return nil;
    self = [self initRevenantWithTicks:ticks];
    if (self) {
        _allowsTickValuesOnly = [coder decodeBoolForKey:@"allowsTickValuesOnly"];
        _neutralValue = [coder decodeFloatForKey:@"neutralValue"];
        _minimumEnabledValue = minimum;
        _maximumEnabledValue = maximum;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_allowsTickValuesOnly forKey:@"allowsTickValuesOnly"];
    [coder encodeFloat:_neutralValue forKey:@"neutralValue"];
    [coder encodeFloat:_minimumEnabledValue forKey:@"minimumEnabledValue"];
    [coder encodeFloat:_maximumEnabledValue forKey:@"maximumEnabledValue"];
    [coder encodeObject:_ticks forKey:@"ticks"];
}

@end

@implementation UISlider (RevenantUISliderTrackConfiguration)

- (UISliderTrackConfiguration *)trackConfiguration
{
    return objc_getAssociatedObject(self, &RevenantSliderTrackConfigurationKey);
}

- (void)setTrackConfiguration:(UISliderTrackConfiguration *)configuration
{
    objc_setAssociatedObject(self, &RevenantSliderTrackConfigurationKey, [configuration copy],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
