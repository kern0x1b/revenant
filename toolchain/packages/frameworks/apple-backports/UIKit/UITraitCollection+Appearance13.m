#import "RevenantTraitStyle.h"
#import "RevenantTraits17.h"
#import "RevenantSymbols.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSString *const RevenantContrast = @"AccessibilityContrast";
static NSString *const RevenantLevel = @"UserInterfaceLevel";
static NSString *const RevenantLegibility = @"LegibilityWeight";

static char revenant_extras_key;

static NSMutableArray *revenant_kinds(void)
{
    static NSMutableArray *kinds;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kinds = [[NSMutableArray alloc] init];
    });
    return kinds;
}

void revenant_register_trait_kind(RevenantTraitKind kind)
{
    NSMutableArray *kinds = revenant_kinds();
    @synchronized (kinds) {
        for (NSValue *held in kinds) {
            RevenantTraitKind other;
            [held getValue:&other];
            if ([other.name isEqualToString:kind.name])
                return;
        }
        [kinds addObject:[NSValue valueWithBytes:&kind objCType:@encode(RevenantTraitKind)]];
    }
}

static void revenant_each_kind(void (^visit)(RevenantTraitKind kind))
{
    NSMutableArray *kinds = revenant_kinds();
    NSArray *copy;
    @synchronized (kinds) {
        copy = [kinds copy];
    }
    for (NSValue *held in copy) {
        RevenantTraitKind kind;
        [held getValue:&kind];
        visit(kind);
    }
}

NSDictionary *revenant_trait_extras(UITraitCollection *collection)
{
    return objc_getAssociatedObject(collection, &revenant_extras_key);
}

NSInteger revenant_trait_extra(UITraitCollection *collection, NSString *name)
{
    id held = revenant_trait_extras(collection)[name];
    return [held isKindOfClass:[NSNumber class]] ? [held integerValue] : -1;
}

void revenant_set_trait_extra(UITraitCollection *collection, NSString *name, NSInteger value)
{
    revenant_set_trait_extra_object(collection, name, value == -1 ? nil : @(value));
}

id revenant_trait_extra_object(UITraitCollection *collection, NSString *name)
{
    return revenant_trait_extras(collection)[name];
}

void revenant_set_trait_extra_object(UITraitCollection *collection, NSString *name, id value)
{
    NSMutableDictionary *extras = [revenant_trait_extras(collection) mutableCopy] ?: [NSMutableDictionary dictionary];
    if (!value)
        [extras removeObjectForKey:name];
    else
        extras[name] = value;
    objc_setAssociatedObject(collection, &revenant_extras_key, extras.count ? extras : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NSDictionary *revenant_merge_trait_extras(NSArray *collections)
{
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    for (UITraitCollection *collection in collections)
        [merged addEntriesFromDictionary:revenant_trait_extras(collection) ?: @{}];
    return merged;
}

void revenant_apply_trait_extras(UITraitCollection *collection, NSDictionary *extras)
{
    objc_setAssociatedObject(collection, &revenant_extras_key, extras.count ? [extras copy] : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void revenant_apply_screen_trait_extras(UITraitCollection *collection)
{
    revenant_each_kind(^(RevenantTraitKind kind) {
        revenant_set_trait_extra(collection, kind.name, kind.screenDefault);
    });
}

BOOL revenant_trait_extras_contained(UITraitCollection *collection, UITraitCollection *wanted)
{
    for (NSString *name in revenant_trait_extras(wanted)) {
        if (revenant_trait_extra(wanted, name) != revenant_trait_extra(collection, name))
            return NO;
    }
    return YES;
}

BOOL revenant_trait_extras_equal(UITraitCollection *a, UITraitCollection *b)
{
    NSDictionary *first = revenant_trait_extras(a), *second = revenant_trait_extras(b);
    return first == second || (!first.count && !second.count) || [first isEqualToDictionary:second];
}

NSUInteger revenant_trait_extras_hash(UITraitCollection *collection)
{
    NSUInteger hash = 0;
    NSDictionary *extras = revenant_trait_extras(collection);
    for (NSString *name in extras) {
        id value = extras[name];
        hash ^= name.hash + ([value isKindOfClass:[NSNumber class]] ? (NSUInteger)[value unsignedIntegerValue] * 2654435761u : [(NSObject *)value hash]);
    }
    return hash;
}

static NSString *revenant_trait_value_text_for_name(NSString *name, NSInteger number)
{
    if (!name)
        return nil;
    __block NSString *found = nil;
    revenant_each_kind(^(RevenantTraitKind kind) {
        if (found || ![kind.name isEqualToString:name])
            return;
        if (kind.described == 2 && kind.first) {
            NSArray *names = [kind.first componentsSeparatedByString:@","];
            if (number >= 0 && number < (NSInteger)names.count)
                found = names[number];
        } else if (kind.described == 1 && number >= 0)
            found = number == 0 ? kind.first : (number == 1 ? kind.second : nil);
    });
    return found;
}

NSString *revenant_trait_value_text(const RevenantTraitDefinition *definition, id value)
{
    if (!value)
        return nil;
    if (definition && definition->kind == RevenantTraitValueObject)
        return [value description];
    NSInteger number = [value integerValue];
    NSString *name = revenant_trait_value_text_for_name(definition ? definition->name : nil, number);
    return name.length ? name : [NSString stringWithFormat:@"%ld", (long)number];
}

static RevenantTraitValueReader *revenant_trait_value_readers;
static NSUInteger revenant_trait_value_reader_count;

void revenant_add_trait_value_reader(RevenantTraitValueReader reader)
{
    if (!reader)
        return;
    RevenantTraitValueReader *grown =
        realloc(revenant_trait_value_readers, (revenant_trait_value_reader_count + 1) * sizeof(*grown));
    if (!grown)
        return;
    revenant_trait_value_readers = grown;
    revenant_trait_value_readers[revenant_trait_value_reader_count++] = reader;
}

static void revenant_add_trait(UITraitCollection *collection, NSMutableArray *traits, RevenantTraitKind kind)
{
    if (!kind.described)
        return;
    for (NSUInteger index = 0; index < revenant_trait_value_reader_count; index++) {
        BOOL known = NO, isDefault = NO;
        NSString *printed = revenant_trait_value_readers[index](collection, kind.name, &known, &isDefault);
        if (!known)
            continue;
        if (printed && !isDefault)
            [traits addObject:[NSString stringWithFormat:@"%@ = %@", kind.name, printed]];
        return;
    }
    id stored = revenant_trait_extras(collection)[kind.name];
    if (!stored)
        return;
    if (kind.described == 3) {
        [traits addObject:[NSString stringWithFormat:@"%@ = %@", kind.name, stored]];
        return;
    }
    NSString *text = revenant_trait_value_text_for_name(kind.name, [stored integerValue]);
    if (!text.length)
        text = [NSString stringWithFormat:@"%ld", (long)[stored integerValue]];
    if (text)
        [traits addObject:[NSString stringWithFormat:@"%@ = %@", kind.name, text]];
}

void revenant_add_trait_extras_description(UITraitCollection *collection, NSMutableArray *traits)
{
    revenant_each_kind(^(RevenantTraitKind kind) {
        revenant_add_trait(collection, traits, kind);
    });
}

void revenant_encode_trait_extras(UITraitCollection *collection, NSCoder *coder)
{
    NSDictionary *extras = revenant_trait_extras(collection);
    for (NSString *name in extras) {
        NSString *key = [@"UITraitCollectionBuiltinTrait-_UITraitName" stringByAppendingString:name];
        id value = extras[name];
        if ([value isKindOfClass:[NSNumber class]])
            [coder encodeInteger:[value integerValue] forKey:key];
        else
            [coder encodeObject:value forKey:key];
    }
}

void revenant_decode_trait_extras(UITraitCollection *collection, NSCoder *coder)
{
    revenant_each_kind(^(RevenantTraitKind kind) {
        NSString *key = [@"UITraitCollectionBuiltinTrait-_UITraitName" stringByAppendingString:kind.name];
        if (![coder containsValueForKey:key])
            return;
        if (kind.described == 3) {
            id object = [coder decodeObjectForKey:key];
            revenant_set_trait_extra_object(collection, kind.name, object);
        } else
            revenant_set_trait_extra(collection, kind.name, [coder decodeIntegerForKey:key]);
    });
}

static void revenant_register_thirteen(void)
{
    revenant_register_trait_kind((RevenantTraitKind){RevenantContrast, 0, YES, @"Normal", @"High"});
    revenant_register_trait_kind((RevenantTraitKind){RevenantLevel, 0, YES, @"Base", @"Elevated"});
    revenant_register_trait_kind((RevenantTraitKind){RevenantLegibility, 0, NO, @"Default", @"Bold"});
}

static UITraitCollection *revenant_with(NSString *name, NSInteger value)
{
    revenant_register_thirteen();
    UITraitCollection *collection = [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
    revenant_set_trait_extra(collection, name, value);
    return collection;
}

static NSMutableArray *revenant_current_stack(void)
{
    NSMutableDictionary *dictionary = [NSThread currentThread].threadDictionary;
    NSMutableArray *stack = dictionary[@"RevenantCurrentTraits"];
    if (!stack) {
        stack = [NSMutableArray array];
        dictionary[@"RevenantCurrentTraits"] = stack;
    }
    return stack;
}

static UITraitCollection *revenant_current_base(void)
{
    UITraitCollection *screen = [UIScreen mainScreen].traitCollection;
    return screen ? screen : [UITraitCollection traitCollectionWithTraitsFromCollections:@[]];
}

@interface RevenantTraitKinds13 : NSObject
@end

@implementation RevenantTraitKinds13

+ (void)load
{
    revenant_register_thirteen();
}

@end

@implementation UITraitCollection (RevenantAppearance13)

+ (UITraitCollection *)traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)accessibilityContrast
{
    return revenant_with(RevenantContrast, accessibilityContrast);
}

+ (UITraitCollection *)traitCollectionWithLegibilityWeight:(UILegibilityWeight)legibilityWeight
{
    return revenant_with(RevenantLegibility, legibilityWeight);
}

+ (UITraitCollection *)traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)userInterfaceLevel
{
    return revenant_with(RevenantLevel, userInterfaceLevel);
}

- (UIAccessibilityContrast)accessibilityContrast
{
    return (UIAccessibilityContrast)revenant_trait_extra(self, RevenantContrast);
}

- (UILegibilityWeight)legibilityWeight
{
    return (UILegibilityWeight)revenant_trait_extra(self, RevenantLegibility);
}

- (UIUserInterfaceLevel)userInterfaceLevel
{
    return (UIUserInterfaceLevel)revenant_trait_extra(self, RevenantLevel);
}

- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(UITraitCollection *)traitCollection
{
    return self.userInterfaceStyle != traitCollection.userInterfaceStyle || self.accessibilityContrast != traitCollection.accessibilityContrast ||
           self.userInterfaceLevel != traitCollection.userInterfaceLevel ||
           revenant_trait_extra(self, @"ActiveAppearance") != (traitCollection ? revenant_trait_extra(traitCollection, @"ActiveAppearance") : 0);
}

- (UIImageConfiguration *)imageConfiguration
{
    return [[UIImageConfiguration alloc] initRevenantWithTraitCollection:self];
}

+ (UITraitCollection *)currentTraitCollection
{
    UITraitCollection *held = [revenant_current_stack() lastObject];
    return held ? held : revenant_current_base();
}

+ (void)setCurrentTraitCollection:(UITraitCollection *)currentTraitCollection
{
    NSMutableArray *stack = revenant_current_stack();
    [stack removeAllObjects];
    if (currentTraitCollection)
        [stack addObject:[UITraitCollection traitCollectionWithTraitsFromCollections:@[revenant_current_base(), currentTraitCollection]]];
}

- (void)performAsCurrentTraitCollection:(void (NS_NOESCAPE ^)(void))actions
{
    NSMutableArray *stack = revenant_current_stack();
    [stack addObject:[UITraitCollection traitCollectionWithTraitsFromCollections:@[revenant_current_base(), self]]];
    @try {
        actions();
    } @finally {
        [stack removeLastObject];
    }
}

@end
