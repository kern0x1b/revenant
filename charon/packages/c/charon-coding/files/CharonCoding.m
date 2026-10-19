//
//  CharonCoding.m
//  Intents
//
//  The three functions CharonCoding.h declares, and nothing else: this file exports no
//  symbol of the framework's surface, so the package's release check has no API to place in an
//  object of its own and every band keeps it.
//

#import "CharonCoding.h"

#import <string.h>

#import <CoreLocation/CoreLocation.h>

#import <objc/message.h>
#import <objc/runtime.h>

// Whether the property an ivar belongs to is declared copy, which the copy below has to honour:
// a property declared copy owns one of its own object and a property declared strong or retain
// shares the original's, and a copy that turned the first into the second would be a different
// answer from the one the header gives.
//
// The two are matched the way the runtime pairs them and not by name: a property's attributes end
// in its backing ivar (T@"NSString",C,N,V_name), and a property whose ivar is not spelled after it
// would be missed by any name comparison - which is how a lookup by the ivar's own name, with its
// leading underscore, found nothing at all and made every object ivar a copy.
//
// The ownership is then read out of the **field list**, which is a comma-separated set of flags
// after the type field. It is not read by searching the string: the type field is the class's own
// name, so the C of "INCar" and the S of "NSString" are inside it, R is *readonly* and S is a
// custom setter's name, and the only characters that mean ownership are the flags themselves - C
// for copy, & for retain, W for weak, and nothing at all for assign.
//
// Measured with the port's own compiler, armv7-apple-ios6.1.3:
//   strong / retain   T@"X",&,N,V_p        copy iff C is absent
//   copy              T@"X",C,N,V_p
//   assign            T@"X",N,V_p
//   weak              T@"X",W,N,V_p
//   readonly, strong  T@"X",R,&,N,V_p     R is readonly; & is the ownership
//   getter=isFoo      T@"X",&,N,GisFoo,V_p  the G payload runs to the next comma
static BOOL charon_intents_ivar_is_copy(Class owner, const char *name)
{
    unsigned count = 0;
    objc_property_t *properties = class_copyPropertyList(owner, &count);
    BOOL copy = YES, found = NO;
    for (unsigned index = 0; index < count && !found; index++) {
        const char *attributes = property_getAttributes(properties[index]);
        if (!attributes) {
            continue;
        }
        // The type field is everything up to the first comma: no type encoding holds one.
        const char *flags = strchr(attributes, ',');
        const char *ivar = strstr(attributes, ",V_");
        // The two spellings of one name: a property's V_ field carries the ivar name without its
        // leading underscore, and ivar_getName() carries it with. Comparing them as they are
        // never matches, which is how this walk became dead code and every ivar a copy.
        if (!flags || !ivar || strcmp(ivar + 3, name + 1) != 0) {
            continue;
        }
        found = YES;
        copy = NO;
        for (flags++; flags < ivar; flags++) {
            if (*flags == ',') {
                continue;               // the next field's first character
            }
            if (*flags == 'G' || *flags == 'S' || *flags == 'V') {
                // A payload: the getter's, the setter's or the ivar's name, which runs to the
                // next comma and is not a flag of its own.
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

id charon_intents_super_init(id object, Class superclass)
{
    struct objc_super parent = { object, superclass };
    return ((id (*)(struct objc_super *, SEL, Class))objc_msgSendSuper)(&parent, @selector(init), superclass);
}

// The classes an Intents archive nests besides the Intents classes themselves: the containers
// Foundation's own archives are built from, and the value types. Every class of this process
// whose name begins with IN is in the set as well, which is what an archive of an Intents object
// may hold, and it is read from the runtime once instead of written out here so a class of a
// later group of this package is allowed without this file naming it.
NSSet *charon_intents_allowed_classes(void)
{
    static NSSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Every name here is a class an archive of this package's data may hold, and the set is
        // built from the names the process actually has: this file lives in the library every
        // backport links, and a name it linked for one framework's sake would put that framework
        // in every port. A class this process does not have cannot be in one of its archives, so
        // leaving it out costs nothing and keeps CLPlacemark allowed where CoreLocation is.
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

// The key one ivar is carried under names the class that owns the ivar and the ivar's own name,
// so two classes of one hierarchy that both have a "date" never read each other's.
static NSString *charon_intents_key(Class owner, const char *name)
{
    return [NSString stringWithFormat:@"%s.%s", class_getName(owner), name];
}

// An ivar that holds a pointer to an object, a pointer to something that is not one (a block's
// context, a C pointer), or a value of the class's own shape.
enum { CharonIntentsObject, CharonIntentsOpaque, CharonIntentsValue };

static int charon_intents_kind(Ivar ivar, NSUInteger *size)
{
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding) {
        return CharonIntentsOpaque;
    }
    if (encoding[0] == '@') {
        return CharonIntentsObject;
    }
    if (encoding[0] == '^' || encoding[0] == '#' || encoding[0] == ':') {
        return CharonIntentsOpaque;
    }
    NSGetSizeAndAlignment(encoding, size, NULL);
    return CharonIntentsValue;
}

// What charon_intents_ivar_is_copy answers for one ivar, exposed so a test can check the
// decision without a copy: tests/backports/callgen/ownership-test.m is that test, and it is the
// negative control for the guard that matches a property to its backing ivar.
int charon_copy_is_copy_for_testing(Class owner, const char *ivar)
{
    return charon_intents_ivar_is_copy(owner, ivar) ? 1 : 0;
}

void charon_intents_encode(id object, NSCoder *coder)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = charon_intents_kind(ivars[index], &size);
            NSString *key = charon_intents_key(owner, ivar_getName(ivars[index]));
            if (kind == CharonIntentsObject) {
                id value = object_getIvar(object, ivars[index]);
                if (value) {
                    [coder encodeObject:value forKey:key];
                }
            } else if (kind == CharonIntentsValue && size > 0) {
                const char *bytes = (const char *)(__bridge void *)object + ivar_getOffset(ivars[index]);
                [coder encodeObject:[NSData dataWithBytes:bytes length:size] forKey:key];
            }
        }
        free(ivars);
    }
}

void charon_intents_decode(id object, NSCoder *coder)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = charon_intents_kind(ivars[index], &size);
            NSString *key = charon_intents_key(owner, ivar_getName(ivars[index]));
            char *bytes = (char *)(__bridge void *)object + ivar_getOffset(ivars[index]);
            if (kind == CharonIntentsObject) {
                id value = [coder decodeObjectOfClasses:charon_intents_allowed_classes() forKey:key];
                if (value) {
                    object_setIvar(object, ivars[index], value);
                }
            } else if (kind == CharonIntentsValue && size > 0) {
                NSData *data = [coder decodeObjectOfClass:[NSData class] forKey:key];
                if (data.length == size) {
                    memcpy(bytes, data.bytes, size);
                }
            }
        }
        free(ivars);
    }
}

void charon_intents_copy(id copy, id object)
{
    for (Class owner = [object class]; owner && owner != [NSObject class]; owner = class_getSuperclass(owner)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(owner, &count);
        for (unsigned index = 0; index < count; index++) {
            NSUInteger size = 0;
            int kind = charon_intents_kind(ivars[index], &size);
            if (kind == CharonIntentsObject) {
                // The copy owns what it is handed the way the property says: a property declared
                // copy gets one of its own, and a property declared strong or retain shares the
                // original's, so the two objects share nothing the header says they should.
                id value = object_getIvar(object, ivars[index]);
                id owned = (value && charon_intents_ivar_is_copy(owner, ivar_getName(ivars[index])) &&
                            [value respondsToSelector:@selector(copy)]) ? [value copy] : value;
                object_setIvar(copy, ivars[index], owned);
            } else if (kind == CharonIntentsValue && size > 0) {
                NSUInteger offset = ivar_getOffset(ivars[index]);
                memcpy((char *)(__bridge void *)copy + offset,
                       (const char *)(__bridge void *)object + offset, size);
            }
        }
        free(ivars);
    }
}
