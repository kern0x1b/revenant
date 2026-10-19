#ifndef CHARON_CK_VALUE_H
#define CHARON_CK_VALUE_H

#import <Foundation/Foundation.h>

static inline BOOL CharonCKSameObject(id left, id right)
{
    return left == right || [left isEqual:right];
}

static inline BOOL CharonCKSameObjects(NSArray *left, NSArray *right)
{
    return left == right || [left isEqual:right];
}

static inline NSString *CharonCKNewSubscriptionID(void)
{
    return [[NSUUID UUID] UUIDString];
}

#endif
