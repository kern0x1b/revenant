#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface CharonHostUIMotionEffect : NSObject <NSCopying, NSCoding>
- (NSDictionary *)keyPathsAndRelativeValuesForViewerOffset:(UIOffset)viewerOffset;
@end

@interface CharonHostUIInterpolatingMotionEffect : CharonHostUIMotionEffect
- (instancetype)initWithKeyPath:(NSString *)keyPath type:(UIInterpolatingMotionEffectType)type;
@property (readonly, nonatomic) NSString *keyPath;
@property (readonly, nonatomic) UIInterpolatingMotionEffectType type;
@property (strong, nonatomic) id minimumRelativeValue;
@property (strong, nonatomic) id maximumRelativeValue;
@end

@interface CharonHostUIMotionEffectGroup : CharonHostUIMotionEffect
@property (copy, nonatomic) NSArray *motionEffects;
@end

@interface UIView (CharonHostMotionEffects)
- (NSArray *)charonHostMotionEffects;
- (void)charonHostSetMotionEffects:(NSArray *)motionEffects;
- (void)charonHostAddMotionEffect:(CharonHostUIMotionEffect *)effect;
- (void)charonHostRemoveMotionEffect:(CharonHostUIMotionEffect *)effect;
- (void)charonHostCharon_applyMotionEffectsForViewerOffset:(UIOffset)offset duration:(NSTimeInterval)duration;
@end

static CharonHostUIInterpolatingMotionEffect *effect_for(NSString *keyPath, UIInterpolatingMotionEffectType type, id minimum, id maximum)
{
    CharonHostUIInterpolatingMotionEffect *effect = [[CharonHostUIInterpolatingMotionEffect alloc] initWithKeyPath:keyPath type:type];
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
        CharonHostUIInterpolatingMotionEffect *horizontal = effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @(-10), @30);
        CharonHostUIInterpolatingMotionEffect *vertical = effect_for(@"center.y", UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis, @(-10), @30);
        for (NSUInteger index = 0; index < sizeof(offsets) / sizeof(*offsets); index++) {
            NSDictionary *values = [horizontal keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(offsets[index], 0.5)];
            double ours = [[values objectForKey:@"center.x"] doubleValue];
            charon_check(fabs(ours - expected_value(offsets[index], -10, 30)) < 1e-6, NAMED(@"horizontal tilt %g", offsets[index]),
                         [NSString stringWithFormat:@"%g != %g", ours, expected_value(offsets[index], -10, 30)]);
            charon_check(values.count == 1, NAMED(@"horizontal tilt %g emits one key path", offsets[index]), @"more than one key path");
            NSDictionary *down = [vertical keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(0.5, offsets[index])];
            double downwards = [[down objectForKey:@"center.y"] doubleValue];
            charon_check(fabs(downwards - expected_value(-offsets[index], -10, 30)) < 1e-6, NAMED(@"vertical tilt %g", offsets[index]),
                         [NSString stringWithFormat:@"%g != %g", downwards, expected_value(-offsets[index], -10, 30)]);
        }
        CharonHostUIInterpolatingMotionEffect *points = effect_for(@"center", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis,
                                                                  [NSValue valueWithCGPoint:CGPointMake(-4, 2)], [NSValue valueWithCGPoint:CGPointMake(8, -6)]);
        CGPoint point = [[[points keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(0.5, 0)] objectForKey:@"center"] CGPointValue];
        charon_check(fabs(point.x - expected_value(0.5, -4, 8)) < 1e-6 && fabs(point.y - expected_value(0.5, 2, -6)) < 1e-6, "a point relative value",
                     [NSString stringWithFormat:@"%@", NSStringFromCGPoint(point)]);
        charon_check([effect_for(@"center.x", 0, nil, @10) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an effect without a minimum emits nothing", @"values were emitted");
        charon_check([effect_for(nil, 0, @0, @10) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an effect without a key path emits nothing", @"values were emitted");
        charon_check([effect_for(@"center.x", 0, @0, [NSValue valueWithCGPoint:CGPointZero]) keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil,
                     "an effect with mismatched value types emits nothing", @"values were emitted");
        charon_check([[[CharonHostUIMotionEffect alloc] init] keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "the abstract effect emits nothing", @"values were emitted");

        CharonHostUIInterpolatingMotionEffect *copy = [horizontal copy];
        charon_check([copy.keyPath isEqualToString:horizontal.keyPath] && copy.type == horizontal.type &&
                     [copy.minimumRelativeValue isEqual:horizontal.minimumRelativeValue], "copying an effect", @"the copy differs");
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:horizontal requiringSecureCoding:NO error:NULL];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
        unarchiver.requiresSecureCoding = NO;
        CharonHostUIInterpolatingMotionEffect *decoded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        charon_check([decoded.keyPath isEqualToString:@"center.x"] && [decoded.maximumRelativeValue isEqual:@30], "coding an effect", @"the decoded effect differs");

        CharonHostUIMotionEffectGroup *group = [[CharonHostUIMotionEffectGroup alloc] init];
        charon_check([group keyPathsAndRelativeValuesForViewerOffset:UIOffsetZero] == nil, "an empty group emits nothing", @"values were emitted");
        group.motionEffects = @[horizontal, effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @1, @3), vertical];
        NSDictionary *merged = [group keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(1, -1)];
        charon_check(merged.count == 2, "a group merges the key paths of its effects", [NSString stringWithFormat:@"%@", merged]);
        charon_check(fabs([[merged objectForKey:@"center.x"] doubleValue] - (30 + 3)) < 1e-6, "a group adds the values of one key path", [NSString stringWithFormat:@"%@", merged]);
        charon_check(fabs([[merged objectForKey:@"center.y"] doubleValue] - 30) < 1e-6, "a group keeps the values of the other key path", [NSString stringWithFormat:@"%@", merged]);
        CharonHostUIMotionEffectGroup *nested = [[CharonHostUIMotionEffectGroup alloc] init];
        nested.motionEffects = @[group, horizontal];
        charon_check(fabs([[[nested keyPathsAndRelativeValuesForViewerOffset:UIOffsetMake(1, -1)] objectForKey:@"center.x"] doubleValue] - (30 + 3 + 30)) < 1e-6,
                     "a group inside a group", @"the nested values are wrong");

        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        charon_check([view charonHostMotionEffects].count == 0, "a view starts without motion effects", @"effects were found");
        [view charonHostAddMotionEffect:horizontal];
        [view charonHostAddMotionEffect:horizontal];
        charon_check([view charonHostMotionEffects].count == 1, "a view holds an effect once", @"the effect was added twice");
        [view charonHostAddMotionEffect:vertical];
        charon_check([view charonHostMotionEffects].count == 2, "a view holds several effects", @"the second effect is missing");
        [view charonHostRemoveMotionEffect:horizontal];
        charon_check([view charonHostMotionEffects].count == 1 && [[view charonHostMotionEffects] objectAtIndex:0] == vertical, "removing an effect", @"the wrong effect was removed");
        [view charonHostSetMotionEffects:@[horizontal, (CharonHostUIMotionEffect *)@"not an effect"]];
        charon_check([view charonHostMotionEffects].count == 2, "setting the effects keeps what is not an effect, as the system does", @"a foreign object was dropped");

        [view charonHostSetMotionEffects:@[effect_for(@"center.x", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @(-10), @10),
                                           effect_for(@"layer.shadowOpacity", UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis, @0, @1)]];
        [view charonHostCharon_applyMotionEffectsForViewerOffset:UIOffsetMake(1, 0) duration:0.05];
        CABasicAnimation *position = (CABasicAnimation *)[view.layer animationForKey:@"charon.motionEffect.position.x"];
        CABasicAnimation *shadow = (CABasicAnimation *)[view.layer animationForKey:@"charon.motionEffect.shadowOpacity"];
        charon_check(position != nil && shadow != nil, "applying the effects animates the layer", @"no animation was added");
        charon_check(position.additive, "the applied animation is additive", @"the animation replaces the layer value");
        charon_check([position.toValue doubleValue] == 10 && [position.fromValue doubleValue] == 0, "the applied animation carries the relative value",
                     [NSString stringWithFormat:@"%@ -> %@", position.fromValue, position.toValue]);
        charon_check([shadow.toValue doubleValue] == 1, "a layer key path is applied without its prefix", [NSString stringWithFormat:@"%@", shadow.toValue]);
        [view charonHostCharon_applyMotionEffectsForViewerOffset:UIOffsetMake(-1, 0) duration:0.05];
        position = (CABasicAnimation *)[view.layer animationForKey:@"charon.motionEffect.position.x"];
        charon_check([position.fromValue doubleValue] == 10 && [position.toValue doubleValue] == -10, "the next update starts where the last one stopped",
                     [NSString stringWithFormat:@"%@ -> %@", position.fromValue, position.toValue]);
        [view charonHostSetMotionEffects:@[]];
        [view charonHostCharon_applyMotionEffectsForViewerOffset:UIOffsetZero duration:0.05];
        position = (CABasicAnimation *)[view.layer animationForKey:@"charon.motionEffect.position.x"];
        charon_check([position.toValue doubleValue] == 0 && position.removedOnCompletion, "removing the effects animates the layer back", [NSString stringWithFormat:@"%@", position]);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
