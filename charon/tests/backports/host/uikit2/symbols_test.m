#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "symbols_record.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"

@interface CharonHostUIImageConfiguration : NSObject <NSCopying, NSSecureCoding>
- (UITraitCollection *)traitCollection;
- (instancetype)configurationWithTraitCollection:(UITraitCollection *)traitCollection;
- (instancetype)configurationByApplyingConfiguration:(id)configuration;
@end

@interface CharonHostUIImageSymbolConfiguration : CharonHostUIImageConfiguration
+ (instancetype)unspecifiedConfiguration;
+ (instancetype)configurationWithScale:(UIImageSymbolScale)scale;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize;
+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)weight;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight scale:(UIImageSymbolScale)scale;
+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle;
+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle scale:(UIImageSymbolScale)scale;
+ (instancetype)configurationWithFont:(UIFont *)font;
+ (instancetype)configurationWithFont:(UIFont *)font scale:(UIImageSymbolScale)scale;
- (instancetype)configurationWithoutTextStyle;
- (instancetype)configurationWithoutScale;
- (instancetype)configurationWithoutWeight;
- (instancetype)configurationWithoutPointSizeAndWeight;
- (BOOL)isEqualToConfiguration:(id)otherConfiguration;
@end

UIImageSymbolWeight CharonHostUIImageSymbolWeightForFontWeight(UIFontWeight fontWeight);
UIFontWeight CharonHostUIFontWeightForImageSymbolWeight(UIImageSymbolWeight symbolWeight);

@interface UIImage (CharonHostSymbols)
+ (UIImage *)charonHostSystemImageNamed:(NSString *)name;
+ (UIImage *)charonHostSystemImageNamed:(NSString *)name compatibleWithTraitCollection:(UITraitCollection *)traitCollection;
+ (UIImage *)charonHostSystemImageNamed:(NSString *)name withConfiguration:(id)configuration;
- (BOOL)charonHostIsSymbolImage;
- (id)charonHostSymbolConfiguration;
- (UIImage *)charonHostImageByApplyingSymbolConfiguration:(id)configuration;
- (BOOL)charonHostHasBaseline;
- (CGFloat)charonHostBaselineOffsetFromBottom;
@end

@interface UIImageView (CharonHostSymbols)
- (id)charonHostPreferredSymbolConfiguration;
- (void)charonHostSetPreferredSymbolConfiguration:(id)configuration;
@end

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static NSString *without_traits(id object)
{
    NSString *text = norm(object);
    NSRegularExpression *traits = [NSRegularExpression regularExpressionWithPattern:@"(, )?traits=\\(.*\\)$" options:0 error:nil];
    text = [traits stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    return text.length ? text : @"unspecified";
}

static NSString *raised_name(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
}

static void agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static id fresh(Class cls)
{
    return [[cls alloc] performSelector:NSSelectorFromString(@"init")];
}

static NSArray *text_styles(void)
{
    return @[UIFontTextStyleLargeTitle, UIFontTextStyleTitle1, UIFontTextStyleTitle2, UIFontTextStyleTitle3, UIFontTextStyleHeadline, UIFontTextStyleBody,
             UIFontTextStyleCallout, UIFontTextStyleSubheadline, UIFontTextStyleFootnote, UIFontTextStyleCaption1, UIFontTextStyleCaption2];
}

static NSArray *trait_collections(void)
{
    return @[[UITraitCollection traitCollectionWithDisplayScale:2], [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark],
             [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPhone],
             [UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassCompact],
             [UITraitCollection traitCollectionWithTraitsFromCollections:@[]],
             [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithDisplayScale:3], [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]]]];
}

static NSArray *sample_configurations(Class cls, Class base)
{
    NSArray *traits = trait_collections();
    id plain = fresh(base);
    return @[[cls unspecifiedConfiguration], [cls configurationWithPointSize:10], [cls configurationWithWeight:UIImageSymbolWeightLight], [cls configurationWithScale:UIImageSymbolScaleLarge],
             [cls configurationWithTextStyle:UIFontTextStyleTitle2], [cls configurationWithPointSize:30 weight:UIImageSymbolWeightThin],
             [cls configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleSmall], [cls configurationWithPointSize:20 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleLarge],
             [[cls configurationWithPointSize:10] configurationWithTraitCollection:traits[0]], [[cls configurationWithWeight:UIImageSymbolWeightLight] configurationWithTraitCollection:traits[1]],
             [plain configurationWithTraitCollection:traits[1]], [cls configurationWithFont:nil], plain, [[cls configurationWithTextStyle:UIFontTextStyleBody] configurationWithTraitCollection:traits[0]],
             [cls configurationWithScale:UIImageSymbolScaleDefault], [cls configurationWithPointSize:10], [cls configurationWithPointSize:10 weight:UIImageSymbolWeightLight]];
}

static NSArray *factory_lines(Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:norm([cls unspecifiedConfiguration])];
    [lines addObject:[NSString stringWithFormat:@"singleton %d", [cls unspecifiedConfiguration] == [cls unspecifiedConfiguration]]];
    [lines addObject:[NSString stringWithFormat:@"init %@ %@", norm(fresh(cls)), norm(raised_name(^{ return [cls performSelector:NSSelectorFromString(@"new")]; }))]];
    for (NSNumber *size in @[@-0.0, @0, @0.001, @0.5, @1, @16.99, @17, @1e10, @-1e10, @-5, @(NAN), @(INFINITY)])
        [lines addObject:[NSString stringWithFormat:@"point size %@ %@ %@", size, norm([cls configurationWithPointSize:size.doubleValue]), norm([cls configurationWithPointSize:size.doubleValue weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleSmall])]];
    for (NSInteger weight = -1; weight <= 12; weight++)
        [lines addObject:[NSString stringWithFormat:@"weight %ld %@ %@", (long)weight, norm([cls configurationWithWeight:(UIImageSymbolWeight)weight]), norm([cls configurationWithPointSize:8 weight:(UIImageSymbolWeight)weight])]];
    for (NSInteger scale = -3; scale <= 5; scale++)
        [lines addObject:[NSString stringWithFormat:@"scale %ld %@ %@", (long)scale, norm([cls configurationWithScale:(UIImageSymbolScale)scale]), norm([cls configurationWithPointSize:8 weight:UIImageSymbolWeightBold scale:(UIImageSymbolScale)scale])]];
    for (NSString *style in text_styles())
        [lines addObject:[NSString stringWithFormat:@"style %@ %@ %@", style, norm([cls configurationWithTextStyle:style]), norm([cls configurationWithTextStyle:style scale:UIImageSymbolScaleMedium])]];
    [lines addObject:[NSString stringWithFormat:@"style odd %@ %@ %@ %@", norm([cls configurationWithTextStyle:nil]), norm([cls configurationWithTextStyle:nil scale:UIImageSymbolScaleLarge]),
                                                norm([cls configurationWithTextStyle:@""]), norm([cls configurationWithTextStyle:@"bogus"])]];
    NSMutableString *pending = [NSMutableString stringWithString:@"UICTFontTextStyleBody"];
    id held = [cls configurationWithTextStyle:pending];
    [pending appendString:@"x"];
    [lines addObject:[NSString stringWithFormat:@"style copied %@", norm(held)]];
    NSMutableArray *fonts = [NSMutableArray arrayWithObjects:[UIFont systemFontOfSize:17], [UIFont boldSystemFontOfSize:17], [UIFont italicSystemFontOfSize:17],
                             [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy], [UIFont systemFontOfSize:14 weight:UIFontWeightUltraLight], [UIFont systemFontOfSize:14 weight:UIFontWeightMedium],
                             [UIFont systemFontOfSize:0], [UIFont systemFontOfSize:0.5], [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightBlack], nil];
    for (NSString *name in @[@"Helvetica", @"Helvetica-Bold", @"HelveticaNeue-Light", @"HelveticaNeue-UltraLight", @"HelveticaNeue-Thin", @"HelveticaNeue-Medium", @"HelveticaNeue-Bold",
                             @"Courier-Bold", @"Georgia-Bold", @"Avenir-Black", @"Avenir-Heavy", @"Avenir-Light", @"Zapfino", @"Futura-Medium", @"Optima-ExtraBlack"]) {
        UIFont *font = [UIFont fontWithName:name size:12];
        if (font)
            [fonts addObject:font];
    }
    for (UIFont *font in fonts)
        [lines addObject:[NSString stringWithFormat:@"font %@ %@ %@", font.fontName, norm([cls configurationWithFont:font]), norm([cls configurationWithFont:font scale:UIImageSymbolScaleLarge])]];
    [lines addObject:[NSString stringWithFormat:@"font nil %@ %@", norm([cls configurationWithFont:nil]), norm([cls configurationWithFont:nil scale:UIImageSymbolScaleLarge])]];
    return lines;
}

static NSArray *without_lines(Class cls, Class base)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *traits = trait_collections();
    NSMutableArray *configs = [NSMutableArray arrayWithArray:sample_configurations(cls, base)];
    for (NSString *style in text_styles()) {
        [configs addObject:[cls configurationWithTextStyle:style scale:UIImageSymbolScaleMedium]];
        [configs addObject:[[cls configurationWithTextStyle:style] configurationWithTraitCollection:traits[0]]];
    }
    [configs addObject:[cls configurationWithTextStyle:@"bogus"]];
    [configs addObject:[[cls configurationWithTextStyle:@"bogus"] configurationWithTraitCollection:traits[0]]];
    [configs addObject:[[cls configurationWithPointSize:4 weight:UIImageSymbolWeightLight] configurationWithTraitCollection:traits[0]]];
    for (NSString *category in @[UIContentSizeCategoryExtraSmall, UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge, UIContentSizeCategoryUnspecified])
        [configs addObject:[[cls configurationWithTextStyle:UIFontTextStyleBody] configurationWithTraitCollection:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:category]]];
    for (id config in configs) {
        if (![config respondsToSelector:@selector(configurationWithoutTextStyle)])
            continue;
        NSMutableString *line = [NSMutableString stringWithFormat:@"%@ =>", norm(config)];
        for (NSString *name in @[@"configurationWithoutTextStyle", @"configurationWithoutScale", @"configurationWithoutWeight", @"configurationWithoutPointSizeAndWeight"]) {
            id result = [config performSelector:NSSelectorFromString(name)];
            [line appendFormat:@" [%@ %d]", norm(result), result == config];
        }
        [lines addObject:line];
    }
    return lines;
}

static NSArray *apply_lines(Class cls, Class base)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *configs = sample_configurations(cls, base);
    for (NSUInteger i = 0; i < configs.count; i++) {
        [lines addObject:[NSString stringWithFormat:@"%lu nil %@ %d", (unsigned long)i, norm([configs[i] configurationByApplyingConfiguration:nil]),
                          [configs[i] configurationByApplyingConfiguration:nil] == configs[i]]];
        for (NSUInteger j = 0; j < configs.count; j++) {
            id result = [configs[i] configurationByApplyingConfiguration:configs[j]];
            [lines addObject:[NSString stringWithFormat:@"%lu+%lu %@ %@ %d %d %@", (unsigned long)i, (unsigned long)j, norm(result), norm([result class]), result == configs[i], result == configs[j],
                              norm([result traitCollection])]];
        }
    }
    [lines addObject:raised_name(^{ return [configs[1] configurationByApplyingConfiguration:@"x"]; })];
    return lines;
}

static NSArray *traits_lines(Class cls, Class base)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *configs = sample_configurations(cls, base);
    NSMutableArray *collections = [NSMutableArray arrayWithArray:trait_collections()];
    [collections insertObject:[NSNull null] atIndex:0];
    for (NSUInteger i = 0; i < configs.count; i++) {
        [lines addObject:[NSString stringWithFormat:@"%lu traitCollection %@", (unsigned long)i, norm([configs[i] traitCollection])]];
        for (id collection in collections) {
            id argument = collection == [NSNull null] ? nil : collection;
            id result = [configs[i] configurationWithTraitCollection:argument];
            [lines addObject:[NSString stringWithFormat:@"%lu with %@ => %@ %@ %d %@", (unsigned long)i, norm(argument), norm(result), norm([result class]), result == configs[i], norm([result traitCollection])]];
        }
    }
    [lines addObject:raised_name(^{ return [configs[1] configurationWithTraitCollection:(id)@"x"]; })];
    return lines;
}

static NSArray *equality_lines(Class cls, Class base)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *configs = sample_configurations(cls, base);
    NSMutableArray *more = [NSMutableArray arrayWithArray:configs];
    [more addObjectsFromArray:@[[cls configurationWithPointSize:10], [cls configurationWithWeight:UIImageSymbolWeightLight], [cls configurationWithWeight:0], [cls configurationWithScale:0],
                                [cls configurationWithPointSize:10 weight:UIImageSymbolWeightRegular], [cls configurationWithTextStyle:UIFontTextStyleBody], [cls configurationWithPointSize:17],
                                [[cls configurationWithPointSize:10] configurationWithTraitCollection:trait_collections()[0]],
                                [[cls configurationWithPointSize:10] configurationWithTraitCollection:[UITraitCollection traitCollectionWithDisplayScale:2]],
                                [[cls configurationWithPointSize:10] configurationWithTraitCollection:trait_collections()[4]]]];
    for (NSUInteger i = 0; i < more.count; i++) {
        id a = more[i];
        [lines addObject:[NSString stringWithFormat:@"%lu self %d %d %d %d %d", (unsigned long)i, [a isEqual:a], [a isEqual:nil], [a isEqual:@"x"], [a isEqual:[a copy]], [a copy] != a]];
        [lines addObject:[NSString stringWithFormat:@"%lu hash %lu %lu", (unsigned long)i, (unsigned long)[a hash], (unsigned long)[[a copy] hash]]];
        if ([a respondsToSelector:@selector(isEqualToConfiguration:)])
            [lines addObject:[NSString stringWithFormat:@"%lu nil %d", (unsigned long)i, [a isEqualToConfiguration:nil]]];
        for (NSUInteger j = 0; j < more.count; j++) {
            id b = more[j];
            BOOL equal = [a isEqual:b];
            NSString *typed = [a respondsToSelector:@selector(isEqualToConfiguration:)] ? [NSString stringWithFormat:@"%d", [a isEqualToConfiguration:b]] : @"-";
            [lines addObject:[NSString stringWithFormat:@"%lu %lu %d %@ %d", (unsigned long)i, (unsigned long)j, equal, typed, equal ? [a hash] == [b hash] : 1]];
        }
    }
    [lines addObject:[NSString stringWithFormat:@"protocols %d %d %d %d", [cls conformsToProtocol:@protocol(NSCopying)], [cls conformsToProtocol:@protocol(NSSecureCoding)],
                                                [cls supportsSecureCoding], [base supportsSecureCoding]]];
    [lines addObject:[NSString stringWithFormat:@"superclass %@ %@", norm(class_getSuperclass(cls)), norm(class_getSuperclass(base))]];
    id copy = [more[1] copyWithZone:nil];
    [lines addObject:[NSString stringWithFormat:@"copy class %@ %d", norm([copy class]), copy != more[1]]];
    return lines;
}

static NSData *archive_of(id object)
{
    return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:nil];
}

static id unarchive_as(NSData *data, Class cls)
{
    NSError *error = nil;
    id object = [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error];
    return object ?: [NSString stringWithFormat:@"failed %d", (int)error.code];
}

static NSArray *coding_lines(Class cls, Class base)
{
    NSMutableArray *lines = [NSMutableArray array];
    NSArray *configs = sample_configurations(cls, base);
    for (NSUInteger i = 0; i < configs.count; i++) {
        NSData *data = archive_of(configs[i]);
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil];
        NSMutableString *keys = [NSMutableString string];
        for (id entry in plist[@"$objects"]) {
            if ([entry isKindOfClass:[NSDictionary class]])
                [keys appendFormat:@"%@ | ", norm([[[entry allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","])];
            else
                [keys appendFormat:@"%@ | ", norm(entry)];
        }
        [lines addObject:[NSString stringWithFormat:@"%lu archive %@", (unsigned long)i, keys]];
        id back = unarchive_as(data, [configs[i] class]);
        [lines addObject:[NSString stringWithFormat:@"%lu back %@ %d", (unsigned long)i, norm(back), [back isEqual:configs[i]]]];
    }
    NSMutableDictionary *root = [[NSPropertyListSerialization propertyListWithData:archive_of([cls configurationWithPointSize:10]) options:NSPropertyListMutableContainers format:NULL error:nil] mutableCopy];
    NSMutableArray *objects = [root[@"$objects"] mutableCopy];
    NSMutableDictionary *entry = [objects[1] mutableCopy];
    id class_reference = entry[@"$class"];
    void (^decode)(NSString *) = ^(NSString *label) {
        objects[1] = entry;
        root[@"$objects"] = objects;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
        [lines addObject:[NSString stringWithFormat:@"decode %@ %@", label, norm(unarchive_as(data, cls))]];
    };
    for (NSNumber *size in @[@0, @-4, @0.25, @40])
        for (NSNumber *weight in @[@0, @4, @42, @-1])
            for (NSNumber *scale in @[@0, @2, @77, @-1]) {
                entry[@"UIPointSize"] = size;
                entry[@"UISymbolWeight"] = weight;
                entry[@"UISymbolScale"] = scale;
                decode([NSString stringWithFormat:@"%@ %@ %@", size, weight, scale]);
            }
    [entry removeAllObjects];
    entry[@"$class"] = class_reference;
    decode(@"empty");
    entry[@"UITextStyle"] = @1;
    decode(@"style of the wrong type");
    return lines;
}

static NSArray *weight_lines(NSInteger (*symbol_weight)(double), double (*font_weight)(NSInteger))
{
    NSMutableArray *lines = [NSMutableArray array];
    double thresholds[] = {-0.8f, -0.6f, -0.4f, 0, 0.23f, 0.3f, 0.4f, 0.56f, 0.62f};
    NSMutableString *sweep = [NSMutableString string];
    for (double weight = -1.2; weight <= 1.2; weight += 0.0005)
        [sweep appendFormat:@"%ld", (long)symbol_weight(weight)];
    [lines addObject:sweep];
    for (int index = 0; index < 9; index++) {
        double value = thresholds[index];
        [lines addObject:[NSString stringWithFormat:@"boundary %d %ld %ld %ld %ld %ld", index, (long)symbol_weight(nextafter(value, -INFINITY)), (long)symbol_weight(value),
                          (long)symbol_weight(nextafter(value, INFINITY)), (long)symbol_weight((double)(float)value), (long)symbol_weight(value == 0 ? -0.0 : (double)nextafterf((float)value, -INFINITY))]];
    }
    [lines addObject:[NSString stringWithFormat:@"limits %ld %ld %ld %ld %ld %ld", (long)symbol_weight(NAN), (long)symbol_weight(INFINITY), (long)symbol_weight(-INFINITY),
                      (long)symbol_weight(1e300), (long)symbol_weight(-1e300), (long)symbol_weight(-0.0)]];
    double named[] = {-0.4, 0.23, 0.3, 0.4, 0.56, 0.62, -0.8, -0.6};
    for (int index = 0; index < 8; index++)
        [lines addObject:[NSString stringWithFormat:@"double %g %ld", named[index], (long)symbol_weight(named[index])]];
    for (NSInteger weight = 0; weight <= 14; weight++)
        [lines addObject:[NSString stringWithFormat:@"table %ld %.17g", (long)weight, font_weight(weight)]];
    return lines;
}

static NSInteger port_symbol_weight(double weight)
{
    return CharonHostUIImageSymbolWeightForFontWeight(weight);
}

static double port_font_weight(NSInteger weight)
{
    return CharonHostUIFontWeightForImageSymbolWeight((UIImageSymbolWeight)weight);
}

static NSInteger system_symbol_weight(double weight)
{
    return UIImageSymbolWeightForFontWeight(weight);
}

static double system_font_weight(NSInteger weight)
{
    return UIFontWeightForImageSymbolWeight((UIImageSymbolWeight)weight);
}

static UIImage *bitmap(CGFloat scale)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 6), NO, scale);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static NSString *image_facts(UIImage *image)
{
    return [NSString stringWithFormat:@"size %@ scale %g orientation %ld caps %@ mode %ld rendering %ld align %@ frames %lu duration %g",
            NSStringFromCGSize(image.size), (double)image.scale, (long)image.imageOrientation, NSStringFromUIEdgeInsets(image.capInsets), (long)image.resizingMode,
            (long)image.renderingMode, NSStringFromUIEdgeInsets(image.alignmentRectInsets), (unsigned long)image.images.count, image.duration];
}

static NSArray *image_lines(BOOL port, Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIImage *plain = bitmap(1), *retina = bitmap(2), *empty = [[UIImage alloc] init];
    id (^symbol_configuration)(UIImage *) = ^id(UIImage *image) { return port ? [image charonHostSymbolConfiguration] : image.symbolConfiguration; };
    BOOL (^is_symbol)(UIImage *) = ^BOOL(UIImage *image) { return port ? [image charonHostIsSymbolImage] : image.symbolImage; };
    UIImage *(^apply)(UIImage *, id) = ^UIImage *(UIImage *image, id configuration) {
        return port ? [image charonHostImageByApplyingSymbolConfiguration:configuration] : [image imageByApplyingSymbolConfiguration:configuration];
    };
    for (UIImage *image in @[plain, retina, empty])
        [lines addObject:[NSString stringWithFormat:@"ordinary image %@ %d %@", norm(symbol_configuration(image)), is_symbol(image), image_facts(image)]];
    id a = [cls configurationWithPointSize:10], b = [cls configurationWithWeight:UIImageSymbolWeightLight], c = [cls configurationWithTextStyle:UIFontTextStyleTitle2 scale:UIImageSymbolScaleLarge];
    UITraitCollection *display = [UITraitCollection traitCollectionWithDisplayScale:3];
    id d = [[cls configurationWithScale:UIImageSymbolScaleSmall] configurationWithTraitCollection:display];
    for (UIImage *image in @[plain, retina, empty]) {
        for (id configuration in @[a, b, c, d, [cls unspecifiedConfiguration]]) {
            UIImage *result = apply(image, configuration);
            [lines addObject:[NSString stringWithFormat:@"apply %@ %@ | %d %d %d | %@ | %@", norm(configuration), without_traits(symbol_configuration(result)), result != image, is_symbol(result),
                              result.CGImage == image.CGImage, image_facts(result), norm([result class])]];
        }
        UIImage *none = apply(image, nil);
        [lines addObject:[NSString stringWithFormat:@"apply nil %@ %d %d | %@", norm(symbol_configuration(none)), none != image, none.CGImage == image.CGImage, image_facts(none)]];
        UIImage *twice = apply(apply(image, a), b);
        [lines addObject:[NSString stringWithFormat:@"apply twice %@ %d", without_traits(symbol_configuration(twice)), twice != image]];
        UIImage *again = apply(apply(image, a), nil);
        [lines addObject:[NSString stringWithFormat:@"apply then nil %@ %d", without_traits(symbol_configuration(again)), again == apply(image, a)]];
        UIImage *kept = apply(apply(image, a), a);
        [lines addObject:[NSString stringWithFormat:@"apply the same twice %@", without_traits(symbol_configuration(kept))]];
        UIImage *overridden = apply(apply(image, d), [cls configurationWithPointSize:5]);
        [lines addObject:[NSString stringWithFormat:@"apply over traits %@", without_traits(symbol_configuration(overridden))]];
    }
    UIImage *resized = [[[bitmap(2) resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1) resizingMode:UIImageResizingModeTile] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                        imageWithAlignmentRectInsets:UIEdgeInsetsMake(1, 0, 0, 0)];
    UIImage *resized_result = apply(resized, a);
    [lines addObject:[NSString stringWithFormat:@"kept layout %@ | %@", image_facts(resized), image_facts(resized_result)]];
    UIImage *animated = [UIImage animatedImageWithImages:@[plain, plain] duration:1.5];
    [lines addObject:[NSString stringWithFormat:@"animated %@ | %@", image_facts(animated), image_facts(apply(animated, a))]];
    UIImage *rotated = [UIImage imageWithCGImage:plain.CGImage scale:2 orientation:UIImageOrientationLeft];
    [lines addObject:[NSString stringWithFormat:@"orientation %@ | %@", image_facts(rotated), image_facts(apply(rotated, a))]];
    for (NSString *name in @[@"", @"nonexistent.symbol.zz", @"a.b.c", @"  "]) {
        NSMutableArray *answers = [NSMutableArray array];
        for (id answer in port ? @[[UIImage charonHostSystemImageNamed:name] ?: [NSNull null], [UIImage charonHostSystemImageNamed:name compatibleWithTraitCollection:display] ?: [NSNull null],
                                   [UIImage charonHostSystemImageNamed:name withConfiguration:a] ?: [NSNull null], [UIImage charonHostSystemImageNamed:name withConfiguration:nil] ?: [NSNull null]]
                               : @[[UIImage systemImageNamed:name] ?: [NSNull null], [UIImage systemImageNamed:name compatibleWithTraitCollection:display] ?: [NSNull null],
                                   [UIImage systemImageNamed:name withConfiguration:a] ?: [NSNull null], [UIImage systemImageNamed:name withConfiguration:nil] ?: [NSNull null]])
            [answers addObject:norm(answer)];
        [lines addObject:[NSString stringWithFormat:@"unknown name [%@] %@", name, answers]];
    }
    NSString *(^named_nil)(void) = ^NSString *{
        UIImage *one = port ? [UIImage charonHostSystemImageNamed:nil] : [UIImage systemImageNamed:nil];
        UIImage *two = port ? [UIImage charonHostSystemImageNamed:nil compatibleWithTraitCollection:nil] : [UIImage systemImageNamed:nil compatibleWithTraitCollection:nil];
        UIImage *three = port ? [UIImage charonHostSystemImageNamed:nil withConfiguration:nil] : [UIImage systemImageNamed:nil withConfiguration:nil];
        return [NSString stringWithFormat:@"%@ %@ %@", norm(one), norm(two), norm(three)];
    };
    [lines addObject:[NSString stringWithFormat:@"nil name %@", named_nil()]];
    return lines;
}

static NSArray *view_lines(BOOL port, Class cls)
{
    NSMutableArray *lines = [NSMutableArray array];
    id (^get)(UIImageView *) = ^id(UIImageView *view) { return port ? [view charonHostPreferredSymbolConfiguration] : view.preferredSymbolConfiguration; };
    void (^set)(UIImageView *, id) = ^(UIImageView *view, id configuration) {
        if (port)
            [view charonHostSetPreferredSymbolConfiguration:configuration];
        else
            view.preferredSymbolConfiguration = configuration;
    };
    UIImageView *view = [[UIImageView alloc] init];
    [lines addObject:[NSString stringWithFormat:@"default %@ %@", get(view), get([[UIImageView alloc] initWithImage:bitmap(1)])]];
    id a = [cls configurationWithPointSize:10], equal = [cls configurationWithPointSize:10], b = [cls configurationWithWeight:UIImageSymbolWeightBold];
    set(view, a);
    [lines addObject:[NSString stringWithFormat:@"set %d %@", get(view) == a, norm(get(view))]];
    set(view, equal);
    [lines addObject:[NSString stringWithFormat:@"set equal %d %d", get(view) == a, get(view) == equal]];
    set(view, b);
    [lines addObject:[NSString stringWithFormat:@"set other %d %@", get(view) == b, norm(get(view))]];
    view.image = bitmap(1);
    [lines addObject:[NSString stringWithFormat:@"image set %d", get(view) == b]];
    view.image = nil;
    [lines addObject:[NSString stringWithFormat:@"image nil %d", get(view) == b]];
    set(view, nil);
    [lines addObject:[NSString stringWithFormat:@"set nil %@", get(view)]];
    set(view, nil);
    [lines addObject:[NSString stringWithFormat:@"set nil twice %@", get(view)]];
    [lines addObject:raised_name(^{ set(view, @"x"); return get(view); })];
    UIImageView *other = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 4, 4)];
    set(other, a);
    [lines addObject:[NSString stringWithFormat:@"other view %d %d", get(other) == a, get(view) == a]];
    return lines;
}


static NSArray *lines_of(NSString *file)
{
    NSString *path = [[@__FILE__ stringByDeletingLastPathComponent] stringByAppendingPathComponent:file];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"])
        if (line.length)
            [lines addObject:line];
    return lines;
}

// How much of the union of two drawings is in both, the drawings placed in the middle of one canvas.
static double overlap(UIImage *port, UIImage *host)
{
    CGSize canvas = CGSizeMake(MAX(port.size.width, host.size.width), MAX(port.size.height, host.size.height));
    CGRect a = CGRectMake((canvas.width - port.size.width) / 2, (canvas.height - port.size.height) / 2, port.size.width, port.size.height);
    CGRect b = CGRectMake((canvas.width - host.size.width) / 2, (canvas.height - host.size.height) / 2, host.size.width, host.size.height);
    NSData *first = record_alpha(port, canvas, a, 4), *second = record_alpha(host, canvas, b, 4);
    const uint8_t *x = first.bytes, *y = second.bytes;
    long both = 0, either = 0;
    for (NSUInteger i = 0; i < first.length; i++) {
        BOOL p = x[i] > 127, h = y[i] > 127;
        both += p && h;
        either += p || h;
    }
    return either ? (double)both / either : 1;
}

static void symbol_checks(Class port)
{
    NSArray *names = lines_of(@"symbols-names.txt"), *absent = lines_of(@"symbols-absent.txt");
    static const double sizes[4] = {12, 17, 32, 64};
    static const double configs[8][3] = {{17, 4, 2}, {34, 7, 3}, {12, 1, 1}, {100, 9, 1}, {24, 2, 3}, {48, 6, 2}, {10, 5, 2}, {17, 4, 0}};
    NSMutableArray *missing = [NSMutableArray array], *notImages = [NSMutableArray array], *rendered = [NSMutableArray array];
    NSMutableArray *sizeMisses = [NSMutableArray array], *insetMisses = [NSMutableArray array], *baselineMisses = [NSMutableArray array];
    NSMutableArray *scores = [NSMutableArray array], *weak = [NSMutableArray array];
    double worstSize = 0, worstInset = 0, worstBaseline = 0;
    NSMutableString *tsv = [NSMutableString string];
    for (NSString *name in names) {
        UIImage *drawn = [UIImage charonHostSystemImageNamed:name];
        if (!drawn) {
            [missing addObject:name];
            continue;
        }
        if (!drawn.charonHostSymbolConfiguration || ![drawn charonHostIsSymbolImage] || drawn.renderingMode != UIImageRenderingModeAlwaysTemplate || ![drawn charonHostHasBaseline])
            [notImages addObject:name];
        for (int c = 0; c < 8; c++) {
            id configuration = [port configurationWithPointSize:configs[c][0] weight:(UIImageSymbolWeight)configs[c][1] scale:(UIImageSymbolScale)configs[c][2]];
            UIImage *ours = [UIImage charonHostSystemImageNamed:name withConfiguration:configuration];
            UIImage *host = [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:configs[c][0] weight:(UIImageSymbolWeight)configs[c][1] scale:(UIImageSymbolScale)configs[c][2]]];
            double size = MAX(fabs(ours.size.width - host.size.width), fabs(ours.size.height - host.size.height));
            UIEdgeInsets a = ours.alignmentRectInsets, b = host.alignmentRectInsets;
            double inset = MAX(MAX(fabs(a.top - b.top), fabs(a.left - b.left)), MAX(fabs(a.bottom - b.bottom), fabs(a.right - b.right)));
            double baseline = fabs([ours charonHostBaselineOffsetFromBottom] - host.baselineOffsetFromBottom);
            worstSize = MAX(worstSize, size); worstInset = MAX(worstInset, inset); worstBaseline = MAX(worstBaseline, baseline);
            NSString *at = [NSString stringWithFormat:@"%@ at %g/%g/%g", name, configs[c][0], configs[c][1], configs[c][2]];
            if (size > 1) [sizeMisses addObject:[NSString stringWithFormat:@"%@: %g", at, size]];
            if (inset > 1) [insetMisses addObject:[NSString stringWithFormat:@"%@: %g", at, inset]];
            if (baseline > 1) [baselineMisses addObject:[NSString stringWithFormat:@"%@: %g", at, baseline]];
        }
        double sum = 0;
        NSMutableString *row = [NSMutableString stringWithString:name];
        for (int k = 0; k < 4; k++) {
            UIImage *ours = [UIImage charonHostSystemImageNamed:name withConfiguration:[port configurationWithPointSize:sizes[k] weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium]];
            UIImage *host = [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:sizes[k] weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium]];
            double value = overlap(ours, host);
            sum += value;
            [row appendFormat:@"\t%.3f", value];
        }
        [tsv appendFormat:@"%@\t%.3f\n", row, sum / 4];
        [scores addObject:@(sum / 4)];
        if (sum / 4 < 0.3)
            [weak addObject:[NSString stringWithFormat:@"%@ %.2f", name, sum / 4]];
    }
    for (NSString *name in absent)
        if ([UIImage charonHostSystemImageNamed:name] || ![UIImage systemImageNamed:name])
            [rendered addObject:name];
    charon_check(names.count >= 500 && !missing.count, "every recorded symbol name is drawn", missing.description);
    charon_check(!absent.count || !rendered.count, "the names listed as not drawn are the host's and are answered nil", rendered.description);
    charon_check(!notImages.count, "a drawn symbol is a template symbol image with its configuration and a baseline", notImages.description);
    printf("info size: worst difference %g points over %lu names in 8 configurations, %lu beyond 1 point\n", worstSize, (unsigned long)names.count, (unsigned long)sizeMisses.count);
    printf("info alignment insets: worst difference %g points, %lu beyond 1 point; baseline: worst %g, %lu beyond 1 point\n", worstInset, (unsigned long)insetMisses.count, worstBaseline, (unsigned long)baselineMisses.count);
    charon_check(!sizeMisses.count, "the size of every symbol is the host's within a point", [sizeMisses.description substringToIndex:MIN(400, sizeMisses.description.length)]);
    charon_check(!insetMisses.count, "the alignment insets of every symbol are the host's within a point", [insetMisses.description substringToIndex:MIN(400, insetMisses.description.length)]);
    charon_check(!baselineMisses.count, "the baseline offset of every symbol is the host's within a point", [baselineMisses.description substringToIndex:MIN(400, baselineMisses.description.length)]);
    NSArray *sorted = [scores sortedArrayUsingSelector:@selector(compare:)];
    double minimum = sorted.count ? [sorted[0] doubleValue] : 0, median = sorted.count ? [sorted[sorted.count / 2] doubleValue] : 0;
    NSUInteger below = 0, belowHalf = 0;
    for (NSNumber *score in sorted) {
        below += score.doubleValue < 0.3;
        belowHalf += score.doubleValue < 0.5;
    }
    printf("info overlap with the host's drawing at 12, 17, 32 and 64 points (union over intersection, mean of the four): %lu symbols, minimum %.3f, median %.3f, %lu below 0.5, %lu below 0.3\n",
           (unsigned long)sorted.count, minimum, median, (unsigned long)belowHalf, (unsigned long)below);
    charon_check(minimum >= 0.10 && median >= 0.60, "the drawings overlap the host's at least 0.10 each and 0.60 at the median", [NSString stringWithFormat:@"%g %g", minimum, median]);
    const char *write = getenv("CHARON_WRITE_SYMBOLS");
    if (write) {
        NSString *dir = @(write);
        NSArray *recorded = record_names([[@__FILE__ stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"symbols-names.txt"]);
        [record_metrics_header(recorded) writeToFile:[dir stringByAppendingPathComponent:@"CharonSymbolMetrics.h"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [record_expectations_header(recorded) writeToFile:[dir stringByAppendingPathComponent:@"symbols-expectations.h"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [tsv writeToFile:[dir stringByAppendingPathComponent:@"symbols-overlap.tsv"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    UIImage *small = [UIImage charonHostSystemImageNamed:@"star" withConfiguration:[port configurationWithPointSize:12 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium]];
    UIImage *again = [small charonHostImageByApplyingSymbolConfiguration:[port configurationWithPointSize:48 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleMedium]];
    UIImage *host = [[UIImage systemImageNamed:@"star" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightRegular scale:UIImageSymbolScaleMedium]]
                        imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightBold scale:UIImageSymbolScaleMedium]];
    charon_check(fabs(again.size.width - host.size.width) <= 1 && fabs(again.size.height - host.size.height) <= 1 && [again charonHostIsSymbolImage],
                 "applying a configuration to a symbol image draws it again at the new size", NSStringFromCGSize(again.size));
    NSString *merged = norm([again charonHostSymbolConfiguration]);
    charon_check([without_traits([again charonHostSymbolConfiguration]) isEqualToString:@"pointSize=48, weight=Bold, scale=Medium"], "and holds the merged configuration", merged);
    charon_check([UIImage charonHostSystemImageNamed:@"nonexistent.symbol.zz"] == nil && [UIImage charonHostSystemImageNamed:@"star.fill.fill"] == nil && [UIImage charonHostSystemImageNamed:@""] == nil,
                 "a name that is not a symbol is nil", @"");
}

int main(void)
{
    @autoreleasepool {
        Class port = [CharonHostUIImageSymbolConfiguration class], portBase = [CharonHostUIImageConfiguration class];
        Class system = [UIImageSymbolConfiguration class], systemBase = [UIImageConfiguration class];

        agree(@"factories", factory_lines(port), factory_lines(system));
        agree(@"the without... methods", without_lines(port, portBase), without_lines(system, systemBase));
        agree(@"applying one configuration over another", apply_lines(port, portBase), apply_lines(system, systemBase));
        agree(@"trait collections", traits_lines(port, portBase), traits_lines(system, systemBase));
        agree(@"equality, hash and copies", equality_lines(port, portBase), equality_lines(system, systemBase));
        agree(@"secure coding", coding_lines(port, portBase), coding_lines(system, systemBase));
        agree(@"UIImageSymbolWeightForFontWeight and UIFontWeightForImageSymbolWeight", weight_lines(port_symbol_weight, port_font_weight), weight_lines(system_symbol_weight, system_font_weight));
        agree(@"UIImage symbol members on ordinary images", image_lines(YES, port), image_lines(NO, system));
        agree(@"UIImageView.preferredSymbolConfiguration", view_lines(YES, port), view_lines(NO, system));

        NSArray *selectors = @[@"configurationWithPaletteColors:", @"configurationWithHierarchicalColor:", @"configurationPreferringMulticolor", @"configurationWithColorRenderingMode:"];
        NSMutableArray *answers = [NSMutableArray array];
        for (NSString *name in selectors)
            [answers addObject:@([port respondsToSelector:NSSelectorFromString(name)])];
        charon_check([answers isEqual:@[@NO, @NO, @NO, @NO]], "members of later releases are not answered", answers.description);

        UIImage *ordinary = bitmap(1);
        charon_check([ordinary respondsToSelector:@selector(charonHostSymbolConfiguration)] && [UIImage respondsToSelector:@selector(charonHostSystemImageNamed:)],
                     "the port's UIImage members are there", @"");

        UITraitCollection *screen = [UIScreen mainScreen].traitCollection;
        id applied = [[ordinary charonHostImageByApplyingSymbolConfiguration:[port configurationWithPointSize:9]] charonHostSymbolConfiguration];
        charon_check([[applied traitCollection] isEqual:screen], "an ordinary image takes the traits of the main screen when a configuration is applied", norm([applied traitCollection]));
        id own = [[port configurationWithScale:UIImageSymbolScaleSmall] configurationWithTraitCollection:[UITraitCollection traitCollectionWithDisplayScale:5]];
        id merged = [[ordinary charonHostImageByApplyingSymbolConfiguration:own] charonHostSymbolConfiguration];
        UITraitCollection *expected = [UITraitCollection traitCollectionWithTraitsFromCollections:@[screen, [UITraitCollection traitCollectionWithDisplayScale:5]]];
        charon_check([[merged traitCollection] isEqual:expected], "the traits of the configuration win over the traits of the screen", norm([merged traitCollection]));

        UIFont *body = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        charon_check([norm([port configurationWithFont:body]) isEqualToString:@"pointSize=17, weight=Regular"],
                     "a font of a text style gives its size and weight, where the host keeps the text style", norm([port configurationWithFont:body]));
        for (NSInteger weight = -6; weight <= -1; weight++)
            charon_check(CharonHostUIFontWeightForImageSymbolWeight((UIImageSymbolWeight)weight) == 0, NAMED(@"symbol weight %ld out of range is Regular where the host reads beside its table", (long)weight), @"");

        symbol_checks(port);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
