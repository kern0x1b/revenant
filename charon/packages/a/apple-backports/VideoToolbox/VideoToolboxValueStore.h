#ifndef CHARON_VIDEOTOOLBOX_VALUE_STORE_H
#define CHARON_VIDEOTOOLBOX_VALUE_STORE_H

#import "../CharonValueStore.h"

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

#define CHARON_VIDEO_TOOLBOX_VALUE_STORE(ClassName)                                        \
    @implementation ClassName (CharonVideoToolboxValue)                                   \
    - (NSMutableDictionary *)charon_values { return CharonValueStore(self); }             \
    - (id)charon_valueForKey:(NSString *)key { return CharonValueStore(self)[key]; }       \
    - (void)charon_setValue:(id)value forKey:(NSString *)key                                \
    { CharonValueSet(self, value, key); }                                                  \
    @end

#endif
