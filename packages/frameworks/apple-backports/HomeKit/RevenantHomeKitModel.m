#import "RevenantHomeKitModel.h"
#import "RevenantHomeKitInternal.h"

NSString *const RevenantHomeKitHomeOrderKey = @"org.revenant.homekit.order";

NSMutableDictionary *RevenantHomeKitRecord(NSString *table, NSString *identifier)
{
    RevenantHomeKitStore *store = [RevenantHomeKitStore shared];
    NSMutableDictionary *all = [store tableNamed:table];
    NSMutableDictionary *record = all[identifier];
    if (!record) {
        record = [[NSMutableDictionary alloc] init];
        all[identifier] = record;
    }
    return record;
}

id RevenantHomeKitField(NSMutableDictionary *record, NSString *key, id fallback)
{
    id value = record[key];
    if (!value) {
        record[key] = fallback;
        return fallback;
    }
    return value;
}

NSString *RevenantHomeKitStringField(NSMutableDictionary *record, NSString *key, NSString *fallback)
{
    return [RevenantHomeKitField(record, key, fallback) copy];
}

BOOL RevenantHomeKitBoolField(NSMutableDictionary *record, NSString *key, BOOL fallback)
{
    return [RevenantHomeKitField(record, key, @(fallback)) boolValue];
}

NSArray<NSString *> *RevenantHomeKitStringListField(NSMutableDictionary *record, NSString *key)
{
    NSMutableArray *list = [RevenantHomeKitField(record, key, @[]) mutableCopy];
    for (id entry in list) {
        if (![entry isKindOfClass:[NSString class]])
            return @[];
    }
    return list;
}

void RevenantHomeKitSetField(NSString *table, NSString *identifier, NSString *key, id value)
{
    RevenantHomeKitStore *store = [RevenantHomeKitStore shared];
    NSMutableDictionary *record = [store tableNamed:table][identifier];
    if (!record)
        return;
    if (value)
        record[key] = value;
    else
        [record removeObjectForKey:key];
    [store flushTableNamed:table];
}

void RevenantHomeKitOnMainQueue(void (^work)(void))
{
    if ([NSThread isMainThread])
        work();
    else
        dispatch_async(dispatch_get_main_queue(), work);
}

NSError *RevenantHomeKitError(HMErrorCode code, NSString *localizedDescription)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (localizedDescription)
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    return [NSError errorWithDomain:HMErrorDomain code:code userInfo:userInfo];
}

NSError *RevenantHomeKitErrorForAccessory(HMErrorCode code, HMAccessory *accessory, NSString *localizedDescription)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (localizedDescription)
        userInfo[NSLocalizedDescriptionKey] = localizedDescription;
    if (accessory.identifier)
        userInfo[HMUserFailedAccessoriesKey] = @[accessory.identifier];
    return [NSError errorWithDomain:HMErrorDomain code:code userInfo:userInfo];
}

void RevenantHomeKitTell(id delegate, SEL selector, void (^work)(id target))
{
    if (!delegate || ![delegate respondsToSelector:selector])
        return;
    RevenantHomeKitOnMainQueue(^{
        if ([delegate respondsToSelector:selector])
            work(delegate);
    });
}

void RevenantHomeKitFinish(void (^handler)(id, NSError *), id result, NSError *error)
{
    if (!handler)
        return;
    RevenantHomeKitOnMainQueue(^{
        handler(result, error);
    });
}

void RevenantHomeKitFinishError(void (^handler)(NSError *), NSError *error)
{
    RevenantHomeKitFinish(^(id result, NSError *reported) {
        (void)result;
        handler(reported);
    }, nil, error);
}

HMHome *RevenantHomeKitHome(NSString *identifier)
{
    return [[HMHome alloc] revenant_initWithStore:[RevenantHomeKitStore shared] identifier:nil];
}
