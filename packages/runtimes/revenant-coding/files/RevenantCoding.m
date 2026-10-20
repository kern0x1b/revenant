#import "RevenantCoding.h"

#import <string.h>

#import <CoreLocation/CoreLocation.h>

#import <objc/message.h>
#import <objc/runtime.h>

static BOOL revenant_intents_ivar_is_copy(Class owner, const char *name)
{
    unsigned count = 0;
    objc_property_t *properties = class_copyPropertyList(owner, &count);
    BOOL copy = YES, found = NO;
    for (unsigned index = 0; index < count && !found; index++) {
        const char *attributes = property_getAttributes(properties[index]);
        if (!attributes) {
            continue;
        }
        const char *flags = strchr(attributes, ',');
        const char *ivar = strstr(attributes, ",V_");
        if (!flags || !ivar || strcmp(ivar + 3, name + 1) != 0) {
            continue;
        }
        found = YES;
        copy = NO;
        for (flags++; flags < ivar; flags++) {
            if (*flags == ',') {
                continue;
            }
            if (*flags == 'G' || *flags == 'S' || *flags == 'V') {
                while (*flags && *flags != ',') {
                    flags++;
                }
                flags--;
                continue;
            }
            if (*flags == 'C') {
                copy = YES;
            }
        }
    }
    free(properties);
    return copy;
}

id revenant_intents_super_init(id object, Class superclass)
{
    struct objc_super parent = { object, superclass };
    return ((id (*)(struct objc_super *, SEL, Class))objc_msgSendSuper)(&parent, @selector(init), superclass);
}

NSSet *revenant_intents_allowed_classes(void)
{
    static NSSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableSet *classes = [NSMutableSet setWithObjects:
                                 [NSArray class], [NSDictionary class], [NSSet class],
                                 [NSOrderedSet class], [NSIndexSet class], [NSCharacterSet class],
                                 [NSString class], [NSAttributedString class], [NSNumber class],
                                 [NSValue class], [NSData class], [NSDate class], [NSDateComponents class],
                                 [NSDateInterval class], [NSURL class], [NSUUID class], [NSError class],
                                 [NSLocale class], [NSRegularExpression class], nil];
        for (NSString *name in @[@"CLPlacemark", @"CNContact", @"MKMapItem", @"INShortcut",
                                 @"INVoiceShortcut", @"AXBrailleTable", @"AXRequest"]) {
            Class named = NSClassFromString(name);
            if (named) {
                [classes addObject:named];
            }
        }
        unsigned count = objc_getClassList(NULL, 0);
        if (count > 0) {
            Class *loaded = (Class *)malloc(sizeof(Class) * count);
            count = objc_getClassList(loaded, count);
            for (unsigned index = 0; index < count; index++) {
                const char *name = class_getName(loaded[index]);
                if (name && name[0] == 'I' && name[1] == 'N' && class_getSuperclass(loaded[index])) {
                    [classes addObject:loaded[index]];
                }
            }
            free(loaded);
        }
        allowed = [classes copy];
    });
    return allowed;
}

static NSString *revenant_intents_key(Class owner, const char *name)
{
    return [NSString stringWithFormat:@"%s.%s", class_getName(owner), name];
}

enum { RevenantIntentsObject, RevenantIntentsOpaque, RevenantIntentsValue };

static int revenant_intents_kind(Ivar ivar, NSUInteger *size)
{
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding) {
        return RevenantIntentsOpaque;
    }
    if (encoding[0] == '@') {
        return RevenantIntentsObject;
    }
    if (encoding[0] == '^' || encoding[0] == '#' || encoding[0] == ':') {
        return RevenantIntentsOpaque;
    }
    NSGetSizeAndAlignment(encoding, size, NULL);
    return RevenantIntentsValue;
}

int revenant_copy_is_copy_for_testing(Class owner, const char *ivar)
{
    return revenant_intents_ivar_is_copy(owner, ivar) ? 1 : 0;
}

void revenant_intents_encode(id object, NSCoder *coder)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = revenant_intents_kind(ivars[index], &size);
            NSString *key = revenant_intents_key(owner, ivar_getName(ivars[index]));
            if (kind == RevenantIntentsObject) {
                id value = object_getIvar(object, ivars[index]);
                if (value) {
                    [coder encodeObject:value forKey:key];
                }
            } else if (kind == RevenantIntentsValue && size > 0) {
                const char *bytes = (const char *)(__bridge void *)object + ivar_getOffset(ivars[index]);
                [coder encodeObject:[NSData dataWithBytes:bytes length:size] forKey:key];
            }
        }
        free(ivars);
    }
}

void revenant_intents_decode(id object, NSCoder *coder)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = revenant_intents_kind(ivars[index], &size);
            NSString *key = revenant_intents_key(owner, ivar_getName(ivars[index]));
            char *bytes = (char *)(__bridge void *)object + ivar_getOffset(ivars[index]);
            if (kind == RevenantIntentsObject) {
                id value = [coder decodeObjectOfClasses:revenant_intents_allowed_classes() forKey:key];
                if (value) {
                    object_setIvar(object, ivars[index], value);
                }
            } else if (kind == RevenantIntentsValue && size > 0) {
                NSData *data = [coder decodeObjectOfClass:[NSData class] forKey:key];
                if (data.length == size) {
                    memcpy(bytes, data.bytes, size);
                }
            }
        }
        free(ivars);
    }
}

void revenant_intents_copy(id copy, id object)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = revenant_intents_kind(ivars[index], &size);
            if (kind == RevenantIntentsObject) {
                id value = object_getIvar(object, ivars[index]);
                id owned = (value && revenant_intents_ivar_is_copy(owner, ivar_getName(ivars[index])) &&
                            [value respondsToSelector:@selector(copy)]) ? [value copy] : value;
                object_setIvar(copy, ivars[index], owned);
            } else if (kind == RevenantIntentsValue && size > 0) {
                NSUInteger offset = ivar_getOffset(ivars[index]);
                memcpy((char *)(__bridge void *)copy + offset,
                       (const char *)(__bridge void *)object + offset, size);
            }
        }
        free(ivars);
    }
}
