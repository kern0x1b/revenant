#ifndef CHARON_VALUE_STORE_H
#define CHARON_VALUE_STORE_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// The value machinery every framework of this package whose classes are value objects shares: the
// property list, the dictionary and JSON a value is written as, the archiver walk, and the store each
// value keeps its properties in.
//
// It is a header of `static inline` functions and macros, not a class in a library, and that is
// deliberate: a library of this package exports only the names the registry lists, and the registry
// lists only names an SDK header declares, so a class defined in one library cannot be linked from
// another (measured on a built libFoundationBackports.dylib: six `os_log*` symbols exported, zero
// `charon_` C symbols, zero `Charon*` classes, and no registry entry beginning with `charon`). Two
// libraries that both include this header each get their own copy of the code and neither needs a
// symbol from the other. This is the same arrangement CharonSayOnce.h has for the say-once, which
// several libraries include from here.
//
// The roots a framework passes are advisory and are kept only for the record: a value is recognised by
// the store's own accessor (see CharonValueConvert), so a framework with two roots and one with
// thirty-eight are both covered by the same test and neither has to enumerate its classes.

// The property names an object has: its own class first, then each superclass, and without NSObject's
// own. This is the one place that knows what a value object is made of, and the dictionary, the JSON
// and the archiver all walk it - so a property the SDK header declares is always in the
// representation, and one it does not declare cannot be read.
static inline NSArray<NSString *> *CharonValuePropertyNames(Class cls)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (Class current = cls; current && current != [NSObject class]; current = class_getSuperclass(current)) {
        unsigned int count = 0;
        objc_property_t *properties = class_copyPropertyList(current, &count);
        for (unsigned int index = 0; index < count; index++)
            [names addObject:[NSString stringWithUTF8String:property_getName(properties[index])]];
        free(properties);
    }
    return names;
}

// The store, one pair of functions for every root: the dictionary is created on first use, so an
// object the port only reads costs nothing, and it is keyed by the property's own name - the same
// names the walk returns - so a value is found by name from either side.
static inline NSMutableDictionary *CharonValueStore(id owner)
{
    static const char key;
    NSMutableDictionary *values = objc_getAssociatedObject(owner, &key);
    if (!values) {
        values = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(owner, &key, values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return values;
}

static inline void CharonValueSet(id owner, id value, NSString *key)
{
    if (!key)
        return;
    if (value)
        CharonValueStore(owner)[key] = value;
    else
        [CharonValueStore(owner) removeObjectForKey:key];
}

// What a property's value becomes in a dictionary. Four cases, and each is the only one that keeps
// the value true:
//
//   - a value of the framework itself is its own dictionary, so the JSON is a tree of the same shape
//     the object graph is and nothing is flattened into a string;
//   - an NSMeasurement carries a double in a unit, and the double is the value: the unit is named by
//     the property's own declared type, which the header keeps, so a number need not repeat it;
//   - an NSDate is a point in time, and the number a JSON can carry is its time interval since the
//     reference date, which is exact and reversible;
//   - and an NSURL is its absolute string, because that is what identifies it to anything that reads
//     it.
//
// Anything else is already a JSON type. A nil property is left out of the dictionary entirely rather
// than written as null, so a reader can tell "not measured" from "measured as nothing".
static inline id CharonValueConvertProperties(id value, Class firstRoot, Class secondRoot);

static inline id CharonValueConvert(id value, Class firstRoot, Class secondRoot)
{
    if (!value || value == [NSNull null])
        return nil;
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]])
        return value;
    if ([value isKindOfClass:[NSDate class]])
        return @([(NSDate *)value timeIntervalSinceReferenceDate]);
    if ([value isKindOfClass:[NSURL class]])
        return [(NSURL *)value absoluteString];
    if ([value isKindOfClass:[NSMeasurement class]])
        return @([(NSMeasurement *)value doubleValue]);
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *converted = [NSMutableArray array];
        for (id element in (NSArray *)value)
            [converted addObject:CharonValueConvert(element, firstRoot, secondRoot) ?: [NSNull null]];
        return converted;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *converted = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id element, BOOL *stop) {
            id one = CharonValueConvert(element, firstRoot, secondRoot);
            if (one)
                converted[[key description]] = one;
        }];
        return converted;
    }
    // A value of one of the frameworks using this header represents itself the way its own class does,
    // which is the contract its representation methods make. The test is that the class answers the
    // store's own accessor, which every value class here gets from the category its framework declares -
    // not "a subclass of one of the roots this framework named", which fits a framework with two roots
    // and cannot fit one with thirty-eight, since all of those are NSObject subclasses and there is no
    // common superclass left to name.
    if ([(id)value respondsToSelector:@selector(charon_valueForKey:)])
        return CharonValueConvertProperties(value, firstRoot, secondRoot);
    return [value description];
}

// The object's own properties, each key the property's own name as the SDK header spells it.
//
// The STORE is read, not the getter, and that is the whole point of it. A scalar property's getter boxes
// its value, so a property nothing ever set reads back as 0 or NO - and asking the getter would put
// that into the dictionary as a measured zero, which is exactly what MetricKit's facts promise the port
// does not do ("a property that was never set is left out rather than written as null"). Reading the
// store makes "not set" absent whatever the property's type, and it is the same string the KVC walk
// and the setter use, so the three cannot disagree.
static inline NSDictionary *CharonValueConvertProperties(id value, Class firstRoot, Class secondRoot)
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (NSString *name in CharonValuePropertyNames([value class])) {
        id held = CharonValueStore(value)[name];
        if (!held)
            continue;
        id converted = CharonValueConvert(held, firstRoot, secondRoot);
        if (converted)
            dictionary[name] = converted;
    }
    return dictionary;
}

// The JSON is the dictionary, serialised: there is no second, private shape to match, so anything
// that can read this JSON can read -dictionaryRepresentation and find the same content.
static inline NSData *CharonValueJSON(id value, Class firstRoot, Class secondRoot)
{
    NSDictionary *dictionary = CharonValueConvertProperties(value, firstRoot, secondRoot);
    if (![NSJSONSerialization isValidJSONObject:dictionary])
        return [NSJSONSerialization dataWithJSONObject:@{} options:0 error:NULL];
    return [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
}

// The classes a decoded value of this framework may be: every class the framework carries, found
// through the runtime by its own prefix so the set cannot fall behind the classes that are built, and
// the Foundation value types those hold. An archive naming a class outside the set decodes as nil
// rather than as an instance of something the process does not have.
static inline NSSet<Class> *CharonValueDecodableClasses(NSString *prefix)
{
    static NSMutableDictionary<NSString *, NSSet<Class> *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary dictionary];
    });
    NSSet<Class> *known = cache[prefix];
    if (known)
        return known;
    NSMutableSet *found = [NSMutableSet set];
    int count = objc_getClassList(NULL, 0);
    if (count > 0) {
        Class *list = (Class *)malloc(sizeof(Class) * (size_t)count);
        count = objc_getClassList(list, count);
        for (int index = 0; index < count; index++)
            if ([NSStringFromClass(list[index]) hasPrefix:prefix])
                [found addObject:list[index]];
        free(list);
    }
    for (NSString *name in @[@"NSString", @"NSDate", @"NSNumber", @"NSData", @"NSURL", @"NSArray",
                             @"NSDictionary", @"NSMeasurement", @"NSDimension", @"NSNull"])
        if (NSClassFromString(name))
            [found addObject:NSClassFromString(name)];
    [cache setObject:found forKey:prefix];
    return found;
}

// The archiver, over the same property list: a payload archived by this package is read back into the
// properties it was written from. `ok` answers NO when a key the archive names could not be decoded,
// which is the one thing a caller of a decoding initialiser can see.
static inline void CharonValueEncode(id value, NSCoder *coder)
{
    for (NSString *name in CharonValuePropertyNames([value class])) {
        id held = [value valueForKey:name];
        if (held)
            [coder encodeObject:held forKey:name];
    }
}

static inline BOOL CharonValueDecode(id value, NSCoder *coder, NSSet<Class> *allowed)
{
    BOOL whole = YES;
    for (NSString *name in CharonValuePropertyNames([value class])) {
        if (![coder containsValueForKey:name])
            continue;
        id held = [coder decodeObjectOfClasses:allowed forKey:name];
        if (held)
            [value setValue:held forKey:name];
        else
            whole = NO;
    }
    return whole;
}

// The one way a value is put in, on the class's own CharonMetricValue category and on SensorKit's when
// it arrives: -charon_setValue:forKey: with the property's own name as the key. Every category
// declares it, so a translation unit outside the class's file can fill a value in.

// A property whose value is a STRUCT - CMTimeRange, a chromaticity, a CGRect - cannot be cast out of
// the store the way an object can and cannot sit in a dictionary, so it is held as an NSValue over its
// own bytes. That is real storage rather than a widened number, and the object comes back with the
// layout the type declares.
#define CHARON_STRUCT_PROPERTY(Type, name)                                                 \
    -(Type)name {                                                                           \
        Type value = {};                                                                     \
        NSValue *boxed = [self charon_valueForKey:@ #name];                                 \
        if (boxed)                                                                           \
            [boxed getValue:&value size:sizeof(Type)];                                      \
        return value;                                                                        \
    }                                                                                        \
    -(void)charon_set##name:(Type)value {                                                   \
        [self charon_setValue:[NSValue valueWithBytes:&value objCType:@encode(Type)]          \
                         forKey:@ #name];                                                    \
    }

// One value property: the accessor the SDK header declares, and nothing else. A per-property setter
// generated here would be a SECOND place every property's name is spelled - the property here and the
// selector a call site sends - and a second spelling is what the M-Z reviews caught twice: once with
// the declaration and the accessor disagreeing, and once with a macro that emitted
// `charon_setcumulativeCPUTime:` while every call site sent `charon_setCumulativeCPUTime:`. The preprocessor
// cannot capitalise a name, so doing that correctly needs a 142-entry spelling table maintained by
// hand - a worse version of the same duplication, because a new property is a compile error in it.
//
// A value is therefore put in through the store's own -charon_setValue:forKey:, with the property's
// name as the key, which is the SAME string the property walk and every KVC read use. There is one
// spelling of each property's name, in the header, and a key that does not match one simply reads nil.
#define CHARON_VALUE_PROPERTY(Type, name)                                                   \
    -(Type)name { return (Type)[self charon_valueForKey:@ #name]; }

// A property whose value is not an object - a count, a flag - is boxed into the store as an NSNumber
// and read back out of one, which is what the property walk sees through KVC as well.
#define CHARON_SCALAR_PROPERTY(Type, name)                                                  \
    -(Type)name { return (Type)[[self charon_valueForKey:@ #name] longLongValue]; }

// The same for a double, which longLongValue would round.
#define CHARON_DOUBLE_PROPERTY(Type, name)                                                  \
    -(Type)name { return (Type)[[self charon_valueForKey:@ #name] doubleValue]; }

// A property the release declares with a getter of its own: Apple's SRAcousticSettings.h renames the
// getter of eight BOOL properties to the is... form and leaves the property's own name alone, so the
// selector the class carries is not the one the property is spelled with. Both spellings are needed and
// neither may be written twice, so the macro takes both - the name is what the store is keyed by and
// what a caller writes, the getter is the selector Apple's class carries.
#define CHARON_SCALAR_GETTER(Type, name, getter)                                           \
    -(Type)getter { return (Type)[[self charon_valueForKey:@ #name] longLongValue]; }

// The door a value class keeps for itself when its public -init refuses, which is what a class whose
// own framework raises for -init does (see SensorKit's CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT):
// -copyWithZone: must hand back a NEW object holding the same values, and the only way to make one
// of these is through a door the class owns. `values` is another object's store, so the copy holds
// the same names and each held value that conforms to NSCopying is copied too - which is what a copy
// means, and the same rule the -copyWithZone: bodies of this package already apply to the classes
// whose -init does not refuse.
#define CHARON_VALUE_COPY_INITIALISER                                                       \
    -(instancetype)initWithCharonValues:(NSDictionary *)values {                           \
        self = [super init];                                                                \
        if (self) {                                                                         \
            for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) { \
                id held = values[key];                                                       \
                [self charon_setValue:[held conformsToProtocol:@protocol(NSCopying)] ? [held copy] : held \
                         forKey:key];                                                        \
            }                                                                                \
        }                                                                                    \
        return self;                                                                         \
    }

#endif
