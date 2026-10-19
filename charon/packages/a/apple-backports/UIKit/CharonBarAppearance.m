#import "CharonBarAppearance.h"
#import "../CharonSayOnce.h"
#import "../CharonSRGB.h"

NSDictionary *charon_attributes_merge(NSDictionary *base, NSDictionary *over)
{
    if (!over.count)
        return base ?: @{};
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:base ?: @{}];
    [merged addEntriesFromDictionary:over];
    return merged;
}

UIColor *charon_disabled_colour(UIColor *colour)
{
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (![colour getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat white = 0;
        if (![colour getWhite:&white alpha:&alpha])
            return colour;
        red = green = blue = white;
    }
    CGFloat linear[3] = {red, green, blue}, weights[3] = {0.2224, 0.7167, 0.0606}, luminance = 0;
    for (int index = 0; index < 3; index++) {
        CGFloat value = linear[index];
        luminance += weights[index] * charon_srgb_decode(value);
    }
    CGFloat grey = charon_srgb_encode(luminance);
    return [UIColor colorWithWhite:MIN(grey, 0.6) alpha:alpha * 0.45];
}

NSDictionary *charon_attributes_carried(NSDictionary *custom, BOOL colour, BOOL disabled)
{
    NSMutableDictionary *carried = [NSMutableDictionary dictionary];
    id font = custom[NSFontAttributeName], tint = custom[NSForegroundColorAttributeName];
    if (font)
        carried[NSFontAttributeName] = font;
    if (colour && tint)
        carried[NSForegroundColorAttributeName] = disabled ? charon_disabled_colour(tint) : tint;
    return carried;
}

NSString *charon_attributes_text(NSDictionary *custom)
{
    if (!custom.count)
        return @"default";
    NSMutableArray *items = [NSMutableArray array];
    [custom enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        [items addObject:[NSString stringWithFormat:@"(%@=%@)", key, value]];
    }];
    return [NSString stringWithFormat:@"{%@}", [items componentsJoinedByString:@", "]];
}

UIFont *charon_font(CGFloat size, CGFloat weight)
{
    return [UIFont systemFontOfSize:size weight:weight];
}

UIColor *charon_label_colour(void)
{
    return [UIColor colorWithWhite:0 alpha:0.847];
}

UIColor *charon_secondary_label_colour(void)
{
    return [UIColor colorWithWhite:0 alpha:0.498];
}

UIColor *charon_default_shadow_colour(void)
{
    return [UIColor colorWithWhite:0 alpha:0.3];
}

UIColor *charon_white_colour(void)
{
    return [UIColor colorWithWhite:1 alpha:1];
}

NSArray *charon_offset_pack(UIOffset offset)
{
    return @[@(offset.horizontal), @(offset.vertical)];
}

UIOffset charon_offset_unpack(NSArray *packed)
{
    return packed.count == 2 ? UIOffsetMake([packed[0] doubleValue], [packed[1] doubleValue]) : UIOffsetZero;
}

NSString *charon_offset_text(NSArray *packed)
{
    return NSStringFromUIOffset(charon_offset_unpack(packed));
}

BOOL charon_same(id first, id second)
{
    return first == second || (first && second && [first isEqual:second]);
}

NSString *charon_text(id object)
{
    return object ? [object description] : @"(null)";
}

static NSString *const CharonTag = @"\x01";

id charon_plist_pack(id object)
{
    if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSNumber class]] || [object isKindOfClass:[NSData class]])
        return object;
    if ([object isKindOfClass:[NSNull class]])
        return @{CharonTag: @"null"};
    if ([object isKindOfClass:[UIColor class]]) {
        CGFloat red = 0, green = 0, blue = 0, alpha = 0;
        if (CGColorSpaceGetModel(CGColorGetColorSpace([object CGColor])) == kCGColorSpaceModelMonochrome) {
            [object getWhite:&red alpha:&alpha];
            return @{CharonTag: @"colour", @"c": @[@(red), @(alpha)]};
        }
        [object getRed:&red green:&green blue:&blue alpha:&alpha];
        return @{CharonTag: @"colour", @"c": @[@(red), @(green), @(blue), @(alpha)]};
    }
    if ([object isKindOfClass:[UIFont class]])
        return @{CharonTag: @"font", @"n": [object fontName], @"s": @([object pointSize]), @"d": [NSKeyedArchiver archivedDataWithRootObject:object]};
    if ([object isKindOfClass:[UIImage class]]) {
        NSData *data = UIImagePNGRepresentation(object);
        return data ? @{CharonTag: @"image", @"d": data, @"s": @([(UIImage *)object scale])} : nil;
    }
    if ([object isKindOfClass:[UIBlurEffect class]])
        return @{CharonTag: @"effect", @"d": [NSKeyedArchiver archivedDataWithRootObject:object]};
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *packed = [NSMutableArray array];
        for (id item in object) {
            id one = charon_plist_pack(item);
            if (one)
                [packed addObject:one];
        }
        return packed;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *packed = [NSMutableDictionary dictionary];
        [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            id one = [key isKindOfClass:[NSString class]] ? charon_plist_pack(value) : nil;
            if (one)
                packed[key] = one;
        }];
        return packed;
    }
    return nil;
}

id charon_plist_unpack(id object)
{
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *unpacked = [NSMutableArray array];
        for (id item in object) {
            id one = charon_plist_unpack(item);
            if (one)
                [unpacked addObject:one];
        }
        return unpacked;
    }
    if (![object isKindOfClass:[NSDictionary class]])
        return object;
    NSString *kind = object[CharonTag];
    if ([kind isEqual:@"null"])
        return [NSNull null];
    if ([kind isEqual:@"colour"]) {
        NSArray *components = object[@"c"];
        if (components.count == 2)
            return [UIColor colorWithWhite:[components[0] doubleValue] alpha:[components[1] doubleValue]];
        return components.count == 4 ? [UIColor colorWithRed:[components[0] doubleValue] green:[components[1] doubleValue] blue:[components[2] doubleValue] alpha:[components[3] doubleValue]] : nil;
    }
    if ([kind isEqual:@"font"]) {
        UIFont *font = nil;
        @try {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:object[@"d"]];
            unarchiver.requiresSecureCoding = YES;
            font = [unarchiver decodeObjectOfClass:[UIFont class] forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
        } @catch (NSException *exception) {
        }
        return font ?: [UIFont fontWithName:object[@"n"] size:[object[@"s"] doubleValue]];
    }
    if ([kind isEqual:@"image"])
        return [UIImage imageWithData:object[@"d"] scale:[object[@"s"] doubleValue]];
    if ([kind isEqual:@"effect"]) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:object[@"d"]];
        unarchiver.requiresSecureCoding = YES;
        id effect = [unarchiver decodeObjectOfClass:[UIBlurEffect class] forKey:NSKeyedArchiveRootObjectKey];
        [unarchiver finishDecoding];
        return effect;
    }
    NSMutableDictionary *unpacked = [NSMutableDictionary dictionary];
    [object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        id one = charon_plist_unpack(value);
        if (one)
            unpacked[key] = one;
    }];
    return unpacked;
}

NSSet *charon_plist_classes(void)
{
    return [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class], [NSData class], nil];
}

void charon_bar_say_once(NSString *key, NSString *text)
{
    charon_say_once_for(key, text);
}

UIImage *charon_solid_image(UIColor *colour)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 1);
    [colour setFill];
    UIRectFill(CGRectMake(0, 0, 1, 1));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsZero];
}

NSMutableDictionary *charon_sanitised(id decoded, NSDictionary *classes, NSSet *nullable)
{
    NSMutableDictionary *clean = [NSMutableDictionary dictionary];
    if (![decoded isKindOfClass:[NSDictionary class]])
        return clean;
    [classes enumerateKeysAndObjectsUsingBlock:^(NSString *key, Class kind, BOOL *stop) {
        id value = decoded[key];
        if ([value isKindOfClass:[NSNull class]] && [nullable containsObject:key]) {
            clean[key] = value;
            return;
        }
        if (![value isKindOfClass:kind])
            return;
        if (kind == [NSArray class]) {
            NSArray *pair = value;
            if (pair.count != 2 || ![pair[0] isKindOfClass:[NSNumber class]] || ![pair[1] isKindOfClass:[NSNumber class]])
                return;
        }
        clean[key] = value;
    }];
    return clean;
}

void charon_adopt_child(UIBarAppearance *owner, id child)
{
    __weak UIBarAppearance *weak = owner;
    [child charon_setChangeObserver:^{
        [weak charon_notify];
    }];
}
