#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIAction (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier handler:(UIActionHandler)handler NS_SWIFT_NAME(init(revenantTitle:image:identifier:handler:));
@end

@interface UIMenu (RevenantOverlayInitializers)
- (instancetype)initRevenantWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier options:(UIMenuOptions)options children:(NSArray *)children NS_SWIFT_NAME(init(revenantTitle:image:identifier:options:children:));
@end

extern char OBJC_CLASS_$_UIPointerShape __attribute__((weak_import));

static inline Class _Nullable revenant_pointer_shape_class(void)
{
    return &OBJC_CLASS_$_UIPointerShape ? (__bridge Class)(void *)&OBJC_CLASS_$_UIPointerShape : Nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_with_path(UIBezierPath *path) NS_SWIFT_NAME(revenantPointerShape(path:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape shapeWithPath:path] : nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_rounded_rect(CGRect rect, CGFloat radius) NS_SWIFT_NAME(revenantPointerShape(roundedRect:cornerRadius:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape shapeWithRoundedRect:rect cornerRadius:radius] : nil;
}

static inline UIPointerShape *_Nullable revenant_pointer_shape_beam(CGFloat length, UIAxis axis) NS_SWIFT_NAME(revenantPointerShape(beamWithPreferredLength:axis:))
{
    Class shape = revenant_pointer_shape_class();
    return shape ? (UIPointerShape *)[shape beamWithPreferredLength:length axis:axis] : nil;
}

static inline UICornerRadius *_Nullable revenant_corner_radius_fixed(CGFloat radius) NS_SWIFT_NAME(revenantCornerRadius(fixed:))
{
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    return cornerRadius ? [cornerRadius fixedRadius:radius] : nil;
}

static inline UICornerRadius *_Nullable revenant_corner_radius_container_concentric(void) NS_SWIFT_NAME(revenantCornerRadiusContainerConcentric())
{
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    return cornerRadius ? [cornerRadius containerConcentricRadius] : nil;
}

static inline UICornerRadius *_Nullable revenant_corner_radius_container_concentric_with_minimum(CGFloat minimum) NS_SWIFT_NAME(revenantCornerRadius(containerConcentricMinimum:))
{
    Class cornerRadius = NSClassFromString(@"UICornerRadius");
    return cornerRadius ? [cornerRadius containerConcentricRadiusWithMinimum:minimum] : nil;
}

static inline UISliderTick *_Nullable revenant_slider_tick_with_position(float position, NSString *_Nullable title, UIImage *_Nullable image) NS_SWIFT_NAME(revenantSliderTick(position:title:image:))
{
    Class tick = NSClassFromString(@"UISliderTick");
    return tick ? [tick tickWithPosition:position title:title image:image] : nil;
}

static inline UISliderTrackConfiguration *_Nullable revenant_slider_track_configuration_with_number_of_ticks(NSInteger count) NS_SWIFT_NAME(revenantSliderTrackConfiguration(numberOfTicks:))
{
    Class configuration = NSClassFromString(@"UISliderTrackConfiguration");
    return configuration ? [configuration configurationWithNumberOfTicks:count] : nil;
}

static inline UISliderTrackConfiguration *_Nullable revenant_slider_track_configuration_with_ticks(NSArray *ticks) NS_SWIFT_NAME(revenantSliderTrackConfiguration(ticks:))
{
    Class configuration = NSClassFromString(@"UISliderTrackConfiguration");
    return configuration ? [configuration configurationWithTicks:ticks] : nil;
}

static inline NSArray *revenant_slider_track_configuration_ticks(UISliderTrackConfiguration *configuration) NS_SWIFT_NAME(revenantSliderTicks(of:))
{
    return configuration.ticks;
}

static inline float revenant_slider_tick_position(id tick) NS_SWIFT_NAME(revenantSliderTickPosition(_:))
{
    return ((UISliderTick *)tick).position;
}

static inline NSString *_Nullable revenant_slider_tick_title(id tick) NS_SWIFT_NAME(revenantSliderTickTitle(_:))
{
    return ((UISliderTick *)tick).title;
}

static inline UIImage *_Nullable revenant_slider_tick_image(id tick) NS_SWIFT_NAME(revenantSliderTickImage(_:))
{
    return ((UISliderTick *)tick).image;
}

NS_ASSUME_NONNULL_END
