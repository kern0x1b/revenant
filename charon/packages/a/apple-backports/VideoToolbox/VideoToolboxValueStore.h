#ifndef CHARON_VIDEOTOOLBOX_VALUE_STORE_H
#define CHARON_VIDEOTOOLBOX_VALUE_STORE_H

#import "../CharonValueStore.h"

// The store a CLASS property's value is kept in, and the one way such a value is put.
//
// A class property has no instance to keep the value on, so it is kept on the class itself - a property
// whose value belongs to the type rather than to an instance, which is what a class property means.
// The keyed store is per object, so the class is the object here: the same objc_getAssociatedObject
// on the class, under a key of this file's own.
//
// static inline, like CharonValueStore.h and for the reason that file gives: a library of this package
// exports only the names the registry lists, and the registry lists only names an SDK header declares,
// so a class defined in one library cannot be linked from another. Seventeen value files include this,
// and each gets its own copy of the code and needs no symbol from any of the others.
static inline NSMutableDictionary *CharonValueStoreOfClass(Class cls)
{
    static const char key;
    NSMutableDictionary *values = objc_getAssociatedObject(cls, &key);
    if (!values) {
        values = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(cls, &key, values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return values;
}

static inline void CharonValueSetOnClass(Class cls, id value, NSString *name)
{
    if (!name)
        return;
    if (value)
        CharonValueStoreOfClass(cls)[name] = value;
    else
        [CharonValueStoreOfClass(cls) removeObjectForKey:name];
}

// The category the three property macros in CharonValueStore.h read through. It is declared on each of
// this framework's own classes and on no other: seventeen declarations here rather than one on NSObject,
// because a category on NSObject adds three methods to every object in the process.
//
// The implementation is one macro rather than seventeen copies, and each of the three is a line over the
// keyed store: charon_valueForKey: is what makes a property's name spelled ONCE, in the macro's argument
// and nowhere else - the header argues that a second spelling is what the M-Z reviews caught twice, and
// 146 hand-written accessor bodies were that second spelling.
#define CHARON_VIDEO_TOOLBOX_VALUE_STORE(ClassName)                                        \
    @implementation ClassName (CharonVideoToolboxValue)                                   \
    - (NSMutableDictionary *)charon_values { return CharonValueStore(self); }             \
    - (id)charon_valueForKey:(NSString *)key { return CharonValueStore(self)[key]; }       \
    - (void)charon_setValue:(id)value forKey:(NSString *)key                                \
    { CharonValueSet(self, value, key); }                                                  \
    @end

#endif
