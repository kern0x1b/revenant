#import <UIKit/UIKit.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface RevenantHostUITraitCollection : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)traitCollectionWithTraitsFromCollections:(NSArray *)traitCollections;
+ (instancetype)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom;
+ (instancetype)traitCollectionWithDisplayScale:(CGFloat)scale;
+ (instancetype)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass;
+ (instancetype)traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass;
+ (instancetype)revenant_traitCollectionWithScreenIdiom:(UIUserInterfaceIdiom)screenIdiom deviceIdiom:(UIUserInterfaceIdiom)deviceIdiom scale:(CGFloat)scale bounds:(CGSize)bounds;
- (BOOL)containsTraitsInCollection:(id)trait;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic, readonly) UIUserInterfaceSizeClass verticalSizeClass;
@end

static NSString *traits_of(id collection)
{
    NSString *description = [collection description];
    NSRange separator = [description rangeOfString:@"; "];
    return separator.location == NSNotFound ? description : [description substringFromIndex:NSMaxRange(separator)];
}

static NSString *values_of(id collection)
{
    return [NSString stringWithFormat:@"idiom %ld scale %g horizontal %ld vertical %ld",
            (long)[collection userInterfaceIdiom], (double)[collection displayScale],
            (long)[collection horizontalSizeClass], (long)[collection verticalSizeClass]];
}

static void compare(id ours, UITraitCollection *system, const char *name)
{
    revenant_check([values_of(ours) isEqualToString:values_of(system)], name, [NSString stringWithFormat:@"%@ != %@", values_of(ours), values_of(system)]);
    if ([ours userInterfaceIdiom] > UIUserInterfaceIdiomPad)
        return;
    revenant_check([traits_of(ours) isEqualToString:traits_of(system)], NAMED(@"%s description", name), [NSString stringWithFormat:@"%@ != %@", traits_of(ours), traits_of(system)]);
}

static NSArray *archive_keys(id object)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:NULL];
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    NSMutableArray *keys = [NSMutableArray array];
    for (id entry in [plist objectForKey:@"$objects"]) {
        if (![entry isKindOfClass:[NSDictionary class]])
            continue;
        for (NSString *key in entry) {
            if (![key hasPrefix:@"$"])
                [keys addObject:key];
        }
    }
    [keys sortUsingSelector:@selector(compare:)];
    return keys;
}

int main(void)
{
    @autoreleasepool {
        UIUserInterfaceIdiom idioms[] = {UIUserInterfaceIdiomUnspecified, UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPad, (UIUserInterfaceIdiom)9};
        CGFloat scales[] = {0, 1, 2, 2.5};
        UIUserInterfaceSizeClass classes[] = {UIUserInterfaceSizeClassUnspecified, UIUserInterfaceSizeClassCompact, UIUserInterfaceSizeClassRegular, (UIUserInterfaceSizeClass)5};
        for (int index = 0; index < 4; index++) {
            compare([RevenantHostUITraitCollection traitCollectionWithUserInterfaceIdiom:idioms[index]],
                    [UITraitCollection traitCollectionWithUserInterfaceIdiom:idioms[index]], NAMED(@"idiom %ld", (long)idioms[index]));
            compare([RevenantHostUITraitCollection traitCollectionWithDisplayScale:scales[index]],
                    [UITraitCollection traitCollectionWithDisplayScale:scales[index]], NAMED(@"scale %g", (double)scales[index]));
            compare([RevenantHostUITraitCollection traitCollectionWithHorizontalSizeClass:classes[index]],
                    [UITraitCollection traitCollectionWithHorizontalSizeClass:classes[index]], NAMED(@"horizontal %ld", (long)classes[index]));
            compare([RevenantHostUITraitCollection traitCollectionWithVerticalSizeClass:classes[index]],
                    [UITraitCollection traitCollectionWithVerticalSizeClass:classes[index]], NAMED(@"vertical %ld", (long)classes[index]));
        }
        compare([[RevenantHostUITraitCollection alloc] init], [[UITraitCollection alloc] init], "empty collection");

        NSArray *ourParts = @[[RevenantHostUITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPhone],
                              [RevenantHostUITraitCollection traitCollectionWithDisplayScale:2],
                              [RevenantHostUITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassCompact],
                              [RevenantHostUITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular],
                              [RevenantHostUITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassRegular],
                              [RevenantHostUITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomUnspecified],
                              [RevenantHostUITraitCollection traitCollectionWithDisplayScale:0],
                              [[RevenantHostUITraitCollection alloc] init]];
        NSArray *systemParts = @[[UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPhone],
                                 [UITraitCollection traitCollectionWithDisplayScale:2],
                                 [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassCompact],
                                 [UITraitCollection traitCollectionWithVerticalSizeClass:UIUserInterfaceSizeClassRegular],
                                 [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassRegular],
                                 [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomUnspecified],
                                 [UITraitCollection traitCollectionWithDisplayScale:0],
                                 [[UITraitCollection alloc] init]];
        compare([RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:@[]],
                [UITraitCollection traitCollectionWithTraitsFromCollections:@[]], "merge of nothing");
        compare([RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:nil],
                [UITraitCollection traitCollectionWithTraitsFromCollections:nil], "merge of a nil array");
        for (NSUInteger first = 0; first < ourParts.count; first++) {
            for (NSUInteger second = 0; second < ourParts.count; second++) {
                NSArray *ours = @[[ourParts objectAtIndex:first], [ourParts objectAtIndex:second]];
                NSArray *system = @[[systemParts objectAtIndex:first], [systemParts objectAtIndex:second]];
                compare([RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:ours],
                        [UITraitCollection traitCollectionWithTraitsFromCollections:system], NAMED(@"merge %lu %lu", (unsigned long)first, (unsigned long)second));
            }
        }
        compare([RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:ourParts],
                [UITraitCollection traitCollectionWithTraitsFromCollections:systemParts], "merge of every part");

        for (NSUInteger first = 0; first < ourParts.count; first++) {
            for (NSUInteger second = 0; second < ourParts.count; second++) {
                BOOL ours = [[ourParts objectAtIndex:first] containsTraitsInCollection:[ourParts objectAtIndex:second]];
                BOOL system = [[systemParts objectAtIndex:first] containsTraitsInCollection:[systemParts objectAtIndex:second]];
                revenant_check(ours == system, NAMED(@"contains %lu %lu", (unsigned long)first, (unsigned long)second), [NSString stringWithFormat:@"%d != %d", ours, system]);
                BOOL equalOurs = [[ourParts objectAtIndex:first] isEqual:[ourParts objectAtIndex:second]];
                BOOL equalSystem = [[systemParts objectAtIndex:first] isEqual:[systemParts objectAtIndex:second]];
                revenant_check(equalOurs == equalSystem, NAMED(@"equal %lu %lu", (unsigned long)first, (unsigned long)second), [NSString stringWithFormat:@"%d != %d", equalOurs, equalSystem]);
                if (equalOurs)
                    revenant_check([[ourParts objectAtIndex:first] hash] == [[ourParts objectAtIndex:second] hash], NAMED(@"hash %lu %lu", (unsigned long)first, (unsigned long)second), @"equal collections hash differently");
            }
        }
        id merged = [RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:ourParts];
        UITraitCollection *systemMerged = [UITraitCollection traitCollectionWithTraitsFromCollections:systemParts];
        revenant_check([merged containsTraitsInCollection:nil] == [systemMerged containsTraitsInCollection:nil], "contains nil", @"a nil collection is contained");
        revenant_check([merged copy] == merged, "copy returns the same object", @"copy allocated a new collection");
        revenant_check([[merged class] supportsSecureCoding] == [[systemMerged class] supportsSecureCoding], "supports secure coding", @"secure coding differs");
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:merged requiringSecureCoding:YES error:NULL];
        id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[merged class] fromData:data error:NULL];
        revenant_check([values_of(decoded) isEqualToString:values_of(merged)], "coding round trip", [NSString stringWithFormat:@"%@ != %@", values_of(decoded), values_of(merged)]);
        revenant_check([archive_keys(merged) isEqual:archive_keys(systemMerged)], "archive keys", [NSString stringWithFormat:@"%@ != %@", archive_keys(merged), archive_keys(systemMerged)]);

        struct { UIUserInterfaceIdiom screen; UIUserInterfaceIdiom device; CGFloat scale; CGFloat width; CGFloat height; const char *expected; } rules[] = {
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 320, 480, "idiom 0 scale 2 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 320, 568, "idiom 0 scale 2 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 480, 320, "idiom 0 scale 2 horizontal 1 vertical 1"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 1, 568, 320, "idiom 0 scale 1 horizontal 1 vertical 1"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 320, 479, "idiom 0 scale 2 horizontal 1 vertical 1"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 667, 375, "idiom 0 scale 2 horizontal 1 vertical 1"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 2, 668, 375, "idiom 0 scale 2 horizontal 2 vertical 1"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 3, 414, 736, "idiom 0 scale 3 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPhone, 3, 736, 414, "idiom 0 scale 3 horizontal 2 vertical 1"},
            {UIUserInterfaceIdiomPad, UIUserInterfaceIdiomPad, 2, 768, 1024, "idiom 1 scale 2 horizontal 2 vertical 2"},
            {UIUserInterfaceIdiomPad, UIUserInterfaceIdiomPad, 1, 1024, 768, "idiom 1 scale 1 horizontal 2 vertical 2"},
            {UIUserInterfaceIdiomPad, UIUserInterfaceIdiomPad, 1, 320, 320, "idiom 1 scale 1 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomUnspecified, UIUserInterfaceIdiomPhone, 1, 1024, 768, "idiom -1 scale 1 horizontal 2 vertical 2"},
            {UIUserInterfaceIdiomUnspecified, UIUserInterfaceIdiomPhone, 1, 640, 480, "idiom -1 scale 1 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomUnspecified, UIUserInterfaceIdiomPad, 1, 640, 480, "idiom -1 scale 1 horizontal 1 vertical 2"},
            {UIUserInterfaceIdiomUnspecified, UIUserInterfaceIdiomPad, 1, 1280, 720, "idiom -1 scale 1 horizontal 2 vertical 2"},
            {UIUserInterfaceIdiomPhone, (UIUserInterfaceIdiom)2, 2, 1920, 1080, "idiom 0 scale 2 horizontal 0 vertical 0"},
        };
        for (NSUInteger index = 0; index < sizeof(rules) / sizeof(*rules); index++) {
            id collection = [RevenantHostUITraitCollection revenant_traitCollectionWithScreenIdiom:rules[index].screen deviceIdiom:rules[index].device scale:rules[index].scale bounds:CGSizeMake(rules[index].width, rules[index].height)];
            NSString *expected = [NSString stringWithUTF8String:rules[index].expected];
            revenant_check([values_of(collection) isEqualToString:expected], NAMED(@"iOS 8 rule %lu", (unsigned long)index), [NSString stringWithFormat:@"%@ != %@", values_of(collection), expected]);
        }
        id foreign[] = {[NSNull null], @"traits", @1, [NSObject new]};
        NSMutableArray *oursRaised = [NSMutableArray array];
        for (int index = 0; index < 4; index++) {
            @try {
                [RevenantHostUITraitCollection traitCollectionWithTraitsFromCollections:@[[ourParts objectAtIndex:1], foreign[index]]];
                [oursRaised addObject:@"no exception"];
            } @catch (NSException *exception) {
                [oursRaised addObject:[NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];
            }
        }
        NSString *systemRaised = @"no exception";
        @try {
            [UITraitCollection traitCollectionWithTraitsFromCollections:@[[systemParts objectAtIndex:1], foreign[0]]];
        } @catch (NSException *exception) {
            systemRaised = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        }
        for (int index = 0; index < 4; index++)
            revenant_check([[oursRaised objectAtIndex:index] isEqualToString:systemRaised], NAMED(@"merge with a foreign object %d raises as the system does", index), [NSString stringWithFormat:@"%@ != %@", [oursRaised objectAtIndex:index], systemRaised]);
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}
