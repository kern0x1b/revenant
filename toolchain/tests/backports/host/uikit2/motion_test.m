#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface RevenantHostUIMotionEffect : NSObject <NSCopying, NSCoding>
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset;
@end

@interface RevenantHostUIInterpolatingMotionEffect : RevenantHostUIMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type;
@property (readonly, nonatomic) NSString *keyPath;
@property (readonly, nonatomic) UIInterpolatingMotionEffectType type;
@property (strong, nonatomic) id minimumRelativeValue;
@property (strong, nonatomic) id maximumRelativeValue;
@end

@interface RevenantHostUIMotionEffectGroup : RevenantHostUIMotionEffect
@property (copy, nonatomic) NSArray *motionEffects;
@end

@interface UIView (RevenantHostMotionEffects)
- (NSArray *)revenantHostMotionEffects;
- (void)revenantHostSetMotionEffects:(NSArray *)motionEffects;
- (void)revenantHostAddMotionEffect:(RevenantHostUIMotionEffect *)effect;
- (void)revenantHostRemoveMotionEffect:(RevenantHostUIMotionEffect *)effect;
- (void)revenantHostRevenant_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration;
@end

static RevenantHostUIInterpolatingMotionEffect *effect_for(NSString *keyPath, UIInterpolatingMotionEffectType type, id minimum, id maximum)
{
    RevenantHostUIInterpolatingMotionEffect *effect = [[RevenantHostUIInterpolatingMotionEffect alloc] initWithKeyPath:keyPath type:type];
    effect.minimumRelativeValue = minimum;
    effect.maximumRelativeValue = maximum;
    return effect;
}

static double expected_value(double offset, double minimum, double maximum)
{
    double clamped = MAX(-1, MIN(1, offset));
    return minimum + (clamped + 1) / 2 * (maximum - minimum);
}

int main(void)
{
    @autoreleasepool {
        double offsets[] = {-2, -1, -0.5, 0, 0.25, 1, 1.5};
        RevenantHostUIInterpolatingMotionEffect *horizontal = effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @(-10), @30);
        RevenantHostUIInterpolatingMotionEffect *vertical = effect_for(@"center.y", UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis, @(-10), @30);
        for (NSUInteger index = 0; index < sizeof(offsets) / sizeof(*offsets); index++) {
            NSDictionary *values = [horizontal keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(offsets[index], 0.5)];
            double ours = [[values objectForKey:@"center.x"] doubleValue];
            revenant_check(fabs(ours - expected_value(offsets[index], -10, 30)) < 1e-6, NAMED(@"horizontal tilt %g", offsets[index]),
                         [NSString stringWithFormat:@"%g != %g", ours, expected_value(offsets[index], -10, 30)]);
            revenant_check(values.count == 1, NAMED(@"horizontal tilt %g emits one key path", offsets[index]), @"more than one key path");
            NSDictionary *down = [vertical keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(0.5, offsets[index])];
            double downwards = [[down objectForKey:@"center.y"] doubleValue];
            revenant_check(fabs(downwards - expected_value(-offsets[index], -10, 30)) < 1e-6, NAMED(@"vertical tilt %g", offsets[index]),
                         [NSString stringWithFormat:@"%g != %g", downwards, expected_value(-offsets[index], -10, 30)]);
        }
        RevenantHostUIInterpolatingMotionEffect *points = effect_for(@"center", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis,
                                                                  [NSValue valueWithCGPoint:CGPointMake(-4, 2)], [NSValue valueWithCGPoint:CGPointMake(8, -6)]);
        CGPoint point = [[[points keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(0.5, 0)] objectForKey:@"center"] CGPointValue];
        revenant_check(fabs(point.x - expected_value(0.5, -4, 8)) < 1e-6 && fabs(point.y - expected_value(0.5, 2, -6)) < 1e-6, "a point relative value",
                     [NSString stringWithFormat:@"%@", NSStringFromCGPoint(point)]);
        revenant_check([effect_for(@"center.x", 0, nil, @10) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an effect without a minimum emits nothing", @"values were emitted");
        revenant_check([effect_for(nil, 0, @0, @10) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an effect without a key path emits nothing", @"values were emitted");
        revenant_check([effect_for(@"center.x", 0, @0, [NSValue valueWithCGPoint:CGPointZero]) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil,
                     "an effect with mismatched value types emits nothing", @"values were emitted");
        revenant_check([[[RevenantHostUIMotionEffect alloc] init] keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "the abstract effect emits nothing", @"values were emitted");

        RevenantHostUIInterpolatingMotionEffect *copy = [horizontal copy];
        revenant_check([copy.keyPath isEqualToString:horizontal.keyPath] && copy.type == horizontal.type &&
                     [copy.minimumRelativeValue isEqual:horizontal.minimumRelativeValue], "copying an effect", @"the copy differs");
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:horizontal requiringSecureCoding:NO error:NULL];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
        unarchiver.requiresSecureCoding = NO;
        RevenantHostUIInterpolatingMotionEffect *decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        revenant_check([decoded.keyPath isEqualToString:@"center.x"] && [decoded.maximumRelativeValue isEqual:@30], "coding an effect", @"the decoded effect differs");

        RevenantHostUIMotionEffectGroup *group = [[RevenantHostUIMotionEffectGroup alloc] init];
        revenant_check([group keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an empty group emits nothing", @"values were emitted");
        group.motionEffects = @[horizontal, effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @1, @3), vertical];
        NSDictionary *merged = [group keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(1, -1)];
        revenant_check(merged.count == 2, "a group merges the key paths of its effects", [NSString stringWithFormat:@"%@", merged]);
        revenant_check(fabs([[merged objectForKey:@"center.x"] doubleValue] - (30 + 3)) < 1e-6, "a group adds the values of one key path", [NSString stringWithFormat:@"%@", merged]);
        revenant_check(fabs([[merged objectForKey:@"center.y"] doubleValue] - 30) < 1e-6, "a group keeps the values of the other key path", [NSString stringWithFormat:@"%@", merged]);
        RevenantHostUIMotionEffectGroup *nested = [[RevenantHostUIMotionEffectGroup alloc] init];
        nested.motionEffects = @[group, horizontal];
        revenant_check(fabs([[[nested keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(1, -1)] objectForKey:@"center.x"] doubleValue] - (30 + 3 + 30)) < 1e-6,
                     "a group inside a group", @"the nested values are wrong");

        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        revenant_check([view revenantHostMotionEffects].count == 0, "a view starts without motion effects", @"effects were found");
        [view revenantHostAddMotionEffect:horizontal];
        [view revenantHostAddMotionEffect:horizontal];
        revenant_check([view revenantHostMotionEffects].count == 1, "a view holds an effect once", @"the effect was added twice");
        [view revenantHostAddMotionEffect:vertical];
        revenant_check([view revenantHostMotionEffects].count == 2, "a view holds several effects", @"the second effect is missing");
        [view revenantHostRemoveMotionEffect:horizontal];
        revenant_check([view revenantHostMotionEffects].count == 1 && [[view revenantHostMotionEffects] objectAtIndex:0] == vertical, "removing an effect", @"the wrong effect was removed");
        [view revenantHostSetMotionEffects:@[horizontal, (RevenantHostUIMotionEffect *)@"not an effect"]];
        revenant_check([view revenantHostMotionEffects].count == 2, "setting the effects keeps what is not an effect, as the system does", @"a foreign object was dropped");

        [view revenantHostSetMotionEffects:@[effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @(-10), @10),
                                           effect_for(@"layer.shadowOpacity", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @0, @1)]];
        [view revenantHostRevenant_applyMotionEffectsForViewerOffset:UIOffsetMake(1, 0) duration:0.05];
        CABasicAnimation *position = (CABasicAnimation *)[view.layer animationForKey:@"revenant.motionEffect.position.x"];
        CABasicAnimation *shadow = (CABasicAnimation *)[view.layer animationForKey:@"revenant.motionEffect.shadowOpacity"];
        revenant_check(position != nil && shadow != nil, "applying the effects animates the layer", @"no animation was added");
        revenant_check(position.additive, "the applied animation is additive", @"the animation replaces the layer value");
        revenant_check([position.toValue doubleValue] == 10 && [position.fromValue doubleValue] == 0, "the applied animation carries the relative value",
                     [NSString stringWithFormat:@"%@ -> %@", position.fromValue, position.toValue]);
        revenant_check([shadow.toValue doubleValue] == 1, "a layer key path is applied without its prefix", [NSString stringWithFormat:@"%@", shadow.toValue]);
        [view revenantHostRevenant_applyMotionEffectsForViewerOffset:UIOffsetMake(-1, 0) duration:0.05];
        position = (CABasicAnimation *)[view.layer animationForKey:@"revenant.motionEffect.position.x"];
        revenant_check([position.fromValue doubleValue] == 10 && [position.toValue doubleValue] == -10, "the next update starts where the last one stopped",
                     [NSString stringWithFormat:@"%@ -> %@", position.fromValue, position.toValue]);
        [view revenantHostSetMotionEffects:@[]];
        [view revenantHostRevenant_applyMotionEffectsForViewerOffset:UIOffsetZero duration:0.05];
        position = (CABasicAnimation *)[view.layer animationForKey:@"revenant.motionEffect.position.x"];
        revenant_check([position.toValue doubleValue] == 0 && position.removedOnCompletion, "removing the effects animates the layer back", [NSString stringWithFormat:@"%@", position]);

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
