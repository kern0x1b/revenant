#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

@interface RevenantHostUIListSeparatorConfiguration : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithListAppearance:(UICollectionLayoutListAppearance)listAppearance;
@property (nonatomic) UIListSeparatorVisibility topSeparatorVisibility;
@property (nonatomic) UIListSeparatorVisibility bottomSeparatorVisibility;
@property (nonatomic) NSDirectionalEdgeInsets topSeparatorInsets;
@property (nonatomic) NSDirectionalEdgeInsets bottomSeparatorInsets;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) UIColor *multipleSelectionColor;
@property (nonatomic, copy, nullable) UIVisualEffect *visualEffect;
@end

typedef id (*zero_init)(id, SEL);
typedef id (*sep_init)(id, SEL, UICollectionLayoutListAppearance);

static void BOTH(NSString *what, NSString *ours, NSString *theirs)
{
    revenant_check([ours isEqualToString:theirs], what.UTF8String,
                 [NSString stringWithFormat:@"port %@ != system %@", ours, theirs]);
}

static NSString *insets(NSDirectionalEdgeInsets e)
{
    return [NSString stringWithFormat:@"%g %g %g %g", (double)e.top, (double)e.leading, (double)e.bottom, (double)e.trailing];
}

static NSString *colourRole(UIColor *color)
{
    if (!color)
        return @"none";
    if ([color isEqual:[UIColor clearColor]])
        return @"clear";
    return @"present";
}

static void equality(NSString *what, void (^write)(id configuration), Class port, Class system)
{
    UICollectionLayoutListAppearance appearance = UICollectionLayoutListAppearancePlain;
    NSObject *written = [[port alloc] initWithListAppearance:appearance];
    NSObject *fresh = [[port alloc] initWithListAppearance:appearance];
    write(written);
    NSObject *writtenTheirs = [[system alloc] initWithListAppearance:appearance];
    NSObject *freshTheirs = [[system alloc] initWithListAppearance:appearance];
    write(writtenTheirs);
    BOTH(what,
         [NSString stringWithFormat:@"%d/%@", (int)[written isEqual:fresh],
          written.hash == fresh.hash ? @"same hash" : @"other hash"],
         [NSString stringWithFormat:@"%d/%@", (int)[writtenTheirs isEqual:freshTheirs],
          writtenTheirs.hash == freshTheirs.hash ? @"same hash" : @"other hash"]);
}

static void check_one_appearance(NSInteger appearance, NSString *label)
{
    RevenantHostUIListSeparatorConfiguration *ours = [[RevenantHostUIListSeparatorConfiguration alloc] initWithListAppearance:(UICollectionLayoutListAppearance)appearance];
    UIListSeparatorConfiguration *theirs = [[UIListSeparatorConfiguration alloc] initWithListAppearance:(UICollectionLayoutListAppearance)appearance];
    revenant_check(ours != nil && theirs != nil, "both sides build a separator configuration", @"one side answered nothing");

    BOTH([NSString stringWithFormat:@"the %@ top visibility", label],
         [NSString stringWithFormat:@"%ld", (long)ours.topSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirs.topSeparatorVisibility]);
    BOTH([NSString stringWithFormat:@"the %@ bottom visibility", label],
         [NSString stringWithFormat:@"%ld", (long)ours.bottomSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirs.bottomSeparatorVisibility]);
    BOTH([NSString stringWithFormat:@"the %@ top insets are the automatic ones", label],
         insets(ours.topSeparatorInsets), insets(theirs.topSeparatorInsets));
    BOTH([NSString stringWithFormat:@"the %@ bottom insets are the automatic ones", label],
         insets(ours.bottomSeparatorInsets), insets(theirs.bottomSeparatorInsets));
    BOTH([NSString stringWithFormat:@"the %@ insets are the shared constant", label],
         [NSString stringWithFormat:@"%d", (int)(ours.topSeparatorInsets.leading == UIListSeparatorAutomaticInsets.leading)],
         [NSString stringWithFormat:@"%d", (int)(theirs.topSeparatorInsets.leading == UIListSeparatorAutomaticInsets.leading)]);
    BOTH([NSString stringWithFormat:@"the %@ colour is a colour", label], colourRole(ours.color), colourRole(theirs.color));
    BOTH([NSString stringWithFormat:@"the %@ multiple-selection colour is a colour", label],
         colourRole(ours.multipleSelectionColor), colourRole(theirs.multipleSelectionColor));
    BOTH([NSString stringWithFormat:@"the %@ visual effect is nil until written", label],
         ours.visualEffect ? @"set" : @"nil", theirs.visualEffect ? @"set" : @"nil");

    ours.topSeparatorVisibility = 2; theirs.topSeparatorVisibility = 2;
    ours.bottomSeparatorVisibility = 1; theirs.bottomSeparatorVisibility = 1;
    ours.topSeparatorInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
    theirs.topSeparatorInsets = NSDirectionalEdgeInsetsMake(1, 2, 3, 4);
    ours.bottomSeparatorInsets = NSDirectionalEdgeInsetsMake(5, 6, 7, 8);
    theirs.bottomSeparatorInsets = NSDirectionalEdgeInsetsMake(5, 6, 7, 8);
    ours.color = [UIColor redColor]; theirs.color = [UIColor redColor];
    ours.multipleSelectionColor = [UIColor greenColor]; theirs.multipleSelectionColor = [UIColor greenColor];
    BOTH([NSString stringWithFormat:@"a written %@ top visibility reads back", label],
         [NSString stringWithFormat:@"%ld", (long)ours.topSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirs.topSeparatorVisibility]);
    BOTH([NSString stringWithFormat:@"a written %@ bottom visibility reads back", label],
         [NSString stringWithFormat:@"%ld", (long)ours.bottomSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirs.bottomSeparatorVisibility]);
    BOTH([NSString stringWithFormat:@"a written %@ top insets read back", label],
         insets(ours.topSeparatorInsets), insets(theirs.topSeparatorInsets));
    BOTH([NSString stringWithFormat:@"a written %@ bottom insets read back", label],
         insets(ours.bottomSeparatorInsets), insets(theirs.bottomSeparatorInsets));
    BOTH([NSString stringWithFormat:@"a written %@ colour reads back by identity", label],
         ours.color == [UIColor redColor] ? @"same" : @"copied", theirs.color == [UIColor redColor] ? @"same" : @"copied");
    BOTH([NSString stringWithFormat:@"a written %@ multiple-selection colour reads back by identity", label],
         ours.multipleSelectionColor == [UIColor greenColor] ? @"same" : @"copied",
         theirs.multipleSelectionColor == [UIColor greenColor] ? @"same" : @"copied");

    RevenantHostUIListSeparatorConfiguration *ourCopy = [ours copy];
    UIListSeparatorConfiguration *theirCopy = [theirs copy];
    BOTH([NSString stringWithFormat:@"a %@ copy is not its receiver", label], ourCopy == ours ? @"same" : @"other",
         theirCopy == theirs ? @"same" : @"other");
    BOTH([NSString stringWithFormat:@"a %@ copy keeps the top visibility", label],
         [NSString stringWithFormat:@"%ld", (long)ourCopy.topSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirCopy.topSeparatorVisibility]);
    BOTH([NSString stringWithFormat:@"a %@ copy keeps the bottom insets", label],
         insets(ourCopy.bottomSeparatorInsets), insets(theirCopy.bottomSeparatorInsets));
    BOTH([NSString stringWithFormat:@"a %@ copy keeps the colour instance", label],
         ourCopy.color == ours.color ? @"same" : @"other", theirCopy.color == theirs.color ? @"same" : @"other");

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    ours.visualEffect = effect;
    theirs.visualEffect = effect;
    BOTH([NSString stringWithFormat:@"the %@ visual effect is a visual effect", label],
         ours.visualEffect ? NSStringFromClass([ours.visualEffect class]) : @"nil",
         theirs.visualEffect ? NSStringFromClass([theirs.visualEffect class]) : @"nil");
    BOTH([NSString stringWithFormat:@"the %@ visual effect is copied on the way in", label],
         ours.visualEffect == effect ? @"same" : @"copy", theirs.visualEffect == effect ? @"same" : @"copy");
    UIListSeparatorConfiguration *ourEffectCopy = [ours copy];
    UIListSeparatorConfiguration *theirEffectCopy = [theirs copy];
    BOTH([NSString stringWithFormat:@"the %@ copy carries the visual effect", label],
         ourEffectCopy.visualEffect ? NSStringFromClass([ourEffectCopy.visualEffect class]) : @"nil",
         theirEffectCopy.visualEffect ? NSStringFromClass([theirEffectCopy.visualEffect class]) : @"nil");
    BOTH([NSString stringWithFormat:@"the %@ copy's visual effect is copied too", label],
         ourEffectCopy.visualEffect == ours.visualEffect ? @"same" : @"other",
         theirEffectCopy.visualEffect == theirs.visualEffect ? @"same" : @"other");

    NSError *ourError = nil, *theirError = nil, *ourReadError = nil, *theirReadError = nil;
    NSData *ourArchive = [NSKeyedArchiver archivedDataWithRootObject:ours requiringSecureCoding:YES error:&ourError];
    NSData *theirArchive = [NSKeyedArchiver archivedDataWithRootObject:theirs requiringSecureCoding:YES error:&theirError];
    revenant_check(ourArchive != nil && theirArchive != nil, [[NSString stringWithFormat:@"the %@ archives", label] UTF8String],
                 [NSString stringWithFormat:@"port %@ (%lu bytes) system %@ (%lu bytes)", ourError,
                  (unsigned long)ourArchive.length, theirError, (unsigned long)theirArchive.length]);
    if (ourArchive && theirArchive) {
        RevenantHostUIListSeparatorConfiguration *ourBack =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[RevenantHostUIListSeparatorConfiguration class] fromData:ourArchive error:&ourReadError];
        UIListSeparatorConfiguration *theirBack =
            [NSKeyedUnarchiver unarchivedObjectOfClass:[UIListSeparatorConfiguration class] fromData:theirArchive error:&theirReadError];
        revenant_check(ourBack != nil && theirBack != nil, [[NSString stringWithFormat:@"the %@ archive reads back", label] UTF8String],
                     [NSString stringWithFormat:@"port %@ system %@", ourBack ? @"an object" : ourReadError,
                      theirBack ? @"an object" : theirReadError]);
        if (ourBack && theirBack) {
            BOTH([NSString stringWithFormat:@"the %@ archived top visibility comes back", label],
                 [NSString stringWithFormat:@"%ld", (long)ourBack.topSeparatorVisibility],
                 [NSString stringWithFormat:@"%ld", (long)theirBack.topSeparatorVisibility]);
            BOTH([NSString stringWithFormat:@"the %@ archived bottom visibility comes back", label],
                 [NSString stringWithFormat:@"%ld", (long)ourBack.bottomSeparatorVisibility],
                 [NSString stringWithFormat:@"%ld", (long)theirBack.bottomSeparatorVisibility]);
            BOTH([NSString stringWithFormat:@"the %@ archived top insets come back", label],
                 insets(ourBack.topSeparatorInsets), insets(theirBack.topSeparatorInsets));
            BOTH([NSString stringWithFormat:@"the %@ archived bottom insets come back", label],
                 insets(ourBack.bottomSeparatorInsets), insets(theirBack.bottomSeparatorInsets));
            BOTH([NSString stringWithFormat:@"the %@ archived colour comes back", label],
                 colourRole(ourBack.color), colourRole(theirBack.color));
            BOTH([NSString stringWithFormat:@"the %@ archived visual effect comes back", label],
                 ourBack.visualEffect ? NSStringFromClass([ourBack.visualEffect class]) : @"nil",
                 theirBack.visualEffect ? NSStringFromClass([theirBack.visualEffect class]) : @"nil");
        }
    }
}

static void check_every_appearance(void)
{
    NSArray *names = @[@"plain", @"grouped", @"inset grouped", @"sidebar", @"sidebar plain"];
    for (NSInteger i = 0; i < (NSInteger)names.count; i++)
        check_one_appearance(i, names[(NSUInteger)i]);
}

static void check_the_equality(void)
{
    Class port = [RevenantHostUIListSeparatorConfiguration class], system = [UIListSeparatorConfiguration class];
    equality(@"two fresh configurations are equal", ^(id c) {}, port, system);
    equality(@"the top visibility joins the equality and the hash", ^(id c) { [c setTopSeparatorVisibility:2]; }, port, system);
    equality(@"the bottom visibility joins the equality and the hash", ^(id c) { [c setBottomSeparatorVisibility:1]; }, port, system);
    equality(@"the top insets join the equality and NOT the hash",
             ^(id c) { [c setTopSeparatorInsets:NSDirectionalEdgeInsetsMake(1, 2, 3, 4)]; }, port, system);
    equality(@"the bottom insets join the equality and the hash",
             ^(id c) { [c setBottomSeparatorInsets:NSDirectionalEdgeInsetsMake(5, 6, 7, 8)]; }, port, system);
    equality(@"the colour joins the equality and the hash", ^(id c) { [c setColor:[UIColor redColor]]; }, port, system);
    equality(@"the multiple-selection colour joins the equality and the hash",
             ^(id c) { [c setMultipleSelectionColor:[UIColor greenColor]]; }, port, system);
    equality(@"the visual effect joins the equality and NOT the hash", ^(id c) {
        [c setVisualEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    }, port, system);
    equality(@"equal colours from separate objects are equal", ^(id c) {
        [c setColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:1]];
        [c setMultipleSelectionColor:[UIColor colorWithRed:0 green:1 blue:0 alpha:1]];
    }, port, system);
    NSObject *ours = [[port alloc] initWithListAppearance:UICollectionLayoutListAppearancePlain];
    NSObject *theirs = [[system alloc] initWithListAppearance:UICollectionLayoutListAppearancePlain];
    BOTH(@"a configuration is not equal to a view",
         [NSString stringWithFormat:@"%d", (int)[ours isEqual:(id)[UIView new]]],
         [NSString stringWithFormat:@"%d", (int)[theirs isEqual:(id)[UIView new]]]);
}

static void check_the_unavailable_pair(void)
{
    RevenantHostUIListSeparatorConfiguration *ours = ((zero_init)objc_msgSend)((id)((zero_init)objc_msgSend)((id)[RevenantHostUIListSeparatorConfiguration class], @selector(alloc)), @selector(init));
    UIListSeparatorConfiguration *theirs = ((zero_init)objc_msgSend)((id)((zero_init)objc_msgSend)((id)[UIListSeparatorConfiguration class], @selector(alloc)), @selector(init));
    revenant_check(ours != nil && theirs != nil, "both sides answer an unavailable -init", @"one side raised");
    BOTH(@"the unavailable -init gives zero top visibility",
         [NSString stringWithFormat:@"%ld", (long)ours.topSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirs.topSeparatorVisibility]);
    BOTH(@"the unavailable -init gives zero top insets", insets(ours.topSeparatorInsets), insets(theirs.topSeparatorInsets));
    BOTH(@"the unavailable -init gives zero bottom insets", insets(ours.bottomSeparatorInsets), insets(theirs.bottomSeparatorInsets));
    BOTH(@"the unavailable -init gives no colour", colourRole(ours.color), colourRole(theirs.color));
    BOTH(@"the unavailable -init gives no multiple-selection colour", colourRole(ours.multipleSelectionColor),
         colourRole(theirs.multipleSelectionColor));

    RevenantHostUIListSeparatorConfiguration *ourNew = ((zero_init)objc_msgSend)((id)[RevenantHostUIListSeparatorConfiguration class], @selector(new));
    UIListSeparatorConfiguration *theirNew = ((zero_init)objc_msgSend)((id)[UIListSeparatorConfiguration class], @selector(new));
    revenant_check(ourNew != nil && theirNew != nil, "both sides answer an unavailable +new", @"one side raised");
    BOTH(@"the unavailable +new gives zero bottom visibility",
         [NSString stringWithFormat:@"%ld", (long)ourNew.bottomSeparatorVisibility],
         [NSString stringWithFormat:@"%ld", (long)theirNew.bottomSeparatorVisibility]);
    BOTH(@"the unavailable +new gives zero bottom insets", insets(ourNew.bottomSeparatorInsets), insets(theirNew.bottomSeparatorInsets));
    BOTH(@"the unavailable +new gives no colour", colourRole(ourNew.color), colourRole(theirNew.color));
    BOTH(@"+supportsSecureCoding", [NSString stringWithFormat:@"%d", (int)[RevenantHostUIListSeparatorConfiguration supportsSecureCoding]],
         [NSString stringWithFormat:@"%d", (int)[UIListSeparatorConfiguration supportsSecureCoding]]);
}

int main(void)
{
    @autoreleasepool {
        check_every_appearance();
        check_the_unavailable_pair();
        check_the_equality();
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
    }
    return revenant_failures;
}
