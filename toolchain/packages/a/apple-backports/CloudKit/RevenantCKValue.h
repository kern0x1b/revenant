#ifndef REVENANT_CK_VALUE_H
#define REVENANT_CK_VALUE_H

#import <Foundation/Foundation.h>

static inline BOOL RevenantCKSameObject(id left, id right)
{
    return left == right || [left isEqual:right];
}

static inline BOOL RevenantCKSameObjects(NSArray *left, NSArray *right)
{
    return left == right || [left isEqual:right];
}

static inline NSString *RevenantCKNewSubscriptionID(void)
{
    return [[NSUUID UUID] UUIDString];
}

#endif
