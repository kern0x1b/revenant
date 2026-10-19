#import "CharonHomeKitModel.h"
#import "CharonHomeKitInternal.h"

NSString *const CharonHomeKitHomeOrderKey = @"org.charon.homekit.order";

NSMutableDictionary *CharonHomeKitRecord(NSString *table, NSString *identifier)
{
    CharonHomeKitStore *store = [CharonHomeKitStore shared];
    NSMutableDictionary *all = [store tableNamed:table];
    NSMutableDictionary *record = all[identifier];
    if (!record) {
        record = [[NSMutableDictionary alloc] init];
        all[identifier] = record;
    }
    return record;
}

id CharonHomeKitField(NSMutableDictionary *record, NSString *key, id fallback)
{
    id value = record[key];
    if (!value) {
        record[key] = fallback;
        return fallback;
    }
    return value;
}

NSString *CharonHomeKitStringField(NSMutableDictionary *record, NSString *key, NSString *fallback)
{
    return [CharonHomeKitField(record, key, fallback) copy];
}

BOOL CharonHomeKitBoolField(NSMutableDictionary *record, NSString *key, BOOL fallback)
{
    return [CharonHomeKitField(record, key, @(fallback)) boolValue];
}

NSArray<NSString *> *CharonHomeKitStringListField(NSMutableDictionary *record, NSString *key)
{
    NSMutableArray *list = [CharonHomeKitField(record, key, @[]) mutableCopy];
    for (id entry in list) {
        if (![entry isKindOfClass:[NSString class]])
            return @[];
    }
    return list;
}

void CharonHomeKitSetField(NSString *table, NSString *identifier, NSString *key, id value)
{
    CharonHomeKitStore *store = [CharonHomeKitStore shared];
    NSMutableDictionary *record = [store tableNamed:table][identifier];
    if (!record)
        return;
    if (value)
        record[key] = value;
    else
        [record removeObjectForKey:key];
    [store flushTableNamed:table];
}

void CharonHomeKitOnMainQueue(void (^work)(void))
{
    if ([NSThread isMainThread])
        work();
    else
        dispatch_async(dispatch_get_main_queue(), work);
}

NSError *CharonHomeKitError(HMErrorCode code, NSString *localizedDescription)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (localizedDescription)
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    return [NSError errorWithDomain:HMErrorDomain code:code userInfo:userInfo];
}

NSError *CharonHomeKitErrorForAccessory(HMErrorCode code, HMAccessory *accessory, NSString *localizedDescription)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (localizedDescription)
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    if (accessory.identifier)
        userInfo[HMUserFailedAccessoriesKey] = @[accessory.identifier];
    return [NSError errorWithDomain:HMErrorDomain code:code userInfo:userInfo];
}

void CharonHomeKitTell(id delegate, SEL selector, void (^work)(id target))
{
    if (!delegate || ![delegate respondsToSelector:selector])
        return;
    CharonHomeKitOnMainQueue(^{
        if ([delegate respondsToSelector:selector])
            work(delegate);
    });
}

void CharonHomeKitFinish(void (^handler)(id, NSError *), id result, NSError *error)
{
    if (!handler)
        return;
    CharonHomeKitOnMainQueue(^{
        handler(result, error);
    });
}

void CharonHomeKitFinishError(void (^handler)(NSError *), NSError *error)
{
    CharonHomeKitFinish(^(id result, NSError *reported) {
        (void)result;
        handler(reported);
    }, nil, error);
}

HMHome *CharonHomeKitHome(NSString *identifier)
{
    return [[HMHome alloc] charon_initWithStore:[CharonHomeKitStore shared] identifier:nil];
}
