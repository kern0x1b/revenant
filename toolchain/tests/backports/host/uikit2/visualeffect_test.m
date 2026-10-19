#import <UIKit/UIKit.h>
#import "check.h"

@interface RevenantHostUIVisualEffect : NSObject <NSCopying, NSSecureCoding>
@end
@interface RevenantHostUIBlurEffect : RevenantHostUIVisualEffect
+ (instancetype)effectWithStyle:(NSInteger)style;
@end
@interface RevenantHostUIVibrancyEffect : RevenantHostUIVisualEffect
+ (instancetype)effectForBlurEffect:(RevenantHostUIBlurEffect *)effect;
@end
@interface RevenantHostUIVisualEffectView : UIView
- (instancetype)initWithEffect:(RevenantHostUIVisualEffect *)effect;
@property (nonatomic, copy) RevenantHostUIVisualEffect *effect;
@property (nonatomic, readonly) UIView *contentView;
@end

static NSArray *keys(id object)
{
    NSError *error = nil; NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error]; if (!data) { printf("archive: %s\n", error.userInfo[NSUnderlyingErrorKey] ? [[error.userInfo[NSUnderlyingErrorKey] localizedDescription] UTF8String] : error.description.UTF8String); return @[]; }
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    NSMutableSet *found = [NSMutableSet set];
    for (id entry in plist[@"$objects"])
        if ([entry isKindOfClass:[NSDictionary class]] && entry[@"$class"]) {
            NSMutableArray *own = [[entry allKeys] mutableCopy];
            [own removeObject:@"$class"];
            [found addObjectsFromArray:own];
        }
    NSArray *sorted = [found.allObjects sortedArrayUsingSelector:@selector(compare:)];
    return sorted;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception.name;
    }
    return @"none";
}

int main(void)
{
    @autoreleasepool {
        for (NSInteger style = 0; style <= 2; style++) {
            RevenantHostUIBlurEffect *ours = [RevenantHostUIBlurEffect effectWithStyle:style];
            UIBlurEffect *system = [UIBlurEffect effectWithStyle:(UIBlurEffectStyle)style];
            revenant_check([ours copy] == ours && [system copy] == system, "an effect is immutable, so a copy is the same object", @"a copy is another object");
            revenant_check([ours isEqual:[RevenantHostUIBlurEffect effectWithStyle:style]] == [system isEqual:[UIBlurEffect effectWithStyle:(UIBlurEffectStyle)style]], "two effects of one style are equal", @"the equality differs");
            revenant_check([ours isEqual:[RevenantHostUIBlurEffect effectWithStyle:style + 1]] == [system isEqual:[UIBlurEffect effectWithStyle:(UIBlurEffectStyle)(style + 1)]], "two effects of two styles are not", @"the equality differs");
            revenant_check([keys(ours) isEqual:keys(system)], "a blur effect archives under the keys the system uses", ([NSString stringWithFormat:@"%@ != %@", keys(ours), keys(system)]));
        }
        RevenantHostUIBlurEffect *ourBlur = [RevenantHostUIBlurEffect effectWithStyle:1];
        UIBlurEffect *systemBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        revenant_check([keys([RevenantHostUIVibrancyEffect effectForBlurEffect:ourBlur]) isEqual:keys([UIVibrancyEffect effectForBlurEffect:systemBlur])], "a vibrancy effect archives under the keys the system uses", @"the keys differ");
        revenant_check([[RevenantHostUIVibrancyEffect effectForBlurEffect:ourBlur] isEqual:[RevenantHostUIVibrancyEffect effectForBlurEffect:ourBlur]] == [[UIVibrancyEffect effectForBlurEffect:systemBlur] isEqual:[UIVibrancyEffect effectForBlurEffect:systemBlur]], "two vibrancy effects of one blur are equal", @"the equality differs");

        RevenantHostUIVisualEffectView *ours = [[RevenantHostUIVisualEffectView alloc] initWithEffect:ourBlur];
        UIVisualEffectView *system = [[UIVisualEffectView alloc] initWithEffect:systemBlur];
        revenant_check(ours.effect == ourBlur && system.effect == systemBlur, "the effect it was given is the effect it answers", @"another object comes back");
        revenant_check(CGRectEqualToRect(ours.frame, system.frame) && CGRectEqualToRect(ours.contentView.frame, system.contentView.frame), "a view made with an effect has no size", @"the frames differ");
        revenant_check(ours.contentView.autoresizingMask == system.contentView.autoresizingMask && ours.contentView.superview == ours && system.contentView.superview == system, "the content view fills the view and is its subview", @"the content view differs");
        ours.frame = CGRectMake(3, 4, 100, 50);
        system.frame = CGRectMake(3, 4, 100, 50);
        revenant_check(CGRectEqualToRect(ours.contentView.frame, system.contentView.frame), "the content view follows the size of the view", ([NSString stringWithFormat:@"%@ != %@", NSStringFromCGRect(ours.contentView.frame), NSStringFromCGRect(system.contentView.frame)]));
        ours.bounds = CGRectMake(0, 0, 30, 40);
        system.bounds = CGRectMake(0, 0, 30, 40);
        revenant_check(CGRectEqualToRect(ours.contentView.frame, system.contentView.frame), "and the size of its bounds", @"the content view differs");
        revenant_check([ours.backgroundColor isEqual:system.backgroundColor] || (ours.backgroundColor == nil && system.backgroundColor == nil), "the view has no colour of its own", @"a colour is there");
        revenant_check(ours.opaque == system.opaque && ours.clipsToBounds == system.clipsToBounds && ours.userInteractionEnabled == system.userInteractionEnabled, "opacity, clipping and touches are the view's own", @"they differ");

        UIView *first = [[UIView alloc] init], *second = [[UIView alloc] init];
        [ours.contentView addSubview:first];
        [system.contentView addSubview:second];
        revenant_check(ours.contentView.subviews.count == system.contentView.subviews.count && first.superview == ours.contentView, "a view added to the content view is its subview", @"it is not");

        revenant_check([raised(^{ [ours addSubview:[[UIView alloc] init]]; }) isEqualToString:raised(^{ [system addSubview:[[UIView alloc] init]]; })], "a subview added to the view itself is refused with the same exception", @"the exceptions differ");
        revenant_check([raised(^{ [ours insertSubview:[[UIView alloc] init] atIndex:0]; }) isEqualToString:raised(^{ [system insertSubview:[[UIView alloc] init] atIndex:0]; })], "so is one inserted at an index", @"the exceptions differ");
        revenant_check([raised(^{ [ours insertSubview:[[UIView alloc] init] aboveSubview:ours.contentView]; }) isEqualToString:raised(^{ [system insertSubview:[[UIView alloc] init] aboveSubview:system.contentView]; })], "so is one inserted above the content view", @"the exceptions differ");
        revenant_check([raised(^{ [ours insertSubview:[[UIView alloc] init] belowSubview:ours.contentView]; }) isEqualToString:raised(^{ [system insertSubview:[[UIView alloc] init] belowSubview:system.contentView]; })], "so is one inserted below it", @"the exceptions differ");
        revenant_check([raised(^{ [ours addSubview:nil]; }) isEqualToString:raised(^{ [system addSubview:nil]; })], "so is nothing", @"the exceptions differ");
        revenant_check(ours.subviews.count == 1 && system.subviews.count >= 1, "a refused subview is not added", @"it was added");

        RevenantHostUIVisualEffectView *bare = [[RevenantHostUIVisualEffectView alloc] initWithEffect:nil];
        UIVisualEffectView *bareSystem = [[UIVisualEffectView alloc] initWithEffect:nil];
        revenant_check(bare.effect == nil && bareSystem.effect == nil && bare.contentView != nil && bareSystem.contentView != nil, "a view with no effect still has a content view", @"it has none");
        RevenantHostUIVisualEffectView *framed = [[RevenantHostUIVisualEffectView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
        UIVisualEffectView *framedSystem = [[UIVisualEffectView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
        revenant_check(framed.effect == nil && framedSystem.effect == nil && CGRectEqualToRect(framed.contentView.frame, framedSystem.contentView.frame), "a view made with a frame has no effect and a content view of its size", @"they differ");
        ours.effect = nil;
        system.effect = nil;
        revenant_check(ours.effect == nil && system.effect == nil && ours.contentView.superview == ours, "an effect taken away leaves the content view", @"it went");
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
        [archiver encodeObject:ours forKey:NSKeyedArchiveRootObjectKey];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
        unarchiver.requiresSecureCoding = NO;
        RevenantHostUIVisualEffectView *revived = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        revenant_check(revived != nil && revived.contentView != nil && revived.contentView.superview == revived && revived.subviews.count == 1, "a view comes back from an archive with its content view in place", @"it does not");
    }
    printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    return revenant_failures;
}
