#pragma once
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

static NSString *normalised(id object);
static BOOL reordering_allowed = YES;

static Class named(int side, NSString *name)
{
    return side ? NSClassFromString([@"CharonHost" stringByAppendingString:name]) : NSClassFromString(name);
}

static uint64_t rng = 0x2545F4914F6CDD1DULL;
static uint32_t next_random(void)
{
    rng = rng * 6364136223846793005ULL + 1442695040888963407ULL;
    return (uint32_t)(rng >> 33);
}
static NSInteger pick(NSInteger count) { return next_random() % count; }
static BOOL chance(int percent) { return (int)(next_random() % 100) < percent; }

static NSString *rgb(UIColor *color)
{
    if (!color)
        return @"nil";
    UITraitCollection *light = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
    UIColor *resolved = [color resolvedColorWithTraitCollection:light];
    CGFloat c[4] = {0, 0, 0, 0};
    [resolved getRed:&c[0] green:&c[1] blue:&c[2] alpha:&c[3]];
    return [NSString stringWithFormat:@"(%.4f,%.4f,%.4f,%.4f)", c[0], c[1], c[2], c[3]];
}

static NSString *transformer_text(UIConfigurationColorTransformer transformer)
{
    if (!transformer)
        return @"none";
    return [NSString stringWithFormat:@"%@|%@|%@", rgb(transformer(UIColor.redColor)), rgb(transformer(UIColor.whiteColor)), rgb(transformer(nil))];
}

static NSString *font_text(UIFont *font)
{
    return font ? [NSString stringWithFormat:@"%@/%.2f", font.fontName, font.pointSize] : @"nil";
}

static NSString *attributed_text(NSAttributedString *text)
{
    return text ? [NSString stringWithFormat:@"A%@", text] : @"nil";
}

static NSString *dump_text_properties(id t)
{
    UIListContentTextProperties *p = t;
    return [NSString stringWithFormat:@"font=%@ color=%@ res=%@ ct=%@ al=%ld lb=%ld n=%ld fit=%d min=%.3f tight=%d adj=%d tr=%ld", font_text(p.font), rgb(p.color), rgb([p resolvedColor]), transformer_text(p.colorTransformer),
            (long)p.alignment, (long)p.lineBreakMode, (long)p.numberOfLines, p.adjustsFontSizeToFitWidth, p.minimumScaleFactor, p.allowsDefaultTighteningForTruncation, p.adjustsFontForContentSizeCategory, (long)p.transform];
}

static NSString *dump_image_properties(id t)
{
    UIListContentImageProperties *p = t;
    return [NSString stringWithFormat:@"tint=%@ res=%@ tt=%@ corner=%.2f max=%@ reserved=%@ inv=%d sym=%@", rgb(p.tintColor), rgb([p resolvedTintColorForTintColor:UIColor.greenColor]), transformer_text(p.tintColorTransformer), p.cornerRadius,
            NSStringFromCGSize(p.maximumSize), NSStringFromCGSize(p.reservedLayoutSize), p.accessibilityIgnoresInvertColors, p.preferredSymbolConfiguration];
}

static NSString *dump_config(id c)
{
    UIListContentConfiguration *k = c;
    return [NSString stringWithFormat:@"image=%@ text=%@ attr=%@ sec=%@ secattr=%@ axes=%ld margins=%@ side=%d i2t=%.2f h=%.2f v=%.2f\n  T[%@]\n  S[%@]\n  I[%@]", k.image ? @"img" : @"nil", k.text, attributed_text(k.attributedText), k.secondaryText,
            attributed_text(k.secondaryAttributedText), (long)k.axesPreservingSuperviewLayoutMargins, NSStringFromDirectionalEdgeInsets(k.directionalLayoutMargins), k.prefersSideBySideTextAndSecondaryText, k.imageToTextPadding,
            k.textToSecondaryTextHorizontalPadding, k.textToSecondaryTextVerticalPadding, dump_text_properties(k.textProperties), dump_text_properties(k.secondaryTextProperties), dump_image_properties(k.imageProperties)];
}

static NSString *effect_text(UIVisualEffect *effect)
{
    return effect ? normalised(effect) : @"nil";
}

static NSString *dump_background(id c)
{
    UIBackgroundConfiguration *b = c;
    return [NSString stringWithFormat:@"cv=%d cr=%.2f ins=%@ edges=%lu color=%@ ct=%@ res=%@ ve=%@ stroke=%@ st=%@ sres=%@ sw=%.2f so=%.2f", b.customView != nil, b.cornerRadius, NSStringFromDirectionalEdgeInsets(b.backgroundInsets),
            (unsigned long)b.edgesAddingLayoutMarginsToBackgroundInsets, rgb(b.backgroundColor), transformer_text(b.backgroundColorTransformer), rgb([b resolvedBackgroundColorForTintColor:UIColor.greenColor]), effect_text(b.visualEffect),
            rgb(b.strokeColor), transformer_text(b.strokeColorTransformer), rgb([b resolvedStrokeColorForTintColor:UIColor.greenColor]), b.strokeWidth, b.strokeOutset];
}

static NSString *normalised(id object)
{
    NSString *(^mask)(NSString *) = ^NSString *(NSString *in) {
        NSMutableString *out = [in mutableCopy];
        NSRegularExpression *color = [NSRegularExpression regularExpressionWithPattern:@"(backgroundColor|strokeColor|tintColor|color) = (<system color>|UIExtended[A-Za-z]+ [0-9. ]+|<UIDynamicProviderColor: 0x; provider = <[^>]*>>)" options:0 error:NULL];
        [color replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:@"$1 = <color>"];
        return out;
    };
    NSMutableString *text = [([object description] ?: @"nil") mutableCopy];
    [text replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+|fobj=0x[0-9a-f]+, spc=[0-9.]+" options:0 error:NULL];
    [pointer replaceMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
    NSRegularExpression *named = [NSRegularExpression regularExpressionWithPattern:@"<UI(Dynamic|Mac)(System|Catalog)?Color: 0x; name = [A-Za-z0-9_]+>" options:0 error:NULL];
    [named replaceMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"<system color>"];
    return mask(text);
}

static void same(NSString *name, NSString *system, NSString *port)
{
    if ([system isEqual:port])
        charon_check(YES, name.UTF8String, nil);
    else
        charon_check(NO, name.UTF8String, [NSString stringWithFormat:@"\n  system %@\n  port   %@", system, port]);
}

static UIImage *square(CGFloat side)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 1);
    [UIColor.redColor setFill];
    UIRectFill(CGRectMake(0, 0, side, side));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *images[3];
static NSArray *strings;
static NSString *S(void)
{
    id s = strings[pick(strings.count)];
    return s == (id)[NSNull null] ? nil : s;
}
static NSArray *colors;
static NSArray *fonts;

typedef void (^Op)(id object, int side);

static NSArray *text_property_ops(id (^get)(id))
{
    NSMutableArray *ops = [NSMutableArray array];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.font = fonts[pick(fonts.count)]; }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.color = colors[pick(colors.count)]; }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.colorTransformer = chance(70) ? ^UIColor *(UIColor *c) { return [c colorWithAlphaComponent:0.5]; } : nil; }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.alignment = (UIListContentTextAlignment)pick(3); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.lineBreakMode = (NSLineBreakMode)pick(6); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.numberOfLines = pick(4); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.adjustsFontSizeToFitWidth = chance(50); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.minimumScaleFactor = pick(3) * 0.25; }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.allowsDefaultTighteningForTruncation = chance(50); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.adjustsFontForContentSizeCategory = chance(50); }];
    [ops addObject:^(id o, int s) { UIListContentTextProperties *p = get(o); p.transform = (UIListContentTextTransform)pick(4); }];
    return ops;
}

static NSArray *config_ops(void)
{
    NSMutableArray *ops = [NSMutableArray array];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).text = S(); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).secondaryText = S(); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).attributedText = chance(70) ? [[NSAttributedString alloc] initWithString:S() ?: @"" attributes:@{NSForegroundColorAttributeName: UIColor.redColor}] : nil; }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).secondaryAttributedText = chance(70) ? [[NSAttributedString alloc] initWithString:S() ?: @"" attributes:nil] : nil; }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).image = chance(80) ? images[pick(3)] : nil; }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).axesPreservingSuperviewLayoutMargins = (UIAxis)pick(4); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).directionalLayoutMargins = NSDirectionalEdgeInsetsMake(pick(20), pick(20), pick(20), pick(20)); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).prefersSideBySideTextAndSecondaryText = chance(50); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageToTextPadding = pick(20); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).textToSecondaryTextHorizontalPadding = pick(20); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).textToSecondaryTextVerticalPadding = pick(20); }];
    for (Op op in text_property_ops(^id(id o) { return ((UIListContentConfiguration *)o).textProperties; }))
        [ops addObject:op];
    for (Op op in text_property_ops(^id(id o) { return ((UIListContentConfiguration *)o).secondaryTextProperties; }))
        [ops addObject:op];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.tintColor = chance(70) ? colors[pick(colors.count)] : nil; }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.tintColorTransformer = chance(70) ? ^UIColor *(UIColor *c) { return [c colorWithAlphaComponent:0.25]; } : nil; }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.cornerRadius = pick(9); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.maximumSize = CGSizeMake(pick(3) * 20, pick(3) * 20); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.reservedLayoutSize = CGSizeMake(pick(3) * 20, pick(3) * 20); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.accessibilityIgnoresInvertColors = chance(50); }];
    [ops addObject:^(id o, int s) { ((UIListContentConfiguration *)o).imageProperties.preferredSymbolConfiguration = chance(70) ? [UIImageSymbolConfiguration configurationWithPointSize:10 + pick(20)] : nil; }];
    return ops;
}

static NSArray *background_ops(void)
{
    NSMutableArray *ops = [NSMutableArray array];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).customView = chance(70) ? [[UIView alloc] init] : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).cornerRadius = pick(10); }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).backgroundInsets = NSDirectionalEdgeInsetsMake(pick(6), pick(6), pick(6), pick(6)); }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).edgesAddingLayoutMarginsToBackgroundInsets = (NSDirectionalRectEdge)pick(16); }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).backgroundColor = chance(70) ? colors[pick(colors.count)] : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).backgroundColorTransformer = chance(70) ? ^UIColor *(UIColor *c) { return [c colorWithAlphaComponent:0.5]; } : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).visualEffect = chance(70) ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).strokeColor = chance(70) ? colors[pick(colors.count)] : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).strokeColorTransformer = chance(70) ? ^UIColor *(UIColor *c) { return [c colorWithAlphaComponent:0.75]; } : nil; }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).strokeWidth = pick(4); }];
    [ops addObject:^(id o, int s) { ((UIBackgroundConfiguration *)o).strokeOutset = pick(4); }];
    return ops;
}

