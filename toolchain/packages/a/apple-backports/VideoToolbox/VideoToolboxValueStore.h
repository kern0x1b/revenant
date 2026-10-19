#ifndef REVENANT_VIDEOTOOLBOX_VALUE_STORE_H
#define REVENANT_VIDEOTOOLBOX_VALUE_STORE_H

#import "../RevenantValueStore.h"

static inline NSMutableDictionary *RevenantValueStoreOfClass(Class cls)
{
    static const char key;
    NSMutableDictionary *values = objc_getAssociatedObject(cls, &key);
    if (!values) {
        values = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(cls, &key, values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return values;
}

static inline void RevenantValueSetOnClass(Class cls, id value, NSString *name)
{
    if (!name)
        return;
    if (value)
        RevenantValueStoreOfClass(cls)[name] = value;
    else
        [RevenantValueStoreOfClass(cls) removeObjectForKey:name];
}

#define REVENANT_VIDEO_TOOLBOX_VALUE_STORE(ClassName)                                        \
    @implementation ClassName (RevenantVideoToolboxValue)                                   \
    - (NSMutableDictionary *)revenant_values { return RevenantValueStore(self); }             \
    - (id)revenant_valueForKey:(NSString *)key { return RevenantValueStore(self)[key]; }       \
    - (void)revenant_setValue:(id)value forKey:(NSString *)key                                \
    { RevenantValueSet(self, value, key); }                                                  \
    @end

#endif
